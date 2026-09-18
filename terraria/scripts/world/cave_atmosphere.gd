class_name CaveAtmosphere
extends Node2D

## Gehoert an: World/Background. Fadet Himmel/Wolken und Cave-Layer nach Spielertiefe.

const FADE_TIME := 0.55

@export var shallow_start: int = 6
@export var underground_start: int = 26
@export var deep_start: int = 70

@onready var _sky: CanvasItem = $"Sky"
@onready var _far_clouds: CanvasItem = $"FarClouds"
@onready var _near_clouds: CanvasItem = $"NearClouds"
@onready var _surface_sky: CanvasItem = get_node_or_null("SurfaceSky")
@onready var _cave_layer: CanvasItem = get_node_or_null("CaveBackground")
@onready var _deep_layer: CanvasItem = get_node_or_null("DeepCaveBackground")

var _world: WorldGenerator
var _player: Player
var _blend := Vector3(1.0, 0.0, 0.0) # surface, underground, deep
var _target := Vector3(1.0, 0.0, 0.0)


func _ready() -> void:
	_world = get_parent() as WorldGenerator
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	_apply(_blend)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_target = _target_from_player()
	var t := clampf(delta / FADE_TIME, 0.0, 1.0)
	_blend.x = lerpf(_blend.x, _target.x, t)
	_blend.y = lerpf(_blend.y, _target.y, t)
	_blend.z = lerpf(_blend.z, _target.z, t)
	_apply(_blend)


func _target_from_player() -> Vector3:
	if _player == null or _world == null:
		return Vector3(1.0, 0.0, 0.0)
	var tilemap := get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if tilemap == null or tilemap.tile_set == null:
		return Vector3(1.0, 0.0, 0.0)
	var tile := tilemap.local_to_map(tilemap.to_local(_player.global_position))
	var depth := tile.y - _world.get_surface_y(tile.x)
	if depth <= 5:
		return Vector3(1.0, 0.0, 0.0)
	if depth <= underground_start:
		var u := clampf(float(depth - 5) / float(maxi(underground_start - 5, 1)), 0.0, 1.0)
		return Vector3(1.0 - u, u, 0.0)
	if depth <= deep_start:
		var d := clampf(float(depth - underground_start) / float(maxi(deep_start - underground_start, 1)), 0.0, 1.0)
		return Vector3(0.0, 1.0 - d, d)
	return Vector3(0.0, 0.0, 1.0)


func _apply(blend: Vector3) -> void:
	var surface := clampf(blend.x, 0.0, 1.0)
	var cave := clampf(blend.y, 0.0, 1.0)
	var deep := clampf(blend.z, 0.0, 1.0)
	if _sky != null:
		_sky.modulate.a = lerpf(0.0, 1.0, surface)
	if _surface_sky != null:
		_surface_sky.modulate.a = surface
		_surface_sky.visible = surface > 0.01
	if _far_clouds != null:
		_far_clouds.modulate.a = 0.65 * surface
	if _near_clouds != null:
		_near_clouds.modulate.a = surface
	if _cave_layer != null:
		_cave_layer.modulate.a = clampf(cave + deep * 0.35, 0.0, 1.0)
	if _deep_layer != null:
		_deep_layer.modulate.a = deep
