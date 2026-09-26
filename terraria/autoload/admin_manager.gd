extends Node

## Debug-Dienst. Spricht nur bestehende Last-Lantern-Systeme an. Map-Performance-Toggles.

signal menu_visibility_changed(is_open: bool)
signal modifiers_changed

const ENEMY_CATALOG_PATH := "res://resources/enemies/enemy_catalog.tres"
const ANIMAL_CATALOG_PATH := "res://resources/animals/animal_catalog.tres"
const ITEM_CATALOG_PATH := "res://resources/items/item_catalog.tres"
const CYCLE_LENGTH := 7
const PHASE_PRESETS := {
	&"morning": 0.32,
	&"noon": 0.50,
	&"evening": 0.72,
	&"night": 0.85,
}

var menu_open: bool = false
var god_mode: bool = false
var no_clip: bool = false
var ai_ignore: bool = false
var infinite_stamina: bool = false
var infinite_energy: bool = false
var freeze_ai: bool = false
var inspect_enemy: bool = false
var show_animal_ai: bool = false
var speed_multiplier: float = 1.0
var debug_spawn: Vector2 = Vector2.INF
var selected_enemy: Node = null
var perf_overlay: bool = false
var perf_map_updates: bool = true
var perf_minimap: bool = true
var perf_world_map: bool = true
var perf_discovery: bool = true
var perf_map_markers: bool = true
var perf_liquid_map: bool = true
var last_map_benchmark: String = ""
var show_weapon_debug: bool = false
var _perf_worst_ms: float = 0.0

var _saved_collision_layer: int = -1
var _saved_collision_mask: int = -1
var _saved_calendar_scale: float = 1.0
var _enemy_catalog: Resource
var _animal_catalog: Resource
var _item_catalog: ItemCatalog
var _menu: Node = null
var _hud_input_locked: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_enemy_catalog = load(ENEMY_CATALOG_PATH) as Resource
	_animal_catalog = load(ANIMAL_CATALOG_PATH) as Resource
	_item_catalog = load(ITEM_CATALOG_PATH) as ItemCatalog


func _input(event: InputEvent) -> void:
	if not is_available():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_F8:
			toggle_menu()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_F7:
			show_weapon_debug = not show_weapon_debug
			get_viewport().set_input_as_handled()


func is_available() -> bool:
	return OS.is_debug_build() or OS.has_feature("editor")


func is_menu_open() -> bool:
	return menu_open


func has_active_modifiers() -> bool:
	var day := get_day_cycle()
	var calendar_paused := day != null and day.settings != null and day.settings.time_scale <= 0.0
	return god_mode or no_clip or ai_ignore or infinite_stamina or infinite_energy \
		or freeze_ai or not is_equal_approx(speed_multiplier, 1.0) \
		or not is_equal_approx(Engine.time_scale, 1.0) \
		or calendar_paused


func active_modifier_names() -> PackedStringArray:
	var names := PackedStringArray()
	if god_mode:
		names.append("GOD MODE")
	if no_clip:
		names.append("NO CLIP")
	if ai_ignore:
		names.append("AI IGNORE")
	if infinite_stamina:
		names.append("INF STA")
	if infinite_energy:
		names.append("INF EN")
	if freeze_ai:
		names.append("AI FREEZE")
	if not is_equal_approx(speed_multiplier, 1.0):
		names.append("%.1fx SPEED" % speed_multiplier)
	return names


func register_menu(menu: Node) -> void:
	_menu = menu


func toggle_menu() -> void:
	if menu_open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	if not is_available() or menu_open:
		return
	menu_open = true
	_lock_player_world_input(true)
	menu_visibility_changed.emit(true)
	if _menu != null and _menu.has_method("show_menu"):
		_menu.call("show_menu")


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	inspect_enemy = false
	_lock_player_world_input(false)
	menu_visibility_changed.emit(false)
	if _menu != null and _menu.has_method("hide_menu"):
		_menu.call("hide_menu")


func _lock_player_world_input(locked: bool) -> void:
	_hud_input_locked = locked
	var player := get_player()
	if player == null:
		return
	if locked:
		player.world_input_enabled = false
		return
	if UIManager.is_pause_open() or UIManager.is_options_open():
		return
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and bool(inventory.visible):
		return
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("is_open") and bool(world_map.call("is_open")):
		return
	player.world_input_enabled = true


func get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func get_stats() -> PlayerStats:
	return get_tree().get_first_node_in_group("player_stats") as PlayerStats


func get_inventory() -> Inventory:
	return get_tree().get_first_node_in_group("player_inventory") as Inventory


func get_world() -> WorldGenerator:
	return get_tree().get_first_node_in_group("world_generator") as WorldGenerator


func get_day_cycle() -> DayCycle:
	return get_tree().get_first_node_in_group("day_cycle") as DayCycle


func get_fog() -> FogEvent:
	return get_tree().get_first_node_in_group("fog_event") as FogEvent


func get_enemy_spawner() -> EnemySpawner:
	return get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner


func get_animal_spawner() -> AnimalSpawner:
	return get_tree().get_first_node_in_group("animal_spawner") as AnimalSpawner


func get_save_manager() -> SaveManager:
	return get_tree().get_first_node_in_group(SaveManager.GROUP) as SaveManager


func get_item_catalog() -> ItemCatalog:
	var inventory := get_inventory()
	if inventory != null and inventory.item_catalog != null:
		return inventory.item_catalog
	return _item_catalog


func get_enemy_catalog() -> Resource:
	return _enemy_catalog


func get_animal_catalog() -> Resource:
	if _animal_catalog == null:
		_animal_catalog = load(ANIMAL_CATALOG_PATH) as Resource
	return _animal_catalog


func get_all_animals() -> Array:
	var catalog := get_animal_catalog()
	if catalog == null or not catalog.has_method("get_all"):
		return []
	return catalog.call("get_all")


func spawn_animal(definition: Resource, amount: int, mode: StringName) -> int:
	if definition == null or amount <= 0:
		return 0
	var spawner := get_animal_spawner()
	if spawner == null:
		return 0
	var manager: Node = get_tree().get_first_node_in_group(&"spawn_manager")
	var animal_id := StringName(str(definition.get("id")))
	var spawned := 0
	for i in amount:
		if manager != null and manager.has_method("can_debug_spawn_animal"):
			if not bool(manager.call("can_debug_spawn_animal")):
				break
		var pos := _spawn_position(mode) + Vector2(float(i % 5) * 18.0 - 36.0, 0.0)
		var instance := spawner.spawn_animal(animal_id, pos, true)
		if instance == null:
			continue
		if freeze_ai:
			instance.frozen = true
		spawned += 1
	return spawned


func spawn_one_of_each_animal() -> int:
	var spawner := get_animal_spawner()
	var player := get_player()
	if spawner == null or player == null:
		return 0
	var manager: Node = get_tree().get_first_node_in_group(&"spawn_manager")
	if manager != null and manager.has_method("population_snapshot"):
		var snap: Dictionary = manager.call("population_snapshot")
		var max_debug := 48
		var settings_res = manager.get("settings")
		if settings_res != null:
			max_debug = int(settings_res.max_debug_animals)
		var remaining := max_debug - int(snap.get("debug_animals", 0))
		if remaining <= 0:
			return 0
	return spawner.spawn_one_of_each(player.global_position + Vector2(48.0 * player.facing_sign, 0.0)).size()


func clear_animals() -> void:
	var spawner := get_animal_spawner()
	if spawner != null:
		spawner.clear_animals()
		return
	for node in get_tree().get_nodes_in_group("animals"):
		if node is AnimalBase:
			(node as AnimalBase).remove_silent()


func get_animal_population_stats() -> Dictionary:
	var spawner := get_animal_spawner()
	if spawner != null:
		return spawner.population_stats()
	return {"active": 0, "sleeping": 0, "flying": 0, "water": 0, "darkness": 0, "total": 0}


func get_all_items() -> Array[ItemData]:
	var catalog := get_item_catalog()
	if catalog == null:
		return []
	return catalog.get_all_items()


func get_all_enemies() -> Array:
	if _enemy_catalog == null or not _enemy_catalog.has_method("get_all"):
		return []
	return _enemy_catalog.call("get_all")


func should_block_damage() -> bool:
	return god_mode


func should_skip_stamina_drain() -> bool:
	return infinite_stamina


func should_skip_energy_drain() -> bool:
	return infinite_energy


func should_ignore_player_for_ai() -> bool:
	return ai_ignore


func get_speed_multiplier() -> float:
	return speed_multiplier


func set_god_mode(enabled: bool) -> void:
	god_mode = enabled
	modifiers_changed.emit()


func set_infinite_stamina(enabled: bool) -> void:
	infinite_stamina = enabled
	modifiers_changed.emit()


func set_infinite_energy(enabled: bool) -> void:
	infinite_energy = enabled
	modifiers_changed.emit()


func set_ai_ignore(enabled: bool) -> void:
	ai_ignore = enabled
	modifiers_changed.emit()


func set_speed_multiplier(value: float) -> void:
	speed_multiplier = maxf(value, 0.05)
	modifiers_changed.emit()


func set_no_clip(enabled: bool) -> void:
	var player := get_player()
	if enabled:
		if player != null and not no_clip:
			_saved_collision_layer = player.collision_layer
			_saved_collision_mask = player.collision_mask
			player.collision_layer = 0
			player.collision_mask = 0
		no_clip = true
	else:
		if player != null and no_clip and _saved_collision_layer >= 0:
			player.collision_layer = _saved_collision_layer
			player.collision_mask = _saved_collision_mask
		no_clip = false
		_saved_collision_layer = -1
		_saved_collision_mask = -1
	modifiers_changed.emit()


func set_freeze_ai(enabled: bool) -> void:
	freeze_ai = enabled
	for enemy in get_live_enemies():
		if "frozen" in enemy:
			enemy.frozen = enabled
	for node in get_tree().get_nodes_in_group("animals"):
		if "frozen" in node:
			node.frozen = enabled
	modifiers_changed.emit()


func reset_all_modifiers() -> void:
	set_god_mode(false)
	set_no_clip(false)
	set_ai_ignore(false)
	set_infinite_stamina(false)
	set_infinite_energy(false)
	set_freeze_ai(false)
	set_speed_multiplier(1.0)
	inspect_enemy = false
	show_animal_ai = false
	set_calendar_time_scale(1.0)
	Engine.time_scale = 1.0
	modifiers_changed.emit()


func adjust_health(delta: float) -> void:
	var stats := get_stats()
	if stats == null:
		return
	if delta >= 0.0:
		stats.heal(delta)
	else:
		stats.set_health(stats.health + delta)


func full_heal() -> void:
	var stats := get_stats()
	if stats == null:
		return
	stats.set_health(stats.max_health)
	stats.set_stamina(stats.max_stamina)
	stats.set_energy(stats.max_energy)


func kill_player() -> void:
	var stats := get_stats()
	if stats == null:
		return
	var was_god := god_mode
	god_mode = false
	stats.set_health(0.0)
	god_mode = was_god


func teleport_to_spawn() -> void:
	var player := get_player()
	var world := get_world()
	if player == null:
		return
	if debug_spawn != Vector2.INF:
		player.global_position = debug_spawn
		return
	if world != null:
		player.global_position = world.player_spawn_position


func set_debug_spawn_here() -> void:
	var player := get_player()
	if player != null:
		debug_spawn = player.global_position


func save_world() -> void:
	var saver := get_save_manager()
	if saver != null:
		saver.save_game()


func reload_world() -> void:
	var saver := get_save_manager()
	if saver != null:
		saver.load_game()


func get_world_map_data() -> WorldMapData:
	return get_tree().get_first_node_in_group("world_map_data") as WorldMapData


func reveal_full_map() -> void:
	var map_data := get_world_map_data()
	if map_data != null:
		map_data.reveal_full_map()


func reset_map_discovery() -> void:
	var map_data := get_world_map_data()
	if map_data != null:
		map_data.reset_discovery(true)


func run_map_benchmark() -> String:
	var live := get_world_map_data()
	var data := WorldMapData.new()
	data.setup_test_world(320, 180, 40)
	for x in 320:
		data.test_set_block(Vector2i(x, 40), 3, true)
	var t0 := Time.get_ticks_usec()
	data.discover_around(Vector2i(160, 38), 16)
	var partial_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var partial_count := data.discovered_count()
	data.map_flush_count = 0
	for _i in 120:
		data._process(0.016)
	var partial_flushes := data.map_flush_count
	var t1 := Time.get_ticks_usec()
	data.reveal_full_map()
	var reveal_ms := (Time.get_ticks_usec() - t1) / 1000.0
	var t2 := Time.get_ticks_usec()
	data.discover_around(Vector2i(200, 38), 16)
	var post_discover_ms := (Time.get_ticks_usec() - t2) / 1000.0
	data.map_flush_count = 0
	for _i in 120:
		data._process(0.016)
	var full_flushes := data.map_flush_count
	var save_partial := MapExploration.byte_size_for(320, 180)
	var save_full := str(data.to_save_dict()).length()
	last_map_benchmark = "Partial discover: %.2f ms (%d tiles)\nPartial hidden flushes/120: %d\nFull reveal: %.2f ms (%d tiles)\nDiscover after full: %.3f ms\nFull hidden flushes/120: %d\nSave compact: %d chars (mask would be %d bytes)\nDiscover ms live: %.2f\nFlush ms live: %.2f" % [
		partial_ms, partial_count, partial_flushes, reveal_ms, data.discovered_count(), post_discover_ms, full_flushes, save_full, save_partial,
		live.last_discover_ms if live != null else 0.0,
		live.last_flush_ms if live != null else 0.0,
	]
	return last_map_benchmark


func remove_all_drops() -> void:
	var parent := get_tree().get_first_node_in_group("item_drops")
	if parent == null:
		return
	for child in parent.get_children():
		if child is ItemDrop:
			child.queue_free()


func get_live_enemies() -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_dead") and bool(node.call("is_dead")):
			continue
		result.append(node)
	return result


func get_dropped_item_count() -> int:
	var parent := get_tree().get_first_node_in_group("item_drops")
	if parent == null:
		return 0
	var count := 0
	for child in parent.get_children():
		if child is ItemDrop:
			count += 1
	return count


func kill_all_enemies() -> void:
	for enemy in get_live_enemies():
		kill_enemy(enemy)


func remove_all_enemies() -> void:
	for enemy in get_live_enemies():
		remove_enemy(enemy)


func kill_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("take_damage"):
		var hp := 9999
		if "current_health" in enemy:
			hp = maxi(int(enemy.current_health), 1)
		elif "health" in enemy:
			hp = maxi(int(enemy.health), 1)
		enemy.call("take_damage", hp, get_player())
		return
	enemy.queue_free()


func remove_enemy(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy.has_method("remove_silent"):
		enemy.call("remove_silent")
		return
	enemy.queue_free()


func spawn_enemy(definition: Resource, amount: int, mode: StringName) -> int:
	if definition == null or amount <= 0:
		return 0
	var scene := definition.get("scene") as PackedScene
	if scene == null:
		return 0
	var spawned := 0
	var fog := get_fog()
	var darkness := fog != null and fog.state == FogEvent.State.FOG_ACTIVE
	var spawner := get_enemy_spawner()
	var enemy_id := StringName(str(definition.get("id")))
	for i in amount:
		var pos := _spawn_position(mode) + Vector2(float(i % 5) * 16.0 - 32.0, 0.0)
		var instance: Node2D
		if enemy_id == &"zombie" and spawner != null:
			var manager: Node = get_tree().get_first_node_in_group(&"spawn_manager")
			if manager != null and manager.has_method("can_debug_spawn_enemy"):
				if not bool(manager.call("can_debug_spawn_enemy")):
					break
			instance = spawner.spawn_zombie_at(pos, darkness, true, true)
		else:
			instance = scene.instantiate() as Node2D
			if instance == null:
				continue
			var parent: Node = spawner if spawner != null else _enemy_parent()
			if parent == null:
				continue
			parent.add_child(instance)
			instance.global_position = pos
		if instance == null:
			continue
		if freeze_ai and "frozen" in instance:
			instance.frozen = true
		spawned += 1
	return spawned


func _enemy_parent() -> Node:
	var world := get_world()
	if world != null:
		return world
	return get_tree().current_scene


func _spawn_position(mode: StringName) -> Vector2:
	var player := get_player()
	match mode:
		&"mouse":
			if player != null and player.has_method("get_world_mouse_position"):
				return player.get_world_mouse_position()
			return get_world_mouse_position()
		&"spawn":
			var world := get_world()
			if world != null:
				return world.player_spawn_position
		_:
			if player != null:
				return player.global_position + Vector2(48.0 * player.facing_sign, 0.0)
	return Vector2.ZERO


func get_world_mouse_position() -> Vector2:
	var player := get_player()
	if player != null:
		return player.get_world_mouse_position()
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var cam := vp.get_camera_2d() as Camera2D
	if cam == null:
		return vp.get_canvas_transform().affine_inverse() * vp.get_mouse_position()
	var view_size := vp.get_visible_rect().size
	var zoom := Vector2(maxf(cam.zoom.x, 0.0001), maxf(cam.zoom.y, 0.0001))
	return cam.get_screen_center_position() + (vp.get_mouse_position() - view_size * 0.5) / zoom


func pick_enemy_at_mouse() -> Node:
	var player := get_player()
	var space: PhysicsDirectSpaceState2D
	if player != null:
		space = player.get_world_2d().direct_space_state
	if space == null:
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_world_mouse_position()
	query.collision_mask = 4
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hits := space.intersect_point(query, 8)
	for hit in hits:
		var collider: Object = hit.get("collider")
		var node := collider as Node
		if node == null:
			continue
		if node.is_in_group("enemies"):
			selected_enemy = node
			return node
		var owner_node := node.get_parent()
		if owner_node != null and owner_node.is_in_group("enemies"):
			selected_enemy = owner_node
			return owner_node
	return null


func give_item(item_id: int, amount: int) -> bool:
	var inventory := get_inventory()
	if inventory == null or amount <= 0:
		return false
	return inventory.add_item(item_id, amount)


func give_max_stack(item: ItemData) -> bool:
	if item == null:
		return false
	return give_item(item.id, maxi(item.max_stack, 1))


func clear_inventory() -> void:
	var inventory := get_inventory()
	if inventory != null:
		inventory.clear_all()


func give_all_of(filter: Callable) -> int:
	var inventory := get_inventory()
	if inventory == null:
		return 0
	var given := 0
	for item in get_all_items():
		if item == null or not bool(filter.call(item)):
			continue
		if inventory.add_item(item.id, 1):
			given += 1
	return given


func give_items(items: Array[ItemData], amount: int) -> int:
	var inventory := get_inventory()
	if inventory == null:
		return 0
	var given := 0
	var qty := maxi(amount, 1)
	for item in items:
		if item == null:
			continue
		if inventory.add_item(item.id, qty):
			given += 1
	return given


func get_cycle_day() -> int:
	var day := get_day_cycle()
	if day == null:
		return 1
	var rem := day.current_day % CYCLE_LENGTH
	return CYCLE_LENGTH if rem == 0 else rem


func set_cycle_day(cycle: int) -> void:
	var day := get_day_cycle()
	if day == null:
		return
	cycle = clampi(cycle, 1, CYCLE_LENGTH)
	var week := int((maxi(day.current_day, 1) - 1) / float(CYCLE_LENGTH))
	day.set_day_and_time(week * CYCLE_LENGTH + cycle, day.time_of_day)


func set_phase(phase: StringName) -> void:
	var day := get_day_cycle()
	if day == null or not PHASE_PRESETS.has(phase):
		return
	day.set_day_and_time(day.current_day, float(PHASE_PRESETS[phase]))


func get_phase() -> StringName:
	var day := get_day_cycle()
	if day == null:
		return &""
	var t := day.time_of_day
	var settings := day.settings
	if settings == null:
		return &"night" if day.is_night else &"day"
	if t >= settings.night_start_time or t < settings.night_end_time:
		return &"night"
	if t >= settings.phase_evening_start:
		return &"evening"
	if t >= settings.phase_noon_start:
		return &"noon"
	return &"morning"


func set_seconds_before_night(seconds: float) -> void:
	var day := get_day_cycle()
	if day == null or day.settings == null:
		return
	var night := day.settings.night_start_time
	var frac := seconds / maxf(day.settings.day_duration, 0.001) * night
	day.set_day_and_time(day.current_day, clampf(night - frac, 0.0, 0.999))


func set_seconds_before_darkness(seconds: float) -> void:
	var day := get_day_cycle()
	if day == null or day.settings == null:
		return
	var fog := get_fog()
	if fog != null:
		fog.reset_event_guard()
	var target := maxi(day.current_day, 1)
	while not day.settings.is_fog_day(target):
		target += 1
	var start := day.settings.fog_start_time
	var frac := seconds / maxf(day.settings.day_duration, 0.001) * start
	day.set_day_and_time(target, clampf(start - frac, 0.0, 0.999))


func jump_to_darkness_night() -> void:
	var fog := get_fog()
	if fog != null:
		fog.debug_jump_to_fog_night(7)
		return
	set_cycle_day(7)
	set_phase(&"night")


func start_darkness() -> void:
	jump_to_darkness_night()


func stop_darkness() -> void:
	var fog := get_fog()
	if fog != null:
		fog.debug_end_fog()
	if get_cycle_day() == 7:
		set_cycle_day(1)


func darkness_status() -> StringName:
	var fog := get_fog()
	if fog == null:
		return &"INACTIVE"
	match fog.state:
		FogEvent.State.FOG_ACTIVE:
			return &"ACTIVE"
		FogEvent.State.WARNING:
			return &"WARNING"
		FogEvent.State.FOG_ENDING:
			return &"ENDING"
		_:
			return &"INACTIVE"


func set_engine_time_scale(value: float) -> void:
	Engine.time_scale = maxf(value, 0.01)


func set_calendar_time_scale(value: float) -> void:
	var day := get_day_cycle()
	if day == null or day.settings == null:
		return
	day.settings.time_scale = maxf(value, 0.0)
	_saved_calendar_scale = day.settings.time_scale


func pause_calendar(enabled: bool) -> void:
	var day := get_day_cycle()
	if day == null or day.settings == null:
		return
	if enabled:
		if day.settings.time_scale > 0.0:
			_saved_calendar_scale = day.settings.time_scale
		day.settings.time_scale = 0.0
	else:
		day.settings.time_scale = _saved_calendar_scale if _saved_calendar_scale > 0.0 else 1.0


func pause_game(enabled: bool) -> void:
	get_tree().paused = enabled


func set_debug_collisions(enabled: bool) -> void:
	get_tree().debug_collisions_hint = enabled


func set_debug_navigation(enabled: bool) -> void:
	get_tree().debug_navigation_hint = enabled


func current_biome() -> StringName:
	var world := get_world()
	var player := get_player()
	if world == null or player == null:
		return &""
	var tilemap := get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if tilemap == null:
		return &""
	var tile := tilemap.local_to_map(tilemap.to_local(player.global_position))
	return world.get_surface_biome(tile.x)


func item_matches(item: ItemData, query: String, filter: int) -> bool:
	if item == null:
		return false
	if filter >= 0 and int(item.category) != filter:
		return false
	if query.strip_edges().is_empty():
		return true
	var needle := query.to_lower()
	if item.display_name.to_lower().find(needle) >= 0:
		return true
	if str(item.id).find(needle) >= 0:
		return true
	if needle == "barren" and item.ore_metal_category == OreData.OreMetalCategory.REFINED_METAL:
		return true
	var cat := ItemData.get_category_display_name(item.category).to_lower()
	return cat.find(needle) >= 0


func current_weapon_name() -> String:
	var inventory := get_inventory()
	if inventory == null:
		return "-"
	var item := inventory.get_selected_item()
	if item == null:
		return "-"
	return item.display_name


func _liquid() -> LiquidSystem:
	return get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem


func toggle_liquid_simulation() -> void:
	var liquid := _liquid()
	if liquid == null:
		return
	liquid.set_simulation_enabled(not liquid.is_simulation_enabled())


func toggle_liquid_active_overlay() -> void:
	var liquid := _liquid()
	if liquid != null:
		liquid.debug_toggle_active_overlay()


func toggle_liquid_amount_overlay() -> void:
	var liquid := _liquid()
	if liquid != null:
		liquid.debug_toggle_amount_overlay()


func spawn_water_at_player() -> void:
	var liquid := _liquid()
	var player := get_player()
	if liquid == null or player == null:
		return
	var cell := liquid.world_to_cell(player.global_position)
	liquid.debug_fill_area(cell - Vector2i(2, 1), Vector2i(5, 4))


func spawn_lava_at_player() -> void:
	var liquid := _liquid()
	var player := get_player()
	if liquid == null or player == null:
		return
	var cell := liquid.world_to_cell(player.global_position)
	liquid.debug_fill_lava(cell - Vector2i(2, 1), Vector2i(5, 4))


func remove_water_at_player() -> void:
	var liquid := _liquid()
	var player := get_player()
	if liquid == null or player == null:
		return
	var cell := liquid.world_to_cell(player.global_position)
	liquid.debug_clear_area(cell - Vector2i(3, 2), Vector2i(7, 5))


func remove_liquid_at_player() -> void:
	remove_water_at_player()


func toggle_infinite_breath() -> void:
	var liquid := _liquid()
	if liquid == null:
		return
	liquid.set_debug_infinite_breath(not liquid.is_debug_infinite_breath())


func force_breath_zero() -> void:
	var player := get_player()
	if player == null:
		return
	var water := player.get_node_or_null("WaterInteraction") as WaterInteraction
	if water != null:
		water.force_breath(0.0)


func run_liquid_fall_test() -> void:
	var liquid := _liquid()
	var player := get_player()
	if liquid == null or player == null:
		return
	var cell := liquid.world_to_cell(player.global_position)
	liquid.debug_run_falling_water_test(cell.x, cell.y - 12, 12)


func run_lava_fall_test() -> void:
	var liquid := _liquid()
	var player := get_player()
	if liquid == null or player == null:
		return
	var cell := liquid.world_to_cell(player.global_position)
	liquid.debug_run_falling_lava_test(cell.x, cell.y - 12, 12)


func teleport_to_depth_layer(layer_id: int, fire_only: bool = false) -> void:
	var player := get_player()
	var world := get_world()
	if player == null or world == null or not world.has_method("find_open_cell_in_layer"):
		return
	var around_x := int(player.global_position.x / 16.0)
	var cell: Vector2i = world.call("find_open_cell_in_layer", layer_id, around_x, fire_only)
	if cell.x < 0:
		return
	player.global_position = Vector2(float(cell.x) * 16.0 + 8.0, float(cell.y + 1) * 16.0 - 1.0)


func teleport_to_deep_caves() -> void:
	teleport_to_depth_layer(DepthLayer.Id.DEEP_CAVES)


func teleport_to_danger_layer() -> void:
	teleport_to_depth_layer(DepthLayer.Id.DANGER, false)


func teleport_to_fire_region() -> void:
	teleport_to_depth_layer(DepthLayer.Id.DANGER, true)


func toggle_liquid_mass_tracking() -> void:
	var liquid := _liquid()
	if liquid != null:
		liquid.debug_toggle_mass_tracking()


func _lava() -> Lava:
	var liquid := _liquid()
	if liquid == null:
		return null
	return liquid.get_node_or_null("Lava") as Lava


func set_lava_lights_enabled(enabled: bool) -> void:
	var lava := _lava()
	if lava != null:
		lava.lights_enabled = enabled


func are_lava_lights_enabled() -> bool:
	var lava := _lava()
	return lava == null or lava.lights_enabled


func set_lava_particles_enabled(enabled: bool) -> void:
	var lava := _lava()
	if lava != null:
		lava.particles_enabled = enabled


func are_lava_particles_enabled() -> bool:
	var lava := _lava()
	return lava == null or lava.particles_enabled


func get_performance_overlay_text(compact: bool = false) -> String:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 0.001)
	_perf_worst_ms = maxf(_perf_worst_ms * 0.98, frame_ms)
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var mem_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var liquid := _liquid()
	var vis := get_tree().get_first_node_in_group("visibility_overlay")
	var renderer: LiquidRenderer = liquid.get_node_or_null("LiquidRenderer") as LiquidRenderer if liquid != null else null
	var lights := 0
	var lava := _lava()
	if lava != null:
		var light_root := lava.get_node_or_null("Visual/Light")
		if light_root != null:
			for child in light_root.get_children():
				if child is PointLight2D and child.visible:
					lights += 1
	var sim_ms := 0.0
	var active := 0
	var water := 0
	var lava_cells := 0
	var queue := 0
	var drawn := 0
	if liquid != null:
		var stats := liquid.get_debug_stats()
		sim_ms = float(stats.get("simulation_ms", 0.0))
		active = int(stats.get("active_cells", liquid.get_active_cell_count()))
		water = liquid.get_water_cell_count()
		lava_cells = liquid.get_lava_cell_count()
		queue = liquid.get_queue_size()
		if renderer != null:
			drawn = renderer.last_drawn_cells
	var vis_ms := 0.0
	if vis != null and "last_rebuild_ms" in vis:
		vis_ms = float(vis.get("last_rebuild_ms"))
	var map := get_world_map_data()
	var disc_ms := 0.0
	var flush_ms := 0.0
	var disc_pct := 0.0
	var dirty := 0
	if map != null:
		disc_ms = map.last_discover_ms
		flush_ms = map.last_flush_ms
		disc_pct = map.discovered_percent()
		dirty = map.dirty_chunk_count()
	if compact:
		return "FPS %d   %.1f ms (worst %.1f)   proc %.1f phy %.1f   vis %.1f liq %.1f\nW %d L %d act %d q %d draw %d lights %d   nodes %d obj %d   %.0f MB  dc %d\nmap disc %.2fms flush %.2fms  %.0f%% dirty %d" % [
			roundi(fps), frame_ms, _perf_worst_ms, process_ms, physics_ms, vis_ms, sim_ms,
			water, lava_cells, active, queue, drawn, lights, nodes, objects, mem_mb, draw_calls,
			disc_ms, flush_ms, disc_pct, dirty,
		]
	return "FPS:  %d     Frame:  %.1f ms     Worst:  %.1f ms\nProcess:  %.1f ms     Physics:  %.1f ms     Overlay:  %.1f ms     Liquid:  %.1f ms\nWater:  %d     Lava:  %d     Active:  %d     Queue:  %d     Drawn:  %d     Lights:  %d\nNodes:  %d     Objects:  %d     Memory:  %.0f MB     DrawCalls:  %d     Enemies:  %d     Drops:  %d\nMap Discover:  %.2f ms     Map Flush:  %.2f ms     Discovered:  %.1f %%     Dirty Chunks:  %d" % [
		roundi(fps), frame_ms, _perf_worst_ms, process_ms, physics_ms, vis_ms, sim_ms,
		water, lava_cells, active, queue, drawn, lights, nodes, objects, mem_mb, draw_calls,
		get_live_enemies().size(), get_dropped_item_count(),
		disc_ms, flush_ms, disc_pct, dirty,
	]


func get_liquid_debug_text() -> String:
	var liquid := _liquid()
	if liquid == null:
		return "[color=#8D8D9A]LiquidSystem nicht geladen.[/color]"
	var stats := liquid.get_debug_stats()
	if stats.is_empty():
		stats = {
			"active_cells": liquid.get_active_cell_count(),
			"sleeping_cells": liquid.get_sleeping_cell_count(),
			"water_cells": liquid.get_water_cell_count(),
			"queue_size": liquid.get_queue_size(),
		}
	var text := "[color=#D8D8DF]LIQUID DEBUG[/color]\nActive Cells:  %s\nSleeping Cells:  %s\nWater Cells:  %s\nLava Cells:  %s\nQueue Size:  %s\nUpdates/Tick:  %s / %s\nSim Time:  %.2f ms\nSim Rate:  %.0f Hz\nDirty Cells:  %s\nDirty Chunks:  %s" % [
		str(stats.get("active_cells", 0)),
		str(stats.get("sleeping_cells", 0)),
		str(stats.get("water_cells", 0)),
		str(stats.get("lava_cells", liquid.get_lava_cell_count() if liquid.has_method("get_lava_cell_count") else 0)),
		str(stats.get("queue_size", 0)),
		str(stats.get("updates_last_tick", 0)),
		str(stats.get("update_budget", 0)),
		float(stats.get("simulation_ms", 0.0)),
		float(stats.get("simulation_hz", 0.0)),
		str(stats.get("dirty_cells_last_tick", 0)),
		str(stats.get("dirty_chunks_last_tick", 0)),
	]
	if bool(stats.get("mass_tracking", liquid.is_debug_mass_tracking())):
		var err := bool(stats.get("mass_error", false))
		var mass_color := "#E07070" if err else "#7DCEA0"
		text += "\n[color=%s]TOTAL WATER:  %s  (delta %s)[/color]" % [
			mass_color,
			str(stats.get("total_water", liquid.get_total_water_amount())),
			str(stats.get("mass_delta", 0)),
		]
	else:
		text += "\n[color=#8D8D9A]TOTAL WATER:  off (TRACK MASS)[/color]"
	text += "\n\n" + get_map_debug_text()
	return text


func get_map_debug_text() -> String:
	var map := get_world_map_data()
	if map == null:
		return "[color=#8D8D9A]MAP PERFORMANCE:  WorldMapData nicht geladen.[/color]"
	var minimap_ui := get_tree().get_first_node_in_group("minimap_ui") as CanvasItem
	var world_map := get_tree().get_first_node_in_group("world_map_ui") as CanvasItem
	var extra := last_map_benchmark
	if extra.is_empty():
		extra = "RUN MAP BENCHMARK fuer Synthetic-Zahlen."
	return "[color=#D8D8DF]MAP PERFORMANCE[/color]\nDiscovered:  %.1f %%  (%d)\nDiscover:  %.2f ms     Paint:  %.2f ms     Flush:  %.2f ms     Reveal:  %.2f ms\nDirty Chunks:  %d     Liquid Dirty:  %d     Flushes:  %d\nTexture:  %d KB     Discovery:  %d B     Full:  %s     Revealing:  %s\nMinimap:  %s     World Map:  %s\nToggles:  mini %s  world %s  disc %s  liquid-map %s  markers %s\n%s" % [
		map.discovered_percent(),
		map.discovered_count(),
		map.last_discover_ms,
		map.last_paint_ms,
		map.last_flush_ms,
		map.last_reveal_ms,
		map.dirty_chunk_count(),
		map.dirty_liquid_count(),
		map.map_flush_count,
		int(map.map_texture_bytes() / 1024.0),
		map.discovery_byte_size(),
		str(map.full_revealed),
		str(map.is_revealing()),
		"ON" if minimap_ui != null and minimap_ui.visible else "off",
		"ON" if world_map != null and world_map.visible else "off",
		str(perf_minimap),
		str(perf_world_map),
		str(perf_discovery),
		str(perf_liquid_map),
		str(perf_map_markers),
		extra,
	]
