extends Button

## Visuelles Feedback fuer Hauptmenue-Buttons. Keine Logik-Aenderung.

@export var intro_delay: float = 0.0
@export var show_hover_marker: bool = true

var _marker: Label
var _rest_top: float = 0.0
var _pressed_offset: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(1.0, 0.96)
	_create_marker()
	call_deferred("_cache_rest_top")
	call_deferred("_play_intro")


func _cache_rest_top() -> void:
	_rest_top = offset_top


func _create_marker() -> void:
	if not show_hover_marker:
		return
	_marker = Label.new()
	_marker.name = "HoverMarker"
	_marker.text = ">"
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	_marker.add_theme_color_override("font_color", MainMenuTheme.COL_GOLD)
	_marker.add_theme_font_size_override("font_size", 12)
	add_child(_marker)
	call_deferred("_position_marker")


func _position_marker() -> void:
	if _marker == null:
		return
	_marker.position = Vector2(6, (size.y - _marker.get_minimum_size().y) * 0.5)


func _play_intro() -> void:
	await get_tree().create_timer(intro_delay).timeout
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.18)


func _on_hover_changed(active: bool) -> void:
	if _marker != null:
		_marker.visible = active and not disabled
	if active and not disabled:
		offset_top = int(_rest_top) - 1
	else:
		offset_top = int(_rest_top)


func _on_button_down() -> void:
	if disabled:
		return
	_pressed_offset = true
	offset_top = int(_rest_top) + 1


func _on_button_up() -> void:
	if _pressed_offset:
		_pressed_offset = false
		offset_top = int(_rest_top) - 1 if is_hovered() else int(_rest_top)
