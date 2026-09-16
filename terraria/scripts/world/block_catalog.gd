@tool
class_name BlockCatalog
extends Resource

## Sucht Blockdaten anhand der echten TileSet-Atlas-Koordinaten oder der Block-ID.

@export var blocks: Array[BlockData] = []

func get_by_atlas(coords: Vector2i) -> BlockData:
	for block in blocks:
		if block != null and block.atlas_coords == coords:
			return block
	return null


func get_by_id(block_id: int) -> BlockData:
	if block_id < 0:
		return null
	for block in blocks:
		if block != null and block.id == block_id:
			return block
	return null


func terrain_source_id(tileset: TileSet) -> int:
	if tileset == null or tileset.get_source_count() == 0:
		return 0
	return tileset.get_source_id(0)


func set_block_cell(tilemap: TileMapLayer, cell: Vector2i, block: BlockData) -> void:
	if tilemap == null or block == null:
		return
	tilemap.set_cell(cell, terrain_source_id(tilemap.tile_set), block.atlas_coords)


func ensure_tileset_tiles(tileset: TileSet) -> void:
	if tileset == null or tileset.get_source_count() == 0:
		return
	var source := tileset.get_source(tileset.get_source_id(0)) as TileSetAtlasSource
	if source == null:
		return
	source.texture_region_size = Vector2i(16, 16)
	var physics := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	for block in blocks:
		if block == null:
			continue
		var coords := block.atlas_coords
		if not source.has_tile(coords):
			source.create_tile(coords)
		if not block.solid:
			continue
		var data := source.get_tile_data(coords, 0)
		if data == null or data.get_collision_polygons_count(0) > 0:
			continue
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, physics)
