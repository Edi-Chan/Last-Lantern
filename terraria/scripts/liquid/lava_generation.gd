class_name LavaGeneration
extends RefCounted

## Direkte Lava-Befuellung in tiefen Becken. Keine Live-Simulation zum Fuellen.


static func generate(world: WorldGenerator, liquid: LiquidSystem) -> Dictionary:
	var stats := {
		"deep_pools": 0,
		"danger_pools": 0,
		"fire_basins": 0,
		"ravine_pools": 0,
		"total_cells": 0,
		"contacts_resolved": 0,
	}
	if world == null or liquid == null or liquid.settings == null:
		return stats
	if liquid.world_width != world.world_width or liquid.world_height != world.world_height:
		liquid.initialize(world.world_width, world.world_height)
	var settings := liquid.settings
	var rng := _make_rng(world, 9901)
	stats["deep_pools"] = _generate_deep_pools(world, liquid, settings, rng)
	rng = _make_rng(world, 9902)
	stats["danger_pools"] = _generate_danger_pools(world, liquid, settings, rng)
	rng = _make_rng(world, 9903)
	stats["fire_basins"] = _generate_fire_region(world, liquid, settings, rng)
	rng = _make_rng(world, 9904)
	stats["ravine_pools"] = _generate_ravine_lava(world, liquid, settings, rng)
	stats["contacts_resolved"] = liquid.resolve_contacts()
	stats["total_cells"] = liquid.get_lava_cell_count()
	return stats


static func _generate_deep_pools(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var attempts := settings.max_deep_lava_pools * 8
	for _i in attempts:
		if count >= settings.max_deep_lava_pools:
			break
		if rng.randf() > settings.deep_lava_chance:
			continue
		var x := rng.randi_range(12, world.world_width - 13)
		if _skip_column(world, x):
			continue
		var y := rng.randi_range(int(world.base_surface_y) + 40, world.world_height - world.bedrock_rows - 14)
		if world.get_depth_layer(x, y) != DepthLayer.Id.DEEP_CAVES:
			continue
		if world.is_fire_region(x, y):
			continue
		if _try_pool(world, liquid, Vector2i(x, y), rng, settings, settings.lava_fill_ratio, 4, 8):
			count += 1
	return count


static func _generate_danger_pools(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var attempts := settings.max_danger_lava_pools * 7
	for _i in attempts:
		if count >= settings.max_danger_lava_pools:
			break
		if rng.randf() > settings.danger_lava_chance:
			continue
		var x := rng.randi_range(12, world.world_width - 13)
		if _skip_column(world, x):
			continue
		var y := rng.randi_range(world.world_height - 90, world.world_height - world.bedrock_rows - 8)
		if world.get_depth_layer(x, y) != DepthLayer.Id.DANGER:
			continue
		if world.is_fire_region(x, y):
			continue
		if _try_pool(world, liquid, Vector2i(x, y), rng, settings, 0.5, 5, 12):
			count += 1
	return count


static func _generate_fire_region(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var step := 5 if world.world_width < 1200 else (6 if world.world_width < 2000 else 8)
	for x in range(world.world_edge_width + 8, world.world_width - world.world_edge_width - 8, step):
		if _skip_column(world, x):
			continue
		if rng.randf() > settings.fire_region_lava_density:
			continue
		var y := _lowest_air_in_fire(world, x)
		if y < 0:
			continue
		if _fill_basin(world, liquid, Vector2i(x, y), rng, settings, settings.fire_lava_fill_ratio, 6, 16):
			count += 1
	return count


static func _generate_ravine_lava(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	for x in range(20, world.world_width - 20, 9):
		if _skip_column(world, x):
			continue
		var layer := world.get_depth_layer(x, mini(world.get_surface_y(x) + 24, world.world_height - 12))
		if layer < DepthLayer.Id.DEEP_CAVES:
			continue
		if rng.randf() > (0.18 if world.is_fire_region(x, world.world_height - world.bedrock_rows - 6) else 0.08):
			continue
		var surface_y := world.get_surface_y(x)
		var depth := 0
		var bottom_y := surface_y
		for y in range(surface_y + 1, mini(world.world_height - world.bedrock_rows - 1, surface_y + 80)):
			if world.get_block_id(x, y) != WorldGenerator.AIR:
				break
			depth += 1
			bottom_y = y
		if depth < 10:
			continue
		if world.get_depth_layer(x, bottom_y) < DepthLayer.Id.DEEP_CAVES:
			continue
		var left_wall := world.get_block_id(x - 1, bottom_y) != WorldGenerator.AIR
		var right_wall := world.get_block_id(x + 1, bottom_y) != WorldGenerator.AIR
		if not left_wall or not right_wall:
			continue
		var fill_h := 2 if world.get_depth_layer(x, bottom_y) == DepthLayer.Id.DEEP_CAVES else 4
		if world.is_fire_region(x, bottom_y):
			fill_h = 5
		var filled := 0
		for dx in range(-2, 3):
			for dy in range(0, fill_h):
				var cell := Vector2i(x + dx, bottom_y - dy)
				if _can_place_lava(world, liquid, cell):
					liquid.set_cell(cell, LiquidTypes.Type.LAVA, LiquidTypes.FULL, false)
					filled += 1
		if filled >= settings.lava_pool_min_size:
			count += 1
	return count


static func _try_pool(
		world: WorldGenerator,
		liquid: LiquidSystem,
		origin: Vector2i,
		rng: RandomNumberGenerator,
		settings: LiquidSettings,
		fill_ratio: float,
		min_w: int,
		max_w: int
	) -> bool:
	origin = _snap_to_floor(world, origin)
	if origin.y < 0:
		return false
	return _fill_basin(world, liquid, origin, rng, settings, fill_ratio, min_w, max_w)


static func _fill_basin(
		world: WorldGenerator,
		liquid: LiquidSystem,
		origin: Vector2i,
		rng: RandomNumberGenerator,
		settings: LiquidSettings,
		fill_ratio: float,
		min_w: int,
		max_w: int
	) -> bool:
	if world.get_block_id(origin.x, origin.y) != WorldGenerator.AIR:
		return false
	if world.get_block_id(origin.x, origin.y + 1) == WorldGenerator.AIR:
		return false
	var width := rng.randi_range(min_w, mini(max_w, settings.lava_pool_max_size / 2))
	var max_height := rng.randi_range(2, 6)
	var floor_y := origin.y
	for dx in range(-width, width + 1):
		var x := origin.x + dx
		if world.get_block_id(x, floor_y + 1) == WorldGenerator.AIR:
			return false
	var ceiling := floor_y
	for dy in range(1, 12):
		var y := floor_y - dy
		if world.get_block_id(origin.x, y) != WorldGenerator.AIR:
			break
		ceiling = y
	var air_h := floor_y - ceiling + 1
	var keep_air := maxi(settings.min_air_above_lava, 2)
	var fill_h := clampi(int(round(float(air_h) * fill_ratio)), 1, max_height)
	fill_h = mini(fill_h, maxi(air_h - keep_air, 1))
	if fill_h < 1:
		return false
	var filled := 0
	for dy in range(fill_h):
		for dx in range(-width, width + 1):
			var cell := Vector2i(origin.x + dx, floor_y - dy)
			if not _can_place_lava(world, liquid, cell):
				continue
			liquid.set_cell(cell, LiquidTypes.Type.LAVA, LiquidTypes.FULL, false)
			filled += 1
	return filled >= settings.lava_pool_min_size


static func _snap_to_floor(world: WorldGenerator, origin: Vector2i) -> Vector2i:
	if world.get_block_id(origin.x, origin.y) != WorldGenerator.AIR:
		return Vector2i(-1, -1)
	var y := origin.y
	while y < world.world_height - world.bedrock_rows - 1 and world.get_block_id(origin.x, y + 1) == WorldGenerator.AIR:
		y += 1
	if y >= world.world_height - world.bedrock_rows - 1:
		return Vector2i(-1, -1)
	return Vector2i(origin.x, y)


static func _lowest_air_in_fire(world: WorldGenerator, x: int) -> int:
	var bottom := world.world_height - world.bedrock_rows - 1
	for y in range(bottom, 8, -1):
		if not world.is_fire_region(x, y):
			break
		if world.get_block_id(x, y) == WorldGenerator.AIR and world.get_block_id(x, y + 1) != WorldGenerator.AIR:
			if world.get_block_id(x, y + 1) == WorldGenerator.BEDROCK:
				continue
			return y
	return -1


static func _can_place_lava(world: WorldGenerator, liquid: LiquidSystem, cell: Vector2i) -> bool:
	if cell.y >= world.world_height - world.bedrock_rows:
		return false
	if world.get_block_id(cell.x, cell.y) != WorldGenerator.AIR:
		return false
	if world.get_block_id(cell.x, cell.y) == WorldGenerator.BEDROCK:
		return false
	if liquid.has_liquid(cell):
		return false
	return liquid.can_hold_liquid(cell)


static func _skip_column(world: WorldGenerator, x: int) -> bool:
	if world.has_method("should_skip_ambient_water"):
		return bool(world.should_skip_ambient_water(x))
	return false


static func _make_rng(world: WorldGenerator, offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.get_seed() + offset * 7919
	return rng
