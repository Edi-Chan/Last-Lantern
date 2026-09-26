class_name LookRecord
extends Resource

const NAME_MAX_LENGTH := 20
const DEFAULT_HAIR := Color(122.0 / 255.0, 72.0 / 255.0, 38.0 / 255.0)
const DEFAULT_SKIN := Color(224.0 / 255.0, 176.0 / 255.0, 138.0 / 255.0)
const DEFAULT_SHIRT := Color(52.0 / 255.0, 108.0 / 255.0, 176.0 / 255.0)
const DEFAULT_PANTS := Color(118.0 / 255.0, 74.0 / 255.0, 44.0 / 255.0)
const DEFAULT_SHOES := Color(62.0 / 255.0, 42.0 / 255.0, 32.0 / 255.0)

@export var character_name: String = ""
@export var hair_style: int = 0
@export var hair_color: Color = DEFAULT_HAIR
@export var skin_color: Color = DEFAULT_SKIN
@export var shirt_color: Color = DEFAULT_SHIRT
@export var pants_color: Color = DEFAULT_PANTS
@export var shoes_color: Color = DEFAULT_SHOES


func normalize() -> void:
	character_name = character_name.strip_edges()
	if character_name.length() > NAME_MAX_LENGTH:
		character_name = character_name.substr(0, NAME_MAX_LENGTH)
	hair_style = maxi(hair_style, 0)
	hair_color.a = 1.0
	skin_color.a = 1.0
	shirt_color.a = 1.0
	pants_color.a = 1.0
	shoes_color.a = 1.0


func is_valid() -> bool:
	normalize()
	return not character_name.is_empty()


func duplicate_look() -> LookRecord:
	var copy := LookRecord.new()
	copy.from_dict(to_dict())
	return copy


func to_dict() -> Dictionary:
	normalize()
	return {
		"character_name": character_name,
		"hair_style": hair_style,
		"hair_color": _color_to_arr(hair_color),
		"skin_color": _color_to_arr(skin_color),
		"shirt_color": _color_to_arr(shirt_color),
		"pants_color": _color_to_arr(pants_color),
		"shoes_color": _color_to_arr(shoes_color),
	}


func from_dict(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	character_name = str(data.get("character_name", ""))
	hair_style = int(data.get("hair_style", 0))
	hair_color = _color_from(data.get("hair_color", null), DEFAULT_HAIR)
	skin_color = _color_from(data.get("skin_color", null), DEFAULT_SKIN)
	shirt_color = _color_from(data.get("shirt_color", null), DEFAULT_SHIRT)
	pants_color = _color_from(data.get("pants_color", null), DEFAULT_PANTS)
	shoes_color = _color_from(data.get("shoes_color", null), DEFAULT_SHOES)
	normalize()


static func _color_to_arr(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


static func _color_from(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var a := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), a)
	if value is Dictionary:
		return Color(
			float(value.get("r", fallback.r)),
			float(value.get("g", fallback.g)),
			float(value.get("b", fallback.b)),
			float(value.get("a", 1.0))
		)
	return fallback
