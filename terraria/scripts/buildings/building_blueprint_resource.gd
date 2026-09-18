@tool
class_name BuildingBlueprintResource
extends Resource

## Daten eines Spezialgebaeudes. Layout wird aus Parametern erzeugt, nicht hart verdrahtet.

enum BuildingType {
	NONE,
	FORGE,
	MERCHANT,
	HEALER,
	LAB,
	WAREHOUSE,
	TAVERN,
	POWER,
}

enum ComponentRole {
	FOUNDATION,
	WALL,
	ROOF,
	SUPPORT,
	CORE,
	ENTRANCE,
	DECORATION,
}

enum BuildingState {
	INTACT,
	DAMAGED,
	CRITICAL,
	DESTROYED,
}

enum RemovalCause {
	NONE,
	PLAYER_REMOVED,
	ENEMY_DESTROYED,
	COLLAPSE_DESTROYED,
}

@export var building_id: StringName = &"forge"
@export var display_name: String = "Schmiede"
@export var building_type: BuildingType = BuildingType.FORGE
@export var layout_preset: StringName = &"forge"
@export var exterior_scene_path: String = "res://scenes/buildings/forge_exterior.tscn"
@export var interior_scene_path: String = "res://scenes/buildings/forge_interior.tscn"
@export var item_id: int = 61
@export var consume_blueprint: bool = true

@export_group("Ressourcen")
@export var required_item_ids: PackedInt32Array = PackedInt32Array([2, 9, 60])
@export var required_amounts: PackedInt32Array = PackedInt32Array([80, 120, 8])

@export_group("Layout")
@export var width: int = 32
@export var wall_height: int = 7
@export var foundation_overhang: int = 2
@export var door_height: int = 4
@export var support_count: int = 7
@export var stone_block_id: int = 32
@export var wood_block_id: int = 33
@export var beam_block_id: int = 29
@export var core_block_id: int = 62
@export var roof_block_id: int = 39
@export var stone_wall_id: int = 34
@export var wood_wall_id: int = 33
@export var stone_bg_id: int = 36
@export var wood_bg_id: int = 35
@export var horiz_beam_id: int = 41
@export var window_id: int = 47
@export var max_ground_variance: int = 0

@export_group("Platzierung")
@export var require_flat_ground: bool = true
@export var require_foundation_anchor: bool = true
@export var forbid_lantern_overlap: bool = true
@export var forbid_tree_overlap: bool = true
@export var forbid_player_overlap: bool = true
@export var visual_background_only: bool = true
@export var indestructible: bool = true


func get_costs() -> Array:
	var costs: Array = []
	var n := mini(required_item_ids.size(), required_amounts.size())
	for i in n:
		costs.append({
			"item_id": int(required_item_ids[i]),
			"amount": int(required_amounts[i]),
		})
	return costs


func get_exterior_scene() -> PackedScene:
	if exterior_scene_path.is_empty() or not ResourceLoader.exists(exterior_scene_path):
		return null
	return load(exterior_scene_path) as PackedScene


func get_interior_scene() -> PackedScene:
	if interior_scene_path.is_empty() or not ResourceLoader.exists(interior_scene_path):
		return null
	return load(interior_scene_path) as PackedScene


func get_type_id() -> StringName:
	match building_type:
		BuildingType.FORGE:
			return &"FORGE"
		BuildingType.MERCHANT:
			return &"MERCHANT"
		BuildingType.HEALER:
			return &"HEALER"
		BuildingType.LAB:
			return &"LAB"
		BuildingType.WAREHOUSE:
			return &"WAREHOUSE"
		BuildingType.TAVERN:
			return &"TAVERN"
		BuildingType.POWER:
			return &"POWER"
		_:
			return building_id


func total_width() -> int:
	return width + foundation_overhang * 2


func shop_width() -> int:
	return clampi(int(round(float(width) * 0.62)), 10, width - 8)


func footprint_size() -> Vector2i:
	return Vector2i(total_width(), wall_height + 8)


func entrance_local() -> Vector2i:
	return Vector2i(total_width() - foundation_overhang - 2, -1)


func door_local() -> Vector2i:
	return Vector2i(total_width() - foundation_overhang - 2, -1)


func return_local() -> Vector2i:
	return Vector2i(total_width() - foundation_overhang - 3, 0)


func chimney_local() -> Vector2i:
	return Vector2i(foundation_overhang + 3, -wall_height - 5)


func get_layout() -> Array:
	match layout_preset:
		&"forge":
			return _layout_forge()
		_:
			return _layout_simple_house()


func _layout_simple_house() -> Array:
	return _layout_forge()


func _layout_forge() -> Array:
	var cells: Array = []
	var used: Dictionary = {}
	var tw := total_width()
	var left := foundation_overhang
	var right := tw - 1 - foundation_overhang
	var split := left + shop_width()
	var shop_h := wall_height
	var eaves_y := -shop_h - 1
	var door_right := right - 1
	var door_left := right - 2
	for x in tw:
		_add_cell(cells, used, Vector2i(x, 0), stone_block_id, ComponentRole.FOUNDATION, true, false)
	_layout_shop(cells, used, left, split, shop_h, eaves_y)
	_layout_house(cells, used, split, right, shop_h, eaves_y, door_left, door_right)
	_layout_shop_gear(cells, used, left, split)
	return cells


func _layout_shop(cells: Array, used: Dictionary, left: int, split: int, shop_h: int, eaves_y: int) -> void:
	for y in range(-shop_h, 0):
		for x in range(left, split):
			_add_cell(cells, used, Vector2i(x, y), stone_bg_id, ComponentRole.DECORATION, false, true)
	var posts: Array[int] = [left, left + 4, split - 1]
	for px in posts:
		for y in range(-shop_h, 0):
			_add_cell(cells, used, Vector2i(px, y), beam_block_id, ComponentRole.SUPPORT, true, false)
	for x in range(left, split):
		_add_cell(cells, used, Vector2i(x, -shop_h), horiz_beam_id, ComponentRole.SUPPORT, true, false)
		_add_cell(cells, used, Vector2i(x, eaves_y), roof_block_id, ComponentRole.ROOF, false, false)
		_add_cell(cells, used, Vector2i(x, eaves_y - 1), roof_block_id, ComponentRole.ROOF, false, false)
	var chim_x := left + 3
	for i in 4:
		_add_cell(cells, used, Vector2i(chim_x, eaves_y - 2 - i), stone_wall_id, ComponentRole.DECORATION, false, true)
		_add_cell(cells, used, Vector2i(chim_x + 1, eaves_y - 2 - i), stone_wall_id, ComponentRole.DECORATION, false, true)


func _layout_house(cells: Array, used: Dictionary, split: int, right: int, shop_h: int, eaves_y: int, door_left: int, door_right: int) -> void:
	for y in range(-shop_h, 0):
		for x in range(split, right + 1):
			_add_cell(cells, used, Vector2i(x, y), stone_wall_id, ComponentRole.WALL, false, true)
	for y in range(-shop_h, 0):
		_add_cell(cells, used, Vector2i(split, y), beam_block_id, ComponentRole.SUPPORT, true, false)
	var mid := int((split + right) * 0.5)
	var half := maxi(right - split, 1)
	var peak_h := 5
	for x in range(split, right + 1):
		var dist := absi(x - mid)
		var rise := maxi(int(round(float(half - dist) * float(peak_h) / float(half))), 0)
		for gy in range(1, rise + 1):
			var gy_cell := eaves_y - gy
			if x == split or x == right or gy == rise:
				_add_cell(cells, used, Vector2i(x, gy_cell), wood_wall_id, ComponentRole.WALL, false, false)
			else:
				_add_cell(cells, used, Vector2i(x, gy_cell), wood_bg_id, ComponentRole.DECORATION, false, true)
		_add_cell(cells, used, Vector2i(x, eaves_y - rise - 1), roof_block_id, ComponentRole.ROOF, false, true)
		if rise > 0:
			_add_cell(cells, used, Vector2i(x, eaves_y - rise), roof_block_id, ComponentRole.ROOF, false, true)
	_add_cell(cells, used, Vector2i(mid, eaves_y - 2), window_id, ComponentRole.DECORATION, false, true)
	for y in range(-door_height, 0):
		_add_cell(cells, used, Vector2i(door_left, y), wood_bg_id, ComponentRole.ENTRANCE, false, true)
		_add_cell(cells, used, Vector2i(door_right, y), wood_bg_id, ComponentRole.ENTRANCE, false, true)


func _layout_shop_gear(cells: Array, used: Dictionary, left: int, split: int) -> void:
	_add_cell(cells, used, Vector2i(left + 2, -1), 50, ComponentRole.DECORATION, false, true)
	_add_entity(cells, used, Vector2i(left + 4, -1), 61, ComponentRole.DECORATION, Vector2i(2, 1), true)
	_add_entity(cells, used, Vector2i(left + 8, -1), core_block_id, ComponentRole.CORE, Vector2i(2, 2), false)
	_add_entity(cells, used, Vector2i(left + 12, -1), 60, ComponentRole.DECORATION, Vector2i(2, 1), true)
	_add_cell(cells, used, Vector2i(left + 3, -4), 51, ComponentRole.DECORATION, false, true)
	_add_cell(cells, used, Vector2i(split - 3, -1), 55, ComponentRole.DECORATION, false, true)
	_add_cell(cells, used, Vector2i(left + 7, -4), 63, ComponentRole.DECORATION, false, true)


func _add_entity(cells: Array, used: Dictionary, origin: Vector2i, block_id: int, role: int, footprint: Vector2i, decoration: bool) -> void:
	_add_cell(cells, used, origin, block_id, role, not decoration, decoration)
	for y in footprint.y:
		for x in footprint.x:
			var cell := origin + Vector2i(x, y - (footprint.y - 1))
			if cell == origin:
				continue
			if not used.has(cell):
				used[cell] = {"offset": cell, "block_id": -4, "role": role, "critical": false, "decoration": true}


func _add_cell(cells: Array, used: Dictionary, offset: Vector2i, block_id: int, role: int, critical: bool, decoration: bool) -> void:
	if used.has(offset):
		var existing: Dictionary = used[offset]
		if int(existing.get("role", 0)) == ComponentRole.CORE and role != ComponentRole.CORE:
			return
		if int(existing.get("block_id", -1)) >= 0 and block_id < 0 and role != ComponentRole.ENTRANCE:
			return
	var cell := {
		"offset": offset,
		"block_id": block_id,
		"role": role,
		"critical": critical,
		"decoration": decoration,
	}
	used[offset] = cell
	var replaced := -1
	for i in cells.size():
		var prev: Dictionary = cells[i]
		if prev["offset"] == offset:
			replaced = i
			break
	if replaced >= 0:
		cells[replaced] = cell
	else:
		cells.append(cell)
