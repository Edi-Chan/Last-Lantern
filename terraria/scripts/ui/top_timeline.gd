class_name TopTimeline
extends PanelContainer

## Gehoert an: HUD/TopTimeline. Nur Anzeige. DayCycle und FogEvent bleiben Source of Truth.

const LEFT_SAFE := 176.0
const RIGHT_SAFE := 224.0
const MIN_WIDTH := 360.0
const MAX_WIDTH := 520.0
const SLOT_COUNT := 7

const COL_MUTED := Color(0.70, 0.74, 0.80, 0.82)
const COL_CURRENT := Color(0.98, 0.90, 0.58, 1)
const COL_FOG := Color(0.95, 0.38, 0.34, 1)
const COL_FOG_DIM := Color(0.78, 0.42, 0.40, 0.92)
const COL_CLOCK := Color(0.93, 0.90, 0.78, 1)

var _day: DayCycle
var _fog: FogEvent
var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _cycle_start: int = -1
var _shown_day: int = -1
var _shown_clock := ""
var _shown_status := ""
var _shown_phase := -1
var _pulse: float = 0.0
var _last_track_w := -1.0
var _slot_style: StyleBox
var _fog_style: StyleBox

@onready var _day_row: HBoxContainer = $Margin/Rows/DayRow
@onready var _status: Label = $Margin/Rows/StatusLabel
@onready var _clock: Label = $Margin/Rows/ClockLabel
@onready var _track: Control = $Margin/Rows/Track
@onready var _marker: ColorRect = $Margin/Rows/Track/Marker
@onready var _sunrise: ColorRect = $Margin/Rows/Track/SunriseTick
@onready var _sunset: ColorRect = $Margin/Rows/Track/SunsetTick
@onready var _phase_morning: Label = $Margin/Rows/PhaseRow/Morning
@onready var _phase_noon: Label = $Margin/Rows/PhaseRow/Noon
@onready var _phase_evening: Label = $Margin/Rows/PhaseRow/Evening
@onready var _phase_night: Label = $Margin/Rows/PhaseRow/Night
@onready var _seg_night_l: ColorRect = $Margin/Rows/Track/SegNightL
@onready var _seg_morning: ColorRect = $Margin/Rows/Track/SegMorning
@onready var _seg_noon: ColorRect = $Margin/Rows/Track/SegNoon
@onready var _seg_evening: ColorRect = $Margin/Rows/Track/SegEvening
@onready var _seg_night_r: ColorRect = $Margin/Rows/Track/SegNightR


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_marker.z_index = 3
	_sunrise.z_index = 2
	_sunset.z_index = 2
	_collect_slots()
	if not SettingsManager.ui_scale_changed.is_connected(_on_ui_scale_changed):
		SettingsManager.ui_scale_changed.connect(_on_ui_scale_changed)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_fit_width):
		vp.size_changed.connect(_fit_width)
	call_deferred("_bind")
	call_deferred("_fit_width")
	set_process(true)


func _on_ui_scale_changed(_scale: float) -> void:
	_fit_width()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_fit_width()


func _process(delta: float) -> void:
	_pulse += delta
	_update_marker()
	_update_fog_pulse()


func _bind() -> void:
	_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _day != null:
		if not _day.day_changed.is_connected(_on_day_changed):
			_day.day_changed.connect(_on_day_changed)
		if not _day.time_changed.is_connected(_on_time_changed):
			_day.time_changed.connect(_on_time_changed)
	if _fog != null and not _fog.state_changed.is_connected(_on_fog_state):
		_fog.state_changed.connect(_on_fog_state)
	_refresh_days(true)
	_refresh_clock(true)
	_refresh_status(true)
	_refresh_phases(true)
	_fit_width()


func _on_day_changed(_day_n: int) -> void:
	_refresh_days(false)
	_refresh_status(true)


func _on_time_changed(_day_n: int, _time: float, _night: bool) -> void:
	_refresh_clock(false)
	_refresh_status(false)
	_refresh_phases(false)
	if _day != null and _day.current_day != _shown_day:
		_refresh_days(false)


func _on_fog_state(_state: int) -> void:
	_refresh_status(true)
	_refresh_days(true)


func _collect_slots() -> void:
	_slots.clear()
	_slot_labels.clear()
	if _day_row == null:
		return
	for child in _day_row.get_children():
		var panel := child as PanelContainer
		if panel == null:
			continue
		_slots.append(panel)
		var label := panel.get_node_or_null("DayLabel") as Label
		_slot_labels.append(label)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		if _slots.size() == 1:
			_slot_style = panel.get_theme_stylebox("panel")
		if _slots.size() == SLOT_COUNT:
			_fog_style = panel.get_theme_stylebox("panel")


func _settings() -> LastLanternSettings:
	if _day != null and _day.settings != null:
		return _day.settings
	if _fog != null:
		return _fog.settings
	return null


func _refresh_days(force: bool) -> void:
	var settings := _settings()
	if settings == null or _day == null or _slots.size() < SLOT_COUNT:
		return
	var day := _day.current_day
	var start := settings.cycle_start_day(day)
	if not force and start == _cycle_start and day == _shown_day:
		return
	_cycle_start = start
	_shown_day = day
	var fog_day := settings.cycle_fog_day(day)
	var days_left := settings.days_until_fog(day, _fog.fog_done_today() if _fog != null else false)
	for i in SLOT_COUNT:
		var slot_day := start + i
		var is_fog := slot_day == fog_day
		var is_current := slot_day == day
		var label := _slot_labels[i] if i < _slot_labels.size() else null
		var panel := _slots[i]
		if label != null:
			if is_fog:
				label.text = "⚠ TAG %d" % slot_day
			elif is_current:
				label.text = "[TAG %d]" % slot_day
			else:
				label.text = "TAG %d" % slot_day
			if is_current:
				label.add_theme_color_override("font_color", COL_FOG if is_fog else COL_CURRENT)
			elif is_fog:
				label.add_theme_color_override("font_color", COL_FOG_DIM)
			else:
				label.add_theme_color_override("font_color", COL_MUTED)
		_apply_slot_style(panel, is_current, is_fog)
		if is_fog:
			panel.tooltip_text = "TAG %d\n⚠ Tödliche Finsternis" % slot_day
		else:
			var left := fog_day - slot_day
			panel.tooltip_text = "TAG %d\nNormaler Tag\nFinsternis in %d Tagen" % [slot_day, left] if left > 0 else "TAG %d\nNormaler Tag" % slot_day
		panel.set_meta("days_left_to_fog", days_left)
		panel.set_meta("is_fog", is_fog)
		panel.set_meta("is_current", is_current)


func _refresh_clock(force: bool) -> void:
	if _day == null or _clock == null:
		return
	var settings := _settings()
	var icon := "☾"
	if settings != null:
		match settings.day_phase_at(_day.time_of_day):
			LastLanternSettings.DayPhase.MORNING:
				icon = "☀"
			LastLanternSettings.DayPhase.NOON:
				icon = "☀"
			LastLanternSettings.DayPhase.EVENING:
				icon = "◐"
			_:
				icon = "☾"
	var text := "%s %s" % [icon, _day.clock_text()]
	if not force and text == _shown_clock:
		return
	_shown_clock = text
	_clock.text = text


func _refresh_status(force: bool) -> void:
	if _status == null or _day == null:
		return
	var settings := _settings()
	var text := ""
	var color := COL_MUTED
	if _fog != null and (_fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING):
		text = "☠ TÖDLICHE FINSTERNIS AKTIV"
		color = COL_FOG
	elif _fog != null and _fog.state == FogEvent.State.WARNING:
		text = "Die Finsternis naht"
		color = Color(1.0, 0.72, 0.35, 1)
	elif settings != null:
		var done := _fog.fog_done_today() if _fog != null else false
		var left := settings.days_until_fog(_day.current_day, done)
		if left <= 0:
			text = "⚠ FINSTERNIS HEUTE"
			color = COL_FOG
		elif left == 1:
			text = "⚠ FINSTERNIS MORGEN"
			color = Color(0.95, 0.55, 0.38, 1)
		else:
			text = "Finsternis in %d Tagen" % left
			color = COL_MUTED
			if left <= 3:
				color = Color(0.90, 0.70, 0.48, 0.95)
	if not force and text == _shown_status:
		return
	_shown_status = text
	_status.text = text
	_status.add_theme_color_override("font_color", color)


func _refresh_phases(force: bool) -> void:
	var settings := _settings()
	if settings == null or _day == null:
		return
	var phase := int(settings.day_phase_at(_day.time_of_day))
	if not force and phase == _shown_phase:
		return
	_shown_phase = phase
	_set_phase_style(_phase_morning, phase == int(LastLanternSettings.DayPhase.MORNING))
	_set_phase_style(_phase_noon, phase == int(LastLanternSettings.DayPhase.NOON))
	_set_phase_style(_phase_evening, phase == int(LastLanternSettings.DayPhase.EVENING))
	_set_phase_style(_phase_night, phase == int(LastLanternSettings.DayPhase.NIGHT))


func _set_phase_style(label: Label, active: bool) -> void:
	if label == null:
		return
	label.modulate = Color(1, 1, 1, 1) if active else Color(0.72, 0.74, 0.78, 0.55)


func _update_marker() -> void:
	if _day == null or _track == null or _marker == null:
		return
	var width := _track.size.x
	if width <= 1.0:
		return
	var t := clampf(_day.time_of_day, 0.0, 0.999)
	var x := t * width - _marker.size.x * 0.5
	_marker.position = Vector2(clampf(x, 0.0, width - _marker.size.x), 1.0)
	if absf(width - _last_track_w) > 0.5:
		_last_track_w = width
		_layout_track_segments(width)


func _apply_slot_style(panel: PanelContainer, is_current: bool, is_fog: bool) -> void:
	var base := _fog_style if is_fog else _slot_style
	if base == null:
		panel.self_modulate = Color(1.28, 0.78, 0.72, 1) if is_current and is_fog else (Color(1.32, 1.18, 0.82, 1) if is_current else Color.WHITE)
		return
	var sb := base.duplicate() as StyleBoxFlat
	if sb == null:
		return
	if is_current:
		sb.border_color = Color(0.92, 0.32, 0.28, 0.95) if is_fog else Color(0.96, 0.86, 0.48, 0.95)
		sb.bg_color = Color(0.42, 0.12, 0.10, 0.55) if is_fog else Color(0.22, 0.20, 0.12, 0.55)
		panel.self_modulate = Color(1.12, 1.04, 0.96, 1)
	else:
		panel.self_modulate = Color.WHITE
	panel.add_theme_stylebox_override("panel", sb)


func _update_fog_pulse() -> void:
	if _slots.size() < SLOT_COUNT:
		return
	var fog_slot := _slots[SLOT_COUNT - 1]
	var days_left := int(fog_slot.get_meta("days_left_to_fog", 99))
	var is_current := bool(fog_slot.get_meta("is_current", false))
	if days_left > 3 and not is_current:
		if fog_slot.modulate != Color.WHITE:
			fog_slot.modulate = Color.WHITE
		return
	if days_left <= 0 or is_current:
		var u := 0.5 + 0.5 * sin(_pulse * 3.2)
		fog_slot.modulate = Color(1.0, 0.72 + 0.18 * u, 0.70, 1.0)
	elif days_left == 1:
		var u := 0.5 + 0.5 * sin(_pulse * 2.2)
		fog_slot.modulate = Color(1.0, 0.82 + 0.10 * u, 0.78, 1.0)
	else:
		fog_slot.modulate = Color(1.0, 0.90, 0.88, 1.0)


func _layout_track_segments(width: float) -> void:
	var settings := _settings()
	if settings == null:
		return
	var ne := settings.night_end_time
	var noon := settings.phase_noon_start
	var eve := minf(settings.phase_evening_start, settings.night_start_time)
	var ns := settings.night_start_time
	_place_seg(_seg_night_l, 0.0, ne, width)
	_place_seg(_seg_morning, ne, noon, width)
	_place_seg(_seg_noon, noon, eve, width)
	_place_seg(_seg_evening, eve, ns, width)
	_place_seg(_seg_night_r, ns, 1.0, width)
	if _sunrise != null:
		_sunrise.position = Vector2(clampf(ne * width - 1.0, 0.0, width - 2.0), 0.0)
		_sunrise.size = Vector2(2, 8)
	if _sunset != null:
		_sunset.position = Vector2(clampf(ns * width - 1.0, 0.0, width - 2.0), 0.0)
		_sunset.size = Vector2(2, 8)


func _place_seg(rect: ColorRect, from_t: float, to_t: float, width: float) -> void:
	if rect == null:
		return
	var x0 := from_t * width
	var x1 := to_t * width
	rect.position = Vector2(x0, 0.0)
	rect.size = Vector2(maxf(x1 - x0, 1.0), 8.0)


func _fit_width() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var width := vp.get_visible_rect().size.x
	var available := maxf(MIN_WIDTH, width - LEFT_SAFE - RIGHT_SAFE)
	var target := minf(MAX_WIDTH, available)
	offset_left = -target * 0.5
	offset_right = target * 0.5
	_last_track_w = -1.0
