@tool
class_name RecipeCatalog
extends Resource

## Baut Rezepte aus vorhandenen Item-/Blockdaten. Keine neuen Items, keine Screenshot-Kosten.

const WOOD_ITEM_ID := 9
const STONE_ITEM_ID := 2
const WORKBENCH_ITEM_ID := 90

## Spitzhacke -> vorhandenes Material. Menge kommt aus ToolData.base_tool_power.
const PICKAXE_MATERIAL := {
	22: STONE_ITEM_ID,
	40: 11,
	41: 12,
	42: 13,
	43: 14,
	44: 33,
	45: 34,
	46: 35,
	47: 36,
	48: 37,
	49: 38,
}

## Holzwerkzeuge, deren Name und ToolData eindeutig Holz als Material vorgeben.
const WOOD_TOOL_IDS := [24, 26, 27]

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
	var from_weapon := _recipe_from_weapon(item)
	if from_weapon != null:
		return from_weapon
	var from_building := _recipe_from_building_part(item)
	if from_building != null:
		return from_building
	return _recipe_from_tool(item)


## Waffe -> vorhandene Materialien. Metalle wie Spitzhacken aus Erz, nicht erfundenen Barren.
const WEAPON_RECIPES := {
	100: {"mats": [2, 9], "amts": [8, 2], "station": 1, "out": 1},
	101: {"mats": [11, 9], "amts": [8, 2], "station": 2, "out": 1},
	102: {"mats": [13, 9], "amts": [9, 2], "station": 2, "out": 1},
	103: {"mats": [33, 9], "amts": [9, 3], "station": 2, "out": 1},
	104: {"mats": [35, 9], "amts": [10, 3], "station": 2, "out": 1},
	105: {"mats": [37, 9], "amts": [10, 3], "station": 2, "out": 1},
	106: {"mats": [38, 9], "amts": [12, 4], "station": 2, "out": 1},
	107: {"mats": [9, 2], "amts": [6, 2], "station": 1, "out": 1},
	108: {"mats": [11, 9], "amts": [5, 4], "station": 2, "out": 1},
	109: {"mats": [33, 9], "amts": [6, 5], "station": 2, "out": 1},
	110: {"mats": [37, 9], "amts": [7, 5], "station": 2, "out": 1},
	111: {"mats": [9, 2], "amts": [8, 2], "station": 1, "out": 1},
	112: {"mats": [33, 9], "amts": [8, 6], "station": 2, "out": 1},
	113: {"mats": [38, 9], "amts": [10, 6], "station": 2, "out": 1},
	114: {"mats": [9, 2], "amts": [1, 1], "station": 1, "out": 8},
	115: {"mats": [9, 2, 11], "amts": [6, 8, 4], "station": 1, "out": 1},
}


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
		ids.append(int(PICKAXE_MATERIAL[item.id]))
		amounts.append(amount)
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
