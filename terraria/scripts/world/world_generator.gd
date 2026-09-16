class_name WorldGenerator
extends Node2D

## Gehoert an: World-Wurzelnode in res://scenes/world/world.tscn
##
## Erzeugt die komplette statische Welt einmalig beim Start. Gearbeitet wird auf
## einem flachen Byte-Array (ein Block pro Tile, 0 = Luft); erst ganz am Ende
## wandert das Ergebnis in einem Rutsch in den TileMapLayer. Dadurch wird jedes
## Tile nur einmal an die Engine uebergeben, auch wenn Hoehlen, Erze und Huetten
## denselben Platz mehrfach ueberschreiben.

## Block-IDs aus res://resources/blocks/. Die Zahlen sind die BlockData.id und
## die einzige Stelle, an der der Generator Blocktypen benennt.
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

## Kantenlaenge eines Welt-Tiles in Pixeln, identisch zum TileSet.
const TILE_SIZE := 16

## Erz-Adern ersetzen ausschliesslich diese Blocktypen.
const STONE_LIKE: Array[int] = [STONE, GRANITE, SLATE]

const NEIGHBORS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

@export_group("Weltgroesse")
@export var world_width: int = 800
@export var world_height: int = 240
## 0 erzeugt bei jedem Start eine andere Welt, jeder andere Wert ist reproduzierbar.
@export var world_seed: int = 12345

@export_group("Oberflaeche")
@export var base_surface_y: int = 72
@export var surface_amplitude: int = 14
@export var dirt_depth_min: int = 4
@export var dirt_depth_max: int = 8

@export_group("Sand")
@export var sand_region_min_width: int = 6
@export var sand_region_max_width: int = 30
@export var sand_depth_min: int = 3
@export var sand_depth_max: int = 6

@export_group("Hoehlen")
## Anteil des aushoehlbaren Untergrunds, der zu Luft wird. Der Schwellwert des
## Noise wird daraus gemessen statt geraten.
@export_range(0.0, 0.5, 0.01) var cave_fill_ratio: float = 0.17
## Tiefe unter der Oberflaeche, in der Hoehlen stark unterdrueckt werden.
@export var cave_surface_guard: int = 12
@export var cave_entrance_min: int = 3
@export var cave_entrance_max: int = 8

@export_group("Baeume und Huetten")
@export var tree_min_height: int = 4
@export var tree_max_height: int = 7
@export var tree_min_spacing: int = 4
@export var tree_max_spacing: int = 9
@export var hut_count_target: int = 9
@export var hut_min_spacing: int = 70

@export_group("Spawn und Rand")
@export var spawn_clear_radius: int = 20
@export var world_edge_width: int = 3
@export var bedrock_rows: int = 5

@export_group("Referenzen")
@export var block_catalog: BlockCatalog
@export var ore_catalog: OreCatalog
## Nur fuer Screenshots/Debug. Aendert keine Spawnraten.
@export var debug_place_ore_row: bool = false

## Vom Generator ermittelter Startpunkt. Main setzt den Player darauf.
var player_spawn_position: Vector2 = Vector2.ZERO
var spawn_tile: Vector2i = Vector2i.ZERO
## Kennzahlen der letzten Generierung, dienen dem DebugHUD und der Abnahme.
var stats: Dictionary = {}

var _tiles: PackedByteArray
var _surface: PackedInt32Array
var _is_sand_column: PackedByteArray
var _hut_blocked: PackedByteArray
var _used_seed: int = 0
var _cave_noise: FastNoiseLite
var _cave_threshold: float = 1.0

@onready var _tilemap: TileMapLayer = $Terrain/TileMapLayer


func _ready() -> void:
	add_to_group("world_generator")
	generate_world()


func generate_world() -> void:
	var start_usec := Time.get_ticks_usec()
	_used_seed = world_seed if world_seed != 0 else randi()

	_tiles = PackedByteArray()
	_tiles.resize(world_width * world_height)
	_surface = PackedInt32Array()
	_surface.resize(world_width)
	_is_sand_column = PackedByteArray()
	_is_sand_column.resize(world_width)
	_hut_blocked = PackedByteArray()
	_hut_blocked.resize(world_width)
	stats = {}

	generate_surface()
	generate_ground_layers()
	generate_sand_regions()
	generate_caves()
	generate_rock_variation()
	generate_world_bounds()
	cleanup_surface()
	find_spawn_position()
	generate_ores()
	generate_cave_entrances()
	generate_huts()
	generate_trees()
	_align_underground_backdrop()
	_commit_to_tilemap()
	if debug_place_ore_row:
		place_progression_test_row()
	_place_combat_dummy()

	stats["seed"] = _used_seed
	stats["width"] = world_width
	stats["height"] = world_height
	stats["generation_ms"] = (Time.get_ticks_usec() - start_usec) / 1000.0
	print("[WorldGenerator] ", stats)


# --------------------------------------------------------------------- Zugriff

func get_surface_y(tile_x: int) -> int:
	if tile_x < 0 or tile_x >= world_width:
		return base_surface_y
	return _surface[tile_x]


## Grobe Regionsbezeichnung fuer das DebugHUD.
func get_region(tile: Vector2i) -> String:
	if tile.x < 0 or tile.x >= world_width:
		return "Ausserhalb"
	if tile.y > _surface[tile.x] + 4:
		return "Underground"
	if _is_sand_column[tile.x] != 0:
		return "Sand Area"
	return "Grassland"


func get_seed() -> int:
	return _used_seed


# ------------------------------------------------------------------- Oberflaeche

func generate_surface() -> void:
	# Zwei Frequenzen: breite Huegel plus kleine Wellen, damit die Wiese weder
	# schnurgerade noch zerklueftet wirkt.
	var hills := _make_noise(1, 0.0045, 3)
	var bumps := _make_noise(2, 0.02, 2)
	var min_y := base_surface_y - surface_amplitude
	var max_y := base_surface_y + surface_amplitude
	for x in world_width:
		var value := hills.get_noise_1d(float(x)) + bumps.get_noise_1d(float(x)) * 0.35
		var y := base_surface_y + int(roundf(value * float(surface_amplitude)))
		_surface[x] = clampi(y, min_y, max_y)


func generate_ground_layers() -> void:
	var dirt_noise := _make_noise(3, 0.03, 1)
	for x in world_width:
		var top := _surface[x]
		var span := float(dirt_depth_max - dirt_depth_min)
		var dirt_depth := dirt_depth_min + int(roundf((dirt_noise.get_noise_1d(float(x)) * 0.5 + 0.5) * span))
		_set_tile(x, top, GRASS)
		for y in range(top + 1, mini(top + 1 + dirt_depth, world_height)):
			_set_tile(x, y, DIRT)
		for y in range(top + 1 + dirt_depth, world_height):
			_set_tile(x, y, STONE)


func generate_sand_regions() -> void:
	var rng := _rng(11)
	var region_count := clampi(world_width / 100, 4, 10)
	var regions := 0
	var columns: Array[int] = []
	for i in region_count:
		var width := rng.randi_range(sand_region_min_width, sand_region_max_width)
		var start := rng.randi_range(world_edge_width, maxi(world_edge_width, world_width - width - world_edge_width))
		var depth := rng.randi_range(sand_depth_min, sand_depth_max)
		for x in range(start, mini(start + width, world_width)):
			_is_sand_column[x] = 1
			var top := _surface[x]
			for y in range(top, mini(top + depth, world_height)):
				if _get_tile(x, y) in [GRASS, DIRT]:
					_set_tile(x, y, SAND)
		columns.append(start + width / 2)
		regions += 1
	stats["sand_regions"] = regions
	stats["sand_columns"] = columns


# ----------------------------------------------------------------------- Hoehlen

func generate_caves() -> void:
	var noise := _make_noise(21, 0.045, 2)
	var threshold := _measure_cave_threshold(noise)
	_cave_noise = noise
	_cave_threshold = threshold
	var eligible := 0
	var carved := 0
	var floor_y := world_height - bedrock_rows
	for x in range(world_edge_width, world_width - world_edge_width):
		var top := _surface[x]
		for y in range(top + 1, floor_y):
			eligible += 1
			var depth := y - top
			var local_threshold := threshold
			if depth < cave_surface_guard:
				# Nahe der Oberflaeche praktisch unerreichbar, nach unten weich auslaufend.
				local_threshold += (1.0 - float(depth) / float(cave_surface_guard)) * 2.0
			if noise.get_noise_2d(float(x), float(y)) > local_threshold:
				_set_tile(x, y, AIR)
				carved += 1
	stats["cave_ratio"] = float(carved) / float(maxi(eligible, 1))
	stats["cave_tiles"] = carved


## Schwellwert aus echten Noise-Werten ablesen, damit der Aushoehlungsgrad
## unabhaengig von Frequenz und Seed im gewuenschten Bereich landet.
func _measure_cave_threshold(noise: FastNoiseLite) -> float:
	var samples := PackedFloat32Array()
	var floor_y := world_height - bedrock_rows
	for x in range(world_edge_width, world_width - world_edge_width, 7):
		for y in range(_surface[x] + cave_surface_guard, floor_y, 5):
			samples.append(noise.get_noise_2d(float(x), float(y)))
	if samples.is_empty():
		return 1.0
	samples.sort()
	var index := int((1.0 - cave_fill_ratio) * float(samples.size() - 1))
	return samples[clampi(index, 0, samples.size() - 1)]


## Laeuft nach der Spawn-Suche, damit kein Schacht im Startbereich aufreisst.
func generate_cave_entrances() -> void:
	var noise := _cave_noise
	var threshold := _cave_threshold
	var rng := _rng(22)
	var count := rng.randi_range(cave_entrance_min, cave_entrance_max)
	var made := 0
	for i in count:
		var x := rng.randi_range(world_edge_width + 5, world_width - world_edge_width - 5)
		if absi(x - spawn_tile.x) < spawn_clear_radius:
			continue
		# Der Schacht endet, sobald er die Noise-Hoehlenschicht erreicht.
		var y := _surface[x]
		var max_depth := cave_surface_guard + 14
		var drift := 0
		for step in max_depth:
			var radius := 1 if step < 2 else rng.randi_range(1, 2)
			for dx in range(-radius, radius + 1):
				for dy in range(0, 2):
					_set_tile(x + drift + dx, y + step + dy, AIR)
			if rng.randf() < 0.35:
				drift += rng.randi_range(-1, 1)
			if step > cave_surface_guard and noise.get_noise_2d(float(x + drift), float(y + step)) > threshold:
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
			var depth := y - top
			if depth > 40 and slate_noise.get_noise_2d(float(x), float(y)) > 0.33:
				_set_tile(x, y, SLATE)
				slate += 1
			elif depth > 14 and granite_noise.get_noise_2d(float(x), float(y)) > 0.38:
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


func generate_ore(ore: OreData, rng: RandomNumberGenerator) -> void:
	if ore == null or ore.block_id < 1:
		return
	var area := float(world_width * world_height) / 1000.0
	var vein_count := maxi(1, int(round(area * ore.rarity_weight)))
	if ore.special_spawn:
		vein_count = maxi(1, int(round(area * ore.rarity_weight)))
	var placed := 0
	var veins := 0
	for i in vein_count:
		var start := _find_ore_start_for(ore, rng)
		if start.x < 0:
			continue
		var size := rng.randi_range(ore.vein_min_size, ore.vein_max_size)
		var done := _carve_vein(rng, start, size, ore)
		if done > 0:
			placed += done
			veins += 1
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
		var x := rng.randi_range(world_edge_width, world_width - world_edge_width - 1)
		if absi(x - spawn_tile.x) < spawn_clear_radius:
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


## Sucht ein Start-Tile in passender Tiefe, das noch Stein ist.
func _find_ore_start(rng: RandomNumberGenerator, min_depth: int) -> Vector2i:
	for attempt in 12:
		var x := rng.randi_range(world_edge_width, world_width - world_edge_width - 1)
		var min_y := _surface[x] + min_depth
		var max_y := world_height - bedrock_rows - 1
		if min_y >= max_y:
			continue
		var y := rng.randi_range(min_y, max_y)
		if _get_tile(x, y) in STONE_LIKE:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## Random Walk plus Nachbarwachstum. Luft, Baeume und Huetten bleiben unangetastet.
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
	# Die Randwand endet nicht am Weltdach, sondern deutlich ueber dem hoechsten
	# Gelaende - hoch genug zum Einsperren, ohne als Turm in den Himmel zu ragen.
	var wall_top := maxi(base_surface_y - surface_amplitude - 24, 0)
	for x in world_width:
		var is_edge := x < world_edge_width or x >= world_width - world_edge_width
		if is_edge:
			for y in range(wall_top, world_height):
				_set_tile(x, y, STONE)
			_surface[x] = wall_top
		for y in range(world_height - bedrock_rows, world_height):
			_set_tile(x, y, BEDROCK)


# ------------------------------------------------------------------- Aufraeumen

func cleanup_surface() -> void:
	var removed := 0
	# Einzelne schwebende Bloecke ohne jeden festen Nachbarn entfernen.
	for x in range(world_edge_width, world_width - world_edge_width):
		for y in range(0, world_height - bedrock_rows):
			if _get_tile(x, y) == AIR:
				continue
			if _get_tile(x - 1, y) == AIR and _get_tile(x + 1, y) == AIR \
			and _get_tile(x, y - 1) == AIR and _get_tile(x, y + 1) == AIR:
				_set_tile(x, y, AIR)
				removed += 1

	# Einzelne 1-Tile-Zacken an der Oberflaeche abtragen.
	for pass_index in 2:
		for x in range(world_edge_width + 1, world_width - world_edge_width - 1):
			var top := _find_top_solid(x)
			if top < 0:
				continue
			var left := _find_top_solid(x - 1)
			var right := _find_top_solid(x + 1)
			if left - top >= 2 and right - top >= 2:
				_set_tile(x, top, AIR)
				removed += 1

	# Oberste feste Erde wieder begruenen, falls Hoehlen die Grasnarbe gefressen haben.
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
		# Gras darf nur die Oberkante sein, darunter wieder Erde.
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
	var middle := world_width / 2
	var found := -1
	for offset in range(0, world_width / 2):
		if _is_flat_grass(middle + offset, 8):
			found = middle + offset
			break
		if _is_flat_grass(middle - offset, 8):
			found = middle - offset
			break
	if found < 0:
		found = middle
	spawn_tile = Vector2i(found, _surface[found] - 1)
	# Fuesse stehen auf der Oberkante des Bodenblocks.
	player_spawn_position = _ground_position(found)
	stats["spawn_tile"] = spawn_tile
	stats["spawn_position"] = player_spawn_position


func _is_flat_grass(x: int, radius: int) -> bool:
	if x - radius < world_edge_width or x + radius >= world_width - world_edge_width:
		return false
	var lowest := world_height
	var highest := -1
	for cx in range(x - radius, x + radius + 1):
		var top := _surface[cx]
		if _get_tile(cx, top) != GRASS:
			return false
		lowest = mini(lowest, top)
		highest = maxi(highest, top)
	return highest - lowest <= 2


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
		if rng.randf() < 0.55:
			var species := trees.pick_species_for_column(rng, x, _surface[x], base_surface_y)
			if _plant_tree(rng, x, species, trees):
				planted += 1
				match species.tree_id:
					&"oak":
						oak_n += 1
					&"birch":
						birch_n += 1
					&"pine":
						pine_n += 1
				x += rng.randi_range(tree_min_spacing, tree_max_spacing)
				continue
		x += rng.randi_range(2, 4)
	stats["trees"] = planted
	stats["trees_oak"] = oak_n
	stats["trees_birch"] = birch_n
	stats["trees_pine"] = pine_n


func _plant_tree(rng: RandomNumberGenerator, x: int, species: TreeData, trees: TreeSystem) -> bool:
	if species == null:
		return false
	if absi(x - spawn_tile.x) < spawn_clear_radius:
		return false
	if _hut_blocked[x] != 0:
		return false
	var ground := _surface[x]
	if _get_tile(x, ground) != GRASS:
		return false
	if absi(_surface[x - 1] - ground) > 1 or absi(_surface[x + 1] - ground) > 1:
		return false
	return trees.plant_generated_tree(self, rng, x, species)


# ----------------------------------------------------------------------- Huetten

func generate_huts() -> void:
	var rng := _rng(61)
	var placed: Array[int] = []
	var attempts := 0
	while placed.size() < hut_count_target and attempts < 600:
		attempts += 1
		var width := rng.randi_range(7, 12)
		var x := rng.randi_range(world_edge_width + 12, world_width - world_edge_width - width - 12)
		if absi(x - spawn_tile.x) < spawn_clear_radius + width:
			continue
		var too_close := false
		for other in placed:
			if absi(other - x) < hut_min_spacing:
				too_close = true
				break
		if too_close:
			continue
		if not _is_flat_enough(x, width):
			continue
		_build_hut(rng, x, width)
		placed.append(x)
	stats["huts"] = placed.size()
	stats["hut_columns"] = placed


func _is_flat_enough(x: int, width: int) -> bool:
	var lowest := world_height
	var highest := -1
	for cx in range(x, x + width):
		var top := _surface[cx]
		var block := _get_tile(cx, top)
		if block != GRASS and block != DIRT and block != SAND:
			return false
		lowest = mini(lowest, top)
		highest = maxi(highest, top)
	return highest - lowest <= 2


func _build_hut(rng: RandomNumberGenerator, x: int, width: int) -> void:
	var interior := rng.randi_range(4, 5)
	var base_y := world_height
	for cx in range(x, x + width):
		base_y = mini(base_y, _surface[cx])

	# Senken unter der Huette auffuellen, damit der Boden nirgends schwebt.
	for cx in range(x, x + width):
		for y in range(base_y, _surface[cx]):
			_set_tile(cx, y, DIRT)
		_surface[cx] = base_y

	var floor_y := base_y - 1
	var roof_y := floor_y - interior - 1
	# Bauplatz und direkten Umkreis von Baeumen befreien, sonst ragen Kronen
	# durch Dach und Waende.
	for cx in range(x - 2, x + width + 2):
		if cx >= 0 and cx < world_width:
			_hut_blocked[cx] = 1
		for y in range(roof_y - 4, floor_y + 1):
			var existing := _get_tile(cx, y)
			if existing == AIR or existing == WOOD or existing == LEAVES or _is_tree_block(existing):
				_set_tile(cx, y, AIR)

	for cx in range(x, x + width):
		_set_tile(cx, floor_y, WOOD)
		_set_tile(cx, roof_y, WOOD)
	for y in range(roof_y, floor_y + 1):
		_set_tile(x, y, WOOD)
		_set_tile(x + width - 1, y, WOOD)

	# Tuer: 3 Tiles hoch, damit der 42 px hohe Player aufrecht hineinlaeuft.
	var door_x := x if rng.randf() < 0.5 else x + width - 1
	for i in range(1, 4):
		_set_tile(door_x, floor_y - i, AIR)


# ------------------------------------------------------------------- Uebergabe

func _commit_to_tilemap() -> void:
	if _tilemap == null or block_catalog == null:
		push_error("WorldGenerator: TileMapLayer oder BlockCatalog fehlt.")
		return
	block_catalog.ensure_tileset_tiles(_tilemap.tile_set)
	_tilemap.clear()
	var source_id := block_catalog.terrain_source_id(_tilemap.tile_set)
	# Block-ID -> Atlas-Koordinate einmal aufloesen statt pro Tile zu suchen.
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


func _terrain_source_id() -> int:
	if block_catalog != null and _tilemap != null:
		return block_catalog.terrain_source_id(_tilemap.tile_set)
	var tileset := _tilemap.tile_set if _tilemap != null else null
	if tileset == null or tileset.get_source_count() == 0:
		return 0
	return tileset.get_source_id(0)


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


func _is_tree_block(block_id: int) -> bool:
	return block_id >= OAK_WOOD and block_id <= PINE_SAPLING


func _align_underground_backdrop() -> void:
	var backdrop := get_node_or_null("Background/UndergroundBackdrop") as UndergroundBackdrop
	if backdrop == null:
		return
	backdrop.set_profile(_surface, TILE_SIZE, float(world_height * TILE_SIZE))


## Der Testgegner steht sonst im neuen Terrain fest.
func _place_combat_dummy() -> void:
	var dummy := get_node_or_null("Enemies/CombatDummy") as Node2D
	if dummy == null:
		return
	var x := clampi(spawn_tile.x + 14, world_edge_width, world_width - world_edge_width - 1)
	dummy.global_position = _ground_position(x)


## Weltkoordinate in Spaltenmitte, auf der Oberkante des obersten Bodenblocks.
func ground_world_position(tile_x: int) -> Vector2:
	return _ground_position(tile_x)


func _ground_position(tile_x: int) -> Vector2:
	var size := float(TILE_SIZE)
	return Vector2(float(tile_x) * size + size * 0.5, float(_surface[tile_x]) * size - 1.0)


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
