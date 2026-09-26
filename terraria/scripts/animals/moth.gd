class_name Moth
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/moth/moth.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/moth_data.tres") as AnimalData
	super._ready()
