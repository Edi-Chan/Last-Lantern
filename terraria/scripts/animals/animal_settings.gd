@tool
class_name AnimalSettings
extends Resource

## Zentrale Wildlife-Limits. Keine Magic Numbers in den 24 Tierscripts.

@export_group("Population")
@export var max_active_animals: int = 16
@export var max_surface_animals: int = 10
@export var max_flying_animals: int = 6
@export var max_water_animals: int = 4
@export var max_darkness_animals: int = 4
@export var max_critter_animals: int = 12

@export_group("Spawn")
@export var animal_spawn_interval: float = 3.2
@export var darkness_spawn_interval: float = 2.0
@export var min_spawn_distance: float = 720.0
@export var max_spawn_distance: float = 1280.0
@export var max_spawns_per_tick: int = 1
@export var initial_surface_count: int = 4

@export_group("LOD")
@export var animal_activation_distance: float = 480.0
@export var animal_sleep_distance: float = 900.0
@export var animal_despawn_distance: float = 1680.0
@export var ai_near_interval: float = 0.18
@export var ai_medium_interval: float = 0.42
@export var lod_update_interval: float = 0.28

@export_group("Audio")
@export var max_idle_sounds: int = 3
@export var idle_sound_min_delay: float = 4.5
@export var idle_sound_max_delay: float = 11.0
@export var audio_max_distance: float = 380.0
