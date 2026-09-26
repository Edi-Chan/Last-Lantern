@tool
extends McpTestSuite


func suite_name() -> String:
	return "world_map"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _map(width: int = 64, height: int = 48, surface_y: int = 12) -> WorldMapData:
	var data := WorldMapData.new()
	track(data)
	data.setup_test_world(width, height, surface_y)
	return data


func _fill_solid_row(data: WorldMapData, y: int, block_id: int = 3) -> void:
	for x in data.exploration.width:
		data.test_set_block(Vector2i(x, y), block_id, true)


func test_new_world_starts_undiscovered() -> void:
	var data := _map()
	assert_eq(data.discovered_count(), 0)
	assert_eq(data.is_discovered(Vector2i(8, 8)), false)
	assert_eq(data.display_color_at(Vector2i(8, 8)), WorldMapData.COLOR_FOG)
	assert_true(data.display_color_at(Vector2i(8, 8)) != data.color_at(Vector2i(8, 8)))


func test_start_area_is_small_and_local() -> void:
	var data := _map(80, 40, 10)
	_fill_solid_row(data, 10)
	data.reveal_start_area()
	assert_true(data.discovered_count() > 0)
	assert_true(data.discovered_count() < 80 * 40 / 4)
	assert_true(data.is_discovered(data.start_tile()))
	assert_eq(data.is_discovered(Vector2i(2, 35)), false)
	assert_eq(data.display_color_at(Vector2i(2, 35)), WorldMapData.COLOR_FOG)


func test_discovery_radius_reveals_local_path() -> void:
	var data := _map(80, 24, 8)
	_fill_solid_row(data, 8)
	data.discover_around(Vector2i(10, 7), 8)
	assert_true(data.is_discovered(Vector2i(10, 7)))
	assert_true(data.is_discovered(Vector2i(16, 7)))
	assert_eq(data.is_discovered(Vector2i(70, 7)), false)


func test_surface_does_not_reveal_cave_through_walls() -> void:
	var data := _map(48, 36, 8)
	_fill_solid_row(data, 8)
	for y in range(9, 28):
		data.test_set_block(Vector2i(20, y), 3, true)
	data.test_set_block(Vector2i(24, 20), 0, false)
	data.discover_around(Vector2i(24, 7), WorldMapData.DISCOVERY_RADIUS)
	assert_true(data.is_discovered(Vector2i(24, 7)))
	assert_true(data.is_discovered(Vector2i(24, 8)))
	assert_eq(data.is_discovered(Vector2i(24, 20)), false)
	assert_eq(data.display_color_at(Vector2i(24, 20)), WorldMapData.COLOR_FOG)


func test_cave_exploration_reveals_only_local_chamber() -> void:
	var data := _map(40, 32, 6)
	for x in range(8, 28):
		for y in range(12, 22):
			data.test_set_block(Vector2i(x, y), 0, false)
	for x in range(8, 28):
		data.test_set_block(Vector2i(x, 12), 3, true)
		data.test_set_block(Vector2i(x, 21), 3, true)
	for y in range(12, 22):
		data.test_set_block(Vector2i(8, y), 3, true)
		data.test_set_block(Vector2i(18, y), 3, true)
		data.test_set_block(Vector2i(27, y), 3, true)
	data.discover_around(Vector2i(12, 16), 10)
	assert_true(data.is_discovered(Vector2i(12, 16)))
	assert_true(data.is_discovered(Vector2i(14, 16)))
	assert_eq(data.is_discovered(Vector2i(24, 16)), false)
	assert_eq(data.display_color_at(Vector2i(24, 16)), WorldMapData.COLOR_FOG)


func test_discovery_is_permanent() -> void:
	var data := _map()
	data.discover_around(Vector2i(12, 8), 6)
	var count := data.discovered_count()
	assert_true(count > 0)
	data._last_player_tile = Vector2i(40, 8)
	assert_eq(data.discovered_count(), count)
	assert_true(data.is_discovered(Vector2i(12, 8)))


func test_tile_change_updates_only_discovered_cells() -> void:
	var data := _map()
	data.discover_around(Vector2i(10, 8), 4)
	data.test_set_block(Vector2i(10, 8), 4, true)
	data.update_tile(Vector2i(10, 8))
	assert_eq(data.display_color_at(Vector2i(10, 8)), data.color_at(Vector2i(10, 8)))
	data.test_set_block(Vector2i(50, 20), 4, true)
	data.update_tile(Vector2i(50, 20))
	assert_eq(data.display_color_at(Vector2i(50, 20)), WorldMapData.COLOR_FOG)


func test_water_and_lava_colors() -> void:
	var data := _map()
	data.test_set_liquid(Vector2i(5, 15), LiquidTypes.Type.WATER, 220)
	data.test_set_liquid(Vector2i(6, 15), LiquidTypes.Type.LAVA, 200)
	data.exploration.set_discovered(Vector2i(5, 15))
	data.exploration.set_discovered(Vector2i(6, 15))
	assert_eq(data.color_at(Vector2i(5, 15)), WorldMapData.COLOR_WATER_DEEP)
	assert_eq(data.color_at(Vector2i(6, 15)), WorldMapData.COLOR_LAVA_HOT)
	assert_eq(data.display_color_at(Vector2i(5, 15)), WorldMapData.COLOR_WATER_DEEP)
	assert_eq(data.display_color_at(Vector2i(7, 15)), WorldMapData.COLOR_FOG)


func test_fire_region_and_bedrock_colors() -> void:
	var data := _map()
	data.test_set_block(Vector2i(4, 30), 6, true)
	data.test_set_fire(Vector2i(4, 30), true)
	data.test_set_block(Vector2i(5, 40), WorldGenerator.BEDROCK, true)
	data.exploration.set_discovered(Vector2i(4, 30))
	data.exploration.set_discovered(Vector2i(5, 40))
	var fire_color := data.color_at(Vector2i(4, 30))
	assert_true(fire_color.r > fire_color.b)
	assert_eq(data.color_at(Vector2i(5, 40)), WorldMapData.COLOR_BEDROCK)


func test_save_and_load_restore_exact_mask() -> void:
	var data := _map(32, 24, 8)
	data.discover_around(Vector2i(6, 7), 5)
	data.discover_around(Vector2i(20, 18), 4)
	var saved := data.to_save_dict()
	assert_eq(int(saved.get("width", 0)), 32)
	assert_eq(int(saved.get("height", 0)), 24)
	assert_true(str(saved.get("mask", "")).length() > 8)
	var restored := _map(32, 24, 8)
	restored.from_save_dict(saved)
	assert_eq(restored.discovered_count(), data.discovered_count())
	for y in 24:
		for x in 32:
			var cell := Vector2i(x, y)
			assert_eq(restored.is_discovered(cell), data.is_discovered(cell))


func test_old_save_without_discovery_does_not_crash() -> void:
	var data := _map(40, 20, 8)
	_fill_solid_row(data, 8)
	data.from_save_dict({})
	assert_true(data.discovered_count() > 0)
	assert_true(data.is_discovered(data.start_tile()))
	assert_eq(data.is_discovered(Vector2i(2, 18)), false)


func test_mismatched_save_size_falls_back_to_start() -> void:
	var data := _map(40, 20, 8)
	_fill_solid_row(data, 8)
	data.from_save_dict({
		"width": 16,
		"height": 16,
		"mask": Marshalls.raw_to_base64(PackedByteArray([1, 2, 3])),
	})
	assert_true(data.discovered_count() > 0)
	assert_true(data.discovered_count() < 40 * 20)


func test_admin_reveal_covers_entire_world() -> void:
	var data := _map(24, 16, 6)
	data.test_set_block(Vector2i(23, 15), 13, true)
	data.reveal_full_map()
	assert_eq(data.discovered_count(), 24 * 16)
	assert_true(data.is_discovered(Vector2i(0, 0)))
	assert_true(data.is_discovered(Vector2i(23, 15)))
	assert_true(data.display_color_at(Vector2i(23, 15)) != WorldMapData.COLOR_FOG)
	var saved := data.to_save_dict()
	var other := _map(24, 16, 6)
	assert_eq(other.discovered_count(), 0)
	other.from_save_dict(saved)
	assert_eq(other.discovered_count(), 24 * 16)
	assert_eq(bool(saved.get("full", false)), true)
	assert_eq(saved.has("mask"), false)


func test_full_reveal_skips_further_discovery() -> void:
	var data := _map(32, 16, 6)
	data.reveal_full_map()
	var count := data.discovered_count()
	assert_eq(data.discover_around(Vector2i(8, 4), 12), 0)
	assert_eq(data.discovered_count(), count)


func test_full_reveal_does_not_flush_while_maps_hidden() -> void:
	var data := _map(48, 24, 8)
	data.reveal_full_map()
	data.map_flush_count = 0
	data._texture_dirty = true
	for _i in 30:
		data._process(0.05)
	assert_eq(data.map_flush_count, 0)
	assert_eq(data.full_revealed, true)


func test_compact_full_save_roundtrip() -> void:
	var data := _map(40, 20, 8)
	data.reveal_full_map()
	var saved := data.to_save_dict()
	assert_eq(bool(saved.get("full", false)), true)
	var restored := _map(40, 20, 8)
	restored.from_save_dict(saved)
	assert_eq(restored.discovered_count(), 40 * 20)
	assert_eq(restored.full_revealed, true)
	assert_eq(restored.discover_around(Vector2i(10, 8), 8), 0)


func test_reset_keeps_start_area_only() -> void:
	var data := _map(48, 24, 8)
	_fill_solid_row(data, 8)
	data.reveal_full_map()
	assert_eq(data.discovered_count(), 48 * 24)
	data.reset_discovery(true)
	assert_true(data.discovered_count() > 0)
	assert_true(data.discovered_count() < 48 * 24 / 2)
	assert_eq(data.display_color_at(Vector2i(2, 20)), WorldMapData.COLOR_FOG)


func test_discovery_byte_sizes_for_world_sizes() -> void:
	var settings := WorldGenerationSettings.new()
	var small: Dictionary = settings.size_profile(WorldSize.Id.SMALL)
	var medium: Dictionary = settings.size_profile(WorldSize.Id.MEDIUM)
	var large: Dictionary = settings.size_profile(WorldSize.Id.LARGE)
	var small_bytes := MapExploration.byte_size_for(int(small["width"]), int(small["height"]))
	var medium_bytes := MapExploration.byte_size_for(int(medium["width"]), int(medium["height"]))
	var large_bytes := MapExploration.byte_size_for(int(large["width"]), int(large["height"]))
	assert_eq(small_bytes, (960 * 360 + 7) >> 3)
	assert_eq(medium_bytes, (1600 * 480 + 7) >> 3)
	assert_eq(large_bytes, (2560 * 640 + 7) >> 3)
	assert_true(small_bytes < medium_bytes)
	assert_true(medium_bytes < large_bytes)
	assert_true(large_bytes < 300000)


func test_markers_require_discovery() -> void:
	var data := _map()
	var lantern := data.get_marker(WorldMapData.LANTERN_MARKER_ID)
	var player := data.get_marker(WorldMapData.PLAYER_MARKER_ID)
	var death := data.get_marker(WorldMapData.DEATH_MARKER_ID)
	assert_ne(lantern, null)
	assert_ne(player, null)
	assert_ne(death, null)
	lantern.world_position = Vector2(16 * 30, 16 * 10)
	assert_eq(lantern.is_shown(data), false)
	data.exploration.set_discovered(Vector2i(30, 10))
	assert_eq(lantern.is_shown(data), true)
	assert_eq(player.discovered_required, false)
	assert_eq(death.visible, false)


func test_shared_data_and_admin_hooks_exist() -> void:
	var minimap := _read("res://scripts/ui/minimap.gd")
	var world_map := _read("res://scripts/ui/world_map.gd")
	var save_src := _read("res://scripts/save/save_manager.gd")
	var admin := _read("res://autoload/admin_manager.gd")
	var menu := _read("res://scripts/ui/admin_menu.gd")
	assert_true(minimap.contains("_rebuild_local"))
	assert_true(minimap.contains("BASE_VISIBLE"))
	assert_true(world_map.contains("WorldMapData"))
	assert_true(minimap.contains("LANTERN_MARKER_ID"))
	assert_true(world_map.contains("center_on_player"))
	assert_true(save_src.contains("map_discovery"))
	assert_true(save_src.contains("_call_save(\"world_map_data\")") or save_src.contains("_call_save(\"world_map_data\")") or save_src.contains("world_map_data"))
	assert_true(admin.contains("func reveal_full_map"))
	assert_true(admin.contains("func reset_map_discovery"))
	assert_true(menu.contains("GANZE KARTE AUFDECKEN"))
	assert_true(menu.contains("RESET MAP DISCOVERY"))
	assert_true(menu.contains("Reveal the entire map?"))
	assert_true(menu.contains("RUN MAP BENCHMARK"))
	assert_true(menu.contains("MAP PERFORMANCE"))
	assert_true(admin.contains("func run_map_benchmark"))
	assert_true(admin.contains("perf_minimap"))


func test_minimap_rebuild_recreates_texture_on_size_change() -> void:
	var data := _map(80, 48, 12)
	var minimap := MiniMap.new()
	track(minimap)
	var world_texture := TextureRect.new()
	track(world_texture)
	minimap._data = data
	minimap._world_texture = world_texture
	minimap._rebuild_local(Vector2i.ZERO, Vector2i(8, 8))
	minimap._rebuild_local(Vector2i.ZERO, Vector2i(12, 10))
	assert_eq(minimap._local_texture.get_width(), 12)
	assert_eq(minimap._local_texture.get_height(), 10)
	assert_true(world_texture.texture == minimap._local_texture)


func test_block_map_colors_are_data_driven() -> void:
	var grass := load("res://resources/blocks/grass.tres") as BlockData
	var dirt := load("res://resources/blocks/dirt.tres") as BlockData
	var stone := load("res://resources/blocks/stone.tres") as BlockData
	var sand := load("res://resources/blocks/sand.tres") as BlockData
	var bedrock := load("res://resources/blocks/bedrock.tres") as BlockData
	assert_ne(grass, null)
	assert_true(grass.get_map_color().a > 0.0)
	assert_true(dirt.get_map_color().g < grass.get_map_color().g)
	assert_true(stone.get_map_color().r > 0.4)
	assert_true(sand.get_map_color().r > 0.7)
	assert_true(bedrock.get_map_color().r < 0.15)
