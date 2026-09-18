class_name SceneTransition
extends CanvasLayer

## Kurzes Fade fuer Interior-Wechsel. Weltzeit laeuft weiter.

signal faded_out
signal faded_in

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	add_to_group("scene_transition")
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Fade"
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func fade_out(duration: float = 0.22) -> void:
	await _fade_to(1.0, duration)
	faded_out.emit()


func fade_in(duration: float = 0.22) -> void:
	await _fade_to(0.0, duration)
	faded_in.emit()


func _fade_to(alpha: float, duration: float) -> void:
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.5 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, maxf(duration, 0.01))
	await tween.finished
	if alpha <= 0.01:
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
