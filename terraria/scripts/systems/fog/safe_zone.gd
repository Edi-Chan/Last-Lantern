class_name SafeZone
extends Area2D

## Gameplay-Schutzradius. Visuals nutzen dieselben Werte, entscheiden aber nicht über Schaden.

signal radius_changed(radius_pixels: float)
signal active_changed(is_active: bool)

@export var tile_size: int = 16
@export var radius_tiles: float = 22.0
@export var zone_active: bool = true

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("safe_zone")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	_sync_shape()


func is_active() -> bool:
	return zone_active


func set_zone_active(value: bool) -> void:
	if zone_active == value:
		return
	zone_active = value
	active_changed.emit(zone_active)


func set_radius_tiles(tiles: float, size_px: int = -1) -> void:
	radius_tiles = maxf(tiles, 0.0)
	if size_px > 0:
		tile_size = size_px
	_sync_shape()
	radius_changed.emit(get_radius_pixels())


func get_radius_pixels() -> float:
	return radius_tiles * float(tile_size)


func contains_world_point(world_position: Vector2) -> bool:
	if not zone_active:
		return false
	return global_position.distance_to(world_position) <= get_radius_pixels()


func _sync_shape() -> void:
	if _shape == null:
		return
	var circle := _shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		_shape.shape = circle
	circle.radius = get_radius_pixels()
