class_name CorruptedBoar
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/corrupted_boar/corrupted_boar.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/corrupted_boar_data.tres") as AnimalData
	super._ready()
