class_name Bird
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/bird/bird.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/bird_data.tres") as AnimalData
	super._ready()
