extends CanvasLayer

## Gehoert an: HUD-Wurzel. UI-Skalierung ohne Einfluss auf die Weltkamera.
## Chrome (Leben, Zeit, Hotbar, Minimap, Tests) liegt hinter dem Inventar.

const CHROME_LAYER := 20
const INVENTORY_LAYER := 30
const MODAL_LAYER := 40

func _ready() -> void:
	add_to_group("hud")
	layer = CHROME_LAYER
	_ensure_stack_layers()
	_ensure_menus()
	if not SettingsManager.ui_scale_changed.is_connected(_on_ui_scale_changed):
		SettingsManager.ui_scale_changed.connect(_on_ui_scale_changed)
	call_deferred("_apply_ui_scale")


func _ensure_stack_layers() -> void:
	var inventory_host := _ensure_canvas_layer("InventoryLayer", INVENTORY_LAYER)
	var modal_host := _ensure_canvas_layer("ModalLayer", MODAL_LAYER)
	_reparent_named("InventoryScreen", inventory_host)
	for node_name in ["WorldMap", "LanternUpgradeMenu", "PauseMenu", "OptionsMenu"]:
		_reparent_named(node_name, modal_host)


func _ensure_canvas_layer(node_name: String, layer_index: int) -> CanvasLayer:
	var host := get_node_or_null(node_name) as CanvasLayer
	if host == null:
		host = CanvasLayer.new()
		host.name = node_name
		add_child(host)
	host.layer = layer_index
	return host


func _reparent_named(node_name: String, host: CanvasLayer) -> void:
	if host == null:
		return
	var node := find_child(node_name, true, false)
	if node == null or node.get_parent() == host:
		return
	node.reparent(host)


func _ensure_menus() -> void:
	var modal := _ensure_canvas_layer("ModalLayer", MODAL_LAYER)
	if find_child("PauseMenu", true, false) == null:
		var pause: Node = load("res://scenes/ui/pause_menu.tscn").instantiate()
		pause.name = "PauseMenu"
		modal.add_child(pause)
	if find_child("OptionsMenu", true, false) == null:
		var options: Node = load("res://scenes/ui/options_menu.tscn").instantiate()
		options.name = "OptionsMenu"
		modal.add_child(options)


func _on_ui_scale_changed(_scale: float) -> void:
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	var scale_v := SettingsManager.get_ui_scale()
	var scale_vec := Vector2(scale_v, scale_v)
	offset = Vector2.ZERO
	scale = scale_vec
	for child in get_children():
		var canvas := child as CanvasLayer
		if canvas != null:
			canvas.offset = Vector2.ZERO
			canvas.scale = scale_vec
