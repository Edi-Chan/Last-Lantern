class_name Fox
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/fox/fox.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/fox_data.tres") as AnimalData
	super._ready()
