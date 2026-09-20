class_name VegetationSystem
extends Node2D

## Gehoert an: World/VegetationSystem.
## Oberflaechenpflanzen als Dekoration: MultiMesh + Wind-Shader, keine Kollision.

const TILE_SIZE := 16
const AIR := 0
const WIND_SHADER := preload("res://shaders/plant_wind.gdshader")

@export var catalog: PlantCatalog
@export var item_catalog: ItemCatalog
@export var item_drop_scene: PackedScene

var plants: Dictionary = {}

var _world: WorldGenerator
var _tilemap: TileMapLayer
var _drops_parent: Node2D
var _meshes: Dictionary = {}
var _wind_material: ShaderMaterial
var _dirty: bool = false


func _ready() -> void:
	add_to_group("vegetation_system")
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world = get_parent() as WorldGenerator
	_tilemap = get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	_drops_parent = get_node_or_null("../ItemDrops") as Node2D
	_wind_material = ShaderMaterial.new()
	_wind_material.shader = WIND_SHADER
	_wind_material.set_shader_parameter("wind_speed", 1.35)
	_wind_material.set_shader_parameter("wind_pixels", 1.55)
	set_process(false)


func _process(_delta: float) -> void:
	if not _dirty:
		set_process(false)
		return
	_dirty = false
	_rebuild_meshes()
	set_process(false)


func generate_from_world(world: WorldGenerator) -> void:
	_world = world
	plants.clear()
	if catalog == null or world == null:
		_mark_dirty()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = world.get_seed() + 9029
	var cover := FastNoiseLite.new()
	cover.seed = world.get_seed() + 77
	cover.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cover.frequency = 0.028
	var planted := 0
	var x := world.world_edge_width + 2
	while x < world.world_width - world.world_edge_width - 2:
		var field := cover.get_noise_1d(float(x))
		if field > 0.42:
			x += rng.randi_range(2, 5)
			continue
		var density := 0.20
		if field < -0.28:
			density = 0.48
		elif field < 0.05:
			density = 0.32
		if rng.randf() > density:
			x += rng.randi_range(1, 2)
			continue
		var biome := world.get_surface_biome(x)
		var plant := catalog.pick_for_biome(biome, rng)
		if plant == null:
			x += 1
			continue
		if _try_place_generated(world, rng, x, plant):
			planted += 1
			if rng.randf() < plant.cluster_chance:
				var want := plant.cluster_size(rng)
				var extra := 1
				var attempts := 0
				while extra < want and attempts < want * 5:
					attempts += 1
					var cx := x + rng.randi_range(-3, 3)
					if _try_place_generated(world, rng, cx, plant):
						planted += 1
						extra += 1
			x += rng.randi_range(1, 4)
		else:
			x += 1
	world.stats["plants"] = planted
	_mark_dirty()


func has_plant(cell: Vector2i) -> bool:
	return plants.has(cell)


func get_plant(cell: Vector2i) -> PlantData:
	if not plants.has(cell) or catalog == null:
		return null
	return catalog.get_by_id(plants[cell]["id"])


func harvest_time(cell: Vector2i) -> float:
	var plant := get_plant(cell)
	if plant == null:
		return 0.06
	return maxf(plant.harvest_time, 0.02)


func can_place(cell: Vector2i, plant: PlantData) -> bool:
	if plant == null or not plant.can_be_planted:
		return false
	if plants.has(cell):
		return false
	if not _is_air(cell):
		return false
	var ground := _ground_id(cell)
	return plant.allows_ground(ground)


func try_plant(cell: Vector2i, plant: PlantData) -> bool:
	if not can_place(cell, plant):
		return false
	_add_record(cell, plant, true, 0.0, Vector2.ZERO)
	_mark_dirty()
	return true


func harvest(cell: Vector2i, player: Player = null) -> bool:
	if not plants.has(cell):
		return false
	var plant := get_plant(cell)
	plants.erase(cell)
	_mark_dirty()
	if plant != null and plant.can_be_harvested and plant.item_id >= 0:
		var amount := 1
		if player != null and player.stats != null:
			amount = maxi(1, int(round(player.stats.harvest_amount())))
		_spawn_drop(plant.item_id, amount, _cell_center(cell))
	if player != null and player.has_method("play_sfx"):
		player.play_sfx(&"BlockBreak", 0.0, &"grass")
	return true


func on_block_removed(cell: Vector2i) -> void:
	var above := cell + Vector2i.UP
	if plants.has(above) and not _still_supported(above):
		harvest(above, null)
	if plants.has(cell):
		harvest(cell, null)


func on_block_placed(cell: Vector2i) -> void:
	if plants.has(cell):
		harvest(cell, null)


func to_save_dict() -> Dictionary:
	var generated: Array = []
	var planted: Array = []
	for cell in plants:
		var rec: Dictionary = plants[cell]
		var entry := {"x": cell.x, "y": cell.y, "id": String(rec["id"])}
		if bool(rec.get("planted", false)):
			planted.append(entry)
		else:
			generated.append(entry)
	return {"generated": generated, "planted": planted}


func from_save_dict(data: Dictionary) -> void:
	plants.clear()
	for entry in data.get("generated", []):
		_restore_entry(entry, false)
	for entry in data.get("planted", []):
		_restore_entry(entry, true)
	_mark_dirty()


func _restore_entry(entry: Variant, planted: bool) -> void:
	if typeof(entry) != TYPE_DICTIONARY or catalog == null:
		return
	var rec: Dictionary = entry
	var plant := catalog.get_by_id(StringName(str(rec.get("id", ""))))
	if plant == null:
		return
	_add_record(Vector2i(int(rec.get("x", 0)), int(rec.get("y", 0))), plant, planted, 0.0, Vector2.ZERO)


func _try_place_generated(world: WorldGenerator, rng: RandomNumberGenerator, tile_x: int, plant: PlantData) -> bool:
	if plant == null:
		return false
	if tile_x < world.world_edge_width + 1 or tile_x >= world.world_width - world.world_edge_width - 1:
		return false
	if world.is_spawn_pad_column(tile_x):
		return false
	var ground_y := world.get_surface_y(tile_x)
	var ground_id := world.get_block_id(tile_x, ground_y)
	if not plant.allows_ground(ground_id):
		return false
	if not plant.allows_biome(world.get_surface_biome(tile_x)):
		return false
	if world.is_hut_column(tile_x):
		return false
	var cell := Vector2i(tile_x, ground_y - 1)
	if cell.y < 0:
		return false
	if world.get_block_id(cell.x, cell.y) != AIR:
		return false
	if plants.has(cell):
		return false
	if plants.has(Vector2i(tile_x - 1, cell.y)) and rng.randf() > plant.cluster_chance:
		return false
	var phase := rng.randf() * TAU
	var offset := Vector2(rng.randf_range(-2.2, 2.2), 0.0)
	_add_record(cell, plant, false, phase, offset)
	return true


func _add_record(cell: Vector2i, plant: PlantData, planted: bool, phase: float, offset: Vector2) -> void:
	plants[cell] = {
		"id": plant.plant_id,
		"planted": planted,
		"phase": phase,
		"offset": offset,
		"wind": plant.wind_strength,
	}


func _mark_dirty() -> void:
	_dirty = true
	set_process(true)


func _rebuild_meshes() -> void:
	var groups: Dictionary = {}
	for cell in plants:
		var rec: Dictionary = plants[cell]
		var pid: StringName = rec["id"]
		if not groups.has(pid):
			groups[pid] = []
		groups[pid].append(cell)
	for pid in _meshes.keys():
		if not groups.has(pid):
			var leftover: MultiMeshInstance2D = _meshes[pid]
			leftover.visible = false
			leftover.multimesh.instance_count = 0
	for pid in groups:
		var plant := catalog.get_by_id(pid) if catalog != null else null
		if plant == null or plant.world_texture == null:
			continue
		var mi := _ensure_mesh(pid, plant.world_texture)
		var cells: Array = groups[pid]
		var mm := mi.multimesh
		mm.instance_count = cells.size()
		var tex_size := plant.world_texture.get_size()
		for i in cells.size():
			var cell: Vector2i = cells[i]
			var rec: Dictionary = plants[cell]
			var bottom := _cell_bottom(cell)
			var origin := bottom + Vector2(rec["offset"]) - Vector2(0.0, tex_size.y * 0.5)
			var xf := Transform2D(0.0, origin)
			mm.set_instance_transform_2d(i, xf)
			mm.set_instance_custom_data(i, Color(float(rec["phase"]), float(rec["wind"]), 0.0, 1.0))
		mi.visible = cells.size() > 0


func _ensure_mesh(plant_id: StringName, tex: Texture2D) -> MultiMeshInstance2D:
	if _meshes.has(plant_id):
		return _meshes[plant_id]
	var mi := MultiMeshInstance2D.new()
	mi.name = "Mesh_%s" % String(plant_id)
	mi.texture = tex
	mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mi.material = _wind_material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = tex.get_size()
	mm.mesh = quad
	mi.multimesh = mm
	add_child(mi)
	_meshes[plant_id] = mi
	return mi


func _still_supported(cell: Vector2i) -> bool:
	var plant := get_plant(cell)
	if plant == null:
		return false
	return _is_air(cell) and plant.allows_ground(_ground_id(cell))


func _is_air(cell: Vector2i) -> bool:
	if _tilemap != null:
		return _tilemap.get_cell_source_id(cell) == -1
	if _world != null:
		return _world.get_block_id(cell.x, cell.y) == AIR
	return true


func _ground_id(cell: Vector2i) -> int:
	var ground := cell + Vector2i.DOWN
	if _tilemap != null and _world != null:
		var block := _world.block_catalog.get_by_atlas(_tilemap.get_cell_atlas_coords(ground)) if _world.block_catalog != null and _tilemap.get_cell_source_id(ground) != -1 else null
		if block != null:
			return block.id
	if _world != null:
		return _world.get_block_id(ground.x, ground.y)
	return AIR


func _cell_center(cell: Vector2i) -> Vector2:
	if _tilemap == null or _tilemap.tile_set == null:
		return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) * 0.5
	return _tilemap.to_global(_tilemap.map_to_local(cell))


func _cell_bottom(cell: Vector2i) -> Vector2:
	return _cell_center(cell) + Vector2(0.0, float(TILE_SIZE) * 0.5)


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
