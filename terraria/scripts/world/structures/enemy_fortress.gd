class_name EnemyFortress
extends Node2D

## Placeholder der Endgame-Festung. Boss-Logik kommt spaeter.

const GROUP := &"enemy_fortress"


func _ready() -> void:
	add_to_group(GROUP)


func configure(world: WorldGenerator, tile_x: int) -> void:
	if world != null and world.has_method("ground_world_position"):
		global_position = world.ground_world_position(tile_x)
	visible = true
