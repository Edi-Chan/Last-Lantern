@tool
extends McpTestSuite


func suite_name() -> String:
	return "enemy_health_bars"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_settings_health_bar_constants() -> void:
	var tres := _read("res://resources/systems/last_lantern_settings.tres")
	assert_true(tres.contains("max_visible_enemy_health_bars = 8"))
	assert_true(tres.contains("health_bar_visible_after_hit = 3.0"))
	assert_true(tres.contains("health_bar_fade_in = 0.15"))
	assert_true(tres.contains("health_bar_fade_out = 0.30"))
	assert_true(tres.contains("show_enemy_health_numbers = false"))
	var src := _read("res://scripts/systems/last_lantern_settings.gd")
	assert_true(src.contains("max_visible_enemy_health_bars"))
	assert_true(src.contains("health_bar_visible_after_hit"))
	assert_true(src.contains("show_enemy_health_numbers"))
	assert_false(src.contains("MAX_VISIBLE_ENEMY_HEALTH_BARS = 8"))


func test_priority_order() -> void:
	var aimed := EnemyHealthBarManager.display_priority(true, 10.0, false, 400.0)
	var hit := EnemyHealthBarManager.display_priority(false, 0.1, false, 400.0)
	var attack := EnemyHealthBarManager.display_priority(false, 10.0, true, 400.0)
	var near := EnemyHealthBarManager.display_priority(false, 10.0, false, 48.0)
	var far := EnemyHealthBarManager.display_priority(false, 10.0, false, 400.0)
	assert_true(aimed > hit)
	assert_true(hit > attack)
	assert_true(attack > near)
	assert_true(near > far)


func test_scripts_and_scenes_exist() -> void:
	assert_true(ResourceLoader.exists("res://scripts/ui/enemy_health_bar.gd"))
	assert_true(ResourceLoader.exists("res://scripts/ui/enemy_health_bar_manager.gd"))
	assert_true(ResourceLoader.exists("res://scripts/ui/boss_health_hud.gd"))
	var zombie := _read("res://scripts/enemies/zombie.gd")
	assert_true(zombie.contains("signal health_changed"))
	assert_true(zombie.contains("signal damage_received"))
	assert_true(zombie.contains("notify_hit"))
	assert_true(zombie.contains("HealthBarAnchor") or _read("res://scenes/enemies/zombie.tscn").contains("HealthBarAnchor"))
	assert_true(zombie.contains("func get_health_bar_world_position"))
	assert_true(zombie.contains("func is_attacking_player"))
	assert_true(zombie.contains("func is_on_screen"))
	var hud := _read("res://scripts/ui/hud.gd")
	assert_true(hud.contains("EnemyHealthBarManager"))
	assert_true(hud.contains("_ensure_enemy_health_overlay"))
	var mgr := _read("res://scripts/ui/enemy_health_bar_manager.gd")
	assert_true(mgr.contains("max_visible_bars"))
	assert_true(mgr.contains("max_visible_bars() * 2"))
	assert_true(mgr.contains("MOUSE_FILTER_IGNORE") or _read("res://scripts/ui/enemy_health_bar.gd").contains("MOUSE_FILTER_IGNORE"))
	assert_true(mgr.contains("EnemyData.Rank.BOSS"))
	assert_false(mgr.contains("SHOP MENU"))
	var bar := _read("res://scripts/ui/enemy_health_bar.gd")
	assert_true(bar.contains("MOUSE_FILTER_IGNORE"))
	var data := _read("res://scripts/enemies/enemy_data.gd")
	assert_true(data.contains("enum Rank"))
	assert_true(data.contains("BOSS"))
	assert_eq(int(EnemyData.Rank.NORMAL), 0)
	assert_eq(int(EnemyData.Rank.ELITE), 1)
	assert_eq(int(EnemyData.Rank.BOSS), 2)


func test_no_permanent_bar_on_zombie_scene() -> void:
	var scene := _read("res://scenes/enemies/zombie.tscn")
	assert_false(scene.contains("ProgressBar"))
	assert_false(scene.contains("enemy_health_bar.gd"))
	assert_true(scene.contains("HealthBarAnchor"))
	assert_true(_read("res://scripts/ui/enemy_health_bar.gd").contains("show_numbers"))


func test_manager_cap_from_settings() -> void:
	var mgr := EnemyHealthBarManager.new()
	mgr.settings = null
	assert_eq(mgr.max_visible_bars(), 8)
	assert_eq(mgr.hit_duration(), 3.0)
	assert_eq(mgr.show_numbers(), false)
	mgr.free()


func test_health_bar_control_defaults() -> void:
	var bar := EnemyHealthBar.new()
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_STOP)
	bar._ready()
	assert_eq(bar.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	bar.bind_health(25.0, 50.0, true)
	bar.bind_health(75.0, 150.0, true)
	bar.free()
	var src := _read("res://scripts/enemies/enemy_spawner.gd")
	assert_true(src.contains("func debug_spawn_horde"))


func test_read_health_tolerates_missing_fields() -> void:
	var mgr := EnemyHealthBarManager.new()
	var bare := Node.new()
	assert_eq(mgr._read_health(bare), 0.0)
	assert_eq(mgr._read_max(bare), 1.0)
	assert_eq(mgr._as_float(null, 3.0), 3.0)
	bare.free()
	mgr.free()


func test_zombie_health_signals_not_polled() -> void:
	var src := _read("res://scripts/ui/enemy_health_bar_manager.gd")
	assert_true(src.contains("health_changed.connect"))
	assert_true(src.contains("notify_hit"))
	assert_false(src.contains("current_health = enemy.current_health") and src.contains("_process") and src.contains("for zombie"))
