class_name ToolHitbox
extends Area2D

## Gehoert an: Player/ToolPivot/ToolArm/ToolHitbox
## Nur waehrend der Trefferphase aktiv. Ein Ziel nur einmal pro Swing.

var already_hit_targets: Array = []
var _damage: int = 0
var _knockback: float = 0.0
var _source: Node2D

@onready var _anim: AnimationPlayer = $"../../../AnimationPlayer"

func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func begin_swing(damage: int, knockback: float, source: Node2D) -> void:
	already_hit_targets.clear()
	_damage = damage
	_knockback = knockback
	_source = source


func _process(_delta: float) -> void:
	var hit := false
	if _anim != null and _anim.is_playing() and _anim.current_animation == &"tool_swing":
		var t := _anim.current_animation_position
		hit = t >= 0.08 and t <= 0.18
	if monitoring != hit:
		monitoring = hit


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	if node == null or _damage <= 0:
		return
	var target := _find_damageable(node)
	if target == null or target in already_hit_targets:
		return
	already_hit_targets.append(target)
	target.take_damage(_damage, _source)
	if _knockback > 0.0 and target.has_method("apply_knockback") and _source != null:
		var away: Vector2 = target.global_position - _source.global_position
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		target.apply_knockback(away.normalized() * _knockback)


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
