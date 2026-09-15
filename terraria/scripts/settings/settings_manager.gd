extends Node

## Autoload. Eine Quelle fuer Grafik, Audio, Spiel und Tastenbelegung.
## User-Daten liegen in user://settings.cfg, nie in res://.

signal settings_applied
signal ui_scale_changed(scale: float)
signal display_revert_started(seconds_left: int)
signal display_revert_tick(seconds_left: int)
signal display_confirmed
signal display_reverted

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_VERSION := 1
const DISPLAY_CONFIRM_SECONDS := 15

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"

enum WindowMode {
	WINDOWED = 0,
	BORDERLESS = 1,
	EXCLUSIVE = 2,
}

const RESOLUTIONS: Array[Dictionary] = [
	{"id": "720p", "label": "HD / 720p (1280 × 720)", "size": Vector2i(1280, 720)},
	{"id": "1080p", "label": "Full HD / 1080p (1920 × 1080)", "size": Vector2i(1920, 1080)},
	{"id": "1440p", "label": "QHD / 1440p (2560 × 1440)", "size": Vector2i(2560, 1440)},
	{"id": "4k", "label": "4K / UHD (3840 × 2160)", "size": Vector2i(3840, 2160)},
]

const FPS_LIMITS: Array[int] = [30, 60, 120, 144, 165, 240, 0]
const UI_SCALES: Array[int] = [75, 100, 125, 150]

const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"sprint",
	&"crouch",
	&"inventory",
	&"world_map",
	&"toggle_minimap",
	&"use_item",
	&"interact_secondary",
	&"block_autolock",
	&"hotbar_1",
	&"hotbar_2",
	&"hotbar_3",
	&"hotbar_4",
	&"hotbar_5",
	&"hotbar_6",
	&"hotbar_7",
	&"hotbar_8",
	&"hotbar_9",
	&"hotbar_10",
	&"zoom_in",
	&"zoom_out",
	&"map_center",
]

const ACTION_LABELS := {
	&"move_left": "Bewegen Links",
	&"move_right": "Bewegen Rechts",
	&"jump": "Springen",
	&"sprint": "Sprinten",
	&"crouch": "Ducken",
	&"inventory": "Inventar",
	&"world_map": "Weltkarte",
	&"toggle_minimap": "Minimap",
	&"use_item": "Angriff / Abbauen",
	&"interact_secondary": "Platzieren",
	&"block_autolock": "Autolock",
	&"hotbar_1": "Hotbar 1",
	&"hotbar_2": "Hotbar 2",
	&"hotbar_3": "Hotbar 3",
	&"hotbar_4": "Hotbar 4",
	&"hotbar_5": "Hotbar 5",
	&"hotbar_6": "Hotbar 6",
	&"hotbar_7": "Hotbar 7",
	&"hotbar_8": "Hotbar 8",
	&"hotbar_9": "Hotbar 9",
	&"hotbar_10": "Hotbar 10",
	&"zoom_in": "Zoom In",
	&"zoom_out": "Zoom Out",
	&"map_center": "Karte zentrieren",
}

var graphics: Dictionary = {}
var audio: Dictionary = {}
var game: Dictionary = {}
var controls: Dictionary = {}

var _factory_controls: Dictionary = {}
var _pending_display: Dictionary = {}
var _backup_display: Dictionary = {}
var _display_confirm_left: float = 0.0
var _display_confirm_active: bool = false
var _paused_by_focus: bool = false
var _menu_pause_active: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_factory_controls = _capture_input_map()
	_reset_to_defaults()
	_load_from_disk()
	_apply_all(false)


func _process(delta: float) -> void:
	if _display_confirm_active:
		var before := int(ceilf(_display_confirm_left))
		_display_confirm_left = maxf(0.0, _display_confirm_left - delta)
		var after := int(ceilf(_display_confirm_left))
		if after != before:
			display_revert_tick.emit(after)
		if _display_confirm_left <= 0.0:
			revert_display_settings()
	_update_focus_pause()


func get_defaults() -> Dictionary:
	return {
		"graphics": _default_graphics(),
		"audio": _default_audio(),
		"game": _default_game(),
	}


func duplicate_current() -> Dictionary:
	return {
		"graphics": graphics.duplicate(true),
		"audio": audio.duplicate(true),
		"game": game.duplicate(true),
		"controls": controls.duplicate(true),
	}


func apply_draft(draft: Dictionary, persist_non_display: bool = true) -> bool:
	var prev_graphics: Dictionary = graphics.duplicate(true)
	if draft.has("audio"):
		audio = _sanitize_audio(draft["audio"])
		_apply_audio()
	if draft.has("game"):
		game = _sanitize_game(draft["game"])
		_apply_game()
	if draft.has("controls"):
		controls = _sanitize_controls(draft["controls"])
		_apply_controls()
	var display_changed := false
	if draft.has("graphics"):
		var next_graphics := _sanitize_graphics(draft["graphics"])
		display_changed = _display_differs(prev_graphics, next_graphics)
		if display_changed:
			_backup_display = prev_graphics.duplicate(true)
			graphics = next_graphics
			_apply_graphics()
			_begin_display_confirm()
		else:
			graphics = next_graphics
			_apply_graphics()
			ui_scale_changed.emit(get_ui_scale())
	if persist_non_display:
		_save_to_disk(not _display_confirm_active)
	settings_applied.emit()
	return display_changed


func confirm_display_settings() -> void:
	if not _display_confirm_active:
		return
	_display_confirm_active = false
	_display_confirm_left = 0.0
	_backup_display.clear()
	_save_to_disk(true)
	display_confirmed.emit()


func revert_display_settings() -> void:
	if not _display_confirm_active and _backup_display.is_empty():
		return
	_display_confirm_active = false
	_display_confirm_left = 0.0
	if not _backup_display.is_empty():
		graphics = _sanitize_graphics(_backup_display)
	_backup_display.clear()
	_apply_graphics()
	ui_scale_changed.emit(get_ui_scale())
	_save_to_disk(true)
	display_reverted.emit()


func is_display_confirm_active() -> bool:
	return _display_confirm_active


func get_display_confirm_seconds() -> int:
	return int(ceilf(_display_confirm_left))


func reset_controls_to_defaults() -> void:
	controls = _factory_controls.duplicate(true)
	_apply_controls()


func get_ui_scale() -> float:
	return clampf(float(graphics.get("ui_scale", 100)) / 100.0, 0.5, 2.0)


func set_menu_pause(active: bool) -> void:
	_menu_pause_active = active
	if active:
		_paused_by_focus = false
		get_tree().paused = true
	elif not _paused_by_focus:
		get_tree().paused = false


func is_menu_pause_active() -> bool:
	return _menu_pause_active


func is_gameplay_blocked() -> bool:
	return _menu_pause_active or get_tree().paused


func volume_to_db(linear: float) -> float:
	var value := clampf(linear, 0.0, 1.0)
	if value <= 0.0001:
		return -80.0
	return linear_to_db(value)


func preview_audio(draft_audio: Dictionary) -> void:
	_apply_audio_dict(_sanitize_audio(draft_audio))


func restore_applied_audio() -> void:
	_apply_audio()


func get_factory_controls() -> Dictionary:
	return _factory_controls.duplicate(true)


func preview_controls(data: Dictionary) -> void:
	var previous := controls
	controls = _sanitize_controls(data)
	_apply_controls()
	controls = previous


func serialize_event(event: InputEvent) -> Dictionary:
	return _serialize_event(event)


func restore_applied_controls() -> void:
	_apply_controls()


func find_binding_conflict(action: StringName, event: InputEvent) -> StringName:
	if event == null:
		return &""
	for other in REBINDABLE_ACTIONS:
		if other == action:
			continue
		if not InputMap.has_action(other):
			continue
		for existing in InputMap.action_get_events(other):
			if _events_equal(existing, event):
				return other
	return &""


func event_to_text(event: InputEvent) -> String:
	if event == null:
		return "—"
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if code == KEY_NONE:
			return "—"
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Maus Links"
			MOUSE_BUTTON_RIGHT:
				return "Maus Rechts"
			MOUSE_BUTTON_MIDDLE:
				return "Maus Mitte"
			MOUSE_BUTTON_XBUTTON1:
				return "Maus 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Maus 5"
			_:
				return "Maus %d" % (event as InputEventMouseButton).button_index
	return event.as_text()


func primary_event_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return event_to_text(events[0])


func resolution_index_for(size: Vector2i) -> int:
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i]["size"] == size:
			return i
	return 1


func fps_index_for(limit: int) -> int:
	var idx := FPS_LIMITS.find(limit)
	return idx if idx >= 0 else 1


func ui_scale_index_for(percent: int) -> int:
	var idx := UI_SCALES.find(percent)
	return idx if idx >= 0 else 1


func _reset_to_defaults() -> void:
	graphics = _default_graphics()
	audio = _default_audio()
	game = _default_game()
	controls = _factory_controls.duplicate(true)


func _default_graphics() -> Dictionary:
	return {
		"resolution": Vector2i(1920, 1080),
		"window_mode": WindowMode.WINDOWED,
		"vsync": true,
		"fps_limit": 60,
		"ui_scale": 100,
	}


func _default_audio() -> Dictionary:
	return {
		"master": 1.0,
		"music": 1.0,
		"sfx": 1.0,
		"ui": 1.0,
		"master_mute": false,
		"music_mute": false,
		"sfx_mute": false,
		"ui_mute": false,
	}


func _default_game() -> Dictionary:
	return {
		"pause_when_unfocused": true,
		"show_fps": false,
	}


func _load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_save_to_disk(true)
		return
	var version := int(cfg.get_value("meta", "settings_version", 1))
	if version < 1:
		version = 1
	graphics = _sanitize_graphics({
		"resolution": Vector2i(
			int(cfg.get_value("graphics", "resolution_width", 1920)),
			int(cfg.get_value("graphics", "resolution_height", 1080))
		),
		"window_mode": int(cfg.get_value("graphics", "window_mode", WindowMode.WINDOWED)),
		"vsync": bool(cfg.get_value("graphics", "vsync", true)),
		"fps_limit": int(cfg.get_value("graphics", "fps_limit", 60)),
		"ui_scale": int(cfg.get_value("graphics", "ui_scale", 100)),
	})
	audio = _sanitize_audio({
		"master": float(cfg.get_value("audio", "master", 1.0)),
		"music": float(cfg.get_value("audio", "music", 1.0)),
		"sfx": float(cfg.get_value("audio", "sfx", 1.0)),
		"ui": float(cfg.get_value("audio", "ui", 1.0)),
		"master_mute": bool(cfg.get_value("audio", "master_mute", false)),
		"music_mute": bool(cfg.get_value("audio", "music_mute", false)),
		"sfx_mute": bool(cfg.get_value("audio", "sfx_mute", false)),
		"ui_mute": bool(cfg.get_value("audio", "ui_mute", false)),
	})
	game = _sanitize_game({
		"pause_when_unfocused": bool(cfg.get_value("game", "pause_when_unfocused", true)),
		"show_fps": bool(cfg.get_value("game", "show_fps", false)),
	})
	if cfg.has_section_key("controls", "bindings"):
		var parsed: Variant = JSON.parse_string(str(cfg.get_value("controls", "bindings", "")))
		if parsed is Dictionary:
			controls = _sanitize_controls(parsed)
		else:
			controls = _factory_controls.duplicate(true)
	else:
		controls = _factory_controls.duplicate(true)


func _save_to_disk(include_display: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("meta", "settings_version", SETTINGS_VERSION)
	var gfx: Dictionary = graphics if include_display else (
		_backup_display if not _backup_display.is_empty() else graphics
	)
	var res: Vector2i = gfx.get("resolution", Vector2i(1920, 1080))
	cfg.set_value("graphics", "resolution_width", res.x)
	cfg.set_value("graphics", "resolution_height", res.y)
	cfg.set_value("graphics", "window_mode", int(gfx.get("window_mode", WindowMode.WINDOWED)))
	cfg.set_value("graphics", "vsync", bool(gfx.get("vsync", true)))
	cfg.set_value("graphics", "fps_limit", int(gfx.get("fps_limit", 60)))
	cfg.set_value("graphics", "ui_scale", int(gfx.get("ui_scale", 100)))
	cfg.set_value("audio", "master", float(audio.get("master", 1.0)))
	cfg.set_value("audio", "music", float(audio.get("music", 1.0)))
	cfg.set_value("audio", "sfx", float(audio.get("sfx", 1.0)))
	cfg.set_value("audio", "ui", float(audio.get("ui", 1.0)))
	cfg.set_value("audio", "master_mute", bool(audio.get("master_mute", false)))
	cfg.set_value("audio", "music_mute", bool(audio.get("music_mute", false)))
	cfg.set_value("audio", "sfx_mute", bool(audio.get("sfx_mute", false)))
	cfg.set_value("audio", "ui_mute", bool(audio.get("ui_mute", false)))
	cfg.set_value("game", "pause_when_unfocused", bool(game.get("pause_when_unfocused", true)))
	cfg.set_value("game", "show_fps", bool(game.get("show_fps", false)))
	cfg.set_value("controls", "bindings", JSON.stringify(controls))
	cfg.save(SETTINGS_PATH)


func _apply_all(_unused: bool = false) -> void:
	_apply_graphics()
	_apply_audio()
	_apply_game()
	_apply_controls()
	ui_scale_changed.emit(get_ui_scale())
	settings_applied.emit()


func _apply_graphics() -> void:
	var win := get_window()
	if win == null:
		return
	var mode := int(graphics.get("window_mode", WindowMode.WINDOWED))
	var requested: Vector2i = graphics.get("resolution", Vector2i(1920, 1080))
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		screen = requested
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if bool(graphics.get("vsync", true)) else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = int(graphics.get("fps_limit", 60))
	match mode:
		WindowMode.BORDERLESS:
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			win.size = screen
			win.position = DisplayServer.screen_get_position()
			win.mode = Window.MODE_FULLSCREEN
		WindowMode.EXCLUSIVE:
			win.borderless = false
			var exclusive_size := _safe_resolution(requested, screen)
			win.mode = Window.MODE_WINDOWED
			win.size = exclusive_size
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
			var windowed := _safe_resolution(requested, screen)
			win.size = windowed
			_center_window(win, windowed, screen)


func _safe_resolution(requested: Vector2i, screen: Vector2i) -> Vector2i:
	var allowed: Array[Vector2i] = []
	for spec in RESOLUTIONS:
		var size: Vector2i = spec["size"]
		if size.x <= screen.x and size.y <= screen.y:
			allowed.append(size)
	if allowed.is_empty():
		return Vector2i(mini(requested.x, screen.x), mini(requested.y, screen.y))
	for candidate in allowed:
		if candidate == requested:
			return requested
	return allowed[allowed.size() - 1]


func _center_window(win: Window, size: Vector2i, screen: Vector2i) -> void:
	var origin := DisplayServer.screen_get_position()
	win.position = origin + Vector2i(
		maxi(0, int((screen.x - size.x) * 0.5)),
		maxi(0, int((screen.y - size.y) * 0.5))
	)


func _apply_audio() -> void:
	_apply_audio_dict(audio)


func _apply_audio_dict(data: Dictionary) -> void:
	_set_bus_volume(BUS_MASTER, float(data.get("master", 1.0)), bool(data.get("master_mute", false)))
	_set_bus_volume(BUS_MUSIC, float(data.get("music", 1.0)), bool(data.get("music_mute", false)))
	_set_bus_volume(BUS_SFX, float(data.get("sfx", 1.0)), bool(data.get("sfx_mute", false)))
	_set_bus_volume(BUS_UI, float(data.get("ui", 1.0)), bool(data.get("ui_mute", false)))


func _set_bus_volume(bus_name: String, linear: float, muted: bool) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, muted or value <= 0.0001)
	AudioServer.set_bus_volume_db(idx, volume_to_db(value))


func _apply_game() -> void:
	if not bool(game.get("pause_when_unfocused", true)) and _paused_by_focus and not _menu_pause_active:
		_paused_by_focus = false
		get_tree().paused = false


func _apply_controls() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		var packed: Variant = controls.get(String(action), [])
		if packed is Array:
			for item in packed:
				var event := _deserialize_event(item)
				if event != null:
					InputMap.action_add_event(action, event)


func _capture_input_map() -> Dictionary:
	var data := {}
	for action in REBINDABLE_ACTIONS:
		var list: Array = []
		if InputMap.has_action(action):
			for event in InputMap.action_get_events(action):
				var serialized := _serialize_event(event)
				if not serialized.is_empty():
					list.append(serialized)
		data[String(action)] = list
	return data


func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		return {
			"type": "key",
			"keycode": int(key.keycode),
			"physical_keycode": int(key.physical_keycode),
			"shift": key.shift_pressed,
			"alt": key.alt_pressed,
			"ctrl": key.ctrl_pressed,
			"meta": key.meta_pressed,
		}
	if event is InputEventMouseButton:
		return {
			"type": "mouse",
			"button": int((event as InputEventMouseButton).button_index),
		}
	return {}


func _deserialize_event(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var dict: Dictionary = data
	match str(dict.get("type", "")):
		"key":
			var key := InputEventKey.new()
			key.keycode = int(dict.get("keycode", 0)) as Key
			key.physical_keycode = int(dict.get("physical_keycode", 0)) as Key
			key.shift_pressed = bool(dict.get("shift", false))
			key.alt_pressed = bool(dict.get("alt", false))
			key.ctrl_pressed = bool(dict.get("ctrl", false))
			key.meta_pressed = bool(dict.get("meta", false))
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(dict.get("button", 1)) as MouseButton
			return mouse
	return null


func _sanitize_graphics(data: Dictionary) -> Dictionary:
	var fallback := _default_graphics()
	var res: Vector2i = fallback["resolution"]
	if data.get("resolution") is Vector2i:
		res = data["resolution"]
	elif data.get("resolution") is Dictionary:
		res = Vector2i(int(data["resolution"].get("x", 1920)), int(data["resolution"].get("y", 1080)))
	var known := false
	for spec in RESOLUTIONS:
		if spec["size"] == res:
			known = true
			break
	if not known:
		res = Vector2i(1920, 1080)
	var mode := int(data.get("window_mode", WindowMode.WINDOWED))
	if mode < WindowMode.WINDOWED or mode > WindowMode.EXCLUSIVE:
		mode = WindowMode.WINDOWED
	var fps := int(data.get("fps_limit", 60))
	if FPS_LIMITS.find(fps) < 0:
		fps = 60
	var scale := int(data.get("ui_scale", 100))
	if UI_SCALES.find(scale) < 0:
		scale = 100
	return {
		"resolution": res,
		"window_mode": mode,
		"vsync": bool(data.get("vsync", true)),
		"fps_limit": fps,
		"ui_scale": scale,
	}


func _sanitize_audio(data: Dictionary) -> Dictionary:
	return {
		"master": clampf(float(data.get("master", 1.0)), 0.0, 1.0),
		"music": clampf(float(data.get("music", 1.0)), 0.0, 1.0),
		"sfx": clampf(float(data.get("sfx", 1.0)), 0.0, 1.0),
		"ui": clampf(float(data.get("ui", 1.0)), 0.0, 1.0),
		"master_mute": bool(data.get("master_mute", false)),
		"music_mute": bool(data.get("music_mute", false)),
		"sfx_mute": bool(data.get("sfx_mute", false)),
		"ui_mute": bool(data.get("ui_mute", false)),
	}


func _sanitize_game(data: Dictionary) -> Dictionary:
	return {
		"pause_when_unfocused": bool(data.get("pause_when_unfocused", true)),
		"show_fps": bool(data.get("show_fps", false)),
	}


func is_show_fps() -> bool:
	return bool(game.get("show_fps", false))


func _sanitize_controls(data: Dictionary) -> Dictionary:
	var clean := _factory_controls.duplicate(true)
	for action in REBINDABLE_ACTIONS:
		var key := String(action)
		if data.has(key) and data[key] is Array:
			var list: Array = []
			for item in data[key]:
				if _deserialize_event(item) != null:
					list.append(item)
			if not list.is_empty():
				clean[key] = list
	return clean


func _display_differs(a: Dictionary, b: Dictionary) -> bool:
	return a.get("resolution") != b.get("resolution") \
		or int(a.get("window_mode", 0)) != int(b.get("window_mode", 0))


func _begin_display_confirm() -> void:
	_display_confirm_active = true
	_display_confirm_left = float(DISPLAY_CONFIRM_SECONDS)
	display_revert_started.emit(DISPLAY_CONFIRM_SECONDS)


func _events_equal(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var a_code := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var b_code := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return a_code == b_code \
			and ka.shift_pressed == kb.shift_pressed \
			and ka.alt_pressed == kb.alt_pressed \
			and ka.ctrl_pressed == kb.ctrl_pressed \
			and ka.meta_pressed == kb.meta_pressed
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


func _update_focus_pause() -> void:
	if _menu_pause_active:
		return
	if not bool(game.get("pause_when_unfocused", true)):
		if _paused_by_focus:
			_paused_by_focus = false
			get_tree().paused = false
		return
	var focused := DisplayServer.window_is_focused()
	if not focused and not get_tree().paused:
		_paused_by_focus = true
		get_tree().paused = true
	elif focused and _paused_by_focus:
		_paused_by_focus = false
		get_tree().paused = false
