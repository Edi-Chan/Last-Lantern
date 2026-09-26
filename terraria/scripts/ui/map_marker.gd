class_name MapMarker
extends RefCounted

## Erweiterbare Kartenmarkierung. Sichtbarkeit haengt an Discovery, ausser der Spieler.

enum Type {
	PLAYER,
	LAST_LANTERN,
	BED,
	DEATH,
	BOSS_FORTRESS,
	SHOP,
	WAYPOINT,
	QUEST,
	STRUCTURE,
	CUSTOM,
}

var id: StringName = &""
var type: Type = Type.CUSTOM
var world_position: Vector2 = Vector2.ZERO
var icon: Texture2D
var color: Color = Color.WHITE
var discovered_required: bool = true
var visible: bool = true


func tile(map_data: Object) -> Vector2i:
	if map_data != null and map_data.has_method("world_to_map"):
		return map_data.call("world_to_map", world_position) as Vector2i
	return Vector2i(int(floor(world_position.x / 16.0)), int(floor(world_position.y / 16.0)))


func is_shown(map_data: Object) -> bool:
	if not visible:
		return false
	if not discovered_required:
		return true
	if map_data == null or not map_data.has_method("is_discovered"):
		return false
	return bool(map_data.call("is_discovered", tile(map_data)))
