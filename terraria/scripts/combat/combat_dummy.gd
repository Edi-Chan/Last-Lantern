class_name CombatDummy
extends CharacterBody2D

## Gehoert an: Root von res://scenes/test/combat_dummy.tscn
## Einfacher Treffer-Dummy fuer Tool-Schaden.

@export var max_health: int = 20
@export var gravity_strength: float = 1000.0

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
	health = maxi(health - amount, 0)
	_update_label()
	_flash()
	print("CombatDummy hp=%d (-%d)" % [health, amount])


func apply_knockback(impulse: Vector2) -> void:
	velocity += impulse


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
