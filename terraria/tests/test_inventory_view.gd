@tool
extends McpTestSuite

func suite_name() -> String:
	return "inventory_view"


func _item(path: String) -> ItemData:
	return load(path) as ItemData


func _names(entries: Array[Dictionary]) -> PackedStringArray:
	var names := PackedStringArray()
	for entry in entries:
		var item := entry["item"] as ItemData
		if item != null:
			names.append(item.display_name)
	return names


func _ids(entries: Array[Dictionary]) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for entry in entries:
		ids.append(int(entry["source_slot_index"]))
	return ids


func test_filter_categories_match_item_category() -> void:
	assert_eq(InventoryScreen.FILTER_CATEGORIES.size(), 16)
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[0]), int(ItemData.ItemCategory.WEAPON))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[1]), int(ItemData.ItemCategory.ARMOR))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[2]), int(ItemData.ItemCategory.HEALING))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[3]), int(ItemData.ItemCategory.FOOD_DRINK))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[4]), int(ItemData.ItemCategory.AMMUNITION))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[5]), int(ItemData.ItemCategory.BUILDING_MATERIAL))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[6]), int(ItemData.ItemCategory.RESOURCE))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[7]), int(ItemData.ItemCategory.ORE_METAL))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[8]), int(ItemData.ItemCategory.MAGIC_ENERGY))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[9]), int(ItemData.ItemCategory.TOOL))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[10]), int(ItemData.ItemCategory.BUFF))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[11]), int(ItemData.ItemCategory.MONSTER_MATERIAL))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[12]), int(ItemData.ItemCategory.TRAP_DEFENSE))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[13]), int(ItemData.ItemCategory.MACHINE_TECH))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[14]), int(ItemData.ItemCategory.VALUABLE))
	assert_eq(int(InventoryScreen.FILTER_CATEGORIES[15]), int(ItemData.ItemCategory.QUEST_KEY))
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.WEAPON).to_html(false).to_upper(), "E53935")
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.ARMOR).to_html(false).to_upper(), "3F7CFF")
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.TOOL).to_html(false).to_upper(), "24C7C8")


func test_search_is_case_insensitive() -> void:
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	var pickaxe := _item("res://resources/items/tools/mining/pickaxes/wood_pickaxe.tres")
	assert_true(InventoryScreen.item_matches_search(helmet, "helm"))
	assert_true(InventoryScreen.item_matches_search(helmet, "HELM"))
	assert_true(InventoryScreen.item_matches_search(helmet, "Holzhelm"))
	assert_false(InventoryScreen.item_matches_search(helmet, "hacke"))
	assert_true(InventoryScreen.item_matches_search(pickaxe, "hacke"))
	assert_true(InventoryScreen.item_matches_search(helmet, ""))


func test_filter_uses_existing_item_category() -> void:
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	assert_ne(helmet, null)
	assert_eq(int(helmet.category), int(ItemData.ItemCategory.ARMOR))
	assert_true(InventoryScreen.item_matches_filter(helmet, int(ItemData.ItemCategory.ARMOR)))
	assert_false(InventoryScreen.item_matches_filter(helmet, int(ItemData.ItemCategory.TOOL)))
	assert_true(InventoryScreen.item_matches_filter(helmet, -1), "Alle-Filter muss jedes Item durchlassen")


func test_search_and_filter_combine() -> void:
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	var chest := _item("res://resources/items/equipment/wood_chestplate.tres")
	assert_true(InventoryScreen.item_matches_search(chest, "brust") and InventoryScreen.item_matches_filter(chest, int(ItemData.ItemCategory.ARMOR)))
	assert_false(InventoryScreen.item_matches_search(helmet, "brust") and InventoryScreen.item_matches_filter(helmet, int(ItemData.ItemCategory.ARMOR)))


func test_sort_az_za_amount_damage_keep_source_indices() -> void:
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	var chest := _item("res://resources/items/equipment/wood_chestplate.tres")
	var legs := _item("res://resources/items/equipment/wood_leggings.tres")
	var pickaxe := _item("res://resources/items/tools/mining/pickaxes/wood_pickaxe.tres")
	var entries: Array[Dictionary] = [
		InventoryScreen.view_entry(10, helmet, 1),
		InventoryScreen.view_entry(11, chest, 4),
		InventoryScreen.view_entry(12, legs, 2),
		InventoryScreen.view_entry(13, pickaxe, 1),
	]
	var az := entries.duplicate()
	InventoryScreen.sort_view_entries(az, InventoryScreen.SortMode.NAME_AZ)
	assert_eq(_names(az), PackedStringArray(["Holzbeinschutz", "Holzbrustrüstung", "Holzhelm", "Holzspitzhacke"]))
	assert_eq(_ids(az), PackedInt32Array([12, 11, 10, 13]))
	var za := entries.duplicate()
	InventoryScreen.sort_view_entries(za, InventoryScreen.SortMode.NAME_ZA)
	assert_eq(_names(za), PackedStringArray(["Holzspitzhacke", "Holzhelm", "Holzbrustrüstung", "Holzbeinschutz"]))
	var amount := entries.duplicate()
	InventoryScreen.sort_view_entries(amount, InventoryScreen.SortMode.AMOUNT_HIGH)
	assert_eq(_ids(amount), PackedInt32Array([11, 12, 10, 13]))
	var amount_low := entries.duplicate()
	InventoryScreen.sort_view_entries(amount_low, InventoryScreen.SortMode.AMOUNT_LOW)
	assert_eq(int(amount_low[0]["amount"]), 1)
	var dmg := entries.duplicate()
	InventoryScreen.sort_view_entries(dmg, InventoryScreen.SortMode.DAMAGE_HIGH)
	assert_eq(int((dmg[0]["item"] as ItemData).id), 117)
	assert_eq(int(entries[0]["source_slot_index"]), 10)
	assert_eq(int(entries[1]["source_slot_index"]), 11)


func test_category_sort_uses_filter_order() -> void:
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	var pickaxe := _item("res://resources/items/tools/mining/pickaxes/wood_pickaxe.tres")
	var dirt := _item("res://resources/items/dirt.tres")
	var entries: Array[Dictionary] = [
		InventoryScreen.view_entry(10, dirt, 1),
		InventoryScreen.view_entry(11, pickaxe, 1),
		InventoryScreen.view_entry(12, helmet, 1),
	]
	InventoryScreen.sort_view_entries(entries, InventoryScreen.SortMode.CATEGORY)
	assert_eq(_ids(entries), PackedInt32Array([12, 10, 11]))


func test_default_view_flag() -> void:
	assert_true(InventoryScreen.is_default_bag_view("", -1, InventoryScreen.SortMode.STANDARD))
	assert_false(InventoryScreen.is_default_bag_view("hel", -1, InventoryScreen.SortMode.STANDARD))
	assert_false(InventoryScreen.is_default_bag_view("", int(ItemData.ItemCategory.TOOL), InventoryScreen.SortMode.STANDARD))
	assert_false(InventoryScreen.is_default_bag_view("", -1, InventoryScreen.SortMode.NAME_AZ))


func test_inspect_and_hover_text() -> void:
	var pickaxe := _item("res://resources/items/tools/mining/pickaxes/wood_pickaxe.tres")
	assert_ne(pickaxe, null)
	var hover := InventoryScreen.build_hover_text(pickaxe, null, 1)
	assert_true(hover.begins_with("Holzspitzhacke"))
	assert_true(hover.contains("Schaden 5"))
	var stats := InventoryScreen.build_inspect_stats(pickaxe, null, 1)
	assert_eq(stats, "Schaden 5 · Spitzhacken-Power 6")
	var helmet := _item("res://resources/items/equipment/wood_helmet.tres")
	var armor_stats := InventoryScreen.build_inspect_stats(helmet, null, 1)
	assert_true(armor_stats.contains("Rüstung: +1"))
	assert_true(armor_stats.contains("Max. Ausdauer: +3"))
	var empty := InventoryScreen.build_hover_text(null, null, 0)
	assert_eq(empty, "")
