class_name LiquidSettings
extends Resource

## Zentrale Balancing-Werte für das Flüssigkeitssystem.

@export_group("Simulation")
@export var simulation_rate: float = 15.0
@export var max_updates_per_tick: int = 800
@export var max_updates_per_tick_min: int = 400
@export var max_updates_per_tick_max: int = 1600
@export var adaptive_budget: bool = true
@export var vertical_flow_rate: int = 255
@export var horizontal_flow_rate: int = 64
@export var max_vertical_steps_per_cell: int = 8
@export var settle_threshold: int = 2
@export var equalize_min_diff: int = 4
@export var sleep_after_stable_ticks: int = 3

@export_group("Player")
@export var shallow_water_speed_multiplier: float = 0.90
@export var deep_water_speed_multiplier: float = 0.70
@export var water_gravity_multiplier: float = 0.35
@export var water_max_fall_multiplier: float = 0.45
@export var water_drag_horizontal: float = 6.0
@export var water_drag_vertical: float = 4.0
@export var swim_force: float = 420.0
@export var swim_max_up_speed: float = 220.0
@export var swim_stamina_cost: float = 6.0
@export var feet_depth_threshold: float = 0.12
@export var waist_depth_threshold: float = 0.45
@export var swim_depth_threshold: float = 0.55
@export var head_submerge_threshold: float = 0.85

@export_group("Breath")
@export var max_breath: float = 100.0
@export var breath_drain_rate: float = 5.56
@export var breath_regen_rate: float = 25.0
@export var breath_low_threshold: float = 0.25
@export var drowning_damage: float = 10.0
@export var drowning_damage_interval: float = 1.5

@export_group("Enemy")
@export var enemy_shallow_speed_multiplier: float = 0.85
@export var enemy_deep_speed_multiplier: float = 0.65
@export var enemy_water_gravity_multiplier: float = 0.40

@export_group("World Generation")
@export_range(0.0, 1.0, 0.01) var surface_water_frequency: float = 0.08
@export_range(0.0, 1.0, 0.01) var cave_water_frequency: float = 0.07
@export_range(0.0, 1.0, 0.01) var ravine_water_frequency: float = 0.12
@export var minimum_pool_size: int = 4
@export var maximum_pool_size: int = 48
@export var spawn_water_exclusion_radius: int = 90
@export var max_surface_ponds: int = 18
@export var max_cave_pools: int = 24

@export_group("Visual")
@export var water_color: Color = Color(0.18, 0.42, 0.78, 0.82)
@export var water_surface_color: Color = Color(0.35, 0.62, 0.92, 0.95)
@export var underwater_overlay_color: Color = Color(0.12, 0.28, 0.55, 0.18)
@export var surface_anim_fps: float = 4.0
@export var max_dirty_render_updates: int = 512

@export_group("Debug")
@export var debug_simulation_enabled: bool = true
@export var debug_show_active_cells: bool = false
@export var debug_show_amounts: bool = false
