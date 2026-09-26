class_name Firefly
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/firefly/firefly.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/firefly_data.tres") as AnimalData
	super._ready()
