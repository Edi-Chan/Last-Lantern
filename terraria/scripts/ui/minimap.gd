class_name MiniMap
extends Control

## Gehoert an: HUD/MiniMap. Groesse und Zoom sind getrennt. Gleiche Textur wie WorldMapData.

const SIZES: Array[Vector2] = [Vector2(160, 96), Vector2(200, 120), Vector2(260, 156)]
const BASE_VISIBLE := Vector2(64, 32)
const MIN_ZOOM := 0.5
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.5
const MARKER_SIZE := Vector2(8, 8)
const MARGIN := 12.0

@onready var _map_clip: Control = $Layout/MapClip
@onready var _map_content: Control = $Layout/MapClip/MapContent
@onready var _world_texture: TextureRect = $Layout/MapClip/MapContent/WorldTexture
@onready var _player_marker: TextureRect = $Layout/MapClip/PlayerMarker
@onready var _lantern_marker: ColorRect = $Layout/MapClip/LanternMarker
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


func _ready() -> void:
	add_to_group("minimap_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wanted_visible = false
	visible = false
	_player = get_tree().get_first_node_in_group("player") as Player
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
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	_bind_texture()
	_update_view()


func toggle() -> void:
	_wanted_visible = not _wanted_visible
	_apply_visible()


func _connect_data() -> void:
	_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if _data == null:
		return
	if not _data.rebuilt.is_connected(_bind_texture):
		_data.rebuilt.connect(_bind_texture)
	if _data.is_ready():
		_bind_texture()


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


func _bind_texture() -> void:
	if _data == null:
		_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	if _data == null or _data.texture == null or _world_texture == null:
		return
	if _world_texture.texture != _data.texture:
		_world_texture.texture = _data.texture
	var world_size := _data.world_size()
	if _world_texture.size != world_size:
		_world_texture.custom_minimum_size = world_size
		_world_texture.size = world_size
	if _map_content != null and _map_content.size != world_size:
		_map_content.custom_minimum_size = world_size
		_map_content.size = world_size


func _update_view() -> void:
	if _map_clip == null or _map_content == null or _player == null:
		return
	var clip := _map_clip.size
	if clip.x < 4.0 or clip.y < 4.0:
		return
	var visible_tiles := BASE_VISIBLE / maxf(_zoom, 0.05)
	var scale_v := minf(clip.x / visible_tiles.x, clip.y / visible_tiles.y)
	_map_content.scale = Vector2(scale_v, scale_v)
	var tile := _player_tile()
	_map_content.position = clip * 0.5 - (Vector2(tile) + Vector2(0.5, 0.5)) * scale_v
	if _player_marker != null:
		_player_marker.size = MARKER_SIZE
		_player_marker.position = clip * 0.5 - MARKER_SIZE * 0.5
	_update_lantern_marker(clip, scale_v, tile)
	if _coords_label != null:
		_coords_label.text = "X:%d Y:%d" % [tile.x, tile.y]
	if _biome_label != null:
		_biome_label.text = "%s  %s" % [_region_name(tile), _depth_name(tile)]


func _update_lantern_marker(clip: Vector2, scale_v: float, player_tile: Vector2i) -> void:
	if _lantern_marker == null:
		return
	var lantern := get_tree().get_first_node_in_group("lantern") as Node2D
	if lantern == null or _data == null:
		_lantern_marker.visible = false
		return
	_lantern_marker.visible = true
	_lantern_marker.size = Vector2(6, 6)
	var lantern_tile := _data.world_to_map(lantern.global_position)
	var offset := (Vector2(lantern_tile) - Vector2(player_tile)) * scale_v
	_lantern_marker.position = clip * 0.5 + offset - _lantern_marker.size * 0.5


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
	var surface := _world.get_surface_y(tile.x)
	var depth := tile.y - surface
	if depth <= 5:
		return "Surface"
	if depth <= 25:
		return "Shallow"
	if depth <= 70:
		return "Cave"
	return "Deep"
