@tool
class_name ItemCatalog
extends Resource

## Sucht Itemdaten anhand der Item-ID.

@export var items: Array[ItemData] = []

func get_item(item_id: int) -> ItemData:
	for item in items:
		if item != null and item.id == item_id:
			return item
	return null


func get_all_items() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for item in items:
		if item != null:
			result.append(item)
	return result
