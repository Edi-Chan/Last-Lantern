@tool
extends McpTestSuite


func suite_name() -> String:
	return "structural"


func test_wood_and_stone_structural_values() -> void:
	var wood := FileAccess.get_file_as_string("res://resources/blocks/wood.tres")
	var stone := FileAccess.get_file_as_string("res://resources/blocks/stone.tres")
	assert_true(wood.contains("id = 7"))
	assert_true(wood.contains("structural_enabled = true"))
	assert_true(wood.contains("structural_weight = 1"))
	assert_true(wood.contains("support_strength = 5"))
	assert_true(wood.contains("max_horizontal_support = 6"))
	assert_true(stone.contains("id = 3"))
	assert_true(stone.contains("structural_enabled = true"))
	assert_true(stone.contains("structural_weight = 3"))
	assert_true(stone.contains("support_strength = 12"))
	assert_true(stone.contains("max_horizontal_support = 8"))
	assert_true(wood.contains("required_tool = 2"))
	assert_true(stone.contains("required_tool = 1"))


func test_wood_support_beam_catalog() -> void:
	var block := FileAccess.get_file_as_string("res://resources/blocks/wood_support_beam.tres")
	var item := FileAccess.get_file_as_string("res://resources/items/wood_support_beam.tres")
	var blocks := FileAccess.get_file_as_string("res://resources/blocks/block_catalog.tres")
	var items := FileAccess.get_file_as_string("res://resources/items/item_catalog.tres")
	assert_true(block.contains("id = 29"))
	assert_true(item.contains("id = 60"))
	assert_true(block.contains("solid = false"))
	assert_true(block.contains("is_support_beam = true"))
	assert_true(block.contains("support_strength = 10"))
	assert_true(block.contains("max_horizontal_support = 8"))
	assert_true(block.contains("required_tool = 2"))
	assert_true(item.contains("placeable_block_id = 29"))
	assert_true(block.contains("drop_item_id = 60"))
	assert_true(blocks.contains("wood_support_beam.tres"))
	assert_true(items.contains("wood_support_beam.tres"))
	assert_true(item.contains("Holzstütze") or item.contains("Holzstu"))


func test_dirt_not_structural() -> void:
	var dirt := FileAccess.get_file_as_string("res://resources/blocks/dirt.tres")
	assert_false(dirt.contains("structural_enabled = true"))


func test_axe_breaks_beam() -> void:
	var axe := load("res://resources/items/tools/woodcutting/stone_axe.tres") as ItemData
	var pick := load("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres") as ItemData
	var beam := load("res://resources/blocks/wood_support_beam.tres") as BlockData
	assert_eq(int(beam.evaluate_break(axe)), int(BlockData.BreakCheck.CAN_BREAK))
	assert_eq(int(beam.evaluate_break(pick)), int(BlockData.BreakCheck.WRONG_TOOL))


func test_world_highest_block_unchanged() -> void:
	assert_eq(WorldGenerator.HIGHEST_BLOCK_ID, 28)


func test_dev_loadout_constants() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/inventory/inventory.gd")
	assert_true(src.contains("DEV_WOOD_AMOUNT := 100"))
	assert_true(src.contains("DEV_SUPPORT_BEAM_ID := 60"))
	assert_true(src.contains("DEV_SUPPORT_BEAM_AMOUNT := 20"))
	assert_true(src.contains("_give_dev_structural_loadout_once"))
