class_name LavaGeneration
extends RefCounted

## Direkte Lava-Befuellung in tiefen Höhlenbecken. Keine Live-Simulation zum Fuellen.


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
	stats["deep_pools"] = _generate_layer_pools(
		world, liquid, settings, rng,
		DepthLayer.Id.DEEP_CAVES, DepthLayer.Id.DEEP_CAVES,
		settings.deep_lava_chance, settings.max_deep_lava_pools,
		settings.lava_fill_ratio, 5, 4, true
	)
	rng = _make_rng(world, 9902)
	stats["danger_pools"] = _generate_layer_pools(
		world, liquid, settings, rng,
		DepthLayer.Id.DANGER, DepthLayer.Id.DANGER,
		settings.danger_lava_chance, settings.max_danger_lava_pools,
		0.52, 7, 6, true
	)
	rng = _make_rng(world, 9903)
	stats["fire_basins"] = _generate_fire_region(world, liquid, settings, rng)
	rng = _make_rng(world, 9904)
	stats["ravine_pools"] = _generate_ravine_lava(world, liquid, settings, rng)
	stats["contacts_resolved"] = liquid.resolve_contacts()
	stats["total_cells"] = liquid.get_lava_cell_count()
	return stats


static func _generate_layer_pools(
		world: WorldGenerator,
		liquid: LiquidSystem,
		settings: LiquidSettings,
		rng: RandomNumberGenerator,
		min_layer: int,
		max_layer: int,
		chance: float,
		max_pools: int,
		fill_ratio: float,
		max_half_width: int,
		max_height: int,
		skip_fire: bool
	) -> int:
	var count := 0
	var step := 4 if world.world_width < 1200 else (5 if world.world_width < 2000 else 7)
	var start_x := world.world_edge_width + 8 + rng.randi_range(0, step - 1)
	for x in range(start_x, world.world_width - world.world_edge_width - 8, step):
		if count >= max_pools:
			break
		if _skip_column(world, x):
			continue
		if rng.randf() > chance:
			continue
		var floors := LiquidBasin.floors_in_column(world, x, min_layer, max_layer, skip_fire)
		if floors.is_empty():
			continue
		var origin: Vector2i = floors[rng.randi() % floors.size()]
		if LiquidBasin.fill(
			world, liquid, origin, LiquidTypes.Type.LAVA,
			fill_ratio, settings.lava_pool_min_size, settings.min_air_above_lava,
			max_half_width, max_height
		) > 0:
			count += 1
	return count


static func _generate_fire_region(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	var step := 3 if world.world_width < 1200 else (4 if world.world_width < 2000 else 5)
	var start_x := world.world_edge_width + 6 + rng.randi_range(0, step - 1)
	for x in range(start_x, world.world_width - world.world_edge_width - 6, step):
		if _skip_column(world, x):
			continue
		if rng.randf() > settings.fire_region_lava_density:
			continue
		var min_y := world.fire_region_start_y(x)
		var max_y := world.world_height - world.bedrock_rows - 1
		var origin := LiquidBasin.lowest_floor_in_column(world, x, min_y, max_y)
		if origin.x < 0 or not world.is_fire_region(origin.x, origin.y):
			continue
		if LiquidBasin.fill(
			world, liquid, origin, LiquidTypes.Type.LAVA,
			settings.fire_lava_fill_ratio, settings.lava_pool_min_size,
			settings.min_air_above_lava, 8, 6
		) > 0:
			count += 1
	if count == 0:
		count += _force_fire_pockets(world, liquid, settings)
	return count


static func _force_fire_pockets(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings) -> int:
	var count := 0
	var step := maxi(int(world.world_width / 12.0), 24)
	for x in range(world.world_edge_width + 10, world.world_width - world.world_edge_width - 10, step):
		if _skip_column(world, x):
			continue
		var origin := LiquidBasin.lowest_floor_in_column(
			world, x, world.fire_region_start_y(x), world.world_height - world.bedrock_rows - 1
		)
		if origin.x < 0:
			continue
		if LiquidBasin.fill(
			world, liquid, origin, LiquidTypes.Type.LAVA,
			settings.fire_lava_fill_ratio, 2, 2, 6, 5
		) > 0:
			count += 1
		if count >= 6:
			break
	return count


static func _generate_ravine_lava(world: WorldGenerator, liquid: LiquidSystem, settings: LiquidSettings, rng: RandomNumberGenerator) -> int:
	var count := 0
	for x in range(20, world.world_width - 20, 9):
		if _skip_column(world, x):
			continue
		var probe_y := mini(world.get_surface_y(x) + 24, world.world_height - 12)
		if world.get_depth_layer(x, probe_y) < DepthLayer.Id.DEEP_CAVES:
			continue
		var chance := 0.22 if world.is_fire_region(x, world.world_height - world.bedrock_rows - 6) else 0.10
		if rng.randf() > chance:
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
		var origin := Vector2i(x, bottom_y)
		if not LiquidBasin.is_floor(world, origin.x, origin.y):
			origin = LiquidBasin.lowest_floor_in_column(world, x, bottom_y - 4, bottom_y)
		if origin.x < 0:
			continue
		var fill_ratio := 0.55 if world.is_fire_region(origin.x, origin.y) else 0.40
		if LiquidBasin.fill(
			world, liquid, origin, LiquidTypes.Type.LAVA,
			fill_ratio, settings.lava_pool_min_size, 2, 4, 5
		) > 0:
			count += 1
	return count


static func _skip_column(world: WorldGenerator, x: int) -> bool:
	if world.has_method("should_skip_ambient_water"):
		return bool(world.should_skip_ambient_water(x))
	return false


static func _make_rng(world: WorldGenerator, offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.get_seed() + offset * 7919
	return rng
