class_name AnimalSpawner
extends Node2D

## Dynamischer Wildlife-Spawner um den Spieler. Keine permanente Weltgen-Population.
## Ambient-Tiere werden nicht gespeichert.

const TILE := 16.0
const GROUP := &"animal_spawner"

@export var settings: AnimalSettings
@export var catalog: AnimalCatalog

var _world: WorldGenerator
var _player: Player
var _fog: FogEvent
var _day: DayCycle
var _liquid: LiquidSystem
var _spawn_left: float = 4.0
var _lod_left: float = 0.2
var _initial_done: bool = false
var _idle_sounds_used: int = 0
var _idle_sound_reset: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	if settings == null:
		settings = load("res://resources/animals/animal_settings.tres") as AnimalSettings
	if catalog == null:
		catalog = load("res://resources/animals/animal_catalog.tres") as AnimalCatalog
	if settings == null:
		settings = AnimalSettings.new()
	call_deferred("_boot")


func _boot() -> void:
	_refresh_refs()
	if _spawn_manager() != null:
		return
	_place_initial()


func _process(delta: float) -> void:
	_refresh_refs()
	_idle_sound_reset -= delta
	if _idle_sound_reset <= 0.0:
		_idle_sounds_used = 0
		_idle_sound_reset = 1.0
	if _spawn_manager() != null:
		return
	_lod_left -= delta
	if _lod_left <= 0.0:
		_lod_left = settings.lod_update_interval if settings != null else 0.28
		update_lod_and_despawn()
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	_spawn_left = settings.darkness_spawn_interval if _is_darkness() else settings.animal_spawn_interval
	_try_spawn_auto()


func try_consume_idle_sound() -> bool:
	if settings == null:
		return true
	if _idle_sounds_used >= settings.max_idle_sounds:
		return false
	_idle_sounds_used += 1
	return true


func spawn_animal(animal_id: StringName, world_pos: Vector2, lock_debug: bool = false) -> AnimalBase:
	if catalog == null:
		return null
	var definition := catalog.get_by_id(animal_id)
	if definition == null:
		return null
	var scene := definition.get("scene") as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as AnimalBase
	if node == null:
		return null
	if definition.get("data") != null:
		node.data = definition.get("data") as AnimalData
	node.debug_spawned = lock_debug
	add_child(node)
	node.name = String(animal_id)
	node.global_position = world_pos
	return node


func spawn_one_of_each(origin: Vector2) -> Array:
	var spawned: Array = []
	if catalog == null:
		return spawned
	var i := 0
	for definition in catalog.get_all():
		var id := StringName(str(definition.get("id")))
		var pos := origin + Vector2(float(i) * 28.0 - 80.0, 0.0)
		var node := spawn_animal(id, pos, true)
		if node != null:
			spawned.append(node)
		i += 1
	return spawned


func clear_animals() -> void:
	for node in get_tree().get_nodes_in_group("animals"):
		if node is AnimalBase and is_instance_valid(node):
			(node as AnimalBase).remove_silent()


func population_stats() -> Dictionary:
	var active := 0
	var sleeping := 0
	var flying := 0
	var water := 0
	var darkness := 0
	for node in get_tree().get_nodes_in_group("animals"):
		var animal := node as AnimalBase
		if animal == null or not is_instance_valid(animal) or animal.is_dead():
			continue
		if animal.is_sleeping():
			sleeping += 1
		else:
			active += 1
		match animal.population_kind():
			AnimalData.Population.FLYING:
				flying += 1
			AnimalData.Population.WATER:
				water += 1
			AnimalData.Population.DARKNESS:
				darkness += 1
	return {
		"active": active,
		"sleeping": sleeping,
		"flying": flying,
		"water": water,
		"darkness": darkness,
		"critters": _count_critters(),
		"total": active + sleeping,
	}


func _place_initial() -> void:
	if _initial_done or _world == null or settings == null or catalog == null:
		return
	_initial_done = true
	if _is_darkness():
		return
	var origin := _world.player_spawn_position
	for _i in settings.initial_surface_count:
		var defn := _pick_definition(false, false)
		if defn == null:
			continue
		var data := defn.get("data") as AnimalData
		var pos := _find_spawn_point(origin, data, 14.0 * TILE, 32.0 * TILE)
		if pos != Vector2.INF:
			spawn_animal(defn.get("id"), pos, false)


func try_spawn_natural(critter: bool) -> bool:
	return _spawn_one(critter)


func _try_spawn_auto() -> void:
	if settings == null:
		return
	for _i in settings.max_spawns_per_tick:
		if not _spawn_one(false):
			return


func _spawn_one(critter: bool) -> bool:
	if _player == null or _world == null or settings == null or catalog == null:
		return false
	var stats := population_stats()
	if int(stats["total"]) >= settings.max_active_animals:
		return false
	var darkness := _is_darkness()
	var night := _is_night()
	var defn := _pick_definition(night, darkness, critter)
	if defn == null:
		return false
	var data := defn.get("data") as AnimalData
	if data == null or not _has_population_room(data, stats):
		return false
	var ring := _spawn_ring(critter)
	var pos := _find_spawn_point(_player.global_position, data, ring.x, ring.y)
	if pos == Vector2.INF:
		return false
	return spawn_animal(defn.get("id"), pos, false) != null


func _has_population_room(data: AnimalData, stats: Dictionary) -> bool:
	if int(stats["total"]) >= settings.max_active_animals:
		return false
	if data.is_critter():
		return int(stats.get("critters", 0)) < settings.max_critter_animals
	match data.population:
		AnimalData.Population.FLYING:
			return int(stats["flying"]) < settings.max_flying_animals
		AnimalData.Population.WATER:
			return int(stats["water"]) < settings.max_water_animals
		AnimalData.Population.DARKNESS:
			return int(stats["darkness"]) < settings.max_darkness_animals
		_:
			return (int(stats["total"]) - int(stats["flying"]) - int(stats["water"]) - int(stats["darkness"])) < settings.max_surface_animals


func _pick_definition(night: bool, darkness: bool, critter: bool = false) -> Resource:
	var pool: Array = []
	var weights: Array[float] = []
	var total := 0.0
	for definition in catalog.get_all():
		var data := definition.get("data") as AnimalData
		if data == null:
			continue
		if data.is_critter() != critter:
			continue
		var w := _spawn_weight(data, night, darkness)
		if w <= 0.0:
			continue
		pool.append(definition)
		weights.append(w)
		total += w
	if pool.is_empty() or total <= 0.0:
		return null
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in pool.size():
		acc += weights[i]
		if roll <= acc:
			return pool[i]
	return pool[pool.size() - 1]


func _spawn_weight(data: AnimalData, night: bool, darkness: bool) -> float:
	if not _time_allows(data, night, darkness):
		return 0.0
	if data.darkness_form and not darkness:
		return 0.0
	var w := data.spawn_weight
	if darkness:
		w = data.darkness_spawn_weight if data.darkness_spawn_weight > 0.0 else data.spawn_weight * 0.15
	elif night:
		w += data.night_spawn_bonus
	return maxf(w, 0.0)


func _time_allows(data: AnimalData, night: bool, darkness: bool) -> bool:
	match data.time_rule:
		AnimalData.TimeRule.DAY:
			return not night and not darkness
		AnimalData.TimeRule.NIGHT:
			return night or darkness
		AnimalData.TimeRule.DARKNESS:
			return darkness
		AnimalData.TimeRule.NIGHT_OR_DARKNESS:
			return night or darkness
		_:
			return true


func _find_spawn_point(origin: Vector2, data: AnimalData, min_d: float, max_d: float) -> Vector2:
	if data == null:
		return Vector2.INF
	if data.needs_water:
		return _find_water_point(origin, data, min_d, max_d)
	if data.locomotion == AnimalData.Locomotion.FLYING:
		return _find_air_point(origin, data, min_d, max_d)
	return _find_ground_point(origin, data, min_d, max_d)


func _find_ground_point(origin: Vector2, data: AnimalData, min_d: float, max_d: float) -> Vector2:
	if _world == null:
		return Vector2.INF
	for _i in 16:
		var dist := _rng.randf_range(min_d, max_d)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := origin.x + dist * side
		var tile_x := clampi(int(floor(x / TILE)), 2, _world.world_width - 3)
		if not _column_allowed(tile_x, data):
			continue
		if data.surface_only and _player_too_deep(origin) and not data.allow_cave:
			var surface := float(_world.get_surface_y(tile_x)) * TILE
			if origin.y > surface + 6.0 * TILE:
				continue
		var pos := _world.ground_world_position(tile_x)
		if pos == Vector2.INF:
			continue
		if origin.distance_to(pos) < min_d or origin.distance_to(pos) > max_d:
			continue
		if not _habitat_ok(tile_x, data):
			continue
		if data.near_water and not _near_water(pos):
			continue
		if not _is_clear(pos, data):
			continue
		if data.blocked_by_safe_zone and _inside_safe_zone(pos):
			continue
		if _liquid_blocks(pos, data):
			continue
		return pos
	return Vector2.INF


func _find_air_point(origin: Vector2, data: AnimalData, min_d: float, max_d: float) -> Vector2:
	for _i in 14:
		var dist := _rng.randf_range(min_d, max_d)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var pos := origin + Vector2(dist * side, _rng.randf_range(-80.0, -12.0))
		var tile_x := clampi(int(floor(pos.x / TILE)), 2, _world.world_width - 3)
		if not _column_allowed(tile_x, data):
			continue
		if data.surface_only and not data.allow_cave:
			var surface := float(_world.get_surface_y(tile_x)) * TILE
			if pos.y > surface + 2.0 * TILE:
				continue
		if not _habitat_ok(tile_x, data):
			continue
		if data.blocked_by_safe_zone and _inside_safe_zone(pos):
			continue
		if _world.get_block_id(tile_x, int(floor(pos.y / TILE))) != WorldGenerator.AIR:
			continue
		if _liquid_blocks(pos, data):
			continue
		return pos
	return Vector2.INF


func _find_water_point(origin: Vector2, data: AnimalData, min_d: float, max_d: float) -> Vector2:
	if _liquid == null:
		return Vector2.INF
	for _i in 20:
		var dist := _rng.randf_range(min_d, max_d)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var pos := origin + Vector2(dist * side, _rng.randf_range(-20.0, 90.0))
		var cell := _liquid.world_to_cell(pos)
		if not _liquid.has_water(cell) or _liquid.has_lava(cell):
			continue
		if _liquid.is_cell_solid(cell):
			continue
		var world_pos := Vector2((float(cell.x) + 0.5) * TILE, (float(cell.y) + 0.5) * TILE)
		if origin.distance_to(world_pos) < min_d:
			continue
		var tile_x := cell.x
		if tile_x < 2 or tile_x >= _world.world_width - 2:
			continue
		if data.blocked_by_safe_zone and _inside_safe_zone(world_pos):
			continue
		return world_pos
	return Vector2.INF


func _column_allowed(tile_x: int, data: AnimalData) -> bool:
	if _world == null:
		return false
	if _world.is_hut_column(tile_x):
		return false
	if _world.is_spawn_pad_column(tile_x):
		return false
	if _world.has_method("is_fortress_column") and _world.is_fortress_column(tile_x) and data.population != AnimalData.Population.DARKNESS:
		return false
	if data.needs_water:
		return true
	if _world.has_method("is_ocean_column") and bool(_world.call("is_ocean_column", tile_x)) and not data.near_water:
		return false
	return true


func _habitat_ok(tile_x: int, data: AnimalData) -> bool:
	if data.habitats.is_empty():
		return true
	var biome := String(_world.get_surface_biome(tile_x))
	if biome in data.habitats:
		return true
	if "water" in data.habitats and _world.has_method("is_ocean_column") and bool(_world.call("is_ocean_column", tile_x)):
		return true
	return false


func _near_water(world_pos: Vector2) -> bool:
	if _liquid == null:
		return false
	var origin := _liquid.world_to_cell(world_pos)
	for ox in range(-3, 4):
		for oy in range(-1, 3):
			if _liquid.has_water(origin + Vector2i(ox, oy)):
				return true
	return false


func _liquid_blocks(world_pos: Vector2, data: AnimalData) -> bool:
	if _liquid == null:
		return false
	var cell := _liquid.world_to_cell(world_pos)
	if _liquid.has_lava(cell):
		return true
	if data.needs_water:
		return not _liquid.has_water(cell)
	if data.locomotion == AnimalData.Locomotion.GROUND and _liquid.has_water(cell):
		return true
	return false


func _inside_safe_zone(world_pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("safe_zone"):
		var zone := node as SafeZone
		if zone != null and zone.contains_world_point(world_pos):
			return true
	return false


func _player_too_deep(origin: Vector2) -> bool:
	if _world == null:
		return false
	var tile_x := clampi(int(floor(origin.x / TILE)), 0, _world.world_width - 1)
	return origin.y > float(_world.get_surface_y(tile_x)) * TILE + 8.0 * TILE


func _is_clear(world_pos: Vector2, data: AnimalData) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var shape := RectangleShape2D.new()
	shape.size = data.collider_size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_pos + Vector2(0, -data.collider_size.y * 0.5))
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if not space.intersect_shape(query, 1).is_empty():
		return false
	if _player != null and world_pos.distance_to(_player.global_position) < 3.0 * TILE:
		return false
	var manager := _spawn_manager()
	if manager != null and manager.has_method("is_on_camera") and bool(manager.call("is_on_camera", world_pos)):
		return false
	return true


func update_lod_and_despawn() -> void:
	_update_lod_and_despawn()


func _update_lod_and_despawn() -> void:
	if _player == null or settings == null:
		return
	var origin := _player.global_position
	for node in get_tree().get_nodes_in_group("animals"):
		var animal := node as AnimalBase
		if animal == null or not is_instance_valid(animal) or animal.is_dead():
			continue
		if animal.debug_spawned:
			animal.wake_ai()
			animal.set_lod(AnimalBase.Lod.NEAR)
			continue
		var rings := _lod_ring(animal.is_critter())
		var d := origin.distance_to(animal.global_position)
		if d > rings.z:
			animal.remove_silent()
			continue
		if d > rings.y:
			animal.set_lod(AnimalBase.Lod.FAR)
			animal.sleep_ai()
		elif d > rings.x:
			animal.set_lod(AnimalBase.Lod.MEDIUM)
			animal.wake_ai()
		else:
			animal.set_lod(AnimalBase.Lod.NEAR)
			animal.wake_ai()


func _is_darkness() -> bool:
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _is_night() -> bool:
	return _day != null and _day.is_night


func _spawn_ring(critter: bool) -> Vector2:
	var spawn_settings := _spawn_settings()
	if spawn_settings == null:
		return Vector2(settings.min_spawn_distance, settings.max_spawn_distance)
	if critter:
		return Vector2(spawn_settings.critter_min_spawn, spawn_settings.critter_max_spawn)
	return Vector2(spawn_settings.animal_min_spawn, spawn_settings.animal_max_spawn)


func _lod_ring(critter: bool) -> Vector3:
	var spawn_settings := _spawn_settings()
	if spawn_settings == null:
		return Vector3(settings.animal_activation_distance, settings.animal_sleep_distance, settings.animal_despawn_distance)
	if critter:
		return Vector3(spawn_settings.critter_near, spawn_settings.critter_sleep, spawn_settings.critter_despawn)
	return Vector3(spawn_settings.animal_near, spawn_settings.animal_sleep, spawn_settings.animal_despawn)


func _count_critters() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("animals"):
		var animal := node as AnimalBase
		if animal != null and is_instance_valid(animal) and not animal.is_dead() and animal.is_critter():
			n += 1
	return n


func _spawn_manager() -> Node:
	return get_tree().get_first_node_in_group(&"spawn_manager")


func _spawn_settings() -> SpawnSettings:
	var manager := _spawn_manager()
	if manager != null and manager.get("settings") is SpawnSettings:
		return manager.get("settings") as SpawnSettings
	return null


func _refresh_refs() -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null:
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _day == null:
		_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if _liquid == null:
		_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
