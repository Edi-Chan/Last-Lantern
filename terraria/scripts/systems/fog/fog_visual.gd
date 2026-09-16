class_name FogVisual
extends CanvasLayer

## Gehoert an: Main/FogVisual. Ein Screen-Space-Shader, kein Tile-Loop.

@export var settings: LastLanternSettings

const LightningPalette := preload("res://scripts/systems/fog/lightning_palette.gd")

@onready var _overlay: ColorRect = $Overlay

var lightning_intensity: float = 0.0

var _fog: FogEvent
var _material: ShaderMaterial
var _density: float = 0.0
var _time_scroll: float = 0.0
var _next_lightning: float = 2.0
var _flash: float = 0.0
var _pre_left: float = -1.0
var _peak_left: float = -1.0
var _second_flash_in: float = -1.0
var _thunder_in: float = -1.0
var _bolt: LightningFx
var _variant_id: int = LightningPalette.VariantId.PURPLE
var _force_next_bolt: bool = false


func _ready() -> void:
	add_to_group("fog_visual")
	layer = 8
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	if _overlay != null:
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_material = _overlay.material as ShaderMaterial
	call_deferred("_bind")


func _bind() -> void:
	_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	_bolt = get_tree().get_first_node_in_group("lightning_fx") as LightningFx


func _process(delta: float) -> void:
	if _material == null:
		return
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _bolt == null or not is_instance_valid(_bolt):
		_bolt = get_tree().get_first_node_in_group("lightning_fx") as LightningFx
	var target := 0.0
	if _fog != null:
		target = _fog.visual_density()
	_density = lerpf(_density, target, clampf(delta * 2.4, 0.0, 1.0))
	_time_scroll += delta
	_tick_lightning(delta)
	_material.set_shader_parameter("fog_density", _density)
	_material.set_shader_parameter("time_scroll", _time_scroll)
	_material.set_shader_parameter("lightning_intensity", lightning_intensity)
	_material.set_shader_parameter("lightning_color", LightningPalette.color_for(_variant_id))
	var debug_border := 0.0
	if settings != null and settings.show_debug_safe_radius:
		debug_border = 1.0
	_material.set_shader_parameter("debug_border", debug_border)
	var vp := get_viewport()
	if vp == null:
		return
	var view_size := vp.get_visible_rect().size
	_material.set_shader_parameter("view_size", view_size)
	var cam := vp.get_camera_2d() as Camera2D
	if cam != null:
		_material.set_shader_parameter("camera_center", cam.get_screen_center_position())
		_material.set_shader_parameter("camera_zoom", cam.zoom)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		_material.set_shader_parameter("player_world", player.global_position)
	_upload_safe_zones()
	if _fog != null:
		_fog.update_wind_hook(_density, _fog.player_is_safe)


func trigger_lightning(force_bolt: bool = false) -> void:
	if _density < 0.12 and not force_bolt:
		return
	_variant_id = LightningPalette.pick_variant()
	_force_next_bolt = force_bolt
	_pre_left = randf_range(0.05, 0.11)
	_peak_left = -1.0
	_flash = 0.20
	lightning_intensity = 0.20
	_second_flash_in = -1.0
	_thunder_in = randf_range(0.20, 1.20)
	if _material != null:
		_material.set_shader_parameter("lightning_color", LightningPalette.color_for(_variant_id))


func _tick_lightning(delta: float) -> void:
	if _pre_left >= 0.0:
		_pre_left -= delta
		_flash = 0.16 + 0.10 * absf(sin(_time_scroll * 28.0))
		if _pre_left <= 0.0:
			_pre_left = -1.0
			_flash = 1.0
			_peak_left = randf_range(0.035, 0.065)
			if _force_next_bolt or randf() < 0.68:
				_spawn_bolt()
			_force_next_bolt = false
			if randf() < 0.46:
				_second_flash_in = randf_range(0.05, 0.13)
	elif _peak_left >= 0.0:
		_peak_left -= delta
		_flash = 1.0
		if _peak_left <= 0.0:
			_peak_left = -1.0
			_flash = 0.0
	if _second_flash_in >= 0.0:
		_second_flash_in -= delta
		if _second_flash_in <= 0.0:
			_second_flash_in = -1.0
			_flash = maxf(_flash, 0.58)
			_peak_left = maxf(_peak_left, 0.03)
	if _pre_left < 0.0 and _peak_left < 0.0 and _flash > 0.0:
		_flash = maxf(_flash - delta * 7.8, 0.0)
	lightning_intensity = _flash
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in <= 0.0:
			_thunder_in = -1.0
			if _fog != null:
				_fog.play_thunder_hook()
	var storm := 0.0
	if _fog != null:
		match _fog.state:
			FogEvent.State.WARNING:
				storm = 0.28 + _fog.warning_progress() * 0.35
			FogEvent.State.FOG_ACTIVE:
				storm = 1.0
			FogEvent.State.FOG_ENDING:
				storm = _fog.ending_progress()
			_:
				storm = 0.0
	if storm <= 0.001:
		_next_lightning = randf_range(4.0, 8.0)
		return
	_next_lightning -= delta
	if _next_lightning > 0.0:
		return
	trigger_lightning(false)
	if storm > 0.8:
		_next_lightning = randf_range(4.0, 12.0)
	elif storm > 0.35:
		_next_lightning = randf_range(7.0, 16.0)
	else:
		_next_lightning = randf_range(10.0, 18.0)


func _spawn_bolt() -> void:
	if _bolt == null:
		return
	var center := Vector2.ZERO
	var radius := 0.0
	for node in get_tree().get_nodes_in_group("safe_zone"):
		var zone := node as SafeZone
		if zone != null and zone.is_active():
			center = zone.global_position
			radius = zone.get_radius_pixels()
			break
	var cam := get_viewport().get_camera_2d() as Camera2D
	var origin := center
	if cam != null:
		origin = cam.get_screen_center_position()
	var dir := Vector2(randf_range(-1.0, 1.0), randf_range(0.15, 1.0)).normalized()
	var dist := radius + randf_range(90.0, 460.0)
	var top := origin + Vector2(dir.x * dist, -randf_range(140.0, 340.0))
	var bottom := top + Vector2(randf_range(-70.0, 70.0), randf_range(150.0, 320.0))
	if center != Vector2.ZERO and top.distance_to(center) < radius + 24.0:
		top = center + (top - center).normalized() * (radius + 110.0)
		bottom = top + Vector2(randf_range(-40.0, 40.0), randf_range(160.0, 260.0))
	_bolt.strike(top, bottom, randf_range(0.07, 0.16), LightningPalette.color_for(_variant_id))


func _upload_safe_zones() -> void:
	var centers: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var radii := Vector4.ZERO
	var i := 0
	for node in get_tree().get_nodes_in_group("safe_zone"):
		if i >= 4:
			break
		var zone := node as SafeZone
		if zone == null or not zone.is_active():
			continue
		centers[i] = zone.global_position
		match i:
			0:
				radii.x = zone.get_radius_pixels()
			1:
				radii.y = zone.get_radius_pixels()
			2:
				radii.z = zone.get_radius_pixels()
			3:
				radii.w = zone.get_radius_pixels()
		i += 1
	_material.set_shader_parameter("safe_center_0", centers[0])
	_material.set_shader_parameter("safe_center_1", centers[1])
	_material.set_shader_parameter("safe_center_2", centers[2])
	_material.set_shader_parameter("safe_center_3", centers[3])
	_material.set_shader_parameter("safe_radii", radii)
