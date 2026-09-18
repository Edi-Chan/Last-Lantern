@tool
extends McpTestSuite


func suite_name() -> String:
	return "zombie"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_aaa_generate_assets() -> void:
	var gen = load("res://tools/generate_zombie_assets.gd").new()
	assert_ne(gen, null)
	gen.run()
	assert_true(FileAccess.file_exists("res://assets/enemies/zombie/idle_0.png"))
	assert_true(FileAccess.file_exists("res://audio/sfx/zombie_attack.wav"))


func test_single_zombie_scene_not_split() -> void:
	assert_true(FileAccess.file_exists("res://scenes/enemies/zombie.tscn"))
	assert_false(FileAccess.file_exists("res://scenes/enemies/normal_zombie.tscn"))
	assert_false(FileAccess.file_exists("res://scenes/enemies/dark_zombie.tscn"))
	var scene := _read("res://scenes/enemies/zombie.tscn")
	assert_true(scene.contains("scripts/enemies/zombie.gd"))
	assert_true(scene.contains("hurtbox.gd"))
	assert_true(scene.contains("enemy_hitbox.gd"))
	assert_true(scene.contains("AttackHitbox"))
	assert_true(scene.contains("DetectionArea"))
	assert_true(scene.contains("BodySmoke"))
	assert_true(scene.contains("TrailSmoke"))
	assert_true(scene.contains("AmbientParticles"))


func test_enemy_data_values() -> void:
	var data := load("res://resources/enemies/zombie_data.tres") as EnemyData
	assert_ne(data, null)
	assert_eq(data.display_name, "Zombie")
	assert_eq(data.max_health, 50)
	assert_eq(data.darkness_max_health, 150)
	assert_eq(data.attack_damage, 10.0)
	assert_eq(data.darkness_attack_damage, 20.0)
	assert_eq(data.attack_cooldown, 1.0)
	assert_true(data.darkness_move_speed > data.move_speed)
	assert_true(data.darkness_detection_range > data.detection_range)
	assert_eq(data.scaled_darkness_health(1), 150)
	assert_eq(data.scaled_darkness_health(3), 150)


func test_zombie_reuses_combat_and_fog() -> void:
	var src := _read("res://scripts/enemies/zombie.gd")
	assert_true(src.contains("func take_damage"))
	assert_true(src.contains("func apply_knockback"))
	assert_true(src.contains("fog_started"))
	assert_true(src.contains("fog_ended"))
	assert_true(src.contains("enum State"))
	assert_true(src.contains("CHASE"))
	assert_true(src.contains("ATTACK"))
	assert_true(src.contains("TRANSFORM"))
	assert_true(src.contains("_set_strike"))
	assert_true(src.contains("ATTACK_DAMAGE_FRAMES"))
	assert_true(src.contains("queue_free()"))
	assert_true(src.contains("_on_anim_finished"))
	var hit := _read("res://scripts/combat/enemy_hitbox.gd")
	assert_true(hit.contains("already_hit_targets"))
	assert_true(hit.contains("set_strike_active"))
	var dummy := _read("res://scripts/combat/combat_dummy.gd")
	assert_true(dummy.contains("func take_damage"))
	var tool := _read("res://scripts/player/tool_hitbox.gd")
	assert_true(tool.contains("get_hurtbox_owner"))
	assert_true(tool.contains("take_damage"))


func test_health_ratio_formula() -> void:
	var data := load("res://resources/enemies/zombie_data.tres") as EnemyData
	var ratio := 25.0 / 50.0
	var transformed := clampi(int(round(ratio * float(data.darkness_max_health))), 1, data.darkness_max_health)
	assert_eq(transformed, 75)
	var back := clampi(int(round(0.5 * float(data.max_health))), 1, data.max_health)
	assert_eq(back, 25)


func test_debug_and_spawner_hooks() -> void:
	var spawner := _read("res://scripts/enemies/enemy_spawner.gd")
	assert_true(spawner.contains("debug_spawn_zombie"))
	assert_true(spawner.contains("min_spawn_distance"))
	assert_true(spawner.contains("max_spawn_distance"))
	assert_true(spawner.contains("spawn_zombie_at"))
	var hud := _read("res://scenes/ui/hud.tscn")
	assert_true(hud.contains("SpawnNormalZombie"))
	assert_true(hud.contains("SpawnDarkZombie"))
	var dbg := _read("res://scripts/ui/fog_debug_controls.gd")
	assert_true(dbg.contains("_on_spawn_normal"))
	assert_true(dbg.contains("_on_spawn_dark"))
	var world := _read("res://scenes/world/world.tscn")
	assert_true(world.contains("EnemySpawner"))
	assert_true(world.contains("zombie.tscn"))


func test_animations_exist() -> void:
	var frames := load("res://resources/enemies/zombie_frames.tres") as SpriteFrames
	assert_ne(frames, null)
	for name in ["idle", "walk", "attack", "hurt", "death", "transform", "dark_idle", "dark_walk", "dark_attack", "dark_hurt", "dark_death"]:
		assert_true(frames.has_animation(name), name)
	assert_true(frames.get_frame_count("idle") >= 4)
	assert_true(frames.get_frame_count("walk") >= 6)
	assert_true(frames.get_frame_count("attack") >= 6)
	assert_true(frames.get_frame_count("hurt") >= 3)
	assert_true(frames.get_frame_count("death") >= 6)
	assert_true(FileAccess.file_exists("res://assets/enemies/zombie/idle_0.png"))
	assert_true(FileAccess.file_exists("res://assets/enemies/zombie/smoke_puff.png"))
	assert_true(FileAccess.file_exists("res://audio/sfx/zombie_attack.wav"))
