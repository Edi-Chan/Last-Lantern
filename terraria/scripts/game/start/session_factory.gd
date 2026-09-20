class_name SessionFactory
extends RefCounted

## Bereitet SessionRecord vor. Keine Szenenwechsel, keine Weltgeneration.


static func make_random_seed() -> int:
	var generated := randi()
	if generated == 0:
		generated = 1
	return generated


static func look_from_dict(data: Dictionary) -> LookRecord:
	var appearance := LookRecord.new()
	if data != null:
		appearance.character_name = str(data.get("character_name", ""))
	appearance.normalize()
	return appearance


static func session_from_dict(data: Dictionary) -> SessionRecord:
	var session := SessionRecord.new()
	if data == null:
		session.appearance = LookRecord.new()
		return session
	session.world_seed = int(data.get("world_seed", 0))
	session.world_size = WorldSize.clamp_id(int(data.get("world_size", WorldSize.Id.MEDIUM)))
	var character_raw: Variant = data.get("character", {})
	if character_raw is Dictionary:
		session.appearance = look_from_dict(character_raw)
	else:
		session.appearance = LookRecord.new()
	return session


static func create_session(appearance: LookRecord, world_size: int = WorldSize.Id.MEDIUM) -> SessionRecord:
	var session := SessionRecord.new()
	var copy := LookRecord.new()
	if appearance != null:
		copy.character_name = appearance.character_name
	copy.normalize()
	session.appearance = copy
	session.world_seed = make_random_seed()
	session.world_size = WorldSize.clamp_id(world_size)
	return session
