extends RefCounted

## Eine Quelle fuer Blitzfarben und Wahrscheinlichkeiten. Nicht in mehreren Scripts hardcoden.

enum VariantId {
	PURPLE,
	CRIMSON,
	RED,
	VOID_PURPLE,
}

const WEIGHT_PURPLE := 0.45
const WEIGHT_CRIMSON := 0.30
const WEIGHT_RED := 0.20
const WEIGHT_VOID := 0.05

const COLOR_PURPLE := Color(0.78, 0.42, 1.0)
const COLOR_CRIMSON := Color(0.72, 0.06, 0.14)
const COLOR_RED := Color(0.95, 0.14, 0.08)
const COLOR_VOID := Color(0.86, 0.16, 0.62)

const GLOW_PURPLE := Color(0.42, 0.12, 0.72)
const GLOW_CRIMSON := Color(0.38, 0.03, 0.08)
const GLOW_RED := Color(0.55, 0.05, 0.04)
const GLOW_VOID := Color(0.48, 0.06, 0.38)


static func pick_variant(roll: float = -1.0) -> int:
	var r := roll if roll >= 0.0 else randf()
	if r < WEIGHT_PURPLE:
		return VariantId.PURPLE
	if r < WEIGHT_PURPLE + WEIGHT_CRIMSON:
		return VariantId.CRIMSON
	if r < WEIGHT_PURPLE + WEIGHT_CRIMSON + WEIGHT_RED:
		return VariantId.RED
	return VariantId.VOID_PURPLE


static func color_for(id: int) -> Color:
	match id:
		VariantId.CRIMSON:
			return COLOR_CRIMSON
		VariantId.RED:
			return COLOR_RED
		VariantId.VOID_PURPLE:
			return COLOR_VOID
		_:
			return COLOR_PURPLE


static func glow_for(id: int) -> Color:
	match id:
		VariantId.CRIMSON:
			return GLOW_CRIMSON
		VariantId.RED:
			return GLOW_RED
		VariantId.VOID_PURPLE:
			return GLOW_VOID
		_:
			return GLOW_PURPLE


static func variant_name(id: int) -> String:
	match id:
		VariantId.CRIMSON:
			return "CRIMSON"
		VariantId.RED:
			return "RED"
		VariantId.VOID_PURPLE:
			return "VOID_PURPLE"
		_:
			return "PURPLE"
