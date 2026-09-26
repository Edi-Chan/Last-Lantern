extends Label

## Gehoert an: HUD/FpsOverlay. Echte Framerate, unabhängig von Pause. Update ~4×/s.

var _refresh_left: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _process(delta: float) -> void:
	var show_fps := SettingsManager.is_show_fps()
	var show_perf := AdminManager.perf_overlay
	visible = show_fps or show_perf
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh(show_perf)


func _refresh(show_perf: bool = false) -> void:
	_refresh_left = 0.25
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 0.001)
	if fps >= 60.0:
		modulate = Color(0.55, 1.0, 0.55)
	elif fps >= 30.0:
		modulate = Color(1.0, 0.85, 0.4)
	else:
		modulate = Color(1.0, 0.4, 0.4)
	if show_perf:
		text = AdminManager.get_performance_overlay_text(true)
		return
	text = "%d FPS  %.1f ms" % [roundi(fps), frame_ms]
