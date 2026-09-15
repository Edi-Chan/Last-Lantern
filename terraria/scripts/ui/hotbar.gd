class_name Hotbar
extends HBoxContainer

## Gehoert an: HUD/Hotbar in res://scenes/ui/hud.tscn
## Zeigt Inventory-Slots 0-9. Auswahl liegt in Inventory.selected_hotbar_index.
## Basisgroesse ist ca. 200% der alten 24px-Slots, danach greift UI Scale.

@export var item_catalog: ItemCatalog

const BASE_SLOT_SIZE := 48.0
const BASE_SEPARATION := 8.0
const BASE_BOTTOM_MARGIN := 16.0
const BASE_SIDE_MARGIN := 16.0
const ICON_INSET := 4.0
const MIN_SLOT_SIZE := 24.0

var _inventory: Inventory
var _slot_size: int = int(BASE_SLOT_SIZE)

func _ready() -> void:
	_inventory = get_tree().get_first_node_in_group("player_inventory") as Inventory
	add_to_group("hotbar_ui")
	if _inventory != null:
		_inventory.inventory_changed.connect(refresh)
		_inventory.selected_slot_changed.connect(_on_selected_changed)
	if not SettingsManager.ui_scale_changed.is_connected(_on_ui_scale_changed):
		SettingsManager.ui_scale_changed.connect(_on_ui_scale_changed)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_viewport_size_changed):
		vp.size_changed.connect(_on_viewport_size_changed)
	for i in Inventory.HOTBAR_COUNT:
		var slot := get_node("Slot%d" % i) as Control
		if slot != null:
			slot.clip_contents = true
			slot.mouse_filter = Control.MOUSE_FILTER_STOP
			slot.gui_input.connect(_on_slot_gui_input.bind(i))
			var icon := slot.get_node_or_null("Icon") as TextureRect
			var amount := slot.get_node_or_null("Amount") as Label
			if icon != null:
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			if amount != null:
				amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ensure_category_indicator(slot)
			_ensure_favorite_star(slot)
			_ensure_slot_number(slot, i)
	_apply_layout()
	refresh()


func _on_ui_scale_changed(_scale: float) -> void:
	_apply_layout()


func _on_viewport_size_changed() -> void:
	_apply_layout()


func _resolved_slot_size() -> int:
	var available := get_viewport_rect().size.x - BASE_SIDE_MARGIN * 2.0
	var needed := BASE_SLOT_SIZE * float(Inventory.HOTBAR_COUNT) + BASE_SEPARATION * float(Inventory.HOTBAR_COUNT - 1)
	if needed <= available:
		return int(BASE_SLOT_SIZE)
	var scale := available / needed
	return maxi(int(MIN_SLOT_SIZE), int(floor(BASE_SLOT_SIZE * scale)))


func _apply_layout() -> void:
	_slot_size = _resolved_slot_size()
	var size_ratio := float(_slot_size) / BASE_SLOT_SIZE
	var separation := maxi(4, int(round(BASE_SEPARATION * size_ratio)))
	var bottom := maxi(8, int(round(BASE_BOTTOM_MARGIN * size_ratio)))
	var side := maxi(8, int(round(BASE_SIDE_MARGIN * size_ratio)))
	var extra := maxi(4, int(round(8.0 * size_ratio)))
	offset_left = float(side)
	offset_right = float(-side)
	offset_bottom = float(-bottom)
	offset_top = float(-(bottom + _slot_size + extra))
	add_theme_constant_override("separation", separation)
	alignment = BoxContainer.ALIGNMENT_CENTER
	var slot_vec := Vector2(_slot_size, _slot_size)
	var inset := maxf(2.0, ICON_INSET * size_ratio)
	for i in Inventory.HOTBAR_COUNT:
		var slot := get_node("Slot%d" % i) as Control
		if slot == null:
			continue
		slot.custom_minimum_size = slot_vec
		slot.custom_maximum_size = slot_vec
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon != null:
			icon.anchor_left = 0.0
			icon.anchor_top = 0.0
			icon.anchor_right = 1.0
			icon.anchor_bottom = 1.0
			icon.offset_left = inset
			icon.offset_top = inset
			icon.offset_right = -inset
			icon.offset_bottom = -inset
		var amount := slot.get_node_or_null("Amount") as Label
		if amount != null:
			_style_amount_label(amount, size_ratio)
		_style_category_indicator(slot, size_ratio)
		_style_favorite_star(slot, size_ratio)
		_style_slot_number(slot, size_ratio)


func _style_amount_label(label: Label, size_ratio: float = 1.0) -> void:
	label.anchor_left = 1.0
	label.anchor_top = 1.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = -30.0 * size_ratio
	label.offset_top = -18.0 * size_ratio
	label.offset_right = -1.0
	label.offset_bottom = 0.0
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", maxi(8, int(round(14.0 * size_ratio))))
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", maxi(3, int(round(4.0 * size_ratio))))


func _ensure_category_indicator(slot: Control) -> void:
	if slot == null or slot.get_node_or_null("CategoryIndicator") != null:
		return
	var border := ColorRect.new()
	border.name = "CategoryIndicator"
	border.visible = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.color = Color(0.08, 0.08, 0.1, 0.95)
	border.z_index = 2
	slot.add_child(border)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_child(fill)


func _style_category_indicator(slot: Control, size_ratio: float) -> void:
	var border := slot.get_node_or_null("CategoryIndicator") as ColorRect
	if border == null:
		return
	var pad := 2.0 * size_ratio
	var box := 10.0 * size_ratio
	border.anchor_left = 0.0
	border.anchor_top = 0.0
	border.anchor_right = 0.0
	border.anchor_bottom = 0.0
	border.offset_left = pad
	border.offset_top = pad
	border.offset_right = pad + box
	border.offset_bottom = pad + box
	var fill := border.get_node_or_null("Fill") as ColorRect
	if fill == null:
		return
	var inner_pad := 2.0 * size_ratio
	var inner := 6.0 * size_ratio
	fill.position = Vector2(inner_pad, inner_pad)
	fill.size = Vector2(inner, inner)


func _ensure_favorite_star(slot: Control) -> void:
	if slot == null or slot.get_node_or_null("FavoriteStar") != null:
		return
	var star := Label.new()
	star.name = "FavoriteStar"
	star.visible = false
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.z_index = 3
	star.text = "★"
	slot.add_child(star)


func _style_favorite_star(slot: Control, size_ratio: float) -> void:
	var star := slot.get_node_or_null("FavoriteStar") as Label
	if star == null:
		return
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	star.add_theme_font_size_override("font_size", maxi(8, int(round(14.0 * size_ratio))))
	star.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2, 1))
	star.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	star.add_theme_constant_override("outline_size", 2)
	star.anchor_left = 1.0
	star.anchor_top = 0.0
	star.anchor_right = 1.0
	star.anchor_bottom = 0.0
	star.offset_left = -16.0 * size_ratio
	star.offset_top = 0.0
	star.offset_right = 0.0
	star.offset_bottom = 14.0 * size_ratio


func _ensure_slot_number(slot: Control, index: int) -> void:
	if slot == null or slot.get_node_or_null("SlotNumber") != null:
		return
	var number := Label.new()
	number.name = "SlotNumber"
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.z_index = 1
	number.text = "0" if index == 9 else str(index + 1)
	slot.add_child(number)


func _style_slot_number(slot: Control, size_ratio: float) -> void:
	var number := slot.get_node_or_null("SlotNumber") as Label
	if number == null:
		return
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	number.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	number.add_theme_font_size_override("font_size", maxi(8, int(round(10.0 * size_ratio))))
	number.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.72))
	number.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	number.add_theme_constant_override("outline_size", 2)
	number.anchor_left = 0.0
	number.anchor_top = 1.0
	number.anchor_right = 0.0
	number.anchor_bottom = 1.0
	number.offset_left = 2.0 * size_ratio
	number.offset_top = -14.0 * size_ratio
	number.offset_right = 16.0 * size_ratio
	number.offset_bottom = -1.0


func _on_selected_changed(_index: int) -> void:
	refresh()


func _is_inventory_open() -> bool:
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	return inventory != null and bool(inventory.visible)


func _unhandled_input(event: InputEvent) -> void:
	if _inventory == null:
		return
	if UIManager.is_blocking_gameplay():
		return
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("is_open") and world_map.is_open():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not visible or _is_inventory_open():
				return
			var hovered := get_viewport().gui_get_hovered_control()
			if hovered is ScrollContainer:
				return
			_inventory.set_selected_hotbar_index(_inventory.selected_hotbar_index - 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else _inventory.selected_hotbar_index + 1)
	elif event.is_action_pressed("hotbar_1"):
		_inventory.set_selected_hotbar_index(0)
	elif event.is_action_pressed("hotbar_2"):
		_inventory.set_selected_hotbar_index(1)
	elif event.is_action_pressed("hotbar_3"):
		_inventory.set_selected_hotbar_index(2)
	elif event.is_action_pressed("hotbar_4"):
		_inventory.set_selected_hotbar_index(3)
	elif event.is_action_pressed("hotbar_5"):
		_inventory.set_selected_hotbar_index(4)
	elif event.is_action_pressed("hotbar_6"):
		_inventory.set_selected_hotbar_index(5)
	elif event.is_action_pressed("hotbar_7"):
		_inventory.set_selected_hotbar_index(6)
	elif event.is_action_pressed("hotbar_8"):
		_inventory.set_selected_hotbar_index(7)
	elif event.is_action_pressed("hotbar_9"):
		_inventory.set_selected_hotbar_index(8)
	elif event.is_action_pressed("hotbar_10"):
		_inventory.set_selected_hotbar_index(9)


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if _inventory == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_inventory.set_selected_hotbar_index(index)


func refresh() -> void:
	if _inventory == null:
		return
	for i in Inventory.HOTBAR_COUNT:
		var slot := get_node("Slot%d" % i) as Panel
		var icon := slot.get_node("Icon") as TextureRect
		var amount := slot.get_node("Amount") as Label
		var data: Dictionary = _inventory.get_slot(i)
		var item_id := int(data["item_id"])
		var count := int(data["amount"])
		slot.modulate = Color(1.2, 1.15, 0.8) if i == _inventory.selected_hotbar_index else Color.WHITE
		if item_id < 0 or count <= 0:
			icon.texture = null
			amount.text = ""
			ItemData.apply_category_indicator(
				slot.get_node_or_null("CategoryIndicator") as ColorRect,
				slot.get_node_or_null("CategoryIndicator/Fill") as ColorRect,
				null,
				0
			)
			var empty_star := slot.get_node_or_null("FavoriteStar") as Label
			if empty_star != null:
				empty_star.visible = false
			continue
		var item := item_catalog.get_item(item_id) if item_catalog != null else null
		icon.texture = item.icon if item != null else null
		amount.text = str(count) if count > 1 else ""
		ItemData.apply_category_indicator(
			slot.get_node_or_null("CategoryIndicator") as ColorRect,
			slot.get_node_or_null("CategoryIndicator/Fill") as ColorRect,
			item,
			count
		)
		var star := slot.get_node_or_null("FavoriteStar") as Label
		if star != null:
			star.visible = bool(data.get("favorite", false))
