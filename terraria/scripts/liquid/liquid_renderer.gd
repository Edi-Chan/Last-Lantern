class_name LiquidRenderer
extends Node2D

## Sparse Pixel-Art-Darstellung. Zeichnet nur Zellen mit Fluessigkeit.
## Wasser und Lava teilen den Draw-Pass, nutzen aber eigene Farben und Tempi.

var _system: LiquidSystem
var _draw_cells: Dictionary = {}
var _anim_time: float = 0.0
var _anim_frame: int = 0
var _lava_anim_frame: int = 0
var _surface_offsets: PackedInt32Array = PackedInt32Array([0, 1, 0, -1])

@onready var _splash_particles: GPUParticles2D = get_node_or_null("SplashParticles") as GPUParticles2D
@onready var _splash_audio: AudioStreamPlayer2D = get_node_or_null("SplashAudio") as AudioStreamPlayer2D
@onready var _flow_audio: AudioStreamPlayer2D = get_node_or_null("FlowAudio") as AudioStreamPlayer2D


func setup(system: LiquidSystem) -> void:
	_system = system
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	set_process(true)


func rebuild_from_system(system: LiquidSystem) -> void:
	_system = system
	_draw_cells.clear()
	if _system == null:
		queue_redraw()
		return
	for cell in _system.get_liquid_cells():
		_draw_cells[cell] = true
	queue_redraw()


func apply_dirty(dirty: Dictionary) -> void:
	if _system == null or dirty.is_empty():
		return
	for cell in dirty.keys():
		var c: Vector2i = cell
		if _system.get_amount(c) <= 0:
			_draw_cells.erase(c)
		else:
			_draw_cells[c] = true
	queue_redraw()


func mark_dirty(_cell: Vector2i) -> void:
	# Legacy hook — batched updates laufen über apply_dirty().
	pass


func mark_all_dirty() -> void:
	if _system != null:
		rebuild_from_system(_system)


func _process(delta: float) -> void:
	if _system == null or _system.settings == null:
		return
	if _draw_cells.is_empty():
		return
	var water_fps := maxf(_system.settings.surface_anim_fps, 1.0)
	var lava_fps := maxf(_system.settings.lava_surface_animation_speed, 1.0)
	_anim_time += delta
	var frame := int(floor(_anim_time * water_fps)) % _surface_offsets.size()
	var lava_frame := int(floor(_anim_time * lava_fps)) % _surface_offsets.size()
	if frame == _anim_frame and lava_frame == _lava_anim_frame:
		return
	_anim_frame = frame
	_lava_anim_frame = lava_frame
	queue_redraw()


func _draw() -> void:
	if _system == null or _system.settings == null:
		return
	var tile_size := _system.tile_size
	var settings := _system.settings
	var water_wave := int(_surface_offsets[_anim_frame])
	var lava_wave := int(_surface_offsets[_lava_anim_frame])
	for cell in _draw_cells.keys():
		var c: Vector2i = cell
		var amount := _system.get_amount(c)
		if amount <= 0:
			continue
		_draw_cell(c, amount, tile_size, settings, water_wave, lava_wave)


func _draw_cell(cell: Vector2i, amount: int, tile_size: int, settings: LiquidSettings, water_wave: int, lava_wave: int) -> void:
	var origin := Vector2(cell.x * tile_size, cell.y * tile_size)
	var fill_h := _system.quantized_fill_height(amount)
	var top_y := origin.y + float(tile_size - fill_h)
	var body_rect := Rect2(origin.x, top_y, float(tile_size), float(fill_h))
	var is_surface := _system.is_surface_cell(cell)
	var is_falling := _system.is_falling_cell(cell)
	if _system.get_type(cell) == LiquidTypes.Type.LAVA:
		_draw_lava_cell(cell, origin, body_rect, fill_h, tile_size, settings, is_surface, is_falling, lava_wave)
	elif is_falling:
		_draw_falling(origin, fill_h, tile_size, settings)
	elif is_surface:
		draw_rect(body_rect, settings.water_color, true)
		var surface_y := top_y + float(water_wave)
		draw_rect(Rect2(origin.x, surface_y, float(tile_size), 2.0), settings.water_surface_color, true)
	else:
		draw_rect(body_rect, _body_color(settings), true)
	if settings.debug_show_active_cells and _system.is_cell_active(cell):
		draw_rect(Rect2(origin, Vector2(tile_size, tile_size)), Color(1, 0.2, 0.2, 0.35), false, 1.0)
	if settings.debug_show_amounts:
		draw_string(ThemeDB.fallback_font, origin + Vector2(1, 10), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_lava_cell(
		cell: Vector2i,
		origin: Vector2,
		body_rect: Rect2,
		fill_h: int,
		tile_size: int,
		settings: LiquidSettings,
		is_surface: bool,
		is_falling: bool,
		wave: int
	) -> void:
	if is_falling:
		var width := clampi(settings.waterfall_width_px, 2, tile_size)
		var x := origin.x + float((tile_size - width) / 2)
		draw_rect(Rect2(x, body_rect.position.y, float(width), float(fill_h)), settings.lava_fall_color, true)
		return
	var pulse := 0.04 * sin(_anim_time * settings.lava_animation_speed + float(cell.x * 0.35 + cell.y * 0.2))
	var body := settings.lava_body_color
	if not is_surface:
		body = settings.lava_deep_color.lerp(settings.lava_body_color, 0.35 + pulse)
	else:
		body = settings.lava_color.lerp(settings.lava_body_color, 0.4 + pulse)
	draw_rect(body_rect, body, true)
	if fill_h >= 6:
		var dark_band := Rect2(origin.x, origin.y + float(tile_size) - 3.0, float(tile_size), 3.0)
		draw_rect(dark_band, settings.lava_deep_color, true)
	if is_surface:
		var surface_y := body_rect.position.y + float(wave)
		draw_rect(Rect2(origin.x, surface_y, float(tile_size), 2.0), settings.lava_surface_color, true)
		var spark := absi((cell.x * 17 + cell.y * 31 + _lava_anim_frame * 9) % 22)
		if spark < 2:
			draw_rect(Rect2(origin.x + float(4 + spark * 5), surface_y - 1.0, 2.0, 2.0), Color(1.0, 0.92, 0.45, 0.9), true)
		if spark == 7:
			draw_rect(Rect2(origin.x + 7.0, surface_y + 3.0, 2.0, 2.0), Color(1.0, 0.7, 0.2, 0.55), true)


func _draw_falling(origin: Vector2, fill_h: int, tile_size: int, settings: LiquidSettings) -> void:
	var width_value: Variant = settings.get("waterfall_width_px")
	var width := clampi(int(width_value) if width_value != null else 8, 2, tile_size)
	var x := origin.x + float((tile_size - width) / 2)
	var top_y := origin.y + float(tile_size - fill_h)
	draw_rect(Rect2(x, top_y, float(width), float(fill_h)), _fall_color(settings), true)


func _body_color(settings: LiquidSettings) -> Color:
	var value: Variant = settings.get("water_body_color")
	if value is Color:
		return value
	return settings.water_color


func _fall_color(settings: LiquidSettings) -> Color:
	var value: Variant = settings.get("water_fall_color")
	if value is Color:
		return value
	return settings.water_color


func spawn_splash(world_pos: Vector2, intensity: float = 1.0) -> void:
	if _splash_particles == null:
		return
	_splash_particles.global_position = world_pos
	_splash_particles.amount = clampi(int(6.0 * intensity), 3, 18)
	_splash_particles.restart()
	_splash_particles.emitting = true
	if _splash_audio != null and _splash_audio.stream != null:
		_splash_audio.global_position = world_pos
		_splash_audio.volume_db = clampf(-8.0 + intensity * 4.0, -16.0, 0.0)
		_splash_audio.play()


func spawn_bubbles(world_pos: Vector2) -> void:
	spawn_splash(world_pos, 0.35)
