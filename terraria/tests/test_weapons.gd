@tool
extends McpTestSuite

func suite_name() -> String:
	return "weapons"


func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func _items() -> ItemCatalog:
	return _load_fresh("res://resources/items/item_catalog.tres") as ItemCatalog


func _catalog() -> RecipeCatalog:
	return _load_fresh("res://resources/crafting/recipe_catalog.tres") as RecipeCatalog


func test_aaa_generate_weapon_assets() -> void:
	var gen = load("res://tools/generate_weapon_assets.gd").new()
	assert_ne(gen, null)
	gen.run()
	assert_true(FileAccess.file_exists("res://assets/items/weapons/swords/stone_sword.png"))
	assert_true(FileAccess.file_exists("res://assets/items/weapons/spears/wood_spear.png"))
	assert_true(FileAccess.file_exists("res://assets/items/weapons/bows/wood_bow.png"))
	assert_true(FileAccess.file_exists("res://assets/items/ammunition/wood_arrow.png"))
	assert_true(FileAccess.file_exists("res://assets/items/weapons/lanterns/old_combat_lantern.png"))
	assert_true(FileAccess.file_exists("res://assets/items/weapons/lanterns/combat_light.png"))


func test_weapon_kind_enum() -> void:
	assert_eq(int(ItemData.WeaponKind.NONE), 0)
	assert_eq(int(ItemData.WeaponKind.SWORD), 1)
	assert_eq(int(ItemData.WeaponKind.SPEAR), 2)
	assert_eq(int(ItemData.WeaponKind.BOW), 3)
	assert_eq(int(ItemData.WeaponKind.LANTERN), 4)
	assert_eq(ItemData.get_weapon_kind_display_name(int(ItemData.WeaponKind.SWORD)), "Schwert")
	assert_eq(ItemData.get_weapon_kind_display_name(int(ItemData.WeaponKind.LANTERN)), "Kampflaterne")
	assert_eq(ItemData.get_category_color(ItemData.ItemCategory.WEAPON).to_html(false).to_upper(), "E53935")


func test_starter_weapons_in_catalog() -> void:
	var items := _items()
	var stone := items.get_item(100)
	assert_ne(stone, null)
	assert_eq(stone.display_name, "Steinschwert")
	assert_eq(int(stone.item_type), int(ItemData.ItemType.WEAPON))
	assert_eq(int(stone.category), int(ItemData.ItemCategory.WEAPON))
	assert_eq(int(stone.weapon_kind), int(ItemData.WeaponKind.SWORD))
	assert_eq(stone.max_stack, 1)
	assert_eq(stone.get_base_damage(), 12)
	assert_true(stone.is_weapon())
	assert_false(stone.is_tool())
	var copper := items.get_item(101)
	assert_eq(copper.get_base_damage(), 16)
	var spear := items.get_item(107)
	assert_eq(int(spear.weapon_kind), int(ItemData.WeaponKind.SPEAR))
	assert_true(spear.get_base_range() > stone.get_base_range())
	var bow := items.get_item(111)
	assert_eq(int(bow.weapon_kind), int(ItemData.WeaponKind.BOW))
	assert_eq(int(bow.weapon_data.get("ammo_item_id")), 114)
	var arrow := items.get_item(114)
	assert_eq(int(arrow.category), int(ItemData.ItemCategory.AMMUNITION))
	assert_true(arrow.max_stack > 1)
	var lantern := items.get_item(115)
	assert_eq(int(lantern.weapon_kind), int(ItemData.WeaponKind.LANTERN))
	assert_eq(lantern.get_base_damage(), 15)
	assert_eq(float(lantern.weapon_data.get("darkness_damage_multiplier")), 1.5)


func test_weapon_recipes_and_anvil() -> void:
	var catalog := _catalog()
	var stone := catalog.get_recipe_for_output(100)
	assert_ne(stone, null)
	assert_true(stone.requires_station_kind(RecipeData.Station.WORKBENCH))
	assert_eq(int(stone.ui_category), int(RecipeData.UiCategory.WEAPONS))
	var copper := catalog.get_recipe_for_output(101)
	assert_true(copper.requires_station_kind(RecipeData.Station.ANVIL))
	assert_false(copper.requires_station_kind(RecipeData.Station.WORKBENCH))
	var arrows := catalog.get_recipe_for_output(114)
	assert_ne(arrows, null)
	assert_eq(arrows.output_amount, 8)
	var system := CraftingSystem.new()
	system.setup(catalog, _items())
	for recipe in system.recipes_for_context(RecipeData.Station.ANVIL):
		assert_true(recipe.requires_station_kind(RecipeData.Station.ANVIL))
		assert_ne(recipe.output_item_id, 100)
		assert_ne(recipe.output_item_id, 90)


func _make_darkness_target(active: bool) -> Node:
	var gds := GDScript.new()
	gds.source_code = "@tool\nextends Node\nvar darkness_active := false\nfunc is_darkness_form() -> bool:\n\treturn darkness_active\n"
	gds.reload()
	var target := Node.new()
	target.set_script(gds)
	target.set("darkness_active", active)
	track(target)
	return target


func test_darkness_multiplier_is_central() -> void:
	var lantern := _items().get_item(115)
	assert_ne(lantern, null)
	var normal := _make_darkness_target(false)
	assert_eq(CombatResolver.resolve_damage(15, lantern.weapon_data, normal), 15)
	var dark := _make_darkness_target(true)
	assert_eq(CombatResolver.resolve_damage(15, lantern.weapon_data, dark), 23)
	var zombie_src := FileAccess.get_file_as_string("res://scripts/enemies/zombie.gd")
	assert_false(zombie_src.contains("darkness_damage_multiplier"))
	assert_true(zombie_src.contains("func is_darkness_form"))


func test_combat_resolver_combined_bow_damage() -> void:
	var bow := _items().get_item(111)
	var arrow := _items().get_item(114)
	assert_eq(CombatResolver.combined_ranged_damage(bow.weapon_data, arrow), 12)
	assert_eq(CombatResolver.quick_ranged_damage(bow.weapon_data, arrow), 6)
	assert_eq(CombatResolver.charged_ranged_damage(bow.weapon_data, arrow, 0.0), 10)
	assert_eq(CombatResolver.charged_ranged_damage(bow.weapon_data, arrow, 1.0), 19)
	assert_eq(float(bow.weapon_data.get("projectile_speed")), 297.0)
	assert_eq(float(bow.weapon_data.get("base_range")), 54.0)
	assert_eq(float(_items().get_item(112).weapon_data.get("base_range")), 66.0)
	assert_eq(float(_items().get_item(113).weapon_data.get("base_range")), 78.0)


func test_bow_draw_and_arrow_physics() -> void:
	var proj := FileAccess.get_file_as_string("res://scripts/combat/projectile.gd")
	assert_true(proj.contains("gravity_strength"))
	assert_true(proj.contains("max_distance"))
	assert_true(proj.contains("func predict_arc"))
	var interact := FileAccess.get_file_as_string("res://scripts/player/player_interaction.gd")
	assert_true(interact.contains("func is_drawing_bow"))
	assert_true(interact.contains("_tick_bow_draw"))
	assert_true(interact.contains("charged_ranged_damage"))
	assert_true(interact.contains("get_flight_distance"))
	assert_true(interact.contains("_is_bow_aim_held"))
	assert_true(interact.contains("interact_secondary"))
	assert_true(interact.contains("_update_bow_trajectory"))
	assert_true(interact.contains("_fire_bow_quick"))
	assert_true(interact.contains("quick_ranged_damage"))
	var weapon := WeaponData.new()
	weapon.base_range = 54.0
	weapon.projectile_speed = 297.0
	assert_eq(weapon.get_flight_distance(16.0), 864.0)
	assert_eq(weapon.scale_quick_damage(12), 6)
	assert_eq(weapon.scale_charge_damage(12, 1.0), 19)
	var arc := Projectile.predict_arc(Vector2.ZERO, Vector2(300.0, -40.0), 820.0, 864.0)
	assert_true(arc.size() >= 2)
	assert_true(arc[arc.size() - 1].y > arc[0].y)


func test_auto_tool_ignores_weapons() -> void:
	var inv := FileAccess.get_file_as_string("res://scripts/inventory/inventory.gd")
	assert_true(inv.contains("func find_best_hotbar_tool_for"))
	assert_true(inv.contains("DEV_WEAPON_TEST_LOADOUT"))
	var mining := FileAccess.get_file_as_string("res://scripts/player/player_interaction.gd")
	assert_true(mining.contains("item.is_weapon()"))
	assert_true(mining.contains("cancel_attack"))
	assert_true(mining.contains("spear_thrust"))
	assert_true(mining.contains("bow_shot"))
	assert_true(mining.contains("lantern_burst"))


func test_hitbox_one_hit_per_attack() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/player/tool_hitbox.gd")
	assert_true(src.contains("already_hit_targets"))
	assert_true(src.contains("begin_attack"))
	assert_true(src.contains("CombatResolver"))
	assert_true(FileAccess.file_exists("res://scenes/combat/projectile.tscn"))
	assert_true(FileAccess.file_exists("res://scripts/combat/projectile.gd"))
	var player_scene := FileAccess.get_file_as_string("res://scenes/player/player.tscn")
	assert_true(player_scene.contains("&\"sword_swing\""))
	assert_true(player_scene.contains("&\"spear_thrust\""))
	assert_true(player_scene.contains("&\"bow_shot\""))
	assert_true(player_scene.contains("&\"lantern_burst\""))
	assert_true(player_scene.contains("CombatLight"))


func test_spear_trades_dps_for_range() -> void:
	var sword := _items().get_item(100)
	var spear := _items().get_item(107)
	assert_true(spear.get_base_range() > sword.get_base_range())
	assert_true(spear.get_base_use_speed() < sword.get_base_use_speed())
	assert_true(spear.get_weapon_knockback() > sword.get_weapon_knockback())
	assert_true(spear.get_base_damage() < sword.get_base_damage())


func test_weapon_ui_categories() -> void:
	var items := _items()
	assert_eq(int(RecipeData.resolve_ui_category(items.get_item(100))), int(RecipeData.UiCategory.WEAPONS))
	assert_eq(int(RecipeData.resolve_ui_category(items.get_item(107))), int(RecipeData.UiCategory.WEAPONS))
	assert_eq(int(RecipeData.resolve_ui_category(items.get_item(111))), int(RecipeData.UiCategory.WEAPONS))
	assert_eq(int(RecipeData.resolve_ui_category(items.get_item(115))), int(RecipeData.UiCategory.WEAPONS))
	assert_eq(int(RecipeData.resolve_ui_category(items.get_item(114))), int(RecipeData.UiCategory.CONSUMABLE))
	assert_ne(int(RecipeData.resolve_ui_category(items.get_item(115))), int(RecipeData.UiCategory.LIGHT))
	var page := FileAccess.get_file_as_string("res://scripts/ui/crafting_page.gd")
	assert_true(page.contains("Schwerter"))
	assert_true(page.contains("Speere"))
	assert_true(page.contains("Bögen"))
	assert_true(page.contains("Kampflaternen"))
