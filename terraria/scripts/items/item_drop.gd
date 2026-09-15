class_name ItemDrop
extends CharacterBody2D

## Gehoert an: Root von res://scenes/items/item_drop.tscn
##
## Layer 4 (Items), Maske 1 (World): der Drop kollidiert mit dem Terrain, aber
## nicht mit dem Player. Der Player wird also nicht blockiert, das Aufsammeln
## laeuft ausschliesslich ueber die PickupArea.

@export var gravity_strength: float = 1000.0
@export var max_fall_speed: float = 600.0
## Startimpuls beim Spawn, damit der Drop sichtbar aus dem Block herausspringt.
@export var spawn_jump_velocity: float = -90.0
@export var spawn_spread_velocity: float = 40.0
## Bodenreibung in px/s^2. Hoch genug, dass der Drop nach rund 0.1 s steht.
@export var ground_friction: float = 400.0
## In der Luft nur leicht bremsen, sonst faellt der Bogen in sich zusammen.
@export var air_friction: float = 40.0
## Darunter gilt der Drop als stehend. Verhindert das Mikrorutschen.
@export var stop_threshold: float = 3.0
@export var pickup_delay: float = 0.35

var item_id: int = -1
var amount: int = 1
var _can_pickup: bool = false

@onready var _pickup_area: Area2D = $PickupArea

func setup(p_item_id: int, p_amount: int, icon: Texture2D) -> void:
	item_id = p_item_id
	amount = p_amount
	$Sprite2D.texture = icon
	velocity = Vector2(
		randf_range(-spawn_spread_velocity, spawn_spread_velocity),
		spawn_jump_velocity,
	)


func _ready() -> void:
	get_tree().create_timer(pickup_delay).timeout.connect(_enable_pickup)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		# Keine Restgeschwindigkeit nach unten, sonst zittert der Drop auf der
		# Kante. Der Bodenkontakt bleibt ueber floor_snap_length erhalten und
		# faellt weg, sobald der Block darunter abgebaut wird.
		velocity.y = 0.0
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		if absf(velocity.x) < stop_threshold:
			velocity.x = 0.0
	else:
		velocity.y = minf(velocity.y + gravity_strength * delta, max_fall_speed)
		velocity.x = move_toward(velocity.x, 0.0, air_friction * delta)
	move_and_slide()

	if not _can_pickup:
		return
	# Bewusst per Ueberlappungsabfrage statt body_entered: beim Abbau des Blocks
	# unter den Fuessen liegt der Spieler schon im Radius, bevor die Aufnahme
	# freigeschaltet ist. body_entered wuerde dann nie mehr ausloesen.
	for body in _pickup_area.get_overlapping_bodies():
		if _try_pickup(body):
			return


func _enable_pickup() -> void:
	_can_pickup = true


func _try_pickup(body: Node2D) -> bool:
	if item_id < 0:
		return false
	var inventory := body.get_node_or_null("Inventory") as Inventory
	if inventory == null or not inventory.add_item(item_id, amount):
		return false
	if body.has_method("play_sfx"):
		body.call("play_sfx", &"Pickup")
	queue_free()
	return true
