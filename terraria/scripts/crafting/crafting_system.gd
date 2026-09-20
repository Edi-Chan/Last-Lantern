class_name CraftingSystem
extends RefCounted

## Prueft und fuehrt Crafting aus. Bei Fehlern werden keine Materialien entfernt.

enum Result {
	OK,
	NO_RECIPE,
	LOCKED,
	NO_MATERIALS,
	NO_STATION,
	NO_SPACE,
	INVALID_AMOUNT,
}

var catalog: RecipeCatalog
var item_catalog: ItemCatalog


func setup(p_catalog: RecipeCatalog, p_items: ItemCatalog) -> void:
	catalog = p_catalog
	item_catalog = p_items


func get_recipes() -> Array[RecipeData]:
	if catalog == null:
		return []
	return catalog.get_recipes()


func recipes_for_context(context: int) -> Array[RecipeData]:
	var result: Array[RecipeData] = []
	for recipe in get_recipes():
		if recipe != null and recipe.matches_context(context):
			result.append(recipe)
	return result


func evaluate(recipe: RecipeData, inventory: Inventory, quantity: int, nearby_stations: Array[int]) -> int:
	if recipe == null:
		return Result.NO_RECIPE
	if not recipe.unlocked:
		return Result.LOCKED
	if quantity < 1:
		return Result.INVALID_AMOUNT
	if not _stations_satisfied(recipe, nearby_stations):
		return Result.NO_STATION
	if inventory == null:
		return Result.NO_MATERIALS
	if not _has_materials(recipe, inventory, quantity):
		return Result.NO_MATERIALS
	var out_amount := recipe.output_amount * quantity
	if not inventory.can_add_item(recipe.output_item_id, out_amount):
		return Result.NO_SPACE
	return Result.OK


func is_craftable(recipe: RecipeData, inventory: Inventory, nearby_stations: Array[int]) -> bool:
	return evaluate(recipe, inventory, 1, nearby_stations) == Result.OK


func max_craftable(recipe: RecipeData, inventory: Inventory, nearby_stations: Array[int]) -> int:
	if recipe == null or inventory == null or not recipe.unlocked:
		return 0
	if not _stations_satisfied(recipe, nearby_stations):
		return 0
	var limit := 999
	for ingredient in recipe.get_ingredients():
		var need := int(ingredient["amount"])
		if need <= 0:
			continue
		var have := _count_ingredient(inventory, int(ingredient["item_id"]))
		limit = mini(limit, int(float(have) / float(need)))
	if limit <= 0:
		return 0
	var output := recipe.output_amount if recipe.output_amount > 0 else 1
	var item: ItemData = null
	if item_catalog != null:
		item = item_catalog.get_item(recipe.output_item_id)
	var max_stack := item.max_stack if item != null else 999
	var space := _count_add_space(inventory, recipe.output_item_id, max_stack)
	limit = mini(limit, int(float(space) / float(output)))
	return maxi(0, limit)


func try_craft(recipe: RecipeData, inventory: Inventory, quantity: int, nearby_stations: Array[int]) -> int:
	var q := maxi(1, quantity)
	var check := evaluate(recipe, inventory, q, nearby_stations)
	if check != Result.OK:
		return check
	var costs := recipe.get_costs_for_quantity(q)
	var taken: Array = []
	for cost in costs:
		var removed := _consume_ingredient(inventory, int(cost["item_id"]), int(cost["amount"]))
		for part in removed:
			taken.append(part)
	var added := inventory.add_item(recipe.output_item_id, recipe.output_amount * q)
	if added:
		return Result.OK
	for part in taken:
		inventory.add_item(int(part["item_id"]), int(part["amount"]))
	return Result.NO_SPACE


func count_ingredient(inventory: Inventory, item_id: int) -> int:
	return _count_ingredient(inventory, item_id)


func _has_materials(recipe: RecipeData, inventory: Inventory, quantity: int) -> bool:
	if inventory == null:
		return false
	for cost in recipe.get_costs_for_quantity(quantity):
		var need := int(cost["amount"])
		if _count_ingredient(inventory, int(cost["item_id"])) < need:
			return false
	return true


func _count_ingredient(inventory: Inventory, item_id: int) -> int:
	if inventory == null:
		return 0
	var total := 0
	for alt_id in _alts(item_id):
		total += inventory.get_bag_amount(int(alt_id))
	return total


func _alts(item_id: int) -> Array[int]:
	return RecipeCatalog.substitute_ids(item_id)


func _consume_ingredient(inventory: Inventory, item_id: int, amount: int) -> Array:
	var taken: Array = []
	var remaining := amount
	if inventory == null or remaining <= 0:
		return taken
	for alt_id in RecipeCatalog.substitute_ids(item_id):
		if remaining <= 0:
			break
		var have := inventory.get_bag_amount(int(alt_id))
		var take := mini(have, remaining)
		if take <= 0:
			continue
		if inventory.try_consume_items([{"item_id": int(alt_id), "amount": take}]):
			taken.append({"item_id": int(alt_id), "amount": take})
			remaining -= take
	return taken


func collect_nearby_stations(tree: SceneTree) -> Array[int]:
	var found: Array[int] = []
	if tree == null:
		return found
	for node in tree.get_nodes_in_group("building_entity"):
		var entity := node as BuildingEntity
		if entity == null or not entity.is_player_in_range():
			continue
		var kind := entity.get_crafting_station_kind()
		if kind == RecipeData.Station.NONE:
			continue
		if not found.has(kind):
			found.append(kind)
	return found


func _stations_satisfied(recipe: RecipeData, nearby_stations: Array[int]) -> bool:
	if recipe == null or not recipe.requires_station():
		return true
	for station in recipe.required_stations:
		var kind := int(station)
		if kind == RecipeData.Station.NONE:
			continue
		if not nearby_stations.has(kind):
			return false
	return true


func _count_add_space(inventory: Inventory, item_id: int, max_stack: int) -> int:
	var space := 0
	for i in Inventory.SLOT_COUNT:
		var slot := inventory.get_slot(i)
		var sid := int(slot["item_id"])
		var amount := int(slot["amount"])
		if sid == item_id and amount > 0:
			space += maxi(0, max_stack - amount)
		elif sid < 0 or amount <= 0:
			space += max_stack
	return space
