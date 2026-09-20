@tool
extends McpTestSuite


func suite_name() -> String:
	return "player_stats"


func test_sheet_excludes_equipment_kinds() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(StatId.ARMOR, 2.0)
	sheet.add_modifier(StatModifier.new(StatId.ARMOR, 5.0, StatModifier.Type.FLAT, &"helm", StatModifier.SourceKind.EQUIPMENT))
	sheet.add_modifier(StatModifier.new(StatId.ARMOR, 3.0, StatModifier.Type.FLAT, &"potion", StatModifier.SourceKind.CONSUMABLE))
	assert_eq(int(sheet.get_final(StatId.ARMOR)), 10)
	assert_eq(int(sheet.get_final_excluding_source_kinds(StatId.ARMOR, [StatModifier.SourceKind.EQUIPMENT])), 5)


func test_sheet_flat_then_percent() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(StatId.MAX_HEALTH, 100.0)
	sheet.add_modifier(StatModifier.new(StatId.MAX_HEALTH, 20.0, StatModifier.Type.FLAT, &"armor"))
	sheet.add_modifier(StatModifier.new(StatId.MAX_HEALTH, 10.0, StatModifier.Type.FLAT, &"potion"))
	sheet.add_modifier(StatModifier.new(StatId.MAX_HEALTH, 20.0, StatModifier.Type.FLAT, &"upgrade"))
	assert_eq(int(sheet.get_final(StatId.MAX_HEALTH)), 150)
	sheet.set_base(StatId.MOVEMENT_SPEED, 1.0)
	sheet.add_modifier(StatModifier.new(StatId.MOVEMENT_SPEED, 0.10, StatModifier.Type.PERCENT, &"boots"))
	sheet.add_modifier(StatModifier.new(StatId.MOVEMENT_SPEED, 0.20, StatModifier.Type.PERCENT, &"potion"))
	assert_true(is_equal_approx(sheet.get_final(StatId.MOVEMENT_SPEED), 1.30))


func test_timed_modifier_expires() -> void:
	var sheet := StatSheet.new()
	sheet.set_base(StatId.ARMOR, 0.0)
	var buff := StatModifier.new(StatId.ARMOR, 10.0, StatModifier.Type.FLAT, &"armor_potion", StatModifier.SourceKind.CONSUMABLE, 2.0)
	sheet.add_modifier(buff)
	assert_eq(int(sheet.get_final(StatId.ARMOR)), 10)
	sheet.tick(2.0)
	assert_eq(int(sheet.get_final(StatId.ARMOR)), 0)
	assert_eq(sheet.timed_effects().size(), 0)


func test_item_defense_becomes_armor_modifier() -> void:
	var item := load("res://resources/items/helmet.tres") as ItemData
	assert_ne(item, null)
	assert_true(item.defense > 0)
	var mods := StatSheet.modifiers_from_item(item)
	var armor_flat := 0.0
	for mod in mods:
		if int(mod.stat) == StatId.ARMOR and mod.modifier_type == StatModifier.Type.FLAT:
			armor_flat += mod.value
	assert_eq(int(armor_flat), item.defense)


func test_defaults_match_start_sheet() -> void:
	var sheet := StatSheet.new()
	sheet.apply_defaults()
	assert_eq(int(sheet.get_final(StatId.MAX_HEALTH)), 100)
	assert_eq(int(sheet.get_final(StatId.MAX_STAMINA)), 100)
	assert_eq(int(sheet.get_final(StatId.STAMINA_REGEN)), 15)
	assert_true(is_equal_approx(sheet.get_final(StatId.MOVEMENT_SPEED), 1.0))
	assert_true(is_equal_approx(sheet.get_final(StatId.SPRINT_SPEED), 1.5))
	assert_true(is_equal_approx(sheet.get_final(StatId.CRIT_CHANCE), 0.05))
	assert_true(is_equal_approx(sheet.get_final(StatId.CRIT_DAMAGE), 1.5))
	assert_eq(int(sheet.get_final(StatId.ARMOR)), 0)
	assert_true(is_equal_approx(sheet.get_final(StatId.DARKNESS_RESISTANCE), 0.0))


func test_darkness_resist_reduces_fog() -> void:
	var stats := PlayerStats.new()
	stats.sheet.apply_defaults()
	stats.sheet.add_modifier(StatModifier.new(StatId.DARKNESS_RESISTANCE, 0.5, StatModifier.Type.FLAT, &"test"))
	stats._sync_caps_from_sheet(true)
	var result := stats.apply_incoming_damage(20.0, true, DamageTypes.Type.DARKNESS)
	assert_eq(int(round(float(result["applied"]))), 10)


func test_character_tab_exists() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/inventory_screen.gd")
	assert_true(src.contains("CHARACTER"))
	assert_true(src.contains("Charakter"))
	assert_true(FileAccess.file_exists("res://scripts/ui/character_page.gd"))
	var scene := FileAccess.get_file_as_string("res://scenes/ui/inventory_screen.tscn")
	assert_true(scene.contains("TabCharacter"))
	assert_true(scene.contains("CharacterPage"))
	var stats_src := FileAccess.get_file_as_string("res://scripts/player/player_stats.gd")
	assert_true(stats_src.contains("func rebuild_from_inventory"))
	assert_true(stats_src.contains("sheet: StatSheet"))
