class_name Wolf
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/wolf/wolf.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/wolf_data.tres") as AnimalData
	super._ready()
