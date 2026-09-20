extends Control

## Kosmetischer Editor fuer vorhandene Player-Visuals.
## Der aktuelle Player hat keine getrennten Haar-/Haut-/Kleidungsschichten.

const PLAYER_FRAMES_PATH := "res://resources/player/player_frames.tres"
const PREVIEW_SCALE := 4.0

@onready var _name_edit: LineEdit = $Center/Panel/Margin/Layout/Body/Details/NameEdit
@onready var _create_button: Button = $Center/Panel/Margin/Layout/Footer/CreateButton
@onready var _back_button: Button = $Center/Panel/Margin/Layout/Footer/BackButton
@onready var _random_button: Button = $Center/Panel/Margin/Layout/Actions/RandomButton
@onready var _reset_button: Button = $Center/Panel/Margin/Layout/Actions/ResetButton
@onready var _idle_button: Button = $Center/Panel/Margin/Layout/Body/PreviewColumn/AnimRow/IdleButton
@onready var _walk_button: Button = $Center/Panel/Margin/Layout/Body/PreviewColumn/AnimRow/WalkButton
@onready var _hint: Label = $Center/Panel/Margin/Layout/Body/Details/HintLabel
@onready var _error: Label = $Center/Panel/Margin/Layout/Footer/ErrorLabel
@onready var _preview_host: Control = $Center/Panel/Margin/Layout/Body/PreviewColumn/PreviewFrame/PreviewHost

var _preview_sprite: AnimatedSprite2D
var _default_name: String = ""
var _world_size: int = WorldSize.Id.MEDIUM
var _size_buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("start_flow_ui")
	theme = AdminTheme.make_theme()
	_setup_copy()
	_setup_preview()
	_setup_world_size()
	_name_edit.max_length = LookRecord.NAME_MAX_LENGTH
	_name_edit.placeholder_text = "Name"
	_name_edit.text_changed.connect(_on_name_changed)
	_create_button.pressed.connect(_on_create)
	_back_button.pressed.connect(_on_back)
	_random_button.pressed.connect(_on_random)
	_reset_button.pressed.connect(_on_reset)
	_idle_button.pressed.connect(func() -> void: _play_preview("idle"))
	_walk_button.pressed.connect(func() -> void: _play_preview("walk"))
	_random_button.visible = false
	_refresh_create()
	_fade_in()
	_name_edit.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()


func _setup_copy() -> void:
	if _hint != null:
		_hint.text = "Der Survivor steckt in den bestehenden Player-Sprites.\nGetrennte Haar-, Haut- oder Kleidungsschichten gibt es noch nicht.\nDu bestimmst den Namen. Das Aussehen folgt dem echten Charakter."


func _setup_preview() -> void:
	if _preview_host == null:
		return
	var frames := load(PLAYER_FRAMES_PATH) as SpriteFrames
	_preview_sprite = AnimatedSprite2D.new()
	_preview_sprite.name = "CharacterPreview"
	_preview_sprite.centered = true
	_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_sprite.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview_sprite.position = _preview_host.size * 0.5
	if frames != null:
		_preview_sprite.sprite_frames = frames
		_preview_sprite.play("idle")
	_preview_host.add_child(_preview_sprite)
	_preview_host.resized.connect(_center_preview)
	call_deferred("_center_preview")


func _setup_world_size() -> void:
	var details := get_node_or_null("Center/Panel/Margin/Layout/Body/Details") as VBoxContainer
	if details == null:
		return
	var title := Label.new()
	title.text = "Weltgröße"
	details.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	details.add_child(row)
	for size_id in [WorldSize.Id.SMALL, WorldSize.Id.MEDIUM, WorldSize.Id.LARGE]:
		var button := Button.new()
		button.text = WorldSize.display_name(size_id)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(70, 28)
		button.tooltip_text = WorldSize.description(size_id)
		button.set_meta("world_size", size_id)
		button.pressed.connect(_on_world_size_pressed.bind(size_id))
		row.add_child(button)
		_size_buttons[size_id] = button
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Klein, Mittel oder Groß. Gleicher Seed und gleiche Größe erzeugen dieselbe Welt."
	details.add_child(hint)
	_refresh_world_size_buttons()


func _on_world_size_pressed(size_id: int) -> void:
	_world_size = WorldSize.clamp_id(size_id)
	_refresh_world_size_buttons()


func _refresh_world_size_buttons() -> void:
	for size_id in _size_buttons.keys():
		var button := _size_buttons[size_id] as Button
		if button == null:
			continue
		button.set_pressed_no_signal(int(size_id) == _world_size)


func _center_preview() -> void:
	if _preview_sprite == null or _preview_host == null:
		return
	_preview_sprite.position = _preview_host.size * 0.5 + Vector2(0, 8)


func _play_preview(anim_name: String) -> void:
	if _preview_sprite == null or _preview_sprite.sprite_frames == null:
		return
	if _preview_sprite.sprite_frames.has_animation(anim_name):
		_preview_sprite.play(anim_name)


func _on_name_changed(_value: String) -> void:
	_refresh_create()


func _refresh_create() -> void:
	var appearance := _read_appearance()
	_create_button.disabled = not appearance.is_valid()
	if _error != null:
		_error.text = "" if appearance.is_valid() or _name_edit.text.strip_edges().is_empty() else "Name ist ungueltig."


func _read_appearance() -> LookRecord:
	var appearance := LookRecord.new()
	appearance.character_name = _name_edit.text
	appearance.normalize()
	return appearance


func _flow() -> Node:
	return get_node_or_null("/root/GameFlow")


func _on_create() -> void:
	var appearance := _read_appearance()
	if not appearance.is_valid():
		if _error != null:
			_error.text = "Bitte einen Namen eingeben."
		return
	var flow := _flow()
	if flow != null and flow.has_method("submit_character"):
		flow.call("submit_character", appearance, _world_size)


func _on_back() -> void:
	var flow := _flow()
	if flow != null and flow.has_method("open_main_menu"):
		flow.call("open_main_menu")


func _on_random() -> void:
	pass


func _on_reset() -> void:
	_name_edit.text = _default_name
	_play_preview("idle")
	_refresh_create()


func _fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
