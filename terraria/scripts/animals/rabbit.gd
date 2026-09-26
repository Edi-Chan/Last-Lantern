class_name Rabbit
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/rabbit/rabbit.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/rabbit_data.tres") as AnimalData
	super._ready()
