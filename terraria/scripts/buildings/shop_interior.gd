class_name ShopInterior
extends BuildingInterior

## Dekorativer Shop-Innenraum. Kein NPC, kein Kaufmenue, kein Crafting.

const TILE := 16

const THEMES := {
	&"CARPENTER": {
		"w": 16, "h": 9, "floor": 37, "wall": 7, "beam": 29, "core": 60,
		"light": Color(1.0, 0.72, 0.38, 1), "bg": Color(0.13, 0.08, 0.05, 1),
		"labels": ["Werkbank", "Holzstapel"], "exit": "[E] Schreinerei verlassen",
		"props": [[50, 3, 6], [50, 4, 6], [51, 6, 3], [53, 11, 6], [63, 2, 3], [63, 13, 3]],
	},
	&"HUNTER": {
		"w": 14, "h": 8, "floor": 38, "wall": 7, "beam": 29, "core": 59,
		"light": Color(1.0, 0.62, 0.32, 1), "bg": Color(0.08, 0.06, 0.05, 1),
		"labels": ["Vorrat", "Regal"], "exit": "[E] Jägerhütte verlassen",
		"props": [[50, 2, 5], [55, 6, 2], [51, 9, 2], [63, 3, 2]],
	},
	&"LANTERN_MAKER": {
		"w": 16, "h": 9, "floor": 38, "wall": 7, "beam": 29, "core": 52,
		"light": Color(1.0, 0.78, 0.32, 1), "bg": Color(0.12, 0.08, 0.04, 1),
		"labels": ["Werkstatt", "Laternen"], "exit": "[E] Laternenmacher verlassen",
		"props": [[52, 4, 6], [51, 8, 3], [50, 12, 6], [63, 2, 3], [63, 7, 2], [63, 13, 3]],
	},
	&"GARDENER": {
		"w": 14, "h": 8, "floor": 37, "wall": 7, "beam": 29, "core": 52,
		"light": Color(0.92, 0.85, 0.45, 1), "bg": Color(0.09, 0.11, 0.06, 1),
		"labels": ["Arbeitstisch", "Pflanzen"], "exit": "[E] Gärtnerhütte verlassen",
		"props": [[52, 4, 5], [53, 6, 5], [17, 2, 5], [17, 10, 5], [51, 9, 2], [63, 3, 2]],
	},
	&"MECHANIC": {
		"w": 16, "h": 9, "floor": 38, "wall": 3, "beam": 29, "core": 61,
		"light": Color(0.95, 0.72, 0.42, 1), "bg": Color(0.08, 0.08, 0.08, 1),
		"labels": ["Amboss", "Ofen"], "exit": "[E] Mechaniker verlassen",
		"props": [[61, 4, 6], [62, 8, 5], [51, 12, 3], [50, 13, 6], [63, 2, 3], [63, 14, 3]],
	},
	&"MERCHANT": {
		"w": 16, "h": 9, "floor": 37, "wall": 7, "beam": 29, "core": 59,
		"light": Color(1.0, 0.78, 0.48, 1), "bg": Color(0.11, 0.08, 0.05, 1),
		"labels": ["Theke", "Waren"], "exit": "[E] Handelshaus verlassen",
		"props": [[52, 6, 6], [59, 3, 6], [50, 4, 6], [51, 10, 3], [54, 8, 3], [63, 2, 3], [63, 13, 3]],
	},
}

var _tilemap: TileMapLayer
var _catalog: BlockCatalog
var _theme: Dictionary = {}


func _ready() -> void:
	_theme = THEMES.get(building_type, THEMES[&"MERCHANT"])
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
	var floor_b := _block(int(_theme.get("floor", 37)))
	var wall_b := _block(int(_theme.get("wall", 7)))
	var beam := _block(int(_theme.get("beam", 29)))
	var core := _block(int(_theme.get("core", 60)))
	var w := int(_theme.get("w", 16))
	var h := int(_theme.get("h", 9))
	for x in w:
		for y in h:
			if y == h - 1 or y == 0 or x == 0 or x == w - 1:
				_set_block(Vector2i(x, y), floor_b if y == h - 1 else wall_b)
			elif y == h - 2:
				_set_block(Vector2i(x, y), floor_b)
	for x in [4, 9, w - 5]:
		for y in range(1, h - 2):
			_set_block(Vector2i(x, y), beam)
	if core != null:
		_set_block(Vector2i(5, h - 3), core)
	for prop in _theme.get("props", []):
		_set_block(Vector2i(int(prop[1]), int(prop[2])), _block(int(prop[0])))
	_carve_exit(w, h)
	_ensure_floor_body(w, h)
	_ensure_spawn(w, h)
	_ensure_exit_door(w, h)
	_ensure_lights(w, h)
	_ensure_labels(h)
	_bg(w, h)


func _block(id: int) -> BlockData:
	if _catalog == null:
		return null
	return _catalog.get_by_id(id)


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


func _ensure_spawn(w: int, h: int) -> void:
	var spawn := get_node_or_null("PlayerSpawn") as Marker2D
	if spawn == null:
		spawn = Marker2D.new()
		spawn.name = "PlayerSpawn"
		add_child(spawn)
	spawn.position = Vector2((w - 4) * TILE, (h - 2) * TILE)


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
		hint.position = Vector2(-80, -72)
		hint.size = Vector2(160, 16)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 10)
		hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		hint.add_theme_constant_override("outline_size", 3)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		door.add_child(hint)
	hint.text = str(_theme.get("exit", "[E] Verlassen"))


func _ensure_lights(w: int, h: int) -> void:
	if get_node_or_null("ShopLight") != null:
		return
	var color: Color = _theme.get("light", Color(1.0, 0.72, 0.4, 1))
	var energy := 1.2
	if building_type == &"LANTERN_MAKER":
		energy = 1.7
	var tex := _radial_texture()
	var light := PointLight2D.new()
	light.name = "ShopLight"
	light.position = Vector2(5 * TILE, (h - 4) * TILE)
	light.color = color
	light.energy = energy
	light.texture_scale = 2.6
	light.texture = tex
	add_child(light)
	var glow := PointLight2D.new()
	glow.name = "RoomLight"
	glow.position = Vector2(w * TILE * 0.5, 4 * TILE)
	glow.color = color.lightened(0.15)
	glow.energy = 0.7 if building_type == &"LANTERN_MAKER" else 0.5
	glow.texture_scale = 4.0
	glow.texture = tex
	add_child(glow)
	if building_type == &"LANTERN_MAKER":
		var extra := PointLight2D.new()
		extra.name = "WarmLight"
		extra.position = Vector2((w - 4) * TILE, 3 * TILE)
		extra.color = Color(1.0, 0.7, 0.22, 1)
		extra.energy = 1.1
		extra.texture_scale = 2.2
		extra.texture = tex
		add_child(extra)


func _ensure_labels(h: int) -> void:
	var labels: Array = _theme.get("labels", [])
	if labels.size() > 0:
		_label(str(labels[0]), Vector2(3 * TILE, (h - 5) * TILE), Color(1.0, 0.78, 0.45))
	if labels.size() > 1:
		_label(str(labels[1]), Vector2(9 * TILE, (h - 5) * TILE), Color(0.82, 0.78, 0.68))


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


func _bg(w: int, h: int) -> void:
	if get_node_or_null("Backdrop") != null:
		return
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = _theme.get("bg", Color(0.08, 0.06, 0.05, 1))
	bg.position = Vector2(-64, -64)
	bg.size = Vector2(w * TILE + 128, h * TILE + 128)
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
