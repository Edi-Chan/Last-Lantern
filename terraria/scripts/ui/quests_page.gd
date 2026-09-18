class_name QuestsPage
extends PanelContainer

## Platzhalter-Reiter. Kein Questsystem, keine Fake-Quests.


func _ready() -> void:
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.125, 1)
	style.border_color = Color(0.28, 0.36, 0.45, 1)
	style.set_border_width_all(1)
	style.anti_aliasing = false
	add_theme_stylebox_override("panel", style)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "QUESTS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1))
	var body := Label.new()
	body.text = "Noch keine Quests verfügbar."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.68, 0.74, 0.8, 1))
	box.add_child(title)
	box.add_child(body)
