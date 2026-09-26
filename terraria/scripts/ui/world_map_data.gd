class_name WorldMapData
extends Node

## Gemeinsame Kartendaten fuer MiniMap und WorldMap. Discovery ist Zustand, kein permanenter Update-Auftrag.
## Terrainfarben kommen aus der Welt; die Anzeige filtert ueber Discovery.
## Discovery ist weltbezogen und wird mit dem World Save gespeichert.

signal rebuilt
signal tiles_updated
signal discovery_changed
signal markers_changed

const COLOR_SKY := Color(0.22, 0.42, 0.64, 1)
const COLOR_CAVE := Color(0.045, 0.05, 0.06, 1)
const COLOR_CAVE_DEEP := Color(0.03, 0.032, 0.04, 1)
const COLOR_CAVE_FIRE := Color(0.07, 0.03, 0.025, 1)
const COLOR_FOG := Color(0.015, 0.016, 0.02, 1)
const COLOR_UNKNOWN := Color(0.12, 0.12, 0.14, 1)
const COLOR_WATER := Color(0.16, 0.42, 0.78, 1)
const COLOR_WATER_DEEP := Color(0.10, 0.28, 0.62, 1)
const COLOR_LAVA := Color(0.92, 0.34, 0.08, 1)
const COLOR_LAVA_HOT := Color(1.0, 0.62, 0.18, 1)
const COLOR_BEDROCK := Color(0.08, 0.07, 0.09, 1)

const CHUNK_SHIFT := MapExploration.CHUNK_SHIFT
const DISCOVERY_RADIUS := 16
const START_REVEAL_RADIUS := 18
const LIQUID_FLUSH_INTERVAL := 0.18
const TEXTURE_FLUSH_INTERVAL := 0.05
const REVEAL_ROWS_PER_FRAME := 48
const REVEAL_BUDGET_MS := 4.0
const TEXTURE_FLUSH_WHEN_HIDDEN := false
const LIQUID_MAP_MIN := 20
const PLAYER_MARKER_ID := &"player"
const LANTERN_MARKER_ID := &"last_lantern"
const BED_MARKER_ID := &"bed"
const DEATH_MARKER_ID := &"last_death"

var image: Image
var texture: ImageTexture
var exploration := MapExploration.new()

var _world: WorldGenerator
var _tilemap: TileMapLayer
var _liquid: LiquidSystem
var _player: Player
var _lantern: Node2D
var _built: bool = false
var _pixels: PackedByteArray = PackedByteArray()
var _dirty_chunks: Dictionary = {}
var _dirty_liquids: Dictionary = {}
var _texture_dirty: bool = false
var _texture_flush_left: float = 0.0
var _liquid_flush_left: float = 0.0
var _last_player_tile := Vector2i(99999, 99999)
var _pending_save: Dictionary = {}
var _has_loaded_save: bool = false
var _start_revealed: bool = false
var _full_reveal_y: int = -1
var _block_color_cache: Dictionary = {}
var _markers: Dictionary = {}
var _test_blocks: Dictionary = {}
var _test_liquids: Dictionary = {}
var _test_solid: Dictionary = {}
var _test_surface_y: int = 24
var _test_fire: Dictionary = {}
var last_discover_ms: float = 0.0
var last_flush_ms: float = 0.0
var last_reveal_ms: float = 0.0
var last_paint_ms: float = 0.0
var full_revealed: bool = false
var map_flush_count: int = 0
var _deferred_full_paint: bool = false


func _ready() -> void:
	add_to_group("world_map_data")
	_ensure_core_markers()
	_bind_world()
	rebuild_full()


func _process(delta: float) -> void:
	if not _built:
		return
	if _player == null or not is_instance_valid(_player) or _liquid == null:
		_bind_world()
	_update_player_discovery()
	var maps_visible := _any_map_visible()
	if _deferred_full_paint and maps_visible:
		_full_reveal_y = 0
		_deferred_full_paint = false
	if _full_reveal_y >= 0:
		_paint_reveal_rows()
	if maps_visible and _map_flag("perf_map_markers"):
		_refresh_runtime_markers()
	var world_map_open := _world_map_visible()
	_liquid_flush_left -= delta
	if _liquid_flush_left <= 0.0:
		if _map_flag("perf_map_updates") and world_map_open and _map_flag("perf_liquid_map"):
			_flush_dirty_liquids()
		elif not _map_flag("perf_map_updates") or not _map_flag("perf_liquid_map"):
			_dirty_liquids.clear()
		_liquid_flush_left = LIQUID_FLUSH_INTERVAL
	_texture_flush_left -= delta
	if _texture_dirty and _texture_flush_left <= 0.0 and (world_map_open or TEXTURE_FLUSH_WHEN_HIDDEN):
		_flush_texture()
		_texture_flush_left = TEXTURE_FLUSH_INTERVAL


func _map_flag(flag_name: String, default_on: bool = true) -> bool:
	var value = AdminManager.get(flag_name)
	if typeof(value) == TYPE_NIL:
		return default_on
	return bool(value)


func is_ready() -> bool:
	return _built and image != null and texture != null


func world_size() -> Vector2:
	if image == null:
		return Vector2.ZERO
	return Vector2(image.get_width(), image.get_height())


func world_to_map(world_pos: Vector2) -> Vector2i:
	if _tilemap != null:
		return _tilemap.local_to_map(_tilemap.to_local(world_pos))
	return Vector2i(int(floor(world_pos.x / 16.0)), int(floor(world_pos.y / 16.0)))


func is_discovered(cell: Vector2i) -> bool:
	return exploration.is_discovered(cell)


func discovered_count() -> int:
	return exploration.discovered_count


func discovery_byte_size() -> int:
	return exploration.byte_size()


func rebuild_full() -> void:
	_bind_world()
	var size := _world_dimensions()
	if size.x <= 0 or size.y <= 0:
		return
	_setup_buffers(size.x, size.y)
	_built = true
	if not _pending_save.is_empty():
		_apply_save(_pending_save)
		_pending_save.clear()
	elif not _has_loaded_save:
		reveal_start_area()
	else:
		_repaint_discovered()
	_refresh_runtime_markers()
	_flush_texture()
	rebuilt.emit()


func update_tile(cell: Vector2i) -> void:
	if not _built:
		return
	if not exploration.in_bounds(cell):
		return
	if exploration.is_discovered(cell):
		_paint_cell(cell)
		_mark_chunk_dirty(cell)
		_request_texture_flush()
		tiles_updated.emit()


func update_tiles(cells: Array) -> void:
	if not _built:
		return
	var changed := false
	for cell_value in cells:
		var cell: Vector2i = cell_value
		if not exploration.in_bounds(cell):
			continue
		if not exploration.is_discovered(cell):
			continue
		_paint_cell(cell)
		_mark_chunk_dirty(cell)
		changed = true
	if changed:
		_request_texture_flush()
		tiles_updated.emit()


func color_at(cell: Vector2i) -> Color:
	var liquid_color := _liquid_color_at(cell)
	if liquid_color.a > 0.0:
		return liquid_color
	var block_id := _block_id_at(cell)
	if block_id == 0:
		return _air_color(cell)
	var mapped := _color_for_block(block_id)
	if block_id == WorldGenerator.BEDROCK:
		return COLOR_BEDROCK
	if _is_fire_region(cell):
		return mapped.darkened(0.22).lerp(COLOR_LAVA, 0.16)
	var layer := _depth_layer_at(cell)
	if layer >= DepthLayer.Id.DEEP_CAVES:
		return mapped.darkened(0.18)
	if layer >= DepthLayer.Id.SHALLOW_CAVES:
		return mapped.darkened(0.08)
	return mapped


func display_color_at(cell: Vector2i) -> Color:
	if not exploration.is_discovered(cell):
		return COLOR_FOG
	return color_at(cell)


func discover_around(origin: Vector2i, radius: int = DISCOVERY_RADIUS) -> int:
	if not _built or full_revealed:
		return 0
	var started := Time.get_ticks_usec()
	var newly := exploration.discover_with_los(origin, radius, Callable(self, "_blocks_map_vision"))
	for cell in newly:
		_paint_cell(cell)
		_mark_chunk_dirty(cell)
	if not newly.is_empty():
		_request_texture_flush()
		discovery_changed.emit()
		markers_changed.emit()
	last_discover_ms = (Time.get_ticks_usec() - started) / 1000.0
	return newly.size()


func reveal_start_area() -> void:
	if not _built:
		return
	var center := start_tile()
	discover_around(center, START_REVEAL_RADIUS)
	var lantern_tile := _lantern_tile()
	if lantern_tile != center:
		discover_around(lantern_tile, START_REVEAL_RADIUS)
	_start_revealed = true


func reveal_full_map() -> void:
	if not _built:
		return
	var started := Time.get_ticks_usec()
	exploration.reveal_all()
	full_revealed = true
	var maps_visible := _any_map_visible()
	var total := exploration.width * exploration.height
	if total <= 80000 and (maps_visible or not is_inside_tree()):
		for y in exploration.height:
			for x in exploration.width:
				_paint_cell(Vector2i(x, y))
		_full_reveal_y = -1
		_deferred_full_paint = false
		_flush_texture()
	elif maps_visible:
		_full_reveal_y = 0
		_deferred_full_paint = false
	else:
		_deferred_full_paint = true
		_full_reveal_y = -1
	last_reveal_ms = (Time.get_ticks_usec() - started) / 1000.0
	discovery_changed.emit()
	markers_changed.emit()
	if _full_reveal_y < 0 and not _deferred_full_paint:
		tiles_updated.emit()


func reset_discovery(keep_start: bool = true) -> void:
	if not _built:
		return
	exploration.clear()
	_fill_fog()
	_has_loaded_save = false
	_start_revealed = false
	_full_reveal_y = -1
	full_revealed = false
	_deferred_full_paint = false
	if keep_start:
		reveal_start_area()
	_request_texture_flush()
	discovery_changed.emit()
	markers_changed.emit()
	rebuilt.emit()


func to_save_dict() -> Dictionary:
	if not _built:
		return {}
	if full_revealed:
		return {
			"version": 1,
			"width": exploration.width,
			"height": exploration.height,
			"count": exploration.width * exploration.height,
			"full": true,
		}
	return exploration.to_save_dict()


func from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		if _built and discovered_count() == 0 and not _start_revealed:
			reveal_start_area()
			_flush_texture()
		return
	if not _built:
		_pending_save = data.duplicate(true)
		return
	_apply_save(data)


func set_last_death(world_pos: Vector2) -> void:
	var marker := _ensure_marker(DEATH_MARKER_ID, MapMarker.Type.DEATH)
	marker.world_position = world_pos
	marker.visible = false
	marker.discovered_required = true
	marker.color = Color(0.78, 0.22, 0.22, 1)
	markers_changed.emit()


func get_visible_markers() -> Array[MapMarker]:
	var result: Array[MapMarker] = []
	for marker in _markers.values():
		var item := marker as MapMarker
		if item != null and item.is_shown(self):
			result.append(item)
	return result


func get_marker(marker_id: StringName) -> MapMarker:
	return _markers.get(marker_id) as MapMarker


func setup_test_world(width: int, height: int, surface_y: int = 24) -> void:
	_test_blocks.clear()
	_test_liquids.clear()
	_test_solid.clear()
	_test_fire.clear()
	_test_surface_y = surface_y
	_world = null
	_tilemap = null
	_liquid = null
	_player = null
	_has_loaded_save = false
	_start_revealed = false
	full_revealed = false
	_pending_save.clear()
	_setup_buffers(width, height)
	_ensure_core_markers()
	_built = true


func test_set_block(cell: Vector2i, block_id: int, blocks_vision: bool = true) -> void:
	_test_blocks[cell] = block_id
	if block_id == 0:
		_test_solid[cell] = false
	else:
		_test_solid[cell] = blocks_vision


func test_set_liquid(cell: Vector2i, liquid_type: int, amount: int) -> void:
	_test_liquids[cell] = Vector2i(liquid_type, amount)


func test_set_fire(cell: Vector2i, enabled: bool = true) -> void:
	if enabled:
		_test_fire[cell] = true
	elif _test_fire.has(cell):
		_test_fire.erase(cell)


func _apply_save(data: Dictionary) -> void:
	if exploration.from_save_dict(data):
		_has_loaded_save = true
		_start_revealed = true
		full_revealed = bool(data.get("full", false)) or discovered_count() >= exploration.width * exploration.height
		_repaint_discovered()
		_flush_texture()
		discovery_changed.emit()
		markers_changed.emit()
		return
	_has_loaded_save = false
	if not _start_revealed:
		reveal_start_area()
		_flush_texture()


func _bind_world() -> void:
	if not is_inside_tree():
		return
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _tilemap == null:
		_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if _liquid == null:
		_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
		if _liquid != null and not _liquid.liquid_changed.is_connected(_on_liquid_changed):
			_liquid.liquid_changed.connect(_on_liquid_changed)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player


func _world_dimensions() -> Vector2i:
	if _world != null:
		return Vector2i(_world.world_width, _world.world_height)
	if image != null:
		return Vector2i(image.get_width(), image.get_height())
	return Vector2i.ZERO


func _setup_buffers(width: int, height: int) -> void:
	var keep := exploration.width == width and exploration.height == height and not exploration.mask.is_empty()
	exploration.setup(width, height, keep)
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_FOG)
	_pixels = image.get_data()
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.set_image(image)
	_dirty_chunks.clear()
	_dirty_liquids.clear()
	_full_reveal_y = -1
	_deferred_full_paint = false
	_texture_dirty = false


func _fill_fog() -> void:
	if image == null:
		return
	image.fill(COLOR_FOG)
	_pixels = image.get_data()
	_texture_dirty = true


func _repaint_discovered() -> void:
	if image == null:
		return
	_fill_fog()
	for y in exploration.height:
		for x in exploration.width:
			var cell := Vector2i(x, y)
			if exploration.is_discovered(cell):
				_paint_cell(cell)
	_texture_dirty = true


func _paint_cell(cell: Vector2i) -> void:
	if image == null or not exploration.in_bounds(cell):
		return
	var color := color_at(cell)
	var index := (cell.y * exploration.width + cell.x) * 4
	if index < 0 or index + 3 >= _pixels.size():
		return
	_pixels[index] = color.r8
	_pixels[index + 1] = color.g8
	_pixels[index + 2] = color.b8
	_pixels[index + 3] = 255


func _paint_reveal_rows() -> void:
	if image == null or _full_reveal_y < 0:
		return
	var started := Time.get_ticks_usec()
	var budget_us := int(REVEAL_BUDGET_MS * 1000.0)
	var y := _full_reveal_y
	var painted := 0
	while y < exploration.height:
		for x in exploration.width:
			_paint_cell(Vector2i(x, y))
		painted += 1
		y += 1
		if painted >= REVEAL_ROWS_PER_FRAME:
			break
		if Time.get_ticks_usec() - started >= budget_us:
			break
	_full_reveal_y = y
	last_paint_ms = (Time.get_ticks_usec() - started) / 1000.0
	_request_texture_flush()
	if _full_reveal_y >= exploration.height:
		_full_reveal_y = -1
		if _any_map_visible() or not is_inside_tree():
			_flush_texture()
		tiles_updated.emit()


func flush_if_dirty() -> void:
	if _deferred_full_paint:
		_full_reveal_y = 0
		_deferred_full_paint = false
		_paint_reveal_rows()
	if _texture_dirty:
		_flush_texture()


func _any_map_visible() -> bool:
	return _minimap_visible() or _world_map_visible()


func _minimap_visible() -> bool:
	if not is_inside_tree() or not _map_flag("perf_minimap"):
		return false
	var minimap_ui := get_tree().get_first_node_in_group("minimap_ui") as CanvasItem
	return minimap_ui != null and minimap_ui.visible


func _world_map_visible() -> bool:
	if not is_inside_tree() or not _map_flag("perf_world_map"):
		return false
	var world_map := get_tree().get_first_node_in_group("world_map_ui") as CanvasItem
	return world_map != null and world_map.visible


func discovered_percent() -> float:
	if exploration.width <= 0 or exploration.height <= 0:
		return 0.0
	return 100.0 * float(discovered_count()) / float(exploration.width * exploration.height)


func dirty_chunk_count() -> int:
	return _dirty_chunks.size()


func dirty_liquid_count() -> int:
	return _dirty_liquids.size()


func map_texture_bytes() -> int:
	if _pixels.is_empty():
		return 0
	return _pixels.size()


func is_revealing() -> bool:
	return _full_reveal_y >= 0 or _deferred_full_paint


func _update_player_discovery() -> void:
	if full_revealed or not _map_flag("perf_discovery"):
		return
	if _player == null or not is_instance_valid(_player):
		return
	var tile := world_to_map(_player.global_position)
	if tile == _last_player_tile:
		return
	_last_player_tile = tile
	discover_around(tile, DISCOVERY_RADIUS)


func _on_liquid_changed(cell: Vector2i) -> void:
	if not _built or not exploration.is_discovered(cell):
		return
	_dirty_liquids[cell] = true


func _flush_dirty_liquids() -> void:
	if _dirty_liquids.is_empty():
		return
	for cell in _dirty_liquids.keys():
		if exploration.is_discovered(cell):
			_paint_cell(cell)
			_mark_chunk_dirty(cell)
	_dirty_liquids.clear()
	_request_texture_flush()
	tiles_updated.emit()


func _mark_chunk_dirty(cell: Vector2i) -> void:
	_dirty_chunks[exploration.chunk_of(cell)] = true


func _request_texture_flush() -> void:
	_texture_dirty = true


func _flush_texture() -> void:
	if image == null or _pixels.is_empty():
		return
	var started := Time.get_ticks_usec()
	image.set_data(exploration.width, exploration.height, false, Image.FORMAT_RGBA8, _pixels)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
	else:
		texture.update(image)
	_texture_dirty = false
	_dirty_chunks.clear()
	map_flush_count += 1
	last_flush_ms = (Time.get_ticks_usec() - started) / 1000.0


func _block_id_at(cell: Vector2i) -> int:
	if _test_blocks.has(cell):
		return int(_test_blocks[cell])
	if _tilemap != null and _world != null and _world.block_catalog != null:
		if _tilemap.get_cell_source_id(cell) == -1:
			return 0
		var block := _world.block_catalog.get_cell_block(_tilemap, cell)
		return block.id if block != null else 0
	if _world != null:
		return _world.get_block_id(cell.x, cell.y)
	return 0


func _blocks_map_vision(cell: Vector2i) -> bool:
	if _test_solid.has(cell):
		return bool(_test_solid[cell])
	var block_id := _block_id_at(cell)
	if block_id == 0:
		return false
	if _world != null and _world.block_catalog != null:
		var block := _world.block_catalog.get_by_id(block_id)
		if block == null:
			return true
		if not block.solid:
			return false
		return block.get_vision_occlusion() >= 0.75
	return true


func _liquid_color_at(cell: Vector2i) -> Color:
	var liquid_type := 0
	var amount := 0
	if _test_liquids.has(cell):
		var packed := _test_liquids[cell] as Vector2i
		liquid_type = packed.x
		amount = packed.y
	elif _liquid != null:
		liquid_type = _liquid.get_type(cell)
		amount = _liquid.get_amount(cell)
	if amount < LIQUID_MAP_MIN or liquid_type == LiquidTypes.Type.NONE:
		return Color(0, 0, 0, 0)
	if liquid_type == LiquidTypes.Type.LAVA:
		return COLOR_LAVA_HOT if amount >= 192 else COLOR_LAVA
	if amount >= 192:
		return COLOR_WATER_DEEP
	return COLOR_WATER


func _air_color(cell: Vector2i) -> Color:
	if _is_fire_region(cell):
		return COLOR_CAVE_FIRE
	var surface := _surface_y(cell.x)
	if cell.y < surface:
		return COLOR_SKY
	var layer := _depth_layer_at(cell)
	if layer >= DepthLayer.Id.DANGER:
		return COLOR_CAVE_FIRE.darkened(0.15)
	if layer >= DepthLayer.Id.DEEP_CAVES:
		return COLOR_CAVE_DEEP
	return COLOR_CAVE


func _surface_y(tile_x: int) -> int:
	if _world != null:
		return _world.get_surface_y(tile_x)
	return _test_surface_y


func _depth_layer_at(cell: Vector2i) -> int:
	if _world != null:
		return _world.get_depth_layer(cell.x, cell.y)
	if cell.y <= _test_surface_y:
		return DepthLayer.Id.SURFACE
	return DepthLayer.Id.UNDERGROUND


func _is_fire_region(cell: Vector2i) -> bool:
	if _test_fire.has(cell):
		return true
	return _world != null and _world.is_fire_region(cell.x, cell.y)


func _color_for_block(block_id: int) -> Color:
	if _block_color_cache.has(block_id):
		return _block_color_cache[block_id]
	var mapped := Color(0, 0, 0, 0)
	if _world != null and _world.block_catalog != null:
		var block := _world.block_catalog.get_by_id(block_id)
		if block != null:
			mapped = block.get_map_color()
	if mapped.a <= 0.0:
		mapped = _fallback_block_color(block_id)
	_block_color_cache[block_id] = mapped
	return mapped


func _fallback_block_color(block_id: int) -> Color:
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
			return Color(0.42, 0.28, 0.30)
		6:
			return Color(0.22, 0.24, 0.28)
		7:
			return Color(0.42, 0.28, 0.14)
		8:
			return Color(0.22, 0.46, 0.16)
		9:
			return Color(0.52, 0.38, 0.24)
		10:
			return Color(0.54, 0.55, 0.56)
		11:
			return Color(0.48, 0.42, 0.40)
		12:
			return Color(0.58, 0.52, 0.32)
		13:
			return COLOR_BEDROCK
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


func start_tile() -> Vector2i:
	if _world != null:
		return _world.spawn_tile
	if _player != null:
		return world_to_map(_player.global_position)
	return Vector2i(exploration.width >> 1, _test_surface_y - 1)


func _lantern_tile() -> Vector2i:
	if is_inside_tree():
		var lantern := get_tree().get_first_node_in_group("lantern") as Node2D
		if lantern != null:
			return world_to_map(lantern.global_position)
	if _world != null:
		return Vector2i(_world.lantern_column_x(), _world.get_surface_y(_world.lantern_column_x()) - 1)
	return start_tile()


func _ensure_core_markers() -> void:
	_ensure_marker(PLAYER_MARKER_ID, MapMarker.Type.PLAYER).discovered_required = false
	_ensure_marker(LANTERN_MARKER_ID, MapMarker.Type.LAST_LANTERN).color = Color(1.0, 0.78, 0.28, 1)
	_ensure_marker(BED_MARKER_ID, MapMarker.Type.BED).color = Color(0.45, 0.62, 0.92, 1)
	var death := _ensure_marker(DEATH_MARKER_ID, MapMarker.Type.DEATH)
	death.color = Color(0.78, 0.22, 0.22, 1)
	death.visible = false


func _ensure_marker(marker_id: StringName, type: MapMarker.Type) -> MapMarker:
	var existing := _markers.get(marker_id) as MapMarker
	if existing != null:
		return existing
	var marker := MapMarker.new()
	marker.id = marker_id
	marker.type = type
	marker.discovered_required = type != MapMarker.Type.PLAYER
	_markers[marker_id] = marker
	return marker


func _refresh_runtime_markers() -> void:
	if not _built or not _map_flag("perf_map_markers"):
		return
	var player_marker := _ensure_marker(PLAYER_MARKER_ID, MapMarker.Type.PLAYER)
	if _player != null and is_instance_valid(_player):
		player_marker.world_position = _player.global_position
		player_marker.visible = true
	var lantern_marker := _ensure_marker(LANTERN_MARKER_ID, MapMarker.Type.LAST_LANTERN)
	if is_inside_tree():
		if _lantern == null or not is_instance_valid(_lantern):
			_lantern = get_tree().get_first_node_in_group("lantern") as Node2D
		if _lantern != null:
			lantern_marker.world_position = _lantern.global_position
			lantern_marker.visible = true
		else:
			lantern_marker.visible = false
	var bed_marker := _ensure_marker(BED_MARKER_ID, MapMarker.Type.BED)
	if _player != null and _player.has_valid_bed_spawn():
		bed_marker.world_position = _player.bed_spawn_position
		bed_marker.visible = true
	else:
		bed_marker.visible = false
