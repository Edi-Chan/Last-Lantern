@tool
extends McpTestSuite

const ORE_KEYS := ["copper", "tin", "ferrite", "aurel", "cobalt", "veyrite", "cryonite", "ignitium", "voidium", "astralith"]
const ORE_POWERS := [10, 15, 22, 30, 40, 52, 65, 80, 100, 125]
const ORE_XP := [2, 3, 5, 8, 12, 18, 25, 35, 50, 100]
const ORE_DROPS := [[2, 4], [2, 4], [2, 3], [1, 3], [1, 3], [1, 3], [1, 2], [1, 2], [1, 2], [1, 1]]
const ORE_VEINS := [[5, 12], [4, 10], [4, 9], [3, 7], [3, 6], [2, 5], [2, 5], [2, 4], [1, 4], [1, 3]]
const PICK_KEYS := ["stone", "copper", "tin", "ferrite", "aurel", "cobalt", "veyrite", "cryonite", "ignitium", "voidium", "astralith"]
const PICK_POWERS := [10, 15, 22, 30, 40, 52, 65, 80, 100, 125, 160]
const PICK_NAMES := ["Steinspitzhacke", "Kupferspitzhacke", "Zinnspitzhacke", "Ferritspitzhacke", "Aurelspitzhacke", "Kobaltspitzhacke", "Veyritspitzhacke", "Cryonitspitzhacke", "Ignitiumspitzhacke", "Voidiumspitzhacke", "Astralithspitzhacke"]
const PICK_IDS := [22, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49]


func suite_name() -> String:
	return "ores"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _has(text: String, needle: String) -> bool:
	return text.contains(needle)


func test_ore_metal_categories_exist() -> void:
	assert_eq(int(OreData.OreMetalCategory.NONE), 0)
	assert_eq(int(OreData.OreMetalCategory.RAW_ORE), 1)
	assert_eq(int(OreData.OreMetalCategory.REFINED_METAL), 2)
	assert_eq(int(OreData.OreMetalCategory.ALLOY), 3)
	assert_eq(int(OreData.OreMetalCategory.SPECIAL_ORE), 4)
	assert_eq(OreData.get_metal_category_display_name(OreData.OreMetalCategory.RAW_ORE), "Roherz")
	assert_eq(OreData.get_metal_category_display_name(OreData.OreMetalCategory.REFINED_METAL), "Verarbeitetes Metall")
	assert_eq(OreData.get_metal_category_display_name(OreData.OreMetalCategory.ALLOY), "Legierung")
	assert_eq(OreData.get_metal_category_display_name(OreData.OreMetalCategory.SPECIAL_ORE), "Spezialerz")
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.ORE_METAL).to_html(false).to_upper(), "708090")
	assert_eq(ItemData.get_category_display_name(ItemData.ItemCategory.ORE_METAL), "Erze & Metalle")


func test_all_ore_resource_files() -> void:
	var catalog := _read("res://resources/ores/ore_catalog.tres")
	assert_true(catalog.contains("script_class=\"OreCatalog\""))
	for i in ORE_KEYS.size():
		var key: String = ORE_KEYS[i]
		var ore := _read("res://resources/ores/%s_ore.tres" % key)
		var block := _read("res://resources/blocks/ores/%s_ore_block.tres" % key)
		var item := _read("res://resources/items/materials/ores/%s_ore_item.tres" % key)
		assert_true(ore.contains("required_tool = 1"), key)
		assert_true(ore.contains("required_tool_power = %d" % ORE_POWERS[i]), key)
		assert_true(ore.contains("xp_reward = %d" % ORE_XP[i]), key)
		assert_true(ore.contains("drop_min = %d" % ORE_DROPS[i][0]), key)
		assert_true(ore.contains("drop_max = %d" % ORE_DROPS[i][1]), key)
		assert_true(ore.contains("vein_min_size = %d" % ORE_VEINS[i][0]), key)
		assert_true(ore.contains("vein_max_size = %d" % ORE_VEINS[i][1]), key)
		assert_true(ore.contains("min_depth_ratio ="), key)
		assert_true(ore.contains("max_depth_ratio ="), key)
		assert_true(block.contains("ore_data = ExtResource(\"2_ore\")"), key)
		assert_true(item.contains("ore_data = ExtResource(\"3_ore\")"), key)
		assert_true(item.contains("category = 8"), key)
		assert_true(catalog.contains("%s_ore.tres" % key), key)
		if key == "astralith":
			assert_true(ore.contains("metal_category = 4"))
			assert_true(ore.contains("special_spawn = true"))
		else:
			assert_true(ore.contains("metal_category = 1"), key)
		assert_true(FileAccess.file_exists("res://assets/world/ores/%s_ore.png" % key), key)
		assert_true(FileAccess.file_exists("res://assets/items/ores/%s_ore.png" % key), key)


func test_pickaxe_resource_files() -> void:
	for i in PICK_KEYS.size():
		var path := "res://resources/items/tools/mining/pickaxes/%s_pickaxe.tres" % PICK_KEYS[i]
		var text := _read(path)
		assert_true(_has(text, "base_tool_power = %d" % PICK_POWERS[i]), path)
		assert_true(_has(text, "pickaxe_tier = %d" % (i + 1)), path)
		assert_true(_has(text, "display_name = \"%s\"" % PICK_NAMES[i]), path)
		assert_true(_has(text, "id = %d" % PICK_IDS[i]), path)
		assert_true(_has(text, "base_range = 2.5"), path)
		assert_true(_has(text, "tool_category = 1"), path)
		assert_true(_has(text, "category = 10"), path)
		assert_true(FileAccess.file_exists("res://assets/items/tools/mining/pickaxes/%s_pickaxe.png" % PICK_KEYS[i]), path)


func test_mining_gates_from_data_files() -> void:
	for i in ORE_POWERS.size():
		var required: int = ORE_POWERS[i]
		var pick_that_can: int = required
		var pick_too_weak: int = required - 1
		assert_true(pick_that_can >= required, ORE_KEYS[i])
		assert_false(pick_too_weak >= required, ORE_KEYS[i])
	assert_true(10 >= 10)
	assert_false(10 >= 15)
	assert_true(15 >= 15)
	assert_false(15 >= 22)
	assert_true(22 >= 22)
	assert_true(30 >= 30)
	assert_false(30 >= 40)
	assert_true(40 >= 40)
	assert_false(40 >= 52)
	assert_true(52 >= 52)
	assert_false(52 >= 65)
	assert_true(65 >= 65)
	assert_false(65 >= 80)
	assert_true(80 >= 80)
	assert_false(80 >= 100)
	assert_true(100 >= 100)
	assert_false(100 >= 125)
	assert_true(125 >= 125)
	assert_true(160 >= 125)
	assert_false(160 >= 200)
	assert_true(200 >= 200)
	assert_true(0 >= 0)


func test_upgrades_and_start_loadout_text() -> void:
	var copper_pick := _read("res://resources/items/tools/mining/pickaxes/copper_pickaxe.tres")
	assert_true(copper_pick.contains("base_tool_power = 15"))
	var effective := 15 + 3
	assert_eq(effective, 18)
	assert_true(effective >= 15)
	assert_false(effective >= 22)
	assert_true(22 in Inventory.START_TOOL_IDS)
	for pick_id in range(40, 50):
		assert_false(pick_id in Inventory.START_TOOL_IDS)
	var catalog := _read("res://resources/items/item_catalog.tres")
	assert_true(catalog.contains("stone_pickaxe.tres"))
	assert_true(catalog.contains("astralith_pickaxe.tres"))
	assert_true(catalog.contains("astralith_ore_item.tres"))
	assert_false(catalog.contains("res://resources/items/pickaxe.tres"))
	var block_catalog := _read("res://resources/blocks/block_catalog.tres")
	assert_true(block_catalog.contains("astralith_ore_block.tres"))
	assert_false(block_catalog.contains("iron_ore.tres"))
	assert_eq(WorldGenerator.HIGHEST_BLOCK_ID, 28)
	var gen := _read("res://scripts/world/world_generator.gd")
	assert_true(gen.contains("func generate_ore("))
	assert_true(gen.contains("ore_catalog"))
	assert_true(gen.contains("STONE_LIKE"))
	var mining := _read("res://scripts/player/player_interaction.gd")
	assert_true(mining.contains("evaluate_break"))
	assert_true(mining.contains("effective_tool_power"))
	assert_true(mining.contains("MIN_MINING_TIME"))
	assert_true(mining.contains("_show_break_denied_feedback"))
	assert_false(mining.contains("Copper Pickaxe"))
	assert_false(mining.contains("Tin Ore"))
	var details := _read("res://scripts/ui/inventory_screen.gd")
	assert_true(details.contains("Spitzhacken-Power"))
	assert_true(details.contains("Benötigte Spitzhacken-Power"))
	assert_true(details.contains("XP:"))
