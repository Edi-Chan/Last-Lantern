extends Control

## Atmosphaerischer Hintergrund fuer das Hauptmenue. Nur Visuals.

const ASSET_DIR := "res://assets/ui/main_menu/"
const MOON_TEXTURE := preload("res://assets/ui/day_night/moon.png")

const PARALLAX := {
	"Sky": 0.008,
	"Stars": 0.012,
	"Moon": 0.018,
	"Clouds": 0.022,
	"FarMountains": 0.028,
	"FarForest": 0.036,
	"FogBack": 0.04,
	"MidForest": 0.05,
	"Base": 0.058,
	"LanternGroup": 0.062,
	"FogFront": 0.07,
	"Foreground": 0.085,
}

@onready var _moon: TextureRect = $Moon
@onready var _fog_layer: ColorRect = $FogLayer
@onready var _lantern_glow: TextureRect = $LanternGroup/LanternGlow
@onready var _lantern_flame: TextureRect = $LanternGroup/LanternFlame
@onready var _stars: TextureRect = $Stars
@onready var _cloud_a: TextureRect = $Clouds/CloudA
@onready var _cloud_b: TextureRect = $Clouds/CloudB
@onready var _fog_back: TextureRect = $FogBack
@onready var _fog_front: TextureRect = $FogFront
@onready var _eyes: TextureRect = $Threats/Eyes
@onready var _zombie: TextureRect = $Threats/Zombie
@onready var _vignette: TextureRect = $Vignette
@onready var _dust: GPUParticles2D = $LanternGroup/DustParticles

var _layer_bases: Dictionary = {}
var _mouse_norm := Vector2.ZERO
var _time: float = 0.0
var _event_timer: float = 18.0
var _darkness_timer: float = 42.0
var _darkness_active: bool = false
var _darkness_strength: float = 0.0
var _zombie_active: bool = false
var _zombie_x: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_textures()
	_cache_layer_bases()
	if _moon != null:
		_moon.texture = MOON_TEXTURE
		_moon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _eyes != null:
		_eyes.modulate.a = 0.0
	if _zombie != null:
		_zombie.modulate.a = 0.0
	_event_timer = randf_range(15.0, 28.0)
	_darkness_timer = randf_range(30.0, 55.0)


func _setup_textures() -> void:
	_set_tex($Sky, "sky_gradient.png")
	_set_tex(_stars, "stars.png")
	_set_tex($FarMountains, "mountains.png")
	_set_tex($FarForest, "forest_far.png")
	_set_tex($MidForest, "forest_mid.png")
	_set_tex($Base, "base_hut.png")
	_set_tex($LanternGroup/Lantern, "lantern.png")
	_set_tex(_lantern_glow, "lantern_glow.png")
	_set_tex($Foreground, "foreground.png")
	_set_tex(_fog_back, "fog_strip.png")
	_set_tex(_fog_front, "fog_strip.png")
	_set_tex(_cloud_a, "cloud.png")
	_set_tex(_cloud_b, "cloud.png")
	_set_tex(_eyes, "eyes.png")
	_set_tex(_zombie, "zombie_sil.png")
	_set_tex(_vignette, "vignette.png")
	if _dust != null:
		var dust_tex := load(ASSET_DIR + "dust.png")
		if dust_tex is Texture2D:
			_dust.texture = dust_tex
			_dust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _set_tex(node: TextureRect, file_name: String) -> void:
	if node == null:
		return
	var tex := load(ASSET_DIR + file_name)
	if tex is Texture2D:
		node.texture = tex
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _cache_layer_bases() -> void:
	for child in get_children():
		if child is Control and child.name in PARALLAX:
			_layer_bases[child.name] = child.position
	if has_node("Clouds"):
		_layer_bases["Clouds"] = $Clouds.position
	if has_node("LanternGroup"):
		_layer_bases["LanternGroup"] = $LanternGroup.position
	if has_node("Threats"):
		_layer_bases["Threats"] = $Threats.position


func _process(delta: float) -> void:
	_time += delta
	_update_mouse_norm()
	_apply_parallax()
	_animate_sky_elements(delta)
	_animate_lantern(delta)
	_tick_events(delta)
	_animate_darkness(delta)


func _update_mouse_norm() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	var mouse := get_viewport().get_mouse_position()
	_mouse_norm = Vector2(
		(mouse.x / vp.x) * 2.0 - 1.0,
		(mouse.y / vp.y) * 2.0 - 1.0
	)


func _apply_parallax() -> void:
	for layer_name in PARALLAX.keys():
		if layer_name == "Moon":
			continue
		var node: Control = get_node_or_null(layer_name) as Control
		if node == null or not _layer_bases.has(layer_name):
			continue
		var factor: float = PARALLAX[layer_name]
		var base: Vector2 = _layer_bases[layer_name]
		var shift := Vector2(-_mouse_norm.x * factor * 48.0, -_mouse_norm.y * factor * 24.0)
		node.position = base + shift


func _animate_sky_elements(_delta: float) -> void:
	if _moon != null and _layer_bases.has("Moon"):
		var base: Vector2 = _layer_bases["Moon"]
		var factor: float = PARALLAX["Moon"]
		var shift := Vector2(-_mouse_norm.x * factor * 48.0, -_mouse_norm.y * factor * 24.0)
		_moon.position = base + shift + Vector2(0.0, sin(_time * 0.18) * 2.0)
	if _stars != null:
		_stars.modulate = Color(1, 1, 1, 0.82 + sin(_time * 1.7) * 0.06)
	if _cloud_a != null:
		_cloud_a.position.x = fmod(_time * 6.0, 520.0) - 40.0
	if _cloud_b != null:
		_cloud_b.position.x = fmod(180.0 + _time * 4.0, 520.0) - 40.0
	if _fog_back != null:
		_fog_back.position.x = sin(_time * 0.08) * 12.0
		_fog_back.modulate.a = 0.16 + sin(_time * 0.35) * 0.05
	if _fog_front != null:
		_fog_front.position.x = sin(_time * 0.12 + 1.2) * 18.0
		_fog_front.modulate.a = 0.22 + sin(_time * 0.42) * 0.06
	if _fog_layer != null:
		_fog_layer.modulate.a = 0.10 + sin(_time * 0.35) * 0.04


func _animate_lantern(_delta: float) -> void:
	if _lantern_glow == null:
		return
	var flicker := 0.94 + sin(_time * 3.2) * 0.04 + sin(_time * 7.5) * 0.02
	if _darkness_active:
		flicker *= 0.88 + sin(_time * 11.0) * 0.06
	_lantern_glow.modulate = Color(1.0, 0.92, 0.72, flicker)
	if _lantern_flame != null:
		var frame := int(_time * 3.0) % 3
		_lantern_flame.position.y = 10.0 + frame
		_lantern_flame.modulate.a = 0.85 + float(frame) * 0.05


func _tick_events(delta: float) -> void:
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = randf_range(18.0, 38.0)
		_trigger_random_event()
	if _zombie_active:
		_zombie_x += delta * 18.0
		if _zombie != null:
			_zombie.position.x = _zombie_x
			if _zombie_x > 520.0:
				_zombie_active = false
				_zombie.modulate.a = 0.0


func _trigger_random_event() -> void:
	match randi() % 5:
		0:
			_flash_eyes()
		1:
			_start_zombie_pass()
		2:
			_shooting_star()
		3:
			_lantern_sputter()
		_:
			_wind_rustle()


func _flash_eyes() -> void:
	if _eyes == null:
		return
	var tween := create_tween()
	_eyes.modulate.a = 0.0
	tween.tween_property(_eyes, "modulate:a", 0.85, 0.35)
	tween.tween_interval(0.8)
	tween.tween_property(_eyes, "modulate:a", 0.0, 0.6)


func _start_zombie_pass() -> void:
	if _zombie == null:
		return
	_zombie_active = true
	_zombie_x = -20.0
	_zombie.position = Vector2(_zombie_x, 190.0)
	_zombie.modulate.a = 0.55


func _shooting_star() -> void:
	if _stars == null:
		return
	var tween := create_tween()
	tween.tween_property(_stars, "modulate", Color(1.2, 1.15, 1.0, 1.0), 0.08)
	tween.tween_property(_stars, "modulate", Color(1, 1, 1, 0.85), 0.35)


func _lantern_sputter() -> void:
	if _lantern_glow == null:
		return
	var tween := create_tween()
	tween.tween_property(_lantern_glow, "modulate:a", 0.55, 0.05)
	tween.tween_property(_lantern_glow, "modulate:a", 1.0, 0.12)
	tween.tween_property(_lantern_glow, "modulate:a", 0.7, 0.06)
	tween.tween_property(_lantern_glow, "modulate:a", 1.0, 0.15)


func _wind_rustle() -> void:
	if _fog_front == null:
		return
	var tween := create_tween()
	tween.tween_property(_fog_front, "modulate:a", 0.34, 0.4)
	tween.tween_property(_fog_front, "modulate:a", 0.22, 0.8)


func _animate_darkness(delta: float) -> void:
	_darkness_timer -= delta
	if _darkness_timer <= 0.0 and not _darkness_active:
		_start_darkness_teaser()
	if not _darkness_active:
		return
	_darkness_strength = move_toward(_darkness_strength, 1.0 if _darkness_active else 0.0, delta * 1.6)
	if _fog_layer != null:
		_fog_layer.color = _fog_layer.color.lerp(Color(0.28, 0.15, 0.31, 0.14), _darkness_strength * 0.6)
	if _moon != null:
		_moon.modulate = Color(1, 1, 1, 1).lerp(Color(0.75, 0.62, 0.95, 1), _darkness_strength * 0.55)
	if _vignette != null:
		_vignette.modulate = Color(1, 1, 1, 1).lerp(Color(0.85, 0.75, 0.95, 1.08), _darkness_strength * 0.35)


func _start_darkness_teaser() -> void:
	_darkness_active = true
	_darkness_strength = 0.0
	_darkness_timer = randf_range(34.0, 58.0)
	_flash_eyes()
	var tween := create_tween()
	tween.tween_interval(1.6)
	tween.tween_callback(_end_darkness_teaser)


func _end_darkness_teaser() -> void:
	_darkness_active = false
	var tween := create_tween()
	tween.tween_method(_set_darkness_fade, _darkness_strength, 0.0, 1.2)


func _set_darkness_fade(value: float) -> void:
	_darkness_strength = value
	if _moon != null:
		_moon.modulate = Color(1, 1, 1, 1).lerp(Color(0.75, 0.62, 0.95, 1), value * 0.55)
	if _fog_layer != null:
		_fog_layer.color = Color(0.18, 0.16, 0.24, 0.14).lerp(Color(0.28, 0.15, 0.31, 0.14), value * 0.6)
