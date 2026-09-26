class_name SpawnManager
extends Node2D

## Einzige natürliche Spawn-Kontrolle. EnemySpawner und AnimalSpawner sind Kanäle.

const GROUP := &"spawn_manager"

@export var settings: SpawnSettings

var _player: Player
var _fog: FogEvent
var _animals: AnimalSpawner
var _enemies: EnemySpawner
var _lod_left: float = 0.2
var _enemy_left: float = 8.0
var _animal_left: float = 3.0
var _critter_left: float = 2.5
var _initial_done: bool = false
var event_enemy_rate_scale: float = 1.0
var event_animal_rate_scale: float = 1.0
var event_critter_rate_scale: float = 1.0


func _ready() -> void:
	add_to_group(GROUP)
	if settings == null:
		settings = load("res://resources/systems/spawn_settings.tres") as SpawnSettings
	if settings == null:
		settings = SpawnSettings.new()
	call_deferred("_boot")


func _boot() -> void:
	_refresh_refs()
	_place_initial()


func _process(delta: float) -> void:
	_refresh_refs()
	if settings == null:
		return
	_lod_left -= delta
	if _lod_left <= 0.0:
		_lod_left = settings.lod_update_interval
		_update_lod()
	var dark := _is_darkness()
	_enemy_left -= delta
	_animal_left -= delta
	_critter_left -= delta
	if _enemy_left <= 0.0:
		_enemy_left = (settings.enemy_interval_darkness if dark else settings.enemy_interval_normal) / maxf(event_enemy_rate_scale, 0.05)
		_try_channel(SpawnSettings.Channel.ENEMY)
	if _animal_left <= 0.0:
		_animal_left = (settings.darkness_wildlife_interval if dark else settings.animal_interval) / maxf(event_animal_rate_scale, 0.05)
		_try_channel(SpawnSettings.Channel.ANIMAL)
	if _critter_left <= 0.0:
		_critter_left = (settings.darkness_wildlife_interval if dark else settings.critter_interval) / maxf(event_critter_rate_scale, 0.05)
		_try_channel(SpawnSettings.Channel.CRITTER)


func is_on_camera(world_pos: Vector2, margin: float = -1.0) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return false
	var pad := settings.camera_reject_margin if settings != null and margin < 0.0 else margin
	if pad < 0.0:
		pad = 72.0
	var vis := get_viewport().get_visible_rect().size
	var zoom := cam.zoom
	var half := Vector2(vis.x / (2.0 * maxf(zoom.x, 0.001)), vis.y / (2.0 * maxf(zoom.y, 0.001)))
	var center := cam.get_screen_center_position()
	return Rect2(center - half, half * 2.0).grow(pad).has_point(world_pos)


func can_debug_spawn_animal() -> bool:
	if settings == null:
		return true
	return _count_debug_animals() < settings.max_debug_animals


func can_debug_spawn_enemy() -> bool:
	if settings == null:
		return true
	return _count_debug_enemies() < settings.max_debug_enemies


func population_snapshot() -> Dictionary:
	var animals := _count_wildlife(false, false)
	var critters := _count_wildlife(true, false)
	var enemies := _count_enemies(false)
	return {
		"enemies": enemies,
		"animals": animals,
		"critters": critters,
		"debug_animals": _count_debug_animals(),
		"debug_enemies": _count_debug_enemies(),
		"total": enemies + animals + critters,
		"local_enemies": _count_enemies(true),
		"local_animals": _count_wildlife(false, true),
		"local_critters": _count_wildlife(true, true),
	}


func _place_initial() -> void:
	if _initial_done:
		return
	_initial_done = true
	_refresh_refs()
	if _is_darkness():
		return
	if _animals != null:
		for _i in settings.initial_animals:
			_animals.try_spawn_natural(false)
		for _i in settings.initial_critters:
			_animals.try_spawn_natural(true)


func _try_channel(channel: int) -> void:
	if _player == null or settings == null:
		return
	var snap := population_snapshot()
	if int(snap["total"]) >= settings.max_dynamic_entities:
		return
	match channel:
		SpawnSettings.Channel.ENEMY:
			if int(snap["enemies"]) >= settings.max_enemies:
				return
			var local_cap := settings.max_local_enemies_darkness if _is_darkness() else settings.max_local_enemies_normal
			if int(snap["local_enemies"]) >= local_cap:
				return
			if _enemies != null:
				_enemies.try_spawn_natural()
		SpawnSettings.Channel.ANIMAL:
			if int(snap["animals"]) >= settings.max_animals:
				return
			if int(snap["local_animals"]) >= settings.max_local_animals:
				return
			if _animals != null:
				_animals.try_spawn_natural(false)
		SpawnSettings.Channel.CRITTER:
			if int(snap["critters"]) >= settings.max_critters:
				return
			if int(snap["local_critters"]) >= settings.max_local_critters:
				return
			if _animals != null:
				_animals.try_spawn_natural(true)


func _update_lod() -> void:
	if _animals != null:
		_animals.update_lod_and_despawn()
	if _enemies != null:
		_enemies.update_lod_and_despawn()


func _count_wildlife(critter: bool, local_only: bool) -> int:
	var n := 0
	var origin := _player.global_position if _player != null else Vector2.ZERO
	var radius := settings.local_radius if settings != null else 1400.0
	for node in get_tree().get_nodes_in_group("animals"):
		var animal := node as AnimalBase
		if animal == null or not is_instance_valid(animal) or animal.is_dead():
			continue
		if animal.debug_spawned:
			continue
		if animal.is_critter() != critter:
			continue
		if local_only and origin.distance_to(animal.global_position) > radius:
			continue
		n += 1
	return n


func _count_enemies(local_only: bool) -> int:
	var n := 0
	var origin := _player.global_position if _player != null else Vector2.ZERO
	var radius := settings.local_radius if settings != null else 1400.0
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie == null or not is_instance_valid(zombie) or zombie.is_dead():
			continue
		if zombie.debug_spawned:
			continue
		if local_only and origin.distance_to(zombie.global_position) > radius:
			continue
		n += 1
	return n


func _count_debug_animals() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("animals"):
		var animal := node as AnimalBase
		if animal != null and is_instance_valid(animal) and animal.debug_spawned and not animal.is_dead():
			n += 1
	return n


func _count_debug_enemies() -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group("zombies"):
		var zombie := node as Zombie
		if zombie != null and is_instance_valid(zombie) and zombie.debug_spawned and not zombie.is_dead():
			n += 1
	return n


func _is_darkness() -> bool:
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _refresh_refs() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null:
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _animals == null:
		_animals = get_tree().get_first_node_in_group("animal_spawner") as AnimalSpawner
	if _enemies == null:
		_enemies = get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
