@tool
class_name ToolData
extends Resource

## Unveraenderliche Basiswerte eines Werkzeugs. Upgrades leben auf der Instance.

enum ToolCategory {
	NONE,
	MINING,
	WOODCUTTING,
	BUILDING_REPAIR,
	DISMANTLING,
	FARMING,
	GATHERING_SPECIAL,
	EXPLORATION,
}

## Range ist in Tiles (16 px). Player-Mining bleibt separat auf interaction_range_tiles.
@export var tool_category: ToolCategory = ToolCategory.NONE
@export var base_damage: int = 0
@export var base_tool_power: int = 0
@export var base_use_speed: float = 1.0
@export var base_max_durability: int = 0
@export var base_range: float = 2.5
@export var special: String = ""
## Nur fuer MINING-Werkzeuge. 0 = kein Pickaxe-Tier.
@export var pickaxe_tier: int = 0


static func get_category_display_name(tool_category: ToolCategory) -> String:
	match tool_category:
		ToolCategory.MINING:
			return "Bergbau"
		ToolCategory.WOODCUTTING:
			return "Holzfällen"
		ToolCategory.BUILDING_REPAIR:
			return "Bauen / Reparieren"
		ToolCategory.DISMANTLING:
			return "Demontieren"
		ToolCategory.FARMING:
			return "Landwirtschaft"
		ToolCategory.GATHERING_SPECIAL:
			return "Sammeln / Spezial"
		ToolCategory.EXPLORATION:
			return "Erkundung"
		_:
			return ""
