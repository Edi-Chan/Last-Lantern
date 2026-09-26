@tool
class_name SpawnSettings
extends Resource

## Zentrale Caps und LOD-Ringe. Spawner lesen das, statt eigene Magic Numbers.

enum Channel {
	ENEMY,
	ANIMAL,
	CRITTER,
}

@export_group("Harte Caps")
@export var max_dynamic_entities: int = 36
@export var max_enemies: int = 8
@export var max_animals: int = 16
@export var max_critters: int = 12
@export var max_debug_animals: int = 48
@export var max_debug_enemies: int = 24

@export_group("Lokale Caps")
@export var local_radius: float = 1400.0
@export var max_local_enemies_normal: int = 4
@export var max_local_enemies_darkness: int = 8
@export var max_local_animals: int = 10
@export var max_local_critters: int = 8

@export_group("Enemy Distanz")
@export var enemy_min_spawn: float = 380.0
@export var enemy_max_spawn: float = 920.0
@export var enemy_near: float = 480.0
@export var enemy_sleep: float = 1000.0
@export var enemy_despawn: float = 1680.0

@export_group("Animal Distanz")
@export var animal_min_spawn: float = 720.0
@export var animal_max_spawn: float = 1280.0
@export var animal_near: float = 480.0
@export var animal_sleep: float = 900.0
@export var animal_despawn: float = 1680.0

@export_group("Critter Distanz")
@export var critter_min_spawn: float = 640.0
@export var critter_max_spawn: float = 1100.0
@export var critter_near: float = 400.0
@export var critter_sleep: float = 800.0
@export var critter_despawn: float = 1400.0

@export_group("Raten")
@export var enemy_interval_normal: float = 22.0
@export var enemy_interval_darkness: float = 10.0
@export var animal_interval: float = 3.2
@export var critter_interval: float = 2.8
@export var darkness_wildlife_interval: float = 2.0
@export var lod_update_interval: float = 0.28
@export var camera_reject_margin: float = 72.0

@export_group("Start")
@export var initial_animals: int = 4
@export var initial_critters: int = 3
