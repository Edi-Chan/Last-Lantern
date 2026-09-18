class_name BuildingManager
extends Node2D

## Spezialgebaeude: Placement, Instanzen, State, Interior. Statik bleibt beim StructuralManager.

signal building_created(instance_id: String)
signal building_state_changed(instance_id: String, state: int)
signal building_destroyed(instance_id: String)
signal building_entered(instance_id: String)
signal building_exited(instance_id: String)

const GROUP := &"building_manager"
const INTERIOR_ORIGIN := Vector2(96, -4200)
const AREA_WORLD := &"WORLD"
const AREA_FORGE_INTERIOR := &"FORGE_INTERIOR"

@export var block_catalog: BlockCatalog
@export var item_catalog: ItemCatalog
@export var default_blueprint: BuildingBlueprintResource

var current_area: StringName = AREA_WORLD
var interior_building_id: String = ""

var _instances: Dictionary = {}
var _cell_index: Dictionary = {}
var _exteriors: Dictionary = {}
var _next_index: int = 1
var _tilemap: TileMapLayer
var _preview: BuildingPlacementPreview
var _hud: BuildingHud
var _interior: Node2D
var _collapsing_cells: Dictionary = {}
var _busy: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	_tilemap = get_node_or_null("../Terrain/TileMapLayer") as TileMapLayer
	if _tilemap == null:
		_tilemap = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	_preview = BuildingPlacementPreview.new()
	_preview.name = "BuildingPreview"
	add_child(_preview)
	call_deferred("_bind")
	call_deferred("_attach_hud")


func _attach_hud() -> void:
	if _hud == null:
		_hud = BuildingHud.new()
		_hud.name = "BuildingHud"
	var main := get_tree().current_scene
	if main == null:
		return
	if _hud.get_parent() != main:
		if _hud.get_parent() != null:
			_hud.reparent(main)
		else:
			main.add_child(_hud)


func _bind() -> void:
	var structural := _structural()
	if structural != null:
		if not structural.structure_changed.is_connected(_on_structure_changed):
			structural.structure_changed.connect(_on_structure_changed)
		if not structural.structure_collapsed.is_connected(_on_structure_collapsed):
			structural.structure_collapsed.connect(_on_structure_collapsed)
		if not structural.structure_became_unstable.is_connected(_on_structure_unstable):
			structural.structure_became_unstable.connect(_on_structure_unstable)


func is_player_inside() -> bool:
	return current_area != AREA_WORLD


func selected_blueprint(inventory: Inventory) -> BuildingBlueprintResource:
	if inventory == null:
		return null
	var item := inventory.get_selected_item()
	if item == null or not item.has_method("is_building_blueprint"):
		return null
	if not bool(item.call("is_building_blueprint")):
		return null
	var bp: BuildingBlueprintResource = item.get("blueprint") as BuildingBlueprintResource
	if bp != null:
		return bp
	return default_blueprint


func update_hotbar_preview(inventory: Inventory, hover: Vector2i, in_range: bool) -> bool:
	var blueprint := selected_blueprint(inventory)
	if blueprint == null:
		if _preview != null:
			_preview.hide_preview()
		if _hud != null:
			_hud.hide_costs()
		return false
	var report := evaluate_placement(blueprint, hover, inventory, in_range)
	_show_cost_panel(blueprint, inventory, report)
	var cells: Array = report.get("cells", [])
	var color: Color = report.get("color", Color(0.9, 0.25, 0.2, 0.4))
	if _preview != null:
		_preview.show_cells(_tilemap, cells, color)
	return true


func try_place_from_hotbar(inventory: Inventory, hover: Vector2i, in_range: bool) -> bool:
	if _busy:
		return false
	var blueprint := selected_blueprint(inventory)
	if blueprint == null:
		return false
	var report := evaluate_placement(blueprint, hover, inventory, in_range)
	if not bool(report.get("ok", false)):
		if _hud != null:
			_hud.toast(str(report.get("hint", "Hier kann nicht gebaut werden.")))
		return false
	return _commit_build(blueprint, report, inventory)


func evaluate_placement(blueprint: BuildingBlueprintResource, hover: Vector2i, inventory: Inventory, _in_range: bool) -> Dictionary:
	var origin := _snap_origin(hover, blueprint)
	var layout: Array = blueprint.get_layout()
	var cells: Array = []
	for spec in layout:
		var offset: Vector2i = spec["offset"]
		cells.append(origin + offset)
	var resources := _resource_report(blueprint, inventory)
	var resources_ok: bool = bool(resources["ok"])
	var problems: PackedStringArray = PackedStringArray()
	if not _ground_ok(blueprint, origin):
		problems.append("ground")
	var volume_reason := _volume_problem(blueprint, origin, layout)
	if not volume_reason.is_empty() and volume_reason != "ground":
		problems.append(volume_reason)
	if blueprint.forbid_lantern_overlap and _overlaps_lantern(origin, layout):
		problems.append("lantern")
	if _overlaps_building(origin, layout):
		problems.append("building")
	if blueprint.forbid_player_overlap and not blueprint.visual_background_only and _overlaps_player(origin, layout):
		problems.append("player")
	if not resources_ok:
		problems.append("resources")
	var reason := "ok"
	var grade := 1
	if not problems.is_empty():
		reason = problems[0]
		grade = 3
	elif _ground_variance(blueprint, origin) > 0:
		grade = 2
	var hint := _placement_hint(problems, str(resources["missing"]))
	var color := Color(0.25, 0.9, 0.35, 0.42)
	if grade == 2:
		color = Color(0.95, 0.85, 0.2, 0.45)
	elif grade == 3:
		color = Color(0.95, 0.2, 0.15, 0.45)
	return {
		"ok": reason == "ok",
		"reason": reason,
		"problems": problems,
		"hint": hint,
		"grade": grade,
		"color": color,
		"origin": origin,
		"cells": cells,
		"layout": layout,
		"resources_ok": resources_ok,
		"resource_lines": resources["lines"],
		"missing": resources["missing"],
	}


func try_enter(instance_id: String) -> void:
	if _busy or is_player_inside():
		return
	var inst: BuildingInstance = _instances.get(instance_id)
	if inst == null:
		return
	_refresh_state(inst)
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if fog != null and fog.is_fog_active():
		_lock_door(inst, "⚠ Während der Finsternis geschlossen.")
		if _hud != null:
			_hud.toast("⚠ Während der Finsternis geschlossen.")
		return
	if inst.state == BuildingBlueprintResource.BuildingState.DESTROYED or not inst.core_intact:
		_lock_door(inst, "⚠ Schmiede zerstört")
		if _hud != null:
			_hud.toast("⚠ Schmiede zerstört")
		return
	if inst.state == BuildingBlueprintResource.BuildingState.CRITICAL or not inst.entrance_ok:
		_lock_door(inst, "⚠ Gebäude zu schwer beschädigt.")
		if _hud != null:
			_hud.toast("⚠ Gebäude zu schwer beschädigt.")
		return
	_busy = true
	var trans := _transition()
	if trans != null:
		await trans.fade_out()
	_enter_interior(inst)
	if trans != null:
		await trans.fade_in()
	_busy = false
	building_entered.emit(inst.instance_id)


func try_exit() -> void:
	if _busy or not is_player_inside():
		return
	await _leave_interior(false)


func eject_for_fog(instance_id: String) -> void:
	if not is_player_inside():
		return
	if _hud != null:
		_hud.toast("⚠ DIE FINSTERNIS BEGINNT\nDie Schmiede wird geschlossen.", 1.6)
	await get_tree().create_timer(0.85).timeout
	await _leave_interior(true, instance_id)


func apply_loaded_player_area() -> void:
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	if current_area == AREA_FORGE_INTERIOR:
		if fog != null and fog.is_fog_active():
			var inst: BuildingInstance = _instances.get(interior_building_id)
			_force_world_visible()
			_clear_interior()
			current_area = AREA_WORLD
			if inst != null:
				_place_player_at_door(inst)
			interior_building_id = ""
			return
		var inst2: BuildingInstance = _instances.get(interior_building_id)
		if inst2 != null:
			_enter_interior(inst2)
			return
	current_area = AREA_WORLD
	_force_world_visible()
	_clear_interior()


func to_save_dict() -> Dictionary:
	var list: Array = []
	for key in _instances.keys():
		var inst: BuildingInstance = _instances[key]
		list.append(inst.to_save_dict())
	return {
		"next_index": _next_index,
		"current_area": String(current_area),
		"interior_building_id": interior_building_id,
		"instances": list,
	}


func from_save_dict(data: Dictionary) -> void:
	_clear_all_runtime()
	_next_index = int(data.get("next_index", 1))
	current_area = StringName(str(data.get("current_area", "WORLD")))
	interior_building_id = str(data.get("interior_building_id", ""))
	for entry in data.get("instances", []):
		if not (entry is Dictionary):
			continue
		var inst := BuildingInstance.from_save_dict(entry)
		_instances[inst.instance_id] = inst
		_restamp_instance(inst)
		_spawn_exterior(inst)
		_index_instance(inst)
		_refresh_state(inst)


func _commit_build(blueprint: BuildingBlueprintResource, report: Dictionary, inventory: Inventory) -> bool:
	var costs: Array = blueprint.get_costs()
	if blueprint.consume_blueprint:
		costs = costs.duplicate()
		costs.append({"item_id": blueprint.item_id, "amount": 1})
	if inventory == null or not inventory.try_consume_items(costs):
		return false
	var origin: Vector2i = report["origin"]
	var layout: Array = report["layout"]
	if not _stamp(origin, layout, blueprint):
		_refund(inventory, costs)
		return false
	var inst := BuildingInstance.new()
	inst.instance_id = _make_id(blueprint.get_type_id())
	inst.building_type = blueprint.get_type_id()
	inst.blueprint_id = blueprint.building_id
	inst.origin = origin
	inst.indestructible = blueprint.indestructible or blueprint.visual_background_only
	inst.door_cell = origin + blueprint.door_local()
	inst.return_cell = origin + blueprint.return_local()
	inst.original_count = 0
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		var block_id := int(spec["block_id"])
		inst.components[cell] = {
			"block_id": block_id,
			"role": int(spec["role"]),
			"critical": bool(spec["critical"]),
			"decoration": bool(spec["decoration"]),
			"present": true,
			"removal_cause": 0,
		}
		if int(spec["role"]) == BuildingBlueprintResource.ComponentRole.CORE:
			inst.core_cell = cell
		if block_id >= 0:
			inst.original_count += 1
	inst.present_count = inst.original_count
	_instances[inst.instance_id] = inst
	_index_instance(inst)
	_spawn_exterior(inst)
	_refresh_state(inst)
	var structural := _structural()
	if structural != null and not inst.indestructible:
		structural.call("notify_structure_changed", origin)
	building_created.emit(inst.instance_id)
	if _hud != null:
		_hud.toast("%s errichtet." % blueprint.display_name)
	return true


func _stamp(origin: Vector2i, layout: Array, blueprint: BuildingBlueprintResource = null) -> bool:
	if _tilemap == null or block_catalog == null:
		return false
	var backdrop := blueprint != null and blueprint.visual_background_only
	var veg := get_tree().get_first_node_in_group("vegetation_system") as VegetationSystem
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	if backdrop and parts != null and blueprint != null:
		_stamp_interior_background(origin, blueprint, parts)
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		var block_id := int(spec["block_id"])
		if block_id <= -1:
			if block_id == -1 and not backdrop:
				if _tilemap.get_cell_source_id(cell) != -1:
					_tilemap.erase_cell(cell)
				if veg != null:
					veg.on_block_removed(cell)
			continue
		var block := block_catalog.get_by_id(block_id)
		if block == null:
			continue
		var role := int(spec["role"])
		var solid_shell := _role_is_solid_shell(role)
		if backdrop and parts != null:
			if solid_shell:
				parts.stamp_solid(block, cell, false)
			elif _is_forge_foreground_prop(block, role):
				if block.is_building_part():
					parts.stamp_solid(block, cell, false)
				else:
					block_catalog.set_block_cell(_tilemap, cell, block)
			else:
				parts.stamp_backdrop(block, cell)
		elif parts != null and block.is_building_part():
			parts.stamp_blueprint_part(block, cell)
		else:
			block_catalog.set_block_cell(_tilemap, cell, block)
			if not backdrop:
				_notify_placed(cell)
		_notify_map(cell)
		if veg != null:
			veg.on_block_placed(cell)
	if not backdrop:
		_clear_interior_air(origin, layout)
	return true


func _stamp_interior_background(origin: Vector2i, blueprint: BuildingBlueprintResource, parts: BuildingPartSystem) -> void:
	var stone_bg := block_catalog.get_by_id(blueprint.stone_bg_id)
	var stone_wall := block_catalog.get_by_id(blueprint.stone_wall_id)
	var wood_bg := block_catalog.get_by_id(blueprint.wood_bg_id)
	var wood_wall := block_catalog.get_by_id(blueprint.wood_wall_id)
	var left := blueprint.foundation_overhang
	var right := blueprint.total_width() - 1 - blueprint.foundation_overhang
	var split := left + blueprint.shop_width()
	var shop_h := blueprint.wall_height
	for y in range(-shop_h, 0):
		for x in range(left, split):
			if stone_bg != null:
				parts.stamp_backdrop(stone_bg, origin + Vector2i(x, y))
		for x in range(split, right + 1):
			if stone_wall != null:
				parts.stamp_backdrop(stone_wall, origin + Vector2i(x, y))
	var eaves_y := -shop_h - 1
	var mid := int((split + right) * 0.5)
	var half := maxi(right - split, 1)
	var peak_h := 5
	for x in range(split, right + 1):
		var dist := absi(x - mid)
		var rise := maxi(int(round(float(half - dist) * float(peak_h) / float(half))), 0)
		for gy in range(1, rise + 1):
			var cell := origin + Vector2i(x, eaves_y - gy)
			var gable := wood_wall if (x == split or x == right or gy == rise) else wood_bg
			if gable != null:
				parts.stamp_backdrop(gable, cell)


func _is_forge_foreground_prop(block: BlockData, role: int) -> bool:
	if role == BuildingBlueprintResource.ComponentRole.SUPPORT:
		return true
	if role == BuildingBlueprintResource.ComponentRole.CORE:
		return true
	if block == null:
		return false
	if block.occupies_background_layer():
		return false
	var part := block.building_part_type
	if part == BlockData.BuildingPartType.SUPPORT \
			or part == BlockData.BuildingPartType.BEAM \
			or part == BlockData.BuildingPartType.DOOR \
			or part == BlockData.BuildingPartType.LIGHT \
			or part == BlockData.BuildingPartType.STORAGE \
			or part == BlockData.BuildingPartType.CRAFTING_STATION \
			or part == BlockData.BuildingPartType.DEFENSE \
			or part == BlockData.BuildingPartType.DECORATION:
		return true
	return block.footprint.x > 1 or block.footprint.y > 1


func _clear_interior_air(origin: Vector2i, layout: Array) -> void:
	var occupied: Dictionary = {}
	var min_x := 999999
	var max_x := -999999
	var min_y := 999999
	var max_y := -999999
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		occupied[cell] = true
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var veg := get_tree().get_first_node_in_group("vegetation_system") as VegetationSystem
	for x in range(min_x + 1, max_x):
		for y in range(min_y + 1, origin.y):
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var block := _block_at(cell)
			if block == null:
				continue
			if block.solid and block.structural_enabled:
				continue
			if block.id == 13:
				continue
			_tilemap.erase_cell(cell)
			if veg != null:
				veg.on_block_removed(cell)
			_notify_map(cell)


func _restamp_instance(inst: BuildingInstance) -> void:
	if inst.indestructible and default_blueprint != null:
		_stamp(inst.origin, default_blueprint.get_layout(), default_blueprint)
		return
	if _tilemap == null or block_catalog == null:
		return
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	for key in inst.components.keys():
		var cell: Vector2i = key
		var data: Dictionary = inst.components[key]
		if not bool(data.get("present", true)):
			continue
		var block_id := int(data.get("block_id", -1))
		if block_id < 0:
			continue
		var block := block_catalog.get_by_id(block_id)
		if block == null:
			continue
		var role := int(data.get("role", 0))
		var solid_shell := _role_is_solid_shell(role)
		if inst.indestructible and parts != null and not solid_shell:
			parts.stamp_backdrop(block, cell)
		elif inst.indestructible and parts != null and solid_shell:
			parts.stamp_solid(block, cell, false)
		elif parts != null and block.is_building_part():
			parts.stamp_blueprint_part(block, cell)
		else:
			block_catalog.set_block_cell(_tilemap, cell, block)
			if not inst.indestructible:
				_notify_placed(cell)
		_notify_map(cell)


func _spawn_exterior(inst: BuildingInstance) -> void:
	if _tilemap == null:
		return
	var root: Node2D
	var packed: PackedScene = null
	if default_blueprint != null:
		packed = default_blueprint.get_exterior_scene()
	if packed != null:
		root = packed.instantiate() as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "ForgeExterior"
	root.name = inst.instance_id
	root.add_to_group("building_exterior")
	add_child(root)
	root.z_index = -1
	root.global_position = _cell_center(inst.door_cell)
	var door := root.find_child("EntranceDoor", true, false) as BuildingDoor
	if door == null:
		door = BuildingDoor.new()
		door.name = "EntranceDoor"
		root.add_child(door)
	door.z_as_relative = false
	door.z_index = 0
	door.position = Vector2.ZERO
	door.building_instance_id = inst.instance_id
	door.set_locked(false, "[E] Schmiede betreten")
	_attach_workshop_fx(root, inst)
	if inst.core_cell != Vector2i.ZERO:
		var light := PointLight2D.new()
		light.name = "ForgeCoreLight"
		light.color = Color(1.0, 0.5, 0.18, 1)
		light.energy = 0.42
		light.texture_scale = 1.35
		root.add_child(light)
		light.global_position = _cell_center(inst.core_cell)
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var center := Vector2(16, 16)
		for y in 32:
			for x in 32:
				var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / 16.0
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		light.texture = ImageTexture.create_from_image(img)
	_exteriors[inst.instance_id] = root
	inst.exterior_path = root.get_path()


func _attach_workshop_fx(root: Node2D, inst: BuildingInstance) -> void:
	if default_blueprint == null or _tilemap == null:
		return
	var chim := origin_cell_center(inst.origin + default_blueprint.chimney_local())
	var smoke := GPUParticles2D.new()
	smoke.name = "ChimneySmoke"
	smoke.z_index = 8
	smoke.amount = 18
	smoke.lifetime = 2.4
	smoke.preprocess = 0.8
	smoke.explosiveness = 0.05
	smoke.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.particle_flag_disable_z = true
	mat.emission_sphere_radius = 4.0
	mat.direction = Vector3(0.15, -1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(4.0, -6.0, 0.0)
	mat.scale_min = 0.35
	mat.scale_max = 0.85
	mat.color = Color(0.55, 0.55, 0.58, 0.45)
	smoke.process_material = mat
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			var d := Vector2(float(x) - 3.5, float(y) - 3.5).length() / 4.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.72, 0.72, 0.74, a * a))
	var tex := ImageTexture.create_from_image(img)
	smoke.texture = tex
	root.add_child(smoke)
	smoke.emitting = true
	smoke.global_position = chim + Vector2(8, -20)


func origin_cell_center(cell: Vector2i) -> Vector2:
	return _cell_center(cell)


func _enter_interior(inst: BuildingInstance) -> void:
	var blueprint := default_blueprint
	if blueprint == null or blueprint.get_interior_scene() == null:
		return
	_set_world_visible(false)
	_clear_interior()
	_interior = blueprint.get_interior_scene().instantiate() as Node2D
	var host := _interior_host()
	host.add_child(_interior)
	_interior.position = Vector2.ZERO
	if _interior is BuildingInterior:
		(_interior as BuildingInterior).building_instance_id = inst.instance_id
	current_area = AREA_FORGE_INTERIOR
	interior_building_id = inst.instance_id
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		if _interior is BuildingInterior:
			player.global_position = (_interior as BuildingInterior).player_spawn()
		else:
			player.global_position = host.global_position + Vector2(48, -8)
		player.velocity = Vector2.ZERO


func _leave_interior(from_fog: bool, instance_id: String = "") -> void:
	if _busy and not from_fog:
		return
	_busy = true
	var trans := _transition()
	if trans != null:
		await trans.fade_out()
	var id := instance_id if not instance_id.is_empty() else interior_building_id
	var inst: BuildingInstance = _instances.get(id)
	_clear_interior()
	_set_world_visible(true)
	current_area = AREA_WORLD
	interior_building_id = ""
	if inst != null:
		_place_player_at_door(inst)
	if trans != null:
		await trans.fade_in()
	_busy = false
	building_exited.emit(id)


func _place_player_at_door(inst: BuildingInstance) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or _tilemap == null:
		return
	var cell := inst.return_cell
	var pos := _cell_center(cell)
	pos.y -= 8.0
	player.global_position = pos
	player.velocity = Vector2.ZERO


func _interior_host() -> Node2D:
	var parent := get_tree().get_first_node_in_group("world_generator")
	var main: Node = parent.get_parent() if parent != null else get_tree().current_scene
	var host := main.get_node_or_null("InteriorHost") as Node2D
	if host == null:
		host = Node2D.new()
		host.name = "InteriorHost"
		main.add_child(host)
		host.global_position = INTERIOR_ORIGIN
	return host


func _clear_interior() -> void:
	if _interior != null and is_instance_valid(_interior):
		_interior.queue_free()
	_interior = null


func _set_world_visible(vis: bool) -> void:
	var world := get_tree().get_first_node_in_group("world_generator") as Node2D
	if world != null:
		world.visible = vis
	var fog_vis := get_tree().get_first_node_in_group("fog_visual")
	if fog_vis is CanvasLayer:
		(fog_vis as CanvasLayer).visible = vis
	elif fog_vis is CanvasItem:
		(fog_vis as CanvasItem).visible = vis


func _force_world_visible() -> void:
	_set_world_visible(true)


func _refresh_state(inst: BuildingInstance) -> void:
	if inst.indestructible:
		inst.state = BuildingBlueprintResource.BuildingState.INTACT
		inst.core_intact = true
		inst.door_intact = true
		inst.entrance_ok = true
		inst.missing_count = 0
		inst.present_count = inst.original_count
		_update_door_prompt(inst)
		return
	var present := 0
	var missing := 0
	var foundation_total := 0
	var foundation_ok := 0
	var support_total := 0
	var support_ok := 0
	var core_ok := true
	var entrance_air := 0
	var entrance_total := 0
	for key in inst.components.keys():
		var cell: Vector2i = key
		var data: Dictionary = inst.components[key]
		_sync_cell(inst, cell, int(data.get("removal_cause", 0)))
		data = inst.components[cell]
		var role := int(data.get("role", 0))
		var decoration := bool(data.get("decoration", false))
		var is_present := bool(data.get("present", false))
		if int(data.get("block_id", -1)) >= 0 and not decoration:
			if is_present:
				present += 1
			else:
				missing += 1
		match role:
			BuildingBlueprintResource.ComponentRole.FOUNDATION:
				foundation_total += 1
				if is_present:
					foundation_ok += 1
			BuildingBlueprintResource.ComponentRole.SUPPORT:
				support_total += 1
				if is_present:
					support_ok += 1
			BuildingBlueprintResource.ComponentRole.CORE:
				core_ok = is_present
			BuildingBlueprintResource.ComponentRole.ENTRANCE:
				entrance_total += 1
				if is_present:
					entrance_air += 1
	inst.present_count = present
	inst.missing_count = missing
	inst.core_intact = core_ok
	inst.entrance_ok = entrance_total == 0 or entrance_air >= maxi(entrance_total - 1, 1)
	var foundation_ratio := 1.0 if foundation_total == 0 else float(foundation_ok) / float(foundation_total)
	var support_ratio := 1.0 if support_total == 0 else float(support_ok) / float(support_total)
	var next := BuildingBlueprintResource.BuildingState.INTACT
	if not core_ok or foundation_ratio < 0.25:
		next = BuildingBlueprintResource.BuildingState.DESTROYED
	elif foundation_ratio < 0.5 or support_ratio < 0.5 or not inst.entrance_ok:
		next = BuildingBlueprintResource.BuildingState.CRITICAL
	elif missing > 0:
		next = BuildingBlueprintResource.BuildingState.DAMAGED
	var previous := inst.state
	inst.state = next
	_update_door_prompt(inst)
	if previous != next:
		building_state_changed.emit(inst.instance_id, next)
		if next == BuildingBlueprintResource.BuildingState.DESTROYED:
			building_destroyed.emit(inst.instance_id)
			if is_player_inside() and interior_building_id == inst.instance_id:
				call_deferred("try_exit")


func _sync_cell(inst: BuildingInstance, cell: Vector2i, cause: int) -> void:
	if not inst.components.has(cell):
		return
	var data: Dictionary = inst.components[cell]
	var expected := int(data.get("block_id", -1))
	var block := _block_at(cell)
	var present := false
	if expected < 0:
		present = block == null or not block.solid
	else:
		present = block != null and block.id == expected
	if present:
		data["present"] = true
		if not _collapsing_cells.has(cell):
			data["removal_cause"] = BuildingBlueprintResource.RemovalCause.NONE
	else:
		if bool(data.get("present", true)):
			if cause == 0:
				cause = BuildingBlueprintResource.RemovalCause.PLAYER_REMOVED
			data["removal_cause"] = cause
		data["present"] = false
	inst.components[cell] = data


func _on_structure_changed(cell: Vector2i) -> void:
	var inst := _instance_at(cell)
	if inst == null:
		return
	_refresh_state(inst)


func _on_structure_collapsed(cells: Array) -> void:
	for cell in cells:
		_collapsing_cells[cell] = true
		var inst := _instance_at(cell)
		if inst == null:
			continue
		_sync_cell(inst, cell, BuildingBlueprintResource.RemovalCause.COLLAPSE_DESTROYED)
		_refresh_state(inst)
	call_deferred("_clear_collapse_marks")


func _on_structure_unstable(_cells: Array) -> void:
	pass


func _clear_collapse_marks() -> void:
	_collapsing_cells.clear()


func _resource_report(blueprint: BuildingBlueprintResource, inventory: Inventory) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	var missing_parts: PackedStringArray = PackedStringArray()
	var ok := true
	if inventory == null:
		return {"ok": false, "lines": PackedStringArray(["Kein Inventar"]), "missing": "Inventar"}
	for cost in blueprint.get_costs():
		var item_id := int(cost["item_id"])
		var need := int(cost["amount"])
		var have := inventory.get_bag_amount(item_id)
		var item := item_catalog.get_item(item_id) if item_catalog != null else null
		var item_name := item.display_name if item != null else str(item_id)
		var mark := "✓" if have >= need else "✗"
		if have < need:
			ok = false
			missing_parts.append("%d %s" % [need - have, item_name])
		lines.append("%s    %d / %d   %s" % [item_name, have, need, mark])
	return {"ok": ok, "lines": lines, "missing": ", ".join(missing_parts)}


func _show_cost_panel(blueprint: BuildingBlueprintResource, _inventory: Inventory, report: Dictionary) -> void:
	if _hud == null:
		return
	_hud.show_costs(
		blueprint.display_name,
		report.get("resource_lines", PackedStringArray()),
		str(report.get("missing", "")),
		bool(report.get("ok", false)),
		str(report.get("hint", ""))
	)


func _snap_origin(hover: Vector2i, blueprint: BuildingBlueprintResource) -> Vector2i:
	var half := blueprint.total_width() / 2
	var y := hover.y
	if _is_support_ground(_foreground_block(hover)):
		y = hover.y - 1
	return Vector2i(hover.x - half, y)


func _ground_ok(blueprint: BuildingBlueprintResource, origin: Vector2i) -> bool:
	return _has_flat_support(origin, blueprint.total_width())


func _ground_variance(blueprint: BuildingBlueprintResource, origin: Vector2i) -> int:
	if _has_flat_support(origin, blueprint.total_width()):
		return 0
	return blueprint.max_ground_variance + 1


func _has_flat_support(origin: Vector2i, width: int) -> bool:
	for x in width:
		var floor_cell := Vector2i(origin.x + x, origin.y)
		var ground_cell := Vector2i(origin.x + x, origin.y + 1)
		if _is_obstruction(floor_cell):
			return false
		if not _is_support_ground(_foreground_block(ground_cell)):
			return false
	return true


func _is_support_ground(block: BlockData) -> bool:
	if block == null:
		return false
	if block.solid:
		return true
	return block.is_one_way


func _volume_ok(blueprint: BuildingBlueprintResource, origin: Vector2i, layout: Array) -> bool:
	return _volume_problem(blueprint, origin, layout).is_empty()


func _volume_problem(blueprint: BuildingBlueprintResource, origin: Vector2i, layout: Array) -> String:
	var trees := get_tree().get_first_node_in_group("tree_system") as TreeSystem
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	var structural := _structural()
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		if blueprint.forbid_tree_overlap and trees != null and trees.is_tree_tile(cell):
			return "tree"
		if parts != null and parts.is_entity_cell(cell):
			return "occupied"
		if structural != null and bool(structural.call("is_player_placed", cell)):
			if not _cell_index.has(cell):
				return "player_block"
		var role := int(spec["role"])
		var block := _foreground_block(cell)
		if role == BuildingBlueprintResource.ComponentRole.FOUNDATION:
			if _is_obstruction(cell):
				return "occupied"
			continue
		if block == null:
			continue
		if block.id == 13:
			return "bedrock"
		if block.ore_data != null:
			return "ore"
		if block.solid or block.structural_enabled:
			return "occupied"
	if blueprint.require_foundation_anchor and not _has_flat_support(origin, blueprint.total_width()):
		return "ground"
	return ""


func _placement_hint(problems: PackedStringArray, missing: String) -> String:
	if problems.is_empty():
		return "Rechtsklick: Gebäude errichten."
	var lines: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for code in problems:
		if seen.has(code):
			continue
		seen[code] = true
		lines.append("• %s" % _reason_text(code, missing))
	return "Kann nicht platziert werden:\n%s" % "\n".join(lines)


func _reason_text(code: String, missing: String) -> String:
	match code:
		"range":
			return "Zu weit entfernt. Näher herangehen."
		"ground":
			return "Nur auf ebener Fläche. Die ganze Breite braucht freien Platz, direkt darunter durchgehend festen Boden."
		"tree":
			return "Bäume stehen im Weg."
		"player_block":
			return "Eigene Blöcke stehen im Weg."
		"bedrock":
			return "Unzerstörbarer Fels im Weg."
		"ore":
			return "Erz steht im Weg."
		"occupied":
			return "Erde oder andere Objekte stehen im Weg. Freie, ebene Fläche wählen."
		"lantern":
			return "Zu nah an der Laterne."
		"building":
			return "Überlappt ein anderes Gebäude."
		"player":
			return "Spieler steht im Gebäudevolumen."
		"resources":
			if missing.is_empty():
				return "Es fehlen Baumaterialien."
			return "Es fehlen Ressourcen: %s." % missing
		_:
			return "Hier kann nicht gebaut werden."


func _is_obstruction(cell: Vector2i) -> bool:
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	if parts != null and parts.is_entity_cell(cell):
		return true
	var block := _foreground_block(cell)
	if block == null:
		return false
	if block.id == 13 or block.ore_data != null:
		return true
	return block.solid or block.structural_enabled


func _foreground_block(cell: Vector2i) -> BlockData:
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	if parts != null and parts.is_entity_cell(cell):
		return parts.get_block_at(cell)
	return _block_at(cell)


func _is_soft_surface(block: BlockData) -> bool:
	if block == null:
		return false
	return block.id == 1 or block.id == 2 or block.id == 4 or block.id == 8 or block.id == 17 or block.id == 18 or block.id == 19


func _overlaps_lantern(origin: Vector2i, layout: Array) -> bool:
	var lantern := get_tree().get_first_node_in_group("lantern") as Node2D
	if lantern == null or _tilemap == null:
		return false
	var lantern_cell := _tilemap.local_to_map(_tilemap.to_local(lantern.global_position))
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		if absi(cell.x - lantern_cell.x) <= 1 and absi(cell.y - lantern_cell.y) <= 3:
			return true
	return false


func _overlaps_building(origin: Vector2i, layout: Array) -> bool:
	for spec in layout:
		var cell: Vector2i = origin + spec["offset"]
		if _cell_index.has(cell):
			return true
	return false


func _overlaps_player(origin: Vector2i, layout: Array) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or _tilemap == null:
		return false
	var collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		return false
	var rect_shape := collision.shape as RectangleShape2D
	if rect_shape == null:
		return false
	var player_rect := Rect2(collision.global_position - rect_shape.size * 0.5, rect_shape.size).grow(1.0)
	for spec in layout:
		if int(spec["block_id"]) < 0:
			continue
		var block := block_catalog.get_by_id(int(spec["block_id"])) if block_catalog != null else null
		if block != null and not block.solid:
			continue
		var cell: Vector2i = origin + spec["offset"]
		var center := _cell_center(cell)
		var tile_rect := Rect2(center - Vector2(8, 8), Vector2(16, 16))
		if player_rect.intersects(tile_rect):
			return true
	return false


func _index_instance(inst: BuildingInstance) -> void:
	for key in inst.components.keys():
		_cell_index[key] = inst.instance_id


func is_protected_cell(cell: Vector2i) -> bool:
	var inst := _instance_at(cell)
	return inst != null and inst.indestructible


func _role_is_solid_shell(role: int) -> bool:
	return role == BuildingBlueprintResource.ComponentRole.FOUNDATION or role == BuildingBlueprintResource.ComponentRole.ROOF


func _instance_at(cell: Vector2i) -> BuildingInstance:
	if not _cell_index.has(cell):
		return null
	return _instances.get(_cell_index[cell])


func _make_id(type_id: StringName) -> String:
	var raw := String(type_id).to_lower()
	var id := "%s_%06d" % [raw, _next_index]
	_next_index += 1
	return id


func _notify_placed(cell: Vector2i) -> void:
	var mgr := _structural()
	if mgr != null:
		mgr.call("notify_block_placed", cell)


func _notify_map(cell: Vector2i) -> void:
	var map_data := get_tree().get_first_node_in_group("world_map_data")
	if map_data != null and map_data.has_method("update_tile"):
		map_data.call("update_tile", cell)


func _block_at(cell: Vector2i) -> BlockData:
	if _tilemap == null or block_catalog == null:
		return null
	if _tilemap.get_cell_source_id(cell) == -1:
		return null
	return block_catalog.get_cell_block(_tilemap, cell)


func _cell_center(cell: Vector2i) -> Vector2:
	return _tilemap.to_global(_tilemap.map_to_local(cell))


func _structural() -> Node:
	return get_tree().get_first_node_in_group("structural_manager")


func _transition() -> SceneTransition:
	return get_tree().get_first_node_in_group("scene_transition") as SceneTransition


func _lock_door(inst: BuildingInstance, text: String) -> void:
	var root: Node2D = _exteriors.get(inst.instance_id)
	if root == null:
		return
	var door := root.find_child("EntranceDoor", true, false) as BuildingDoor
	if door != null:
		door.set_locked(true, "[E] %s" % text.replace("⚠ ", ""))


func _update_door_prompt(inst: BuildingInstance) -> void:
	var root: Node2D = _exteriors.get(inst.instance_id)
	if root == null:
		return
	var door := root.find_child("EntranceDoor", true, false) as BuildingDoor
	if door == null:
		return
	match inst.state:
		BuildingBlueprintResource.BuildingState.DESTROYED:
			door.set_locked(true, "[E] Schmiede zerstört")
		BuildingBlueprintResource.BuildingState.CRITICAL:
			door.set_locked(true, "[E] Gebäude zu schwer beschädigt.")
		_:
			door.set_locked(false, "[E] Schmiede betreten")


func _refund(inventory: Inventory, costs: Array) -> void:
	if inventory == null:
		return
	for cost in costs:
		inventory.add_item(int(cost["item_id"]), int(cost["amount"]))


func _clear_all_runtime() -> void:
	for key in _exteriors.keys():
		var node: Node = _exteriors[key]
		if node != null and is_instance_valid(node):
			node.queue_free()
	_exteriors.clear()
	_instances.clear()
	_cell_index.clear()
	_clear_interior()
