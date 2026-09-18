class_name InventoryScreen
extends Control

## Gehoert an: HUD/InventoryLayer/InventoryScreen. TAB oeffnet und schliesst das Inventar.
## Search/Filter/Sort aendern nur die Beutel-Ansicht, nie die echten Slots 0-39.

@export var slot_scene: PackedScene

const PANEL_PATH := "CenterWrap/MainPanel/MainLayout/Body/Content"
const INSPECT_ROOT := PANEL_PATH + "/LeftColumn/InspectPanel/InspectMargin/InspectOuter"
const INSPECT_LAYOUT_PATH := INSPECT_ROOT + "/InspectScroll/InspectScrollPad/InspectLayout"
const PANEL_SIZE := Vector2(1040, 624)
const CONTENT_SCALE := 1.0
const BAG_SLOT_SIZE := 62
const HOTBAR_SLOT_SIZE := 56
const EQUIP_SLOT_SIZE := 34
const EMPTY_VIEW_SLOT := -1
const FILTER_ALL_ID := 100
const FILTER_GROUP_ALL := -1
const FILTER_GROUP_EQUIP := 200
const FILTER_GROUP_CONSUMABLE := 201
const FILTER_GROUP_MATERIALS := 202
const FILTER_GROUP_OTHER := 203

enum SortMode {
	STANDARD,
	NAME_AZ,
	NAME_ZA,
	CATEGORY,
	AMOUNT_HIGH,
	AMOUNT_LOW,
	DAMAGE_HIGH,
	DAMAGE_LOW,
}

const FILTER_CATEGORIES: Array[ItemData.ItemCategory] = [
	ItemData.ItemCategory.WEAPON,
	ItemData.ItemCategory.ARMOR,
	ItemData.ItemCategory.HEALING,
	ItemData.ItemCategory.FOOD_DRINK,
	ItemData.ItemCategory.AMMUNITION,
	ItemData.ItemCategory.BUILDING_MATERIAL,
	ItemData.ItemCategory.RESOURCE,
	ItemData.ItemCategory.ORE_METAL,
	ItemData.ItemCategory.MAGIC_ENERGY,
	ItemData.ItemCategory.TOOL,
	ItemData.ItemCategory.BUFF,
	ItemData.ItemCategory.MONSTER_MATERIAL,
	ItemData.ItemCategory.TRAP_DEFENSE,
	ItemData.ItemCategory.MACHINE_TECH,
	ItemData.ItemCategory.VALUABLE,
	ItemData.ItemCategory.QUEST_KEY,
]

const SORT_LABELS := {
	SortMode.STANDARD: "Std",
	SortMode.NAME_AZ: "A-Z",
	SortMode.NAME_ZA: "Z-A",
	SortMode.CATEGORY: "Kat.",
	SortMode.AMOUNT_HIGH: "Anz v",
	SortMode.AMOUNT_LOW: "Anz ^",
	SortMode.DAMAGE_HIGH: "Dmg v",
	SortMode.DAMAGE_LOW: "Dmg ^",
}

const FILTER_SHORT_NAMES := {
	ItemData.ItemCategory.WEAPON: "Waffen",
	ItemData.ItemCategory.ARMOR: "Rüstung",
	ItemData.ItemCategory.HEALING: "Heilung",
	ItemData.ItemCategory.FOOD_DRINK: "Nahrung",
	ItemData.ItemCategory.AMMUNITION: "Muni",
	ItemData.ItemCategory.BUILDING_MATERIAL: "Bau",
	ItemData.ItemCategory.RESOURCE: "Rohst.",
	ItemData.ItemCategory.ORE_METAL: "Erze",
	ItemData.ItemCategory.MAGIC_ENERGY: "Magie",
	ItemData.ItemCategory.TOOL: "Tools",
	ItemData.ItemCategory.BUFF: "Buffs",
	ItemData.ItemCategory.MONSTER_MATERIAL: "Monster",
	ItemData.ItemCategory.TRAP_DEFENSE: "Fallen",
	ItemData.ItemCategory.MACHINE_TECH: "Tech",
	ItemData.ItemCategory.VALUABLE: "Werte",
	ItemData.ItemCategory.QUEST_KEY: "Quest",
}

enum MainTab {
	INVENTORY,
	CRAFTING,
	QUESTS,
}

@onready var _inventory_grid: GridContainer = get_node(PANEL_PATH + "/InventorySection/InventoryGrid")
@onready var _hotbar_grid: HBoxContainer = get_node(PANEL_PATH + "/InventorySection/HotbarGrid")
@onready var _preview: TextureRect = get_node(PANEL_PATH + "/LeftColumn/CharacterEquipRow/CharacterSection/PreviewFrame/CharacterPreview")
@onready var _held_preview: TextureRect = get_node(PANEL_PATH + "/LeftColumn/CharacterEquipRow/CharacterSection/PreviewFrame/HeldPreview")
@onready var _inspect_icon: TextureRect = get_node(INSPECT_LAYOUT_PATH + "/InspectIconFrame/InspectIcon")
@onready var _inspect_name: Label = get_node(INSPECT_ROOT + "/InspectName")
@onready var _inspect_subtitle: Label = get_node(INSPECT_ROOT + "/InspectSubtitle")
@onready var _inspect_category: Label = get_node(INSPECT_ROOT + "/InspectCategory")
@onready var _inspect_stats_box: VBoxContainer = get_node(INSPECT_LAYOUT_PATH + "/InspectStatsBox")
@onready var _inspect_description: Label = get_node(INSPECT_LAYOUT_PATH + "/InspectDescription")
@onready var _inspect_desc_sep: HSeparator = get_node(INSPECT_LAYOUT_PATH + "/InspectDescSep")
@onready var _inspect_value_sep: HSeparator = get_node(INSPECT_LAYOUT_PATH + "/InspectValueSep")
@onready var _inspect_value_row: HBoxContainer = get_node(INSPECT_LAYOUT_PATH + "/InspectValueRow")
@onready var _inspect_value_icon: TextureRect = get_node(INSPECT_LAYOUT_PATH + "/InspectValueRow/InspectValueIcon")
@onready var _inspect_value_amount: Label = get_node(INSPECT_LAYOUT_PATH + "/InspectValueRow/InspectValueAmount")
@onready var _inspect_scroll: ScrollContainer = get_node(INSPECT_ROOT + "/InspectScroll")
@onready var _close_button: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/HeaderRow/CloseButton") as Button
@onready var _esc_close_button: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/FooterRow/EscCloseButton") as Button
@onready var _drop_button: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/FooterRow/DropButton") as Button
@onready var _tab_alle: Button = get_node_or_null(PANEL_PATH + "/InventorySection/InventoryToolbar/TabAlle") as Button
@onready var _tab_equip: Button = get_node_or_null(PANEL_PATH + "/InventorySection/InventoryToolbar/TabEquip") as Button
@onready var _tab_consume: Button = get_node_or_null(PANEL_PATH + "/InventorySection/InventoryToolbar/TabConsume") as Button
@onready var _tab_mats: Button = get_node_or_null(PANEL_PATH + "/InventorySection/InventoryToolbar/TabMats") as Button
@onready var _tab_other: Button = get_node_or_null(PANEL_PATH + "/InventorySection/InventoryToolbar/TabOther") as Button
@onready var _main_panel: Control = get_node_or_null("CenterWrap/MainPanel") as Control
@onready var _hover_tooltip: PanelContainer = get_node_or_null("HoverTooltip") as PanelContainer
@onready var _hover_icon: TextureRect = get_node_or_null("HoverTooltip/HoverMargin/HoverLayout/HoverIcon") as TextureRect
@onready var _hover_label: Label = get_node_or_null("HoverTooltip/HoverMargin/HoverLayout/HoverLabel") as Label
@onready var _search_edit: LineEdit = get_node(PANEL_PATH + "/InventorySection/InventoryToolbar/SearchLineEdit")
@onready var _filter_button: MenuButton = get_node(PANEL_PATH + "/InventorySection/InventoryToolbar/FilterButton")
@onready var _sort_button: MenuButton = get_node(PANEL_PATH + "/InventorySection/InventoryToolbar/SortButton")
@onready var _tab_inventory: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/HeaderRow/MainTabs/TabInventory") as Button
@onready var _tab_crafting: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/HeaderRow/MainTabs/TabCrafting") as Button
@onready var _tab_quests: Button = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/HeaderRow/MainTabs/TabQuests") as Button
@onready var _inventory_page: Control = get_node_or_null(PANEL_PATH) as Control
@onready var _crafting_page: CraftingPage = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/CraftingPage") as CraftingPage
@onready var _quests_page: Control = get_node_or_null("CenterWrap/MainPanel/MainLayout/Body/QuestsPage") as Control

var _crafting: CraftingSystem = CraftingSystem.new()
var _main_tab: int = MainTab.INVENTORY

var _inventory: Inventory
var _player: Player
var _bag_slots: Array = []
var _hotbar_slots: Array = []
var _equip_slots: Dictionary = {}
var _search_query: String = ""
var _filter_category: int = -1
var _filter_group: int = FILTER_GROUP_ALL
var _sort_mode: SortMode = SortMode.STANDARD
var _color_icons: Dictionary = {}
var _context_menu: PopupMenu
var _details_popup: PopupPanel
var _split_popup: PopupPanel
var _split_slider: HSlider
var _split_amount_label: Label
var _context_ref: Variant = null
var _drop_scene: PackedScene = preload("res://scenes/items/item_drop.tscn")
var _inspect_ref: Variant = null
var _inspect_rows: Dictionary = {}
var _inspect_icons: Dictionary = {}
var _hover_slot: Panel = null
var _hover_delay: Timer
var _restore_world_input_after_close: bool = false
var _cancel_handled_frame: int = -1


func _ready() -> void:
	add_to_group("inventory_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_panel_size()
	_inventory = get_tree().get_first_node_in_group("player_inventory") as Inventory
	_player = get_tree().get_first_node_in_group("player") as Player
	_build_slots()
	_collect_equipment_slots()
	_setup_toolbar()
	_setup_context_ui()
	_setup_hover_timer()
	_setup_close_button()
	_setup_filter_tabs()
	_setup_footer()
	_setup_inspect_card()
	_setup_inspect_scroll()
	_setup_overlay_input()
	_setup_main_tabs()
	_setup_crafting()
	if _preview != null:
		_preview.texture = load("res://assets/player/player_idle.png") as Texture2D
	if _inventory != null:
		_inventory.inventory_changed.connect(refresh)
		_inventory.selected_slot_changed.connect(_on_selected_changed)
		_inventory.equipment_changed.connect(refresh)
	refresh()
	_lock_panel_size()


func _setup_close_button() -> void:
	if _close_button == null:
		return
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.tooltip_text = "Schließen"
	_close_button.flat = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.16, 0.16, 1)
	style.border_color = Color(0.82, 0.42, 0.38, 1)
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_close_button.add_theme_stylebox_override("normal", style)
	_close_button.add_theme_stylebox_override("hover", style)
	_close_button.add_theme_stylebox_override("pressed", style)
	if not _close_button.pressed.is_connected(close_inventory):
		_close_button.pressed.connect(close_inventory)


func _setup_crafting() -> void:
	var catalog := load("res://resources/crafting/recipe_catalog.tres") as RecipeCatalog
	var items: ItemCatalog = _inventory.item_catalog if _inventory != null else load("res://resources/items/item_catalog.tres") as ItemCatalog
	_crafting.setup(catalog, items)
	if _crafting_page != null:
		_crafting_page.bind(_crafting, _inventory, items)


func _setup_main_tabs() -> void:
	_bind_main_tab(_tab_inventory, MainTab.INVENTORY)
	_bind_main_tab(_tab_crafting, MainTab.CRAFTING)
	_bind_main_tab(_tab_quests, MainTab.QUESTS)
	_set_main_tab(MainTab.INVENTORY)


func _bind_main_tab(button: Button, tab: int) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	if not button.pressed.is_connected(_on_main_tab_pressed):
		button.pressed.connect(_on_main_tab_pressed.bind(tab))


func _on_main_tab_pressed(tab: int) -> void:
	if tab != MainTab.CRAFTING and _crafting_page != null:
		_crafting_page.set_station_context(RecipeData.Station.NONE)
	_set_main_tab(tab)


func _set_main_tab(tab: int) -> void:
	_main_tab = tab
	if _inventory_page != null:
		_inventory_page.visible = tab == MainTab.INVENTORY
	if _crafting_page != null:
		_crafting_page.visible = tab == MainTab.CRAFTING
	if _quests_page != null:
		_quests_page.visible = tab == MainTab.QUESTS
	if _drop_button != null:
		_drop_button.visible = tab == MainTab.INVENTORY
	_apply_main_tab_style(_tab_inventory, tab == MainTab.INVENTORY, "Inventar")
	_apply_main_tab_style(_tab_crafting, tab == MainTab.CRAFTING, "Crafting")
	_apply_main_tab_style(_tab_quests, tab == MainTab.QUESTS, "Quests")
	if tab == MainTab.CRAFTING and _crafting_page != null:
		_crafting_page.refresh()


func _apply_main_tab_style(button: Button, selected: bool, label: String) -> void:
	if button == null:
		return
	var active := preload("res://resources/ui/inv_main_tab_active.tres")
	var idle := preload("res://resources/ui/inv_main_tab.tres")
	button.add_theme_stylebox_override("normal", active if selected else idle)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_color_override("font_color", Color(1, 0.95, 0.82, 1) if selected else Color(0.82, 0.86, 0.9, 1))
	button.text = label.to_upper() if selected else label


func _setup_inspect_card() -> void:
	if _inspect_stats_box == null:
		return
	_inspect_rows["damage"] = _make_inspect_row("Schaden", _pixel_icon_sword())
	_inspect_rows["speed"] = _make_inspect_row("Angriffstempo", _pixel_icon_bolt())
	_inspect_rows["durability"] = _make_inspect_row("Haltbarkeit", _pixel_icon_shield())
	_inspect_rows["power"] = _make_inspect_row("Werkzeug-Power", _pixel_icon_sword())
	_inspect_rows["defense"] = _make_inspect_row("Rüstung", _pixel_icon_shield())
	_inspect_rows["range"] = _make_inspect_row("Reichweite", _pixel_icon_bolt())
	_inspect_rows["amount"] = _make_inspect_row("Menge", _pixel_icon_coin())
	if _inspect_value_icon != null:
		_inspect_value_icon.texture = _pixel_icon_coin()


func _setup_inspect_scroll() -> void:
	if _inspect_scroll == null:
		return
	_inspect_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inspect_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO


func _lock_panel_size() -> void:
	if _main_panel == null:
		return
	_main_panel.custom_minimum_size = PANEL_SIZE
	_main_panel.custom_maximum_size = PANEL_SIZE
	_main_panel.size = PANEL_SIZE
	_main_panel.clip_contents = true
	_main_panel.pivot_offset = PANEL_SIZE * 0.5
	var vp := get_viewport_rect().size
	var fit := minf((vp.x - 24.0) / PANEL_SIZE.x, (vp.y - 24.0) / PANEL_SIZE.y)
	var ui_scale := clampf(fit, 0.62, 1.0)
	_main_panel.scale = Vector2(ui_scale, ui_scale)


func _on_selected_changed(index: int) -> void:
	if _inspect_ref == null or (_inspect_ref is int and int(_inspect_ref) >= 0 and int(_inspect_ref) < Inventory.HOTBAR_COUNT):
		_inspect_ref = index
	refresh()


func _setup_overlay_input() -> void:
	var dimmer := get_node_or_null("Dimmer") as Control
	if dimmer == null:
		return
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if not dimmer.gui_input.is_connected(_on_overlay_gui_input):
		dimmer.gui_input.connect(_on_overlay_gui_input)


func _gui_input(event: InputEvent) -> void:
	_consume_inventory_wheel(event)


func _on_overlay_gui_input(event: InputEvent) -> void:
	_consume_inventory_wheel(event)


func _consume_inventory_wheel(event: InputEvent) -> void:
	if not visible:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		accept_event()


func _set_hud_hotbar_visible(shown: bool) -> void:
	var hotbar := get_tree().get_first_node_in_group("hotbar_ui") as CanvasItem
	if hotbar == null:
		return
	hotbar.visible = shown


func toggle() -> void:
	if visible:
		close_inventory()
	else:
		open()


func open() -> void:
	open_on_tab(MainTab.INVENTORY, RecipeData.Station.NONE)


func open_crafting(station_context: int = RecipeData.Station.NONE) -> void:
	open_on_tab(MainTab.CRAFTING, station_context)


func open_on_tab(tab: int, station_context: int = RecipeData.Station.NONE) -> void:
	var lantern_ui := get_tree().get_first_node_in_group("lantern_ui")
	if lantern_ui != null and lantern_ui.has_method("close_menu"):
		lantern_ui.call("close_menu")
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("is_open") and world_map.is_open():
		world_map.call("close", false)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_hud_hotbar_visible(false)
	_lock_panel_size()
	if _player != null:
		_player.world_input_enabled = false
	if _inventory != null:
		_inspect_ref = _inventory.selected_hotbar_index
	if _crafting_page != null:
		_crafting_page.set_station_context(station_context)
	_set_main_tab(tab)
	refresh()
	_lock_panel_size()


func close_inventory() -> void:
	close(true)


func close(restore_input: bool = true) -> void:
	_hide_popups()
	_hide_hover()
	visible = false
	if _crafting_page != null:
		_crafting_page.set_station_context(RecipeData.Station.NONE)
	_set_main_tab(MainTab.INVENTORY)
	_set_hud_hotbar_visible(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_restore_world_input_after_close = restore_input
	if restore_input:
		_finish_close_later()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _finish_close_later() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _restore_world_input_after_close or visible:
		return
	if _player == null:
		return
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map == null or not world_map.has_method("is_open") or not world_map.is_open():
		_player.world_input_enabled = true


func _build_slots() -> void:
	if slot_scene == null:
		return
	if _inventory_grid != null:
		for child in _inventory_grid.get_children():
			_inventory_grid.remove_child(child)
			child.free()
		_bag_slots.clear()
	if _hotbar_grid != null:
		for child in _hotbar_grid.get_children():
			_hotbar_grid.remove_child(child)
			child.free()
		_hotbar_slots.clear()
	for i in range(Inventory.HOTBAR_COUNT, Inventory.SLOT_COUNT):
		var slot := _make_slot(i)
		_configure_slot_size(slot, BAG_SLOT_SIZE)
		_inventory_grid.add_child(slot)
		_bag_slots.append(slot)
	for i in Inventory.HOTBAR_COUNT:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		cell.size_flags_horizontal = 0
		var slot := _make_slot(i)
		_configure_slot_size(slot, HOTBAR_SLOT_SIZE)
		var num := Label.new()
		num.text = "0" if i == 9 else str(i + 1)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_font_size_override("font_size", 11)
		num.add_theme_color_override("font_color", Color(0.72, 0.78, 0.84, 1))
		cell.add_child(slot)
		cell.add_child(num)
		_hotbar_grid.add_child(cell)
		_hotbar_slots.append(slot)


func _make_slot(index: int) -> Panel:
	var slot := slot_scene.instantiate() as Panel
	slot.set("slot_index", index)
	slot.connect("slot_clicked", _on_slot_clicked)
	slot.connect("slot_right_clicked", _on_slot_right_clicked)
	slot.connect("slot_double_clicked", _on_slot_double_clicked)
	slot.connect("slot_shift_clicked", _on_slot_shift_clicked)
	slot.connect("slot_ctrl_clicked", _on_slot_ctrl_clicked)
	if slot.has_signal("slot_hovered") and not slot.is_connected("slot_hovered", _on_slot_hovered):
		slot.connect("slot_hovered", _on_slot_hovered)
	if slot.has_signal("slot_unhovered") and not slot.is_connected("slot_unhovered", _on_slot_unhovered):
		slot.connect("slot_unhovered", _on_slot_unhovered)
	return slot


func _configure_slot_size(slot: Panel, px: int) -> void:
	if slot != null and slot.has_method("configure_size"):
		slot.call("configure_size", px)


func _collect_equipment_slots() -> void:
	_collect_equipment_slots_in(get_node(PANEL_PATH + "/LeftColumn/CharacterEquipRow/EquipmentSlots"))


func _collect_equipment_slots_in(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("apply_item"):
			var key := str(child.get("equipment_key"))
			if key.is_empty():
				continue
			_equip_slots[key] = child
			if not child.is_connected("slot_clicked", _on_slot_clicked):
				child.connect("slot_clicked", _on_slot_clicked)
			if child.has_signal("slot_right_clicked") and not child.is_connected("slot_right_clicked", _on_slot_right_clicked):
				child.connect("slot_right_clicked", _on_slot_right_clicked)
			if child.has_signal("slot_double_clicked") and not child.is_connected("slot_double_clicked", _on_slot_double_clicked):
				child.connect("slot_double_clicked", _on_slot_double_clicked)
			if child.has_signal("slot_shift_clicked") and not child.is_connected("slot_shift_clicked", _on_slot_shift_clicked):
				child.connect("slot_shift_clicked", _on_slot_shift_clicked)
			if child.has_signal("slot_ctrl_clicked") and not child.is_connected("slot_ctrl_clicked", _on_slot_ctrl_clicked):
				child.connect("slot_ctrl_clicked", _on_slot_ctrl_clicked)
			if child.has_signal("slot_hovered") and not child.is_connected("slot_hovered", _on_slot_hovered):
				child.connect("slot_hovered", _on_slot_hovered)
			if child.has_signal("slot_unhovered") and not child.is_connected("slot_unhovered", _on_slot_unhovered):
				child.connect("slot_unhovered", _on_slot_unhovered)
			_configure_slot_size(child, EQUIP_SLOT_SIZE)
		else:
			_collect_equipment_slots_in(child)


func _setup_toolbar() -> void:
	_style_toolbar_controls()
	if _search_edit != null:
		_search_edit.placeholder_text = "Suchen..."
		_search_edit.tooltip_text = "Suche"
		if not _search_edit.text_changed.is_connected(_on_search_changed):
			_search_edit.text_changed.connect(_on_search_changed)
	_setup_filter_menu()
	_setup_sort_menu()
	_update_toolbar_labels()


func _style_toolbar_controls() -> void:
	var chrome := _toolbar_style()
	if _search_edit != null:
		_search_edit.placeholder_text = "Suchen ..."
		_search_edit.custom_minimum_size = Vector2(140, 22)
		_search_edit.add_theme_font_size_override("font_size", 11)
		_search_edit.add_theme_color_override("font_placeholder_color", Color(0.55, 0.6, 0.66, 0.85))
	for button in [_filter_button, _sort_button]:
		if button == null:
			continue
		button.flat = false
		button.custom_minimum_size = Vector2(48, 22)
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_stylebox_override("normal", chrome)
		button.add_theme_stylebox_override("hover", chrome)
		button.add_theme_stylebox_override("pressed", chrome)
	if _filter_button != null:
		_filter_button.tooltip_text = "Detailfilter"
	if _sort_button != null:
		_sort_button.tooltip_text = "Sortierung"


func _setup_filter_tabs() -> void:
	_bind_filter_tab(_tab_alle, FILTER_GROUP_ALL)
	_bind_filter_tab(_tab_equip, FILTER_GROUP_EQUIP)
	_bind_filter_tab(_tab_consume, FILTER_GROUP_CONSUMABLE)
	_bind_filter_tab(_tab_mats, FILTER_GROUP_MATERIALS)
	_bind_filter_tab(_tab_other, FILTER_GROUP_OTHER)
	_update_filter_tab_styles()


func _bind_filter_tab(button: Button, group_id: int) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	if not button.pressed.is_connected(_on_filter_group_pressed):
		button.pressed.connect(_on_filter_group_pressed.bind(group_id))


func _on_filter_group_pressed(group_id: int) -> void:
	_filter_group = group_id
	_filter_category = -1
	_update_toolbar_labels()
	_update_filter_tab_styles()
	refresh_inventory_view()


func _setup_footer() -> void:
	if _esc_close_button != null:
		_esc_close_button.focus_mode = Control.FOCUS_NONE
		if not _esc_close_button.pressed.is_connected(close_inventory):
			_esc_close_button.pressed.connect(close_inventory)
	if _drop_button != null:
		_drop_button.focus_mode = Control.FOCUS_NONE
		_drop_button.tooltip_text = "Gegenstand fallen lassen"
		if not _drop_button.pressed.is_connected(_on_drop_button_pressed):
			_drop_button.pressed.connect(_on_drop_button_pressed)


func _on_drop_button_pressed() -> void:
	if _inventory == null:
		return
	var ref: Variant = _resolved_inspect_ref()
	if _inventory.get_ref_item(ref) == null:
		return
	_drop_item(ref)


func _update_filter_tab_styles() -> void:
	_apply_tab_style(_tab_alle, _filter_group == FILTER_GROUP_ALL and _filter_category < 0)
	_apply_tab_style(_tab_equip, _filter_group == FILTER_GROUP_EQUIP)
	_apply_tab_style(_tab_consume, _filter_group == FILTER_GROUP_CONSUMABLE)
	_apply_tab_style(_tab_mats, _filter_group == FILTER_GROUP_MATERIALS)
	_apply_tab_style(_tab_other, _filter_group == FILTER_GROUP_OTHER)


func _apply_tab_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var style := _tab_style(selected)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", _tab_style(true))
	button.add_theme_stylebox_override("pressed", _tab_style(true))
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1) if selected else Color(0.78, 0.82, 0.86, 1))


func _tab_style(selected: bool) -> StyleBox:
	return preload("res://resources/ui/inv_tab_active.tres") if selected else preload("res://resources/ui/inv_tab.tres")


func _toolbar_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.2, 1)
	style.border_color = Color(0.45, 0.48, 0.52, 1)
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	style.corner_radius_top_left = 1
	style.corner_radius_top_right = 1
	style.corner_radius_bottom_right = 1
	style.corner_radius_bottom_left = 1
	return style


func _setup_filter_menu() -> void:
	if _filter_button == null:
		return
	var popup := _filter_button.get_popup()
	popup.clear()
	popup.add_item("Alle", FILTER_ALL_ID)
	for category in FILTER_CATEGORIES:
		var id := int(category)
		var label := str(FILTER_SHORT_NAMES.get(category, ItemData.get_category_display_name(category)))
		popup.add_icon_item(_category_icon(category), label, id)
	_style_popup_menu(popup)
	if not popup.id_pressed.is_connected(_on_filter_selected):
		popup.id_pressed.connect(_on_filter_selected)


func _setup_sort_menu() -> void:
	if _sort_button == null:
		return
	var popup := _sort_button.get_popup()
	popup.clear()
	popup.add_item("Standard", SortMode.STANDARD)
	popup.add_item("A-Z", SortMode.NAME_AZ)
	popup.add_item("Z-A", SortMode.NAME_ZA)
	popup.add_item("Kategorie", SortMode.CATEGORY)
	popup.add_item("Anzahl hoch", SortMode.AMOUNT_HIGH)
	popup.add_item("Anzahl tief", SortMode.AMOUNT_LOW)
	popup.add_item("Schaden hoch", SortMode.DAMAGE_HIGH)
	popup.add_item("Schaden tief", SortMode.DAMAGE_LOW)
	_style_popup_menu(popup)
	if not popup.id_pressed.is_connected(_on_sort_selected):
		popup.id_pressed.connect(_on_sort_selected)


func _category_icon(category: ItemData.ItemCategory) -> Texture2D:
	if _color_icons.has(category):
		return _color_icons[category]
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(ItemData.get_category_color(category))
	var tex := ImageTexture.create_from_image(img)
	_color_icons[category] = tex
	return tex


func _on_search_changed(text: String) -> void:
	_search_query = text.strip_edges()
	refresh_inventory_view()


func _on_filter_selected(id: int) -> void:
	_filter_category = -1 if id == FILTER_ALL_ID else id
	if _filter_category < 0:
		_filter_group = FILTER_GROUP_ALL
	else:
		_filter_group = _group_for_category(_filter_category)
	_update_toolbar_labels()
	_update_filter_tab_styles()
	refresh_inventory_view()


func _on_sort_selected(id: int) -> void:
	_sort_mode = id as SortMode
	_update_toolbar_labels()
	refresh_inventory_view()


func _update_toolbar_labels() -> void:
	if _filter_button != null:
		if _filter_category < 0:
			_filter_button.text = "Filter"
			_filter_button.icon = null
		else:
			var category := _filter_category as ItemData.ItemCategory
			_filter_button.text = str(FILTER_SHORT_NAMES.get(category, ItemData.get_category_display_name(category)))
			_filter_button.icon = _category_icon(category)
	if _sort_button != null:
		_sort_button.text = str(SORT_LABELS.get(_sort_mode, "Sortieren"))
	_update_filter_tab_styles()


func _on_slot_clicked(slot: Panel) -> void:
	if _inventory == null or slot == null:
		return
	var ref: Variant = slot.call("get_slot_ref")
	if _inventory.get_ref_item(ref) != null:
		_inspect_ref = ref
	var index := int(slot.get("slot_index"))
	if index >= 0 and index < Inventory.HOTBAR_COUNT:
		_inventory.set_selected_hotbar_index(index)
	else:
		refresh()


func _on_slot_shift_clicked(slot: Panel) -> void:
	if _inventory == null or slot == null:
		return
	var ref: Variant = slot.call("get_slot_ref")
	if _inventory.get_ref_item(ref) == null:
		return
	_inventory.move_to_hotbar(ref)


func _on_slot_ctrl_clicked(slot: Panel) -> void:
	if _inventory == null or slot == null:
		return
	var ref: Variant = slot.call("get_slot_ref")
	if _inventory.get_ref_amount(ref) < 2:
		return
	if _inventory.find_first_empty_slot() < 0:
		return
	_open_split_popup(ref)


func refresh() -> void:
	if _inventory == null:
		return
	refresh_inventory_view()
	for key in _equip_slots.keys():
		var slot: Panel = _equip_slots[key]
		var item := _inventory.get_equipment_item(str(key))
		var data: Dictionary = _inventory.equipment[key]
		slot.call("apply_item", item, int(data["amount"]), _is_inspect_ref(str(key)), bool(data.get("favorite", false)))
	_update_preview()
	_update_inspect_panel()
	if _main_tab == MainTab.CRAFTING and _crafting_page != null:
		_crafting_page.refresh()
	_lock_panel_size()


func refresh_inventory_view() -> void:
	if _inventory == null:
		return
	for slot in _hotbar_slots:
		_apply_inventory_slot(slot)
	var entries := build_bag_view_entries(_inventory, _search_query, _filter_category, _sort_mode, _filter_group)
	for i in _bag_slots.size():
		var slot: Panel = _bag_slots[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			slot.set("slot_index", int(entry["source_slot_index"]))
			_apply_inventory_slot(slot)
		else:
			slot.set("slot_index", EMPTY_VIEW_SLOT)
			slot.call("apply_item", null, 0, false, false)


static func is_default_bag_view(search_query: String, filter_category: int, sort_mode: int, filter_group: int = -1) -> bool:
	return search_query.is_empty() and filter_category < 0 and sort_mode == SortMode.STANDARD and filter_group < 0


static func build_bag_view_entries(inventory: Inventory, search_query: String, filter_category: int, sort_mode: int, filter_group: int = -1) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if inventory == null:
		return entries
	var default_view := is_default_bag_view(search_query, filter_category, sort_mode, filter_group)
	for index in range(Inventory.HOTBAR_COUNT, Inventory.SLOT_COUNT):
		var item := inventory.get_item_in_slot(index)
		var amount := int(inventory.get_slot(index)["amount"])
		if default_view:
			entries.append(view_entry(index, item, amount))
			continue
		if item == null or amount <= 0:
			continue
		if not item_matches_search(item, search_query):
			continue
		if filter_category >= 0:
			if not item_matches_filter(item, filter_category):
				continue
		elif not item_matches_filter_group(item, filter_group):
			continue
		entries.append(view_entry(index, item, amount))
	if not default_view:
		sort_view_entries(entries, sort_mode)
	return entries


static func view_entry(index: int, item: ItemData, amount: int) -> Dictionary:
	return {
		"source_slot_index": index,
		"item": item,
		"amount": amount,
	}


static func item_matches_search(item: ItemData, search_query: String) -> bool:
	if search_query.is_empty():
		return true
	if item == null:
		return false
	var query := search_query.to_lower()
	if item.display_name.to_lower().find(query) >= 0:
		return true
	return str(item.id).find(query) >= 0


static func item_matches_filter(item: ItemData, filter_category: int) -> bool:
	if filter_category < 0:
		return true
	return item != null and int(item.category) == filter_category


static func item_matches_filter_group(item: ItemData, filter_group: int) -> bool:
	if filter_group < 0:
		return true
	if item == null:
		return false
	if filter_group == FILTER_GROUP_EQUIP:
		return item.category == ItemData.ItemCategory.WEAPON or item.category == ItemData.ItemCategory.ARMOR or item.category == ItemData.ItemCategory.TOOL
	if filter_group == FILTER_GROUP_CONSUMABLE:
		return item.category == ItemData.ItemCategory.HEALING or item.category == ItemData.ItemCategory.FOOD_DRINK or item.category == ItemData.ItemCategory.BUFF or item.category == ItemData.ItemCategory.AMMUNITION
	if filter_group == FILTER_GROUP_MATERIALS:
		return item.category == ItemData.ItemCategory.BUILDING_MATERIAL or item.category == ItemData.ItemCategory.RESOURCE or item.category == ItemData.ItemCategory.ORE_METAL or item.category == ItemData.ItemCategory.MONSTER_MATERIAL
	if filter_group == FILTER_GROUP_OTHER:
		return item.category == ItemData.ItemCategory.MAGIC_ENERGY or item.category == ItemData.ItemCategory.TRAP_DEFENSE or item.category == ItemData.ItemCategory.MACHINE_TECH or item.category == ItemData.ItemCategory.VALUABLE or item.category == ItemData.ItemCategory.QUEST_KEY
	return false


static func _group_for_category(category: int) -> int:
	match category:
		ItemData.ItemCategory.WEAPON, ItemData.ItemCategory.ARMOR, ItemData.ItemCategory.TOOL:
			return FILTER_GROUP_EQUIP
		ItemData.ItemCategory.HEALING, ItemData.ItemCategory.FOOD_DRINK, ItemData.ItemCategory.BUFF, ItemData.ItemCategory.AMMUNITION:
			return FILTER_GROUP_CONSUMABLE
		ItemData.ItemCategory.BUILDING_MATERIAL, ItemData.ItemCategory.RESOURCE, ItemData.ItemCategory.ORE_METAL, ItemData.ItemCategory.MONSTER_MATERIAL:
			return FILTER_GROUP_MATERIALS
		ItemData.ItemCategory.MAGIC_ENERGY, ItemData.ItemCategory.TRAP_DEFENSE, ItemData.ItemCategory.MACHINE_TECH, ItemData.ItemCategory.VALUABLE, ItemData.ItemCategory.QUEST_KEY:
			return FILTER_GROUP_OTHER
		_:
			return FILTER_GROUP_ALL


static func sort_view_entries(entries: Array[Dictionary], sort_mode: int) -> void:
	match sort_mode:
		SortMode.NAME_AZ:
			entries.sort_custom(func(a, b): return _entry_name(a) < _entry_name(b))
		SortMode.NAME_ZA:
			entries.sort_custom(func(a, b): return _entry_name(a) > _entry_name(b))
		SortMode.CATEGORY:
			entries.sort_custom(func(a, b): return _entry_category_rank(a) < _entry_category_rank(b))
		SortMode.AMOUNT_HIGH:
			entries.sort_custom(func(a, b): return int(a["amount"]) > int(b["amount"]))
		SortMode.AMOUNT_LOW:
			entries.sort_custom(func(a, b): return int(a["amount"]) < int(b["amount"]))
		SortMode.DAMAGE_HIGH:
			entries.sort_custom(func(a, b): return _entry_damage(a) > _entry_damage(b))
		SortMode.DAMAGE_LOW:
			entries.sort_custom(func(a, b): return _entry_damage(a) < _entry_damage(b))
		_:
			pass


static func _entry_name(entry: Dictionary) -> String:
	var item := entry["item"] as ItemData
	return item.display_name.to_lower() if item != null else ""


static func _entry_category_rank(entry: Dictionary) -> int:
	var item := entry["item"] as ItemData
	if item == null:
		return 1000
	var wanted := int(item.category)
	for i in FILTER_CATEGORIES.size():
		if int(FILTER_CATEGORIES[i]) == wanted:
			return i
	return 999


static func _entry_damage(entry: Dictionary) -> int:
	var item := entry["item"] as ItemData
	if item == null:
		return 0
	return item.get_base_damage()


func _apply_inventory_slot(slot: Panel) -> void:
	var index := int(slot.get("slot_index"))
	if index < 0:
		slot.call("apply_item", null, 0, false, false)
		return
	var data := _inventory.get_slot(index)
	var item := _inventory.get_item_in_slot(index)
	var selected: bool = _is_inspect_ref(index)
	slot.call("apply_item", item, int(data["amount"]), selected, bool(data.get("favorite", false)))


func _update_preview() -> void:
	if _preview != null and _player != null and _player.has_method("compose_preview_texture"):
		var composed: Texture2D = _player.compose_preview_texture()
		if composed != null:
			_preview.texture = composed
	if _held_preview == null or _inventory == null:
		return
	var item := _inventory.get_selected_item()
	if item == null or item.icon == null:
		_held_preview.visible = false
		return
	_held_preview.visible = true
	_held_preview.texture = item.icon


func _is_inspect_ref(ref: Variant) -> bool:
	if _inspect_ref == null or ref == null:
		return false
	if _inspect_ref is String or ref is String:
		return str(_inspect_ref) == str(ref)
	return int(_inspect_ref) == int(ref)


func _resolved_inspect_ref() -> Variant:
	if _inventory == null:
		return null
	if _inventory.get_ref_item(_inspect_ref) != null:
		return _inspect_ref
	return _inventory.selected_hotbar_index


func _update_inspect_panel() -> void:
	if _inspect_name == null:
		return
	_inspect_ref = _resolved_inspect_ref()
	var item: ItemData = null
	if _inventory != null:
		item = _inventory.get_ref_item(_inspect_ref)
	if item == null:
		_fill_inspect_empty()
		return
	var inst := _inventory.get_instance(_inspect_ref)
	var amount := _inventory.get_ref_amount(_inspect_ref)
	if _inspect_icon != null:
		_inspect_icon.texture = item.icon
	_inspect_name.text = item.display_name
	if _inspect_subtitle != null:
		_inspect_subtitle.text = item.get_inspect_subtitle()
		_inspect_subtitle.add_theme_color_override("font_color", item.get_rarity_color())
	if _inspect_category != null:
		_inspect_category.visible = false
	_fill_inspect_stats(item, inst, amount)
	if _inspect_description != null:
		_inspect_description.text = item.description if not item.description.is_empty() else ""
		_inspect_description.visible = not item.description.is_empty()
	if _inspect_value_row != null:
		_inspect_value_row.visible = true
	if _inspect_value_sep != null:
		_inspect_value_sep.visible = true
	if _inspect_value_amount != null:
		_inspect_value_amount.text = str(item.get_sell_value())
	_update_drop_button()


func _fill_inspect_empty() -> void:
	if _inspect_icon != null:
		_inspect_icon.texture = null
	_inspect_name.text = "Kein Gegenstand ausgewählt"
	if _inspect_subtitle != null:
		_inspect_subtitle.text = ""
	if _inspect_category != null:
		_inspect_category.text = ""
		_inspect_category.visible = false
	if _inspect_stats_box != null:
		_inspect_stats_box.visible = false
	for row_variant in _inspect_rows.values():
		var hidden_row := row_variant as Control
		if hidden_row != null:
			hidden_row.visible = false
	if _inspect_description != null:
		_inspect_description.visible = true
		_inspect_description.text = "Kein Gegenstand ausgewählt"
	if _inspect_desc_sep != null:
		_inspect_desc_sep.visible = false
	if _inspect_value_row != null:
		_inspect_value_row.visible = false
	if _inspect_value_sep != null:
		_inspect_value_sep.visible = false
	_update_drop_button()


func _update_drop_button() -> void:
	if _drop_button == null or _inventory == null:
		return
	var ref: Variant = _resolved_inspect_ref()
	var item := _inventory.get_ref_item(ref)
	var blocked := item == null or _inventory.is_favorite(ref)
	_drop_button.disabled = blocked


func _fill_inspect_stats(item: ItemData, inst: ItemInstanceData, amount: int) -> void:
	var damage := inst.effective_damage(item) if inst != null else item.get_base_damage()
	var damage_max := item.get_damage_max()
	if inst != null and item.damage_max > 0:
		damage_max = item.damage_max + inst.damage_bonus
	var damage_text := ""
	if damage > 0:
		if damage_max > damage:
			damage_text = "%d – %d" % [damage, damage_max]
		else:
			damage_text = str(damage)
	_set_inspect_row("damage", not damage_text.is_empty(), damage_text)

	var speed := 0.0
	if item.tool_data != null or item.is_weapon():
		speed = inst.effective_use_speed(item) if inst != null else item.get_base_use_speed()
	elif item.attack_cooldown > 0.0 and (item.item_type == ItemData.ItemType.WEAPON or damage > 0):
		speed = 1.0 / item.attack_cooldown
	_set_inspect_row("speed", speed > 0.0, "%s / s" % _format_de_float(speed))

	var max_dur := inst.effective_max_durability(item) if inst != null else item.get_base_max_durability()
	var dur_text := ""
	if max_dur > 0:
		var current := inst.durability if inst != null and inst.durability >= 0 else max_dur
		dur_text = "%d / %d" % [current, max_dur]
	_set_inspect_row("durability", not dur_text.is_empty(), dur_text)

	var power := inst.effective_tool_power(item) if inst != null else item.get_base_tool_power()
	var power_visible := item.tool_data != null and power > 0
	if power_visible:
		var power_row: Control = _inspect_rows.get("power") as Control
		if power_row != null:
			var name_label := power_row.get_node_or_null("Name") as Label
			if name_label != null:
				name_label.text = "Spitzhacken-Power" if int(item.get_tool_category()) == int(ToolData.ToolCategory.MINING) else "Werkzeug-Power"
	_set_inspect_row("power", power_visible, str(power) if power_visible else "")

	var defense := item.defense
	_set_inspect_row("defense", defense > 0, str(defense) if defense > 0 else "")
	var item_range := inst.effective_range(item) if inst != null else item.get_base_range()
	_set_inspect_row("range", item_range > 0.0, _format_de_float(item_range) if item_range > 0.0 else "")
	_set_inspect_row("amount", amount > 1, "x%d" % amount if amount > 1 else "")

	var any_visible := false
	for row_variant in _inspect_rows.values():
		var shown_row := row_variant as Control
		if shown_row != null and shown_row.visible:
			any_visible = true
			break
	if _inspect_stats_box != null:
		_inspect_stats_box.visible = any_visible
	if _inspect_desc_sep != null:
		_inspect_desc_sep.visible = any_visible


func _set_inspect_row(key: String, shown: bool, value_text: String) -> void:
	var row: Control = _inspect_rows.get(key) as Control
	if row == null:
		return
	row.visible = shown
	if not shown:
		return
	var value_label := row.get_node_or_null("Value") as Label
	if value_label != null:
		value_label.text = value_text


func _make_inspect_row(title: String, icon: Texture2D) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "InspectRow%s" % title.replace(" ", "")
	row.add_theme_constant_override("separation", 4)
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(8, 8)
	icon_rect.texture = icon
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = title
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 1))
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95, 1))
	row.add_child(icon_rect)
	row.add_child(name_label)
	row.add_child(value_label)
	row.visible = false
	_inspect_stats_box.add_child(row)
	return row


static func _format_de_float(value: float, digits: int = 1) -> String:
	return (("%%.%df" % digits) % value).replace(".", ",")


func _pixel_icon_sword() -> Texture2D:
	return _make_pixel_icon("sword", [
		"00000010",
		"00000111",
		"00001110",
		"00011100",
		"01111000",
		"01110000",
		"11010000",
		"01000000",
	], Color(0.82, 0.84, 0.88, 1))


func _pixel_icon_bolt() -> Texture2D:
	return _make_pixel_icon("bolt", [
		"00011000",
		"00110000",
		"01111000",
		"00011100",
		"00111000",
		"01100000",
		"11000000",
		"10000000",
	], Color(0.82, 0.84, 0.88, 1))


func _pixel_icon_shield() -> Texture2D:
	return _make_pixel_icon("shield", [
		"01111110",
		"11000011",
		"11011011",
		"11011011",
		"11000011",
		"01100110",
		"00111100",
		"00011000",
	], Color(0.82, 0.84, 0.88, 1))


func _pixel_icon_coin() -> Texture2D:
	return _make_pixel_icon("coin", [
		"00111100",
		"01111110",
		"11011011",
		"11011011",
		"11011011",
		"11000011",
		"01111110",
		"00111100",
	], Color(0.92, 0.78, 0.28, 1))


func _make_pixel_icon(key: String, rows: PackedStringArray, color: Color) -> Texture2D:
	if _inspect_icons.has(key):
		return _inspect_icons[key]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		var line := str(rows[y])
		for x in mini(8, line.length()):
			if line[x] == "1":
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_inspect_icons[key] = tex
	return tex


static func build_inspect_stats(item: ItemData, inst: ItemInstanceData, amount: int) -> String:
	if item == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	var damage := item.damage
	if inst != null:
		damage += inst.damage_bonus
	if damage > 0:
		parts.append("Schaden %d" % damage)
	var tool: ToolData = item.tool_data
	if tool != null:
		var power := tool.base_tool_power
		if inst != null:
			power += inst.tool_power_bonus
		if power > 0:
			if int(tool.tool_category) == int(ToolData.ToolCategory.MINING):
				parts.append("Spitzhacken-Power %d" % power)
			else:
				parts.append("Werkzeug-Power %d" % power)
	if item.defense > 0:
		parts.append("Rüstung %d" % item.defense)
	if amount > 1:
		parts.append("x%d" % amount)
	return " · ".join(parts)


static func build_inspect_info(item: ItemData) -> String:
	if item == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	var cat := ItemData.get_category_display_name(item.category)
	if not cat.is_empty():
		lines.append(cat)
	if item.building_part_type != BlockData.BuildingPartType.NONE:
		var part := BlockData.part_type_display_name(item.building_part_type)
		if not part.is_empty():
			lines.append(part)
	var tool: ToolData = item.tool_data
	if tool != null:
		var sub := ToolData.get_category_display_name(tool.tool_category)
		if not sub.is_empty():
			lines.append(sub)
	var ore: OreData = item.get("ore_data") as OreData
	if ore != null:
		var ore_sub := OreData.get_metal_category_display_name(ore.metal_category)
		if not ore_sub.is_empty():
			lines.append(ore_sub)
	if not item.description.is_empty():
		lines.append(item.description)
	return "\n".join(lines)


static func build_hover_text(item: ItemData, inst: ItemInstanceData, amount: int) -> String:
	if item == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append(item.display_name)
	var stats := build_inspect_stats(item, inst, amount)
	if not stats.is_empty():
		lines.append(stats)
	var cat := ItemData.get_category_display_name(item.category)
	if not cat.is_empty():
		lines.append(cat)
	return "\n".join(lines)


func _setup_hover_timer() -> void:
	_hover_delay = Timer.new()
	_hover_delay.name = "HoverDelay"
	_hover_delay.one_shot = true
	_hover_delay.wait_time = 0.12
	_hover_delay.timeout.connect(_show_pending_hover)
	add_child(_hover_delay)
	if _hover_tooltip == null:
		return
	_hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tooltip.z_index = 40
	_hover_tooltip.z_as_relative = false
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	panel.border_color = Color(0.82, 0.78, 0.48, 1)
	panel.set_border_width_all(1)
	panel.content_margin_left = 0
	panel.content_margin_right = 0
	panel.content_margin_top = 0
	panel.content_margin_bottom = 0
	_hover_tooltip.add_theme_stylebox_override("panel", panel)
	_hover_tooltip.scale = Vector2(CONTENT_SCALE, CONTENT_SCALE)
	_ignore_mouse_tree(_hover_tooltip)


func _ignore_mouse_tree(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_tree(child)


func _on_slot_hovered(slot: Panel) -> void:
	if not visible or slot == null:
		return
	if slot.has_method("is_dragging") and bool(slot.call("is_dragging")):
		return
	_hover_slot = slot
	if _hover_delay != null:
		_hover_delay.start()
	else:
		_show_pending_hover()


func _on_slot_unhovered(slot: Panel) -> void:
	if _hover_slot == slot:
		_hover_slot = null
		if _hover_delay != null:
			_hover_delay.stop()
		_hide_hover()


func _show_pending_hover() -> void:
	if not visible or _hover_slot == null or _inventory == null or _hover_tooltip == null:
		return
	var ref: Variant = _hover_slot.call("get_slot_ref")
	var item := _inventory.get_ref_item(ref)
	if item == null:
		_hide_hover()
		return
	var inst := _inventory.get_instance(ref)
	var amount := _inventory.get_ref_amount(ref)
	if _hover_icon != null:
		_hover_icon.texture = item.icon
	if _hover_label != null:
		_hover_label.text = build_hover_text(item, inst, amount)
	_hover_tooltip.visible = true
	_position_hover()


func _hide_hover() -> void:
	if _hover_tooltip != null:
		_hover_tooltip.visible = false


func _position_hover() -> void:
	if _hover_tooltip == null or not _hover_tooltip.visible:
		return
	var mouse := get_viewport().get_mouse_position()
	var size := _hover_tooltip.get_combined_minimum_size()
	if size.x < 8.0:
		size = _hover_tooltip.size
	var pos := mouse + Vector2(12.0, 14.0)
	var vp := get_viewport_rect().size
	if pos.x + size.x > vp.x:
		pos.x = vp.x - size.x
	if pos.y + size.y > vp.y:
		pos.y = mouse.y - size.y - 8.0
	pos.x = maxf(pos.x, 0.0)
	pos.y = maxf(pos.y, 0.0)
	_hover_tooltip.position = pos


func consume_escape() -> bool:
	if not visible:
		return false
	if _cancel_handled_frame == Engine.get_process_frames():
		return true
	_handle_cancel()
	return true


func _process(_delta: float) -> void:
	if not visible:
		return
	if _main_panel != null:
		var vp := get_viewport_rect().size
		var fit := minf((vp.x - 24.0) / PANEL_SIZE.x, (vp.y - 24.0) / PANEL_SIZE.y)
		var ui_scale := clampf(fit, 0.62, 1.0)
		if not _main_panel.scale.is_equal_approx(Vector2(ui_scale, ui_scale)):
			_lock_panel_size()
	if _hover_tooltip != null and _hover_tooltip.visible:
		_position_hover()


func _handle_cancel() -> void:
	var frame := Engine.get_process_frames()
	if _cancel_handled_frame == frame:
		return
	_cancel_handled_frame = frame
	if _any_popup_open():
		_hide_popups()
		return
	close_inventory()


func _style_popup_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	popup.add_theme_font_size_override("font_size", 8)
	popup.add_theme_constant_override("v_separation", 0)
	popup.add_theme_constant_override("item_start_padding", 4)
	popup.add_theme_constant_override("item_end_padding", 4)
	popup.max_size = Vector2i(128, 140)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	panel.border_color = Color(0.42, 0.46, 0.5, 1)
	panel.set_border_width_all(1)
	panel.content_margin_left = 3
	panel.content_margin_right = 3
	panel.content_margin_top = 2
	panel.content_margin_bottom = 2
	popup.add_theme_stylebox_override("panel", panel)


func _setup_context_ui() -> void:
	_context_menu = PopupMenu.new()
	_context_menu.name = "ItemContextMenu"
	_context_menu.hide_on_checkable_item_selection = true
	add_child(_context_menu)
	_style_popup_menu(_context_menu)
	_context_menu.id_pressed.connect(_on_context_id_pressed)
	_bind_popup_cancel(_context_menu)
	_build_details_popup()
	_build_split_popup()


func _bind_popup_cancel(popup: Window) -> void:
	if popup == null:
		return
	if not popup.visibility_changed.is_connected(_on_inventory_popup_visibility_changed):
		popup.visibility_changed.connect(_on_inventory_popup_visibility_changed)


func _on_inventory_popup_visibility_changed() -> void:
	if _any_popup_open():
		return
	_cancel_handled_frame = Engine.get_process_frames()


func _build_details_popup() -> void:
	_details_popup = PopupPanel.new()
	_details_popup.name = "ItemDetailsPopup"
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	panel.border_color = Color(0.42, 0.46, 0.5, 1)
	panel.set_border_width_all(1)
	panel.content_margin_left = 6
	panel.content_margin_right = 6
	panel.content_margin_top = 5
	panel.content_margin_bottom = 5
	_details_popup.add_theme_stylebox_override("panel", panel)
	var label := Label.new()
	label.name = "DetailsLabel"
	label.add_theme_font_size_override("font_size", 8)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(148, 0)
	_details_popup.add_child(label)
	add_child(_details_popup)
	_bind_popup_cancel(_details_popup)


func _build_split_popup() -> void:
	_split_popup = PopupPanel.new()
	_split_popup.name = "SplitStackPopup"
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	panel.border_color = Color(0.42, 0.46, 0.5, 1)
	panel.set_border_width_all(1)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 6
	panel.content_margin_bottom = 6
	_split_popup.add_theme_stylebox_override("panel", panel)
	var box := VBoxContainer.new()
	box.name = "SplitBox"
	box.add_theme_constant_override("separation", 5)
	var title := Label.new()
	title.name = "SplitTitle"
	title.add_theme_font_size_override("font_size", 8)
	title.text = "Stack teilen"
	_split_slider = HSlider.new()
	_split_slider.custom_minimum_size = Vector2(120, 14)
	_split_slider.step = 1.0
	_split_slider.rounded = true
	_split_slider.allow_greater = false
	_split_slider.allow_lesser = false
	_split_slider.value_changed.connect(_on_split_slider_changed)
	_split_amount_label = Label.new()
	_split_amount_label.name = "SplitAmount"
	_split_amount_label.add_theme_font_size_override("font_size", 8)
	_split_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_split_amount_label.text = "1"
	var confirm := Button.new()
	confirm.name = "SplitConfirm"
	confirm.text = "Teilen"
	confirm.custom_minimum_size = Vector2(56, 16)
	confirm.add_theme_font_size_override("font_size", 8)
	confirm.pressed.connect(_on_split_confirm)
	box.add_child(title)
	box.add_child(_split_slider)
	box.add_child(_split_amount_label)
	box.add_child(confirm)
	_split_popup.add_child(box)
	add_child(_split_popup)
	_bind_popup_cancel(_split_popup)


func _any_popup_open() -> bool:
	if (_context_menu != null and _context_menu.visible) \
		or (_details_popup != null and _details_popup.visible) \
		or (_split_popup != null and _split_popup.visible):
		return true
	if _filter_button != null:
		var filter_popup := _filter_button.get_popup()
		if filter_popup != null and filter_popup.visible:
			return true
	if _sort_button != null:
		var sort_popup := _sort_button.get_popup()
		if sort_popup != null and sort_popup.visible:
			return true
	return false


func _hide_popups() -> void:
	if _context_menu != null:
		_context_menu.hide()
	if _details_popup != null:
		_details_popup.hide()
	if _split_popup != null:
		_split_popup.hide()
	if _filter_button != null:
		var filter_popup := _filter_button.get_popup()
		if filter_popup != null:
			filter_popup.hide()
	if _sort_button != null:
		var sort_popup := _sort_button.get_popup()
		if sort_popup != null:
			sort_popup.hide()
	_hide_hover()
	_context_ref = null


func _on_slot_right_clicked(slot: Panel) -> void:
	if _inventory == null or slot == null:
		return
	var ref: Variant = slot.call("get_slot_ref")
	var item := _inventory.get_ref_item(ref)
	if item == null:
		_hide_popups()
		return
	_open_context_menu(ref, item)


func _open_context_menu(ref: Variant, item: ItemData) -> void:
	_hide_popups()
	_context_ref = ref
	_context_menu.clear()
	var favorite := _inventory.is_favorite(ref)
	var amount := _inventory.get_ref_amount(ref)
	if favorite:
		_context_menu.add_item("★ Favorit entfernen", 1)
	else:
		_context_menu.add_item("★ Favorisieren", 1)
	var can_toolbar := _can_move_to_toolbar(ref)
	_context_menu.add_item("✋ In Toolbar legen", 2)
	_context_menu.set_item_disabled(_context_menu.get_item_index(2), not can_toolbar)
	if amount >= 2:
		var can_split := _inventory.find_first_empty_slot() >= 0
		_context_menu.add_item("🔀 Stack teilen", 3)
		_context_menu.set_item_disabled(_context_menu.get_item_index(3), not can_split)
	_context_menu.add_item("🗑 Wegwerfen", 4)
	_context_menu.set_item_disabled(_context_menu.get_item_index(4), favorite)
	_context_menu.add_item("📖 Details", 5)
	_popup_at_mouse(_context_menu)


func _can_move_to_toolbar(ref: Variant) -> bool:
	if ref is int and int(ref) >= 0 and int(ref) < Inventory.HOTBAR_COUNT:
		return false
	return _inventory.find_first_empty_hotbar_slot() >= 0


func _on_context_id_pressed(id: int) -> void:
	if _inventory == null or _context_ref == null:
		return
	var ref: Variant = _context_ref
	match id:
		1:
			_inventory.set_favorite(ref, not _inventory.is_favorite(ref))
		2:
			_inventory.move_to_hotbar(ref)
		3:
			_open_split_popup(ref)
		4:
			_drop_item(ref)
		5:
			_open_details(ref)
	if id != 3 and id != 5:
		_context_ref = null


func _open_split_popup(ref: Variant) -> void:
	var amount := _inventory.get_ref_amount(ref)
	if amount < 2 or _split_slider == null:
		return
	_context_ref = ref
	_split_slider.min_value = 1
	_split_slider.max_value = amount - 1
	_split_slider.value = floori(float(amount) / 2.0)
	var title := _split_popup.get_node_or_null("SplitBox/SplitTitle") as Label
	if title != null:
		title.text = "Stack: %d" % amount
	_update_split_amount_label()
	_popup_at_mouse(_split_popup)


func _on_split_slider_changed(_value: float) -> void:
	_update_split_amount_label()


func _update_split_amount_label() -> void:
	if _split_amount_label == null or _split_slider == null:
		return
	_split_amount_label.text = "%d Stück" % int(_split_slider.value)


func _on_split_confirm() -> void:
	if _inventory == null or _context_ref == null or _split_slider == null:
		return
	_inventory.split_stack(_context_ref, int(_split_slider.value))
	_hide_popups()


func _drop_item(ref: Variant) -> void:
	if _inventory.is_favorite(ref):
		return
	var snapshot := _inventory.take_stack(ref)
	if snapshot.is_empty():
		return
	var item_id := int(snapshot["item_id"])
	var amount := int(snapshot["amount"])
	var item: ItemData = null
	if _inventory.item_catalog != null:
		item = _inventory.item_catalog.get_item(item_id)
	if item == null or _drop_scene == null:
		_inventory.add_item(item_id, amount)
		return
	var drop := _drop_scene.instantiate()
	var parent: Node = get_tree().get_first_node_in_group("item_drops")
	if parent == null:
		parent = _player.get_parent() if _player != null else get_tree().current_scene
	parent.add_child(drop)
	var facing := _player.facing_sign if _player != null else 1.0
	drop.global_position = _player.global_position + Vector2(12.0 * facing, -2.0)
	if drop.has_method("setup"):
		drop.call("setup", item_id, amount, item.icon)


func _open_details(ref: Variant) -> void:
	var item := _inventory.get_ref_item(ref)
	if item == null or _details_popup == null:
		return
	var inst := _inventory.get_instance(ref)
	var label := _details_popup.get_node("DetailsLabel") as Label
	if label == null:
		return
	label.text = _build_details_text(item, inst, _inventory.get_ref_amount(ref))
	_popup_at_mouse(_details_popup)


func _build_details_text(item: ItemData, inst: ItemInstanceData, amount: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(item.display_name)
	var cat_name := ItemData.get_category_display_name(item.category)
	if not cat_name.is_empty():
		lines.append("Kategorie: %s" % cat_name)
	if item.building_part_type != BlockData.BuildingPartType.NONE:
		var part := BlockData.part_type_display_name(item.building_part_type)
		if not part.is_empty():
			lines.append("Unterkategorie: %s" % part)
	if item.tool_data != null:
		var sub := ToolData.get_category_display_name(item.get_tool_category())
		if not sub.is_empty():
			lines.append("Unterkategorie: %s" % sub)
		if item.get_pickaxe_tier() > 0:
			lines.append("Tier: %d" % item.get_pickaxe_tier())
	var ore := item.ore_data
	if ore != null:
		var ore_sub := OreData.get_metal_category_display_name(ore.metal_category)
		if not ore_sub.is_empty():
			lines.append("Unterkategorie: %s" % ore_sub)
		lines.append("Tier: %d" % ore.tier)
	if not item.description.is_empty():
		lines.append(item.description)
	lines.append("Stack: %d / %d" % [amount, item.max_stack])
	_append_stat_line(lines, "Schaden", inst.effective_damage(item), inst.damage_bonus, item.get_base_damage())
	if item.tool_data != null:
		var power_label := "Spitzhacken-Power" if item.get_tool_category() == ToolData.ToolCategory.MINING else "Werkzeug-Power"
		_append_stat_line(lines, power_label, inst.effective_tool_power(item), inst.tool_power_bonus, item.get_base_tool_power())
		if item.get_base_use_speed() > 0.0:
			lines.append("Tempo: %.1f" % inst.effective_use_speed(item))
		var max_dur := inst.effective_max_durability(item)
		if max_dur > 0:
			var current := inst.durability if inst.durability >= 0 else max_dur
			lines.append("Haltbarkeit: %d / %d" % [current, max_dur])
		if item.get_base_range() > 0.0:
			lines.append("Reichweite: %.1f" % inst.effective_range(item))
		var special := item.get_special()
		if not special.is_empty():
			lines.append("Spezial: %s" % special)
	elif item.defense > 0:
		lines.append("Rüstung: %d" % item.defense)
	if ore != null:
		lines.append("Benötigte Spitzhacken-Power: %d" % ore.get_required_tool_power())
		if ore.drop_min == ore.drop_max:
			lines.append("Drop: %d" % ore.drop_min)
		else:
			lines.append("Drop: %d–%d" % [ore.drop_min, ore.drop_max])
		lines.append("XP: %d" % ore.xp_reward)
	return "\n".join(lines)


func _append_stat_line(lines: PackedStringArray, label: String, effective: int, bonus: int, base: int) -> void:
	if base <= 0 and bonus == 0 and effective <= 0:
		return
	if bonus != 0:
		lines.append("%s: %d + %d" % [label, base, bonus])
	else:
		lines.append("%s: %d" % [label, effective])


func _popup_at_mouse(popup: Window) -> void:
	if popup == null:
		return
	popup.reset_size()
	var mouse := get_viewport().get_mouse_position()
	var vp := get_viewport_rect().size
	var size := Vector2(popup.size)
	if size.x <= 0.0:
		size.x = 96.0
	if size.y <= 0.0:
		size.y = 80.0
	var pos := mouse
	if pos.x + size.x > vp.x:
		pos.x = vp.x - size.x
	if pos.y + size.y > vp.y:
		pos.y = vp.y - size.y
	pos.x = maxf(pos.x, 0.0)
	pos.y = maxf(pos.y, 0.0)
	popup.position = Vector2i(pos.round())
	popup.popup()


func _on_slot_double_clicked(slot: Panel) -> void:
	if _inventory == null or slot == null:
		return
	if slot.has_method("is_dragging") and bool(slot.call("is_dragging")):
		return
	var ref: Variant = slot.call("get_slot_ref")
	var item := _inventory.get_ref_item(ref)
	if item == null:
		return
	if item.equipment_slot != ItemData.EquipmentSlot.NONE:
		var key := _inventory.find_equipment_key(item)
		if not key.is_empty():
			_inventory.transfer(ref, key)
		return
	if item.item_type == ItemData.ItemType.TOOL or item.item_type == ItemData.ItemType.WEAPON or item.is_tool():
		_quick_to_hotbar(ref)
		return
	_quick_to_hotbar(ref)


func _quick_to_hotbar(ref: Variant) -> void:
	if ref is int and int(ref) >= 0 and int(ref) < Inventory.HOTBAR_COUNT:
		_inventory.set_selected_hotbar_index(int(ref))
		return
	_inventory.move_to_hotbar(ref)
