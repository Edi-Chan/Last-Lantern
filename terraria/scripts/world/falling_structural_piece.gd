extends Node2D

var gravity_strength: float = 980.0
var max_fall_speed: float = 640.0
var velocity: Vector2 = Vector2.ZERO
var cell: Vector2i = Vector2i.ZERO
var block: BlockData
var _alive: bool = false
var _sprite: Sprite2D
var _manager: Node
var _tilemap: TileMapLayer
var _fall_time: float = 0.0

func _ready() -> void:
	visible = false
	z_index = 8
	_sprite = Sprite2D.new()
	add_child(_sprite)
	set_process(false)

func begin(p_cell: Vector2i, p_block: BlockData, tilemap: TileMapLayer, manager: Node) -> void:
	cell = p_cell
	block = p_block
	_tilemap = tilemap
	_manager = manager
	_alive = true
	_fall_time = 0.0
	velocity = Vector2(randf_range(-18.0, 18.0), 20.0)
	visible = true
	global_position = tilemap.to_global(tilemap.map_to_local(p_cell))
	_apply_texture(p_block, tilemap)
	set_process(true)

func _process(delta: float) -> void:
	if not _alive:
		return
	_fall_time += delta
	velocity.y = minf(velocity.y + gravity_strength * delta, max_fall_speed)
	global_position += velocity * delta
	if (_fall_time > 0.12 and _hit_ground()) or _fall_time > 1.8:
		_finish()

func _apply_texture(p_block: BlockData, tilemap: TileMapLayer) -> void:
	if _sprite == null or p_block == null or tilemap == null or tilemap.tile_set == null:
		return
	var source := tilemap.tile_set.get_source(tilemap.tile_set.get_source_id(0)) as TileSetAtlasSource
	if source == null:
		return
	var atlas := source.texture
	if atlas == null:
		return
	var atlas_tex := AtlasTexture.new()
	atlas_tex.atlas = atlas
	atlas_tex.region = Rect2(Vector2(p_block.atlas_coords) * Vector2(16, 16), Vector2(16, 16))
	_sprite.texture = atlas_tex

func _hit_ground() -> bool:
	if _tilemap == null:
		return true
	var below := _tilemap.local_to_map(_tilemap.to_local(global_position + Vector2(0, 8)))
	return _tilemap.get_cell_source_id(below) != -1

func _finish() -> void:
	_alive = false
	set_process(false)
	visible = false
	if _manager != null:
		_manager.call("consume_collapse_drop", cell, block)
		_manager.call("recycle_piece", self)
