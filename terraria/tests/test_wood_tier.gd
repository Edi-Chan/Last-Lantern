@tool
extends McpTestSuite


func suite_name() -> String:
	return "wood_tier"


func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func _items() -> ItemCatalog:
	return _load_fresh("res://resources/items/item_catalog.tres") as ItemCatalog


func _catalog() -> RecipeCatalog:
	return _load_fresh("res://resources/crafting/recipe_catalog.tres") as RecipeCatalog


func _system() -> CraftingSystem:
	var system := CraftingSystem.new()
	system.setup(_catalog(), _items())
	return system


func _inv() -> Inventory:
	var inv := Inventory.new()
	track(inv)
	inv.item_catalog = _items()
	inv.slots.resize(Inventory.SLOT_COUNT)
	for i in Inventory.SLOT_COUNT:
		inv.slots[i] = inv._empty_slot()
	inv.equipment = {
		"head": inv._empty_slot(),
		"chest": inv._empty_slot(),
		"legs": inv._empty_slot(),
		"accessory_1": inv._empty_slot(),
		"accessory_2": inv._empty_slot(),
	}
	return inv


func test_wood_items_in_catalog() -> void:
	var items := _items()
	assert_eq(items.get_item(117).display_name, "Holzspitzhacke")
	assert_eq(items.get_item(118).display_name, "Holzaxt")
	assert_eq(items.get_item(119).display_name, "Holzschwert")
	assert_eq(items.get_item(120).display_name, "Holzhelm")
	assert_eq(items.get_item(121).display_name, "Holzbrustrüstung")
	assert_eq(items.get_item(122).display_name, "Holzbeinschutz")
	assert_eq(int(items.get_item(120).equipment_slot), int(ItemData.EquipmentSlot.HEAD))
	assert_eq(int(items.get_item(121).equipment_slot), int(ItemData.EquipmentSlot.CHEST))
	assert_eq(int(items.get_item(122).equipment_slot), int(ItemData.EquipmentSlot.LEGS))
	assert_eq(items.get_item(120).defense, 1)
	assert_eq(items.get_item(121).defense, 2)
	assert_eq(items.get_item(122).defense, 2)
	assert_true(items.get_item(119).get_base_damage() < items.get_item(100).get_base_damage())


func test_wood_recipes_need_workbench() -> void:
	var catalog := _catalog()
	for item_id in [117, 118, 119, 120, 121, 122]:
		var recipe := catalog.get_recipe_for_output(item_id)
		assert_ne(recipe, null, "recipe missing for %d" % item_id)
		assert_true(recipe.requires_station_kind(RecipeData.Station.WORKBENCH))
		assert_eq(int(recipe.ingredient_item_ids[0]), 9)
	assert_eq(int(catalog.get_recipe_for_output(117).ingredient_amounts[0]), 10)
	assert_eq(int(catalog.get_recipe_for_output(118).ingredient_amounts[0]), 8)
	assert_eq(int(catalog.get_recipe_for_output(119).ingredient_amounts[0]), 8)
	assert_eq(int(catalog.get_recipe_for_output(120).ingredient_amounts[0]), 10)
	assert_eq(int(catalog.get_recipe_for_output(121).ingredient_amounts[0]), 20)
	assert_eq(int(catalog.get_recipe_for_output(122).ingredient_amounts[0]), 15)
	assert_eq(int(catalog.get_recipe_for_output(120).ui_category), int(RecipeData.UiCategory.ARMOR))
	assert_eq(int(catalog.get_recipe_for_output(119).ui_category), int(RecipeData.UiCategory.WEAPONS))
	assert_eq(int(catalog.get_recipe_for_output(117).ui_category), int(RecipeData.UiCategory.TOOLS))


func test_workbench_stays_handcraft_softlock_free() -> void:
	var recipe := _catalog().get_recipe_for_output(90)
	assert_ne(recipe, null)
	assert_false(recipe.requires_station())
	assert_eq(int(recipe.ingredient_item_ids[0]), 9)
	var trees := FileAccess.get_file_as_string("res://scripts/world/tree_data.gd")
	assert_true(trees.contains("func can_fell_with"))


func test_new_game_start_items_once() -> void:
	var inv := _inv()
	inv.give_new_game_start_items()
	assert_eq(int(inv.slots[0]["item_id"]), 117)
	assert_eq(int(inv.slots[1]["item_id"]), 118)
	assert_eq(int(inv.slots[2]["item_id"]), 119)
	assert_eq(inv.get_total_amount(117), 1)
	assert_eq(inv.get_total_amount(118), 1)
	assert_eq(inv.get_total_amount(119), 1)
	inv.give_new_game_start_items()
	assert_eq(inv.get_total_amount(117), 1)
	assert_eq(inv.get_total_amount(118), 1)
	assert_eq(inv.get_total_amount(119), 1)
	var saved := inv.to_save_dict()
	var loaded := _inv()
	loaded.from_save_dict(saved)
	assert_eq(int(loaded.slots[0]["item_id"]), 117)
	assert_eq(int(loaded.slots[1]["item_id"]), 118)
	assert_eq(int(loaded.slots[2]["item_id"]), 119)
	loaded.give_new_game_start_items()
	assert_eq(loaded.get_total_amount(117), 1)


func test_wood_armor_crafts_at_workbench() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(9, 20)
	var recipe := _catalog().get_recipe_for_output(121)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.NO_STATION)
	assert_eq(system.try_craft(recipe, inv, 1, [RecipeData.Station.WORKBENCH]), CraftingSystem.Result.OK)
	assert_eq(inv.get_total_amount(121), 1)
	assert_eq(inv.get_total_amount(9), 0)
