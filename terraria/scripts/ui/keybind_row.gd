class_name KeybindRow
extends HBoxContainer

signal rebind_requested(action: StringName)

@onready var _label: Label = $ActionLabel
@onready var _button: Button = $BindButton

var action_name: StringName = &""
var _bind_text: String = "—"


func _ready() -> void:
	_button.pressed.connect(func() -> void: rebind_requested.emit(action_name))
	_button.focus_mode = Control.FOCUS_ALL


func setup(action: StringName, display_name: String, event_text: String) -> void:
	action_name = action
	if _label != null:
		_label.text = display_name
	set_bind_text(event_text)


func set_bind_text(event_text: String) -> void:
	_bind_text = event_text
	if _button != null and not _button.disabled:
		_button.text = event_text


func set_listening(listening: bool) -> void:
	if _button == null:
		return
	_button.disabled = listening and action_name == &""
	_button.text = "Warte auf Eingabe..." if listening else _bind_text
