extends Control

## Austauschbares Placeholder-Intro. Slides kommen aus StoryCatalog.

@onready var _art: ColorRect = $Center/Panel/Margin/Layout/ArtFrame/ArtPlaceholder
@onready var _title: Label = $Center/Panel/Margin/Layout/TitleLabel
@onready var _body: Label = $Center/Panel/Margin/Layout/BodyLabel
@onready var _page: Label = $Center/Panel/Margin/Layout/PageLabel
@onready var _next_button: Button = $Center/Panel/Margin/Layout/Footer/NextButton
@onready var _skip_button: Button = $Center/Panel/Margin/Layout/Footer/SkipButton

var _slides: Array[StorySlide] = []
var _index: int = 0


func _ready() -> void:
	add_to_group("start_flow_ui")
	theme = AdminTheme.make_theme()
	_slides = StoryCatalog.slides()
	if _slides.is_empty():
		_finish()
		return
	_next_button.pressed.connect(_on_next)
	_skip_button.pressed.connect(_on_skip)
	_show_slide(0)
	_fade_in()
	_next_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_next()
		get_viewport().set_input_as_handled()


func _show_slide(index: int) -> void:
	if index < 0 or index >= _slides.size():
		_finish()
		return
	_index = index
	var slide := _slides[_index]
	_title.text = slide.title
	_body.text = slide.body
	_page.text = "%d / %d" % [_index + 1, _slides.size()]
	_next_button.text = "Weiter" if _index < _slides.size() - 1 else "Aufbrechen"
	if _art != null:
		var colors := [
			Color(0.10, 0.12, 0.17, 1.0),
			Color(0.14, 0.09, 0.16, 1.0),
			Color(0.16, 0.13, 0.08, 1.0),
			Color(0.08, 0.13, 0.09, 1.0),
		]
		_art.color = colors[_index % colors.size()]


func _on_next() -> void:
	if _index >= _slides.size() - 1:
		_finish()
		return
	_show_slide(_index + 1)


func _on_skip() -> void:
	_finish()


func _finish() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("finish_intro"):
		flow.call("finish_intro")


func _fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
