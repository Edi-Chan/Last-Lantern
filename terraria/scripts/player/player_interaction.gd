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
@export var projectile_scene: PackedScene
@export var debug_targeting: bool = false

var current_mining_tile := Vector2i(9999, 9999)
var mining_progress: float = 0.0
var current_target_cell := Vector2i(9999, 9999)

@onready var _player: Player = get_parent()
@onready var _inventory: Inventory = $"../Inventory"
@onready var _anim: AnimationPlayer = $"../AnimationPlayer"
@onready var _hitbox: Area2D = $"../ToolPivot/ToolArm/ToolHitbox"

const ATTACK_ANIMS := [&"tool_swing", &"sword_swing", &"spear_thrust", &"bow_shot", &"lantern_burst"]
const WOOD_ARROW_ID := 114
const BOW_TRAJECTORY_STEPS := 300
const BOW_TRAJECTORY_DT := 1.0 / 60.0

var _lantern_cooldown_left: float = 0.0
var _bow_drawing: bool = false
var _bow_charge: float = 0.0
var _bow_item: ItemData
var _bow_weapon: Resource
var _bow_trajectory: Line2D

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
const BARE_HAND_DAMAGE := 7
const BARE_HAND_KNOCKBACK := 70.0
const BARE_HAND_COOLDOWN := 0.42
const BARE_HAND_RANGE := 1.8
const BARE_HAND_MINE_SPEED := 0.5

var _weak_flash_left: float = 0.0
var _weak_message_cooldown: float = 0.0
var _weak_hint: Label
var _debug_refresh_left: float = 0.0
var _mouse_marker: ColorRect
var _target_marker: ColorRect
var _mouse_cell := Vector2i(9999, 9999)
var _auto_tool_held: bool = false
var _auto_tool_saved_slot: int = -1
var _frame_poly: Polygon2D
var _progress_poly: Polygon2D
var _last_vp_mouse := Vector2.ZERO
var _place_orientation: int = 0
var _building_parts: BuildingPartSystem
var _plant_progress: float = 0.0
var _plant_tile := Vector2i(9999, 9999)
var _vegetation: VegetationSystem
var _stair_drag_active: bool = false
var _stair_drag_start := Vector2i(9999, 9999)
var _stair_drag_placed: Dictionary = {}

func _ready() -> void:
	_tile_map = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if _tile_map != null and _tile_map.tile_set != null:
		# Das TileSet ist die einzige Quelle der Rastergroesse.
		tile_size = _tile_map.tile_set.tile_size.x
	if _inventory != null and not _inventory.selected_slot_changed.is_connected(_on_hotbar_changed):
		_inventory.selected_slot_changed.connect(_on_hotbar_changed)
	_highlight = get_tree().get_first_node_in_group("block_highlight") as Node2D
	_drops_parent = get_tree().get_first_node_in_group("item_drops") as Node2D
	_debug_label = get_tree().get_first_node_in_group("mining_debug") as Label
	if _highlight != null:
		_highlight_frame = _highlight.get_node_or_null("Frame") as ColorRect
		_progress_fill = _highlight.get_node_or_null("Progress") as ColorRect
		_weak_hint = _highlight.get_node_or_null("WeakHint") as Label
		_setup_world_highlight()


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
		_cancel_bow_draw()
		_clear_auto_tool(true)
		_reset_mining()
		_attack_cooldown_left = maxf(0.0, _attack_cooldown_left - delta)
		if _highlight != null:
			_highlight.visible = false
		_hide_targeting_markers()
		_clear_stair_drag()
		var buildings := get_tree().get_first_node_in_group("building_manager")
		if buildings != null and buildings.has_method("update_hotbar_preview"):
			buildings.call("update_hotbar_preview", null, INVALID_TILE, false)
		return
	if Input.is_action_just_pressed("use_item"):
		_world_use_held = true
	if not Input.is_action_pressed("use_item"):
		_world_use_held = false
	if InputMap.has_action("rotate_place") and Input.is_action_just_pressed("rotate_place"):
		_place_orientation = 1 - _place_orientation
	var hover_tile := _get_hovered_tile()
	_mouse_cell = hover_tile
	var tile := _resolve_target_tile(hover_tile)
	current_target_cell = tile
	_handle_auto_tool(tile)
	var block := get_block_data(tile)
	var in_range := _is_in_range(tile)
	var hover_in_range := _is_in_range(hover_tile)
	var holding_blueprint := _holding_blueprint()
	_handle_building_blueprint(hover_tile, hover_in_range)
	if holding_blueprint:
		if _highlight != null:
			_highlight.visible = false
	var stair_item := _selected_stair_block()
	var place_state := _get_place_state(hover_tile, hover_in_range)
	var plant_cell := _resolve_plant_cell(hover_tile)
	if plant_cell == INVALID_TILE:
		plant_cell = _resolve_plant_cell(tile)
	if not holding_blueprint:
		_update_highlight(tile, block, in_range, place_state, plant_cell)
	_handle_tool_use(delta)
	var plant_in_range := plant_cell != INVALID_TILE and _is_in_range(plant_cell)
	var harvesting_plant := _handle_plant_harvest(delta, plant_cell, plant_in_range)
	if not harvesting_plant:
		_handle_mining(delta, tile, block, in_range)
	if not holding_blueprint:
		if _is_bow_equipped() or _bow_drawing:
			_clear_stair_drag()
		elif stair_item != null:
			_handle_stair_placement(hover_tile, hover_in_range, stair_item)
		else:
			_clear_stair_drag()
			_handle_placement(hover_tile, place_state)
	if not _is_bow_equipped() and not _bow_drawing:
		_handle_seed_plant(hover_tile, hover_in_range)
		_handle_plant_place(hover_tile, hover_in_range)
	_update_targeting_markers(hover_tile, tile)
	_debug_refresh_left -= delta
	_update_debug(tile, block, in_range, place_state)


func _on_hotbar_changed(_index: int) -> void:
	cancel_attack()


func get_block_data(tile_position: Vector2i) -> BlockData:
	if tile_position == INVALID_TILE:
		return null
	var parts := _parts()
	if parts != null:
		var part_block := parts.get_block_at(tile_position)
		if part_block != null:
			return part_block
	if _tile_map == null or block_catalog == null:
		return null
	if _tile_map.get_cell_source_id(tile_position) == -1:
		return null
	return block_catalog.get_cell_block(_tile_map, tile_position)


func _can_interact_with_world() -> bool:
	if UIManager.is_blocking_gameplay():
		return false
	if _player == null or not _player.world_input_enabled:
		return false
	var buildings := get_tree().get_first_node_in_group("building_manager")
	if buildings != null and buildings.has_method("is_player_inside") and bool(buildings.call("is_player_inside")):
		return false
	return not _is_pointer_over_blocking_ui()


func _is_pointer_over_blocking_ui() -> bool:
	if get_viewport().gui_get_hovered_control() != null:
		return true
	var mouse := get_viewport().get_mouse_position()
	var groups: Array[StringName] = [&"minimap_ui", &"inventory_ui", &"world_map_ui", &"hotbar_ui", &"pause_menu", &"options_menu", &"lantern_ui", &"admin_menu"]
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_vp_mouse = event.position


func _setup_world_highlight() -> void:
	if _highlight == null:
		return
	if _highlight_frame != null:
		_highlight_frame.visible = false
		_highlight_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _progress_fill != null:
		_progress_fill.visible = false
		_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _frame_poly == null:
		_frame_poly = Polygon2D.new()
		_frame_poly.z_index = 0
		_highlight.add_child(_frame_poly)
	if _progress_poly == null:
		_progress_poly = Polygon2D.new()
		_progress_poly.z_index = 1
		_highlight.add_child(_progress_poly)


func _viewport_mouse() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		return vp.get_mouse_position()
	return _last_vp_mouse


func _get_hovered_tile() -> Vector2i:
	if _tile_map == null:
		return INVALID_TILE
	# TileMap-eigene Maus: beruecksichtigt Kamera, Zoom und Stretch 1:1.
	return _tile_map.local_to_map(_tile_map.get_local_mouse_position())


func _get_world_mouse() -> Vector2:
	if _tile_map != null:
		return _tile_map.get_global_mouse_position()
	if _player != null:
		return _player.get_global_mouse_position()
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()


func _player_reach_origin() -> Vector2:
	if _player == null:
		return Vector2.ZERO
	var collision := _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		return collision.global_position
	return _player.global_position


func _is_in_range(tile_position: Vector2i) -> bool:
	if tile_position == INVALID_TILE or _tile_map == null or _player == null:
		return false
	var origin := _player_reach_origin()
	var reach := interaction_range_tiles * float(tile_size)
	var tile_center := _tile_map.to_global(_tile_map.map_to_local(tile_position))
	if origin.distance_to(tile_center) <= reach:
		return true
	# Mausfeld: wenn der Cursor selbst in Reichweite liegt, zaehlt der Block unter der Maus.
	if tile_position == _mouse_cell:
		return origin.distance_to(_get_world_mouse()) <= reach
	return false


func _resolve_target_tile(hover_tile: Vector2i) -> Vector2i:
	# Maus hat Vorrang: das Feld unter dem Cursor ist immer das Ziel, sobald dort ein Block liegt.
	# STRG-Autolock greift nur, wenn die Maus in der Luft haengt.
	if get_block_data(hover_tile) != null:
		_autolock_active = false
		_autolock_dir = Vector2i.ZERO
		return hover_tile
	var want_autolock := InputMap.has_action("block_autolock") and Input.is_action_pressed("block_autolock")
	if not want_autolock:
		_autolock_active = false
		_autolock_dir = Vector2i.ZERO
		return hover_tile
	_autolock_active = true
	return _autolock_tile()


func _is_auto_tool_held() -> bool:
	if _player != null and _player.has_method("is_auto_tool_held"):
		return bool(_player.call("is_auto_tool_held"))
	if Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT):
		return true
	return InputMap.has_action("auto_tool") and Input.is_action_pressed("auto_tool")


func _handle_auto_tool(target_tile: Vector2i) -> void:
	if not _is_auto_tool_held():
		_clear_auto_tool(true)
		return
	if _inventory == null:
		return
	if not _auto_tool_held:
		_auto_tool_held = true
		_auto_tool_saved_slot = _inventory.selected_hotbar_index
	var block := get_block_data(target_tile)
	if block == null or not _is_in_range(target_tile):
		_restore_auto_tool_slot()
		return
	var preferred := _auto_tool_preferred_kind(target_tile, block)
	var slot := _inventory.find_best_hotbar_tool_for(block, preferred)
	if slot < 0:
		_restore_auto_tool_slot()
		return
	_inventory.set_selected_hotbar_index(slot)


func _auto_tool_preferred_kind(tile: Vector2i, block: BlockData) -> int:
	if block != null:
		var need := block.get_required_tool()
		if need != 0:
			return need
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees != null and trees.is_tree_tile(tile):
		return int(ItemData.ToolKind.AXE)
	if block != null:
		return int(ItemData.ToolKind.PICKAXE)
	return 0


func _restore_auto_tool_slot() -> void:
	if _inventory == null or _auto_tool_saved_slot < 0:
		return
	_inventory.set_selected_hotbar_index(_auto_tool_saved_slot)


func _clear_auto_tool(restore: bool) -> void:
	if restore and _auto_tool_held:
		_restore_auto_tool_slot()
	_auto_tool_held = false
	_auto_tool_saved_slot = -1


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
	_lantern_cooldown_left = maxf(0.0, _lantern_cooldown_left - delta)
	if _bow_drawing:
		_tick_bow_draw(delta)
		return
	var item := _inventory.get_selected_item() if _inventory != null else null
	if _is_bow_item(item):
		_handle_bow_use(item)
		return
	if _is_attack_anim_playing():
		return
	if not _world_use_held:
		return
	if _attack_cooldown_left > 0.0:
		return
	if not _item_can_swing(item):
		return
	if item == null:
		_start_bare_hand_swing()
		return
	if item.is_weapon():
		_start_weapon_attack(item)
		return
	_start_tool_swing(item)


func _handle_bow_use(item: ItemData) -> void:
	if _attack_cooldown_left > 0.0:
		return
	if _is_bow_aim_held():
		_start_bow_attack(item)
		return
	if _world_use_held:
		_fire_bow_quick(item)


func _item_can_swing(item: ItemData) -> bool:
	if item == null:
		return true
	if item.is_weapon():
		return true
	return item.item_type == ItemData.ItemType.TOOL or item.tool_kind != ItemData.ToolKind.NONE


func _is_attack_anim_playing() -> bool:
	if _anim == null or not _anim.is_playing():
		return false
	return ATTACK_ANIMS.has(_anim.current_animation)


func _start_bare_hand_swing() -> void:
	# Faustschlag ohne Inventar-Item.
	if _hitbox != null and _hitbox.has_method("begin_attack"):
		_hitbox.call("begin_attack", BARE_HAND_DAMAGE, BARE_HAND_KNOCKBACK, _player, null, &"tool_swing", 0.08, 0.18, int(ItemData.WeaponKind.NONE), BARE_HAND_RANGE)
	elif _hitbox != null and _hitbox.has_method("begin_swing"):
		_hitbox.call("begin_swing", BARE_HAND_DAMAGE, BARE_HAND_KNOCKBACK, _player)
	_play_attack_anim(&"tool_swing")
	if _player != null:
		_player.play_weapon_swing(int(ItemData.WeaponKind.NONE))
	_attack_cooldown_left = BARE_HAND_COOLDOWN / _attack_speed_scale()


func _start_tool_swing(item: ItemData) -> void:
	var inst := _inventory.get_selected_instance() if _inventory != null else null
	var damage := inst.effective_damage(item) if inst != null else item.get_base_damage()
	var kb := item.get_weapon_knockback() if item.has_method("get_weapon_knockback") else item.knockback
	if _hitbox != null and _hitbox.has_method("begin_attack"):
		_hitbox.call("begin_attack", damage, kb, _player, null, &"tool_swing", 0.08, 0.18, int(ItemData.WeaponKind.NONE), 2.5)
	elif _hitbox != null and _hitbox.has_method("begin_swing"):
		_hitbox.call("begin_swing", damage, kb, _player)
	_play_attack_anim(&"tool_swing")
	_player.play_weapon_swing(int(ItemData.WeaponKind.NONE))
	var tool_cd := item.resolve_attack_cooldown() if item.has_method("resolve_attack_cooldown") else 0.35
	_attack_cooldown_left = tool_cd / _attack_speed_scale()


func _start_weapon_attack(item: ItemData) -> void:
	match int(item.weapon_kind):
		ItemData.WeaponKind.BOW:
			return
		ItemData.WeaponKind.LANTERN:
			_start_lantern_attack(item)
		ItemData.WeaponKind.SPEAR:
			_start_melee_attack(item, &"spear_thrust", 0.16, 0.28)
		_:
			_start_melee_attack(item, &"sword_swing", 0.08, 0.18)


func _start_melee_attack(item: ItemData, anim: StringName, hit_start: float, hit_end: float) -> void:
	var inst := _inventory.get_selected_instance() if _inventory != null else null
	if inst != null and inst.durability == 0:
		return
	var damage := inst.effective_damage(item) if inst != null else item.get_base_damage()
	var kb := item.get_weapon_knockback()
	var item_range := inst.effective_range(item) if inst != null else item.get_base_range()
	var play_anim := anim if _has_anim(anim) else &"tool_swing"
	if _hitbox != null and _hitbox.has_method("begin_attack"):
		_hitbox.call("begin_attack", damage, kb, _player, item.weapon_data, play_anim, hit_start, hit_end, int(item.weapon_kind), item_range)
	_play_attack_anim(play_anim)
	_player.play_weapon_swing(int(item.weapon_kind))
	_attack_cooldown_left = item.resolve_attack_cooldown() / _attack_speed_scale()
	_use_selected_durability()


func is_drawing_bow() -> bool:
	return _bow_drawing


func _start_bow_attack(item: ItemData) -> void:
	if _bow_drawing:
		return
	if not _bow_can_shoot(item):
		return
	var weapon := item.weapon_data
	_bow_drawing = true
	_bow_charge = 0.0
	_bow_item = item
	_bow_weapon = weapon
	_apply_bow_draw_visual(_bow_charge)
	_update_bow_trajectory()
	_player.play_sfx(&"BowDraw", -4.0)


func _bow_can_shoot(item: ItemData) -> bool:
	if item == null:
		return false
	var weapon := item.weapon_data
	var ammo_id := int(weapon.get("ammo_item_id")) if weapon != null else WOOD_ARROW_ID
	if ammo_id < 0:
		ammo_id = WOOD_ARROW_ID
	if _inventory == null or _inventory.get_total_amount(ammo_id) <= 0:
		return false
	var inst := _inventory.get_selected_instance()
	if inst != null and inst.durability == 0:
		return false
	return true


func _fire_bow_quick(item: ItemData) -> void:
	if not _bow_can_shoot(item):
		return
	var weapon := item.weapon_data
	var anim := &"bow_shot" if _has_anim(&"bow_shot") else &"tool_swing"
	_play_attack_anim(anim)
	_player.play_sfx(&"BowRelease")
	_spawn_arrow(item, weapon, 1.0, true)
	var cd := 0.28
	if weapon != null and weapon.has_method("get_quick_shot_cooldown"):
		cd = float(weapon.call("get_quick_shot_cooldown"))
	_attack_cooldown_left = cd / _attack_speed_scale()


func _tick_bow_draw(delta: float) -> void:
	if not _bow_drawing:
		return
	var selected := _inventory.get_selected_item() if _inventory != null else null
	if selected != _bow_item:
		_cancel_bow_draw()
		return
	var ammo_id := int(_bow_weapon.get("ammo_item_id")) if _bow_weapon != null else WOOD_ARROW_ID
	if ammo_id < 0:
		ammo_id = WOOD_ARROW_ID
	if _inventory == null or _inventory.get_total_amount(ammo_id) <= 0:
		_cancel_bow_draw()
		return
	var draw_time := 0.55
	if _bow_weapon != null and _bow_weapon.has_method("get_draw_time"):
		draw_time = maxf(0.2, float(_bow_weapon.call("get_draw_time")))
	_bow_charge = minf(1.0, _bow_charge + delta / draw_time)
	_apply_bow_draw_visual(_bow_charge)
	_update_bow_trajectory()
	if _is_bow_aim_held():
		return
	_release_bow()


func _apply_bow_draw_visual(charge: float) -> void:
	_aim_held_at_mouse()
	if _player == null:
		return
	var arm := _player.get_node_or_null("ToolPivot/ToolArm") as Node2D
	if arm == null:
		return
	arm.position = Vector2(roundf(-7.0 * charge), 0.0)


func _release_bow() -> void:
	var item := _bow_item
	var weapon := _bow_weapon
	var charge := _bow_charge
	_clear_bow_draw_state()
	if item == null:
		return
	var anim := &"bow_shot" if _has_anim(&"bow_shot") else &"tool_swing"
	_play_attack_anim(anim)
	_player.play_sfx(&"BowRelease")
	_spawn_arrow(item, weapon, charge, false)
	_attack_cooldown_left = item.resolve_attack_cooldown() / _attack_speed_scale()


func _cancel_bow_draw() -> void:
	_clear_bow_draw_state()
	if _player == null:
		return
	var arm := _player.get_node_or_null("ToolPivot/ToolArm") as Node2D
	if arm != null:
		arm.position = Vector2.ZERO


func _clear_bow_draw_state() -> void:
	_bow_drawing = false
	_bow_charge = 0.0
	_bow_item = null
	_bow_weapon = null
	_hide_bow_trajectory()


func _is_bow_item(item: ItemData) -> bool:
	return item != null and item.is_weapon() and int(item.weapon_kind) == ItemData.WeaponKind.BOW


func _is_bow_equipped() -> bool:
	if _inventory == null:
		return false
	return _is_bow_item(_inventory.get_selected_item())


func _is_bow_aim_held() -> bool:
	return Input.is_action_pressed("interact_secondary")


func _compute_bow_shot(item: ItemData, weapon: Resource, charge: float, quick: bool = false) -> Dictionary:
	var origin := _player.global_position + Vector2(10.0 * _player.facing_sign, -24.0)
	var mouse := _get_world_mouse()
	var dir := (mouse - origin).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(_player.facing_sign, 0.0)
	var t := clampf(charge, 0.0, 1.0)
	var speed := float(weapon.get("projectile_speed")) if weapon != null else 297.0
	var gravity := 280.0
	var max_distance := item.get_base_range() * float(tile_size) if item != null else 864.0
	if weapon != null and weapon.has_method("get_projectile_gravity"):
		gravity = float(weapon.call("get_projectile_gravity"))
	if weapon != null and weapon.has_method("get_flight_distance"):
		max_distance = float(weapon.call("get_flight_distance", float(tile_size)))
	if not quick:
		speed *= lerpf(0.7, 1.0, t)
		max_distance *= lerpf(0.7, 1.0, t)
	return {
		"origin": origin,
		"velocity": dir * speed,
		"gravity": gravity,
		"max_distance": max_distance,
		"charge": t,
		"quick": quick,
	}


func _ensure_bow_trajectory() -> Line2D:
	if _bow_trajectory != null and is_instance_valid(_bow_trajectory):
		return _bow_trajectory
	var line := Line2D.new()
	line.name = "BowTrajectory"
	line.width = 2.0
	line.default_color = Color(1.0, 0.82, 0.32, 0.92)
	line.antialiased = false
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 80
	line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	line.top_level = false
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.9, 0.42, 0.95),
		Color(1.0, 0.45, 0.16, 0.12),
	])
	line.gradient = grad
	var host: Node = _player.get_parent() if _player != null else _player
	if host == null:
		host = _player
	host.add_child(line)
	line.position = Vector2.ZERO
	_bow_trajectory = line
	return line


func _update_bow_trajectory() -> void:
	if not _bow_drawing or _bow_item == null or _player == null:
		_hide_bow_trajectory()
		return
	var shot := _compute_bow_shot(_bow_item, _bow_weapon, _bow_charge, false)
	var points := Projectile.predict_arc(
		shot["origin"],
		shot["velocity"],
		shot["gravity"],
		shot["max_distance"],
		BOW_TRAJECTORY_DT,
		BOW_TRAJECTORY_STEPS
	)
	points = _clip_trajectory_to_world(points)
	var line := _ensure_bow_trajectory()
	line.position = Vector2.ZERO
	var host := line.get_parent()
	if host is Node2D:
		var local_points := PackedVector2Array()
		var node := host as Node2D
		for point in points:
			local_points.append(node.to_local(point))
		line.points = local_points
	else:
		line.points = points
	line.visible = points.size() >= 2


func _clip_trajectory_to_world(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	var clipped := PackedVector2Array()
	for i in points.size():
		var point: Vector2 = points[i]
		clipped.append(point)
		if i < 2:
			continue
		if get_block_data(_world_to_cell(point)) != null:
			break
	return clipped


func _hide_bow_trajectory() -> void:
	if _bow_trajectory != null and is_instance_valid(_bow_trajectory):
		_bow_trajectory.visible = false
		_bow_trajectory.points = PackedVector2Array()


func _aim_held_at_mouse() -> void:
	if _player == null:
		return
	var arm := _player.get_node_or_null("ToolPivot/ToolArm") as Node2D
	if arm == null:
		return
	var mouse := _get_world_mouse()
	var origin := _player.global_position + Vector2(0, -24)
	var angle := (mouse - origin).angle()
	if _player.facing_sign < 0.0:
		arm.rotation = PI - angle
	else:
		arm.rotation = angle


func _spawn_arrow(item: ItemData, weapon: Resource, charge: float = 1.0, quick: bool = false) -> void:
	if item == null or _player == null:
		return
	var ammo_id := int(weapon.get("ammo_item_id")) if weapon != null else WOOD_ARROW_ID
	if ammo_id < 0:
		ammo_id = WOOD_ARROW_ID
	if _inventory == null or not _inventory.try_consume_items([{"item_id": ammo_id, "amount": 1}]):
		return
	var scene := projectile_scene
	if scene == null and ResourceLoader.exists("res://scenes/combat/projectile.tscn"):
		scene = load("res://scenes/combat/projectile.tscn") as PackedScene
	if scene == null:
		return
	var projectile := scene.instantiate() as Node2D
	if projectile == null:
		return
	var shot := _compute_bow_shot(item, weapon, charge, quick)
	var t := float(shot["charge"])
	var ammo := _inventory.item_catalog.get_item(ammo_id) if _inventory.item_catalog != null else null
	var damage := 1
	if quick:
		damage = CombatResolver.quick_ranged_damage(weapon, ammo)
	else:
		damage = CombatResolver.charged_ranged_damage(weapon, ammo, t)
	var kb := item.get_weapon_knockback()
	if quick:
		kb *= 0.55
	else:
		kb *= lerpf(0.7, 1.15, t)
	_player.get_parent().add_child(projectile)
	projectile.global_position = shot["origin"]
	if projectile.has_method("setup"):
		var tex: Texture2D = ammo.icon if ammo != null else item.icon
		projectile.call("setup", shot["velocity"], damage, kb, _player, weapon, tex, 6.0, shot["gravity"], shot["max_distance"])
	_use_selected_durability()


func _start_lantern_attack(item: ItemData) -> void:
	if _lantern_cooldown_left > 0.0:
		return
	var inst := _inventory.get_selected_instance() if _inventory != null else null
	if inst != null and inst.durability == 0:
		return
	var damage := inst.effective_damage(item) if inst != null else item.get_base_damage()
	var kb := item.get_weapon_knockback()
	var item_range := inst.effective_range(item) if inst != null else item.get_base_range()
	var anim := &"lantern_burst" if _has_anim(&"lantern_burst") else &"tool_swing"
	if _hitbox != null and _hitbox.has_method("begin_attack"):
		_hitbox.call("begin_attack", damage, kb, _player, item.weapon_data, anim, 0.18, 0.32, int(ItemData.WeaponKind.LANTERN), item_range)
	_play_attack_anim(anim)
	_flash_lantern_light()
	_player.play_weapon_swing(int(ItemData.WeaponKind.LANTERN))
	var cd := item.resolve_attack_cooldown()
	_attack_cooldown_left = cd / _attack_speed_scale()
	_lantern_cooldown_left = cd
	_use_selected_durability()


func _flash_lantern_light() -> void:
	var light := _player.get_node_or_null("ToolPivot/ToolArm/CombatLight") as PointLight2D
	if light == null:
		return
	if light.texture == null:
		light.texture = _make_combat_light_texture()
	light.enabled = true
	light.energy = 1.35
	light.color = Color(1.0, 0.72, 0.28, 1.0)
	var tween := create_tween()
	tween.tween_property(light, "energy", 0.0, 0.42)
	tween.tween_callback(func() -> void:
		if light != null:
			light.enabled = false
	)


func _make_combat_light_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(32, 32)
	for y in 64:
		for x in 64:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 0.92, 0.7, a * a))
	return ImageTexture.create_from_image(img)


func _play_attack_anim(anim: StringName) -> void:
	if _anim == null:
		return
	if _anim.has_animation(anim):
		_anim.play(anim)
	elif _anim.has_animation(&"tool_swing"):
		_anim.play(&"tool_swing")


func _has_anim(anim: StringName) -> bool:
	return _anim != null and _anim.has_animation(anim)


func _use_selected_durability() -> void:
	if _inventory != null and _inventory.has_method("use_selected_durability"):
		_inventory.call("use_selected_durability", 1)


func cancel_attack() -> void:
	_cancel_bow_draw()
	if _hitbox != null and _hitbox.has_method("cancel_attack"):
		_hitbox.call("cancel_attack")
	if _is_attack_anim_playing() and _anim != null:
		_anim.stop()


func _get_place_state(tile: Vector2i, in_range: bool) -> Dictionary:
	var item := _inventory.get_selected_item() if _inventory != null else null
	var holding_placeable := item != null and item.is_placeable()
	var placing := block_catalog.get_by_id(item.placeable_block_id) if item != null and block_catalog != null else null
	var empty := true
	if placing != null and placing.occupies_background_layer():
		var parts := _parts()
		empty = parts == null or not parts.is_background_cell(tile)
	else:
		empty = get_block_data(tile) == null or (placing != null and placing.occupies_background_layer())
		if _parts() != null and _parts().is_entity_cell(tile):
			empty = false
		if _tile_map != null and _tile_map.get_cell_source_id(tile) != -1 and (placing == null or not placing.occupies_background_layer()):
			empty = false
	var can_place := false
	var reason := ""
	if not holding_placeable:
		reason = "no_item"
	elif not in_range:
		reason = "range"
	elif _tile_overlaps_player(tile):
		reason = "player"
	elif require_adjacent_block and placing != null and not placing.occupies_background_layer() and not placing.is_climbable and not _has_place_neighbor(tile, placing) and placing.building_part_type != BlockData.BuildingPartType.LIGHT:
		reason = "neighbor"
	elif placing == null:
		reason = "unknown_block"
	else:
		var parts := _parts()
		if parts != null and placing.is_building_part():
			var report := parts.can_place(placing, tile, _place_orientation, _player)
			can_place = bool(report.get("ok", false))
			reason = str(report.get("reason", "ok"))
		elif not empty:
			reason = "occupied"
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


func _set_highlight_color(color: Color) -> void:
	if _frame_poly != null:
		_frame_poly.color = color
	elif _highlight_frame != null:
		_highlight_frame.color = color


func _update_highlight(tile: Vector2i, block: BlockData, in_range: bool, place_state: Dictionary, plant_cell: Vector2i = Vector2i(9999, 9999)) -> void:
	if _highlight == null:
		return
	if tile == INVALID_TILE:
		_highlight.visible = false
		return
	var show := block != null or bool(place_state["holding"]) or _holding_seed() or _holding_plant() or plant_cell != INVALID_TILE
	_highlight.visible = show
	if not show:
		return
	var draw_tile := tile
	if not _holding_plant() and not _holding_seed() and not bool(place_state["holding"]) and plant_cell != INVALID_TILE:
		draw_tile = plant_cell
	var cell := Vector2(float(tile_size), float(tile_size))
	if _tile_map.tile_set != null:
		cell = Vector2(_tile_map.tile_set.tile_size)
	var top_left := _tile_map.to_global(_tile_map.map_to_local(draw_tile) - cell * 0.5)
	_highlight.global_position = top_left
	if _frame_poly != null:
		_frame_poly.polygon = PackedVector2Array([
			Vector2.ZERO,
			Vector2(cell.x, 0.0),
			cell,
			Vector2(0.0, cell.y),
		])
	if _highlight_frame != null:
		_highlight_frame.position = Vector2.ZERO
		_highlight_frame.size = cell
	if _holding_plant():
		_set_highlight_color(Color(0.35, 0.9, 0.4, 0.45) if _can_plant_item(tile, in_range) else Color(0.9, 0.25, 0.2, 0.45))
	elif _holding_seed():
		_set_highlight_color(Color(0.35, 0.9, 0.4, 0.45) if _can_plant_seed(tile, in_range) else Color(0.9, 0.25, 0.2, 0.45))
	elif bool(place_state["holding"]):
		_set_highlight_color(_placement_preview_color(place_state, tile))
	elif plant_cell != INVALID_TILE:
		_set_highlight_color(Color(0.95, 0.95, 0.4, 0.45) if _is_in_range(plant_cell) else Color(0.9, 0.25, 0.2, 0.4))
	elif block != null:
		if _weak_flash_left > 0.0:
			_set_highlight_color(Color(0.95, 0.18, 0.12, 0.7))
		elif _autolock_active and in_range:
			_set_highlight_color(Color(1.0, 0.86, 0.2, 0.55))
		else:
			_set_highlight_color(Color(0.95, 0.95, 0.4, 0.45) if in_range else Color(0.9, 0.25, 0.2, 0.4))
	else:
		_set_highlight_color(Color(0.9, 0.25, 0.2, 0.4))


func _handle_mining(delta: float, tile: Vector2i, block: BlockData, in_range: bool) -> void:
	var holding := _world_use_held
	if not holding or block == null or not in_range:
		_reset_mining()
		return
	var item: ItemData = _inventory.get_selected_item() if _inventory != null else null
	if item != null and item.is_weapon():
		_reset_mining()
		return
	var buildings := get_tree().get_first_node_in_group("building_manager")
	if buildings != null and buildings.has_method("is_protected_cell") and bool(buildings.call("is_protected_cell", tile)):
		_reset_mining()
		return
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
	speed *= _gather_speed_for(tile, block)
	var mining_time := maxf(hardness / maxf(speed, 0.01), MIN_MINING_TIME)
	mining_progress += delta
	_update_progress_bar(mining_progress / mining_time)
	_mine_sound_cooldown -= delta
	if _mine_sound_cooldown <= 0.0:
		_player.play_sfx(&"MineHit", 0.0, _audio_material(block))
		_mine_sound_cooldown = MINE_SOUND_INTERVAL
	if mining_progress >= mining_time:
		_break_block(tile, block)


func _get_effective_tool_power(item: ItemData, inst: ItemInstanceData) -> int:
	if item == null or item.tool_data == null:
		return 0
	if inst == null:
		return item.get_base_tool_power()
	return inst.effective_tool_power(item)


func _gather_speed_for(tile: Vector2i, block: BlockData) -> float:
	if _player == null or _player.stats == null:
		return 1.0
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	if trees != null and trees.is_tree_tile(tile):
		return _player.stats.woodcutting_speed()
	if block != null and block.get_required_tool() == int(ItemData.ToolKind.AXE):
		return _player.stats.woodcutting_speed()
	return _player.stats.mining_speed()


func _attack_speed_scale() -> float:
	if _player == null or _player.stats == null:
		return 1.0
	return maxf(_player.stats.attack_speed(), 0.05)


func _mining_efficiency(item: ItemData, inst: ItemInstanceData, block: BlockData) -> float:
	var speed := base_mining_speed
	if item == null:
		return speed * BARE_HAND_MINE_SPEED
	if block == null:
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
	_set_highlight_color(Color(0.95, 0.18, 0.12, 0.7))
	if _weak_message_cooldown > 0.0:
		return
	_weak_message_cooldown = WEAK_FEEDBACK_INTERVAL
	_player.play_sfx(&"MineHit", -8.0, _audio_material(block))
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


func _selected_stair_block() -> BlockData:
	if _inventory == null or block_catalog == null:
		return null
	var item := _inventory.get_selected_item()
	if item == null or not item.is_placeable():
		return null
	var block := block_catalog.get_by_id(item.placeable_block_id)
	return block if StairSystem.is_stair(block) else null


func _stair_orientation_hint(tile: Vector2i) -> int:
	var hint := StairSystem.hint_from_mouse(tile, _get_world_mouse(), _tile_map)
	var parts := _parts()
	if parts == null:
		return hint
	return parts.resolve_stair_orientation(tile, hint)


func _handle_stair_placement(hover_tile: Vector2i, _in_range: bool, block: BlockData) -> void:
	var parts := _parts()
	if parts == null or block == null:
		_clear_stair_drag()
		return
	if not Input.is_action_pressed("interact_secondary"):
		_clear_stair_drag()
		return
	if hover_tile == INVALID_TILE:
		return
	if Input.is_action_just_pressed("interact_secondary"):
		_stair_drag_active = true
		_stair_drag_start = hover_tile
		_stair_drag_placed.clear()
	if not _stair_drag_active:
		_stair_drag_start = hover_tile
		_stair_drag_active = true
	if _stair_drag_start == INVALID_TILE:
		_stair_drag_start = hover_tile
	var cells := StairSystem.diagonal_line(_stair_drag_start, hover_tile)
	var ori := StairSystem.hint_from_drag(_stair_drag_start, hover_tile)
	if cells.size() <= 1:
		ori = _stair_orientation_hint(hover_tile)
	var preview_ok: Array[bool] = []
	var preview_grade: Array[int] = []
	var simulated: Dictionary = {}
	for cell in cells:
		simulated[cell] = true
		preview_ok.append(_stair_cell_can_place(cell, block, simulated))
		var grade := 0
		var mgr := _structural()
		if mgr != null and block.structural_enabled:
			grade = int(mgr.call("preview_grade", cell, block))
		preview_grade.append(grade)
	parts.set_stair_preview(cells, preview_ok, preview_grade)
	var slot := _inventory.get_slot(_inventory.selected_hotbar_index) if _inventory != null else {}
	var remaining := int(slot.get("amount", 0))
	var placed_now := false
	for i in cells.size():
		if remaining <= 0:
			break
		var cell: Vector2i = cells[i]
		if _stair_drag_placed.has(cell):
			continue
		if not _is_in_range(cell):
			continue
		if not _stair_cell_can_place(cell, block, _stair_drag_placed):
			continue
		if not parts.try_place(block, cell, ori, _player):
			continue
		_stair_drag_placed[cell] = true
		remaining -= 1
		placed_now = true
		_notify_map_tile(cell)
		if _inventory != null:
			_inventory.consume_from_slot(_inventory.selected_hotbar_index, 1)
		var veg := _veg()
		if veg != null:
			veg.on_block_placed(cell)
	if placed_now:
		if _anim != null:
			_anim.play(&"block_place")
		_player.play_sfx(&"BlockPlace", 0.0, _audio_material(block))


func _stair_cell_can_place(cell: Vector2i, block: BlockData, line_cells: Dictionary) -> bool:
	if not _is_in_range(cell):
		return false
	var state := _get_place_state(cell, true)
	if bool(state.get("can_place", false)):
		return true
	if str(state.get("reason", "")) != "neighbor":
		return false
	if not _has_place_neighbor(cell, block) and not _stair_line_supports(cell, line_cells):
		return false
	var parts := _parts()
	if parts == null:
		return false
	return bool(parts.can_place(block, cell, 0, _player).get("ok", false))


func _stair_line_supports(cell: Vector2i, line_cells: Dictionary) -> bool:
	for dir in StairSystem.NEIGHBOR_DIRS:
		if line_cells.has(cell + dir) and cell + dir != cell:
			return true
	return false


func _clear_stair_drag() -> void:
	_stair_drag_active = false
	_stair_drag_start = INVALID_TILE
	_stair_drag_placed.clear()
	var parts := _parts()
	if parts != null:
		parts.clear_stair_preview()


func _handle_placement(tile: Vector2i, place_state: Dictionary) -> void:
	if not Input.is_action_pressed("interact_secondary"):
		return
	if not bool(place_state["can_place"]):
		return
	var item: ItemData = place_state["item"]
	var block := block_catalog.get_by_id(item.placeable_block_id)
	if block == null:
		return
	var parts := _parts()
	if parts != null and block.is_building_part():
		if not parts.try_place(block, tile, _place_orientation, _player):
			return
	else:
		var liquid := _liquid()
		if liquid != null and liquid.has_liquid(tile):
			if not liquid.displace_for_placement(tile):
				return
		if block_catalog != null:
			block_catalog.set_block_cell(_tile_map, tile, block)
		else:
			_tile_map.set_cell(tile, _terrain_source_id(), block.atlas_coords)
		_notify_structure_placed(tile)
	_notify_map_tile(tile)
	if _inventory != null:
		_inventory.consume_from_slot(_inventory.selected_hotbar_index, 1)
	var veg := _veg()
	if veg != null:
		veg.on_block_placed(tile)
	if _anim != null:
		_anim.play(&"block_place")
	_player.play_sfx(&"BlockPlace", 0.0, _audio_material(block))


func _terrain_source_id() -> int:
	if block_catalog != null:
		return block_catalog.terrain_source_id(_tile_map.tile_set if _tile_map != null else null)
	var tileset := _tile_map.tile_set if _tile_map != null else null
	if tileset == null or tileset.get_source_count() == 0:
		return 0
	return tileset.get_source_id(0)


func _tile_overlaps_player(tile: Vector2i) -> bool:
	var item := _inventory.get_selected_item() if _inventory != null else null
	if item != null and block_catalog != null:
		var placing := block_catalog.get_by_id(item.placeable_block_id)
		if placing != null and not placing.solid:
			return false
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


func _has_place_neighbor(tile: Vector2i, placing: BlockData) -> bool:
	var dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	if StairSystem.is_stair(placing):
		dirs = StairSystem.NEIGHBOR_DIRS
	for dir in dirs:
		var neighbor: Vector2i = tile + dir
		var neighbor_block := get_block_data(neighbor)
		if neighbor_block == null:
			continue
		if neighbor_block.solid or neighbor_block.structural_enabled or neighbor_block.occupies_background_layer():
			return true
		if StairSystem.is_stair(placing) and StairSystem.is_stair(neighbor_block):
			return true
	return false


func _has_solid_neighbor(tile: Vector2i) -> bool:
	return _has_place_neighbor(tile, null)


func _break_block(tile: Vector2i, block: BlockData) -> void:
	var buildings := get_tree().get_first_node_in_group("building_manager")
	if buildings != null and buildings.has_method("is_protected_cell") and bool(buildings.call("is_protected_cell", tile)):
		_reset_mining()
		return
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	var item: ItemData = _inventory.get_selected_item() if _inventory != null else null
	if trees != null and trees.handle_break(tile, _player, item):
		_note_block_mined()
		_reset_mining()
		_refresh_target_after_break()
		return
	var parts := _parts()
	if parts != null and block != null and block.is_building_part():
		var removed := parts.try_remove(tile, true)
		if removed != null:
			_notify_structure_removed(tile, true)
			_notify_map_tile(tile)
			_player.play_sfx(&"BlockBreak", 0.0, _audio_material(removed))
			_spawn_drop(tile, removed)
			_note_block_mined()
			_reset_mining()
			_refresh_target_after_break()
			return
	_tile_map.erase_cell(tile)
	_notify_structure_removed(tile, true)
	_notify_map_tile(tile)
	var veg := _veg()
	if veg != null:
		veg.on_block_removed(tile)
	_player.play_sfx(&"BlockBreak", 0.0, _audio_material(block))
	_spawn_drop(tile, block)
	_note_block_mined()
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
	_player.play_sfx(&"BlockPlace", 0.0, &"wood")


func _veg() -> VegetationSystem:
	if _vegetation == null or not is_instance_valid(_vegetation):
		_vegetation = get_tree().get_first_node_in_group("vegetation_system") as VegetationSystem
	return _vegetation


func _plant_at(tile: Vector2i) -> PlantData:
	var veg := _veg()
	if veg == null:
		return null
	var cell := _resolve_plant_cell(tile)
	if cell == INVALID_TILE:
		return null
	return veg.get_plant(cell)


func _resolve_plant_cell(tile: Vector2i) -> Vector2i:
	var veg := _veg()
	if veg == null or tile == INVALID_TILE:
		return INVALID_TILE
	if veg.has_plant(tile):
		return tile
	var above := tile + Vector2i.UP
	if veg.has_plant(above):
		return above
	return INVALID_TILE


func _holding_plant() -> bool:
	var item := _inventory.get_selected_item() if _inventory != null else null
	return item != null and item.is_plant()


func _plant_from_selected() -> PlantData:
	var veg := _veg()
	var item := _inventory.get_selected_item() if _inventory != null else null
	if veg == null or veg.catalog == null or item == null:
		return null
	var plant := veg.catalog.get_by_item_id(item.id)
	if plant == null and item.plant_id != &"":
		plant = veg.catalog.get_by_id(item.plant_id)
	return plant


func _plant_item_cell(tile: Vector2i) -> Vector2i:
	if get_block_data(tile) != null:
		return tile + Vector2i.UP
	return tile


func _can_plant_item(tile: Vector2i, in_range: bool) -> bool:
	if not in_range or not _holding_plant():
		return false
	var veg := _veg()
	var plant := _plant_from_selected()
	if veg == null or plant == null:
		return false
	var cell := _plant_item_cell(tile)
	if _tile_overlaps_player(cell):
		return false
	return veg.can_place(cell, plant)


func _handle_plant_place(tile: Vector2i, in_range: bool) -> void:
	if not Input.is_action_just_pressed("interact_secondary"):
		return
	if not _can_plant_item(tile, in_range):
		return
	var veg := _veg()
	var plant := _plant_from_selected()
	if veg == null or plant == null:
		return
	if not veg.try_plant(_plant_item_cell(tile), plant):
		return
	if _inventory != null:
		_inventory.consume_from_slot(_inventory.selected_hotbar_index, 1)
	if _anim != null:
		_anim.play(&"block_place")
	_player.play_sfx(&"BlockPlace", 0.0, &"grass")


func _handle_plant_harvest(delta: float, tile: Vector2i, in_range: bool) -> bool:
	var veg := _veg()
	if veg == null or tile == INVALID_TILE or not veg.has_plant(tile) or not in_range:
		_plant_progress = 0.0
		_plant_tile = INVALID_TILE
		return false
	if not _world_use_held:
		_plant_progress = 0.0
		return false
	if tile != _plant_tile:
		_plant_tile = tile
		_plant_progress = 0.0
	_plant_progress += delta
	if Input.is_action_just_pressed("use_item") or _plant_progress >= veg.harvest_time(tile):
		veg.harvest(tile, _player)
		_plant_progress = 0.0
		_reset_mining()
	return true


func _holding_blueprint() -> bool:
	var item := _inventory.get_selected_item() if _inventory != null else null
	return item != null and item.is_building_blueprint()


func _handle_building_blueprint(tile: Vector2i, _in_range: bool) -> void:
	var mgr := get_tree().get_first_node_in_group("building_manager")
	if mgr == null:
		return
	mgr.call("update_hotbar_preview", _inventory, tile, true)
	if not _holding_blueprint():
		return
	if Input.is_action_just_pressed("interact_secondary"):
		mgr.call("try_place_from_hotbar", _inventory, tile, true)


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
	if _player != null and _player.stats != null:
		amount = maxi(1, int(round(float(amount) * _player.stats.harvest_amount())))
	var drop := item_drop_scene.instantiate() as ItemDrop
	var parent := _drops_parent if _drops_parent != null else _tile_map.get_parent()
	parent.add_child(drop)
	drop.global_position = _tile_map.to_global(_tile_map.map_to_local(tile))
	drop.setup(block.drop_item_id, amount, item.icon)


func _note_block_mined() -> void:
	if _player != null and _player.stats != null:
		_player.stats.note_block_mined()


func _refresh_target_after_break() -> void:
	var hover := _get_hovered_tile()
	current_target_cell = _resolve_target_tile(hover)
	var block := get_block_data(current_target_cell)
	var in_range := _is_in_range(current_target_cell)
	var plant_cell := _resolve_plant_cell(hover)
	if plant_cell == INVALID_TILE:
		plant_cell = _resolve_plant_cell(current_target_cell)
	_update_highlight(current_target_cell, block, in_range, _get_place_state(hover, _is_in_range(hover)), plant_cell)


func _reset_mining() -> void:
	current_mining_tile = Vector2i(9999, 9999)
	mining_progress = 0.0
	_mine_sound_cooldown = 0.0
	_update_progress_bar(0.0)


func _update_progress_bar(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var width := float(tile_size) * clamped
	if _progress_poly != null:
		_progress_poly.visible = clamped > 0.0
		if clamped > 0.0:
			var y0 := float(tile_size) - 3.0
			_progress_poly.polygon = PackedVector2Array([
				Vector2(0.0, y0),
				Vector2(width, y0),
				Vector2(width, float(tile_size)),
				Vector2(0.0, float(tile_size)),
			])
			_progress_poly.color = Color(1.0, 0.75, 0.2, 0.95)
		return
	if _progress_fill == null:
		return
	_progress_fill.visible = clamped > 0.0
	_progress_fill.size = Vector2(width, 3.0)


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
	var mgr := _structural()
	if mgr != null and bool(mgr.get("debug_enabled")):
		var info := str(mgr.call("debug_info", tile))
		if not info.is_empty():
			lines.append(info)
	_debug_label.text = "\n".join(lines)


func _placement_preview_color(place_state: Dictionary, tile: Vector2i) -> Color:
	if not bool(place_state["can_place"]):
		return Color(0.9, 0.25, 0.2, 0.45)
	var item: ItemData = place_state["item"]
	var block := block_catalog.get_by_id(item.placeable_block_id) if item != null and block_catalog != null else null
	var mgr := _structural()
	if mgr == null or block == null or not block.structural_enabled:
		return Color(0.35, 0.9, 0.4, 0.45)
	var grade := int(mgr.call("preview_grade", tile, block))
	match grade:
		1:
			return Color(0.25, 0.9, 0.35, 0.5)
		2:
			return Color(0.95, 0.85, 0.2, 0.5)
		3:
			return Color(0.95, 0.2, 0.15, 0.5)
		_:
			return Color(0.35, 0.9, 0.4, 0.45)


func _structural() -> Node:
	return get_tree().get_first_node_in_group(&"structural_manager")


func _parts() -> BuildingPartSystem:
	if _building_parts != null:
		return _building_parts
	_building_parts = get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	return _building_parts


func _notify_structure_placed(tile: Vector2i) -> void:
	var mgr := _structural()
	if mgr != null:
		mgr.call("notify_block_placed", tile)
	_notify_liquid_changed(tile)


func _notify_structure_removed(tile: Vector2i, mined: bool) -> void:
	var mgr := _structural()
	if mgr != null:
		mgr.call("notify_block_removed", tile, mined)
	_notify_liquid_changed(tile)


func _liquid() -> LiquidSystem:
	return get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem


func _notify_liquid_changed(tile: Vector2i) -> void:
	var liquid := _liquid()
	if liquid != null:
		liquid.on_block_changed(tile)


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
		"ALT Auto-Tool: %s" % ("ON" if _is_auto_tool_held() else "OFF"),
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


func _audio_material(block: BlockData) -> StringName:
	if block != null:
		return block.get_audio_material()
	return &"stone"
