class_name Snail
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/snail/snail.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/snail_data.tres") as AnimalData
	super._ready()
