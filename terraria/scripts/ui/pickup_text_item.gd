class_name PickupTextItem
extends HBoxContainer

## Eine gepoolte Pickup-Zeile. Kleiner Floating-Text, keine Interaktion.

const ICON_SIZE := 11

var active: bool = false
var age: float = 0.0
var lifetime: float = 1.6
var fade_time: float = 0.4
var world_pos: Vector2 = Vector2.ZERO
var rise: float = 0.0
var rise_distance: float = 18.0
var spawn_order: int = 0
var item_id: int = -1
var amount: int = 0

var _icon: TextureRect
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 2)
	visible = false
	modulate.a = 0.0
	_ensure_children()


func _ensure_children() -> void:
	if _icon != null:
		return
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.name = "Label"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.86))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_font_size_override("font_size", 9)
	add_child(_label)


func activate(p_item_id: int, p_amount: int, item: ItemData, origin: Vector2) -> void:
	_ensure_children()
	item_id = p_item_id
	amount = maxi(p_amount, 1)
	_apply_visual(item)
	world_pos = origin
	age = 0.0
	rise = 0.0
	active = true
	visible = true
	modulate.a = 1.0
	reset_size()
	pivot_offset = size * 0.5


func add_amount(extra: int, item: ItemData) -> void:
	if extra <= 0:
		return
	amount += extra
	_apply_visual(item)
	age = 0.0
	reset_size()
	pivot_offset = size * 0.5


func deactivate() -> void:
	active = false
	visible = false
	modulate.a = 0.0
	item_id = -1
	amount = 0
	if _label != null:
		_label.text = ""
	if _icon != null:
		_icon.texture = null


func tick(delta: float, canvas_xform: Transform2D, ui_scale: float) -> bool:
	if not active:
		return false
	age += delta
	var t := clampf(age / maxf(lifetime, 0.001), 0.0, 1.0)
	rise = rise_distance * t
	var screen: Vector2 = canvas_xform * (world_pos + Vector2(0.0, -rise))
	var ui := maxf(ui_scale, 0.001)
	position = screen / ui - size * 0.5
	var fade_start := lifetime - fade_time
	if age >= fade_start:
		modulate.a = 1.0 - clampf((age - fade_start) / maxf(fade_time, 0.001), 0.0, 1.0)
	else:
		modulate.a = 1.0
	if age >= lifetime:
		deactivate()
		return false
	return true


func _apply_visual(item: ItemData) -> void:
	_label.text = PickupTextPresenter.display_text(item, amount, item_id)
	_label.add_theme_color_override("font_color", PickupTextPresenter.color_for(item))
	var tex := PickupTextPresenter.icon_for(item)
	_icon.texture = tex
	_icon.visible = tex != null
