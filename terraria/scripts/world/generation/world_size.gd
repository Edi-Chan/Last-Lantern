class_name WorldSize
extends Object

## Feste Weltgroessen. Die Welt wird niemals unendlich generiert.

enum Id {
	SMALL = 0,
	MEDIUM = 1,
	LARGE = 2,
}


static func clamp_id(value: int) -> int:
	return clampi(value, Id.SMALL, Id.LARGE)


static func display_name(size_id: int) -> String:
	match clamp_id(size_id):
		Id.SMALL:
			return "Klein"
		Id.LARGE:
			return "Groß"
		_:
			return "Mittel"


static func description(size_id: int) -> String:
	match clamp_id(size_id):
		Id.SMALL:
			return "Kurze Reise, geringere Tiefe."
		Id.LARGE:
			return "Lange Reise, tiefer Untergrund."
		_:
			return "Standardgroesse."
