extends Node2D

## Nur Development. F7 schaltet Overlay-Farben.

var manager: Node

func _ready() -> void:
	z_index = 12

func _draw() -> void:
	if manager == null or not bool(manager.get("debug_enabled")):
		return
	var tilemap := manager.get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	if tilemap == null:
		return
	var placed: Dictionary = manager.get("_placed")
	for key in placed.keys():
		var cell: Vector2i = key
		var block: BlockData = manager.call("_block_at", cell)
		if block == null:
			continue
		var color := Color(0.2, 0.85, 0.25, 0.28)
		var unstable: Dictionary = manager.get("_unstable_until")
		if unstable.has(cell):
			color = Color(0.95, 0.15, 0.12, 0.4)
		elif float(manager.call("get_support", cell)) < float(block.support_strength) * 0.45:
			color = Color(0.95, 0.85, 0.15, 0.32)
		if bool(manager.call("is_anchor", cell)):
			color = Color(0.2, 0.4, 1.0, 0.38)
		if block.is_support_beam or block.structural_role == BlockData.StructuralRole.SUPPORT_BEAM:
			color = Color(0.15, 0.9, 0.95, 0.4)
		var pos := to_local(tilemap.to_global(tilemap.map_to_local(cell) - Vector2(8, 8)))
		draw_rect(Rect2(pos, Vector2(16, 16)), color)
