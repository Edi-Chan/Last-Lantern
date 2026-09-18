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
