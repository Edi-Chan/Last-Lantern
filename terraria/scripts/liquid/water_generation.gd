class_name WaterGeneration
extends RefCounted

## Prozedurale Wasserplatzierung nach Terrain, Höhlen und Senken.


static func generate(world: WorldGenerator, liquid: LiquidSystem) -> Dictionary:
	var stats := {
		"surface_ponds": 0,
		"cave_pools": 0,
		"ravine_pools": 0,
		"total_cells": 0,
	}
	if world == null or liquid == null or liquid.settings == null:
		return stats
	liquid.initialize(world.world_width, world.world_height)
	var settings := liquid.settings
	var rng := _make_rng(world, 8803)
	stats["surface_ponds"] = _generate_surface_ponds(world, liquid, settings, rng)
	rng = _make_rng(world, 8804)
	stats["cave_pools"] = _generate_cave_pools(world, liquid, settings, rng)
	rng = _make_rng(world, 8805)
	stats["ravine_pools"] = _generate_ravine_pools(world, liquid, settings, rng)
	stats["total_cells"] = _count_water(liquid)
	return stats


static func _generate_surface_ponds(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var attempts := settings.max_surface_ponds * 4
	var spawn_x := world.spawn_tile.x if world.spawn_tile != Vector2i.ZERO else world.world_width / 2
	for _i in attempts:
		if count >= settings.max_surface_ponds:
			break
		if rng.randf() > settings.surface_water_frequency:
			continue
		var x := rng.randi_range(8, world.world_width - 9)
		if abs(x - spawn_x) < settings.spawn_water_exclusion_radius:
			continue
		if _try_surface_pond(world, liquid, x, rng, settings):
			count += 1
	return count


static func _try_surface_pond(world: WorldGenerator, liquid: LiquidSystem, start_x: int, rng: RandomNumberGenerator, settings: LiquidSettings) -> bool:
	var surface_y := world.get_surface_y(start_x)
	var width := rng.randi_range(3, mini(12, settings.maximum_pool_size / 2))
	var left := start_x - width / 2
	var min_y := surface_y + 1
	var max_depth := rng.randi_range(1, 3)
	var lowest := min_y
	for dx in range(width):
		var x := left + dx
		var col_surface := world.get_surface_y(x)
		if col_surface < lowest:
			lowest = col_surface
		if col_surface > lowest + 2:
			return false
	var basin_depth := lowest - min_y + max_depth
	if basin_depth < 1:
		return false
	var filled := 0
	for dx in range(width):
		var x := left + dx
		for dy in range(basin_depth):
			var y := lowest - dy
			if not _can_place_water(world, liquid, Vector2i(x, y)):
				continue
			if not _has_side_support(world, Vector2i(x, y), width):
				continue
			liquid.set_cell(Vector2i(x, y), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
			filled += 1
	return filled >= settings.minimum_pool_size


static func _generate_cave_pools(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var spawn_x := world.spawn_tile.x if world.spawn_tile != Vector2i.ZERO else world.world_width / 2
	var attempts := settings.max_cave_pools * 6
	for _i in attempts:
		if count >= settings.max_cave_pools:
			break
		if rng.randf() > settings.cave_water_frequency:
			continue
		var x := rng.randi_range(10, world.world_width - 11)
		var y := rng.randi_range(int(world.base_surface_y) + 20, world.world_height - 12)
		if Vector2(x, y).distance_to(Vector2(spawn_x, world.get_surface_y(spawn_x) + 8)) < float(settings.spawn_water_exclusion_radius):
			continue
		if _try_cave_pool(world, liquid, Vector2i(x, y), rng, settings):
			count += 1
	return count


static func _try_cave_pool(world: WorldGenerator, liquid: LiquidSystem, origin: Vector2i, rng: RandomNumberGenerator, settings: LiquidSettings) -> bool:
	if world.get_block_id(origin.x, origin.y) != WorldGenerator.AIR:
		return false
	var width := rng.randi_range(3, mini(10, settings.maximum_pool_size / 3))
	var height := rng.randi_range(2, mini(6, settings.maximum_pool_size / 4))
	var floor_y := origin.y
	for dx in range(-width, width + 1):
		var x := origin.x + dx
		var floor_cell := Vector2i(x, floor_y + 1)
		if world.get_block_id(floor_cell.x, floor_cell.y) == WorldGenerator.AIR:
			return false
	var filled := 0
	for dy in range(height):
		for dx in range(-width, width + 1):
			var cell := Vector2i(origin.x + dx, floor_y - dy)
			if not _can_place_water(world, liquid, cell):
				continue
			if not _is_enclosed_basin(world, cell, width + 2, height + 2):
				continue
			liquid.set_cell(cell, LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
			filled += 1
	return filled >= settings.minimum_pool_size


static func _generate_ravine_pools(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var spawn_x := world.spawn_tile.x if world.spawn_tile != Vector2i.ZERO else world.world_width / 2
	for x in range(20, world.world_width - 20, 7):
		if abs(x - spawn_x) < settings.spawn_water_exclusion_radius:
			continue
		if rng.randf() > settings.ravine_water_frequency:
			continue
		var surface_y := world.get_surface_y(x)
		var depth := 0
		var bottom_y := surface_y
		for y in range(surface_y + 1, mini(surface_y + 40, world.world_height - 8)):
			if world.get_block_id(x, y) != WorldGenerator.AIR:
				break
			depth += 1
			bottom_y = y
		if depth < 8:
			continue
		var left_wall := world.get_block_id(x - 1, bottom_y) != WorldGenerator.AIR
		var right_wall := world.get_block_id(x + 1, bottom_y) != WorldGenerator.AIR
		if not left_wall or not right_wall:
			continue
		var filled := 0
		for dx in range(-2, 3):
			for dy in range(0, 3):
				var cell := Vector2i(x + dx, bottom_y - dy)
				if _can_place_water(world, liquid, cell):
					liquid.set_cell(cell, LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
					filled += 1
		if filled >= 3:
			count += 1
	return count


static func _can_place_water(world: WorldGenerator, liquid: LiquidSystem, cell: Vector2i) -> bool:
	if world.get_block_id(cell.x, cell.y) != WorldGenerator.AIR:
		return false
	return liquid.can_hold_liquid(cell)


static func _has_side_support(world: WorldGenerator, cell: Vector2i, width: int) -> bool:
	var left_solid := world.get_block_id(cell.x - 1, cell.y) != WorldGenerator.AIR
	var right_solid := world.get_block_id(cell.x + 1, cell.y) != WorldGenerator.AIR
	return left_solid or right_solid or width <= 4


static func _is_enclosed_basin(world: WorldGenerator, cell: Vector2i, radius_x: int, radius_y: int) -> bool:
	var solid_neighbors := 0
	for dx in range(-radius_x, radius_x + 1):
		for dy in range(-radius_y, radius_y + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) != radius_x and abs(dy) != radius_y:
				continue
			if world.get_block_id(cell.x + dx, cell.y + dy) != WorldGenerator.AIR:
				solid_neighbors += 1
	return solid_neighbors >= 3


static func _count_water(liquid: LiquidSystem) -> int:
	var total := 0
	for y in liquid.world_height:
		for x in liquid.world_width:
			if liquid.get_amount(Vector2i(x, y)) > 0:
				total += 1
	return total


static func _make_rng(world: WorldGenerator, offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.get_seed() + offset * 7919
	return rng
