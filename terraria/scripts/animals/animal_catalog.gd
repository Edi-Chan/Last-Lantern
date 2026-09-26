@tool
class_name AnimalCatalog
extends Resource

## Zentrale Wildlife-Liste. Neue Tiere hier registrieren, nicht im Admin-Menue.

@export var animals: Array[Resource] = []


func get_all() -> Array:
	var result: Array = []
	for animal in animals:
		if animal != null and (animal.get("scene") != null or str(animal.get("id")) != ""):
			result.append(animal)
	return result


func get_by_id(animal_id: StringName) -> Resource:
	for animal in animals:
		if animal != null and StringName(str(animal.get("id"))) == animal_id:
			return animal
	return null
