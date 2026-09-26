@tool
extends McpTestSuite


func suite_name() -> String:
	return "spawn_manager"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_spawn_manager_is_central() -> void:
	assert_true(FileAccess.file_exists("res://scripts/spawn/spawn_manager.gd"))
	assert_true(FileAccess.file_exists("res://scripts/spawn/spawn_settings.gd"))
	assert_true(FileAccess.file_exists("res://resources/systems/spawn_settings.tres"))
	var world := _read("res://scenes/world/world.tscn")
	assert_true(world.contains("SpawnManager"))
	assert_true(world.contains("spawn_manager.gd"))
	assert_true(world.contains("spawn_settings.tres"))
	var manager := _read("res://scripts/spawn/spawn_manager.gd")
	assert_true(manager.contains("class_name SpawnManager"))
	assert_true(manager.contains("Channel.ENEMY"))
	assert_true(manager.contains("Channel.ANIMAL"))
	assert_true(manager.contains("Channel.CRITTER"))
	assert_true(manager.contains("max_dynamic_entities"))
	assert_true(manager.contains("is_on_camera"))
	assert_false(manager.contains("to_save_dict"))


func test_channels_defer_to_manager() -> void:
	var animals := _read("res://scripts/animals/animal_spawner.gd")
	assert_true(animals.contains("try_spawn_natural"))
	assert_true(animals.contains("_spawn_manager()"))
	assert_true(animals.contains("TimeRule.DAY"))
	assert_true(animals.contains("not night and not darkness"))
	var enemies := _read("res://scripts/enemies/enemy_spawner.gd")
	assert_true(enemies.contains("try_spawn_natural"))
	assert_true(enemies.contains("enemy_despawn"))
	assert_true(enemies.contains("debug_spawned"))
	var zombie := _read("res://scripts/enemies/zombie.gd")
	assert_true(zombie.contains("var debug_spawned"))
	var base := _read("res://scripts/animals/animal_base.gd")
	assert_true(base.contains("func sleep_ai"))
	assert_false(base.contains("if not _uses_air_motion() and not is_on_floor()"))
	var save := _read("res://scripts/save/save_manager.gd")
	assert_false(save.contains("SpawnManager"))
	assert_false(save.contains("AnimalSpawner"))


func test_lod_rings_are_outside_spawn_near() -> void:
	var settings = load("res://resources/systems/spawn_settings.tres")
	assert_ne(settings, null)
	assert_true(float(settings.animal_min_spawn) > float(settings.animal_near))
	assert_true(float(settings.animal_sleep) < float(settings.animal_despawn))
	assert_true(float(settings.enemy_despawn) > float(settings.enemy_sleep))
	assert_true(int(settings.max_animals) <= 20)
	assert_true(int(settings.max_critters) <= 16)
	assert_true(int(settings.max_dynamic_entities) <= 40)


func test_animal_data_marks_critters() -> void:
	assert_true(_read("res://scripts/animals/animal_data.gd").contains("func is_critter"))
	assert_true(_read("res://scripts/animals/animal_data.gd").contains("\"bee\""))
	assert_true(_read("res://scripts/animals/animal_data.gd").contains("\"butterfly\""))
	assert_true(_read("res://scripts/animals/animal_spawner.gd").contains("data.is_critter()"))
	assert_true(_read("res://scripts/animals/animal_base.gd").contains("func is_critter"))
