class_name Chicken
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/chicken/chicken.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/chicken_data.tres") as AnimalData
	super._ready()
