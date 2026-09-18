@tool
class_name EnemyData
extends Resource

## Wiederverwendbare Gegnerwerte. Neue Gegner bekommen eine eigene .tres-Datei.
## Finsternis nutzt die Darkness-Felder, nicht eine zweite Szene.

@export var display_name: String = "Zombie"

@export_group("Normal")
@export var max_health: int = 50
@export var move_speed: float = 42.0
@export var wander_speed: float = 18.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 192.0
@export var attack_range: float = 30.0
@export var lose_target_multiplier: float = 1.35

@export_group("Finsternis")
@export var darkness_max_health: int = 150
@export var darkness_move_speed: float = 72.0
@export var darkness_attack_damage: float = 20.0
@export var darkness_attack_cooldown: float = 0.75
@export var darkness_detection_range: float = 288.0

@export_group("Finsternis-Skalierung")
## Vorbereitet fuer spaetere Zyklen. 0 = aktuell keine Extra-Skalierung.
@export var darkness_health_cycle_bonus: float = 0.0
@export var darkness_damage_cycle_bonus: float = 0.0
@export var darkness_speed_cycle_bonus: float = 0.0

@export_group("Physik")
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 600.0
@export var ground_acceleration: float = 220.0
@export var darkness_acceleration: float = 420.0
@export var knockback_force: float = 90.0
@export var hurt_lock_time: float = 0.16

@export_group("Architektur")
## Spaeter: Gegner an der Schutzkuppel stoppen. Aktuell ohne Wirkung.
@export var blocked_by_safe_zone: bool = false

enum Rank {
	NORMAL,
	ELITE,
	BOSS,
}

@export var rank: Rank = Rank.NORMAL


func scaled_darkness_health(cycle: int) -> int:
	return _scale_int(darkness_max_health, darkness_health_cycle_bonus, cycle)


func scaled_darkness_damage(cycle: int) -> float:
	return _scale_float(darkness_attack_damage, darkness_damage_cycle_bonus, cycle)


func scaled_darkness_speed(cycle: int) -> float:
	return _scale_float(darkness_move_speed, darkness_speed_cycle_bonus, cycle)


func _scale_int(base: int, bonus: float, cycle: int) -> int:
	return int(round(_scale_float(float(base), bonus, cycle)))


func _scale_float(base: float, bonus: float, cycle: int) -> float:
	var extra := bonus * float(maxi(cycle - 1, 0))
	return base * (1.0 + extra)
