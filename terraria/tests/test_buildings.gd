@tool
extends McpTestSuite


func suite_name() -> String:
	return "buildings"


func test_forge_item_id_is_free() -> void:
	var item := FileAccess.get_file_as_string("res://resources/items/forge_blueprint.tres")
	var catalog := FileAccess.get_file_as_string("res://resources/items/item_catalog.tres")
	assert_true(item.contains("id = 61"))
	assert_true(item.contains("Schmiede-Bauplan"))
	assert_true(item.contains("item_type = 8"))
	assert_true(item.contains("category = 17"))
	assert_true(item.contains("placeable_block_id = -1"))
	assert_true(catalog.contains("forge_blueprint.tres"))


func test_forge_core_block_id_is_free() -> void:
	var block := FileAccess.get_file_as_string("res://resources/blocks/forge_core.tres")
	var catalog := FileAccess.get_file_as_string("res://resources/blocks/block_catalog.tres")
	assert_true(block.contains("id = 30"))
	assert_true(block.contains("Schmiedekern"))
	assert_true(block.contains("atlas_coords = Vector2i(5, 3)"))
	assert_true(block.contains("structural_enabled = true"))
	assert_true(catalog.contains("forge_core.tres"))


func test_world_highest_block_unchanged() -> void:
	assert_eq(WorldGenerator.HIGHEST_BLOCK_ID, 28)


func test_blueprint_costs_use_existing_items() -> void:
	var bp := load("res://resources/buildings/forge_blueprint.tres") as BuildingBlueprintResource
	assert_true(bp != null)
	assert_eq(int(bp.item_id), 61)
	assert_eq(int(bp.required_item_ids[0]), 2)
	assert_eq(int(bp.required_amounts[0]), 140)
	assert_eq(int(bp.required_item_ids[1]), 9)
	assert_eq(int(bp.required_amounts[1]), 200)
	assert_eq(int(bp.required_item_ids[2]), 60)
	assert_eq(int(bp.required_amounts[2]), 16)
	var layout: Array = bp.get_layout()
	assert_true(layout.size() > 80)
	var has_core := false
	var beams := 0
	var foundation := 0
	var bg := 0
	var roof := 0
	for spec in layout:
		if int(spec["role"]) == BuildingBlueprintResource.ComponentRole.CORE:
			has_core = true
			assert_eq(int(spec["block_id"]), 62)
		if int(spec["role"]) == BuildingBlueprintResource.ComponentRole.SUPPORT:
			beams += 1
		if int(spec["role"]) == BuildingBlueprintResource.ComponentRole.FOUNDATION:
			foundation += 1
			assert_eq(int(spec["block_id"]), 32)
		if int(spec["block_id"]) == 36 or int(spec["block_id"]) == 35:
			bg += 1
		if int(spec["role"]) == BuildingBlueprintResource.ComponentRole.ROOF:
			roof += 1
	assert_true(has_core)
	assert_true(beams >= 10)
	assert_true(foundation >= 15)
	assert_true(bg >= 20)
	assert_true(roof >= 20)


func test_scenes_exist() -> void:
	assert_true(ResourceLoader.exists("res://scenes/buildings/forge_exterior.tscn"))
	assert_true(ResourceLoader.exists("res://scenes/buildings/forge_interior.tscn"))
	assert_true(ResourceLoader.exists("res://assets/items/buildings/forge_blueprint.png"))
	assert_true(ResourceLoader.exists("res://assets/buildings/forge_door.png"))
	assert_true(ResourceLoader.exists("res://assets/world/tiles/forge_core.png"))


func test_item_data_blueprint_api() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/items/item_data.gd")
	assert_true(src.contains("BLUEPRINT"))
	assert_true(src.contains("func is_building_blueprint"))
	var item := load("res://resources/items/forge_blueprint.tres") as ItemData
	assert_true(item != null)
	assert_true(item.is_building_blueprint())
	assert_false(item.is_placeable())


func test_dev_loadout_forge_once() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/inventory/inventory.gd")
	assert_true(src.contains("DEV_FORGE_BLUEPRINT_ID := 61"))
	assert_true(src.contains("_give_dev_forge_blueprint_once"))
	assert_true(src.contains("DEV_WOOD_AMOUNT := 200"))
	assert_true(src.contains("DEV_STONE_AMOUNT := 140"))


func test_building_manager_event_based() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/buildings/building_manager.gd")
	assert_true(src.contains("structure_changed.connect"))
	assert_true(src.contains("structure_collapsed.connect"))
	assert_true(src.contains("fog_event"))
	assert_true(src.contains("AREA_FORGE_INTERIOR"))
	assert_true(src.contains("COLLAPSE_DESTROYED"))
	assert_true(src.contains("PLAYER_REMOVED"))
	assert_false(src.contains("_process("))
	assert_false(src.contains("world.get_surface_y"))
	assert_true(src.contains("func _has_flat_support"))
	assert_true(src.contains("func _is_support_ground"))
	assert_true(src.contains("func _is_obstruction"))
	assert_true(src.contains("func _placement_hint"))


func test_fog_blocks_interior_damage() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/systems/fog/fog_event.gd")
	assert_true(src.contains("is_player_inside"))


func test_forge_backdrop_and_door() -> void:
	var tres := FileAccess.get_file_as_string("res://resources/buildings/forge_blueprint.tres")
	assert_true(tres.contains("visual_background_only = true"))
	assert_true(tres.contains("indestructible = true"))
	var src := FileAccess.get_file_as_string("res://scripts/buildings/building_manager.gd")
	assert_true(src.contains("func is_protected_cell"))
	assert_true(src.contains("stamp_backdrop"))
	assert_true(src.contains("stamp_solid"))
	assert_true(src.contains("_role_is_solid_shell"))
	assert_true(src.contains("_stamp_interior_background"))
	assert_true(src.contains("try_enter"))
	var bp_src := FileAccess.get_file_as_string("res://scripts/buildings/building_blueprint_resource.gd")
	assert_true(bp_src.contains("visual_background_only"))
	assert_true(bp_src.contains("indestructible"))


func test_interact_uses_inputmap() -> void:
	var door := FileAccess.get_file_as_string("res://scripts/buildings/building_door.gd")
	assert_true(door.contains("is_action_just_pressed(\"interact\")"))
	assert_false(door.contains("KEY_E"))


func test_building_type_keeps_merchant_and_adds_shops() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/buildings/building_blueprint_resource.gd")
	assert_true(src.contains("MERCHANT"))
	assert_true(src.contains("CARPENTER"))
	assert_true(src.contains("HUNTER"))
	assert_true(src.contains("LANTERN_MAKER"))
	assert_true(src.contains("GARDENER"))
	assert_true(src.contains("MECHANIC"))
	assert_eq(int(BuildingBlueprintResource.BuildingType.MERCHANT), 2)
	assert_eq(int(BuildingBlueprintResource.BuildingType.CARPENTER), 8)
	assert_eq(int(BuildingBlueprintResource.BuildingType.HUNTER), 9)
	assert_eq(int(BuildingBlueprintResource.BuildingType.LANTERN_MAKER), 10)
	assert_eq(int(BuildingBlueprintResource.BuildingType.GARDENER), 11)
	assert_eq(int(BuildingBlueprintResource.BuildingType.MECHANIC), 12)


func test_settlement_shop_blueprints_exist() -> void:
	var catalog := FileAccess.get_file_as_string("res://resources/items/item_catalog.tres")
	var shops := {
		"carpenter": {"item": 95, "name": "Schreinerei-Bauplan", "id": "carpenter_shop"},
		"hunter": {"item": 96, "name": "Jägerhütten-Bauplan", "id": "hunter_shop"},
		"lantern_maker": {"item": 97, "name": "Laternenmacher-Bauplan", "id": "lantern_maker_shop"},
		"gardener": {"item": 98, "name": "Gärtner-Bauplan", "id": "gardener_shop"},
		"mechanic": {"item": 99, "name": "Mechaniker-Bauplan", "id": "mechanic_shop"},
		"merchant": {"item": 116, "name": "Händler-Bauplan", "id": "merchant_shop"},
	}
	for key in shops.keys():
		var spec: Dictionary = shops[key]
		var item_path := "res://resources/items/%s_blueprint.tres" % key
		var bp_path := "res://resources/buildings/%s_blueprint.tres" % key
		var item_txt := FileAccess.get_file_as_string(item_path)
		var bp_txt := FileAccess.get_file_as_string(bp_path)
		assert_true(item_txt.contains("id = %d" % int(spec["item"])))
		assert_true(item_txt.contains(str(spec["name"])))
		assert_true(item_txt.contains("item_type = 8"))
		assert_true(item_txt.contains("category = 17"))
		assert_true(item_txt.contains("placeable_block_id = -1"))
		assert_true(bp_txt.contains("building_id = &\"%s\"" % str(spec["id"])))
		assert_true(bp_txt.contains("indestructible = false"))
		assert_true(catalog.contains("%s_blueprint.tres" % key))
		assert_true(ResourceLoader.exists("res://scenes/buildings/%s_exterior.tscn" % key))
		assert_true(ResourceLoader.exists("res://scenes/buildings/%s_interior.tscn" % key))
		assert_true(ResourceLoader.exists("res://assets/items/buildings/%s_blueprint.png" % key))


func test_settlement_shop_layouts_are_compact_and_distinct() -> void:
	var paths := [
		"res://resources/buildings/carpenter_blueprint.tres",
		"res://resources/buildings/hunter_blueprint.tres",
		"res://resources/buildings/lantern_maker_blueprint.tres",
		"res://resources/buildings/gardener_blueprint.tres",
		"res://resources/buildings/mechanic_blueprint.tres",
		"res://resources/buildings/merchant_blueprint.tres",
	]
	var widths: Dictionary = {}
	var roofs: Dictionary = {}
	for path in paths:
		var bp := load(path) as BuildingBlueprintResource
		assert_true(bp != null)
		assert_true(bp.total_width() >= 10)
		assert_true(bp.total_width() <= 16)
		assert_true(bp.wall_height >= 5)
		assert_true(bp.wall_height <= 6)
		var layout: Array = bp.get_layout()
		var foundation := 0
		var support := 0
		var roof := 0
		var entrance := 0
		var core := 0
		var wall := 0
		var light := 0
		for spec in layout:
			var role := int(spec["role"])
			var block_id := int(spec["block_id"])
			match role:
				BuildingBlueprintResource.ComponentRole.FOUNDATION:
					foundation += 1
				BuildingBlueprintResource.ComponentRole.SUPPORT:
					support += 1
				BuildingBlueprintResource.ComponentRole.ROOF:
					roof += 1
				BuildingBlueprintResource.ComponentRole.ENTRANCE:
					entrance += 1
				BuildingBlueprintResource.ComponentRole.CORE:
					core += 1
				BuildingBlueprintResource.ComponentRole.WALL:
					wall += 1
			if block_id == 63:
				light += 1
		assert_true(foundation >= 10)
		assert_true(support >= 8)
		assert_true(roof >= 8)
		assert_true(entrance >= 4)
		assert_true(core >= 1)
		assert_true(wall >= 8)
		assert_true(light >= 1)
		assert_true(bp.shop_type() != BuildingBlueprintResource.BuildingType.NONE)
		widths[path] = bp.total_width()
		roofs[path] = bp.roof_block_id
	assert_true(int(widths["res://resources/buildings/carpenter_blueprint.tres"]) != int(widths["res://resources/buildings/hunter_blueprint.tres"]) or int(roofs["res://resources/buildings/carpenter_blueprint.tres"]) != int(roofs["res://resources/buildings/hunter_blueprint.tres"]))
	assert_eq(int((load("res://resources/buildings/hunter_blueprint.tres") as BuildingBlueprintResource).roof_block_id), 40)
	assert_eq(int((load("res://resources/buildings/gardener_blueprint.tres") as BuildingBlueprintResource).roof_block_id), 40)
	assert_eq(int((load("res://resources/buildings/carpenter_blueprint.tres") as BuildingBlueprintResource).roof_block_id), 39)


func test_shop_supports_keep_background_walls() -> void:
	var paths := [
		"res://resources/buildings/carpenter_blueprint.tres",
		"res://resources/buildings/hunter_blueprint.tres",
		"res://resources/buildings/lantern_maker_blueprint.tres",
		"res://resources/buildings/gardener_blueprint.tres",
		"res://resources/buildings/mechanic_blueprint.tres",
		"res://resources/buildings/merchant_blueprint.tres",
	]
	for path in paths:
		var bp := load(path) as BuildingBlueprintResource
		var layout: Array = bp.get_layout()
		var supports := 0
		var with_bg := 0
		for spec in layout:
			if int(spec["role"]) != BuildingBlueprintResource.ComponentRole.SUPPORT:
				continue
			supports += 1
			var bg_id := int(spec.get("bg_id", -1))
			assert_true(bg_id == 35 or bg_id == 36)
			with_bg += 1
		assert_true(supports >= 8)
		assert_eq(with_bg, supports)
	var src := FileAccess.get_file_as_string("res://scripts/buildings/building_manager.gd")
	assert_true(src.contains("func _stamp_shop_interior_background"))
	assert_true(src.contains("stamp_backdrop(behind, cell)"))
	assert_true(src.contains("parts.get_block_at"))


func test_settlement_shop_costs_use_existing_items() -> void:
	var expected := {
		"res://resources/buildings/carpenter_blueprint.tres": [[9, 80], [15, 24], [60, 8]],
		"res://resources/buildings/hunter_blueprint.tres": [[9, 50], [2, 24], [17, 16], [60, 6]],
		"res://resources/buildings/lantern_maker_blueprint.tres": [[9, 55], [2, 32], [11, 12], [60, 8]],
		"res://resources/buildings/gardener_blueprint.tres": [[9, 70], [15, 16], [51, 8], [60, 6]],
		"res://resources/buildings/mechanic_blueprint.tres": [[9, 45], [2, 48], [11, 18], [60, 10]],
		"res://resources/buildings/merchant_blueprint.tres": [[9, 65], [2, 36], [15, 20], [60, 8]],
	}
	var catalog := load("res://resources/items/item_catalog.tres") as ItemCatalog
	assert_true(catalog != null)
	for path in expected.keys():
		var bp := load(path) as BuildingBlueprintResource
		var costs: Array = expected[path]
		assert_eq(bp.required_item_ids.size(), costs.size())
		for i in costs.size():
			assert_eq(int(bp.required_item_ids[i]), int(costs[i][0]))
			assert_eq(int(bp.required_amounts[i]), int(costs[i][1]))
			assert_true(catalog.get_item(int(costs[i][0])) != null)


func test_manager_resolves_blueprint_per_instance() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/buildings/building_manager.gd")
	assert_true(src.contains("func _blueprint_for"))
	assert_true(src.contains("registered_blueprints"))
	assert_true(src.contains("AREA_FORGE_INTERIOR"))
	assert_true(src.contains("fog_event"))
	assert_false(src.contains("SHOP MENU"))
	assert_false(src.contains("shop_menu"))
	var interior := FileAccess.get_file_as_string("res://scripts/buildings/shop_interior.gd")
	assert_false(interior.contains("SHOP MENU"))
	assert_true(interior.contains("Kein NPC"))


func test_dev_shop_blueprints_in_debug_loadout() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/inventory/inventory.gd")
	assert_true(src.contains("DEV_SHOP_BLUEPRINT_IDS := [95, 96, 97, 98, 99, 116]"))
	assert_true(src.contains("_give_dev_shop_blueprints_once"))
	assert_true(src.contains("[9, 500]"))
