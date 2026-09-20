class_name LookRecord
extends Resource

const NAME_MAX_LENGTH := 20

@export var character_name: String = ""


func normalize() -> void:
	character_name = character_name.strip_edges()
	if character_name.length() > NAME_MAX_LENGTH:
		character_name = character_name.substr(0, NAME_MAX_LENGTH)


func is_valid() -> bool:
	normalize()
	return not character_name.is_empty()


func to_dict() -> Dictionary:
	normalize()
	return {"character_name": character_name}
