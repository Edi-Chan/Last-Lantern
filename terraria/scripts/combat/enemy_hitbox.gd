class_name EnemyHitbox
extends Area2D

## Gehoert an: Gegner/AttackHitbox. Nur waehrend des Damage-Frames aktiv.
## Kein permanenter Kontaktschaden.

var already_hit_targets: Array = []
var _damage: float = 0.0
var _source: Node2D


func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func begin_attack(damage: float, source: Node2D) -> void:
	already_hit_targets.clear()
	_damage = damage
	_source = source


func set_strike_active(active: bool) -> void:
	if monitoring == active:
		return
	monitoring = active
	if not active:
		already_hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	if node == null or _damage <= 0.0:
		return
	var target := _find_damageable(node)
	if target == null or target in already_hit_targets:
		return
	if target == _source:
		return
	already_hit_targets.append(target)
	target.take_damage(_damage, _source)


func _find_damageable(node: Node) -> Node:
	var current := node
	for _i in 4:
		if current == null:
			break
		if current.has_method("get_hurtbox_owner"):
			current = current.get_hurtbox_owner()
			continue
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null
