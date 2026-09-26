class_name Hedgehog
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/hedgehog/hedgehog.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/hedgehog_data.tres") as AnimalData
	super._ready()
