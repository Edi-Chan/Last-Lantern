class_name SessionRecord
extends Resource

@export var appearance: LookRecord
@export var world_seed: int = 0
@export var world_size: int = WorldSize.Id.MEDIUM


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"world_size": WorldSize.clamp_id(world_size),
		"character": appearance.to_dict() if appearance != null else {},
	}
