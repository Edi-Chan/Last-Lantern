class_name Main
extends Node

## Gehoert an: Main-Wurzelnode in res://scenes/main/main.tscn
##
## _ready laeuft nach den Kindern, die Welt ist hier also bereits generiert und
## kennt ihren Startpunkt. Dadurch braucht die Szene keine feste Testposition.

@onready var _world: WorldGenerator = $World
@onready var _player: Player = $Player


func _ready() -> void:
	if _world == null or _player == null:
		return
	_player.global_position = _world.player_spawn_position
	if _world.has_method("_apply_camera_limits"):
		_world.call("_apply_camera_limits")
	var lantern := get_tree().get_first_node_in_group("lantern") as Lantern
	if lantern != null:
		lantern.place_near_spawn()
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("on_world_ready"):
		flow.call("on_world_ready", self)
