class_name VisibilityOverlay
extends Sprite2D

## Gehoert an: World/VisibilityOverlay. Tile-Sicht durch solide Bloecke, nur Camera-Ausschnitt.
## Rebuild nur bei Tile-/Kamera-Aenderung. Offene Luft ueber der Oberflaeche wird nicht geflutet.

const TILE := 16
const MARGIN_TILES := 4
const MAX_COST := 6.0
const MIN_REBUILD_INTERVAL := 0.05
const TARGET_CELLS := 10000
## Bis zu diesem zoom_out bleibt die feine 1-Tile-Sicht (wie bei Zoom 1–1.5).
const FINE_VISION_ZOOM_OUT := 1.75
const OCC_UNKNOWN := 255
const OCC_SCALE := 20.0
## Terraria-artig: so viele Tiles reicht Himmelslicht in den Boden.
const SKY_LIGHT_DEPTH := 5.0

var _tilemap: TileMapLayer
var _world: WorldGenerator
var _player: Player
var _catalog: BlockCatalog
var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _occ_by_atlas: Dictionary = {}
var _world_occ := PackedByteArray()
var _cache_w: int = 0
var _cache_h: int = 0
var _origin := Vector2i.ZERO
var _view_size := Vector2i.ZERO
var _last_player := Vector2i(99999, 99999)
var _last_origin := Vector2i(99999, 99999)
var _last_size := Vector2i.ZERO
var _last_cell: int = 0
var _dirty: bool = true
var _rebuild_cooldown: float = 0.0
var _occ := PackedFloat32Array()
var _costs := PackedFloat32Array()
var _queue := PackedInt32Array()
var last_rebuild_ms: float = 0.0
var last_flood_ms: float = 0.0
var last_occ_ms: float = 0.0
var last_pixels_ms: float = 0.0


func _ready() -> void:
	add_to_group("visibility_overlay")
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 6
	_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _world != null:
		_catalog = _world.block_catalog
	var trees := get_tree().get_first_node_in_group("tree_system")
	if trees != null and trees.has_signal("tiles_changed"):
		if not trees.is_connected("tiles_changed", _on_tiles_changed):
			trees.connect("tiles_changed", _on_tiles_changed)


func invalidate() -> void:
	_dirty = true


func invalidate_cell(cell: Vector2i) -> void:
	_forget_occ_rect(cell, 3)
	_dirty = true


func invalidate_cells(cells: Array) -> void:
	for cell in cells:
		_forget_occ_rect(cell, 2)
	_dirty = true


func _on_tiles_changed(cells: Array) -> void:
	invalidate_cells(cells)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
		if _world != null:
			_catalog = _world.block_catalog
	if _player == null or _tilemap == null:
		return
	_rebuild_cooldown = maxf(0.0, _rebuild_cooldown - delta)
	var player_tile := _tilemap.local_to_map(_tilemap.to_local(_player.global_position))
	_fill_view_rect()
	var cell := _cell_scale_for(_view_size)
	var aligned := Vector2i(
		int(floor(float(_origin.x) / float(cell))) * cell,
		int(floor(float(_origin.y) / float(cell))) * cell
	)
	var size := _quantized_size(_view_size)
	var need := _dirty or player_tile != _last_player or aligned != _last_origin or size != _last_size or cell != _last_cell
	if not need:
		return
	if not _dirty and _rebuild_cooldown > 0.0:
		return
	_rebuild(player_tile, aligned, size, cell)
	_rebuild_cooldown = 0.0 if _dirty else MIN_REBUILD_INTERVAL


func _fill_view_rect() -> void:
	var camera := get_viewport().get_camera_2d()
	var view := get_viewport().get_visible_rect().size
	if camera != null:
		view = view / camera.zoom
		var center := camera.get_screen_center_position()
		var top_left := center - view * 0.5
		_origin = Vector2i(int(floor(top_left.x / float(TILE))), int(floor(top_left.y / float(TILE)))) - Vector2i(MARGIN_TILES, MARGIN_TILES)
	else:
		var top_left := _player.global_position - view * 0.5
		_origin = Vector2i(int(floor(top_left.x / float(TILE))), int(floor(top_left.y / float(TILE)))) - Vector2i(MARGIN_TILES, MARGIN_TILES)
	_view_size = Vector2i(int(ceil(view.x / float(TILE))) + MARGIN_TILES * 2 + 2, int(ceil(view.y / float(TILE))) + MARGIN_TILES * 2 + 2)


func _cell_scale_for(raw: Vector2i) -> int:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("get_zoom_out"):
		if float(cam.call("get_zoom_out")) <= FINE_VISION_ZOOM_OUT + 0.001:
			return 1
	var area := maxi(1, raw.x * raw.y)
	if area <= TARGET_CELLS:
		return 1
	if area <= TARGET_CELLS * 4:
		return 2
	if area <= TARGET_CELLS * 9:
		return 3
	return 4


func _quantized_size(raw: Vector2i) -> Vector2i:
	return Vector2i(
		maxi(8, (raw.x + 7) & ~7),
		maxi(8, (raw.y + 7) & ~7)
	)


func _rebuild(player_tile: Vector2i, origin: Vector2i, view_size: Vector2i, cell: int) -> void:
	var t0 := Time.get_ticks_usec()
	_ensure_occ_cache()
	_last_player = player_tile
	_last_origin = origin
	_last_size = view_size
	_last_cell = cell
	_dirty = false
	visible = true
	var gw := maxi(1, int(ceil(float(view_size.x) / float(cell))))
	var gh := maxi(1, int(ceil(float(view_size.y) / float(cell))))
	_ensure_image(gw, gh)
	var t1 := Time.get_ticks_usec()
	_fill_occlusion(origin, gw, gh, cell)
	var t2 := Time.get_ticks_usec()
	_flood(player_tile, origin, gw, gh, cell)
	var t3 := Time.get_ticks_usec()
	_fill_combined_pixels(player_tile, origin, gw, gh, cell)
	_apply_texture(origin, cell)
	var t4 := Time.get_ticks_usec()
	last_occ_ms = float(t2 - t1) / 1000.0
	last_flood_ms = float(t3 - t2) / 1000.0
	last_pixels_ms = float(t4 - t3) / 1000.0
	last_rebuild_ms = float(t4 - t0) / 1000.0


func _ensure_image(gw: int, gh: int) -> void:
	var cell_count := gw * gh
	if _image == null or _image.get_width() != gw or _image.get_height() != gh:
		_image = Image.create(gw, gh, false, Image.FORMAT_RGBA8)
	if _pixels.size() != cell_count * 4:
		_pixels.resize(cell_count * 4)
		_pixels.fill(0)


func _apply_texture(origin: Vector2i, cell: int) -> void:
	_image.set_data(_image.get_width(), _image.get_height(), false, Image.FORMAT_RGBA8, _pixels)
	if _texture == null or _texture.get_width() != _image.get_width() or _texture.get_height() != _image.get_height():
		_texture = ImageTexture.create_from_image(_image)
		texture = _texture
	else:
		_texture.update(_image)
		if texture != _texture:
			texture = _texture
	global_position = Vector2(origin) * float(TILE)
	scale = Vector2(float(TILE * cell), float(TILE * cell))


func _fill_combined_pixels(player_tile: Vector2i, origin: Vector2i, gw: int, gh: int, cell: int) -> void:
	var px := player_tile.x
	var py := player_tile.y
	var gx := 0
	while gx < gw:
		var world_x := origin.x + gx * cell
		var surf := _world.get_surface_y(world_x) if _world != null else origin.y
		var remaining := _trace_sky_remaining(world_x, origin.y)
		var gy := 0
		while gy < gh:
			var i := gy * gw + gx
			var world_y := origin.y + gy * cell
			var sky_dark := 0.0
			if world_y < surf:
				remaining = SKY_LIGHT_DEPTH
				sky_dark = 0.0
			elif _occ[i] <= 0.05:
				if remaining > 0.0:
					remaining = SKY_LIGHT_DEPTH
					sky_dark = 0.0
				else:
					sky_dark = 1.0
			else:
				sky_dark = _sky_darkness(SKY_LIGHT_DEPTH - remaining)
				remaining = maxf(0.0, remaining - 1.0)
			var cost := _costs[i]
			if absi(world_x - px) + absi(world_y - py) <= 3:
				cost = 0.0
			var player_dark := _wall_darkness(cost)
			var darkness := sky_dark if sky_dark < player_dark else player_dark
			_pixels[i * 4 + 3] = clampi(int(darkness * 255.0), 0, 255)
			gy += 1
		gx += 1


func _trace_sky_remaining(world_x: int, view_top_y: int) -> float:
	if _world == null:
		return SKY_LIGHT_DEPTH
	var surf := _world.get_surface_y(world_x)
	if view_top_y <= surf:
		return SKY_LIGHT_DEPTH
	var remaining := SKY_LIGHT_DEPTH
	var y := surf
	while y < view_top_y:
		if _occ_world(world_x, y) <= 0.05:
			remaining = SKY_LIGHT_DEPTH
		else:
			remaining = maxf(0.0, remaining - 1.0)
		y += 1
	return remaining


func _occ_world(x: int, y: int) -> float:
	if _cache_w > 0 and x >= 0 and y >= 0 and x < _cache_w and y < _cache_h:
		var idx := y * _cache_w + x
		var packed := _world_occ[idx]
		if packed != OCC_UNKNOWN:
			return float(packed) / OCC_SCALE
		var value := _occlusion_at(Vector2i(x, y))
		_world_occ[idx] = clampi(int(value * OCC_SCALE + 0.5), 0, 250)
		return value
	return _occlusion_at(Vector2i(x, y))


func _sky_darkness(depth: float) -> float:
	if depth <= 0.0:
		return 0.0
	if depth <= 3.0:
		return lerpf(0.0, 0.28, depth / 3.0)
	if depth <= SKY_LIGHT_DEPTH:
		return lerpf(0.28, 1.0, (depth - 3.0) / 2.0)
	return 1.0


func _ensure_occ_cache() -> void:
	if _world == null:
		return
	var w: int = _world.world_width
	var h: int = _world.world_height
	if _world_occ.size() == w * h and _cache_w == w and _cache_h == h:
		return
	_cache_w = w
	_cache_h = h
	_world_occ.resize(w * h)
	_world_occ.fill(OCC_UNKNOWN)


func _forget_occ_rect(cell: Vector2i, radius: int) -> void:
	if _world_occ.is_empty():
		return
	var x0 := cell.x - radius
	var y0 := cell.y - radius
	var x1 := cell.x + radius
	var y1 := cell.y + radius
	var y := y0
	while y <= y1:
		var x := x0
		while x <= x1:
			if x >= 0 and y >= 0 and x < _cache_w and y < _cache_h:
				_world_occ[y * _cache_w + x] = OCC_UNKNOWN
			x += 1
		y += 1


func _fill_occlusion(origin: Vector2i, gw: int, gh: int, cell: int) -> void:
	var n := gw * gh
	if _occ.size() != n:
		_occ.resize(n)
	var cache_w := _cache_w
	var cache_h := _cache_h
	var has_cache := cache_w > 0 and _world_occ.size() == cache_w * cache_h
	var i := 0
	var gy := 0
	while gy < gh:
		var gx := 0
		while gx < gw:
			var wx := origin.x + gx * cell
			var wy := origin.y + gy * cell
			var value := 0.0
			if has_cache and wx >= 0 and wy >= 0 and wx < cache_w and wy < cache_h:
				var idx := wy * cache_w + wx
				var packed := _world_occ[idx]
				if packed == OCC_UNKNOWN:
					value = _occlusion_at(Vector2i(wx, wy))
					_world_occ[idx] = clampi(int(value * OCC_SCALE + 0.5), 0, 250)
				else:
					value = float(packed) / OCC_SCALE
			else:
				value = _occlusion_at(Vector2i(wx, wy))
			if cell > 1:
				var extra := 0.0
				if has_cache and wx + 1 >= 0 and wy >= 0 and wx + 1 < cache_w and wy < cache_h:
					var sidx := wy * cache_w + (wx + 1)
					var sp := _world_occ[sidx]
					if sp == OCC_UNKNOWN:
						extra = _occlusion_at(Vector2i(wx + 1, wy))
						_world_occ[sidx] = clampi(int(extra * OCC_SCALE + 0.5), 0, 250)
					else:
						extra = float(sp) / OCC_SCALE
				else:
					extra = _occlusion_at(Vector2i(wx + 1, wy))
				if extra > value:
					value = extra
				if has_cache and wx >= 0 and wy + 1 >= 0 and wx < cache_w and wy + 1 < cache_h:
					var sidx2 := (wy + 1) * cache_w + wx
					var sp2 := _world_occ[sidx2]
					if sp2 == OCC_UNKNOWN:
						extra = _occlusion_at(Vector2i(wx, wy + 1))
						_world_occ[sidx2] = clampi(int(extra * OCC_SCALE + 0.5), 0, 250)
					else:
						extra = float(sp2) / OCC_SCALE
				else:
					extra = _occlusion_at(Vector2i(wx, wy + 1))
				if extra > value:
					value = extra
				if has_cache and wx + 1 >= 0 and wy + 1 >= 0 and wx + 1 < cache_w and wy + 1 < cache_h:
					var sidx3 := (wy + 1) * cache_w + (wx + 1)
					var sp3 := _world_occ[sidx3]
					if sp3 == OCC_UNKNOWN:
						extra = _occlusion_at(Vector2i(wx + 1, wy + 1))
						_world_occ[sidx3] = clampi(int(extra * OCC_SCALE + 0.5), 0, 250)
					else:
						extra = float(sp3) / OCC_SCALE
				else:
					extra = _occlusion_at(Vector2i(wx + 1, wy + 1))
				if extra > value:
					value = extra
			_occ[i] = value
			i += 1
			gx += 1
		gy += 1


func _flood(start: Vector2i, origin: Vector2i, gw: int, gh: int, cell: int) -> void:
	var n := gw * gh
	if _costs.size() != n:
		_costs.resize(n)
	_costs.fill(MAX_COST)
	_prefill_open_sky(start, origin, gw, gh, cell)
	var cap := n * 2 + 16
	if _queue.size() != cap:
		_queue.resize(cap)
	var head := 0
	var tail := 0
	var count := 0
	var sx := clampi(int(floor(float(start.x - origin.x) / float(cell))), 0, gw - 1)
	var sy := clampi(int(floor(float(start.y - origin.y) / float(cell))), 0, gh - 1)
	var start_i := sy * gw + sx
	_costs[start_i] = 0.0
	_queue[0] = start_i
	tail = 1
	count = 1
	while count > 0:
		var idx := _queue[head]
		head += 1
		if head >= cap:
			head = 0
		count -= 1
		var current := _costs[idx]
		if current >= MAX_COST:
			continue
		var cx := idx % gw
		var cy := int(float(idx) / float(gw))
		var d := 0
		while d < 4:
			var nx := cx
			var ny := cy
			if d == 0:
				nx -= 1
			elif d == 1:
				nx += 1
			elif d == 2:
				ny -= 1
			else:
				ny += 1
			d += 1
			if nx < 0 or ny < 0 or nx >= gw or ny >= gh or count >= cap:
				continue
			var ni := ny * gw + nx
			var add := _occ[ni]
			var next_cost := current + add
			if next_cost >= MAX_COST or next_cost + 0.001 >= _costs[ni]:
				continue
			_costs[ni] = next_cost
			if add <= 0.05:
				head -= 1
				if head < 0:
					head = cap - 1
				_queue[head] = ni
			else:
				_queue[tail] = ni
				tail += 1
				if tail >= cap:
					tail = 0
			count += 1


func _prefill_open_sky(start: Vector2i, origin: Vector2i, gw: int, gh: int, cell: int) -> void:
	if _world == null:
		return
	var surface := _world.get_surface_y(start.x)
	if start.y > surface + 10:
		return
	var gx := 0
	while gx < gw:
		var world_x := origin.x + gx * cell
		var sky_limit := _world.get_surface_y(world_x) - 1
		var gy := 0
		while gy < gh:
			var world_y := origin.y + gy * cell
			if world_y >= sky_limit:
				break
			_costs[gy * gw + gx] = 0.0
			gy += 1
		gx += 1


func _occlusion_at(cell: Vector2i) -> float:
	if _tilemap == null or _tilemap.get_cell_source_id(cell) == -1:
		return 0.0
	var source := _tilemap.get_cell_source_id(cell)
	var atlas := _tilemap.get_cell_atlas_coords(cell)
	var key := source * 1000000 + atlas.x * 1024 + atlas.y
	if _occ_by_atlas.has(key):
		return float(_occ_by_atlas[key])
	var value := 1.0
	if _catalog != null:
		var block := _catalog.get_cell_block(_tilemap, cell)
		value = 0.0 if block == null else block.get_vision_occlusion()
	_occ_by_atlas[key] = value
	return value


func _wall_darkness(cost: float) -> float:
	if cost <= 0.0:
		return 0.0
	if cost < 1.0:
		return lerpf(0.0, 0.15, cost)
	if cost < 2.0:
		return lerpf(0.15, 0.40, cost - 1.0)
	if cost < 3.0:
		return lerpf(0.40, 0.65, cost - 2.0)
	if cost < 4.0:
		return lerpf(0.65, 0.90, cost - 3.0)
	return lerpf(0.90, 1.0, clampf((cost - 4.0) / 2.0, 0.0, 1.0))
