class_name AdminTheme
extends RefCounted

## Pixel-Art-Styles nur fuer das Admin-Menue. Kein Gameplay-Theme.

const COL_BG := Color("111118")
const COL_PANEL := Color("1B1B26")
const COL_PANEL_INNER := Color("20202C")
const COL_BORDER := Color("30303D")
const COL_BORDER_LIT := Color("404052")
const COL_TEXT := Color("D8D8DF")
const COL_TEXT_BRIGHT := Color("EEEEF2")
const COL_MUTED := Color("8D8D9A")
const COL_GOLD := Color("D6AD45")
const COL_GOLD_DIM := Color("3A3018")
const COL_ACCENT := Color("3A3A58")
const COL_WARN := Color("C47A3A")
const COL_DANGER := Color("6B2E32")
const COL_DANGER_BORDER := Color("8B3A3A")
const COL_DARKNESS := Color("4A2040")
const COL_HOVER := Color("262633")
const COL_PRESSED := Color("2E2A1C")


static func box(bg: Color, border: Color, pad := Vector4(6, 4, 6, 4)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = pad.x
	style.content_margin_top = pad.y
	style.content_margin_right = pad.z
	style.content_margin_bottom = pad.w
	style.anti_aliasing = false
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 11
	var btn := box(COL_PANEL_INNER, COL_BORDER)
	var btn_hover := box(COL_HOVER, COL_BORDER_LIT)
	var btn_pressed := box(COL_PRESSED, COL_GOLD)
	var btn_disabled := box(Color("16161F"), Color("252530"))
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", COL_GOLD)
	theme.set_color("font_disabled_color", "Button", COL_MUTED)
	theme.set_font_size("font_size", "Button", 10)
	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 11)
	var edit := box(Color("14141C"), COL_BORDER, Vector4(6, 3, 6, 3))
	theme.set_stylebox("normal", "LineEdit", edit)
	theme.set_stylebox("focus", "LineEdit", box(Color("14141C"), COL_GOLD, Vector4(6, 3, 6, 3)))
	theme.set_color("font_color", "LineEdit", COL_TEXT_BRIGHT)
	theme.set_color("font_placeholder_color", "LineEdit", COL_MUTED)
	theme.set_font_size("font_size", "LineEdit", 11)
	theme.set_stylebox("panel", "PanelContainer", box(COL_PANEL, COL_BORDER, Vector4(8, 6, 8, 6)))
	theme.set_stylebox("panel", "Panel", box(COL_PANEL_INNER, COL_BORDER, Vector4(6, 4, 6, 4)))
	var grab := box(COL_BORDER_LIT, COL_BORDER, Vector4(1, 1, 1, 1))
	theme.set_stylebox("grabber", "VScrollBar", grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", box(COL_GOLD, COL_GOLD, Vector4(1, 1, 1, 1)))
	theme.set_stylebox("scroll", "VScrollBar", box(Color("14141C"), COL_BORDER, Vector4(0, 0, 0, 0)))
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 4)
	return theme
