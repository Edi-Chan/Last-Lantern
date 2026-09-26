class_name EnemyHealthBar
extends Control

## Kleine Overhead-Leiste. Wird vom EnemyHealthBarManager gepoolt, nicht am Gegner gebaut.

enum Style {
	NORMAL,
	ELITE,
	ANIMAL,
}

const BAR_SIZE := Vector2(48, 6)
const SIZE := BAR_SIZE
const TRAIL_DELAY := 0.18
const FILL_LERP := 18.0

var show_numbers: bool = false
var show_identity: bool = false
var style: int = Style.NORMAL

var _fill_ratio: float = 1.0
var _shown_ratio: float = 1.0
var _trail_ratio: float = 1.0
var _trail_wait: float = 0.0
var _label: Label
var _name_label: Label
var _current: float = 0.0
var _maximum: float = 1.0
var _display_name: String = ""
var _bar_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	visible = false
	modulate.a = 0.0
	z_index = 8
	_ensure_labels()
	_apply_chrome()
	set_process(false)


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_shown_ratio = move_toward(_shown_ratio, _fill_ratio, FILL_LERP * delta)
	if _trail_wait > 0.0:
		_trail_wait = maxf(_trail_wait - delta, 0.0)
	else:
		_trail_ratio = move_toward(_trail_ratio, _shown_ratio, 8.0 * delta)
	queue_redraw()


func bind_health(current: float, maximum: float, instant: bool = false) -> void:
	_current = current
	_maximum = maxf(maximum, 0.001)
	var next := clampf(current / _maximum, 0.0, 1.0)
	if instant:
		_fill_ratio = next
		_shown_ratio = next
		_trail_ratio = next
		_trail_wait = 0.0
	else:
		if next < _fill_ratio - 0.001:
			_trail_wait = TRAIL_DELAY
		_fill_ratio = next
	_refresh_numbers()
	queue_redraw()


func set_style(next: int) -> void:
	style = next
	queue_redraw()


func set_identity(display_name: String, visible_identity: bool) -> void:
	_display_name = display_name
	show_identity = visible_identity
	_apply_chrome()
	_refresh_numbers()


func _refresh_numbers() -> void:
	_ensure_labels()
	_label.visible = show_identity or show_numbers
	_label.text = "%d / %d" % [ceili(_current), roundi(_maximum)]
	_name_label.visible = show_identity and not _display_name.is_empty()
	_name_label.text = _display_name


func _draw() -> void:
	var rect := Rect2(_bar_origin, BAR_SIZE)
	var border := Color(0.08, 0.06, 0.04, 0.95)
	var back := Color(0.12, 0.08, 0.06, 0.82)
	var trail := Color(0.72, 0.28, 0.12, 0.85)
	var fill := Color(0.78, 0.18, 0.16, 1.0)
	if style == Style.ELITE:
		border = Color(0.62, 0.46, 0.16, 0.95)
		fill = Color(0.86, 0.58, 0.18, 1.0)
	elif style == Style.ANIMAL:
		border = Color(0.16, 0.22, 0.10, 0.95)
		fill = Color(0.46, 0.72, 0.28, 1.0)
		trail = Color(0.72, 0.62, 0.20, 0.85)
	draw_rect(rect, border, false, 1.0)
	draw_rect(rect.grow(-1.0), back, true)
	var inner := rect.grow(-1.0)
	if _trail_ratio > _shown_ratio + 0.01:
		var trail_w := inner.size.x * _trail_ratio
		draw_rect(Rect2(inner.position, Vector2(trail_w, inner.size.y)), trail, true)
	var fill_w := inner.size.x * _shown_ratio
	if fill_w > 0.25:
		draw_rect(Rect2(inner.position, Vector2(fill_w, inner.size.y)), fill, true)


func _ensure_labels() -> void:
	if _name_label == null:
		_name_label = Label.new()
		_name_label.name = "Name"
		_name_label.visible = false
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_label.add_theme_font_size_override("font_size", 9)
		_name_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7, 1))
		_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_name_label.add_theme_constant_override("outline_size", 3)
		add_child(_name_label)
	if _label != null:
		return
	_label = Label.new()
	_label.name = "Numbers"
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 2)
	add_child(_label)


func _apply_chrome() -> void:
	_ensure_labels()
	if show_identity:
		var name_w := 72.0
		if not _display_name.is_empty():
			name_w = maxf(72.0, float(_display_name.length()) * 6.2 + 12.0)
		size = Vector2(minf(name_w, 140.0), 32.0)
		custom_minimum_size = size
		_bar_origin = Vector2((size.x - BAR_SIZE.x) * 0.5, 13.0)
		_name_label.position = Vector2(0, 0)
		_name_label.size = Vector2(size.x, 12)
		_label.position = Vector2(0, 20)
		_label.size = Vector2(size.x, 12)
	else:
		size = BAR_SIZE
		custom_minimum_size = BAR_SIZE
		_bar_origin = Vector2.ZERO
		_label.position = Vector2(-8, -11)
		_label.size = Vector2(BAR_SIZE.x + 16, 10)
		_name_label.visible = false
	queue_redraw()
