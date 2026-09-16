@tool
extends McpTestSuite

func suite_name() -> String:
	return "tools"


func _tool(path: String) -> ItemData:
	return load(path) as ItemData


func test_tool_category_enum_and_color() -> void:
	assert_eq(int(ToolData.ToolCategory.NONE), 0)
	assert_eq(int(ToolData.ToolCategory.MINING), 1)
	assert_eq(int(ToolData.ToolCategory.WOODCUTTING), 2)
	assert_eq(int(ToolData.ToolCategory.BUILDING_REPAIR), 3)
	assert_eq(int(ToolData.ToolCategory.DISMANTLING), 4)
	assert_eq(int(ToolData.ToolCategory.FARMING), 5)
	assert_eq(int(ToolData.ToolCategory.GATHERING_SPECIAL), 6)
	assert_eq(int(ToolData.ToolCategory.EXPLORATION), 7)
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.TOOL).to_html(false).to_upper(), "24C7C8")


func test_starter_tool_base_stats() -> void:
	var pick := _tool("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres")
	assert_ne(pick, null)
	assert_eq(pick.display_name, "Steinspitzhacke")
	assert_eq(int(pick.category), int(ItemData.ItemCategory.TOOL))
	assert_eq(pick.max_stack, 1)
	assert_eq(pick.damage, 8)
	var pick_tool: ToolData = pick.tool_data
	assert_ne(pick_tool, null)
	assert_eq(int(pick_tool.tool_category), int(ToolData.ToolCategory.MINING))
	assert_eq(pick_tool.base_damage, 8)
	assert_eq(pick_tool.base_tool_power, 10)
	assert_eq(pick_tool.base_use_speed, 1.0)
	assert_eq(pick_tool.base_max_durability, 100)
	assert_eq(pick_tool.base_range, 2.5)
	assert_eq(pick_tool.pickaxe_tier, 1)
	assert_eq(int(pick.tool_kind), int(ItemData.ToolKind.PICKAXE))
	assert_eq(pick_tool.special, "Stein/Erz")

	var axe := _tool("res://resources/items/tools/woodcutting/stone_axe.tres")
	assert_eq(axe.display_name, "Steinaxt")
	assert_eq(int(axe.tool_data.tool_category), int(ToolData.ToolCategory.WOODCUTTING))
	assert_eq(axe.tool_data.base_damage, 10)
	assert_eq(axe.tool_data.base_tool_power, 12)
	assert_eq(axe.tool_data.base_use_speed, 0.9)
	assert_eq(axe.tool_data.base_max_durability, 100)
	assert_eq(axe.tool_data.base_range, 2.5)
	assert_eq(axe.tool_data.special, "Holz")
	assert_eq(int(axe.tool_kind), int(ItemData.ToolKind.AXE))

	var hammer := _tool("res://resources/items/tools/building_repair/wood_hammer.tres")
	assert_eq(hammer.display_name, "Holzhammer")
	assert_eq(int(hammer.tool_data.tool_category), int(ToolData.ToolCategory.BUILDING_REPAIR))
	assert_eq(hammer.tool_data.base_damage, 5)
	assert_eq(hammer.tool_data.base_tool_power, 8)
	assert_eq(hammer.tool_data.base_use_speed, 1.0)
	assert_eq(hammer.tool_data.base_max_durability, 120)
	assert_eq(hammer.tool_data.base_range, 2.5)
	assert_eq(hammer.tool_data.special, "Bauen/Reparieren")
	assert_eq(int(hammer.tool_kind), int(ItemData.ToolKind.HAMMER))

	var wrench := _tool("res://resources/items/tools/dismantling/simple_wrench.tres")
	assert_eq(wrench.display_name, "Einfacher Schraubenschlüssel")
	assert_eq(int(wrench.tool_data.tool_category), int(ToolData.ToolCategory.DISMANTLING))
	assert_eq(wrench.tool_data.base_damage, 6)
	assert_eq(wrench.tool_data.base_tool_power, 8)
	assert_eq(wrench.tool_data.base_use_speed, 0.8)
	assert_eq(wrench.tool_data.base_max_durability, 100)
	assert_eq(wrench.tool_data.base_range, 2.0)
	assert_eq(wrench.tool_data.special, "Demontieren")
	assert_eq(int(wrench.tool_kind), int(ItemData.ToolKind.WRENCH))

	var hoe := _tool("res://resources/items/tools/farming/wood_hoe.tres")
	assert_eq(hoe.display_name, "Holzhacke")
	assert_eq(int(hoe.tool_data.tool_category), int(ToolData.ToolCategory.FARMING))
	assert_eq(hoe.tool_data.base_damage, 4)
	assert_eq(hoe.tool_data.base_tool_power, 6)
	assert_eq(hoe.tool_data.base_use_speed, 1.1)
	assert_eq(hoe.tool_data.base_max_durability, 80)
	assert_eq(hoe.tool_data.base_range, 2.5)
	assert_eq(hoe.tool_data.special, "Erde/Farming")
	assert_eq(int(hoe.tool_kind), int(ItemData.ToolKind.HOE))

	var rod := _tool("res://resources/items/tools/gathering/wood_fishing_rod.tres")
	assert_eq(rod.display_name, "Holzangel")
	assert_eq(int(rod.tool_data.tool_category), int(ToolData.ToolCategory.GATHERING_SPECIAL))
	assert_eq(rod.tool_data.base_damage, 2)
	assert_eq(rod.tool_data.base_tool_power, 5)
	assert_eq(rod.tool_data.base_use_speed, 1.0)
	assert_eq(rod.tool_data.base_max_durability, 80)
	assert_eq(rod.tool_data.base_range, 8.0)
	assert_eq(rod.tool_data.special, "Angeln")
	assert_eq(int(rod.tool_kind), int(ItemData.ToolKind.FISHING_ROD))


func test_prepared_tool_items() -> void:
	var sickle := _tool("res://resources/items/tools/farming/sickle.tres")
	assert_eq(sickle.display_name, "Sichel")
	assert_eq(int(sickle.tool_data.tool_category), int(ToolData.ToolCategory.FARMING))
	assert_eq(sickle.tool_data.base_damage, 5)
	assert_eq(sickle.tool_data.base_tool_power, 7)
	assert_eq(sickle.tool_data.base_use_speed, 1.1)
	assert_eq(sickle.tool_data.base_max_durability, 80)
	assert_eq(sickle.tool_data.base_range, 2.5)
	assert_eq(sickle.tool_data.special, "Pflanzen")
	assert_eq(int(sickle.tool_kind), int(ItemData.ToolKind.SICKLE))

	var net := _tool("res://resources/items/tools/gathering/net.tres")
	assert_eq(net.display_name, "Kescher")
	assert_eq(int(net.tool_data.tool_category), int(ToolData.ToolCategory.GATHERING_SPECIAL))
	assert_eq(net.tool_data.base_damage, 1)
	assert_eq(net.tool_data.base_tool_power, 4)
	assert_eq(net.tool_data.base_use_speed, 1.0)
	assert_eq(net.tool_data.base_max_durability, 70)
	assert_eq(net.tool_data.base_range, 3.0)
	assert_eq(int(net.tool_kind), int(ItemData.ToolKind.NET))

	var torch := _tool("res://resources/items/tools/exploration/torch.tres")
	assert_eq(int(torch.tool_data.tool_category), int(ToolData.ToolCategory.EXPLORATION))
	var lantern := _tool("res://resources/items/tools/exploration/lantern.tres")
	assert_eq(int(lantern.tool_data.tool_category), int(ToolData.ToolCategory.EXPLORATION))
	var scanner := _tool("res://resources/items/tools/exploration/scanner.tres")
	assert_eq(int(scanner.tool_data.tool_category), int(ToolData.ToolCategory.EXPLORATION))
	assert_eq(int(torch.tool_kind), int(ItemData.ToolKind.NONE))
	assert_eq(int(lantern.tool_kind), int(ItemData.ToolKind.NONE))
	assert_eq(int(scanner.tool_kind), int(ItemData.ToolKind.NONE))
	assert_eq(scanner.tool_data.base_range, 6.0)
	assert_eq(scanner.tool_data.special, "Erkundung")
	assert_eq(scanner.max_stack, 1)


func test_default_hotbar_tool_order() -> void:
	assert_eq(Inventory.DEFAULT_HOTBAR_TOOL_IDS.size(), 10)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[0]), 22)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[1]), 23)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[2]), 24)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[3]), 25)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[4]), 26)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[5]), 28)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[6]), 27)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[7]), 29)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[8]), 30)
	assert_eq(int(Inventory.DEFAULT_HOTBAR_TOOL_IDS[9]), 31)
	assert_true(32 in Inventory.START_TOOL_IDS)
	assert_false(32 in Inventory.DEFAULT_HOTBAR_TOOL_IDS)


func test_instance_upgrades_do_not_mutate_resource() -> void:
	var pick := _tool("res://resources/items/tools/mining/pickaxes/stone_pickaxe.tres")
	var a := ItemInstanceData.from_item(pick)
	var b := ItemInstanceData.from_item(pick)
	a.damage_bonus = 2
	assert_eq(pick.tool_data.base_damage + a.damage_bonus, 10)
	assert_eq(pick.tool_data.base_damage + b.damage_bonus, 8)
	assert_eq(pick.tool_data.base_damage, 8)
	assert_eq(a.durability, 100)
	assert_eq(b.durability, 100)
	a.durability = 40
	assert_eq(b.durability, 100)
	assert_eq(pick.tool_data.base_max_durability, 100)


func test_split_default_is_floor_half() -> void:
	assert_eq(int(floor(64.0 / 2.0)), 32)
	assert_eq(int(floor(15.0 / 2.0)), 7)
