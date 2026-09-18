class_name CombatTextItem
extends Label

## Eine gepoolte Schadenszahl. Keine Sounds, keine Mausinteraktion.

var active: bool = false
var age: float = 0.0
var lifetime: float = 0.9
var fade_time: float = 0.32
var world_pos: Vector2 = Vector2.ZERO
var rise: float = 0.0
var rise_distance: float = 22.0
var pop_from: float = 1.12
var pop_time: float = 0.1
var spawn_order: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	visible = false
	modulate.a = 0.0


func activate(p_text: String, color: Color, font_size: int, origin: Vector2, config: CombatTextConfig, critical: bool) -> void:
	var cfg := config if config != null else CombatTextConfig.new()
	text = p_text
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_outline_color", cfg.outline_color)
	add_theme_constant_override("outline_size", cfg.outline_size)
	add_theme_font_size_override("font_size", font_size)
	world_pos = origin
	age = 0.0
	rise = 0.0
	lifetime = cfg.lifetime
	fade_time = cfg.fade_time
	rise_distance = cfg.critical_rise_distance if critical else cfg.rise_distance
	pop_from = cfg.critical_pop_scale if critical else cfg.normal_pop_scale
	pop_time = cfg.pop_time
	active = true
	visible = true
	modulate.a = 1.0
	scale = Vector2(pop_from, pop_from)
	reset_size()
	pivot_offset = size * 0.5


func deactivate() -> void:
	active = false
	visible = false
	modulate.a = 0.0
	text = ""
	set_process(false)


func tick(delta: float, canvas_xform: Transform2D, ui_scale: float) -> bool:
	if not active:
		return false
	age += delta
	var t := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	rise = rise_distance * t
	var screen: Vector2 = canvas_xform * (world_pos + Vector2(0.0, -rise))
	var ui := maxf(ui_scale, 0.001)
	position = screen / ui - size * 0.5
	if pop_time > 0.0 and age < pop_time:
		var pop := clampf(age / pop_time, 0.0, 1.0)
		var s := lerpf(pop_from, 1.0, pop)
		scale = Vector2(s, s)
	else:
		scale = Vector2.ONE
	var fade_start := lifetime - fade_time
	if age >= fade_start:
		modulate.a = 1.0 - clampf((age - fade_start) / maxf(fade_time, 0.001), 0.0, 1.0)
	else:
		modulate.a = 1.0
	if age >= lifetime:
		deactivate()
		return false
	return true
