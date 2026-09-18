@tool
class_name BlockCatalog
extends Resource

## Sucht Blockdaten anhand der echten TileSet-Atlas-Koordinaten oder der Block-ID.

const BUILDING_ATLAS_PATH := "res://assets/building/building_atlas.png"
const BUILDING_SOURCE_ID := 1
const PLATFORM_PHYSICS_LAYER := 1

@export var blocks: Array[BlockData] = []

var _id_lookup: Dictionary = {}
var _atlas_lookup: Dictionary = {}
var _lookup_dirty: bool = true
var _prepared_tilesets: Dictionary = {}


func get_by_atlas(coords: Vector2i) -> BlockData:
	_ensure_lookup()
	var found: BlockData = _atlas_lookup.get(_atlas_key(0, coords))
	if found != null:
		return found
	return _atlas_lookup.get(_atlas_key(BUILDING_SOURCE_ID, coords))


func get_by_source_atlas(source_id: int, coords: Vector2i) -> BlockData:
	_ensure_lookup()
	return _atlas_lookup.get(_atlas_key(source_id, coords))


func get_by_id(block_id: int) -> BlockData:
	if block_id < 0:
		return null
	_ensure_lookup()
	return _id_lookup.get(block_id)


func get_cell_block(tilemap: TileMapLayer, cell: Vector2i) -> BlockData:
	if tilemap == null or cell == Vector2i(9999, 9999):
		return null
	if tilemap.get_cell_source_id(cell) == -1:
		return null
	return get_by_source_atlas(tilemap.get_cell_source_id(cell), tilemap.get_cell_atlas_coords(cell))


func terrain_source_id(tileset: TileSet) -> int:
	if tileset == null or tileset.get_source_count() == 0:
		return 0
	return tileset.get_source_id(0)


func building_source_id(tileset: TileSet) -> int:
	if tileset == null:
		return BUILDING_SOURCE_ID
	if tileset.has_source(BUILDING_SOURCE_ID):
		return BUILDING_SOURCE_ID
	return terrain_source_id(tileset)


func source_id_for(block: BlockData, tileset: TileSet) -> int:
	if block == null:
		return terrain_source_id(tileset)
	if block.atlas_source_id > 0:
		return building_source_id(tileset)
	return terrain_source_id(tileset)


func set_block_cell(tilemap: TileMapLayer, cell: Vector2i, block: BlockData, orientation: int = 0) -> void:
	if tilemap == null or block == null:
		return
	ensure_tileset_tiles(tilemap.tile_set)
	var coords := StairSystem.atlas_for(block, orientation, StairSystem.Visual.INNER) if StairSystem.is_stair(block) else _oriented_atlas(block, orientation)
	_set_cell_if_changed(tilemap, cell, source_id_for(block, tilemap.tile_set), coords)


func set_block_cell_mask(tilemap: TileMapLayer, cell: Vector2i, block: BlockData, mask: int, orientation: int = 0) -> void:
	if tilemap == null or block == null:
		return
	ensure_tileset_tiles(tilemap.tile_set)
	var coords := block.variant_atlas(mask)
	if StairSystem.is_stair(block):
		coords = StairSystem.atlas_for(block, orientation, mask)
	elif block.uses_orientation and orientation != 0 and block.autotile_count <= 1:
		coords = _oriented_atlas(block, orientation)
	_set_cell_if_changed(tilemap, cell, source_id_for(block, tilemap.tile_set), coords)


func _set_cell_if_changed(tilemap: TileMapLayer, cell: Vector2i, source_id: int, coords: Vector2i) -> void:
	if tilemap.get_cell_source_id(cell) == source_id and tilemap.get_cell_atlas_coords(cell) == coords:
		return
	tilemap.set_cell(cell, source_id, coords)


func _oriented_atlas(block: BlockData, orientation: int) -> Vector2i:
	if block.uses_orientation and orientation != 0:
		return block.atlas_coords + Vector2i(orientation, 0)
	return block.atlas_coords


func notify_changed() -> void:
	_lookup_dirty = true
	_prepared_tilesets.clear()


func ensure_tileset_tiles(tileset: TileSet) -> void:
	if tileset == null:
		return
	if _prepared_tilesets == null:
		_prepared_tilesets = {}
	var key := tileset.get_instance_id()
	var cached := bool(_prepared_tilesets.get(key, false))
	_ensure_physics_layers(tileset)
	_ensure_building_source(tileset)
	if tileset.get_source_count() == 0:
		_prepared_tilesets[key] = true
		return
	if cached:
		_ensure_missing_stair_tiles(tileset)
		return
	for block in blocks:
		if block == null:
			continue
		var source := tileset.get_source(source_id_for(block, tileset)) as TileSetAtlasSource
		if source == null:
			continue
		if source.texture_region_size != Vector2i(16, 16):
			source.texture_region_size = Vector2i(16, 16)
		var count := maxi(block.autotile_count, 1)
		if block.uses_orientation:
			count = maxi(count, 2)
		for i in count:
			var coords := Vector2i(block.atlas_coords.x + i, block.atlas_coords.y)
			_ensure_atlas_tile(source, coords, block, i)
	_ensure_stair_tiles(tileset)
	_prepared_tilesets[key] = true
	_lookup_dirty = true


func _ensure_atlas_tile(source: TileSetAtlasSource, coords: Vector2i, block: BlockData, variant_index: int) -> void:
	var existed := source.has_tile(coords)
	if not existed:
		source.create_tile(coords)
	if not source.has_tile(coords):
		return
	if block.atlas_source_id > 0 or not existed:
		_apply_tile_collision(source, coords, block, variant_index)


func _ensure_physics_layers(tileset: TileSet) -> void:
	if tileset.get_physics_layers_count() < 1:
		tileset.add_physics_layer()
		tileset.set_physics_layer_collision_layer(0, 1)
	if tileset.get_physics_layers_count() < 2:
		tileset.add_physics_layer()
		tileset.set_physics_layer_collision_layer(PLATFORM_PHYSICS_LAYER, 32)
		tileset.set_physics_layer_collision_mask(PLATFORM_PHYSICS_LAYER, 0)


func _ensure_building_source(tileset: TileSet) -> void:
	if tileset.has_source(BUILDING_SOURCE_ID):
		return
	if not ResourceLoader.exists(BUILDING_ATLAS_PATH):
		return
	var source := TileSetAtlasSource.new()
	source.texture = load(BUILDING_ATLAS_PATH) as Texture2D
	source.texture_region_size = Vector2i(16, 16)
	tileset.add_source(source, BUILDING_SOURCE_ID)


func _ensure_missing_stair_tiles(tileset: TileSet) -> void:
	for block in blocks:
		if not StairSystem.is_stair(block):
			continue
		var source := tileset.get_source(source_id_for(block, tileset)) as TileSetAtlasSource
		if source == null:
			continue
		for coords in StairSystem.all_atlas_coords(block):
			if source.has_tile(coords):
				continue
			source.create_tile(coords)
			_apply_stair_collision(source, coords, StairSystem.orientation_from_atlas(coords))


func _ensure_stair_tiles(tileset: TileSet) -> void:
	for block in blocks:
		if not StairSystem.is_stair(block):
			continue
		var source := tileset.get_source(source_id_for(block, tileset)) as TileSetAtlasSource
		if source == null:
			continue
		for coords in StairSystem.all_atlas_coords(block):
			if not source.has_tile(coords):
				source.create_tile(coords)
			_apply_stair_collision(source, coords, StairSystem.orientation_from_atlas(coords))


func _apply_stair_collision(source: TileSetAtlasSource, coords: Vector2i, orientation: int) -> void:
	var data := source.get_tile_data(coords, 0)
	if data == null:
		return
	_clear_collision(data, 0)
	_clear_collision(data, PLATFORM_PHYSICS_LAYER)
	data.add_collision_polygon(PLATFORM_PHYSICS_LAYER)
	data.set_collision_polygon_points(PLATFORM_PHYSICS_LAYER, 0, StairSystem.collision_points(orientation))
	data.set_collision_polygon_one_way(PLATFORM_PHYSICS_LAYER, 0, true)
	data.set_collision_polygon_one_way_margin(PLATFORM_PHYSICS_LAYER, 0, 3.0)


func _apply_tile_collision(source: TileSetAtlasSource, coords: Vector2i, block: BlockData, _variant: int) -> void:
	var data := source.get_tile_data(coords, 0)
	if data == null:
		return
	if StairSystem.is_stair(block):
		_apply_stair_collision(source, coords, StairSystem.orientation_from_atlas(coords))
		return
	_clear_collision(data, 0)
	_clear_collision(data, PLATFORM_PHYSICS_LAYER)
	if block.occupies_background_layer() or block.is_climbable or not block.solid:
		if not block.is_one_way:
			return
	if block.is_one_way:
		data.add_collision_polygon(PLATFORM_PHYSICS_LAYER)
		data.set_collision_polygon_points(PLATFORM_PHYSICS_LAYER, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4),
		]))
		data.set_collision_polygon_one_way(PLATFORM_PHYSICS_LAYER, 0, true)
		return
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	]))


func _clear_collision(data: TileData, layer: int) -> void:
	while data.get_collision_polygons_count(layer) > 0:
		data.remove_collision_polygon(layer, 0)


func _ensure_lookup() -> void:
	if not _lookup_dirty and not _id_lookup.is_empty():
		return
	_id_lookup.clear()
	_atlas_lookup.clear()
	for block in blocks:
		if block == null:
			continue
		_id_lookup[block.id] = block
		var source := block.atlas_source_id
		if StairSystem.is_stair(block):
			for coords in StairSystem.all_atlas_coords(block):
				_atlas_lookup[_atlas_key(source, coords)] = block
			continue
		var count := maxi(block.autotile_count, 1)
		if block.uses_orientation:
			count = maxi(count, 2)
		for i in count:
			var coords := Vector2i(block.atlas_coords.x + i, block.atlas_coords.y)
			_atlas_lookup[_atlas_key(source, coords)] = block
	_lookup_dirty = false


func _atlas_key(source_id: int, coords: Vector2i) -> int:
	return source_id * 1000000 + (coords.y + 512) * 1024 + (coords.x + 512)
