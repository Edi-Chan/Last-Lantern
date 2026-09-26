class_name Deer
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/deer/deer.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/deer_data.tres") as AnimalData
	super._ready()
