class_name BuildingInstance
extends RefCounted

## Laufzeitdaten einer platzierten Gebaeudeinstanz. Kein Node, speicherbar.

var instance_id: String = ""
var building_type: StringName = &"FORGE"
var blueprint_id: StringName = &"forge"
var origin: Vector2i = Vector2i.ZERO
var facing: int = 0
var state: int = BuildingBlueprintResource.BuildingState.INTACT
var core_intact: bool = true
var door_intact: bool = true
var entrance_ok: bool = true
var original_count: int = 0
var present_count: int = 0
var missing_count: int = 0
var components: Dictionary = {}
var door_cell: Vector2i = Vector2i.ZERO
var return_cell: Vector2i = Vector2i.ZERO
var core_cell: Vector2i = Vector2i.ZERO
var exterior_path: NodePath = NodePath()
var indestructible: bool = false


func to_save_dict() -> Dictionary:
	var saved_components: Array = []
	for key in components.keys():
		var cell: Vector2i = key
		var data: Dictionary = components[key]
		saved_components.append({
			"x": cell.x,
			"y": cell.y,
			"block_id": int(data.get("block_id", -1)),
			"role": int(data.get("role", 0)),
			"critical": bool(data.get("critical", false)),
			"decoration": bool(data.get("decoration", false)),
			"present": bool(data.get("present", true)),
			"removal_cause": int(data.get("removal_cause", 0)),
		})
	return {
		"instance_id": instance_id,
		"building_type": String(building_type),
		"blueprint_id": String(blueprint_id),
		"origin": [origin.x, origin.y],
		"facing": facing,
		"state": state,
		"core_intact": core_intact,
		"door_intact": door_intact,
		"entrance_ok": entrance_ok,
		"original_count": original_count,
		"present_count": present_count,
		"missing_count": missing_count,
		"door_cell": [door_cell.x, door_cell.y],
		"return_cell": [return_cell.x, return_cell.y],
		"core_cell": [core_cell.x, core_cell.y],
		"indestructible": indestructible,
		"components": saved_components,
	}


static func from_save_dict(data: Dictionary) -> BuildingInstance:
	var inst := BuildingInstance.new()
	inst.instance_id = str(data.get("instance_id", ""))
	inst.building_type = StringName(str(data.get("building_type", "FORGE")))
	inst.blueprint_id = StringName(str(data.get("blueprint_id", "forge")))
	var origin_a: Array = data.get("origin", [0, 0])
	inst.origin = Vector2i(int(origin_a[0]), int(origin_a[1]))
	inst.facing = int(data.get("facing", 0))
	inst.state = int(data.get("state", 0))
	inst.core_intact = bool(data.get("core_intact", true))
	inst.door_intact = bool(data.get("door_intact", true))
	inst.entrance_ok = bool(data.get("entrance_ok", true))
	inst.original_count = int(data.get("original_count", 0))
	inst.present_count = int(data.get("present_count", 0))
	inst.missing_count = int(data.get("missing_count", 0))
	var door_a: Array = data.get("door_cell", [0, 0])
	inst.door_cell = Vector2i(int(door_a[0]), int(door_a[1]))
	var ret_a: Array = data.get("return_cell", [0, 0])
	inst.return_cell = Vector2i(int(ret_a[0]), int(ret_a[1]))
	var core_a: Array = data.get("core_cell", [0, 0])
	inst.core_cell = Vector2i(int(core_a[0]), int(core_a[1]))
	inst.indestructible = bool(data.get("indestructible", false))
	for entry in data.get("components", []):
		if not (entry is Dictionary):
			continue
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		inst.components[cell] = {
			"block_id": int(entry.get("block_id", -1)),
			"role": int(entry.get("role", 0)),
			"critical": bool(entry.get("critical", false)),
			"decoration": bool(entry.get("decoration", false)),
			"present": bool(entry.get("present", true)),
			"removal_cause": int(entry.get("removal_cause", 0)),
		}
	return inst
