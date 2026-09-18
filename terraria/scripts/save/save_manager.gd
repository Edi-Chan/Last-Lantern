class_name SaveManager
extends Node

## Sammelt vorhandene to_save_dict-Systeme und Gebaeudedaten. Kein Auto-Load beim Start.

const SAVE_PATH := "user://last_lantern_save.json"
const GROUP := &"save_manager"

signal save_completed
signal load_completed


func _ready() -> void:
	add_to_group(GROUP)


func save_game() -> bool:
	var payload := {
		"version": 1,
		"buildings": _call_save("building_manager"),
		"structural": _call_save("structural_manager"),
		"building_parts": _call_save("building_part_system"),
		"day_cycle": _call_save("day_cycle"),
		"fog_event": _call_save("fog_event"),
		"lantern": _call_save("lantern"),
		"vegetation": _call_save("vegetation_system"),
		"inventory": _inventory_save(),
		"player": _player_save(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: konnte nicht schreiben.")
		return false
	file.store_string(JSON.stringify(payload))
	save_completed.emit()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	_call_load("day_cycle", data.get("day_cycle", {}))
	_call_load("fog_event", data.get("fog_event", {}))
	_call_load("lantern", data.get("lantern", {}))
	_call_load("vegetation_system", data.get("vegetation", {}))
	_call_load("structural_manager", data.get("structural", {}))
	_call_load("building_part_system", data.get("building_parts", {}))
	_call_load("building_manager", data.get("buildings", {}))
	_inventory_load(data.get("inventory", {}))
	_player_load(data.get("player", {}))
	var buildings := get_tree().get_first_node_in_group("building_manager")
	if buildings != null and buildings.has_method("apply_loaded_player_area"):
		buildings.call("apply_loaded_player_area")
	load_completed.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _call_save(group_name: StringName) -> Dictionary:
	var node := get_tree().get_first_node_in_group(group_name)
	if node != null and node.has_method("to_save_dict"):
		return node.call("to_save_dict")
	return {}


func _call_load(group_name: StringName, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var node := get_tree().get_first_node_in_group(group_name)
	if node != null and node.has_method("from_save_dict"):
		node.call("from_save_dict", data)


func _inventory_save() -> Dictionary:
	var inv := get_tree().get_first_node_in_group("player_inventory") as Inventory
	if inv == null:
		return {}
	if inv.has_method("to_save_dict"):
		return inv.call("to_save_dict")
	return {}


func _inventory_load(data: Dictionary) -> void:
	var inv := get_tree().get_first_node_in_group("player_inventory") as Inventory
	if inv != null and inv.has_method("from_save_dict"):
		inv.call("from_save_dict", data)


func _player_save() -> Dictionary:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return {}
	return {
		"position": [player.global_position.x, player.global_position.y],
	}


func _player_load(data: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or data.is_empty():
		return
	var pos: Array = data.get("position", [])
	if pos.size() >= 2:
		player.global_position = Vector2(float(pos[0]), float(pos[1]))
		player.velocity = Vector2.ZERO
