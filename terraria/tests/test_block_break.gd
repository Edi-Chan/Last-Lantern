@tool
extends McpTestSuite

func suite_name() -> String:
	return "block_break"


func _block(path: String) -> BlockData:
	return load(path) as BlockData


func _item(path: String) -> ItemData:
	return load(path) as ItemData


func _ore_block(block_path: String, ore_key: String) -> BlockData:
	var block := _block(block_path)
	var ore := load("res://resources/ores/%s_ore.tres" % ore_key) as OreData
	if block == null:
		return null
	var copy := block.duplicate() as BlockData
	if copy != null and ore != null:
		copy.ore_data = ore
		return copy
	return block


func _check(block: BlockData, item: ItemData, expected: BlockData.BreakCheck) -> void:
	assert_ne(block, null, block.resource_path if block != null else "block")
	var result := block.evaluate_break(item)
	assert_eq(int(result), int(expected), "%s + %s" % [block.display_name, item.display_name if item != null else "leer"])


func test_tool_kind_enum() -> void:
	assert_eq(int(ItemData.ToolKind.NONE), 0)
	assert_eq(int(ItemData.ToolKind.PICKAXE), 1)
	assert_eq(int(ItemData.ToolKind.AXE), 2)
	assert_eq(int(ItemData.ToolKind.HAMMER), 3)
	assert_eq(int(ItemData.ToolKind.WRENCH), 4)
	assert_eq(int(ItemData.ToolKind.HOE), 5)
	assert_eq(int(ItemData.ToolKind.SICKLE), 6)
	assert_eq(int(ItemData.ToolKind.FISHING_ROD), 7)
	assert_eq(int(ItemData.ToolKind.NET), 8)


func test_stone_pickaxe_gates() -> void:
	var pick := _item("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres")
	var stone := _block("res://resources/blocks/stone.tres")
	var granite := _block("res://resources/blocks/granite.tres")
	var wood := _block("res://resources/blocks/wood.tres")
	var copper := _ore_block("res://resources/blocks/ores/copper_ore_block.tres", "copper")
	var tin := _ore_block("res://resources/blocks/ores/tin_ore_block.tres", "tin")
	_check(stone, pick, BlockData.BreakCheck.CAN_BREAK)
	_check(granite, pick, BlockData.BreakCheck.CAN_BREAK)
	_check(wood, pick, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, pick, BlockData.BreakCheck.CAN_BREAK)
	_check(tin, pick, BlockData.BreakCheck.TOOL_TOO_WEAK)


func test_copper_pickaxe_ore_progression() -> void:
	var pick := _item("res://resources/items/tools/mining/pickaxes/copper_pickaxe.tres")
	var copper := _ore_block("res://resources/blocks/ores/copper_ore_block.tres", "copper")
	var tin := _ore_block("res://resources/blocks/ores/tin_ore_block.tres", "tin")
	var ferrite := _ore_block("res://resources/blocks/ores/ferrite_ore_block.tres", "ferrite")
	_check(copper, pick, BlockData.BreakCheck.CAN_BREAK)
	_check(tin, pick, BlockData.BreakCheck.CAN_BREAK)
	_check(ferrite, pick, BlockData.BreakCheck.TOOL_TOO_WEAK)


func test_stone_axe_wood_not_stone() -> void:
	var axe := _item("res://resources/items/tools/woodcutting/stone_axe.tres")
	var wood := _block("res://resources/blocks/wood.tres")
	var oak := _block("res://resources/blocks/oak_wood.tres")
	var stone := _block("res://resources/blocks/stone.tres")
	var copper := _ore_block("res://resources/blocks/ores/copper_ore_block.tres", "copper")
	_check(wood, axe, BlockData.BreakCheck.CAN_BREAK)
	_check(oak, axe, BlockData.BreakCheck.CAN_BREAK)
	_check(stone, axe, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, axe, BlockData.BreakCheck.WRONG_TOOL)
	assert_eq(int(axe.tool_kind), int(ItemData.ToolKind.AXE))


func test_wrong_tools_cannot_mine_ore_or_stone() -> void:
	var hammer := _item("res://resources/items/tools/building_repair/wood_hammer.tres")
	var wrench := _item("res://resources/items/tools/dismantling/simple_wrench.tres")
	var hoe := _item("res://resources/items/tools/farming/wood_hoe.tres")
	var rod := _item("res://resources/items/tools/gathering/wood_fishing_rod.tres")
	var net := _item("res://resources/items/tools/gathering/net.tres")
	var wood := _block("res://resources/blocks/wood.tres")
	var copper := _ore_block("res://resources/blocks/ores/copper_ore_block.tres", "copper")
	var stone := _block("res://resources/blocks/stone.tres")
	_check(wood, hammer, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, hammer, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, wrench, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, hoe, BlockData.BreakCheck.WRONG_TOOL)
	_check(stone, rod, BlockData.BreakCheck.WRONG_TOOL)
	_check(stone, net, BlockData.BreakCheck.WRONG_TOOL)
	var torch := _item("res://resources/items/tools/exploration/torch.tres")
	var sickle := _item("res://resources/items/tools/farming/sickle.tres")
	_check(stone, torch, BlockData.BreakCheck.WRONG_TOOL)
	_check(copper, sickle, BlockData.BreakCheck.WRONG_TOOL)
	assert_eq(int(hammer.tool_kind), int(ItemData.ToolKind.HAMMER))
	assert_eq(int(wrench.tool_kind), int(ItemData.ToolKind.WRENCH))
	assert_eq(int(hoe.tool_kind), int(ItemData.ToolKind.HOE))
	assert_eq(int(rod.tool_kind), int(ItemData.ToolKind.FISHING_ROD))
	assert_eq(int(net.tool_kind), int(ItemData.ToolKind.NET))


func test_empty_hand_and_bedrock() -> void:
	var copper := _ore_block("res://resources/blocks/ores/copper_ore_block.tres", "copper")
	var stone := _block("res://resources/blocks/stone.tres")
	var wood := _block("res://resources/blocks/wood.tres")
	var dirt := _block("res://resources/blocks/dirt.tres")
	var grass := _block("res://resources/blocks/grass.tres")
	var sand := _block("res://resources/blocks/sand.tres")
	var leaves := _block("res://resources/blocks/leaves.tres")
	var sapling := _block("res://resources/blocks/oak_sapling.tres")
	var bedrock := _block("res://resources/blocks/bedrock.tres")
	var astralith_pick := _item("res://resources/items/tools/mining/pickaxes/astralith_pickaxe.tres")
	_check(copper, null, BlockData.BreakCheck.WRONG_TOOL)
	_check(stone, null, BlockData.BreakCheck.WRONG_TOOL)
	_check(wood, null, BlockData.BreakCheck.WRONG_TOOL)
	_check(dirt, null, BlockData.BreakCheck.CAN_BREAK)
	_check(grass, null, BlockData.BreakCheck.CAN_BREAK)
	_check(sand, null, BlockData.BreakCheck.CAN_BREAK)
	_check(leaves, null, BlockData.BreakCheck.CAN_BREAK)
	_check(sapling, null, BlockData.BreakCheck.CAN_BREAK)
	_check(bedrock, null, BlockData.BreakCheck.UNBREAKABLE)
	_check(bedrock, astralith_pick, BlockData.BreakCheck.UNBREAKABLE)
	assert_true(bedrock.is_unbreakable)
	assert_true(bedrock.is_block_unbreakable())


func test_power_alone_never_enough() -> void:
	var axe := _item("res://resources/items/tools/woodcutting/stone_axe.tres")
	var tin := _ore_block("res://resources/blocks/ores/tin_ore_block.tres", "tin")
	assert_true(axe.get_base_tool_power() >= 12)
	assert_true(tin.get_required_tool_power() <= 15)
	_check(tin, axe, BlockData.BreakCheck.WRONG_TOOL)
	assert_eq(int(tin.get_required_tool()), int(ItemData.ToolKind.PICKAXE))
	assert_eq(int(_block("res://resources/blocks/wood.tres").get_required_tool()), int(ItemData.ToolKind.AXE))


func test_trees_require_axe() -> void:
	var oak := load("res://resources/trees/oak.tres") as TreeData
	var birch := load("res://resources/trees/birch.tres") as TreeData
	var pine := load("res://resources/trees/pine.tres") as TreeData
	var axe := _item("res://resources/items/tools/woodcutting/stone_axe.tres")
	var pick := _item("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres")
	var hammer := _item("res://resources/items/tools/building_repair/wood_hammer.tres")
	assert_eq(oak.required_felling_tool, int(ItemData.ToolKind.AXE))
	assert_eq(birch.required_felling_tool, int(ItemData.ToolKind.AXE))
	assert_eq(pine.required_felling_tool, int(ItemData.ToolKind.AXE))
	assert_true(oak.can_fell_with(axe))
	assert_false(oak.can_fell_with(pick))
	assert_false(oak.can_fell_with(hammer))
	assert_false(oak.can_fell_with(null))
	_check(_block("res://resources/blocks/oak_wood.tres"), pick, BlockData.BreakCheck.WRONG_TOOL)
	_check(_block("res://resources/blocks/oak_wood.tres"), axe, BlockData.BreakCheck.CAN_BREAK)


func test_placeholder_pickaxe_removed_from_catalog() -> void:
	var catalog_text := FileAccess.get_file_as_string("res://resources/items/item_catalog.tres")
	assert_false(catalog_text.contains("res://resources/items/pickaxe.tres"))
	var placeholder := _item("res://resources/items/pickaxe.tres")
	assert_ne(placeholder, null)
	assert_eq(placeholder.tool_data, null)
	var stone := _block("res://resources/blocks/stone.tres")
	_check(stone, placeholder, BlockData.BreakCheck.WRONG_TOOL)


func test_ore_power_values_unchanged() -> void:
	var expected := {
		"copper": 10,
		"tin": 15,
		"ferrite": 22,
		"aurel": 30,
		"cobalt": 40,
		"veyrite": 52,
		"cryonite": 65,
		"ignitium": 80,
		"voidium": 100,
		"astralith": 125,
	}
	for key in expected:
		var ore := load("res://resources/ores/%s_ore.tres" % key) as OreData
		assert_eq(ore.required_tool, int(ItemData.ToolKind.PICKAXE), key)
		assert_eq(ore.required_tool_power, int(expected[key]), key)
		assert_eq(ore.get_required_pickaxe_power(), int(expected[key]), key)
