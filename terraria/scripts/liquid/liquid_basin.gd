class_name LiquidBasin
extends RefCounted

## Findet Höhlenböden und füllt Senken direkt. Keine Live-Simulation.


static func is_floor(world: WorldGenerator, x: int, y: int) -> bool:
	if world.get_block_id(x, y) != WorldGenerator.AIR:
		return false
	return world.get_block_id(x, y + 1) != WorldGenerator.AIR


static func fill(
		world: WorldGenerator,
		liquid: LiquidSystem,
		origin: Vector2i,
		liquid_type: int,
		fill_ratio: float,
		min_size: int,
		min_air_above: int,
		max_half_width: int,
		max_fill_height: int
	) -> int:
	if world == null or liquid == null:
		return 0
	if not is_floor(world, origin.x, origin.y):
		return 0
	var span := _span(world, origin, maxi(max_half_width, 2))
	var left: int = span.x
	var right: int = span.y
	if right - left + 1 < 2:
		return 0
	var cells: Array[Vector2i] = []
	for x in range(left, right + 1):
		var floor_y := _column_floor(world, x, origin.y)
		if floor_y < 0:
			continue
		var ceiling := floor_y
		for _i in 16:
			var above := ceiling - 1
			if world.get_block_id(x, above) != WorldGenerator.AIR:
				break
			ceiling = above
		var air_h := floor_y - ceiling + 1
		var keep := maxi(min_air_above, 1)
		var fill_h := clampi(int(round(float(air_h) * clampf(fill_ratio, 0.15, 0.85))), 1, maxi(max_fill_height, 1))
		fill_h = mini(fill_h, maxi(air_h - keep, 1))
		for dy in fill_h:
			var cell := Vector2i(x, floor_y - dy)
			if not _can_place(world, liquid, cell):
				continue
			cells.append(cell)
	if cells.size() < maxi(min_size, 2):
		return 0
	var placed := 0
	for cell in cells:
		liquid.set_cell(cell, liquid_type, LiquidTypes.FULL, false)
		placed += 1
	return placed


static func floors_in_column(world: WorldGenerator, x: int, min_layer: int, max_layer: int, skip_fire: bool) -> Array[Vector2i]:
	var floors: Array[Vector2i] = []
	var top := world.get_surface_y(x) + 4
	var bottom := world.world_height - world.bedrock_rows - 1
	var y := top
	while y <= bottom:
		if not is_floor(world, x, y):
			y += 1
			continue
		var layer := world.get_depth_layer(x, y)
		if layer >= min_layer and layer <= max_layer:
			if not skip_fire or not world.is_fire_region(x, y):
				floors.append(Vector2i(x, y))
		while y <= bottom and world.get_block_id(x, y) == WorldGenerator.AIR:
			y += 1
	return floors


static func lowest_floor_in_column(world: WorldGenerator, x: int, min_y: int, max_y: int) -> Vector2i:
	var y := mini(max_y, world.world_height - world.bedrock_rows - 1)
	while y >= maxi(min_y, 1):
		if is_floor(world, x, y):
			return Vector2i(x, y)
		y -= 1
	return Vector2i(-1, -1)


static func _span(world: WorldGenerator, origin: Vector2i, max_half_width: int) -> Vector2i:
	var left := origin.x
	var right := origin.x
	while origin.x - left < max_half_width:
		var nx := left - 1
		if not _can_expand(world, nx, origin.y):
			break
		left = nx
	while right - origin.x < max_half_width:
		var nx := right + 1
		if not _can_expand(world, nx, origin.y):
			break
		right = nx
	return Vector2i(left, right)


static func _can_expand(world: WorldGenerator, x: int, ref_y: int) -> bool:
	if x < world.world_edge_width + 1 or x >= world.world_width - world.world_edge_width - 1:
		return false
	if _is_drain(world, x, ref_y):
		return false
	return _column_floor(world, x, ref_y) >= 0


static func _column_floor(world: WorldGenerator, x: int, ref_y: int) -> int:
	var offsets: Array[int] = [0, 1, -1, 2, -2]
	for dy in offsets:
		var y: int = ref_y + dy
		if is_floor(world, x, y):
			return y
	return -1


static func _is_drain(world: WorldGenerator, x: int, ref_y: int) -> bool:
	return world.get_block_id(x, ref_y) == WorldGenerator.AIR \
		and world.get_block_id(x, ref_y + 1) == WorldGenerator.AIR \
		and world.get_block_id(x, ref_y + 2) == WorldGenerator.AIR


static func _can_place(world: WorldGenerator, liquid: LiquidSystem, cell: Vector2i) -> bool:
	if cell.y >= world.world_height - world.bedrock_rows:
		return false
	if world.get_block_id(cell.x, cell.y) != WorldGenerator.AIR:
		return false
	if world.get_block_id(cell.x, cell.y) == WorldGenerator.BEDROCK:
		return false
	if liquid.has_liquid(cell):
		return false
	return true
