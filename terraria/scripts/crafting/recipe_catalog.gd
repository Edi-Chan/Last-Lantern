@tool
class_name RecipeCatalog
extends Resource

## Baut Rezepte aus vorhandenen Item-/Blockdaten. Keine neuen Items, keine Screenshot-Kosten.

const WOOD_ITEM_ID := 9
const OAK_WOOD_ITEM_ID := 15
const BIRCH_WOOD_ITEM_ID := 16
const PINE_WOOD_ITEM_ID := 17
const STONE_ITEM_ID := 2
const WORKBENCH_ITEM_ID := 90
## Alle Holzarten sind beim Craften untereinander ersetzbar.
const WOOD_MATERIAL_IDS := [WOOD_ITEM_ID, OAK_WOOD_ITEM_ID, BIRCH_WOOD_ITEM_ID, PINE_WOOD_ITEM_ID]

## Spitzhacke -> Material und Barren-/Steinmenge. Metalle brauchen geschmolzene Barren.
const PICKAXE_MATERIAL := {
	22: {"mat": STONE_ITEM_ID, "amt": 10},
	40: {"mat": 123, "amt": 5},
	41: {"mat": 124, "amt": 6},
	42: {"mat": 125, "amt": 7},
	43: {"mat": 126, "amt": 8},
	44: {"mat": 127, "amt": 10},
	45: {"mat": 128, "amt": 11},
	46: {"mat": 129, "amt": 12},
	47: {"mat": 130, "amt": 13},
	48: {"mat": 131, "amt": 15},
	49: {"mat": 132, "amt": 16},
}

## Erz zu Barren am Schmelzofen. Fruehe Erze 3:1, mittlere 4:1, spaete 5:1.
const SMELT_RECIPES := {
	123: {"ore": 11, "amt": 3},
	124: {"ore": 12, "amt": 3},
	125: {"ore": 13, "amt": 3},
	126: {"ore": 14, "amt": 3},
	127: {"ore": 33, "amt": 4},
	128: {"ore": 34, "amt": 4},
	129: {"ore": 35, "amt": 4},
	130: {"ore": 36, "amt": 4},
	131: {"ore": 37, "amt": 5},
	132: {"ore": 38, "amt": 5},
}

## Metallruestung aus Barren am Amboss. Helm / Brust / Beine.
const ARMOR_BAR_RECIPES := {
	133: {"mat": 123, "amt": 8},
	134: {"mat": 123, "amt": 16},
	135: {"mat": 123, "amt": 12},
	136: {"mat": 124, "amt": 8},
	137: {"mat": 124, "amt": 16},
	138: {"mat": 124, "amt": 12},
	139: {"mat": 125, "amt": 10},
	140: {"mat": 125, "amt": 20},
	141: {"mat": 125, "amt": 15},
	142: {"mat": 126, "amt": 10},
	143: {"mat": 126, "amt": 20},
	144: {"mat": 126, "amt": 15},
	145: {"mat": 127, "amt": 12},
	146: {"mat": 127, "amt": 24},
	147: {"mat": 127, "amt": 18},
	148: {"mat": 128, "amt": 12},
	149: {"mat": 128, "amt": 24},
	150: {"mat": 128, "amt": 18},
	151: {"mat": 129, "amt": 14},
	152: {"mat": 129, "amt": 28},
	153: {"mat": 129, "amt": 21},
	154: {"mat": 130, "amt": 14},
	155: {"mat": 130, "amt": 28},
	156: {"mat": 130, "amt": 21},
	157: {"mat": 131, "amt": 16},
	158: {"mat": 131, "amt": 32},
	159: {"mat": 131, "amt": 24},
	160: {"mat": 132, "amt": 18},
	161: {"mat": 132, "amt": 36},
	162: {"mat": 132, "amt": 27},
}

## Holzwerkzeuge, deren Name und ToolData eindeutig Holz als Material vorgeben.
const WOOD_TOOL_IDS := [24, 26, 27]
const WOOD_PICKAXE_ID := 117
const WOOD_AXE_ID := 118
const WOOD_SWORD_ID := 119
const WOOD_HELMET_ID := 120
const WOOD_CHEST_ID := 121
const WOOD_LEGS_ID := 122
## Holz-Tier an der Werkbank. Mengen bewusst unter Stein/Metall.
const WOOD_GEAR_RECIPES := {
	WOOD_PICKAXE_ID: {"amt": 10, "station": 1},
	WOOD_AXE_ID: {"amt": 8, "station": 1},
	WOOD_SWORD_ID: {"amt": 8, "station": 1},
	WOOD_HELMET_ID: {"amt": 10, "station": 1},
	WOOD_CHEST_ID: {"amt": 20, "station": 1},
	WOOD_LEGS_ID: {"amt": 15, "station": 1},
}

@export var item_catalog: ItemCatalog
@export var block_catalog: BlockCatalog
## Optionale Handrezepte. Ueberschreiben Auto-Rezepte mit gleicher Output-ID.
@export var extra_recipes: Array[RecipeData] = []

var _recipes: Array[RecipeData] = []
var _by_id: Dictionary = {}
var _built: bool = false


func get_recipes() -> Array[RecipeData]:
	_ensure_built()
	return _recipes


static func is_wood_material(item_id: int) -> bool:
	return item_id == WOOD_ITEM_ID \
		or item_id == OAK_WOOD_ITEM_ID \
		or item_id == BIRCH_WOOD_ITEM_ID \
		or item_id == PINE_WOOD_ITEM_ID


static func substitute_ids(item_id: int) -> Array[int]:
	var result: Array[int] = []
	if not is_wood_material(item_id):
		result.append(item_id)
		return result
	result.append(item_id)
	for wood_id in WOOD_MATERIAL_IDS:
		if wood_id != item_id:
			result.append(int(wood_id))
	return result


static func ingredient_display_name(item: ItemData, item_id: int) -> String:
	if is_wood_material(item_id):
		return "Holz (alle Arten)"
	if item != null and not item.display_name.is_empty():
		return item.display_name
	return "Item %d" % item_id


static func material_rank(item_id: int) -> int:
	if is_wood_material(item_id):
		return 0
	match item_id:
		2:
			return 1
		11, 123:
			return 2
		12, 124:
			return 3
		13, 125:
			return 4
		14, 126:
			return 5
		33, 127:
			return 6
		34, 128:
			return 7
		35, 129:
			return 8
		36, 130:
			return 9
		37, 131:
			return 10
		38, 132:
			return 11
		_:
			return 20


static func recipe_progression_rank(recipe: RecipeData, item: ItemData) -> int:
	if item != null:
		if item.tool_kind == ItemData.ToolKind.PICKAXE:
			return item.get_pickaxe_tier()
		if item.building_material == BlockData.BuildingMaterial.WOOD:
			return 0
		if item.building_material == BlockData.BuildingMaterial.STONE:
			return 1
		if item.building_material == BlockData.BuildingMaterial.BRICK:
			return 2
		if item.building_material == BlockData.BuildingMaterial.METAL:
			return 4
	if recipe != null:
		var best_amount := -1
		var rank := 20
		for ingredient in recipe.get_ingredients():
			var amount := int(ingredient["amount"])
			if amount > best_amount:
				best_amount = amount
				rank = material_rank(int(ingredient["item_id"]))
		return rank
	if item != null and item.is_weapon():
		return item.get_weapon_tier()
	return 20


static func recipe_sort_key(recipe: RecipeData, item: ItemData) -> Array:
	var subtype := 50
	var power := 0
	if item != null:
		if item.is_weapon():
			subtype = int(item.weapon_kind)
			power = item.get_base_damage()
		elif item.is_tool():
			subtype = int(item.tool_kind)
			power = item.get_base_tool_power()
		elif item.building_part_type != BlockData.BuildingPartType.NONE:
			subtype = int(item.building_part_type)
		else:
			power = item.defense
	var output_id := recipe.output_item_id if recipe != null else 0
	return [recipe_progression_rank(recipe, item), subtype, power, output_id]


func get_recipe(recipe_id: StringName) -> RecipeData:
	_ensure_built()
	return _by_id.get(recipe_id) as RecipeData


func get_recipe_for_output(item_id: int) -> RecipeData:
	_ensure_built()
	for recipe in _recipes:
		if recipe != null and recipe.output_item_id == item_id:
			return recipe
	return null


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_recipes.clear()
	_by_id.clear()
	var overrides: Dictionary = {}
	for extra in extra_recipes:
		if extra == null or extra.output_item_id < 0:
			continue
		overrides[extra.output_item_id] = extra
		_add_recipe(extra)
	if item_catalog == null:
		return
	for item in item_catalog.items:
		if item == null or overrides.has(item.id):
			continue
		var recipe := _make_recipe_for_item(item)
		if recipe != null:
			_add_recipe(recipe)


func _add_recipe(recipe: RecipeData) -> void:
	if recipe == null:
		return
	if recipe.recipe_id == &"":
		recipe.recipe_id = StringName("item_%d" % recipe.output_item_id)
	_recipes.append(recipe)
	_by_id[recipe.recipe_id] = recipe


func _make_recipe_for_item(item: ItemData) -> RecipeData:
	if item == null:
		return null
	var from_smelt := _recipe_from_smelt(item)
	if from_smelt != null:
		return from_smelt
	var from_wood := _recipe_from_wood_gear(item)
	if from_wood != null:
		return from_wood
	var from_armor := _recipe_from_bar_armor(item)
	if from_armor != null:
		return from_armor
	var from_weapon := _recipe_from_weapon(item)
	if from_weapon != null:
		return from_weapon
	var from_building := _recipe_from_building_part(item)
	if from_building != null:
		return from_building
	return _recipe_from_tool(item)


## Waffen: Stein/Holz bleiben roh, Metalle brauchen Barren statt Roherz.
const WEAPON_RECIPES := {
	100: {"mats": [2, 9], "amts": [8, 2], "station": 1, "out": 1},
	101: {"mats": [123, 9], "amts": [6, 2], "station": 2, "out": 1},
	102: {"mats": [125, 9], "amts": [7, 2], "station": 2, "out": 1},
	103: {"mats": [127, 9], "amts": [8, 3], "station": 2, "out": 1},
	104: {"mats": [129, 9], "amts": [9, 3], "station": 2, "out": 1},
	105: {"mats": [131, 9], "amts": [10, 3], "station": 2, "out": 1},
	106: {"mats": [132, 9], "amts": [12, 4], "station": 2, "out": 1},
	107: {"mats": [9, 2], "amts": [6, 2], "station": 1, "out": 1},
	108: {"mats": [123, 9], "amts": [4, 4], "station": 2, "out": 1},
	109: {"mats": [127, 9], "amts": [5, 5], "station": 2, "out": 1},
	110: {"mats": [131, 9], "amts": [6, 5], "station": 2, "out": 1},
	111: {"mats": [9, 2], "amts": [8, 2], "station": 1, "out": 1},
	112: {"mats": [127, 9], "amts": [6, 6], "station": 2, "out": 1},
	113: {"mats": [132, 9], "amts": [8, 6], "station": 2, "out": 1},
	114: {"mats": [9, 2], "amts": [1, 1], "station": 1, "out": 8},
	115: {"mats": [9, 2, 123], "amts": [6, 8, 2], "station": 1, "out": 1},
}


func _recipe_from_smelt(item: ItemData) -> RecipeData:
	if item == null or not SMELT_RECIPES.has(item.id):
		return null
	var spec: Dictionary = SMELT_RECIPES[item.id]
	var ids: Array[int] = [int(spec["ore"])]
	var amounts: Array[int] = [maxi(1, int(spec["amt"]))]
	var stations: Array[int] = [RecipeData.Station.FURNACE]
	var recipe := _new_recipe(item, ids, amounts, stations)
	recipe.ui_category = RecipeData.UiCategory.SMELTING
	return recipe


func _recipe_from_bar_armor(item: ItemData) -> RecipeData:
	if item == null or not ARMOR_BAR_RECIPES.has(item.id):
		return null
	var spec: Dictionary = ARMOR_BAR_RECIPES[item.id]
	var ids: Array[int] = [int(spec["mat"])]
	var amounts: Array[int] = [maxi(1, int(spec["amt"]))]
	var stations: Array[int] = [RecipeData.Station.ANVIL]
	return _new_recipe(item, ids, amounts, stations)


func _recipe_from_wood_gear(item: ItemData) -> RecipeData:
	if item == null or not WOOD_GEAR_RECIPES.has(item.id):
		return null
	var spec: Dictionary = WOOD_GEAR_RECIPES[item.id]
	var ids: Array[int] = [WOOD_ITEM_ID]
	var amounts: Array[int] = [maxi(1, int(spec["amt"]))]
	var stations: Array[int] = []
	var station := int(spec["station"])
	if station != RecipeData.Station.NONE:
		stations.append(station)
	return _new_recipe(item, ids, amounts, stations)


func _recipe_from_weapon(item: ItemData) -> RecipeData:
	if item == null or not WEAPON_RECIPES.has(item.id):
		return null
	var spec: Dictionary = WEAPON_RECIPES[item.id]
	var ids: Array[int] = []
	var amounts: Array[int] = []
	for mat in spec["mats"]:
		ids.append(int(mat))
	for amt in spec["amts"]:
		amounts.append(int(amt))
	var stations: Array[int] = []
	var station := int(spec["station"])
	if station != RecipeData.Station.NONE:
		stations.append(station)
	var recipe := _new_recipe(item, ids, amounts, stations)
	recipe.output_amount = maxi(1, int(spec["out"]))
	return recipe


func _recipe_from_building_part(item: ItemData) -> RecipeData:
	if item.building_part_type == BlockData.BuildingPartType.NONE:
		return null
	var material_id := _material_item_id(item.building_material)
	if material_id < 0:
		return null
	var amount := 1
	if block_catalog != null and item.placeable_block_id >= 0:
		var block := block_catalog.get_by_id(item.placeable_block_id)
		if block != null:
			amount = maxi(1, block.footprint.x * block.footprint.y)
	var ids: Array[int] = []
	ids.append(material_id)
	var amounts: Array[int] = []
	amounts.append(amount)
	var stations: Array[int] = []
	if item.id != WORKBENCH_ITEM_ID:
		stations.append(RecipeData.Station.WORKBENCH)
	return _new_recipe(item, ids, amounts, stations)


func _recipe_from_tool(item: ItemData) -> RecipeData:
	if not item.is_tool() or item.tool_data == null:
		return null
	var amount := maxi(1, item.get_base_tool_power())
	var ids: Array[int] = []
	var amounts: Array[int] = []
	var stations: Array[int] = []
	if PICKAXE_MATERIAL.has(item.id):
		var spec: Dictionary = PICKAXE_MATERIAL[item.id]
		ids.append(int(spec["mat"]))
		amounts.append(maxi(1, int(spec["amt"])))
		if item.id != 22:
			stations.append(RecipeData.Station.ANVIL)
		return _new_recipe(item, ids, amounts, stations)
	if item.id == 23:
		ids.append(STONE_ITEM_ID)
		amounts.append(amount)
		return _new_recipe(item, ids, amounts, stations)
	if item.id in WOOD_TOOL_IDS:
		ids.append(WOOD_ITEM_ID)
		amounts.append(amount)
		return _new_recipe(item, ids, amounts, stations)
	return null


func _new_recipe(item: ItemData, ids: Array[int], amounts: Array[int], stations: Array[int]) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.recipe_id = StringName("item_%d" % item.id)
	recipe.output_item_id = item.id
	recipe.output_amount = 1
	for item_id in ids:
		recipe.ingredient_item_ids.append(int(item_id))
	for value in amounts:
		recipe.ingredient_amounts.append(int(value))
	for station in stations:
		recipe.required_stations.append(int(station))
	recipe.ui_category = RecipeData.resolve_ui_category(item) as RecipeData.UiCategory
	recipe.unlocked = true
	return recipe


func _material_item_id(material: int) -> int:
	match material:
		BlockData.BuildingMaterial.WOOD:
			return WOOD_ITEM_ID
		BlockData.BuildingMaterial.STONE:
			return STONE_ITEM_ID
		_:
			return -1
