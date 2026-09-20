@tool
extends McpTestSuite


func suite_name() -> String:
	return "liquid_system"


func test_liquid_files_exist() -> void:
	assert_true(FileAccess.file_exists("res://scripts/liquid/liquid_system.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/water_generation.gd"))
	assert_true(FileAccess.file_exists("res://scripts/liquid/water_interaction.gd"))
	assert_true(FileAccess.file_exists("res://resources/systems/liquid_settings.tres"))


func test_world_integrates_liquid() -> void:
	var scene := _read("res://scenes/world/world.tscn")
	assert_true(scene.contains("LiquidSystem"))
	assert_true(scene.contains("liquid_system.gd"))
	var world_src := _read("res://scripts/world/world_generator.gd")
	assert_true(world_src.contains("_generate_water"))
	assert_true(world_src.contains("_finalize_water"))


func test_player_has_water_interaction() -> void:
	var scene := _read("res://scenes/player/player.tscn")
	assert_true(scene.contains("WaterInteraction"))
	var src := _read("res://scripts/player/player.gd")
	assert_true(src.contains("_water_movement_multipliers"))


func test_save_manager_persists_liquid() -> void:
	var src := _read("res://scripts/save/save_manager.gd")
	assert_true(src.contains('"liquid"'))
	assert_true(src.contains("liquid_system"))


func test_drowning_damage_type_exists() -> void:
	var src := _read("res://scripts/combat/damage_types.gd")
	assert_true(src.contains("DROWNING"))


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)
