class_name LiquidRenderer
extends Node2D

## Sparse Pixel-Art-Wasser-Darstellung. Zeichnet nur Zellen mit Wasser.

var _system: LiquidSystem
var _draw_cells: Dictionary = {}
var _anim_phase: float = 0.0
var _surface_offsets: PackedInt32Array = PackedInt32Array([0, 1, 0, -1])
var _needs_anim_redraw: bool = false

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
	for cell in _system.get_water_cells():
		_draw_cells[cell] = true
	queue_redraw()


func apply_dirty(dirty: Dictionary) -> void:
	if _system == null or dirty.is_empty():
		return
	var limit := _system.settings.max_dirty_render_updates if _system.settings != null else 512
	var count := 0
	for cell in dirty.keys():
		if count >= limit:
			break
		var c: Vector2i = cell
		if _system.get_amount(c) <= 0:
			_draw_cells.erase(c)
		else:
			_draw_cells[c] = true
		count += 1
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
	_anim_phase += delta * _system.settings.surface_anim_fps
	var frame_step := 1.0 / maxf(_system.settings.surface_anim_fps, 1.0)
	if _anim_phase >= frame_step:
		_anim_phase = fmod(_anim_phase, frame_step)
		_needs_anim_redraw = true
		queue_redraw()


func _draw() -> void:
	if _system == null or _system.settings == null:
		return
	var tile_size := float(_system.tile_size)
	var settings := _system.settings
	var frame_idx := int(_anim_phase / maxf(1.0 / settings.surface_anim_fps, 0.001)) % _surface_offsets.size()
	var wave_offset := float(_surface_offsets[frame_idx])
	_needs_anim_redraw = false
	for cell in _draw_cells.keys():
		var c: Vector2i = cell
		var amount := _system.get_amount(c)
		if amount <= 0:
			continue
		_draw_cell(c, amount, tile_size, settings, wave_offset)


func _draw_cell(cell: Vector2i, amount: int, tile_size: float, settings: LiquidSettings, wave_offset: float) -> void:
	var origin := Vector2(float(cell.x), float(cell.y)) * tile_size
	var fill_h := (float(amount) / float(LiquidTypes.FULL)) * tile_size
	var top_y := origin.y + tile_size - fill_h
	draw_rect(Rect2(origin.x, top_y, tile_size, fill_h), settings.water_color, true)
	draw_rect(Rect2(origin.x, top_y + wave_offset, tile_size, 2.0), settings.water_surface_color, true)
	if settings.debug_show_active_cells and _system.is_cell_active(cell):
		draw_rect(Rect2(origin, Vector2(tile_size, tile_size)), Color(1, 0.2, 0.2, 0.35), false, 1.0)
	if settings.debug_show_amounts:
		draw_string(ThemeDB.fallback_font, origin + Vector2(1, 10), str(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


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
