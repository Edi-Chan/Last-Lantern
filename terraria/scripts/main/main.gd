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
