class_name AdminMenu
extends Control

## Gehoert an: HUD/AdminMenu. Baut die Debug-Seiten zur Laufzeit aus echten Daten.

const WINDOW_SIZE := Vector2i(780, 540)
const SIDEBAR_W := 156
const REFRESH_INTERVAL := 0.15

enum Page { PLAYER, WORLD, TIME, EVENTS, SPAWN, ITEMS, DEBUG }

var _theme: Theme
var _panel: PanelContainer
var _pages: Dictionary = {}
var _nav_buttons: Dictionary = {}
var _current := Page.PLAYER
var _refresh_left: float = 0.0
var _confirm: Control
var _confirm_title: Label
var _confirm_body: Label
var _confirm_action: Callable
var _footer_active: Label
var _pause_button: Button

var _health_label: Label
var _god_button: Button
var _clip_button: Button
var _ai_button: Button
var _sta_button: Button
var _en_button: Button
var _speed_buttons: Dictionary = {}

var _day_label: Label
var _time_label: Label
var _phase_label: Label
var _dark_status: Label
var _wave_box: Control

var _spawn_search: LineEdit
var _spawn_list: VBoxContainer
var _spawn_amount: int = 1
var _spawn_amount_label: Label
var _spawn_mode: StringName = &"player"
var _spawn_selected: Resource
var _spawn_count_label: Label
var _mode_buttons: Dictionary = {}

var _item_search: LineEdit
var _item_filter: int = -1
var _item_list: VBoxContainer
var _item_qty: int = 1
var _item_qty_label: Label
var _item_selected: ItemData
var _item_detail: RichTextLabel
var _filter_buttons: Dictionary = {}
var _filter_host: HFlowContainer

var _fps_label: Label
var _debug_player: RichTextLabel
var _inspect_label: RichTextLabel
var _inspect_button: Button
var _collision_check: CheckBox
var _nav_check: CheckBox
var _liquid_perf_label: RichTextLabel

var _built: bool = false


func _ready() -> void:
	add_to_group("admin_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 80
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_theme = AdminTheme.make_theme()
	theme = _theme
	if not AdminManager.is_available():
		queue_free()
		return
	AdminManager.register_menu(self)
	if not AdminManager.modifiers_changed.is_connected(_on_modifiers_changed):
		AdminManager.modifiers_changed.connect(_on_modifiers_changed)
	_build()
	_built = true


func show_menu() -> void:
	if not AdminManager.is_available():
		return
	if not _built:
		_build()
		_built = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fit_panel()
	_refresh_all()
	_play_open()


func hide_menu() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _confirm != null:
		_confirm.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_panel()


func _fit_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	var w := mini(WINDOW_SIZE.x, maxi(int(vp.x) - 24, 320))
	var h := mini(WINDOW_SIZE.y, maxi(int(vp.y) - 24, 240))
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.pivot_offset = Vector2(w, h) * 0.5


func _play_open() -> void:
	if _panel == null:
		return
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.12)


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = REFRESH_INTERVAL
	_refresh_live()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _panel != null and not _panel.get_global_rect().has_point(event.position):
			if AdminManager.inspect_enemy:
				AdminManager.pick_enemy_at_mouse()
				_refresh_inspect()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not AdminManager.inspect_enemy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AdminManager.pick_enemy_at_mouse()
		_refresh_inspect()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.18)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dimmer_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(WINDOW_SIZE)
	_panel.theme = _theme
	_panel.add_theme_stylebox_override("panel", AdminTheme.box(AdminTheme.COL_BG, AdminTheme.COL_BORDER, Vector4(0, 0, 0, 0)))
	_panel.pivot_offset = Vector2(WINDOW_SIZE) * 0.5
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	_panel.add_child(root)

	root.add_child(_make_header())
	root.add_child(_hairline())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	body.add_child(_make_sidebar())
	body.add_child(_vline())
	body.add_child(_make_pages())

	root.add_child(_hairline())
	root.add_child(_make_footer())
	_build_confirm()
	_fit_panel()
	_show_page(Page.PLAYER)


func _make_header() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 34)
	bar.add_theme_constant_override("separation", 8)
	var pad := _padded(bar, 8, 6)
	var title := Label.new()
	title.text = "ADMIN / DEBUG"
	title.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	title.add_theme_font_size_override("font_size", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	_pause_button = _btn("PAUSE GAME", _on_pause_game, "Pausiert den Szenenbaum. Das Admin-Menü bleibt bedienbar.")
	_pause_button.custom_minimum_size = Vector2(88, 20)
	bar.add_child(_pause_button)
	var close := _btn("X", func() -> void: AdminManager.close_menu(), "Schließen")
	close.custom_minimum_size = Vector2(24, 20)
	close.add_theme_stylebox_override("normal", AdminTheme.box(AdminTheme.COL_DANGER, AdminTheme.COL_DANGER_BORDER, Vector4(6, 2, 6, 2)))
	bar.add_child(close)
	return pad


func _make_sidebar() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	side.add_theme_constant_override("separation", 3)
	var pad := _padded(side, 6, 8)
	var entries := [
		[Page.PLAYER, "PLAYER"],
		[Page.WORLD, "WORLD"],
		[Page.TIME, "TIME"],
		[Page.EVENTS, "EVENTS"],
		[Page.SPAWN, "SPAWN"],
		[Page.ITEMS, "ITEMS"],
		[Page.DEBUG, "DEBUG"],
	]
	for entry in entries:
		var page: Page = entry[0]
		var button := Button.new()
		button.text = String(entry[1])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 26)
		button.pressed.connect(_show_page.bind(page))
		side.add_child(button)
		_nav_buttons[page] = button
	return pad


func _make_pages() -> Control:
	var host := MarginContainer.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	host.add_theme_constant_override("margin_left", 10)
	host.add_theme_constant_override("margin_top", 8)
	host.add_theme_constant_override("margin_right", 10)
	host.add_theme_constant_override("margin_bottom", 8)
	_pages[Page.PLAYER] = _build_player_page()
	_pages[Page.WORLD] = _build_world_page()
	_pages[Page.TIME] = _build_time_page()
	_pages[Page.EVENTS] = _build_events_page()
	_pages[Page.SPAWN] = _build_spawn_page()
	_pages[Page.ITEMS] = _build_items_page()
	_pages[Page.DEBUG] = _build_debug_page()
	for page in _pages.values():
		host.add_child(page)
		page.visible = false
	return host


func _make_footer() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 26)
	var pad := _padded(bar, 8, 4)
	_footer_active = Label.new()
	_footer_active.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	_footer_active.add_theme_font_size_override("font_size", 9)
	_footer_active.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer_active.text = "Admin Mode"
	bar.add_child(_footer_active)
	var version := Label.new()
	version.add_theme_color_override("font_color", AdminTheme.COL_MUTED)
	version.add_theme_font_size_override("font_size", 9)
	version.text = "Dev  ·  %s" % ProjectSettings.get_setting("application/config/name", "Game")
	bar.add_child(version)
	return pad


func _build_player_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("PLAYER"))
	_health_label = _muted("Health:  - / -")
	col.add_child(_health_label)
	col.add_child(_row([
		_btn("-", func() -> void: AdminManager.adjust_health(-10.0), "Leben -10"),
		_btn("HEAL", func() -> void: AdminManager.adjust_health(25.0), "Heilt 25 Leben."),
		_btn("+", func() -> void: AdminManager.adjust_health(10.0), "Leben +10"),
	]))
	col.add_child(_row([
		_btn("FULL HEAL", func() -> void: AdminManager.full_heal(), "Setzt Leben, Ausdauer und Energie auf Maximum."),
		_danger("KILL PLAYER", func() -> void: _ask("Spieler töten?", "Setzt das Leben über PlayerStats.set_health(0).", func() -> void: AdminManager.kill_player()), "Tötet den Spieler über die echte Health-Logik."),
	]))
	_god_button = _toggle("God Mode  OFF", func() -> void: AdminManager.set_god_mode(not AdminManager.god_mode), "Verhindert Schaden am Spieler.")
	_clip_button = _toggle("No Clip  OFF", func() -> void: AdminManager.set_no_clip(not AdminManager.no_clip), "Deaktiviert Spielerkollision und erlaubt freie Bewegung.")
	_ai_button = _toggle("Invisible To AI  OFF", func() -> void: AdminManager.set_ai_ignore(not AdminManager.ai_ignore), "Gegner ignorieren den Spieler.")
	_sta_button = _toggle("Infinite Stamina  OFF", func() -> void: AdminManager.set_infinite_stamina(not AdminManager.infinite_stamina), "Sprint verbraucht keine Ausdauer.")
	_en_button = _toggle("Infinite Energy  OFF", func() -> void: AdminManager.set_infinite_energy(not AdminManager.infinite_energy), "Energy-Verbrauch wird übersprungen.")
	for button in [_god_button, _clip_button, _ai_button, _sta_button, _en_button]:
		col.add_child(button)
	col.add_child(_muted("Speed Multiplier"))
	var speeds := HBoxContainer.new()
	for value in [0.5, 1.0, 2.0, 5.0]:
		var label := "%sx" % str(value)
		var button := _btn(label, func() -> void: AdminManager.set_speed_multiplier(value), "Bewegungsgeschwindigkeit.")
		_speed_buttons[value] = button
		speeds.add_child(button)
	col.add_child(speeds)
	col.add_child(_danger("RESET ALL ADMIN MODIFIERS", func() -> void: AdminManager.reset_all_modifiers(), "Setzt alle temporären Cheats zurück."))
	return _scroll(col)


func _build_world_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("WORLD"))
	col.add_child(_row([
		_btn("SAVE WORLD", func() -> void: AdminManager.save_world(), "Speichert über SaveManager.save_game()."),
		_danger("RELOAD WORLD", func() -> void: _ask("Welt laden?", "Lädt den Spielstand über SaveManager.load_game().", func() -> void: AdminManager.reload_world()), "Lädt den Spielstand."),
	]))
	col.add_child(_row([
		_btn("TELEPORT TO SPAWN", func() -> void: AdminManager.teleport_to_spawn(), "Teleportiert zum Welt- oder Debug-Spawn."),
		_btn("SET DEBUG SPAWN", func() -> void: AdminManager.set_debug_spawn_here(), "Merkt die aktuelle Position als Debug-Spawn."),
	]))
	col.add_child(_muted("Spielgeschwindigkeit  (Engine.time_scale)"))
	var scales := HBoxContainer.new()
	for value in [0.25, 0.5, 1.0, 5.0, 20.0]:
		scales.add_child(_btn("%sx" % str(value), func() -> void: AdminManager.set_engine_time_scale(value), "Engine.time_scale"))
	col.add_child(scales)
	col.add_child(_row([
		_danger("REMOVE ALL DROPPED ITEMS", func() -> void: _ask("Drops entfernen?", "Löscht alle ItemDrop-Nodes.", func() -> void: AdminManager.remove_all_drops()), "Entfernt liegende Drops."),
		_danger("REMOVE ALL ENEMIES", func() -> void: _ask("Gegner entfernen?", "Entfernt Gegner ohne Todeslogik.", func() -> void: AdminManager.remove_all_enemies()), "Entfernt Gegner ohne normalen Tod/Loot."),
	]))
	col.add_child(_heading("LIQUID DEBUG"))
	col.add_child(_row([
		_btn("SIM ON/OFF", func() -> void: AdminManager.toggle_liquid_simulation(), "Schaltet die Wassersimulation um."),
		_btn("SHOW ACTIVE", func() -> void: AdminManager.toggle_liquid_active_overlay(), "Markiert aktive Wasserzellen."),
		_btn("SHOW AMOUNTS", func() -> void: AdminManager.toggle_liquid_amount_overlay(), "Zeigt Liquid Amount pro Zelle."),
	]))
	col.add_child(_row([
		_btn("SPAWN WATER", func() -> void: AdminManager.spawn_water_at_player(), "Füllt Wasser um den Spieler."),
		_btn("REMOVE WATER", func() -> void: AdminManager.remove_water_at_player(), "Entfernt Wasser um den Spieler."),
		_btn("INFINITE BREATH", func() -> void: AdminManager.toggle_infinite_breath(), "Unendlich Luft unter Wasser."),
	]))
	col.add_child(_row([
		_btn("FORCE BREATH 0", func() -> void: AdminManager.force_breath_zero(), "Setzt Atem auf 0."),
		_btn("FALL TEST", func() -> void: AdminManager.run_liquid_fall_test(), "Debug: Wasser fällt über Luft."),
		_btn("TRACK MASS", func() -> void: AdminManager.toggle_liquid_mass_tracking(), "Misst Total Water nur im Debug. Warnt bei Massendrift."),
	]))
	_liquid_perf_label = RichTextLabel.new()
	_liquid_perf_label.bbcode_enabled = true
	_liquid_perf_label.fit_content = true
	_liquid_perf_label.custom_minimum_size = Vector2(0, 148)
	col.add_child(_liquid_perf_label)
	return _scroll(col)


func _build_time_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("TIME"))
	_day_label = _muted("Current Day:  -")
	_time_label = _muted("Time of Day:  -")
	_phase_label = _muted("Phase:  -")
	col.add_child(_day_label)
	col.add_child(_time_label)
	col.add_child(_phase_label)
	col.add_child(_row([
		_btn("-", func() -> void: AdminManager.set_cycle_day(AdminManager.get_cycle_day() - 1), "Vorheriger Zyklustag"),
		_btn("DAY 1", func() -> void: AdminManager.set_cycle_day(1), "Zyklustag 1"),
		_btn("DAY 6", func() -> void: AdminManager.set_cycle_day(6), "Warnphase vor der Finsternis."),
		_btn("DAY 7", func() -> void: AdminManager.set_cycle_day(7), "Finsternis-Tag."),
		_btn("+", func() -> void: AdminManager.set_cycle_day(AdminManager.get_cycle_day() + 1), "Nächster Zyklustag"),
	]))
	col.add_child(_muted("Time"))
	col.add_child(_row([
		_btn("MORNING", func() -> void: AdminManager.set_phase(&"morning"), "DayCycle morning"),
		_btn("NOON", func() -> void: AdminManager.set_phase(&"noon"), "DayCycle noon"),
		_btn("EVENING", func() -> void: AdminManager.set_phase(&"evening"), "DayCycle evening"),
		_btn("NIGHT", func() -> void: AdminManager.set_phase(&"night"), "DayCycle night"),
	]))
	col.add_child(_muted("Calendar Speed  (LastLanternSettings.time_scale)"))
	col.add_child(_row([
		_btn("PAUSE", func() -> void: AdminManager.pause_calendar(true), "Hält nur die Ingame-Uhr an."),
		_btn("1x", func() -> void: AdminManager.set_calendar_time_scale(1.0), "Normale Tageslänge"),
		_btn("5x", func() -> void: AdminManager.set_calendar_time_scale(5.0), "Kalender 5x"),
		_btn("20x", func() -> void: AdminManager.set_calendar_time_scale(20.0), "Kalender 20x"),
	]))
	col.add_child(_row([
		_btn("10 SEC BEFORE NIGHT", func() -> void: AdminManager.set_seconds_before_night(10.0), "Springt kurz vor den Nachtbeginn."),
		_btn("10 SEC BEFORE DARKNESS", func() -> void: AdminManager.set_seconds_before_darkness(10.0), "Springt kurz vor den Beginn der nächsten Finsternis."),
	]))
	return _scroll(col)


func _build_events_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("FINSTERNIS"))
	_dark_status = _muted("Status:  -")
	col.add_child(_dark_status)
	col.add_child(_row([
		_btn("START DARKNESS", func() -> void: AdminManager.start_darkness(), "Ruft FogEvent.debug_jump_to_fog_night() auf."),
		_btn("STOP DARKNESS", func() -> void: AdminManager.stop_darkness(), "Ruft FogEvent.debug_end_fog() auf."),
		_btn("LIGHTNING", _strike_lightning, "Ruft FogEvent.debug_strike_lightning() auf."),
	]))
	col.add_child(_row([
		_btn("DARKNESS IN 10 SEC", func() -> void: AdminManager.set_seconds_before_darkness(10.0), "Springt kurz vor den Beginn der nächsten Finsternis."),
		_btn("JUMP TO DARKNESS NIGHT", func() -> void: AdminManager.jump_to_darkness_night(), "Setzt Tag 7 und Finsternis-Nacht."),
	]))
	col.add_child(_heading("WAVES"))
	_wave_box = _muted("Kein Wave-System im Projekt vorhanden.")
	col.add_child(_wave_box)
	return _scroll(col)


func _build_spawn_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("SPAWN ENEMY"))
	_spawn_search = LineEdit.new()
	_spawn_search.placeholder_text = "Suche Name / ID"
	_spawn_search.text_changed.connect(func(_t: String) -> void: _rebuild_spawn_list())
	col.add_child(_spawn_search)
	var list_wrap := ScrollContainer.new()
	list_wrap.custom_minimum_size = Vector2(0, 160)
	list_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spawn_list = VBoxContainer.new()
	_spawn_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_wrap.add_child(_spawn_list)
	col.add_child(list_wrap)
	_spawn_amount_label = _muted("Amount:  1")
	col.add_child(_spawn_amount_label)
	col.add_child(_row([
		_btn("-", func() -> void: _set_spawn_amount(_spawn_amount - 1), "Menge -1"),
		_btn("1", func() -> void: _set_spawn_amount(1), ""),
		_btn("5", func() -> void: _set_spawn_amount(5), ""),
		_btn("10", func() -> void: _set_spawn_amount(10), ""),
		_btn("25", func() -> void: _set_spawn_amount(25), ""),
		_btn("+", func() -> void: _set_spawn_amount(_spawn_amount + 1), "Menge +1"),
	]))
	col.add_child(_muted("Spawn Location"))
	var modes := HBoxContainer.new()
	for pair in [[&"player", "At Player"], [&"mouse", "At Mouse"], [&"spawn", "Normal Spawn"]]:
		var button := _btn(String(pair[1]), func() -> void: _set_spawn_mode(pair[0]), "Spawnposition")
		_mode_buttons[pair[0]] = button
		modes.add_child(button)
	col.add_child(modes)
	col.add_child(_btn("SPAWN", _on_spawn_pressed, "Spawnt den gewählten Gegner."))
	_spawn_count_label = _muted("Active Enemies:  0")
	col.add_child(_spawn_count_label)
	col.add_child(_row([
		_btn("KILL ALL", func() -> void: AdminManager.kill_all_enemies(), "Tötet Gegner über die normale Todeslogik."),
		_danger("REMOVE ALL", func() -> void: AdminManager.remove_all_enemies(), "Entfernt Gegner ohne normalen Tod/Loot."),
		_toggle("FREEZE AI", func() -> void: AdminManager.set_freeze_ai(not AdminManager.freeze_ai), "Pausiert Gegnerbewegung, ohne sie zu löschen."),
	]))
	return _scroll(col)


func _build_items_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("ITEMS"))
	_item_search = LineEdit.new()
	_item_search.placeholder_text = "Suche Name / ID / Kategorie"
	_item_search.text_changed.connect(func(_t: String) -> void: _rebuild_item_list())
	col.add_child(_item_search)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 3)
	filters.add_theme_constant_override("v_separation", 3)
	_add_filter(filters, -1, "ALL")
	col.add_child(filters)
	_filter_host = filters
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list_wrap := ScrollContainer.new()
	list_wrap.custom_minimum_size = Vector2(280, 180)
	list_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list = VBoxContainer.new()
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_wrap.add_child(_item_list)
	split.add_child(list_wrap)
	_item_detail = RichTextLabel.new()
	_item_detail.bbcode_enabled = true
	_item_detail.fit_content = true
	_item_detail.custom_minimum_size = Vector2(200, 180)
	_item_detail.scroll_active = true
	split.add_child(_item_detail)
	col.add_child(split)
	_item_qty_label = _muted("Quantity:  1")
	col.add_child(_item_qty_label)
	col.add_child(_row([
		_btn("-", func() -> void: _set_item_qty(_item_qty - 1), ""),
		_btn("1", func() -> void: _set_item_qty(1), ""),
		_btn("10", func() -> void: _set_item_qty(10), ""),
		_btn("100", func() -> void: _set_item_qty(100), ""),
		_btn("MAX", func() -> void: _give_selected(true), "Gibt einen vollen Stack."),
		_btn("+", func() -> void: _set_item_qty(_item_qty + 1), ""),
	]))
	col.add_child(_row([
		_btn("GIVE", func() -> void: _give_selected(false), "Legt das Item ins Inventar."),
		_btn("GIVE MAX STACK", func() -> void: _give_selected(true), "Gibt max_stack."),
	]))
	col.add_child(_row([
		_danger("CLEAR INVENTORY", func() -> void: _ask("Inventar leeren?", "Löscht alle Slots über Inventory.clear_all().", func() -> void: AdminManager.clear_inventory()), "Leert das Inventar."),
		_btn("GIVE ALL RESOURCES", func() -> void: AdminManager.give_all_of(func(item: ItemData) -> bool: return _is_resource_item(item)), "Gibt je 1 Stück aller Rohstoffe."),
		_btn("GIVE ALL TOOLS", func() -> void: AdminManager.give_all_of(func(item: ItemData) -> bool: return item.is_tool()), "Gibt je 1 Stück aller Werkzeuge."),
	]))
	return _scroll(col)


func _build_debug_page() -> Control:
	var col := _page_column()
	col.add_child(_heading("PERFORMANCE"))
	_fps_label = _muted("FPS:  -")
	col.add_child(_fps_label)
	col.add_child(_heading("VISUAL DEBUG"))
	_collision_check = CheckBox.new()
	_collision_check.text = "Collision Shapes"
	_collision_check.toggled.connect(func(on: bool) -> void: AdminManager.set_debug_collisions(on))
	_nav_check = CheckBox.new()
	_nav_check.text = "Navigation"
	_nav_check.toggled.connect(func(on: bool) -> void: AdminManager.set_debug_navigation(on))
	col.add_child(_collision_check)
	col.add_child(_nav_check)
	col.add_child(_heading("PLAYER DEBUG"))
	_debug_player = RichTextLabel.new()
	_debug_player.bbcode_enabled = true
	_debug_player.fit_content = true
	_debug_player.custom_minimum_size = Vector2(0, 110)
	col.add_child(_debug_player)
	col.add_child(_heading("ENEMY INSPECTOR"))
	_inspect_button = _toggle("INSPECT ENEMY  OFF", func() -> void: AdminManager.inspect_enemy = not AdminManager.inspect_enemy; _refresh_toggles(), "Danach einen Gegner in der Welt anklicken.")
	col.add_child(_inspect_button)
	_inspect_label = RichTextLabel.new()
	_inspect_label.bbcode_enabled = true
	_inspect_label.fit_content = true
	_inspect_label.custom_minimum_size = Vector2(0, 90)
	col.add_child(_inspect_label)
	col.add_child(_row([
		_btn("KILL", func() -> void: AdminManager.kill_enemy(AdminManager.selected_enemy), "Normale Todeslogik"),
		_danger("REMOVE", func() -> void: AdminManager.remove_enemy(AdminManager.selected_enemy), "Ohne Tod/Loot"),
		_btn("TELEPORT TO PLAYER", _teleport_selected_to_player, ""),
		_btn("FREEZE", func() -> void: _freeze_selected(), "Friert nur diesen Gegner ein."),
	]))
	col.add_child(_danger("RESET ALL ADMIN MODIFIERS", func() -> void: AdminManager.reset_all_modifiers(), "Setzt alle temporären Cheats zurück."))
	return _scroll(col)


func _show_page(page: Page) -> void:
	_current = page
	for key in _pages.keys():
		var node: Control = _pages[key]
		node.visible = key == page
	for key in _nav_buttons.keys():
		var button: Button = _nav_buttons[key]
		var active: bool = key == page
		button.add_theme_color_override("font_color", AdminTheme.COL_GOLD if active else AdminTheme.COL_MUTED)
		button.add_theme_stylebox_override("normal", AdminTheme.box(AdminTheme.COL_GOLD_DIM if active else AdminTheme.COL_PANEL_INNER, AdminTheme.COL_GOLD if active else AdminTheme.COL_BORDER))
	if page == Page.SPAWN:
		_rebuild_spawn_list()
	elif page == Page.ITEMS:
		_ensure_item_filters()
		_rebuild_item_list()
	_refresh_all()


func _refresh_all() -> void:
	_refresh_toggles()
	_refresh_live()


func _refresh_live() -> void:
	if not visible:
		return
	_refresh_footer()
	var stats := AdminManager.get_stats()
	if _health_label != null:
		if stats == null:
			_health_label.text = "Kein Spieler aktiv."
		else:
			_health_label.text = "Health:  %d / %d     STA %d / %d     EN %d / %d" % [
				ceili(stats.health), roundi(stats.max_health),
				ceili(stats.stamina), roundi(stats.max_stamina),
				ceili(stats.energy), roundi(stats.max_energy),
			]
	var day := AdminManager.get_day_cycle()
	if _day_label != null:
		if day == null:
			_day_label.text = "Current Day:  -"
		else:
			_day_label.text = "Current Day:  DAY %d / %d   (calendar %d)" % [
				AdminManager.get_cycle_day(), AdminManager.CYCLE_LENGTH, day.current_day,
			]
	if _time_label != null:
		if day == null:
			_time_label.text = "Time of Day:  -"
		else:
			var scale := day.settings.time_scale if day.settings != null else 1.0
			_time_label.text = "Time of Day:  %s  (%.3f)   scale %.1fx%s" % [
				day.clock_text(), day.time_of_day, scale, "  PAUSED" if scale <= 0.0 else "",
			]
	if _phase_label != null:
		_phase_label.text = "Phase:  %s" % String(AdminManager.get_phase())
	if _dark_status != null:
		_dark_status.text = "Status:  %s     Current Day:  %d / %d" % [
			String(AdminManager.darkness_status()), AdminManager.get_cycle_day(), AdminManager.CYCLE_LENGTH,
		]
	if _spawn_count_label != null:
		_spawn_count_label.text = "Active Enemies:  %d" % AdminManager.get_live_enemies().size()
	if _fps_label != null:
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "FPS:  %d     Frame:  %.1f ms     Enemies:  %d     Dropped Items:  %d" % [
			roundi(fps), 1000.0 / maxf(fps, 0.001),
			AdminManager.get_live_enemies().size(),
			AdminManager.get_dropped_item_count(),
		]
	_refresh_player_debug()
	_refresh_liquid_perf()
	_refresh_inspect()
	if _pause_button != null:
		_pause_button.text = "RESUME GAME" if get_tree().paused else "PAUSE GAME"


func _refresh_toggles() -> void:
	_set_toggle(_god_button, "God Mode", AdminManager.god_mode)
	_set_toggle(_clip_button, "No Clip", AdminManager.no_clip)
	_set_toggle(_ai_button, "Invisible To AI", AdminManager.ai_ignore)
	_set_toggle(_sta_button, "Infinite Stamina", AdminManager.infinite_stamina)
	_set_toggle(_en_button, "Infinite Energy", AdminManager.infinite_energy)
	_set_toggle(_inspect_button, "INSPECT ENEMY", AdminManager.inspect_enemy)
	for value in _speed_buttons.keys():
		var button: Button = _speed_buttons[value]
		var on := is_equal_approx(float(value), AdminManager.speed_multiplier)
		button.add_theme_color_override("font_color", AdminTheme.COL_GOLD if on else AdminTheme.COL_TEXT)
	for mode in _mode_buttons.keys():
		var button: Button = _mode_buttons[mode]
		button.add_theme_color_override("font_color", AdminTheme.COL_GOLD if mode == _spawn_mode else AdminTheme.COL_TEXT)
	var player := AdminManager.get_player()
	var has_player := player != null
	if _god_button != null:
		for child in _pages[Page.PLAYER].find_children("*", "Button", true, false):
			if child is Button:
				child.disabled = not has_player and String(child.text).find("RESET") < 0


func _refresh_footer() -> void:
	if _footer_active == null:
		return
	var names := AdminManager.active_modifier_names()
	_footer_active.text = "ACTIVE:  " + ", ".join(names) if not names.is_empty() else "Admin Mode"


func _refresh_player_debug() -> void:
	if _debug_player == null:
		return
	var player := AdminManager.get_player()
	var stats := AdminManager.get_stats()
	if player == null:
		_debug_player.text = "[color=#8D8D9A]Kein Spieler.[/color]"
		return
	var hp := "-"
	if stats != null:
		hp = "%d / %d" % [ceili(stats.health), roundi(stats.max_health)]
	_debug_player.text = "[color=#D8D8DF]Position:[/color]  %.1f , %.1f\n[color=#D8D8DF]Velocity:[/color]  %.1f , %.1f\n[color=#D8D8DF]Grounded:[/color]  %s\n[color=#D8D8DF]Biome:[/color]  %s\n[color=#D8D8DF]Weapon:[/color]  %s\n[color=#D8D8DF]Health:[/color]  %s\n[color=#D8D8DF]Animation:[/color]  %s" % [
		player.global_position.x, player.global_position.y,
		player.velocity.x, player.velocity.y,
		str(player.is_on_floor()),
		String(AdminManager.current_biome()),
		AdminManager.current_weapon_name(),
		hp,
		_player_anim(player),
	]


func _refresh_liquid_perf() -> void:
	if _liquid_perf_label == null:
		return
	_liquid_perf_label.text = AdminManager.get_liquid_debug_text()


func _player_anim(player: Player) -> String:
	var sprite := player.get_node_or_null("Visuals/BaseSprite") as AnimatedSprite2D
	if sprite == null:
		return "-"
	return String(sprite.animation)


func _refresh_inspect() -> void:
	if _inspect_label == null:
		return
	var enemy := AdminManager.selected_enemy
	if enemy == null or not is_instance_valid(enemy):
		_inspect_label.text = "[color=#8D8D9A]Kein Gegner gewählt.[/color]"
		return
	var hp := "-"
	if "current_health" in enemy and "max_health" in enemy:
		hp = "%s / %s" % [str(enemy.current_health), str(enemy.max_health)]
	elif "health" in enemy and "max_health" in enemy:
		hp = "%s / %s" % [str(enemy.health), str(enemy.max_health)]
	elif "health" in enemy:
		hp = str(enemy.health)
	var pos := Vector2.ZERO
	if enemy is Node2D:
		pos = (enemy as Node2D).global_position
	var player := AdminManager.get_player()
	var dist := 0.0
	if player != null:
		dist = pos.distance_to(player.global_position)
	var frozen := bool(enemy.get("frozen")) if "frozen" in enemy else false
	_inspect_label.text = "[color=#D8D8DF]Name:[/color]  %s\n[color=#D8D8DF]Health:[/color]  %s\n[color=#D8D8DF]Position:[/color]  %.1f , %.1f\n[color=#D8D8DF]AI State:[/color]  %s\n[color=#D8D8DF]Distance:[/color]  %.1f" % [
		enemy.name, hp, pos.x, pos.y, "frozen" if frozen else "idle", dist,
	]


func _rebuild_spawn_list() -> void:
	if _spawn_list == null:
		return
	for child in _spawn_list.get_children():
		child.queue_free()
	var query := _spawn_search.text.to_lower() if _spawn_search != null else ""
	var enemies := AdminManager.get_all_enemies()
	var shown := 0
	for enemy in enemies:
		var hay := ("%s %s" % [enemy.display_name, String(enemy.id)]).to_lower()
		if not query.is_empty() and hay.find(query) < 0:
			continue
		_spawn_list.add_child(_enemy_row(enemy))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "No enemies available."
		empty.add_theme_color_override("font_color", AdminTheme.COL_MUTED)
		_spawn_list.add_child(empty)


func _enemy_row(enemy: Resource) -> Control:
	var row := HBoxContainer.new()
	if enemy.icon != null:
		var icon := TextureRect.new()
		icon.texture = enemy.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
	var button := Button.new()
	button.text = "%s    [%s]" % [enemy.display_name, String(enemy.id)]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _spawn_selected == enemy:
		button.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	button.pressed.connect(func() -> void:
		_spawn_selected = enemy
		_rebuild_spawn_list()
	)
	row.add_child(button)
	return row


func _ensure_item_filters() -> void:
	if _filter_host == null or _filter_host.get_child_count() > 1:
		return
	var seen := {}
	for item in AdminManager.get_all_items():
		if item == null or item.category == ItemData.ItemCategory.UNASSIGNED:
			continue
		seen[int(item.category)] = true
	var keys := seen.keys()
	keys.sort()
	for key in keys:
		var cat := key as int
		_add_filter(_filter_host, cat, ItemData.get_category_display_name(cat as ItemData.ItemCategory))


func _add_filter(host: Control, id: int, label: String) -> void:
	var button := _btn(label, func() -> void: _item_filter = id; _rebuild_item_list(), "")
	_filter_buttons[id] = button
	host.add_child(button)


func _rebuild_item_list() -> void:
	if _item_list == null:
		return
	for child in _item_list.get_children():
		child.queue_free()
	var query := _item_search.text if _item_search != null else ""
	var items := AdminManager.get_all_items()
	var shown := 0
	for item in items:
		if not AdminManager.item_matches(item, query, _item_filter):
			continue
		_item_list.add_child(_item_row(item))
		shown += 1
	if shown == 0:
		var empty := Label.new()
		empty.text = "No items available."
		empty.add_theme_color_override("font_color", AdminTheme.COL_MUTED)
		_item_list.add_child(empty)
	_refresh_item_detail()
	for id in _filter_buttons.keys():
		var button: Button = _filter_buttons[id]
		button.add_theme_color_override("font_color", AdminTheme.COL_GOLD if int(id) == _item_filter else AdminTheme.COL_TEXT)


func _item_row(item: ItemData) -> Control:
	var row := HBoxContainer.new()
	if item.icon != null:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(20, 20)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	info.add_theme_constant_override("separation", 0)
	var name_l := Label.new()
	name_l.text = item.display_name
	name_l.add_theme_font_size_override("font_size", 11)
	if _item_selected == item:
		name_l.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	info.add_child(name_l)
	var id_l := Label.new()
	id_l.text = "id %d  ·  %s" % [item.id, item.get_kind_display_name()]
	id_l.add_theme_font_size_override("font_size", 8)
	id_l.add_theme_color_override("font_color", AdminTheme.COL_MUTED)
	info.add_child(id_l)
	row.add_child(info)
	var give := _btn("GIVE", func() -> void:
		_item_selected = item
		_give_selected(false)
		_rebuild_item_list()
	, "Ins Inventar legen")
	give.custom_minimum_size = Vector2(52, 20)
	row.add_child(give)
	info.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_item_selected = item
			_rebuild_item_list()
	)
	return row


func _refresh_item_detail() -> void:
	if _item_detail == null:
		return
	var item := _item_selected
	if item == null:
		_item_detail.text = "[color=#8D8D9A]Kein Item gewählt.[/color]"
		return
	var lines := PackedStringArray()
	lines.append("[color=#D6AD45]%s[/color]" % item.display_name)
	lines.append("ID  %d" % item.id)
	var cat := ItemData.get_category_display_name(item.category)
	if not cat.is_empty():
		lines.append("Kategorie  %s" % cat)
	lines.append("Typ  %s" % item.get_kind_display_name())
	lines.append("Stack  %d" % item.max_stack)
	if item.get_base_damage() > 0:
		lines.append("Damage  %d" % item.get_base_damage())
	if "attack_cooldown" in item and item.attack_cooldown > 0.0:
		lines.append("Cooldown  %.2f" % item.attack_cooldown)
	if item.defense > 0:
		lines.append("Defense  %d" % item.defense)
	if item.get_sell_value() > 0:
		lines.append("Value  %d" % item.get_sell_value())
	_item_detail.text = "\n".join(lines)


func _give_selected(max_stack: bool) -> void:
	if _item_selected == null:
		return
	if max_stack:
		AdminManager.give_max_stack(_item_selected)
	else:
		AdminManager.give_item(_item_selected.id, _item_qty)


func _set_spawn_amount(value: int) -> void:
	_spawn_amount = clampi(value, 1, 99)
	if _spawn_amount_label != null:
		_spawn_amount_label.text = "Amount:  %d" % _spawn_amount


func _set_spawn_mode(mode: StringName) -> void:
	_spawn_mode = mode
	_refresh_toggles()


func _on_spawn_pressed() -> void:
	if _spawn_selected == null:
		var all := AdminManager.get_all_enemies()
		if all.is_empty():
			return
		_spawn_selected = all[0]
	AdminManager.spawn_enemy(_spawn_selected, _spawn_amount, _spawn_mode)


func _set_item_qty(value: int) -> void:
	_item_qty = clampi(value, 1, 999)
	if _item_qty_label != null:
		_item_qty_label.text = "Quantity:  %d" % _item_qty


func _teleport_selected_to_player() -> void:
	var enemy := AdminManager.selected_enemy
	var player := AdminManager.get_player()
	if enemy is Node2D and player != null:
		(enemy as Node2D).global_position = player.global_position + Vector2(24, 0)


func _freeze_selected() -> void:
	var enemy := AdminManager.selected_enemy
	if enemy != null and "frozen" in enemy:
		enemy.frozen = true


func _strike_lightning() -> void:
	var fog := AdminManager.get_fog()
	if fog != null:
		fog.debug_strike_lightning()


func _on_pause_game() -> void:
	AdminManager.pause_game(not get_tree().paused)
	_refresh_live()


func _on_modifiers_changed() -> void:
	_refresh_toggles()
	_refresh_footer()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if AdminManager.inspect_enemy:
			AdminManager.pick_enemy_at_mouse()
			_refresh_inspect()
		accept_event()


func _ask(title: String, body: String, action: Callable) -> void:
	_confirm_action = action
	if _confirm == null:
		return
	_confirm.visible = true
	if _confirm_title != null:
		_confirm_title.text = title
	if _confirm_body != null:
		_confirm_body.text = body


func _build_confirm() -> void:
	_confirm = ColorRect.new()
	_confirm.name = "ConfirmOverlay"
	_confirm.color = Color(0, 0, 0, 0.45)
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.visible = false
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.z_index = 10
	add_child(_confirm)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(280, 120)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.name = "Col"
	margin.add_child(col)
	_confirm_title = Label.new()
	_confirm_title.name = "Title"
	_confirm_title.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	col.add_child(_confirm_title)
	_confirm_body = Label.new()
	_confirm_body.name = "Body"
	_confirm_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_body.add_theme_font_size_override("font_size", 10)
	col.add_child(_confirm_body)
	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(_btn("Abbrechen", func() -> void: _confirm.visible = false, ""))
	row.add_child(_danger("Bestätigen", func() -> void:
		_confirm.visible = false
		if _confirm_action.is_valid():
			_confirm_action.call()
	, ""))


func _page_column() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	return col


func _scroll(col: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	return scroll


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", AdminTheme.COL_GOLD)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", AdminTheme.COL_MUTED)
	label.add_theme_font_size_override("font_size", 10)
	return label


func _row(children: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for child in children:
		if child is Control:
			row.add_child(child)
	return row


func _btn(text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(0, 22)
	button.pressed.connect(action)
	return button


func _toggle(text: String, action: Callable, tip: String) -> Button:
	return _btn(text, action, tip)


func _danger(text: String, action: Callable, tip: String) -> Button:
	var button := _btn(text, action, tip)
	button.add_theme_stylebox_override("normal", AdminTheme.box(AdminTheme.COL_DANGER, AdminTheme.COL_DANGER_BORDER))
	button.add_theme_color_override("font_color", Color("E8C8C8"))
	return button


func _set_toggle(button: Button, label: String, on: bool) -> void:
	if button == null:
		return
	button.text = "%s  %s" % [label, "ON" if on else "OFF"]
	button.add_theme_color_override("font_color", AdminTheme.COL_GOLD if on else AdminTheme.COL_TEXT)


func _padded(inner: Control, h: int, v: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", h)
	margin.add_theme_constant_override("margin_right", h)
	margin.add_theme_constant_override("margin_top", v)
	margin.add_theme_constant_override("margin_bottom", v)
	margin.add_child(inner)
	if inner is VBoxContainer or inner is HBoxContainer:
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return margin


func _hairline() -> ColorRect:
	var line := ColorRect.new()
	line.color = AdminTheme.COL_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _vline() -> ColorRect:
	var line := ColorRect.new()
	line.color = AdminTheme.COL_BORDER
	line.custom_minimum_size = Vector2(1, 0)
	return line


static func _is_resource_item(item: ItemData) -> bool:
	if item == null:
		return false
	return item.item_type == ItemData.ItemType.MATERIAL \
		or item.item_type == ItemData.ItemType.BLOCK \
		or item.category == ItemData.ItemCategory.RESOURCE \
		or item.category == ItemData.ItemCategory.ORE_METAL \
		or item.category == ItemData.ItemCategory.BUILDING_MATERIAL
