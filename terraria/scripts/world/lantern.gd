class_name Lantern
extends Node2D

## Gehoert an: World/Entities/Lantern. Basis-Laterne mit Licht, SafeZone und Interaktion.

signal level_changed(level: int)
signal safe_radius_changed(radius_tiles: float)
signal active_changed(is_active: bool)
signal interaction_opened(lantern: Lantern)

@export var settings: LastLanternSettings
@export var start_level: int = 1
@export var is_lantern_active: bool = true

var level: int = 1
var fuel: float = 1.0
var max_fuel: float = 1.0
var _player_in_range: bool = false

@onready var _base_sprite: Sprite2D = $Visuals/BaseSprite
@onready var _glow_sprite: Sprite2D = $Visuals/GlowSprite
@onready var _beam_sprite: Sprite2D = get_node_or_null("Visuals/BeamSprite")
@onready var _light: PointLight2D = $PointLight2D
@onready var _safe_zone: SafeZone = $SafeZone
@onready var _interact: Area2D = $InteractionArea
@onready var _hint: Label = $HintLabel

var _base_energy: float = 1.15
var _base_texture_scale: float = 4.0


func _ready() -> void:
	add_to_group("lantern")
	if settings == null:
		settings = load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
	_ensure_light_texture()
	if _interact != null:
		_interact.collision_layer = 0
		_interact.collision_mask = 2
		_interact.monitoring = true
		if not _interact.body_entered.is_connected(_on_body_entered):
			_interact.body_entered.connect(_on_body_entered)
		if not _interact.body_exited.is_connected(_on_body_exited):
			_interact.body_exited.connect(_on_body_exited)
	if _hint != null:
		_hint.visible = false
	level = start_level
	apply_level(level, false)
	set_lantern_active(is_lantern_active)
	call_deferred("place_near_spawn")


func _process(_delta: float) -> void:
	_update_fog_light()
	if not _player_in_range:
		return
	if UIManager.is_blocking_gameplay():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.world_input_enabled:
		return
	var menu := get_tree().get_first_node_in_group("lantern_ui")
	if menu != null and menu.has_method("is_open") and bool(menu.call("is_open")):
		return
	if not InputMap.has_action("interact"):
		return
	if Input.is_action_just_pressed("interact"):
		open_menu()


func place_near_spawn() -> void:
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null or settings == null:
		return
	var offset := settings.lantern_spawn_offset_tiles
	var tile_x := world.spawn_tile.x + offset
	if world.has_method("ground_world_position"):
		global_position = world.call("ground_world_position", tile_x)
	else:
		var size := float(settings.tile_size)
		global_position = Vector2(float(tile_x) * size + size * 0.5, float(world.get_surface_y(tile_x)) * size - 1.0)


func apply_level(next_level: int, emit_change: bool = true) -> void:
	if settings == null:
		return
	var max_level := settings.max_lantern_level()
	level = clampi(next_level, 1, max_level)
	var data := settings.get_level_data(level)
	if data == null:
		return
	_apply_visual(data)
	_apply_light(data)
	if _safe_zone != null:
		_safe_zone.set_radius_tiles(float(data.safe_radius_tiles), settings.tile_size)
		_safe_zone.set_zone_active(is_lantern_active)
	safe_radius_changed.emit(float(data.safe_radius_tiles))
	if emit_change:
		level_changed.emit(level)


func current_data() -> LanternLevelData:
	if settings == null:
		return null
	return settings.get_level_data(level)


func next_data() -> LanternLevelData:
	if settings == null:
		return null
	return settings.get_level_data(level + 1)


func is_max_level() -> bool:
	if settings == null:
		return true
	return level >= settings.max_lantern_level()


func get_safe_radius_tiles() -> float:
	var data := current_data()
	return float(data.safe_radius_tiles) if data != null else 44.0


func get_safe_radius_pixels() -> float:
	if _safe_zone != null:
		return _safe_zone.get_radius_pixels()
	var size := 16
	if settings != null:
		size = settings.tile_size
	return get_safe_radius_tiles() * float(size)


func set_lantern_active(value: bool) -> void:
	is_lantern_active = value
	if _safe_zone != null:
		_safe_zone.set_zone_active(value)
	if _light != null:
		_light.enabled = value
	if _glow_sprite != null:
		_glow_sprite.visible = value
	active_changed.emit(value)


func try_upgrade(inventory: Inventory) -> Dictionary:
	var result := {
		"ok": false,
		"reason": "",
		"missing": [],
	}
	if inventory == null:
		result["reason"] = "no_inventory"
		return result
	if is_max_level():
		result["reason"] = "max"
		return result
	var nxt := next_data()
	if nxt == null:
		result["reason"] = "max"
		return result
	var costs := nxt.get_upgrade_costs()
	var missing: Array = []
	if not inventory.can_consume_items(costs):
		for cost in costs:
			var have := inventory.get_bag_amount(int(cost["item_id"]))
			var need := int(cost["amount"])
			if have < need:
				missing.append({
					"item_id": int(cost["item_id"]),
					"need": need,
					"have": have,
				})
		result["reason"] = "missing"
		result["missing"] = missing
		return result
	if not inventory.try_consume_items(costs):
		result["reason"] = "missing"
		return result
	apply_level(level + 1, true)
	result["ok"] = true
	return result


func open_menu() -> void:
	interaction_opened.emit(self)
	var menu := get_tree().get_first_node_in_group("lantern_ui")
	if menu != null and menu.has_method("open_for"):
		menu.call("open_for", self)


func _apply_visual(data: LanternLevelData) -> void:
	if _base_sprite == null:
		return
	_base_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if data.texture != null:
		_base_sprite.texture = _texture_with_alpha(data.texture)
		var width := float(data.texture.get_width())
		var scale_v := data.sprite_width_px / maxf(width, 1.0)
		_base_sprite.scale = Vector2(scale_v, scale_v)
		_base_sprite.centered = true
		var height := float(data.texture.get_height()) * scale_v
		_base_sprite.position = Vector2(0.0, -height * 0.5)
		if _glow_sprite != null:
			_glow_sprite.position = Vector2(0.0, -height * 0.62)
			_glow_sprite.scale = Vector2(1.15 + float(level) * 0.28, 1.15 + float(level) * 0.28)
		if _beam_sprite != null:
			_beam_sprite.position = Vector2(0.0, -height * 0.95)
			_beam_sprite.scale = Vector2(0.55 + float(level) * 0.12, 1.15 + float(level) * 0.22)
		if _hint != null:
			_hint.position = Vector2(-48.0, -height - 12.0)
		if _light != null:
			_light.position = Vector2(0.0, -height * 0.62)
	_base_sprite.offset = Vector2.ZERO


func _apply_light(data: LanternLevelData) -> void:
	_base_energy = data.light_energy
	_base_texture_scale = data.light_texture_scale
	if _light == null:
		return
	_light.color = Color(1.0, 0.72, 0.38, 1.0)
	_light.energy = _base_energy
	_light.texture_scale = _base_texture_scale
	_light.enabled = is_lantern_active
	_light.shadow_enabled = false


func _texture_with_alpha(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var image := Image.new()
	var loaded := false
	if not tex.resource_path.is_empty():
		loaded = image.load(tex.resource_path) == OK
	if not loaded:
		image = tex.get_image()
	if image == null:
		return tex
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.size.x >= 8 and used.size.y >= 8 and used.size != image.get_size():
		image = image.get_region(used)
	return ImageTexture.create_from_image(image)


func _ensure_light_texture() -> void:
	if _light != null and _light.texture == null:
		_light.texture = _make_radial_texture(256, Color(1, 1, 1, 1))
	if _glow_sprite != null and _glow_sprite.texture == null:
		_glow_sprite.texture = _make_radial_texture(64, Color(1.0, 0.55, 0.18, 1))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow_sprite.material = mat
	_ensure_beam()


func _ensure_beam() -> void:
	if _beam_sprite == null:
		var visuals := get_node_or_null("Visuals")
		if visuals == null:
			return
		_beam_sprite = Sprite2D.new()
		_beam_sprite.name = "BeamSprite"
		visuals.add_child(_beam_sprite)
		visuals.move_child(_beam_sprite, 0)
	if _beam_sprite.texture == null:
		_beam_sprite.texture = _make_beam_texture()
		_beam_sprite.centered = true
		_beam_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_beam_sprite.material = mat
		_beam_sprite.modulate = Color(1.0, 0.82, 0.42, 0.0)


func _make_beam_texture() -> Texture2D:
	var width := 24
	var height := 96
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var mid := float(width) * 0.5
	for y in height:
		var ty := float(y) / float(height)
		var fall := clampf(1.0 - ty, 0.0, 1.0)
		fall *= fall
		for x in width:
			var dx := absf(float(x) + 0.5 - mid) / mid
			var a := clampf(1.0 - dx, 0.0, 1.0)
			a *= a * fall
			image.set_pixel(x, y, Color(1.0, 0.88, 0.55, a))
	return ImageTexture.create_from_image(image)


func _update_fog_light() -> void:
	var fog_boost := 0.0
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null:
		match fog.state:
			FogEvent.State.WARNING:
				fog_boost = 0.35 + fog.warning_progress() * 0.25
			FogEvent.State.FOG_ACTIVE:
				fog_boost = 1.0
			FogEvent.State.FOG_ENDING:
				fog_boost = fog.ending_progress() * 0.85
			_:
				fog_boost = 0.0
	var pulse := 0.92 + sin(Time.get_ticks_msec() * 0.0032) * 0.08
	if fog_boost > 0.01:
		pulse = 0.88 + sin(Time.get_ticks_msec() * 0.0022) * (0.10 + fog_boost * 0.06)
	if _glow_sprite != null:
		_glow_sprite.modulate.a = pulse * (0.85 + fog_boost * 0.35)
		if fog_boost > 0.01:
			var extra := 1.0 + fog_boost * (0.12 + float(level) * 0.04)
			_glow_sprite.scale = Vector2(1.15 + float(level) * 0.28, 1.15 + float(level) * 0.28) * extra
	if _light != null and is_lantern_active:
		_light.energy = _base_energy * (1.0 + fog_boost * 0.42)
		_light.texture_scale = _base_texture_scale * (1.0 + fog_boost * 0.18)
	if _beam_sprite != null:
		var beam_a := fog_boost * (0.18 + float(level) * 0.05)
		if level >= 4:
			beam_a += fog_boost * 0.08
		_beam_sprite.modulate.a = beam_a * pulse
		_beam_sprite.visible = is_lantern_active and beam_a > 0.01


func _make_radial_texture(size: int, color: Color) -> Texture2D:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a))
	return ImageTexture.create_from_image(image)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if _hint != null:
			_hint.visible = true


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if _hint != null:
			_hint.visible = false


func to_save_dict() -> Dictionary:
	return {
		"level": level,
		"active": is_lantern_active,
		"position": global_position,
	}


func from_save_dict(data: Dictionary) -> void:
	apply_level(int(data.get("level", 1)), false)
	set_lantern_active(bool(data.get("active", true)))
	if data.has("position"):
		global_position = data["position"]
