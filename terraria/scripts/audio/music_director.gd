extends Node

## Autoload. Musik plus Ambient (Wind, Voegel, Nacht, Hoehle).

const DEFAULT_MUSIC_PATH := "res://resources/audio/music/music_catalog.tres"
const DEFAULT_AMBIENT_PATH := "res://resources/audio/ambient/ambient_catalog.tres"
const BUS_MUSIC := &"Master"
const BUS_AMBIENT := &"Ambient"
const MENU_FALLBACK := "res://audio/music/menu.wav"
const WORLD_FALLBACK := "res://audio/music/grassland_day.wav"
const POLL_INTERVAL := 0.35
const BIOME_HOLD := 1.15
const SURFACE_MAX_DEPTH := 5
const UNDERGROUND_MAX_DEPTH := 26

@export var catalog: MusicCatalog
@export var ambient_catalog: AmbientCatalog
@export var enabled: bool = true

var current_track_id: StringName = &""
var current_context: MusicContext = MusicContext.new()

var _cue: StringName = &""
var _poll_left: float = 0.0
var _fade_t: float = 1.0
var _fade_dur: float = 2.0
var _active: int = 0
var _music: Array[AudioStreamPlayer] = []
var _music_target: Array[float] = [-3.0, -3.0]
var _stable_biome: StringName = &"grassland"
var _pending_biome: StringName = &"grassland"
var _biome_hold: float = 0.0
var _stable_depth: StringName = &"surface"
var _pending_depth: StringName = &"surface"
var _depth_hold: float = 0.0
var _beds: Dictionary = {}
var _oneshot_wait: Dictionary = {}
var _oneshot_player: AudioStreamPlayer
var _oneshot_alt: AudioStreamPlayer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("music_director")


func _ready() -> void:
	if catalog == null:
		catalog = load(DEFAULT_MUSIC_PATH) as MusicCatalog
	if ambient_catalog == null and ResourceLoader.exists(DEFAULT_AMBIENT_PATH):
		ambient_catalog = load(DEFAULT_AMBIENT_PATH) as AmbientCatalog
	_music = [_make_player(BUS_MUSIC), _make_player(BUS_MUSIC)]
	_oneshot_player = _make_player(BUS_AMBIENT)
	_oneshot_alt = _make_player(BUS_AMBIENT)
	_start_immediately()
	_evaluate(true)


func set_cue(cue_id: StringName) -> void:
	_cue = cue_id
	_evaluate(true)


func clear_cue() -> void:
	set_cue(&"")


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = String(bus)
	if AudioServer.get_bus_index(String(bus)) < 0:
		player.bus = "Master"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.volume_db = -48.0
	add_child(player)
	return player


func _process(delta: float) -> void:
	if _music.size() < 2:
		return
	_advance_music_fade(delta)
	_advance_ambient_fade(delta)
	_keep_music_playing()
	if not enabled:
		return
	_poll_left -= delta
	_tick_oneshots(delta)
	if _poll_left > 0.0:
		return
	_poll_left = POLL_INTERVAL
	_evaluate(false)


func _start_immediately() -> void:
	var path := MENU_FALLBACK if _is_menu_scene() else WORLD_FALLBACK
	var stream := WavLoader.playable(path, true)
	if stream == null:
		return
	var player := _music[0]
	player.stream = stream
	player.volume_db = _mix_db(-2.0, "music")
	player.play()
	_active = 0
	_fade_t = 1.0
	current_track_id = &"boot"


func _evaluate(snap: bool) -> void:
	_bind_world()
	current_context = _build_context(snap)
	var track: MusicTrackData = null
	if catalog != null:
		track = catalog.resolve(current_context)
	if track != null and track.id != current_track_id:
		_play_track(track)
	elif current_track_id == &"" or current_track_id == &"boot":
		var path := MENU_FALLBACK if current_context.scene == &"menu" else WORLD_FALLBACK
		_play_path(path, &"fallback", -2.0)
	_sync_ambient()


func _play_track(track: MusicTrackData) -> void:
	var stream := track.resolved_stream()
	if stream == null:
		var path := track.stream_path
		if path.is_empty():
			path = MENU_FALLBACK if current_context.scene == &"menu" else WORLD_FALLBACK
		_play_path(path, track.id, track.volume_db)
		return
	_swap_music(stream, track.id, track.volume_db, track.crossfade_seconds)


func _play_path(path: String, track_id: StringName, volume_db: float) -> void:
	var stream := WavLoader.playable(path, true)
	if stream == null:
		return
	_swap_music(stream, track_id, volume_db, 0.8)


func _swap_music(stream: AudioStream, track_id: StringName, volume_db: float, fade: float) -> void:
	if _music.size() < 2:
		return
	var incoming := 1 - _active
	var player := _music[incoming]
	var target := _mix_db(volume_db, "music")
	player.bus = "Master"
	player.stream = stream
	player.play()
	_music_target[incoming] = target
	_music_target[_active] = -48.0
	if current_track_id == &"" or current_track_id == &"boot":
		player.volume_db = target
		_music[_active].stop()
		_fade_t = 1.0
	else:
		player.volume_db = -48.0
		_fade_t = 0.0
		_fade_dur = maxf(fade, 0.05)
	_active = incoming
	current_track_id = track_id


func _mix_db(track_db: float, key: String) -> float:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings == null:
		return track_db
	var audio: Dictionary = settings.audio
	if bool(audio.get(key + "_mute", false)):
		return -80.0
	var linear := clampf(float(audio.get(key, 1.0)), 0.0, 1.0)
	if linear <= 0.0001:
		return -80.0
	return track_db + linear_to_db(linear)


func _keep_music_playing() -> void:
	var player := _music[_active]
	if player.stream != null and not player.playing:
		player.play()


func _advance_music_fade(delta: float) -> void:
	if _fade_t >= 1.0:
		if _music[1 - _active] != _music[_active] and _music[1 - _active].playing:
			_music[1 - _active].stop()
		return
	_fade_t = minf(_fade_t + delta / _fade_dur, 1.0)
	var t := _fade_t * _fade_t * (3.0 - 2.0 * _fade_t)
	_music[_active].volume_db = lerpf(-48.0, _music_target[_active], t)
	_music[1 - _active].volume_db = lerpf(-48.0, _music_target[1 - _active], 1.0 - t)


func _sync_ambient() -> void:
	if ambient_catalog == null or current_context.scene == &"menu":
		_fade_all_beds_out()
		return
	var wanted: Dictionary = {}
	for layer in ambient_catalog.matching(current_context):
		if layer.kind == AmbientLayerData.Kind.BED:
			wanted[layer.id] = layer
			_ensure_bed(layer)
		elif not _oneshot_wait.has(layer.id):
			_oneshot_wait[layer.id] = randf_range(layer.oneshot_min, layer.oneshot_max)
	for layer_id in _beds.keys():
		if not wanted.has(layer_id):
			_beds[layer_id]["target"] = -48.0
	for layer_id in _oneshot_wait.keys():
		if not _is_oneshot_active(layer_id):
			_oneshot_wait.erase(layer_id)


func _ensure_bed(layer: AmbientLayerData) -> void:
	if _beds.has(layer.id):
		_beds[layer.id]["target"] = layer.volume_db
		_beds[layer.id]["fade"] = maxf(layer.fade_seconds, 0.05)
		return
	var stream := layer.resolved_stream()
	if stream == null:
		return
	var player := _make_player(BUS_AMBIENT)
	player.stream = stream
	player.volume_db = -48.0
	player.play()
	_beds[layer.id] = {
		"player": player,
		"volume": -48.0,
		"target": layer.volume_db,
		"fade": maxf(layer.fade_seconds, 0.05),
	}


func _fade_all_beds_out() -> void:
	for layer_id in _beds.keys():
		_beds[layer_id]["target"] = -48.0


func _advance_ambient_fade(delta: float) -> void:
	var drop: Array[StringName] = []
	for layer_id in _beds.keys():
		var bed: Dictionary = _beds[layer_id]
		var player: AudioStreamPlayer = bed["player"]
		var target: float = bed["target"]
		var fade: float = maxf(float(bed["fade"]), 0.05)
		var volume: float = float(bed["volume"])
		volume = move_toward(volume, target, delta * (48.0 / fade))
		bed["volume"] = volume
		if is_instance_valid(player):
			player.volume_db = volume
			if player.stream != null and not player.playing and target > -40.0:
				player.play()
		if target <= -47.0 and volume <= -47.0:
			if is_instance_valid(player):
				player.stop()
				player.queue_free()
			drop.append(layer_id)
	for layer_id in drop:
		_beds.erase(layer_id)


func _tick_oneshots(delta: float) -> void:
	if current_context.scene == &"menu" or ambient_catalog == null:
		return
	for layer in ambient_catalog.matching(current_context):
		if layer.kind != AmbientLayerData.Kind.ONESHOT:
			continue
		if not _oneshot_wait.has(layer.id):
			_oneshot_wait[layer.id] = randf_range(layer.oneshot_min, layer.oneshot_max)
		_oneshot_wait[layer.id] = float(_oneshot_wait[layer.id]) - delta
		if float(_oneshot_wait[layer.id]) > 0.0:
			continue
		_oneshot_wait[layer.id] = randf_range(layer.oneshot_min, layer.oneshot_max)
		var player := _oneshot_player
		if player.playing:
			player = _oneshot_alt
		if player.playing:
			continue
		var stream := layer.resolved_stream()
		if stream == null:
			continue
		player.stream = stream
		player.volume_db = _mix_db(layer.volume_db + randf_range(-3.0, 0.5), "ambient")
		player.pitch_scale = randf_range(0.86, 1.14)
		player.play()


func _is_oneshot_active(layer_id: StringName) -> bool:
	if ambient_catalog == null:
		return false
	for layer in ambient_catalog.matching(current_context):
		if layer.id == layer_id:
			return true
	return false


func _build_context(snap: bool) -> MusicContext:
	var ctx := MusicContext.new()
	ctx.cue = _cue
	if _is_menu_scene():
		ctx.scene = &"menu"
		return ctx
	ctx.scene = &"world"
	var day := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if day != null and day.settings != null:
		ctx.day_phase = _phase_name(day.settings.day_phase_at(day.time_of_day))
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null:
		ctx.fog_state = _fog_name(fog.state)
	var buildings := get_tree().get_first_node_in_group("building_manager") as BuildingManager
	if buildings != null:
		ctx.interior = buildings.current_area
	_update_world_location(ctx, snap)
	return ctx


func _on_world_shift(_a: Variant = null, _b: Variant = null) -> void:
	_evaluate(true)


func _bind_world() -> void:
	var day := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if day != null:
		if not day.night_started.is_connected(_on_world_shift):
			day.night_started.connect(_on_world_shift)
		if not day.day_started.is_connected(_on_world_shift):
			day.day_started.connect(_on_world_shift)
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null and not fog.state_changed.is_connected(_on_world_shift):
		fog.state_changed.connect(_on_world_shift)
	var buildings := get_tree().get_first_node_in_group("building_manager") as BuildingManager
	if buildings != null:
		if not buildings.building_entered.is_connected(_on_world_shift):
			buildings.building_entered.connect(_on_world_shift)
		if not buildings.building_exited.is_connected(_on_world_shift):
			buildings.building_exited.connect(_on_world_shift)


func _is_menu_scene() -> bool:
	return get_tree().get_first_node_in_group("day_cycle") == null


func _update_world_location(ctx: MusicContext, snap: bool) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	var tilemap := get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if player == null or world == null or tilemap == null or tilemap.tile_set == null:
		ctx.biome = _stable_biome
		ctx.depth_layer = _stable_depth
		return
	var tile := tilemap.local_to_map(tilemap.to_local(player.global_position))
	_hold_value(world.get_surface_biome(tile.x), snap, true)
	_hold_value(_depth_name(tile.y - world.get_surface_y(tile.x)), snap, false)
	ctx.biome = _stable_biome
	ctx.depth_layer = _stable_depth


func _hold_value(raw: StringName, snap: bool, is_biome: bool) -> void:
	if is_biome:
		if snap or raw == _pending_biome and _biome_hold >= BIOME_HOLD:
			_pending_biome = raw
			_stable_biome = raw
			_biome_hold = BIOME_HOLD
			return
		if raw != _pending_biome:
			_pending_biome = raw
			_biome_hold = 0.0
		else:
			_biome_hold += POLL_INTERVAL
			if _biome_hold >= BIOME_HOLD:
				_stable_biome = raw
	else:
		if snap or raw == _pending_depth and _depth_hold >= BIOME_HOLD:
			_pending_depth = raw
			_stable_depth = raw
			_depth_hold = BIOME_HOLD
			return
		if raw != _pending_depth:
			_pending_depth = raw
			_depth_hold = 0.0
		else:
			_depth_hold += POLL_INTERVAL
			if _depth_hold >= BIOME_HOLD:
				_stable_depth = raw


func _depth_name(depth: int) -> StringName:
	if depth <= SURFACE_MAX_DEPTH:
		return &"surface"
	if depth <= UNDERGROUND_MAX_DEPTH:
		return &"underground"
	return &"deep"


func _phase_name(phase: int) -> StringName:
	match phase:
		LastLanternSettings.DayPhase.NOON:
			return &"noon"
		LastLanternSettings.DayPhase.EVENING:
			return &"evening"
		LastLanternSettings.DayPhase.NIGHT:
			return &"night"
		_:
			return &"morning"


func _fog_name(state: int) -> StringName:
	match state:
		FogEvent.State.WARNING:
			return &"warning"
		FogEvent.State.FOG_ACTIVE:
			return &"fog_active"
		FogEvent.State.FOG_ENDING:
			return &"fog_ending"
		_:
			return &"clear"
