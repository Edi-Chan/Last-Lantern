@tool
class_name ArmorSetCatalog
extends Resource

## Sucht Setdaten anhand der Set-ID. Keine Laufzeit-Dateisuche im Projektbaum.

const DEFAULT_PATH := "res://resources/armor_sets/armor_set_catalog.tres"
const ARMOR_KEYS := ["head", "chest", "legs"]

@export var sets: Array[ArmorSetData] = []

static var _cached: ArmorSetCatalog


static func load_default() -> ArmorSetCatalog:
	if _cached != null:
		return _cached
	if not ResourceLoader.exists(DEFAULT_PATH):
		return null
	_cached = ResourceLoader.load(DEFAULT_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as ArmorSetCatalog
	return _cached


static func clear_cache() -> void:
	_cached = null


func set_id_for_item(item: ItemData) -> StringName:
	if item == null:
		return ArmorSet.NONE
	var sid := StringName(str(item.get("armor_set_id")))
	if sid != ArmorSet.NONE and String(sid) != "":
		return sid
	var item_id := int(item.get("id"))
	for entry in sets:
		if entry == null:
			continue
		if entry.piece_item_ids.has(item_id):
			return entry.set_id
	return ArmorSet.NONE


func get_set(set_id: StringName) -> ArmorSetData:
	if set_id == ArmorSet.NONE:
		return null
	for entry in sets:
		if entry != null and entry.set_id == set_id:
			return entry
	return null


func evaluate(inventory: Inventory) -> Dictionary:
	var counts: Dictionary = {}
	if inventory != null:
		for key in ARMOR_KEYS:
			var item := inventory.get_equipment_item(str(key))
			if item == null:
				continue
			var sid := set_id_for_item(item)
			if sid == ArmorSet.NONE:
				continue
			counts[sid] = int(counts.get(sid, 0)) + 1
	var best_id: StringName = ArmorSet.NONE
	var best_count := 0
	for sid in counts.keys():
		var count := int(counts[sid])
		if count > best_count:
			best_id = sid
			best_count = count
	var data := get_set(best_id)
	var required := data.required_piece_count if data != null else 3
	var complete := data != null and data.is_complete(best_count)
	return {
		"set_id": best_id,
		"data": data,
		"equipped": best_count,
		"required": required,
		"complete": complete,
		"counts": counts,
	}


func equipped_count_for(inventory: Inventory, set_id: StringName) -> int:
	if inventory == null or set_id == ArmorSet.NONE:
		return 0
	var count := 0
	for key in ARMOR_KEYS:
		var item := inventory.get_equipment_item(str(key))
		if item != null and set_id_for_item(item) == set_id:
			count += 1
	return count


func tooltip_lines_for_item(item: ItemData, inventory: Inventory = null) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if item == null or item.item_type != ItemData.ItemType.ARMOR:
		return lines
	for mod in item.collect_stat_modifiers():
		var line := StatId.format_modifier_line(mod)
		if not line.is_empty():
			lines.append(line)
	var set_id := set_id_for_item(item)
	var data := get_set(set_id)
	if data == null:
		return lines
	var have := equipped_count_for(inventory, set_id)
	if have <= 0:
		have = 1
	lines.append("%sset (%d/%d)" % [data.display_name, have, data.required_piece_count])
	if not data.set_bonus_name.is_empty():
		lines.append("Setbonus – %s:" % data.set_bonus_name)
	for bonus in data.bonus_lines():
		lines.append(bonus)
	return lines
