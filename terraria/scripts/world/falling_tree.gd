class_name FallingTree
extends Node2D

## Temporaere Kipp-Darstellung. Pivot ist das untere Ende des fallenden Teils.

signal finished

const TILE := 16.0

@onready var _visual: Node2D = $VisualRoot


func setup(snapshots: Array[Dictionary], pivot_cell: Vector2i, tilemap: TileMapLayer, fall_right: bool, duration: float) -> void:
	if tilemap != null:
		global_position = tilemap.to_global(tilemap.map_to_local(pivot_cell)) + Vector2(0.0, TILE * 0.5)
	_build_sprites(snapshots, pivot_cell, tilemap)
	var target := deg_to_rad(88.0 if fall_right else -88.0)
	if _visual == null:
		_done()
		return
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_visual, "rotation", target, clampf(duration, 0.6, 1.3))
	tween.finished.connect(_done)


func _build_sprites(snapshots: Array[Dictionary], pivot_cell: Vector2i, tilemap: TileMapLayer) -> void:
	if _visual == null:
		return
	var atlas: Texture2D = null
	if tilemap != null and tilemap.tile_set != null and tilemap.tile_set.get_source_count() > 0:
		var source := tilemap.tile_set.get_source(tilemap.tile_set.get_source_id(0)) as TileSetAtlasSource
		if source != null:
			atlas = source.texture
	for snap in snapshots:
		var cell: Vector2i = snap["cell"]
		var coords: Vector2i = snap["atlas"]
		var sprite := Sprite2D.new()
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if atlas != null:
			sprite.texture = atlas
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2(coords) * TILE, Vector2(TILE, TILE))
		sprite.position = Vector2(float(cell.x - pivot_cell.x) * TILE, float(cell.y - pivot_cell.y) * TILE - TILE * 0.5)
		_visual.add_child(sprite)


func _done() -> void:
	finished.emit()
	queue_free()
