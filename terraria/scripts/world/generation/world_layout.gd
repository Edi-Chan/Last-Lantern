class_name WorldLayout
extends RefCounted

## Reservierte Weltregionen. Gleicher Seed + gleiche Groesse => gleiche Aufteilung.
## Start/Last-Lantern liegt immer in der Weltmitte. Meer und Festung an den Enden.

var size_id: int = WorldSize.Id.MEDIUM
var width: int = 1600
var height: int = 480
var base_surface_y: int = 144
var surface_amplitude: int = 22
var ocean_depth: int = 48
var spine_caves: int = 4
var edge_width: int = 3
## True = Meer links, Festung rechts. Die Basis bleibt in der Mitte.
var start_on_left: bool = true
var ocean_x0: int = 0
var ocean_x1: int = 0
var start_x0: int = 0
var start_x1: int = 0
var playable_x0: int = 0
var playable_x1: int = 0
var playable_b_x0: int = 0
var playable_b_x1: int = 0
var fortress_x0: int = 0
var fortress_x1: int = 0
var fortress_approach_x0: int = 0
var fortress_approach_x1: int = 0
var fortress_keep_x0: int = 0
var fortress_keep_x1: int = 0
var lantern_x: int = 0
var spawn_x: int = 0
var fortress_center_x: int = 0
var sea_level: int = 144
var start_surface_y: int = 144


static func build(settings: WorldGenerationSettings, world_size_id: int, world_seed: int) -> WorldLayout:
	var layout := WorldLayout.new()
	var cfg := settings if settings != null else WorldGenerationSettings.new()
	var profile: Dictionary = cfg.size_profile(world_size_id)
	layout.size_id = WorldSize.clamp_id(world_size_id)
	layout.width = maxi(int(profile.get("width", 1600)), 320)
	layout.height = maxi(int(profile.get("height", 480)), 120)
	layout.base_surface_y = int(profile.get("base_surface_y", 144))
	layout.surface_amplitude = int(profile.get("surface_amplitude", 22))
	layout.ocean_depth = maxi(int(profile.get("ocean_depth", 48)), 12)
	layout.spine_caves = maxi(int(profile.get("spine_caves", 4)), 1)
	layout.edge_width = maxi(cfg.world_edge_width, 2)
	layout._assign_regions(
		cfg,
		world_seed,
		maxi(int(profile.get("ocean_width", 288)), 48),
		maxi(int(profile.get("start_width", 96)), 40),
		maxi(int(profile.get("fortress_width", 112)), 40),
		maxi(int(profile.get("fortress_approach_width", 144)), 48)
	)
	return layout


func _assign_regions(cfg: WorldGenerationSettings, world_seed: int, ocean_w: int, start_w: int, keep_w: int, approach_w: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 101 * 7919
	start_on_left = rng.randf() < 0.5

	var inner0 := edge_width
	var inner1 := width - edge_width
	var inner := maxi(inner1 - inner0, 160)
	var side_min := maxi(cfg.min_playable_width, 80)
	start_w = mini(start_w, maxi(int(inner / 6.0), 40))
	var center := int(float(width) * 0.5)
	start_x0 = center - int(start_w / 2.0)
	start_x1 = start_x0 + start_w
	if start_x0 < inner0 + side_min + 24:
		start_x0 = inner0 + side_min + 24
		start_x1 = start_x0 + start_w
	if start_x1 > inner1 - side_min - 24:
		start_x1 = inner1 - side_min - 24
		start_x0 = start_x1 - start_w

	var left_room := maxi(start_x0 - inner0, 48)
	var right_room := maxi(inner1 - start_x1, 48)
	if start_on_left:
		var left_need := ocean_w + side_min
		if left_need > left_room:
			ocean_w = maxi(48, left_room - side_min)
		var right_need := keep_w + approach_w + side_min
		if right_need > right_room:
			var scale := float(maxi(right_room - side_min, 64)) / float(maxi(keep_w + approach_w, 1))
			keep_w = maxi(40, int(round(float(keep_w) * scale)))
			approach_w = maxi(48, int(round(float(approach_w) * scale)))
		ocean_x0 = inner0
		ocean_x1 = inner0 + ocean_w
		playable_x0 = ocean_x1
		playable_x1 = start_x0
		fortress_keep_x1 = inner1
		fortress_keep_x0 = inner1 - keep_w
		fortress_approach_x1 = fortress_keep_x0
		fortress_approach_x0 = fortress_keep_x0 - approach_w
		fortress_x0 = fortress_approach_x0
		fortress_x1 = fortress_keep_x1
		playable_b_x0 = start_x1
		playable_b_x1 = fortress_x0
	else:
		var right_need := ocean_w + side_min
		if right_need > right_room:
			ocean_w = maxi(48, right_room - side_min)
		var left_need := keep_w + approach_w + side_min
		if left_need > left_room:
			var scale := float(maxi(left_room - side_min, 64)) / float(maxi(keep_w + approach_w, 1))
			keep_w = maxi(40, int(round(float(keep_w) * scale)))
			approach_w = maxi(48, int(round(float(approach_w) * scale)))
		ocean_x1 = inner1
		ocean_x0 = inner1 - ocean_w
		playable_x0 = start_x1
		playable_x1 = ocean_x0
		fortress_keep_x0 = inner0
		fortress_keep_x1 = inner0 + keep_w
		fortress_approach_x0 = fortress_keep_x1
		fortress_approach_x1 = fortress_keep_x1 + approach_w
		fortress_x0 = fortress_keep_x0
		fortress_x1 = fortress_approach_x1
		playable_b_x0 = fortress_x1
		playable_b_x1 = start_x0

	_clamp_ranges()
	_restore_order()
	lantern_x = clampi(int(float(start_x0 + start_x1) * 0.5), start_x0 + 4, start_x1 - 5)
	var spawn_offset := clampi(cfg.spawn_offset_tiles, 3, 16)
	if start_on_left:
		spawn_x = clampi(lantern_x + spawn_offset, lantern_x + 3, start_x1 - 3)
	else:
		spawn_x = clampi(lantern_x - spawn_offset, start_x0 + 3, lantern_x - 3)
	fortress_center_x = int(floor(float(fortress_keep_x0 + fortress_keep_x1) * 0.5))
	sea_level = base_surface_y + 1
	start_surface_y = base_surface_y


func _clamp_ranges() -> void:
	ocean_x0 = clampi(ocean_x0, edge_width, width - edge_width)
	ocean_x1 = clampi(maxi(ocean_x1, ocean_x0 + 16), ocean_x0 + 16, width - edge_width)
	start_x0 = clampi(start_x0, edge_width + 16, width - edge_width - 16)
	start_x1 = clampi(maxi(start_x1, start_x0 + 16), start_x0 + 16, width - edge_width - 16)
	fortress_keep_x0 = clampi(fortress_keep_x0, edge_width, width - edge_width)
	fortress_keep_x1 = clampi(maxi(fortress_keep_x1, fortress_keep_x0 + 16), fortress_keep_x0 + 16, width - edge_width)
	fortress_approach_x0 = clampi(fortress_approach_x0, edge_width, width - edge_width)
	fortress_approach_x1 = clampi(maxi(fortress_approach_x1, fortress_approach_x0 + 12), fortress_approach_x0 + 12, width - edge_width)
	fortress_x0 = mini(fortress_keep_x0, fortress_approach_x0)
	fortress_x1 = maxi(fortress_keep_x1, fortress_approach_x1)
	playable_x0 = clampi(playable_x0, edge_width, width - edge_width)
	playable_x1 = clampi(maxi(playable_x1, playable_x0 + 1), playable_x0 + 1, width - edge_width)
	playable_b_x0 = clampi(playable_b_x0, edge_width, width - edge_width)
	playable_b_x1 = clampi(maxi(playable_b_x1, playable_b_x0 + 1), playable_b_x0 + 1, width - edge_width)


func _restore_order() -> void:
	if start_on_left:
		if ocean_x1 > playable_x0:
			playable_x0 = ocean_x1
		if playable_x1 > start_x0:
			playable_x1 = start_x0
		if playable_b_x0 < start_x1:
			playable_b_x0 = start_x1
		if playable_b_x1 > fortress_x0:
			playable_b_x1 = fortress_x0
		if fortress_approach_x1 > fortress_keep_x0:
			fortress_approach_x1 = fortress_keep_x0
	else:
		if fortress_approach_x0 < fortress_keep_x1:
			fortress_approach_x0 = fortress_keep_x1
		if playable_b_x0 < fortress_x1:
			playable_b_x0 = fortress_x1
		if playable_b_x1 > start_x0:
			playable_b_x1 = start_x0
		if playable_x0 < start_x1:
			playable_x0 = start_x1
		if playable_x1 > ocean_x0:
			playable_x1 = ocean_x0
	fortress_x0 = mini(fortress_keep_x0, fortress_approach_x0)
	fortress_x1 = maxi(fortress_keep_x1, fortress_approach_x1)
	playable_x1 = maxi(playable_x1, playable_x0 + 1)
	playable_b_x1 = maxi(playable_b_x1, playable_b_x0 + 1)


func start_width() -> int:
	return maxi(start_x1 - start_x0, 1)


func ocean_width() -> int:
	return maxi(ocean_x1 - ocean_x0, 1)


func fortress_width() -> int:
	return maxi(fortress_x1 - fortress_x0, 1)


func fortress_keep_width() -> int:
	return maxi(fortress_keep_x1 - fortress_keep_x0, 1)


func fortress_approach_width() -> int:
	return maxi(fortress_approach_x1 - fortress_approach_x0, 1)


func playable_width() -> int:
	return maxi(playable_x1 - playable_x0, 0) + maxi(playable_b_x1 - playable_b_x0, 0)


func is_ocean_column(tile_x: int) -> bool:
	return tile_x >= ocean_x0 and tile_x < ocean_x1


func is_start_column(tile_x: int) -> bool:
	return tile_x >= start_x0 and tile_x < start_x1


func is_fortress_column(tile_x: int) -> bool:
	return tile_x >= fortress_x0 and tile_x < fortress_x1


func is_fortress_keep_column(tile_x: int) -> bool:
	return tile_x >= fortress_keep_x0 and tile_x < fortress_keep_x1


func is_fortress_approach_column(tile_x: int) -> bool:
	return tile_x >= fortress_approach_x0 and tile_x < fortress_approach_x1


func is_playable_column(tile_x: int) -> bool:
	return (tile_x >= playable_x0 and tile_x < playable_x1) \
		or (tile_x >= playable_b_x0 and tile_x < playable_b_x1)


func is_edge_column(tile_x: int) -> bool:
	return tile_x < edge_width or tile_x >= width - edge_width


func is_start_centered() -> bool:
	var center := int(float(width) * 0.5)
	return absi(lantern_x - center) <= maxi(start_width(), int(float(width) * 0.08))


func opposite_of_start_is_fortress() -> bool:
	var start_mid := int(float(start_x0 + start_x1) * 0.5)
	if start_on_left:
		return fortress_center_x > start_mid and ocean_x1 <= start_x0
	return fortress_center_x < start_mid and ocean_x0 >= start_x1


func clamp_playable_x(tile_x: int, margin: int = 4) -> int:
	if is_playable_column(tile_x):
		if tile_x >= playable_x0 and tile_x < playable_x1:
			return clampi(tile_x, playable_x0 + margin, playable_x1 - margin - 1)
		return clampi(tile_x, playable_b_x0 + margin, playable_b_x1 - margin - 1)
	var a_mid := int(float(playable_x0 + playable_x1) * 0.5)
	var b_mid := int(float(playable_b_x0 + playable_b_x1) * 0.5)
	if absi(tile_x - a_mid) <= absi(tile_x - b_mid):
		return clampi(a_mid, playable_x0 + margin, playable_x1 - margin - 1)
	return clampi(b_mid, playable_b_x0 + margin, playable_b_x1 - margin - 1)


func random_playable_x(rng: RandomNumberGenerator, margin: int = 6) -> int:
	var a0 := playable_x0 + margin
	var a1 := playable_x1 - margin
	var b0 := playable_b_x0 + margin
	var b1 := playable_b_x1 - margin
	var a_span := maxi(a1 - a0, 0)
	var b_span := maxi(b1 - b0, 0)
	var total := a_span + b_span
	if total <= 0:
		return lantern_x
	var pick := rng.randi_range(0, total - 1)
	if pick < a_span:
		return a0 + pick
	return b0 + (pick - a_span)
