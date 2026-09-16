@tool
class_name LastLanternSettings
extends Resource

## Zentrale Last-Lantern-Werte. Keine Magic Numbers in den Gameplay-Scripts.

@export_group("Zeit")
@export var tile_size: int = 16
@export var day_duration: float = 75.0
@export var night_duration: float = 35.0
@export var time_scale: float = 1.0
## 0.0 = 00:00, 0.5 = 12:00, 0.75 = 18:00.
@export var night_start_time: float = 0.75
## Nacht endet hier (0.25 = 06:00). 00:00 bleibt Nacht.
@export var night_end_time: float = 0.25

@export_group("Nebel")
@export var fog_interval_days: int = 7
@export var fog_start_time: float = 0.75
@export var warning_duration: float = 8.0
@export var fog_duration_base: float = 22.0
@export var fog_duration_per_cycle: float = 6.0
@export var fog_duration_max: float = 55.0
@export var fog_ending_duration: float = 4.0
@export var fog_damage_base: float = 5.0
@export var fog_damage_tick: float = 0.5
@export var fog_grace_period: float = 0.75

@export_group("Laterne")
@export var lantern_spawn_offset_tiles: int = 5
@export var lantern_levels: Array[LanternLevelData] = []

@export_group("Debug")
@export var show_debug_fog_button: bool = true
## Debug-Button springt auf diese Uhrzeit (22.0 = 22:00).
@export var debug_jump_hour: float = 22.0
## Optionaler Gameplay-Radius als duenne Linie. Standard aus, damit der heilige Rand allein steht.
@export var show_debug_safe_radius: bool = false


func clock_hour_to_time(hour: float) -> float:
	return clampf(hour / 24.0, 0.0, 0.999)


func is_fog_day(day: int) -> bool:
	return day > 0 and (day % fog_interval_days) == 0


func fog_cycle_for_day(day: int) -> int:
	if day <= 0:
		return 0
	return int(day / fog_interval_days)


func fog_damage_per_second(cycle: int) -> float:
	var c := maxi(cycle, 1)
	var dps := fog_damage_base
	if c == 2:
		dps = 7.0
	elif c == 3:
		dps = 9.0
	elif c == 4:
		dps = 12.0
	elif c > 4:
		dps = 12.0 + float(c - 4) * 1.25
	return minf(dps, 24.0)


func fog_duration_seconds(cycle: int) -> float:
	var c := maxi(cycle, 1)
	return minf(fog_duration_base + float(c - 1) * fog_duration_per_cycle, fog_duration_max)


func next_fog_day(current_day: int, fog_done_today: bool) -> int:
	if current_day <= 0:
		return fog_interval_days
	if is_fog_day(current_day) and not fog_done_today:
		return current_day
	if is_fog_day(current_day) and fog_done_today:
		return current_day + fog_interval_days
	return int((current_day - 1) / fog_interval_days + 1) * fog_interval_days


func get_level_data(level: int) -> LanternLevelData:
	for data in lantern_levels:
		if data != null and data.level == level:
			return data
	return null


func max_lantern_level() -> int:
	var highest := 1
	for data in lantern_levels:
		if data != null:
			highest = maxi(highest, data.level)
	return highest
