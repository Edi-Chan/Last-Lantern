"""Generate simple pixel-art placeholders. Not used at runtime."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write_png(path: Path, width: int, height: int, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixels[y][x])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def blank(width: int, height: int, color: tuple[int, int, int, int] = (0, 0, 0, 0)) -> list[list[tuple[int, int, int, int]]]:
    return [[color for _ in range(width)] for _ in range(height)]


def px(pixels: list[list[tuple[int, int, int, int]]], x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= y < len(pixels) and 0 <= x < len(pixels[0]):
        pixels[y][x] = color


def fill(pixels: list[list[tuple[int, int, int, int]]], x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int, int]) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(pixels, x, y, color)


OUTLINE = (42, 31, 20, 255)
SKIN = (232, 180, 138, 255)
SKIN_SHADOW = (214, 150, 108, 255)
HAIR = (90, 58, 34, 255)
HAIR_LIGHT = (122, 78, 46, 255)
SHIRT = (61, 126, 199, 255)
SHIRT_DARK = (42, 92, 155, 255)
PANTS = (58, 63, 74, 255)
PANTS_DARK = (40, 44, 52, 255)
SHOE = (43, 33, 24, 255)
EYE = (26, 26, 26, 255)


def draw_player(pose: str) -> list[list[tuple[int, int, int, int]]]:
    p = blank(20, 40)
    # hair / head
    fill(p, 6, 2, 13, 4, HAIR)
    fill(p, 5, 4, 14, 6, HAIR_LIGHT)
    fill(p, 5, 6, 14, 13, SKIN)
    fill(p, 6, 13, 13, 14, SKIN_SHADOW)
    px(p, 7, 8, EYE)
    px(p, 12, 8, EYE)
    px(p, 8, 11, SKIN_SHADOW)
    px(p, 9, 11, SKIN_SHADOW)
    px(p, 10, 11, SKIN_SHADOW)

    # body
    fill(p, 5, 15, 14, 25, SHIRT)
    fill(p, 5, 23, 14, 25, SHIRT_DARK)

    # arms
    if pose == "walk_a":
        fill(p, 3, 16, 4, 24, SKIN)
        fill(p, 15, 16, 16, 22, SKIN)
    elif pose == "walk_b":
        fill(p, 3, 16, 4, 22, SKIN)
        fill(p, 15, 16, 16, 24, SKIN)
    elif pose == "jump":
        fill(p, 3, 12, 4, 20, SKIN)
        fill(p, 15, 12, 16, 20, SKIN)
    elif pose == "fall":
        fill(p, 2, 16, 4, 21, SKIN)
        fill(p, 15, 16, 17, 21, SKIN)
    else:
        fill(p, 3, 16, 4, 23, SKIN)
        fill(p, 15, 16, 16, 23, SKIN)

    # legs
    if pose == "walk_a":
        fill(p, 6, 26, 8, 35, PANTS)
        fill(p, 11, 26, 13, 32, PANTS_DARK)
        fill(p, 6, 36, 8, 38, SHOE)
        fill(p, 11, 33, 13, 35, SHOE)
    elif pose == "walk_b":
        fill(p, 6, 26, 8, 32, PANTS_DARK)
        fill(p, 11, 26, 13, 35, PANTS)
        fill(p, 6, 33, 8, 35, SHOE)
        fill(p, 11, 36, 13, 38, SHOE)
    elif pose == "jump":
        fill(p, 6, 26, 8, 33, PANTS)
        fill(p, 11, 26, 13, 33, PANTS)
        fill(p, 6, 34, 8, 36, SHOE)
        fill(p, 11, 34, 13, 36, SHOE)
    elif pose == "fall":
        fill(p, 5, 26, 8, 34, PANTS)
        fill(p, 11, 26, 14, 34, PANTS)
        fill(p, 5, 35, 8, 37, SHOE)
        fill(p, 11, 35, 14, 37, SHOE)
    else:
        fill(p, 6, 26, 8, 35, PANTS)
        fill(p, 11, 26, 13, 35, PANTS)
        fill(p, 6, 36, 8, 38, SHOE)
        fill(p, 11, 36, 13, 38, SHOE)

    # outline hints
    for x in range(5, 15):
        px(p, x, 2, OUTLINE)
    return p


def draw_tile(kind: str) -> list[list[tuple[int, int, int, int]]]:
    p = blank(16, 16)
    if kind == "grass":
        dirt = (122, 78, 42, 255)
        dirt_d = (96, 58, 30, 255)
        grass = (74, 160, 62, 255)
        grass_l = (110, 188, 78, 255)
        grass_d = (46, 112, 44, 255)
        fill(p, 0, 4, 15, 15, dirt)
        for x, y in ((1, 6), (5, 8), (9, 7), (12, 10), (3, 12), (8, 13), (14, 14)):
            px(p, x, y, dirt_d)
        fill(p, 0, 0, 15, 4, grass)
        for x in range(16):
            px(p, x, 0, grass_l if x % 3 else grass_d)
            px(p, x, 2, grass_d if x % 2 else grass)
        for x, y in ((2, 1), (7, 1), (11, 3), (14, 2), (4, 3)):
            px(p, x, y, grass_l)
    elif kind == "dirt":
        base = (140, 90, 48, 255)
        dark = (108, 68, 34, 255)
        light = (168, 114, 66, 255)
        fill(p, 0, 0, 15, 15, base)
        for x, y in ((1, 2), (4, 5), (8, 3), (12, 7), (3, 10), (9, 12), (14, 14), (6, 8), (11, 1)):
            px(p, x, y, dark)
        for x, y in ((2, 6), (7, 1), (13, 4), (5, 13), (10, 9)):
            px(p, x, y, light)
    else:
        base = (128, 132, 138, 255)
        dark = (86, 90, 96, 255)
        light = (176, 180, 186, 255)
        fill(p, 0, 0, 15, 15, base)
        for x, y in ((0, 0), (5, 2), (11, 1), (3, 7), (8, 6), (14, 8), (1, 12), (7, 13), (12, 14)):
            px(p, x, y, dark)
        for x, y in ((2, 3), (9, 4), (13, 2), (6, 10), (15, 11)):
            px(p, x, y, light)
        fill(p, 4, 4, 6, 5, light)
    return p


def draw_pickaxe() -> list[list[tuple[int, int, int, int]]]:
    p = blank(16, 16)
    wood = (160, 104, 52, 255)
    wood_d = (112, 70, 32, 255)
    steel = (186, 192, 200, 255)
    steel_d = (110, 118, 128, 255)
    fill(p, 6, 5, 8, 15, wood)
    fill(p, 8, 5, 8, 15, wood_d)
    fill(p, 3, 2, 13, 5, steel)
    fill(p, 12, 3, 14, 7, steel)
    fill(p, 3, 2, 13, 2, steel_d)
    fill(p, 14, 3, 14, 7, steel_d)
    fill(p, 6, 4, 8, 5, wood)
    return p


def main() -> None:
    player_dir = ROOT / "assets" / "player"
    tile_dir = ROOT / "assets" / "world" / "tiles"
    tool_dir = ROOT / "assets" / "items" / "tools"

    frames = {
        "player_placeholder.png": draw_player("idle"),
        "player_idle.png": draw_player("idle"),
        "player_walk_a.png": draw_player("walk_a"),
        "player_walk_b.png": draw_player("walk_b"),
        "player_jump.png": draw_player("jump"),
        "player_fall.png": draw_player("fall"),
    }
    for name, pixels in frames.items():
        write_png(player_dir / name, 20, 40, pixels)

    tiles = {
        "grass_placeholder.png": draw_tile("grass"),
        "dirt_placeholder.png": draw_tile("dirt"),
        "stone_placeholder.png": draw_tile("stone"),
    }
    for name, pixels in tiles.items():
        write_png(tile_dir / name, 16, 16, pixels)

    atlas = blank(48, 16)
    for index, kind in enumerate(("grass", "dirt", "stone")):
        tile = draw_tile(kind)
        for y in range(16):
            for x in range(16):
                atlas[y][x + index * 16] = tile[y][x]
    write_png(tile_dir / "terrain_atlas.png", 48, 16, atlas)
    write_png(tool_dir / "pickaxe_placeholder.png", 16, 16, draw_pickaxe())
    print("placeholders written")


if __name__ == "__main__":
    main()
