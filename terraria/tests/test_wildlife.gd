@tool
extends McpTestSuite


func suite_name() -> String:
	return "wildlife"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_aaa_generate_assets() -> void:
	var gen = load("res://tools/generate_animal_assets.gd").new()
	assert_ne(gen, null)
	gen.run()
	assert_true(FileAccess.file_exists("res://assets/animals/rabbit/idle_0.png"))
	assert_true(FileAccess.file_exists("res://resources/animals/animal_catalog.tres"))
	assert_true(FileAccess.file_exists("res://resources/animals/animal_settings.tres"))
	assert_true(FileAccess.file_exists("res://audio/sfx/animals/chirp.wav"))


func test_all_twenty_four_animals_exist() -> void:
	var ids := [
		"rabbit", "deer", "boar", "wolf", "fox", "squirrel", "rat", "chicken",
		"bird", "duck", "frog", "fish", "bee", "butterfly", "snail", "hedgehog",
		"raven", "bat", "shadow_deer", "dark_wolf", "moth", "firefly", "dark_frog", "corrupted_boar",
	]
	assert_eq(ids.size(), 24)
	for id in ids:
		assert_true(FileAccess.file_exists("res://scenes/animals/%s/%s.tscn" % [id, id]), id + " scene")
		assert_true(FileAccess.file_exists("res://scripts/animals/%s.gd" % id), id + " script")
		assert_true(FileAccess.file_exists("res://resources/animals/%s_data.tres" % id), id + " data")
		assert_true(FileAccess.file_exists("res://resources/animals/%s_frames.tres" % id), id + " frames")
		assert_true(FileAccess.file_exists("res://assets/animals/%s/idle_0.png" % id), id + " sprite")
		var scene := _read("res://scenes/animals/%s/%s.tscn" % [id, id])
		assert_true(scene.contains("scripts/animals/%s.gd" % id), id + " scene script")
		assert_true(scene.contains("AnimatedSprite2D"), id + " sprite node")
		assert_true(scene.contains("CollisionShape2D"), id + " collision")
		assert_true(scene.contains("hurtbox.gd"), id + " hurtbox")
		assert_true(scene.contains("AudioStreamPlayer2D"), id + " audio")
		assert_false(scene.contains("ItemDrop"), id + " no drops")
		var script := _read("res://scripts/animals/%s.gd" % id)
		assert_true(script.contains("extends AnimalBase"), id + " extends")


func test_catalog_and_settings() -> void:
	assert_true(FileAccess.file_exists("res://resources/animals/animal_catalog.tres"))
	var catalog_text := _read("res://resources/animals/animal_catalog.tres")
	assert_true(catalog_text.contains("script_class=\"AnimalCatalog\""))
	assert_eq(catalog_text.count("_def.tres"), 24)
	assert_true(catalog_text.contains("rabbit_def.tres"))
	assert_true(catalog_text.contains("dark_wolf_def.tres"))
	var catalog = load("res://resources/animals/animal_catalog.tres")
	assert_ne(catalog, null)
	if catalog.has_method("get_all"):
		assert_eq(catalog.get_all().size(), 24)
		assert_ne(catalog.get_by_id(&"rabbit"), null)
		assert_ne(catalog.get_by_id(&"dark_wolf"), null)
	var settings = load("res://resources/animals/animal_settings.tres")
	assert_ne(settings, null)
	assert_true(int(settings.max_active_animals) <= 50)
	assert_true(float(settings.min_spawn_distance) > 0.0)
	assert_true(float(settings.animal_despawn_distance) > float(settings.animal_sleep_distance))
	var wolf_scene := _read("res://scenes/animals/wolf/wolf.tscn")
	assert_true(wolf_scene.find("[sub_resource type=\"RectangleShape2D\" id=\"RectangleShape2D_hit\"]") < wolf_scene.find("[node name=\"Wolf\""))
	assert_true(wolf_scene.contains("AttackHitbox"))


func test_reuses_existing_systems() -> void:
	var base := _read("res://scripts/animals/animal_base.gd")
	assert_true(base.contains("func take_damage"))
	assert_true(base.contains("func apply_damage_event"))
	assert_true(base.contains("func apply_knockback"))
	assert_true(base.contains("DamageEvent"))
	assert_true(base.contains("CombatTextSystem"))
	assert_true(base.contains("Hurtbox"))
	assert_true(base.contains("LiquidSystem"))
	assert_true(base.contains("FogEvent"))
	assert_true(base.contains("sleep_ai"))
	assert_true(base.contains("queue_free()"))
	assert_false(base.contains("ItemDrop"))
	assert_false(base.contains("loot"))
	assert_false(base.contains("NavigationServer"))
	var spawner := _read("res://scripts/animals/animal_spawner.gd")
	assert_true(spawner.contains("get_surface_biome"))
	assert_true(spawner.contains("has_water"))
	assert_true(spawner.contains("has_lava"))
	assert_true(spawner.contains("safe_zone"))
	assert_true(spawner.contains("animal_despawn_distance"))
	assert_false(spawner.contains("ItemDrop"))


func test_animations_and_data() -> void:
	var rabbit = load("res://resources/animals/rabbit_frames.tres")
	assert_ne(rabbit, null)
	for name in ["idle", "walk", "run", "jump", "hurt", "death"]:
		assert_true(rabbit.has_animation(name), name)
	var fish = load("res://resources/animals/fish_frames.tres")
	assert_true(fish.has_animation("swim"))
	var bird = load("res://resources/animals/bird_frames.tres")
	assert_true(bird.has_animation("fly"))
	var wolf_data = load("res://resources/animals/wolf_data.tres")
	assert_eq(int(wolf_data.temperament), 3)
	assert_eq(bool(wolf_data.can_attack), true)
	var rabbit_data = load("res://resources/animals/rabbit_data.tres")
	assert_eq(bool(rabbit_data.hop_locomotion), true)
	assert_eq(int(rabbit_data.temperament), 1)
	var firefly = load("res://resources/animals/firefly_data.tres")
	assert_eq(bool(firefly.glow), true)
	assert_eq(int(firefly.time_rule), 4)
	var moth = load("res://resources/animals/moth_data.tres")
	assert_eq(bool(moth.attracted_to_light), true)
	var dark_wolf = load("res://resources/animals/dark_wolf_data.tres")
	assert_eq(bool(dark_wolf.blocked_by_safe_zone), true)
	assert_eq(bool(dark_wolf.darkness_form), true)


func test_world_and_admin_hooks() -> void:
	var world := _read("res://scenes/world/world.tscn")
	assert_true(world.contains("AnimalSpawner"))
	assert_true(world.contains("SpawnManager"))
	assert_true(world.contains("animal_spawner.gd"))
	assert_true(world.contains("animal_catalog.tres"))
	var admin := _read("res://scripts/ui/admin_menu.gd")
	assert_true(admin.contains("ANIMALS"))
	assert_true(admin.contains("SPAWN ONE OF EACH"))
	assert_true(admin.contains("CLEAR ANIMALS"))
	assert_true(admin.contains("SHOW ANIMAL AI"))
	var mgr := _read("res://autoload/admin_manager.gd")
	assert_true(mgr.contains("spawn_animal"))
	assert_true(mgr.contains("clear_animals"))
	assert_true(mgr.contains("show_animal_ai"))
	assert_true(mgr.contains("get_animal_population_stats"))


func test_no_loot_or_items_added() -> void:
	var base := _read("res://scripts/animals/animal_base.gd")
	assert_false(base.contains("add_item"))
	assert_false(base.contains("ItemData"))
	assert_false(base.contains("drop_item"))
	var spawner := _read("res://scripts/animals/animal_spawner.gd")
	assert_false(spawner.contains("to_save_dict"))
	var save := _read("res://scripts/save/save_manager.gd")
	assert_false(save.contains("AnimalSpawner"))
