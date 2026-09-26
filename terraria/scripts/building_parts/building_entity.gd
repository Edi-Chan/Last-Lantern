class_name BuildingEntity
extends Node2D

## Interaktive Bauteile: Tueren, Tore, Stationen, Licht, Kiste.
## Kollision und State sitzen hier, das TileMap bleibt fuer normale Bloecke.

signal entity_removed(entity: BuildingEntity)

@export var block_id: int = -1
@export var item_id: int = -1
@export var origin: Vector2i = Vector2i.ZERO
@export var footprint: Vector2i = Vector2i.ONE
@export var orientation: int = 0
@export var is_open: bool = false

var block_data: BlockData
var _sprite: Sprite2D
var _body: StaticBody2D
var _shape: CollisionShape2D
var _hint: Label
var _player_near: bool = false
var _light: PointLight2D
var _interactable: bool = false


func setup(p_block: BlockData, p_origin: Vector2i, p_orientation: int, tile_size: int) -> void:
	block_data = p_block
	block_id = p_block.id if p_block != null else -1
	item_id = p_block.drop_item_id if p_block != null else -1
	origin = p_origin
	orientation = p_orientation
	if p_block != null and p_block.footprint != Vector2i.ZERO:
		footprint = p_block.footprint
	_interactable = p_block != null and p_block.building_part_type in [
		BlockData.BuildingPartType.DOOR,
		BlockData.BuildingPartType.DEFENSE,
		BlockData.BuildingPartType.STORAGE,
		BlockData.BuildingPartType.CRAFTING_STATION,
		BlockData.BuildingPartType.BED,
	]
	if p_block != null and p_block.building_part_type == BlockData.BuildingPartType.LIGHT:
		_interactable = false
	position = Vector2(float(p_origin.x) * float(tile_size), float(p_origin.y + footprint.y) * float(tile_size))
	_ensure_visuals()
	_ensure_collision()
	_ensure_light()
	_apply_open_state()


func occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in footprint.y:
		for x in footprint.x:
			cells.append(origin + Vector2i(x, y - (footprint.y - 1)))
	return cells


func toggle() -> void:
	if not _can_toggle():
		return
	is_open = not is_open
	_apply_open_state()


func take_hit() -> void:
	entity_removed.emit(self)


func to_save_dict() -> Dictionary:
	return {
		"block_id": block_id,
		"origin": [origin.x, origin.y],
		"orientation": orientation,
		"open": is_open,
	}


func _can_toggle() -> bool:
	if block_data == null:
		return false
	return block_data.building_part_type in [
		BlockData.BuildingPartType.DOOR,
		BlockData.BuildingPartType.DEFENSE,
	] and block_data.building_part_type != BlockData.BuildingPartType.NONE


func _process(_delta: float) -> void:
	if not _interactable or not _player_near:
		return
	if UIManager.is_blocking_gameplay():
		return
	var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
	if inventory_ui != null and inventory_ui.visible:
		return
	if not InputMap.has_action("interact"):
		return
	if Input.is_action_just_pressed("interact"):
		if _can_toggle():
			toggle()
		elif get_crafting_station_kind() != RecipeData.Station.NONE:
			_open_station_crafting()
		elif is_bed():
			_use_bed()
		elif _hint != null:
			_hint.text = _station_hint()
			_hint.visible = true


func _ready() -> void:
	add_to_group("building_entity")
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _ensure_visuals() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = false
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	var tex := _texture_for_block()
	if tex != null:
		_sprite.texture = tex
		_sprite.position = Vector2(0, -float(tex.get_height()))
		if orientation != 0:
			_sprite.flip_h = true
	if _hint == null:
		_hint = Label.new()
		_hint.name = "Hint"
		_hint.visible = false
		_hint.position = Vector2(-58, -float(footprint.y * 16) - 18)
		_hint.size = Vector2(140, 14)
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_font_size_override("font_size", 9)
		_hint.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55, 1))
		_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_hint.add_theme_constant_override("outline_size", 3)
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.text = _default_hint()
		add_child(_hint)
	var area := get_node_or_null("Interact") as Area2D
	if area == null:
		area = Area2D.new()
		area.name = "Interact"
		area.collision_layer = 0
		area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = maxf(22.0, float(footprint.x + footprint.y) * 8.0)
		cs.shape = circle
		cs.position = Vector2(float(footprint.x) * 8.0, -float(footprint.y) * 8.0)
		area.add_child(cs)
		add_child(area)
		area.body_entered.connect(func(body: Node) -> void:
			if body.is_in_group("player"):
				_player_near = true
				if _hint != null:
					_hint.visible = _interactable
		)
		area.body_exited.connect(func(body: Node) -> void:
			if body.is_in_group("player"):
				_player_near = false
				if _hint != null:
					_hint.visible = false
		)


func _ensure_collision() -> void:
	if _body != null:
		return
	if block_data == null:
		return
	var needs_body := block_data.building_part_type in [
		BlockData.BuildingPartType.DOOR,
		BlockData.BuildingPartType.DEFENSE,
		BlockData.BuildingPartType.CRAFTING_STATION,
		BlockData.BuildingPartType.STORAGE,
		BlockData.BuildingPartType.BED,
	]
	if not needs_body:
		return
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(footprint.x) * 16.0 - 2.0, float(footprint.y) * 16.0 - 2.0)
	_shape.shape = rect
	_shape.position = Vector2(float(footprint.x) * 8.0, -float(footprint.y) * 8.0)
	_body.add_child(_shape)
	add_child(_body)


func _ensure_light() -> void:
	if block_data == null or block_data.light_energy <= 0.0:
		return
	if _light != null:
		return
	_light = PointLight2D.new()
	_light.name = "Light"
	_light.position = Vector2(8, -12)
	_light.color = Color(1.0, 0.62, 0.28, 1)
	_light.energy = block_data.light_energy
	_light.texture_scale = 1.8
	_light.texture = _radial_texture()
	add_child(_light)


func _apply_open_state() -> void:
	if _shape != null:
		_shape.disabled = is_open
	if _sprite != null:
		_sprite.modulate = Color(0.75, 0.85, 0.7, 0.85) if is_open else Color.WHITE
	if _hint != null:
		_hint.text = _default_hint()


func is_player_in_range() -> bool:
	return _player_near


func get_crafting_station_kind() -> int:
	return RecipeData.station_from_block_id(block_id)


func is_bed() -> bool:
	return block_data != null and block_data.building_part_type == BlockData.BuildingPartType.BED


func rest_position() -> Vector2:
	var along := 50.0 if orientation == 0 else 14.0
	return global_position + Vector2(along + 6.0, -14.0)


func safe_spawn_position() -> Vector2:
	var parts := get_tree().get_first_node_in_group(BuildingPartSystem.GROUP) as BuildingPartSystem
	var candidates: Array[Vector2i] = [
		origin + Vector2i(-1, 0),
		origin + Vector2i(footprint.x, 0),
		origin + Vector2i(-1, -1),
		origin + Vector2i(footprint.x, -1),
		origin + Vector2i(int(footprint.x / 2.0), -footprint.y),
	]
	if parts != null:
		for cell in candidates:
			if parts.is_spawn_cell_blocked(cell, self):
				continue
			if parts.is_spawn_cell_blocked(cell + Vector2i(0, -1), self):
				continue
			if parts.is_spawn_cell_blocked(cell + Vector2i(0, -2), self):
				continue
			if not parts.has_stand_ground(cell):
				continue
			return Vector2(float(cell.x) * 16.0 + 8.0, float(cell.y + 1) * 16.0 - 1.0)
	return global_position + Vector2(float(footprint.x) * 16.0 + 12.0, 0.0)


func _use_bed() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	player.use_bed(self)


func _open_station_crafting() -> void:
	var screen := get_tree().get_first_node_in_group("inventory_ui")
	if screen == null:
		return
	var kind := get_crafting_station_kind()
	if screen.has_method("open_crafting"):
		screen.call("open_crafting", kind)
	elif screen.has_method("open"):
		screen.call("open")


func _default_hint() -> String:
	if block_data == null:
		return ""
	match block_data.building_part_type:
		BlockData.BuildingPartType.DOOR, BlockData.BuildingPartType.DEFENSE:
			return "[E] Schließen" if is_open else "[E] Öffnen"
		BlockData.BuildingPartType.CRAFTING_STATION:
			return _station_hint()
		BlockData.BuildingPartType.STORAGE:
			return "[E] Kiste (bald)"
		BlockData.BuildingPartType.BED:
			return "[E] Bett benutzen"
		_:
			return ""


func _station_hint() -> String:
	match get_crafting_station_kind():
		RecipeData.Station.WORKBENCH:
			return "[E] Werkbank benutzen"
		RecipeData.Station.ANVIL:
			return "[E] Amboss benutzen"
		RecipeData.Station.FURNACE:
			return "[E] Schmelzofen benutzen"
		_:
			if block_data != null:
				return "[E] %s benutzen" % block_data.display_name
			return ""


func _texture_for_block() -> Texture2D:
	if block_data == null:
		return null
	var path := ""
	match block_data.id:
		56:
			path = "res://assets/building/doors/wood_door.png"
		57:
			path = "res://assets/building/doors/reinforced_wood_door.png"
		58:
			path = "res://assets/building/defense/wood_gate.png"
		59:
			path = "res://assets/building/furniture/wood_chest.png"
		60:
			path = "res://assets/building/stations/workbench.png"
		61:
			path = "res://assets/building/stations/anvil.png"
		62:
			path = "res://assets/building/stations/furnace.png"
		63:
			path = "res://assets/building/lights/wall_torch.png"
		64:
			path = "res://assets/building/furniture/wood_bed.png"
		_:
			return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _radial_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(32, 32)
	for y in 64:
		for x in 64:
			var d := Vector2(float(x), float(y)).distance_to(center) / 32.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a *= a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
