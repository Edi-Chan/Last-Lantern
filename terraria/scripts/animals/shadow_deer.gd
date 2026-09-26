class_name ShadowDeer
extends AnimalBase

## Gehoert an: Root von res://scenes/animals/shadow_deer/shadow_deer.tscn

func _ready() -> void:
	if data == null:
		data = load("res://resources/animals/shadow_deer_data.tres") as AnimalData
	super._ready()
