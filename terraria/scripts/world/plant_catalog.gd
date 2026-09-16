@tool
class_name PlantCatalog
extends Resource

## Sucht Pflanzendaten nach plant_id, Item-ID oder Biom.

@export var plants: Array[PlantData] = []


func get_by_id(plant_id: StringName) -> PlantData:
	for plant in plants:
		if plant != null and plant.plant_id == plant_id:
			return plant
	return null


func get_by_item_id(item_id: int) -> PlantData:
	if item_id < 0:
		return null
	for plant in plants:
		if plant != null and plant.item_id == item_id:
			return plant
	return null


func plants_for_biome(biome: StringName) -> Array[PlantData]:
	var out: Array[PlantData] = []
	for plant in plants:
		if plant != null and plant.spawn_weight > 0.0 and plant.allows_biome(biome):
			out.append(plant)
	return out


func pick_for_biome(biome: StringName, rng: RandomNumberGenerator) -> PlantData:
	var candidates := plants_for_biome(biome)
	if candidates.is_empty():
		return null
	var total := 0.0
	for plant in candidates:
		total += maxf(plant.spawn_weight, 0.0)
	if total <= 0.0:
		return candidates[0]
	var roll := rng.randf() * total
	var acc := 0.0
	for plant in candidates:
		acc += maxf(plant.spawn_weight, 0.0)
		if roll <= acc:
			return plant
	return candidates[candidates.size() - 1]
