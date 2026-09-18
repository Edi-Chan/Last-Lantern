class_name CombatTextConfig
extends Resource

## Zentrale Darstellungswerte fuer Kampftext. Keine Magic Numbers in den Anzeige-Scripts.

@export_group("Farben")
@export var physical_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var critical_color: Color = Color(1.0, 0.82, 0.18, 1.0)
@export var player_damage_color: Color = Color(1.0, 0.22, 0.22, 1.0)
@export var darkness_color: Color = Color(0.72, 0.32, 0.95, 1.0)
@export var fire_color: Color = Color(1.0, 0.48, 0.12, 1.0)
@export var frost_color: Color = Color(0.52, 0.86, 1.0, 1.0)
@export var heal_color: Color = Color(0.32, 0.92, 0.38, 1.0)
@export var reduced_color: Color = Color(0.62, 0.62, 0.66, 1.0)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.88)

@export_group("Schrift")
@export var normal_font_size: int = 11
@export var critical_font_size: int = 15
@export var dot_font_size: int = 9
@export var outline_size: int = 3

@export_group("Animation")
@export var lifetime: float = 0.9
@export var fade_time: float = 0.32
@export var rise_distance: float = 22.0
@export var critical_rise_distance: float = 28.0
@export var random_x_offset: float = 7.0
@export var stack_x: float = 8.0
@export var stack_y: float = -6.0
@export var critical_pop_scale: float = 1.3
@export var normal_pop_scale: float = 1.12
@export var pop_time: float = 0.1

@export_group("Limits")
@export var max_combat_text: int = 30
@export var dot_aggregate_window: float = 0.28
@export var text_above_health_bar: float = 14.0
