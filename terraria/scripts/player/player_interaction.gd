class_name PlayerInteraction
extends Node

## Gehoert an: Player/Interaction in res://scenes/player/player.tscn
## Tool-Use / Swing getrennt von tile-basiertem Mining und Platzierung.

@export var interaction_range_tiles: float = 5.0
@export var base_mining_speed: float = 1.0
@export var tile_size: int = 16
@export var require_adjacent_block: bool = true
@export var block_catalog: BlockCatalog
@export var item_catalog: ItemCatalog
@export var item_drop_scene: PackedScene
@export var debug_targeting: bool = false

var current_mining_tile := Vector2i(9999, 9999)
var mining_progress: float = 0.0
var current_target_cell := Vector2i(9999, 9999)

@onready var _player: Player = get_parent()
@onready var _inventory: Inventory = $"../Inventory"
@onready var _anim: AnimationPlayer = $"../AnimationPlayer"
@onready var _hitbox: Area2D = $"../ToolPivot/ToolArm/ToolHitbox"

var _tile_map: TileMapLayer
var _highlight: Node2D
var _highlight_frame: ColorRect
var _progress_fill: ColorRect
var _drops_parent: Node2D
var _debug_label: Label
var _attack_cooldown_left: float = 0.0
var _mine_sound_cooldown: float = 0.0
var _autolock_dir := Vector2i.ZERO
var _autolock_active: bool = false
var _world_use_held: bool = false

const INVALID_TILE := Vector2i(9999, 9999)
const AUTOLOCK_DEADZONE := 16.0
const AUTOLOCK_AXIS_BIAS := 1.35
const AUTOLOCK_SWITCH_HYSTERESIS := 8.0
const MINE_SOUND_INTERVAL := 0.22
const WEAK_FEEDBACK_INTERVAL := 0.55
const MIN_MINING_TIME := 0.05

var _weak_flash_left: float = 0.0
var _weak_message_cooldown: float = 0.0
var _weak_hint: Label
var _debug_refresh_left: float = 0.0
var _mouse_marker: ColorRect
var _target_marker: ColorRect
var _mouse_cell := Vector2i(9999, 9999)

func _ready() -> void:
	_tile_map = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if _tile_map != null and _tile_map.tile_set != null:
		# Das TileSet ist die einzige Quelle der Rastergroesse.
		tile_size = _tile_map.tile_set.tile_size.x
	_highlight = get_tree().get_first_node_in_group("block_highlight") as Node2D
	_drops_parent = get_tree().get_first_node_in_group("item_drops") as Node2D
	_debug_label = get_tree().get_first_node_in_group("mining_debug") as Label
	if _highlight != null:
		_highlight_frame = _highlight.get_node_or_null("Frame") as ColorRect
		_progress_fill = _highlight.get_node_or_null("Progress") as ColorRect
		_weak_hint = _highlight.get_node_or_null("WeakHint") as Label


func _process(delta: float) -> void:
	if _tile_map == null:
		return
	_weak_flash_left = maxf(0.0, _weak_flash_left - delta)
	_weak_message_cooldown = maxf(0.0, _weak_message_cooldown - delta)
	if _weak_flash_left <= 0.0:
		_hide_weak_hint()
	if not _can_interact_with_world():
		_autolock_active = false
		_world_use_held = false
		_reset_mining()
		_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
		if _highlight != null:
			_highlight.visible = false
		_hide_targeting_markers()
		return
	if Input.is_action_just_pressed("use_item"):
		_world_use_held = true
	if not Input.is_action_pressed("use_item"):
		_world_use_held = false
	var hover_tile := _get_hovered_tile()
	_mouse_cell = hover_tile
	var tile := _resolve_target_tile(hover_tile)
	current_target_cell = tile
	var block := get_block_data(tile)
	var in_range := _is_in_range(tile)
	var hover_in_range := _is_in_range(hover_tile)
	var place_state := _get_place_state(hover_tile, hover_in_range)
	_update_highlight(tile, block, in_range, place_state)
	_handle_tool_use(delta)
	_handle_mining(delta, tile, block, in_range)
	_handle_placement(hover_tile, place_state)
	_handle_seed_plant(hover_tile, hover_in_range)
	_update_targeting_markers(hover_tile, tile)
	_debug_refresh_left -= delta
	_update_debug(tile, block, in_range, place_state)


func get_block_data(tile_position: Vector2i) -> BlockData:
	if _tile_map == null or block_catalog == null or tile_position == INVALID_TILE:
		return null
	if _tile_map.get_cell_source_id(tile_position) == -1:
		return null
	return block_catalog.get_by_atlas(_tile_map.get_cell_atlas_coords(tile_position))


func _can_interact_with_world() -> bool:
	if UIManager.is_blocking_gameplay():
		return false
	if _player == null or not _player.world_input_enabled:
		return false
	return not _is_pointer_over_blocking_ui()


func _is_pointer_over_blocking_ui() -> bool:
	if get_viewport().gui_get_hovered_control() != null:
		return true
	var mouse := get_viewport().get_mouse_position()
	var groups: Array[StringName] = [&"minimap_ui", &"inventory_ui", &"world_map_ui", &"hotbar_ui", &"pause_menu", &"options_menu", &"fog_debug_ui", &"lantern_ui"]
	for group_name in groups:
		var node := get_tree().get_first_node_in_group(group_name)
		var control := node as Control
		if control == null or not control.visible:
			continue
		if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if control.get_global_rect().has_point(mouse):
			return true
	return false


func _get_hovered_tile() -> Vector2i:
	if _tile_map == null:
		return INVALID_TILE
	return _tile_map.local_to_map(_tile_map.get_local_mouse_position())


func _get_world_mouse() -> Vector2:
	if _tile_map != null:
		return _tile_map.to_global(_tile_map.get_local_mouse_position())
	if _player != null:
		return _player.get_world_mouse_position()
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


func _is_in_range(tile_position: Vector2i) -> bool:
	if tile_position == INVALID_TILE or _tile_map == null:
		return false
	var tile_center := _tile_map.to_global(_tile_map.map_to_local(tile_position))
	var reach := interaction_range_tiles * float(tile_size)
	return _player.global_position.distance_to(tile_center) <= reach


func _resolve_target_tile(hover_tile: Vector2i) -> Vector2i:
	var want_autolock := InputMap.has_action("block_autolock") and Input.is_action_pressed("block_autolock")
	if not want_autolock:
		_autolock_active = false
		_autolock_dir = Vector2i.ZERO
		return hover_tile
	_autolock_active = true
	return _autolock_tile()


func _autolock_tile() -> Vector2i:
	var body := _collider_rect()
	if body.size.x < 1.0:
		return INVALID_TILE
	var mouse := _get_world_mouse()
	var delta := mouse - body.get_center()
	var previous_dir := _autolock_dir
	var new_dir := _pick_autolock_dir(delta)
	var dir_changed := previous_dir != Vector2i.ZERO and new_dir != previous_dir
	_autolock_dir = new_dir
	if new_dir == Vector2i.ZERO:
		return INVALID_TILE
	# Laufendes Mining behalten, solange der Block gilt und die Richtung nicht klar wechselt.
	if not dir_changed and _is_valid_autolock_cell(current_mining_tile):
		return current_mining_tile
	var candidates := _gather_autolock_candidates(body, mouse, new_dir)
	return _pick_mouse_candidate(candidates, mouse)


func _pick_autolock_dir(delta: Vector2) -> Vector2i:
	if delta.length() < AUTOLOCK_DEADZONE:
		return _autolock_dir if _autolock_dir != Vector2i.ZERO else Vector2i.DOWN
	var want_h := absf(delta.x) >= absf(delta.y)
	if _autolock_dir != Vector2i.ZERO:
		var was_h := _autolock_dir.x != 0
		if was_h and not want_h and absf(delta.y) < absf(delta.x) * AUTOLOCK_AXIS_BIAS:
			want_h = true
		elif not was_h and want_h and absf(delta.x) < absf(delta.y) * AUTOLOCK_AXIS_BIAS:
			want_h = false
	if want_h:
		return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP


func _is_valid_autolock_cell(cell: Vector2i) -> bool:
	return cell != INVALID_TILE and get_block_data(cell) != null and _is_in_range(cell)


func _gather_autolock_candidates(body: Rect2, mouse: Vector2, dir: Vector2i) -> Array[Vector2i]:
	if dir == Vector2i.DOWN or dir == Vector2i.UP:
		return _autolock_vertical_candidates(body, mouse, dir)
	return _autolock_horizontal_candidates(body, dir)


func _autolock_vertical_candidates(body: Rect2, mouse: Vector2, dir: Vector2i) -> Array[Vector2i]:
	var inset := 3.0
	var y := body.end.y + 1.0 if dir == Vector2i.DOWN else body.position.y - 1.0
	var left_cell := _world_to_cell(Vector2(body.position.x + inset, y))
	var right_cell := _world_to_cell(Vector2(body.end.x - inset, y))
	var starts: Array[Vector2i] = [left_cell]
	if right_cell != left_cell:
		starts.append(right_cell)
	if mouse.x < body.position.x - 2.0:
		var extra := Vector2i(left_cell.x - 1, left_cell.y)
		if extra != left_cell and extra != right_cell:
			starts.append(extra)
	elif mouse.x > body.end.x + 2.0:
		var extra := Vector2i(right_cell.x + 1, right_cell.y)
		if extra != left_cell and extra != right_cell:
			starts.append(extra)
	return _unique_solids_from(starts, dir)


func _autolock_horizontal_candidates(body: Rect2, dir: Vector2i) -> Array[Vector2i]:
	var x := body.position.x - 1.0 if dir == Vector2i.LEFT else body.end.x + 1.0
	var top_cell := _world_to_cell(Vector2(x, body.position.y + 2.0))
	var bottom_cell := _world_to_cell(Vector2(x, body.end.y - 2.0))
	var min_row := mini(top_cell.y, bottom_cell.y)
	var max_row := maxi(top_cell.y, bottom_cell.y)
	var starts: Array[Vector2i] = []
	for row in range(min_row, max_row + 1):
		starts.append(Vector2i(top_cell.x, row))
	return _unique_solids_from(starts, dir)


func _unique_solids_from(starts: Array[Vector2i], dir: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for start in starts:
		var cell := _first_solid_in_dir(start, dir)
		if cell != INVALID_TILE and not result.has(cell):
			result.append(cell)
	return result


func _pick_mouse_candidate(candidates: Array[Vector2i], mouse: Vector2) -> Vector2i:
	if candidates.is_empty():
		return INVALID_TILE
	var best := INVALID_TILE
	var best_dist := INF
	for cell in candidates:
		var dist := _cell_center(cell).distance_to(mouse)
		if dist < best_dist:
			best_dist = dist
			best = cell
	if _is_valid_autolock_cell(current_target_cell) and candidates.has(current_target_cell):
		var current_dist := _cell_center(current_target_cell).distance_to(mouse)
		if best_dist + AUTOLOCK_SWITCH_HYSTERESIS >= current_dist:
			return current_target_cell
	return best


func _cell_center(cell: Vector2i) -> Vector2:
	return _tile_map.to_global(_tile_map.map_to_local(cell))


func _collider_rect() -> Rect2:
	var collision := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return Rect2(_player.global_position, Vector2.ZERO)
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2(_player.global_position, Vector2.ZERO)
	return Rect2(collision.global_position - rect_shape.size * 0.5, rect_shape.size)


func _world_to_cell(world: Vector2) -> Vector2i:
	return _tile_map.local_to_map(_tile_map.to_local(world))


func _first_solid_in_dir(start: Vector2i, dir: Vector2i) -> Vector2i:
	var cell := start
	var max_steps := int(ceili(interaction_range_tiles)) + 2
	for _i in max_steps:
		if not _is_in_range(cell):
			return INVALID_TILE
		if get_block_data(cell) != null:
			return cell
		cell += dir
	return INVALID_TILE


func _handle_tool_use(delta: float) -> void:
	_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
	if not _world_use_held:
		return
	if _attack_cooldown_left > 0.0:
		return
	if _anim != null and _anim.is_playing() and _anim.current_animation == &"tool_swing":
		return
	var item := _inventory.get_selected_item() if _inventory != null else null
	if not _item_can_swing(item):
		return
	var cooldown := item.attack_cooldown if item.attack_cooldown > 0.0 else 0.35
	if _hitbox != null and _hitbox.has_method("begin_swing"):
		_hitbox.call("begin_swing", item.damage, item.knockback, _player)
	if _anim != null:
		_anim.play(&"tool_swing")
	_player.play_sfx(&"Swing")
	_attack_cooldown_left = cooldown


func _item_can_swing(item: ItemData) -> bool:
	if item == null:
		return false
	return item.item_type == ItemData.ItemType.TOOL or item.item_type == ItemData.ItemType.WEAPON or item.tool_kind != ItemData.ToolKind.NONE


func _get_place_state(tile: Vector2i, in_range: bool) -> Dictionary:
	var item := _inventory.get_selected_item() if _inventory != null else null
	var holding_placeable := item != null and item.is_placeable()
	var empty := get_block_data(tile) == null
	var can_place := false
	var reason := ""
	if not holding_placeable:
		reason = "no_item"
	elif not empty:
		reason = "occupied"
	elif not in_range:
		reason = "range"
	elif _tile_overlaps_player(tile):
		reason = "player"
	elif require_adjacent_block and not _has_solid_neighbor(tile):
		reason = "neighbor"
	elif block_catalog == null or block_catalog.get_by_id(item.placeable_block_id) == null:
		reason = "unknown_block"
	else:
		can_place = true
		reason = "ok"
	return {
		"holding": holding_placeable,
		"empty": empty,
		"can_place": can_place,
		"reason": reason,
		"item": item,
	}


func _update_highlight(tile: Vector2i, block: BlockData, in_range: bool, place_state: Dictionary) -> void:
	if _highlight == null:
		return
	if tile == INVALID_TILE:
		_highlight.visible = false
		return
	var show := block != null or bool(place_state["holding"]) or _holding_seed()
	_highlight.visible = show
	if not show:
		return
	var top_left := _tile_map.to_global(_tile_map.map_to_local(tile) - Vector2(tile_size, tile_size) * 0.5)
	_highlight.global_position = top_left
	if _highlight_frame == null:
		return
	if _holding_seed():
		_highlight_frame.color = Color(0.35, 0.9, 0.4, 0.45) if _can_plant_seed(tile, in_range) else Color(0.9, 0.25, 0.2, 0.45)
	elif bool(place_state["holding"]) and bool(place_state["empty"]):
		_highlight_frame.color = Color(0.35, 0.9, 0.4, 0.45) if bool(place_state["can_place"]) else Color(0.9, 0.25, 0.2, 0.45)
	elif block != null:
		if _weak_flash_left > 0.0:
			_highlight_frame.color = Color(0.95, 0.18, 0.12, 0.7)
		elif _autolock_active and in_range:
			_highlight_frame.color = Color(1.0, 0.86, 0.2, 0.55)
		else:
			_highlight_frame.color = Color(0.95, 0.95, 0.4, 0.45) if in_range else Color(0.9, 0.25, 0.2, 0.4)
	else:
		_highlight_frame.color = Color(0.9, 0.25, 0.2, 0.4)


func _handle_mining(delta: float, tile: Vector2i, block: BlockData, in_range: bool) -> void:
	var holding := _world_use_held
	if not holding or block == null or not in_range:
		_reset_mining()
		return
	var item: ItemData = _inventory.get_selected_item() if _inventory != null else null
	var inst: ItemInstanceData = _inventory.get_selected_instance() if _inventory != null else ItemInstanceData.new()
	var break_check := block.evaluate_break(item, inst)
	if break_check != BlockData.BreakCheck.CAN_BREAK:
		_reset_mining()
		_show_break_denied_feedback(break_check, block)
		return
	if tile != current_mining_tile:
		current_mining_tile = tile
		mining_progress = 0.0
	var speed := _mining_efficiency(item, inst, block)
	var hardness := block.hardness
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees != null:
		var trunk_hardness := trees.get_trunk_hardness(tile)
		if trunk_hardness > 0.0:
			hardness = trunk_hardness
	var mining_time := maxf(hardness / maxf(speed, 0.01), MIN_MINING_TIME)
	mining_progress += delta
	_update_progress_bar(mining_progress / mining_time)
	_mine_sound_cooldown -= delta
	if _mine_sound_cooldown <= 0.0:
		_player.play_sfx(&"MineHit")
		_mine_sound_cooldown = MINE_SOUND_INTERVAL
	if mining_progress >= mining_time:
		_break_block(tile, block)


func _get_effective_tool_power(item: ItemData, inst: ItemInstanceData) -> int:
	if item == null or item.tool_data == null:
		return 0
	if inst == null:
		return item.get_base_tool_power()
	return inst.effective_tool_power(item)


func _mining_efficiency(item: ItemData, inst: ItemInstanceData, block: BlockData) -> float:
	var speed := base_mining_speed
	if item == null or block == null:
		return speed
	var use_speed := inst.effective_use_speed(item) if inst != null else item.get_base_use_speed()
	speed *= maxf(use_speed, 0.01)
	var required_kind := block.get_required_tool()
	if required_kind != int(ItemData.ToolKind.NONE) and int(item.tool_kind) == required_kind:
		var power := _get_effective_tool_power(item, inst)
		speed *= 1.0 + float(maxi(power, 0)) * 0.012
	return speed


func _show_break_denied_feedback(result: BlockData.BreakCheck, block: BlockData) -> void:
	if result == BlockData.BreakCheck.UNBREAKABLE:
		return
	_weak_flash_left = 0.18
	if _highlight_frame != null:
		_highlight_frame.color = Color(0.95, 0.18, 0.12, 0.7)
	if _weak_message_cooldown > 0.0:
		return
	_weak_message_cooldown = WEAK_FEEDBACK_INTERVAL
	_player.play_sfx(&"MineHit", -8.0)
	if _weak_hint == null:
		return
	if result == BlockData.BreakCheck.WRONG_TOOL:
		var need := ItemData.get_tool_kind_display_name(block.get_required_tool())
		_weak_hint.text = "Falsches Werkzeug" if need.is_empty() else "Falsches Werkzeug (%s)" % need
	else:
		_weak_hint.text = "Werkzeug zu schwach (Power %d)" % block.get_required_tool_power()
	_weak_hint.visible = true


func _hide_weak_hint() -> void:
	if _weak_hint != null:
		_weak_hint.visible = false


func _handle_placement(tile: Vector2i, place_state: Dictionary) -> void:
	if not Input.is_action_just_pressed("interact_secondary"):
		return
	if not bool(place_state["can_place"]):
		return
	var item: ItemData = place_state["item"]
	var block := block_catalog.get_by_id(item.placeable_block_id)
	if block == null:
		return
	if block_catalog != null:
		block_catalog.set_block_cell(_tile_map, tile, block)
	else:
		_tile_map.set_cell(tile, _terrain_source_id(), block.atlas_coords)
	_notify_map_tile(tile)
	if _inventory != null:
		_inventory.consume_from_slot(_inventory.selected_hotbar_index, 1)
	if _anim != null:
		_anim.play(&"block_place")
	_player.play_sfx(&"BlockPlace")


func _terrain_source_id() -> int:
	if block_catalog != null:
		return block_catalog.terrain_source_id(_tile_map.tile_set if _tile_map != null else null)
	var tileset := _tile_map.tile_set if _tile_map != null else null
	if tileset == null or tileset.get_source_count() == 0:
		return 0
	return tileset.get_source_id(0)


func _tile_overlaps_player(tile: Vector2i) -> bool:
	var collision := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return true
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return true
	var player_rect := Rect2(collision.global_position - rect_shape.size * 0.5, rect_shape.size).grow(1.0)
	var center := _tile_map.to_global(_tile_map.map_to_local(tile))
	var tile_rect := Rect2(center - Vector2(tile_size, tile_size) * 0.5, Vector2(tile_size, tile_size))
	return player_rect.intersects(tile_rect)


func _has_solid_neighbor(tile: Vector2i) -> bool:
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for dir in dirs:
		var neighbor: Vector2i = tile + dir
		if _tile_map.get_cell_source_id(neighbor) == -1:
			continue
		var neighbor_block := get_block_data(neighbor)
		if neighbor_block == null or neighbor_block.solid:
			return true
	return false


func _break_block(tile: Vector2i, block: BlockData) -> void:
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	var item: ItemData = _inventory.get_selected_item() if _inventory != null else null
	if trees != null and trees.handle_break(tile, _player, item):
		_reset_mining()
		_refresh_target_after_break()
		return
	_tile_map.erase_cell(tile)
	_notify_map_tile(tile)
	_player.play_sfx(&"BlockBreak")
	_spawn_drop(tile, block)
	_reset_mining()
	_refresh_target_after_break()


func _handle_seed_plant(tile: Vector2i, in_range: bool) -> void:
	if not Input.is_action_just_pressed("interact_secondary"):
		return
	if not _can_plant_seed(tile, in_range):
		return
	var item := _inventory.get_selected_item() if _inventory != null else null
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees == null:
		return
	var species := trees.get_species_for_seed_item(item)
	var ground := _seed_ground_tile(tile)
	if not trees.try_plant_seed(_player, ground, species):
		return
	if _inventory != null:
		_inventory.consume_from_slot(_inventory.selected_hotbar_index, 1)
	if _anim != null:
		_anim.play(&"block_place")
	_player.play_sfx(&"BlockPlace")


func _holding_seed() -> bool:
	var item := _inventory.get_selected_item() if _inventory != null else null
	return item != null and item.is_seed()


func _seed_ground_tile(tile: Vector2i) -> Vector2i:
	var block := get_block_data(tile)
	if block != null:
		return tile
	return tile + Vector2i(0, 1)


func _can_plant_seed(tile: Vector2i, in_range: bool) -> bool:
	if not in_range or not _holding_seed():
		return false
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees == null:
		return false
	var item := _inventory.get_selected_item()
	if trees.get_species_for_seed_item(item) == null:
		return false
	var ground := _seed_ground_tile(tile)
	var ground_block := get_block_data(ground)
	if ground_block == null:
		return false
	if ground_block.id != 1 and ground_block.id != 2:
		return false
	if get_block_data(ground + Vector2i(0, -1)) != null:
		return false
	return true


func _notify_map_tile(tile: Vector2i) -> void:
	var map_data := get_tree().get_first_node_in_group("world_map_data")
	if map_data != null and map_data.has_method("update_tile"):
		map_data.call("update_tile", tile)
	else:
		var world_map := get_tree().get_first_node_in_group("world_map_ui")
		if world_map != null and world_map.has_method("update_map_tile"):
			world_map.call("update_map_tile", tile)
	_notify_visibility(tile)


func _notify_visibility(tile: Vector2i) -> void:
	var vis := get_tree().get_first_node_in_group("visibility_overlay")
	if vis == null:
		return
	if vis.has_method("invalidate_cell"):
		vis.call("invalidate_cell", tile)
	elif vis.has_method("invalidate"):
		vis.call("invalidate")


func _spawn_drop(tile: Vector2i, block: BlockData) -> void:
	if block == null or block.drop_item_id < 0 or item_drop_scene == null or item_catalog == null:
		return
	var item := item_catalog.get_item(block.drop_item_id)
	if item == null:
		return
	var amount := 1
	if block.ore_data != null:
		var rng := RandomNumberGenerator.new()
		var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
		var seed_base := world.get_seed() if world != null else 0
		rng.seed = hash("%d:%d:%d:%d" % [seed_base, tile.x, tile.y, block.id])
		amount = block.ore_data.roll_drop_amount(rng)
	var drop := item_drop_scene.instantiate() as ItemDrop
	var parent := _drops_parent if _drops_parent != null else _tile_map.get_parent()
	parent.add_child(drop)
	drop.global_position = _tile_map.to_global(_tile_map.map_to_local(tile))
	drop.setup(block.drop_item_id, amount, item.icon)


func _refresh_target_after_break() -> void:
	if _autolock_active:
		current_target_cell = _autolock_tile()
	else:
		current_target_cell = _get_hovered_tile()
	var block := get_block_data(current_target_cell)
	var in_range := _is_in_range(current_target_cell)
	var hover := _get_hovered_tile()
	_update_highlight(current_target_cell, block, in_range, _get_place_state(hover, _is_in_range(hover)))


func _reset_mining() -> void:
	current_mining_tile = Vector2i(9999, 9999)
	mining_progress = 0.0
	_mine_sound_cooldown = 0.0
	_update_progress_bar(0.0)


func _update_progress_bar(ratio: float) -> void:
	if _progress_fill == null:
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	_progress_fill.visible = clamped > 0.0
	_progress_fill.size = Vector2(float(tile_size) * clamped, 3.0)


func _update_debug(tile: Vector2i, block: BlockData, in_range: bool, _place_state: Dictionary) -> void:
	if _debug_label == null:
		return
	if not debug_targeting and _debug_refresh_left > 0.0:
		return
	_debug_refresh_left = 0.05 if debug_targeting else 0.25
	if debug_targeting:
		_debug_label.text = _targeting_debug_text()
		return
	var block_name := block.display_name if block != null else "Air"
	var selected := _inventory.get_selected_item() if _inventory != null else null
	var selected_name := selected.display_name if selected != null else "leer"
	var lines := [
		"Tile %s  %s %s" % [str(tile), block_name, "in range" if in_range else "far"],
		"Mine %.2f  CD %.2f  Hand %s" % [mining_progress, _attack_cooldown_left, selected_name],
	]
	lines.append_array(_world_debug_lines(tile))
	_debug_label.text = "\n".join(lines)


func get_targeting_debug() -> Dictionary:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() as Camera2D if vp != null else null
	var world := _get_world_mouse()
	var screen := vp.get_mouse_position() if vp != null else Vector2.ZERO
	var local := _tile_map.to_local(world) if _tile_map != null else Vector2.ZERO
	var zoom_out := 1.0
	if cam != null and cam.has_method("get_zoom_out"):
		zoom_out = float(cam.call("get_zoom_out"))
	return {
		"mouse_screen": screen,
		"mouse_world": world,
		"tilemap_local": local,
		"mouse_cell": _mouse_cell,
		"final_target": current_target_cell,
		"mining_cell": current_mining_tile,
		"autolock": _autolock_active,
		"zoom": cam.zoom if cam != null else Vector2.ONE,
		"zoom_out": zoom_out,
		"match": _mouse_cell == current_target_cell,
	}


func _targeting_debug_text() -> String:
	var data := get_targeting_debug()
	var world: Vector2 = data["mouse_world"]
	var screen: Vector2 = data["mouse_screen"]
	var local: Vector2 = data["tilemap_local"]
	var zoom_v: Vector2 = data["zoom"]
	return "\n".join([
		"Mouse Screen: %s" % str(screen.round()),
		"Mouse World: %s" % str(world.round()),
		"TileMap Local: %s" % str(local.round()),
		"Mouse Cell: %s" % str(data["mouse_cell"]),
		"Final Target Cell: %s" % str(data["final_target"]),
		"Mining Cell: %s" % str(data["mining_cell"]),
		"Auto Target: %s" % ("ON" if bool(data["autolock"]) else "OFF"),
		"CTRL: %s" % ("ON" if bool(data["autolock"]) else "OFF"),
		"Camera Zoom: %.2f (out %.2f)" % [zoom_v.x, float(data["zoom_out"])],
	])


func _update_targeting_markers(mouse_cell: Vector2i, target_cell: Vector2i) -> void:
	if not debug_targeting:
		_hide_targeting_markers()
		return
	_ensure_targeting_markers()
	_place_marker(_mouse_marker, mouse_cell)
	_place_marker(_target_marker, target_cell)


func _ensure_targeting_markers() -> void:
	if _mouse_marker != null and _target_marker != null:
		return
	var parent: Node = _highlight.get_parent() if _highlight != null else _tile_map
	if parent == null:
		return
	if _mouse_marker == null:
		_mouse_marker = _make_debug_marker(Color(1.0, 1.0, 1.0, 0.72), Vector2(float(tile_size), float(tile_size)))
		parent.add_child(_mouse_marker)
	if _target_marker == null:
		_target_marker = _make_debug_marker(Color(1.0, 0.86, 0.12, 0.78), Vector2(float(tile_size) - 4.0, float(tile_size) - 4.0))
		parent.add_child(_target_marker)


func _make_debug_marker(color: Color, size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = size
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 11
	rect.visible = false
	return rect


func _place_marker(marker: ColorRect, cell: Vector2i) -> void:
	if marker == null or _tile_map == null:
		return
	if cell == INVALID_TILE:
		marker.visible = false
		return
	var top_left := _tile_map.to_global(_tile_map.map_to_local(cell) - Vector2(tile_size, tile_size) * 0.5)
	if marker == _target_marker:
		top_left += Vector2(2.0, 2.0)
	marker.global_position = top_left
	marker.visible = true


func _hide_targeting_markers() -> void:
	if _mouse_marker != null:
		_mouse_marker.visible = false
	if _target_marker != null:
		_target_marker.visible = false


## Weltinfos nur anzeigen, wenn tatsaechlich ein Generator in der Szene haengt.
func _world_debug_lines(hover_tile: Vector2i) -> Array[String]:
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null:
		return []
	var player_tile := _tile_map.local_to_map(_tile_map.to_local(_player.global_position))
	var lines: Array[String] = [
		"Seed %d  %s" % [world.get_seed(), world.get_region(player_tile)],
		"Player %s  Surface Y %d" % [str(player_tile), world.get_surface_y(player_tile.x)],
	]
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees != null:
		var counts := trees.counts()
		lines.append("Baeume E:%d B:%d K:%d" % [counts["oak"], counts["birch"], counts["pine"]])
		var trunk_h := trees.get_trunk_hardness(hover_tile)
		if trunk_h > 0.0:
			lines.append("Stamm-Haerte %.2f" % trunk_h)
	return lines
