class_name FogDebugControls
extends VBoxContainer

## Gehoert an: HUD/FogDebug. Testknopf oben links, springt sofort auf Tag 7 22:00.

@export var settings: LastLanternSettings
@export var debug_day: int = 7

@onready var _test_button: Button = $TestFogButton
@onready var _end_button: Button = $EndFogButton
@onready var _lightning_button: Button = get_node_or_null("LightningButton")
@onready var _spawn_normal_button: Button = get_node_or_null("SpawnNormalZombie")
@onready var _spawn_dark_button: Button = get_node_or_null("SpawnDarkZombie")


func _ready() -> void:
	add_to_group("fog_debug_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 0
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	visible = settings == null or settings.show_debug_fog_button
	_disable_focus_pause()
	_wire_button(_test_button, _on_test_pressed)
	_wire_button(_end_button, _on_end_pressed)
	_wire_button(_lightning_button, _on_lightning_pressed)
	_wire_button(_spawn_normal_button, _on_spawn_normal)
	_wire_button(_spawn_dark_button, _on_spawn_dark)


func _process(_delta: float) -> void:
	_disable_focus_pause()


func _wire_button(button: Button, handler: Callable) -> void:
	if button == null:
		return
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not button.pressed.is_connected(handler):
		button.pressed.connect(handler)


func _on_test_pressed() -> void:
	_unpause_for_debug()
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog == null:
		return
	fog.debug_jump_to_fog_night(debug_day)


func _disable_focus_pause() -> void:
	var sm := get_tree().root.get_node_or_null("SettingsManager")
	if sm == null:
		return
	if sm.get("game") is Dictionary:
		sm.game["pause_when_unfocused"] = false
	if bool(sm.get("_paused_by_focus")):
		sm._paused_by_focus = false
		if not bool(sm.get("_menu_pause_active")):
			get_tree().paused = false


func _unpause_for_debug() -> void:
	var tree := get_tree()
	if tree == null:
		return
	_disable_focus_pause()
	var sm := tree.root.get_node_or_null("SettingsManager")
	if sm != null and sm.has_method("set_menu_pause"):
		sm.set_menu_pause(false)
	var pause := tree.get_first_node_in_group("pause_menu")
	if pause != null and pause.has_method("resume_game"):
		pause.call("resume_game")
	tree.paused = false


func _on_end_pressed() -> void:
	_unpause_for_debug()
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null:
		fog.debug_end_fog()


func _on_lightning_pressed() -> void:
	_unpause_for_debug()
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null:
		fog.debug_strike_lightning()


func _on_spawn_normal() -> void:
	_unpause_for_debug()
	_spawn_zombie(false)


func _on_spawn_dark() -> void:
	_unpause_for_debug()
	_spawn_zombie(true)


func _spawn_zombie(darkness: bool) -> void:
	var spawner := get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	if spawner != null:
		spawner.debug_spawn_zombie(darkness)
		return
	var scene := load("res://scenes/enemies/zombie.tscn") as PackedScene
	var player := get_tree().get_first_node_in_group("player") as Player
	if scene == null or player == null:
		return
	var zombie := scene.instantiate() as Zombie
	if zombie == null:
		return
	zombie.start_in_darkness = darkness
	zombie.lock_form = true
	player.get_parent().add_child(zombie)
	zombie.global_position = player.global_position + Vector2(player.facing_sign * 80.0, 0.0)
