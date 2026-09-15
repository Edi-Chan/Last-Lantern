class_name PauseMenu
extends Control

## Gehoert an: HUD/PauseMenu. Oeffnet sich per ESC, wenn keine hoehere UI-Ebene aktiv ist.

@onready var _dimmer: ColorRect = $Dimmer
@onready var _continue_button: Button = $CenterWrap/Panel/Margin/Layout/ContinueButton
@onready var _options_button: Button = $CenterWrap/Panel/Margin/Layout/OptionsButton
@onready var _quit_button: Button = $CenterWrap/Panel/Margin/Layout/QuitButton

var _open: bool = false
var _hidden_for_options: bool = false


func _ready() -> void:
	add_to_group("pause_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	_continue_button.pressed.connect(resume_game)
	_options_button.pressed.connect(_on_options_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_continue_button.focus_neighbor_top = _quit_button.get_path()
	_continue_button.focus_neighbor_bottom = _options_button.get_path()
	_options_button.focus_neighbor_top = _continue_button.get_path()
	_options_button.focus_neighbor_bottom = _quit_button.get_path()
	_quit_button.focus_neighbor_top = _options_button.get_path()
	_quit_button.focus_neighbor_bottom = _continue_button.get_path()
	UIManager.register_pause_menu(self)


func is_open() -> bool:
	return _open


func open_pause() -> void:
	if _open:
		return
	_close_gameplay_windows()
	_open = true
	_hidden_for_options = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _dimmer != null:
		_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.world_input_enabled = false
	SettingsManager.set_menu_pause(true)
	focus_default()


func resume_game() -> void:
	if not _open:
		return
	if UIManager.is_options_open():
		UIManager.close_options_to_pause()
	_open = false
	_hidden_for_options = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SettingsManager.set_menu_pause(false)
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	var inventory_open := false
	if inventory != null:
		inventory_open = bool(inventory.visible)
	var map_open := false
	if world_map != null and world_map.has_method("is_open"):
		map_open = bool(world_map.call("is_open"))
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not inventory_open and not map_open:
		player.world_input_enabled = true


func set_hidden_for_options(hidden: bool) -> void:
	_hidden_for_options = hidden
	visible = _open and not hidden
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE


func focus_default() -> void:
	if not visible:
		return
	_continue_button.grab_focus()


func _on_options_pressed() -> void:
	UIManager.open_options_from_pause()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _close_gameplay_windows() -> void:
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.visible and inventory.has_method("close"):
		inventory.call("close", false)
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("is_open") and world_map.is_open():
		world_map.call("close", false)
