class_name EnemySpawner
extends Node2D

## Gehoert an: World/Enemies/EnemySpawner
## Einfacher Oberflaechen-Spawner. Spaetere Finsternis-Kreaturen koennen
## dieselben Distanz- und Bodenregeln nutzen.

const TILE := 16.0

@export var zombie_scene: PackedScene
@export var data: EnemyData
@export var min_spawn_distance: float = 192.0
@export var max_spawn_distance: float = 640.0
@export var max_alive_normal: int = 3
@export var max_alive_darkness: int = 6
@export var spawn_interval_normal: float = 28.0
@export var spawn_interval_darkness: float = 12.0
@export var initial_normal_count: int = 1

var _world: WorldGenerator
var _player: Player
var _fog: FogEvent
var _spawn_left: float = 6.0
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
	_place_initial()


func _process(delta: float) -> void:
	_refresh_refs()
	_spawn_left -= delta
	if _spawn_left > 0.0:
		return
	_spawn_left = spawn_interval_darkness if _is_darkness() else spawn_interval_normal
	_try_spawn_auto()


func debug_spawn_zombie(darkness: bool) -> Node2D:
	_refresh_refs()
	var pos := _debug_position(darkness)
	if pos == Vector2.INF:
		return null
	return spawn_zombie_at(pos, darkness, true)


func spawn_zombie_at(world_pos: Vector2, darkness: bool, lock_form: bool = false) -> Node2D:
	if zombie_scene == null:
		return null
	var zombie := zombie_scene.instantiate() as Zombie
	if zombie == null:
		return null
	zombie.start_in_darkness = darkness
	zombie.lock_form = lock_form
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
		var node := spawn_zombie_at(origin + offset, darkness, true)
		if node != null:
			spawned.append(node)
	return spawned


func alive_zombie_count() -> int:
	return _count_alive()


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


func _try_spawn_auto() -> void:
	if _player == null or _world == null:
		return
	var cap := max_alive_darkness if _is_darkness() else max_alive_normal
	if _count_alive() >= cap:
		return
	var pos := _find_surface_point(_player.global_position, min_spawn_distance, max_spawn_distance)
	if pos == Vector2.INF:
		return
	spawn_zombie_at(pos, _is_darkness(), false)


func _count_alive() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("zombies"):
		var z := node as Zombie
		if z != null and is_instance_valid(z) and not z.is_dead():
			n += 1
	return n


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
