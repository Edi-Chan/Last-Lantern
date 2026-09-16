@tool
class_name PlantData
extends Resource

## Eine Oberflaechenpflanze. Gameplay-Werte bleiben vorerst leer/deaktiviert.

enum PlantCategory {
	FLOWER,
	GRASS,
	FERN,
	BUSH,
}

@export var plant_id: StringName = &""
@export var display_name: String = ""
@export var plant_category: PlantCategory = PlantCategory.FLOWER
@export var valid_biomes: Array[StringName] = [&"grassland"]
@export var spawn_weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var cluster_chance: float = 0.22
@export var min_cluster_size: int = 2
@export var max_cluster_size: int = 4
## BlockData.id-Werte, auf denen die Pflanze stehen darf. 1=Grass, 2=Dirt, 4=Sand.
@export var valid_ground_types: Array[int] = [1, 2]
@export var can_be_harvested: bool = true
@export var can_be_planted: bool = true
@export var item_id: int = -1
@export var world_texture: Texture2D
@export var wind_strength: float = 0.7
@export var harvest_time: float = 0.06

@export_group("Spaeter")
@export var sell_value: int = 0
@export var healing: int = 0
@export var alchemy_tag: StringName = &""
@export var rarity: int = 0
@export var growth_time: float = 0.0


func allows_biome(biome: StringName) -> bool:
	if valid_biomes.is_empty():
		return true
	return valid_biomes.has(biome)


func allows_ground(block_id: int) -> bool:
	return valid_ground_types.has(block_id)


func cluster_size(rng: RandomNumberGenerator) -> int:
	var lo := mini(min_cluster_size, max_cluster_size)
	var hi := maxi(min_cluster_size, max_cluster_size)
	return rng.randi_range(maxi(lo, 1), maxi(hi, 1))
