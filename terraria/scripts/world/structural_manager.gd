class_name StructuralManager
extends Node2D

## Event-basiertes Gebaeude-Statiksystem. Nur spieler-gesetzte Wood/Stone/Stuetzen.
## Natuerliches Terrain dient als Anker und kollabiert nie durch dieses System.

signal structure_changed(cell: Vector2i)
signal structure_became_unstable(cells: Array[Vector2i])
signal structure_collapsed(cells: Array[Vector2i])

enum PreviewGrade { NONE, STABLE, MARGINAL, UNSTABLE }

const GROUP := &"structural_manager"
const MAX_VISIT := 4096
const DIRTY_PADDING := 24
const COLLAPSE_BUDGET := 24
const WARN_MIN := 0.5
const WARN_MAX := 1.5
const DIRS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const DIAGONALS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

@export var block_catalog: BlockCatalog
@export var item_catalog: ItemCatalog
@export var item_drop_scene: PackedScene
@export var debug_enabled: bool = false

var _tilemap: TileMapLayer
var _placed: Dictionary = {}
var _support: Dictionary = {}
var _distance: Dictionary = {}
var _component: Dictionary = {}
var _anchored: Dictionary = {}
var _unstable_until: Dictionary = {}
var _dirty: Dictionary = {}
var _recalc_queued: bool = false
var _collapsing: Dictionary = {}
var _pool: Array = []
var _active_falling: int = 0
var _drops_parent: Node2D
var _debug: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	_tilemap = get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	_drops_parent = get_node_or_null("../ItemDrops") as Node2D
	_debug = (load("res://scripts/world/structural_debug_overlay.gd") as GDScript).new()
	_debug.set("manager", self)
	add_child(_debug)
	call_deferred("spawn_test_house")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		debug_enabled = not debug_enabled
		if _debug != null:
			_debug.queue_redraw()


func _process(delta: float) -> void:
	if _unstable_until.is_empty():
		return
	var now_collapse: Array[Vector2i] = []
	var keys := _unstable_until.keys()
	for key in keys:
		var cell: Vector2i = key
		var left := float(_unstable_until[cell]) - delta
		if left <= 0.0:
			now_collapse.append(cell)
		else:
			_unstable_until[cell] = left
	if _debug != null:
		_debug.queue_redraw()
	if not now_collapse.is_empty():
		_collapse_cells(now_collapse)


func is_player_placed(cell: Vector2i) -> bool:
	return _placed.has(cell)


func get_support(cell: Vector2i) -> float:
	return float(_support.get(cell, 0.0))


func get_distance(cell: Vector2i) -> int:
	return int(_distance.get(cell, -1))


func get_component_id(cell: Vector2i) -> int:
	return int(_component.get(cell, 0))


func is_stable(cell: Vector2i) -> bool:
	return is_player_placed(cell) and not _unstable_until.has(cell) and get_support(cell) >= 1.0


func is_anchor(cell: Vector2i) -> bool:
	return bool(_anchored.get(cell, false))


func notify_block_placed(cell: Vector2i) -> void:
	var block := _block_at(cell)
	if block == null or not block.structural_enabled:
		return
	_placed[cell] = true
	_mark_dirty(cell)
	structure_changed.emit(cell)


func notify_block_removed(cell: Vector2i, mined_drop: bool = false) -> void:
	var was_placed := _placed.has(cell)
	_placed.erase(cell)
	_support.erase(cell)
	_distance.erase(cell)
	_component.erase(cell)
	_anchored.erase(cell)
	_unstable_until.erase(cell)
	if mined_drop:
		_collapsing.erase(cell)
	if was_placed or _has_placed_neighbor(cell):
		_mark_dirty(cell)
		structure_changed.emit(cell)


func notify_structure_changed(cell: Vector2i) -> void:
	_mark_dirty(cell)
	structure_changed.emit(cell)


func preview_grade(cell: Vector2i, block: BlockData) -> PreviewGrade:
	if block == null or not block.structural_enabled:
		return PreviewGrade.NONE
	if _touches_natural(cell):
		return PreviewGrade.STABLE
	var best := 0.0
	for dir in _dirs_from(cell, block):
		var n: Vector2i = cell + dir
		if _is_natural_anchor(n):
			return PreviewGrade.STABLE
		if _placed.has(n):
			best = maxf(best, float(_support.get(n, 0.0)) - 1.0)
	return _grade_from_support(block, best)


func debug_info(cell: Vector2i) -> String:
	var block := _block_at(cell)
	if block == null or not _placed.has(cell):
		return ""
	return "Role: %s\nMaterial: %s\nWeight: %d\nSupport: %.1f\nDist: %d\nStable: %s\nId: %d" % [
		_role_name(block),
		block.display_name,
		block.structural_weight,
		get_support(cell),
		get_distance(cell),
		str(is_stable(cell)),
		get_component_id(cell),
	]


func to_save_dict() -> Dictionary:
	var cells: Array = []
	for key in _placed.keys():
		var cell: Vector2i = key
		cells.append([cell.x, cell.y])
	return {"placed": cells}


func from_save_dict(data: Dictionary) -> void:
	_placed.clear()
	for entry in data.get("placed", []):
		if entry is Array and entry.size() >= 2:
			_placed[Vector2i(int(entry[0]), int(entry[1]))] = true
	for key in _placed.keys():
		_mark_dirty(key)


func spawn_test_house() -> void:
	var world := get_parent() as WorldGenerator
	if world == null or _tilemap == null or block_catalog == null:
		return
	var stone := block_catalog.get_by_id(3)
	var wood := block_catalog.get_by_id(7)
	var beam := block_catalog.get_by_id(29)
	if stone == null or wood == null or beam == null:
		return
	var origin_x := world.spawn_tile.x + 12
	var ground := world.get_surface_y(origin_x)
	var width := 15
	var wall_h := 5
	var left := origin_x
	var right := origin_x + width - 1
	for x in range(left - 1, right + 2):
		var gy := world.get_surface_y(x)
		_place_structural(Vector2i(x, gy), stone)
		for y in range(gy - wall_h - 1, gy):
			var cell := Vector2i(x, y)
			if _tilemap.get_cell_source_id(cell) != -1:
				var existing := _block_at(cell)
				if existing != null and not existing.structural_enabled:
					_tilemap.erase_cell(cell)
	for y in range(ground - wall_h, ground):
		_place_structural(Vector2i(left, y), wood)
		_place_structural(Vector2i(right, y), wood)
	for y in range(ground - 3, ground):
		_tilemap.erase_cell(Vector2i(left, y))
		_placed.erase(Vector2i(left, y))
	var beam_xs: Array[int] = [left + 4, left + 7, left + 10]
	for bx in beam_xs:
		for y in range(ground - wall_h, ground):
			_place_structural(Vector2i(bx, y), beam)
	var roof_y := ground - wall_h - 1
	for x in range(left, right + 1):
		_place_structural(Vector2i(x, roof_y), wood)
	_recalculate_region(Rect2i(left - 2, roof_y - 2, width + 6, wall_h + 8), false)


func _place_structural(cell: Vector2i, block: BlockData) -> void:
	block_catalog.set_block_cell(_tilemap, cell, block)
	_placed[cell] = true


func _mark_dirty(cell: Vector2i) -> void:
	_dirty[cell] = true
	if _recalc_queued:
		return
	_recalc_queued = true
	call_deferred("_flush_dirty")


func _flush_dirty() -> void:
	_recalc_queued = false
	if _dirty.is_empty():
		return
	var rect := Rect2i()
	var first := true
	for key in _dirty.keys():
		var cell: Vector2i = key
		if first:
			rect = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			rect = rect.expand(cell)
	_dirty.clear()
	rect = rect.grow(DIRTY_PADDING)
	_recalculate_region(rect, false)


func _dirty_rect_for(cell: Vector2i) -> Rect2i:
	return Rect2i(cell, Vector2i.ONE).grow(DIRTY_PADDING)


func _recalculate_region(rect: Rect2i, preview: bool) -> void:
	var region: Array[Vector2i] = []
	for key in _placed.keys():
		var cell: Vector2i = key
		if rect.has_point(cell):
			region.append(cell)
			_support[cell] = 0.0
			_distance[cell] = -1
			_anchored[cell] = false
			_component[cell] = 0
	if region.is_empty():
		return
	var queue: Array[Vector2i] = []
	var horiz: Dictionary = {}
	var visited := 0
	var component_id := 1
	for cell in region:
		var block := _block_at(cell)
		if block == null:
			continue
		if _touches_natural(cell):
			_anchored[cell] = true
			_support[cell] = float(block.support_strength)
			_distance[cell] = 0
			_component[cell] = component_id
			horiz[cell] = 0
			queue.append(cell)
			component_id += 1
			visited += 1
	var head := 0
	while head < queue.size() and visited < MAX_VISIT:
		var cell := queue[head]
		head += 1
		var from_block := _block_at(cell)
		if from_block == null:
			continue
		var from_support := float(_support.get(cell, 0.0))
		var from_dist := int(_distance.get(cell, 0))
		var from_h := int(horiz.get(cell, 0))
		var from_comp := int(_component.get(cell, 0))
		var max_h := from_block.max_horizontal_support
		for dir in _dirs_from(cell, from_block):
			var next: Vector2i = cell + dir
			if not _placed.has(next):
				continue
			var next_block := _block_at(next)
			if next_block == null or not next_block.structural_enabled:
				continue
			var diagonal := dir.x != 0 and dir.y != 0
			var stair_chain := diagonal and (StairSystem.is_stair(from_block) or StairSystem.is_stair(next_block))
			var next_h := 0 if dir.x == 0 or stair_chain else from_h + 1
			if dir.x != 0 and not stair_chain and next_h > max_h:
				continue
			var next_val := float(next_block.support_strength)
			if dir.x == 0 or stair_chain:
				next_val = minf(from_support, float(next_block.support_strength))
			else:
				next_val = minf(from_support - 1.0, float(next_block.support_strength))
			var old := float(_support.get(next, 0.0))
			if next_val <= old:
				continue
			_support[next] = next_val
			_distance[next] = from_dist + 1
			_component[next] = from_comp
			horiz[next] = next_h
			queue.append(next)
			visited += 1
	if preview:
		return
	var newly_unstable: Array[Vector2i] = []
	for cell in region:
		var block := _block_at(cell)
		if block == null:
			continue
		var support := float(_support.get(cell, 0.0))
		var ok := support >= float(maxi(block.structural_weight, 1))
		if ok:
			_unstable_until.erase(cell)
		elif not _unstable_until.has(cell):
			_unstable_until[cell] = _rng.randf_range(WARN_MIN, WARN_MAX)
			newly_unstable.append(cell)
	if not newly_unstable.is_empty():
		structure_became_unstable.emit(newly_unstable)
	if _debug != null:
		_debug.queue_redraw()


func _grade_from_support(block: BlockData, support: float) -> PreviewGrade:
	if support >= float(maxi(block.structural_weight, 1)) and support >= float(block.support_strength) * 0.45:
		return PreviewGrade.STABLE
	if support >= float(maxi(block.structural_weight, 1)):
		return PreviewGrade.MARGINAL
	return PreviewGrade.UNSTABLE


func _touches_natural(cell: Vector2i) -> bool:
	var block := _block_at(cell)
	for dir in _dirs_from(cell, block):
		if _is_natural_anchor(cell + dir):
			return true
	return false


func _is_natural_anchor(cell: Vector2i) -> bool:
	if _placed.has(cell):
		return false
	var block := _block_at(cell)
	return block != null and block.solid


func _has_placed_neighbor(cell: Vector2i) -> bool:
	var block := _block_at(cell)
	for dir in _dirs_from(cell, block):
		if _placed.has(cell + dir):
			return true
	for dir in DIRS:
		if _placed.has(cell + dir):
			return true
	return false


func _dirs_from(cell: Vector2i, block: BlockData) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	dirs.append_array(DIRS)
	if StairSystem.is_stair(block):
		dirs.append_array(DIAGONALS)
		return dirs
	for diag in DIAGONALS:
		if StairSystem.is_stair(_block_at(cell + diag)):
			dirs.append(diag)
	return dirs


func _block_at(cell: Vector2i) -> BlockData:
	if _tilemap == null or block_catalog == null:
		return null
	if _tilemap.get_cell_source_id(cell) == -1:
		return null
	return block_catalog.get_cell_block(_tilemap, cell)


func _role_name(block: BlockData) -> String:
	if block == null:
		return "NONE"
	match block.structural_role:
		BlockData.StructuralRole.FOUNDATION:
			return "FOUNDATION"
		BlockData.StructuralRole.SUPPORT_BEAM:
			return "SUPPORT_BEAM"
		BlockData.StructuralRole.BEAM:
			return "BEAM"
		BlockData.StructuralRole.ROOF:
			return "ROOF"
		BlockData.StructuralRole.STRUCTURAL_BLOCK:
			return "STRUCTURAL_BLOCK"
		_:
			if block.is_support_beam:
				return "SUPPORT_BEAM"
			if block.is_foundation_material:
				return "FOUNDATION"
			if block.structural_enabled:
				return "STRUCTURAL_BLOCK"
			return "NONE"


func _collapse_cells(cells: Array[Vector2i]) -> void:
	var unique: Array[Vector2i] = []
	for cell in cells:
		if not _placed.has(cell):
			_unstable_until.erase(cell)
			continue
		unique.append(cell)
	if unique.is_empty():
		return
	structure_collapsed.emit(unique)
	for cell in unique:
		var block := _block_at(cell)
		_placed.erase(cell)
		_unstable_until.erase(cell)
		_support.erase(cell)
		if block == null:
			continue
		_tilemap.erase_cell(cell)
		_collapsing[cell] = true
		if _active_falling < COLLAPSE_BUDGET:
			_spawn_falling(cell, block)
		else:
			_spawn_collapse_drop(cell, block)
		_mark_dirty(cell)


func _spawn_falling(cell: Vector2i, block: BlockData) -> void:
	var piece := _acquire_piece()
	piece.call("begin", cell, block, _tilemap, self)


func _acquire_piece() -> Node2D:
	var piece: Node2D
	if _pool.is_empty():
		piece = (load("res://scripts/world/falling_structural_piece.gd") as GDScript).new()
		add_child(piece)
	else:
		piece = _pool.pop_back()
	_active_falling += 1
	return piece


func recycle_piece(piece: Node2D) -> void:
	_active_falling = maxi(0, _active_falling - 1)
	piece.visible = false
	_pool.append(piece)


func _spawn_collapse_drop(cell: Vector2i, block: BlockData) -> void:
	if block == null or block.drop_item_id < 0 or item_drop_scene == null or item_catalog == null:
		return
	if not _collapsing.has(cell):
		return
	_collapsing.erase(cell)
	var item := item_catalog.get_item(block.drop_item_id)
	if item == null:
		return
	var drop := item_drop_scene.instantiate() as ItemDrop
	var parent := _drops_parent if _drops_parent != null else self
	parent.add_child(drop)
	drop.global_position = _tilemap.to_global(_tilemap.map_to_local(cell))
	drop.setup(block.drop_item_id, 1, item.icon)


func consume_collapse_drop(cell: Vector2i, block: BlockData) -> void:
	_spawn_collapse_drop(cell, block)
