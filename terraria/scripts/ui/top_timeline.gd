class_name TopTimeline
extends Control

## Gehoert an: HUD/TopTimeline. Nur Anzeige. DayCycle und FogEvent bleiben Source of Truth.

enum VisualState { NORMAL, WARNING, DARKNESS }

const HUD_WIDTH := 284.0
const HUD_HEIGHT := 54.0
const COL_TICK := Color("F2EEE6")
const COL_TICK_GLOW := Color("FFFFFF", 0.35)
const TOP_MARGIN := 16.0
const BAR_SIZE := Vector2(220, 10)
const ICON_PX := 22
const MARKER_W := 7.0
const PULSE_SECONDS := 2.0
const BANNER_SECONDS := 2.2

const COL_FRAME := Color("15151C")
const COL_FRAME_WARN := Color("3A2438")
const COL_FRAME_DARK := Color("4A1824")
const COL_LABEL := Color("C8C4BC")
const COL_LABEL_WARN := Color("D4B49A")
const COL_LABEL_DARK := Color("C47878")
const COL_DASH := Color("5A5868")

const BAR_NORMAL: Array[Color] = [
	Color("6FA8C8"),
	Color("8EC4D8"),
	Color("B8C8A0"),
	Color("E0C46A"),
	Color("D4884A"),
	Color("6A4A88"),
	Color("3A2A58"),
]
const BAR_WARNING: Array[Color] = [
	Color("6FA8C8"),
	Color("8EC4D8"),
	Color("C4B878"),
	Color("D4884A"),
	Color("8A4068"),
	Color("5A2848"),
	Color("2E1838"),
]
const BAR_DARKNESS: Array[Color] = [
	Color("2A2030"),
	Color("4A1824"),
	Color("5A2040"),
	Color("3A1838"),
	Color("2A1028"),
	Color("1A0C1C"),
	Color("120814"),
]

var _day: DayCycle
var _fog: FogEvent
var _state: VisualState = VisualState.NORMAL
var _progress: float = 0.0
var _displayed_progress: float = 0.0
var _pulse: float = 0.0
var _banner_left: float = 0.0
var _last_fog_state: int = -1
var _shown_day: int = -1
var _shown_clock: String = ""

@onready var _sun: TextureRect = $Margin/Column/TimeRow/SunIcon
@onready var _moon: TextureRect = $Margin/Column/TimeRow/MoonIcon
@onready var _bar: Control = $Margin/Column/TimeRow/TimeBarContainer/TimeBar
@onready var _marker: TextureRect = $Margin/Column/TimeRow/TimeBarContainer/TimeBar/TimeMarker
@onready var _frame: Panel = $Margin/Column/TimeRow/TimeBarContainer/BarFrame
@onready var _day_label: Label = $Margin/Column/DayRow/DayLabel
@onready var _clock_label: Label = $Margin/Column/DayRow/ClockLabel
@onready var _banner: Label = $Margin/Column/EclipseBanner


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_layout()
	_apply_icon_textures()
	if _banner != null:
		_banner.visible = false
	if _bar != null:
		_bar.clip_contents = false
		if not _bar.draw.is_connected(_on_bar_draw):
			_bar.draw.connect(_on_bar_draw)
	if not SettingsManager.ui_scale_changed.is_connected(_on_ui_scale_changed):
		SettingsManager.ui_scale_changed.connect(_on_ui_scale_changed)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_apply_layout):
		vp.size_changed.connect(_apply_layout)
	call_deferred("_bind")
	set_process(true)


func _on_ui_scale_changed(_scale: float) -> void:
	_apply_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_apply_layout()


func _process(delta: float) -> void:
	var need := _day != null
	if _day != null:
		_progress = _calc_progress(_day.time_of_day)
		_displayed_progress = _progress
		_place_marker()
		_refresh_clock_label(false)
		if _bar != null:
			_bar.queue_redraw()
	if _state == VisualState.DARKNESS and _is_fog_running() and _frame != null:
		_pulse += delta
		var wave := 0.5 + 0.5 * sin(_pulse * TAU / PULSE_SECONDS)
		_frame.modulate = Color(1, 1, 1, lerpf(0.75, 1.0, wave))
		need = true
	elif _frame != null and not is_equal_approx(_frame.modulate.a, 1.0):
		_frame.modulate = Color.WHITE
	if _banner_left > 0.0:
		_banner_left = maxf(0.0, _banner_left - delta)
		if _banner != null:
			_banner.visible = true
			_banner.modulate.a = clampf(_banner_left / 0.35, 0.0, 1.0) if _banner_left < 0.35 else 1.0
		need = true
	elif _banner != null and _banner.visible:
		_banner.visible = false
	if not need:
		set_process(false)


func _bind() -> void:
	_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _day != null:
		if not _day.time_changed.is_connected(_on_time_changed):
			_day.time_changed.connect(_on_time_changed)
		if not _day.day_changed.is_connected(_on_day_changed):
			_day.day_changed.connect(_on_day_changed)
	if _fog != null and not _fog.state_changed.is_connected(_on_fog_state):
		_fog.state_changed.connect(_on_fog_state)
	_refresh_all(true)


func _on_day_changed(_day_n: int) -> void:
	_refresh_all(true)


func _on_time_changed(_day_n: int, time_of_day: float, _night: bool) -> void:
	_apply_progress(time_of_day)
	update_visual_state()
	_refresh_day_label(false)
	_refresh_clock_label(true)
	_update_icons()


func _on_fog_state(state: int) -> void:
	var became_active := (
		state == FogEvent.State.FOG_ACTIVE
		and _last_fog_state != FogEvent.State.FOG_ACTIVE
	)
	_last_fog_state = state
	update_visual_state()
	if became_active:
		_show_banner()


func _refresh_all(_force: bool) -> void:
	if _day == null:
		return
	_apply_progress(_day.time_of_day)
	update_visual_state()
	_refresh_day_label(true)
	_refresh_clock_label(true)
	_update_icons()
	_place_marker()
	if _bar != null:
		_bar.queue_redraw()


func _apply_progress(time_of_day: float) -> void:
	_progress = _calc_progress(time_of_day)
	if absf(_progress - _displayed_progress) > 0.5 or _displayed_progress == 0.0:
		_displayed_progress = _progress
	_place_marker()
	if _bar != null:
		_bar.queue_redraw()
	_ensure_process()


func _calc_progress(time_of_day: float) -> float:
	var settings := _settings()
	var day_start := 0.25
	if settings != null:
		day_start = settings.night_end_time
	return fposmod(time_of_day - day_start, 1.0)


func update_visual_state() -> void:
	var settings := _settings()
	var next := VisualState.NORMAL
	if _is_fog_running() or _is_fog_day():
		next = VisualState.DARKNESS
	elif _is_warning_day(settings):
		next = VisualState.WARNING
	_state = next
	_apply_frame_style()
	_apply_day_label_color()
	_apply_label_color()
	if _bar != null:
		_bar.queue_redraw()
	_ensure_process()


func _settings() -> LastLanternSettings:
	if _day != null and _day.settings != null:
		return _day.settings
	if _fog != null:
		return _fog.settings
	return null


func _cycle_index(day: int) -> int:
	var settings := _settings()
	if settings == null:
		return posmod(day - 1, 7) + 1
	return day - settings.cycle_start_day(day) + 1


func _is_fog_day() -> bool:
	var settings := _settings()
	return settings != null and _day != null and settings.is_fog_day(_day.current_day)


func _is_warning_day(settings: LastLanternSettings) -> bool:
	if settings == null or _day == null:
		return false
	var done := _fog.fog_done_today() if _fog != null else false
	return settings.days_until_fog(_day.current_day, done) == 1


func _is_fog_running() -> bool:
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _refresh_day_label(force: bool) -> void:
	if _day_label == null or _day == null:
		return
	var day := _day.current_day
	if not force and day == _shown_day:
		return
	_shown_day = day
	var settings := _settings()
	var interval := 7
	if settings != null:
		interval = maxi(settings.fog_interval_days, 1)
	_day_label.text = "Tag %d / %d" % [_cycle_index(day), interval]


func _refresh_clock_label(force: bool) -> void:
	if _clock_label == null or _day == null:
		return
	var text := _day.clock_text()
	if not force and text == _shown_clock:
		return
	_shown_clock = text
	_clock_label.text = text


func _apply_label_color() -> void:
	if _clock_label == null:
		return
	match _state:
		VisualState.WARNING:
			_clock_label.add_theme_color_override("font_color", COL_LABEL_WARN)
		VisualState.DARKNESS:
			_clock_label.add_theme_color_override("font_color", COL_LABEL_DARK)
		_:
			_clock_label.add_theme_color_override("font_color", COL_LABEL)


func _apply_day_label_color() -> void:
	if _day_label == null:
		return
	match _state:
		VisualState.WARNING:
			_day_label.add_theme_color_override("font_color", COL_LABEL_WARN)
		VisualState.DARKNESS:
			_day_label.add_theme_color_override("font_color", COL_LABEL_DARK)
		_:
			_day_label.add_theme_color_override("font_color", COL_LABEL)


func _apply_frame_style() -> void:
	if _frame == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.anti_aliasing = false
	match _state:
		VisualState.WARNING:
			box.border_color = COL_FRAME_WARN
		VisualState.DARKNESS:
			box.border_color = COL_FRAME_DARK
		_:
			box.border_color = COL_FRAME
	_frame.add_theme_stylebox_override("panel", box)


func _update_icons() -> void:
	if _day == null:
		return
	var settings := _settings()
	if settings != null:
		var _phase := settings.day_phase_at(_day.time_of_day)
	var sun_v := _day.sun_visibility()
	var moon_v := _day.moon_visibility()
	if _sun != null:
		var dim := lerpf(0.72, 1.0, sun_v)
		if _state == VisualState.DARKNESS:
			dim *= 0.75
		_sun.modulate = Color(1.0, 1.0, 1.0, dim)
	if _moon != null:
		var glow := lerpf(0.72, 1.0, moon_v)
		match _state:
			VisualState.WARNING:
				_moon.modulate = Color(0.92, 0.78, 1.0, maxf(glow, 0.82))
			VisualState.DARKNESS:
				_moon.modulate = Color(1.0, 0.55, 0.62, maxf(glow, 0.88))
			_:
				_moon.modulate = Color(1.0, 1.0, 1.0, maxf(glow, 0.82))


func _place_marker() -> void:
	if _marker == null or _bar == null:
		return
	var inner_w := _bar.size.x if _bar.size.x > 1.0 else BAR_SIZE.x
	var x := roundf(_displayed_progress * maxf(inner_w - 1.0, 1.0) - MARKER_W * 0.5)
	x = clampf(x, -1.0, inner_w - MARKER_W + 1.0)
	_marker.position = Vector2(x, -6.0)


func _on_bar_draw() -> void:
	if _bar == null:
		return
	var colors := BAR_NORMAL
	match _state:
		VisualState.WARNING:
			colors = BAR_WARNING
		VisualState.DARKNESS:
			colors = BAR_DARKNESS
	var bar_size := _bar.size
	var bounds := _phase_band_bounds()
	var segments := mini(colors.size(), maxi(bounds.size() - 1, 0))
	var x := 0.0
	for i in segments:
		var t1: float = bounds[i + 1]
		var x1 := roundf(t1 * bar_size.x)
		_bar.draw_rect(Rect2(x, 0.0, maxf(x1 - x, 1.0), bar_size.y), colors[i], true)
		x = x1
	_bar.draw_rect(Rect2(0.0, 0.0, 1.0, bar_size.y), COL_FRAME, true)
	_bar.draw_rect(Rect2(bar_size.x - 1.0, 0.0, 1.0, bar_size.y), COL_FRAME, true)
	_draw_time_tick(bar_size)


func _draw_time_tick(bar_size: Vector2) -> void:
	var tick_x := roundf(_displayed_progress * maxf(bar_size.x - 1.0, 1.0))
	tick_x = clampf(tick_x, 0.0, bar_size.x - 1.0)
	_bar.draw_rect(Rect2(tick_x - 1.0, -1.0, 3.0, bar_size.y + 2.0), COL_TICK_GLOW, true)
	_bar.draw_rect(Rect2(tick_x, 0.0, 1.0, bar_size.y), COL_TICK, true)


func _phase_band_bounds() -> PackedFloat32Array:
	## Liest night_end_time, phase_noon_start, phase_evening_start, night_start_time
	## nur fuer die Pixel-Balken — keine Gameplay-Aenderung.
	var settings := _settings()
	var ne := 0.25
	var noon := 0.458333
	var eve := 0.708333
	var ns := 0.75
	if settings != null:
		ne = settings.night_end_time
		noon = settings.phase_noon_start
		eve = settings.phase_evening_start
		ns = settings.night_start_time
	var span := maxf(1.0 - ne, 0.001)
	# colors.size() == 7 → bounds braucht 8 Stuetzpunkte (0..7).
	return PackedFloat32Array([
		0.0,
		_time_to_bar_u(ne + span * 0.12, ne, span),
		_time_to_bar_u(noon, ne, span),
		_time_to_bar_u(noon + (eve - noon) * 0.55, ne, span),
		_time_to_bar_u(eve, ne, span),
		_time_to_bar_u(eve + (ns - eve) * 0.45, ne, span),
		_time_to_bar_u(ns, ne, span),
		1.0,
	])


func _time_to_bar_u(t: float, day_start: float, span: float) -> float:
	return clampf((t - day_start) / span, 0.0, 1.0)


func _show_banner() -> void:
	if _banner == null:
		return
	_banner.text = "FINSTERNIS"
	_banner.visible = true
	_banner.modulate = COL_LABEL_DARK
	_banner_left = BANNER_SECONDS
	_ensure_process()


func _ensure_process() -> void:
	var need := (
		_day != null
		or not is_equal_approx(_displayed_progress, _progress)
		or (_state == VisualState.DARKNESS and _is_fog_running())
		or _banner_left > 0.0
	)
	set_process(need)


func _apply_layout() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -roundf(HUD_WIDTH * 0.5)
	offset_right = roundf(HUD_WIDTH * 0.5)
	offset_top = TOP_MARGIN
	offset_bottom = TOP_MARGIN + HUD_HEIGHT
	_place_marker()


func _apply_icon_textures() -> void:
	if _sun != null:
		_sun.texture = _build_sun_texture()
		_sun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sun.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		_sun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_sun.stretch_mode = TextureRect.STRETCH_KEEP
	if _moon != null:
		_moon.texture = _build_moon_texture()
		_moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_moon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		_moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_moon.stretch_mode = TextureRect.STRETCH_KEEP
	if _marker != null:
		_marker.texture = _build_marker_texture()
		_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_marker.stretch_mode = TextureRect.STRETCH_KEEP


func _build_sun_texture() -> ImageTexture:
	var img := Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var y1 := Color("F4C14A")
	var y2 := Color("FFF3A8")
	var ray_col := Color("E8943A")
	for p in [Vector2i(11, 1), Vector2i(11, 2), Vector2i(11, 19), Vector2i(11, 20), Vector2i(1, 11), Vector2i(2, 11), Vector2i(19, 11), Vector2i(20, 11)]:
		img.set_pixel(p.x, p.y, ray_col)
	for y in range(7, 15):
		for x in range(7, 15):
			if Vector2(x - 10.5, y - 10.5).length() <= 4.0:
				img.set_pixel(x, y, y1)
	for y in range(8, 14):
		for x in range(8, 14):
			if Vector2(x - 10.5, y - 10.5).length() <= 2.8:
				img.set_pixel(x, y, y2)
	return ImageTexture.create_from_image(img)


func _build_moon_texture() -> ImageTexture:
	var img := Image.create(ICON_PX, ICON_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var m1 := Color("C8C0D8")
	var m2 := Color("E8E0F0")
	var m3 := Color("8B7AA8")
	var st := Color("B8A8D0")
	for y in range(5, 18):
		for x in range(6, 19):
			if Vector2(x - 12, y - 11).length() <= 6.0:
				img.set_pixel(x, y, m1)
	for y in range(5, 18):
		for x in range(6, 19):
			if Vector2(x - 15, y - 10).length() <= 4.7:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in range(6, 17):
		for x in range(6, 14):
			if img.get_pixel(x, y).a > 0.0 and x <= 8:
				img.set_pixel(x, y, m3)
	img.set_pixel(8, 8, m2)
	img.set_pixel(9, 9, m2)
	for p in [Vector2i(17, 4), Vector2i(19, 8), Vector2i(18, 16), Vector2i(3, 6), Vector2i(2, 15)]:
		img.set_pixel(p.x, p.y, st)
	return ImageTexture.create_from_image(img)


func _build_marker_texture() -> ImageTexture:
	var w := 7
	var h := 5
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color("ECE8E0")
	var rows: Array = [
		[0, 0, 0, 1, 0, 0, 0],
		[0, 0, 1, 1, 1, 0, 0],
		[0, 1, 1, 1, 1, 1, 0],
		[0, 0, 1, 1, 1, 0, 0],
		[0, 0, 0, 1, 0, 0, 0],
	]
	for y in h:
		for x in w:
			if rows[y][x] == 1:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
