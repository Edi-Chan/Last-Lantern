@tool
extends McpTestSuite


func suite_name() -> String:
	return "building_parts"


func _blocks() -> BlockCatalog:
	return load("res://resources/blocks/block_catalog.tres") as BlockCatalog


func _items() -> ItemCatalog:
	return load("res://resources/items/item_catalog.tres") as ItemCatalog


func test_enums_exist() -> void:
	assert_eq(int(BlockData.BuildingMaterial.WOOD), 1)
	assert_eq(int(BlockData.BuildingMaterial.STONE), 2)
	assert_eq(int(BlockData.BuildingMaterial.BRICK), 3)
	assert_eq(int(BlockData.BuildingMaterial.METAL), 4)
	assert_eq(int(BlockData.BuildingPartType.FOUNDATION), 1)
	assert_eq(int(BlockData.BuildingPartType.WALL), 2)
	assert_eq(int(BlockData.BuildingPartType.BACKGROUND_WALL), 3)
	assert_eq(int(BlockData.BuildingPartType.FLOOR), 4)
	assert_eq(int(BlockData.BuildingPartType.ROOF), 5)
	assert_eq(int(BlockData.BuildingPartType.SUPPORT), 6)
	assert_eq(int(BlockData.BuildingPartType.BEAM), 7)
	assert_eq(int(BlockData.BuildingPartType.PLATFORM), 8)
	assert_eq(int(BlockData.BuildingPartType.STAIRS), 9)
	assert_eq(int(BlockData.BuildingPartType.LADDER), 10)
	assert_eq(int(BlockData.BuildingPartType.DOOR), 11)
	assert_eq(int(BlockData.BuildingPartType.WINDOW), 12)
	assert_eq(int(BlockData.BuildingPartType.LIGHT), 13)
	assert_eq(int(BlockData.BuildingPartType.STORAGE), 14)
	assert_eq(int(BlockData.BuildingPartType.CRAFTING_STATION), 15)
	assert_eq(int(BlockData.BuildingPartType.DEFENSE), 16)
	assert_eq(int(BlockData.BuildingPartType.DECORATION), 17)
	assert_eq(int(BlockData.BuildingPartType.BED), 18)
	assert_eq(int(BlockData.StructuralRole.BEAM), 4)
	assert_eq(int(BlockData.StructuralRole.ROOF), 5)


func test_no_duplicate_ids() -> void:
	var catalog := _blocks()
	var seen: Dictionary = {}
	for block in catalog.blocks:
		assert_ne(block, null)
		assert_false(seen.has(block.id), "duplicate block id %d" % block.id)
		seen[block.id] = true
	var items := _items()
	var seen_items: Dictionary = {}
	for item in items.items:
		assert_ne(item, null)
		assert_false(seen_items.has(item.id), "duplicate item id %d" % item.id)
		seen_items[item.id] = true
	assert_false(seen.has(0))
	assert_true(seen.has(29))
	assert_true(seen.has(31))
	assert_true(seen.has(63))
	assert_true(seen_items.has(60))
	assert_true(seen_items.has(62))
	assert_true(seen_items.has(94))


func test_existing_ids_untouched() -> void:
	var catalog := _blocks()
	assert_eq(catalog.get_by_id(7).display_name, "Wood")
	assert_eq(catalog.get_by_id(3).display_name, "Stone")
	assert_eq(catalog.get_by_id(29).display_name, "Holzstütze")
	assert_eq(catalog.get_by_id(30).id, 30)
	var items := _items()
	assert_eq(items.get_item(9).placeable_block_id, 7)
	assert_eq(items.get_item(30).id, 30)
	assert_eq(items.get_item(31).id, 31)
	assert_eq(items.get_item(60).placeable_block_id, 29)
	assert_eq(WorldGenerator.HIGHEST_BLOCK_ID, 28)


func test_foundations_and_walls() -> void:
	var catalog := _blocks()
	var wood_f := catalog.get_by_id(31)
	var stone_f := catalog.get_by_id(32)
	var wood_w := catalog.get_by_id(33)
	var stone_w := catalog.get_by_id(34)
	assert_eq(int(wood_f.building_part_type), int(BlockData.BuildingPartType.FOUNDATION))
	assert_eq(int(stone_f.building_part_type), int(BlockData.BuildingPartType.FOUNDATION))
	assert_eq(int(wood_w.building_part_type), int(BlockData.BuildingPartType.WALL))
	assert_eq(int(stone_w.building_part_type), int(BlockData.BuildingPartType.WALL))
	assert_true(wood_f.solid and wood_f.structural_enabled and wood_f.flammable)
	assert_true(stone_f.solid and stone_f.structural_enabled and not stone_f.flammable)
	assert_eq(wood_f.get_required_tool(), int(ItemData.ToolKind.AXE))
	assert_eq(stone_f.get_required_tool(), int(ItemData.ToolKind.PICKAXE))
	assert_eq(wood_w.get_required_tool(), int(ItemData.ToolKind.AXE))
	assert_eq(stone_w.get_required_tool(), int(ItemData.ToolKind.PICKAXE))
	assert_true(wood_f.autotile_count > 1)
	assert_true(wood_w.autotile_count > 1)


func test_background_not_structural() -> void:
	var catalog := _blocks()
	var wood_bg := catalog.get_by_id(35)
	var stone_bg := catalog.get_by_id(36)
	assert_eq(int(wood_bg.building_part_type), int(BlockData.BuildingPartType.BACKGROUND_WALL))
	assert_eq(int(stone_bg.building_part_type), int(BlockData.BuildingPartType.BACKGROUND_WALL))
	assert_false(wood_bg.solid)
	assert_false(stone_bg.solid)
	assert_false(wood_bg.structural_enabled)
	assert_false(stone_bg.structural_enabled)
	assert_eq(wood_bg.structural_weight, 0)
	assert_true(wood_bg.occupies_background_layer())
	assert_true(stone_bg.occupies_background_layer())
	assert_true(catalog.get_by_id(47).occupies_background_layer())
	assert_true(catalog.get_by_id(48).occupies_background_layer())
	var parts_src := FileAccess.get_file_as_string("res://scripts/building_parts/building_part_system.gd")
	assert_true(parts_src.contains("if block.occupies_background_layer():"))
	assert_true(parts_src.contains("if _bg.get_cell_source_id(origin) != -1:"))


func test_floors_roofs_supports() -> void:
	var catalog := _blocks()
	var wood_floor := catalog.get_by_id(37)
	var stone_floor := catalog.get_by_id(38)
	var wood_roof := catalog.get_by_id(39)
	var straw := catalog.get_by_id(40)
	var beam := catalog.get_by_id(41)
	var support := catalog.get_by_id(29)
	assert_eq(int(wood_floor.building_part_type), int(BlockData.BuildingPartType.FLOOR))
	assert_eq(int(stone_floor.building_part_type), int(BlockData.BuildingPartType.FLOOR))
	assert_eq(int(wood_roof.building_part_type), int(BlockData.BuildingPartType.ROOF))
	assert_eq(int(straw.building_part_type), int(BlockData.BuildingPartType.ROOF))
	assert_eq(int(beam.building_part_type), int(BlockData.BuildingPartType.BEAM))
	assert_eq(int(support.building_part_type), int(BlockData.BuildingPartType.SUPPORT))
	assert_true(wood_roof.structural_enabled)
	assert_true(straw.structural_enabled and straw.flammable)
	assert_true(straw.support_strength < wood_roof.support_strength)
	assert_eq(straw.material_variant, &"straw")
	assert_true(beam.structural_enabled)
	assert_false(beam.solid)
	assert_true(beam.max_horizontal_support > 0)
	assert_false(support.solid)
	assert_true(support.is_support_beam)


func test_movement_parts() -> void:
	var catalog := _blocks()
	var wood_stairs := catalog.get_by_id(42)
	var stone_stairs := catalog.get_by_id(43)
	var ladder := catalog.get_by_id(44)
	var wood_plat := catalog.get_by_id(45)
	var stone_plat := catalog.get_by_id(46)
	assert_true(wood_stairs.uses_orientation)
	assert_true(stone_stairs.uses_orientation)
	assert_true(wood_stairs.is_stair())
	assert_true(stone_stairs.is_stair())
	assert_eq(stone_stairs.get_required_tool(), int(ItemData.ToolKind.PICKAXE))
	assert_true(ladder.is_climbable)
	assert_false(ladder.solid)
	assert_true(wood_plat.is_one_way)
	assert_true(stone_plat.is_one_way)
	assert_true(stone_plat.structural_weight > wood_plat.structural_weight)


func test_doors_windows_furniture_stations() -> void:
	var catalog := _blocks()
	var door := catalog.get_by_id(56)
	var heavy := catalog.get_by_id(57)
	var gate := catalog.get_by_id(58)
	var window := catalog.get_by_id(47)
	var glass := catalog.get_by_id(48)
	var chest := catalog.get_by_id(59)
	var bench := catalog.get_by_id(60)
	var anvil := catalog.get_by_id(61)
	var furnace := catalog.get_by_id(62)
	var torch := catalog.get_by_id(63)
	var barricade := catalog.get_by_id(49)
	assert_eq(int(door.building_part_type), int(BlockData.BuildingPartType.DOOR))
	assert_eq(door.footprint, Vector2i(1, 3))
	assert_eq(heavy.footprint, Vector2i(1, 3))
	assert_true(heavy.enemy_break_cost > door.enemy_break_cost)
	assert_eq(gate.footprint, Vector2i(2, 3))
	assert_eq(int(window.building_part_type), int(BlockData.BuildingPartType.WINDOW))
	assert_eq(int(glass.building_part_type), int(BlockData.BuildingPartType.WINDOW))
	assert_true(window.enemy_break_cost > 0)
	assert_false(window.structural_enabled)
	assert_eq(int(chest.building_part_type), int(BlockData.BuildingPartType.STORAGE))
	assert_eq(int(bench.building_part_type), int(BlockData.BuildingPartType.CRAFTING_STATION))
	assert_eq(bench.footprint, Vector2i(2, 1))
	assert_eq(int(anvil.building_part_type), int(BlockData.BuildingPartType.CRAFTING_STATION))
	assert_eq(int(furnace.building_part_type), int(BlockData.BuildingPartType.CRAFTING_STATION))
	assert_eq(int(torch.building_part_type), int(BlockData.BuildingPartType.LIGHT))
	assert_true(torch.light_energy > 0.0)
	assert_false(torch.structural_enabled)
	assert_true(barricade.solid)
	assert_false(barricade.structural_enabled)
	assert_eq(catalog.get_by_id(52).building_part_type, BlockData.BuildingPartType.DECORATION)
	assert_false(catalog.get_by_id(52).structural_enabled)
	var bed := catalog.get_by_id(64)
	assert_ne(bed, null)
	assert_eq(int(bed.building_part_type), int(BlockData.BuildingPartType.BED))
	assert_eq(bed.footprint, Vector2i(4, 2))
	assert_eq(bed.drop_item_id, 163)
	assert_false(bed.solid)


func test_items_link_and_categories() -> void:
	var items := _items()
	var catalog := _blocks()
	var expected := {
		62: 31, 63: 32, 64: 33, 65: 34, 66: 35, 67: 36, 68: 37, 69: 38,
		70: 39, 71: 40, 72: 41, 73: 42, 74: 43, 75: 44, 76: 45, 77: 46,
		78: 56, 79: 57, 80: 47, 81: 48, 82: 63, 83: 59, 84: 50, 85: 51,
		86: 52, 87: 53, 88: 54, 89: 55, 90: 60, 91: 61, 92: 62, 93: 49, 94: 58,
		163: 64,
	}
	for item_id in expected.keys():
		var item := items.get_item(int(item_id))
		assert_ne(item, null, "missing item %d" % int(item_id))
		assert_ne(item.icon, null, "missing icon %d" % int(item_id))
		assert_eq(item.placeable_block_id, int(expected[item_id]))
		var block := catalog.get_by_id(item.placeable_block_id)
		assert_ne(block, null)
		assert_eq(block.drop_item_id, item.id)
		assert_eq(int(item.building_part_type), int(block.building_part_type))
		if item.building_part_type == BlockData.BuildingPartType.CRAFTING_STATION:
			assert_eq(int(item.category), int(ItemData.ItemCategory.MACHINE_TECH))
		elif item.building_part_type == BlockData.BuildingPartType.DEFENSE:
			assert_eq(int(item.category), int(ItemData.ItemCategory.TRAP_DEFENSE))
		else:
			assert_eq(int(item.category), int(ItemData.ItemCategory.BUILDING_MATERIAL))


func test_tools_match_material() -> void:
	var axe := load("res://resources/items/tools/woodcutting/stone_axe.tres") as ItemData
	var pick := load("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres") as ItemData
	var catalog := _blocks()
	assert_eq(int(catalog.get_by_id(31).evaluate_break(axe)), int(BlockData.BreakCheck.CAN_BREAK))
	assert_eq(int(catalog.get_by_id(31).evaluate_break(pick)), int(BlockData.BreakCheck.WRONG_TOOL))
	assert_eq(int(catalog.get_by_id(32).evaluate_break(pick)), int(BlockData.BreakCheck.CAN_BREAK))
	assert_eq(int(catalog.get_by_id(32).evaluate_break(axe)), int(BlockData.BreakCheck.WRONG_TOOL))
	assert_eq(int(catalog.get_by_id(41).evaluate_break(axe)), int(BlockData.BreakCheck.CAN_BREAK))
	assert_eq(int(catalog.get_by_id(56).evaluate_break(axe)), int(BlockData.BreakCheck.CAN_BREAK))
	assert_eq(int(catalog.get_by_id(38).evaluate_break(pick)), int(BlockData.BreakCheck.CAN_BREAK))


func test_reused_not_duplicated() -> void:
	var items := _items()
	var torch_count := 0
	var lantern_count := 0
	var support_count := 0
	for item in items.items:
		if item.display_name == "Fackel":
			torch_count += 1
		if item.display_name == "Laterne":
			lantern_count += 1
		if item.display_name == "Holzstütze":
			support_count += 1
	assert_eq(torch_count, 1)
	assert_eq(lantern_count, 1)
	assert_eq(support_count, 1)


func test_dev_loadout_once() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/inventory/inventory.gd")
	assert_true(src.contains("DEV_BUILDING_TEST_LOADOUT"))
	assert_true(src.contains("DEV_BUILDING_SENTINEL_ID := 62"))
	assert_true(src.contains("_give_dev_building_test_loadout_once"))
	assert_true(src.contains("dev_building_loadout_given"))
	assert_true(src.contains("_ensure_total_at_least"))
	assert_eq(Inventory.SLOT_COUNT, 70)


func test_world_and_save_wiring() -> void:
	var world := FileAccess.get_file_as_string("res://scenes/world/world.tscn")
	assert_true(world.contains("BackgroundTiles"))
	assert_true(world.contains("building_background"))
	assert_true(world.contains("BuildingPartSystem"))
	assert_true(world.contains("building_part_system"))
	var save := FileAccess.get_file_as_string("res://scripts/save/save_manager.gd")
	assert_true(save.contains("building_parts"))
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_true(project.contains("rotate_place"))
	assert_true(project.contains("move_down"))
	assert_true(project.contains("layer_6=\"Platforms\""))
	assert_true(ResourceLoader.exists("res://assets/building/building_atlas.png"))
	assert_true(ResourceLoader.exists("res://assets/building/doors/wood_door.png"))
	assert_true(ResourceLoader.exists("res://assets/building/stations/furnace.png"))


func test_roof_autotile_not_extra_items() -> void:
	var items := _items()
	var roof_items := 0
	for item in items.items:
		if item.building_part_type == BlockData.BuildingPartType.ROOF:
			roof_items += 1
	assert_eq(roof_items, 2)
	var wood_roof := _blocks().get_by_id(39)
	assert_eq(wood_roof.autotile_count, 7)
