class_name ItemInstanceData
extends RefCounted

## Konkreter Stack im Inventar. Die ItemData-Resource bleibt unangetastet.

var favorite: bool = false
var durability: int = -1
var damage_bonus: int = 0
var tool_power_bonus: int = 0
var speed_bonus: float = 0.0
var durability_bonus: int = 0
var range_bonus: float = 0.0


static func from_item(item: ItemData) -> ItemInstanceData:
	var inst := ItemInstanceData.new()
	if item != null:
		var max_dur := item.get_base_max_durability()
		if max_dur > 0:
			inst.durability = max_dur
	return inst


static func from_slot(slot: Dictionary) -> ItemInstanceData:
	var inst := ItemInstanceData.new()
	inst.favorite = bool(slot.get("favorite", false))
	inst.durability = int(slot.get("durability", -1))
	var upgrades: Dictionary = slot.get("upgrades", {}) as Dictionary
	inst.damage_bonus = int(upgrades.get("damage_bonus", 0))
	inst.tool_power_bonus = int(upgrades.get("tool_power_bonus", 0))
	inst.speed_bonus = float(upgrades.get("speed_bonus", 0.0))
	inst.durability_bonus = int(upgrades.get("durability_bonus", 0))
	inst.range_bonus = float(upgrades.get("range_bonus", 0.0))
	return inst


func to_slot_fields() -> Dictionary:
	return {
		"favorite": favorite,
		"durability": durability,
		"upgrades": {
			"damage_bonus": damage_bonus,
			"tool_power_bonus": tool_power_bonus,
			"speed_bonus": speed_bonus,
			"durability_bonus": durability_bonus,
			"range_bonus": range_bonus,
		},
	}


func effective_damage(item: ItemData) -> int:
	return item.get_base_damage() + damage_bonus if item != null else damage_bonus


func effective_tool_power(item: ItemData) -> int:
	return item.get_base_tool_power() + tool_power_bonus if item != null else tool_power_bonus


func effective_use_speed(item: ItemData) -> float:
	var base := item.get_base_use_speed() if item != null else 1.0
	return base * (1.0 + speed_bonus)


func effective_max_durability(item: ItemData) -> int:
	return item.get_base_max_durability() + durability_bonus if item != null else durability_bonus


func effective_range(item: ItemData) -> float:
	return item.get_base_range() + range_bonus if item != null else range_bonus
