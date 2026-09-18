class_name TreeSystem
extends Node2D

## Gehoert an: World/TreeSystem in res://scenes/world/world.tscn
## Registry, Faellen, Nachwachsen und Samen pflanzen. Huettenholz bleibt aussen vor.

signal tiles_changed(cells: Array[Vector2i])

const AIR := 0
const GRASS := 1
const DIRT := 2
const TILE_SIZE := 16
const MATURE_STAGE := 4

@export var tree_regrow_delay: float = 10.0
@export var growth_stage_interval_min: float = 2.0
@export var growth_stage_interval_max: float = 4.0
@export var oak: TreeData
@export var birch: TreeData
@export var pine: TreeData
@export var block_catalog: BlockCatalog
@export var item_catalog: ItemCatalog
@export var item_drop_scene: PackedScene
@export var falling_tree_scene: PackedScene

var trees_by_base: Dictionary = {}
var trunk_to_base: Dictionary = {}
var leaf_to_base: Dictionary = {}

var _tilemap: TileMapLayer
var _world: WorldGenerator
var _drops_parent: Node2D
var _rng := RandomNumberGenerator.new()
var _next_instance_id: int = 1

@onready var _wood_hit: AudioStreamPlayer2D = $WoodHit
@onready var _tree_fall: AudioStreamPlayer2D = $TreeFall


func _ready() -> void:
	add_to_group("tree_system")
	_rng.randomize()
	_world = get_parent() as WorldGenerator
	_tilemap = get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	_drops_parent = get_node_or_null("../ItemDrops") as Node2D


func _process(delta: float) -> void:
	if trees_by_base.is_empty():
		return
	var bases: Array = trees_by_base.keys()
	for base in bases:
		var inst: TreeInstanceData = trees_by_base.get(base)
		if inst == null:
			continue
		if inst.regrow_left > 0.0:
			inst.regrow_left = maxf(inst.regrow_left - delta, 0.0)
			if inst.regrow_left == 0.0:
				_begin_growth(inst)
		elif inst.grow_left > 0.0:
			inst.grow_left = maxf(inst.grow_left - delta, 0.0)
			if inst.grow_left == 0.0:
				_advance_growth(inst)


func get_species(tree_type: StringName) -> TreeData:
	match tree_type:
		&"oak":
			return oak
		&"birch":
			return birch
		&"pine":
			return pine
		_:
			return oak


func pick_species_for_column(rng: RandomNumberGenerator, tile_x: int, surface_y: int, base_surface_y: int) -> TreeData:
	var hill := surface_y < base_surface_y - 3
	var roll := rng.randf()
	if hill:
		if roll < 0.55:
			return pine
		if roll < 0.80:
			return oak
		return birch
	var stripe := int(floor(float(tile_x) / 90.0))
	if stripe % 3 == 1:
		if roll < 0.50:
			return birch
		if roll < 0.75:
			return oak
		return pine
	if roll < 0.40:
		return oak
	if roll < 0.70:
		return birch
	return pine


func plant_generated_tree(world: WorldGenerator, rng: RandomNumberGenerator, tile_x: int, species: TreeData) -> bool:
	if species == null:
		return false
	var ground_y := world.get_surface_y(tile_x)
	var ground := Vector2i(tile_x, ground_y)
	var height := rng.randi_range(species.min_height, species.max_height)
	if not _can_fit_generated(world, ground, height, species):
		return false
	var inst := TreeInstanceData.new()
	inst.tree_type = species.tree_id
	inst.base_cell = Vector2i(tile_x, ground_y - 1)
	inst.height = height
	inst.target_height = height
	inst.growth_stage = MATURE_STAGE
	inst.damaged = false
	inst.planted = false
	_layout_tree(inst, species, height, rng)
	if not _cells_are_air_in_world(world, inst):
		return false
	_stamp_generated(world, inst, species)
	_register(inst)
	return true


func handle_break(tile: Vector2i, player: Player, item: ItemData = null) -> bool:
	if trees_by_base.has(tile):
		if not _can_fell_instance(trees_by_base[tile], item):
			return true
		_fell_tree(trees_by_base[tile], player, true)
		return true
	if trunk_to_base.has(tile):
		var base: Vector2i = trunk_to_base[tile]
		var inst: TreeInstanceData = trees_by_base.get(base)
		if inst == null:
			return false
		if not _can_fell_instance(inst, item):
			return true
		if tile == inst.base_cell:
			_fell_tree(inst, player, true)
			return true
		_fell_from_cut(inst, tile, player)
		return true
	if leaf_to_base.has(tile):
		var base: Vector2i = leaf_to_base[tile]
		var inst: TreeInstanceData = trees_by_base.get(base)
		if inst == null:
			return false
		_remove_leaf(inst, tile)
		return true
	return false


func _can_fell_instance(inst: TreeInstanceData, item: ItemData) -> bool:
	if inst == null:
		return false
	var species := get_species(inst.tree_type)
	if species == null:
		return false
	return species.can_fell_with(item)


func is_tree_tile(tile: Vector2i) -> bool:
	return trees_by_base.has(tile) or trunk_to_base.has(tile) or leaf_to_base.has(tile)


func get_trunk_hardness(tile: Vector2i) -> float:
	if not trees_by_base.has(tile) and not trunk_to_base.has(tile):
		return 0.0
	var base: Vector2i = tile if trees_by_base.has(tile) else trunk_to_base[tile]
	var inst: TreeInstanceData = trees_by_base.get(base)
	if inst == null:
		return 0.0
	var species := get_species(inst.tree_type)
	if species == null:
		return 0.0
	var tree_height := maxi(inst.height, inst.trunk_cells.size())
	var trunk_index := inst.base_cell.y - tile.y
	if trunk_index < 0:
		return species.trunk_hardness
	var denom := maxf(1.0, float(tree_height - 1))
	var normalized := clampf(float(trunk_index) / denom, 0.0, 1.0)
	var multiplier := lerpf(1.0, species.top_hardness_multiplier, normalized)
	return species.trunk_hardness * multiplier


func try_plant_seed(player: Player, ground_tile: Vector2i, species: TreeData) -> bool:
	if species == null or _tilemap == null:
		return false
	if not _is_plantable_ground(ground_tile):
		return false
	var base := Vector2i(ground_tile.x, ground_tile.y - 1)
	if _get_block_id(base) != AIR:
		return false
	for dx in range(-1, 2):
		if trees_by_base.has(Vector2i(base.x + dx, base.y)):
			return false
	if player != null and _tile_overlaps_player(player, base):
		return false
	var inst := TreeInstanceData.new()
	inst.tree_type = species.tree_id
	inst.base_cell = base
	inst.height = 0
	inst.target_height = _roll_target_height(species, species.max_height)
	inst.growth_stage = 0
	inst.damaged = false
	inst.planted = true
	inst.trunk_cells = [base]
	inst.leaf_cells = []
	_set_block(base, species.sapling_block_id)
	_register(inst)
	inst.grow_left = _roll_stage_interval()
	_notify_cells([base])
	return true


func get_species_for_seed_item(item: ItemData) -> TreeData:
	if item == null:
		return null
	if oak != null and item.id == oak.seed_item_id:
		return oak
	if birch != null and item.id == birch.seed_item_id:
		return birch
	if pine != null and item.id == pine.seed_item_id:
		return pine
	if item.tree_type != &"":
		return get_species(item.tree_type)
	return null


func counts() -> Dictionary:
	var oak_n := 0
	var birch_n := 0
	var pine_n := 0
	for base in trees_by_base:
		var inst: TreeInstanceData = trees_by_base[base]
		match inst.tree_type:
			&"oak":
				oak_n += 1
			&"birch":
				birch_n += 1
			&"pine":
				pine_n += 1
	return {"oak": oak_n, "birch": birch_n, "pine": pine_n, "total": trees_by_base.size()}


func _can_fit_generated(world: WorldGenerator, ground: Vector2i, height: int, species: TreeData) -> bool:
	var radius := 3 if species.crown_style == &"round" else (2 if species.crown_style == &"narrow" else 3)
	for cx in range(ground.x - radius, ground.x + radius + 1):
		for cy in range(ground.y - height - 4, ground.y):
			if world._get_tile(cx, cy) != AIR:
				return false
	return true


func _cells_are_air_in_world(world: WorldGenerator, inst: TreeInstanceData) -> bool:
	for cell in inst.trunk_cells:
		if world._get_tile(cell.x, cell.y) != AIR:
			return false
	for cell in inst.leaf_cells:
		if world._get_tile(cell.x, cell.y) != AIR:
			return false
	return true


func _stamp_generated(world: WorldGenerator, inst: TreeInstanceData, species: TreeData) -> void:
	for cell in inst.trunk_cells:
		world._set_tile(cell.x, cell.y, species.trunk_block_id)
	for cell in inst.leaf_cells:
		world._set_tile(cell.x, cell.y, species.leaf_block_id)


func _layout_tree(inst: TreeInstanceData, species: TreeData, height: int, rng: RandomNumberGenerator) -> void:
	inst.height = height
	inst.trunk_cells.clear()
	inst.leaf_cells.clear()
	if height <= 0:
		inst.trunk_cells.append(inst.base_cell)
		return
	for i in height:
		inst.trunk_cells.append(Vector2i(inst.base_cell.x, inst.base_cell.y - i))
	inst.leaf_cells = _build_crown(inst.base_cell, height, species.crown_style, rng)


func _build_crown(base: Vector2i, height: int, style: StringName, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var top := Vector2i(base.x, base.y - height + 1)
	match style:
		&"narrow":
			var radius := 2
			for dy in range(-3, 2):
				var row_r := 1 if dy <= -3 or dy >= 1 else radius
				for dx in range(-row_r, row_r + 1):
					if dx == 0 and dy > 0:
						continue
					if rng.randf() < 0.06 and absi(dx) == row_r:
						continue
					cells.append(Vector2i(top.x + dx, top.y + dy))
		&"triangle":
			var max_r := 3 if height >= 10 else 2
			var top_dy := -(max_r + 2)
			for dy in range(top_dy, 2):
				var from_top := dy - top_dy
				var row_r := mini(max_r, from_top)
				if dy >= 1:
					row_r = maxi(1, row_r - 1)
				for dx in range(-row_r, row_r + 1):
					if dx == 0 and dy > 0:
						continue
					cells.append(Vector2i(top.x + dx, top.y + dy))
		_:
			var radius := 3 if height >= 6 else 2
			for dy in range(-3, 2):
				var row_r := radius
				if dy <= -3 or dy >= 1:
					row_r = maxi(1, radius - 1)
				for dx in range(-row_r, row_r + 1):
					if dx == 0 and dy > 0:
						continue
					if absi(dx) == row_r and absi(dy) >= 2 and rng.randf() < 0.35:
						continue
					cells.append(Vector2i(top.x + dx, top.y + dy))
	return cells


func _register(inst: TreeInstanceData) -> void:
	_unregister_maps_for(inst.base_cell)
	trees_by_base[inst.base_cell] = inst
	for cell in inst.trunk_cells:
		trunk_to_base[cell] = inst.base_cell
	for cell in inst.leaf_cells:
		leaf_to_base[cell] = inst.base_cell
	_next_instance_id += 1


func _unregister(inst: TreeInstanceData) -> void:
	_unregister_maps_for(inst.base_cell)
	trees_by_base.erase(inst.base_cell)


func _unregister_maps_for(base: Vector2i) -> void:
	var inst: TreeInstanceData = trees_by_base.get(base)
	if inst == null:
		return
	for cell in inst.trunk_cells:
		if trunk_to_base.get(cell) == base:
			trunk_to_base.erase(cell)
	for cell in inst.leaf_cells:
		if leaf_to_base.get(cell) == base:
			leaf_to_base.erase(cell)


func _fell_tree(inst: TreeInstanceData, player: Player, animate: bool) -> void:
	var species := get_species(inst.tree_type)
	if species == null:
		return
	var cells := _all_cells(inst)
	var fall_right := true
	if player != null:
		var base_world := _cell_center(inst.base_cell)
		fall_right = player.global_position.x <= base_world.x
	var snapshots: Array[Dictionary] = []
	for cell in cells:
		var block := _block_at(cell)
		if block != null:
			snapshots.append({"cell": cell, "atlas": block.atlas_coords})
	var wood_count := inst.trunk_cells.size()
	var was_sapling := inst.growth_stage <= 0 or inst.height <= 0
	_play_at(inst.base_cell, _wood_hit)
	_clear_instance_tiles(inst)
	_unregister(inst)
	_notify_cells(cells)
	if was_sapling:
		_spawn_drop(species.seed_item_id, 1, _cell_center(inst.base_cell))
		return
	if animate and falling_tree_scene != null and not snapshots.is_empty():
		_play_at(inst.base_cell, _tree_fall)
		var falling := falling_tree_scene.instantiate() as FallingTree
		var parent := _world if _world != null else get_tree().current_scene
		parent.add_child(falling)
		var duration := _fall_duration(wood_count)
		falling.finished.connect(_on_tree_fell.bind(inst.base_cell, species, wood_count, fall_right, wood_count), CONNECT_ONE_SHOT)
		falling.setup(snapshots, inst.base_cell, _tilemap, fall_right, duration)
	else:
		_spawn_fell_drops(inst.base_cell, species, wood_count, fall_right, wood_count)


func _fell_from_cut(inst: TreeInstanceData, cut_tile: Vector2i, player: Player) -> void:
	var species := get_species(inst.tree_type)
	if species == null:
		return
	var stump: Array[Vector2i] = []
	var falling_trunk: Array[Vector2i] = []
	for cell in inst.trunk_cells:
		if cell.y > cut_tile.y:
			stump.append(cell)
		else:
			falling_trunk.append(cell)
	if stump.is_empty():
		_fell_tree(inst, player, true)
		return
	var fall_right := true
	if player != null:
		var base_world := _cell_center(inst.base_cell)
		fall_right = player.global_position.x <= base_world.x
	var falling_cells: Array[Vector2i] = []
	falling_cells.append_array(falling_trunk)
	falling_cells.append_array(inst.leaf_cells)
	var snapshots: Array[Dictionary] = []
	for cell in falling_cells:
		var block := _block_at(cell)
		if block != null:
			snapshots.append({"cell": cell, "atlas": block.atlas_coords})
	var wood_count := maxi(1, falling_trunk.size())
	_play_at(cut_tile, _wood_hit)
	for cell in falling_cells:
		_erase_cell(cell)
	_unregister_maps_for(inst.base_cell)
	inst.trunk_cells = stump
	inst.leaf_cells = []
	inst.height = stump.size()
	inst.damaged = true
	inst.regrow_left = tree_regrow_delay
	inst.grow_left = -1.0
	_register(inst)
	_notify_cells(falling_cells)
	var origin_cell := stump[0]
	for cell in stump:
		if cell.y < origin_cell.y:
			origin_cell = cell
	if falling_tree_scene != null and not snapshots.is_empty():
		_play_at(cut_tile, _tree_fall)
		var falling := falling_tree_scene.instantiate() as FallingTree
		var parent := _world if _world != null else get_tree().current_scene
		parent.add_child(falling)
		var duration := _fall_duration(wood_count)
		falling.finished.connect(_on_tree_fell.bind(origin_cell, species, wood_count, fall_right, wood_count), CONNECT_ONE_SHOT)
		falling.setup(snapshots, cut_tile, _tilemap, fall_right, duration)
	else:
		_spawn_fell_drops(origin_cell, species, wood_count, fall_right, wood_count)


func _fall_duration(segment_count: int) -> float:
	if segment_count <= 5:
		return clampf(0.55 + float(segment_count) * 0.05, 0.6, 0.8)
	if segment_count <= 9:
		return clampf(0.72 + float(segment_count - 5) * 0.06, 0.8, 1.0)
	return clampf(0.95 + float(segment_count - 9) * 0.07, 1.0, 1.3)


func _on_tree_fell(origin: Vector2i, species: TreeData, wood_count: int, fall_right: bool, segments: int) -> void:
	_spawn_fell_drops(origin, species, wood_count, fall_right, segments)


func _spawn_fell_drops(origin_cell: Vector2i, species: TreeData, wood_count: int, fall_right: bool, segments: int) -> void:
	var wood_amount := maxi(1, wood_count)
	var seed_amount := 1 + (1 if _rng.randf() < 0.22 else 0)
	var origin := _cell_center(origin_cell)
	var dir := 1.0 if fall_right else -1.0
	var line_length := maxf(float(maxi(segments, 1)) * float(TILE_SIZE), float(TILE_SIZE))
	var piles := _split_wood_piles(wood_amount)
	for i in piles.size():
		var t := float(i + 1) / float(piles.size() + 1)
		var along := t * line_length + _rng.randf_range(-3.0, 4.0)
		var jitter_x := _rng.randf_range(4.0, 10.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
		var jitter_y := _rng.randf_range(-6.0, -2.0) if _rng.randf() < 0.5 else _rng.randf_range(2.0, 6.0)
		var pos := origin + Vector2(dir * along + jitter_x, jitter_y)
		if fall_right:
			pos.x = maxf(pos.x, origin.x + 8.0)
		else:
			pos.x = minf(pos.x, origin.x - 8.0)
		_spawn_drop(species.wood_item_id, piles[i], pos)
	var seed_along := line_length * _rng.randf_range(0.45, 0.85)
	var seed_pos := origin + Vector2(dir * seed_along + _rng.randf_range(-6.0, 6.0), _rng.randf_range(-8.0, -2.0))
	if fall_right:
		seed_pos.x = maxf(seed_pos.x, origin.x + 4.0)
	else:
		seed_pos.x = minf(seed_pos.x, origin.x - 4.0)
	_spawn_drop(species.seed_item_id, seed_amount, seed_pos)


func _split_wood_piles(amount: int) -> PackedInt32Array:
	var piles := 1
	if amount >= 5:
		piles = 2
	if amount >= 9:
		piles = 3
	if amount >= 13:
		piles = mini(4, amount)
	var pile_counts := PackedInt32Array()
	var remaining := amount
	for i in piles:
		var left := piles - i
		var take := int(float(remaining) / float(left))
		if i == piles - 1:
			take = remaining
		pile_counts.append(maxi(1, take))
		remaining -= take
	return pile_counts


func _remove_leaf(inst: TreeInstanceData, tile: Vector2i) -> void:
	_erase_cell(tile)
	leaf_to_base.erase(tile)
	var remaining: Array[Vector2i] = []
	for cell in inst.leaf_cells:
		if cell != tile:
			remaining.append(cell)
	inst.leaf_cells = remaining
	if _rng.randf() < 0.08:
		var species := get_species(inst.tree_type)
		if species != null:
			_spawn_drop(species.seed_item_id, 1, _cell_center(tile))
	_notify_cells([tile])


func _begin_growth(inst: TreeInstanceData) -> void:
	var species := get_species(inst.tree_type)
	if species == null or not trees_by_base.has(inst.base_cell):
		return
	inst.damaged = false
	inst.target_height = _roll_target_height(species, inst.height if inst.height > 0 else species.max_height)
	var keep_height := 1
	for cell in inst.trunk_cells:
		if cell.x == inst.base_cell.x:
			keep_height = maxi(keep_height, inst.base_cell.y - cell.y + 1)
	keep_height = mini(keep_height, inst.target_height)
	var start_stage := 1 if keep_height <= 1 else clampi(int(round(float(keep_height) / float(maxi(inst.target_height, 1)) * float(MATURE_STAGE))), 1, MATURE_STAGE - 1)
	if not _apply_stage(inst, species, start_stage):
		inst.grow_left = _roll_stage_interval()
		return
	if inst.growth_stage < MATURE_STAGE:
		inst.grow_left = _roll_stage_interval()
	else:
		inst.grow_left = -1.0


func _advance_growth(inst: TreeInstanceData) -> void:
	var species := get_species(inst.tree_type)
	if species == null or not trees_by_base.has(inst.base_cell):
		return
	if inst.growth_stage >= MATURE_STAGE:
		inst.grow_left = -1.0
		return
	if not _apply_stage(inst, species, inst.growth_stage + 1):
		inst.grow_left = _roll_stage_interval()
		return
	if inst.growth_stage < MATURE_STAGE:
		inst.grow_left = _roll_stage_interval()
	else:
		inst.grow_left = -1.0


func _apply_stage(inst: TreeInstanceData, species: TreeData, stage: int) -> bool:
	var desired_height := _height_for_stage(inst.target_height, stage)
	var planned := TreeInstanceData.new()
	planned.tree_type = inst.tree_type
	planned.base_cell = inst.base_cell
	if stage <= 0:
		planned.height = 0
		planned.trunk_cells = [inst.base_cell]
		planned.leaf_cells = []
	else:
		_layout_tree(planned, species, maxi(desired_height, 1), _rng)
	if not _growth_space_free(inst, planned):
		return false
	var old_cells := _all_cells(inst)
	var new_owned := {}
	for cell in planned.trunk_cells:
		new_owned[cell] = true
	for cell in planned.leaf_cells:
		new_owned[cell] = true
	for cell in old_cells:
		if not new_owned.has(cell):
			_erase_cell(cell)
	_unregister_maps_for(inst.base_cell)
	inst.height = planned.height
	inst.growth_stage = stage
	inst.trunk_cells = planned.trunk_cells.duplicate()
	inst.leaf_cells = planned.leaf_cells.duplicate()
	if stage <= 0:
		_set_block(inst.base_cell, species.sapling_block_id)
	else:
		for cell in inst.trunk_cells:
			_set_block(cell, species.trunk_block_id)
		for cell in inst.leaf_cells:
			if _get_block_id(cell) == AIR or old_cells.has(cell):
				_set_block(cell, species.leaf_block_id)
	_register(inst)
	var changed := _merge_cells(old_cells, _all_cells(inst))
	_notify_cells(changed)
	return true


func _growth_space_free(current: TreeInstanceData, planned: TreeInstanceData) -> bool:
	var owned := {}
	for cell in current.trunk_cells:
		owned[cell] = true
	for cell in current.leaf_cells:
		owned[cell] = true
	var player := get_tree().get_first_node_in_group("player") as Player
	for cell in planned.trunk_cells:
		if owned.has(cell):
			continue
		if _get_block_id(cell) != AIR:
			return false
		if player != null and _tile_overlaps_player(player, cell):
			return false
	for cell in planned.leaf_cells:
		if owned.has(cell):
			continue
		if _get_block_id(cell) != AIR:
			return false
		if player != null and _tile_overlaps_player(player, cell):
			return false
	return true


func _height_for_stage(target: int, stage: int) -> int:
	if stage <= 0:
		return 0
	if stage >= MATURE_STAGE:
		return target
	var t := float(stage) / float(MATURE_STAGE)
	return maxi(1, int(round(lerpf(1.0, float(target), t))))


func _roll_target_height(species: TreeData, previous: int) -> int:
	var lo := species.min_height
	var hi := species.max_height
	previous = clampi(previous, lo, hi)
	if _rng.randf() < 0.70:
		return _rng.randi_range(lo, maxi(lo, previous - 1 if previous > lo else lo))
	return _rng.randi_range(maxi(lo, previous - 1), hi)


func _roll_stage_interval() -> float:
	return _rng.randf_range(growth_stage_interval_min, growth_stage_interval_max)


func _clear_instance_tiles(inst: TreeInstanceData) -> void:
	for cell in inst.leaf_cells:
		_erase_cell(cell)
	for cell in inst.trunk_cells:
		_erase_cell(cell)


func _all_cells(inst: TreeInstanceData) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.append_array(inst.trunk_cells)
	cells.append_array(inst.leaf_cells)
	return cells


func _merge_cells(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for cell in a:
		if not seen.has(cell):
			seen[cell] = true
			out.append(cell)
	for cell in b:
		if not seen.has(cell):
			seen[cell] = true
			out.append(cell)
	return out


func _is_plantable_ground(tile: Vector2i) -> bool:
	var id := _get_block_id(tile)
	return id == GRASS or id == DIRT


func _get_block_id(tile: Vector2i) -> int:
	if _tilemap == null or _tilemap.get_cell_source_id(tile) == -1:
		return AIR
	if block_catalog == null:
		return AIR
	var block := block_catalog.get_by_atlas(_tilemap.get_cell_atlas_coords(tile))
	return block.id if block != null else AIR


func _block_at(tile: Vector2i) -> BlockData:
	if _tilemap == null or block_catalog == null:
		return null
	if _tilemap.get_cell_source_id(tile) == -1:
		return null
	return block_catalog.get_by_atlas(_tilemap.get_cell_atlas_coords(tile))


func _set_block(tile: Vector2i, block_id: int) -> void:
	if _tilemap == null or block_catalog == null:
		return
	var block := block_catalog.get_by_id(block_id)
	if block == null:
		return
	block_catalog.set_block_cell(_tilemap, tile, block)


func _erase_cell(tile: Vector2i) -> void:
	if _tilemap != null:
		_tilemap.erase_cell(tile)


func _terrain_source_id() -> int:
	if _tilemap == null or _tilemap.tile_set == null or _tilemap.tile_set.get_source_count() == 0:
		return 0
	return _tilemap.tile_set.get_source_id(0)


func _cell_center(tile: Vector2i) -> Vector2:
	if _tilemap == null:
		return Vector2(tile * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	return _tilemap.to_global(_tilemap.map_to_local(tile))


func _spawn_drop(item_id: int, amount: int, world_pos: Vector2) -> void:
	if item_id < 0 or amount <= 0 or item_drop_scene == null or item_catalog == null:
		return
	var item := item_catalog.get_item(item_id)
	if item == null:
		return
	var drop := item_drop_scene.instantiate() as ItemDrop
	var parent := _drops_parent if _drops_parent != null else self
	parent.add_child(drop)
	drop.global_position = world_pos
	drop.setup(item_id, amount, item.icon)


func _notify_cells(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	tiles_changed.emit(cells)
	var map_data := get_tree().get_first_node_in_group("world_map_data")
	if map_data != null and map_data.has_method("update_tiles"):
		map_data.call("update_tiles", cells)
	else:
		var map := get_tree().get_first_node_in_group("world_map_ui")
		if map != null and map.has_method("update_map_tiles"):
			map.call("update_map_tiles", cells)
	var overlay := get_tree().get_first_node_in_group("visibility_overlay")
	if overlay != null and overlay.has_method("invalidate_cells"):
		overlay.call("invalidate_cells", cells)
	elif overlay != null and overlay.has_method("invalidate"):
		overlay.call("invalidate")


func _play_at(tile: Vector2i, player: AudioStreamPlayer2D) -> void:
	if player == null or player.stream == null:
		return
	player.global_position = _cell_center(tile)
	player.pitch_scale = 1.0 + _rng.randf_range(-0.08, 0.08)
	player.play()


func _tile_overlaps_player(player: Player, tile: Vector2i) -> bool:
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return true
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return true
	var player_rect := Rect2(collision.global_position - rect_shape.size * 0.5, rect_shape.size).grow(1.0)
	var center := _cell_center(tile)
	var tile_rect := Rect2(center - Vector2(TILE_SIZE, TILE_SIZE) * 0.5, Vector2(TILE_SIZE, TILE_SIZE))
	return player_rect.intersects(tile_rect)
