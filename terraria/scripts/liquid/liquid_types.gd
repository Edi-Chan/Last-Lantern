class_name LiquidTypes
extends Object

## Fluessigkeitstypen. WATER und LAVA teilen Speicher, Queue und Flow-Logik
## in LiquidSystem. Typ-spezifische Werte stehen in LiquidSettings.

enum Type {
	NONE = 0,
	WATER = 1,
	LAVA = 2,
}

const FULL := 255
const EMPTY := 0
const QUARTER := 64
const HALF := 128
const THREE_QUARTER := 192

## Wasser + Lava wird zu diesem Terrain-Block. Placeholder: Slate, bis
## ein eigenes Obsidian-Asset existiert. Keine neuen Materialien erfunden.
const WATER_LAVA_RESULT_BLOCK_ID := 6
