class_name EnemySpawner
extends Node2D

## Gehoert an: World/Enemies/EnemySpawner
## Einfacher Oberflaechen-Spawner. Spaetere Finsternis-Kreaturen koennen
## dieselben Distanz- und Bodenregeln nutzen.

const TILE := 16.0
const LOD_INTERVAL := 0.22
const FULL_SIM_COUNT := 12
const LIGHT_CAP := 4
const PARTICLE_CAP := 6
const SLEEP_DISTANCE := 960.0

@export var zombie_scene: PackedScene
@export var data: EnemyData
@export var min_spawn_distance: float = 192.0
@export var max_spawn_distance: float = 640.0
@export var max_alive_normal: int = 4
@export var max_alive_darkness: int = 8
@export var spawn_interval_normal: float = 22.0
@export var spawn_interval_darkness: float = 10.0
@export var initial_normal_count: int = 0

var _world: WorldGenerator
var _player: Player
var _fog: FogEvent
var _spawn_left: float = 6.0
var _lod_left: float = 0.15
var _initial_done: bool = false


func _ready() -> void:
	add_to_group("enemy_spawner")
	if zombie_scene == null:
		zombie_scene = load("res://scenes/enemies/zombie.tscn") as PackedScene
	if data == null:
		data = load("res://resources/enemies/zombie_data.tres") as EnemyData
	call_deferred("_boot")


func _boot() -> void:
	_refresh_refs()
	if _spawn_manager() != null:
		return
	_place_initial()


func _process(delta: float) -> void:
	_refresh_refs()
	if _spawn_manager() != null:
		return
	_lod_left -= delta
	if _lod_left <= 0.0:
		_lod_left = LOD_INTERVAL
		update_lod_and_despawn()
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	_spawn_left = spawn_interval_darkness if _is_darkness() else spawn_interval_normal
	try_spawn_natural()


func debug_spawn_zombie(darkness: bool) -> Node2D:
	_refresh_refs()
	var pos := _debug_position(darkness)
	if pos == Vector2.INF:
		return null
	return spawn_zombie_at(pos, darkness, true, true)


func spawn_zombie_at(world_pos: Vector2, darkness: bool, lock_form: bool = false, debug_spawned: bool = false) -> Node2D:
	if zombie_scene == null:
		return null
	var zombie := zombie_scene.instantiate() as Zombie
	if zombie == null:
		return null
	zombie.start_in_darkness = darkness
	zombie.lock_form = lock_form
	zombie.debug_spawned = debug_spawned
	if data != null:
		zombie.data = data
	add_child(zombie)
	zombie.name = "Zombie"
	zombie.global_position = world_pos
	return zombie


func debug_spawn_horde(count: int, darkness: bool = false) -> Array:
	_refresh_refs()
	var spawned: Array = []
	var origin := _debug_position(darkness)
	if origin == Vector2.INF:
		return spawned
	for i in maxi(count, 0):
		var offset := Vector2(float((i % 10) - 5) * 28.0, float(i) / 10.0 * -8.0)
		var node := spawn_zombie_at(origin + offset, darkness, true, true)
		if node != null:
			spawned.append(node)
	return spawned


func alive_zombie_count() -> int:
	return _count_alive(true)


func _place_initial() -> void:
	if _initial_done or _world == null:
		return
	_initial_done = true
	if _is_darkness():
		return
	for _i in initial_normal_count:
		var pos := _find_surface_point(_world.player_spawn_position, 18.0 * TILE, 28.0 * TILE)
		if pos != Vector2.INF:
			spawn_zombie_at(pos, false, false)


func try_spawn_natural() -> bool:
	if _player == null or _world == null:
		return false
	var cap := max_alive_darkness if _is_darkness() else max_alive_normal
	if _count_alive(false) >= cap:
		return false
	var min_d := min_spawn_distance
	var max_d := max_spawn_distance
	var spawn_settings := _spawn_settings()
	if spawn_settings != null:
		min_d = spawn_settings.enemy_min_spawn
		max_d = spawn_settings.enemy_max_spawn
	var pos := _find_surface_point(_player.global_position, min_d, max_d)
	if pos == Vector2.INF:
		return false
	return spawn_zombie_at(pos, _is_darkness(), false, false) != null


func _try_spawn_auto() -> void:
	try_spawn_natural()


func _count_alive(include_debug: bool = true) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z == null or not is_instance_valid(z) or z.is_dead():
			continue
		if not include_debug and z.debug_spawned:
			continue
		n += 1
	return n


func update_lod_and_despawn() -> void:
	if _player == null:
		return
	var origin := _player.global_position
	var spawn_settings := _spawn_settings()
	var sleep_d := spawn_settings.enemy_sleep if spawn_settings != null else SLEEP_DISTANCE
	var despawn_d := spawn_settings.enemy_despawn if spawn_settings != null else SLEEP_DISTANCE * 1.75
	var zombies: Array[Zombie] = []
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie == null or not is_instance_valid(zombie) or zombie.is_dead():
			continue
		if not zombie.debug_spawned and origin.distance_to(zombie.global_position) > despawn_d:
			if not zombie.is_attacking_player():
				zombie.remove_silent()
				continue
		zombies.append(zombie)
	zombies.sort_custom(func(a: Zombie, b: Zombie) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position)
	)
	var sleep_d2 := sleep_d * sleep_d
	for i in zombies.size():
		var zombie := zombies[i]
		if zombie.debug_spawned:
			zombie.apply_crowd_budget(true, true, true, false)
			continue
		var sleep := origin.distance_squared_to(zombie.global_position) > sleep_d2 and not zombie.is_busy()
		zombie.apply_crowd_budget(i < FULL_SIM_COUNT, i < LIGHT_CAP, i < PARTICLE_CAP, sleep)


func _debug_position(_darkness: bool) -> Vector2:
	if _player == null:
		return Vector2.INF
	var origin := _player.global_position
	var dir := _player.facing_sign if _player.facing_sign != 0.0 else 1.0
	var tries: Array[float] = [5.0 * TILE * dir, 8.0 * TILE * dir, -5.0 * TILE * dir, -8.0 * TILE * dir]
	for offset in tries:
		var pos := _ground_at_x(origin.x + offset)
		if pos != Vector2.INF and origin.distance_to(pos) >= 3.0 * TILE:
			if _is_clear(pos):
				return pos
	return _find_surface_point(origin, 4.0 * TILE, 12.0 * TILE)


func _find_surface_point(origin: Vector2, min_d: float, max_d: float) -> Vector2:
	if _world == null:
		return Vector2.INF
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in 18:
		var dist := rng.randf_range(min_d, max_d)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := origin.x + dist * side
		var pos := _ground_at_x(x)
		if pos == Vector2.INF:
			continue
		var d := origin.distance_to(pos)
		if d < min_d or d > max_d:
			continue
		if not _is_clear(pos):
			continue
		return pos
	return Vector2.INF


func _ground_at_x(world_x: float) -> Vector2:
	if _world == null:
		return Vector2.INF
	var tile_x := clampi(int(floor(world_x / TILE)), 2, _world.world_width - 3)
	if _world.is_hut_column(tile_x):
		return Vector2.INF
	if _world.has_method("is_ocean_column") and bool(_world.call("is_ocean_column", tile_x)):
		return Vector2.INF
	if _world.has_method("is_spawn_pad_column") and _world.is_spawn_pad_column(tile_x):
		return Vector2.INF
	var block := _world.get_block_id(tile_x, _world.get_surface_y(tile_x) - 1)
	if block != WorldGenerator.AIR:
		return Vector2.INF
	return _world.ground_world_position(tile_x)


func _is_clear(world_pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 42)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_pos + Vector2(0, -21))
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


func _is_darkness() -> bool:
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _refresh_refs() -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null:
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent


func _spawn_manager() -> Node:
	return get_tree().get_first_node_in_group(&"spawn_manager")


func _spawn_settings() -> SpawnSettings:
	var manager := _spawn_manager()
	if manager != null and manager.get("settings") is SpawnSettings:
		return manager.get("settings") as SpawnSettings
	return null
