class_name WorldValidator
extends RefCounted

## Prueft die Mindestbedingungen einer generierten Welt und listet Reparaturen.


static func evaluate(world: WorldGenerator) -> Dictionary:
	var failures: PackedStringArray = PackedStringArray()
	if world == null:
		return {"ok": false, "failures": PackedStringArray(["world_missing"])}
	var layout: WorldLayout = world.layout
	if layout == null:
		failures.append("layout_missing")
		return {"ok": false, "failures": failures}

	if world.lantern_column_x() < layout.start_x0 or world.lantern_column_x() >= layout.start_x1:
		failures.append("lantern_not_in_start")
	if world.spawn_tile.x < layout.start_x0 or world.spawn_tile.x >= layout.start_x1:
		failures.append("spawn_not_in_start")
	if world.get_block_id(world.spawn_tile.x, world.spawn_tile.y) != WorldGenerator.AIR:
		failures.append("spawn_inside_block")
	if world.get_block_id(world.spawn_tile.x, world.get_surface_y(world.spawn_tile.x)) == WorldGenerator.AIR:
		failures.append("spawn_no_ground")

	if layout.ocean_width() < 48:
		failures.append("ocean_missing")
	else:
		var ocean_deeper := false
		var sample := layout.ocean_x0 + int(layout.ocean_width() / 2.0)
		if world.get_surface_y(sample) > layout.start_surface_y + 8:
			ocean_deeper = true
		if not ocean_deeper:
			failures.append("ocean_not_lower")

	if not layout.is_start_centered():
		failures.append("lantern_not_centered")
	if layout.start_x0 < layout.edge_width + 24 or layout.start_x1 > layout.width - layout.edge_width - 24:
		failures.append("start_too_close_to_edge")

	if layout.fortress_width() < 24:
		failures.append("fortress_missing")
	if layout.fortress_approach_width() < 24:
		failures.append("fortress_approach_missing")
	if not layout.opposite_of_start_is_fortress():
		failures.append("fortress_wrong_side")
	if world.fortress_tile_count() < 20:
		failures.append("fortress_tiles_missing")

	var biomes := world.present_surface_biomes()
	for required in world.generation_settings.required_surface_biomes if world.generation_settings != null else PackedStringArray(["grassland", "forest", "sand"]):
		if not biomes.has(StringName(required)):
			failures.append("biome_missing_%s" % required)

	if world.cave_tile_count() < 40:
		failures.append("caves_missing")
	if world.ore_tile_count() < 8:
		failures.append("ores_missing")

	if _has_objects_out_of_bounds(world):
		failures.append("objects_out_of_bounds")
	if _has_edge_holes(world):
		failures.append("edge_holes")
	if world.get_node_or_null("WorldBounds") == null:
		failures.append("bounds_missing")

	var warnings := _liquid_warnings(world)
	return {
		"ok": failures.is_empty(),
		"failures": failures,
		"warnings": warnings,
	}


static func _liquid_warnings(world: WorldGenerator) -> PackedStringArray:
	var warnings := PackedStringArray()
	var liquid := world.get_node_or_null("Terrain/LiquidSystem") as LiquidSystem
	if liquid == null:
		return warnings
	var lava_on_surface := 0
	var lava_in_fire := 0
	var lava_in_deep := 0
	var bedrock_hits := 0
	for cell in liquid.get_lava_cells():
		var layer := world.get_depth_layer(cell.x, cell.y)
		if layer <= DepthLayer.Id.SHALLOW_CAVES:
			lava_on_surface += 1
		elif layer == DepthLayer.Id.DEEP_CAVES:
			lava_in_deep += 1
		if world.is_fire_region(cell.x, cell.y):
			lava_in_fire += 1
		if cell.y >= world.world_height - world.bedrock_rows:
			bedrock_hits += 1
	if lava_on_surface > 0:
		warnings.append("lava_above_deep_caves:%d" % lava_on_surface)
	if bedrock_hits > 0:
		warnings.append("lava_on_world_bottom:%d" % bedrock_hits)
	if lava_in_fire == 0 and world.world_height >= 300:
		warnings.append("fire_region_no_lava")
	if lava_in_deep > lava_in_fire and lava_in_fire > 0:
		warnings.append("deep_lava_outnumbers_fire")
	return warnings


static func _has_objects_out_of_bounds(world: WorldGenerator) -> bool:
	if world.spawn_tile.x < 0 or world.spawn_tile.x >= world.world_width:
		return true
	if world.lantern_column_x() < 0 or world.lantern_column_x() >= world.world_width:
		return true
	if world.layout != null and (world.layout.fortress_center_x < 0 or world.layout.fortress_center_x >= world.world_width):
		return true
	return false


static func _has_edge_holes(world: WorldGenerator) -> bool:
	var edge := world.world_edge_width
	for x in [0, 1, world.world_width - 1, world.world_width - 2]:
		if x < 0 or x >= world.world_width:
			continue
		for y in range(world.world_height - world.bedrock_rows, world.world_height):
			if world.get_block_id(x, y) != WorldGenerator.BEDROCK:
				return true
		for y in range(maxi(world.base_surface_y - 8, 0), world.world_height - world.bedrock_rows):
			if x < edge or x >= world.world_width - edge:
				if world.get_block_id(x, y) == WorldGenerator.AIR:
					return true
	return false
