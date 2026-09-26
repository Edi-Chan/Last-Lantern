class_name GameCursor
extends CanvasLayer

## Pixel-Maus. Im Menue Hardware-Pfeil, in der Welt duennes Crosshair.

const GROUP := &"game_cursor"
const POINTER_PATH := "res://assets/ui/cursor/pointer.png"
const CROSSHAIR_PATH := "res://assets/ui/cursor/crosshair.png"
const TARGET_PATH := "res://assets/ui/cursor/target.png"
const POINTER_HOTSPOT := Vector2(1, 1)
const CROSS_HOTSPOT := Vector2(7, 7)

enum Kind {
	POINTER,
	CROSSHAIR,
	TARGET,
}

var _sprite: Sprite2D
var _pointer: Texture2D
var _crosshair: Texture2D
var _target: Texture2D
var _kind: int = Kind.POINTER
var _os_bound: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100


func _ready() -> void:
	add_to_group(GROUP)
	layer = 128
	follow_viewport_enabled = false
	_load_textures()
	_bind_os_cursors()
	_sprite = Sprite2D.new()
	_sprite.name = "CursorSprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_as_relative = false
	_sprite.z_index = 100
	add_child(_sprite)
	_apply_cursor()
	set_process(true)
	set_process_input(true)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.set_custom_mouse_cursor(null)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_apply_cursor()
		return
	if event.is_action("inventory") or event.is_action("ui_cancel") or event.is_action("world_map"):
		call_deferred("_apply_cursor")


func _process(_delta: float) -> void:
	_apply_cursor()


func pixel_scale() -> int:
	return 1


func resolve_kind() -> int:
	if wants_pointer():
		return Kind.POINTER
	if get_aimed_creature() != null:
		return Kind.TARGET
	return Kind.CROSSHAIR


func wants_pointer() -> bool:
	if Engine.is_editor_hint():
		return true
	var tree := get_tree()
	if tree == null:
		return true
	if tree.get_first_node_in_group("player") == null:
		return true
	if tree.get_first_node_in_group("start_flow_ui") != null:
		return true
	if UIManager != null and is_instance_valid(UIManager) and UIManager.has_method("is_blocking_gameplay"):
		if bool(UIManager.is_blocking_gameplay()):
			return true
	var inv := tree.get_first_node_in_group("inventory_ui")
	if inv != null and bool(inv.visible):
		return true
	var map := tree.get_first_node_in_group("world_map_ui")
	if map != null and map.has_method("is_open") and bool(map.call("is_open")):
		return true
	var vp := get_viewport()
	if vp == null:
		return false
	var hovered := vp.gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func get_aimed_creature() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var mgr := tree.get_first_node_in_group(EnemyHealthBarManager.GROUP)
	if mgr != null and mgr.has_method("get_aimed_target"):
		return mgr.call("get_aimed_target") as Node
	return null


func _apply_cursor() -> void:
	var vp := get_viewport()
	if vp == null or _sprite == null:
		return
	_kind = resolve_kind()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var tex := _texture_for(_kind)
	var hot := POINTER_HOTSPOT if _kind == Kind.POINTER else CROSS_HOTSPOT
	var pixel := pixel_scale()
	_sprite.texture = tex
	_sprite.scale = Vector2(pixel, pixel)
	_sprite.position = vp.get_mouse_position() - hot * float(pixel)
	_sprite.visible = true


func _texture_for(kind: int) -> Texture2D:
	match kind:
		Kind.TARGET:
			return _target
		Kind.CROSSHAIR:
			return _crosshair
		_:
			return _pointer


func _bind_os_cursors() -> void:
	if _os_bound or _pointer == null:
		return
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_ARROW, POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_IBEAM, POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_POINTING_HAND, POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_MOVE, POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_pointer, Input.CURSOR_CAN_DROP, POINTER_HOTSPOT)
	_os_bound = true


func _load_textures() -> void:
	_pointer = _load_or_build(POINTER_PATH, Kind.POINTER)
	_crosshair = _load_or_build(CROSSHAIR_PATH, Kind.CROSSHAIR)
	_target = _load_or_build(TARGET_PATH, Kind.TARGET)


func _load_or_build(path: String, kind: int) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	return _build_texture(kind)


func _build_texture(kind: int) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var fill := Color(0.97, 0.93, 0.81, 1)
	if kind == Kind.TARGET:
		fill = Color(0.84, 0.24, 0.19, 1)
	var outline := Color(0.04, 0.03, 0.02, 1)
	var cells: Array[Vector2i] = _pointer_cells() if kind == Kind.POINTER else _crosshair_cells()
	for cell in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nx := cell.x + dx
				var ny := cell.y + dy
				if nx < 0 or ny < 0 or nx >= 16 or ny >= 16:
					continue
				if kind != Kind.POINTER and abs(nx - 7) <= 1 and abs(ny - 7) <= 1:
					continue
				if img.get_pixel(nx, ny).a <= 0.0:
					img.set_pixel(nx, ny, outline)
	for cell in cells:
		img.set_pixel(cell.x, cell.y, fill)
	return ImageTexture.create_from_image(img)


func _pointer_cells() -> Array[Vector2i]:
	return [
		Vector2i(1, 1),
		Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
		Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 5),
		Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6), Vector2i(6, 6),
		Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7),
		Vector2i(1, 8), Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8), Vector2i(6, 8),
		Vector2i(1, 9), Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9),
		Vector2i(1, 10), Vector2i(2, 10), Vector2i(3, 10),
		Vector2i(1, 11), Vector2i(2, 11),
		Vector2i(1, 12),
		Vector2i(4, 9), Vector2i(5, 10), Vector2i(6, 11),
	]


func _crosshair_cells() -> Array[Vector2i]:
	return [
		Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4),
		Vector2i(7, 10), Vector2i(7, 11), Vector2i(7, 12),
		Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7),
		Vector2i(10, 7), Vector2i(11, 7), Vector2i(12, 7),
	]
