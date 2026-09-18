class_name InventorySlotUI
extends Panel

## Wiederverwendbarer Slot fuer Inventar, Hotbar und Equipment.
## Drag & Drop laeuft ueber die Control-Methoden _get_drag_data / _can_drop_data /
## _drop_data. Das Verschieben selbst macht Inventory.transfer(), damit Hotbar,
## Inventar und Equipment auf derselben Datenquelle arbeiten.

signal slot_clicked(slot: InventorySlotUI)
signal slot_right_clicked(slot: InventorySlotUI)
signal slot_double_clicked(slot: InventorySlotUI)
signal slot_shift_clicked(slot: InventorySlotUI)
signal slot_ctrl_clicked(slot: InventorySlotUI)
signal slot_hovered(slot: InventorySlotUI)
signal slot_unhovered(slot: InventorySlotUI)

@export var slot_index: int = -1
@export var equipment_key: String = ""

@onready var icon: TextureRect = $Icon
@onready var amount_label: Label = $AmountLabel
@onready var selection_border: ColorRect = $SelectionBorder
@onready var _category_indicator: ColorRect = $CategoryIndicator
@onready var _category_fill: ColorRect = $CategoryIndicator/Fill
@onready var _favorite_star: Label = get_node_or_null("FavoriteStar") as Label
@onready var _empty_hint: TextureRect = get_node_or_null("EmptyHint") as TextureRect

var _inventory: Inventory
var _item: ItemData
var _amount: int = 0
var _selected: bool = false
var _hovered: bool = false
var _dragging: bool = false
var _favorite: bool = false
var _skip_drag: bool = false
var _slot_px: int = 24
var _style_normal: StyleBox = preload("res://resources/ui/inv_slot.tres")
var _style_selected: StyleBox = preload("res://resources/ui/inv_slot_selected.tres")
var _style_hover: StyleBox = preload("res://resources/ui/inv_slot_hover.tres")

func _ready() -> void:
	clip_contents = true
	configure_size(_slot_px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_inventory = get_tree().get_first_node_in_group("player_inventory") as Inventory
	_style_amount_label()
	_style_category_indicator()
	_style_favorite_star()
	_refresh_panel_style()


func configure_size(px: int) -> void:
	_slot_px = maxi(16, px)
	var sz := Vector2(_slot_px, _slot_px)
	custom_minimum_size = sz
	custom_maximum_size = sz
	size = sz
	if icon != null:
		icon.offset_left = 3.0
		icon.offset_top = 3.0
		icon.offset_right = -3.0
		icon.offset_bottom = -3.0
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


func _style_amount_label() -> void:
	if amount_label == null:
		return
	amount_label.anchor_left = 1.0
	amount_label.anchor_top = 1.0
	amount_label.anchor_right = 1.0
	amount_label.anchor_bottom = 1.0
	amount_label.offset_left = -16.0
	amount_label.offset_top = -11.0
	amount_label.offset_right = 0.0
	amount_label.offset_bottom = 0.0
	amount_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	amount_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amount_label.add_theme_font_size_override("font_size", 9)
	amount_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	amount_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	amount_label.add_theme_constant_override("outline_size", 3)


func _style_category_indicator() -> void:
	if _category_indicator == null:
		return
	_category_indicator.anchor_left = 0.0
	_category_indicator.anchor_top = 0.0
	_category_indicator.anchor_right = 0.0
	_category_indicator.anchor_bottom = 0.0
	_category_indicator.offset_left = 1.0
	_category_indicator.offset_top = 1.0
	_category_indicator.offset_right = 7.0
	_category_indicator.offset_bottom = 7.0
	_category_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_category_indicator.color = Color(0.08, 0.08, 0.1, 0.95)
	_category_indicator.visible = false
	if _category_fill == null:
		return
	_category_fill.position = Vector2(1, 1)
	_category_fill.size = Vector2(4, 4)
	_category_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style_favorite_star() -> void:
	if _favorite_star == null:
		return
	_favorite_star.anchor_left = 1.0
	_favorite_star.anchor_top = 0.0
	_favorite_star.anchor_right = 1.0
	_favorite_star.anchor_bottom = 0.0
	_favorite_star.offset_left = -9.0
	_favorite_star.offset_top = 0.0
	_favorite_star.offset_right = 0.0
	_favorite_star.offset_bottom = 8.0
	_favorite_star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_favorite_star.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_favorite_star.add_theme_font_size_override("font_size", 8)
	_favorite_star.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2, 1))
	_favorite_star.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_favorite_star.add_theme_constant_override("outline_size", 2)
	_favorite_star.visible = false


## Referenz auf die Datenquelle: int fuer Inventar/Hotbar, String fuer Equipment.
## slot_index ist immer der echte Inventory-Index, nie die sichtbare View-Position.
func get_slot_ref() -> Variant:
	if not equipment_key.is_empty():
		return equipment_key
	return slot_index


func get_source_slot_index() -> int:
	return slot_index


func is_dragging() -> bool:
	return _dragging


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null:
		return
	if not mouse.pressed:
		_skip_drag = false
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		if _item != null and _amount > 0:
			slot_right_clicked.emit(self)
		accept_event()
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.shift_pressed:
		_skip_drag = true
		if _item != null and _amount > 0:
			slot_shift_clicked.emit(self)
		accept_event()
		return
	if mouse.ctrl_pressed:
		_skip_drag = true
		if _item != null and _amount > 0:
			slot_ctrl_clicked.emit(self)
		accept_event()
		return
	if mouse.double_click:
		_skip_drag = true
		if _item != null and _amount > 0:
			slot_double_clicked.emit(self)
		accept_event()
		return
	slot_clicked.emit(self)


func apply_item(item: ItemData, amount: int, selected: bool = false, favorite: bool = false) -> void:
	_item = item
	_amount = amount
	_selected = selected
	_favorite = favorite
	_refresh_visual()


func _refresh_visual() -> void:
	if icon == null:
		return
	if _item == null or _amount <= 0:
		icon.texture = null
		if amount_label != null:
			amount_label.text = ""
	else:
		icon.texture = _item.icon
		if amount_label != null:
			amount_label.text = str(_amount) if _amount > 1 else ""
	ItemData.apply_category_indicator(_category_indicator, _category_fill, _item, _amount)
	if _favorite_star != null:
		_favorite_star.visible = _favorite and _item != null and _amount > 0
		_favorite_star.text = "★" if _favorite_star.visible else ""
	if _empty_hint != null:
		_empty_hint.visible = _item == null or _amount <= 0
		_empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_hint.z_index = -1
	if selection_border != null:
		selection_border.visible = false
	_refresh_panel_style()
	var tint := Color.WHITE
	if _selected:
		tint = Color(1.05, 1.04, 0.95)
	elif _hovered and _item != null and _amount > 0:
		tint = Color(1.08, 1.08, 1.1)
	if _dragging:
		tint.a = 0.35
	modulate = tint


func _refresh_panel_style() -> void:
	if _selected:
		add_theme_stylebox_override("panel", _style_selected)
	elif _hovered:
		add_theme_stylebox_override("panel", _style_hover)
	else:
		add_theme_stylebox_override("panel", _style_normal)


# --- Drag & Drop -------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	if _skip_drag or _inventory == null:
		return null
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		return null
	var ref: Variant = get_slot_ref()
	var item: ItemData = _inventory.get_ref_item(ref)
	if item == null:
		return null
	set_drag_preview(_build_drag_preview(item, _inventory.get_ref_amount(ref)))
	_dragging = true
	_hovered = false
	_refresh_visual()
	slot_unhovered.emit(self)
	return {"source_ref": ref}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _inventory == null or typeof(data) != TYPE_DICTIONARY or not data.has("source_ref"):
		return false
	var source_ref: Variant = data["source_ref"]
	var dragged: ItemData = _inventory.get_ref_item(source_ref)
	if dragged == null or not _inventory.accepts(get_slot_ref(), dragged):
		return false
	# Beim Tausch muss auch das hier liegende Item zurueck in die Quelle passen.
	var here: ItemData = _inventory.get_ref_item(get_slot_ref())
	return here == null or _inventory.accepts(source_ref, here)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _inventory == null or typeof(data) != TYPE_DICTIONARY or not data.has("source_ref"):
		return
	_inventory.transfer(data["source_ref"], get_slot_ref())


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		_refresh_visual()


func _build_drag_preview(item: ItemData, amount: int) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate = Color(1.0, 1.0, 1.0, 0.8)
	root.scale = Vector2.ONE

	var body := Panel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size = size
	# Godot setzt die Vorschau mit der Ecke an den Cursor, hier mittig darunter.
	body.position = -size * 0.5
	var panel_style: StyleBox = get_theme_stylebox("panel")
	if panel_style != null:
		body.add_theme_stylebox_override("panel", panel_style)
	root.add_child(body)

	var preview_icon := TextureRect.new()
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_icon.texture = item.icon
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	preview_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_icon.offset_left = 2.0
	preview_icon.offset_top = 2.0
	preview_icon.offset_right = -2.0
	preview_icon.offset_bottom = -2.0
	body.add_child(preview_icon)

	var cat_border := ColorRect.new()
	cat_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_border.color = Color(0.08, 0.08, 0.1, 0.95)
	cat_border.position = Vector2(1, 1)
	cat_border.size = Vector2(6, 6)
	body.add_child(cat_border)
	var cat_fill := ColorRect.new()
	cat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_fill.position = Vector2(1, 1)
	cat_fill.size = Vector2(4, 4)
	cat_border.add_child(cat_fill)
	ItemData.apply_category_indicator(cat_border, cat_fill, item, amount)

	if amount > 1:
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = str(amount)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
		label.add_theme_constant_override("outline_size", 4)
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		label.offset_left = -20.0
		label.offset_top = -12.0
		label.offset_right = -1.0
		label.offset_bottom = 0.0
		body.add_child(label)

	return root


func _on_mouse_entered() -> void:
	if _dragging or _item == null or _amount <= 0:
		return
	_hovered = true
	_refresh_visual()
	slot_hovered.emit(self)


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_visual()
	slot_unhovered.emit(self)
