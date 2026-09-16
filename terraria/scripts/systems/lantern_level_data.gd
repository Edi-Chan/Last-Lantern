@tool
class_name LanternLevelData
extends Resource

## Eine Laternenstufe. Kosten gelten fuer das Upgrade AUF diese Stufe.

@export var level: int = 1
@export var display_name: String = "Alte Laterne"
@export_multiline var description: String = ""
@export var safe_radius_tiles: int = 44
@export var light_energy: float = 1.15
@export var light_texture_scale: float = 4.0
@export var texture: Texture2D
@export var sprite_width_px: float = 48.0
@export var cost_item_ids: Array[int] = []
@export var cost_amounts: Array[int] = []


func get_upgrade_costs() -> Array[Dictionary]:
	var costs: Array[Dictionary] = []
	var n := mini(cost_item_ids.size(), cost_amounts.size())
	for i in n:
		if cost_amounts[i] <= 0:
			continue
		costs.append({
			"item_id": cost_item_ids[i],
			"amount": cost_amounts[i],
		})
	return costs
