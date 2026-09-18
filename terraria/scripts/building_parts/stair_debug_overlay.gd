extends Node2D

## Nur Development (F8). Im Release unsichtbar.

var parts: Node
var debug_enabled: bool = false

func _ready() -> void:
	z_index = 14
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F8:
		debug_enabled = not debug_enabled
		visible = debug_enabled
		queue_redraw()


func _process(_delta: float) -> void:
	if debug_enabled:
		queue_redraw()


func _draw() -> void:
	if not OS.is_debug_build() or not debug_enabled or parts == null:
		return
	var tilemap: TileMapLayer = parts.get("_fg")
	if tilemap == null:
		return
	var placed: Dictionary = parts.get("_placed_fg")
	var orientations: Dictionary = parts.get("_orientation")
	var catalog: BlockCatalog = parts.get("block_catalog")
	var structural := get_tree().get_first_node_in_group(&"structural_manager")
	var font := ThemeDB.fallback_font
	var font_size := 8
	for key in placed.keys():
		var cell: Vector2i = key
		var block: BlockData = catalog.get_by_id(int(placed[cell])) if catalog != null else null
		if not StairSystem.is_stair(block):
			continue
		var ori := int(orientations.get(cell, 0))
		var visual := StairSystem.resolve_visual(cell, ori, Callable(parts, "get_block_at"))
		var top_left := to_local(tilemap.to_global(tilemap.map_to_local(cell) - Vector2(8, 8)))
		draw_rect(Rect2(top_left, Vector2(16, 16)), Color(0.15, 0.7, 1.0, 0.18))
		draw_polyline(PackedVector2Array([
			top_left + Vector2(0, 16) if StairSystem.is_up_right(ori) else top_left + Vector2(16, 16),
			top_left + Vector2(16, 0) if StairSystem.is_up_right(ori) else top_left,
		]), Color(1.0, 0.85, 0.2, 0.9), 1.2)
		var support := "—"
		if structural != null and structural.has_method("is_stable"):
			if bool(structural.call("is_player_placed", cell)):
				support = "SUPPORTED" if bool(structural.call("is_stable", cell)) else "UNSTABLE"
		var lines := [
			"%s,%s" % [cell.x, cell.y],
			StairSystem.orientation_name(ori),
			StairSystem.visual_name(visual),
			support,
		]
		for i in lines.size():
			draw_string(font, top_left + Vector2(1, 6 + i * 8), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 64, font_size, Color(1, 1, 1, 0.92))
