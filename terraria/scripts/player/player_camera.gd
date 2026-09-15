class_name PlayerCamera
extends Camera2D

## Gehoert an: Player/Camera2D in res://scenes/player/player.tscn
##
## Achtung auf die Godot-Konvention: Camera2D.zoom ist ein Vergroesserungsfaktor.
## zoom = 2 zeigt halb so viel Welt, zoom = 0.5 zeigt doppelt so viel.
## Dieses Script rechnet deshalb in "wie viel mehr Welt ist sichtbar als bei 1:1":
##
##     zoom_out = 0.75 -> Camera2D.zoom = 1.333 (naeher herangezoomt)
##     zoom_out = 1    -> Camera2D.zoom = 1.0   (1:1)
##     zoom_out = 1.75 -> Camera2D.zoom ≈ 0.571 (weitester Zoom Out)
##
## Groesserer zoom_out = weiter herausgezoomt.

## Startwert: 1:1.
@export var default_zoom_out: float = 1.0
## Staerkster Zoom In.
@export var min_zoom_out: float = 0.75
## Weitester Zoom Out.
@export var max_zoom_out: float = 1.75
@export var zoom_step: float = 0.25
## Groesser = schnelleres Nachziehen auf den Zielwert.
@export var zoom_lerp_speed: float = 12.0
## Wartezeit, bevor das Halten der Taste weiterzoomt.
@export var repeat_delay: float = 0.35
@export var repeat_interval: float = 0.06

var _target_zoom_out: float = 1.0
var _held_direction: float = 0.0
var _repeat_left: float = 0.0

func _ready() -> void:
	_target_zoom_out = clampf(default_zoom_out, min_zoom_out, max_zoom_out)
	_apply(_target_zoom_out)


func _process(delta: float) -> void:
	_read_input(delta)
	_interpolate(delta)


## Bewusst per Action-Polling statt _unhandled_input: die Tastenwiederholung
## haengt so nicht an der OS-Repeat-Rate.
func _read_input(delta: float) -> void:
	if UIManager.is_blocking_gameplay():
		_held_direction = 0.0
		return
	var world_map := get_tree().get_first_node_in_group("world_map_ui")
	if world_map != null and world_map.has_method("is_open") and world_map.is_open():
		_held_direction = 0.0
		return
	var direction := 0.0
	if Input.is_action_pressed("zoom_out"):
		direction += 1.0
	if Input.is_action_pressed("zoom_in"):
		direction -= 1.0
	if direction == 0.0:
		_held_direction = 0.0
		return
	if direction != _held_direction:
		_held_direction = direction
		_repeat_left = repeat_delay
		_step(direction * zoom_step)
		return
	_repeat_left -= delta
	if _repeat_left <= 0.0:
		_repeat_left = repeat_interval
		_step(direction * zoom_step)


func _interpolate(delta: float) -> void:
	var current := get_zoom_out()
	if is_equal_approx(current, _target_zoom_out):
		return
	var weight := clampf(zoom_lerp_speed * delta, 0.0, 1.0)
	var next := lerpf(current, _target_zoom_out, weight)
	if absf(next - _target_zoom_out) < 0.002:
		next = _target_zoom_out
	_apply(next)


## Aktueller Faktor, wie viel mehr Welt sichtbar ist als bei 1:1.
func get_zoom_out() -> float:
	return 1.0 / maxf(zoom.x, 0.0001)


func get_target_zoom_out() -> float:
	return _target_zoom_out


func set_zoom_out(value: float) -> void:
	_target_zoom_out = clampf(value, min_zoom_out, max_zoom_out)


func _step(amount: float) -> void:
	set_zoom_out(_target_zoom_out + amount)


func _apply(zoom_out: float) -> void:
	var factor := 1.0 / maxf(zoom_out, 0.0001)
	zoom = Vector2(factor, factor)
