@tool
class_name TreeData
extends Resource

## Beschreibt eine Baumart: Optik, Hoehe, Drops und Wachstum.

@export var tree_id: StringName = &"oak"
@export var display_name: String = "Eiche"
@export var trunk_block_id: int = 14
@export var leaf_block_id: int = 17
@export var sapling_block_id: int = 20
@export var wood_item_id: int = 15
@export var seed_item_id: int = 18
@export var min_height: int = 5
@export var max_height: int = 8
@export var growth_stage_count: int = 5
@export var regrow_time: float = 10.0
@export var trunk_hardness: float = 1.0
## Oberster Stammblock relativ zur Basis. 0.45 = 45% der Basis-Haerte.
@export var top_hardness_multiplier: float = 0.45
## round = Eiche, narrow = Birke, triangle = Kiefer
@export var crown_style: StringName = &"round"
## ItemData.ToolKind als int. 2 = AXE. Staemme fallen nur mit diesem Werkzeug.
@export var required_felling_tool: int = 2


func can_fell_with(item: Resource = null) -> bool:
	if item == null or item.get("tool_data") == null:
		return false
	return int(item.get("tool_kind")) == required_felling_tool
