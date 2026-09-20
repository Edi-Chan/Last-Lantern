class_name WorldGenerationSettings
extends Resource

## Zentrale, datengetriebene Parameter der Weltgenerierung.

const SETTINGS_PATH := "res://resources/world/world_generation_settings.tres"

@export_group("Klein")
@export var small_width: int = 960
@export var small_height: int = 360
@export var small_base_surface_y: int = 104
@export var small_surface_amplitude: int = 16
@export var small_ocean_width: int = 192
@export var small_start_width: int = 80
@export var small_fortress_width: int = 80
@export var small_fortress_approach_width: int = 96
@export var small_ocean_depth: int = 40

@export_group("Mittel")
@export var medium_width: int = 1600
@export var medium_height: int = 480
@export var medium_base_surface_y: int = 144
@export var medium_surface_amplitude: int = 22
@export var medium_ocean_width: int = 288
@export var medium_start_width: int = 96
@export var medium_fortress_width: int = 112
@export var medium_fortress_approach_width: int = 144
@export var medium_ocean_depth: int = 48

@export_group("Gross")
@export var large_width: int = 2560
@export var large_height: int = 640
@export var large_base_surface_y: int = 184
@export var large_surface_amplitude: int = 28
@export var large_ocean_width: int = 384
@export var large_start_width: int = 112
@export var large_fortress_width: int = 144
@export var large_fortress_approach_width: int = 192
@export var large_ocean_depth: int = 64

@export_group("Grenzen")
@export var world_edge_width: int = 3
@export var bedrock_rows: int = 5
@export var sky_margin_tiles: int = 8
@export var bound_thickness_px: int = 96
@export var min_playable_width: int = 160

@export_group("Startgebiet")
@export var lantern_inset_tiles: int = 18
@export var spawn_offset_tiles: int = 8
@export var start_flatness: int = 1

@export_group("Terrain")
@export var dirt_depth_min: int = 4
@export var dirt_depth_max: int = 8
@export var sand_depth_min: int = 3
@export var sand_depth_max: int = 7
@export var surface_smooth_passes: int = 2

@export_group("Biome")
@export var biome_min_band_width: int = 36
@export var biome_max_band_width: int = 110
@export var biome_transition_width: int = 10
@export var required_surface_biomes: PackedStringArray = PackedStringArray(["grassland", "forest", "sand"])

@export_group("Tiefenebenen")
## Kumulierte Anteile von der Oberflaeche bis zum Bedrock.
@export_range(0.02, 0.2, 0.01) var surface_depth_ratio: float = 0.06
@export_range(0.08, 0.4, 0.01) var underground_depth_ratio: float = 0.22
@export_range(0.25, 0.7, 0.01) var shallow_caves_ratio: float = 0.48
@export_range(0.5, 0.95, 0.01) var deep_caves_ratio: float = 0.76

@export_group("Hoehlen")
@export_range(0.0, 0.4, 0.01) var cave_fill_underground: float = 0.11
@export_range(0.0, 0.5, 0.01) var cave_fill_shallow: float = 0.22
@export_range(0.0, 0.5, 0.01) var cave_fill_deep: float = 0.32
@export_range(0.0, 0.5, 0.01) var cave_fill_danger: float = 0.24
@export var spine_cave_count_small: int = 18
@export var spine_cave_count_medium: int = 32
@export var spine_cave_count_large: int = 48
@export var cave_entrance_min: int = 4
@export var cave_entrance_max: int = 10
@export var cave_connect_min_size: int = 28
@export var cave_connect_max_distance: int = 42
@export var cave_chamber_min_radius: int = 3
@export var cave_chamber_max_radius: int = 11

@export_group("Baeume")
@export var tree_min_height: int = 4
@export var tree_max_height: int = 7
@export var forest_tree_spacing_min: int = 3
@export var forest_tree_spacing_max: int = 6
@export var grassland_tree_spacing_min: int = 8
@export var grassland_tree_spacing_max: int = 14
@export_range(0.0, 1.0, 0.01) var forest_tree_chance: float = 0.78
@export_range(0.0, 1.0, 0.01) var grassland_tree_chance: float = 0.22

@export_group("Erze")
@export var ore_vein_min_distance: int = 8
@export var rare_ore_vein_min_distance: int = 16

@export_group("Festung")
@export var fortress_keep_height: int = 18
@export var fortress_wall_thickness: int = 2


static func load_or_default() -> WorldGenerationSettings:
	if ResourceLoader.exists(SETTINGS_PATH):
		var loaded := load(SETTINGS_PATH) as WorldGenerationSettings
		if loaded != null:
			return loaded
	return WorldGenerationSettings.new()


func size_profile(size_id: int) -> Dictionary:
	match WorldSize.clamp_id(size_id):
		WorldSize.Id.SMALL:
			return {
				"width": small_width,
				"height": small_height,
				"base_surface_y": small_base_surface_y,
				"surface_amplitude": small_surface_amplitude,
				"ocean_width": small_ocean_width,
				"start_width": small_start_width,
				"fortress_width": small_fortress_width,
				"fortress_approach_width": small_fortress_approach_width,
				"ocean_depth": small_ocean_depth,
				"spine_caves": spine_cave_count_small,
			}
		WorldSize.Id.LARGE:
			return {
				"width": large_width,
				"height": large_height,
				"base_surface_y": large_base_surface_y,
				"surface_amplitude": large_surface_amplitude,
				"ocean_width": large_ocean_width,
				"start_width": large_start_width,
				"fortress_width": large_fortress_width,
				"fortress_approach_width": large_fortress_approach_width,
				"ocean_depth": large_ocean_depth,
				"spine_caves": spine_cave_count_large,
			}
		_:
			return {
				"width": medium_width,
				"height": medium_height,
				"base_surface_y": medium_base_surface_y,
				"surface_amplitude": medium_surface_amplitude,
				"ocean_width": medium_ocean_width,
				"start_width": medium_start_width,
				"fortress_width": medium_fortress_width,
				"fortress_approach_width": medium_fortress_approach_width,
				"ocean_depth": medium_ocean_depth,
				"spine_caves": spine_cave_count_medium,
			}


func layer_for_ratio(depth_ratio: float) -> int:
	var t := clampf(depth_ratio, 0.0, 1.0)
	if t <= surface_depth_ratio:
		return DepthLayer.Id.SURFACE
	if t <= underground_depth_ratio:
		return DepthLayer.Id.UNDERGROUND
	if t <= shallow_caves_ratio:
		return DepthLayer.Id.SHALLOW_CAVES
	if t <= deep_caves_ratio:
		return DepthLayer.Id.DEEP_CAVES
	return DepthLayer.Id.DANGER


func cave_fill_for_layer(layer_id: int) -> float:
	match layer_id:
		DepthLayer.Id.UNDERGROUND:
			return cave_fill_underground
		DepthLayer.Id.SHALLOW_CAVES:
			return cave_fill_shallow
		DepthLayer.Id.DEEP_CAVES:
			return cave_fill_deep
		DepthLayer.Id.DANGER:
			return cave_fill_danger
		_:
			return 0.0


func cave_radius_for_layer(layer_id: int) -> int:
	match layer_id:
		DepthLayer.Id.UNDERGROUND:
			return 1
		DepthLayer.Id.SHALLOW_CAVES:
			return 2
		DepthLayer.Id.DEEP_CAVES:
			return 3
		DepthLayer.Id.DANGER:
			return 2
		_:
			return 1
