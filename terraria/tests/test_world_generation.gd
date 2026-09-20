@tool
extends McpTestSuite


func suite_name() -> String:
	return "world_generation"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_size_profiles_are_finite_and_ordered() -> void:
	var settings := WorldGenerationSettings.new()
	var small: Dictionary = settings.size_profile(WorldSize.Id.SMALL)
	var medium: Dictionary = settings.size_profile(WorldSize.Id.MEDIUM)
	var large: Dictionary = settings.size_profile(WorldSize.Id.LARGE)
	assert_eq(WorldSize.display_name(WorldSize.Id.SMALL), "Klein")
	assert_eq(WorldSize.display_name(WorldSize.Id.MEDIUM), "Mittel")
	assert_eq(WorldSize.display_name(WorldSize.Id.LARGE), "Groß")
	assert_true(int(small["width"]) < int(medium["width"]))
	assert_true(int(medium["width"]) < int(large["width"]))
	assert_true(int(small["height"]) < int(medium["height"]))
	assert_true(int(medium["height"]) < int(large["height"]))
	assert_eq(int(medium["width"]), 1600)
	assert_eq(int(medium["height"]), 480)
	assert_eq(int(small["width"]), 960)
	assert_eq(int(large["width"]), 2560)
	assert_true(int(medium["ocean_width"]) >= 200)
	assert_true(int(medium["ocean_depth"]) >= 40)
	assert_true(int(medium["fortress_approach_width"]) >= 96)


func test_same_seed_and_size_same_layout() -> void:
	var settings := WorldGenerationSettings.new()
	var a := WorldLayout.build(settings, WorldSize.Id.MEDIUM, 424242)
	var b := WorldLayout.build(settings, WorldSize.Id.MEDIUM, 424242)
	assert_eq(a.start_on_left, b.start_on_left)
	assert_eq(a.lantern_x, b.lantern_x)
	assert_eq(a.spawn_x, b.spawn_x)
	assert_eq(a.fortress_center_x, b.fortress_center_x)
	assert_eq(a.ocean_x0, b.ocean_x0)
	assert_eq(a.playable_width(), b.playable_width())
	var other_size := WorldLayout.build(settings, WorldSize.Id.SMALL, 424242)
	assert_true(a.width != other_size.width)
	assert_true(a.height != other_size.height)


func test_layout_places_ocean_start_and_fortress() -> void:
	var settings := WorldGenerationSettings.new()
	var found_left := false
	var found_right := false
	for seed in range(1, 41):
		var layout := WorldLayout.build(settings, WorldSize.Id.MEDIUM, seed)
		assert_true(layout.ocean_width() >= 160)
		assert_true(layout.start_width() >= 12)
		assert_true(layout.fortress_width() >= 48)
		assert_true(layout.fortress_approach_width() >= 48)
		assert_true(layout.fortress_keep_width() >= 32)
		assert_true(layout.playable_width() >= 160)
		assert_true(layout.is_start_centered())
		assert_true(layout.start_x0 > layout.edge_width + 24)
		assert_true(layout.start_x1 < layout.width - layout.edge_width - 24)
		assert_true(layout.is_start_column(layout.lantern_x))
		assert_true(layout.is_start_column(layout.spawn_x))
		assert_true(layout.is_fortress_keep_column(layout.fortress_center_x))
		assert_true(layout.is_fortress_column(layout.fortress_center_x))
		assert_true(layout.opposite_of_start_is_fortress())
		assert_false(layout.is_ocean_column(layout.lantern_x))
		assert_false(layout.is_fortress_column(layout.lantern_x))
		if layout.start_on_left:
			found_left = true
			assert_true(layout.ocean_x1 <= layout.start_x0)
			assert_eq(layout.fortress_approach_x1, layout.fortress_keep_x0)
			assert_true(layout.fortress_x0 >= layout.start_x1)
		else:
			found_right = true
			assert_true(layout.ocean_x0 >= layout.start_x1)
			assert_eq(layout.fortress_approach_x0, layout.fortress_keep_x1)
			assert_true(layout.fortress_x1 <= layout.start_x0)
	assert_true(found_left)
	assert_true(found_right)


func test_depth_layers_are_ordered() -> void:
	var settings := WorldGenerationSettings.new()
	assert_eq(settings.layer_for_ratio(0.01), DepthLayer.Id.SURFACE)
	assert_eq(settings.layer_for_ratio(0.12), DepthLayer.Id.UNDERGROUND)
	assert_eq(settings.layer_for_ratio(0.35), DepthLayer.Id.SHALLOW_CAVES)
	assert_eq(settings.layer_for_ratio(0.60), DepthLayer.Id.DEEP_CAVES)
	assert_eq(settings.layer_for_ratio(0.90), DepthLayer.Id.DANGER)
	assert_eq(DepthLayer.display_name(DepthLayer.Id.DANGER), "Danger Layer")
	assert_true(settings.cave_fill_for_layer(DepthLayer.Id.DEEP_CAVES) > settings.cave_fill_for_layer(DepthLayer.Id.UNDERGROUND))


func test_generator_has_no_huts_or_infinite_world() -> void:
	var src := _read("res://scripts/world/world_generator.gd")
	assert_false(src.contains("func generate_huts"))
	assert_false(src.contains("hut_count_target"))
	assert_false(src.contains("_place_combat_dummy"))
	assert_false(src.contains("spawn_test_house"))
	var structural := _read("res://scripts/world/structural_manager.gd")
	assert_false(structural.contains("spawn_test_house"))
	assert_false(src.contains("spawn_test_pool_enabled"))
	assert_true(src.contains("WorldLayout.build"))
	assert_true(src.contains("_carve_winding_tunnel"))
	assert_true(src.contains("_carve_cave_chambers"))
	assert_false(src.contains("while x != to_pos.x"))
	assert_true(src.contains("generate_ocean"))
	assert_true(src.contains("WorldValidator.evaluate"))
	assert_true(src.contains("WorldBounds"))
	assert_true(FileAccess.file_exists("res://scripts/world/generation/world_generation_settings.gd"))
	assert_true(FileAccess.file_exists("res://resources/world/world_generation_settings.tres"))
	assert_true(FileAccess.file_exists("res://scripts/world/structures/enemy_fortress.gd"))
	assert_true(FileAccess.file_exists("res://scenes/world/structures/enemy_fortress.tscn"))


func test_water_generation_keeps_water_not_lava() -> void:
	var types := _read("res://scripts/liquid/liquid_types.gd")
	assert_true(types.contains("WATER = 1"))
	assert_false(types.contains("LAVA = 2,"))
	var water := _read("res://scripts/liquid/water_generation.gd")
	assert_true(water.contains("func generate_ocean"))
	assert_true(water.contains("func generate_danger_water"))
	assert_true(water.contains("LiquidTypes.Type.WATER"))
	assert_false(water.contains("Type.LAVA"))
