@tool
extends McpTestSuite


func suite_name() -> String:
	return "player_visual"


func _load_fresh(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)


func test_contract_frame_size() -> void:
	assert_eq(PlayerAnimationContract.FRAME_WIDTH, 40)
	assert_eq(PlayerAnimationContract.FRAME_HEIGHT, 56)
	assert_eq(PlayerAnimationContract.FOOT_ORIGIN_Y, 55)
	var size := PlayerAnimationContract.sheet_size()
	assert_eq(size.x, 240)
	assert_true(size.y > 56)


func test_contract_has_required_anims() -> void:
	var names := PlayerAnimationContract.anim_names()
	for required in [&"idle", &"walk", &"run", &"crouch_idle", &"jump", &"fall", &"land", &"swim", &"ladder_climb", &"hurt", &"death", &"sleep", &"use_swing", &"use_mine", &"use_chop", &"use_thrust", &"use_stab", &"bow_draw", &"bow_release"]:
		assert_true(names.has(required), "missing " + String(required))


func test_layer_sheets_exist() -> void:
	assert_true(FileAccess.file_exists("res://assets/player/sheets/body.png"))
	assert_true(FileAccess.file_exists("res://assets/player/sheets/composed.png"))
	assert_true(FileAccess.file_exists("res://resources/player/body_frames.tres"))
	assert_true(FileAccess.file_exists("res://resources/player/armor_wood_helmet_frames.tres"))
	var body := _load_fresh("res://resources/player/body_frames.tres") as SpriteFrames
	assert_ne(body, null)
	assert_true(body.has_animation(&"walk"))
	assert_eq(body.get_frame_count(&"walk"), 6)
	assert_eq(body.get_frame_count(&"use_swing"), 6)


func test_action_type_from_weapon_kind() -> void:
	var sword := _load_fresh("res://resources/items/weapons/swords/wood_sword.tres") as ItemData
	assert_ne(sword, null)
	assert_eq(int(sword.resolve_action_type()), int(ItemData.ActionType.SWING))
	var spear := _load_fresh("res://resources/items/weapons/spears/wood_spear.tres") as ItemData
	assert_eq(int(spear.resolve_action_type()), int(ItemData.ActionType.THRUST))
	var bow := _load_fresh("res://resources/items/weapons/bows/wood_bow.tres") as ItemData
	assert_eq(int(bow.resolve_action_type()), int(ItemData.ActionType.BOW))


func test_action_type_from_tool_kind() -> void:
	assert_eq(int(ItemData.ActionType.MINE), int(PlayerAnimationContract.ActionType.MINE))
	assert_eq(int(ItemData.ActionType.SWING), 1)
	var pick := ItemData.new()
	pick.item_type = ItemData.ItemType.TOOL
	pick.tool_kind = ItemData.ToolKind.PICKAXE
	assert_eq(int(pick.resolve_action_type()), int(ItemData.ActionType.MINE))
	var axe := ItemData.new()
	axe.item_type = ItemData.ItemType.TOOL
	axe.tool_kind = ItemData.ToolKind.AXE
	assert_eq(int(axe.resolve_action_type()), int(ItemData.ActionType.CHOP))


func test_wood_armor_uses_wood_frames() -> void:
	var helm := _load_fresh("res://resources/items/equipment/wood_helmet.tres") as ItemData
	assert_ne(helm, null)
	assert_ne(helm.resolve_armor_frames(), null)
	assert_true(helm.resolve_armor_frames().has_animation(&"swim"))
	assert_eq(int(helm.resolve_hair_policy()), 1)


func test_copper_armor_keeps_stats_and_unique_frames() -> void:
	var helm := _load_fresh("res://resources/items/equipment/metal/copper_helmet.tres") as ItemData
	assert_ne(helm, null)
	assert_eq(helm.defense, 2)
	assert_eq(helm.armor_modulate, Color.WHITE)
	assert_ne(helm.resolve_armor_frames(), null)
	assert_true(String(helm.resolve_armor_frames().resource_path).contains("armor_copper_helmet"))
	var ferrite := _load_fresh("res://resources/items/equipment/metal/ferrite_helmet.tres") as ItemData
	assert_eq(ferrite.defense, 4)
	assert_true(String(ferrite.resolve_armor_frames().resource_path).contains("armor_ferrite_helmet"))
	assert_ne(helm.resolve_armor_frames(), ferrite.resolve_armor_frames())


func test_look_record_roundtrip() -> void:
	var look := LookRecord.new()
	look.character_name = "Mira"
	look.hair_color = Color(0.2, 0.1, 0.05)
	look.skin_color = Color(0.7, 0.5, 0.4)
	var data := look.to_dict()
	var loaded := SessionFactory.look_from_dict(data)
	assert_eq(loaded.character_name, "Mira")
	assert_true(loaded.hair_color.is_equal_approx(look.hair_color))
	assert_true(loaded.skin_color.is_equal_approx(look.skin_color))
	var old := SessionFactory.look_from_dict({"character_name": "Old"})
	assert_eq(old.character_name, "Old")
	assert_true(old.shirt_color.is_equal_approx(LookRecord.DEFAULT_SHIRT))


func test_validator_accepts_generated_assets() -> void:
	var validator_script: Script = load("res://tools/player_equipment_validator.gd")
	assert_ne(validator_script, null)
	var report: Dictionary = validator_script.call("run")
	assert_true(bool(report["ok"]), "validator errors: " + ",".join(report["errors"]))


func test_player_scene_has_visual_controller() -> void:
	var src := FileAccess.get_file_as_string("res://scenes/player/player.tscn")
	assert_true(src.contains("player_visual_controller.gd"))
	assert_true(src.contains("use_swing"))
	assert_true(src.contains("use_mine"))
	assert_true(src.contains("use_thrust"))
	assert_true(src.contains("body_frames.tres"))
