class_name UndergroundBackdrop
extends Node2D

## Gehoert an: World/Background/UndergroundBackdrop
## Fuellt unter der Oberkante. Farbe und Textur folgen der Tiefe.

@export var shallow_color: Color = Color(0.22, 0.15, 0.11, 1)
@export var underground_color: Color = Color(0.13, 0.12, 0.14, 1)
@export var deep_color: Color = Color(0.07, 0.075, 0.10, 1)
@export var shallow_texture: Texture2D
@export var underground_texture: Texture2D
@export var deep_texture: Texture2D

var _tile_size: int = 16
var _bottom: float = 0.0
var _tops: PackedInt32Array


func _ready() -> void:
	if shallow_texture == null:
		shallow_texture = _load_world_texture("res://assets/world/background/dark_dirt_background.png")
	if underground_texture == null:
		underground_texture = _load_world_texture("res://assets/world/background/dark_stone_background.png")
	if deep_texture == null:
		deep_texture = _load_world_texture("res://assets/world/background/deep_stone_background.png")


func _load_world_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func set_profile(surface_tops: PackedInt32Array, tile_size: int, bottom_y: float) -> void:
	_tops = surface_tops
	_tile_size = tile_size
	_bottom = bottom_y
	queue_redraw()


func _draw() -> void:
	if _tops.is_empty():
		return
	var size := float(_tile_size)
	var x := 0
	while x < _tops.size():
		var top := _tops[x]
		var last := x
		while last + 1 < _tops.size() and _tops[last + 1] == top:
			last += 1
		var left := float(x) * size
		var width := float(last - x + 1) * size
		var y0 := float(top) * size
		var y1 := minf(y0 + 25.0 * size, _bottom)
		var y2 := minf(y0 + 70.0 * size, _bottom)
		_fill_band(left, width, y0, y1, shallow_color, shallow_texture)
		_fill_band(left, width, y1, y2, underground_color, underground_texture)
		_fill_band(left, width, y2, _bottom, deep_color, deep_texture)
		x = last + 1


func _fill_band(left: float, width: float, top: float, bottom: float, color: Color, tex: Texture2D) -> void:
	if bottom <= top + 0.5:
		return
	var rect := Rect2(left, top, width, bottom - top)
	draw_rect(rect, color)
	if tex != null:
		draw_texture_rect(tex, rect, true, Color(1, 1, 1, 0.32))
