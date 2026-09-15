extends CanvasLayer

## Gehoert an: HUD-Wurzel. UI-Skalierung ohne Einfluss auf die Weltkamera.

func _ready() -> void:
	add_to_group("hud")
	_ensure_menus()
	if not SettingsManager.ui_scale_changed.is_connected(_on_ui_scale_changed):
		SettingsManager.ui_scale_changed.connect(_on_ui_scale_changed)
	call_deferred("_apply_ui_scale")


func _ensure_menus() -> void:
	if get_node_or_null("PauseMenu") == null:
		var pause: Node = load("res://scenes/ui/pause_menu.tscn").instantiate()
		pause.name = "PauseMenu"
		add_child(pause)
	if get_node_or_null("OptionsMenu") == null:
		var options: Node = load("res://scenes/ui/options_menu.tscn").instantiate()
		options.name = "OptionsMenu"
		add_child(options)


func _on_ui_scale_changed(_scale: float) -> void:
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	var scale_v := SettingsManager.get_ui_scale()
	offset = Vector2.ZERO
	scale = Vector2(scale_v, scale_v)
