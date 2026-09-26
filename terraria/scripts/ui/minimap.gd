class_name MiniMap
extends Control

## Gehoert an: HUD/MiniMap. Groesse und Zoom sind getrennt. Gleiche Textur wie WorldMapData.

const SIZES: Array[Vector2] = [Vector2(160, 96), Vector2(200, 120), Vector2(260, 156)]
const BASE_VISIBLE := Vector2(64, 32)
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.5
const MARKER_SIZE := Vector2(8, 8)
const LANTERN_SIZE := Vector2(6, 6)
const BED_SIZE := Vector2(5, 5)
const MARGIN := 12.0

@onready var _map_clip: Control = $Layout/MapClip
@onready var _map_content: Control = $Layout/MapClip/MapContent
@onready var _world_texture: TextureRect = $Layout/MapClip/MapContent/WorldTexture
@onready var _player_marker: TextureRect = $Layout/MapClip/MapContent/PlayerMarker
@onready var _lantern_marker: ColorRect = $Layout/MapClip/MapContent/LanternMarker
@onready var _bed_marker: ColorRect = $Layout/MapClip/MapContent/BedMarker
@onready var _coords_label: Label = $Layout/TopBar/CoordinatesLabel
@onready var _biome_label: Label = $Layout/InfoPanel/BiomeLabel
@onready var _size_down: Button = $Layout/TopBar/SizeDownButton
@onready var _size_up: Button = $Layout/TopBar/SizeUpButton
@onready var _zoom_out_btn: Button = $Layout/TopBar/ZoomOutButton
@onready var _zoom_in_btn: Button = $Layout/TopBar/ZoomInButton

var _data: WorldMapData
var _world: WorldGenerator
var _player: Player
var _wanted_visible: bool = false
var _suppressed: bool = false
var _size_index: int = 1
var _zoom: float = 1.0
var _local_image: Image
var _local_texture: ImageTexture
var _local_origin := Vector2i(-99999, -99999)
var _local_size := Vector2i.ZERO
var _local_dirty: bool = true
var _liquid_view_left: float = 0.0


func _ready() -> void:
	add_to_group("minimap_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wanted_visible = false
	visible = false
	_player = get_tree().get_first_node_in_group("player") as Player
	if _world_texture != null:
		_world_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _size_down != null:
		_size_down.pressed.connect(func() -> void: _shift_size(-1))
	if _size_up != null:
		_size_up.pressed.connect(func() -> void: _shift_size(1))
	if _zoom_out_btn != null:
		_zoom_out_btn.pressed.connect(func() -> void: _shift_zoom(-1))
	if _zoom_in_btn != null:
		_zoom_in_btn.pressed.connect(func() -> void: _shift_zoom(1))
	if _map_clip != null:
		_map_clip.gui_input.connect(_on_clip_gui_input)
	_apply_size()
	call_deferred("_connect_data")


func _process(_delta: float) -> void:
	if UIManager.is_blocking_gameplay():
		return
	if Input.is_action_just_pressed("toggle_minimap"):
		toggle()
	if not visible:
		return
	var mini_on = AdminManager.get("perf_minimap")
	if typeof(mini_on) != TYPE_NIL and not bool(mini_on):
		if _world_texture != null:
			_world_texture.texture = null
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_liquid_view_left -= _delta
	_update_view()


func toggle() -> void:
	_wanted_visible = not _wanted_visible
	_apply_visible()


func _connect_data() -> void:
	_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _data == null:
		return
	if not _data.rebuilt.is_connected(_mark_local_dirty):
		_data.rebuilt.connect(_mark_local_dirty)
	if not _data.tiles_updated.is_connected(_mark_local_dirty):
		_data.tiles_updated.connect(_mark_local_dirty)
	if not _data.discovery_changed.is_connected(_mark_local_dirty):
		_data.discovery_changed.connect(_mark_local_dirty)
	if _data.is_ready():
		_mark_local_dirty()


func set_suppressed(value: bool) -> void:
	_suppressed = value
	_apply_visible()


func _apply_visible() -> void:
	visible = _wanted_visible and not _suppressed
	mouse_filter = Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE


func _shift_size(delta: int) -> void:
	_size_index = clampi(_size_index + delta, 0, SIZES.size() - 1)
	_apply_size()


func _shift_zoom(delta: int) -> void:
	_zoom = clampf(_zoom + float(delta) * ZOOM_STEP, MIN_ZOOM, MAX_ZOOM)
	_update_view()


func _apply_size() -> void:
	var next := SIZES[_size_index]
	custom_minimum_size = next
	size = next
	if get_parent() is BoxContainer:
		_update_view()
		return
	offset_left = -(MARGIN + next.x)
	offset_top = MARGIN
	offset_right = -MARGIN
	offset_bottom = MARGIN + next.y
	_update_view()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		accept_event()


func _on_clip_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_shift_zoom(1)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_shift_zoom(-1)
		accept_event()


func _mark_local_dirty() -> void:
	_local_dirty = true


func _bind_texture() -> void:
	return


func _update_view() -> void:
	if _map_clip == null or _map_content == null or _player == null:
		return
	if _data == null:
		_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	var clip := _map_clip.size
	if clip.x < 4.0 or clip.y < 4.0:
		return
	var visible_tiles := BASE_VISIBLE / maxf(_zoom, 0.05)
	var scale_v := minf(clip.x / visible_tiles.x, clip.y / visible_tiles.y)
	var tile := _player_tile()
	var world_size := _data.world_size() if _data != null else Vector2.ZERO
	var region := _visible_region(tile, visible_tiles, world_size)
	var origin := Vector2i(region.position)
	var region_size := Vector2i(Vector2(region.size).ceil())
	region_size.x = maxi(region_size.x, 8)
	region_size.y = maxi(region_size.y, 8)
	if _liquid_view_left <= 0.0:
		_local_dirty = true
		_liquid_view_left = 0.18
	if origin != _local_origin or region_size != _local_size or _local_dirty:
		_rebuild_local(origin, region_size)
	if _world_texture != null:
		_world_texture.custom_minimum_size = Vector2(region_size)
		_world_texture.size = Vector2(region_size)
	if _map_content != null:
		_map_content.custom_minimum_size = Vector2(region_size)
		_map_content.size = Vector2(region_size)
		_map_content.scale = Vector2(scale_v, scale_v)
		_map_content.position = _clamped_content_pos(Vector2.ZERO, Vector2(region_size), scale_v, clip)
	_place_marker(_player_marker, Vector2(tile) - Vector2(origin), MARKER_SIZE, scale_v, true)
	_update_named_marker(_lantern_marker, WorldMapData.LANTERN_MARKER_ID, LANTERN_SIZE, scale_v, origin)
	_update_named_marker(_bed_marker, WorldMapData.BED_MARKER_ID, BED_SIZE, scale_v, origin)
	if _coords_label != null:
		_coords_label.text = "X:%d Y:%d" % [tile.x, tile.y]
	if _biome_label != null:
		_biome_label.text = "%s  %s" % [_region_name(tile), _depth_name(tile)]


func _clamped_content_pos(desired: Vector2, world_size: Vector2, scale_v: float, clip: Vector2) -> Vector2:
	var scaled := world_size * scale_v
	var pos := desired
	if scaled.x <= clip.x:
		pos.x = (clip.x - scaled.x) * 0.5
	else:
		pos.x = clampf(pos.x, clip.x - scaled.x, 0.0)
	if scaled.y <= clip.y:
		pos.y = (clip.y - scaled.y) * 0.5
	else:
		pos.y = clampf(pos.y, clip.y - scaled.y, 0.0)
	return pos


func _update_named_marker(node: Control, marker_id: StringName, marker_size: Vector2, scale_v: float, origin: Vector2i = Vector2i.ZERO) -> void:
	if node == null or _data == null:
		return
	var marker := _data.get_marker(marker_id)
	if marker == null or not marker.is_shown(_data):
		node.visible = false
		return
	_place_marker(node, Vector2(marker.tile(_data)) - Vector2(origin), marker_size, scale_v, true)


func _place_marker(node: Control, tile: Vector2, marker_size: Vector2, scale_v: float, shown: bool) -> void:
	if node == null:
		return
	node.visible = shown
	if not shown:
		return
	var inverse := 1.0 / maxf(scale_v, 0.001)
	node.size = marker_size
	node.scale = Vector2(inverse, inverse)
	node.position = tile + Vector2(0.5, 0.5) - marker_size * 0.5 * inverse


func _rebuild_local(origin: Vector2i, region_size: Vector2i) -> void:
	if _data == null or _world_texture == null:
		return
	if _local_image == null or _local_image.get_width() != region_size.x or _local_image.get_height() != region_size.y:
		_local_image = Image.create(region_size.x, region_size.y, false, Image.FORMAT_RGBA8)
	var pixels := PackedByteArray()
	pixels.resize(region_size.x * region_size.y * 4)
	var i := 0
	for y in region_size.y:
		for x in region_size.x:
			var color := _data.display_color_at(origin + Vector2i(x, y))
			pixels[i] = color.r8
			pixels[i + 1] = color.g8
			pixels[i + 2] = color.b8
			pixels[i + 3] = 255
			i += 4
	_local_image.set_data(region_size.x, region_size.y, false, Image.FORMAT_RGBA8, pixels)
	var texture_size_changed := _local_texture == null
	if not texture_size_changed:
		texture_size_changed = _local_texture.get_width() != region_size.x or _local_texture.get_height() != region_size.y
	if texture_size_changed:
		_local_texture = ImageTexture.create_from_image(_local_image)
	else:
		_local_texture.update(_local_image)
	_world_texture.texture = _local_texture
	_world_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_local_origin = origin
	_local_size = region_size
	_local_dirty = false


func _visible_region(center: Vector2i, visible_tiles: Vector2, world_size: Vector2) -> Rect2:
	var w := maxf(visible_tiles.x, 8.0)
	var h := maxf(visible_tiles.y, 8.0)
	var max_x := maxf(world_size.x - w, 0.0)
	var max_y := maxf(world_size.y - h, 0.0)
	var x := clampf(float(center.x) - w * 0.5, 0.0, max_x)
	var y := clampf(float(center.y) - h * 0.5, 0.0, max_y)
	if world_size.x > 0.0:
		w = minf(w, world_size.x)
	if world_size.y > 0.0:
		h = minf(h, world_size.y)
	return Rect2(x, y, w, h)


func _player_tile() -> Vector2i:
	if _data != null and _player != null:
		return _data.world_to_map(_player.global_position)
	return Vector2i.ZERO


func _region_name(tile: Vector2i) -> String:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _world == null:
		return ""
	return _world.get_region(tile)


func _depth_name(tile: Vector2i) -> String:
	if _world == null:
		return ""
	if _world.has_method("get_depth_layer"):
		return DepthLayer.display_name(_world.get_depth_layer(tile.x, tile.y))
	var surface := _world.get_surface_y(tile.x)
	var depth := tile.y - surface
	if depth <= 5:
		return "Surface"
	if depth <= 25:
		return "Shallow"
	if depth <= 70:
		return "Cave"
	return "Deep"
