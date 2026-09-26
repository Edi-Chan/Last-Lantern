@tool
extends McpTestSuite


func suite_name() -> String:
	return "liquid_system"


func test_liquid_files_exist() -> void:
	assert_true(FileAccess.file_exists("res://scripts/liquid/liquid_system.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/water_generation.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/water_interaction.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/lava.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/lava_generation.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/lava_interaction.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/liquid_basin.gd"))
	assert_true(FileAccess.file_exists("res://scenes/world/lava.tscn"))
	assert_true(FileAccess.file_exists("res://resources/systems/liquid_settings.tres"))


func test_world_integrates_liquid() -> void:
	var scene := _read("res://scenes/world/world.tscn")
	assert_true(scene.contains("LiquidSystem"))
	assert_true(scene.contains("liquid_system.gd"))
	assert_true(scene.contains("lava.tscn"))
	var world_src := _read("res://scripts/world/world_generator.gd")
	assert_true(world_src.contains("_generate_water"))
	assert_true(world_src.contains("_generate_lava"))
	assert_true(world_src.contains("_finalize_liquids"))


func test_player_has_water_interaction() -> void:
	var scene := _read("res://scenes/player/player.tscn")
	assert_true(scene.contains("WaterInteraction"))
	assert_true(scene.contains("LavaInteraction"))
	var src := _read("res://scripts/player/player.gd")
	assert_true(src.contains("_water_movement_multipliers"))
	assert_true(src.contains("_lava"))


func test_liquid_perf_budget_exists() -> void:
	var settings := _read("res://scripts/liquid/liquid_settings.gd")
	assert_true(settings.contains("max_simulation_ticks_per_frame"))
	assert_true(settings.contains("simulation_budget_ms"))
	var src := _read("res://scripts/liquid/liquid_system.gd")
	assert_true(src.contains("has_active_in_rect"))
	var renderer := _read("res://scripts/liquid/liquid_renderer.gd")
	assert_true(renderer.contains("_view_rect_cells"))


func test_save_manager_persists_liquid() -> void:
	var src := _read("res://scripts/save/save_manager.gd")
	assert_true(src.contains('"liquid"'))
	assert_true(src.contains("liquid_system"))


func test_drowning_damage_type_exists() -> void:
	var src := _read("res://scripts/combat/damage_types.gd")
	assert_true(src.contains("DROWNING"))


func test_renderer_separates_surface_and_body() -> void:
	var renderer_src := _read("res://scripts/liquid/liquid_renderer.gd")
	assert_true(renderer_src.contains("is_surface_cell"))
	assert_true(renderer_src.contains("is_falling_cell"))
	assert_true(renderer_src.contains("_body_color"))
	assert_true(renderer_src.contains("quantized_fill_height"))
	assert_false(renderer_src.contains("for y in _system.world_height"))


func test_falling_water_conserves_mass() -> void:
	var liquid := _make_liquid(8, 12)
	for y in range(0, 12):
		liquid.debug_set_solid(Vector2i(2, y), true)
		liquid.debug_set_solid(Vector2i(4, y), true)
	liquid.set_cell(Vector2i(3, 1), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	assert_eq(liquid.get_total_water_amount(), LiquidTypes.FULL)
	liquid.stabilize(80)
	assert_eq(liquid.get_total_water_amount(), LiquidTypes.FULL)
	assert_eq(liquid.get_amount(Vector2i(3, 1)), 0)
	assert_eq(liquid.get_amount(Vector2i(3, 11)), LiquidTypes.FULL)
	assert_eq(liquid.get_active_cell_count(), 0)


func test_lake_drain_lowers_surface_and_conserves_mass() -> void:
	var liquid := _make_liquid(16, 16)
	_build_basin(liquid, 2, 12, 4, 9, 10)
	var start := liquid.get_total_water_amount()
	assert_gt(start, 0)
	assert_eq(liquid.get_amount(Vector2i(4, 4)), LiquidTypes.FULL)
	liquid.debug_set_solid(Vector2i(7, 10), false)
	liquid.on_block_removed(Vector2i(7, 10))
	liquid.stabilize(800)
	assert_eq(liquid.get_total_water_amount(), start)
	assert_gt(liquid.get_amount(Vector2i(7, 15)), 0, "Unten muss Wasser ankommen.")
	assert_true(
		liquid.get_amount(Vector2i(4, 4)) < LiquidTypes.FULL
		or liquid.get_amount(Vector2i(5, 4)) < LiquidTypes.FULL
		or liquid.get_amount(Vector2i(6, 4)) < LiquidTypes.FULL
		or liquid.get_amount(Vector2i(7, 4)) < LiquidTypes.FULL
		or not liquid.has_water(Vector2i(4, 4)),
		"Oberer Wasserspiegel muss sinken."
	)
	assert_eq(liquid.get_active_cell_count(), 0)


func test_horizontal_equalize_then_sleep() -> void:
	var liquid := _make_liquid(12, 8)
	for x in range(2, 10):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(10, 5), true)
	liquid.set_cell(Vector2i(5, 5), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	var start := liquid.get_total_water_amount()
	liquid.stabilize(250)
	assert_eq(liquid.get_total_water_amount(), start)
	assert_gt(liquid.get_amount(Vector2i(4, 5)), 0)
	assert_gt(liquid.get_amount(Vector2i(6, 5)), 0)
	var left := liquid.get_amount(Vector2i(4, 5))
	var mid := liquid.get_amount(Vector2i(5, 5))
	assert_true(absi(left - mid) <= liquid.settings.equalize_min_diff + liquid.settings.horizontal_flow_rate)
	assert_eq(liquid.get_active_cell_count(), 0)


func test_transfer_does_not_duplicate_water() -> void:
	var liquid := _make_liquid(6, 6)
	liquid.debug_set_solid(Vector2i(2, 4), true)
	liquid.debug_set_solid(Vector2i(3, 4), true)
	liquid.set_cell(Vector2i(2, 3), LiquidTypes.Type.WATER, 200)
	liquid.set_cell(Vector2i(3, 3), LiquidTypes.Type.WATER, 10)
	var start := liquid.get_total_water_amount()
	assert_eq(start, 210)
	liquid.stabilize(40)
	assert_eq(liquid.get_total_water_amount(), 210)


func test_save_keeps_drained_water_level() -> void:
	var liquid := _make_liquid(12, 12)
	_build_basin(liquid, 2, 8, 3, 6, 7)
	liquid.capture_baseline()
	var original := liquid.get_total_water_amount()
	liquid.debug_set_solid(Vector2i(5, 7), false)
	liquid.on_block_removed(Vector2i(5, 7))
	liquid.stabilize(600)
	var drained := liquid.get_total_water_amount()
	assert_eq(drained, original)
	var top_after := liquid.get_amount(Vector2i(3, 3))
	var below_after := liquid.get_amount(Vector2i(5, 11))
	assert_gt(below_after, 0)
	var payload := liquid.to_save_dict()
	liquid.from_save_dict(payload)
	assert_eq(liquid.get_total_water_amount(), drained)
	assert_eq(liquid.get_amount(Vector2i(3, 3)), top_after)
	assert_eq(liquid.get_amount(Vector2i(5, 11)), below_after)


func test_surface_only_on_top_layer() -> void:
	var liquid := _make_liquid(8, 8)
	for x in range(2, 6):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 4), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(6, 4), true)
	liquid.debug_set_solid(Vector2i(6, 5), true)
	for x in range(2, 6):
		liquid.set_cell(Vector2i(x, 5), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
		liquid.set_cell(Vector2i(x, 4), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
	assert_true(liquid.is_surface_cell(Vector2i(3, 4)))
	assert_false(liquid.is_surface_cell(Vector2i(3, 5)))
	assert_false(liquid.is_falling_cell(Vector2i(3, 5)))


func test_quantized_fill_height_is_pixel_perfect() -> void:
	var liquid := _make_liquid(4, 4)
	assert_eq(liquid.quantized_fill_height(0), 0)
	assert_eq(liquid.quantized_fill_height(LiquidTypes.FULL), 16)
	assert_eq(liquid.quantized_fill_height(LiquidTypes.HALF), 8)
	assert_eq(liquid.quantized_fill_height(1), 1)


func test_lava_falls_slower_than_water() -> void:
	var water := _make_shaft()
	var lava := _make_shaft()
	water.set_cell(Vector2i(3, 1), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	lava.set_cell(Vector2i(3, 1), LiquidTypes.Type.LAVA, LiquidTypes.FULL)
	for _i in 4:
		water.stabilize(1)
		lava.stabilize(1)
	assert_true(water.get_amount(Vector2i(3, 1)) < lava.get_amount(Vector2i(3, 1)), "Lava muss oben laenger bleiben.")
	var lava_type := lava.get_type(Vector2i(3, 1))
	if lava.get_amount(Vector2i(3, 1)) <= 0:
		lava_type = lava.get_type(Vector2i(3, 2))
	assert_eq(lava_type, LiquidTypes.Type.LAVA)


func test_lava_save_restores_type() -> void:
	var liquid := _make_liquid(8, 8)
	for x in range(2, 6):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.set_cell(Vector2i(3, 5), LiquidTypes.Type.LAVA, LiquidTypes.FULL)
	var payload := liquid.to_save_dict()
	liquid.remove_liquid(Vector2i(3, 5))
	assert_eq(liquid.get_amount(Vector2i(3, 5)), 0)
	liquid.from_save_dict(payload)
	assert_eq(liquid.get_type(Vector2i(3, 5)), LiquidTypes.Type.LAVA)
	assert_eq(liquid.get_amount(Vector2i(3, 5)), LiquidTypes.FULL)
	assert_eq(liquid.get_lava_cell_count(), 1)
	assert_eq(liquid.get_water_cell_count(), 0)


func test_water_lava_reaction_creates_solid_and_stops() -> void:
	var liquid := _make_liquid(8, 8)
	for x in range(1, 7):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(6, 5), true)
	liquid.set_cell(Vector2i(2, 5), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	liquid.set_cell(Vector2i(3, 5), LiquidTypes.Type.LAVA, LiquidTypes.FULL)
	liquid.stabilize(20)
	assert_eq(liquid.get_amount(Vector2i(2, 5)), 0)
	assert_eq(liquid.get_amount(Vector2i(3, 5)), 0)
	assert_true(liquid.is_cell_solid(Vector2i(3, 5)))
	assert_eq(liquid.get_active_cell_count(), 0)


func test_lava_sleeps_after_settle() -> void:
	var liquid := _make_liquid(10, 8)
	for x in range(2, 8):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(8, 5), true)
	liquid.set_cell(Vector2i(4, 5), LiquidTypes.Type.LAVA, LiquidTypes.FULL)
	liquid.stabilize(400)
	assert_gt(liquid.get_lava_cell_count(), 0)
	assert_eq(liquid.get_total_lava_amount(), LiquidTypes.FULL)
	assert_eq(liquid.get_active_cell_count(), 0)


func _make_shaft() -> LiquidSystem:
	var liquid := _make_liquid(8, 12)
	for y in range(0, 12):
		liquid.debug_set_solid(Vector2i(2, y), true)
		liquid.debug_set_solid(Vector2i(4, y), true)
	return liquid


func _make_liquid(width: int, height: int) -> LiquidSystem:
	var liquid := LiquidSystem.new()
	track(liquid)
	liquid.settings = LiquidSettings.new()
	liquid.settings.sleep_after_stable_ticks = 2
	liquid.settings.max_updates_per_tick = 2000
	liquid.settings.max_updates_per_tick_max = 2000
	liquid.settings.adaptive_budget = false
	liquid.initialize(width, height)
	return liquid


func _build_basin(liquid: LiquidSystem, left: int, right: int, top: int, water_bottom: int, floor_y: int) -> void:
	for x in range(left, right + 1):
		liquid.debug_set_solid(Vector2i(x, floor_y), true)
	for y in range(top, floor_y + 1):
		liquid.debug_set_solid(Vector2i(left, y), true)
		liquid.debug_set_solid(Vector2i(right, y), true)
	for y in range(top, water_bottom + 1):
		for x in range(left + 1, right):
			liquid.set_cell(Vector2i(x, y), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
	liquid.finalize_generation()


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
