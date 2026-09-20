class_name SessionRecord
extends Resource

@export var appearance: LookRecord
@export var world_seed: int = 0


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"character": appearance.to_dict() if appearance != null else {},
	}
