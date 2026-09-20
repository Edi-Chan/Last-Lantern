extends Control

## Pixel-Hauptmenue. Keine Schwierigkeitsauswahl, keine Weltkonfiguration.

const OPTIONS_SCENE := preload("res://scenes/ui/options_menu.tscn")
const LANTERN_ICON := preload("res://assets/ui/main_menu/lantern_icon.png")

@onready var _logo_label: Label = $Center/Column/TitleStack/LogoLabel
@onready var _logo_shadow: Label = $Center/Column/TitleStack/LogoShadow
@onready var _logo_icon: TextureRect = $Center/Column/LogoPlaceholder
@onready var _subtitle: Label = $Center/Column/Subtitle
@onready var _continue_button: Button = $Center/Column/Buttons/ContinueButton
@onready var _new_game_button: Button = $Center/Column/Buttons/NewGameButton
@onready var _load_button: Button = $Center/Column/Buttons/LoadButton
@onready var _settings_button: Button = $Center/Column/Buttons/SettingsButton
@onready var _quit_button: Button = $Center/Column/Buttons/QuitButton
@onready var _status: Label = $Center/Column/StatusLabel
@onready var _title_block: Control = $Center/Column/TitleStack
@onready var _load_overlay: Control = $LoadOverlay
@onready var _load_info: Label = $LoadOverlay/Center/Panel/Margin/Layout/InfoLabel
@onready var _load_confirm: Button = $LoadOverlay/Center/Panel/Margin/Layout/Buttons/ConfirmButton
@onready var _load_cancel: Button = $LoadOverlay/Center/Panel/Margin/Layout/Buttons/CancelButton
@onready var _music_slot: AudioStreamPlayer = $MusicSlot

var _options: OptionsMenu


func _ready() -> void:
	add_to_group("start_flow_ui")
	theme = MainMenuTheme.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_visuals()
	_wire_buttons()
	_refresh_save_buttons()
	_hide_load_overlay()
	_ensure_options()
	_fade_in()
	_start_menu_music()
	_new_game_button.grab_focus()


func _setup_visuals() -> void:
	if _logo_icon != null:
		_logo_icon.texture = LANTERN_ICON
		_logo_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _logo_label != null:
		_logo_label.text = "LAST LANTERN"
		_logo_label.add_theme_color_override("font_color", MainMenuTheme.COL_GOLD)
		_logo_label.add_theme_font_size_override("font_size", 42)
	if _logo_shadow != null:
		_logo_shadow.text = "LAST LANTERN"
		_logo_shadow.add_theme_color_override("font_color", Color(0.18, 0.12, 0.06, 0.85))
		_logo_shadow.add_theme_font_size_override("font_size", 42)
	if _subtitle != null:
		_subtitle.text = "Sieben Tage. Eine Laterne."
		_subtitle.add_theme_color_override("font_color", MainMenuTheme.COL_MUTED)
		_subtitle.add_theme_font_size_override("font_size", 14)
	if _status != null:
		_status.add_theme_font_size_override("font_size", 11)


func _wire_buttons() -> void:
	_continue_button.pressed.connect(_on_continue)
	_new_game_button.pressed.connect(_on_new_game)
	_load_button.pressed.connect(_on_load_pressed)
	_settings_button.pressed.connect(_on_settings)
	_quit_button.pressed.connect(_on_quit)
	_load_confirm.pressed.connect(_on_load_confirm)
	_load_cancel.pressed.connect(_hide_load_overlay)


func _flow() -> Node:
	return get_node_or_null("/root/GameFlow")


func _refresh_save_buttons() -> void:
	var flow := _flow()
	var has_save := false
	if flow != null and flow.has_method("has_continue_save"):
		has_save = bool(flow.call("has_continue_save"))
	_continue_button.disabled = not has_save
	_load_button.disabled = not has_save
	if has_save:
		MainMenuTheme.apply_continue_highlight(_continue_button)
	if _status != null:
		if has_save:
			_status.text = _build_save_status_text(flow)
			_status.add_theme_color_override("font_color", MainMenuTheme.COL_STATUS_OK)
		else:
			_status.text = "Kein Spielstand vorhanden."
			_status.add_theme_color_override("font_color", MainMenuTheme.COL_STATUS_MISSING)


func _build_save_status_text(flow: Node) -> String:
	if flow == null or not flow.has_method("peek_save"):
		return "✓ Spielstand verfügbar"
	var raw: Variant = flow.call("peek_save")
	if not raw is Dictionary:
		return "✓ Spielstand verfügbar"
	var payload: Dictionary = raw
	var player_data: Dictionary = payload.get("player", {})
	var character: Dictionary = payload.get("character", {})
	var name_text := str(character.get("character_name", player_data.get("character_name", "")))
	if name_text.strip_edges().is_empty():
		name_text = "Unbenannt"
	var day_data: Dictionary = payload.get("day_cycle", {})
	var day := int(day_data.get("current_day", 1))
	return "✓ Spielstand verfügbar — %s, Tag %d" % [name_text, day]


func _ensure_options() -> void:
	if OPTIONS_SCENE == null:
		return
	_options = OPTIONS_SCENE.instantiate() as OptionsMenu
	if _options == null:
		return
	_options.name = "OptionsMenu"
	add_child(_options)


func _fade_in() -> void:
	modulate.a = 0.0
	if _logo_icon != null:
		_logo_icon.modulate.a = 0.0
	if _title_block != null:
		_title_block.modulate.a = 0.0
		_title_block.scale = Vector2(1.0, 0.96)
	if _subtitle != null:
		_subtitle.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.28)
	if _logo_icon != null:
		var icon_tween := create_tween()
		icon_tween.tween_interval(0.06)
		icon_tween.tween_property(_logo_icon, "modulate:a", 1.0, 0.18)
	if _title_block != null:
		var title_tween := create_tween()
		title_tween.tween_interval(0.08)
		title_tween.set_parallel(true)
		title_tween.tween_property(_title_block, "modulate:a", 1.0, 0.22)
		title_tween.tween_property(_title_block, "scale", Vector2.ONE, 0.22)
	if _subtitle != null:
		var sub_tween := create_tween()
		sub_tween.tween_interval(0.18)
		sub_tween.tween_property(_subtitle, "modulate:a", 1.0, 0.2)


func _start_menu_music() -> void:
	var director := get_node_or_null("/root/MusicDirector")
	if director != null and str(director.get("current_track_id")) != "":
		return
	if _music_slot == null:
		return
	_music_slot.bus = "Master"
	_music_slot.stream = WavLoader.playable("res://audio/music/menu.wav", true)
	_music_slot.volume_db = -2.0
	_music_slot.process_mode = Node.PROCESS_MODE_ALWAYS
	if _music_slot.stream != null:
		_music_slot.play()


func _on_continue() -> void:
	if _continue_button.disabled:
		return
	var flow := _flow()
	if flow != null and flow.has_method("continue_last_save"):
		flow.call("continue_last_save")


func _on_new_game() -> void:
	var flow := _flow()
	if flow != null and flow.has_method("begin_new_game"):
		flow.call("begin_new_game")


func _on_load_pressed() -> void:
	if _load_button.disabled:
		return
	_show_load_overlay()


func _show_load_overlay() -> void:
	var flow := _flow()
	var payload: Dictionary = {}
	if flow != null and flow.has_method("peek_save"):
		var raw: Variant = flow.call("peek_save")
		if raw is Dictionary:
			payload = raw
	if payload.is_empty():
		_refresh_save_buttons()
		return
	var player_data: Dictionary = payload.get("player", {})
	var character: Dictionary = payload.get("character", {})
	var name_text := str(character.get("character_name", player_data.get("character_name", "")))
	if name_text.strip_edges().is_empty():
		name_text = "Unbenannt"
	var day_data: Dictionary = payload.get("day_cycle", {})
	var day := int(day_data.get("current_day", 1))
	_load_info.text = "Charakter: %s\nTag: %d\nEin Spielstand." % [name_text, day]
	_load_overlay.visible = true
	_load_confirm.grab_focus()


func _hide_load_overlay() -> void:
	_load_overlay.visible = false


func _on_load_confirm() -> void:
	_hide_load_overlay()
	var flow := _flow()
	if flow != null and flow.has_method("continue_last_save"):
		flow.call("continue_last_save")


func _on_settings() -> void:
	if _options != null:
		UIManager.open_options_from_pause()


func _on_quit() -> void:
	get_tree().quit()
