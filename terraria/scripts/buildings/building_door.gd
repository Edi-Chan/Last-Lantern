class_name BuildingDoor
extends Node2D

## Eingangstuer eines Spezialgebaeudes. Nutzt die InputMap-Action `interact`.

@export var interact_radius: float = 40.0

var building_instance_id: String = ""
var _player_in_range: bool = false
var _hint: Label
var _locked: bool = false


func _ready() -> void:
	add_to_group("building_door")
	_ensure_visuals()
	_ensure_area()


func _process(_delta: float) -> void:
	if not _player_in_range:
		return
	if UIManager.is_blocking_gameplay():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.world_input_enabled:
		return
	if not InputMap.has_action("interact"):
		return
	if Input.is_action_just_pressed("interact"):
		_try_enter()


func set_locked(locked: bool, hint_text: String = "") -> void:
	_locked = locked
	if _hint == null:
		return
	if not hint_text.is_empty():
		_hint.text = hint_text
	elif locked:
		_hint.text = "[E] Geschlossen"
	else:
		_hint.text = "[E] Betreten"


func _try_enter() -> void:
	if _locked:
		return
	var mgr := get_tree().get_first_node_in_group("building_manager")
	if mgr == null:
		return
	mgr.call("try_enter", building_instance_id)


func _ensure_visuals() -> void:
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.position = Vector2(0, -24)
		sprite.z_index = 0
		add_child(sprite)
	if sprite.texture == null:
		sprite.texture = load("res://assets/buildings/forge_door.png") as Texture2D
	if _hint == null:
		_hint = Label.new()
		_hint.name = "HintLabel"
		_hint.visible = false
		_hint.position = Vector2(-70, -78)
		_hint.size = Vector2(140, 16)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 10)
		_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1))
		_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_hint.add_theme_constant_override("outline_size", 3)
		_hint.text = "[E] Betreten"
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hint)


func _ensure_area() -> void:
	var area := get_node_or_null("InteractionArea") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "InteractionArea"
		add_child(area)
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = interact_radius
		shape.shape = circle
		shape.position = Vector2(0, -24)
		area.add_child(shape)
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _hint != null:
			_hint.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if _hint != null:
			_hint.visible = false
