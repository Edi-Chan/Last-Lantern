class_name Rat
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/rat/rat.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/rat_data.tres") as AnimalData
	super._ready()
