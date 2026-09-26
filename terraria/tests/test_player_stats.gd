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
	var item := load("res://resources/items/equipment/wood_helmet.tres") as ItemData
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


func _inv() -> Inventory:
	var inv := Inventory.new()
	track(inv)
	inv.item_catalog = ResourceLoader.load("res://resources/items/item_catalog.tres", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as ItemCatalog
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


func _equip(inv: Inventory, key: String, item_id: int) -> void:
	inv.equipment[key]["item_id"] = item_id
	inv.equipment[key]["amount"] = 1


func _clear_equip(inv: Inventory, key: String) -> void:
	inv.equipment[key] = inv._empty_slot()


func _fresh_stats(inv: Inventory) -> PlayerStats:
	var stats := PlayerStats.new()
	track(stats)
	stats.sheet.apply_defaults()
	stats.rebuild_from_inventory(inv)
	return stats


func _set_mod_count(stats: PlayerStats) -> int:
	var count := 0
	for mod in stats.sheet.modifiers():
		if mod != null and mod.source_kind == StatModifier.SourceKind.SET_BONUS:
			count += 1
	return count


func test_naked_defaults() -> void:
	var stats := _fresh_stats(_inv())
	assert_eq(int(stats.sheet.get_final(StatId.MAX_HEALTH)), 100)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_STAMINA)), 100)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_ENERGY)), 100)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 0)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MOVEMENT_SPEED), 1.0))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.DAMAGE_MULTIPLIER), 1.0))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.ATTACK_SPEED), 1.0))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.CRIT_CHANCE), 0.05))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.FIRE_RESISTANCE), 0.0))
	assert_eq(_set_mod_count(stats), 0)


func test_cobalt_helmet_only() -> void:
	var inv := _inv()
	_equip(inv, "head", 145)
	var stats := _fresh_stats(inv)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 4)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.05))
	assert_eq(_set_mod_count(stats), 0)
	assert_false(bool(stats.get_set_status().get("complete", false)))


func test_cobalt_helmet_and_chest_no_set() -> void:
	var inv := _inv()
	_equip(inv, "head", 145)
	_equip(inv, "chest", 146)
	var stats := _fresh_stats(inv)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 11)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_STAMINA)), 110)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.05))
	assert_eq(_set_mod_count(stats), 0)


func test_cobalt_full_set_once() -> void:
	var inv := _inv()
	_equip(inv, "head", 145)
	_equip(inv, "chest", 146)
	_equip(inv, "legs", 147)
	var stats := _fresh_stats(inv)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 16)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_STAMINA)), 110)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.15))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MOVEMENT_SPEED), 1.07))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.STAMINA_REGEN), 16.2))
	assert_eq(_set_mod_count(stats), 3)
	assert_true(bool(stats.get_set_status().get("complete", false)))
	assert_eq(str(stats.get_set_status().get("set_id", "")), String(ArmorSet.COBALT))


func test_cobalt_set_removed_and_reapplied() -> void:
	var inv := _inv()
	_equip(inv, "head", 145)
	_equip(inv, "chest", 146)
	_equip(inv, "legs", 147)
	var stats := _fresh_stats(inv)
	_clear_equip(inv, "legs")
	stats.rebuild_from_inventory(inv)
	assert_eq(_set_mod_count(stats), 0)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.05))
	_equip(inv, "legs", 147)
	stats.rebuild_from_inventory(inv)
	assert_eq(_set_mod_count(stats), 3)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.15))


func test_save_load_rebuilds_full_set() -> void:
	var inv := _inv()
	_equip(inv, "head", 145)
	_equip(inv, "chest", 146)
	_equip(inv, "legs", 147)
	var stats := _fresh_stats(inv)
	var saved := stats.to_save_dict()
	assert_eq((saved["sheet"] as Dictionary).get("upgrades", []).size(), 0)
	var loaded := PlayerStats.new()
	track(loaded)
	loaded.sheet.apply_defaults()
	loaded.sheet.load_persistent(saved["sheet"])
	loaded.rebuild_from_inventory(inv)
	assert_eq(_set_mod_count(loaded), 3)
	assert_true(is_equal_approx(loaded.sheet.get_final(StatId.MINING_SPEED), 1.15))
	assert_eq(int(loaded.sheet.get_final(StatId.ARMOR)), 16)


func test_rapid_equip_unequip_does_not_stack() -> void:
	var inv := _inv()
	var stats := _fresh_stats(inv)
	for _i in 100:
		_equip(inv, "head", 145)
		_equip(inv, "chest", 146)
		_equip(inv, "legs", 147)
		stats.rebuild_from_inventory(inv)
		_clear_equip(inv, "head")
		_clear_equip(inv, "chest")
		_clear_equip(inv, "legs")
		stats.rebuild_from_inventory(inv)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 0)
	assert_eq(_set_mod_count(stats), 0)
	_equip(inv, "head", 145)
	_equip(inv, "chest", 146)
	_equip(inv, "legs", 147)
	stats.rebuild_from_inventory(inv)
	assert_eq(_set_mod_count(stats), 3)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MINING_SPEED), 1.15))


func test_astralith_full_set() -> void:
	var inv := _inv()
	_equip(inv, "head", 160)
	_equip(inv, "chest", 161)
	_equip(inv, "legs", 162)
	var stats := _fresh_stats(inv)
	assert_eq(int(stats.sheet.get_final(StatId.ARMOR)), 32)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_HEALTH)), 125)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_STAMINA)), 120)
	assert_eq(int(stats.sheet.get_final(StatId.MAX_ENERGY)), 120)
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.DAMAGE_MULTIPLIER), 1.10))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.ATTACK_SPEED), 1.05))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.CRIT_CHANCE), 0.09))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.MOVEMENT_SPEED), 1.07))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.FIRE_RESISTANCE), 0.10))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.COLD_RESISTANCE), 0.10))
	assert_true(is_equal_approx(stats.sheet.get_final(StatId.DARKNESS_RESISTANCE), 0.10))


func test_resistance_cap() -> void:
	var sheet := StatSheet.new()
	sheet.apply_defaults()
	sheet.add_modifier(StatModifier.new(StatId.FIRE_RESISTANCE, 0.5, StatModifier.Type.FLAT, &"a"))
	sheet.add_modifier(StatModifier.new(StatId.FIRE_RESISTANCE, 0.5, StatModifier.Type.FLAT, &"b"))
	assert_true(is_equal_approx(sheet.get_final(StatId.FIRE_RESISTANCE), 0.9))


func test_health_clamps_when_max_drops() -> void:
	var inv := _inv()
	_equip(inv, "head", 139)
	_equip(inv, "chest", 140)
	_equip(inv, "legs", 141)
	var stats := _fresh_stats(inv)
	assert_eq(int(stats.max_health), 120)
	stats.health = 120.0
	_clear_equip(inv, "chest")
	stats.rebuild_from_inventory(inv)
	assert_true(stats.max_health < 120.0)
	assert_true(stats.health <= stats.max_health)


func test_armor_rarity_and_set_ids() -> void:
	ArmorSetCatalog.clear_cache()
	var catalog := ArmorSetCatalog.load_default()
	assert_ne(catalog, null)
	var helm := ResourceLoader.load("res://resources/items/equipment/wood_helmet.tres", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as ItemData
	assert_eq(int(helm.rarity), int(ItemData.Rarity.COMMON))
	assert_eq(catalog.set_id_for_item(helm), ArmorSet.WOOD)
	var cobalt := ResourceLoader.load("res://resources/items/equipment/metal/cobalt_helmet.tres", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as ItemData
	assert_eq(int(cobalt.rarity), int(ItemData.Rarity.RARE))
	assert_eq(catalog.set_id_for_item(cobalt), ArmorSet.COBALT)
	var astral := ResourceLoader.load("res://resources/items/equipment/metal/astralith_helmet.tres", "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as ItemData
	assert_eq(int(astral.rarity), int(ItemData.Rarity.LEGENDARY))
	assert_eq(catalog.set_id_for_item(astral), ArmorSet.ASTRALITH)
	assert_ne(catalog.get_set(ArmorSet.COBALT), null)
	assert_eq(catalog.get_set(ArmorSet.COBALT).set_bonus_name, "Tiefengänger")
