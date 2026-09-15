class_name OptionsMenu
extends Control

## Wiederverwendbares Optionsmenue. Nicht fest an PauseMenu gekoppelt.

const KEYBIND_ROW := preload("res://scenes/ui/keybind_row.tscn")

@onready var _back_button: Button = $CenterWrap/Panel/Margin/Layout/Footer/BackButton
@onready var _apply_button: Button = $CenterWrap/Panel/Margin/Layout/Footer/ApplyButton
@onready var _reset_controls_button: Button = $CenterWrap/Panel/Margin/Layout/Tabs/Steuerung/Scroll/BindingsBox/ResetControlsButton
@onready var _bindings_box: VBoxContainer = $CenterWrap/Panel/Margin/Layout/Tabs/Steuerung/Scroll/BindingsBox
@onready var _resolution: OptionButton = $CenterWrap/Panel/Margin/Layout/Tabs/Grafik/Scroll/GrafikBox/ResolutionRow/ResolutionOption
@onready var _window_mode: OptionButton = $CenterWrap/Panel/Margin/Layout/Tabs/Grafik/Scroll/GrafikBox/WindowRow/WindowOption
@onready var _vsync: OptionButton = $CenterWrap/Panel/Margin/Layout/Tabs/Grafik/Scroll/GrafikBox/VsyncRow/VsyncOption
@onready var _fps: OptionButton = $CenterWrap/Panel/Margin/Layout/Tabs/Grafik/Scroll/GrafikBox/FpsRow/FpsOption
@onready var _ui_scale: OptionButton = $CenterWrap/Panel/Margin/Layout/Tabs/Grafik/Scroll/GrafikBox/UiScaleRow/UiScaleOption
@onready var _master_slider: HSlider = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MasterRow/MasterSlider
@onready var _music_slider: HSlider = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MusicRow/MusicSlider
@onready var _sfx_slider: HSlider = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/SfxRow/SfxSlider
@onready var _ui_slider: HSlider = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/UiRow/UiSlider
@onready var _master_mute: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MasterRow/MasterMute
@onready var _music_mute: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MusicRow/MusicMute
@onready var _sfx_mute: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/SfxRow/SfxMute
@onready var _ui_mute: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/UiRow/UiMute
@onready var _master_value: Label = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MasterRow/MasterValue
@onready var _music_value: Label = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/MusicRow/MusicValue
@onready var _sfx_value: Label = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/SfxRow/SfxValue
@onready var _ui_value: Label = $CenterWrap/Panel/Margin/Layout/Tabs/Audio/Scroll/AudioBox/UiRow/UiValue
@onready var _pause_unfocused: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Spiel/Scroll/GameBox/PauseUnfocused
@onready var _show_fps: CheckButton = $CenterWrap/Panel/Margin/Layout/Tabs/Spiel/Scroll/GameBox/ShowFps
@onready var _confirm_overlay: Control = $ConfirmOverlay
@onready var _confirm_label: Label = $ConfirmOverlay/Center/ConfirmPanel/ConfirmLayout/ConfirmLabel
@onready var _confirm_yes: Button = $ConfirmOverlay/Center/ConfirmPanel/ConfirmLayout/ConfirmButtons/YesButton
@onready var _confirm_reset: Button = $ConfirmOverlay/Center/ConfirmPanel/ConfirmLayout/ConfirmButtons/ResetButton
@onready var _discard_overlay: Control = $DiscardOverlay
@onready var _discard_yes: Button = $DiscardOverlay/Center/DiscardPanel/DiscardLayout/DiscardButtons/DiscardYes
@onready var _discard_no: Button = $DiscardOverlay/Center/DiscardPanel/DiscardLayout/DiscardButtons/DiscardNo
@onready var _conflict_label: Label = $CenterWrap/Panel/Margin/Layout/Tabs/Steuerung/Scroll/BindingsBox/ConflictLabel

var _draft: Dictionary = {}
var _open: bool = false
var _rebinding_action: StringName = &""
var _bind_rows: Dictionary = {}
var _dirty: bool = false


func _ready() -> void:
	add_to_group("options_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 140
	_setup_dropdowns()
	_setup_audio_controls()
	_setup_bindings()
	_back_button.pressed.connect(_on_back_pressed)
	_apply_button.pressed.connect(_on_apply_pressed)
	_reset_controls_button.pressed.connect(_on_reset_controls)
	_confirm_yes.pressed.connect(_on_confirm_yes)
	_confirm_reset.pressed.connect(_on_confirm_reset)
	_discard_yes.pressed.connect(_discard_and_close)
	_discard_no.pressed.connect(_hide_discard)
	_pause_unfocused.toggled.connect(func(_v: bool) -> void: _mark_dirty())
	_show_fps.toggled.connect(func(_v: bool) -> void: _mark_dirty())
	_confirm_overlay.visible = false
	_discard_overlay.visible = false
	_conflict_label.text = ""
	SettingsManager.display_revert_started.connect(_on_display_revert_started)
	SettingsManager.display_revert_tick.connect(_on_display_revert_tick)
	SettingsManager.display_confirmed.connect(_hide_confirm)
	SettingsManager.display_reverted.connect(_on_display_reverted)
	UIManager.register_options_menu(self)


func _input(event: InputEvent) -> void:
	if _rebinding_action == &"":
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		_finish_rebind(key)
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return
		get_viewport().set_input_as_handled()
		_finish_rebind(mouse)


func is_open() -> bool:
	return _open


func open_menu() -> void:
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_from_applied()
	_hide_discard()
	if not SettingsManager.is_display_confirm_active():
		_hide_confirm()
	_back_button.grab_focus()


func close_menu() -> void:
	_cancel_rebind()
	_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_discard()
	if not SettingsManager.is_display_confirm_active():
		SettingsManager.restore_applied_audio()
		SettingsManager.restore_applied_controls()


func handle_escape() -> bool:
	if not _open:
		return false
	if _rebinding_action != &"":
		_cancel_rebind()
		return true
	if _discard_overlay.visible:
		_hide_discard()
		return true
	if _confirm_overlay.visible:
		return true
	_on_back_pressed()
	return true


func _setup_dropdowns() -> void:
	_resolution.clear()
	for spec in SettingsManager.RESOLUTIONS:
		_resolution.add_item(str(spec["label"]))
	_window_mode.clear()
	_window_mode.add_item("Fenster")
	_window_mode.add_item("Randloses Vollbild")
	_window_mode.add_item("Vollbild")
	_vsync.clear()
	_vsync.add_item("Aus")
	_vsync.add_item("Ein")
	_fps.clear()
	for limit in SettingsManager.FPS_LIMITS:
		_fps.add_item("Unbegrenzt" if limit == 0 else str(limit))
	_ui_scale.clear()
	for percent in SettingsManager.UI_SCALES:
		_ui_scale.add_item("%d%%" % percent)
	_resolution.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_window_mode.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_vsync.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_fps.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_ui_scale.item_selected.connect(func(_i: int) -> void: _mark_dirty())


func _setup_audio_controls() -> void:
	for slider in [_master_slider, _music_slider, _sfx_slider, _ui_slider]:
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value_changed.connect(_on_audio_changed)
	for mute in [_master_mute, _music_mute, _sfx_mute, _ui_mute]:
		mute.toggled.connect(func(_v: bool) -> void: _on_audio_changed(0.0))


func _setup_bindings() -> void:
	for action in SettingsManager.REBINDABLE_ACTIONS:
		var row: KeybindRow = KEYBIND_ROW.instantiate()
		_bindings_box.add_child(row)
		_bindings_box.move_child(row, _reset_controls_button.get_index())
		row.setup(action, str(SettingsManager.ACTION_LABELS.get(action, String(action))), SettingsManager.primary_event_text(action))
		row.rebind_requested.connect(_begin_rebind)
		_bind_rows[action] = row


func _load_from_applied() -> void:
	_draft = SettingsManager.duplicate_current()
	var gfx: Dictionary = _draft["graphics"]
	_resolution.selected = SettingsManager.resolution_index_for(gfx.get("resolution", Vector2i(1920, 1080)))
	_window_mode.selected = int(gfx.get("window_mode", 0))
	_vsync.selected = 1 if bool(gfx.get("vsync", true)) else 0
	_fps.selected = SettingsManager.fps_index_for(int(gfx.get("fps_limit", 60)))
	_ui_scale.selected = SettingsManager.ui_scale_index_for(int(gfx.get("ui_scale", 100)))
	var aud: Dictionary = _draft["audio"]
	_master_slider.value = float(aud.get("master", 1.0)) * 100.0
	_music_slider.value = float(aud.get("music", 1.0)) * 100.0
	_sfx_slider.value = float(aud.get("sfx", 1.0)) * 100.0
	_ui_slider.value = float(aud.get("ui", 1.0)) * 100.0
	_master_mute.button_pressed = bool(aud.get("master_mute", false))
	_music_mute.button_pressed = bool(aud.get("music_mute", false))
	_sfx_mute.button_pressed = bool(aud.get("sfx_mute", false))
	_ui_mute.button_pressed = bool(aud.get("ui_mute", false))
	_refresh_audio_labels()
	_pause_unfocused.button_pressed = bool(_draft["game"].get("pause_when_unfocused", true))
	_show_fps.button_pressed = bool(_draft["game"].get("show_fps", false))
	_refresh_bind_labels()
	_dirty = false
	_conflict_label.text = ""


func _collect_draft() -> Dictionary:
	var gfx: Dictionary = _draft.get("graphics", SettingsManager.graphics.duplicate(true))
	gfx["resolution"] = SettingsManager.RESOLUTIONS[_resolution.selected]["size"]
	gfx["window_mode"] = _window_mode.selected
	gfx["vsync"] = _vsync.selected == 1
	gfx["fps_limit"] = SettingsManager.FPS_LIMITS[_fps.selected]
	gfx["ui_scale"] = SettingsManager.UI_SCALES[_ui_scale.selected]
	var aud: Dictionary = _draft.get("audio", SettingsManager.audio.duplicate(true))
	aud["master"] = _master_slider.value / 100.0
	aud["music"] = _music_slider.value / 100.0
	aud["sfx"] = _sfx_slider.value / 100.0
	aud["ui"] = _ui_slider.value / 100.0
	aud["master_mute"] = _master_mute.button_pressed
	aud["music_mute"] = _music_mute.button_pressed
	aud["sfx_mute"] = _sfx_mute.button_pressed
	aud["ui_mute"] = _ui_mute.button_pressed
	var game: Dictionary = _draft.get("game", SettingsManager.game.duplicate(true))
	game["pause_when_unfocused"] = _pause_unfocused.button_pressed
	game["show_fps"] = _show_fps.button_pressed
	_draft["graphics"] = gfx
	_draft["audio"] = aud
	_draft["game"] = game
	return _draft


func _on_audio_changed(_value: float) -> void:
	_refresh_audio_labels()
	_mark_dirty()
	var preview := {
		"master": _master_slider.value / 100.0,
		"music": _music_slider.value / 100.0,
		"sfx": _sfx_slider.value / 100.0,
		"ui": _ui_slider.value / 100.0,
		"master_mute": _master_mute.button_pressed,
		"music_mute": _music_mute.button_pressed,
		"sfx_mute": _sfx_mute.button_pressed,
		"ui_mute": _ui_mute.button_pressed,
	}
	SettingsManager.preview_audio(preview)


func _refresh_audio_labels() -> void:
	_master_value.text = "%d%%" % int(_master_slider.value)
	_music_value.text = "%d%%" % int(_music_slider.value)
	_sfx_value.text = "%d%%" % int(_sfx_slider.value)
	_ui_value.text = "%d%%" % int(_ui_slider.value)


func _on_apply_pressed() -> void:
	_cancel_rebind()
	var draft := _collect_draft()
	var needs_confirm := SettingsManager.apply_draft(draft, true)
	_dirty = false
	if not needs_confirm:
		_refresh_bind_labels()


func _on_back_pressed() -> void:
	_cancel_rebind()
	if _dirty:
		_discard_overlay.visible = true
		_discard_no.grab_focus()
		return
	SettingsManager.restore_applied_audio()
	SettingsManager.restore_applied_controls()
	UIManager.close_options_to_pause()


func _discard_and_close() -> void:
	_hide_discard()
	_dirty = false
	SettingsManager.restore_applied_audio()
	SettingsManager.restore_applied_controls()
	_load_from_applied()
	UIManager.close_options_to_pause()


func _hide_discard() -> void:
	_discard_overlay.visible = false


func _on_reset_controls() -> void:
	_draft["controls"] = SettingsManager.get_factory_controls()
	SettingsManager.preview_controls(_draft["controls"])
	_refresh_bind_labels()
	_mark_dirty()


func _begin_rebind(action: StringName) -> void:
	if action == &"":
		return
	_rebinding_action = action
	UIManager.capturing_rebind = true
	_conflict_label.text = ""
	for row_action in _bind_rows:
		var row: KeybindRow = _bind_rows[row_action]
		row.set_listening(row_action == action)


func _cancel_rebind() -> void:
	_rebinding_action = &""
	UIManager.capturing_rebind = false
	for row_action in _bind_rows:
		(_bind_rows[row_action] as KeybindRow).set_listening(false)
	_refresh_bind_labels()


func _finish_rebind(event: InputEvent) -> void:
	var action := _rebinding_action
	if action == &"":
		return
	var conflict := SettingsManager.find_binding_conflict(action, event)
	if conflict != &"":
		_conflict_label.text = "%s wird bereits für %s verwendet." % [
			SettingsManager.event_to_text(event),
			str(SettingsManager.ACTION_LABELS.get(conflict, String(conflict))),
		]
		_cancel_rebind()
		return
	if not InputMap.has_action(action):
		_cancel_rebind()
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var list: Array = []
	for existing in InputMap.action_get_events(action):
		list.append(SettingsManager.serialize_event(existing))
	_draft["controls"][String(action)] = list
	_mark_dirty()
	_cancel_rebind()


func _refresh_bind_labels() -> void:
	for action in _bind_rows:
		(_bind_rows[action] as KeybindRow).set_bind_text(SettingsManager.primary_event_text(action))
		(_bind_rows[action] as KeybindRow).set_listening(false)


func _on_confirm_yes() -> void:
	SettingsManager.confirm_display_settings()
	_hide_confirm()


func _on_confirm_reset() -> void:
	SettingsManager.revert_display_settings()


func _on_display_revert_started(seconds: int) -> void:
	_confirm_overlay.visible = true
	_update_confirm_text(seconds)
	_confirm_yes.grab_focus()


func _on_display_revert_tick(seconds: int) -> void:
	_update_confirm_text(seconds)


func _on_display_reverted() -> void:
	_hide_confirm()
	_load_from_applied()


func _update_confirm_text(seconds: int) -> void:
	_confirm_label.text = "Diese Einstellungen beibehalten?\n\n%d Sekunden" % seconds


func _hide_confirm() -> void:
	_confirm_overlay.visible = false


func _mark_dirty() -> void:
	_dirty = true
