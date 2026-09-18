extends Label

## Gehoert an: HUD/FpsOverlay. Echte Framerate, unabhängig von Pause. Update ~4×/s.

var _refresh_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _process(delta: float) -> void:
	var show_fps := SettingsManager.is_show_fps()
	visible = show_fps
	if not show_fps:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh()


func _refresh() -> void:
	_refresh_left = 0.25
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 0.001)
	if fps >= 60.0:
		modulate = Color(0.55, 1.0, 0.55)
	elif fps >= 30.0:
		modulate = Color(1.0, 0.85, 0.4)
	else:
		modulate = Color(1.0, 0.4, 0.4)
	text = "%d FPS  %.1f ms" % [roundi(fps), frame_ms]
