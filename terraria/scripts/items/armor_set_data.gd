@tool
class_name ArmorSetData
extends Resource

## Daten eines 3-teiligen Ruestungssets. Zahlen stehen nur hier, nicht in UI-Scripts.

@export var set_id: StringName = ArmorSet.NONE
@export var display_name: String = ""
@export var required_piece_count: int = 3
@export var set_bonus_name: String = ""
@export_multiline var set_bonus_description: String = ""
@export var icon: Texture2D
@export var piece_item_ids: Array[int] = []
@export var modifiers: Array[StatModifier] = []


func is_complete(equipped_count: int) -> bool:
	return equipped_count >= maxi(required_piece_count, 1)


func bonus_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for mod in modifiers:
		var line := StatId.format_modifier_line(mod)
		if not line.is_empty():
			lines.append(line)
	return lines
