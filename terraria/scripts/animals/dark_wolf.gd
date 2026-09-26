class_name DarkWolf
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/dark_wolf/dark_wolf.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/dark_wolf_data.tres") as AnimalData
	super._ready()
