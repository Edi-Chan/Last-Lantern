@tool
class_name PlayerEquipmentValidator
extends RefCounted

## Prueft Player- und Ruestungs-SpriteFrames gegen den Animation Contract.
## Aufruf: PlayerEquipmentValidator.run() oder Editor-Tool.

const REQUIRED_FRAMES := [
	"res://resources/player/body_frames.tres",
	"res://resources/player/hair_back_frames.tres",
	"res://resources/player/hair_front_frames.tres",
	"res://resources/player/shirt_frames.tres",
	"res://resources/player/pants_frames.tres",
	"res://resources/player/shoes_frames.tres",
	"res://resources/player/player_frames.tres",
	"res://resources/player/armor_helmet_frames.tres",
	"res://resources/player/armor_chest_frames.tres",
	"res://resources/player/armor_legs_frames.tres",
	"res://resources/player/armor_wood_helmet_frames.tres",
	"res://resources/player/armor_wood_chest_frames.tres",
	"res://resources/player/armor_wood_legs_frames.tres",
	"res://resources/player/armor_copper_helmet_frames.tres",
	"res://resources/player/armor_ferrite_helmet_frames.tres",
	"res://resources/player/armor_astralith_helmet_frames.tres",
]

const SHEETS := [
	"res://assets/player/sheets/body.png",
	"res://assets/player/sheets/composed.png",
	"res://assets/player/sheets/armor_metal_helmet.png",
	"res://assets/player/sheets/armor_wood_helmet.png",
	"res://assets/player/sheets/armor_copper_helmet.png",
	"res://assets/player/sheets/armor_voidium_chest.png",
	"res://assets/player/sheets/armor_astralith_legs.png",
]


static func run() -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	var expected := PlayerAnimationContract.sheet_size()
	for path in SHEETS:
		if not ResourceLoader.exists(path):
			errors.append("Missing sheet: %s" % path)
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			errors.append("Sheet is not a texture: %s" % path)
			continue
		if tex.get_width() != expected.x or tex.get_height() != expected.y:
			errors.append("%s size %dx%d, expected %dx%d" % [path, tex.get_width(), tex.get_height(), expected.x, expected.y])
		if tex.get_width() % PlayerAnimationContract.FRAME_WIDTH != 0:
			errors.append("%s width is not a multiple of frame width" % path)
	for path in REQUIRED_FRAMES:
		_validate_frames(path, errors, warnings)
	var catalog := load("res://resources/items/item_catalog.tres") as ItemCatalog
	if catalog != null:
		_validate_catalog(catalog, errors, warnings)
	else:
		errors.append("ItemCatalog missing")
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}


static func _validate_frames(path: String, errors: PackedStringArray, warnings: PackedStringArray) -> void:
	if not ResourceLoader.exists(path):
		errors.append("Missing SpriteFrames: %s" % path)
		return
	var frames := load(path) as SpriteFrames
	if frames == null:
		errors.append("Not SpriteFrames: %s" % path)
		return
	for spec in PlayerAnimationContract.ANIMS:
		var anim: StringName = spec["name"]
		var want := int(spec["frames"])
		if not frames.has_animation(anim):
			warnings.append("%s missing animation: %s" % [path.get_file(), String(anim)])
			continue
		var got := frames.get_frame_count(anim)
		if got != want:
			warnings.append("%s animation %s has %d frames, contract expects %d" % [path.get_file(), String(anim), got, want])
		for i in got:
			var tex := frames.get_frame_texture(anim, i)
			if tex == null:
				errors.append("%s %s frame %d has no texture" % [path.get_file(), String(anim), i])
				continue
			if tex.get_width() != PlayerAnimationContract.FRAME_WIDTH or tex.get_height() != PlayerAnimationContract.FRAME_HEIGHT:
				errors.append("%s %s frame %d is %dx%d" % [path.get_file(), String(anim), i, tex.get_width(), tex.get_height()])


static func _validate_catalog(catalog: ItemCatalog, errors: PackedStringArray, warnings: PackedStringArray) -> void:
	var items: Array = catalog.get_all_items() if catalog != null else []
	for item in items:
		var data := item as ItemData
		if data == null:
			continue
		if data.equipment_slot == ItemData.EquipmentSlot.NONE:
			continue
		if data.equipment_slot == ItemData.EquipmentSlot.ACCESSORY:
			continue
		var frames := data.resolve_armor_frames() if data.has_method("resolve_armor_frames") else data.armor_sprite_frames
		if frames == null:
			warnings.append("Armor item '%s' has no overlay frames" % data.display_name)
			continue
		for spec in PlayerAnimationContract.ANIMS:
			var anim: StringName = spec["name"]
			if not frames.has_animation(anim):
				warnings.append("%s missing animation: %s" % [data.display_name, String(anim)])
