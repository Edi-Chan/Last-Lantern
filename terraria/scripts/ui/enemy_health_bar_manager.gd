class_name EnemyHealthBarManager
extends CanvasLayer

## Verwaltet eine begrenzte Zahl sichtbarer Gegner-HP-Leisten. Kein permanenter UI-Baum je Gegner.

const GROUP := &"enemy_health_bar_manager"

var settings: LastLanternSettings

var _entries: Dictionary = {}
var _pool: Array[EnemyHealthBar] = []
var _assigned: Dictionary = {}
var _fading: Dictionary = {}
var _aimed: Node = null
var _aim_until: float = 0.0
var _boss_hud: BossHealthHud
var _now: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	layer = 18
	follow_viewport_enabled = false
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	_build_pool()
	_ensure_boss_hud()
	set_process(true)
	call_deferred("_bind_existing")


func _bind_existing() -> void:
	for node in get_tree().get_nodes_in_group("enemy_health"):
		register_enemy(node)


func max_visible_bars() -> int:
	var n := _setting_int("max_visible_enemy_health_bars", 8)
	return maxi(n, 1)


func hit_duration() -> float:
	return _setting_float("health_bar_visible_after_hit", 3.0)


func fade_in_time() -> float:
	return _setting_float("health_bar_fade_in", 0.15)


func fade_out_time() -> float:
	return _setting_float("health_bar_fade_out", 0.30)


func aim_grace() -> float:
	return _setting_float("health_bar_aim_grace", 0.20)


func show_numbers() -> bool:
	return _setting_bool("show_enemy_health_numbers", false)


func _setting_int(key: String, fallback: int) -> int:
	if settings == null:
		return fallback
	var value = settings.get(key)
	if value == null:
		return fallback
	return int(value)


func _setting_float(key: String, fallback: float) -> float:
	if settings == null:
		return fallback
	var value = settings.get(key)
	if value == null:
		return fallback
	return float(value)


func _setting_bool(key: String, fallback: bool) -> bool:
	if settings == null:
		return fallback
	var value = settings.get(key)
	if value == null:
		return fallback
	return bool(value)


static func display_priority(aimed: bool, seconds_since_hit: float, attacking: bool, distance: float) -> float:
	var score := 0.0
	if aimed:
		score += 1_000_000.0
	if seconds_since_hit >= 0.0 and seconds_since_hit < 8.0:
		score += 500_000.0 + (8.0 - seconds_since_hit) * 1000.0
	if attacking:
		score += 100_000.0
	score += maxf(0.0, 12_000.0 - distance)
	return score


func register_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _is_boss(enemy):
		_bind_boss(enemy)
		return
	var id := enemy.get_instance_id()
	if _entries.has(id):
		return
	_entries[id] = {
		"enemy": enemy,
		"current": _read_health(enemy),
		"maximum": _read_max(enemy),
		"hit_until": 0.0,
		"last_hit": -1000.0,
		"dead": false,
	}
	if enemy.has_signal("health_changed"):
		var health_cb := _on_health_changed.bind(enemy)
		if not enemy.health_changed.is_connected(health_cb):
			enemy.health_changed.connect(health_cb)
	if enemy.has_signal("died"):
		var died_cb := _on_died.bind(enemy)
		if not enemy.died.is_connected(died_cb):
			enemy.died.connect(died_cb)
	if enemy.has_signal("form_changed"):
		var form_cb := _on_form_changed.bind(enemy)
		if not enemy.form_changed.is_connected(form_cb):
			enemy.form_changed.connect(form_cb)
	if not enemy.tree_exiting.is_connected(_on_exiting):
		enemy.tree_exiting.connect(_on_exiting.bind(enemy))


func unregister_enemy(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	_release_bar(id)
	_entries.erase(id)
	if _aimed == enemy:
		_aimed = null


func notify_hit(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy) or _is_boss(enemy):
		return
	register_enemy(enemy)
	var id := enemy.get_instance_id()
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	entry["hit_until"] = _now + hit_duration()
	entry["last_hit"] = _now
	entry["current"] = _read_health(enemy)
	entry["maximum"] = _read_max(enemy)
	_entries[id] = entry
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar != null:
		bar.bind_health(float(entry["current"]), float(entry["maximum"]), false)
	_refresh_assignment()


func _process(delta: float) -> void:
	_now += delta
	_update_aim()
	_refresh_assignment()
	_layout_bars()


func _build_pool() -> void:
	var count := max_visible_bars() * 2
	for i in count:
		var bar := EnemyHealthBar.new()
		bar.name = "EnemyHealthBar_%d" % i
		bar.show_numbers = show_numbers()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_process(false)
		add_child(bar)
		_pool.append(bar)


func _ensure_boss_hud() -> void:
	_boss_hud = BossHealthHud.new()
	_boss_hud.name = "BossHealthHud"
	add_child(_boss_hud)
	_boss_hud.hide_boss()


func _update_aim() -> void:
	var next := _enemy_under_mouse()
	if next != null:
		_aimed = next
		_aim_until = _now + aim_grace()
		register_enemy(next)
	elif _now >= _aim_until:
		_aimed = null


func _enemy_under_mouse() -> Node:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	var mouse := Vector2.ZERO
	if player.has_method("get_world_mouse_position"):
		mouse = player.call("get_world_mouse_position")
	else:
		mouse = player.get_global_mouse_position()
	var space := player.get_world_2d().direct_space_state
	if space == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse
	query.collision_mask = 4
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := space.intersect_point(query, 8)
	for hit in hits:
		var collider: Object = hit.get("collider")
		var damageable := CombatResolver.find_damageable(collider as Node)
		if damageable != null and damageable.is_in_group("enemies"):
			return damageable
	return null


func _refresh_assignment() -> void:
	var wanted: Array = []
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var player_pos := player.global_position if player != null else Vector2.ZERO
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		var enemy: Node = entry.get("enemy")
		if enemy == null or not is_instance_valid(enemy):
			_entries.erase(id)
			_release_bar(id)
			continue
		if not _wants_display(entry, enemy):
			continue
		if not _is_in_view(enemy):
			continue
		var aimed := enemy == _aimed
		var last_hit := float(entry.get("last_hit", -1000.0))
		var since_hit := _now - last_hit if last_hit > -500.0 else 999.0
		var attacking := enemy.has_method("is_attacking_player") and bool(enemy.call("is_attacking_player"))
		var dist := 9999.0
		if enemy is Node2D:
			dist = player_pos.distance_to((enemy as Node2D).global_position)
		wanted.append({
			"id": id,
			"score": display_priority(aimed, since_hit, attacking, dist),
		})
	wanted.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var keep: Dictionary = {}
	var limit := max_visible_bars()
	for i in mini(wanted.size(), limit):
		keep[wanted[i]["id"]] = true
	for id in _assigned.keys():
		if not keep.has(id):
			_fade_out_bar(id)
	for id in keep.keys():
		_bind_bar(id)


func _wants_display(entry: Dictionary, enemy: Node) -> bool:
	if bool(entry.get("dead", false)):
		return false
	if enemy == _aimed:
		return true
	if _now < float(entry.get("hit_until", 0.0)):
		return true
	return false


func _is_in_view(enemy: Node) -> bool:
	if enemy.has_method("is_on_screen"):
		return bool(enemy.call("is_on_screen"))
	if not (enemy is Node2D):
		return false
	var world: Vector2 = _anchor_of(enemy)
	var screen := get_viewport().get_canvas_transform() * world
	var rect := get_viewport().get_visible_rect().grow(12.0)
	return rect.has_point(screen)


func _bind_bar(id: int) -> void:
	_fading.erase(id)
	if _assigned.has(id):
		return
	var entry: Dictionary = _entries.get(id, {})
	var enemy: Node = entry.get("enemy")
	if enemy == null:
		return
	var bar := _acquire_bar()
	if bar == null:
		return
	_assigned[id] = bar
	_kill_bar_tween(bar)
	bar.show_numbers = show_numbers()
	bar.set_style(EnemyHealthBar.Style.ELITE if _rank(enemy) == EnemyData.Rank.ELITE else EnemyHealthBar.Style.NORMAL)
	bar.bind_health(float(entry.get("current", 0.0)), float(entry.get("maximum", 1.0)), true)
	_fade_in_bar(bar)


func _layout_bars() -> void:
	var ui := 1.0
	if SettingsManager != null and SettingsManager.has_method("get_ui_scale"):
		ui = maxf(SettingsManager.get_ui_scale(), 0.001)
	for id in _assigned.keys():
		var bar: EnemyHealthBar = _assigned[id]
		var entry: Dictionary = _entries.get(id, {})
		var enemy: Node = entry.get("enemy")
		if bar == null or enemy == null or not is_instance_valid(enemy):
			continue
		var world := _anchor_of(enemy)
		var screen := get_viewport().get_canvas_transform() * world
		bar.position = screen / ui - Vector2(bar.size.x * 0.5, bar.size.y + 2.0)


func _anchor_of(enemy: Node) -> Vector2:
	if enemy.has_method("get_health_bar_world_position"):
		return enemy.call("get_health_bar_world_position")
	if enemy is Node2D:
		return (enemy as Node2D).global_position + Vector2(0, -56)
	return Vector2.ZERO


func _on_health_changed(current: float, maximum: float, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _is_boss(enemy):
		if _boss_hud != null:
			var n := str(enemy.get("data").display_name) if enemy.get("data") != null else "Boss"
			_boss_hud.show_boss(n, current, maximum)
		return
	var id := enemy.get_instance_id()
	if not _entries.has(id):
		register_enemy(enemy)
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	entry["current"] = current
	entry["maximum"] = maximum
	_entries[id] = entry
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar != null:
		bar.bind_health(current, maximum, false)


func _on_died(enemy: Node) -> void:
	if enemy == null:
		return
	var id := enemy.get_instance_id()
	if _entries.has(id):
		var entry: Dictionary = _entries[id]
		entry["current"] = 0.0
		entry["dead"] = true
		_entries[id] = entry
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar != null:
		bar.bind_health(0.0, _read_max(enemy), true)
	_fade_out_bar(id)


func _on_form_changed(_darkness: bool, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	if not _entries.has(id):
		return
	var entry: Dictionary = _entries[id]
	entry["current"] = _read_health(enemy)
	entry["maximum"] = _read_max(enemy)
	_entries[id] = entry
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar != null:
		bar.bind_health(float(entry["current"]), float(entry["maximum"]), true)


func _on_exiting(enemy: Node) -> void:
	if enemy.has_signal("health_changed"):
		var health_cb := _on_health_changed.bind(enemy)
		if enemy.health_changed.is_connected(health_cb):
			enemy.health_changed.disconnect(health_cb)
	unregister_enemy(enemy)


func _acquire_bar() -> EnemyHealthBar:
	for bar in _pool:
		if not _assigned.values().has(bar):
			return bar
	return null


func _release_bar(id: int) -> void:
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar == null:
		return
	bar.visible = false
	bar.modulate.a = 0.0
	bar.set_process(false)
	_assigned.erase(id)
	_fading.erase(id)


func _kill_bar_tween(bar: EnemyHealthBar) -> void:
	if bar == null or not bar.has_meta("hb_tween"):
		return
	var tw := bar.get_meta("hb_tween") as Tween
	if tw != null and is_instance_valid(tw) and tw.is_valid():
		tw.kill()
	bar.remove_meta("hb_tween")


func _fade_in_bar(bar: EnemyHealthBar) -> void:
	_kill_bar_tween(bar)
	bar.visible = true
	bar.set_process(true)
	var tween := bar.create_tween()
	bar.set_meta("hb_tween", tween)
	tween.tween_property(bar, "modulate:a", 1.0, fade_in_time())


func _fade_out_bar(id: int) -> void:
	if _fading.has(id):
		return
	var bar: EnemyHealthBar = _assigned.get(id)
	if bar == null:
		return
	_fading[id] = true
	_kill_bar_tween(bar)
	var tween := bar.create_tween()
	bar.set_meta("hb_tween", tween)
	tween.tween_property(bar, "modulate:a", 0.0, fade_out_time())
	tween.finished.connect(func():
		_fading.erase(id)
		if _assigned.get(id) == bar:
			_release_bar(id)
	)


func _read_health(enemy: Node) -> float:
	if enemy.has_method("get_health_current"):
		return float(enemy.call("get_health_current"))
	return float(enemy.get("current_health"))


func _read_max(enemy: Node) -> float:
	if enemy.has_method("get_health_max"):
		return float(enemy.call("get_health_max"))
	return float(enemy.get("max_health"))


func _rank(enemy: Node) -> int:
	if enemy.has_method("get_health_bar_rank"):
		return int(enemy.call("get_health_bar_rank"))
	var data = enemy.get("data")
	if data != null:
		return int(data.get("rank"))
	return EnemyData.Rank.NORMAL


func _is_boss(enemy: Node) -> bool:
	return _rank(enemy) == EnemyData.Rank.BOSS


func _bind_boss(enemy: Node) -> void:
	if enemy.has_signal("health_changed") and not enemy.health_changed.is_connected(_on_health_changed):
		enemy.health_changed.connect(_on_health_changed.bind(enemy))
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_boss_died):
		enemy.died.connect(_on_boss_died.bind(enemy))


func _on_boss_died(enemy: Node) -> void:
	if _boss_hud != null:
		_boss_hud.hide_boss()
	if enemy != null and enemy.has_signal("died") and enemy.died.is_connected(_on_boss_died):
		enemy.died.disconnect(_on_boss_died)
