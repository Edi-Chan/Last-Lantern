@tool
extends McpTestSuite


func suite_name() -> String:
	return "music"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _catalog() -> MusicCatalog:
	var raw := ResourceLoader.load("res://resources/audio/music/music_catalog.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var live := MusicCatalog.new()
	if raw == null:
		return live
	live.fallback_id = raw.get("fallback_id")
	for entry in raw.get("tracks"):
		if entry == null:
			continue
		var track := MusicTrackData.new()
		track.id = entry.get("id")
		track.priority = int(entry.get("priority"))
		track.enabled = bool(entry.get("enabled"))
		track.scenes = _names(entry.get("scenes"))
		track.biomes = _names(entry.get("biomes"))
		track.day_phases = _names(entry.get("day_phases"))
		track.depth_layers = _names(entry.get("depth_layers"))
		track.fog_states = _names(entry.get("fog_states"))
		track.interiors = _names(entry.get("interiors"))
		track.cues = _names(entry.get("cues"))
		live.tracks.append(track)
	return live


func _names(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value == null:
		return result
	for item in value:
		result.append(StringName(str(item)))
	return result


func test_catalog_picks_biome_and_phase() -> void:
	var catalog := _catalog()
	assert_ne(catalog, null)
	var ctx := MusicContext.new()
	ctx.scene = &"world"
	ctx.biome = &"forest"
	ctx.day_phase = &"night"
	ctx.depth_layer = &"surface"
	ctx.fog_state = &"clear"
	ctx.interior = &"WORLD"
	var track := catalog.resolve(ctx)
	assert_ne(track, null)
	assert_eq(str(track.id), "forest_night")


func test_fog_overrides_biome() -> void:
	var catalog := _catalog()
	var ctx := MusicContext.new()
	ctx.scene = &"world"
	ctx.biome = &"grassland"
	ctx.day_phase = &"night"
	ctx.depth_layer = &"surface"
	ctx.fog_state = &"fog_active"
	ctx.interior = &"WORLD"
	var track := catalog.resolve(ctx)
	assert_ne(track, null)
	assert_eq(str(track.id), "fog")


func test_depth_overrides_surface_biome() -> void:
	var catalog := _catalog()
	var ctx := MusicContext.new()
	ctx.scene = &"world"
	ctx.biome = &"sand"
	ctx.day_phase = &"noon"
	ctx.depth_layer = &"deep"
	ctx.fog_state = &"clear"
	ctx.interior = &"WORLD"
	var track := catalog.resolve(ctx)
	assert_ne(track, null)
	assert_eq(str(track.id), "deep")


func test_menu_and_cue_filters() -> void:
	var catalog := MusicCatalog.new()
	var menu_track := MusicTrackData.new()
	menu_track.id = &"menu"
	menu_track.scenes = [&"menu"]
	menu_track.priority = 5
	var world_track := MusicTrackData.new()
	world_track.id = &"world_default"
	world_track.scenes = [&"world"]
	world_track.priority = 1
	var boss := MusicTrackData.new()
	boss.id = &"boss_test"
	boss.priority = 200
	boss.cues = [&"boss"]
	boss.scenes = [&"world"]
	catalog.tracks = [menu_track, world_track, boss]
	catalog.fallback_id = &"menu"
	var menu_ctx := MusicContext.new()
	menu_ctx.scene = &"menu"
	assert_eq(str(catalog.resolve(menu_ctx).id), "menu")
	var ctx := MusicContext.new()
	ctx.scene = &"world"
	ctx.cue = &"boss"
	assert_eq(str(catalog.resolve(ctx).id), "boss_test")
	ctx.cue = &""
	assert_eq(str(catalog.resolve(ctx).id), "world_default")


func test_ambient_layers_match_day_grass() -> void:
	var catalog := load("res://resources/audio/ambient/ambient_catalog.tres") as AmbientCatalog
	if catalog == null:
		var raw = ResourceLoader.load("res://resources/audio/ambient/ambient_catalog.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
		catalog = AmbientCatalog.new()
		if raw != null:
			for entry in raw.get("layers"):
				var layer := AmbientLayerData.new()
				layer.id = entry.get("id")
				layer.enabled = bool(entry.get("enabled"))
				layer.kind = int(entry.get("kind"))
				layer.scenes = _names(entry.get("scenes"))
				layer.biomes = _names(entry.get("biomes"))
				layer.day_phases = _names(entry.get("day_phases"))
				layer.depth_layers = _names(entry.get("depth_layers"))
				layer.fog_states = _names(entry.get("fog_states"))
				layer.interiors = _names(entry.get("interiors"))
				catalog.layers.append(layer)
	var ctx := MusicContext.new()
	ctx.scene = &"world"
	ctx.biome = &"grassland"
	ctx.day_phase = &"morning"
	ctx.depth_layer = &"surface"
	ctx.fog_state = &"clear"
	ctx.interior = &"WORLD"
	var ids: PackedStringArray = []
	for layer in catalog.matching(ctx):
		ids.append(str(layer.id))
	assert_true("wind_grass" in ids)
	assert_true("bird_call" in ids)


func test_tracks_and_autoload_exist() -> void:
	assert_true(FileAccess.file_exists("res://audio/music/menu.wav"))
	assert_true(FileAccess.file_exists("res://audio/music/grassland_day.wav"))
	assert_true(FileAccess.file_exists("res://audio/music/forest_night.wav"))
	assert_true(FileAccess.file_exists("res://audio/music/fog.wav"))
	assert_true(FileAccess.file_exists("res://resources/audio/music/music_catalog.tres"))
	var project := _read("res://project.godot")
	assert_true(project.contains("MusicDirector="))
	var director := _read("res://scripts/audio/music_director.gd")
	assert_true(director.contains("func set_cue"))
	assert_true(director.contains("MusicCatalog"))
	assert_true(director.contains("BUS_MUSIC := &\"Master\""))
	assert_true(director.contains("func _start_immediately"))
	assert_true(director.contains("ambient_catalog"))
	assert_true(FileAccess.file_exists("res://audio/ambient/world/wind_grass.wav"))
	assert_true(FileAccess.file_exists("res://audio/ambient/world/bird_01.wav"))
	assert_true(FileAccess.file_exists("res://audio/ambient/world/bird_03.wav"))
	var playable := WavLoader.playable("res://audio/music/menu.wav", true)
	assert_ne(playable, null)
	assert_true(FileAccess.file_exists("res://resources/audio/ambient/ambient_catalog.tres"))
	var wav := WavLoader.load_loop("res://audio/music/grassland_day.wav")
	assert_ne(wav, null)
	assert_true(wav.data.size() > 1000)
	var ambient := load("res://resources/audio/ambient/ambient_catalog.tres") as AmbientCatalog
	assert_ne(ambient, null)
	assert_true(ambient.layers.size() >= 8)
	var catalog := load("res://resources/audio/music/music_catalog.tres") as MusicCatalog
	assert_ne(catalog, null)
	assert_true(catalog.tracks.size() >= 10)
	for track in catalog.tracks:
		assert_ne(track, null)
		assert_ne(track.stream, null)
