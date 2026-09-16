@tool
extends McpTestSuite


func suite_name() -> String:
	return "vegetation"


func test_item_type_plant_enum() -> void:
	assert_eq(int(ItemData.ItemType.SEED), 6)
	assert_eq(int(ItemData.ItemType.PLANT), 7)


func test_plant_items_exist() -> void:
	var paths := [
		"res://resources/items/plants/white_wildflower.tres",
		"res://resources/items/plants/yellow_wildflower.tres",
		"res://resources/items/plants/red_wildflower.tres",
		"res://resources/items/plants/blue_wildflower.tres",
		"res://resources/items/plants/purple_wildflower.tres",
		"res://resources/items/plants/wild_grass.tres",
		"res://resources/items/plants/tall_grass.tres",
		"res://resources/items/plants/fern.tres",
		"res://resources/items/plants/bush.tres",
		"res://resources/items/plants/dry_grass.tres",
	]
	var names := ["Weiße Wiesenblume", "Gelbe Wiesenblume", "Rotes Wildkraut", "Blaue Wiesenblume", "Violette Waldblume", "Wildgras", "Hohes Gras", "Farn", "Kleiner Busch", "Trockengras"]
	var ids := [50, 51, 52, 53, 54, 55, 56, 57, 58, 59]
	for i in paths.size():
		var item := load(paths[i]) as ItemData
		assert_ne(item, null, paths[i])
		assert_eq(item.id, ids[i], item.display_name)
		assert_eq(item.display_name, names[i], item.display_name)
		assert_true(item.is_plant(), item.display_name)
		assert_eq(int(item.item_type), int(ItemData.ItemType.PLANT), item.display_name)
		assert_true(item.icon != null, item.display_name)
		assert_eq(item.get_kind_display_name(), "Pflanze", item.display_name)
		assert_eq(item.sell_value, 0, item.display_name)
		assert_eq(item.damage, 0, item.display_name)
		assert_eq(item.placeable_block_id, -1, item.display_name)
		assert_true(not item.is_placeable(), item.display_name)
		assert_true(not item.is_seed(), item.display_name)
	var catalog_text := FileAccess.get_file_as_string("res://resources/items/item_catalog.tres")
	assert_true(catalog_text.contains("white_wildflower.tres"), "catalog lists plants")


func test_plant_catalog_biomes() -> void:
	var catalog := load("res://resources/plants/plant_catalog.tres") as PlantCatalog
	assert_ne(catalog, null, "plant_catalog")
	assert_eq(catalog.plants.size(), 10, "plant count")
	var grass := catalog.plants_for_biome(&"grassland")
	var forest := catalog.plants_for_biome(&"forest")
	var sand := catalog.plants_for_biome(&"sand")
	assert_true(grass.size() >= 5, "grassland plants")
	assert_true(forest.size() >= 3, "forest plants")
	assert_eq(sand.size(), 1, "sand plants")
	assert_eq(String(sand[0].plant_id), "dry_grass", "dry grass")
	var fern := catalog.get_by_id(&"fern")
	assert_ne(fern, null, "fern")
	assert_true(fern.allows_biome(&"forest"), "fern forest")
	assert_true(not fern.allows_biome(&"sand"), "fern not sand")
	assert_true(fern.allows_ground(1), "fern grass")
	assert_true(not fern.allows_ground(4), "fern not sand tile")
	var dry := catalog.get_by_item_id(59)
	assert_ne(dry, null, "dry by item")
	assert_true(dry.allows_ground(4), "dry sand tile")
	assert_true(not dry.allows_ground(1), "dry not grass")


func test_day_cycle_celestial_fades() -> void:
	var day := DayCycle.new()
	assert_true(day.sun_visibility_at(0.5) > 0.8, "noon sun")
	assert_true(day.sun_visibility_at(0.9) < 0.2, "night sun")
	assert_true(day.moon_visibility_at(0.9) > 0.8, "night moon")
	assert_true(day.moon_visibility_at(0.5) < 0.2, "day moon")
	assert_true(day.star_visibility_at(0.9) > 0.8, "night stars")
	assert_true(day.star_visibility_at(0.4) < 0.05, "day stars")
	assert_true(day.star_visibility_at(0.7) > 0.0, "evening stars")
	day.free()


func test_world_has_vegetation_nodes() -> void:
	var text := FileAccess.get_file_as_string("res://scenes/world/world.tscn")
	assert_true(text.contains("VegetationSystem"), "vegetation node")
	assert_true(text.contains("SurfaceSky"), "surface sky node")
	assert_true(text.contains("plant_catalog.tres"), "plant catalog")
	assert_true(text.contains("surface_background.gd"), "surface script")
