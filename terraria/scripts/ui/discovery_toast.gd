extends Control

## Mehrere Fundmeldungen unter dem Lebens-HUD, Liste von oben nach unten.

const HOLD_SEC := 3.0
const FADE_IN_SEC := 0.12
const FADE_OUT_SEC := 0.22
const STAGGER_SEC := 0.28
const MAX_LINES := 6
const LINE_WIDTH := 164.0

var _list: VBoxContainer
var _bound: bool = false
var _seq: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 92
	custom_minimum_size = Vector2(LINE_WIDTH, 0)
	_list = VBoxContainer.new()
	_list.name = "Lines"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)
	_bind_inventory()
	set_process(true)


func _process(_delta: float) -> void:
	_sync_anchor()
	if not _bound:
		_bind_inventory()


func present(item: Resource = null, item_id: int = -1) -> void:
	if _list == null:
		return
	var label := "Material"
	var tex: Texture2D = null
	if item != null:
		if "display_name" in item:
			label = str(item.get("display_name"))
		if "icon" in item:
			tex = item.get("icon") as Texture2D
		if tex == null and item.has_method("get_held_texture"):
			tex = item.call("get_held_texture") as Texture2D
	elif item_id >= 0:
		label = "Item %d" % item_id
	for child in _list.get_children():
		if int(child.get_meta("item_id", -2)) == item_id:
			return
	_trim_oldest()
	var row := _make_row(label, tex, item_id)
	_list.add_child(row)
	_play_row(row, _list.get_child_count() - 1)


func _bind_inventory() -> void:
	if get_tree() == null:
		return
	var inv := get_tree().get_first_node_in_group("player_inventory")
	if inv == null or not inv.has_signal("material_discovered"):
		return
	if not inv.material_discovered.is_connected(_on_material_discovered):
		inv.material_discovered.connect(_on_material_discovered)
	_bound = true


func _on_material_discovered(_item_id: int, item: Resource) -> void:
	present(item, _item_id)


func _sync_anchor() -> void:
	var panel: Control = null
	if get_parent() != null:
		panel = get_parent().get_node_or_null("PlayerStatsPanel") as Control
	if panel == null:
		position = Vector2(12, 96)
	else:
		position = Vector2(panel.position.x, panel.position.y + panel.size.y + 6)


func _trim_oldest() -> void:
	if _list == null:
		return
	while _list.get_child_count() >= MAX_LINES:
		var oldest := _list.get_child(0) as Control
		if oldest == null:
			break
		_dismiss_row(oldest)


func _play_row(row: Control, index: int) -> void:
	row.modulate.a = 0.0
	var tween := row.create_tween()
	row.set_meta("tween", tween)
	tween.tween_property(row, "modulate:a", 1.0, FADE_IN_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SEC + STAGGER_SEC * float(maxi(index, 0)))
	tween.tween_property(row, "modulate:a", 0.0, FADE_OUT_SEC).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_dismiss_row(row)
	)


func _dismiss_row(row: Control) -> void:
	if row == null or not is_instance_valid(row):
		return
	var stored: Variant = row.get_meta("tween", null)
	if stored is Tween:
		var tween := stored as Tween
		if tween.is_valid():
			tween.kill()
	row.queue_free()


func _make_row(label: String, tex: Texture2D, item_id: int) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(LINE_WIDTH, 28)
	row.add_theme_stylebox_override("panel", _panel_style())
	row.set_meta("item_id", item_id)
	_seq += 1
	row.set_meta("seq", _seq)
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 6)
	row.add_child(inner)
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(2, 0)
	accent.color = Color(0.55, 0.92, 0.78, 0.95)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(accent)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex
	icon.visible = tex != null
	inner.add_child(icon)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -1)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(texts)
	var title := Label.new()
	title.text = "NEUES MATERIAL ENTDECKT"
	title.add_theme_font_size_override("font_size", 7)
	title.add_theme_color_override("font_color", Color(0.62, 0.9, 0.8, 0.95))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(title)
	var name_label := Label.new()
	name_label.text = label
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	return row


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.11, 0.82)
	style.border_color = Color(0.42, 0.72, 0.62, 0.45)
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_top = 3
	style.content_margin_right = 6
	style.content_margin_bottom = 3
	style.anti_aliasing = false
	return style
