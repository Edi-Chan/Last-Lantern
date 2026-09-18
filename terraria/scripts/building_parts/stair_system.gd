class_name StairSystem
extends RefCounted

## Gemeinsame Treppenmechanik für alle Materialien (Holz, Stein, später Ziegel…).
## Arbeitet ausschließlich mit Vector2i-Gridzellen, nicht mit Sprite-Positionen.

enum Orientation {
	UP_LEFT = 0,
	UP_RIGHT = 1,
	DOWN_RIGHT = 2,
	DOWN_LEFT = 3,
}

enum Visual {
	SINGLE = 0,
	INNER = 1,
	START = 2,
	END = 3,
	FLOOR_CONNECTION = 4,
	PLATFORM_CONNECTION = 5,
}

const TILE_SIZE := 16
const WOOD_ID := 42
const STONE_ID := 43
const WOOD_LEGACY_LEFT := Vector2i(1, 10)
const WOOD_LEGACY_RIGHT := Vector2i(2, 10)
const STONE_LEGACY_LEFT := Vector2i(3, 10)
const STONE_LEGACY_RIGHT := Vector2i(4, 10)
const WOOD_VARIANT_ROW := 12
const STONE_VARIANT_ROW := 13
const VISUAL_COUNT := 6
const UL_COLUMN_OFFSET := 6
const SLOPE_THICKNESS := 4.0

const CARDINALS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]
const DIAGONALS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]
const NEIGHBOR_DIRS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

const ORI_NAMES := ["UP_LEFT", "UP_RIGHT", "DOWN_RIGHT", "DOWN_LEFT"]
const VISUAL_NAMES := [
	"SINGLE", "INNER", "START", "END", "FLOOR_CONNECTION", "PLATFORM_CONNECTION",
]


static func is_stair(block: BlockData) -> bool:
	return block != null and block.building_part_type == BlockData.BuildingPartType.STAIRS


static func normalize_orientation(orientation: int) -> int:
	match orientation:
		Orientation.DOWN_RIGHT:
			return Orientation.UP_LEFT
		Orientation.DOWN_LEFT:
			return Orientation.UP_RIGHT
		Orientation.UP_RIGHT:
			return Orientation.UP_RIGHT
		_:
			return Orientation.UP_LEFT


static func is_up_right(orientation: int) -> bool:
	return normalize_orientation(orientation) == Orientation.UP_RIGHT


static func up_dir(orientation: int) -> Vector2i:
	return Vector2i(1, -1) if is_up_right(orientation) else Vector2i(-1, -1)


static func down_dir(orientation: int) -> Vector2i:
	return Vector2i(-1, 1) if is_up_right(orientation) else Vector2i(1, 1)


static func variant_row(block: BlockData) -> int:
	if block != null and block.building_material == BlockData.BuildingMaterial.STONE:
		return STONE_VARIANT_ROW
	return WOOD_VARIANT_ROW


static func atlas_for(block: BlockData, orientation: int, visual: int) -> Vector2i:
	var ori := normalize_orientation(orientation)
	var vis := clampi(visual, 0, VISUAL_COUNT - 1)
	var col := vis if ori == Orientation.UP_RIGHT else vis + UL_COLUMN_OFFSET
	return Vector2i(col, variant_row(block))


static func all_atlas_coords(block: BlockData) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if block == null:
		return coords
	if block.id == WOOD_ID or (block.building_material == BlockData.BuildingMaterial.WOOD and is_stair(block)):
		coords.append(WOOD_LEGACY_LEFT)
		coords.append(WOOD_LEGACY_RIGHT)
	if block.id == STONE_ID or (block.building_material == BlockData.BuildingMaterial.STONE and is_stair(block)):
		coords.append(STONE_LEGACY_LEFT)
		coords.append(STONE_LEGACY_RIGHT)
	var row := variant_row(block)
	for col in VISUAL_COUNT * 2:
		var cell := Vector2i(col, row)
		if not coords.has(cell):
			coords.append(cell)
	return coords


static func orientation_from_atlas(coords: Vector2i) -> int:
	if coords == WOOD_LEGACY_RIGHT or coords == STONE_LEGACY_RIGHT:
		return Orientation.UP_RIGHT
	if coords == WOOD_LEGACY_LEFT or coords == STONE_LEGACY_LEFT:
		return Orientation.UP_LEFT
	if coords.y == WOOD_VARIANT_ROW or coords.y == STONE_VARIANT_ROW:
		return Orientation.UP_RIGHT if coords.x < UL_COLUMN_OFFSET else Orientation.UP_LEFT
	return Orientation.UP_LEFT


static func collision_points(orientation: int) -> PackedVector2Array:
	var thick := SLOPE_THICKNESS
	if is_up_right(orientation):
		return PackedVector2Array([
			Vector2(-8.0, 8.0),
			Vector2(8.0, -8.0),
			Vector2(8.0, -8.0 + thick),
			Vector2(-8.0 + thick, 8.0),
		])
	return PackedVector2Array([
		Vector2(8.0, 8.0),
		Vector2(-8.0, -8.0),
		Vector2(-8.0, -8.0 + thick),
		Vector2(8.0 - thick, 8.0),
	])


static func hint_from_mouse(cell: Vector2i, mouse_world: Vector2, tilemap: TileMapLayer) -> int:
	if tilemap == null:
		return Orientation.UP_RIGHT
	var center := tilemap.to_global(tilemap.map_to_local(cell))
	return Orientation.UP_RIGHT if mouse_world.x >= center.x else Orientation.UP_LEFT


static func hint_from_drag(start: Vector2i, end: Vector2i) -> int:
	var delta := end - start
	var sx := 1 if delta.x >= 0 else -1
	var sy := -1 if delta.y <= 0 else 1
	if sx > 0 and sy < 0:
		return Orientation.UP_RIGHT
	if sx < 0 and sy < 0:
		return Orientation.UP_LEFT
	if sx > 0 and sy > 0:
		return Orientation.UP_LEFT
	return Orientation.UP_RIGHT


static func diagonal_line(start: Vector2i, end: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var delta := end - start
	if delta == Vector2i.ZERO:
		cells.append(start)
		return cells
	var sx := 1 if delta.x > 0 else (-1 if delta.x < 0 else 0)
	var sy := 1 if delta.y > 0 else (-1 if delta.y < 0 else 0)
	if sx == 0:
		sx = 1
	if sy == 0:
		sy = -1
	var steps := maxi(absi(delta.x), absi(delta.y))
	if delta.x != 0 and delta.y != 0:
		steps = mini(absi(delta.x), absi(delta.y))
	for i in steps + 1:
		cells.append(start + Vector2i(sx * i, sy * i))
	return cells


static func resolve_orientation(cell: Vector2i, get_block: Callable, hint: int) -> int:
	var ur := _stair_at(get_block, cell + Vector2i(-1, 1)) or _stair_at(get_block, cell + Vector2i(1, -1))
	var ul := _stair_at(get_block, cell + Vector2i(1, 1)) or _stair_at(get_block, cell + Vector2i(-1, -1))
	if ur and not ul:
		return Orientation.UP_RIGHT
	if ul and not ur:
		return Orientation.UP_LEFT
	if ur and ul:
		var ur_ori := _neighbor_prefers(get_block, cell, Orientation.UP_RIGHT)
		var ul_ori := _neighbor_prefers(get_block, cell, Orientation.UP_LEFT)
		if ur_ori and not ul_ori:
			return Orientation.UP_RIGHT
		if ul_ori and not ur_ori:
			return Orientation.UP_LEFT
	return normalize_orientation(hint)


static func resolve_visual(cell: Vector2i, orientation: int, get_block: Callable) -> int:
	var ori := normalize_orientation(orientation)
	var toward_up := cell + up_dir(ori)
	var toward_down := cell + down_dir(ori)
	var up_stair := _stair_at(get_block, toward_up)
	var down_stair := _stair_at(get_block, toward_down)
	var floor_down := _has_landing(get_block, cell, ori, true)
	var platform_up := _has_landing(get_block, cell, ori, false)
	if up_stair and down_stair:
		return Visual.INNER
	if not up_stair and not down_stair:
		if floor_down:
			return Visual.FLOOR_CONNECTION
		if platform_up:
			return Visual.PLATFORM_CONNECTION
		return Visual.SINGLE
	if down_stair and not up_stair:
		if platform_up:
			return Visual.PLATFORM_CONNECTION
		return Visual.END
	if floor_down:
		return Visual.FLOOR_CONNECTION
	return Visual.START


static func orientation_name(orientation: int) -> String:
	var ori := normalize_orientation(orientation)
	if ori >= 0 and ori < ORI_NAMES.size():
		return ORI_NAMES[ori]
	return "UP_LEFT"


static func visual_name(visual: int) -> String:
	if visual >= 0 and visual < VISUAL_NAMES.size():
		return VISUAL_NAMES[visual]
	return "SINGLE"


static func _stair_at(get_block: Callable, cell: Vector2i) -> bool:
	return is_stair(_call_block(get_block, cell))


static func _neighbor_prefers(get_block: Callable, cell: Vector2i, orientation: int) -> bool:
	var down := cell + down_dir(orientation)
	var up := cell + up_dir(orientation)
	return _stair_at(get_block, down) or _stair_at(get_block, up)


static func _has_landing(get_block: Callable, cell: Vector2i, orientation: int, at_bottom: bool) -> bool:
	var checks: Array[Vector2i] = []
	if at_bottom:
		checks.append(cell + down_dir(orientation))
		checks.append(cell + Vector2i(0, 1))
		checks.append(cell + Vector2i(-1, 0) if is_up_right(orientation) else Vector2i(1, 0))
	else:
		checks.append(cell + up_dir(orientation))
		checks.append(cell + Vector2i(0, -1))
		checks.append(cell + Vector2i(1, 0) if is_up_right(orientation) else Vector2i(-1, 0))
	for offset in checks:
		if _is_walkable_support(_call_block(get_block, offset)):
			return true
	return false


static func _is_walkable_support(block: BlockData) -> bool:
	if block == null or is_stair(block):
		return false
	if block.building_part_type == BlockData.BuildingPartType.PLATFORM:
		return true
	if block.building_part_type == BlockData.BuildingPartType.FLOOR:
		return true
	if block.building_part_type == BlockData.BuildingPartType.FOUNDATION:
		return true
	return block.solid and not block.occupies_background_layer()


static func _call_block(get_block: Callable, cell: Vector2i) -> BlockData:
	var result: Variant = get_block.call(cell)
	return result as BlockData
