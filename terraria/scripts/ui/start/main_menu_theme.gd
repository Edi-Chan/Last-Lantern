class_name MainMenuTheme
extends RefCounted

## Pixel-UI-Theme nur fuer das Hauptmenue.

const COL_BG := Color("0B0E17")
const COL_PANEL := Color("171A24")
const COL_PANEL_HOVER := Color("202432")
const COL_PANEL_PRESSED := Color("2A2418")
const COL_BORDER := Color("3A4355")
const COL_BORDER_GOLD := Color("D8A83E")
const COL_TEXT := Color("E6E1D8")
const COL_TEXT_BRIGHT := Color("F5F0E6")
const COL_MUTED := Color("9CA3B4")
const COL_GOLD := Color("D8A83E")
const COL_GOLD_BRIGHT := Color("F0C65A")
const COL_LANTERN := Color("FFB84A")
const COL_DISABLED_BG := Color("12151E")
const COL_DISABLED_BORDER := Color("252A36")
const COL_STATUS_OK := Color("8FA86E")
const COL_STATUS_MISSING := Color("6B7280")


static func box(
	bg: Color,
	border: Color,
	pad := Vector4(10, 6, 10, 6),
	shadow := 2,
	shadow_color := Color(0, 0, 0, 0.45)
) -> StyleBoxFlat:
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
	style.shadow_color = shadow_color
	style.shadow_size = shadow
	style.shadow_offset = Vector2(0, shadow)
	return style


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 12

	var btn_normal := box(COL_PANEL, COL_BORDER, Vector4(12, 7, 12, 7), 2)
	var btn_hover := box(COL_PANEL_HOVER, COL_BORDER_GOLD, Vector4(12, 7, 12, 7), 3, Color(0.55, 0.35, 0.08, 0.25))
	btn_hover.shadow_color = Color(0.45, 0.28, 0.05, 0.35)
	var btn_pressed := box(COL_PANEL_PRESSED, COL_BORDER_GOLD, Vector4(12, 8, 12, 6), 1, Color(0.35, 0.22, 0.04, 0.2))
	var btn_disabled := box(COL_DISABLED_BG, COL_DISABLED_BORDER, Vector4(12, 7, 12, 7), 1, Color(0, 0, 0, 0.2))

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_stylebox("focus", "Button", btn_hover)
	theme.set_color("font_color", "Button", COL_TEXT)
	theme.set_color("font_hover_color", "Button", COL_TEXT_BRIGHT)
	theme.set_color("font_pressed_color", "Button", COL_GOLD_BRIGHT)
	theme.set_color("font_disabled_color", "Button", COL_MUTED.darkened(0.15))
	theme.set_font_size("font_size", "Button", 12)

	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Label", 12)
	theme.set_stylebox("panel", "PanelContainer", box(COL_PANEL, COL_BORDER, Vector4(14, 10, 14, 10), 4))
	return theme


static func apply_continue_highlight(button: Button) -> void:
	if button == null:
		return
	var normal := box(Color("1E222C"), COL_GOLD, Vector4(12, 7, 12, 7), 3, Color(0.5, 0.32, 0.06, 0.3))
	var hover := box(Color("252A36"), COL_GOLD_BRIGHT, Vector4(12, 7, 12, 7), 4, Color(0.6, 0.38, 0.08, 0.4))
	var pressed := box(COL_PANEL_PRESSED, COL_GOLD_BRIGHT, Vector4(12, 8, 12, 6), 1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
