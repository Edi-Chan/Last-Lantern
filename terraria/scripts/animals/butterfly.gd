class_name Butterfly
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/butterfly/butterfly.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/butterfly_data.tres") as AnimalData
	super._ready()
