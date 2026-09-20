@tool
extends McpTestSuite

func suite_name() -> String:
	return "crafting"


func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func _catalog() -> RecipeCatalog:
	return _load_fresh("res://resources/crafting/recipe_catalog.tres") as RecipeCatalog


func _items() -> ItemCatalog:
	return _load_fresh("res://resources/items/item_catalog.tres") as ItemCatalog


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


func test_recipes_use_existing_items_only() -> void:
	var items := _items()
	var catalog := _catalog()
	var seen: Dictionary = {}
	for recipe in catalog.get_recipes():
		assert_ne(recipe, null)
		var output := items.get_item(recipe.output_item_id)
		assert_ne(output, null, "output %d missing" % recipe.output_item_id)
		assert_false(seen.has(recipe.output_item_id), "duplicate recipe for %d" % recipe.output_item_id)
		seen[recipe.output_item_id] = true
		assert_true(recipe.output_amount >= 1)
		assert_true(recipe.unlocked)
		assert_false(recipe.get_ingredients().is_empty())
		for ingredient in recipe.get_ingredients():
			var mat := items.get_item(int(ingredient["item_id"]))
			assert_ne(mat, null, "ingredient %d missing" % int(ingredient["item_id"]))
			assert_true(int(ingredient["amount"]) > 0)


func test_no_recipe_for_raw_and_test_items() -> void:
	var catalog := _catalog()
	for item_id in [1, 4, 5, 6, 11, 18, 21, 25, 28, 29, 30, 31, 32, 50, 61, 91]:
		assert_eq(catalog.get_recipe_for_output(item_id), null, "item %d should have no recipe" % item_id)


func test_stone_pickaxe_is_hand_craft() -> void:
	var recipe := _catalog().get_recipe_for_output(22)
	assert_ne(recipe, null)
	assert_false(recipe.requires_station())
	assert_true(recipe.matches_context(RecipeData.Station.NONE))
	assert_false(recipe.matches_context(RecipeData.Station.ANVIL))
	assert_eq(int(recipe.ingredient_item_ids[0]), 2)
	assert_eq(int(recipe.ingredient_amounts[0]), 10)


func test_copper_pickaxe_requires_anvil() -> void:
	var recipe := _catalog().get_recipe_for_output(40)
	assert_ne(recipe, null)
	assert_true(recipe.requires_station_kind(RecipeData.Station.ANVIL))
	assert_false(recipe.requires_station_kind(RecipeData.Station.WORKBENCH))
	assert_eq(int(recipe.ingredient_item_ids[0]), 123)
	assert_eq(int(recipe.ingredient_amounts[0]), 5)


func test_building_part_uses_existing_material_and_workbench() -> void:
	var recipe := _catalog().get_recipe_for_output(62)
	assert_ne(recipe, null)
	assert_true(recipe.requires_station_kind(RecipeData.Station.WORKBENCH))
	assert_eq(int(recipe.ingredient_item_ids[0]), 9)
	assert_eq(int(recipe.ui_category), int(RecipeData.UiCategory.BUILDING_PARTS))


func test_workbench_is_hand_crafted() -> void:
	var recipe := _catalog().get_recipe_for_output(90)
	assert_ne(recipe, null)
	assert_false(recipe.requires_station())
	assert_eq(int(recipe.ui_category), int(RecipeData.UiCategory.STATIONS))


func test_anvil_context_only_anvil_recipes() -> void:
	var system := _system()
	var anvil := system.recipes_for_context(RecipeData.Station.ANVIL)
	assert_true(anvil.size() > 0)
	for recipe in anvil:
		assert_true(recipe.requires_station_kind(RecipeData.Station.ANVIL))
		assert_ne(recipe.output_item_id, 22)
		assert_ne(recipe.output_item_id, 90)
		assert_ne(recipe.output_item_id, 62)
	var general := system.recipes_for_context(RecipeData.Station.NONE)
	assert_true(general.size() > anvil.size())


func test_craft_consumes_materials_and_adds_item() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(2, 20)
	var recipe := _catalog().get_recipe_for_output(22)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.OK)
	assert_eq(inv.get_bag_amount(2), 10)
	assert_eq(inv.get_bag_amount(22), 1)


func test_craft_fails_without_materials() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(2, 3)
	var recipe := _catalog().get_recipe_for_output(22)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.NO_MATERIALS)
	assert_eq(inv.get_bag_amount(2), 3)
	assert_eq(inv.get_bag_amount(22), 0)


func test_craft_fails_without_station() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(123, 10)
	var recipe := _catalog().get_recipe_for_output(40)
	assert_eq(system.evaluate(recipe, inv, 1, []), CraftingSystem.Result.NO_STATION)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.NO_STATION)
	assert_eq(inv.get_bag_amount(123), 10)
	assert_eq(inv.get_bag_amount(40), 0)
	assert_eq(system.try_craft(recipe, inv, 1, [RecipeData.Station.ANVIL]), CraftingSystem.Result.OK)
	assert_eq(inv.get_bag_amount(123), 5)
	assert_eq(inv.get_bag_amount(40), 1)


func test_craft_fails_when_inventory_full() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(2, 10)
	for i in Inventory.SLOT_COUNT:
		var slot := inv.slots[i]
		if int(slot["item_id"]) >= 0:
			continue
		slot["item_id"] = 9
		slot["amount"] = 1
	var recipe := _catalog().get_recipe_for_output(22)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.NO_SPACE)
	assert_eq(inv.get_bag_amount(2), 10)
	assert_eq(inv.get_bag_amount(22), 0)


func test_quantity_uses_materials() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(2, 25)
	var recipe := _catalog().get_recipe_for_output(22)
	assert_eq(system.max_craftable(recipe, inv, []), 2)
	assert_eq(system.try_craft(recipe, inv, 2, []), CraftingSystem.Result.OK)
	assert_eq(inv.get_bag_amount(2), 5)
	assert_eq(inv.get_bag_amount(22), 2)


func test_inventory_can_add_item() -> void:
	var inv := _inv()
	assert_true(inv.can_add_item(2, 10))
	inv.add_item(2, 10)
	assert_eq(inv.get_bag_amount(2), 10)


func test_crafting_has_category_subfilters() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/crafting_page.gd")
	assert_true(src.contains("func _subfilters_for"))
	assert_true(src.contains("func _item_matches_subfilter"))
	assert_true(src.contains("Helme"))
	assert_true(src.contains("Hintergrund"))
	assert_true(src.contains("Theke"))
	assert_true(src.contains("Schuhe"))
	assert_true(src.contains("Munition"))
	assert_true(src.contains("Landwirtschaft"))
	assert_true(src.contains("Schmelzen"))
	assert_true(src.contains("Barren"))
	assert_true(src.contains("Betten"))


func test_menu_tabs_exist() -> void:
	var scene := FileAccess.get_file_as_string("res://scenes/ui/inventory_screen.tscn")
	assert_true(scene.contains("TabInventory"))
	assert_true(scene.contains("TabCrafting"))
	assert_true(scene.contains("TabQuests"))
	assert_true(scene.contains("CraftingPage"))
	assert_true(scene.contains("QuestsPage"))
	assert_true(scene.contains("InventoryGrid"))
	var quests := FileAccess.get_file_as_string("res://scripts/ui/quests_page.gd")
	assert_true(quests.contains("Noch keine Quests verfügbar."))
	assert_false(quests.contains("Tutorial"))
	assert_false(quests.contains("Sammle Holz"))


func test_anvil_reuses_existing_entity_and_interact() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/building_parts/building_entity.gd")
	assert_true(src.contains("open_crafting"))
	assert_true(src.contains("is_action_just_pressed(\"interact\")"))
	assert_true(src.contains("[E] Amboss benutzen"))
	assert_true(src.contains("get_crafting_station_kind"))
	assert_false(src.contains("KEY_E"))
	assert_true(ResourceLoader.exists("res://resources/items/building/stations/anvil.tres"))
	var anvil := load("res://resources/items/building/stations/anvil.tres") as ItemData
	assert_eq(anvil.id, 91)
	assert_eq(anvil.display_name, "Amboss")


func test_any_wood_type_crafts_workbench() -> void:
	var system := _system()
	var recipe := _catalog().get_recipe_for_output(90)
	assert_ne(recipe, null)
	for wood_id in [9, 15, 16, 17]:
		var inv := _inv()
		inv.add_item(wood_id, 2)
		assert_true(system.is_craftable(recipe, inv, []))
		assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.OK)
		assert_eq(inv.get_bag_amount(wood_id), 0)
		assert_eq(inv.get_total_amount(90), 1)


func test_bed_recipe_is_workbench_only() -> void:
	var recipe := _catalog().get_recipe_for_output(163)
	assert_ne(recipe, null)
	assert_true(recipe.requires_station_kind(RecipeData.Station.WORKBENCH))
	assert_true(recipe.requires_station())
	assert_eq(int(recipe.ingredient_amounts[0]), 8)


func test_mixed_wood_types_count_together() -> void:
	var system := _system()
	var inv := _inv()
	inv.add_item(15, 1)
	inv.add_item(16, 1)
	var recipe := _catalog().get_recipe_for_output(90)
	assert_eq(system.count_ingredient(inv, 9), 2)
	assert_eq(system.try_craft(recipe, inv, 1, []), CraftingSystem.Result.OK)
	assert_eq(inv.get_total_amount(90), 1)
	assert_eq(inv.get_bag_amount(15) + inv.get_bag_amount(16), 0)


func test_recipes_sort_wood_before_stone_before_copper() -> void:
	var items := _items()
	var wood := RecipeCatalog.recipe_progression_rank(_catalog().get_recipe_for_output(117), items.get_item(117))
	var stone := RecipeCatalog.recipe_progression_rank(_catalog().get_recipe_for_output(22), items.get_item(22))
	var copper := RecipeCatalog.recipe_progression_rank(_catalog().get_recipe_for_output(40), items.get_item(40))
	var wood_sword := RecipeCatalog.recipe_progression_rank(_catalog().get_recipe_for_output(119), items.get_item(119))
	var stone_sword := RecipeCatalog.recipe_progression_rank(_catalog().get_recipe_for_output(100), items.get_item(100))
	assert_true(wood < stone)
	assert_true(stone < copper)
	assert_true(wood_sword < stone_sword)
	assert_true(RecipeCatalog.is_wood_material(15))
	assert_eq(RecipeCatalog.ingredient_display_name(items.get_item(15), 15), "Holz (alle Arten)")


func test_ores_smelt_to_bars_at_furnace() -> void:
	var catalog := _catalog()
	var copper_bar := catalog.get_recipe_for_output(123)
	assert_ne(copper_bar, null)
	assert_true(copper_bar.requires_station_kind(RecipeData.Station.FURNACE))
	assert_eq(int(copper_bar.ingredient_item_ids[0]), 11)
	assert_eq(int(copper_bar.ingredient_amounts[0]), 3)
	assert_eq(int(copper_bar.ui_category), int(RecipeData.UiCategory.SMELTING))
	var astralith_bar := catalog.get_recipe_for_output(132)
	assert_eq(int(astralith_bar.ingredient_item_ids[0]), 38)
	assert_eq(int(astralith_bar.ingredient_amounts[0]), 5)
	var system := _system()
	var inv := _inv()
	inv.add_item(11, 6)
	assert_eq(system.try_craft(copper_bar, inv, 1, []), CraftingSystem.Result.NO_STATION)
	assert_eq(system.try_craft(copper_bar, inv, 2, [RecipeData.Station.FURNACE]), CraftingSystem.Result.OK)
	assert_eq(inv.get_bag_amount(11), 0)
	assert_eq(inv.get_bag_amount(123), 2)


func test_metal_gear_uses_bars_not_ore() -> void:
	var catalog := _catalog()
	var sword := catalog.get_recipe_for_output(101)
	assert_eq(int(sword.ingredient_item_ids[0]), 123)
	assert_eq(int(sword.ingredient_amounts[0]), 6)
	var helm := catalog.get_recipe_for_output(133)
	assert_ne(helm, null)
	assert_true(helm.requires_station_kind(RecipeData.Station.ANVIL))
	assert_eq(int(helm.ingredient_item_ids[0]), 123)
	assert_eq(int(helm.ingredient_amounts[0]), 8)
	assert_eq(int(helm.ui_category), int(RecipeData.UiCategory.ARMOR))
	var chest := catalog.get_recipe_for_output(134)
	assert_eq(int(chest.ingredient_amounts[0]), 16)
	for item_id in [11, 12, 13, 14, 33, 34, 35, 36, 37, 38]:
		assert_eq(catalog.get_recipe_for_output(item_id), null)


func test_bar_items_have_icons() -> void:
	var items := _items()
	for item_id in range(123, 133):
		var item := items.get_item(item_id)
		assert_ne(item, null, "missing bar item %d" % item_id)
		assert_ne(item.icon, null, "missing bar icon %d" % item_id)
		assert_eq(int(item.ore_metal_category), int(OreData.OreMetalCategory.REFINED_METAL))
		assert_true(ResourceLoader.exists("res://assets/items/bars/%s_bar.png" % _bar_asset_key(item_id)))


func _bar_asset_key(item_id: int) -> String:
	match item_id:
		123: return "copper"
		124: return "tin"
		125: return "ferrite"
		126: return "aurel"
		127: return "cobalt"
		128: return "veyrite"
		129: return "cryonite"
		130: return "ignitium"
		131: return "voidium"
		132: return "astralith"
		_: return ""


func test_context_reset_on_close() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/inventory_screen.gd")
	assert_true(src.contains("open_crafting"))
	assert_true(src.contains("set_station_context"))
	assert_true(src.contains("MainTab.INVENTORY"))
	assert_true(src.contains("RecipeData.Station.NONE"))
