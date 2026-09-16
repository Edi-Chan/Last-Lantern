class_name SurfaceBackground
extends Node2D

## Gehoert an: World/Background/SurfaceSky.
## Mehrschichtiger Oberflaechenhintergrund. Nur sichtbar, solange CaveAtmosphere surface>0.

const STAR_SHADER := preload("res://shaders/starfield.gdshader")
const TREE_WIND_SHADER := preload("res://shaders/bg_tree_wind.gdshader")

const CLOUD_SMALL := preload("res://assets/world/background/small_cloud.png")
const CLOUD_MED := preload("res://assets/world/background/medium_cloud.png")
const CLOUD_LARGE := preload("res://assets/world/background/large_cloud.png")
const CLOUD_WISPY := preload("res://assets/world/background/cloud_wispy.png")
const CLOUD_PUFF := preload("res://assets/world/background/cloud_puff.png")
const HILLS_GRASS := preload("res://assets/world/background/hills_grass.png")
const HILLS_SAND := preload("res://assets/world/background/hills_sand.png")
const FAR_TREES := preload("res://assets/world/background/far_trees.png")
const FAR_TREES_SAND := preload("res://assets/world/background/far_trees_sand.png")
const MID_TREES := preload("res://assets/world/background/mid_trees.png")
const FOG_HAZE := preload("res://assets/world/background/fog_haze.png")
const SUN_TEX := preload("res://assets/world/celestial/sun.png")
const MOON_TEX := preload("res://assets/world/celestial/moon.png")

var _world: WorldGenerator
var _day: DayCycle
var _player: Player
var _stars: ColorRect
var _star_mat: ShaderMaterial
var _sun: Sprite2D
var _moon: Sprite2D
var _hills_grass: Sprite2D
var _hills_sand: Sprite2D
var _far_trees: Sprite2D
var _far_trees_sand: Sprite2D
var _mid_trees: Sprite2D
var _built: bool = false
var _sand_blend: float = 0.0
var _forest_blend: float = 0.0
var _twinkle: float = 0.0


func _ready() -> void:
	add_to_group("surface_background")
	z_index = -15
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_layers()


func setup(world: WorldGenerator) -> void:
	_world = world
	if not _built:
		_build_layers()
	_align_horizon()


func _process(delta: float) -> void:
	if _day == null or not is_instance_valid(_day):
		_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _world == null:
		_world = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	_twinkle += delta
	_update_celestial()
	_update_biome(delta)
	if _star_mat != null:
		_star_mat.set_shader_parameter("twinkle_time", _twinkle)
		if _day != null:
			_star_mat.set_shader_parameter("visibility", _day.star_visibility())


func _build_layers() -> void:
	if _built:
		return
	_built = true
	_star_mat = ShaderMaterial.new()
	_star_mat.shader = STAR_SHADER
	_stars = ColorRect.new()
	_stars.name = "Stars"
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.material = _star_mat
	_stars.color = Color(1, 1, 1, 1)
	_stars.z_index = 0
	add_child(_stars)
	_sun = _make_sprite("Sun", SUN_TEX, 1)
	_moon = _make_sprite("Moon", MOON_TEX, 1)
	_sun.centered = true
	_moon.centered = true
	_sun.scale = Vector2(2.2, 2.2)
	_moon.scale = Vector2(1.8, 1.8)
	var hills := _make_parallax("DistantLandscape", Vector2(0.12, 0.92), Vector2.ZERO, HILLS_GRASS.get_width(), 4)
	_hills_grass = _make_strip(hills, "HillsGrass", HILLS_GRASS)
	_hills_sand = _make_strip(hills, "HillsSand", HILLS_SAND)
	_hills_sand.modulate.a = 0.0
	var far := _make_parallax("FarTrees", Vector2(0.26, 0.94), Vector2.ZERO, FAR_TREES.get_width(), 5)
	var far_mat := _tree_material(1.1, 0.42)
	_far_trees = _make_strip(far, "FarTreesGrass", FAR_TREES)
	_far_trees.material = far_mat
	_far_trees_sand = _make_strip(far, "FarTreesSand", FAR_TREES_SAND)
	_far_trees_sand.material = far_mat
	_far_trees_sand.modulate.a = 0.0
	var fog := _make_parallax("AtmosphericFog", Vector2(0.38, 0.96), Vector2(6.0, 0.0), FOG_HAZE.get_width(), 6)
	var fog_sprite := _make_strip(fog, "Haze", FOG_HAZE)
	fog_sprite.modulate = Color(1, 1, 1, 0.42)
	fog_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mid := _make_parallax("MidTrees", Vector2(0.46, 0.97), Vector2.ZERO, MID_TREES.get_width(), 7)
	_mid_trees = _make_strip(mid, "MidTreesGrass", MID_TREES)
	_mid_trees.material = _tree_material(1.8, 0.55)
	_add_cloud_layer("FarCloudExtra", Vector2(0.09, 0.82), Vector2(4.5, 0.0), 2, 0.55, true)
	_add_cloud_layer("NearCloudExtra", Vector2(0.22, 0.88), Vector2(11.0, 0.0), 3, 0.82, false)


func _make_sprite(node_name: String, tex: Texture2D, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = z
	s.centered = true
	add_child(s)
	return s


func _make_parallax(node_name: String, scroll: Vector2, auto: Vector2, repeat_x: int, z: int) -> Parallax2D:
	var p := Parallax2D.new()
	p.name = node_name
	p.scroll_scale = scroll
	p.autoscroll = auto
	p.repeat_size = Vector2(float(repeat_x), 0.0)
	p.repeat_times = 18
	p.follow_viewport = true
	p.z_index = z
	add_child(p)
	return p


func _make_strip(parent: Node2D, node_name: String, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s


func _tree_material(pixels: float, speed: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TREE_WIND_SHADER
	mat.set_shader_parameter("wind_pixels", pixels)
	mat.set_shader_parameter("wind_speed", speed)
	return mat


func _add_cloud_layer(node_name: String, scroll: Vector2, auto: Vector2, z: int, opacity: float, far: bool) -> void:
	var p := _make_parallax(node_name, scroll, auto, 1700 if far else 2000, z)
	p.modulate = Color(1, 1, 1, opacity)
	var textures: Array[Texture2D] = [CLOUD_SMALL, CLOUD_MED, CLOUD_LARGE, CLOUD_WISPY, CLOUD_PUFF]
	var rng := RandomNumberGenerator.new()
	rng.seed = 44011 if far else 88021
	var count := 8 if far else 7
	var span := 1700.0 if far else 2000.0
	for i in count:
		var s := Sprite2D.new()
		s.texture = textures[rng.randi() % textures.size()]
		s.centered = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sc := rng.randf_range(1.6, 2.8) if far else rng.randf_range(2.2, 3.6)
		s.scale = Vector2(sc, sc)
		s.modulate.a = rng.randf_range(0.55, 0.95)
		s.position = Vector2(rng.randf() * span, rng.randf_range(480.0, 860.0) if far else rng.randf_range(720.0, 1020.0))
		p.add_child(s)


func _align_horizon() -> void:
	if _world == null:
		return
	var horizon := float(_world.base_surface_y * WorldGenerator.TILE_SIZE)
	_place_strip(_hills_grass, horizon + 18.0)
	_place_strip(_hills_sand, horizon + 26.0)
	_place_strip(_far_trees, horizon + 8.0)
	_place_strip(_far_trees_sand, horizon + 14.0)
	_place_strip(_mid_trees, horizon + 2.0)
	var fog := get_node_or_null("AtmosphericFog/Haze") as Sprite2D
	_place_strip(fog, horizon - 10.0)


func _place_strip(sprite: Sprite2D, bottom_y: float) -> void:
	if sprite == null or sprite.texture == null:
		return
	sprite.position = Vector2(0.0, bottom_y - sprite.texture.get_height())


func _update_celestial() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var view := get_viewport().get_visible_rect().size / cam.zoom
	_stars.global_position = center - view * 0.5
	_stars.size = view
	if _day == null:
		return
	var sun_t := _day.sun_path()
	var moon_t := _day.moon_path()
	var sun_a := _day.sun_visibility()
	var moon_a := _day.moon_visibility()
	_sun.modulate.a = sun_a
	_moon.modulate.a = moon_a
	_sun.visible = sun_a > 0.01
	_moon.visible = moon_a > 0.01
	_sun.global_position = _arc_position(center, view, sun_t, 0.62)
	_moon.global_position = _arc_position(center, view, moon_t, 0.54)
	var dusk := _day.dusk_amount()
	_sun.modulate = Color(1.0, 1.0 - dusk * 0.18, 1.0 - dusk * 0.32, sun_a)


func _arc_position(center: Vector2, view: Vector2, t: float, height: float) -> Vector2:
	var x := center.x + lerpf(-view.x * 0.38, view.x * 0.38, t)
	var y := center.y - view.y * (0.06 + height * 0.34 * sin(t * PI))
	return Vector2(x, y)


func _update_biome(delta: float) -> void:
	var target_sand := 0.0
	var target_forest := 0.0
	if _player != null and _world != null:
		var tilemap := get_tree().get_first_node_in_group("terrain") as TileMapLayer
		if tilemap != null:
			var tile := tilemap.local_to_map(tilemap.to_local(_player.global_position))
			var biome := _world.get_surface_biome(tile.x)
			if biome == &"sand":
				target_sand = 1.0
			elif biome == &"forest":
				target_forest = 1.0
	var k := clampf(delta * 0.85, 0.0, 1.0)
	_sand_blend = lerpf(_sand_blend, target_sand, k)
	_forest_blend = lerpf(_forest_blend, target_forest, k)
	if _hills_grass != null:
		_hills_grass.modulate.a = lerpf(1.0, 0.12, _sand_blend)
	if _hills_sand != null:
		_hills_sand.modulate.a = _sand_blend
	if _far_trees != null:
		_far_trees.modulate.a = lerpf(0.92, 0.08, _sand_blend)
	if _far_trees_sand != null:
		_far_trees_sand.modulate.a = _sand_blend * 0.9
	if _mid_trees != null:
		_mid_trees.modulate.a = lerpf(0.88, 0.18, _sand_blend) * lerpf(1.0, 1.18, _forest_blend)
		_mid_trees.modulate = Color(_mid_trees.modulate.r, _mid_trees.modulate.g, _mid_trees.modulate.b, _mid_trees.modulate.a)
