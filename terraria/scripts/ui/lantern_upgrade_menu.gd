class_name LanternUpgradeMenu
extends Control

## Gehoert an: HUD/LanternUpgradeMenu. Upgrade gegen echte Inventarkosten.

@export var item_catalog: ItemCatalog

@onready var _dimmer: ColorRect = $Dimmer
@onready var _title: Label = $CenterWrap/Panel/Margin/Layout/Title
@onready var _level_label: Label = $CenterWrap/Panel/Margin/Layout/LevelLabel
@onready var _radius_label: Label = $CenterWrap/Panel/Margin/Layout/RadiusLabel
@onready var _next_label: Label = $CenterWrap/Panel/Margin/Layout/NextLabel
@onready var _cost_label: RichTextLabel = $CenterWrap/Panel/Margin/Layout/CostLabel
@onready var _missing_label: Label = $CenterWrap/Panel/Margin/Layout/MissingLabel
@onready var _upgrade_button: Button = $CenterWrap/Panel/Margin/Layout/UpgradeButton
@onready var _close_button: Button = $CenterWrap/Panel/Margin/Layout/CloseButton

var _lantern: Lantern
var _inventory: Inventory
var _open: bool = false


func _ready() -> void:
	add_to_group("lantern_ui")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _upgrade_button != null:
		_upgrade_button.pressed.connect(_on_upgrade)
	if _close_button != null:
		_close_button.pressed.connect(close_menu)
	if _dimmer != null:
		_dimmer.gui_input.connect(_on_dimmer_input)


func open_for(lantern: Lantern) -> void:
	_lantern = lantern
	_inventory = get_tree().get_first_node_in_group("player_inventory") as Inventory
	var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui != null and inventory_ui.has_method("close"):
		inventory_ui.call("close", false)
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.world_input_enabled = false
	if _inventory != null and not _inventory.inventory_changed.is_connected(_refresh):
		_inventory.inventory_changed.connect(_refresh)
	if _lantern != null and not _lantern.level_changed.is_connected(_on_level_changed):
		_lantern.level_changed.connect(_on_level_changed)
	_refresh()


func close_menu() -> void:
	if not _open:
		return
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _inventory != null and _inventory.inventory_changed.is_connected(_refresh):
		_inventory.inventory_changed.disconnect(_refresh)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.world_input_enabled = true


func consume_escape() -> bool:
	if not _open:
		return false
	close_menu()
	return true


func is_open() -> bool:
	return _open


func _on_level_changed(_level: int) -> void:
	_refresh()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_menu()
		accept_event()


func _on_upgrade() -> void:
	if _lantern == null or _inventory == null:
		return
	var result := _lantern.try_upgrade(_inventory)
	if bool(result.get("ok", false)):
		_missing_label.text = ""
		_refresh()
		return
	if str(result.get("reason", "")) == "max":
		_missing_label.text = "MAXIMALE STUFE"
		return
	_missing_label.text = _format_missing(result.get("missing", []))
	_refresh()


func _refresh() -> void:
	if _lantern == null:
		return
	var data := _lantern.current_data()
	if data == null:
		return
	_title.text = data.display_name.to_upper()
	_level_label.text = "Stufe %d" % data.level
	_radius_label.text = "Schutzradius: %d Blöcke" % data.safe_radius_tiles
	if _lantern.is_max_level():
		_next_label.text = "MAXIMALE STUFE"
		_cost_label.text = ""
		_upgrade_button.visible = false
		_missing_label.text = ""
		return
	var nxt := _lantern.next_data()
	_upgrade_button.visible = true
	if nxt == null:
		return
	_next_label.text = "Nächstes Upgrade: %s  (%d Blöcke)" % [nxt.display_name, nxt.safe_radius_tiles]
	_cost_label.text = _format_costs(nxt.get_upgrade_costs())
	var can := _inventory != null and _inventory.can_consume_items(nxt.get_upgrade_costs())
	_upgrade_button.disabled = not can


func _format_costs(costs: Array) -> String:
	if costs.is_empty():
		return "Keine Materialien"
	var lines: PackedStringArray = ["Benötigt:"]
	for cost in costs:
		var item_id := int(cost["item_id"])
		var need := int(cost["amount"])
		var have := 0
		if _inventory != null:
			have = _inventory.get_bag_amount(item_id)
		var item := _get_item(item_id)
		var name := item.display_name if item != null else "Item %d" % item_id
		var color := "#8cff8c" if have >= need else "#ff7a70"
		lines.append("[color=%s]%s  %d / %d[/color]" % [color, name, have, need])
	return "\n".join(lines)


func _format_missing(missing: Array) -> String:
	if missing.is_empty():
		return "Materialien fehlen"
	var parts: PackedStringArray = []
	for entry in missing:
		var item := _get_item(int(entry["item_id"]))
		var name := item.display_name if item != null else "Item"
		parts.append("%s (%d/%d)" % [name, int(entry["have"]), int(entry["need"])])
	return "Fehlt: " + ", ".join(parts)


func _get_item(item_id: int) -> ItemData:
	if item_catalog != null:
		return item_catalog.get_item(item_id)
	if _inventory != null and _inventory.item_catalog != null:
		return _inventory.item_catalog.get_item(item_id)
	return null
