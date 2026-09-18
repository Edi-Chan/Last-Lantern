extends Node2D

## Ghost-Preview für Treppen-Drag. Grün/Gelb/Rot je Zelle.

var _cells: Array[Vector2i] = []
var _valid: Array[bool] = []
var _grades: Array[int] = []
var _tilemap: TileMapLayer


func show_cells(cells: Array[Vector2i], valid: Array[bool], grades: Array[int], tilemap: TileMapLayer) -> void:
	_cells = cells
	_valid = valid
	_grades = grades
	_tilemap = tilemap
	visible = not cells.is_empty()
	queue_redraw()


func clear_preview() -> void:
	_cells.clear()
	_valid.clear()
	_grades.clear()
	visible = false
	queue_redraw()


func _draw() -> void:
	if _tilemap == null:
		return
	for i in _cells.size():
		var cell := _cells[i]
		var ok := _valid[i] if i < _valid.size() else false
		var grade := _grades[i] if i < _grades.size() else 0
		var color := Color(0.9, 0.2, 0.15, 0.4)
		if ok:
			color = Color(0.25, 0.9, 0.35, 0.4)
			if grade == 2:
				color = Color(0.95, 0.85, 0.2, 0.42)
			elif grade == 3:
				color = Color(0.95, 0.2, 0.15, 0.42)
		var pos := to_local(_tilemap.to_global(_tilemap.map_to_local(cell) - Vector2(8, 8)))
		draw_rect(Rect2(pos, Vector2(16, 16)), color)
		draw_rect(Rect2(pos, Vector2(16, 16)), Color(color.r, color.g, color.b, 0.85), false, 1.0)
