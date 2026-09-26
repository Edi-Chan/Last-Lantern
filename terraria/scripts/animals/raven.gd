class_name Raven
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/raven/raven.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/raven_data.tres") as AnimalData
	super._ready()
