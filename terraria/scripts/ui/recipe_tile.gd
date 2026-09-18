class_name RecipeTile
extends Panel

signal tile_pressed(tile: RecipeTile)
signal tile_hovered(tile: RecipeTile)
signal tile_unhovered(tile: RecipeTile)

const TILE_SIZE := 52

var recipe: RecipeData
var item: ItemData
var selected: bool = false

var _icon: TextureRect
var _lock: Label
var _station_mark: Label
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_hover: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	custom_maximum_size = Vector2(TILE_SIZE, TILE_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_style_normal = _make_style(Color(0.11, 0.15, 0.21, 1), Color(0.42, 0.52, 0.64, 1), 1)
	_style_hover = _make_style(Color(0.14, 0.19, 0.26, 1), Color(0.72, 0.78, 0.55, 1), 1)
	_style_selected = _make_style(Color(0.16, 0.16, 0.12, 1), Color(0.86, 0.68, 0.18, 1), 2)
	add_theme_stylebox_override("panel", _style_normal)
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 4
	_icon.offset_top = 4
	_icon.offset_right = -4
	_icon.offset_bottom = -4
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_station_mark = Label.new()
	_station_mark.name = "StationMark"
	_station_mark.text = "⚒"
	_station_mark.visible = false
	_station_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_station_mark.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_station_mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_station_mark.offset_left = -16
	_station_mark.offset_top = -14
	_station_mark.add_theme_font_size_override("font_size", 10)
	_station_mark.add_theme_color_override("font_color", Color(0.92, 0.78, 0.38, 1))
	_station_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_station_mark)
	_lock = Label.new()
	_lock.name = "Lock"
	_lock.text = "🔒"
	_lock.visible = false
	_lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lock.add_theme_font_size_override("font_size", 14)
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lock)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void:
		if not selected:
			add_theme_stylebox_override("panel", _style_hover)
		tile_hovered.emit(self)
	)
	mouse_exited.connect(func() -> void:
		_refresh_style()
		tile_unhovered.emit(self)
	)


func apply(p_recipe: RecipeData, p_item: ItemData, p_selected: bool, missing_materials: bool, missing_station: bool, locked: bool) -> void:
	recipe = p_recipe
	item = p_item
	selected = p_selected
	if _icon != null:
		_icon.texture = p_item.icon if p_item != null else null
	if locked:
		modulate = Color(0.28, 0.3, 0.34, 1)
	elif missing_station:
		modulate = Color(0.42, 0.44, 0.48, 1)
	elif missing_materials:
		modulate = Color(0.62, 0.64, 0.68, 1)
	else:
		modulate = Color.WHITE
	if _lock != null:
		_lock.visible = locked
	if _station_mark != null:
		_station_mark.visible = missing_station and not locked
	_refresh_style()


func _refresh_style() -> void:
	add_theme_stylebox_override("panel", _style_selected if selected else _style_normal)


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	tile_pressed.emit(self)


func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.anti_aliasing = false
	return style
