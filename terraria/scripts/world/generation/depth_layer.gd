class_name DepthLayer
extends Object

## Tiefenebenen des Untergrunds. Parameter und spaetere Systeme hängen daran.

enum Id {
	SURFACE = 0,
	UNDERGROUND = 1,
	SHALLOW_CAVES = 2,
	DEEP_CAVES = 3,
	DANGER = 4,
}


static func display_name(layer_id: int) -> String:
	match layer_id:
		Id.SURFACE:
			return "Surface"
		Id.UNDERGROUND:
			return "Underground"
		Id.SHALLOW_CAVES:
			return "Shallow Caves"
		Id.DEEP_CAVES:
			return "Deep Caves"
		Id.DANGER:
			return "Danger Layer"
		_:
			return "Unknown"


static func region_name(layer_id: int) -> String:
	match layer_id:
		Id.SURFACE:
			return "Surface"
		Id.UNDERGROUND:
			return "Underground"
		Id.SHALLOW_CAVES:
			return "Shallow Caves"
		Id.DEEP_CAVES:
			return "Deep Caves"
		Id.DANGER:
			return "Danger Layer"
		_:
			return "Underground"
