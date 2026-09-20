class_name Lava
extends Node2D

## Lava-spezifische Darstellung, Licht-Cluster und Partikel.
## Kein Node pro Tile: Lights und Emitter sind gepoolt und folgen der Kamera.

const LIGHT_TEXTURE_SIZE := 64
const UPDATE_INTERVAL := 0.22

@onready var _light_root: Node2D = $Visual/Light
@onready var _particles: GPUParticles2D = $Visual/Particles
@onready var _ambient_audio: AudioStreamPlayer2D = $AmbientAudio
@onready var _bubble_audio: AudioStreamPlayer2D = $BubbleAudio
@onready var _reaction_audio: AudioStreamPlayer2D = $ReactionAudio
@onready var _burn_audio: AudioStreamPlayer2D = $BurnAudio

var _system: LiquidSystem
var _lights: Array[PointLight2D] = []
var _light_texture: Texture2D
var _update_left: float = 0.0
var _pulse_time: float = 0.0
var _bubble_left: float = 1.2


func _ready() -> void:
	_system = get_parent() as LiquidSystem
	if _system == null:
		_system = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
	_light_texture = _make_radial_texture()
	_ensure_light_pool()
	if _particles != null:
		_particles.emitting = false
	if _ambient_audio != null and _ambient_audio.stream != null:
		_ambient_audio.play()


func play_reaction(cell: Vector2i) -> void:
	var world_pos := Vector2(cell) * float(_tile_size()) + Vector2(8, 8)
	_emit_sparks(world_pos, 0.8)
	_play_hook(_reaction_audio, world_pos)


func play_burn(world_pos: Vector2) -> void:
	_play_hook(_burn_audio, world_pos)


func play_bubble(world_pos: Vector2) -> void:
	_emit_sparks(world_pos, 0.35)
	_play_hook(_bubble_audio, world_pos)


func _process(delta: float) -> void:
	_pulse_time += delta
	_update_left -= delta
	_bubble_left -= delta
	if _system == null:
		return
	if _update_left <= 0.0:
		_update_left = UPDATE_INTERVAL
		_refresh_cluster_lights()
	_pulse_lights()
	if _bubble_left <= 0.0:
		_bubble_left = randf_range(1.4, 3.2)
		_maybe_spawn_surface_bubble()


func _refresh_cluster_lights() -> void:
	_ensure_light_pool()
	var settings := _settings()
	var chunk := maxi(settings.lava_light_chunk_size, 4)
	var view := _view_rect_cells()
	var clusters: Dictionary = {}
	var cells := _system.get_lava_cells()
	for cell in cells:
		if cell.x < view.position.x or cell.y < view.position.y:
			continue
		if cell.x >= view.end.x or cell.y >= view.end.y:
			continue
		if not _system.is_surface_cell(cell) and not _system.is_falling_cell(cell):
			continue
		var key := Vector2i(cell.x / chunk, cell.y / chunk)
		if not clusters.has(key):
			clusters[key] = cell
	var index := 0
	for key in clusters.keys():
		if index >= _lights.size():
			break
		var cell: Vector2i = clusters[key]
		var light := _lights[index]
		light.visible = true
		light.enabled = true
		light.position = Vector2(cell.x * _tile_size() + 8, cell.y * _tile_size() + 8)
		light.color = Color(1.0, 0.48, 0.16, 1.0)
		light.energy = settings.lava_light_intensity
		light.texture_scale = clampf(float(settings.lava_light_range) / 5.0, 1.1, 2.8)
		index += 1
	while index < _lights.size():
		_lights[index].visible = false
		_lights[index].enabled = false
		index += 1


func _pulse_lights() -> void:
	var settings := _settings()
	var pulse := 1.0 + 0.08 * sin(_pulse_time * 1.7)
	for light in _lights:
		if not light.visible:
			continue
		light.energy = settings.lava_light_intensity * pulse


func _maybe_spawn_surface_bubble() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or _system == null:
		return
	var origin := _system.world_to_cell(camera.get_screen_center_position())
	var candidates: Array[Vector2i] = []
	for dx in range(-10, 11):
		for dy in range(-7, 8):
			var cell := origin + Vector2i(dx, dy)
			if _system.has_lava(cell) and _system.is_surface_cell(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return
	var cell: Vector2i = candidates[randi() % candidates.size()]
	var world_pos := Vector2(cell.x * _tile_size() + 8, cell.y * _tile_size() + 4)
	play_bubble(world_pos)


func _emit_sparks(world_pos: Vector2, intensity: float) -> void:
	if _particles == null:
		return
	_particles.global_position = world_pos
	_particles.amount = clampi(int(4.0 * intensity), 2, _settings().lava_particle_budget)
	_particles.restart()
	_particles.emitting = true


func _ensure_light_pool() -> void:
	if _light_root == null:
		return
	var wanted := _settings().lava_max_cluster_lights
	while _lights.size() < wanted:
		var light := PointLight2D.new()
		light.texture = _light_texture
		light.shadow_enabled = false
		light.enabled = false
		light.visible = false
		_light_root.add_child(light)
		_lights.append(light)
	while _lights.size() > wanted:
		var extra := _lights.pop_back() as PointLight2D
		if extra != null:
			extra.queue_free()


func _view_rect_cells() -> Rect2i:
	var tile := _tile_size()
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return Rect2i(0, 0, _system.world_width, _system.world_height)
	var view := get_viewport().get_visible_rect().size / camera.zoom
	var top_left := camera.get_screen_center_position() - view * 0.5
	var origin := Vector2i(floori(top_left.x / float(tile)) - 4, floori(top_left.y / float(tile)) - 4)
	var size := Vector2i(int(ceil(view.x / float(tile))) + 8, int(ceil(view.y / float(tile))) + 8)
	return Rect2i(origin, size)


func _settings() -> LiquidSettings:
	if _system != null and _system.settings != null:
		return _system.settings
	return LiquidSettings.new()


func _tile_size() -> int:
	return _system.tile_size if _system != null else 16


func _play_hook(player: AudioStreamPlayer2D, world_pos: Vector2) -> void:
	if player == null or player.stream == null:
		return
	player.global_position = world_pos
	player.play()


func _make_radial_texture() -> Texture2D:
	var img := Image.create(LIGHT_TEXTURE_SIZE, LIGHT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(LIGHT_TEXTURE_SIZE * 0.5, LIGHT_TEXTURE_SIZE * 0.5)
	var radius := float(LIGHT_TEXTURE_SIZE) * 0.5
	for y in LIGHT_TEXTURE_SIZE:
		for x in LIGHT_TEXTURE_SIZE:
			var d := Vector2(float(x), float(y)).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
