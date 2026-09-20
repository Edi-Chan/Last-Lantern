class_name DamageTypes
extends Object

## Spiel-Schadensarten. Die UI-Farbe darf diese Werte niemals setzen.
## Weitere Arten spaeter ans Enum anhaengen, keine zweite DamageType-Liste.

enum Type {
	PHYSICAL,
	DARKNESS,
	FIRE,
	FROST,
	HEALING,
	## Vorbereitet, aktuell ungenutzt.
	POISON,
	DROWNING,
	LIGHTNING,
	BLEED,
	HOLY,
	EXPLOSIVE,
	TRUE,
	SHIELD,
}


static func from_legacy(value: Variant) -> int:
	if value == null:
		return Type.PHYSICAL
	if value is int:
		return int(value)
	var key := StringName(str(value))
	match key:
		&"fog", &"darkness", &"DARKNESS":
			return Type.DARKNESS
		&"fire", &"ignitium", &"FIRE":
			return Type.FIRE
		&"frost", &"cryonite", &"cryonit", &"FROST":
			return Type.FROST
		&"heal", &"healing", &"HEALING":
			return Type.HEALING
		_:
			return Type.PHYSICAL
