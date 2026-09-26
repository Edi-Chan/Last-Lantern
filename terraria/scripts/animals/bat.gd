class_name Bat
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/bat/bat.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/bat_data.tres") as AnimalData
	super._ready()
