class_name BuildingPlacementPreview
extends Node2D

## Transparente Multi-Tile-Vorschau. Gruen / Gelb / Rot.

var _rects: Array[ColorRect] = []
var _tile_size: int = 16


func _ready() -> void:
	z_index = 11
	visible = false


func hide_preview() -> void:
	visible = false
	for rect in _rects:
		rect.visible = false


func show_cells(tilemap: TileMapLayer, cells: Array, color: Color) -> void:
	if tilemap == null:
		hide_preview()
		return
	if tilemap.tile_set != null:
		_tile_size = tilemap.tile_set.tile_size.x
	visible = true
	while _rects.size() < cells.size():
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = Vector2(_tile_size, _tile_size)
		add_child(rect)
		_rects.append(rect)
	for i in _rects.size():
		var rect := _rects[i]
		if i >= cells.size():
			rect.visible = false
			continue
		var cell: Vector2i = cells[i]
		var top_left := tilemap.to_global(tilemap.map_to_local(cell) - Vector2(_tile_size, _tile_size) * 0.5)
		rect.global_position = top_left
		rect.size = Vector2(_tile_size, _tile_size)
		rect.color = color
		rect.visible = true
