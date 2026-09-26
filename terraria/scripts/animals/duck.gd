class_name Duck
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/duck/duck.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/duck_data.tres") as AnimalData
	super._ready()
