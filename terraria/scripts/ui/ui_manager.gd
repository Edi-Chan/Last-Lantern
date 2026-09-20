extends Node

## Autoload. Eine ESC-Ebene pro Tastendruck, Pause vor Gameplay.

var capturing_rebind: bool = false

var _pause_menu: Node = null
var _options_menu: Node = null


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event == null or not event.is_action_pressed("ui_cancel"):
		return
	if capturing_rebind:
		get_viewport().set_input_as_handled()
		return
	if _handle_escape():
		get_viewport().set_input_as_handled()


func register_pause_menu(menu: Node) -> void:
	_pause_menu = menu


func register_options_menu(menu: Node) -> void:
	_options_menu = menu


func is_pause_open() -> bool:
	return _pause_menu != null and bool(_pause_menu.call("is_open"))


func is_options_open() -> bool:
	return _options_menu != null and bool(_options_menu.call("is_open"))


func is_admin_open() -> bool:
	var admin := get_node_or_null("/root/AdminManager")
	return admin != null and bool(admin.call("is_menu_open"))


func is_blocking_gameplay() -> bool:
	if is_admin_open() or is_pause_open() or is_options_open() or SettingsManager.is_gameplay_blocked():
		return true
	var lantern_ui := get_tree().get_first_node_in_group("lantern_ui")
	if lantern_ui != null and lantern_ui.has_method("is_open") and bool(lantern_ui.call("is_open")):
		return true
	return false


func open_pause() -> void:
	if _pause_menu != null:
		_pause_menu.call("open_pause")


func open_options_from_pause() -> void:
	if _options_menu != null:
		_options_menu.call("open_menu")
	if _pause_menu != null:
		_pause_menu.call("set_hidden_for_options", true)


func close_options_to_pause() -> void:
	if _options_menu != null:
		_options_menu.call("close_menu")
	if _pause_menu != null:
		_pause_menu.call("set_hidden_for_options", false)
		_pause_menu.call("focus_default")


func _handle_escape() -> bool:
	_refresh_refs()
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null and bool(admin.call("is_menu_open")):
		admin.call("close_menu")
		return true
	if _options_menu != null and bool(_options_menu.call("is_open")):
		return bool(_options_menu.call("handle_escape"))
	var lantern_ui := get_tree().get_first_node_in_group("lantern_ui")
	if lantern_ui != null and lantern_ui.has_method("consume_escape") and bool(lantern_ui.call("consume_escape")):
		return true
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.has_method("consume_escape") and bool(inventory.call("consume_escape")):
		return true
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("consume_escape") and bool(world_map.call("consume_escape")):
		return true
	if _pause_menu != null and bool(_pause_menu.call("is_open")):
		_pause_menu.call("resume_game")
		return true
	if get_tree().get_first_node_in_group("start_flow_ui") != null:
		return false
	if _pause_menu != null:
		_pause_menu.call("open_pause")
		return true
	return false


func _refresh_refs() -> void:
	if _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = get_tree().get_first_node_in_group("pause_menu") as Node
	if _options_menu == null or not is_instance_valid(_options_menu):
		_options_menu = get_tree().get_first_node_in_group("options_menu") as Node
