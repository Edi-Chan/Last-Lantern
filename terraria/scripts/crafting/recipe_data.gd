@tool
class_name RecipeData
extends Resource

## Datenbasiertes Crafting-Rezept. Referenziert vorhandene Item-IDs, erzeugt keine neuen Items.

enum Station {
	NONE,
	WORKBENCH,
	ANVIL,
	FURNACE,
	FORGE,
}

enum UiCategory {
	ALL,
	TOOLS,
	WEAPONS,
	ARMOR,
	BUILDING_PARTS,
	STATIONS,
	CONSUMABLE,
	LIGHT,
	DECORATION,
	OTHER,
}

@export var recipe_id: StringName = &""
@export var output_item_id: int = -1
@export var output_amount: int = 1
@export var ingredient_item_ids: Array[int] = []
@export var ingredient_amounts: Array[int] = []
## Leere Liste = Handwerk ohne Station. Mehrere Eintraege gelten als UND.
@export var required_stations: Array[int] = []
@export var ui_category: UiCategory = UiCategory.OTHER
@export var unlocked: bool = true


func get_ingredients() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var n := mini(ingredient_item_ids.size(), ingredient_amounts.size())
	for i in n:
		if ingredient_item_ids[i] < 0 or ingredient_amounts[i] <= 0:
			continue
		result.append({
			"item_id": ingredient_item_ids[i],
			"amount": ingredient_amounts[i],
		})
	return result


func get_costs_for_quantity(quantity: int) -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	var q := maxi(1, quantity)
	for ingredient in get_ingredients():
		costs.append({
			"item_id": int(ingredient["item_id"]),
			"amount": int(ingredient["amount"]) * q,
		})
	return costs


func requires_station() -> bool:
	for station in required_stations:
		if int(station) != int(Station.NONE):
			return true
	return false


func requires_station_kind(kind: int) -> bool:
	if kind == Station.NONE:
		return not requires_station()
	for station in required_stations:
		if int(station) == kind:
			return true
	return false


func matches_context(context: int) -> bool:
	if context == Station.NONE:
		return true
	return requires_station_kind(context)


static func station_display_name(kind: int) -> String:
	match kind:
		Station.WORKBENCH:
			return "Werkbank"
		Station.ANVIL:
			return "Amboss"
		Station.FURNACE:
			return "Schmelzofen"
		Station.FORGE:
			return "Schmiede"
		_:
			return "Handwerk"


static func station_from_block_id(block_id: int) -> int:
	match block_id:
		60:
			return Station.WORKBENCH
		61:
			return Station.ANVIL
		62:
			return Station.FURNACE
		_:
			return Station.NONE


static func ui_category_display_name(category: int) -> String:
	match category:
		UiCategory.TOOLS:
			return "Werkzeuge"
		UiCategory.WEAPONS:
			return "⚔ Waffen"
		UiCategory.ARMOR:
			return "Rüstung"
		UiCategory.BUILDING_PARTS:
			return "Bauteile"
		UiCategory.STATIONS:
			return "Stationen"
		UiCategory.CONSUMABLE:
			return "Verbrauchbar"
		UiCategory.LIGHT:
			return "Licht & Laterne"
		UiCategory.DECORATION:
			return "Dekoration"
		UiCategory.OTHER:
			return "Sonstiges"
		_:
			return "Alle"


static func resolve_ui_category(item: ItemData) -> int:
	if item == null:
		return UiCategory.OTHER
	if item.building_part_type == BlockData.BuildingPartType.CRAFTING_STATION \
		or item.category == ItemData.ItemCategory.MACHINE_TECH:
		return UiCategory.STATIONS
	if item.building_part_type == BlockData.BuildingPartType.LIGHT \
		or item.id == 30 or item.id == 31:
		return UiCategory.LIGHT
	if item.building_part_type == BlockData.BuildingPartType.DECORATION \
		or item.building_part_type == BlockData.BuildingPartType.STORAGE:
		return UiCategory.DECORATION
	if item.category == ItemData.ItemCategory.WEAPON or item.is_weapon():
		return UiCategory.WEAPONS
	if item.category == ItemData.ItemCategory.AMMUNITION:
		return UiCategory.CONSUMABLE
	if item.category == ItemData.ItemCategory.ARMOR:
		return UiCategory.ARMOR
	if item.category == ItemData.ItemCategory.TOOL or item.is_tool():
		return UiCategory.TOOLS
	if item.category == ItemData.ItemCategory.HEALING \
		or item.category == ItemData.ItemCategory.FOOD_DRINK \
		or item.category == ItemData.ItemCategory.BUFF:
		return UiCategory.CONSUMABLE
	if item.building_part_type != BlockData.BuildingPartType.NONE \
		or item.category == ItemData.ItemCategory.BUILDING_MATERIAL \
		or item.category == ItemData.ItemCategory.TRAP_DEFENSE:
		return UiCategory.BUILDING_PARTS
	return UiCategory.OTHER
