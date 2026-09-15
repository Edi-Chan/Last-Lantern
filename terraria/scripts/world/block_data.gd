@tool
class_name BlockData
extends Resource

## Daten eines Welt-Tiles. Atlas-Koordinaten muessen zum vorhandenen TileSet passen.

enum BreakCheck {
	CAN_BREAK,
	UNBREAKABLE,
	WRONG_TOOL,
	TOOL_TOO_WEAK,
}

@export var id: int = 0
@export var display_name: String = ""
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var hardness: float = 1.0
@export var drop_item_id: int = -1
@export var solid: bool = true
## -1 = automatisch aus Blocktyp. 0 = Luft, 1 = volle Steinwand.
@export var vision_occlusion: float = -1.0
## Optional. Nur Erze setzen das.
@export var ore_data: OreData
@export var map_color: Color = Color(0, 0, 0, 0)
## Welches Werkzeug diesen Block abbauen darf. 0 = NONE, ohne spezielles Werkzeug.
## ItemData.ToolKind als int, analog zu OreData.
@export var required_tool: int = 0
@export var required_tool_power: int = 0
## Hartes Override. Bedrock setzt das. hardness >= 100 bleibt zusaetzlicher Fallback.
@export var is_unbreakable: bool = false


func get_required_tool() -> int:
	if ore_data != null:
		return int(ore_data.required_tool)
	return int(required_tool)


func get_required_tool_power() -> int:
	if ore_data != null:
		return ore_data.get_required_tool_power()
	return required_tool_power


func get_required_pickaxe_power() -> int:
	return get_required_tool_power()


func is_block_unbreakable() -> bool:
	return is_unbreakable or hardness >= 100.0


func evaluate_break(item: Resource = null, inst: RefCounted = null) -> BreakCheck:
	if is_block_unbreakable():
		return BreakCheck.UNBREAKABLE
	var need_kind := get_required_tool()
	var need_power := get_required_tool_power()
	if need_kind == 0 and need_power <= 0:
		return BreakCheck.CAN_BREAK
	if item == null or item.get("tool_data") == null:
		return BreakCheck.WRONG_TOOL
	if int(item.get("tool_kind")) != need_kind:
		return BreakCheck.WRONG_TOOL
	var power := 0
	if inst != null and inst.has_method("effective_tool_power"):
		power = int(inst.call("effective_tool_power", item))
	elif item.has_method("get_base_tool_power"):
		power = int(item.call("get_base_tool_power"))
	if power < need_power:
		return BreakCheck.TOOL_TOO_WEAK
	return BreakCheck.CAN_BREAK


func can_break_with(item: Resource = null, inst: RefCounted = null) -> bool:
	return evaluate_break(item, inst) == BreakCheck.CAN_BREAK


func get_map_color() -> Color:
	if map_color.a > 0.0:
		return map_color
	if ore_data != null:
		return ore_data.map_color
	return Color(0, 0, 0, 0)


func get_vision_occlusion() -> float:
	if vision_occlusion >= 0.0:
		return vision_occlusion
	match id:
		0:
			return 0.0
		8, 17, 18, 19:
			return 0.2
		7, 14, 15, 16:
			return 0.5
		20, 21, 22:
			return 0.1
		4:
			return 0.9
		_:
			return 1.0 if solid else 0.0
