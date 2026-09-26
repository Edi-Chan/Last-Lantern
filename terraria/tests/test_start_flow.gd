@tool
extends McpTestSuite


func suite_name() -> String:
	return "start_flow"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_start_scenes_exist() -> void:
	assert_true(FileAccess.file_exists("res://scenes/ui/main_menu.tscn"))
	assert_true(FileAccess.file_exists("res://scenes/ui/character_creator.tscn"))
	assert_true(FileAccess.file_exists("res://scenes/ui/game_intro.tscn"))
	assert_true(FileAccess.file_exists("res://scenes/ui/world_loading_screen.tscn"))
	assert_true(FileAccess.file_exists("res://scenes/main/main.tscn"))
	assert_true(FileAccess.file_exists("res://scripts/game/start/game_session_flow.gd"))
	assert_true(FileAccess.file_exists("res://scripts/game/start/session_factory.gd"))
	assert_true(FileAccess.file_exists("res://scripts/game/start/look_record.gd"))


func test_main_scene_is_menu() -> void:
	var project := _read("res://project.godot")
	assert_true(project.contains("run/main_scene=\"res://scenes/ui/main_menu.tscn\""))
	assert_true(project.contains("GameFlow=\"*res://scripts/game/start/game_session_flow.gd\""))
	assert_true(FileAccess.file_exists("res://scenes/main/main.tscn"))


func test_no_difficulty_selection() -> void:
	for path in [
		"res://scripts/ui/start/main_menu_screen.gd",
		"res://scripts/ui/start/character_creator_screen.gd",
		"res://scripts/game/start/game_session_flow.gd",
		"res://scripts/game/start/session_factory.gd",
		"res://scenes/ui/main_menu.tscn",
	]:
		var src := _read(path)
		assert_false(src.contains("Easy"))
		assert_false(src.contains("Hard"))
		assert_false(src.contains("Brutal"))
		assert_false(src.contains("Difficulty"))


func test_appearance_only_uses_real_player_fields() -> void:
	var src := _read("res://scripts/game/start/look_record.gd")
	assert_true(src.contains("character_name"))
	assert_true(src.contains("hair_style"))
	assert_true(src.contains("hair_color"))
	assert_true(src.contains("skin_color"))
	assert_true(src.contains("shirt_color"))
	assert_true(src.contains("pants_color"))
	assert_false(src.contains("hair_id"))
	assert_false(src.contains("shirt_id"))
	var creator := _read("res://scripts/ui/start/character_creator_screen.gd")
	assert_true(creator.contains("resources/player/player_frames.tres"))
	assert_true(creator.contains("idle"))
	assert_true(creator.contains("walk"))


func test_character_name_validation() -> void:
	var appearance := LookRecord.new()
	appearance.character_name = "   "
	assert_false(appearance.is_valid())
	appearance.character_name = "  Mira  "
	assert_true(appearance.is_valid())
	assert_eq(appearance.character_name, "Mira")
	appearance.character_name = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	appearance.normalize()
	assert_eq(appearance.character_name.length(), LookRecord.NAME_MAX_LENGTH)


func test_new_game_creates_nonzero_seed() -> void:
	var appearance := LookRecord.new()
	appearance.character_name = "Test"
	var session := SessionFactory.create_session(appearance)
	assert_ne(session, null)
	assert_ne(session.world_seed, 0)
	assert_eq(session.appearance.character_name, "Test")


func test_save_manager_keeps_seed_and_character() -> void:
	var src := _read("res://scripts/save/save_manager.gd")
	assert_true(src.contains("world_seed"))
	assert_true(src.contains("character"))
	assert_true(src.contains("map_discovery"))
	assert_true(src.contains("func read_payload"))
	assert_true(src.contains("func has_valid_save"))
	assert_true(src.contains("character_name"))


func test_bare_hands_can_punch_and_harvest() -> void:
	var interaction := _read("res://scripts/player/player_interaction.gd")
	assert_true(interaction.contains("func _start_bare_hand_swing"))
	assert_true(interaction.contains("BARE_HAND_DAMAGE"))
	assert_true(interaction.contains("_item_can_swing"))
	var block := _read("res://scripts/world/block_data.gd")
	assert_true(block.contains("func allows_bare_hands"))
	var trees := _read("res://scripts/world/tree_data.gd")
	assert_true(trees.contains("func can_fell_with"))


func test_inventory_can_skip_start_loadout() -> void:
	var src := _read("res://scripts/inventory/inventory.gd")
	assert_true(src.contains("func _should_give_start_loadout"))
	assert_true(src.contains("skip_start_loadout"))
	assert_true(src.contains("_give_demo_tools_once"))
	assert_true(src.contains("func give_new_game_start_items"))
	assert_true(src.contains("NEW_GAME_HOTBAR_ITEM_IDS"))
	var flow := _read("res://scripts/game/start/game_session_flow.gd")
	assert_true(flow.contains("give_new_game_start_items"))


func test_world_generator_uses_pending_seed() -> void:
	var src := _read("res://scripts/world/world_generator.gd")
	assert_true(src.contains("func _apply_pending_seed"))
	assert_true(src.contains("resolve_world_seed"))
	assert_true(src.contains("resolve_world_size"))
	assert_true(src.contains("func generate_world"))
	assert_true(src.contains("func find_spawn_position"))


func test_new_game_stores_world_size() -> void:
	var appearance := LookRecord.new()
	appearance.character_name = "Test"
	var session := SessionFactory.create_session(appearance, WorldSize.Id.SMALL)
	assert_eq(session.world_size, WorldSize.Id.SMALL)
	var src := _read("res://scripts/ui/start/character_creator_screen.gd")
	assert_true(src.contains("Weltgröße") or src.contains("Weltgroesse") or src.contains("_setup_world_size"))
	assert_true(src.contains("WorldSize.Id.SMALL"))
	var flow := _read("res://scripts/game/start/game_session_flow.gd")
	assert_true(flow.contains("resolve_world_size"))
	assert_true(flow.contains("remember_generated_world_size"))
	var save := _read("res://scripts/save/save_manager.gd")
	assert_true(save.contains("world_size"))


func test_enemy_spawner_keeps_safe_distance() -> void:
	var src := _read("res://scripts/enemies/enemy_spawner.gd")
	assert_true(src.contains("min_spawn_distance"))
	assert_true(src.contains("initial_normal_count"))
	assert_true(src.contains("_place_initial"))
	assert_true(src.contains("18.0 * TILE"))


func test_intro_uses_real_systems() -> void:
	var src := _read("res://scripts/ui/start/story_catalog.gd")
	assert_true(src.contains("Finsternis"))
	assert_true(src.contains("Laterne"))
	assert_true(src.contains("Tag 7") or src.contains("sieben Tage"))
	assert_false(src.contains("Easy"))
	var slides := StoryCatalog.slides()
	assert_true(slides.size() >= 3)
	assert_true(slides.size() <= 5)


func test_pause_returns_to_menu() -> void:
	var pause := _read("res://scripts/ui/pause_menu.gd")
	assert_true(pause.contains("return_to_main_menu"))
	var scene := _read("res://scenes/ui/pause_menu.tscn")
	assert_true(scene.contains("Hauptmen"))
	assert_true(FileAccess.file_exists("res://scenes/main/main.tscn"))
