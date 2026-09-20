class_name BuildingHud
extends CanvasLayer

## Kleines Platzierungsfenster oben rechts.

var _root: Control
var _panel: PanelContainer
var _cost_label: Label
var _hint_label: Label
var _toast: Label
var _toast_left: float = 0.0


func _ready() -> void:
	add_to_group("building_hud")
	layer = 21
	_build_ui()


func _build_ui() -> void:
	if _panel != null:
		return
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "HintPanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -196
	_panel.offset_right = -8
	_panel.offset_top = 8
	_panel.offset_bottom = 8
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_END
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.05, 0.9)
	style.border_color = Color(0.78, 0.62, 0.34, 0.92)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_cost_label = Label.new()
	_cost_label.name = "CostLabel"
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cost_label.add_theme_font_size_override("font_size", 10)
	_cost_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72, 1))
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_cost_label)
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hint_label)
	_root.add_child(_panel)
	_toast = Label.new()
	_toast.name = "Toast"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -220
	_toast.offset_right = 220
	_toast.offset_top = 86
	_toast.offset_bottom = 128
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1))
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)


func _process(delta: float) -> void:
	if _toast_left <= 0.0:
		return
	_toast_left -= delta
	if _toast_left <= 0.0:
		_toast.visible = false


func show_costs(title: String, lines: PackedStringArray, missing: String, valid: bool, hint: String = "") -> void:
	_build_ui()
	var body := "⚒️ %s\n\nBenötigt:\n%s" % [title, "\n".join(lines)]
	if not missing.is_empty():
		body += "\n\nFehlt: %s" % missing
	_cost_label.text = body
	if hint.is_empty():
		hint = "Rechtsklick zum Bauen." if valid else "Ungültige Position."
	_hint_label.text = hint
	if valid:
		_hint_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.52, 1))
	else:
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38, 1))
	_panel.visible = true


func hide_costs() -> void:
	if _panel != null:
		_panel.visible = false


func toast(text: String, duration: float = 2.2) -> void:
	_build_ui()
	_toast.text = text
	_toast.visible = true
	_toast_left = duration
