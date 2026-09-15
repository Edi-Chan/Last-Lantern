class_name WorldMap
extends Control

## Gehoert an: HUD/WorldMap. Verschiebbares Kartenfenster, Zoom/Pan nur im Kartenbereich.

const TILE := 16
const MAX_ZOOM_FACTOR := 12.0
const ZOOM_STEP := 1.18
const MIN_WINDOW_SIZE := Vector2(320, 180)
const DEFAULT_WINDOW_SIZE := Vector2(480, 248)
const TITLE_KEEP := 96.0

@onready var _window: Control = $WindowPanel
@onready var _title_bar: Control = $WindowPanel/TitleBar/TitleRow
@onready var _fit_button: Button = $WindowPanel/TitleBar/TitleRow/FitWorldButton
@onready var _center_button: Button = $WindowPanel/TitleBar/TitleRow/CenterPlayerButton
@onready var _close_button: Button = $WindowPanel/TitleBar/TitleRow/CloseButton
@onready var _coords_label: Label = $WindowPanel/BottomInfo/BottomRow/CoordinatesLabel
@onready var _zoom_label: Label = $WindowPanel/BottomInfo/BottomRow/ZoomLabel
@onready var _map_clip: Control = $WindowPanel/MapClip
@onready var _map_content: Control = $WindowPanel/MapClip/MapContent
@onready var _world_texture: TextureRect = $WindowPanel/MapClip/MapContent/WorldTexture
@onready var _player_marker: TextureRect = $WindowPanel/MapClip/MapContent/PlayerMarker
@onready var _resize_handle: Control = $WindowPanel/ResizeHandle

var _data: WorldMapData
var _player: Player
var _tilemap: TileMapLayer
var _zoom: float = 1.0
var _fit_zoom: float = 1.0
var _map_panning: bool = false
var _pan_last: Vector2 = Vector2.ZERO
var _window_dragging: bool = false
var _window_drag_offset: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_start_mouse: Vector2 = Vector2.ZERO
var _resize_start_size: Vector2 = Vector2.ZERO
var _zoom_repeat_left: float = 0.0
var _saved_pos: Vector2 = Vector2.ZERO
var _saved_size: Vector2 = DEFAULT_WINDOW_SIZE
var _has_layout: bool = false
var _did_initial_fit: bool = false

func _ready() -> void:
	add_to_group("world_map_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_player = get_tree().get_first_node_in_group("player") as Player
	call_deferred("_connect_data")
	if _map_clip != null:
		_map_clip.resized.connect(_on_clip_resized)
		_map_clip.gui_input.connect(_on_clip_gui_input)
	if _title_bar != null:
		_title_bar.gui_input.connect(_on_title_gui_input)
	if _resize_handle != null:
		_resize_handle.gui_input.connect(_on_resize_gui_input)
	if _fit_button != null:
		_fit_button.pressed.connect(_fit_entire_world)
	if _center_button != null:
		_center_button.pressed.connect(center_on_player)
	if _close_button != null:
		_close_button.pressed.connect(close)
	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)


func _connect_data() -> void:
	_data = get_tree().get_first_node_in_group("world_map_data") as WorldMapData
	if _data == null:
		return
	if not _data.rebuilt.is_connected(_bind_texture):
		_data.rebuilt.connect(_bind_texture)
	if _data.is_ready():
		_bind_texture()


func _process(delta: float) -> void:
	if UIManager.is_blocking_gameplay():
		return
	if Input.is_action_just_pressed("world_map"):
		toggle()
		return
	if not visible:
		return
	if Input.is_action_just_pressed("map_center"):
		center_on_player()
	_update_window_drag()
	_update_window_resize()
	var zoom_dir := 0
	if Input.is_action_pressed("zoom_in"):
		zoom_dir += 1
	if Input.is_action_pressed("zoom_out"):
		zoom_dir -= 1
	if zoom_dir != 0:
		if Input.is_action_just_pressed("zoom_in") or Input.is_action_just_pressed("zoom_out") or _zoom_repeat_left <= 0.0:
			_zoom_at(_clip_center_local(), zoom_dir)
			_zoom_repeat_left = 0.12
		else:
			_zoom_repeat_left -= delta
	else:
		_zoom_repeat_left = 0.0
	_update_marker_and_labels()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		var gpos := mouse.global_position
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _point_in_control(_map_clip, gpos) and mouse.pressed:
				_zoom_at(_to_clip_local(gpos), 1 if mouse.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				get_viewport().set_input_as_handled()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT and mouse.button_index != MOUSE_BUTTON_MIDDLE:
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT and _point_in_control(_resize_handle, gpos):
			_resizing = mouse.pressed
			_resize_start_mouse = gpos
			if _window != null:
				_resize_start_size = _window.size
			get_viewport().set_input_as_handled()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT and _point_in_control(_title_bar, gpos) and not _over_window_button(gpos):
			_window_dragging = mouse.pressed
			if _window != null:
				_window_drag_offset = gpos - _window.global_position
			get_viewport().set_input_as_handled()
			return
		if _point_in_control(_map_clip, gpos):
			_map_panning = mouse.pressed
			_pan_last = _to_clip_local(gpos)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _map_panning and not _window_dragging and not _resizing and _map_content != null:
			var local := _to_clip_local(motion.global_position)
			_map_content.position += local - _pan_last
			_pan_last = local
			_clamp_pan()
			get_viewport().set_input_as_handled()


func _point_in_control(ctrl: Control, global_pos: Vector2) -> bool:
	return ctrl != null and ctrl.get_global_rect().has_point(global_pos)


func _to_clip_local(global_pos: Vector2) -> Vector2:
	if _map_clip == null:
		return Vector2.ZERO
	return _map_clip.get_global_transform_with_canvas().affine_inverse() * global_pos


func _over_window_button(global_pos: Vector2) -> bool:
	for btn in [_fit_button, _center_button, _close_button]:
		if btn != null and btn.get_global_rect().has_point(global_pos):
			return true
	return false


func is_open() -> bool:
	return visible


func consume_escape() -> bool:
	if not visible:
		return false
	close()
	return true


func _on_viewport_size_changed() -> void:
	if visible:
		_clamp_window()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_player = _get_player()
	var inventory := get_tree().get_first_node_in_group("inventory_ui")
	if inventory != null and inventory.has_method("close") and inventory.visible:
		inventory.call("close", false)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _player != null:
		_player.world_input_enabled = false
	_set_minimap_suppressed(true)
	_apply_window_layout()
	if _data != null and not _data.is_ready():
		_data.rebuild_full()
	_bind_texture()
	if not _did_initial_fit:
		call_deferred("_fit_entire_world")
		_did_initial_fit = true


func close(restore_input: bool = true) -> void:
	_player = _get_player()
	_save_window_layout()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panning = false
	_window_dragging = false
	_resizing = false
	_set_minimap_suppressed(false)
	if restore_input and _player != null:
		var inventory := get_tree().get_first_node_in_group("inventory_ui")
		if inventory == null or not inventory.visible:
			_player.world_input_enabled = true


func rebuild_full() -> void:
	if _data != null:
		_data.rebuild_full()
		_bind_texture()


func update_map_tile(cell: Vector2i) -> void:
	if _data != null:
		_data.update_tile(cell)


func update_map_tiles(cells: Array) -> void:
	if _data != null:
		_data.update_tiles(cells)


func center_on_player() -> void:
	if _player == null or _map_clip == null or _map_content == null:
		return
	var tile := _player_tile()
	var local := Vector2(tile) * _zoom + _map_content.position
	var delta := _clip_center_local() - local
	_map_content.position += delta
	_clamp_pan()


func _bind_texture() -> void:
	if _data == null or _data.texture == null:
		return
	var world_size := _data.world_size()
	if _world_texture != null:
		_world_texture.texture = _data.texture
		_world_texture.custom_minimum_size = world_size
		_world_texture.size = world_size
	if _map_content != null:
		_map_content.custom_minimum_size = world_size
		_map_content.size = world_size


func _fit_entire_world() -> void:
	if _data == null or _data.image == null or _map_clip == null or _map_content == null:
		return
	var clip := _map_clip.size
	if clip.x < 8.0 or clip.y < 8.0:
		return
	var world_size := _data.world_size()
	_fit_zoom = minf(clip.x / world_size.x, clip.y / world_size.y)
	_zoom = _fit_zoom
	_map_content.scale = Vector2(_zoom, _zoom)
	_map_content.position = (clip - world_size * _zoom) * 0.5
	_update_marker_and_labels()


func _on_clip_resized() -> void:
	if visible:
		_clamp_pan()
		_update_marker_and_labels()


func _on_clip_gui_input(event: InputEvent) -> void:
	if not visible or _window_dragging or _resizing:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
			_zoom_at(mouse.position, 1)
			_map_clip.accept_event()
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
			_zoom_at(mouse.position, -1)
			_map_clip.accept_event()
		elif mouse.button_index == MOUSE_BUTTON_LEFT or mouse.button_index == MOUSE_BUTTON_MIDDLE:
			_map_panning = mouse.pressed
			_pan_last = mouse.position
			_map_clip.accept_event()
	elif event is InputEventMouseMotion and _map_panning:
		var motion := event as InputEventMouseMotion
		_map_content.position += motion.position - _pan_last
		_pan_last = motion.position
		_clamp_pan()
		_map_clip.accept_event()


func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_window_dragging = mouse.pressed
			_window_drag_offset = get_global_mouse_position() - _window.global_position
			_title_bar.accept_event()


func _on_resize_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_resizing = mouse.pressed
			_resize_start_mouse = get_global_mouse_position()
			_resize_start_size = _window.size
			_resize_handle.accept_event()


func _update_window_drag() -> void:
	if not _window_dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_window_dragging = false
		return
	_window.global_position = get_global_mouse_position() - _window_drag_offset
	_clamp_window()


func _update_window_resize() -> void:
	if not _resizing:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_resizing = false
		_save_window_layout()
		return
	var delta := get_global_mouse_position() - _resize_start_mouse
	_window.size = (_resize_start_size + delta).clamp(MIN_WINDOW_SIZE, _max_window_size())
	_clamp_window()


func _apply_window_layout() -> void:
	if _window == null:
		return
	var max_size := _max_window_size()
	if _has_layout:
		_window.size = _saved_size.clamp(MIN_WINDOW_SIZE, max_size)
		_window.position = _saved_pos
	else:
		_window.size = DEFAULT_WINDOW_SIZE.clamp(MIN_WINDOW_SIZE, max_size)
		var vp := get_viewport_rect().size
		_window.position = (vp - _window.size) * 0.5
	_clamp_window()


func _save_window_layout() -> void:
	if _window == null:
		return
	_saved_pos = _window.position
	_saved_size = _window.size
	_has_layout = true


func _clamp_window() -> void:
	if _window == null:
		return
	var vp := get_viewport_rect().size
	var win_size := _window.size.clamp(MIN_WINDOW_SIZE, _max_window_size())
	_window.size = win_size
	var pos := _window.position
	pos.x = clampf(pos.x, TITLE_KEEP - win_size.x, vp.x - TITLE_KEEP)
	pos.y = clampf(pos.y, 0.0, vp.y - TITLE_KEEP)
	_window.position = pos


func _max_window_size() -> Vector2:
	return get_viewport_rect().size * 0.92


func _zoom_at(clip_local: Vector2, direction: int) -> void:
	if _map_content == null:
		return
	var factor := ZOOM_STEP if direction > 0 else 1.0 / ZOOM_STEP
	var next := clampf(_zoom * factor, _fit_zoom, _fit_zoom * MAX_ZOOM_FACTOR)
	if is_equal_approx(next, _zoom):
		return
	var world_point := (clip_local - _map_content.position) / _zoom
	_zoom = next
	_map_content.scale = Vector2(_zoom, _zoom)
	_map_content.position = clip_local - world_point * _zoom
	_clamp_pan()
	_update_marker_and_labels()


func _clamp_pan() -> void:
	if _data == null or _data.image == null or _map_clip == null or _map_content == null:
		return
	var scaled := _data.world_size() * _zoom
	var clip := _map_clip.size
	var pos := _map_content.position
	if scaled.x <= clip.x:
		pos.x = (clip.x - scaled.x) * 0.5
	else:
		pos.x = clampf(pos.x, clip.x - scaled.x, 0.0)
	if scaled.y <= clip.y:
		pos.y = (clip.y - scaled.y) * 0.5
	else:
		pos.y = clampf(pos.y, clip.y - scaled.y, 0.0)
	_map_content.position = pos


func _update_marker_and_labels() -> void:
	if _player_marker == null or _player == null:
		return
	var tile := _player_tile()
	var inverse := 1.0 / maxf(_zoom, 0.001)
	_player_marker.scale = Vector2(inverse, inverse)
	var marker_size := _player_marker.size
	if marker_size.x < 1.0:
		marker_size = Vector2(16, 16)
	_player_marker.position = Vector2(tile) - marker_size * 0.5 * inverse
	if _coords_label != null:
		_coords_label.text = "X: %d   Y: %d" % [tile.x, tile.y]
	if _zoom_label != null:
		var relative := _zoom / maxf(_fit_zoom, 0.0001)
		_zoom_label.text = "Zoom %.1fx" % relative


func _player_tile() -> Vector2i:
	if _data != null and _player != null:
		return _data.world_to_map(_player.global_position)
	if _tilemap == null or _player == null:
		return Vector2i.ZERO
	return _tilemap.local_to_map(_tilemap.to_local(_player.global_position))


func _clip_center_local() -> Vector2:
	if _map_clip == null:
		return Vector2.ZERO
	return _map_clip.size * 0.5


func _get_player() -> Player:
	if _player != null and is_instance_valid(_player):
		return _player
	_player = get_tree().get_first_node_in_group("player") as Player
	return _player


func _set_minimap_suppressed(value: bool) -> void:
	var minimap_ui := get_tree().get_first_node_in_group("minimap_ui")
	if minimap_ui != null and minimap_ui.has_method("set_suppressed"):
		minimap_ui.call("set_suppressed", value)
