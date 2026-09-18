class_name WorldMapData
extends Node

## Gemeinsame 1-Pixel-pro-Tile-Karte fuer WorldMapWindow und MiniMap.

signal rebuilt
signal tiles_updated

const COLOR_SKY := Color(0.20, 0.38, 0.58, 1)
const COLOR_CAVE := Color(0.05, 0.055, 0.07, 1)
const COLOR_UNKNOWN := Color(0.12, 0.12, 0.14, 1)

var image: Image
var texture: ImageTexture

var _world: WorldGenerator
var _tilemap: TileMapLayer
var _built: bool = false


func _ready() -> void:
	add_to_group("world_map_data")
	_bind_world()
	call_deferred("rebuild_full")


func is_ready() -> bool:
	return _built and image != null and texture != null


func world_size() -> Vector2:
	if image == null:
		return Vector2.ZERO
	return Vector2(image.get_width(), image.get_height())


func world_to_map(world_pos: Vector2) -> Vector2i:
	if _tilemap == null:
		return Vector2i.ZERO
	return _tilemap.local_to_map(_tilemap.to_local(world_pos))


func rebuild_full() -> void:
	_bind_world()
	if _world == null or _tilemap == null:
		return
	var width: int = _world.world_width
	var height: int = _world.world_height
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, color_at(Vector2i(x, y)))
	texture = ImageTexture.create_from_image(image)
	_built = true
	rebuilt.emit()


func update_tile(cell: Vector2i) -> void:
	if image == null:
		return
	if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height():
		return
	image.set_pixel(cell.x, cell.y, color_at(cell))
	_refresh_texture()
	tiles_updated.emit()


func update_tiles(cells: Array) -> void:
	if image == null:
		return
	var changed := false
	for cell_value in cells:
		var cell: Vector2i = cell_value
		if cell.x < 0 or cell.y < 0 or cell.x >= image.get_width() or cell.y >= image.get_height():
			continue
		image.set_pixel(cell.x, cell.y, color_at(cell))
		changed = true
	if changed:
		_refresh_texture()
		tiles_updated.emit()


func color_at(cell: Vector2i) -> Color:
	var block_id := _block_id_at(cell)
	if block_id == 0:
		if _world != null and cell.y < _world.get_surface_y(cell.x):
			return COLOR_SKY
		return COLOR_CAVE
	return _color_for_block(block_id)


func _bind_world() -> void:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _tilemap == null:
		_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer


func _refresh_texture() -> void:
	if image == null:
		return
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.set_image(image)


func _block_id_at(cell: Vector2i) -> int:
	if _tilemap == null or _tilemap.get_cell_source_id(cell) == -1:
		return 0
	if _world == null or _world.block_catalog == null:
		return 0
	var block := _world.block_catalog.get_cell_block(_tilemap, cell)
	return block.id if block != null else 0


func _color_for_block(block_id: int) -> Color:
	if _world != null and _world.block_catalog != null:
		var block := _world.block_catalog.get_by_id(block_id)
		if block != null:
			var mapped := block.get_map_color()
			if mapped.a > 0.0:
				return mapped
	match block_id:
		1:
			return Color(0.30, 0.62, 0.22)
		2:
			return Color(0.45, 0.30, 0.16)
		3:
			return Color(0.50, 0.52, 0.54)
		4:
			return Color(0.86, 0.75, 0.38)
		5:
			return Color(0.52, 0.24, 0.24)
		6:
			return Color(0.28, 0.34, 0.42)
		7:
			return Color(0.42, 0.28, 0.14)
		8:
			return Color(0.25, 0.50, 0.20)
		9:
			return Color(0.78, 0.45, 0.18)
		10:
			return Color(0.72, 0.74, 0.76)
		11:
			return Color(0.82, 0.86, 0.90)
		12:
			return Color(0.92, 0.78, 0.18)
		13:
			return Color(0.14, 0.14, 0.16)
		14:
			return Color(0.48, 0.30, 0.14)
		15:
			return Color(0.84, 0.80, 0.62)
		16:
			return Color(0.32, 0.22, 0.12)
		17:
			return Color(0.28, 0.55, 0.18)
		18:
			return Color(0.55, 0.70, 0.28)
		19:
			return Color(0.12, 0.38, 0.22)
		20:
			return Color(0.40, 0.70, 0.28)
		21:
			return Color(0.70, 0.82, 0.32)
		22:
			return Color(0.18, 0.48, 0.28)
		_:
			return COLOR_UNKNOWN
