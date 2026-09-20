class_name CharacterPage
extends Control

## Charakter-Reiter im Inventar. Liest nur PlayerStats / Inventory / DayCycle.

const MUTED := Color(0.7, 0.76, 0.82, 1)
const TITLE := Color(0.92, 0.94, 0.96, 1)
const VALUE := Color(1, 0.95, 0.82, 1)
const BONUS := Color(0.52, 0.88, 0.58, 1)
const EQUIP_KINDS: Array = [StatModifier.SourceKind.EQUIPMENT, StatModifier.SourceKind.ACCESSORY]
const STAT_FONT := 10
const HEADING_FONT := 11
const ROW_HEIGHT := 15
const SLOT_SIZE := 24
const PREVIEW_SIZE := Vector2(40, 56)
const CARD_PAD := 5
const COL_SEP := 6
const STAT_SEP := 2

var _inventory: Inventory
var _player: Player
var _slot_scene: PackedScene
var _name_label: Label
var _preview: TextureRect
var _held_preview: TextureRect
var _equip_host: VBoxContainer
var _attr_box: VBoxContainer
var _gather_box: VBoxContainer
var _effects_box: VBoxContainer
var _resist_box: VBoxContainer
var _progress_box: VBoxContainer
var _equip_slots: Array[InventorySlotUI] = []
var _stat_labels: Dictionary = {}

func _ready() -> void:
	visible = false
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func bind(inventory: Inventory, player: Player, slot_scene: PackedScene) -> void:
	_inventory = inventory
	_player = player
	_slot_scene = slot_scene
	_fill_equipment_slots()
	if _player != null and _player.stats != null:
		if not _player.stats.stats_changed.is_connected(refresh):
			_player.stats.stats_changed.connect(refresh)
		if not _player.stats.health_changed.is_connected(_on_vitals):
			_player.stats.health_changed.connect(_on_vitals)
		if not _player.stats.stamina_changed.is_connected(_on_vitals):
			_player.stats.stamina_changed.connect(_on_vitals)
	if _inventory != null and not _inventory.equipment_changed.is_connected(refresh):
		_inventory.equipment_changed.connect(refresh)
	refresh()


func equipment_slots() -> Array[InventorySlotUI]:
	return _equip_slots


func preview_rect() -> TextureRect:
	return _preview


func held_preview_rect() -> TextureRect:
	return _held_preview


func refresh() -> void:
	if _player == null:
		return
	var stats := _player.stats
	if _name_label != null:
		var name_text := _player.character_name.strip_edges()
		_name_label.text = name_text if not name_text.is_empty() else "Spieler"
	if stats == null:
		return
	var sheet := stats.sheet
	_set_row("health", "Leben", _format_pair_bonus(stats.health, sheet.get_final(StatId.MAX_HEALTH), _equip_bonus(sheet, StatId.MAX_HEALTH)))
	_set_row("health_regen", "Leben-Regen.", _format_rate_bonus(sheet.get_final(StatId.HEALTH_REGEN), _equip_bonus(sheet, StatId.HEALTH_REGEN)))
	_set_row("stamina", "Ausdauer", _format_pair_bonus(stats.stamina, sheet.get_final(StatId.MAX_STAMINA), _equip_bonus(sheet, StatId.MAX_STAMINA)))
	_set_row("stamina_regen", "Ausdauer-Regen.", _format_rate_bonus(stats.stamina_regen_rate(), _equip_bonus(sheet, StatId.STAMINA_REGEN)))
	_set_row("move", "Bewegungstempo", _format_pct_bonus(stats.movement_multiplier(), _equip_bonus(sheet, StatId.MOVEMENT_SPEED)))
	_set_row("sprint", "Sprinttempo", _format_pct_bonus(stats.sprint_multiplier(), _equip_bonus(sheet, StatId.SPRINT_SPEED)))
	_set_row("jump", "Sprungkraft", _format_pct_bonus(stats.jump_multiplier(), _equip_bonus(sheet, StatId.JUMP_POWER)))
	_set_row("armor", "Rüstung", _format_int_bonus(float(stats.armor_defense), _equip_bonus(sheet, StatId.ARMOR)))
	var selected_item: ItemData = _inventory.get_selected_item() if _inventory != null else null
	var combat := stats.combat_snapshot(selected_item)
	var base_damage := maxi(int(combat["base_damage"]), 0)
	var damage_bonus := int(round(float(base_damage) * stats.damage_multiplier())) - int(round(float(base_damage) * sheet.get_final_excluding_source_kinds(StatId.DAMAGE_MULTIPLIER, EQUIP_KINDS)))
	_set_row("damage", "Schaden", _format_int_bonus(float(combat["damage"]), float(damage_bonus)))
	_set_row("attack_speed", "Angriffstempo", _format_pct_bonus(float(combat["attack_speed"]), _equip_bonus(sheet, StatId.ATTACK_SPEED)))
	_set_row("crit", "Krit. Chance", _format_pct_bonus(float(combat["crit_chance"]), _equip_bonus(sheet, StatId.CRIT_CHANCE)))
	_set_row("crit_dmg", "Krit. Schaden", _format_pct_bonus(float(combat["crit_damage"]), _equip_bonus(sheet, StatId.CRIT_DAMAGE)))
	var weapon_kb := 70.0
	if selected_item != null:
		weapon_kb = selected_item.get_weapon_knockback() if selected_item.has_method("get_weapon_knockback") else selected_item.knockback
	var kb_bonus := weapon_kb * stats.knockback_modifier() - weapon_kb * sheet.get_final_excluding_source_kinds(StatId.KNOCKBACK_MODIFIER, EQUIP_KINDS)
	_set_row("kb", "Rückstoß", _format_int_bonus(float(combat["knockback"]), kb_bonus))
	_set_row("kb_res", "Rückstoß-Resistenz", _format_pct_bonus(stats.knockback_resistance(), _equip_bonus(sheet, StatId.KNOCKBACK_RESISTANCE)))
	_set_row("mine", "Abbau", _format_pct_bonus(stats.mining_speed(), _equip_bonus(sheet, StatId.MINING_SPEED)))
	_set_row("wood", "Holzfällen", _format_pct_bonus(stats.woodcutting_speed(), _equip_bonus(sheet, StatId.WOODCUTTING_SPEED)))
	_set_row("harvest", "Ernte", _format_pct_bonus(stats.harvest_amount(), _equip_bonus(sheet, StatId.HARVEST_AMOUNT)))
	_set_row("build", "Bauen", _format_pct_bonus(stats.get_final(StatId.BUILDING_SPEED), _equip_bonus(sheet, StatId.BUILDING_SPEED)))
	_set_row("repair", "Reparieren", _format_pct_bonus(stats.get_final(StatId.REPAIR_SPEED), _equip_bonus(sheet, StatId.REPAIR_SPEED)))
	_set_row("res_fire", "Feuer", _format_pct_bonus(stats.get_final(StatId.FIRE_RESISTANCE), _equip_bonus(sheet, StatId.FIRE_RESISTANCE)))
	_set_row("res_cold", "Kälte", _format_pct_bonus(stats.get_final(StatId.COLD_RESISTANCE), _equip_bonus(sheet, StatId.COLD_RESISTANCE)))
	_set_row("res_poison", "Gift", _format_pct_bonus(stats.get_final(StatId.POISON_RESISTANCE), _equip_bonus(sheet, StatId.POISON_RESISTANCE)))
	_set_row("res_bleed", "Bluten", _format_pct_bonus(stats.get_final(StatId.BLEEDING_RESISTANCE), _equip_bonus(sheet, StatId.BLEEDING_RESISTANCE)))
	_set_row("res_dark", "Finsternis", _format_pct_bonus(stats.get_final(StatId.DARKNESS_RESISTANCE), _equip_bonus(sheet, StatId.DARKNESS_RESISTANCE)))
	_refresh_effects(stats)
	_refresh_progress(stats)
	if _player.has_method("compose_preview_texture") and _preview != null:
		var tex: Texture2D = _player.compose_preview_texture()
		if tex != null:
			_preview.texture = tex


func _on_vitals(_current: float, _maximum: float) -> void:
	refresh()


func _build() -> void:
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var inner := preload("res://resources/ui/inv_panel_inner.tres")
	var cols := HBoxContainer.new()
	cols.set_anchors_preset(Control.PRESET_FULL_RECT)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", COL_SEP)
	add_child(cols)
	cols.add_child(_build_left(inner))
	cols.add_child(_build_mid(inner))
	cols.add_child(_build_right(inner))


func _build_left(inner: StyleBox) -> Control:
	var card := _card(inner, 156)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 0.72
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 4)
	card.add_child(_margin(box, CARD_PAD))
	_name_label = _heading("Spieler")
	box.add_child(_name_label)
	var frame := Panel.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.custom_minimum_size = PREVIEW_SIZE + Vector2(16, 12)
	frame.add_theme_stylebox_override("panel", inner)
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.offset_left = 4
	wrap.offset_top = 4
	wrap.offset_right = -4
	wrap.offset_bottom = -4
	frame.add_child(wrap)
	_preview = TextureRect.new()
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_preview)
	_held_preview = TextureRect.new()
	_held_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_held_preview.custom_minimum_size = Vector2(14, 14)
	_held_preview.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_held_preview.offset_left = -20
	_held_preview.offset_top = -22
	_held_preview.offset_right = -6
	_held_preview.offset_bottom = -6
	_held_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_held_preview)
	box.add_child(frame)
	box.add_child(_label("Ausrüstung", MUTED, STAT_FONT))
	_equip_host = VBoxContainer.new()
	_equip_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equip_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_equip_host.add_theme_constant_override("separation", 3)
	box.add_child(_equip_host)
	return card


func _build_mid(inner: StyleBox) -> Control:
	var card := _card(inner, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.55
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_theme_constant_override("separation", 8)
	card.add_child(_margin(cols, CARD_PAD))
	_attr_box = VBoxContainer.new()
	_attr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attr_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_attr_box.add_theme_constant_override("separation", STAT_SEP)
	cols.add_child(_attr_box)
	_attr_box.add_child(_heading("Attribute & Werte"))
	for pair in [
		["health", "Leben"],
		["health_regen", "Leben-Regen."],
		["stamina", "Ausdauer"],
		["stamina_regen", "Ausdauer-Regen."],
		["move", "Bewegungstempo"],
		["sprint", "Sprinttempo"],
		["jump", "Sprungkraft"],
		["armor", "Rüstung"],
		["damage", "Schaden"],
		["attack_speed", "Angriffstempo"],
		["crit", "Krit. Chance"],
		["crit_dmg", "Krit. Schaden"],
		["kb", "Rückstoß"],
		["kb_res", "Rückstoß-Resistenz"],
	]:
		_add_stat_to(_attr_box, str(pair[0]), str(pair[1]))
	_gather_box = VBoxContainer.new()
	_gather_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gather_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_gather_box.add_theme_constant_override("separation", STAT_SEP)
	cols.add_child(_gather_box)
	_gather_box.add_child(_heading("Sammeln & Bauen"))
	for pair in [
		["mine", "Abbau"],
		["wood", "Holzfällen"],
		["harvest", "Ernte"],
		["build", "Bauen"],
		["repair", "Reparieren"],
	]:
		_add_stat_to(_gather_box, str(pair[0]), str(pair[1]))
	return card


func _build_right(inner: StyleBox) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(188, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.size_flags_stretch_ratio = 0.95
	col.add_theme_constant_override("separation", 4)
	var effects := _card(inner, 0)
	effects.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_effects_box = VBoxContainer.new()
	_effects_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effects_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_effects_box.add_theme_constant_override("separation", STAT_SEP)
	effects.add_child(_margin(_effects_box, CARD_PAD))
	_effects_box.add_child(_heading("Status-Effekte"))
	col.add_child(effects)
	var lower := HBoxContainer.new()
	lower.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lower.add_theme_constant_override("separation", COL_SEP)
	col.add_child(lower)
	var resist := _card(inner, 0)
	resist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resist.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	resist.size_flags_stretch_ratio = 1.0
	_resist_box = VBoxContainer.new()
	_resist_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resist_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_resist_box.add_theme_constant_override("separation", STAT_SEP)
	resist.add_child(_margin(_resist_box, CARD_PAD))
	_resist_box.add_child(_heading("Widerstände"))
	for key in ["res_fire", "res_cold", "res_poison", "res_bleed", "res_dark"]:
		_add_stat_to(_resist_box, key, "")
	lower.add_child(resist)
	var progress := _card(inner, 0)
	progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	progress.size_flags_stretch_ratio = 1.0
	_progress_box = VBoxContainer.new()
	_progress_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_progress_box.add_theme_constant_override("separation", STAT_SEP)
	progress.add_child(_margin(_progress_box, CARD_PAD))
	_progress_box.add_child(_heading("Fortschritt"))
	for key in ["playtime", "day", "kills", "mined", "found"]:
		_add_stat_to(_progress_box, key, "")
	lower.add_child(progress)
	return col


func _fill_equipment_slots() -> void:
	if _equip_host == null or _slot_scene == null:
		return
	for child in _equip_host.get_children():
		child.queue_free()
	_equip_slots.clear()
	var rows := [
		["head", "Helm", "res://assets/ui/slot_helm.png"],
		["chest", "Brust", "res://assets/ui/slot_chest.png"],
		["legs", "Beine", "res://assets/ui/slot_legs.png"],
		["accessory_1", "Acc. 1", "res://assets/ui/slot_acc.png"],
		["accessory_2", "Acc. 2", "res://assets/ui/slot_acc.png"],
	]
	for row in rows:
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 6)
		var caption := _label(str(row[1]), MUTED, STAT_FONT)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.custom_minimum_size = Vector2(52, SLOT_SIZE)
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(caption)
		var slot := _slot_scene.instantiate() as InventorySlotUI
		if slot == null:
			continue
		slot.equipment_key = str(row[0])
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		if ResourceLoader.exists(str(row[2])):
			var hint := TextureRect.new()
			hint.name = "EmptyHint"
			hint.modulate = Color(1, 1, 1, 0.35)
			hint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			hint.texture = load(str(row[2])) as Texture2D
			hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hint.set_anchors_preset(Control.PRESET_CENTER)
			hint.offset_left = -10
			hint.offset_top = -10
			hint.offset_right = 10
			hint.offset_bottom = 10
			slot.add_child(hint)
		line.add_child(slot)
		_equip_host.add_child(line)
		_equip_slots.append(slot)


func _refresh_effects(stats: PlayerStats) -> void:
	if _effects_box == null:
		return
	for child in _effects_box.get_children():
		if child is Label and child != _effects_box.get_child(0):
			child.queue_free()
	var effects := stats.sheet.timed_effects()
	if effects.is_empty():
		_effects_box.add_child(_label("Keine aktiven Effekte", MUTED, STAT_FONT))
		return
	for mod in effects:
		var sign := "+" if mod.value >= 0.0 else ""
		var amount := _pct(mod.value) if mod.modifier_type == StatModifier.Type.PERCENT else str(mod.value)
		var line := "%s %s%s  (%.0fs)" % [StatId.display_name(int(mod.stat)), sign, amount, maxf(mod.remaining, 0.0)]
		_effects_box.add_child(_label(line, TITLE, STAT_FONT))


func _refresh_progress(stats: PlayerStats) -> void:
	var seconds := int(stats.playtime_seconds)
	var h := int(float(seconds) / 3600.0)
	var m := int(float(seconds % 3600) / 60.0)
	var s := seconds % 60
	_set_row("playtime", "Spielzeit", "%02d:%02d:%02d" % [h, m, s])
	var day := 1
	var day_cycle := get_tree().get_first_node_in_group("day_cycle")
	if day_cycle != null:
		day = int(day_cycle.get("current_day"))
	_set_row("day", "Tag", str(day))
	_set_row("kills", "Gegner", str(stats.enemies_killed))
	_set_row("mined", "Abgebaut", str(stats.blocks_mined))
	_set_row("found", "Items", str(stats.items_found))


func _add_stat_to(host: VBoxContainer, key: String, caption: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var left := _label(caption, MUTED, STAT_FONT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.clip_text = true
	var right := _label("-", VALUE, STAT_FONT)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.custom_minimum_size = Vector2(92, 0)
	right.clip_text = true
	row.add_child(left)
	row.add_child(right)
	host.add_child(row)
	_stat_labels[key] = [left, right]


func _set_row(key: String, caption: String, value: String) -> void:
	if not _stat_labels.has(key):
		return
	var pair: Array = _stat_labels[key]
	if caption != "":
		(pair[0] as Label).text = caption
	(pair[1] as Label).text = value


func _card(inner: StyleBox, width: int) -> PanelContainer:
	var card := PanelContainer.new()
	if width > 0:
		card.custom_minimum_size = Vector2(width, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = false
	card.add_theme_stylebox_override("panel", inner)
	return card


func _margin(child: Control, pad: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	m.add_child(child)
	return m


func _heading(text: String) -> Label:
	var label := _label(text, TITLE, HEADING_FONT)
	label.add_theme_color_override("font_color", TITLE)
	return label


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _pct(value: float) -> String:
	return "%d %%" % int(round(value * 100.0))


func _per_sec(value: float) -> String:
	return "%.1f / s" % value


func _equip_bonus(sheet: StatSheet, stat_id: int) -> float:
	return sheet.get_final(stat_id) - sheet.get_final_excluding_source_kinds(stat_id, EQUIP_KINDS)


func _format_pair_bonus(current: float, maximum: float, bonus: float) -> String:
	var text := "%d / %d" % [ceili(current), roundi(maximum)]
	return _append_bonus(text, bonus, _bonus_int)


func _format_rate_bonus(value: float, bonus: float) -> String:
	return _append_bonus(_per_sec(value), bonus, _bonus_rate)


func _format_pct_bonus(value: float, bonus: float) -> String:
	return _append_bonus(_pct(value), bonus, _bonus_pct)


func _format_int_bonus(value: float, bonus: float) -> String:
	return _append_bonus(str(roundi(value)), bonus, _bonus_int)


func _append_bonus(text: String, bonus: float, bonus_formatter: Callable) -> String:
	if absf(bonus) < 0.0001:
		return text
	var bonus_text: String = bonus_formatter.call(bonus)
	if bonus_text.is_empty():
		return text
	return "%s (%s)" % [text, bonus_text]


func _bonus_int(bonus: float) -> String:
	var rounded := roundi(bonus)
	if rounded == 0:
		return ""
	return "%+d" % rounded


func _bonus_pct(bonus: float) -> String:
	var rounded := int(round(bonus * 100.0))
	if rounded == 0:
		return ""
	return "%+d %%" % rounded


func _bonus_rate(bonus: float) -> String:
	if absf(bonus) < 0.05:
		return ""
	return "%+.1f / s" % bonus
