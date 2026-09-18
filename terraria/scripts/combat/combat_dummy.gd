class_name CombatDummy
extends CharacterBody2D

## Gehoert an: Root von res://scenes/test/combat_dummy.tscn
## Einfacher Treffer-Dummy fuer Tool-Schaden.

@export var max_health: int = 20
@export var gravity_strength: float = 1000.0
@export var darkness_active: bool = false


var health: int = 20

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $HealthLabel

func _ready() -> void:
	health = max_health
	_update_label()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity_strength * delta, 600.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	move_and_slide()


func take_damage(amount: int, _source = null) -> void:
	var event := DamageEvent.outgoing_hit(maxi(amount, 0), _source, self, null)
	apply_damage_event(event)


func apply_damage_event(event: DamageEvent) -> void:
	if event == null:
		return
	var dmg := maxi(int(event.amount), 0)
	health = maxi(health - dmg, 0)
	event.amount = dmg
	event.target_node = self
	event.killed = health <= 0
	if event.world_position == Vector2.ZERO:
		event.world_position = get_combat_text_origin()
	_update_label()
	_flash()
	print("CombatDummy hp=%d (-%d)" % [health, event.amount])
	CombatTextSystem.present(event)


func get_combat_text_origin() -> Vector2:
	return global_position + Vector2(0, -48)


func apply_knockback(impulse: Vector2) -> void:
	velocity += impulse


func is_darkness_form() -> bool:
	return darkness_active


func _flash() -> void:
	if _sprite == null:
		return
	_sprite.modulate = Color(1.4, 1.4, 1.4, 1.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _update_label() -> void:
	if _label == null:
		return
	_label.text = str(health)
