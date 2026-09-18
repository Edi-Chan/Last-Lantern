class_name BuildingPartSystem
extends Node2D

## Verwaltet spieler-gesetzte Bauteile: Tile-Autotile, Hintergrund-Layer,
## interaktive Entities, Save/Load. Kein zweites Placement-System.

const GROUP := &"building_part_system"
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIR_BITS: Array[int] = [N, E, S, W]
const ENTITY_TYPES := [
	BlockData.BuildingPartType.DOOR,
	BlockData.BuildingPartType.LIGHT,
	BlockData.BuildingPartType.STORAGE,
	BlockData.BuildingPartType.CRAFTING_STATION,
]
const TILE_SIZE := 16

@export var block_catalog: BlockCatalog
@export var item_catalog: ItemCatalog

var _fg: TileMapLayer
var _bg: TileMapLayer
var _entities: Dictionary = {}
var _occupancy: Dictionary = {}
var _placed_fg: Dictionary = {}
var _placed_bg: Dictionary = {}
var _orientation: Dictionary = {}
var _stair_preview: Node2D
var _stair_debug: Node2D


func _ready() -> void:
	add_to_group(GROUP)
	_fg = get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	if _fg == null:
		_fg = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_bg = get_node_or_null("../Terrain/BackgroundTiles") as TileMapLayer
	if _bg == null:
		_bg = get_tree().get_first_node_in_group("building_background") as TileMapLayer
	if block_catalog != null:
		if _fg != null:
			block_catalog.ensure_tileset_tiles(_fg.tile_set)
		if _bg != null:
			block_catalog.ensure_tileset_tiles(_bg.tile_set)
	_setup_stair_debug()
	call_deferred("_flatten_dev_build_plot")


func _setup_stair_debug() -> void:
	var debug_script := load("res://scripts/building_parts/stair_debug_overlay.gd") as GDScript
	if debug_script != null:
		_stair_debug = debug_script.new() as Node2D
		if _stair_debug != null:
			_stair_debug.set("parts", self)
			add_child(_stair_debug)
	var preview_script := load("res://scripts/building_parts/stair_preview_overlay.gd") as GDScript
	if preview_script != null:
		_stair_preview = Node2D.new()
		_stair_preview.z_index = 16
		_stair_preview.set_script(preview_script)
		add_child(_stair_preview)


func get_block_at(cell: Vector2i) -> BlockData:
	var ent: BuildingEntity = _occupancy.get(cell)
	if ent != null:
		return ent.block_data
	if _fg != null and block_catalog != null:
		var fg := block_catalog.get_cell_block(_fg, cell)
		if fg != null:
			return fg
	if _bg != null and block_catalog != null:
		return block_catalog.get_cell_block(_bg, cell)
	return null


func is_entity_cell(cell: Vector2i) -> bool:
	return _occupancy.has(cell)


func is_climbable_at_world(world_pos: Vector2) -> bool:
	if _fg == null or _fg.tile_set == null or block_catalog == null:
		return false
	var cell := _fg.local_to_map(_fg.to_local(world_pos))
	var block := get_block_at(cell)
	return block != null and block.is_climbable


func is_background_cell(cell: Vector2i) -> bool:
	if _bg == null:
		return false
	return _bg.get_cell_source_id(cell) != -1


func can_place(block: BlockData, origin: Vector2i, orientation: int, player: Node2D) -> Dictionary:
	if block == null:
		return {"ok": false, "reason": "unknown_block"}
	if block.occupies_background_layer():
		if _bg == null:
			return {"ok": false, "reason": "no_layer", "cells": [origin]}
		if _bg.get_cell_source_id(origin) != -1:
			return {"ok": false, "reason": "occupied", "cells": [origin]}
		return {"ok": true, "reason": "ok", "cells": [origin], "orientation": orientation}
	if _is_entity_block(block):
		var cells := _footprint_cells(origin, block.footprint)
		for cell in cells:
			if _fg_blocked(cell) or _occupancy.has(cell):
				return {"ok": false, "reason": "occupied", "cells": cells}
		if block.building_part_type == BlockData.BuildingPartType.LIGHT and not _has_wall_support(origin):
			return {"ok": false, "reason": "wall", "cells": cells}
		if _overlaps_player_cells(cells, player, block):
			return {"ok": false, "reason": "player", "cells": cells}
		return {"ok": true, "reason": "ok", "cells": cells}
	var layer := _layer_for(block)
	if layer == null:
		return {"ok": false, "reason": "no_layer"}
	if layer.get_cell_source_id(origin) != -1:
		return {"ok": false, "reason": "occupied", "cells": [origin]}
	if _occupancy.has(origin):
		return {"ok": false, "reason": "occupied", "cells": [origin]}
	if _fg_blocked(origin):
		return {"ok": false, "reason": "occupied", "cells": [origin]}
	return {"ok": true, "reason": "ok", "cells": [origin], "orientation": orientation}


func try_place(block: BlockData, origin: Vector2i, orientation: int, player: Node2D) -> bool:
	var report := can_place(block, origin, orientation, player)
	if not bool(report.get("ok", false)):
		return false
	if _is_entity_block(block):
		_spawn_entity(block, origin, orientation)
		return true
	var placed_ori := orientation
	if StairSystem.is_stair(block):
		placed_ori = StairSystem.resolve_orientation(origin, Callable(self, "get_block_at"), orientation)
	_place_tile(block, origin, placed_ori)
	_refresh_neighbors(origin, block)
	return true


func stamp_backdrop(block: BlockData, cell: Vector2i) -> void:
	if block == null or _bg == null or block_catalog == null:
		return
	var mask := 0
	if block.building_part_type == BlockData.BuildingPartType.ROOF:
		mask = roof_variant(cell, block)
	elif block.connects_visually():
		mask = autotile_mask(cell, block)
	block_catalog.set_block_cell_mask(_bg, cell, block, mask, 0)
	_orientation[cell] = 0
	_placed_bg[cell] = block.id


func stamp_solid(block: BlockData, cell: Vector2i, register_structural: bool = false) -> void:
	if block == null:
		return
	if _is_entity_block(block):
		stamp_blueprint_part(block, cell)
		return
	_place_tile(block, cell, 0, register_structural)
	_refresh_neighbors(cell, block)


func stamp_blueprint_part(block: BlockData, origin: Vector2i) -> void:
	if block == null:
		return
	if _is_entity_block(block):
		if _occupancy.has(origin):
			var existing: BuildingEntity = _occupancy[origin]
			if existing != null and existing.block_id == block.id:
				return
		_spawn_entity(block, origin, 0)
		return
	var layer := _layer_for(block)
	if layer != null and layer.get_cell_source_id(origin) != -1:
		var present := block_catalog.get_cell_block(layer, origin) if block_catalog != null else null
		if present != null and present.id == block.id:
			_refresh_autotile(origin, block)
			return
	_place_tile(block, origin, 0)
	_refresh_neighbors(origin, block)


func try_remove(cell: Vector2i, _mined: bool = true) -> BlockData:
	var buildings := get_tree().get_first_node_in_group(&"building_manager")
	if buildings != null and buildings.has_method("is_protected_cell") and bool(buildings.call("is_protected_cell", cell)):
		return null
	if _occupancy.has(cell):
		var ent: BuildingEntity = _occupancy[cell]
		var block := ent.block_data
		_remove_entity(ent)
		return block
	if _fg != null and _fg.get_cell_source_id(cell) != -1:
		var block := block_catalog.get_cell_block(_fg, cell) if block_catalog != null else null
		if block != null and block.is_building_part():
			_fg.erase_cell(cell)
			_placed_fg.erase(cell)
			_orientation.erase(cell)
			_refresh_neighbors(cell, block)
			if StairSystem.is_stair(block):
				_refresh_nearby_stairs(cell)
			return block
		return null
	if _bg != null and _bg.get_cell_source_id(cell) != -1:
		var block := block_catalog.get_cell_block(_bg, cell) if block_catalog != null else null
		if block != null:
			_bg.erase_cell(cell)
			_placed_bg.erase(cell)
			_refresh_neighbors(cell, block)
			return block
	return null


func autotile_mask(cell: Vector2i, block: BlockData) -> int:
	var mask := 0
	for i in DIRS.size():
		if _same_connect(cell + DIRS[i], block):
			mask |= DIR_BITS[i]
	return mask


func roof_variant(cell: Vector2i, block: BlockData) -> int:
	var left := _same_connect(cell + Vector2i.LEFT, block)
	var right := _same_connect(cell + Vector2i.RIGHT, block)
	var above := _same_connect(cell + Vector2i.UP, block)
	if not left and not right:
		return 5 if not above else 0
	if left and right:
		return 6 if above else 0
	if not left and right:
		return 3 if not above else 1
	if left and not right:
		return 4 if not above else 2
	return 0


func to_save_dict() -> Dictionary:
	var tiles: Array = []
	for key in _placed_fg.keys():
		var cell: Vector2i = key
		tiles.append(_tile_entry(cell, int(_placed_fg[cell]), false))
	for key in _placed_bg.keys():
		var cell: Vector2i = key
		tiles.append(_tile_entry(cell, int(_placed_bg[cell]), true))
	var ents: Array = []
	var seen: Dictionary = {}
	for key in _entities.keys():
		var ent: BuildingEntity = _entities[key]
		if ent == null or seen.has(ent):
			continue
		seen[ent] = true
		ents.append(ent.to_save_dict())
	return {"tiles": tiles, "entities": ents}


func from_save_dict(data: Dictionary) -> void:
	_clear_all()
	for entry in data.get("tiles", []):
		if not (entry is Dictionary):
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var block := block_catalog.get_by_id(int(entry.get("id", -1))) if block_catalog != null else null
		if block == null:
			continue
		var ori := int(entry.get("ori", 0))
		if bool(entry.get("bg", false)):
			_place_tile(block, cell, ori)
		else:
			_place_tile(block, cell, ori)
	for entry in data.get("entities", []):
		if not (entry is Dictionary):
			continue
		var block := block_catalog.get_by_id(int(entry.get("block_id", -1))) if block_catalog != null else null
		if block == null:
			continue
		var origin_arr: Array = entry.get("origin", [0, 0])
		var origin := Vector2i(int(origin_arr[0]), int(origin_arr[1]))
		var ent := _spawn_entity(block, origin, int(entry.get("orientation", 0)))
		if ent != null:
			ent.is_open = bool(entry.get("open", false))
			ent._apply_open_state()
	for key in _placed_fg.keys():
		var cell: Vector2i = key
		var block := block_catalog.get_by_id(int(_placed_fg[cell])) if block_catalog != null else null
		if block != null:
			_apply_visual(cell, block)


func _tile_entry(cell: Vector2i, block_id: int, bg: bool) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y,
		"id": block_id,
		"ori": int(_orientation.get(cell, 0)),
		"bg": bg,
	}


func _place_tile(block: BlockData, cell: Vector2i, orientation: int, register_structural: bool = true) -> void:
	var layer := _layer_for(block)
	if layer == null or block_catalog == null:
		return
	var placed_ori := orientation
	var mask := 0
	if StairSystem.is_stair(block):
		placed_ori = StairSystem.resolve_orientation(cell, Callable(self, "get_block_at"), orientation)
		mask = StairSystem.resolve_visual(cell, placed_ori, Callable(self, "get_block_at"))
	elif block.building_part_type == BlockData.BuildingPartType.ROOF:
		mask = roof_variant(cell, block)
	elif block.connects_visually():
		mask = autotile_mask(cell, block)
	block_catalog.set_block_cell_mask(layer, cell, block, mask, placed_ori)
	_orientation[cell] = placed_ori
	if block.occupies_background_layer():
		_placed_bg[cell] = block.id
	else:
		_placed_fg[cell] = block.id
		if not register_structural:
			return
		var structural := get_tree().get_first_node_in_group(&"structural_manager")
		if structural != null and block.structural_enabled:
			structural.call("notify_block_placed", cell)


func _refresh_autotile(cell: Vector2i, block: BlockData) -> void:
	_apply_visual(cell, block)
	_refresh_neighbors(cell, block)


func _refresh_neighbors(cell: Vector2i, block: BlockData) -> void:
	for dir in DIRS:
		var n: Vector2i = cell + dir
		var nb := _block_on_same_layer(n, block)
		if nb != null:
			_apply_visual(n, nb)
	_refresh_nearby_stairs(cell)


func _apply_visual(cell: Vector2i, block: BlockData) -> void:
	var layer := _layer_for(block)
	if layer == null or layer.get_cell_source_id(cell) == -1:
		return
	var ori := int(_orientation.get(cell, 0))
	var mask := 0
	if StairSystem.is_stair(block):
		ori = StairSystem.resolve_orientation(cell, Callable(self, "get_block_at"), ori)
		_orientation[cell] = ori
		mask = StairSystem.resolve_visual(cell, ori, Callable(self, "get_block_at"))
	elif block.building_part_type == BlockData.BuildingPartType.ROOF:
		mask = roof_variant(cell, block)
	elif block.connects_visually():
		mask = autotile_mask(cell, block)
	block_catalog.set_block_cell_mask(layer, cell, block, mask, ori)


func _same_connect(cell: Vector2i, block: BlockData) -> bool:
	var other := _block_on_same_layer(cell, block)
	if other == null:
		return false
	if other.id == block.id:
		return true
	return other.building_part_type == block.building_part_type \
		and other.building_material == block.building_material \
		and other.material_variant == block.material_variant


func _block_on_same_layer(cell: Vector2i, block: BlockData) -> BlockData:
	var layer := _layer_for(block)
	if layer == null or block_catalog == null:
		return null
	return block_catalog.get_cell_block(layer, cell)


func _layer_for(block: BlockData) -> TileMapLayer:
	if block != null and block.occupies_background_layer():
		return _bg
	return _fg


func _fg_blocked(cell: Vector2i) -> bool:
	if _fg == null:
		return false
	return _fg.get_cell_source_id(cell) != -1


func _is_entity_block(block: BlockData) -> bool:
	if block == null:
		return false
	if block.footprint.x > 1 or block.footprint.y > 1:
		return true
	return block.building_part_type in ENTITY_TYPES


func _footprint_cells(origin: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var fp := footprint if footprint != Vector2i.ZERO else Vector2i.ONE
	var cells: Array[Vector2i] = []
	for y in fp.y:
		for x in fp.x:
			cells.append(origin + Vector2i(x, y - (fp.y - 1)))
	return cells


func _spawn_entity(block: BlockData, origin: Vector2i, orientation: int) -> BuildingEntity:
	var ent := BuildingEntity.new()
	add_child(ent)
	ent.setup(block, origin, orientation, TILE_SIZE)
	if _fg != null:
		var bottom := origin
		ent.global_position = _fg.to_global(_fg.map_to_local(bottom)) + Vector2(0, float(TILE_SIZE) * 0.5)
	ent.entity_removed.connect(_on_entity_removed)
	_entities[origin] = ent
	for cell in ent.occupied_cells():
		_occupancy[cell] = ent
	return ent


func _remove_entity(ent: BuildingEntity) -> void:
	if ent == null:
		return
	for cell in ent.occupied_cells():
		_occupancy.erase(cell)
	_entities.erase(ent.origin)
	ent.queue_free()


func _on_entity_removed(ent: BuildingEntity) -> void:
	_remove_entity(ent)


func _has_wall_support(cell: Vector2i) -> bool:
	for dir in DIRS:
		var n: Vector2i = cell + dir
		var block := get_block_at(n)
		if block == null:
			continue
		if block.building_part_type in [
			BlockData.BuildingPartType.WALL,
			BlockData.BuildingPartType.BACKGROUND_WALL,
			BlockData.BuildingPartType.FOUNDATION,
		]:
			return true
		if block.solid:
			return true
	return false


func _overlaps_player_cells(cells: Array[Vector2i], player: Node2D, block: BlockData) -> bool:
	if player == null or _fg == null:
		return false
	if block != null and not block.solid and not _is_entity_block(block):
		return false
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return false
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return false
	var player_rect := Rect2(collision.global_position - rect_shape.size * 0.5, rect_shape.size).grow(1.0)
	for cell in cells:
		var center := _fg.to_global(_fg.map_to_local(cell))
		var tile_rect := Rect2(center - Vector2(TILE_SIZE, TILE_SIZE) * 0.5, Vector2(TILE_SIZE, TILE_SIZE))
		if player_rect.intersects(tile_rect):
			return true
	return false


func _clear_all() -> void:
	for key in _entities.keys():
		var ent: BuildingEntity = _entities[key]
		if ent != null:
			ent.queue_free()
	_entities.clear()
	_occupancy.clear()
	for key in _placed_fg.keys():
		var cell: Vector2i = key
		if _fg != null:
			_fg.erase_cell(cell)
	for key in _placed_bg.keys():
		var cell: Vector2i = key
		if _bg != null:
			_bg.erase_cell(cell)
	_placed_fg.clear()
	_placed_bg.clear()
	_orientation.clear()


func _flatten_dev_build_plot() -> void:
	var world := get_parent() as WorldGenerator
	if world == null or _fg == null:
		return
	var origin_x := world.spawn_tile.x - 36
	var width := 22
	for x in range(origin_x, origin_x + width):
		var gy := world.get_surface_y(x)
		for y in range(gy - 10, gy):
			var cell := Vector2i(x, y)
			if _fg.get_cell_source_id(cell) == -1:
				continue
			var existing := block_catalog.get_cell_block(_fg, cell) if block_catalog != null else null
			if existing != null and existing.structural_enabled:
				continue
			if existing != null and existing.id >= 13 and existing.id <= 22:
				continue
			_fg.erase_cell(cell)


func get_stair_orientation(cell: Vector2i) -> int:
	return int(_orientation.get(cell, 0))


func resolve_stair_orientation(cell: Vector2i, hint: int) -> int:
	return StairSystem.resolve_orientation(cell, Callable(self, "get_block_at"), hint)


func _refresh_stair_cell(cell: Vector2i) -> void:
	var block := get_block_at(cell)
	if StairSystem.is_stair(block):
		_apply_visual(cell, block)
	_refresh_nearby_stairs(cell)


func _refresh_nearby_stairs(cell: Vector2i) -> void:
	for dir in StairSystem.NEIGHBOR_DIRS:
		var n: Vector2i = cell + dir
		var nb := get_block_at(n)
		if StairSystem.is_stair(nb):
			_apply_visual(n, nb)


func set_stair_preview(cells: Array[Vector2i], valid: Array[bool], grades: Array[int]) -> void:
	if _stair_preview != null and _stair_preview.has_method("show_cells"):
		_stair_preview.call("show_cells", cells, valid, grades, _fg)


func clear_stair_preview() -> void:
	if _stair_preview != null and _stair_preview.has_method("clear_preview"):
		_stair_preview.call("clear_preview")
