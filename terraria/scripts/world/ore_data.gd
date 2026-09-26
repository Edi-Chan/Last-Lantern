@tool
class_name OreData
extends Resource

## Authoritative Erz-Progression. BlockData und WorldGenerator lesen nur hiervon.

## 0 NONE, 1 RAW_ORE, 2 REFINED_METAL, 3 ALLOY, 4 SPECIAL_ORE (Astralith).
enum OreMetalCategory {
	NONE = 0,
	RAW_ORE = 1,
	REFINED_METAL = 2,
	ALLOY = 3,
	SPECIAL_ORE = 4,
}

## Originaltabelle ist auf diese Referenztiefe skaliert.
const SPEC_REFERENCE_DEPTH := 1200.0

@export var ore_id: StringName = &""
@export var display_name: String = ""
@export var tier: int = 1
@export var block_id: int = -1
@export var drop_item_id: int = -1
## ItemData.ToolKind als int, damit OreData nicht zyklisch von ItemData abhaengt.
## 1 = PICKAXE. Alle aktuellen Erze brauchen eine Spitzhacke.
@export var required_tool: int = 1
@export var required_tool_power: int = 0
@export var spec_min_depth: int = 0
@export var spec_max_depth: int = 1200
@export var min_depth_ratio: float = 0.0
@export var max_depth_ratio: float = 1.0
@export var vein_min_size: int = 1
@export var vein_max_size: int = 1
@export var drop_min: int = 1
@export var drop_max: int = 1
@export var xp_reward: int = 0
@export var rarity_weight: float = 1.0
@export var metal_category: OreMetalCategory = OreMetalCategory.RAW_ORE
@export var hardness: float = 2.0
@export var map_color: Color = Color(0.7, 0.5, 0.3, 1)
@export var special_spawn: bool = false


static func get_metal_category_display_name(category: OreMetalCategory) -> String:
	match category:
		OreMetalCategory.RAW_ORE:
			return "Roherz"
		OreMetalCategory.REFINED_METAL:
			return "Verarbeitetes Metall"
		OreMetalCategory.ALLOY:
			return "Legierung"
		OreMetalCategory.SPECIAL_ORE:
			return "Spezialerz"
		_:
			return ""


func get_required_tool_power() -> int:
	return required_tool_power


func get_required_pickaxe_power() -> int:
	return required_tool_power


func roll_drop_amount(rng: RandomNumberGenerator = null) -> int:
	var low := mini(drop_min, drop_max)
	var high := maxi(drop_min, drop_max)
	if rng != null:
		return rng.randi_range(low, high)
	return randi_range(low, high)
