class_name Bee
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/bee/bee.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/bee_data.tres") as AnimalData
	super._ready()
