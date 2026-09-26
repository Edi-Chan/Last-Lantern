class_name WorldGenerator
extends Node2D

## Gehoert an: World-Wurzelnode in res://scenes/world/world.tscn
##
## Seed-basierter, begrenzter Weltgenerator. Arbeitet auf einem Byte-Array und
## committet erst am Ende in den TileMapLayer. Bestehende Kataloge, Baeume,
## Vegetation und Fluessigkeiten bleiben die Post-Gen-Systeme.

const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const GRANITE := 5
const SLATE := 6
const WOOD := 7
const LEAVES := 8
const COPPER_ORE := 9
const TIN_ORE := 10
const FERRITE_ORE := 11
const AUREL_ORE := 12
const BEDROCK := 13
const OAK_WOOD := 14
const BIRCH_WOOD := 15
const PINE_WOOD := 16
const OAK_LEAVES := 17
const BIRCH_LEAVES := 18
const PINE_LEAVES := 19
const OAK_SAPLING := 20
const BIRCH_SAPLING := 21
const PINE_SAPLING := 22
const COBALT_ORE := 23
const VEYRITE_ORE := 24
const CRYONITE_ORE := 25
const IGNITIUM_ORE := 26
const VOIDIUM_ORE := 27
const ASTRALITH_ORE := 28

const HIGHEST_BLOCK_ID := ASTRALITH_ORE
const TILE_SIZE := 16
const STONE_LIKE: Array[int] = [STONE, GRANITE, SLATE]
const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
const FORTRESS_SCENE := preload("res://scenes/world/structures/enemy_fortress.tscn")

const BIOME_GRASSLAND := 0
const BIOME_FOREST := 1
const BIOME_SAND := 2
const BIOME_BEACH := 3
const BIOME_FORTRESS := 4

@export_group("Welt")
@export var world_width: int = 1600
@export var world_height: int = 480
@export var world_seed: int = 12345
@export var world_size_id: int = WorldSize.Id.MEDIUM
@export var generation_settings: WorldGenerationSettings

@export_group("Oberflaeche")
@export var base_surface_y: int = 144
@export var surface_amplitude: int = 22
@export var dirt_depth_min: int = 4
@export var dirt_depth_max: int = 8

@export_group("Spawn und Rand")
@export var spawn_clear_radius: int = 28
@export var world_edge_width: int = 3
@export var bedrock_rows: int = 5

@export_group("Baeume")
@export var tree_min_height: int = 4
@export var tree_max_height: int = 7
@export var tree_min_spacing: int = 4
@export var tree_max_spacing: int = 9

@export_group("Referenzen")
@export var block_catalog: BlockCatalog
@export var ore_catalog: OreCatalog
@export var debug_place_ore_row: bool = false

var player_spawn_position: Vector2 = Vector2.ZERO
var spawn_tile: Vector2i = Vector2i.ZERO
var stats: Dictionary = {}
var _fire_ratio_cached: float = 0.88
var _fire_ratio_ready: bool = false
var layout: WorldLayout
var _tiles: PackedByteArray
var _surface: PackedInt32Array
var _is_sand_column: PackedByteArray
var _hut_blocked: PackedByteArray
var _forest_column: PackedByteArray
var _biome: PackedByteArray
var _used_seed: int = 0
var _cave_noise: FastNoiseLite
var _cave_threshold: float = 1.0
var _fortress_tiles: int = 0
var _ore_tiles: int = 0

@onready var _tilemap: TileMapLayer = $Terrain/TileMapLayer


func _ready() -> void:
	add_to_group("world_generator")
	_apply_pending_seed()
	generate_world()
	_remember_generated_seed()


func generate_world() -> void:
	var start_usec := Time.get_ticks_usec()
	_ensure_settings()
	_used_seed = world_seed if world_seed != 0 else randi()
	if _used_seed == 0:
		_used_seed = 1
	_apply_size_profile()
	layout = WorldLayout.build(generation_settings, world_size_id, _used_seed)
	world_width = layout.width
	world_height = layout.height
	base_surface_y = layout.base_surface_y
	surface_amplitude = layout.surface_amplitude
	world_edge_width = layout.edge_width
	bedrock_rows = generation_settings.bedrock_rows
	dirt_depth_min = generation_settings.dirt_depth_min
	dirt_depth_max = generation_settings.dirt_depth_max
	tree_min_height = generation_settings.tree_min_height
	tree_max_height = generation_settings.tree_max_height
	spawn_clear_radius = maxi(int(layout.start_width() / 2.0), 12)

	_tiles = PackedByteArray()
	_tiles.resize(world_width * world_height)
	_surface = PackedInt32Array()
	_surface.resize(world_width)
	_is_sand_column = PackedByteArray()
	_is_sand_column.resize(world_width)
	_hut_blocked = PackedByteArray()
	_hut_blocked.resize(world_width)
	_forest_column = PackedByteArray()
	_forest_column.resize(world_width)
	_biome = PackedByteArray()
	_biome.resize(world_width)
	_fortress_tiles = 0
	_ore_tiles = 0
	stats = {}

	generate_surface()
	_apply_layout_surface()
	generate_ground_layers()
	generate_biomes()
	apply_surface_materials()
	generate_caves()
	generate_rock_variation()
	generate_world_bounds()
	cleanup_surface()
	_reapply_reserved_surface()
	find_spawn_position()
	generate_ores()
	generate_cave_entrances()
	_stamp_fortress_ruins()
	generate_trees()
	_build_forest_mask()
	generate_vegetation()
	_generate_water()
	_generate_lava()
	_place_fortress_node()
	_rebuild_world_bounds()
	call_deferred("_apply_camera_limits")
	_validate_and_repair()
	_align_underground_backdrop()
	_align_surface_background()
	_align_cave_atmosphere()
	_align_sky()
	_commit_to_tilemap()
	_finalize_liquids()
	if debug_place_ore_row:
		place_progression_test_row()

	stats["seed"] = _used_seed
	stats["world_size"] = world_size_id
	stats["start_on_left"] = layout.start_on_left
	stats["width"] = world_width
	stats["height"] = world_height
	stats["generation_ms"] = (Time.get_ticks_usec() - start_usec) / 1000.0


# --------------------------------------------------------------------- Zugriff

func get_surface_y(tile_x: int) -> int:
	if tile_x < 0 or tile_x >= world_width:
		return base_surface_y
	return _surface[tile_x]


func get_region(tile: Vector2i) -> String:
	if tile.x < 0 or tile.x >= world_width:
		return "Ausserhalb"
	if layout != null:
		if layout.is_ocean_column(tile.x) and tile.y <= get_surface_y(tile.x) + 2:
			return "Meer"
		if layout.is_start_column(tile.x) and tile.y <= get_surface_y(tile.x) + 2:
			return "Startgebiet"
		if layout.is_fortress_approach_column(tile.x) and tile.y <= get_surface_y(tile.x) + 2:
			return "Festungsweg"
		if layout.is_fortress_keep_column(tile.x) and tile.y <= get_surface_y(tile.x) + 2:
			return "Festung"
		if layout.is_fortress_column(tile.x) and tile.y <= get_surface_y(tile.x) + 2:
			return "Festung"
	if tile.y > _surface[tile.x] + 4:
		return DepthLayer.region_name(get_depth_layer(tile.x, tile.y))
	if _is_sand_column[tile.x] != 0:
		return "Sand Area"
	if _forest_column.size() == world_width and _forest_column[tile.x] != 0:
		return "Forest"
	return "Grassland"


func get_block_id(tile_x: int, tile_y: int) -> int:
	return _get_tile(tile_x, tile_y)


func is_sand_column(tile_x: int) -> bool:
	if tile_x < 0 or tile_x >= world_width:
		return false
	return _is_sand_column[tile_x] != 0


func get_surface_biome(tile_x: int) -> StringName:
	if tile_x < 0 or tile_x >= world_width:
		return &"grassland"
	if _biome.size() != world_width:
		if _is_sand_column[tile_x] != 0:
			return &"sand"
		if _forest_column.size() == world_width and _forest_column[tile_x] != 0:
			return &"forest"
		return &"grassland"
	match int(_biome[tile_x]):
		BIOME_SAND, BIOME_BEACH:
			return &"sand"
		BIOME_FOREST:
			return &"forest"
		_:
			return &"grassland"


func get_seed() -> int:
	return _used_seed


func get_world_size_id() -> int:
	return world_size_id


func sea_level() -> int:
	return layout.sea_level if layout != null else base_surface_y + 1


func is_ocean_column(tile_x: int) -> bool:
	return layout != null and layout.is_ocean_column(tile_x)


func is_fortress_column(tile_x: int) -> bool:
	return layout != null and layout.is_fortress_column(tile_x)


func should_skip_ambient_water(tile_x: int) -> bool:
	if layout == null:
		return is_spawn_pad_column(tile_x)
	return layout.is_ocean_column(tile_x) or layout.is_start_column(tile_x) or layout.is_fortress_column(tile_x) or layout.is_edge_column(tile_x)


func get_depth_layer(tile_x: int, tile_y: int) -> int:
	var top := get_surface_y(tile_x)
	if tile_y <= top:
		return DepthLayer.Id.SURFACE
	var floor_y := world_height - bedrock_rows
	var span := maxf(float(floor_y - top), 1.0)
	var ratio := float(tile_y - top) / span
	if generation_settings == null:
		return DepthLayer.Id.UNDERGROUND
	return generation_settings.layer_for_ratio(ratio)


func get_depth_ratio(tile_x: int, tile_y: int) -> float:
	var top := get_surface_y(tile_x)
	var floor_y := world_height - bedrock_rows
	var span := maxf(float(floor_y - top), 1.0)
	return clampf(float(tile_y - top) / span, 0.0, 1.0)


func is_fire_region(tile_x: int, tile_y: int) -> bool:
	if get_depth_layer(tile_x, tile_y) != DepthLayer.Id.DANGER:
		return false
	if tile_y >= world_height - bedrock_rows:
		return false
	return get_depth_ratio(tile_x, tile_y) >= _fire_region_ratio()


func _fire_region_ratio() -> float:
	if _fire_ratio_ready:
		return _fire_ratio_cached
	_fire_ratio_cached = 0.88
	var liquid := _get_liquid_system()
	if liquid != null and liquid.settings != null:
		_fire_ratio_cached = liquid.settings.fire_region_start_ratio
	_fire_ratio_ready = true
	return _fire_ratio_cached


func fire_region_start_y(tile_x: int) -> int:
	var top := get_surface_y(tile_x)
	var floor_y := world_height - bedrock_rows
	var start := _fire_region_ratio()
	return clampi(top + int(round(float(floor_y - top) * start)), top + 1, floor_y - 1)


func set_generated_tile(tile_x: int, tile_y: int, block_id: int) -> bool:
	if tile_x < 0 or tile_x >= world_width or tile_y < 0 or tile_y >= world_height:
		return false
	if tile_y >= world_height - bedrock_rows:
		return false
	if _get_tile(tile_x, tile_y) == BEDROCK:
		return false
	_set_tile(tile_x, tile_y, block_id)
	return true


func find_open_cell_in_layer(layer_id: int, around_x: int = -1, fire_only: bool = false) -> Vector2i:
	var start_x := around_x if around_x >= 0 else spawn_tile.x
	for radius in range(0, world_width, 8):
		for sign_x in [-1, 1]:
			var x := clampi(start_x + sign_x * radius, world_edge_width + 4, world_width - world_edge_width - 5)
			for y in range(get_surface_y(x) + 2, world_height - bedrock_rows - 2):
				if get_depth_layer(x, y) != layer_id:
					continue
				if fire_only and not is_fire_region(x, y):
					continue
				if not fire_only and is_fire_region(x, y) and layer_id == DepthLayer.Id.DANGER:
					continue
				if _get_tile(x, y) != AIR:
					continue
				if _get_tile(x, y + 1) == AIR:
					continue
				if _get_tile(x, y - 1) != AIR:
					continue
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func present_surface_biomes() -> Dictionary:
	var found := {}
	for x in world_width:
		found[get_surface_biome(x)] = true
	return found


func fortress_tile_count() -> int:
	return _fortress_tiles


func ore_tile_count() -> int:
	if _tiles.is_empty():
		return _ore_tiles
	var count := 0
	for value in _tiles:
		if _is_ore_block(value):
			count += 1
	_ore_tiles = count
	return count


func cave_tile_count() -> int:
	if _tiles.is_empty():
		return int(stats.get("cave_tiles", 0))
	return _count_air_below_surface()


func clamp_world_position(pos: Vector2) -> Vector2:
	var bounds := get_node_or_null("WorldBounds") as WorldBounds
	var sky := float(generation_settings.sky_margin_tiles * TILE_SIZE) if generation_settings != null else 128.0
	if bounds != null:
		return bounds.clamp_position(pos, float(world_width * TILE_SIZE), float(world_height * TILE_SIZE), sky)
	return Vector2(
		clampf(pos.x, 8.0, float(world_width * TILE_SIZE) - 8.0),
		clampf(pos.y, -sky + 8.0, float(world_height * TILE_SIZE) - 8.0)
	)


func _apply_pending_seed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow == null:
		return
	if flow.has_method("resolve_world_seed"):
		var pending := int(flow.call("resolve_world_seed"))
		if pending != 0:
			world_seed = pending
	# Nur im New-Game-/Continue-Flow die Groesse uebernehmen, damit Editor-Starts
	# die Inspector-Werte behalten.
	var mode := int(flow.get("mode"))
	if (mode == 1 or mode == 2) and flow.has_method("resolve_world_size"):
		world_size_id = WorldSize.clamp_id(int(flow.call("resolve_world_size")))


func _remember_generated_seed() -> void:
	var flow := get_node_or_null("/root/GameFlow")
	if flow != null and flow.has_method("remember_generated_seed"):
		flow.call("remember_generated_seed", get_seed())
	if flow != null and flow.has_method("remember_generated_world_size"):
		flow.call("remember_generated_world_size", world_size_id)


func is_hut_column(tile_x: int) -> bool:
	if tile_x < 0 or tile_x >= world_width:
		return false
	return _hut_blocked[tile_x] != 0


func lantern_column_x() -> int:
	if layout != null:
		return layout.lantern_x
	return int(float(world_width) / 2.0)


func is_spawn_pad_column(tile_x: int) -> bool:
	if layout != null:
		return layout.is_start_column(tile_x)
	return absi(tile_x - lantern_column_x()) <= spawn_clear_radius


func _ensure_settings() -> void:
	if generation_settings == null:
		generation_settings = WorldGenerationSettings.load_or_default()


func _apply_size_profile() -> void:
	world_size_id = WorldSize.clamp_id(world_size_id)
	var profile: Dictionary = generation_settings.size_profile(world_size_id)
	world_width = int(profile.get("width", world_width))
	world_height = int(profile.get("height", world_height))
	base_surface_y = int(profile.get("base_surface_y", base_surface_y))
	surface_amplitude = int(profile.get("surface_amplitude", surface_amplitude))


# ------------------------------------------------------------------- Oberflaeche

func generate_surface() -> void:
	var hills := _make_noise(1, 0.0045, 3)
	var bumps := _make_noise(2, 0.02, 2)
	var min_y := base_surface_y - surface_amplitude
	var max_y := base_surface_y + surface_amplitude
	for x in world_width:
		var value := hills.get_noise_1d(float(x)) + bumps.get_noise_1d(float(x)) * 0.35
		var y := base_surface_y + int(roundf(value * float(surface_amplitude)))
		_surface[x] = clampi(y, min_y, max_y)


func _apply_layout_surface() -> void:
	if layout == null:
		return
	var pad_y := clampi(_surface[layout.lantern_x], base_surface_y - 6, base_surface_y + 6)
	layout.start_surface_y = pad_y
	layout.sea_level = pad_y + 1
	for x in range(layout.start_x0, layout.start_x1):
		_surface[x] = pad_y
	var ocean_floor := clampi(pad_y + layout.ocean_depth, pad_y + 6, world_height - bedrock_rows - 8)
	for x in range(layout.ocean_x0, layout.ocean_x1):
		var t := 0.0
		if layout.start_on_left:
			t = float(layout.ocean_x1 - 1 - x) / float(maxi(layout.ocean_width() - 1, 1))
		else:
			t = float(x - layout.ocean_x0) / float(maxi(layout.ocean_width() - 1, 1))
		t = clampf(t, 0.0, 1.0)
		t = t * t
		_surface[x] = int(round(lerpf(float(pad_y), float(ocean_floor), t)))
	var fort_y := pad_y - 1
	for x in range(layout.fortress_x0, layout.fortress_x1):
		_surface[x] = fort_y
	_smooth_surface(generation_settings.surface_smooth_passes)
	for x in range(layout.start_x0, layout.start_x1):
		_surface[x] = pad_y
	for x in range(layout.fortress_x0, layout.fortress_x1):
		_surface[x] = fort_y


func _reapply_reserved_surface() -> void:
	if layout == null:
		return
	var pad_y := layout.start_surface_y
	for x in range(layout.start_x0, layout.start_x1):
		_flatten_column(x, pad_y, GRASS)
		_biome[x] = BIOME_GRASSLAND
		_is_sand_column[x] = 0
	var fort_y := layout.start_surface_y - 1
	for x in range(layout.fortress_approach_x0, layout.fortress_approach_x1):
		_flatten_column(x, fort_y, DIRT)
		_biome[x] = BIOME_FORTRESS
		_hut_blocked[x] = 1
	for x in range(layout.fortress_keep_x0, layout.fortress_keep_x1):
		_flatten_column(x, fort_y, STONE)
		_biome[x] = BIOME_FORTRESS
		_hut_blocked[x] = 1
	for x in range(layout.ocean_x0, layout.ocean_x1):
		_is_sand_column[x] = 1
		_biome[x] = BIOME_BEACH
		var top := _surface[x]
		if _get_tile(x, top) in [GRASS, DIRT, STONE]:
			_set_tile(x, top, SAND)


func _flatten_column(x: int, pad_y: int, top_block: int) -> void:
	for y in range(0, pad_y):
		_set_tile(x, y, AIR)
	_set_tile(x, pad_y, top_block)
	var dirt_depth := dirt_depth_min
	for y in range(pad_y + 1, world_height - bedrock_rows):
		var id := _get_tile(x, y)
		if id == AIR or id == GRASS or id == SAND:
			_set_tile(x, y, DIRT if y <= pad_y + dirt_depth else STONE)
		elif y > pad_y + dirt_depth:
			break
	_surface[x] = pad_y


func _smooth_surface(passes: int) -> void:
	for _pass in maxi(passes, 0):
		var copy := _surface.duplicate()
		for x in range(world_edge_width + 1, world_width - world_edge_width - 1):
			if layout != null and (layout.is_ocean_column(x) or layout.is_start_column(x) or layout.is_fortress_column(x)):
				continue
			copy[x] = int(round(float(_surface[x - 1] + _surface[x] + _surface[x + 1]) / 3.0))
		_surface = copy


func generate_ground_layers() -> void:
	var dirt_noise := _make_noise(3, 0.03, 1)
	for x in world_width:
		var top := _surface[x]
		var span := float(dirt_depth_max - dirt_depth_min)
		var dirt_depth := dirt_depth_min + int(roundf((dirt_noise.get_noise_1d(float(x)) * 0.5 + 0.5) * span))
		var top_block := GRASS
		if layout != null and layout.is_ocean_column(x):
			top_block = SAND
			dirt_depth = maxi(dirt_depth, generation_settings.sand_depth_min)
		_set_tile(x, top, top_block)
		for y in range(top + 1, mini(top + 1 + dirt_depth, world_height)):
			_set_tile(x, y, SAND if top_block == SAND else DIRT)
		for y in range(top + 1 + dirt_depth, world_height):
			_set_tile(x, y, STONE)


func generate_biomes() -> void:
	for x in world_width:
		_biome[x] = BIOME_GRASSLAND
	if layout == null:
		return
	for x in range(layout.ocean_x0, layout.ocean_x1):
		_biome[x] = BIOME_BEACH
	for x in range(layout.start_x0, layout.start_x1):
		_biome[x] = BIOME_GRASSLAND
	for x in range(layout.fortress_x0, layout.fortress_x1):
		_biome[x] = BIOME_FORTRESS
	_assign_playable_biome_bands()
	stats["biomes"] = present_surface_biomes().keys()


func _assign_playable_biome_bands() -> void:
	var rng := _rng(71)
	_paint_biome_span(layout.playable_x0, layout.playable_x1, rng, true)
	_paint_biome_span(layout.playable_b_x0, layout.playable_b_x1, rng, false)
	_ensure_required_playable_biomes()
	_blend_biome_edges(rng)


func _paint_biome_span(x0: int, x1: int, rng: RandomNumberGenerator, prefer_forest: bool) -> void:
	var remaining := x1 - x0
	if remaining < 16:
		return
	var bands: Array[Dictionary] = []
	var intro := clampi(generation_settings.biome_min_band_width, 24, maxi(int(remaining / 5.0), 24))
	bands.append({"id": BIOME_GRASSLAND, "w": intro})
	remaining -= intro
	var pool: Array[int] = [BIOME_FOREST, BIOME_SAND, BIOME_FOREST, BIOME_GRASSLAND]
	if world_size_id == WorldSize.Id.LARGE:
		pool.append(BIOME_FOREST)
		pool.append(BIOME_GRASSLAND)
	elif world_size_id == WorldSize.Id.SMALL:
		pool = [BIOME_FOREST, BIOME_SAND]
	if not prefer_forest:
		pool = [BIOME_SAND, BIOME_FOREST, BIOME_GRASSLAND, BIOME_SAND]
	for i in pool.size():
		var j := rng.randi_range(i, pool.size() - 1)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for biome_id in pool:
		if remaining < generation_settings.biome_min_band_width + 16:
			break
		var prev: int = int(bands[bands.size() - 1]["id"])
		if biome_id == BIOME_SAND and prev == BIOME_FOREST:
			var buffer := mini(generation_settings.biome_transition_width, int(remaining / 3.0))
			if buffer >= 6:
				bands.append({"id": BIOME_GRASSLAND, "w": buffer})
				remaining -= buffer
		if biome_id == BIOME_FOREST and prev == BIOME_SAND:
			var buffer2 := mini(generation_settings.biome_transition_width, int(remaining / 3.0))
			if buffer2 >= 6:
				bands.append({"id": BIOME_GRASSLAND, "w": buffer2})
				remaining -= buffer2
		var width := rng.randi_range(generation_settings.biome_min_band_width, generation_settings.biome_max_band_width)
		width = mini(width, remaining - 16)
		if width < 16:
			break
		bands.append({"id": biome_id, "w": width})
		remaining -= width
	if remaining > 0:
		bands.append({"id": BIOME_GRASSLAND, "w": remaining})
	var cursor := x0
	for band in bands:
		var end := mini(cursor + int(band["w"]), x1)
		for x in range(cursor, end):
			_biome[x] = int(band["id"])
		cursor = end


func _ensure_required_playable_biomes() -> void:
	var present := present_surface_biomes()
	if not present.has(&"forest"):
		_paint_required_biome(BIOME_FOREST, layout.playable_x0, layout.playable_x1)
	if not present.has(&"sand"):
		_paint_required_biome(BIOME_SAND, layout.playable_b_x0, layout.playable_b_x1)


func _paint_required_biome(biome_id: int, x0: int, x1: int) -> void:
	if x1 - x0 < 16:
		return
	var mid := int(floor(float(x0 + x1) * 0.5))
	var width := mini(generation_settings.biome_min_band_width, maxi(int((x1 - x0) / 3.0), 16))
	for x in range(mid - int(width / 2.0), mid + int(width / 2.0)):
		if layout != null and layout.is_playable_column(x):
			_biome[x] = biome_id


func _blend_biome_edges(rng: RandomNumberGenerator) -> void:
	var width := generation_settings.biome_transition_width
	for span in [Vector2i(layout.playable_x0, layout.playable_x1), Vector2i(layout.playable_b_x0, layout.playable_b_x1)]:
		for x in range(span.x + 2, span.y - 2):
			var left := int(_biome[x - 1])
			var here := int(_biome[x])
			if left == here or here == BIOME_BEACH or here == BIOME_FORTRESS:
				continue
			if left == BIOME_SAND and here == BIOME_FOREST:
				_biome[x] = BIOME_GRASSLAND
				continue
			if rng.randf() < 0.45:
				var blend := rng.randi_range(2, maxi(int(width / 2.0), 3))
				for dx in blend:
					var cx := x + dx
					if cx >= span.y:
						break
					if rng.randf() < 0.5:
						_biome[cx] = left


func apply_surface_materials() -> void:
	var rng := _rng(11)
	for x in range(world_edge_width, world_width - world_edge_width):
		var biome := int(_biome[x])
		var sand := biome == BIOME_SAND or biome == BIOME_BEACH
		_is_sand_column[x] = 1 if sand else 0
		if not sand:
			continue
		var depth := rng.randi_range(generation_settings.sand_depth_min, generation_settings.sand_depth_max)
		var top := _surface[x]
		for y in range(top, mini(top + depth, world_height)):
			if _get_tile(x, y) in [GRASS, DIRT]:
				_set_tile(x, y, SAND)


# ----------------------------------------------------------------------- Hoehlen

func generate_caves() -> void:
	var blobs := _make_noise(21, 0.027, 3)
	var tunnels := _make_noise(22, 0.058, 2)
	var warp := _make_noise(24, 0.013, 2)
	_cave_noise = blobs
	var floor_y := world_height - bedrock_rows
	var thresholds := _measure_layer_thresholds(blobs)
	_cave_threshold = float(thresholds.get(DepthLayer.Id.SHALLOW_CAVES, 0.45))
	var eligible := 0
	var carved := 0
	for x in range(world_edge_width, world_width - world_edge_width):
		var top := _surface[x]
		for y in range(top + 1, floor_y):
			if not _can_carve_cave(x, y):
				continue
			eligible += 1
			var layer := get_depth_layer(x, y)
			if layer == DepthLayer.Id.SURFACE:
				continue
			var wx := float(x) + warp.get_noise_2d(float(x), float(y)) * 22.0
			var wy := float(y) + warp.get_noise_2d(float(x) + 80.0, float(y)) * 18.0
			var blob := blobs.get_noise_2d(wx, wy)
			var vein := tunnels.get_noise_2d(wx * 0.85, wy * 1.15)
			var threshold := float(thresholds.get(layer, 1.0))
			var vein_width := 0.07 if layer == DepthLayer.Id.UNDERGROUND else 0.11
			if layer == DepthLayer.Id.DEEP_CAVES:
				vein_width = 0.14
			if blob > threshold or absf(vein) < vein_width:
				_set_tile(x, y, AIR)
				carved += 1
	_carve_spine_caves()
	_carve_cave_chambers()
	_carve_fire_region_basins()
	_connect_cave_pockets()
	stats["cave_ratio"] = float(carved) / float(maxi(eligible, 1))
	stats["cave_tiles"] = _count_air_below_surface()


func _measure_layer_thresholds(noise: FastNoiseLite) -> Dictionary:
	var buckets := {}
	var floor_y := world_height - bedrock_rows
	for x in range(world_edge_width, world_width - world_edge_width, 7):
		for y in range(_surface[x] + 2, floor_y, 5):
			if not _can_carve_cave(x, y):
				continue
			var layer := get_depth_layer(x, y)
			if not buckets.has(layer):
				buckets[layer] = PackedFloat32Array()
			var samples: PackedFloat32Array = buckets[layer]
			samples.append(noise.get_noise_2d(float(x), float(y)))
			buckets[layer] = samples
	var result := {}
	for layer in buckets.keys():
		var samples: PackedFloat32Array = buckets[layer]
		if samples.is_empty():
			result[layer] = 1.0
			continue
		samples.sort()
		var fill := generation_settings.cave_fill_for_layer(int(layer))
		var index := int((1.0 - fill) * float(samples.size() - 1))
		result[layer] = samples[clampi(index, 0, samples.size() - 1)]
	return result


func _carve_spine_caves() -> void:
	var rng := _rng(23)
	var count := layout.spine_caves if layout != null else 24
	for i in count:
		var x := rng.randi_range(world_edge_width + 8, world_width - world_edge_width - 9)
		var min_y := _surface[x] + 8
		var max_y := world_height - bedrock_rows - 8
		if min_y >= max_y:
			continue
		var y := rng.randi_range(min_y, max_y)
		var angle := rng.randf() * TAU
		var length := rng.randi_range(28, 140)
		var radius := rng.randi_range(1, 3)
		for _step in length:
			if not _can_carve_cave(x, y) and y > _surface[x] + 2:
				angle += PI * 0.5
			var layer := get_depth_layer(x, y)
			var layer_r := generation_settings.cave_radius_for_layer(layer)
			radius = clampi(radius + rng.randi_range(-1, 1), 1, layer_r + 2)
			_carve_disk(x, y, radius)
			if rng.randf() < 0.08:
				_carve_ellipse(x, y, radius + rng.randi_range(2, 5), radius + rng.randi_range(1, 3))
			if rng.randf() < 0.06:
				_carve_worm_branch(x, y, angle + rng.randf_range(-1.2, 1.2), rng.randi_range(12, 36), rng)
			angle += rng.randf_range(-0.55, 0.55)
			if rng.randf() < 0.07:
				angle += rng.randf_range(-1.4, 1.4)
			var step := rng.randf_range(0.9, 1.7)
			var nx := int(round(cos(angle) * step))
			var ny := int(round(sin(angle) * step))
			if nx == 0 and ny == 0:
				if absf(cos(angle)) >= absf(sin(angle)):
					nx = 1 if cos(angle) >= 0.0 else -1
				else:
					ny = 1 if sin(angle) >= 0.0 else -1
			x = clampi(x + nx, world_edge_width + 2, world_width - world_edge_width - 3)
			y = clampi(y + ny, _surface[x] + 6, world_height - bedrock_rows - 6)
	stats["spine_caves"] = count


func _carve_worm_branch(start_x: int, start_y: int, angle: float, length: int, rng: RandomNumberGenerator) -> void:
	var x := start_x
	var y := start_y
	var radius := rng.randi_range(1, 2)
	for _step in length:
		_carve_disk(x, y, radius)
		angle += rng.randf_range(-0.5, 0.5)
		x = clampi(x + int(round(cos(angle))), world_edge_width + 2, world_width - world_edge_width - 3)
		y = clampi(y + int(round(sin(angle))), _surface[x] + 6, world_height - bedrock_rows - 6)


func _carve_cave_chambers() -> void:
	var rng := _rng(25)
	var area := world_width * maxi(world_height - base_surface_y, 40)
	var count := clampi(int(round(float(area) / 18000.0)), 8, 64)
	for i in count:
		var x := rng.randi_range(world_edge_width + 10, world_width - world_edge_width - 11)
		var min_y := _surface[x] + 10
		var max_y := world_height - bedrock_rows - 10
		if min_y >= max_y:
			continue
		var y := rng.randi_range(min_y, max_y)
		var rx := rng.randi_range(generation_settings.cave_chamber_min_radius, generation_settings.cave_chamber_max_radius)
		var ry := rng.randi_range(2, maxi(rx - 1, 3))
		_carve_ellipse(x, y, rx, ry)
	stats["cave_chambers"] = count


func _carve_fire_region_basins() -> void:
	var rng := _rng(29)
	var target := clampi(int(world_width / 36.0), 10, 32)
	var count := 0
	var attempts := target * 5
	for _i in attempts:
		if count >= target:
			break
		var x := rng.randi_range(world_edge_width + 12, world_width - world_edge_width - 13)
		if should_skip_ambient_water(x):
			continue
		var min_y := fire_region_start_y(x) + 1
		var max_y := world_height - bedrock_rows - 4
		if min_y >= max_y:
			continue
		var y := rng.randi_range(min_y, max_y)
		var rx := rng.randi_range(5, 10)
		var ry := rng.randi_range(3, 6)
		_carve_ellipse(x, y, rx, ry)
		count += 1
	stats["fire_region_chambers"] = count


func _connect_cave_pockets() -> void:
	var labels := PackedInt32Array()
	labels.resize(world_width * world_height)
	labels.fill(-1)
	var components: Array[Vector2i] = []
	var next_id := 0
	var floor_y := world_height - bedrock_rows
	var min_size := generation_settings.cave_connect_min_size
	for x in range(world_edge_width, world_width - world_edge_width):
		for y in range(_surface[x] + 1, floor_y):
			var idx := y * world_width + x
			if _tiles[idx] != AIR or labels[idx] != -1:
				continue
			var size := _flood_label(labels, x, y, next_id)
			if size >= min_size:
				components.append(Vector2i(x, y))
			next_id += 1
	if components.size() <= 1:
		stats["cave_links"] = 0
		return
	if components.size() > 120:
		var stride := maxi(int(floor(float(components.size()) / 120.0)), 1)
		var trimmed: Array[Vector2i] = []
		var cursor := 0
		while cursor < components.size() and trimmed.size() < 120:
			trimmed.append(components[cursor])
			cursor += stride
		components = trimmed
	var rng := _rng(27)
	var max_dist := generation_settings.cave_connect_max_distance
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(components.size())
	for i in components.size():
		parent[i] = i
	var connected := 0
	var limit := mini(components.size() - 1, 80)
	for i in components.size():
		if connected >= limit:
			break
		var best := -1
		var best_d := 99999
		for j in components.size():
			if i == j or _cave_root(parent, i) == _cave_root(parent, j):
				continue
			var d := components[i].distance_squared_to(components[j])
			if d < best_d:
				best_d = d
				best = j
		if best < 0 or best_d > max_dist * max_dist:
			continue
		_carve_winding_tunnel(components[i], components[best], rng)
		var root_i := _cave_root(parent, i)
		var root_j := _cave_root(parent, best)
		parent[root_i] = root_j
		connected += 1
	stats["cave_links"] = connected


func _cave_root(parent: PackedInt32Array, index: int) -> int:
	var i := index
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _flood_label(labels: PackedInt32Array, start_x: int, start_y: int, id: int) -> int:
	var stack: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var count := 0
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if cell.x < 0 or cell.x >= world_width or cell.y < 0 or cell.y >= world_height:
			continue
		var idx := cell.y * world_width + cell.x
		if _tiles[idx] != AIR or labels[idx] != -1:
			continue
		labels[idx] = id
		count += 1
		stack.append(Vector2i(cell.x + 1, cell.y))
		stack.append(Vector2i(cell.x - 1, cell.y))
		stack.append(Vector2i(cell.x, cell.y + 1))
		stack.append(Vector2i(cell.x, cell.y - 1))
	return count


func _carve_disk(cx: int, cy: int, radius: int) -> void:
	var r := maxi(radius, 1)
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy > r * r + 1:
				continue
			var x := cx + dx
			var y := cy + dy
			if _can_carve_cave(x, y):
				_set_tile(x, y, AIR)


func _carve_ellipse(cx: int, cy: int, radius_x: int, radius_y: int) -> void:
	var rx := maxi(radius_x, 1)
	var ry := maxi(radius_y, 1)
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	for dx in range(-rx, rx + 1):
		for dy in range(-ry, ry + 1):
			if (float(dx * dx) / rx2) + (float(dy * dy) / ry2) > 1.08:
				continue
			if _can_carve_cave(cx + dx, cy + dy):
				_set_tile(cx + dx, cy + dy, AIR)


func _can_carve_cave(tile_x: int, tile_y: int) -> bool:
	if tile_x < world_edge_width or tile_x >= world_width - world_edge_width:
		return false
	if tile_y < 0 or tile_y >= world_height - bedrock_rows:
		return false
	if _get_tile(tile_x, tile_y) == BEDROCK:
		return false
	var top := get_surface_y(tile_x)
	var pad := 2
	if layout != null and (layout.is_start_column(tile_x) or layout.is_fortress_column(tile_x)):
		pad = 6
	if layout != null and layout.is_ocean_column(tile_x):
		pad = 1
	return tile_y > top + pad


func _carve_winding_tunnel(from_pos: Vector2i, to_pos: Vector2i, rng: RandomNumberGenerator) -> void:
	var pos := Vector2(from_pos)
	var target := Vector2(to_pos)
	var max_steps := int(pos.distance_to(target) * 2.4) + 16
	for _step in max_steps:
		if pos.distance_to(target) <= 2.0:
			break
		var dir := (target - pos).normalized()
		dir = dir.rotated(rng.randf_range(-0.85, 0.85))
		if dir.length_squared() < 0.01:
			dir = Vector2.RIGHT
		pos += dir * rng.randf_range(0.8, 1.5)
		var radius := rng.randi_range(1, 2)
		if rng.randf() < 0.12:
			radius += 1
		_carve_disk(int(round(pos.x)), int(round(pos.y)), radius)
	_carve_disk(to_pos.x, to_pos.y, 2)


func _count_air_below_surface() -> int:
	var carved := 0
	for x in range(world_edge_width, world_width - world_edge_width):
		for y in range(_surface[x] + 1, world_height - bedrock_rows):
			if _get_tile(x, y) == AIR:
				carved += 1
	return carved


func generate_cave_entrances() -> void:
	var rng := _rng(22)
	var count := rng.randi_range(generation_settings.cave_entrance_min, generation_settings.cave_entrance_max)
	var made := 0
	for i in count:
		var x := rng.randi_range(world_edge_width + 10, world_width - world_edge_width - 11)
		if layout != null and (layout.is_ocean_column(x) or layout.is_start_column(x) or layout.is_fortress_column(x)):
			continue
		if int(_biome[x]) == BIOME_BEACH:
			continue
		var y := _surface[x] + 1
		var angle := rng.randf_range(0.6, PI - 0.6)
		var length := rng.randi_range(16, 34)
		for _step in length:
			_carve_disk(x, y, rng.randi_range(1, 2))
			angle += rng.randf_range(-0.4, 0.4)
			x = clampi(x + int(round(cos(angle))), world_edge_width + 2, world_width - world_edge_width - 3)
			y = clampi(y + int(round(absf(sin(angle)) + 0.4)), _surface[x] + 1, world_height - bedrock_rows - 8)
			if _step > 10 and _get_tile(x, y + 2) == AIR:
				break
		made += 1
	stats["cave_entrances"] = made


# --------------------------------------------------------- Gestein und Erzadern

func generate_rock_variation() -> void:
	var granite_noise := _make_noise(31, 0.022, 2)
	var slate_noise := _make_noise(32, 0.018, 2)
	var granite := 0
	var slate := 0
	for x in range(world_edge_width, world_width - world_edge_width):
		var top := _surface[x]
		for y in range(top + 1, world_height - bedrock_rows):
			if _get_tile(x, y) != STONE:
				continue
			var layer := get_depth_layer(x, y)
			if is_fire_region(x, y) and slate_noise.get_noise_2d(float(x), float(y)) > 0.08:
				_set_tile(x, y, SLATE)
				slate += 1
			elif layer == DepthLayer.Id.DANGER and slate_noise.get_noise_2d(float(x), float(y)) > 0.22:
				_set_tile(x, y, SLATE)
				slate += 1
			elif layer == DepthLayer.Id.DEEP_CAVES and slate_noise.get_noise_2d(float(x), float(y)) > 0.33:
				_set_tile(x, y, SLATE)
				slate += 1
			elif layer >= DepthLayer.Id.UNDERGROUND and granite_noise.get_noise_2d(float(x), float(y)) > 0.38:
				_set_tile(x, y, GRANITE)
				granite += 1
	stats["granite"] = granite
	stats["slate"] = slate


func generate_ores() -> void:
	if ore_catalog == null:
		push_error("WorldGenerator: OreCatalog fehlt.")
		return
	var rng := _rng(41)
	for ore in ore_catalog.ores:
		generate_ore(ore, rng)
	_ore_tiles = 0
	for value in _tiles:
		if _is_ore_block(value):
			_ore_tiles += 1


func generate_ore(ore: OreData, rng: RandomNumberGenerator) -> void:
	if ore == null or ore.block_id < 1:
		return
	var depth := maxi(world_height - bedrock_rows - 40, 40)
	var area := float(world_width * depth) / 1000.0
	var vein_count := maxi(1, int(round(area * ore.rarity_weight)))
	var placed := 0
	var veins := 0
	var starts: Array[Vector2i] = []
	var min_dist := generation_settings.rare_ore_vein_min_distance if ore.special_spawn or ore.rarity_weight < 0.08 else generation_settings.ore_vein_min_distance
	for i in vein_count:
		var start := _find_ore_start_for(ore, rng)
		if start.x < 0:
			continue
		var too_close := false
		for other in starts:
			if other.distance_to(start) < float(min_dist):
				too_close = true
				break
		if too_close:
			continue
		var size := rng.randi_range(ore.vein_min_size, ore.vein_max_size)
		var done := _carve_vein(rng, start, size, ore)
		if done > 0:
			placed += done
			veins += 1
			starts.append(start)
	var key := String(ore.ore_id)
	if key.is_empty():
		key = block_name(ore.block_id).to_lower().replace(" ", "_")
	stats[key] = placed
	stats[key + "_veins"] = veins


func _ore_depth_bounds(x: int, ore: OreData) -> Vector2i:
	var surface := _surface[x]
	var floor_y := world_height - bedrock_rows - 1
	var span := maxi(floor_y - surface, 1)
	var min_y := surface + int(round(float(span) * clampf(ore.min_depth_ratio, 0.0, 1.0)))
	var max_y := surface + int(round(float(span) * clampf(ore.max_depth_ratio, 0.0, 1.0)))
	min_y = clampi(mini(min_y, max_y), surface + 1, floor_y)
	max_y = clampi(maxi(min_y, max_y), min_y, floor_y)
	return Vector2i(min_y, max_y)


func _find_ore_start_for(ore: OreData, rng: RandomNumberGenerator) -> Vector2i:
	var attempts := 40 if ore.special_spawn else 16
	for attempt in attempts:
		var x := rng.randi_range(world_edge_width + 4, world_width - world_edge_width - 5)
		if layout != null and layout.is_ocean_column(x):
			continue
		var bounds := _ore_depth_bounds(x, ore)
		if bounds.x >= bounds.y:
			continue
		var y := rng.randi_range(bounds.x, bounds.y)
		var host := _get_tile(x, y)
		if host not in STONE_LIKE:
			continue
		if ore.special_spawn and host != SLATE and host != GRANITE:
			continue
		return Vector2i(x, y)
	return Vector2i(-1, -1)


func _carve_vein(rng: RandomNumberGenerator, start: Vector2i, size: int, ore: OreData) -> int:
	var placed := 0
	var cells: Array[Vector2i] = []
	if _can_place_ore_at(start.x, start.y, ore):
		_set_tile(start.x, start.y, ore.block_id)
		cells.append(start)
		placed += 1
	var guard := 0
	while placed < size and not cells.is_empty() and guard < size * 12:
		guard += 1
		var current: Vector2i = cells[rng.randi() % cells.size()]
		var next := current + NEIGHBORS_8[rng.randi() % NEIGHBORS_8.size()]
		if not _can_place_ore_at(next.x, next.y, ore):
			continue
		_set_tile(next.x, next.y, ore.block_id)
		cells.append(next)
		placed += 1
	return placed


func _can_place_ore_at(x: int, y: int, ore: OreData) -> bool:
	if _get_tile(x, y) not in STONE_LIKE:
		return false
	if layout != null and layout.is_ocean_column(x):
		return false
	var bounds := _ore_depth_bounds(x, ore)
	return y >= bounds.x and y <= bounds.y


func place_progression_test_row() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if ore_catalog == null or block_catalog == null or _tilemap == null:
		return cells
	var x0 := clampi(spawn_tile.x + 5, world_edge_width + 2, world_width - 16)
	var i := 0
	for ore in ore_catalog.ores:
		if ore == null:
			continue
		var block := block_catalog.get_by_id(ore.block_id)
		if block == null:
			continue
		var cell := Vector2i(x0 + i, _surface[x0 + i])
		_set_tile(cell.x, cell.y, ore.block_id)
		block_catalog.set_block_cell(_tilemap, cell, block)
		cells.append(cell)
		i += 1
	return cells


# --------------------------------------------------------- Weltrand und Bedrock

func generate_world_bounds() -> void:
	var wall_top := 0
	for x in world_width:
		var is_edge := x < world_edge_width or x >= world_width - world_edge_width
		if is_edge:
			for y in range(wall_top, world_height):
				_set_tile(x, y, BEDROCK)
			_surface[x] = maxi(_surface[x], base_surface_y)
		for y in range(world_height - bedrock_rows, world_height):
			_set_tile(x, y, BEDROCK)


func _rebuild_world_bounds() -> void:
	var bounds := get_node_or_null("WorldBounds") as WorldBounds
	if bounds == null:
		bounds = WorldBounds.new()
		bounds.name = "WorldBounds"
		add_child(bounds)
	var sky := float(generation_settings.sky_margin_tiles * TILE_SIZE)
	bounds.rebuild(float(world_width * TILE_SIZE), float(world_height * TILE_SIZE), sky, float(generation_settings.bound_thickness_px))


func _apply_camera_limits() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var sky := generation_settings.sky_margin_tiles * TILE_SIZE
	cam.limit_enabled = true
	cam.limit_left = 0
	cam.limit_top = -sky
	cam.limit_right = world_width * TILE_SIZE
	cam.limit_bottom = world_height * TILE_SIZE


# ------------------------------------------------------------------- Aufraeumen

func cleanup_surface() -> void:
	var removed := 0
	for x in range(world_edge_width, world_width - world_edge_width):
		for y in range(0, world_height - bedrock_rows):
			if _get_tile(x, y) == AIR:
				continue
			if _get_tile(x - 1, y) == AIR and _get_tile(x + 1, y) == AIR \
			and _get_tile(x, y - 1) == AIR and _get_tile(x, y + 1) == AIR:
				_set_tile(x, y, AIR)
				removed += 1
	for pass_index in 2:
		for x in range(world_edge_width + 1, world_width - world_edge_width - 1):
			if layout != null and (layout.is_ocean_column(x) or layout.is_start_column(x) or layout.is_fortress_column(x)):
				continue
			var top := _find_top_solid(x)
			if top < 0:
				continue
			var left := _find_top_solid(x - 1)
			var right := _find_top_solid(x + 1)
			if left - top >= 2 and right - top >= 2:
				_set_tile(x, top, AIR)
				removed += 1
	for x in range(world_edge_width, world_width - world_edge_width):
		var top := _find_top_solid(x)
		_surface[x] = top if top >= 0 else world_height - bedrock_rows
		if top < 0:
			continue
		var block := _get_tile(x, top)
		if block == DIRT:
			_set_tile(x, top, SAND if _is_sand_column[x] != 0 else GRASS)
		elif block == GRASS and _is_sand_column[x] != 0:
			_set_tile(x, top, SAND)
		if _get_tile(x, top + 1) == GRASS:
			_set_tile(x, top + 1, DIRT)
	stats["cleanup_removed"] = removed


func _find_top_solid(x: int) -> int:
	for y in range(0, world_height):
		if _get_tile(x, y) != AIR:
			return y
	return -1


# ----------------------------------------------------------------------- Spawn

func find_spawn_position() -> void:
	var found := layout.spawn_x if layout != null else clampi(lantern_column_x() - 8, world_edge_width + 2, world_width - world_edge_width - 2)
	found = clampi(found, world_edge_width + 2, world_width - world_edge_width - 2)
	_clear_spawn_air(found)
	spawn_tile = Vector2i(found, _surface[found] - 1)
	player_spawn_position = _ground_position(found)
	stats["spawn_tile"] = spawn_tile
	stats["spawn_position"] = player_spawn_position
	stats["lantern_column"] = lantern_column_x()


func _clear_spawn_air(tile_x: int) -> void:
	var ground := _surface[tile_x]
	for y in range(ground - 4, ground):
		_set_tile(tile_x, y, AIR)
		_set_tile(tile_x - 1, y, AIR)
		_set_tile(tile_x + 1, y, AIR)
	if _get_tile(tile_x, ground) == AIR:
		_set_tile(tile_x, ground, GRASS)
		_surface[tile_x] = ground


# ----------------------------------------------------------------------- Baeume

func generate_trees() -> void:
	var trees := get_node_or_null("TreeSystem") as TreeSystem
	if trees == null:
		push_error("WorldGenerator: TreeSystem fehlt.")
		return
	var rng := _rng(51)
	var planted := 0
	var oak_n := 0
	var birch_n := 0
	var pine_n := 0
	var x := world_edge_width + 4
	while x < world_width - world_edge_width - 4:
		var biome := int(_biome[x]) if _biome.size() == world_width else BIOME_GRASSLAND
		if biome == BIOME_BEACH or biome == BIOME_SAND or biome == BIOME_FORTRESS:
			x += 2
			continue
		if layout != null and (layout.is_ocean_column(x) or layout.is_start_column(x) or layout.is_fortress_column(x)):
			x += 2
			continue
		var chance := generation_settings.grassland_tree_chance
		var spacing_min := generation_settings.grassland_tree_spacing_min
		var spacing_max := generation_settings.grassland_tree_spacing_max
		if biome == BIOME_FOREST:
			chance = generation_settings.forest_tree_chance
			spacing_min = generation_settings.forest_tree_spacing_min
			spacing_max = generation_settings.forest_tree_spacing_max
		if rng.randf() < chance:
			var species := trees.pick_species_for_column(rng, x, _surface[x], base_surface_y)
			if biome == BIOME_FOREST and rng.randf() < 0.35:
				species = trees.oak if rng.randf() < 0.5 else trees.pine
			if _plant_tree(rng, x, species, trees):
				planted += 1
				match species.tree_id:
					&"oak":
						oak_n += 1
					&"birch":
						birch_n += 1
					&"pine":
						pine_n += 1
				x += rng.randi_range(spacing_min, spacing_max)
				continue
		x += rng.randi_range(2, 4)
	stats["trees"] = planted
	stats["trees_oak"] = oak_n
	stats["trees_birch"] = birch_n
	stats["trees_pine"] = pine_n


func _build_forest_mask() -> void:
	_forest_column = PackedByteArray()
	_forest_column.resize(world_width)
	var forest_n := 0
	for x in world_width:
		var is_forest := _biome.size() == world_width and int(_biome[x]) == BIOME_FOREST
		_forest_column[x] = 1 if is_forest else 0
		if is_forest:
			forest_n += 1
	stats["forest_columns"] = forest_n


func generate_vegetation() -> void:
	var veg := get_node_or_null("VegetationSystem") as VegetationSystem
	if veg == null:
		return
	veg.generate_from_world(self)


func _plant_tree(rng: RandomNumberGenerator, x: int, species: TreeData, trees: TreeSystem) -> bool:
	if species == null:
		return false
	if is_spawn_pad_column(x):
		return false
	if _hut_blocked[x] != 0:
		return false
	var ground := _surface[x]
	if _get_tile(x, ground) != GRASS:
		return false
	if absi(_surface[x - 1] - ground) > 1 or absi(_surface[x + 1] - ground) > 1:
		return false
	return trees.plant_generated_tree(self, rng, x, species)


# ---------------------------------------------------------------- Festung

func _stamp_fortress_ruins() -> void:
	if layout == null:
		return
	var rng := _rng(81)
	var x0 := layout.fortress_keep_x0 + 3
	var x1 := layout.fortress_keep_x1 - 3
	if x1 - x0 < 18:
		x0 = layout.fortress_center_x - 9
		x1 = x0 + 18
	var base_y := layout.start_surface_y - 1
	var keep_h := generation_settings.fortress_keep_height
	var toward_approach := -1 if layout.start_on_left else 1
	_fortress_tiles = 0
	for x in range(layout.fortress_x0, layout.fortress_x1):
		_hut_blocked[x] = 1
		var top := STONE if layout.is_fortress_keep_column(x) else DIRT
		_flatten_column(x, base_y, top)
		_biome[x] = BIOME_FORTRESS
	for x in range(x0, x1):
		for y in range(base_y - keep_h, base_y):
			var is_wall := x == x0 or x == x1 - 1 or y == base_y - keep_h or y == base_y - int(keep_h / 2.0)
			var tower := (x <= x0 + 3 or x >= x1 - 4) and y >= base_y - keep_h
			if not is_wall and not tower:
				continue
			if rng.randf() < 0.16:
				_set_tile(x, y, AIR)
				continue
			var block := STONE
			if rng.randf() < 0.35:
				block = SLATE
			elif rng.randf() < 0.2:
				block = GRANITE
			_set_tile(x, y, block)
			_fortress_tiles += 1
	var gate_x := x0 if toward_approach < 0 else x1 - 1
	for gx in range(0, 4):
		var x := gate_x + gx * toward_approach
		for gy in range(1, 6):
			_set_tile(x, base_y - gy, AIR)
	for i in rng.randi_range(8, 14):
		var rx := rng.randi_range(x0 + 2, x1 - 3)
		var ry := rng.randi_range(base_y - keep_h + 2, base_y - 2)
		_set_tile(rx, ry, AIR)
	stats["fortress_tiles"] = _fortress_tiles
	stats["fortress_center"] = layout.fortress_center_x
	stats["fortress_approach_width"] = layout.fortress_approach_width()
	stats["fortress_keep_width"] = layout.fortress_keep_width()


func _place_fortress_node() -> void:
	if layout == null:
		return
	var existing := get_node_or_null("EnemyFortress")
	if existing != null:
		existing.queue_free()
	if FORTRESS_SCENE == null:
		return
	var node := FORTRESS_SCENE.instantiate() as Node2D
	if node == null:
		return
	node.name = "EnemyFortress"
	add_child(node)
	if node.has_method("configure"):
		node.call("configure", self, layout.fortress_center_x)
	else:
		node.global_position = _ground_position(layout.fortress_center_x)


# ------------------------------------------------------------------- Uebergabe

func _commit_to_tilemap() -> void:
	if _tilemap == null or block_catalog == null:
		push_error("WorldGenerator: TileMapLayer oder BlockCatalog fehlt.")
		return
	block_catalog.ensure_tileset_tiles(_tilemap.tile_set)
	_tilemap.clear()
	var source_id := block_catalog.terrain_source_id(_tilemap.tile_set)
	var atlas: Array[Vector2i] = []
	atlas.resize(HIGHEST_BLOCK_ID + 1)
	for block_id in range(1, HIGHEST_BLOCK_ID + 1):
		var block := block_catalog.get_by_id(block_id)
		if block == null:
			push_error("WorldGenerator: BlockData mit id %d fehlt im Katalog." % block_id)
			return
		atlas[block_id] = block.atlas_coords
	var solid := 0
	for y in world_height:
		var row := y * world_width
		for x in world_width:
			var block_id := _tiles[row + x]
			if block_id == AIR:
				continue
			_tilemap.set_cell(Vector2i(x, y), source_id, atlas[block_id])
			solid += 1
	stats["tiles_set"] = solid
	_count_surface_blocks()


func _count_surface_blocks() -> void:
	var counts := {}
	for block_id in range(1, HIGHEST_BLOCK_ID + 1):
		counts[block_id] = 0
	for value in _tiles:
		if value != AIR:
			counts[value] += 1
	for block_id in counts:
		stats["block_" + block_name(block_id).to_lower().replace(" ", "_")] = counts[block_id]


func block_name(block_id: int) -> String:
	if block_catalog == null:
		return str(block_id)
	var block := block_catalog.get_by_id(block_id)
	return block.display_name if block != null else str(block_id)


func _is_ore_block(block_id: int) -> bool:
	return block_id == COPPER_ORE or block_id == TIN_ORE or block_id == FERRITE_ORE or block_id == AUREL_ORE \
		or block_id == COBALT_ORE or block_id == VEYRITE_ORE or block_id == CRYONITE_ORE \
		or block_id == IGNITIUM_ORE or block_id == VOIDIUM_ORE or block_id == ASTRALITH_ORE


func _align_underground_backdrop() -> void:
	var backdrop := get_node_or_null("Background/UndergroundBackdrop") as UndergroundBackdrop
	if backdrop == null:
		return
	backdrop.set_profile(_surface, TILE_SIZE, float(world_height * TILE_SIZE))


func _align_surface_background() -> void:
	var sky := get_node_or_null("Background/SurfaceSky") as SurfaceBackground
	if sky == null:
		return
	sky.setup(self)


func _align_cave_atmosphere() -> void:
	var cave := get_node_or_null("Background") as CaveAtmosphere
	if cave == null or generation_settings == null:
		return
	var span := maxi(world_height - bedrock_rows - base_surface_y, 40)
	cave.shallow_start = maxi(int(float(span) * generation_settings.surface_depth_ratio), 4)
	cave.underground_start = maxi(int(float(span) * generation_settings.underground_depth_ratio), cave.shallow_start + 4)
	cave.deep_start = maxi(int(float(span) * generation_settings.shallow_caves_ratio), cave.underground_start + 8)


func _align_sky() -> void:
	var sky := get_node_or_null("Background/Sky") as ColorRect
	if sky == null:
		return
	var w := world_width * TILE_SIZE
	var h := world_height * TILE_SIZE
	sky.offset_left = -640.0
	sky.offset_top = -2048.0
	sky.offset_right = float(w + 640)
	sky.offset_bottom = float(h + 640)


func ground_world_position(tile_x: int) -> Vector2:
	return _ground_position(tile_x)


func _ground_position(tile_x: int) -> Vector2:
	var size := float(TILE_SIZE)
	return Vector2(float(tile_x) * size + size * 0.5, float(_surface[tile_x]) * size - 1.0)


# ----------------------------------------------------------------- Validierung

func _validate_and_repair() -> void:
	var report := WorldValidator.evaluate(self)
	var attempts := 0
	while not bool(report.get("ok", false)) and attempts < 3:
		attempts += 1
		_repair_failures(report.get("failures", PackedStringArray()))
		report = WorldValidator.evaluate(self)
	stats["validation"] = report
	if not bool(report.get("ok", false)):
		push_warning("WorldGenerator: Validierung unvollstaendig: %s" % str(report.get("failures", [])))


func _repair_failures(failures: PackedStringArray) -> void:
	var rng := _rng(901 + failures.size())
	for key in failures:
		match String(key):
			"spawn_inside_block", "spawn_no_ground":
				find_spawn_position()
			"lantern_not_in_start", "spawn_not_in_start":
				find_spawn_position()
			"caves_missing":
				_carve_spine_caves()
			"ores_missing":
				if ore_catalog != null and not ore_catalog.ores.is_empty():
					generate_ore(ore_catalog.ores[0], rng)
			"fortress_tiles_missing":
				_stamp_fortress_ruins()
			"edge_holes":
				generate_world_bounds()
			"bounds_missing":
				_rebuild_world_bounds()
			"ocean_not_lower", "ocean_missing":
				_apply_layout_surface()
				apply_surface_materials()
				_reapply_reserved_surface()
			"biome_missing_forest":
				_force_biome(BIOME_FOREST)
			"biome_missing_sand":
				_force_biome(BIOME_SAND)
			"biome_missing_grassland":
				_force_biome(BIOME_GRASSLAND)
			"lantern_not_centered", "start_too_close_to_edge", "fortress_approach_missing":
				pass


func _force_biome(biome_id: int) -> void:
	if layout == null:
		return
	var a_span := layout.playable_x1 - layout.playable_x0
	var b_span := layout.playable_b_x1 - layout.playable_b_x0
	var x0 := layout.playable_x0
	var x1 := layout.playable_x1
	if b_span > a_span:
		x0 = layout.playable_b_x0
		x1 = layout.playable_b_x1
	var mid := int(floor(float(x0 + x1) * 0.5))
	var width := mini(generation_settings.biome_min_band_width, int(layout.playable_width() / 3.0))
	for x in range(mid - int(width / 2.0), mid + int(width / 2.0)):
		if layout.is_playable_column(x):
			_biome[x] = biome_id
			_is_sand_column[x] = 1 if biome_id == BIOME_SAND else 0
	apply_surface_materials()


# ----------------------------------------------------------------- Hilfsmittel

func _make_noise(offset: int, frequency: float, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = _used_seed + offset
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.45
	return noise


func _rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _used_seed + offset * 7919
	return rng


func _get_tile(x: int, y: int) -> int:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return AIR
	return _tiles[y * world_width + x]


func _set_tile(x: int, y: int, block_id: int) -> void:
	if x < 0 or x >= world_width or y < 0 or y >= world_height:
		return
	_tiles[y * world_width + x] = block_id


func _get_liquid_system() -> LiquidSystem:
	var liquid := get_node_or_null("Terrain/LiquidSystem") as LiquidSystem
	if liquid == null:
		liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
	return liquid


func _generate_water() -> void:
	var liquid := _get_liquid_system()
	if liquid == null:
		push_warning("WorldGenerator: LiquidSystem fehlt unter Terrain/LiquidSystem.")
		return
	liquid.bind_world_generator(self)
	liquid.begin_batch_writes()
	var water_stats := WaterGeneration.generate(self, liquid)
	water_stats["ocean_cells"] = WaterGeneration.generate_ocean(self, liquid)
	water_stats["danger_pools"] = WaterGeneration.generate_danger_water(self, liquid)
	liquid.end_batch_writes()
	stats["water"] = water_stats


func _generate_lava() -> void:
	var liquid := _get_liquid_system()
	if liquid == null:
		push_warning("WorldGenerator: LiquidSystem fehlt, Lava wird nicht platziert.")
		return
	liquid.bind_world_generator(self)
	liquid.begin_batch_writes()
	var lava_stats := LavaGeneration.generate(self, liquid)
	liquid.end_batch_writes()
	stats["lava"] = lava_stats


func _finalize_liquids() -> void:
	var liquid := _get_liquid_system()
	if liquid == null:
		return
	liquid.resolve_contacts()
	liquid.finalize_generation()


func _finalize_water() -> void:
	_finalize_liquids()
