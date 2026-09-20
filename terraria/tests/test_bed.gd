@tool
extends McpTestSuite


func suite_name() -> String:
	return "bed"


func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func _catalog() -> RecipeCatalog:
	return _load_fresh("res://resources/crafting/recipe_catalog.tres") as RecipeCatalog


func _items() -> ItemCatalog:
	return _load_fresh("res://resources/items/item_catalog.tres") as ItemCatalog


func _blocks() -> BlockCatalog:
	return _load_fresh("res://resources/blocks/block_catalog.tres") as BlockCatalog


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


func test_bed_item_and_block_link() -> void:
	var items := _items()
	var blocks := _blocks()
	var item := items.get_item(163)
	var block := blocks.get_by_id(64)
	assert_ne(item, null)
	assert_ne(block, null)
	assert_eq(item.display_name, "Bett")
	assert_eq(block.display_name, "Bett")
	assert_eq(item.placeable_block_id, 64)
	assert_eq(block.drop_item_id, 163)
	assert_eq(item.max_stack, 999)
	assert_true(item.is_placeable())
	assert_eq(int(item.building_part_type), int(BlockData.BuildingPartType.BED))
	assert_eq(int(block.building_part_type), int(BlockData.BuildingPartType.BED))
	assert_eq(block.footprint, Vector2i(4, 2))
	assert_true(block.footprint.x * 16 >= 40)
	assert_ne(item.icon, null)
	assert_true(ResourceLoader.exists("res://assets/building/furniture/wood_bed.png"))
	assert_eq(int(item.category), int(ItemData.ItemCategory.BUILDING_MATERIAL))


func test_bed_crafts_at_workbench_from_any_wood() -> void:
	var system := CraftingSystem.new()
	system.setup(_catalog(), _items())
	var recipe := _catalog().get_recipe_for_output(163)
	assert_ne(recipe, null)
	assert_true(recipe.requires_station_kind(RecipeData.Station.WORKBENCH))
	assert_eq(int(recipe.ingredient_item_ids[0]), 9)
	assert_eq(int(recipe.ingredient_amounts[0]), 8)
	assert_eq(int(recipe.ui_category), int(RecipeData.UiCategory.DECORATION))
	for wood_id in [9, 15, 16, 17]:
		var inv := _inv()
		inv.add_item(wood_id, 8)
		assert_eq(system.evaluate(recipe, inv, 1, []), CraftingSystem.Result.NO_STATION)
		assert_eq(system.try_craft(recipe, inv, 1, [RecipeData.Station.WORKBENCH]), CraftingSystem.Result.OK)
		assert_eq(inv.get_total_amount(163), 1)
		assert_eq(inv.get_bag_amount(wood_id), 0)


func test_bed_uses_player_heal() -> void:
	var stats := PlayerStats.new()
	track(stats)
	stats.sheet.apply_defaults()
	stats._sync_caps_from_sheet(true)
	stats.set_health(40.0)
	var healed := stats.heal(stats.max_health)
	assert_eq(int(round(stats.health)), int(round(stats.max_health)))
	assert_true(healed > 0.0)
	var src := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	assert_true(src.contains("heal(stats.max_health * bed_heal_fraction)"))
	assert_true(src.contains("use_bed"))
	assert_true(src.contains("resolve_respawn_position"))
	assert_true(src.contains("apply_spawn_after_load"))
	assert_true(src.contains("on_bed_removed"))
	assert_true(src.contains("Respawn-Punkt gesetzt."))


func test_bed_spawn_save_roundtrip_and_fallback() -> void:
	var player := Player.new()
	track(player)
	player.bed_from_save_dict({
		"active": true,
		"origin": [12, 40],
		"block_id": 64,
		"spawn": [200.0, 640.0],
		"world_seed": 99,
	})
	assert_true(player.bed_spawn_active)
	assert_eq(player.bed_origin, Vector2i(12, 40))
	assert_eq(player.bed_block_id, 64)
	assert_eq(player.bed_world_seed, 99)
	var saved := player.bed_to_save_dict()
	assert_true(bool(saved.get("active", false)))
	assert_eq(int(saved.get("block_id", -1)), 64)
	player.clear_bed_spawn()
	assert_false(player.bed_spawn_active)
	assert_false(player.has_valid_bed_spawn())
	var save_src := FileAccess.get_file_as_string("res://scripts/save/save_manager.gd")
	assert_true(save_src.contains("bed_spawn"))
	assert_true(save_src.contains("apply_spawn_after_load"))
	var flow_src := FileAccess.get_file_as_string("res://scripts/game/start/game_session_flow.gd")
	assert_true(flow_src.contains("Mode.NEW_GAME"))
	assert_true(flow_src.contains("Mode.CONTINUE"))
	assert_true(flow_src.contains("load_game"))


func test_admin_uses_same_bed_item() -> void:
	var admin_src := FileAccess.get_file_as_string("res://autoload/admin_manager.gd")
	assert_true(admin_src.contains("give_item"))
	assert_false(admin_src.contains("admin_bed"))
	assert_false(admin_src.contains("Admin Bed"))
	var items := _items()
	assert_eq(items.get_item(163).id, 163)
	var entity_src := FileAccess.get_file_as_string("res://scripts/building_parts/building_entity.gd")
	assert_true(entity_src.contains("is_bed"))
	assert_true(entity_src.contains("wood_bed.png"))
	assert_true(entity_src.contains("[E] Bett benutzen"))
	var parts_src := FileAccess.get_file_as_string("res://scripts/building_parts/building_part_system.gd")
	assert_true(parts_src.contains("on_bed_removed"))
	assert_true(parts_src.contains("BuildingPartType.BED"))
