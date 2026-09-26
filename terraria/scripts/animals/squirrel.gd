class_name Squirrel
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/squirrel/squirrel.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/squirrel_data.tres") as AnimalData
	super._ready()
