class_name Fish
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/fish/fish.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/fish_data.tres") as AnimalData
	super._ready()
