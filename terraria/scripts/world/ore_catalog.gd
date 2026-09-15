@tool
class_name OreCatalog
extends Resource

## Liste aller Erzarten. WorldGenerator erzeugt Adern generisch daraus.

@export var ores: Array[OreData] = []


func get_by_id(ore_id: StringName) -> OreData:
	for ore in ores:
		if ore != null and ore.ore_id == ore_id:
			return ore
	return null


func get_by_block_id(block_id: int) -> OreData:
	for ore in ores:
		if ore != null and ore.block_id == block_id:
			return ore
	return null
