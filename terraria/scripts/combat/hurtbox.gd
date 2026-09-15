class_name Hurtbox
extends Area2D

## Gehoert an: CombatDummy/Hurtbox oder spaetere Gegner.

func get_hurtbox_owner() -> Node:
	return get_parent()
