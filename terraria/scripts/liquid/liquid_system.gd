class_name LiquidSystem
extends Node2D

## Tile-basiertes Flüssigkeitssystem für Last Lantern.
## Simulation arbeitet nur auf ACTIVE/QUEUED Zellen; Rendering ist sparse.
## Massenerhaltung: Transfers ziehen Quellmenge ab und wecken Nachbarn inkl. ABOVE.

signal liquid_changed(cell: Vector2i)
signal simulation_toggled(enabled: bool)

const GROUP := &"liquid_system"
const DIRTY_CHUNK_SHIFT := 4
const INVALID_CELL := Vector2i(-1, -1)

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
var _liquid_cells: Dictionary = {}
var _active: Dictionary = {}
var _reacted_this_tick: Dictionary = {}
var _queued: Dictionary = {}
var _queue: Array[Vector2i] = []
var _queue_read: int = 0
var _stable_ticks: Dictionary = {}
var _sim_accum: float = 0.0
var _sim_enabled: bool = true
var _debug_infinite_breath: bool = false
var _debug_mass_tracking: bool = false
var _dirty_render: Dictionary = {}
var _simulating: bool = false
var _batch_writes: bool = false
var _current_budget: int = 800
var _forced_solids: Dictionary = {}

var _tilemap: TileMapLayer
var _block_catalog: BlockCatalog
var _building_parts: Node
var _renderer: LiquidRenderer
var _world_gen: Node

var _baseline: Dictionary = {}
var _has_baseline: bool = false
var _water_count: int = 0
var _lava_count: int = 0
var last_ticks_this_frame: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	if settings == null:
		settings = load("res://resources/systems/liquid_settings.tres") as LiquidSettings
	_current_budget = settings.max_updates_per_tick if settings != null else 800
	_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_block_catalog = _find_block_catalog()
	_building_parts = get_tree().get_first_node_in_group("building_part_system")
	_world_gen = get_tree().get_first_node_in_group("world_generator")
	_renderer = get_node_or_null("LiquidRenderer") as LiquidRenderer
	if _renderer != null:
		_renderer.setup(self)


func _process(delta: float) -> void:
	if not _sim_enabled or settings == null or _amounts.is_empty():
		last_ticks_this_frame = 0
		return
	_update_adaptive_budget(delta)
	_sim_accum += delta
	var tick_dt := 1.0 / maxf(settings.simulation_rate, 1.0)
	var max_ticks := 2
	if settings != null:
		var tick_value: Variant = settings.get("max_simulation_ticks_per_frame")
		if tick_value != null:
			max_ticks = maxi(int(tick_value), 1)
	var ticks := 0
	while _sim_accum >= tick_dt and ticks < max_ticks:
		_sim_accum -= tick_dt
		_simulation_tick()
		ticks += 1
	if ticks >= max_ticks and _sim_accum > tick_dt * 3.0:
		_sim_accum = tick_dt
	last_ticks_this_frame = ticks


func initialize(width: int, height: int) -> void:
	world_width = width
	world_height = height
	var total := width * height
	_amounts = PackedByteArray()
	_amounts.resize(total)
	_types = PackedByteArray()
	_types.resize(total)
	_water_count = 0
	_lava_count = 0
	_reset_runtime_state()


func bind_world_generator(world_gen: Node) -> void:
	_world_gen = world_gen
	if world_gen != null and "world_width" in world_gen:
		world_width = int(world_gen.get("world_width"))
		world_height = int(world_gen.get("world_height"))
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


func has_liquid(cell: Vector2i) -> bool:
	return _liquid_cells.has(cell)


func has_water(cell: Vector2i) -> bool:
	return get_type(cell) == LiquidTypes.Type.WATER and get_amount(cell) > 0


func has_lava(cell: Vector2i) -> bool:
	return get_type(cell) == LiquidTypes.Type.LAVA and get_amount(cell) > 0


func get_liquid_cell_count() -> int:
	return _liquid_cells.size()


func get_water_cell_count() -> int:
	return _water_count


func get_lava_cell_count() -> int:
	return _lava_count


func has_active_in_rect(origin: Vector2i, size: Vector2i) -> bool:
	if _active.is_empty() or size.x <= 0 or size.y <= 0:
		return false
	var x1 := origin.x
	var y1 := origin.y
	var x2 := origin.x + size.x
	var y2 := origin.y + size.y
	for key in _active.keys():
		var cell: Vector2i = key
		if cell.x >= x1 and cell.y >= y1 and cell.x < x2 and cell.y < y2:
			return true
	return false


func get_liquid_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_liquid_cells.keys())
	return cells


func get_water_cells() -> Array[Vector2i]:
	return _cells_of_type(LiquidTypes.Type.WATER)


func get_lava_cells() -> Array[Vector2i]:
	return _cells_of_type(LiquidTypes.Type.LAVA)


func begin_batch_writes() -> void:
	_batch_writes = true


func end_batch_writes() -> void:
	_batch_writes = false
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func get_sleeping_cell_count() -> int:
	return maxi(_liquid_cells.size() - _active.size(), 0)


func get_queue_size() -> int:
	return maxi(_queue.size() - _queue_read, 0)


func get_debug_stats() -> Dictionary:
	return debug_stats.duplicate()


func get_total_water_amount() -> int:
	return _total_amount_of_type(LiquidTypes.Type.WATER)


func get_total_lava_amount() -> int:
	return _total_amount_of_type(LiquidTypes.Type.LAVA)


func quantized_fill_height(amount: int) -> int:
	if amount <= 0:
		return 0
	var h := int(round(float(amount) * float(tile_size) / float(LiquidTypes.FULL)))
	return clampi(h, 1, tile_size)


func is_surface_cell(cell: Vector2i) -> bool:
	if get_amount(cell) <= 0:
		return false
	var above := cell + Vector2i(0, -1)
	if get_type(above) == get_type(cell) and get_amount(above) > _surface_threshold():
		return false
	return get_amount(above) <= _surface_threshold()


func is_falling_cell(cell: Vector2i) -> bool:
	var below := cell + Vector2i(0, 1)
	if not can_hold_liquid(below):
		return false
	return get_amount(below) <= _surface_threshold()


func set_cell(cell: Vector2i, liquid_type: int, amount: int, activate: bool = true) -> void:
	if not _in_bounds(cell):
		return
	_write_amount(cell, amount, liquid_type)
	if activate:
		_wake_cell_and_neighbors(cell)
	liquid_changed.emit(cell)
	_flush_dirty_render()


func add_water(cell: Vector2i, amount: int) -> void:
	set_cell(cell, LiquidTypes.Type.WATER, get_amount(cell) + amount)


func add_lava(cell: Vector2i, amount: int) -> void:
	set_cell(cell, LiquidTypes.Type.LAVA, get_amount(cell) + amount)


func remove_water(cell: Vector2i) -> void:
	set_cell(cell, LiquidTypes.Type.NONE, LiquidTypes.EMPTY, true)


func remove_liquid(cell: Vector2i) -> void:
	remove_water(cell)


func water_surface_y(cell: Vector2i) -> float:
	var amount := get_amount(cell)
	if amount <= 0:
		return INF
	var tile_top := float(cell.y * tile_size)
	var tile_bottom := tile_top + float(tile_size)
	return tile_bottom - float(quantized_fill_height(amount))


func sample_depth_at_world(world_pos: Vector2) -> float:
	return submerged_depth_at_world(world_pos)


func submerged_depth_at_world(world_pos: Vector2, liquid_type: int = LiquidTypes.Type.WATER) -> float:
	var column_x := world_to_cell(world_pos).x
	var start_y := world_to_cell(world_pos).y
	var best := 0.0
	for y in range(start_y, maxi(start_y - 24, -1), -1):
		var check := Vector2i(column_x, y)
		if get_type(check) != liquid_type or get_amount(check) <= 0:
			continue
		var surface_y := water_surface_y(check)
		if world_pos.y <= surface_y + 0.5:
			continue
		var depth := (world_pos.y - surface_y) / float(tile_size)
		best = maxf(best, depth)
	return best


func sample_submersion(body_pos: Vector2, head_offset_y: float, _body_offset_y: float, liquid_type: int = LiquidTypes.Type.WATER) -> Dictionary:
	var feet_depth := submerged_depth_at_world(body_pos, liquid_type)
	var body_depth := submerged_depth_at_world(body_pos + Vector2(0.0, head_offset_y * 0.5), liquid_type)
	var head_depth := submerged_depth_at_world(body_pos + Vector2(0.0, head_offset_y), liquid_type)
	var immersed := feet_depth > settings.feet_depth_threshold \
		or body_depth > settings.feet_depth_threshold \
		or head_depth > settings.feet_depth_threshold
	var waist_in := body_depth >= settings.waist_depth_threshold
	var swimming := body_depth >= settings.swim_depth_threshold or waist_in
	return {
		"feet_depth": feet_depth,
		"body_depth": body_depth,
		"head_depth": head_depth,
		"in_water": immersed if liquid_type == LiquidTypes.Type.WATER else false,
		"in_lava": immersed if liquid_type == LiquidTypes.Type.LAVA else false,
		"waist_in_water": waist_in if liquid_type == LiquidTypes.Type.WATER else false,
		"swimming": swimming,
		"head_submerged": head_depth >= settings.head_submerge_threshold,
		"shallow": immersed and not swimming,
		"deep": swimming,
		"liquid_type": liquid_type,
	}


func is_cell_active(cell: Vector2i) -> bool:
	return _active.has(cell)


func is_cell_solid(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return true
	if _forced_solids.has(cell):
		return bool(_forced_solids[cell])
	if _building_parts != null and _building_parts.has_method("get_block_at"):
		var part: Variant = _building_parts.call("get_block_at", cell)
		if part != null and bool(part.get("solid")):
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
	_wake_cell_and_neighbors(cell)
	_flush_dirty_render()


func on_block_removed(cell: Vector2i) -> void:
	on_block_changed(cell)


func on_block_placed(cell: Vector2i) -> void:
	if is_cell_solid(cell):
		_displace_liquid(cell)
	on_block_changed(cell)


func displace_for_placement(cell: Vector2i) -> bool:
	if not has_liquid(cell):
		return true
	return _displace_liquid(cell)


func stabilize(max_steps: int = 2000) -> void:
	var steps := 0
	while steps < max_steps and (_active.size() > 0 or get_queue_size() > 0):
		_simulation_tick()
		steps += 1
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func capture_baseline() -> void:
	_baseline.clear()
	for cell in _liquid_cells.keys():
		_baseline[_cell_key(cell)] = _pack_cell(get_amount(cell), get_type(cell))
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


func debug_fill_area(origin: Vector2i, size: Vector2i, amount: int = LiquidTypes.FULL, liquid_type: int = LiquidTypes.Type.WATER) -> void:
	begin_batch_writes()
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			var cell := Vector2i(x, y)
			if can_hold_liquid(cell):
				set_cell(cell, liquid_type, amount)
	end_batch_writes()


func debug_fill_lava(origin: Vector2i, size: Vector2i, amount: int = LiquidTypes.FULL) -> void:
	debug_fill_area(origin, size, amount, LiquidTypes.Type.LAVA)


func debug_clear_area(origin: Vector2i, size: Vector2i) -> void:
	begin_batch_writes()
	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			remove_water(Vector2i(x, y))
	end_batch_writes()


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


func debug_toggle_mass_tracking() -> void:
	_debug_mass_tracking = not _debug_mass_tracking
	if _debug_mass_tracking:
		debug_stats["total_water"] = get_total_water_amount()
		debug_stats["mass_delta"] = 0
		debug_stats["mass_error"] = false


func is_debug_mass_tracking() -> bool:
	return _debug_mass_tracking


func debug_set_solid(cell: Vector2i, solid: bool) -> void:
	if solid:
		_forced_solids[cell] = true
		if has_liquid(cell):
			_remove_at(cell)
	else:
		_forced_solids.erase(cell)
	_wake_cell_and_neighbors(cell)


func debug_clear_solids() -> void:
	_forced_solids.clear()


func debug_run_falling_water_test(x: int, y: int, gap_height: int = 10) -> void:
	debug_clear_area(Vector2i(x - 1, y - 1), Vector2i(3, gap_height + 3))
	set_cell(Vector2i(x, y), LiquidTypes.Type.WATER, LiquidTypes.FULL)


func debug_run_falling_lava_test(x: int, y: int, gap_height: int = 10) -> void:
	debug_clear_area(Vector2i(x - 1, y - 1), Vector2i(3, gap_height + 3))
	set_cell(Vector2i(x, y), LiquidTypes.Type.LAVA, LiquidTypes.FULL)


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
	for cell in _liquid_cells.keys():
		var amount := get_amount(cell)
		var liquid_type := get_type(cell)
		var key := _cell_key(cell)
		if _has_baseline and int(_baseline.get(key, -1)) == _pack_cell(amount, liquid_type):
			continue
		cells[key] = _save_cell_value(amount, liquid_type)
	if _has_baseline:
		for key in _baseline.keys():
			if cells.has(key):
				continue
			var cell := _parse_cell_key(String(key))
			if cell == INVALID_CELL:
				continue
			var packed := int(_baseline[key])
			if _pack_cell(get_amount(cell), get_type(cell)) != packed:
				cells[key] = _save_cell_value(get_amount(cell), get_type(cell))
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
	begin_batch_writes()
	if _has_baseline:
		_restore_baseline_liquid()
	else:
		_clear_all_liquid()
	var cells: Dictionary = data.get("cells", {})
	for key in cells.keys():
		var cell := _parse_cell_key(String(key))
		if cell == INVALID_CELL:
			continue
		var parsed := _parse_save_cell(cells[key])
		set_cell(cell, int(parsed["type"]), int(parsed["amount"]), false)
	end_batch_writes()
	_reset_simulation_state()
	if _renderer != null:
		_renderer.rebuild_from_system(self)


func _simulation_tick() -> void:
	var start_usec := Time.get_ticks_usec()
	var mass_before := 0
	if _debug_mass_tracking:
		mass_before = get_total_water_amount()
	_simulating = true
	_dirty_render.clear()
	_reacted_this_tick.clear()
	_ensure_queue_has_work()
	var batch: Array[Vector2i] = []
	var processed := 0
	var budget_ms := 3.5
	if settings != null:
		var budget_value: Variant = settings.get("simulation_budget_ms")
		if budget_value != null:
			budget_ms = float(budget_value)
	var budget_usec := int(maxf(budget_ms, 0.5) * 1000.0)
	while processed < _current_budget and _queue_read < _queue.size():
		if Time.get_ticks_usec() - start_usec > budget_usec:
			break
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
	var dirty_count := _dirty_render.size()
	var dirty_chunks := _count_dirty_chunks(_dirty_render)
	if _renderer != null and not _dirty_render.is_empty():
		_renderer.apply_dirty(_dirty_render)
	var mass_after := 0
	var mass_delta := 0
	if _debug_mass_tracking:
		mass_after = get_total_water_amount()
		mass_delta = mass_after - mass_before
		if mass_delta != 0:
			push_warning("Liquid mass conservation error: %d -> %d (delta %d)" % [mass_before, mass_after, mass_delta])
	_record_debug_stats(start_usec, processed, dirty_count, dirty_chunks, mass_after, mass_delta)


func _process_cell(cell: Vector2i) -> void:
	if not can_hold_liquid(cell):
		_remove_at(cell)
		_wake_cell_and_neighbors(cell)
		return
	var amount := _read_amount(cell)
	if amount <= 0:
		_deactivate(cell)
		return
	if _try_react_neighbors(cell):
		return
	var liquid_type := get_type(cell)
	var current := cell
	var moved_vertically := false
	for _step in _max_vertical_steps(liquid_type):
		amount = _read_amount(current)
		if amount <= 0:
			break
		if not _flow_down_once(current):
			break
		moved_vertically = true
		if _read_amount(current) > 0:
			break
		current = current + Vector2i(0, 1)
	var horizontal := false
	if _read_amount(cell) > 0 and not _has_downward_space(cell):
		horizontal = _flow_horizontal(cell)
	if not moved_vertically and not horizontal:
		_try_sleep(cell)


func _flow_down_once(cell: Vector2i) -> bool:
	var below := cell + Vector2i(0, 1)
	if not can_hold_liquid(below):
		return false
	if _is_world_bottom(below):
		return false
	var amount := _read_amount(cell)
	var below_amount := _read_amount(below)
	var below_type := get_type(below)
	var from_type := get_type(cell)
	if below_type != LiquidTypes.Type.NONE and below_type != from_type:
		return _react_water_lava(cell, below)
	var space := LiquidTypes.FULL - below_amount
	if space <= 0:
		return false
	var flow := mini(amount, _vertical_rate(from_type))
	flow = mini(flow, space)
	if flow <= 0:
		return false
	return _transfer_internal(cell, below, flow)


func _flow_horizontal(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	var liquid_type := get_type(cell)
	if amount <= _settle_threshold(liquid_type):
		return false
	var changed := false
	for direction in [-1, 1]:
		var neighbor := cell + Vector2i(direction, 0)
		if not can_hold_liquid(neighbor):
			continue
		var n_type := get_type(neighbor)
		if n_type != LiquidTypes.Type.NONE and n_type != liquid_type:
			if _react_water_lava(cell, neighbor):
				changed = true
			continue
		var n_amount := _read_amount(neighbor)
		var diff := amount - n_amount
		if diff <= settings.equalize_min_diff:
			continue
		var flow := mini(maxi(diff >> 1, 1), _horizontal_rate(liquid_type))
		if flow <= 0:
			continue
		if _transfer_internal(cell, neighbor, flow):
			changed = true
			amount = _read_amount(cell)
			if amount <= _settle_threshold(liquid_type):
				break
	return changed


func _transfer_internal(from: Vector2i, to: Vector2i, amount: int) -> bool:
	if amount <= 0:
		return false
	var from_type := get_type(from)
	var to_type := get_type(to)
	if to_type != LiquidTypes.Type.NONE and to_type != from_type:
		return _react_water_lava(from, to)
	var from_amount := _read_amount(from)
	var to_amount := _read_amount(to)
	var space := LiquidTypes.FULL - to_amount
	var moved := mini(amount, mini(from_amount, space))
	if moved <= 0:
		return false
	_write_amount(from, from_amount - moved, from_type)
	_write_amount(to, to_amount + moved, from_type)
	_wake_cell_and_neighbors(from)
	_wake_cell_and_neighbors(to)
	return true


func _has_downward_space(cell: Vector2i) -> bool:
	var below := cell + Vector2i(0, 1)
	return can_hold_liquid(below) and _read_amount(below) < LiquidTypes.FULL


func _is_stable(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	if amount <= 0:
		return true
	if _has_downward_space(cell):
		return false
	var liquid_type := get_type(cell)
	if amount <= _settle_threshold(liquid_type):
		return true
	for direction in [-1, 1]:
		var neighbor := cell + Vector2i(direction, 0)
		if not can_hold_liquid(neighbor):
			continue
		var n_type := get_type(neighbor)
		if n_type != LiquidTypes.Type.NONE and n_type != liquid_type:
			return false
		if amount > _read_amount(neighbor) + settings.equalize_min_diff:
			return false
	for offset in NEIGHBOR_OFFSETS:
		var n_type := get_type(cell + offset)
		if n_type != LiquidTypes.Type.NONE and n_type != liquid_type:
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


func _displace_liquid(cell: Vector2i) -> bool:
	var amount := _read_amount(cell)
	if amount <= 0:
		return true
	var liquid_type := get_type(cell)
	var remaining := amount
	var targets: Array[Vector2i] = []
	for offset in DISPLACE_OFFSETS:
		var target: Vector2i = cell + offset
		if can_hold_liquid(target) and not _is_world_bottom(target):
			var t_type := get_type(target)
			if t_type == LiquidTypes.Type.NONE or t_type == liquid_type:
				targets.append(target)
	if targets.is_empty():
		return false
	var per_target := ceili(float(remaining) / float(targets.size()))
	for target in targets:
		var space := LiquidTypes.FULL - _read_amount(target)
		var moved := mini(per_target, mini(space, remaining))
		if moved > 0:
			_write_amount(target, _read_amount(target) + moved, liquid_type)
			_wake_cell_and_neighbors(target)
			remaining -= moved
	_remove_at(cell)
	_wake_cell_and_neighbors(cell)
	return remaining <= 0


func _write_amount(cell: Vector2i, amount: int, liquid_type: int) -> void:
	if not _in_bounds(cell):
		return
	var idx := _index(cell)
	var clamped := clampi(amount, LiquidTypes.EMPTY, LiquidTypes.FULL)
	var old_amount := int(_amounts[idx])
	var old_type := int(_types[idx])
	if clamped <= 0:
		if old_amount == 0 and old_type == LiquidTypes.Type.NONE:
			return
		_amounts[idx] = 0
		_types[idx] = LiquidTypes.Type.NONE
		_liquid_cells.erase(cell)
		_adjust_type_count(old_type, -1)
		_deactivate(cell)
	else:
		if old_amount == clamped and old_type == liquid_type:
			return
		_amounts[idx] = clamped
		_types[idx] = liquid_type
		_liquid_cells[cell] = true
		if old_amount <= 0:
			_adjust_type_count(liquid_type, 1)
		elif old_type != liquid_type:
			_adjust_type_count(old_type, -1)
			_adjust_type_count(liquid_type, 1)
	_dirty_render[cell] = true


func _remove_at(cell: Vector2i) -> void:
	_write_amount(cell, 0, LiquidTypes.Type.NONE)


func _read_amount(cell: Vector2i) -> int:
	if not _in_bounds(cell):
		return 0
	return _amounts[_index(cell)]


func _wake_cell_and_neighbors(cell: Vector2i) -> void:
	_enqueue_water(cell)
	for offset in NEIGHBOR_OFFSETS:
		_enqueue_water(cell + offset)


func _enqueue_water(cell: Vector2i) -> void:
	if not _in_bounds(cell):
		return
	if _read_amount(cell) <= 0:
		return
	_enqueue(cell)


func _enqueue(cell: Vector2i, reset_stable: bool = true) -> void:
	if not _in_bounds(cell):
		return
	_active[cell] = true
	if reset_stable:
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
		_enqueue(cell, false)


func _compact_queue() -> void:
	if _queue_read < 64:
		return
	if _queue_read <= int(_queue.size() / 2.0):
		return
	_queue = _queue.slice(_queue_read)
	_queue_read = 0


func _reset_runtime_state() -> void:
	_liquid_cells.clear()
	_forced_solids.clear()
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
	_reacted_this_tick.clear()


func _rebuild_water_cells() -> void:
	_liquid_cells.clear()
	_water_count = 0
	_lava_count = 0
	for y in world_height:
		for x in world_width:
			var cell := Vector2i(x, y)
			var amount := _read_amount(cell)
			if amount <= 0:
				continue
			_liquid_cells[cell] = true
			_adjust_type_count(int(_types[_index(cell)]), 1)


func _clear_all_liquid() -> void:
	var existing: Array = _liquid_cells.keys()
	for cell in existing:
		_write_amount(cell, 0, LiquidTypes.Type.NONE)


func _restore_baseline_liquid() -> void:
	_clear_all_liquid()
	for key in _baseline.keys():
		var cell := _parse_cell_key(String(key))
		if cell == INVALID_CELL:
			continue
		var packed := int(_baseline[key])
		_write_amount(cell, packed & 255, packed >> 8)


func _flush_dirty_render() -> void:
	if _simulating or _batch_writes:
		return
	if _renderer != null and not _dirty_render.is_empty():
		_renderer.apply_dirty(_dirty_render)
		_dirty_render.clear()


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


func _record_debug_stats(
		start_usec: int,
		processed: int,
		dirty_count: int,
		dirty_chunks: int,
		mass_after: int,
		mass_delta: int
	) -> void:
	debug_stats = {
		"active_cells": _active.size(),
		"sleeping_cells": get_sleeping_cell_count(),
		"water_cells": get_water_cell_count(),
		"lava_cells": get_lava_cell_count(),
		"liquid_cells": _liquid_cells.size(),
		"queue_size": get_queue_size(),
		"updates_last_tick": processed,
		"update_budget": _current_budget,
		"simulation_ms": (Time.get_ticks_usec() - start_usec) / 1000.0,
		"simulation_hz": settings.simulation_rate,
		"ticks_this_frame": last_ticks_this_frame,
		"dirty_cells_last_tick": dirty_count,
		"dirty_chunks_last_tick": dirty_chunks,
		"mass_tracking": _debug_mass_tracking,
	}
	if _debug_mass_tracking:
		debug_stats["total_water"] = mass_after
		debug_stats["mass_delta"] = mass_delta
		debug_stats["mass_error"] = mass_delta != 0


func _count_dirty_chunks(dirty: Dictionary) -> int:
	if dirty.is_empty():
		return 0
	var chunks := {}
	for cell in dirty.keys():
		var c: Vector2i = cell
		chunks[Vector2i(c.x >> DIRTY_CHUNK_SHIFT, c.y >> DIRTY_CHUNK_SHIFT)] = true
	return chunks.size()


func _surface_threshold() -> int:
	if settings == null:
		return 8
	var value: Variant = settings.get("surface_amount_threshold")
	if value == null:
		return 8
	return int(value)


func _index(cell: Vector2i) -> int:
	return cell.y * world_width + cell.x


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < world_width and cell.y >= 0 and cell.y < world_height


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _parse_cell_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return INVALID_CELL
	return Vector2i(int(parts[0]), int(parts[1]))


func resolve_contacts(max_pairs: int = 8000) -> int:
	var converted := 0
	var cells: Array = _liquid_cells.keys()
	for cell in cells:
		if converted >= max_pairs:
			break
		if _try_react_neighbors(cell):
			converted += 1
	return converted


func _try_react_neighbors(cell: Vector2i) -> bool:
	var liquid_type := get_type(cell)
	if liquid_type == LiquidTypes.Type.NONE or get_amount(cell) <= 0:
		return false
	for offset in NEIGHBOR_OFFSETS:
		var neighbor := cell + offset
		var n_type := get_type(neighbor)
		if n_type == LiquidTypes.Type.NONE or n_type == liquid_type:
			continue
		if _react_water_lava(cell, neighbor):
			return true
	return false


func _react_water_lava(a: Vector2i, b: Vector2i) -> bool:
	if _reacted_this_tick.has(a) or _reacted_this_tick.has(b):
		return false
	var a_type := get_type(a)
	var lava_cell := a if a_type == LiquidTypes.Type.LAVA else b
	var water_cell := a if a_type == LiquidTypes.Type.WATER else b
	if get_type(lava_cell) != LiquidTypes.Type.LAVA or get_type(water_cell) != LiquidTypes.Type.WATER:
		return false
	if _is_world_bottom(lava_cell) or _is_world_bottom(water_cell):
		return false
	_reacted_this_tick[lava_cell] = true
	_reacted_this_tick[water_cell] = true
	_remove_at(lava_cell)
	_remove_at(water_cell)
	_place_reaction_solid(lava_cell)
	_wake_cell_and_neighbors(lava_cell)
	_wake_cell_and_neighbors(water_cell)
	var lava_node := get_node_or_null("Lava")
	if lava_node != null and lava_node.has_method("play_reaction"):
		lava_node.call("play_reaction", lava_cell)
	return true


func _place_reaction_solid(cell: Vector2i) -> void:
	if not _in_bounds(cell) or _is_world_bottom(cell):
		return
	if _world_gen != null and _world_gen.has_method("set_generated_tile"):
		if not bool(_world_gen.call("set_generated_tile", cell.x, cell.y, LiquidTypes.WATER_LAVA_RESULT_BLOCK_ID)):
			return
	if _block_catalog != null and _tilemap != null:
		var block := _block_catalog.get_by_id(LiquidTypes.WATER_LAVA_RESULT_BLOCK_ID)
		if block != null:
			_block_catalog.set_block_cell(_tilemap, cell, block)
	_forced_solids[cell] = true
	var scene_tree := get_tree()
	if scene_tree != null:
		var vis := scene_tree.get_first_node_in_group("visibility_overlay")
		if vis != null and vis.has_method("invalidate_cell"):
			vis.call("invalidate_cell", cell)


func _is_world_bottom(cell: Vector2i) -> bool:
	if not _in_bounds(cell):
		return true
	if _world_gen != null:
		var bedrock_rows := int(_world_gen.get("bedrock_rows")) if "bedrock_rows" in _world_gen else 5
		if cell.y >= world_height - bedrock_rows:
			return true
		if _world_gen.has_method("get_block_id") and int(_world_gen.call("get_block_id", cell.x, cell.y)) == 13:
			return true
	if _block_catalog != null and _tilemap != null:
		var block := _block_catalog.get_cell_block(_tilemap, cell)
		if block != null and block.is_block_unbreakable():
			return true
	return false


func _vertical_rate(liquid_type: int) -> int:
	if liquid_type == LiquidTypes.Type.LAVA:
		return settings.lava_flow_speed if settings != null else 48
	return settings.vertical_flow_rate if settings != null else 255


func _horizontal_rate(liquid_type: int) -> int:
	if liquid_type == LiquidTypes.Type.LAVA:
		return settings.lava_horizontal_flow if settings != null else 12
	return settings.horizontal_flow_rate if settings != null else 64


func _max_vertical_steps(liquid_type: int) -> int:
	if liquid_type == LiquidTypes.Type.LAVA:
		return settings.lava_max_vertical_steps_per_cell if settings != null else 1
	return settings.max_vertical_steps_per_cell if settings != null else 8


func _settle_threshold(liquid_type: int) -> int:
	if liquid_type == LiquidTypes.Type.LAVA:
		return settings.lava_settle_threshold if settings != null else 4
	return settings.settle_threshold if settings != null else 2


func _adjust_type_count(liquid_type: int, delta: int) -> void:
	if delta == 0:
		return
	if liquid_type == LiquidTypes.Type.WATER:
		_water_count = maxi(_water_count + delta, 0)
	elif liquid_type == LiquidTypes.Type.LAVA:
		_lava_count = maxi(_lava_count + delta, 0)


func _count_type(liquid_type: int) -> int:
	var total := 0
	for cell in _liquid_cells.keys():
		if get_type(cell) == liquid_type:
			total += 1
	return total


func _cells_of_type(liquid_type: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _liquid_cells.keys():
		if get_type(cell) == liquid_type:
			cells.append(cell)
	return cells


func _total_amount_of_type(liquid_type: int) -> int:
	var total := 0
	for cell in _liquid_cells.keys():
		if get_type(cell) == liquid_type:
			total += _read_amount(cell)
	return total


func _pack_cell(amount: int, liquid_type: int) -> int:
	return (clampi(amount, 0, 255)) | (clampi(liquid_type, 0, 255) << 8)


func _save_cell_value(amount: int, liquid_type: int) -> Variant:
	if liquid_type == LiquidTypes.Type.WATER:
		return amount
	return {"a": amount, "t": liquid_type}


func _parse_save_cell(value: Variant) -> Dictionary:
	if value is Dictionary:
		return {
			"amount": int(value.get("a", 0)),
			"type": int(value.get("t", LiquidTypes.Type.WATER)),
		}
	return {"amount": int(value), "type": LiquidTypes.Type.WATER}


func _find_block_catalog() -> BlockCatalog:
	if _world_gen != null:
		var catalog: Variant = _world_gen.get("block_catalog")
		if catalog is BlockCatalog:
			return catalog
	return load("res://resources/blocks/block_catalog.tres") as BlockCatalog
