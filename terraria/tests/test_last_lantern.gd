@tool
extends McpTestSuite


func suite_name() -> String:
	return "last_lantern"


func test_timeline_cycle_windows() -> void:
	var src := _read("res://scripts/systems/last_lantern_settings.gd")
	assert_true(src.contains("func cycle_start_day"))
	assert_true(src.contains("func cycle_fog_day"))
	assert_true(src.contains("func day_phase_at"))
	var interval := 7
	var start_1 := int((1 - 1) / interval) * interval + 1
	var start_8 := int((8 - 1) / interval) * interval + 1
	var start_27 := int((27 - 1) / interval) * interval + 1
	assert_eq(start_1, 1)
	assert_eq(start_8, 8)
	assert_eq(start_27, 22)
	assert_eq(start_1 + interval - 1, 7)
	assert_eq(start_8 + interval - 1, 14)
	assert_eq(start_27 + interval - 1, 28)
	var hud := _read("res://scripts/ui/top_timeline.gd")
	assert_true(hud.contains("cycle_start_day"))
	assert_true(hud.contains("time_changed"))
	assert_true(hud.contains("state_changed"))
	assert_false(hud.contains("current_day ="))
	var scene := _read("res://scenes/ui/hud.tscn")
	assert_true(scene.contains("top_timeline.tscn"))
	assert_false(scene.contains("TEST: TAG 7 22:00"))
	assert_false(scene.contains("FogDebug"))
	var hud_src := _read("res://scripts/ui/hud.gd")
	assert_true(hud_src.contains("INVENTORY_LAYER := 30"))
	assert_true(hud_src.contains("CHROME_LAYER := 20"))


func test_day_phases_use_settings() -> void:
	var src := _read("res://scripts/systems/last_lantern_settings.gd")
	assert_true(src.contains("enum DayPhase"))
	assert_true(src.contains("phase_noon_start"))
	assert_true(src.contains("phase_evening_start"))
	assert_true(src.contains("night_start_time"))
	assert_true(src.contains("func day_phase_at"))
	var hud := _read("res://scripts/ui/top_timeline.gd")
	assert_true(hud.contains("day_phase_at"))
	assert_true(hud.contains("phase_noon_start"))
	assert_true(hud.contains("night_end_time"))
	assert_true(hud.contains("update_visual_state"))
	assert_true(hud.contains("Tag %d / %d"))
	assert_false(hud.contains("☀ FRÜH"))
	assert_false(hud.contains("Finsternis in %d Tagen"))


func test_fog_day_formula() -> void:
	var settings := LastLanternSettings.new()
	settings.fog_interval_days = 7
	assert_eq(settings.is_fog_day(7), true)
	assert_eq(settings.is_fog_day(14), true)
	assert_eq(settings.is_fog_day(21), true)
	assert_eq(settings.is_fog_day(28), true)
	assert_eq(settings.is_fog_day(6), false)
	assert_eq(settings.is_fog_day(8), false)
	assert_eq(settings.is_fog_day(13), false)
	assert_eq(settings.is_fog_day(35), true)


func test_fog_cycle_and_next_day() -> void:
	var settings := LastLanternSettings.new()
	settings.fog_interval_days = 7
	assert_eq(settings.fog_cycle_for_day(7), 1)
	assert_eq(settings.fog_cycle_for_day(14), 2)
	assert_eq(settings.fog_cycle_for_day(21), 3)
	assert_eq(settings.fog_cycle_for_day(28), 4)
	assert_eq(settings.next_fog_day(1, false), 7)
	assert_eq(settings.next_fog_day(7, false), 7)
	assert_eq(settings.next_fog_day(7, true), 14)
	assert_eq(settings.next_fog_day(8, false), 14)


func test_fog_damage_curve_and_cap() -> void:
	var settings := LastLanternSettings.new()
	assert_eq(settings.fog_damage_per_second(1), 5.0)
	assert_eq(settings.fog_damage_per_second(2), 7.0)
	assert_eq(settings.fog_damage_per_second(3), 9.0)
	assert_eq(settings.fog_damage_per_second(4), 12.0)
	assert_true(settings.fog_damage_per_second(80) <= 24.0)
	assert_eq(settings.fog_duration_seconds(1), settings.fog_duration_base)
	assert_true(settings.fog_duration_seconds(40) <= settings.fog_duration_max)


func test_debug_jump_is_22_00() -> void:
	var settings := LastLanternSettings.new()
	var t := settings.clock_hour_to_time(22.0)
	assert_eq(int(round(t * 24.0 * 60.0)), 22 * 60)
	assert_true(t > 0.75)


func test_lantern_radii() -> void:
	var l1 := _read("res://resources/lantern/lantern_level_1.tres")
	var l2 := _read("res://resources/lantern/lantern_level_2.tres")
	var l3 := _read("res://resources/lantern/lantern_level_3.tres")
	var l4 := _read("res://resources/lantern/lantern_level_4.tres")
	assert_true(l1.contains("safe_radius_tiles = 44"))
	assert_true(l2.contains("safe_radius_tiles = 68"))
	assert_true(l3.contains("safe_radius_tiles = 100"))
	assert_true(l4.contains("safe_radius_tiles = 140"))
	assert_eq(44 * 16, 704)
	assert_eq(68 * 16, 1088)
	assert_eq(100 * 16, 1600)
	assert_eq(140 * 16, 2240)


func test_safe_zone_pixels_use_tile_size() -> void:
	var zone := SafeZone.new()
	zone.tile_size = 16
	zone.radius_tiles = 44
	assert_eq(zone.get_radius_pixels(), 704.0)
	zone.radius_tiles = 68
	assert_eq(zone.get_radius_pixels(), 1088.0)
	zone.free()


func test_lightning_palette_weights_and_roll() -> void:
	var palette := _read("res://scripts/systems/fog/lightning_palette.gd")
	assert_true(palette.contains("WEIGHT_PURPLE := 0.45"))
	assert_true(palette.contains("WEIGHT_CRIMSON := 0.30"))
	assert_true(palette.contains("WEIGHT_RED := 0.20"))
	assert_true(palette.contains("WEIGHT_VOID := 0.05"))
	assert_true(palette.contains("PURPLE"))
	assert_true(palette.contains("CRIMSON"))
	assert_true(palette.contains("VOID_PURPLE"))
	assert_true(palette.contains("func pick_variant"))
	var vis := _read("res://scripts/systems/fog/fog_visual.gd")
	assert_true(vis.contains("LightningPalette.pick_variant()"))
	assert_true(vis.contains("_pre_left"))


func test_fog_shader_has_soft_distance_zones() -> void:
	var shader := _read("res://shaders/fog_overlay.gdshader")
	assert_true(shader.contains("ZONE_B = 5.0 * TILE"))
	assert_true(shader.contains("ZONE_C = 12.0 * TILE"))
	assert_true(shader.contains("ZONE_D = 25.0 * TILE"))
	assert_true(shader.contains("smoothstep(0.0, ZONE_B, dist_out)"))
	assert_true(shader.contains("fog_color_c"))
	assert_false(shader.contains("mouse_position.x -="))


func test_midnight_stays_night() -> void:
	var src := _read("res://scripts/systems/time/day_cycle.gd")
	assert_true(src.contains("or t < settings.night_end_time"))
	assert_true(src.contains("00:00 bleibt Nacht"))
	assert_false(src.contains("sky = sky_dawn.lerp(sky_day, u)"))
	var settings_src := _read("res://scripts/systems/last_lantern_settings.gd")
	assert_true(settings_src.contains("@export var night_end_time"))
	var tres := _read("res://resources/systems/last_lantern_settings.tres")
	assert_true(tres.contains("night_end_time = 0.25"))


func test_lantern_brightness_stays_constant() -> void:
	var src := _read("res://scripts/world/lantern.gd")
	assert_true(src.contains("_light.energy = _base_energy"))
	assert_false(src.contains("fog_boost * 0.42"))
	assert_true(src.contains("_make_altar_texture"))
	assert_true(src.contains("_composite_foundation"))
	var fog := _read("res://scripts/systems/fog/fog_event.gd")
	assert_true(fog.contains("time_of_day >= settings.fog_start_time"))
	assert_false(fog.contains("or _day_cycle.is_night"))
	var l1 := _read("res://resources/lantern/lantern_level_1.tres")
	assert_true(l1.contains("sprite_width_px = 48"))


func test_mouse_targeting_uses_canvas_transform() -> void:
	var player := _read("res://scripts/player/player.gd")
	assert_true(player.contains("get_canvas_transform().affine_inverse()"))
	assert_false(player.contains("get_screen_center_position() + (vp.get_mouse_position()"))
	var mining := _read("res://scripts/player/player_interaction.gd")
	assert_true(mining.contains("_tile_map.make_canvas_position_local"))
	assert_true(mining.contains("Maus hat Vorrang"))
	assert_true(mining.contains("_player_reach_origin"))
	assert_true(mining.contains("debug_targeting"))


func test_auto_tool_uses_hotbar_and_restores() -> void:
	var mining := _read("res://scripts/player/player_interaction.gd")
	assert_true(mining.contains("func _handle_auto_tool"))
	assert_true(mining.contains("_auto_tool_saved_slot"))
	assert_true(mining.contains("_restore_auto_tool_slot"))
	assert_true(mining.contains("find_best_hotbar_tool_for"))
	assert_true(mining.contains("KEY_ALT"))
	var inv := _read("res://scripts/inventory/inventory.gd")
	assert_true(inv.contains("func find_best_hotbar_tool_for"))
	assert_true(inv.contains("for i in HOTBAR_COUNT"))
	assert_true(inv.contains("evaluate_break"))
	assert_true(inv.contains("ToolKind.NONE"))
	var player := _read("res://scripts/player/player.gd")
	assert_true(player.contains("func is_auto_tool_held"))
	assert_true(player.contains("KEY_ALT"))


func test_liquid_system_integration() -> void:
	var scene := _read("res://scenes/world/world.tscn")
	assert_true(scene.contains("LiquidSystem"))
	var world_src := _read("res://scripts/world/world_generator.gd")
	assert_true(world_src.contains("_generate_water"))
	assert_true(world_src.contains("_finalize_water"))
	var save_src := _read("res://scripts/save/save_manager.gd")
	assert_true(save_src.contains('"liquid"'))
	var player_scene := _read("res://scenes/player/player.tscn")
	assert_true(player_scene.contains("WaterInteraction"))
	assert_true(player_scene.contains("LavaInteraction"))
	var liquid_src := _read("res://scripts/liquid/liquid_system.gd")
	assert_true(liquid_src.contains("_queued"))
	assert_true(liquid_src.contains("_flow_down_once"))
	assert_true(liquid_src.contains("sleep_after_stable_ticks"))
	var renderer_src := _read("res://scripts/liquid/liquid_renderer.gd")
	assert_false(renderer_src.contains("for y in _system.world_height"))
	assert_true(renderer_src.contains("is_surface_cell"))
	assert_true(renderer_src.contains("_body_color"))
	assert_true(liquid_src.contains("_wake_cell_and_neighbors"))
	assert_true(liquid_src.contains("get_total_water_amount"))
	assert_true(liquid_src.contains("get_lava_cells"))
	assert_true(FileAccess.file_exists("res://scenes/world/lava.tscn"))


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
