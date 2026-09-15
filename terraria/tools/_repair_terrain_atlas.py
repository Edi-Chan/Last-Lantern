"""Rebuild terrain_atlas.png from intact standalone tiles.

The previous ore generator read PNGs without decoding row filters, which zeroed
almost every alpha channel in the atlas. This script never re-encodes filtered
source bytes; it composites existing 16x16 assets via Pillow.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
TILES = ROOT / "assets" / "world" / "tiles"
ORES = ROOT / "assets" / "world" / "ores"
ITEMS = ROOT / "assets" / "items" / "ores"
ATLAS_PATH = TILES / "terrain_atlas.png"
TILE = 16

# BlockData.atlas_coords must stay exactly these cells.
BASE_TILES = {
    (0, 0): "grass_placeholder.png",
    (1, 0): "dirt_placeholder.png",
    (2, 0): "stone_placeholder.png",
    (3, 0): "sand_placeholder.png",
    (4, 0): "granite_placeholder.png",
    (5, 0): "slate_placeholder.png",
    (6, 0): "wood_placeholder.png",
    (7, 0): "leaves_placeholder.png",
    (4, 1): "bedrock_placeholder.png",
    (0, 2): "oak_wood.png",
    (1, 2): "birch_wood.png",
    (2, 2): "pine_wood.png",
    (3, 2): "oak_leaves.png",
    (4, 2): "birch_leaves.png",
    (5, 2): "pine_leaves.png",
    (6, 2): "oak_sapling.png",
    (7, 2): "birch_sapling.png",
    (0, 3): "pine_sapling.png",
}

# Stone-base ore veins. Colors match the existing OreData map colors.
ORES_SPEC = [
    ("copper", (0, 1), (196, 108, 42), (232, 160, 86), None),
    ("tin", (1, 1), (196, 204, 210), (236, 240, 244), (150, 156, 162)),
    ("ferrite", (2, 1), (176, 64, 48), (214, 96, 72), (110, 36, 28)),
    ("aurel", (3, 1), (232, 186, 48), (255, 228, 110), (176, 128, 24)),
    ("cobalt", (5, 1), (48, 96, 210), (96, 150, 255), (24, 48, 140)),
    ("veyrite", (6, 1), (148, 64, 196), (196, 110, 236), (88, 28, 128)),
    ("cryonite", (7, 1), (72, 210, 220), (190, 250, 255), (36, 140, 160)),
    ("ignitium", (1, 3), (232, 86, 28), (255, 180, 64), (180, 28, 16)),
    ("voidium", (2, 3), (88, 36, 120), (168, 84, 210), (42, 18, 64)),
    ("astralith", (3, 3), (120, 210, 255), (214, 160, 255), (255, 255, 255)),
]

VEIN_SPOTS = [
    (3, 4), (4, 5), (5, 4), (6, 6), (7, 5), (8, 7), (9, 4), (10, 6),
    (4, 9), (6, 10), (8, 9), (11, 10), (5, 12), (9, 12), (7, 3), (12, 8),
    (3, 11), (10, 3), (2, 7), (13, 5), (8, 11), (11, 7), (4, 7), (12, 12),
]


def load_tile(name: str) -> Image.Image:
    img = Image.open(TILES / name).convert("RGBA")
    if img.size != (TILE, TILE):
        img = img.resize((TILE, TILE), Image.NEAREST)
    return img


def put(px, x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < TILE and 0 <= y < TILE:
        px[x, y] = color + (255,)


def make_ore_tile(stone: Image.Image, body: tuple[int, int, int], light: tuple[int, int, int], dark: tuple[int, int, int] | None) -> Image.Image:
    tile = stone.copy()
    px = tile.load()
    for i, (x, y) in enumerate(VEIN_SPOTS):
        if i % 4 == 0 and dark is not None:
            color = dark
        elif i % 3 == 0:
            color = light
        else:
            color = body
        put(px, x, y, color)
        if i % 2 == 0:
            put(px, x + 1, y, light if i % 5 else body)
    return tile


def make_item_icon(body: tuple[int, int, int], light: tuple[int, int, int], sparkle: tuple[int, int, int] | None) -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    px = img.load()
    stone = (118, 122, 126)
    stone_d = (86, 90, 96)
    for y in range(3, 14):
        for x in range(3, 14):
            if (x - 8) ** 2 + (y - 8) ** 2 < 36:
                px[x, y] = (stone_d if (x + y) % 7 == 0 else stone) + (255,)
    for x, y in [(5, 6), (6, 7), (7, 6), (8, 8), (9, 7), (10, 9), (6, 10), (9, 11), (11, 6), (8, 5)]:
        px[x, y] = body + (255,)
        if 0 <= y - 1 < TILE:
            px[x, y - 1] = light + (255,)
    if sparkle is not None:
        px[8, 5] = sparkle + (255,)
        px[9, 6] = sparkle + (255,)
    return img


def opaque_count(img: Image.Image) -> int:
    return sum(1 for p in img.getdata() if p[3] > 10)


def main() -> None:
    atlas = Image.new("RGBA", (8 * TILE, 4 * TILE), (0, 0, 0, 0))
    for (col, row), name in BASE_TILES.items():
        tile = load_tile(name)
        atlas.paste(tile, (col * TILE, row * TILE), tile if tile.mode == "RGBA" else None)

    stone = load_tile("stone_placeholder.png")
    ORES.mkdir(parents=True, exist_ok=True)
    ITEMS.mkdir(parents=True, exist_ok=True)
    for key, (col, row), body, light, dark in ORES_SPEC:
        sparkle = (255, 255, 255) if key in ("astralith", "cryonite") else ((255, 220, 80) if key == "ignitium" else None)
        tile = make_ore_tile(stone, body, light, dark)
        if key == "astralith":
            px = tile.load()
            put(px, 8, 6, (214, 160, 255))
            put(px, 9, 7, (255, 255, 255))
            put(px, 6, 8, (120, 210, 255))
        atlas.paste(tile, (col * TILE, row * TILE))
        tile.save(ORES / f"{key}_ore.png")
        make_item_icon(body, light, sparkle).save(ITEMS / f"{key}_ore.png")

    atlas.save(ATLAS_PATH)
    print("atlas", atlas.size, "opaque_tiles:")
    for row in range(4):
        for col in range(8):
            cell = atlas.crop((col * TILE, row * TILE, col * TILE + TILE, row * TILE + TILE))
            n = opaque_count(cell)
            if n:
                print(f"  {col},{row}: {n}/256")


if __name__ == "__main__":
    main()
