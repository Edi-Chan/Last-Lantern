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
@onready var _hum: AudioStreamPlayer2D = get_node_or_null("SafeHum")

var _base_energy: float = 1.15
var _base_texture_scale: float = 4.0
var _base_glow_scale: Vector2 = Vector2(0.38, 0.38)
var _foundation_height_px: float = 16.0
var _stone_tile_image: Image
var _altar_cache: Dictionary = {}
var _placed_from_save: bool = false


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
	_ensure_foundation()
	apply_level(level, false)
	set_lantern_active(is_lantern_active)
	call_deferred("place_near_spawn")


func _process(_delta: float) -> void:
	_update_fog_light()
	_update_safe_hum()
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
	if _placed_from_save:
		return
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world == null or settings == null:
		return
	var tile_x := world.spawn_tile.x + settings.lantern_spawn_offset_tiles
	if world.has_method("lantern_column_x"):
		tile_x = int(world.call("lantern_column_x"))
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
	_base_sprite.light_mask = 0
	if data.texture != null:
		var fitted := _make_altar_texture(data.texture, data.sprite_width_px)
		_base_sprite.texture = fitted
		_base_sprite.scale = Vector2.ONE
		_base_sprite.centered = true
		_base_sprite.offset = Vector2.ZERO
		var height := float(fitted.get_height())
		var width := float(fitted.get_width())
		_base_sprite.position = Vector2(0.0, -height * 0.5)
		var shrine_h := maxf(height - _foundation_height_px, height * 0.6)
		var glow_y := -_foundation_height_px - shrine_h * 0.58
		_base_glow_scale = Vector2(0.20 + float(level) * 0.03, 0.20 + float(level) * 0.03)
		if _glow_sprite != null:
			_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_glow_sprite.position = Vector2(0.0, glow_y)
			_glow_sprite.scale = _base_glow_scale
		if _beam_sprite != null:
			_beam_sprite.visible = false
			_beam_sprite.modulate.a = 0.0
			_beam_sprite.position = Vector2(0.0, -height + 8.0)
		if _hint != null:
			_hint.position = Vector2(-48.0, -height - 12.0)
		if _light != null:
			_light.position = Vector2(0.0, glow_y)
		_update_foundation_collision(width)
	else:
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


func _make_altar_texture(tex: Texture2D, width_px: float) -> Texture2D:
	if tex == null:
		return null
	var key := "%s:%.0f" % [tex.resource_path, width_px]
	if _altar_cache.has(key):
		return _altar_cache[key]
	var image := _load_texture_image(tex)
	if image == null:
		return tex
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var max_dim := 256
	var iw := image.get_width()
	var ih := image.get_height()
	if maxi(iw, ih) > max_dim:
		var s := float(max_dim) / float(maxi(iw, ih))
		image.resize(maxi(8, int(round(float(iw) * s))), maxi(8, int(round(float(ih) * s))), Image.INTERPOLATE_LANCZOS)
	_remove_backdrop(image)
	var used := image.get_used_rect()
	if used.size.x >= 4 and used.size.y >= 4:
		image = image.get_region(used)
	var target_w := maxi(24, int(round(width_px)))
	var aspect := float(image.get_height()) / maxf(float(image.get_width()), 1.0)
	var target_h := maxi(24, int(round(float(target_w) * aspect)))
	image.resize(target_w, target_h, Image.INTERPOLATE_NEAREST)
	var fitted := _composite_foundation(image)
	var result := ImageTexture.create_from_image(fitted)
	_altar_cache[key] = result
	return result


func _load_texture_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null and not tex.resource_path.is_empty():
		var loaded := load(tex.resource_path)
		if loaded is Texture2D:
			img = (loaded as Texture2D).get_image()
	if img == null:
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	return img


func _remove_backdrop(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	if w < 2 or h < 2:
		return
	var corner := image.get_pixel(0, 0)
	if corner.a < 0.08:
		return
	var lum := corner.r * 0.3 + corner.g * 0.59 + corner.b * 0.11
	if lum > 0.28:
		return
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[int] = []
	var tol := 0.14
	for x in w:
		_backdrop_try_push(image, visited, stack, x, 0, corner, tol)
		_backdrop_try_push(image, visited, stack, x, h - 1, corner, tol)
	for y in h:
		_backdrop_try_push(image, visited, stack, 0, y, corner, tol)
		_backdrop_try_push(image, visited, stack, w - 1, y, corner, tol)
	while not stack.is_empty():
		var packed: int = stack.pop_back()
		var px := packed % w
		var py := int(float(packed) / float(w))
		image.set_pixel(px, py, Color(0, 0, 0, 0))
		_backdrop_try_push(image, visited, stack, px + 1, py, corner, tol)
		_backdrop_try_push(image, visited, stack, px - 1, py, corner, tol)
		_backdrop_try_push(image, visited, stack, px, py + 1, corner, tol)
		_backdrop_try_push(image, visited, stack, px, py - 1, corner, tol)


func _backdrop_try_push(image: Image, visited: PackedByteArray, stack: Array[int], x: int, y: int, corner: Color, tol: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var idx := y * w + x
	if visited[idx] != 0:
		return
	var c := image.get_pixel(x, y)
	if c.a < 0.04:
		visited[idx] = 1
		return
	if absf(c.r - corner.r) > tol or absf(c.g - corner.g) > tol or absf(c.b - corner.b) > tol:
		return
	visited[idx] = 1
	stack.append(idx)


func _composite_foundation(shrine: Image) -> Image:
	var overlap := 4
	var found_h := int(_foundation_height_px)
	var shrine_w := shrine.get_width()
	var shrine_h := shrine.get_height()
	var tile_count := maxi(3, int(ceil(float(shrine_w) / 16.0)))
	var found_w := tile_count * 16
	var canvas_w := maxi(shrine_w, found_w)
	var canvas_h := shrine_h + found_h - overlap
	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var stone := _stone_tile()
	var found_x := int(float(canvas_w - found_w) / 2.0)
	var found_y := canvas_h - found_h
	for i in tile_count:
		canvas.blit_rect(stone, Rect2i(0, 0, 16, 16), Vector2i(found_x + i * 16, found_y))
	_darken_foundation_edge(canvas, found_x, found_y, found_w, found_h)
	var shrine_x := int(float(canvas_w - shrine_w) / 2.0)
	var shrine_y := found_y + overlap - shrine_h
	canvas.blit_rect(shrine, Rect2i(0, 0, shrine_w, shrine_h), Vector2i(shrine_x, shrine_y))
	return canvas


func _darken_foundation_edge(canvas: Image, fx: int, fy: int, fw: int, fh: int) -> void:
	var bottom := fy + fh - 1
	for x in range(fx, fx + fw):
		if x < 0 or x >= canvas.get_width() or bottom < 0 or bottom >= canvas.get_height():
			continue
		var c := canvas.get_pixel(x, bottom)
		canvas.set_pixel(x, bottom, Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, c.a))
	for y in range(fy, fy + fh):
		if y < 0 or y >= canvas.get_height():
			continue
		if fx >= 0 and fx < canvas.get_width():
			var left := canvas.get_pixel(fx, y)
			canvas.set_pixel(fx, y, Color(left.r * 0.7, left.g * 0.7, left.b * 0.7, left.a))
		var rx := fx + fw - 1
		if rx >= 0 and rx < canvas.get_width():
			var right := canvas.get_pixel(rx, y)
			canvas.set_pixel(rx, y, Color(right.r * 0.7, right.g * 0.7, right.b * 0.7, right.a))


func _stone_tile() -> Image:
	if _stone_tile_image != null:
		return _stone_tile_image
	var atlas_tex := load("res://assets/world/tiles/terrain_atlas.png") as Texture2D
	if atlas_tex == null:
		_stone_tile_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		_stone_tile_image.fill(Color(0.42, 0.42, 0.45, 1))
		return _stone_tile_image
	var atlas := atlas_tex.get_image()
	if atlas == null:
		_stone_tile_image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		_stone_tile_image.fill(Color(0.42, 0.42, 0.45, 1))
		return _stone_tile_image
	atlas = atlas.duplicate()
	if atlas.is_compressed():
		atlas.decompress()
	if atlas.get_format() != Image.FORMAT_RGBA8:
		atlas.convert(Image.FORMAT_RGBA8)
	_stone_tile_image = atlas.get_region(Rect2i(48, 0, 16, 16))
	return _stone_tile_image


func _ensure_foundation() -> void:
	if get_node_or_null("FoundationBody") != null:
		return
	var body := StaticBody2D.new()
	body.name = "FoundationBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 16)
	shape_node.shape = rect
	shape_node.position = Vector2(0, -8)
	body.add_child(shape_node)
	add_child(body)


func _update_foundation_collision(width_px: float) -> void:
	var body := get_node_or_null("FoundationBody") as StaticBody2D
	if body == null:
		return
	var shape_node := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not (shape_node.shape is RectangleShape2D):
		return
	var rect := shape_node.shape as RectangleShape2D
	rect.size = Vector2(maxf(width_px, 32.0), _foundation_height_px)
	shape_node.position = Vector2(0.0, -_foundation_height_px * 0.5)


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
	# Helligkeit bleibt konstant. Kein Fog- oder Mitternachts-Boost.
	var pulse := 0.94 + sin(Time.get_ticks_msec() * 0.0032) * 0.06
	if _glow_sprite != null:
		_glow_sprite.modulate = Color(1.0, 0.62, 0.22, pulse * 0.22)
		_glow_sprite.scale = _base_glow_scale
		_glow_sprite.visible = is_lantern_active
	if _light != null and is_lantern_active:
		_light.energy = _base_energy
		_light.texture_scale = _base_texture_scale
	if _beam_sprite != null:
		_beam_sprite.visible = false
		_beam_sprite.modulate.a = 0.0


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


func _update_safe_hum() -> void:
	if _hum == null:
		return
	if _hum.stream == null and ResourceLoader.exists("res://audio/ambient/lantern_hum.wav"):
		_hum.stream = load("res://audio/ambient/lantern_hum.wav")
	if not is_lantern_active:
		if _hum.playing:
			_hum.stop()
		return
	if not _hum.playing:
		_hum.play()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		_hum.volume_db = -28.0
		return
	var dist := global_position.distance_to(player.global_position)
	var radius := get_safe_radius_pixels()
	var inside := dist <= radius
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	var storm := fog != null and fog.is_fog_active()
	var closeness := clampf(1.0 - dist / maxf(radius * 1.35, 80.0), 0.0, 1.0)
	var db := lerpf(-30.0, -16.0, closeness)
	if inside:
		db += 3.0 if storm else 0.0
	else:
		db -= 8.0 if storm else 4.0
	_hum.volume_db = db


func to_save_dict() -> Dictionary:
	return {
		"level": level,
		"active": is_lantern_active,
		"position": [global_position.x, global_position.y],
	}


func from_save_dict(data: Dictionary) -> void:
	apply_level(int(data.get("level", 1)), false)
	set_lantern_active(bool(data.get("active", true)))
	var pos := _vec2_from_save(data.get("position", null))
	if pos != Vector2.INF:
		global_position = pos
		_placed_from_save = true


static func _vec2_from_save(value: Variant) -> Vector2:
	match typeof(value):
		TYPE_VECTOR2:
			return value
		TYPE_ARRAY:
			if value.size() >= 2:
				return Vector2(float(value[0]), float(value[1]))
		TYPE_DICTIONARY:
			return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
		TYPE_STRING:
			var cleaned := String(value).strip_edges().trim_prefix("(").trim_suffix(")")
			var parts := cleaned.split(",")
			if parts.size() >= 2:
				return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
	return Vector2.INF
