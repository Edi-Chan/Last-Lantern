class_name DayCycle
extends Node

## Gehoert an: Main/DayCycle. Fortlaufender Tag-/Nachtzyklus, pausiert mit dem Spielbaum.

signal day_started(day: int)
signal night_started(day: int)
signal day_changed(day: int)
signal time_changed(day: int, time_of_day: float, is_night: bool)

@export var settings: LastLanternSettings

var current_day: int = 1
var time_of_day: float = 0.25
var is_night: bool = false

var _last_emitted_minute: int = -1
var _modulate: CanvasModulate
var _sky: ColorRect


func _ready() -> void:
	add_to_group("day_cycle")
	process_mode = Node.PROCESS_MODE_INHERIT
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	_modulate = get_tree().get_first_node_in_group("world_modulate") as CanvasModulate
	_sky = get_tree().get_first_node_in_group("world_sky") as ColorRect
	_apply_visuals()
	call_deferred("_emit_initial")


func _emit_initial() -> void:
	is_night = _compute_night()
	day_started.emit(current_day)
	time_changed.emit(current_day, time_of_day, is_night)
	_last_emitted_minute = clock_minutes()


func _process(delta: float) -> void:
	if settings == null:
		return
	var advance := delta * maxf(settings.time_scale, 0.0)
	if advance <= 0.0:
		return
	var night_start := settings.night_start_time
	var was_night := is_night
	var old_day := current_day
	if time_of_day < night_start:
		var day_span := maxf(night_start, 0.001)
		time_of_day += advance * day_span / maxf(settings.day_duration, 0.001)
		if time_of_day >= night_start:
			time_of_day = night_start
	else:
		var night_span := maxf(1.0 - night_start, 0.001)
		time_of_day += advance * night_span / maxf(settings.night_duration, 0.001)
		if time_of_day >= 1.0:
			time_of_day -= 1.0
			current_day += 1
	is_night = _compute_night()
	if current_day != old_day:
		day_changed.emit(current_day)
		day_started.emit(current_day)
	if is_night and not was_night:
		night_started.emit(current_day)
	_apply_visuals()
	_maybe_emit_time()


func _compute_night() -> bool:
	if settings == null:
		return false
	var t := time_of_day
	return t >= settings.night_start_time or t < settings.night_end_time


func _maybe_emit_time() -> void:
	var minute := clock_minutes()
	if minute == _last_emitted_minute:
		return
	_last_emitted_minute = minute
	time_changed.emit(current_day, time_of_day, is_night)


func _apply_visuals() -> void:
	var sample := _sample_light(time_of_day)
	if _modulate != null:
		_modulate.color = sample["modulate"]
	if _sky != null:
		_sky.color = sample["sky"]
	RenderingServer.set_default_clear_color(sample["sky"])


func _sample_light(t: float) -> Dictionary:
	var night_start := 0.75
	var night_end := 0.25
	if settings != null:
		night_start = settings.night_start_time
		night_end = settings.night_end_time
	var sky_day := Color(0.49, 0.78, 0.91, 1)
	var sky_dusk := Color(0.78, 0.40, 0.38, 1)
	var sky_night := Color(0.05, 0.07, 0.14, 1)
	var sky_dawn := Color(0.60, 0.68, 0.82, 1)
	var mod_day := Color(1, 1, 1, 1)
	var mod_dusk := Color(0.94, 0.66, 0.52, 1)
	var mod_night := Color(0.22, 0.28, 0.48, 1)
	var mod_dawn := Color(0.82, 0.74, 0.68, 1)
	var sky: Color
	var modulate: Color
	if t >= night_start:
		var u := clampf((t - night_start) / maxf(1.0 - night_start, 0.001), 0.0, 1.0)
		sky = sky_dusk.lerp(sky_night, u)
		modulate = mod_dusk.lerp(mod_night, u)
	elif t < 0.18:
		# 00:00 bleibt Nacht, nicht Morgengrauen. Frueher: t=0 war Dawn und die Laterne blitzte.
		var u := t / 0.18
		sky = sky_night.lerp(sky_dawn, u * 0.12)
		modulate = mod_night.lerp(mod_dawn, u * 0.10)
	elif t < night_end:
		var u := (t - 0.18) / maxf(night_end - 0.18, 0.001)
		sky = sky_night.lerp(sky_dawn, 0.12).lerp(sky_day, u)
		modulate = mod_night.lerp(mod_dawn, 0.10).lerp(mod_day, u)
	elif t < 0.58:
		sky = sky_day
		modulate = mod_day
	else:
		var u := (t - 0.58) / maxf(night_start - 0.58, 0.001)
		sky = sky_day.lerp(sky_dusk, u)
		modulate = mod_day.lerp(mod_dusk, u)
	return {"sky": sky, "modulate": modulate}


func sun_visibility() -> float:
	return sun_visibility_at(time_of_day)


func moon_visibility() -> float:
	return moon_visibility_at(time_of_day)


func star_visibility() -> float:
	return star_visibility_at(time_of_day)


func sun_path() -> float:
	return _path_in_window(time_of_day, _night_end(), _night_start())


func moon_path() -> float:
	return _path_in_window(time_of_day, _night_start(), _night_end() + 1.0)


func dusk_amount() -> float:
	var t := time_of_day
	var night_start := _night_start()
	if t >= 0.58 and t < night_start:
		return clampf((t - 0.58) / maxf(night_start - 0.58, 0.001), 0.0, 1.0)
	if t >= night_start:
		return 1.0
	if t < 0.18:
		return 0.0
	if t < _night_end():
		return 1.0 - clampf((t - 0.18) / maxf(_night_end() - 0.18, 0.001), 0.0, 1.0)
	return 0.0


func sun_visibility_at(t: float) -> float:
	var ns := _night_start()
	var ne := _night_end()
	if t >= ns or t < ne:
		return 0.0
	var fade := 0.045
	var from_dawn := t - ne
	var to_dusk := ns - t
	return clampf(minf(from_dawn, to_dusk) / fade, 0.0, 1.0)


func moon_visibility_at(t: float) -> float:
	var ns := _night_start()
	var ne := _night_end()
	if t >= ns:
		return clampf((t - ns) / 0.05, 0.0, 1.0)
	if t < ne:
		return clampf((ne - t) / 0.05, 0.0, 1.0)
	return 0.0


func star_visibility_at(t: float) -> float:
	var ns := _night_start()
	var ne := _night_end()
	if t >= 0.62:
		return clampf((t - 0.62) / maxf(ns + 0.04 - 0.62, 0.001), 0.0, 1.0)
	if t < 0.16:
		return 1.0
	if t < ne:
		return 1.0 - clampf((t - 0.16) / maxf(ne - 0.16, 0.001), 0.0, 1.0)
	return 0.0


func _night_start() -> float:
	if settings == null:
		return 0.75
	return settings.night_start_time


func _night_end() -> float:
	if settings == null:
		return 0.25
	return settings.night_end_time


func _window_alpha(t: float, start: float, end: float, fade: float) -> float:
	if end <= start:
		end += 1.0
	var x := t
	if x < start:
		x += 1.0
	if x < start or x > end:
		return 0.0
	var into := x - start
	var out := end - x
	return clampf(minf(into, out) / maxf(fade, 0.001), 0.0, 1.0)


func _path_in_window(t: float, start: float, end: float) -> float:
	if end <= start:
		end += 1.0
	var x := t
	if x < start:
		x += 1.0
	return clampf((x - start) / maxf(end - start, 0.001), 0.0, 1.0)


func clock_minutes() -> int:
	return int(round(time_of_day * 24.0 * 60.0)) % (24 * 60)


func clock_text() -> String:
	var total := clock_minutes()
	return "%02d:%02d" % [total / 60, total % 60]


func seconds_until_night() -> float:
	if settings == null or is_night:
		return 0.0
	var remaining := settings.night_start_time - time_of_day
	return remaining / maxf(settings.night_start_time, 0.001) * settings.day_duration


func set_day_and_time(day: int, time_value: float) -> void:
	var old_day := current_day
	current_day = maxi(day, 1)
	time_of_day = clampf(time_value, 0.0, 0.999)
	is_night = _compute_night()
	_apply_visuals()
	_last_emitted_minute = -1
	if current_day != old_day:
		day_changed.emit(current_day)
		day_started.emit(current_day)
	if is_night:
		night_started.emit(current_day)
	time_changed.emit(current_day, time_of_day, is_night)


func to_save_dict() -> Dictionary:
	return {
		"current_day": current_day,
		"time_of_day": time_of_day,
	}


func from_save_dict(data: Dictionary) -> void:
	set_day_and_time(int(data.get("current_day", 1)), float(data.get("time_of_day", 0.22)))
