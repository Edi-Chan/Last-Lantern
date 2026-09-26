class_name Projectile
extends Area2D

## Wiederverwendbares Projektil. Gleichmaessiger Bogen von Anfang an, bis Welt oder Gegner.

const WORLD_MASK := 1
const HURTBOX_MASK := 4
const PLATFORM_MASK := 32
const STUCK_LIFETIME := 2.4


var velocity: Vector2 = Vector2.ZERO
var damage: int = 0
var knockback_force: float = 0.0
var source: Node2D
var weapon_data: WeaponData
var lifetime: float = 4.0
var gravity_strength: float = 0.0
var max_distance: float = 0.0
var already_hit: Array = []
var _spawn_origin: Vector2 = Vector2.ZERO
var _origin_set: bool = false
var _stuck: bool = false

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = WORLD_MASK | HURTBOX_MASK | PLATFORM_MASK
	if not _origin_set:
		_spawn_origin = global_position
		_origin_set = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(
		p_velocity: Vector2,
		p_damage: int,
		p_knockback: float,
		p_source: Node2D,
		p_weapon: WeaponData,
		p_texture: Texture2D = null,
		p_lifetime: float = 4.0,
		p_gravity: float = 0.0,
		p_max_distance: float = 0.0
	) -> void:
	velocity = p_velocity
	damage = p_damage
	knockback_force = p_knockback
	source = p_source
	weapon_data = p_weapon
	lifetime = p_lifetime
	gravity_strength = p_gravity
	max_distance = p_max_distance
	_stuck = false
	rotation = velocity.angle()
	_spawn_origin = global_position
	_origin_set = true
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if p_texture != null:
			_sprite.texture = p_texture


func _physics_process(delta: float) -> void:
	if _stuck:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
		return
	if gravity_strength != 0.0:
		velocity.y += gravity_strength * delta
	var from := global_position
	var motion := velocity * delta
	var hit := _cast_motion(from, motion)
	if not hit.is_empty():
		_resolve_cast_hit(hit, motion)
		return
	global_position = from + motion
	if velocity.length_squared() > 0.0001:
		rotation = velocity.angle()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _stick(at: Vector2) -> void:
	_stuck = true
	global_position = at
	velocity = Vector2.ZERO
	monitoring = false
	lifetime = STUCK_LIFETIME


func _cast_motion(from: Vector2, motion: Vector2) -> Dictionary:
	if motion.length_squared() < 0.0001:
		return {}
	var space := get_world_2d()
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters2D.create(from, from + motion)
	query.collision_mask = WORLD_MASK | HURTBOX_MASK | PLATFORM_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if source is CollisionObject2D:
		query.exclude = [(source as CollisionObject2D).get_rid()]
	return space.direct_space_state.intersect_ray(query)


func _resolve_cast_hit(hit: Dictionary, motion: Vector2) -> void:
	var collider := hit.get("collider") as Node
	if collider == null or collider == source:
		global_position += motion
		return
	var impact: Vector2 = hit.get("position", global_position)
	if motion.length_squared() > 0.0001:
		impact -= motion.normalized() * 1.5
	if _is_world_collider(collider):
		_stick(impact)
		return
	global_position = impact
	if not _try_hit(collider):
		_stick(impact)


static func velocity_to_hit(origin: Vector2, target: Vector2, speed: float, gravity: float) -> Vector2:
	var offset := target - origin
	var dist := offset.length()
	var launch_speed := maxf(speed, 1.0)
	var travel := maxf(dist / launch_speed, 0.02)
	return offset / travel - Vector2(0.0, 0.5 * gravity * travel)


static func predict_arc(
		origin: Vector2,
		p_velocity: Vector2,
		p_gravity: float,
		_p_max_distance: float,
		delta: float = 1.0 / 60.0,
		max_steps: int = 96
	) -> PackedVector2Array:
	var points := PackedVector2Array()
	var pos := origin
	var vel := p_velocity
	points.append(pos)
	for _i in max_steps:
		if p_gravity != 0.0:
			vel.y += p_gravity * delta
		pos += vel * delta
		points.append(pos)
	return points


func _on_area_entered(area: Area2D) -> void:
	if _stuck:
		return
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	if _stuck or body == source:
		return
	if _is_world_collider(body):
		_stick(global_position)
		return
	if not _try_hit(body) and body is CollisionObject2D:
		var obj := body as CollisionObject2D
		if obj.get_collision_layer_value(1) or obj.get_collision_layer_value(6):
			_stick(global_position)


func _is_world_collider(node: Node) -> bool:
	if node is TileMapLayer or node is TileMap:
		return true
	if node is CollisionObject2D:
		var obj := node as CollisionObject2D
		if obj.get_collision_layer_value(1) or obj.get_collision_layer_value(6):
			return CombatResolver.find_damageable(node) == null
	return false


func _try_hit(node: Node) -> bool:
	if node == null or damage <= 0 or _stuck:
		return false
	var target := CombatResolver.find_damageable(node)
	if target == null or target == source or target in already_hit:
		return false
	already_hit.append(target)
	var resolved := CombatResolver.resolve_damage(damage, weapon_data, target)
	CombatResolver.apply_hit(target, resolved, knockback_force, source, weapon_data)
	if source != null and source.has_method("play_sfx"):
		source.call("play_sfx", &"ArrowImpact")
	queue_free()
	return true
