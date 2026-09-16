class_name FogEvent
extends Node

## Gehoert an: Main/FogEvent. 7-Tage-Nebel, Schaden nur ausserhalb aktiver SafeZones.

signal fog_warning_started(day: int, cycle: int)
signal fog_started(day: int, cycle: int)
signal fog_ending(day: int, cycle: int)
signal fog_ended(day: int, cycle: int)
signal fog_damage_applied(amount: float)
signal state_changed(state: int)

enum State {
	CLEAR,
	WARNING,
	FOG_ACTIVE,
	FOG_ENDING,
}

const DAMAGE_TYPE := &"fog"

@export var settings: LastLanternSettings

var state: int = State.CLEAR
var fog_cycle: int = 0
var player_is_safe: bool = true

var _day_cycle: DayCycle
var _player: Player
var _tick_left: float = 0.0
var _unsafe_time: float = 0.0
var _fog_elapsed: float = 0.0
var _ending_left: float = 0.0
var _event_day: int = -1
var _fog_done_for_day: int = -1
var _warning_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group("fog_event")
	process_mode = Node.PROCESS_MODE_INHERIT
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	_warning_player = get_node_or_null("WarningSound") as AudioStreamPlayer
	_thunder_player = get_node_or_null("ThunderSound") as AudioStreamPlayer
	_wind_player = get_node_or_null("WindSound") as AudioStreamPlayer
	call_deferred("_bind")


func _bind() -> void:
	_day_cycle = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	_player = get_tree().get_first_node_in_group("player") as Player
	if _day_cycle == null:
		return
	if not _day_cycle.time_changed.is_connected(_on_time_changed):
		_day_cycle.time_changed.connect(_on_time_changed)
	if not _day_cycle.night_started.is_connected(_on_night_started):
		_day_cycle.night_started.connect(_on_night_started)
	if not _day_cycle.day_changed.is_connected(_on_day_changed):
		_day_cycle.day_changed.connect(_on_day_changed)


func _process(delta: float) -> void:
	if settings == null or _day_cycle == null:
		return
	_update_state_from_time()
	if state == State.FOG_ACTIVE:
		_fog_elapsed += delta
		if _fog_elapsed >= settings.fog_duration_seconds(fog_cycle):
			_begin_ending()
	elif state == State.FOG_ENDING:
		_ending_left -= delta
		if _ending_left <= 0.0:
			_finish_clear()
	_tick_damage(delta)


func _update_state_from_time() -> void:
	var day := _day_cycle.current_day
	if not settings.is_fog_day(day):
		return
	if _fog_done_for_day == day:
		return
	if state == State.FOG_ACTIVE or state == State.FOG_ENDING:
		return
	if _should_start_warning(day) and state == State.CLEAR:
		_begin_warning(day)
	if _should_start_fog(day) and (state == State.WARNING or state == State.CLEAR):
		_begin_fog(day)


func _should_start_warning(day: int) -> bool:
	if not settings.is_fog_day(day):
		return false
	if _event_day == day and state != State.CLEAR:
		return false
	if _day_cycle.is_night:
		return false
	return _day_cycle.seconds_until_night() <= settings.warning_duration


func _should_start_fog(day: int) -> bool:
	if not settings.is_fog_day(day):
		return false
	if _fog_done_for_day == day:
		return false
	return _day_cycle.time_of_day >= settings.fog_start_time or _day_cycle.is_night


func _begin_warning(day: int) -> void:
	if _event_day == day and state != State.CLEAR:
		return
	_event_day = day
	fog_cycle = settings.fog_cycle_for_day(day)
	_set_state(State.WARNING)
	_play_warning_hook()
	fog_warning_started.emit(day, fog_cycle)


func _begin_fog(day: int) -> void:
	if _event_day == day and state == State.FOG_ACTIVE:
		return
	_event_day = day
	fog_cycle = settings.fog_cycle_for_day(day)
	_fog_elapsed = 0.0
	_unsafe_time = 0.0
	_tick_left = 0.0
	_set_state(State.FOG_ACTIVE)
	fog_started.emit(day, fog_cycle)


func _begin_ending() -> void:
	if state != State.FOG_ACTIVE:
		return
	_ending_left = settings.fog_ending_duration
	_set_state(State.FOG_ENDING)
	fog_ending.emit(_day_cycle.current_day if _day_cycle else 0, fog_cycle)


func _finish_clear() -> void:
	var day := _day_cycle.current_day if _day_cycle else 0
	_fog_done_for_day = _event_day if _event_day > 0 else day
	_set_state(State.CLEAR)
	fog_ended.emit(day, fog_cycle)


func _set_state(next: int) -> void:
	if state == next:
		return
	state = next
	state_changed.emit(state)


func _play_warning_hook() -> void:
	if _warning_player == null:
		return
	if _warning_player.stream == null:
		return
	_warning_player.play()


func _tick_damage(delta: float) -> void:
	if state != State.FOG_ACTIVE:
		_unsafe_time = 0.0
		return
	_refresh_player()
	player_is_safe = is_position_safe(_player.global_position) if _player != null else true
	if player_is_safe:
		_unsafe_time = 0.0
		return
	_unsafe_time += delta
	_tick_left -= delta
	if _tick_left > 0.0:
		return
	_tick_left = settings.fog_damage_tick
	if _unsafe_time < settings.fog_grace_period:
		return
	if _player == null:
		return
	var amount := settings.fog_damage_per_second(fog_cycle) * settings.fog_damage_tick
	_player.take_damage(amount, self, DAMAGE_TYPE)
	fog_damage_applied.emit(amount)


func is_position_safe(world_position: Vector2) -> bool:
	if state != State.FOG_ACTIVE:
		return true
	var tree := get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group("safe_zone"):
		var zone := node as SafeZone
		if zone != null and zone.contains_world_point(world_position):
			return true
		elif node != null and node.has_method("contains_world_point") and bool(node.call("contains_world_point", world_position)):
			return true
	return false


func is_fog_active() -> bool:
	return state == State.FOG_ACTIVE


func is_warning() -> bool:
	return state == State.WARNING


func fog_done_today() -> bool:
	return _day_cycle != null and _fog_done_for_day == _day_cycle.current_day


func fog_time_left() -> float:
	if settings == null or state != State.FOG_ACTIVE:
		return 0.0
	return maxf(settings.fog_duration_seconds(fog_cycle) - _fog_elapsed, 0.0)


func visual_density() -> float:
	match state:
		State.WARNING:
			return lerpf(0.16, 0.52, warning_progress())
		State.FOG_ACTIVE:
			return 1.0
		State.FOG_ENDING:
			return 1.0 * ending_progress()
		_:
			return 0.0


func warning_progress() -> float:
	if state != State.WARNING or settings == null or _day_cycle == null:
		return 0.0
	var span := maxf(settings.warning_duration, 0.001)
	return 1.0 - clampf(_day_cycle.seconds_until_night() / span, 0.0, 1.0)


func ending_progress() -> float:
	if state != State.FOG_ENDING or settings == null or settings.fog_ending_duration <= 0.001:
		return 0.0
	return clampf(_ending_left / settings.fog_ending_duration, 0.0, 1.0)


func play_thunder_hook() -> void:
	if _thunder_player == null or _thunder_player.stream == null:
		return
	_thunder_player.pitch_scale = randf_range(0.86, 1.14)
	_thunder_player.play()


func update_wind_hook(storm: float, player_safe: bool) -> void:
	if _wind_player == null or _wind_player.stream == null:
		return
	if storm <= 0.02:
		if _wind_player.playing:
			_wind_player.stop()
		return
	if not _wind_player.playing:
		_wind_player.play()
	var db := lerpf(-18.0, -4.0, clampf(storm, 0.0, 1.0))
	if player_safe:
		db -= 6.0
	_wind_player.volume_db = db


func debug_strike_lightning() -> void:
	var vis := get_tree().get_first_node_in_group("fog_visual")
	if vis != null and vis.has_method("trigger_lightning"):
		vis.call("trigger_lightning", true)


func reset_event_guard() -> void:
	_event_day = -1
	_fog_done_for_day = -1
	_fog_elapsed = 0.0
	_ending_left = 0.0
	_unsafe_time = 0.0
	_set_state(State.CLEAR)


func debug_jump_to_fog_night(day: int = 7) -> void:
	reset_event_guard()
	if _day_cycle == null:
		_day_cycle = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if _day_cycle == null or settings == null:
		return
	var jump_time := settings.clock_hour_to_time(settings.debug_jump_hour)
	_day_cycle.set_day_and_time(day, jump_time)
	if _day_cycle.is_night and settings.is_fog_day(day):
		_begin_fog(day)


func debug_end_fog() -> void:
	if state == State.CLEAR:
		return
	if _day_cycle != null:
		_fog_done_for_day = _event_day if _event_day > 0 else _day_cycle.current_day
	_set_state(State.CLEAR)
	fog_ended.emit(_day_cycle.current_day if _day_cycle else 0, fog_cycle)


func _on_time_changed(_day: int, _time: float, _night: bool) -> void:
	_update_state_from_time()


func _on_night_started(day: int) -> void:
	if settings != null and settings.is_fog_day(day) and _fog_done_for_day != day:
		if state == State.WARNING or state == State.CLEAR:
			_begin_fog(day)


func _on_day_changed(_day: int) -> void:
	if state == State.FOG_ACTIVE or state == State.FOG_ENDING:
		return
	if state == State.WARNING:
		return
	_set_state(State.CLEAR)


func _refresh_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player


func to_save_dict() -> Dictionary:
	return {
		"state": state,
		"fog_cycle": fog_cycle,
		"event_day": _event_day,
		"fog_done_for_day": _fog_done_for_day,
		"fog_elapsed": _fog_elapsed,
	}


func from_save_dict(data: Dictionary) -> void:
	state = int(data.get("state", State.CLEAR))
	fog_cycle = int(data.get("fog_cycle", 0))
	_event_day = int(data.get("event_day", -1))
	_fog_done_for_day = int(data.get("fog_done_for_day", -1))
	_fog_elapsed = float(data.get("fog_elapsed", 0.0))
	state_changed.emit(state)
