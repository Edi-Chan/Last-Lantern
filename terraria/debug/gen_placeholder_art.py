"""Erzeugt die Platzhalter-Pixelart des Projekts.

Aufruf aus dem Projektwurzelverzeichnis:  python debug/gen_placeholder_art.py

Verbindliche Grundmasse:
  Welt-Tile          16 x 16 px
  Player-Frame       40 x 56 px  (Figur steht mit den Fuessen auf der Unterkante)
  Player-Collider    20 x 42 px  (nur Gameplay, nicht die Grafik)

Alle Grafiken sind eigene Platzhalter. Feste Seeds halten das Ergebnis reproduzierbar.
"""

from __future__ import annotations

import random
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TILE_DIR = ROOT / "assets" / "world" / "tiles"
PLAYER_DIR = ROOT / "assets" / "player"
TOOL_DIR = ROOT / "assets" / "items" / "tools"
CLOUD_DIR = ROOT / "assets" / "world" / "background"

TILE = 16
FRAME_W, FRAME_H = 40, 56


def rgba(value: str) -> tuple[int, int, int, int]:
	value = value.lstrip("#")
	return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), 255


CLEAR = (0, 0, 0, 0)


def fill(px, x0: int, y0: int, x1: int, y1: int, color) -> None:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			px[x, y] = color


# --------------------------------------------------------------------------- Tiles


DIRT_BASE = rgba("#7a4a2a")
DIRT_LIGHT = rgba("#925c35")
DIRT_DARK = rgba("#5e3720")
DIRT_PEBBLE = rgba("#472a16")


def make_dirt(seed: int = 11) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), DIRT_BASE)
	px = img.load()
	for y in range(TILE):
		for x in range(TILE):
			roll = rnd.random()
			if roll < 0.12:
				px[x, y] = DIRT_LIGHT
			elif roll < 0.26:
				px[x, y] = DIRT_DARK
	for _ in range(6):
		x = rnd.randrange(1, TILE - 2)
		y = rnd.randrange(1, TILE - 1)
		px[x, y] = DIRT_PEBBLE
		px[x + 1, y] = DIRT_PEBBLE
	return img


STONE_BASE = rgba("#7b7b86")
STONE_LIGHT = rgba("#9a9aa6")
STONE_DARK = rgba("#5d5d68")
STONE_CRACK = rgba("#474751")


def make_stone(seed: int = 22) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), STONE_BASE)
	px = img.load()
	for y in range(TILE):
		for x in range(TILE):
			roll = rnd.random()
			if roll < 0.10:
				px[x, y] = STONE_LIGHT
			elif roll < 0.20:
				px[x, y] = STONE_DARK
	# Dunkle Flecken als 3x2-Blocks, klar von der Erdstruktur unterscheidbar.
	for _ in range(5):
		x = rnd.randrange(0, TILE - 3)
		y = rnd.randrange(0, TILE - 2)
		fill(px, x, y, x + 2, y + 1, STONE_DARK)
		px[x + 1, y] = STONE_CRACK
	for _ in range(7):
		x = rnd.randrange(0, TILE)
		y = rnd.randrange(0, TILE)
		px[x, y] = STONE_LIGHT
	return img


GRASS_TOP = rgba("#4f9e38")
GRASS_LIGHT = rgba("#6cc24a")
GRASS_DARK = rgba("#3b7a29")


def make_grass(seed: int = 33) -> Image.Image:
	rnd = random.Random(seed)
	img = make_dirt(seed=seed)
	px = img.load()
	fill(px, 0, 0, TILE - 1, 2, GRASS_TOP)
	for x in range(TILE):
		if rnd.random() < 0.4:
			px[x, 0] = GRASS_LIGHT
		px[x, 3] = GRASS_DARK if rnd.random() < 0.65 else GRASS_TOP
		# Einzelne gruene Pixel, die in die Erde auslaufen.
		if rnd.random() < 0.45:
			px[x, 4] = GRASS_DARK
		if rnd.random() < 0.18:
			px[x, 5] = GRASS_DARK
	return img


SAND_BASE = rgba("#ddc383")
SAND_LIGHT = rgba("#f0dca8")
SAND_DARK = rgba("#bda066")
SAND_GRAIN = rgba("#a3865110")


def make_sand(seed: int = 44) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), SAND_BASE)
	px = img.load()
	for y in range(TILE):
		for x in range(TILE):
			roll = rnd.random()
			if roll < 0.16:
				px[x, y] = SAND_LIGHT
			elif roll < 0.28:
				px[x, y] = SAND_DARK
	# Waagerechte Riffel, damit Sand nicht wie helles Rauschen wirkt.
	for y in (3, 8, 13):
		x = rnd.randrange(0, 6)
		while x < TILE:
			px[x, y] = SAND_DARK
			x += rnd.randrange(2, 5)
	return img


GRANITE_BASE = rgba("#6b4a48")
GRANITE_LIGHT = rgba("#8a6260")
GRANITE_DARK = rgba("#4e3433")
GRANITE_SPECK = rgba("#a87a70")


def make_granite(seed: int = 55) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), GRANITE_BASE)
	px = img.load()
	for y in range(TILE):
		for x in range(TILE):
			roll = rnd.random()
			if roll < 0.14:
				px[x, y] = GRANITE_LIGHT
			elif roll < 0.30:
				px[x, y] = GRANITE_DARK
	# Grobe Kristallflecken, deutlich groeber als die Stone-Struktur.
	for _ in range(7):
		x = rnd.randrange(0, TILE - 2)
		y = rnd.randrange(0, TILE - 2)
		fill(px, x, y, x + 1, y + 1, GRANITE_SPECK)
	return img


SLATE_BASE = rgba("#44505e")
SLATE_LIGHT = rgba("#5c6a7a")
SLATE_DARK = rgba("#2e3844")


def make_slate(seed: int = 66) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), SLATE_BASE)
	px = img.load()
	# Waagerechte Schieferlagen als Hauptmerkmal.
	y = 0
	while y < TILE:
		lage = SLATE_DARK if rnd.random() < 0.5 else SLATE_LIGHT
		hoehe = rnd.randrange(1, 3)
		fill(px, 0, y, TILE - 1, min(y + hoehe - 1, TILE - 1), lage)
		y += hoehe + rnd.randrange(1, 3)
	for _ in range(30):
		x = rnd.randrange(0, TILE)
		yy = rnd.randrange(0, TILE)
		px[x, yy] = SLATE_BASE
	for _ in range(5):
		x = rnd.randrange(0, TILE - 3)
		yy = rnd.randrange(0, TILE)
		fill(px, x, yy, x + 2, yy, SLATE_DARK)
	return img


BEDROCK_BASE = rgba("#2b2b33")
BEDROCK_LIGHT = rgba("#3e3e48")
BEDROCK_DARK = rgba("#17171c")


def make_bedrock(seed: int = 77) -> Image.Image:
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), BEDROCK_BASE)
	px = img.load()
	for _ in range(14):
		x = rnd.randrange(0, TILE - 3)
		y = rnd.randrange(0, TILE - 3)
		w = rnd.randrange(1, 4)
		h = rnd.randrange(1, 3)
		fill(px, x, y, x + w, y + h, BEDROCK_DARK if rnd.random() < 0.6 else BEDROCK_LIGHT)
	return img


WOOD_BASE = rgba("#7a5231")
WOOD_LIGHT = rgba("#97673e")
WOOD_DARK = rgba("#5a3b23")
WOOD_RING = rgba("#462d1a")


def make_wood(seed: int = 88) -> Image.Image:
	"""Stamm von vorn: senkrechte Maserung mit dunklen Rindenkanten."""
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), WOOD_BASE)
	px = img.load()
	fill(px, 0, 0, 1, TILE - 1, WOOD_RING)
	fill(px, TILE - 2, 0, TILE - 1, TILE - 1, WOOD_RING)
	for x in (4, 7, 11):
		y = 0
		while y < TILE:
			laenge = rnd.randrange(2, 6)
			fill(px, x, y, x, min(y + laenge - 1, TILE - 1), WOOD_DARK)
			y += laenge + rnd.randrange(1, 4)
	for _ in range(18):
		x = rnd.randrange(2, TILE - 2)
		y = rnd.randrange(0, TILE)
		px[x, y] = WOOD_LIGHT
	return img


LEAF_BASE = rgba("#3f8a34")
LEAF_LIGHT = rgba("#5fb04b")
LEAF_DARK = rgba("#2c6425")
LEAF_DEEP = rgba("#1f4a1b")


def make_leaves(seed: int = 99) -> Image.Image:
	"""Deckend, damit im Tile-Raster keine Loecher zwischen Blattkacheln stehen."""
	rnd = random.Random(seed)
	img = Image.new("RGBA", (TILE, TILE), LEAF_BASE)
	px = img.load()
	for _ in range(22):
		x = rnd.randrange(0, TILE - 2)
		y = rnd.randrange(0, TILE - 2)
		farbe = LEAF_LIGHT if rnd.random() < 0.45 else LEAF_DARK
		fill(px, x, y, x + 1, y + 1, farbe)
	for _ in range(10):
		px[rnd.randrange(0, TILE), rnd.randrange(0, TILE)] = LEAF_DEEP
	return img


# ore_name -> (heller Kern, dunkler Rand)
ORE_COLORS: dict[str, tuple[str, str]] = {
	"copper_ore": ("#d07b3c", "#8d4a1d"),
	"iron_ore": ("#c9c2b6", "#8a7f70"),
	"silver_ore": ("#e6edf2", "#9aa7b2"),
	"gold_ore": ("#f2cf4a", "#b58a17"),
}


def make_ore(name: str, seed: int) -> Image.Image:
	"""Stone als Basis plus geklumpte Erzadern, damit die Tiefe erkennbar bleibt."""
	kern, rand = ORE_COLORS[name]
	kern_c = rgba(kern)
	rand_c = rgba(rand)
	rnd = random.Random(seed)
	img = make_stone(seed=seed)
	px = img.load()
	for _ in range(5):
		cx = rnd.randrange(2, TILE - 3)
		cy = rnd.randrange(2, TILE - 3)
		groesse = rnd.randrange(1, 3)
		fill(px, cx - 1, cy - 1, cx + groesse, cy + groesse, rand_c)
		fill(px, cx, cy, cx + groesse - 1, cy + groesse - 1, kern_c)
	for _ in range(6):
		px[rnd.randrange(0, TILE), rnd.randrange(0, TILE)] = rand_c
	return img


# --------------------------------------------------------------------------- Wolken

CLOUD_CORE = rgba("#ffffff")
CLOUD_MID = rgba("#e4eef7")
CLOUD_SHADE = rgba("#c6d8e8")


def make_cloud(width: int, height: int, seed: int) -> Image.Image:
	"""Ein paar ueberlappende Ellipsen, unten abgeflacht - reine Deko."""
	rnd = random.Random(seed)
	img = Image.new("RGBA", (width, height), CLEAR)
	px = img.load()
	ballen = []
	for i in range(rnd.randrange(3, 6)):
		r = rnd.randrange(height // 3, max(height // 2, height // 3 + 1))
		cx = rnd.randrange(r, max(width - r, r + 1))
		cy = rnd.randrange(height - r - 1, height - r + 1)
		ballen.append((cx, cy, r))
	for x in range(width):
		for y in range(height):
			for cx, cy, r in ballen:
				dx = (x - cx) / float(r)
				dy = (y - cy) / float(r * 0.85)
				if dx * dx + dy * dy <= 1.0:
					px[x, y] = CLOUD_CORE
					break
	# Unterkante abdunkeln, damit die Wolke Volumen bekommt.
	for x in range(width):
		unterste = -1
		for y in range(height):
			if px[x, y][3] > 0:
				unterste = y
		if unterste >= 0:
			px[x, unterste] = CLOUD_SHADE
			if unterste - 1 >= 0 and px[x, unterste - 1][3] > 0:
				px[x, unterste - 1] = CLOUD_MID
	return img


# --------------------------------------------------------------------------- Player

OUTLINE = rgba("#20202b")
SKIN = rgba("#e0a878")
SKIN_DARK = rgba("#b87f52")
HAIR = rgba("#6b4326")
HAIR_DARK = rgba("#4e2f1a")
SHIRT = rgba("#3e74ab")
SHIRT_DARK = rgba("#2d5580")
PANTS = rgba("#3b4152")
PANTS_DARK = rgba("#2a2f3c")
SHOE = rgba("#4e3a27")
EYE = rgba("#1a1a22")

# Die Figur ist um die Frame-Mitte (Kante zwischen Pixel 19 und 20) gespiegelt
# und steht mit der Schuhunterkante auf Zeile 55 = Unterkante des Frames.
BODY_L, BODY_R = 13, 26
HEAD_T, HEAD_B = 5, 19
TORSO_T, TORSO_B = 20, 37
LEG_T, LEG_B = 38, 52
SHOE_T, SHOE_B = 53, 55

# pose -> (arm_links, arm_rechts, bein_links_dx, bein_rechts_dx)
# Arm = (x_start, y_oben, y_unten), Breite immer 4 px.
POSES: dict[str, tuple[tuple[int, int, int], tuple[int, int, int], int, int]] = {
	"idle": ((8, 21, 34), (28, 21, 34), 0, 0),
	"walk_a": ((8, 22, 35), (28, 19, 32), -2, 2),
	"walk_b": ((8, 19, 32), (28, 22, 35), 2, -2),
	# Sprint: groesserer Schrittwinkel und weiter ausgeworfene Arme als beim Gehen.
	"run_a": ((6, 23, 36), (30, 16, 29), -4, 4),
	"run_b": ((6, 16, 29), (30, 23, 36), 4, -4),
	"jump": ((8, 15, 28), (28, 15, 28), -1, 1),
	"fall": ((7, 17, 30), (29, 17, 30), -3, 3),
	"use_tool": ((8, 21, 34), (28, 13, 26), 0, 0),
}


def draw_leg(px, x0: int, dx: int) -> None:
	left = x0 + dx
	fill(px, left, LEG_T, left + 5, LEG_B, PANTS)
	fill(px, left, LEG_T, left + 1, LEG_B, PANTS_DARK)
	# Die Schuhspitze ragt nach rechts heraus. Alle Frames sind nach rechts
	# gezeichnet, gespiegelt wird im Spiel ueber flip_h.
	fill(px, left, SHOE_T, left + 6, SHOE_B, SHOE)


def draw_arm(px, arm: tuple[int, int, int]) -> None:
	x, top, bottom = arm
	hand_top = bottom - 3
	fill(px, x, top, x + 3, hand_top - 1, SHIRT)
	fill(px, x, top, x, hand_top - 1, SHIRT_DARK)
	fill(px, x, hand_top, x + 3, bottom, SKIN)
	fill(px, x, hand_top, x, bottom, SKIN_DARK)


def add_outline(img: Image.Image, color) -> None:
	px = img.load()
	w, h = img.size
	filled = [[px[x, y][3] > 0 for y in range(h)] for x in range(w)]
	edges: list[tuple[int, int]] = []
	for x in range(w):
		for y in range(h):
			if filled[x][y]:
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= nx < w and 0 <= ny < h and filled[nx][ny]:
					edges.append((x, y))
					break
	for x, y in edges:
		px[x, y] = color


def make_player(pose: str) -> Image.Image:
	arm_l, arm_r, leg_l_dx, leg_r_dx = POSES[pose]
	img = Image.new("RGBA", (FRAME_W, FRAME_H), CLEAR)
	px = img.load()

	draw_leg(px, 13, leg_l_dx)
	draw_leg(px, 21, leg_r_dx)

	fill(px, BODY_L, TORSO_T, BODY_R, TORSO_B, SHIRT)
	fill(px, BODY_L, TORSO_T, BODY_L + 1, TORSO_B, SHIRT_DARK)
	fill(px, BODY_L, TORSO_B - 2, BODY_R, TORSO_B, PANTS_DARK)

	draw_arm(px, arm_l)
	draw_arm(px, arm_r)

	fill(px, BODY_L, HEAD_T, BODY_R, HEAD_B, SKIN)
	fill(px, BODY_L, HEAD_T, BODY_L + 1, HEAD_B, SKIN_DARK)
	fill(px, BODY_L, HEAD_T, BODY_R, HEAD_T + 4, HAIR)
	fill(px, BODY_L, HEAD_T, BODY_L + 1, HEAD_T + 7, HAIR_DARK)
	fill(px, BODY_R - 1, HEAD_T, BODY_R, HEAD_T + 7, HAIR)
	fill(px, BODY_L, HEAD_T + 4, BODY_R, HEAD_T + 4, HAIR_DARK)
	px[16, HEAD_T + 8] = EYE
	px[23, HEAD_T + 8] = EYE
	fill(px, 18, HEAD_B, 21, HEAD_B, SKIN_DARK)

	add_outline(img, OUTLINE)
	return img


# ----------------------------------------------------------------- Player geduckt

# Der Frame-Canvas bleibt 40x56 und die Schuhunterkante bleibt auf Zeile 55.
# Die Figur wird nicht gestaucht, sondern neu gezeichnet: Kopf behaelt seine
# Groesse, Rumpf sitzt tiefer, Beine sind gefaltet (Knie vorn, Fuesse unter der
# Huefte). Sichtbare Hoehe ca. 33 px gegenueber 51 px im Stand.
CR_HEAD_T, CR_HEAD_B = 23, 37
CR_HEAD_L, CR_HEAD_R = 15, 26
CR_TORSO_T, CR_TORSO_B = 34, 48
CR_TORSO_L, CR_TORSO_R = 13, 27
CR_THIGH_T, CR_THIGH_B = 44, 50
CR_SHIN_T, CR_SHIN_B = 49, 52
CR_SHOE_T, CR_SHOE_B = 53, 55

# variant -> (knie_dx, fuss_links_dx, fuss_rechts_dx, arm_links, arm_rechts)
CROUCH_POSES: dict[str, tuple[int, int, int, tuple[int, int, int], tuple[int, int, int]]] = {
	"crouch_idle": (0, 0, 0, (9, 36, 47), (28, 36, 47)),
	"crouch_walk_a": (2, -2, 1, (9, 37, 48), (28, 34, 45)),
	"crouch_walk_b": (-1, 1, -2, (9, 34, 45), (28, 37, 48)),
}


def draw_crouch_leg(px, foot_x: int, knee_x: int, y_shift: int, dark: bool) -> None:
	pants = PANTS_DARK if dark else PANTS
	# Oberschenkel waagerecht von der Huefte nach vorn zum Knie.
	fill(px, foot_x, CR_THIGH_T + y_shift, knee_x + 3, CR_THIGH_B + y_shift, pants)
	# Schienbein senkrecht vom Knie zurueck auf den Fuss.
	fill(px, foot_x, CR_SHIN_T, foot_x + 5, CR_SHIN_B, pants)
	fill(px, foot_x, CR_SHOE_T, foot_x + 6, CR_SHOE_B, SHOE)


def make_player_crouch(pose: str) -> Image.Image:
	knee_dx, foot_l_dx, foot_r_dx, arm_l, arm_r = CROUCH_POSES[pose]
	img = Image.new("RGBA", (FRAME_W, FRAME_H), CLEAR)
	px = img.load()

	# Hinteres Bein zuerst und dunkler, damit die Hocke Tiefe bekommt.
	draw_crouch_leg(px, 14 + foot_l_dx, 25 + knee_dx, -2, True)
	draw_crouch_leg(px, 21 + foot_r_dx, 28 + knee_dx, 0, False)

	# Rumpf leicht nach vorn gebeugt: rechte Kante etwas hoeher als die linke.
	fill(px, CR_TORSO_L, CR_TORSO_T + 2, CR_TORSO_R, CR_TORSO_B, SHIRT)
	fill(px, CR_TORSO_L + 2, CR_TORSO_T, CR_TORSO_R, CR_TORSO_B, SHIRT)
	fill(px, CR_TORSO_L, CR_TORSO_T + 2, CR_TORSO_L + 1, CR_TORSO_B, SHIRT_DARK)
	fill(px, CR_TORSO_L, CR_TORSO_B - 2, CR_TORSO_R, CR_TORSO_B, PANTS_DARK)

	draw_arm(px, arm_l)
	draw_arm(px, arm_r)

	fill(px, CR_HEAD_L, CR_HEAD_T, CR_HEAD_R, CR_HEAD_B, SKIN)
	fill(px, CR_HEAD_L, CR_HEAD_T, CR_HEAD_L + 1, CR_HEAD_B, SKIN_DARK)
	fill(px, CR_HEAD_L, CR_HEAD_T, CR_HEAD_R, CR_HEAD_T + 4, HAIR)
	fill(px, CR_HEAD_L, CR_HEAD_T, CR_HEAD_L + 1, CR_HEAD_T + 7, HAIR_DARK)
	fill(px, CR_HEAD_R - 1, CR_HEAD_T, CR_HEAD_R, CR_HEAD_T + 7, HAIR)
	fill(px, CR_HEAD_L, CR_HEAD_T + 4, CR_HEAD_R, CR_HEAD_T + 4, HAIR_DARK)
	px[18, CR_HEAD_T + 8] = EYE
	px[24, CR_HEAD_T + 8] = EYE
	fill(px, 20, CR_HEAD_B, 23, CR_HEAD_B, SKIN_DARK)

	add_outline(img, OUTLINE)
	return img


# --------------------------------------------------------------------------- Tool

WOOD = rgba("#8a5a30")
WOOD_DARK = rgba("#5f3c1e")
IRON = rgba("#b9bcc4")
IRON_DARK = rgba("#7f838c")


def make_pickaxe() -> Image.Image:
	"""16x16, diagonal gezeichnet damit der Kopf den Canvas voll ausnutzt."""
	img = Image.new("RGBA", (TILE, TILE), CLEAR)
	px = img.load()
	for i in range(11):
		x = 3 + i
		y = 13 - i
		px[x, y] = WOOD
		px[x + 1, y] = WOOD_DARK
	head = [
		(8, 1), (9, 1), (10, 1), (11, 2), (12, 3),
		(13, 4), (14, 5), (13, 2), (12, 1),
		(7, 2), (6, 3), (5, 4), (4, 5),
		(6, 2), (5, 3),
	]
	for x, y in head:
		px[x, y] = IRON
	for x, y in ((14, 5), (4, 5), (13, 4), (5, 4)):
		px[x, y] = IRON_DARK
	add_outline(img, OUTLINE)
	return img


# --------------------------------------------------------------------------- Ausgabe


# Zeile fuer Zeile. Die Position im Raster IST die atlas_coords der BlockData,
# darum duerfen bestehende Eintraege nie verschoben werden.
ATLAS_LAYOUT: list[list[str | None]] = [
	["grass", "dirt", "stone", "sand", "granite", "slate", "wood", "leaves"],
	["copper_ore", "iron_ore", "silver_ore", "gold_ore", "bedrock", None, None, None],
]

ATLAS_COLUMNS = 8


def build_tiles() -> dict[str, Image.Image]:
	return {
		"grass": make_grass(),
		"dirt": make_dirt(),
		"stone": make_stone(),
		"sand": make_sand(),
		"granite": make_granite(),
		"slate": make_slate(),
		"wood": make_wood(),
		"leaves": make_leaves(),
		"copper_ore": make_ore("copper_ore", 201),
		"iron_ore": make_ore("iron_ore", 202),
		"silver_ore": make_ore("silver_ore", 203),
		"gold_ore": make_ore("gold_ore", 204),
		"bedrock": make_bedrock(),
	}


CLOUD_SIZES = {
	"small_cloud": (40, 18, 301),
	"medium_cloud": (72, 26, 302),
	"large_cloud": (104, 34, 303),
}


def main() -> None:
	tiles = build_tiles()

	# Einzeldateien dienen gleichzeitig als Item-Icons im Inventar.
	for name, img in tiles.items():
		img.save(TILE_DIR / f"{name}_placeholder.png")

	rows = len(ATLAS_LAYOUT)
	atlas = Image.new("RGBA", (TILE * ATLAS_COLUMNS, TILE * rows), CLEAR)
	for y, row in enumerate(ATLAS_LAYOUT):
		for x, name in enumerate(row):
			if name is not None:
				atlas.paste(tiles[name], (x * TILE, y * TILE))
	atlas.save(TILE_DIR / "terrain_atlas.png")

	CLOUD_DIR.mkdir(parents=True, exist_ok=True)
	for name, (w, h, seed) in CLOUD_SIZES.items():
		make_cloud(w, h, seed).save(CLOUD_DIR / f"{name}.png")

	for pose in POSES:
		make_player(pose).save(PLAYER_DIR / f"player_{pose}.png")

	for pose in CROUCH_POSES:
		make_player_crouch(pose).save(PLAYER_DIR / f"player_{pose}.png")

	make_pickaxe().save(TOOL_DIR / "pickaxe_placeholder.png")

	print("Tiles:", TILE, "x", TILE, "->", ", ".join(sorted(tiles)))
	print("Atlas:", atlas.width, "x", atlas.height)
	print("Wolken:", ", ".join(sorted(CLOUD_SIZES)))
	names = sorted(list(POSES) + list(CROUCH_POSES))
	print("Player-Frames:", FRAME_W, "x", FRAME_H, "->", ", ".join(names))


if __name__ == "__main__":
	main()
