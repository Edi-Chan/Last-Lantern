@tool
class_name AnimalData
extends Resource

## Datengetriebene Wildlife-Werte. Verhalten bleibt in AnimalBase.
## Keine Loot-Tabellen, keine Items. Critter via temperament/id.

enum Locomotion {
	GROUND,
	FLYING,
	WATER,
	AMPHIBIOUS,
}

enum Temperament {
	AMBIENT,
	FLEE,
	NEUTRAL,
	AGGRESSIVE,
}

enum TimeRule {
	ANY,
	DAY,
	NIGHT,
	DARKNESS,
	NIGHT_OR_DARKNESS,
}

enum Population {
	SURFACE,
	FLYING,
	WATER,
	DARKNESS,
}

@export var id: StringName = &"rabbit"
@export var display_name: String = "Kaninchen"

@export_group("Bewegung")
@export var locomotion: Locomotion = Locomotion.GROUND
@export var temperament: Temperament = Temperament.FLEE
@export var walk_speed: float = 38.0
@export var run_speed: float = 92.0
@export var jump_force: float = 160.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 600.0
@export var ground_acceleration: float = 240.0
@export var air_control: float = 180.0

@export_group("Kampf")
@export var max_health: int = 12
@export var attack_damage: float = 0.0
@export var attack_cooldown: float = 1.1
@export var attack_range: float = 22.0
@export var detection_range: float = 96.0
@export var flee_range: float = 112.0
@export var knockback_force: float = 70.0
@export var hurt_lock_time: float = 0.14
@export var can_attack: bool = false
@export var show_health_bar: bool = false
@export var charge_on_hit: bool = false
@export var curl_on_threat: bool = false

@export_group("KI")
@export var wander_radius: float = 80.0
@export var idle_duration_min: float = 0.7
@export var idle_duration_max: float = 2.4
@export var wander_duration_min: float = 1.1
@export var wander_duration_max: float = 2.8
@export var hop_locomotion: bool = false
@export var hop_interval: float = 0.42
@export var perch_then_fly: bool = false
@export var attracted_to_light: bool = false
@export var glow: bool = false
@export var peck_idle: bool = false
@export var jump_small_obstacles: bool = false
@export var flee_on_darkness: bool = true
@export var blocked_by_safe_zone: bool = false

@export_group("Spawn")
@export var time_rule: TimeRule = TimeRule.ANY
@export var population: Population = Population.SURFACE
@export var habitats: PackedStringArray = PackedStringArray(["grassland", "forest"])
@export var spawn_weight: float = 1.0
@export var darkness_spawn_weight: float = 0.0
@export var night_spawn_bonus: float = 0.0
@export var surface_only: bool = true
@export var allow_cave: bool = false
@export var needs_water: bool = false
@export var near_water: bool = false

@export_group("Darstellung")
@export var canvas_size: Vector2i = Vector2i(24, 20)
@export var collider_size: Vector2 = Vector2(10, 10)
@export var hurtbox_size: Vector2 = Vector2(12, 12)
@export var sprite_offset: Vector2 = Vector2(0, -10)
@export var health_bar_offset: Vector2 = Vector2(0, -18)
@export var animation_speed: float = 6.0
@export var z_index_value: int = 16
@export var darkness_form: bool = false


func is_critter() -> bool:
	if temperament == Temperament.AMBIENT:
		return true
	return id == &"bee" or id == &"butterfly" or id == &"snail" or id == &"moth" or id == &"firefly"
