class_name LightningFx
extends Node2D

## Gehoert an: World/LightningFx. Seltener Pixel-Blitz in der Welt, nicht auf dem HUD.

var _life: float = 0.0
var _duration: float = 0.12
var _points: PackedVector2Array = PackedVector2Array()
var _branches: Array[PackedVector2Array] = []
var _width: float = 2.2
var _color: Color = Color(0.78, 0.42, 1.0)


func _ready() -> void:
	add_to_group("lightning_fx")
	z_index = 12
	visible = false
	set_process(false)


func strike(from_world: Vector2, to_world: Vector2, duration: float = 0.12, color: Color = Color(0.78, 0.42, 1.0)) -> void:
	_duration = maxf(duration, 0.04)
	_life = _duration
	_color = color
	_width = randf_range(1.6, 3.1)
	_points = _build(to_local(from_world), to_local(to_world), randi_range(11, 18), randf_range(14.0, 34.0))
	_branches.clear()
	var branch_count := randi_range(1, 3) if randf() < 0.78 else 0
	for _i in branch_count:
		if _points.size() < 4:
			break
		var start_i := randi_range(2, _points.size() - 2)
		var start := _points[start_i]
		var side := 1.0 if randf() < 0.5 else -1.0
		var branch_to := start + Vector2(randf_range(18.0, 70.0) * side, randf_range(28.0, 90.0))
		_branches.append(_build(start, branch_to, randi_range(4, 8), randf_range(8.0, 18.0)))
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var a := clampf(_life / maxf(_duration, 0.001), 0.0, 1.0)
	_draw_bolt(_points, _width, a)
	for branch in _branches:
		_draw_bolt(branch, maxf(_width * 0.55, 1.0), a * 0.75)


func _draw_bolt(pts: PackedVector2Array, width: float, a: float) -> void:
	if pts.size() < 2:
		return
	var glow := Color(_color.r * 0.45, _color.g * 0.22, _color.b * 0.55, a * 0.42)
	var mid := Color(_color.r, _color.g, _color.b, a * 0.9)
	var core := Color(1.0, 0.92, 1.0, a)
	draw_polyline(pts, glow, width + 3.2, false)
	draw_polyline(pts, mid, width, false)
	draw_polyline(pts, core, maxf(width * 0.38, 1.0), false)


func _build(from_pt: Vector2, to_pt: Vector2, steps: int, wobble_max: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var delta := to_pt - from_pt
	var perp := Vector2(-delta.y, delta.x)
	if perp.length_squared() < 0.001:
		perp = Vector2.RIGHT
	else:
		perp = perp.normalized()
	var step_n := maxi(steps, 3)
	for i in step_n + 1:
		var t := float(i) / float(step_n)
		var p := from_pt.lerp(to_pt, t)
		if i > 0 and i < step_n:
			var envelope := 1.0 - absf(t * 2.0 - 1.0)
			var jagged := envelope * randf_range(wobble_max * 0.45, wobble_max)
			if randf() < 0.5:
				jagged *= -1.0
			p += perp * jagged
			p += delta.normalized() * randf_range(-4.0, 4.0)
		pts.append(p)
	return pts
