class_name BossHealthHud
extends Control

## Platzhalter fuer eine spaetere grosse Boss-Leiste. Aktuell kein Boss im Spiel.

var _title: Label
var _bar: ColorRect
var _fill: ColorRect
var _percent: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -180.0
	offset_right = 180.0
	offset_top = 18.0
	offset_bottom = 48.0
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.position = Vector2(0, 0)
	_title.size = Vector2(360, 14)
	_title.add_theme_font_size_override("font_size", 11)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	_bar = ColorRect.new()
	_bar.color = Color(0.08, 0.06, 0.05, 0.85)
	_bar.position = Vector2(20, 16)
	_bar.size = Vector2(320, 8)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_fill = ColorRect.new()
	_fill.color = Color(0.72, 0.16, 0.14, 1)
	_fill.position = Vector2(20, 16)
	_fill.size = Vector2(320, 8)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	_percent = Label.new()
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent.position = Vector2(0, 26)
	_percent.size = Vector2(360, 12)
	_percent.add_theme_font_size_override("font_size", 9)
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_percent)


func show_boss(boss_name: String, current: float, maximum: float) -> void:
	visible = true
	_title.text = boss_name
	var ratio := 0.0 if maximum <= 0.0 else clampf(current / maximum, 0.0, 1.0)
	_fill.size.x = 320.0 * ratio
	_percent.text = "%d %%" % int(round(ratio * 100.0))


func hide_boss() -> void:
	visible = false
