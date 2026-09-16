class_name SafeZoneVisual
extends Node2D

## Gehoert an: Lantern/SafeZoneVisual. Heiliger Schildrand, gleiche Quelle wie Gameplay-Radius.

const PAD_PX := 240.0

@export var underground_fade: float = 1.0

@onready var _overlay: ColorRect = $ShieldOverlay
@onready var _particles: GPUParticles2D = $EdgeParticles

var _zone: SafeZone
var _lantern: Lantern
var _material: ShaderMaterial
var _time: float = 0.0
var _particle_tex: Texture2D


func _ready() -> void:
	add_to_group("safe_zone_visual")
	z_as_relative = true
	_lantern = get_parent() as Lantern
	if _lantern != null:
		_zone = _lantern.get_node_or_null("SafeZone") as SafeZone
	if _overlay != null:
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_material = _overlay.material as ShaderMaterial
		if _material == null and _overlay.material is ShaderMaterial:
			_material = _overlay.material
	if _zone != null:
		if not _zone.radius_changed.is_connected(_on_radius_changed):
			_zone.radius_changed.connect(_on_radius_changed)
		_sync_rect(_zone.get_radius_pixels())
	_setup_particles()


func _process(delta: float) -> void:
	if _material == null:
		return
	_time += delta
	var pulse := 0.975 + sin(_time * 1.05) * 0.075
	var intensity := 0.32
	var lightning := 0.0
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null:
		match fog.state:
			FogEvent.State.WARNING:
				intensity = 0.52 + fog.warning_progress() * 0.28
			FogEvent.State.FOG_ACTIVE:
				intensity = 1.12
			FogEvent.State.FOG_ENDING:
				intensity = 0.42 + fog.ending_progress() * 0.70
			_:
				intensity = 0.32
	var vis := get_tree().get_first_node_in_group("fog_visual") as FogVisual
	if vis != null:
		lightning = vis.lightning_intensity
	var level := 1
	if _lantern != null:
		level = _lantern.level
	var level_power := clampf(float(level - 1) / 3.0, 0.0, 1.0)
	var debug_ring := 0.0
	if _lantern != null and _lantern.settings != null and _lantern.settings.show_debug_safe_radius:
		debug_ring = 1.0
	_material.set_shader_parameter("pulse", pulse)
	_material.set_shader_parameter("intensity", intensity)
	_material.set_shader_parameter("level_power", level_power)
	_material.set_shader_parameter("time_scroll", _time)
	_material.set_shader_parameter("lightning_boost", lightning)
	_material.set_shader_parameter("underground_fade", underground_fade)
	_material.set_shader_parameter("debug_ring", debug_ring)
	if _zone != null:
		_material.set_shader_parameter("radius_px", _zone.get_radius_pixels())
	_sync_particles(level, intensity)


func _on_radius_changed(radius_pixels: float) -> void:
	_sync_rect(radius_pixels)


func _sync_rect(radius_pixels: float) -> void:
	if _overlay == null:
		return
	var size := Vector2.ONE * (radius_pixels * 2.0 + PAD_PX)
	_overlay.size = size
	_overlay.position = -size * 0.5
	if _material != null:
		_material.set_shader_parameter("rect_size", size)
		_material.set_shader_parameter("radius_px", radius_pixels)


func _setup_particles() -> void:
	if _particles == null:
		return
	_particles.local_coords = true
	_particles.emitting = false
	_particles.texture = _particle_texture()
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.particle_flag_disable_z = true
	mat.emission_shape_offset = Vector3(0, -18, 0)
	mat.emission_ring_axis = Vector3(0, 0, 1)
	mat.emission_ring_height = 1.0
	mat.emission_ring_inner_radius = 300.0
	mat.emission_ring_radius = 308.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 28.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 11.0
	mat.gravity = Vector3(0, -7, 0)
	mat.scale_min = 0.12
	mat.scale_max = 0.32
	mat.color = Color(1.0, 0.86, 0.48, 0.72)
	mat.hue_variation_min = -0.02
	mat.hue_variation_max = 0.04
	_particles.process_material = mat
	_particles.lifetime = 2.2
	_particles.speed_scale = 0.65
	_particles.explosiveness = 0.0
	_particles.randomness = 0.35
	_particles.visibility_rect = Rect2(-4000, -4000, 8000, 8000)


func _sync_particles(level: int, intensity: float) -> void:
	if _particles == null or _zone == null:
		return
	var amount := 0
	match level:
		2:
			amount = 8
		3:
			amount = 14
		4:
			amount = 22
		_:
			amount = 0
	var active := amount > 0 and intensity > 0.55 and _zone.is_active()
	_particles.emitting = active
	if not active:
		return
	if _particles.amount != amount:
		_particles.amount = amount
	var mat := _particles.process_material as ParticleProcessMaterial
	if mat != null:
		var r := _zone.get_radius_pixels()
		mat.emission_ring_radius = r + 2.0
		mat.emission_ring_inner_radius = maxf(r - 8.0, 1.0)


func _particle_texture() -> Texture2D:
	if _particle_tex != null:
		return _particle_tex
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var center := Vector2(4.0, 4.0)
	for y in 8:
		for x in 8:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / 4.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			image.set_pixel(x, y, Color(1.0, 0.9, 0.55, a))
	_particle_tex = ImageTexture.create_from_image(image)
	return _particle_tex
