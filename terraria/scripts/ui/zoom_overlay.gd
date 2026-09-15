extends Label

## Gehoert an: HUD/ZoomOverlay. Aktueller Kamera-Zoom, links unten.

var _refresh_left: float = 0.0
var _last_shown: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh(true)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh(false)


func _refresh(force: bool) -> void:
	_refresh_left = 0.08
	var zoom_out := 1.0
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("get_zoom_out"):
		zoom_out = float(cam.call("get_zoom_out"))
	if not force and is_equal_approx(zoom_out, _last_shown):
		return
	_last_shown = zoom_out
	text = "Zoom %.2f" % zoom_out
