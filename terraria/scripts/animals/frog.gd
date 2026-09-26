class_name Frog
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/frog/frog.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/frog_data.tres") as AnimalData
	super._ready()
