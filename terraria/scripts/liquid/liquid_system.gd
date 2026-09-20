class_name LiquidSystem
extends Node2D

## Tile-basiertes Flüssigkeitssystem für Last Lantern.
## Simulation arbeitet nur auf ACTIVE/QUEUED Zellen; Rendering ist sparse.

signal liquid_changed(cell: Vector2i)
signal simulation_toggled(enabled: bool)

const GROUP := &"liquid_system"

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const DISPLACE_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
]

@export var settings: LiquidSettings
@export var tile_size: int = 16

var world_width: int = 0
var world_height: int = 0
var debug_stats: Dictionary = {}

var _amounts: PackedByteArray = PackedByteArray()
var _types: PackedByteArray = PackedByteArray()
var _water_cells: Dictionary = {}
var _active: Dictionary = {}
var _queued: Dictionary = {}
var _queue: Array[Vector2i] = []
var _queue_read: int = 0
var _stable_ticks: Dictionary = {}
var _sim_accum: float = 0.0
var _sim_enabled: bool = true
var _debug_infinite_breath: bool = false
var _dirty_render: Dictionary = {}
var _simulating: bool = false
var _batch_writes: bool = false
var _current_budget: int = 800

var _tilemap: TileMapLayer
var _block_catalog: BlockCatalog
var _building_parts: BuildingPartSystem
var _renderer: LiquidRenderer
var _world_gen: WorldGenerator

var _baseline: Dictionary = {}
var _has_baseline: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if settings == null:
		settings = load("res://resources/systems/liquid_settings.tres") as LiquidSettings
	_current_budget = settings.max_updates_per_tick if settings != null else 800
	_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_block_catalog = _find_block_catalog()
	_building_parts = get_tree().get_first_node_in_group("building_part_system") as BuildingPartSystem
	_world_gen = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	_renderer = get_node_or_null("LiquidRenderer") as LiquidRenderer
	if _renderer != null:
		_renderer.setup(self)


func _process(delta: float) -> void:
	if not _sim_enabled or settings == null or _amounts.is_empty():
		return
	_update_adaptive_budget(delta)
	_sim_accum += delta
	var tick_dt := 1.0 / maxf(settings.simulation_rate, 1.0)
	while _sim_accum >= tick_dt:
		_sim_accum -= tick_dt
		_simulation_tick()


func initialize(width: int, height: int) -> void:
	world_width = width
	world_height = height
	var total := width * height
	_amounts = PackedByteArray()
	_amounts.resize(total)
	_types = PackedByteArray()
	_types.resize(total)
	_reset_runtime_state()


func bind_world_generator(world_gen: WorldGenerator) -> void:
	_world_gen = world_gen
	if world_gen != null:
		world_width = world_gen.world_width
		world_height = world_gen.world_height
		if _amounts.is_empty():
			initialize(world_width, world_height)


func get_amount(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return LiquidTypes.EMPTY
	return _amounts[_index(cell)]


func get_type(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return LiquidTypes.Type.NONE
	return _types[_index(cell)]


func has_water(cell: Vector2i) -> bool:
	return _water_cells.has(cell)


func get_water_cell_count() -> int:
	return _water_cells.size()


func get_water_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_water_cells.keys())
	return cells


func begin_batch_writes() -> void:
	_batch_writes = true


func end_batch_writes() -> void:
	_batch_writes = false
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func get_sleeping_cell_count() -> int:
	return maxi(_water_cells.size() - _active.size(), 0)


func get_queue_size() -> int:
	return maxi(_queue.size() - _queue_read, 0)


func get_debug_stats() -> Dictionary:
	return debug_stats.duplicate()


func set_cell(cell: Vector2i, liquid_type: int, amount: int, activate: bool = true) -> void:
	if not _in_bounds(cell):
		return
	_write_amount(cell, amount, liquid_type)
	if activate and amount > settings.settle_threshold:
		_enqueue(cell)
	liquid_changed.emit(cell)
	_dirty_render[cell] = true
	if not _simulating and not _batch_writes and _renderer != null:
		_renderer.apply_dirty(_dirty_render)
		_dirty_render.clear()


func add_water(cell: Vector2i, amount: int) -> void:
	set_cell(cell, LiquidTypes.Type.WATER, get_amount(cell) + amount)


func remove_water(cell: Vector2i) -> void:
	set_cell(cell, LiquidTypes.Type.NONE, LiquidTypes.EMPTY, false)


func water_surface_y(cell: Vector2i) -> float:
	var amount := get_amount(cell)
	if amount <= 0:
		return INF
	var tile_top := float(cell.y * tile_size)
	var tile_bottom := tile_top + float(tile_size)
	return tile_bottom - (float(amount) / float(LiquidTypes.FULL)) * float(tile_size)


func sample_depth_at_world(world_pos: Vector2) -> float:
	var cell := world_to_cell(world_pos)
	var amount := get_amount(cell)
	if amount <= 0:
		return 0.0
	var surface_y := water_surface_y(cell)
	if world_pos.y <= surface_y:
		return 0.0
	var depth := world_pos.y - surface_y
	return clampf(depth / float(tile_size), 0.0, 1.0)


func sample_submersion(body_pos: Vector2, head_offset_y: float, _body_offset_y: float) -> Dictionary:
	var feet_depth := sample_depth_at_world(body_pos)
	var body_depth := sample_depth_at_world(body_pos + Vector2(0.0, head_offset_y * 0.5))
	var head_depth := sample_depth_at_world(body_pos + Vector2(0.0, head_offset_y))
	var in_water := feet_depth > settings.feet_depth_threshold
	return {
		"feet_depth": feet_depth,
		"body_depth": body_depth,
		"head_depth": head_depth,
		"in_water": in_water,
		"waist_in_water": body_depth >= settings.waist_depth_threshold,
		"swimming": body_depth >= settings.swim_depth_threshold,
		"head_submerged": head_depth >= settings.head_submerge_threshold,
		"shallow": in_water and body_depth < settings.swim_depth_threshold,
		"deep": body_depth >= settings.swim_depth_threshold,
	}


func is_cell_active(cell: Vector2i) -> bool:
	return _active.has(cell)


func is_cell_solid(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return true
	if _building_parts != null:
		var part := _building_parts.get_block_at(cell)
		if part != null and part.solid:
			return true
	if _tilemap != null and _block_catalog != null:
		var block := _block_catalog.get_cell_block(_tilemap, cell)
		if block != null and block.solid:
			return true
	return false


func can_hold_liquid(cell: Vector2i) -> bool:
	return _in_bounds(cell) and not is_cell_solid(cell)


func on_block_changed(cell: Vector2i) -> void:
	if is_cell_solid(cell):
		_remove_at(cell)
	else:
		_enqueue(cell + Vector2i(0, -1))
	for offset in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if has_water(neighbor):
			_enqueue(neighbor)
	if has_water(cell):
		_enqueue(cell)


func on_block_removed(cell: Vector2i) -> void:
	on_block_changed(cell)


func on_block_placed(cell: Vector2i) -> void:
	if is_cell_solid(cell):
		_displace_water(cell)
	on_block_changed(cell)


func displace_for_placement(cell: Vector2i) -> bool:
	if not has_water(cell):
		return true
	return _displace_water(cell)


func stabilize(max_steps: int = 2000) -> void:
	var steps := 0
	while steps < max_steps and (_active.size() > 0 or get_queue_size() > 0):
		_simulation_tick()
		steps += 1
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func capture_baseline() -> void:
	_baseline.clear()
	for cell in _water_cells.keys():
		_baseline[_cell_key(cell)] = get_amount(cell)
	_has_baseline = true


func finalize_generation() -> void:
	_rebuild_water_cells()
	capture_baseline()
	_reset_simulation_state()
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func set_simulation_enabled(enabled: bool) -> void:
	_sim_enabled = enabled
	simulation_toggled.emit(enabled)


func is_simulation_enabled() -> bool:
	return _sim_enabled


func get_active_cell_count() -> int:
	return _active.size()


func debug_fill_area(origin: Vector2i, size: Vector2i, amount: int = LiquidTypes.FULL) -> void:
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			var cell := Vector2i(x, y)
			if can_hold_liquid(cell):
				set_cell(cell, LiquidTypes.Type.WATER, amount)


func debug_clear_area(origin: Vector2i, size: Vector2i) -> void:
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			remove_water(Vector2i(x, y))


func debug_toggle_active_overlay() -> void:
	if settings != null:
		settings.debug_show_active_cells = not settings.debug_show_active_cells
	if _renderer != null:
		_renderer.queue_redraw()


func debug_toggle_amount_overlay() -> void:
	if settings != null:
		settings.debug_show_amounts = not settings.debug_show_amounts
	if _renderer != null:
		_renderer.queue_redraw()


func debug_run_falling_water_test(x: int, y: int, gap_height: int = 10) -> void:
	debug_clear_area(Vector2i(x - 1, y - 1), Vector2i(3, gap_height + 3))
	set_cell(Vector2i(x, y), LiquidTypes.Type.WATER, LiquidTypes.FULL)


func set_debug_infinite_breath(enabled: bool) -> void:
	_debug_infinite_breath = enabled


func is_debug_infinite_breath() -> bool:
	return _debug_infinite_breath


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / float(tile_size)),
		floori(world_pos.y / float(tile_size)),
	)


func to_save_dict() -> Dictionary:
	var cells: Dictionary = {}
	for cell in _water_cells.keys():
		var amount := get_amount(cell)
		var key := _cell_key(cell)
		if _has_baseline and int(_baseline.get(key, -1)) == amount:
			continue
		cells[key] = amount
	return {
		"width": world_width,
		"height": world_height,
		"cells": cells,
	}


func from_save_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	var width := int(data.get("width", world_width))
	var height := int(data.get("height", world_height))
	if _amounts.is_empty() or width != world_width or height != world_height:
		initialize(width, height)
	var cells: Dictionary = data.get("cells", {})
	for key in cells.keys():
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2:
			continue
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		set_cell(cell, LiquidTypes.Type.WATER, int(cells[key]), false)
	_reset_simulation_state()
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func _simulation_tick() -> void:
	var start_usec := Time.get_ticks_usec()
	_simulating = true
	_dirty_render.clear()
	_ensure_queue_has_work()
	var batch: Array[Vector2i] = []
	var processed := 0
	while processed < _current_budget and _queue_read < _queue.size():
		var cell: Vector2i = _queue[_queue_read]
		_queue_read += 1
		_queued.erase(cell)
		if not _active.has(cell):
			continue
		batch.append(cell)
		processed += 1
	batch.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y
	)
	for cell in batch:
		_process_cell(cell)
	_compact_queue()
	_simulating = false
	if _renderer != null and not _dirty_render.is_empty():
		_renderer.apply_dirty(_dirty_render)
	_record_debug_stats(start_usec, processed)


func _process_cell(cell: Vector2i) -> void:
	if not can_hold_liquid(cell):
		_remove_at(cell)
		return
	var amount := _read_amount(cell)
	if amount <= settings.settle_threshold:
		_remove_at(cell)
		return
	var current := cell
	var moved_vertically := false
	for _step in settings.max_vertical_steps_per_cell:
		amount = _read_amount(current)
		if amount <= settings.settle_threshold:
			break
		if not _flow_down_once(current):
			break
		moved_vertically = true
		if _read_amount(current) > settings.settle_threshold:
			break
		current = current + Vector2i(0, 1)
	var horizontal := false
	if _read_amount(cell) > settings.settle_threshold:
		horizontal = _flow_horizontal(cell)
	if not moved_vertically and not horizontal:
		_try_sleep(cell)


func _flow_down_once(cell: Vector2i) -> bool:
	var below := cell + Vector2i(0, 1)
	if not can_hold_liquid(below):
		return false
	var amount := _read_amount(cell)
	var below_amount := _read_amount(below)
	var space := LiquidTypes.FULL - below_amount
	if space <= 0:
		return false
	var flow := amount
	if below_amount > 0:
		flow = mini(flow, settings.vertical_flow_rate)
	flow = mini(flow, space)
	if flow < settings.settle_threshold:
		return false
	_transfer_internal(cell, below, flow)
	return true


func _flow_horizontal(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	var changed := false
	for direction in [-1, 1]:
		var neighbor := cell + Vector2i(direction, 0)
		if not can_hold_liquid(neighbor):
			continue
		var n_amount := _read_amount(neighbor)
		if amount <= n_amount + settings.equalize_min_diff:
			continue
		var diff := amount - n_amount
		var flow := mini(diff >> 1, settings.horizontal_flow_rate)
		if flow < settings.settle_threshold:
			continue
		_transfer_internal(cell, neighbor, flow)
		changed = true
		amount = _read_amount(cell)
	return changed


func _transfer_internal(from: Vector2i, to: Vector2i, amount: int) -> void:
	if amount <= 0:
		return
	var moved := mini(amount, _read_amount(from))
	if moved <= 0:
		return
	var to_amount := _read_amount(to)
	_write_amount(from, _read_amount(from) - moved, LiquidTypes.Type.WATER)
	_write_amount(to, to_amount + moved, LiquidTypes.Type.WATER)
	_enqueue(to)
	if _read_amount(from) > settings.settle_threshold:
		_enqueue(from)


func _is_stable(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	if amount <= settings.settle_threshold:
		return true
	var below := cell + Vector2i(0, 1)
	if can_hold_liquid(below) and _read_amount(below) < LiquidTypes.FULL:
		return false
	for direction in [-1, 1]:
		var neighbor := cell + Vector2i(direction, 0)
		if not can_hold_liquid(neighbor):
			continue
		if amount > _read_amount(neighbor) + settings.equalize_min_diff:
			return false
	return true


func _try_sleep(cell: Vector2i) -> void:
	if not _is_stable(cell):
		_stable_ticks.erase(cell)
		return
	var ticks := int(_stable_ticks.get(cell, 0)) + 1
	_stable_ticks[cell] = ticks
	if ticks >= settings.sleep_after_stable_ticks:
		_deactivate(cell)


func _displace_water(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	if amount <= 0:
		return true
	var remaining := amount
	var targets: Array[Vector2i] = []
	for offset in DISPLACE_OFFSETS:
		var target: Vector2i = cell + offset
		if can_hold_liquid(target):
			targets.append(target)
	if targets.is_empty():
		return false
	var per_target := ceili(float(remaining) / float(targets.size()))
	for target in targets:
		var space := LiquidTypes.FULL - _read_amount(target)
		var moved := mini(per_target, mini(space, remaining))
		if moved > 0:
			_write_amount(target, _read_amount(target) + moved, LiquidTypes.Type.WATER)
			_enqueue(target)
			remaining -= moved
	_remove_at(cell)
	return remaining <= 0


func _write_amount(cell: Vector2i, amount: int, liquid_type: int) -> void:
	if not _in_bounds(cell):
		return
	var idx := _index(cell)
	var clamped := clampi(amount, LiquidTypes.EMPTY, LiquidTypes.FULL)
	if clamped <= settings.settle_threshold:
		_amounts[idx] = 0
		_types[idx] = LiquidTypes.Type.NONE
		_water_cells.erase(cell)
		_deactivate(cell)
	else:
		_amounts[idx] = clamped
		_types[idx] = liquid_type
		_water_cells[cell] = true
	_dirty_render[cell] = true


func _remove_at(cell: Vector2i) -> void:
	_write_amount(cell, 0, LiquidTypes.Type.NONE)


func _read_amount(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return 0
	return _amounts[_index(cell)]


func _enqueue(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	_active[cell] = true
	_stable_ticks.erase(cell)
	if _queued.has(cell):
		return
	_queued[cell] = true
	_queue.append(cell)


func _deactivate(cell: Vector2i) -> void:
	_active.erase(cell)
	_stable_ticks.erase(cell)


func _ensure_queue_has_work() -> void:
	if _queue_read < _queue.size():
		return
	if _active.is_empty():
		return
	_queue_read = 0
	_queue.clear()
	_queued.clear()
	for cell in _active.keys():
		_enqueue(cell)


func _compact_queue() -> void:
	if _queue_read < 64:
		return
	if _queue_read <= _queue.size() / 2:
		return
	_queue = _queue.slice(_queue_read)
	_queue_read = 0


func _reset_runtime_state() -> void:
	_water_cells.clear()
	_reset_simulation_state()
	_baseline.clear()
	_has_baseline = false


func _reset_simulation_state() -> void:
	_active.clear()
	_queued.clear()
	_queue.clear()
	_queue_read = 0
	_stable_ticks.clear()
	_dirty_render.clear()


func _rebuild_water_cells() -> void:
	_water_cells.clear()
	for y in world_height:
		for x in world_width:
			var cell := Vector2i(x, y)
			if _read_amount(cell) > settings.settle_threshold:
				_water_cells[cell] = true


func _update_adaptive_budget(delta: float) -> void:
	if settings == null or not settings.adaptive_budget:
		_current_budget = settings.max_updates_per_tick
		return
	var frame_ms := delta * 1000.0
	if frame_ms > 20.0:
		_current_budget = maxi(settings.max_updates_per_tick_min, _current_budget - 50)
	elif frame_ms < 12.0:
		_current_budget = mini(settings.max_updates_per_tick_max, _current_budget + 25)
	else:
		_current_budget = settings.max_updates_per_tick


func _record_debug_stats(start_usec: int, processed: int) -> void:
	debug_stats = {
		"active_cells": _active.size(),
		"sleeping_cells": get_sleeping_cell_count(),
		"water_cells": _water_cells.size(),
		"queue_size": get_queue_size(),
		"updates_last_tick": processed,
		"update_budget": _current_budget,
		"simulation_ms": (Time.get_ticks_usec() - start_usec) / 1000.0,
		"simulation_hz": settings.simulation_rate,
		"dirty_cells_last_tick": _dirty_render.size(),
	}


func _index(cell: Vector2i) -> int:
	return cell.y * world_width + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < world_width and cell.y >= 0 and cell.y < world_height


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _find_block_catalog() -> BlockCatalog:
	if _world_gen != null and _world_gen.block_catalog != null:
		return _world_gen.block_catalog
	return load("res://resources/blocks/block_catalog.tres") as BlockCatalog
