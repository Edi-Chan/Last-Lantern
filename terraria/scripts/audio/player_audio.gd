class_name PlayerAudio
extends Node

## Gehoert an: Player/Audio in res://scenes/player/player.tscn
##
## Ein Manager, keine zweite Audio-Hierarchie. Bestehende play()-Aufrufe
## bleiben gueltig. Varianten und Materialien werden zur Laufzeit geladen.

@export var pitch_min: float = 0.95
@export var pitch_max: float = 1.05

var _base_volume_db: Dictionary = {}
var _stream_cache: Dictionary = {}
var _last_path: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []

const EVENT_STREAMS := {
	&"Footstep": ["res://audio/sfx/footstep.wav"],
	&"Jump": ["res://audio/sfx/jump.wav"],
	&"Land": [
		"res://audio/sfx/land_01.wav",
		"res://audio/sfx/land_02.wav",
		"res://audio/sfx/land_03.wav",
	],
	&"Swing": ["res://audio/sfx/swing.wav"],
	&"SwordSwing": ["res://audio/sfx/swing_sword.wav"],
	&"SpearThrust": ["res://audio/sfx/swing_spear.wav"],
	&"LanternSwing": ["res://audio/sfx/swing_lantern.wav"],
	&"BowDraw": ["res://audio/sfx/bow_draw.wav"],
	&"BowRelease": ["res://audio/sfx/bow_release.wav"],
	&"Hit": ["res://audio/sfx/hit_impact.wav"],
	&"LanternHit": ["res://audio/sfx/hit_lantern.wav"],
	&"ArrowImpact": ["res://audio/sfx/arrow_impact.wav"],
	&"MineHit": ["res://audio/sfx/mine_hit.wav"],
	&"BlockBreak": ["res://audio/sfx/block_break.wav"],
	&"BlockPlace": ["res://audio/sfx/block_place.wav"],
	&"Pickup": ["res://audio/sfx/pickup.wav", "res://audio/sfx/pickup_02.wav"],
	&"UiOpen": ["res://audio/sfx/ui_open.wav"],
	&"UiClose": ["res://audio/sfx/ui_close.wav"],
	&"UiClick": ["res://audio/sfx/ui_click.wav"],
	&"UiTab": ["res://audio/sfx/ui_tab.wav"],
	&"UiCraftOk": ["res://audio/sfx/ui_craft_ok.wav"],
	&"UiCraftFail": ["res://audio/sfx/ui_craft_fail.wav"],
}

const MATERIAL_STREAMS := {
	&"Footstep": {
		&"grass": [
			"res://audio/sfx/step_grass_01.wav",
			"res://audio/sfx/step_grass_02.wav",
			"res://audio/sfx/step_grass_03.wav",
			"res://audio/sfx/step_grass_04.wav",
		],
		&"dirt": [
			"res://audio/sfx/step_dirt_01.wav",
			"res://audio/sfx/step_dirt_02.wav",
			"res://audio/sfx/step_dirt_03.wav",
			"res://audio/sfx/step_dirt_04.wav",
		],
		&"stone": [
			"res://audio/sfx/step_stone_01.wav",
			"res://audio/sfx/step_stone_02.wav",
			"res://audio/sfx/step_stone_03.wav",
			"res://audio/sfx/step_stone_04.wav",
		],
		&"sand": [
			"res://audio/sfx/step_sand_01.wav",
			"res://audio/sfx/step_sand_02.wav",
			"res://audio/sfx/step_sand_03.wav",
			"res://audio/sfx/step_sand_04.wav",
		],
		&"wood": [
			"res://audio/sfx/step_wood_01.wav",
			"res://audio/sfx/step_wood_02.wav",
			"res://audio/sfx/step_wood_03.wav",
			"res://audio/sfx/step_wood_04.wav",
		],
		&"metal": [
			"res://audio/sfx/step_metal_01.wav",
			"res://audio/sfx/step_metal_02.wav",
			"res://audio/sfx/step_metal_03.wav",
			"res://audio/sfx/step_metal_04.wav",
		],
	},
	&"MineHit": {
		&"dirt": ["res://audio/sfx/hit_dirt_01.wav", "res://audio/sfx/hit_dirt_02.wav", "res://audio/sfx/hit_dirt_03.wav"],
		&"sand": ["res://audio/sfx/hit_dirt_02.wav", "res://audio/sfx/hit_dirt_03.wav"],
		&"stone": ["res://audio/sfx/hit_stone_01.wav", "res://audio/sfx/hit_stone_02.wav", "res://audio/sfx/hit_stone_03.wav"],
		&"ore": ["res://audio/sfx/hit_ore_01.wav", "res://audio/sfx/hit_ore_02.wav", "res://audio/sfx/hit_ore_03.wav"],
		&"wood": ["res://audio/sfx/hit_wood_01.wav", "res://audio/sfx/hit_wood_02.wav", "res://audio/sfx/hit_wood_03.wav"],
		&"grass": ["res://audio/sfx/hit_plant_01.wav", "res://audio/sfx/hit_plant_02.wav", "res://audio/sfx/hit_plant_03.wav"],
		&"metal": ["res://audio/sfx/hit_ore_01.wav", "res://audio/sfx/hit_ore_02.wav"],
	},
	&"BlockBreak": {
		&"dirt": ["res://audio/sfx/break_dirt_01.wav", "res://audio/sfx/break_dirt_02.wav", "res://audio/sfx/break_dirt_03.wav"],
		&"sand": ["res://audio/sfx/break_dirt_02.wav", "res://audio/sfx/break_dirt_03.wav"],
		&"stone": ["res://audio/sfx/break_stone_01.wav", "res://audio/sfx/break_stone_02.wav", "res://audio/sfx/break_stone_03.wav"],
		&"ore": ["res://audio/sfx/break_ore_01.wav", "res://audio/sfx/break_ore_02.wav", "res://audio/sfx/break_ore_03.wav"],
		&"wood": ["res://audio/sfx/break_wood_01.wav", "res://audio/sfx/break_wood_02.wav", "res://audio/sfx/break_wood_03.wav"],
		&"grass": ["res://audio/sfx/break_plant_01.wav", "res://audio/sfx/break_plant_02.wav", "res://audio/sfx/break_plant_03.wav"],
		&"metal": ["res://audio/sfx/break_ore_02.wav", "res://audio/sfx/break_ore_03.wav"],
	},
	&"BlockPlace": {
		&"dirt": ["res://audio/sfx/place_dirt_01.wav", "res://audio/sfx/place_dirt_02.wav", "res://audio/sfx/place_dirt_03.wav"],
		&"sand": ["res://audio/sfx/place_dirt_02.wav", "res://audio/sfx/place_dirt_03.wav"],
		&"stone": ["res://audio/sfx/place_stone_01.wav", "res://audio/sfx/place_stone_02.wav", "res://audio/sfx/place_stone_03.wav"],
		&"wood": ["res://audio/sfx/place_wood_01.wav", "res://audio/sfx/place_wood_02.wav", "res://audio/sfx/place_wood_03.wav"],
		&"metal": ["res://audio/sfx/place_metal_01.wav", "res://audio/sfx/place_metal_02.wav", "res://audio/sfx/place_metal_03.wav"],
		&"ore": ["res://audio/sfx/place_metal_01.wav", "res://audio/sfx/place_stone_02.wav"],
		&"grass": ["res://audio/sfx/place_dirt_01.wav", "res://audio/sfx/place_dirt_03.wav"],
	},
}

const PLAYER_FOR_EVENT := {
	&"Footstep": &"Footstep",
	&"Jump": &"Jump",
	&"Land": &"Land",
	&"Swing": &"Swing",
	&"SwordSwing": &"Swing",
	&"SpearThrust": &"Swing",
	&"LanternSwing": &"Swing",
	&"BowDraw": &"BowDraw",
	&"BowRelease": &"BowRelease",
	&"Hit": &"Hit",
	&"LanternHit": &"Hit",
	&"ArrowImpact": &"Hit",
	&"MineHit": &"MineHit",
	&"BlockBreak": &"BlockBreak",
	&"BlockPlace": &"BlockPlace",
	&"Pickup": &"Pickup",
	&"UiOpen": &"Ui",
	&"UiClose": &"Ui",
	&"UiClick": &"Ui",
	&"UiTab": &"Ui",
	&"UiCraftOk": &"Ui",
	&"UiCraftFail": &"Ui",
}

const UI_EVENTS := {
	&"UiOpen": true,
	&"UiClose": true,
	&"UiClick": true,
	&"UiTab": true,
	&"UiCraftOk": true,
	&"UiCraftFail": true,
}


func _ready() -> void:
	for child in get_children():
		var player := child as AudioStreamPlayer
		if player != null:
			_base_volume_db[player.name] = player.volume_db
	_ensure_player(&"Land", &"SFX", -9.0)
	_ensure_player(&"Hit", &"SFX", -8.0)
	_ensure_player(&"BowDraw", &"SFX", -14.0)
	_ensure_player(&"BowRelease", &"SFX", -11.0)
	_ensure_player(&"Ui", &"UI", -10.0)


func play(sound: StringName, volume_offset_db: float = 0.0, material: StringName = &"") -> void:
	var player := _player_for(sound)
	if player == null:
		return
	var stream := _pick_stream(sound, material)
	if stream == null:
		if player.stream == null:
			return
	else:
		player.stream = stream
	player.volume_db = float(_base_volume_db.get(player.name, 0.0)) + volume_offset_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()


func play_weapon_swing(kind: int) -> void:
	match kind:
		ItemData.WeaponKind.SWORD:
			play(&"SwordSwing")
		ItemData.WeaponKind.SPEAR:
			play(&"SpearThrust")
		ItemData.WeaponKind.LANTERN:
			play(&"LanternSwing", -2.0)
		ItemData.WeaponKind.BOW:
			play(&"BowRelease")
		_:
			play(&"Swing")


func play_hit(kind: int = ItemData.WeaponKind.NONE, darkness_bonus: bool = false) -> void:
	if kind == ItemData.WeaponKind.LANTERN:
		play(&"LanternHit", -4.0 if not darkness_bonus else 0.0)
	else:
		play(&"Hit")


func _player_for(sound: StringName) -> AudioStreamPlayer:
	var named: StringName = PLAYER_FOR_EVENT.get(sound, sound)
	var player := get_node_or_null(NodePath(String(named))) as AudioStreamPlayer
	if player != null:
		if bool(UI_EVENTS.get(sound, false)):
			player.bus = &"UI"
		# overlapping one-shots of the same category use a short pool
		if player.playing and sound != &"Footstep" and sound != &"BowDraw":
			return _borrow_player(player)
		return player
	player = get_node_or_null(NodePath(String(sound))) as AudioStreamPlayer
	if player != null:
		return player
	return _borrow_player(null)


func _borrow_player(template: AudioStreamPlayer) -> AudioStreamPlayer:
	for extra in _pool:
		if extra != null and not extra.playing:
			if template != null:
				extra.bus = template.bus
				extra.volume_db = template.volume_db
			return extra
	var spawned := AudioStreamPlayer.new()
	spawned.name = "PooledSfx%d" % (_pool.size() + 1)
	spawned.bus = template.bus if template != null else &"SFX"
	add_child(spawned)
	_pool.append(spawned)
	_base_volume_db[spawned.name] = float(_base_volume_db.get(template.name, 0.0)) if template != null else 0.0
	return spawned


func _ensure_player(node_name: StringName, bus: StringName, volume_db: float) -> void:
	if get_node_or_null(NodePath(String(node_name))) != null:
		return
	var player := AudioStreamPlayer.new()
	player.name = String(node_name)
	player.bus = bus
	player.volume_db = volume_db
	add_child(player)
	_base_volume_db[player.name] = volume_db


func _pick_stream(sound: StringName, material: StringName) -> AudioStream:
	var paths: Array = []
	if material != &"" and MATERIAL_STREAMS.has(sound):
		var by_mat: Dictionary = MATERIAL_STREAMS[sound]
		if by_mat.has(material):
			paths = by_mat[material]
	if paths.is_empty() and EVENT_STREAMS.has(sound):
		paths = EVENT_STREAMS[sound]
	if paths.is_empty():
		return null
	var key := "%s:%s" % [String(sound), String(material)]
	var last := str(_last_path.get(key, ""))
	var choices: Array = []
	for path in paths:
		if str(path) != last or paths.size() == 1:
			choices.append(path)
	if choices.is_empty():
		choices = paths
	var chosen := str(choices[randi() % choices.size()])
	_last_path[key] = chosen
	return _load_stream(chosen)


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream != null:
		_stream_cache[path] = stream
	return stream
