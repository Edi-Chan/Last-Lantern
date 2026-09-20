class_name WorldBounds
extends Node2D

## Unsichtbare Kollisionswaende an allen Weltkanten. Layer 1 = Terrain.

const GROUP := &"world_bounds"

var _bodies: Array[StaticBody2D] = []


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 0


func rebuild(world_width_px: float, world_height_px: float, sky_margin_px: float, thickness_px: float) -> void:
	_clear()
	var thickness := maxf(thickness_px, 32.0)
	var sky := maxf(sky_margin_px, 0.0)
	var total_h := world_height_px + sky + thickness * 2.0
	var total_w := world_width_px + thickness * 2.0
	_add_wall(Vector2(-thickness * 0.5, world_height_px * 0.5 - sky * 0.5), Vector2(thickness, total_h))
	_add_wall(Vector2(world_width_px + thickness * 0.5, world_height_px * 0.5 - sky * 0.5), Vector2(thickness, total_h))
	_add_wall(Vector2(world_width_px * 0.5, -sky - thickness * 0.5), Vector2(total_w, thickness))
	_add_wall(Vector2(world_width_px * 0.5, world_height_px + thickness * 0.5), Vector2(total_w, thickness))


func clamp_position(pos: Vector2, world_width_px: float, world_height_px: float, sky_margin_px: float, margin: float = 8.0) -> Vector2:
	var left := margin
	var right := world_width_px - margin
	var top := -sky_margin_px + margin
	var bottom := world_height_px - margin
	return Vector2(clampf(pos.x, left, right), clampf(pos.y, top, bottom))


func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_bodies.append(body)


func _clear() -> void:
	for body in _bodies:
		if is_instance_valid(body):
			body.queue_free()
	_bodies.clear()
