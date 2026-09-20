class_name EnemyCatalog
extends Resource

## Zentrale Gegnerliste. Neue Gegner hier registrieren, nicht im Admin-Menue.

@export var enemies: Array[Resource] = []


func get_all() -> Array:
	var result: Array = []
	for enemy in enemies:
		if enemy != null and enemy.get("scene") != null:
			result.append(enemy)
	return result


func get_by_id(enemy_id: StringName) -> Resource:
	for enemy in enemies:
		if enemy != null and StringName(str(enemy.get("id"))) == enemy_id:
			return enemy
	return null
