class_name Projectile
extends Area2D

## Wiederverwendbares Projektil. Reichweite kommt von der Waffe, Flug von der Physik.

const WORLD_MASK := 1
const HURTBOX_MASK := 4

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

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = WORLD_MASK | HURTBOX_MASK
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
	if gravity_strength != 0.0:
		velocity.y += gravity_strength * delta
	position += velocity * delta
	if velocity.length_squared() > 0.0001:
		rotation = velocity.angle()
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	if max_distance > 0.0 and _spawn_origin.distance_to(global_position) >= max_distance:
		queue_free()


static func predict_arc(
		origin: Vector2,
		p_velocity: Vector2,
		p_gravity: float,
		p_max_distance: float,
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
		if p_max_distance > 0.0 and origin.distance_to(pos) >= p_max_distance:
			break
	return points


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	if body == source:
		return
	if body is TileMapLayer or body is TileMap:
		queue_free()
		return
	if body is CollisionObject2D:
		var obj := body as CollisionObject2D
		if obj.get_collision_layer_value(1):
			if not _try_hit(body):
				queue_free()
			return
	_try_hit(body)


func _try_hit(node: Node) -> bool:
	if node == null or damage <= 0:
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
