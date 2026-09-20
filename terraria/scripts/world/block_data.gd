@tool
class_name BlockData
extends Resource

## Daten eines Welt-Tiles. Atlas-Koordinaten muessen zum vorhandenen TileSet passen.

enum BreakCheck {
	CAN_BREAK,
	UNBREAKABLE,
	WRONG_TOOL,
	TOOL_TOO_WEAK,
}

enum StructuralRole {
	NONE,
	FOUNDATION,
	STRUCTURAL_BLOCK,
	SUPPORT_BEAM,
	BEAM,
	ROOF,
}

## Materialskins spaeter (Eiche/Birke/Ziegel) ohne neue Mechanik je Variante.
enum BuildingMaterial {
	NONE,
	WOOD,
	STONE,
	BRICK,
	METAL,
}

enum BuildingPartType {
	NONE,
	FOUNDATION,
	WALL,
	BACKGROUND_WALL,
	FLOOR,
	ROOF,
	SUPPORT,
	BEAM,
	PLATFORM,
	STAIRS,
	LADDER,
	DOOR,
	WINDOW,
	LIGHT,
	STORAGE,
	CRAFTING_STATION,
	DEFENSE,
	DECORATION,
	BED,
}

@export var id: int = 0
@export var display_name: String = ""
@export var atlas_coords: Vector2i = Vector2i.ZERO
## 0 = Terrain-Atlas, 1 = Building-Atlas.
@export var atlas_source_id: int = 0
## Anzahl Nachbar-Varianten in einer Atlas-Zeile. 1 = festes Tile, 16 = 4-Wege-Autotile.
@export var autotile_count: int = 1
@export var hardness: float = 1.0
@export var drop_item_id: int = -1
@export var solid: bool = true
@export var vision_occlusion: float = -1.0
@export var ore_data: OreData
@export var map_color: Color = Color(0, 0, 0, 0)
@export var required_tool: int = 0
@export var required_tool_power: int = 0
@export var is_unbreakable: bool = false
@export var structural_enabled: bool = false
@export var structural_role: StructuralRole = StructuralRole.NONE
@export var structural_weight: int = 1
@export var support_strength: int = 0
@export var max_horizontal_support: int = 0
@export var is_foundation_material: bool = false
@export var is_support_beam: bool = false
@export var enemy_break_cost: int = 0
@export var structural_importance: int = 0
@export var building_material: BuildingMaterial = BuildingMaterial.NONE
@export var building_part_type: BuildingPartType = BuildingPartType.NONE
## Reserviert fuer spaetere Holzarten/Material-Skins. Leer = Standard.
@export var material_variant: StringName = &""
@export var flammable: bool = false
@export var is_background: bool = false
@export var is_one_way: bool = false
@export var is_climbable: bool = false
@export var uses_orientation: bool = false
@export var footprint: Vector2i = Vector2i.ONE
## Optional: interaktive Szene statt reinem Tile (Tuer, Station, Licht).
@export var entity_scene: PackedScene
@export var light_energy: float = 0.0

func get_required_tool() -> int:
	if ore_data != null:
		return int(ore_data.required_tool)
	return int(required_tool)

func get_required_tool_power() -> int:
	if ore_data != null:
		return ore_data.get_required_tool_power()
	return required_tool_power

func get_required_pickaxe_power() -> int:
	return get_required_tool_power()

func is_block_unbreakable() -> bool:
	return is_unbreakable or hardness >= 100.0

func allows_bare_hands() -> bool:
	if is_block_unbreakable():
		return false
	if is_building_part():
		return false
	var need_kind := get_required_tool()
	var need_power := get_required_tool_power()
	if need_kind == 0 and need_power <= 0:
		return true
	# Natuerliches Holz und Baumstaemme. Stein, Erze und gebaute Teile bleiben gesperrt.
	return need_kind == 2 and need_power <= 1


func evaluate_break(item: Resource = null, inst: RefCounted = null) -> BreakCheck:
	if is_block_unbreakable():
		return BreakCheck.UNBREAKABLE
	var need_kind := get_required_tool()
	var need_power := get_required_tool_power()
	if need_kind == 0 and need_power <= 0:
		return BreakCheck.CAN_BREAK
	if item == null:
		return BreakCheck.CAN_BREAK if allows_bare_hands() else BreakCheck.WRONG_TOOL
	if item.get("tool_data") == null:
		return BreakCheck.WRONG_TOOL
	if int(item.get("tool_kind")) != need_kind:
		return BreakCheck.WRONG_TOOL
	var power := 0
	if inst != null and inst.has_method("effective_tool_power"):
		power = int(inst.call("effective_tool_power", item))
	elif item.has_method("get_base_tool_power"):
		power = int(item.call("get_base_tool_power"))
	if power < need_power:
		return BreakCheck.TOOL_TOO_WEAK
	return BreakCheck.CAN_BREAK

func can_break_with(item: Resource = null, inst: RefCounted = null) -> bool:
	return evaluate_break(item, inst) == BreakCheck.CAN_BREAK

func get_map_color() -> Color:
	if map_color.a > 0.0:
		return map_color
	if ore_data != null:
		return ore_data.map_color
	return Color(0, 0, 0, 0)

func get_vision_occlusion() -> float:
	if vision_occlusion >= 0.0:
		return vision_occlusion
	if is_background or building_part_type == BuildingPartType.BACKGROUND_WALL:
		return 0.12
	if building_part_type == BuildingPartType.WINDOW:
		return 0.18
	match id:
		0:
			return 0.0
		8, 17, 18, 19:
			return 0.2
		7, 14, 15, 16:
			return 0.5
		20, 21, 22:
			return 0.1
		4:
			return 0.9
		_:
			return 1.0 if solid else 0.0


func is_stair() -> bool:
	return building_part_type == BuildingPartType.STAIRS


func is_building_part() -> bool:
	return building_part_type != BuildingPartType.NONE


func is_player_passable() -> bool:
	return not solid


func connects_visually() -> bool:
	return autotile_count > 1


func variant_atlas(mask: int) -> Vector2i:
	if autotile_count <= 1:
		return atlas_coords
	return Vector2i(atlas_coords.x + clampi(mask, 0, autotile_count - 1), atlas_coords.y)


func occupies_background_layer() -> bool:
	return is_background \
		or building_part_type == BuildingPartType.BACKGROUND_WALL \
		or building_part_type == BuildingPartType.WINDOW


static func part_type_display_name(part: BuildingPartType) -> String:
	match part:
		BuildingPartType.FOUNDATION:
			return "Fundament"
		BuildingPartType.WALL:
			return "Wand"
		BuildingPartType.BACKGROUND_WALL:
			return "Hintergrundwand"
		BuildingPartType.FLOOR:
			return "Boden"
		BuildingPartType.ROOF:
			return "Dach"
		BuildingPartType.SUPPORT:
			return "Stütze"
		BuildingPartType.BEAM:
			return "Balken"
		BuildingPartType.PLATFORM:
			return "Plattform"
		BuildingPartType.STAIRS:
			return "Treppe"
		BuildingPartType.LADDER:
			return "Leiter"
		BuildingPartType.DOOR:
			return "Tür"
		BuildingPartType.WINDOW:
			return "Fenster"
		BuildingPartType.LIGHT:
			return "Beleuchtung"
		BuildingPartType.STORAGE:
			return "Einrichtung"
		BuildingPartType.CRAFTING_STATION:
			return "Station"
		BuildingPartType.DEFENSE:
			return "Verteidigung"
		BuildingPartType.DECORATION:
			return "Einrichtung"
		BuildingPartType.BED:
			return "Bett"
		_:
			return ""


static func material_display_name(material: BuildingMaterial) -> String:
	match material:
		BuildingMaterial.WOOD:
			return "Holz"
		BuildingMaterial.STONE:
			return "Stein"
		BuildingMaterial.BRICK:
			return "Ziegel"
		BuildingMaterial.METAL:
			return "Metall"
		_:
			return ""


func get_audio_material() -> StringName:
	if ore_data != null:
		return &"ore"
	match building_material:
		BuildingMaterial.WOOD:
			return &"wood"
		BuildingMaterial.METAL:
			return &"metal"
		BuildingMaterial.STONE, BuildingMaterial.BRICK:
			return &"stone"
	match id:
		1, 8, 17, 18, 19, 20, 21, 22:
			return &"grass"
		2:
			return &"dirt"
		4:
			return &"sand"
		7, 14, 15, 16:
			return &"wood"
		_:
			return &"stone" if solid else &"dirt"
