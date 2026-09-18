@tool
extends McpTestSuite


func suite_name() -> String:
	return "stairs"


func _blocks() -> BlockCatalog:
	return load("res://resources/blocks/block_catalog.tres") as BlockCatalog


func _items() -> ItemCatalog:
	return load("res://resources/items/item_catalog.tres") as ItemCatalog


func test_existing_stair_items_reused() -> void:
	var blocks := _blocks()
	var items := _items()
	var wood := blocks.get_by_id(42)
	var stone := blocks.get_by_id(43)
	assert_ne(wood, null)
	assert_ne(stone, null)
	assert_eq(wood.display_name, "Holztreppe")
	assert_eq(stone.display_name, "Steintreppe")
	assert_eq(int(wood.building_part_type), int(BlockData.BuildingPartType.STAIRS))
	assert_eq(int(stone.building_part_type), int(BlockData.BuildingPartType.STAIRS))
	assert_eq(wood.drop_item_id, 73)
	assert_eq(stone.drop_item_id, 74)
	assert_eq(items.get_item(73).placeable_block_id, 42)
	assert_eq(items.get_item(74).placeable_block_id, 43)
	assert_eq(int(wood.get_required_tool()), int(ItemData.ToolKind.AXE))
	assert_eq(int(stone.get_required_tool()), int(ItemData.ToolKind.PICKAXE))
	assert_true(wood.flammable)
	assert_false(stone.flammable)
	assert_true(stone.support_strength > wood.support_strength)


func test_no_extra_stair_inventory_items() -> void:
	var items := _items()
	var stair_items := 0
	for item in items.items:
		if item != null and item.building_part_type == BlockData.BuildingPartType.STAIRS:
			stair_items += 1
			assert_true(item.id == 73 or item.id == 74, "unexpected stair item %d" % item.id)
	assert_eq(stair_items, 2)


func test_orientation_from_diagonal_neighbors() -> void:
	var occupied := {
		Vector2i(1, 1): true,
	}
	var getter := func(cell: Vector2i) -> BlockData:
		if occupied.has(cell):
			return _blocks().get_by_id(42)
		return null
	var ori := StairSystem.resolve_orientation(Vector2i(2, 0), getter, StairSystem.Orientation.UP_LEFT)
	assert_eq(ori, StairSystem.Orientation.UP_RIGHT)
	ori = StairSystem.resolve_orientation(Vector2i(0, 0), getter, StairSystem.Orientation.UP_RIGHT)
	assert_eq(ori, StairSystem.Orientation.UP_LEFT)


func test_visual_inner_start_end() -> void:
	var chain := {Vector2i(0, 2): true, Vector2i(1, 1): true, Vector2i(2, 0): true}
	var getter := func(cell: Vector2i) -> BlockData:
		return _blocks().get_by_id(42) if chain.has(cell) else null
	assert_eq(StairSystem.resolve_visual(Vector2i(1, 1), StairSystem.Orientation.UP_RIGHT, getter), StairSystem.Visual.INNER)
	assert_eq(StairSystem.resolve_visual(Vector2i(0, 2), StairSystem.Orientation.UP_RIGHT, getter), StairSystem.Visual.START)
	assert_eq(StairSystem.resolve_visual(Vector2i(2, 0), StairSystem.Orientation.UP_RIGHT, getter), StairSystem.Visual.END)


func test_diagonal_line_45_degrees() -> void:
	var cells := StairSystem.diagonal_line(Vector2i(0, 4), Vector2i(4, 0))
	assert_eq(cells.size(), 5)
	assert_eq(cells[0], Vector2i(0, 4))
	assert_eq(cells[1], Vector2i(1, 3))
	assert_eq(cells[2], Vector2i(2, 2))
	assert_eq(cells[4], Vector2i(4, 0))
	var left := StairSystem.diagonal_line(Vector2i(4, 4), Vector2i(0, 0))
	assert_eq(left[1], Vector2i(3, 3))
	assert_eq(StairSystem.hint_from_drag(Vector2i(0, 4), Vector2i(4, 0)), StairSystem.Orientation.UP_RIGHT)
	assert_eq(StairSystem.hint_from_drag(Vector2i(4, 4), Vector2i(0, 0)), StairSystem.Orientation.UP_LEFT)


func test_atlas_variants_are_not_new_blocks() -> void:
	var wood := _blocks().get_by_id(42)
	var coords := StairSystem.all_atlas_coords(wood)
	assert_true(coords.has(Vector2i(1, 10)))
	assert_true(coords.has(Vector2i(2, 10)))
	assert_true(coords.has(Vector2i(0, 12)))
	assert_true(coords.has(Vector2i(7, 12)))
	assert_eq(StairSystem.atlas_for(wood, StairSystem.Orientation.UP_RIGHT, StairSystem.Visual.INNER), Vector2i(1, 12))
	assert_eq(StairSystem.atlas_for(wood, StairSystem.Orientation.UP_LEFT, StairSystem.Visual.INNER), Vector2i(7, 12))
	var stone := _blocks().get_by_id(43)
	assert_eq(StairSystem.atlas_for(stone, StairSystem.Orientation.UP_RIGHT, StairSystem.Visual.INNER).y, 13)
	assert_eq(StairSystem.orientation_from_atlas(Vector2i(1, 10)), StairSystem.Orientation.UP_LEFT)
	assert_eq(StairSystem.orientation_from_atlas(Vector2i(2, 10)), StairSystem.Orientation.UP_RIGHT)


func test_collision_is_diagonal_not_full_block() -> void:
	var ur := StairSystem.collision_points(StairSystem.Orientation.UP_RIGHT)
	var ul := StairSystem.collision_points(StairSystem.Orientation.UP_LEFT)
	assert_eq(ur.size(), 4)
	assert_eq(ul.size(), 4)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	assert_false(ur == full)
	assert_true(ur[0] == Vector2(-8, 8) or ur[1] == Vector2(-8, 8))


func test_shared_logic_not_duplicated_per_material() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/building_parts/stair_system.gd")
	assert_true(src.contains("class_name StairSystem"))
	assert_false(FileAccess.file_exists("res://scripts/building_parts/wood_stairs_system.gd"))
	assert_false(FileAccess.file_exists("res://scripts/building_parts/stone_stairs_system.gd"))
	var parts := FileAccess.get_file_as_string("res://scripts/building_parts/building_part_system.gd")
	assert_true(parts.contains("StairSystem.resolve_orientation"))
	assert_true(parts.contains("_refresh_nearby_stairs"))
	assert_false(parts.contains("update_all_stairs_in_world"))


func test_catalog_lookup_covers_variants() -> void:
	var catalog := _blocks()
	catalog.notify_changed()
	assert_eq(catalog.get_by_source_atlas(1, Vector2i(1, 10)).id, 42)
	assert_eq(catalog.get_by_source_atlas(1, Vector2i(2, 10)).id, 42)
	assert_eq(catalog.get_by_source_atlas(1, Vector2i(1, 12)).id, 42)
	assert_eq(catalog.get_by_source_atlas(1, Vector2i(3, 10)).id, 43)
	assert_eq(catalog.get_by_source_atlas(1, Vector2i(1, 13)).id, 43)
