class_name Boar
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/boar/boar.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/boar_data.tres") as AnimalData
	super._ready()
