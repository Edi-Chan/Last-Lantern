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
@export var equalize_min_diff: int = 1
@export var sleep_after_stable_ticks: int = 3
@export var max_simulation_ticks_per_frame: int = 2
@export var simulation_budget_ms: float = 3.5

@export_group("Player")
@export var shallow_water_speed_multiplier: float = 0.90
@export var deep_water_speed_multiplier: float = 0.70
@export var water_gravity_multiplier: float = 0.35
@export var water_max_fall_multiplier: float = 0.45
@export var water_drag_horizontal: float = 6.0
@export var water_drag_vertical: float = 4.0
@export var swim_force: float = 210.0
@export var swim_max_up_speed: float = 110.0
@export var swim_sink_speed: float = 38.0
@export var swim_stamina_cost: float = 4.0
@export var feet_depth_threshold: float = 0.08
@export var waist_depth_threshold: float = 0.35
@export var swim_depth_threshold: float = 0.40
@export var head_submerge_threshold: float = 0.75

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
@export var enemy_lava_speed_multiplier: float = 0.35
@export var enemy_lava_gravity_multiplier: float = 0.50
@export var enemy_lava_damage: float = 8.0
@export var enemy_lava_damage_interval: float = 0.6

@export_group("Lava Physics")
@export var lava_flow_speed: int = 48
@export var lava_horizontal_flow: int = 12
@export var lava_max_vertical_steps_per_cell: int = 1
@export var lava_settle_threshold: int = 4

@export_group("Lava Damage")
@export var lava_contact_damage: float = 12.0
@export var lava_damage_interval: float = 0.5
@export var burn_duration: float = 3.0
@export var burn_damage: float = 4.0
@export var burn_tick_rate: float = 0.75

@export_group("Lava Movement")
@export var lava_move_multiplier: float = 0.40
@export var lava_vertical_multiplier: float = 0.32
@export var lava_gravity_multiplier: float = 0.55
@export var lava_max_fall_multiplier: float = 0.30
@export var lava_drag_horizontal: float = 10.0
@export var lava_drag_vertical: float = 7.0
@export var lava_swim_force: float = 95.0
@export var lava_swim_max_up_speed: float = 48.0
@export var lava_sink_speed: float = 52.0

@export_group("World Generation")
@export_range(0.0, 1.0, 0.01) var surface_water_frequency: float = 0.08
@export_range(0.0, 1.0, 0.01) var cave_water_frequency: float = 0.22
@export_range(0.0, 1.0, 0.01) var ravine_water_frequency: float = 0.12
@export var minimum_pool_size: int = 4
@export var maximum_pool_size: int = 48
@export var spawn_water_exclusion_radius: int = 90
@export var max_surface_ponds: int = 18
@export var max_cave_pools: int = 48
@export_range(0.0, 1.0, 0.01) var deep_lava_chance: float = 0.16
@export_range(0.0, 1.0, 0.01) var danger_lava_chance: float = 0.38
@export_range(0.0, 1.0, 0.01) var fire_region_start_ratio: float = 0.88
@export_range(0.0, 1.0, 0.01) var fire_region_lava_density: float = 0.72
@export var lava_pool_min_size: int = 3
@export var lava_pool_max_size: int = 36
@export var max_deep_lava_pools: int = 18
@export var max_danger_lava_pools: int = 32
@export var lava_fill_ratio: float = 0.48
@export var fire_lava_fill_ratio: float = 0.68
@export var min_air_above_lava: int = 3

@export_group("Visual")
@export var water_color: Color = Color(0.18, 0.42, 0.78, 0.82)
@export var water_body_color: Color = Color(0.18, 0.42, 0.78, 0.82)
@export var water_surface_color: Color = Color(0.35, 0.62, 0.92, 0.95)
@export var water_fall_color: Color = Color(0.28, 0.52, 0.88, 0.70)
@export var underwater_overlay_color: Color = Color(0.12, 0.28, 0.55, 0.18)
@export var surface_anim_fps: float = 4.0
@export var surface_amount_threshold: int = 8
@export var waterfall_width_px: int = 8
@export var max_dirty_render_updates: int = 2048
@export var lava_color: Color = Color(0.82, 0.22, 0.06, 0.94)
@export var lava_body_color: Color = Color(0.72, 0.16, 0.04, 0.96)
@export var lava_deep_color: Color = Color(0.42, 0.06, 0.03, 0.98)
@export var lava_surface_color: Color = Color(1.0, 0.78, 0.28, 1.0)
@export var lava_fall_color: Color = Color(0.95, 0.42, 0.10, 0.88)
@export var lava_animation_speed: float = 2.2
@export var lava_surface_animation_speed: float = 2.8
@export var lava_emission_strength: float = 0.85
@export var lava_light_range: int = 7
@export var lava_light_intensity: float = 1.35
@export var lava_light_chunk_size: int = 8
@export var lava_max_cluster_lights: int = 24
@export var lava_particle_budget: int = 10

@export_group("Debug")
@export var debug_simulation_enabled: bool = true
@export var debug_show_active_cells: bool = false
@export var debug_show_amounts: bool = false
