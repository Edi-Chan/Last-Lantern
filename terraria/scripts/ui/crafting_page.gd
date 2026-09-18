class_name CraftingPage
extends Control

## Drei-Spalten-Crafting nach Referenzlayout. Nutzt vorhandene Items und Rezepte.

const CATEGORY_ORDER: Array[int] = [
	RecipeData.UiCategory.ALL,
	RecipeData.UiCategory.TOOLS,
	RecipeData.UiCategory.WEAPONS,
	RecipeData.UiCategory.ARMOR,
	RecipeData.UiCategory.BUILDING_PARTS,
	RecipeData.UiCategory.STATIONS,
	RecipeData.UiCategory.CONSUMABLE,
	RecipeData.UiCategory.LIGHT,
	RecipeData.UiCategory.DECORATION,
	RecipeData.UiCategory.OTHER,
]
const GRID_COLUMNS := 8
const OK_COLOR := Color(0.42, 0.82, 0.52, 1)
const BAD_COLOR := Color(0.86, 0.4, 0.38, 1)
const MUTED := Color(0.7, 0.76, 0.82, 1)

var _crafting: CraftingSystem
var _inventory: Inventory
var _item_catalog: ItemCatalog
var _context: int = RecipeData.Station.NONE
var _category: int = RecipeData.UiCategory.ALL
var _weapon_kind_filter: int = -1
var _search: String = ""
var _craftable_only: bool = false
var _selected: RecipeData
var _quantity: int = 1
var _nearby: Array[int] = []
var _tiles: Array[RecipeTile] = []
var _category_buttons: Dictionary = {}
var _built: bool = false

var _context_label: Label
var _search_edit: LineEdit
var _craftable_check: CheckBox
var _category_box: VBoxContainer
var _recipe_host: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_icon: TextureRect
var _detail_name: Label
var _detail_sub: Label
var _owned_label: Label
var _detail_desc: Label
var _stats_box: VBoxContainer
var _mats_box: VBoxContainer
var _station_name: Label
var _station_state: Label
var _qty_label: Label
var _minus_btn: Button
var _plus_btn: Button
var _craft_btn: Button
var _craft_fill: ColorRect
var _craft_tween: Tween
var _craft_feedback_playing: bool = false
var _tooltip: PanelContainer
var _tooltip_label: Label
var _empty_label: Label


func bind(crafting: CraftingSystem, inventory: Inventory, items: ItemCatalog) -> void:
	_crafting = crafting
	_inventory = inventory
	_item_catalog = items
	if _built:
		refresh()


func set_station_context(context: int) -> void:
	_context = context
	_selected = null
	_quantity = 1
	_category = RecipeData.UiCategory.ALL
	_weapon_kind_filter = -1
	if _built:
		refresh()


func get_station_context() -> int:
	return _context


func refresh() -> void:
	if not _built:
		return
	_nearby.clear()
	if _crafting != null:
		for kind in _crafting.collect_nearby_stations(get_tree()):
			_nearby.append(int(kind))
	_update_context_banner()
	_rebuild_categories()
	_rebuild_recipes()
	_update_details()


func _ready() -> void:
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_built = true
	refresh()


func _build_layout() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_build_category_panel())
	root.add_child(_build_recipe_panel())
	root.add_child(_build_detail_panel())
	_build_tooltip()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.125, 1)
	style.border_color = Color(0.28, 0.36, 0.45, 1)
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	style.anti_aliasing = false
	return style


func _build_category_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(141, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	_category_box = VBoxContainer.new()
	_category_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_category_box.add_theme_constant_override("separation", 3)
	scroll.add_child(_category_box)
	return panel


func _build_recipe_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_context_label = Label.new()
	_context_label.visible = false
	_context_label.add_theme_font_size_override("font_size", 12)
	_context_label.add_theme_color_override("font_color", Color(0.9, 0.78, 0.42, 1))
	box.add_child(_context_label)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	box.add_child(toolbar)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Suchen..."
	_search_edit.custom_minimum_size = Vector2(144, 19)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.add_theme_font_size_override("font_size", 11)
	if ResourceLoader.exists("res://assets/ui/search_icon.png"):
		_search_edit.right_icon = load("res://assets/ui/search_icon.png") as Texture2D
	_search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(_search_edit)
	_craftable_check = CheckBox.new()
	_craftable_check.text = "Nur herstellbare anzeigen"
	_craftable_check.add_theme_font_size_override("font_size", 11)
	_craftable_check.toggled.connect(_on_craftable_toggled)
	toolbar.add_child(_craftable_check)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_recipe_host = VBoxContainer.new()
	_recipe_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_host.add_theme_constant_override("separation", 10)
	scroll.add_child(_recipe_host)
	_empty_label = Label.new()
	_empty_label.text = "Keine Rezepte in dieser Ansicht."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_color_override("font_color", MUTED)
	_empty_label.visible = false
	box.add_child(_empty_label)
	return panel


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(214, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style())
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_detail_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	_detail_scroll.add_child(body)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(58, 58)
	icon_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_frame.add_theme_stylebox_override("panel", preload("res://resources/ui/inv_slot.tres"))
	body.add_child(icon_frame)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(60, 60)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_frame.add_child(_detail_icon)
	_detail_name = Label.new()
	_detail_name.add_theme_font_size_override("font_size", 14)
	_detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_name)
	_detail_sub = Label.new()
	_detail_sub.add_theme_font_size_override("font_size", 11)
	_detail_sub.add_theme_color_override("font_color", MUTED)
	_detail_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_sub)
	_owned_label = Label.new()
	_owned_label.add_theme_font_size_override("font_size", 11)
	_owned_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.72, 1))
	body.add_child(_owned_label)
	_detail_desc = Label.new()
	_detail_desc.add_theme_font_size_override("font_size", 11)
	_detail_desc.add_theme_color_override("font_color", Color(0.74, 0.78, 0.82, 1))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_detail_desc)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	body.add_child(_stats_box)
	var mats_title := _section_title("Benötigte Materialien")
	body.add_child(mats_title)
	_mats_box = VBoxContainer.new()
	_mats_box.add_theme_constant_override("separation", 4)
	body.add_child(_mats_box)
	body.add_child(_section_title("Benötigte Werkstation"))
	_station_name = Label.new()
	_station_name.add_theme_font_size_override("font_size", 12)
	body.add_child(_station_name)
	_station_state = Label.new()
	_station_state.add_theme_font_size_override("font_size", 11)
	body.add_child(_station_state)
	var qty_row := HBoxContainer.new()
	qty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	qty_row.add_theme_constant_override("separation", 8)
	outer.add_child(qty_row)
	_minus_btn = Button.new()
	_minus_btn.text = "–"
	_minus_btn.custom_minimum_size = Vector2(28, 24)
	_minus_btn.pressed.connect(func() -> void: _set_quantity(_quantity - 1))
	qty_row.add_child(_minus_btn)
	_qty_label = Label.new()
	_qty_label.custom_minimum_size = Vector2(36, 0)
	_qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qty_label.add_theme_font_size_override("font_size", 14)
	qty_row.add_child(_qty_label)
	_plus_btn = Button.new()
	_plus_btn.text = "+"
	_plus_btn.custom_minimum_size = Vector2(28, 24)
	_plus_btn.pressed.connect(func() -> void: _set_quantity(_quantity + 1))
	qty_row.add_child(_plus_btn)
	_craft_btn = Button.new()
	_craft_btn.text = "Herstellen"
	_craft_btn.custom_minimum_size = Vector2(0, 26)
	_craft_btn.clip_contents = true
	_craft_btn.add_theme_stylebox_override("normal", preload("res://resources/ui/inv_craft_button.tres"))
	_craft_btn.add_theme_stylebox_override("hover", preload("res://resources/ui/inv_craft_button.tres"))
	_craft_btn.add_theme_stylebox_override("pressed", preload("res://resources/ui/inv_craft_button.tres"))
	_craft_btn.pressed.connect(_on_craft_pressed)
	_craft_fill = ColorRect.new()
	_craft_fill.color = Color(0.42, 0.78, 0.52, 0.72)
	_craft_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_craft_fill.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_craft_fill.anchor_right = 0.0
	_craft_fill.offset_left = 1.0
	_craft_fill.offset_right = -1.0
	_craft_fill.offset_top = -5.0
	_craft_fill.offset_bottom = -1.0
	_craft_btn.add_child(_craft_fill)
	outer.add_child(_craft_btn)
	var hint := Label.new()
	hint.text = "Halte Shift, um mehrere herzustellen."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.58, 0.64, 0.7, 1))
	outer.add_child(hint)
	return panel


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 1))
	return label


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.z_index = 40
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	style.border_color = Color(0.82, 0.78, 0.48, 1)
	style.set_border_width_all(1)
	style.content_margin_left = 6
	style.content_margin_top = 4
	style.content_margin_right = 6
	style.content_margin_bottom = 4
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(80, 0)
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)


func _on_search_changed(text: String) -> void:
	_search = text.strip_edges()
	_rebuild_recipes()


func _on_craftable_toggled(pressed: bool) -> void:
	_craftable_only = pressed
	_rebuild_recipes()


func _update_context_banner() -> void:
	if _context_label == null:
		return
	if _context == RecipeData.Station.NONE:
		_context_label.visible = false
		return
	_context_label.visible = true
	_context_label.text = "⚒ Werkstation: %s" % RecipeData.station_display_name(_context)


func _visible_recipes() -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	if _crafting == null:
		return result
	for recipe in _crafting.recipes_for_context(_context):
		if recipe == null:
			continue
		if not recipe.unlocked and _craftable_only:
			continue
		var item := _item_of(recipe)
		if item == null:
			continue
		if _category != RecipeData.UiCategory.ALL and int(recipe.ui_category) != _category:
			continue
		if _category == RecipeData.UiCategory.WEAPONS and _weapon_kind_filter >= 0:
			if int(item.weapon_kind) != _weapon_kind_filter:
				continue
		if not _search.is_empty():
			var q := _search.to_lower()
			if item.display_name.to_lower().find(q) < 0 and str(item.id).find(q) < 0:
				continue
		if _craftable_only and not _crafting.is_craftable(recipe, _inventory, _nearby):
			continue
		result.append(recipe)
	return result


func _categories_in_context() -> Array[int]:
	var present: Dictionary = {}
	if _crafting != null:
		for recipe in _crafting.recipes_for_context(_context):
			if recipe != null:
				present[int(recipe.ui_category)] = true
	var result: Array[int] = []
	result.append(RecipeData.UiCategory.ALL)
	for category in CATEGORY_ORDER:
		if category == RecipeData.UiCategory.ALL:
			continue
		if present.has(category):
			result.append(category)
	return result


func _rebuild_categories() -> void:
	if _category_box == null:
		return
	for child in _category_box.get_children():
		child.queue_free()
	_category_buttons.clear()
	var available := _categories_in_context()
	if not available.has(_category):
		_category = RecipeData.UiCategory.ALL
	for category in available:
		var button := Button.new()
		button.text = RecipeData.ui_category_display_name(category)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 28)
		button.pressed.connect(_on_category_pressed.bind(category))
		_apply_category_style(button, category == _category)
		_category_box.add_child(button)
		_category_buttons[category] = button
	if _category == RecipeData.UiCategory.WEAPONS:
		_add_weapon_kind_filters()


func _on_category_pressed(category: int) -> void:
	_category = category
	if category != RecipeData.UiCategory.WEAPONS:
		_weapon_kind_filter = -1
	_rebuild_categories()
	_rebuild_recipes()


func _add_weapon_kind_filters() -> void:
	var spacer := Label.new()
	spacer.text = "Waffentyp"
	spacer.add_theme_font_size_override("font_size", 11)
	spacer.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 1))
	_category_box.add_child(spacer)
	var kinds := [
		[-1, "Alle"],
		[int(ItemData.WeaponKind.SWORD), "Schwerter"],
		[int(ItemData.WeaponKind.SPEAR), "Speere"],
		[int(ItemData.WeaponKind.BOW), "Bögen"],
		[int(ItemData.WeaponKind.LANTERN), "Kampflaternen"],
	]
	for entry in kinds:
		var kind := int(entry[0])
		var button := Button.new()
		button.text = "  %s" % str(entry[1])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 24)
		button.pressed.connect(_on_weapon_kind_pressed.bind(kind))
		_apply_weapon_filter_style(button, kind == _weapon_kind_filter)
		_category_box.add_child(button)


func _on_weapon_kind_pressed(kind: int) -> void:
	_weapon_kind_filter = kind
	_rebuild_categories()
	_rebuild_recipes()


func _apply_weapon_filter_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	style.anti_aliasing = false
	if selected:
		style.bg_color = Color(0.28, 0.12, 0.12, 1)
		style.border_color = Color(0.90, 0.32, 0.28, 1)
		button.add_theme_color_override("font_color", Color(1, 0.88, 0.86, 1))
	else:
		style.bg_color = Color(0.08, 0.10, 0.14, 1)
		style.border_color = Color(0.28, 0.34, 0.42, 1)
		button.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86, 1))
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


func _apply_category_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.anti_aliasing = false
	if selected:
		style.bg_color = Color(0.22, 0.18, 0.10, 1)
		style.border_color = Color(0.86, 0.68, 0.18, 1)
		button.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 1))
	else:
		style.bg_color = Color(0.09, 0.12, 0.16, 1)
		style.border_color = Color(0.32, 0.4, 0.5, 1)
		button.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 1))
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)


func _rebuild_recipes() -> void:
	for child in _recipe_host.get_children():
		child.queue_free()
	_tiles.clear()
	var recipes := _visible_recipes()
	_empty_label.visible = recipes.is_empty()
	if recipes.is_empty():
		if _selected != null:
			_selected = null
			_update_details()
		return
	if _selected != null:
		var still := false
		for recipe in recipes:
			if recipe.recipe_id == _selected.recipe_id:
				still = true
				break
		if not still:
			_selected = recipes[0]
	elif not recipes.is_empty():
		_selected = recipes[0]
	var grouped: Dictionary = {}
	for recipe in recipes:
		var key := int(recipe.ui_category)
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(recipe)
	for category in CATEGORY_ORDER:
		if category == RecipeData.UiCategory.ALL or not grouped.has(category):
			continue
		if _category == RecipeData.UiCategory.ALL:
			var header := Label.new()
			header.text = RecipeData.ui_category_display_name(category)
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", Color(0.86, 0.9, 0.94, 1))
			_recipe_host.add_child(header)
		var grid := GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_recipe_host.add_child(grid)
		for recipe_variant in grouped[category]:
			var recipe := recipe_variant as RecipeData
			var tile := RecipeTile.new()
			grid.add_child(tile)
			_configure_tile(tile, recipe)
			_tiles.append(tile)
	_update_details()


func _configure_tile(tile: RecipeTile, recipe: RecipeData) -> void:
	var item := _item_of(recipe)
	var missing_mats := _inventory == null or not _inventory.can_consume_items(recipe.get_costs_for_quantity(1))
	var missing_station := recipe.requires_station() and not _stations_ok(recipe)
	var locked := not recipe.unlocked
	var selected := _selected != null and recipe.recipe_id == _selected.recipe_id
	tile.apply(recipe, item, selected, missing_mats, missing_station, locked)
	if not tile.tile_pressed.is_connected(_on_tile_pressed):
		tile.tile_pressed.connect(_on_tile_pressed)
	if not tile.tile_hovered.is_connected(_on_tile_hovered):
		tile.tile_hovered.connect(_on_tile_hovered)
	if not tile.tile_unhovered.is_connected(_on_tile_unhovered):
		tile.tile_unhovered.connect(_on_tile_unhovered)


func _on_tile_pressed(tile: RecipeTile) -> void:
	_selected = tile.recipe
	_quantity = 1
	for other in _tiles:
		if other.recipe != null:
			_configure_tile(other, other.recipe)
	_update_details()


func _on_tile_hovered(tile: RecipeTile) -> void:
	if tile.item == null or _tooltip == null:
		return
	var station := "Handwerk"
	if tile.recipe != null and tile.recipe.requires_station():
		station = RecipeData.station_display_name(int(tile.recipe.required_stations[0]))
	_tooltip_label.text = "%s\n%s\n%s" % [
		tile.item.display_name,
		RecipeData.ui_category_display_name(int(tile.recipe.ui_category)),
		station,
	]
	_tooltip.visible = true
	_position_tooltip()


func _on_tile_unhovered(_tile: RecipeTile) -> void:
	if _tooltip != null:
		_tooltip.visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	if _tooltip != null and _tooltip.visible:
		_position_tooltip()


func _position_tooltip() -> void:
	var mouse := get_local_mouse_position()
	var tip_size := _tooltip.get_combined_minimum_size()
	var pos := mouse + Vector2(12, 14)
	if pos.x + tip_size.x > self.size.x:
		pos.x = self.size.x - tip_size.x
	if pos.y + tip_size.y > self.size.y:
		pos.y = mouse.y - tip_size.y - 8.0
	_tooltip.position = pos


func _item_of(recipe: RecipeData) -> ItemData:
	if recipe == null or _item_catalog == null:
		return null
	return _item_catalog.get_item(recipe.output_item_id)


func _stations_ok(recipe: RecipeData) -> bool:
	if recipe == null or not recipe.requires_station():
		return true
	for station in recipe.required_stations:
		if int(station) != RecipeData.Station.NONE and not _nearby.has(int(station)):
			return false
	return true


func _set_quantity(value: int) -> void:
	var max_q := 1
	if _selected != null and _crafting != null:
		max_q = maxi(1, _crafting.max_craftable(_selected, _inventory, _nearby))
	_quantity = clampi(value, 1, max_q)
	_update_details()


func _update_details() -> void:
	var item := _item_of(_selected)
	if item == null:
		_detail_icon.texture = null
		_detail_name.text = "Kein Rezept ausgewählt"
		_detail_sub.text = ""
		if _owned_label != null:
			_owned_label.text = ""
		_detail_desc.text = ""
		_clear_box(_stats_box)
		_clear_box(_mats_box)
		_station_name.text = "—"
		_station_state.text = ""
		_qty_label.text = "1"
		_craft_btn.disabled = true
		if not _craft_feedback_playing:
			_craft_btn.text = "Herstellen"
		return
	_detail_icon.texture = item.icon
	_detail_name.text = item.display_name
	_detail_sub.text = item.get_inspect_subtitle()
	_detail_sub.add_theme_color_override("font_color", item.get_rarity_color())
	_update_owned_label(item)
	_detail_desc.text = item.description
	_detail_desc.visible = not item.description.is_empty()
	_fill_stats(item)
	_fill_materials()
	_fill_station()
	var max_q := _crafting.max_craftable(_selected, _inventory, _nearby) if _crafting != null else 0
	_quantity = clampi(_quantity, 1, maxi(1, max_q))
	_qty_label.text = str(_quantity)
	var can := _crafting != null and _crafting.evaluate(_selected, _inventory, _quantity, _nearby) == CraftingSystem.Result.OK
	_craft_btn.disabled = not can and not _craft_feedback_playing
	_minus_btn.disabled = _quantity <= 1
	_plus_btn.disabled = max_q <= _quantity
	if not _craft_feedback_playing:
		_craft_btn.text = "Herstellen"


func _update_owned_label(item: ItemData) -> void:
	if _owned_label == null:
		return
	if item == null or _inventory == null:
		_owned_label.text = ""
		return
	var owned := _inventory.get_total_amount(item.id)
	_owned_label.text = "Im Inventar: %d" % owned
	_owned_label.add_theme_color_override("font_color", OK_COLOR if owned > 0 else MUTED)


func _play_craft_feedback() -> void:
	if _craft_btn == null or _craft_fill == null:
		return
	_craft_feedback_playing = true
	_craft_btn.text = "Wird hergestellt..."
	_craft_fill.anchor_right = 0.0
	_craft_fill.color = Color(0.55, 0.82, 0.42, 0.85)
	if _craft_tween != null and _craft_tween.is_valid():
		_craft_tween.kill()
	_craft_tween = create_tween()
	_craft_tween.set_trans(Tween.TRANS_QUAD)
	_craft_tween.set_ease(Tween.EASE_OUT)
	_craft_tween.tween_property(_craft_fill, "anchor_right", 1.0, 0.28)
	_craft_tween.tween_callback(func() -> void:
		if _craft_btn == null:
			return
		_craft_btn.text = "Hergestellt"
		_craft_fill.color = Color(0.42, 0.86, 0.52, 0.95)
	)
	_craft_tween.tween_interval(0.42)
	_craft_tween.tween_callback(_reset_craft_feedback)


func _reset_craft_feedback() -> void:
	_craft_feedback_playing = false
	if _craft_fill != null:
		_craft_fill.anchor_right = 0.0
	if _craft_btn != null:
		_craft_btn.text = "Herstellen"
	_update_details()


func _fill_stats(item: ItemData) -> void:
	_clear_box(_stats_box)
	var damage := item.get_base_damage()
	if damage > 0:
		_stat_row("Schaden", str(damage))
	var speed := item.get_base_use_speed()
	if speed > 0.0 and (item.tool_data != null or item.is_weapon()):
		_stat_row("Angriffstempo", "%s / s" % _fmt(speed))
	var dur := item.get_base_max_durability()
	if dur > 0:
		_stat_row("Haltbarkeit", "%d / %d" % [dur, dur])
	if item.is_weapon():
		_stat_row("Waffentyp", ItemData.get_weapon_kind_display_name(int(item.weapon_kind)))
		var kb := item.get_weapon_knockback()
		if kb > 0.0:
			_stat_row("Rückstoß", _fmt(kb))
		var tier := item.get_weapon_tier()
		if tier > 0:
			_stat_row("Tier", str(tier))
		if item.weapon_data != null:
			var dark_mult := float(item.weapon_data.get("darkness_damage_multiplier"))
			if dark_mult > 1.0:
				_stat_row("Finsternis-Bonus", "× %s" % _fmt(dark_mult))
			var ammo_id := int(item.weapon_data.get("ammo_item_id"))
			if ammo_id >= 0 and _item_catalog != null:
				var ammo := _item_catalog.get_item(ammo_id)
				if ammo != null:
					_stat_row("Munition", ammo.display_name)
	var power := item.get_base_tool_power()
	if item.tool_data != null and power > 0:
		var power_name := "Spitzhacken-Power" if item.get_tool_category() == ToolData.ToolCategory.MINING else "Werkzeug-Power"
		_stat_row(power_name, str(power))
	if item.defense > 0:
		_stat_row("Verteidigung", str(item.defense))
	var item_range := item.get_base_range()
	if item_range > 0.0:
		_stat_row("Reichweite", _fmt(item_range))
	if item.building_material != BlockData.BuildingMaterial.NONE:
		_stat_row("Material", BlockData.material_display_name(item.building_material))
	if item.building_part_type != BlockData.BuildingPartType.NONE:
		_stat_row("Typ", BlockData.part_type_display_name(item.building_part_type))


func _stat_row(title: String, value: String) -> void:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 1))
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	row.add_child(name_label)
	row.add_child(value_label)
	_stats_box.add_child(row)


func _fill_materials() -> void:
	_clear_box(_mats_box)
	if _selected == null:
		return
	for ingredient in _selected.get_ingredients():
		var item_id := int(ingredient["item_id"])
		var need := int(ingredient["amount"]) * _quantity
		var have := _inventory.get_bag_amount(item_id) if _inventory != null else 0
		var mat := _item_catalog.get_item(item_id) if _item_catalog != null else null
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture = mat.icon if mat != null else null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var name_label := Label.new()
		name_label.text = mat.display_name if mat != null else str(item_id)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		row.add_child(name_label)
		var count := Label.new()
		count.text = "%d / %d" % [have, need]
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 11)
		count.add_theme_color_override("font_color", OK_COLOR if have >= need else BAD_COLOR)
		row.add_child(count)
		_mats_box.add_child(row)


func _fill_station() -> void:
	if _selected == null or not _selected.requires_station():
		_station_name.text = "⚒ Handwerk"
		_station_state.text = "✓ Keine Station nötig"
		_station_state.add_theme_color_override("font_color", OK_COLOR)
		return
	var names: PackedStringArray = PackedStringArray()
	var ok := true
	for station in _selected.required_stations:
		var kind := int(station)
		if kind == RecipeData.Station.NONE:
			continue
		names.append(RecipeData.station_display_name(kind))
		if not _nearby.has(kind):
			ok = false
	_station_name.text = "⚒ " + ", ".join(names)
	if ok:
		_station_state.text = "✓ In Reichweite"
		_station_state.add_theme_color_override("font_color", OK_COLOR)
	else:
		_station_state.text = "✕ Nicht in Reichweite"
		_station_state.add_theme_color_override("font_color", BAD_COLOR)


func _on_craft_pressed() -> void:
	if _selected == null or _crafting == null:
		return
	_nearby.clear()
	for kind in _crafting.collect_nearby_stations(get_tree()):
		_nearby.append(int(kind))
	var amount := _quantity
	if InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
		amount = maxi(1, _crafting.max_craftable(_selected, _inventory, _nearby))
	var result := _crafting.try_craft(_selected, _inventory, amount, _nearby)
	if result != CraftingSystem.Result.OK:
		_play_ui(&"UiCraftFail")
		_update_details()
		return
	refresh()
	_play_ui(&"UiCraftOk")
	_play_craft_feedback()


func _clear_box(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		child.queue_free()


static func _fmt(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")


func _play_ui(event: StringName) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("play_sfx"):
		player.call("play_sfx", event)
