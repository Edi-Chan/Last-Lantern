class_name BuildingInterior
extends Node2D

## Begehbare Innendarstellung. Die Aussenwelt bleibt die Quelle der Wahrheit.

@export var building_type: StringName = &"FORGE"

var building_instance_id: String = ""
var _exit_hint: Label
var _player_at_exit: bool = false
var _ejecting: bool = false


func _ready() -> void:
	add_to_group("building_interior")
	process_mode = Node.PROCESS_MODE_INHERIT
	_bind_fog()
	_ensure_exit()
	call_deferred("_place_player")


func _process(_delta: float) -> void:
	if _ejecting or not _player_at_exit:
		return
	if UIManager.is_blocking_gameplay():
		return
	if not InputMap.has_action("interact"):
		return
	if Input.is_action_just_pressed("interact"):
		_request_exit()


func player_spawn() -> Vector2:
	var marker := get_node_or_null("PlayerSpawn") as Marker2D
	if marker != null:
		return marker.global_position
	return global_position + Vector2(48, -8)


func _place_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.global_position = player_spawn()
	player.velocity = Vector2.ZERO


func _bind_fog() -> void:
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog == null:
		return
	if not fog.fog_started.is_connected(_on_fog_started):
		fog.fog_started.connect(_on_fog_started)
	if fog.is_fog_active():
		call_deferred("_on_fog_started", 0, 0)


func _on_fog_started(_day: int = 0, _cycle: int = 0) -> void:
	if _ejecting:
		return
	_ejecting = true
	var mgr := get_tree().get_first_node_in_group("building_manager")
	if mgr != null:
		mgr.call("eject_for_fog", building_instance_id)


func _request_exit() -> void:
	var mgr := get_tree().get_first_node_in_group("building_manager")
	if mgr != null:
		mgr.call("try_exit")


func _ensure_exit() -> void:
	var area := get_node_or_null("ExitDoor/InteractionArea") as Area2D
	if area == null:
		return
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	if not area.body_entered.is_connected(_on_exit_entered):
		area.body_entered.connect(_on_exit_entered)
	if not area.body_exited.is_connected(_on_exit_exited):
		area.body_exited.connect(_on_exit_exited)
	_exit_hint = get_node_or_null("ExitDoor/HintLabel") as Label
	if _exit_hint != null:
		_exit_hint.visible = false


func _on_exit_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_at_exit = true
		if _exit_hint != null:
			_exit_hint.visible = true


func _on_exit_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_at_exit = false
		if _exit_hint != null:
			_exit_hint.visible = false
