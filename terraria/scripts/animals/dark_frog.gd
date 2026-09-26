class_name DarkFrog
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/dark_frog/dark_frog.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/dark_frog_data.tres") as AnimalData
	super._ready()
