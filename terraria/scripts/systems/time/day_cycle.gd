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
	return time_of_day >= settings.night_start_time


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
	var sky_day := Color(0.49, 0.78, 0.91, 1)
	var sky_dusk := Color(0.72, 0.38, 0.28, 1)
	var sky_night := Color(0.05, 0.07, 0.14, 1)
	var sky_dawn := Color(0.62, 0.55, 0.48, 1)
	var mod_day := Color(1, 1, 1, 1)
	var mod_dusk := Color(0.92, 0.68, 0.55, 1)
	var mod_night := Color(0.22, 0.28, 0.48, 1)
	var mod_dawn := Color(0.78, 0.72, 0.68, 1)
	var sky: Color
	var modulate: Color
	if t < 0.18:
		var u := t / 0.18
		sky = sky_dawn.lerp(sky_day, u)
		modulate = mod_dawn.lerp(mod_day, u)
	elif t < 0.58:
		sky = sky_day
		modulate = mod_day
	elif t < 0.75:
		var u := (t - 0.58) / 0.17
		sky = sky_day.lerp(sky_dusk, u)
		modulate = mod_day.lerp(mod_dusk, u)
	else:
		var u := clampf((t - 0.75) / 0.25, 0.0, 1.0)
		sky = sky_dusk.lerp(sky_night, u)
		modulate = mod_dusk.lerp(mod_night, u)
	return {"sky": sky, "modulate": modulate}


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
