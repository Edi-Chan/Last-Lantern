extends Node2D

## Debug-Ansicht aller World-Tiles. Verwendet dasselbe TileSet und denselben Katalog wie die echte Welt.

@export var block_catalog: BlockCatalog
@export var tile_set: TileSet

@onready var _layer: TileMapLayer = $TileMapLayer


func _ready() -> void:
	if block_catalog == null:
		block_catalog = load("res://resources/blocks/block_catalog.tres") as BlockCatalog
	if tile_set == null:
		tile_set = load("res://resources/blocks/terrain_tileset.tres") as TileSet
	_layer.tile_set = tile_set
	if block_catalog != null:
		block_catalog.ensure_tileset_tiles(tile_set)
	_place_tiles()


func _place_tiles() -> void:
	if block_catalog == null:
		return
	var source_id := block_catalog.terrain_source_id(tile_set)
	var i := 0
	for block in block_catalog.blocks:
		if block == null:
			continue
		var col := i % 8
		var row := i / 8
		var cell := Vector2i(col * 5, row * 4)
		_layer.set_cell(cell, source_id, block.atlas_coords)
		var label := Label.new()
		label.text = block.display_name
		label.position = Vector2(float(cell.x * 16 - 8), float(cell.y * 16 + 18))
		label.custom_minimum_size = Vector2(72, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1))
		add_child(label)
		i += 1
