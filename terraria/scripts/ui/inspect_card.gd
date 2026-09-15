extends PanelContainer

## Item-Karte im Inventar. Dezente Stahl-Ecken, passend zum dunklen Fantasy-Panel.

const ACCENT := Color(0.45, 0.56, 0.68, 1)
const INNER := Color(0.22, 0.28, 0.36, 0.9)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_rect(r, INNER, false, 1.0)
	var m := 4.0
	var arm := 8.0
	_draw_corner(Vector2(m, m), 1.0, 1.0, arm)
	_draw_corner(Vector2(size.x - m, m), -1.0, 1.0, arm)
	_draw_corner(Vector2(m, size.y - m), 1.0, -1.0, arm)
	_draw_corner(Vector2(size.x - m, size.y - m), -1.0, -1.0, arm)


func _draw_corner(origin: Vector2, dir_x: float, dir_y: float, arm: float) -> void:
	draw_line(origin, origin + Vector2(dir_x * arm, 0.0), ACCENT, 1.0)
	draw_line(origin, origin + Vector2(0.0, dir_y * arm), ACCENT, 1.0)
