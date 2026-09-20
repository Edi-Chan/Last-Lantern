@tool
class_name ItemData
extends Resource

## Daten eines Items. Icons, Typ, Platzierung und Tool-Werte sind inspector-editierbar.

enum ItemType {
	BLOCK,
	TOOL,
	WEAPON,
	ARMOR,
	ACCESSORY,
	MATERIAL,
	SEED,
	PLANT,
	BLUEPRINT,
}

enum EquipmentSlot {
	NONE,
	HEAD,
	CHEST,
	LEGS,
	ACCESSORY,
}

enum ToolKind {
	NONE,
	PICKAXE,
	AXE,
	HAMMER,
	WRENCH,
	HOE,
	SICKLE,
	FISHING_ROD,
	NET,
}
## SHOVEL kann spaeter an dieses Enum angehaengt werden. Dirt/Sand bleiben vorerst NONE.

## Weitere Waffenarten (DAGGER, CROSSBOW, ...) koennen hier angehaengt werden.
enum WeaponKind {
	NONE,
	SWORD,
	SPEAR,
	BOW,
	LANTERN,
}

## Visuelle Hauptkategorie. Genau eine Farbe je Item, zentral aufgeloest.
enum ItemCategory {
	UNASSIGNED,
	WEAPON,
	ARMOR,
	HEALING,
	FOOD_DRINK,
	AMMUNITION,
	BUILDING_MATERIAL,
	RESOURCE,
	ORE_METAL,
	MAGIC_ENERGY,
	TOOL,
	BUFF,
	MONSTER_MATERIAL,
	TRAP_DEFENSE,
	MACHINE_TECH,
	VALUABLE,
	QUEST_KEY,
	BLUEPRINT,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var id: int = 0
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var sell_value: int = 0
@export var icon: Texture2D
@export var max_stack: int = 999
@export var item_type: ItemType = ItemType.MATERIAL
@export var category: ItemCategory = ItemCategory.UNASSIGNED
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var tool_kind: ToolKind = ToolKind.NONE
@export var weapon_kind: WeaponKind = WeaponKind.NONE
## Optionale Werkzeug-Basiswerte. Leer = kein ToolData.
@export var tool_data: ToolData
## Optionale Waffen-Basiswerte. Leer = keine Waffe. Typ: WeaponData.
@export var weapon_data: Resource
@export var ore_data: OreData
@export var ore_metal_category: OreData.OreMetalCategory = OreData.OreMetalCategory.NONE
@export var placeable_block_id: int = -1
@export var building_material: BlockData.BuildingMaterial = BlockData.BuildingMaterial.NONE
@export var building_part_type: BlockData.BuildingPartType = BlockData.BuildingPartType.NONE
@export var material_variant: StringName = &""
@export var can_rotate: bool = false
## Optionaler Gebaeude-Bauplan. Leer = normales Item.
@export var blueprint: BuildingBlueprintResource
## Nur fuer Samen: welche Baumart spaeter / jetzt gepflanzt wird.
@export var tree_type: StringName = &""
## Nur fuer Pflanzen: Verweis auf PlantData.plant_id.
@export var plant_id: StringName = &""
## 1.0 heisst: das 16x16-Icon wird in der Hand 1:1 gezeichnet, ohne Subpixel.
@export var held_scale: float = 1.0
## Zusatzdrehung nur fuer das Held-Item-Sprite, nicht fuer Pivot oder Hitbox.
@export var held_rotation_degrees: float = 0.0
## Basis-Spiegelung der Held-Textur. Facing kommt vom ToolPivot (scale.x).
## Werkzeuge und Waffen werden in der Hand zusaetzlich horizontal gespiegelt,
## weil die Icons den Griff links haben. held_flip_h bleibt fuer Spezialfaelle.
@export var held_flip_h: bool = false
@export var held_flip_v: bool = false
## Optionale Held-Textur. Leer = Inventory-Icon.
@export var held_texture: Texture2D
## Extra-Position des Sprites relativ zur Hand, in Pixeln.
@export var held_offset: Vector2 = Vector2.ZERO
## Sprite2D.offset: verschiebt den Griffpunkt auf den Handursprung.
## (0, 0) = automatischer Default je ToolKind / Itemtyp.
@export var held_pivot_offset: Vector2 = Vector2.ZERO
@export var damage: int = 0
## Obergrenze fuer Schaden. 0 = nur `damage` anzeigen.
@export var damage_max: int = 0
@export var mining_speed: float = 1.0
@export var attack_cooldown: float = 0.35
@export var knockback: float = 100.0
@export var defense: int = 0
## Zusaetzliche Stat-Boni. `defense` bleibt der einfache Ruestungswert.
@export var stat_modifiers: Array[StatModifier] = []
## Optionale Overlay-Frames fuer HEAD/CHEST/LEGS. Leer = kein Player-Overlay.
@export var armor_sprite_frames: SpriteFrames

static var _unassigned_warned: Dictionary = {}


func is_placeable() -> bool:
	return placeable_block_id >= 0


func is_building_blueprint() -> bool:
	return item_type == ItemType.BLUEPRINT or blueprint != null


func is_seed() -> bool:
	return item_type == ItemType.SEED or tree_type != &""


func is_plant() -> bool:
	return item_type == ItemType.PLANT or plant_id != &""


func is_weapon() -> bool:
	return item_type == ItemType.WEAPON or weapon_kind != WeaponKind.NONE


func is_tool() -> bool:
	if is_weapon():
		return false
	return item_type == ItemType.TOOL or get_tool_kind() != ToolKind.NONE or tool_data != null


func collect_stat_modifiers() -> Array[StatModifier]:
	# Bestehende defense-Werte werden als ARMOR-Flat mitgelesen.
	return StatSheet.modifiers_from_item(self)


func get_rarity_display_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Ungewöhnlich"
		Rarity.RARE:
			return "Selten"
		Rarity.EPIC:
			return "Episch"
		Rarity.LEGENDARY:
			return "Legendär"
		_:
			return "Gewöhnlich"


func get_rarity_color() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color(0.38, 0.78, 0.42)
		Rarity.RARE:
			return Color(0.38, 0.58, 0.95)
		Rarity.EPIC:
			return Color(0.74, 0.4, 0.92)
		Rarity.LEGENDARY:
			return Color(0.95, 0.62, 0.22)
		_:
			return Color(0.62, 0.64, 0.68)


func get_kind_display_name() -> String:
	var tool_name := get_tool_kind_display_name(int(get_tool_kind()))
	if not tool_name.is_empty():
		return tool_name
	var weapon_name := get_weapon_kind_display_name(int(weapon_kind))
	if not weapon_name.is_empty():
		return weapon_name
	match item_type:
		ItemType.ARMOR:
			match equipment_slot:
				EquipmentSlot.HEAD:
					return "Helm"
				EquipmentSlot.CHEST:
					return "Brustpanzer"
				EquipmentSlot.LEGS:
					return "Beinschutz"
				_:
					return "Rüstung"
		ItemType.ACCESSORY:
			return "Accessoire"
		ItemType.BLOCK:
			var part := BlockData.part_type_display_name(building_part_type)
			return part if not part.is_empty() else "Block"
		ItemType.SEED:
			return "Samen"
		ItemType.PLANT:
			return "Pflanze"
		ItemType.BLUEPRINT:
			return "Bauplan"
		ItemType.TOOL:
			return "Werkzeug"
		_:
			var cat := get_category_display_name(category)
			return cat if not cat.is_empty() else "Gegenstand"


func get_inspect_subtitle() -> String:
	var cat := get_category_display_name(category)
	var kind := get_kind_display_name()
	var type_name := cat if not cat.is_empty() else kind
	if type_name.is_empty():
		return get_rarity_display_name()
	return "%s · %s" % [get_rarity_display_name(), type_name]


func get_sell_value() -> int:
	if sell_value > 0:
		return sell_value
	if item_type == ItemType.WEAPON or is_tool():
		return maxi(1, get_base_damage())
	if defense > 0:
		return maxi(1, defense * 3)
	if max_stack <= 1:
		return 5
	return 1


func get_damage_max() -> int:
	if damage_max > 0:
		return damage_max
	return get_base_damage()


func get_base_damage() -> int:
	if weapon_data != null:
		return int(weapon_data.get("base_damage"))
	return tool_data.base_damage if tool_data != null else damage


func get_base_tool_power() -> int:
	return tool_data.base_tool_power if tool_data != null else 0


func get_base_use_speed() -> float:
	if weapon_data != null:
		return float(weapon_data.get("attack_speed"))
	if tool_data != null:
		return tool_data.base_use_speed
	return mining_speed if mining_speed > 0.0 else 1.0


func get_base_max_durability() -> int:
	if weapon_data != null:
		return int(weapon_data.get("base_max_durability"))
	return tool_data.base_max_durability if tool_data != null else 0


func get_base_range() -> float:
	if weapon_data != null:
		return float(weapon_data.get("base_range"))
	return tool_data.base_range if tool_data != null else 0.0


func get_special() -> String:
	var weapon_special := str(weapon_data.get("special")) if weapon_data != null else ""
	if not weapon_special.is_empty():
		return weapon_special
	return tool_data.special if tool_data != null else ""


func get_weapon_tier() -> int:
	return int(weapon_data.get("tier")) if weapon_data != null else 0


func get_weapon_knockback() -> float:
	if weapon_data != null:
		return float(weapon_data.get("knockback"))
	return knockback


func resolve_attack_cooldown() -> float:
	if weapon_data != null and weapon_data.has_method("get_attack_cooldown"):
		return float(weapon_data.call("get_attack_cooldown"))
	return attack_cooldown if attack_cooldown > 0.0 else 0.35


func get_tool_category() -> ToolData.ToolCategory:
	return tool_data.tool_category if tool_data != null else ToolData.ToolCategory.NONE


func get_tool_kind() -> ToolKind:
	return tool_kind


func get_held_texture() -> Texture2D:
	if held_texture != null:
		return held_texture
	return icon


func get_held_offset() -> Vector2:
	return Vector2(1, 0) + held_offset


func get_held_pivot_offset() -> Vector2:
	if held_pivot_offset != Vector2.ZERO:
		return held_pivot_offset
	return _default_held_pivot()


func get_held_scale() -> float:
	if is_placeable() and not is_tool() and is_equal_approx(held_scale, 1.0):
		return 0.75
	return held_scale


func _default_held_pivot() -> Vector2:
	match get_tool_kind():
		ToolKind.PICKAXE, ToolKind.AXE:
			return Vector2(2, -5)
		ToolKind.HAMMER, ToolKind.HOE, ToolKind.SICKLE:
			return Vector2(1, -4)
		ToolKind.WRENCH:
			return Vector2(1, -3)
		ToolKind.FISHING_ROD:
			return Vector2(0, -6)
		ToolKind.NET:
			return Vector2(1, -4)
		_:
			if is_weapon():
				match weapon_kind:
					WeaponKind.SWORD:
						return Vector2(2, -5)
					WeaponKind.SPEAR:
						return Vector2(1, -2)
					WeaponKind.BOW:
						return Vector2(1, -3)
					WeaponKind.LANTERN:
						return Vector2(0, -3)
					_:
						return Vector2(0, -4)
			if is_placeable():
				return Vector2(0, 1)
			if is_tool():
				return Vector2(0, -4)
			return Vector2(0, 1)


static func get_tool_kind_display_name(kind: int) -> String:
	match kind:
		ToolKind.PICKAXE:
			return "Spitzhacke"
		ToolKind.AXE:
			return "Axt"
		ToolKind.HAMMER:
			return "Hammer"
		ToolKind.WRENCH:
			return "Schraubenschlüssel"
		ToolKind.HOE:
			return "Hacke"
		ToolKind.SICKLE:
			return "Sichel"
		ToolKind.FISHING_ROD:
			return "Angel"
		ToolKind.NET:
			return "Kescher"
		_:
			return ""


static func get_weapon_kind_display_name(kind: int) -> String:
	match kind:
		WeaponKind.SWORD:
			return "Schwert"
		WeaponKind.SPEAR:
			return "Speer"
		WeaponKind.BOW:
			return "Bogen"
		WeaponKind.LANTERN:
			return "Kampflaterne"
		_:
			return ""


func get_ore_metal_category() -> OreData.OreMetalCategory:
	if ore_data != null:
		return ore_data.metal_category
	return ore_metal_category


func get_pickaxe_tier() -> int:
	return tool_data.pickaxe_tier if tool_data != null else 0


static func get_category_color(item_category: ItemCategory) -> Color:
	match item_category:
		ItemCategory.WEAPON:
			return Color("#E53935")
		ItemCategory.ARMOR:
			return Color("#3F7CFF")
		ItemCategory.HEALING:
			return Color("#35C759")
		ItemCategory.FOOD_DRINK:
			return Color("#FF8A30")
		ItemCategory.AMMUNITION:
			return Color("#F4C542")
		ItemCategory.BUILDING_MATERIAL:
			return Color("#9B6A43")
		ItemCategory.RESOURCE:
			return Color("#BFC5CC")
		ItemCategory.ORE_METAL:
			return Color("#708090")
		ItemCategory.MAGIC_ENERGY:
			return Color("#9C5CFF")
		ItemCategory.TOOL:
			return Color("#24C7C8")
		ItemCategory.BUFF:
			return Color("#E65CA8")
		ItemCategory.MONSTER_MATERIAL:
			return Color("#6336A8")
		ItemCategory.TRAP_DEFENSE:
			return Color("#665044")
		ItemCategory.MACHINE_TECH:
			return Color("#31558C")
		ItemCategory.VALUABLE:
			return Color("#E6B422")
		ItemCategory.QUEST_KEY:
			return Color("#E8E8E8")
		ItemCategory.BLUEPRINT:
			return Color("#C4A35A")
		_:
			return Color(0, 0, 0, 0)


static func get_category_display_name(item_category: ItemCategory) -> String:
	match item_category:
		ItemCategory.WEAPON:
			return "Waffen"
		ItemCategory.ARMOR:
			return "Rüstung"
		ItemCategory.HEALING:
			return "Heilung"
		ItemCategory.FOOD_DRINK:
			return "Nahrung & Getränke"
		ItemCategory.AMMUNITION:
			return "Munition"
		ItemCategory.BUILDING_MATERIAL:
			return "Baumaterialien"
		ItemCategory.RESOURCE:
			return "Rohstoffe"
		ItemCategory.ORE_METAL:
			return "Erze & Metalle"
		ItemCategory.MAGIC_ENERGY:
			return "Magie / Energie"
		ItemCategory.TOOL:
			return "Werkzeuge"
		ItemCategory.BUFF:
			return "Buffs / Booster"
		ItemCategory.MONSTER_MATERIAL:
			return "Monster-Materialien"
		ItemCategory.TRAP_DEFENSE:
			return "Fallen & Verteidigung"
		ItemCategory.MACHINE_TECH:
			return "Maschinen / Technik"
		ItemCategory.VALUABLE:
			return "Wertgegenstände"
		ItemCategory.QUEST_KEY:
			return "Quest / Schlüsselitems"
		ItemCategory.BLUEPRINT:
			return "Baupläne / Gebäude"
		_:
			return ""


## Inventar und Hotbar nutzen dieselbe Anzeige: leer oder UNASSIGNED = unsichtbar.
static func apply_category_indicator(border: ColorRect, fill: ColorRect, item: ItemData, amount: int) -> void:
	if border == null:
		return
	if item == null or amount <= 0 or item.category == ItemCategory.UNASSIGNED:
		border.visible = false
		if item != null and amount > 0:
			item.warn_unassigned_once()
		return
	border.visible = true
	if fill != null:
		fill.color = get_category_color(item.category)


func warn_unassigned_once() -> void:
	if category != ItemCategory.UNASSIGNED:
		return
	if not OS.is_debug_build():
		return
	if _unassigned_warned.has(id):
		return
	_unassigned_warned[id] = true
	push_warning("Item '%s' has no item category assigned." % display_name)
