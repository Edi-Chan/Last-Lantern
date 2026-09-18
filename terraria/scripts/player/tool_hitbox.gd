class_name ToolHitbox
extends Area2D

## Gehoert an: Player/ToolPivot/ToolArm/ToolHitbox
## Nur waehrend der Trefferphase aktiv. Ein Ziel nur einmal pro Attacke.
## Hurtbox-Ziele laufen ueber CombatResolver.find_damageable (get_hurtbox_owner).
## Schaden: CombatResolver.apply_hit ruft take_damage und apply_knockback.

const TILE := 16.0
const DEFAULT_SHAPE := Vector2(24, 26)
const SWORD_SHAPE := Vector2(28, 32)
const SPEAR_SHAPE := Vector2(42, 10)
const LANTERN_SHAPE := Vector2(26, 26)

var already_hit_targets: Array = []
var _damage: int = 0
var _knockback: float = 0.0
var _source: Node2D
var _weapon_data: Resource
var _anim_name: StringName = &"tool_swing"
var _hit_start: float = 0.08
var _hit_end: float = 0.18

@onready var _anim: AnimationPlayer = $"../../../AnimationPlayer"
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring = false
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func begin_swing(damage: int, knockback: float, source: Node2D) -> void:
	begin_attack(damage, knockback, source, null, &"tool_swing", 0.08, 0.18, ItemData.WeaponKind.NONE, 2.5)


func begin_attack(
		damage: int,
		knockback: float,
		source: Node2D,
		weapon: Resource,
		anim_name: StringName,
		hit_start: float,
		hit_end: float,
		kind: int,
		item_range: float
	) -> void:
	already_hit_targets.clear()
	_damage = damage
	_knockback = knockback
	_source = source
	_weapon_data = weapon
	_anim_name = anim_name
	_hit_start = hit_start
	_hit_end = hit_end
	_apply_shape(kind, item_range)


func cancel_attack() -> void:
	already_hit_targets.clear()
	_damage = 0
	monitoring = false


func _apply_shape(kind: int, item_range: float) -> void:
	if _shape == null:
		_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _shape == null:
		return
	var rect := _shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		_shape.shape = rect
	var size := DEFAULT_SHAPE
	var offset := Vector2(14, 0)
	match kind:
		ItemData.WeaponKind.SWORD:
			size = SWORD_SHAPE
			offset = Vector2(16, 0)
		ItemData.WeaponKind.SPEAR:
			size = SPEAR_SHAPE
			offset = Vector2(22, 0)
		ItemData.WeaponKind.LANTERN:
			size = LANTERN_SHAPE
			offset = Vector2(12, 0)
	var scale_r := maxf(item_range, 0.5) / 2.5
	rect.size = Vector2(roundf(size.x * scale_r), roundf(size.y))
	position = Vector2(roundf(offset.x * scale_r), offset.y)


func _process(_delta: float) -> void:
	var hit := false
	if _anim != null and _anim.is_playing() and _anim.current_animation == _anim_name:
		var t := _anim.current_animation_position
		hit = t >= _hit_start and t <= _hit_end
	if monitoring != hit:
		monitoring = hit


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _try_hit(node: Node) -> void:
	if node == null or _damage <= 0:
		return
	var target := CombatResolver.find_damageable(node)
	if target == null or target == _source or target in already_hit_targets:
		return
	already_hit_targets.append(target)
	var resolved := CombatResolver.resolve_damage(_damage, _weapon_data, target)
	CombatResolver.apply_hit(target, resolved, _knockback, _source)
