class_name ForgeInterior
extends BuildingInterior

## Dekorative Schmiede-Innenszene. Kein Crafting, kein NPC.

const TILE := 16

var _tilemap: TileMapLayer
var _catalog: BlockCatalog


func _ready() -> void:
	building_type = &"FORGE"
	_build_room()
	super._ready()


func _build_room() -> void:
	_catalog = load("res://resources/blocks/block_catalog.tres") as BlockCatalog
	var tileset := load("res://resources/blocks/terrain_tileset.tres") as TileSet
	if _catalog != null and tileset != null:
		_catalog.ensure_tileset_tiles(tileset)
	_tilemap = get_node_or_null("Tiles") as TileMapLayer
	if _tilemap == null:
		_tilemap = TileMapLayer.new()
		_tilemap.name = "Tiles"
		add_child(_tilemap)
	_tilemap.tile_set = tileset
	_tilemap.z_index = 0
	var stone := _catalog.get_by_id(3) if _catalog != null else null
	var wood := _catalog.get_by_id(7) if _catalog != null else null
	var beam := _catalog.get_by_id(29) if _catalog != null else null
	var core := _catalog.get_by_id(30) if _catalog != null else null
	var w := 22
	var h := 10
	for x in w:
		for y in h:
			if y == h - 1 or y == 0 or x == 0 or x == w - 1:
				_set_block(Vector2i(x, y), stone if y == h - 1 or y == 0 else wood)
			elif y == h - 2:
				_set_block(Vector2i(x, y), wood)
	for x in [5, 11, 16]:
		for y in range(1, h - 2):
			_set_block(Vector2i(x, y), beam)
	if core != null:
		_set_block(Vector2i(4, h - 3), core)
	_carve_exit(w, h)
	_ensure_floor_body(w, h)
	_ensure_spawn()
	_ensure_exit_door(w, h)
	_ensure_lights()
	_ensure_labels(h)


func _set_block(cell: Vector2i, block: BlockData) -> void:
	if _tilemap == null or _catalog == null or block == null:
		return
	_catalog.set_block_cell(_tilemap, cell, block)


func _carve_exit(w: int, h: int) -> void:
	var door_x := w - 1
	for y in range(h - 4, h - 1):
		_tilemap.erase_cell(Vector2i(door_x, y))


func _ensure_floor_body(w: int, h: int) -> void:
	var body := get_node_or_null("FloorBody") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "FloorBody"
		body.collision_layer = 1
		body.collision_mask = 0
		add_child(body)
	_box(body, Rect2(0, (h - 1) * TILE, w * TILE, TILE))
	_box(body, Rect2(0, 0, TILE, h * TILE))
	_box(body, Rect2((w - 1) * TILE, 0, TILE, (h - 4) * TILE))
	_box(body, Rect2(0, 0, w * TILE, TILE))


func _box(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)


func _ensure_spawn() -> void:
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	if spawn == null:
		spawn = Marker2D.new()
		spawn.name = "PlayerSpawn"
		add_child(spawn)
	spawn.position = Vector2(18 * TILE, 8 * TILE)


func _ensure_exit_door(w: int, h: int) -> void:
	var door := get_node_or_null("ExitDoor") as Node2D
	if door == null:
		door = Node2D.new()
		door.name = "ExitDoor"
		add_child(door)
	door.position = Vector2((w - 1) * TILE + 8, (h - 1) * TILE)
	var sprite := door.get_node_or_null("Sprite") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = true
		sprite.position = Vector2(0, -24)
		door.add_child(sprite)
	sprite.texture = load("res://assets/buildings/forge_door.png") as Texture2D
	var area := door.get_node_or_null("InteractionArea") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "InteractionArea"
		door.add_child(area)
		var col := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 26.0
		col.shape = circle
		col.position = Vector2(0, -16)
		area.add_child(col)
	var hint := door.get_node_or_null("HintLabel") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "HintLabel"
		hint.text = "[E] Schmiede verlassen"
		hint.position = Vector2(-70, -72)
		hint.size = Vector2(140, 16)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		hint.add_theme_constant_override("outline_size", 3)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		door.add_child(hint)


func _ensure_lights() -> void:
	if get_node_or_null("ForgeLight") != null:
		return
	var light := PointLight2D.new()
	light.name = "ForgeLight"
	light.position = Vector2(4 * TILE + 8, 6 * TILE)
	light.color = Color(1.0, 0.55, 0.22, 1)
	light.energy = 1.35
	light.texture_scale = 2.4
	light.texture = _radial_texture()
	add_child(light)
	var glow := PointLight2D.new()
	glow.name = "RoomLight"
	glow.position = Vector2(11 * TILE, 5 * TILE)
	glow.color = Color(1.0, 0.72, 0.42, 1)
	glow.energy = 0.55
	glow.texture_scale = 4.2
	glow.texture = light.texture
	add_child(glow)


func _ensure_labels(h: int) -> void:
	_label("Ofen", Vector2(3 * TILE, (h - 5) * TILE), Color(1.0, 0.55, 0.25))
	_label("Amboss", Vector2(9 * TILE, (h - 4) * TILE), Color(0.78, 0.78, 0.82))
	_bg()


func _label(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 2
	add_child(label)


func _bg() -> void:
	if get_node_or_null("Backdrop") != null:
		return
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = Color(0.07, 0.06, 0.05, 1)
	bg.position = Vector2(-64, -64)
	bg.size = Vector2(22 * TILE + 128, 10 * TILE + 128)
	bg.z_index = -8
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)


func _radial_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / radius
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)
