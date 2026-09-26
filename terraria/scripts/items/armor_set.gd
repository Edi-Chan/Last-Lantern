@tool
class_name ArmorSet
extends Object

## Stabile Set-IDs. Gameplay fragt diese Konstanten ab, niemals Anzeigenamen.

const NONE := &""
const WOOD := &"WOOD"
const COPPER := &"COPPER"
const TIN := &"TIN"
const FERRITE := &"FERRITE"
const AUREL := &"AUREL"
const COBALT := &"COBALT"
const VEYRITE := &"VEYRITE"
const CRYONITE := &"CRYONITE"
const IGNITIUM := &"IGNITIUM"
const VOIDIUM := &"VOIDIUM"
const ASTRALITH := &"ASTRALITH"


static func all_ids() -> Array[StringName]:
	return [
		WOOD, COPPER, TIN, FERRITE, AUREL, COBALT,
		VEYRITE, CRYONITE, IGNITIUM, VOIDIUM, ASTRALITH,
	]
