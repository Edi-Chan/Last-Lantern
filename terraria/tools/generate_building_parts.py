#!/usr/bin/env python3
"""Generate Last Lantern building-part pixel art, icons, and .tres resources."""
from __future__ import annotations

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ATLAS_W, ATLAS_H = 16, 14
TILE = 16


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, w: int, h: int, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    raw = b""
    for y in range(h):
        raw += b"\x00"
        for x in range(w):
            r, g, b, a = pixels[y][x]
            raw += bytes((r, g, b, a))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def blank(w: int, h: int, fill=(0, 0, 0, 0)):
    return [[fill for _ in range(w)] for _ in range(h)]


def put(px, x, y, c):
    if 0 <= y < len(px) and 0 <= x < len(px[0]) and len(c) == 4 and c[3] > 0:
        px[y][x] = c


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (max(a[3], b[3]),)


WOOD = {
    "outline": (28, 16, 10, 255),
    "dark": (58, 34, 18, 255),
    "mid": (98, 62, 32, 255),
    "light": (138, 92, 48, 255),
    "hi": (176, 128, 74, 255),
    "nail": (42, 32, 28, 255),
}
STONE = {
    "outline": (22, 24, 28, 255),
    "dark": (52, 56, 62, 255),
    "mid": (86, 92, 100, 255),
    "light": (118, 124, 132, 255),
    "hi": (158, 162, 168, 255),
    "nail": (36, 38, 42, 255),
}
STRAW = {
    "outline": (48, 34, 12, 255),
    "dark": (110, 78, 22, 255),
    "mid": (168, 124, 36, 255),
    "light": (204, 164, 58, 255),
    "hi": (228, 196, 96, 255),
    "nail": (70, 48, 16, 255),
}
METAL = {
    "outline": (18, 18, 22, 255),
    "dark": (48, 50, 56, 255),
    "mid": (92, 98, 108, 255),
    "light": (150, 156, 166, 255),
    "hi": (210, 214, 220, 255),
    "nail": (28, 28, 32, 255),
}
GLASS = (70, 118, 148, 140)
GLASS_HI = (170, 210, 230, 90)


def hash_xy(x, y, s=0):
    return (x * 73 + y * 37 + s * 19) & 255


def fill_rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(px, x, y, c)


def grain_fill(px, x0, y0, x1, y1, pal, vertical=False, seed=0):
    for y in range(y0, y1):
        for x in range(x0, x1):
            n = hash_xy(x, y, seed)
            if n < 40:
                c = pal["dark"]
            elif n < 140:
                c = pal["mid"]
            elif n < 210:
                c = pal["light"]
            else:
                c = pal["hi"]
            if vertical and x % 4 == 0:
                c = pal["dark"]
            if not vertical and y % 4 == 0:
                c = pal["dark"]
            put(px, x, y, c)


def outline_box(px, x0, y0, x1, y1, c):
    for x in range(x0, x1):
        put(px, x, y0, c)
        put(px, x, y1 - 1, c)
    for y in range(y0, y1):
        put(px, x0, y, c)
        put(px, x1 - 1, y, c)


def draw_connected(px, ox, oy, pal, mask, kind):
    """4-way bitmask: N=1 E=2 S=4 W=8."""
    n, e, s, w = mask & 1, mask & 2, mask & 4, mask & 8
    x0, y0, x1, y1 = ox, oy, ox + 16, oy + 16
    vertical = kind in ("wall", "bg")
    seed_map = {"wall": 3, "bg": 5, "foundation": 7, "floor": 9}
    grain_fill(px, x0, y0, x1, y1, pal, vertical=vertical, seed=seed_map.get(kind, 1))
    if kind == "bg":
        for y in range(16):
            for x in range(16):
                r, g, b, a = px[oy + y][ox + x]
                put(px, ox + x, oy + y, (int(r * 0.62), int(g * 0.6), int(b * 0.58), 255))
    if kind == "foundation":
        fill_rect(px, x0, y0 + 11, x1, y1, pal["dark"])
        for x in range(x0 + 1, x1 - 1, 3):
            put(px, x, y0 + 12, pal["nail"])
    if kind == "floor":
        fill_rect(px, x0, y0, x1, y0 + 3, pal["hi"])
        fill_rect(px, x0, y0 + 3, x1, y0 + 5, pal["light"])
    if not n:
        for x in range(16):
            put(px, ox + x, oy, pal["outline"])
            put(px, ox + x, oy + 1, pal["hi"] if kind != "bg" else pal["mid"])
    if not s:
        for x in range(16):
            put(px, ox + x, oy + 15, pal["outline"])
            put(px, ox + x, oy + 14, pal["dark"])
    if not w:
        for y in range(16):
            put(px, ox, oy + y, pal["outline"])
    if not e:
        for y in range(16):
            put(px, ox + 15, oy + y, pal["outline"])
    if kind == "wall":
        put(px, ox + 4, oy + 6, pal["nail"])
        put(px, ox + 11, oy + 10, pal["nail"])


def draw_roof(px, ox, oy, pal, variant, straw=False):
    p = STRAW if straw else pal
    grain_fill(px, ox, oy, ox + 16, oy + 16, p, vertical=False, seed=9 if straw else 3)
    for y in range(16):
        for x in range(16):
            if straw and (x + y * 2) % 5 == 0:
                put(px, ox + x, oy + y, p["hi"])
    # 0 normal, 1 left edge, 2 right edge, 3 slope L, 4 slope R, 5 peak, 6 inner
    if variant == 1:
        for y in range(16):
            put(px, ox, oy + y, p["outline"])
            for x in range(1, 4):
                put(px, ox + x, oy + y, p["dark"])
    elif variant == 2:
        for y in range(16):
            put(px, ox + 15, oy + y, p["outline"])
            for x in range(12, 15):
                put(px, ox + x, oy + y, p["dark"])
    elif variant == 3:
        for y in range(16):
            for x in range(16):
                if x < (15 - y):
                    put(px, ox + x, oy + y, (0, 0, 0, 0))
                elif x == (15 - y):
                    put(px, ox + x, oy + y, p["outline"])
    elif variant == 4:
        for y in range(16):
            for x in range(16):
                if x > y:
                    put(px, ox + x, oy + y, (0, 0, 0, 0))
                elif x == y:
                    put(px, ox + x, oy + y, p["outline"])
    elif variant == 5:
        for y in range(16):
            for x in range(16):
                left = x < (7 - y // 2)
                right = x > (8 + y // 2)
                if left or right:
                    put(px, ox + x, oy + y, (0, 0, 0, 0))
                elif x == (7 - y // 2) or x == (8 + y // 2):
                    put(px, ox + x, oy + y, p["outline"])
    outline_box(px, ox, oy, ox + 16, oy + 16, p["outline"] if variant in (0, 6) else p["outline"])
    if variant in (3, 4, 5):
        # don't force full box after slope cut
        pass


def draw_beam(px, ox, oy):
    fill_rect(px, ox, oy + 5, ox + 16, oy + 11, WOOD["mid"])
    fill_rect(px, ox, oy + 5, ox + 16, oy + 7, WOOD["hi"])
    fill_rect(px, ox, oy + 9, ox + 16, oy + 11, WOOD["dark"])
    for x in (2, 8, 13):
        put(px, ox + x, oy + 8, WOOD["nail"])
    for x in range(16):
        put(px, ox + x, oy + 5, WOOD["outline"])
        put(px, ox + x, oy + 10, WOOD["outline"])


def stair_dist(tx, ty, right):
    if right:
        return ty + tx - 15
    return ty - tx


def _stair_low_cap(tx, ty, right, kind):
    width = 8 if kind == "floor" else 5
    if ty < 13:
        return False
    if right:
        return tx <= width
    return tx >= 15 - width


def _stair_high_cap(tx, ty, right, kind):
    width = 8 if kind == "platform" else 5
    if ty > 2:
        return False
    if right:
        return tx >= 15 - width
    return tx <= width


def draw_stair_variant(px, ox, oy, pal, right, kind="inner"):
    thick = 5
    for ty in range(16):
        for tx in range(16):
            dist = stair_dist(tx, ty, right)
            on_plank = 0 <= dist < thick
            if kind in ("start", "floor", "single") and _stair_low_cap(tx, ty, right, kind):
                on_plank = True
            if kind in ("end", "platform", "single") and _stair_high_cap(tx, ty, right, kind):
                on_plank = True
            if not on_plank:
                continue
            if dist == 0:
                put(px, ox + tx, oy + ty, pal["outline"])
            elif dist == 1:
                put(px, ox + tx, oy + ty, pal["hi"])
            elif dist == thick - 1:
                put(px, ox + tx, oy + ty, pal["dark"])
            else:
                grain = pal["light"] if ((tx + ty) % 5 == 0) else pal["mid"]
                if (tx * 3 + ty * 7) % 11 == 0:
                    grain = pal["nail"]
                put(px, ox + tx, oy + ty, grain)
    if right:
        put(px, ox, oy + 15, pal["outline"])
        put(px, ox + 15, oy, pal["outline"])
        put(px, ox + 1, oy + 15, pal["hi"])
        put(px, ox + 15, oy + 1, pal["hi"])
    else:
        put(px, ox + 15, oy + 15, pal["outline"])
        put(px, ox, oy, pal["outline"])
        put(px, ox + 14, oy + 15, pal["hi"])
        put(px, ox, oy + 1, pal["hi"])


def draw_stairs(px, ox, oy, pal, right):
    draw_stair_variant(px, ox, oy, pal, right, "inner")


def draw_ladder(px, ox, oy):
    fill_rect(px, ox + 2, oy, ox + 5, oy + 16, WOOD["mid"])
    fill_rect(px, ox + 11, oy, ox + 14, oy + 16, WOOD["mid"])
    for y in (2, 6, 10, 14):
        fill_rect(px, ox + 2, oy + y, ox + 14, oy + y + 2, WOOD["light"])
        put(px, ox + 2, oy + y, WOOD["outline"])
        put(px, ox + 13, oy + y, WOOD["outline"])
    for y in range(16):
        put(px, ox + 2, oy + y, WOOD["outline"])
        put(px, ox + 13, oy + y, WOOD["outline"])


def draw_platform(px, ox, oy, pal):
    fill_rect(px, ox, oy + 2, ox + 16, oy + 7, pal["mid"])
    fill_rect(px, ox, oy + 2, ox + 16, oy + 4, pal["hi"])
    for x in range(16):
        put(px, ox + x, oy + 2, pal["outline"])
        put(px, ox + x, oy + 6, pal["outline"])
    put(px, ox + 4, oy + 5, pal["nail"])
    put(px, ox + 11, oy + 5, pal["nail"])


def draw_window(px, ox, oy, wood_frame=True):
    pal = WOOD if wood_frame else METAL
    fill_rect(px, ox, oy, ox + 16, oy + 16, pal["dark"])
    outline_box(px, ox, oy, ox + 16, oy + 16, pal["outline"])
    fill_rect(px, ox + 2, oy + 2, ox + 14, oy + 14, GLASS)
    fill_rect(px, ox + 3, oy + 3, ox + 7, oy + 7, GLASS_HI)
    fill_rect(px, ox + 7, oy, ox + 9, oy + 16, pal["mid"])
    fill_rect(px, ox, oy + 7, ox + 16, oy + 9, pal["mid"])
    if not wood_frame:
        for y in range(2, 14):
            for x in range(2, 14):
                if (x + y) % 7 == 0:
                    put(px, ox + x, oy + y, (200, 220, 235, 80))


def draw_barricade(px, ox, oy):
    grain_fill(px, ox, oy, ox + 16, oy + 16, WOOD, vertical=True, seed=11)
    for y in range(0, 16, 4):
        fill_rect(px, ox, oy + y, ox + 16, oy + y + 2, WOOD["dark"])
    outline_box(px, ox, oy, ox + 16, oy + 16, WOOD["outline"])
    put(px, ox + 3, oy + 5, METAL["light"])
    put(px, ox + 12, oy + 10, METAL["light"])


def draw_barrel(px, ox, oy):
    fill_rect(px, ox + 3, oy + 2, ox + 13, oy + 15, WOOD["mid"])
    fill_rect(px, ox + 4, oy + 3, ox + 12, oy + 5, WOOD["hi"])
    for y in (6, 10, 14):
        fill_rect(px, ox + 3, oy + y, ox + 13, oy + y + 1, WOOD["dark"])
    outline_box(px, ox + 3, oy + 2, ox + 13, oy + 15, WOOD["outline"])
    put(px, ox + 7, oy + 8, WOOD["nail"])


def draw_shelf(px, ox, oy):
    fill_rect(px, ox + 1, oy + 1, ox + 15, oy + 15, WOOD["dark"])
    for y in (4, 9, 14):
        fill_rect(px, ox + 1, oy + y, ox + 15, oy + y + 1, WOOD["light"])
    fill_rect(px, ox + 1, oy + 1, ox + 3, oy + 15, WOOD["mid"])
    fill_rect(px, ox + 13, oy + 1, ox + 15, oy + 15, WOOD["mid"])
    put(px, ox + 5, oy + 7, (120, 40, 36, 255))
    put(px, ox + 10, oy + 12, (60, 90, 70, 255))
    outline_box(px, ox + 1, oy + 1, ox + 15, oy + 15, WOOD["outline"])


def draw_table(px, ox, oy):
    fill_rect(px, ox + 1, oy + 5, ox + 15, oy + 8, WOOD["light"])
    fill_rect(px, ox + 2, oy + 8, ox + 4, oy + 15, WOOD["mid"])
    fill_rect(px, ox + 12, oy + 8, ox + 14, oy + 15, WOOD["mid"])
    for x in range(1, 15):
        put(px, ox + x, oy + 5, WOOD["outline"])
        put(px, ox + x, oy + 7, WOOD["outline"])


def draw_chair(px, ox, oy):
    fill_rect(px, ox + 4, oy + 1, ox + 12, oy + 8, WOOD["mid"])
    fill_rect(px, ox + 4, oy + 8, ox + 13, oy + 11, WOOD["light"])
    fill_rect(px, ox + 4, oy + 11, ox + 6, oy + 15, WOOD["dark"])
    fill_rect(px, ox + 11, oy + 11, ox + 13, oy + 15, WOOD["dark"])
    outline_box(px, ox + 4, oy + 1, ox + 12, oy + 8, WOOD["outline"])


def draw_sign(px, ox, oy):
    fill_rect(px, ox + 7, oy + 8, ox + 9, oy + 16, WOOD["dark"])
    fill_rect(px, ox + 2, oy + 2, ox + 14, oy + 10, WOOD["light"])
    outline_box(px, ox + 2, oy + 2, ox + 14, oy + 10, WOOD["outline"])
    fill_rect(px, ox + 4, oy + 4, ox + 12, oy + 5, WOOD["dark"])
    fill_rect(px, ox + 4, oy + 7, ox + 10, oy + 8, WOOD["dark"])


def draw_rack(px, ox, oy):
    fill_rect(px, ox + 2, oy + 1, ox + 14, oy + 3, WOOD["mid"])
    fill_rect(px, ox + 2, oy + 1, ox + 4, oy + 15, WOOD["dark"])
    fill_rect(px, ox + 12, oy + 1, ox + 14, oy + 15, WOOD["dark"])
    # swords
    for i, col in enumerate(((160, 160, 170, 255), (140, 90, 50, 255))):
        x = ox + 6 + i * 3
        fill_rect(px, x, oy + 3, x + 2, oy + 13, col)
        put(px, x, oy + 3, METAL["hi"])


def blit(dst, src, ox, oy):
    for y in range(len(src)):
        for x in range(len(src[0])):
            put(dst, ox + x, oy + y, src[y][x])


def crop(px, x, y, w, h):
    out = blank(w, h)
    for yy in range(h):
        for xx in range(w):
            out[yy][xx] = px[y + yy][x + xx]
    return out


def draw_door_sprite(w=16, h=48, reinforced=False):
    px = blank(w, h)
    pal = WOOD
    grain_fill(px, 1, 1, w - 1, h - 1, pal, vertical=True, seed=7)
    outline_box(px, 0, 0, w, h, pal["outline"])
    fill_rect(px, 2, 4, w - 2, 6, pal["dark"])
    fill_rect(px, 2, h // 2, w - 2, h // 2 + 2, pal["dark"])
    fill_rect(px, 2, h - 8, w - 2, h - 6, pal["dark"])
    put(px, w - 4, h // 2 + 4, (210, 180, 70, 255))
    if reinforced:
        for y in (8, 22, 36):
            fill_rect(px, 1, y, w - 1, y + 3, METAL["mid"])
            put(px, 2, y + 1, METAL["hi"])
            put(px, w - 3, y + 1, METAL["hi"])
        fill_rect(px, w - 5, 24, w - 2, 28, METAL["light"])
    return px


def draw_gate_sprite():
    px = blank(32, 48)
    grain_fill(px, 1, 1, 31, 47, WOOD, vertical=True, seed=4)
    outline_box(px, 0, 0, 32, 48, WOOD["outline"])
    fill_rect(px, 15, 1, 17, 47, WOOD["dark"])
    for y in (10, 22, 34):
        fill_rect(px, 1, y, 31, y + 3, METAL["dark"])
    put(px, 6, 24, METAL["hi"])
    put(px, 25, 24, METAL["hi"])
    return px


def draw_workbench():
    px = blank(32, 16)
    fill_rect(px, 1, 4, 31, 9, WOOD["light"])
    fill_rect(px, 2, 9, 6, 16, WOOD["mid"])
    fill_rect(px, 26, 9, 30, 16, WOOD["mid"])
    fill_rect(px, 10, 1, 14, 5, METAL["mid"])
    put(px, 20, 2, WOOD["dark"])
    outline_box(px, 1, 4, 31, 9, WOOD["outline"])
    return px


def draw_anvil():
    px = blank(32, 16)
    fill_rect(px, 6, 10, 26, 16, METAL["dark"])
    fill_rect(px, 4, 5, 28, 10, METAL["mid"])
    fill_rect(px, 2, 6, 8, 9, METAL["light"])
    fill_rect(px, 24, 4, 30, 8, METAL["hi"])
    outline_box(px, 4, 5, 28, 10, METAL["outline"])
    return px


def draw_furnace():
    px = blank(32, 32)
    grain_fill(px, 2, 4, 30, 32, STONE, seed=2)
    outline_box(px, 2, 4, 30, 32, STONE["outline"])
    fill_rect(px, 10, 14, 22, 28, (18, 10, 8, 255))
    fill_rect(px, 12, 16, 20, 26, (220, 90, 24, 255))
    fill_rect(px, 14, 18, 18, 24, (255, 180, 50, 255))
    fill_rect(px, 12, 2, 20, 6, STONE["mid"])
    return px


def draw_chest():
    px = blank(16, 16)
    fill_rect(px, 1, 5, 15, 15, WOOD["mid"])
    fill_rect(px, 1, 5, 15, 9, WOOD["light"])
    fill_rect(px, 7, 8, 9, 12, METAL["light"])
    outline_box(px, 1, 5, 15, 15, WOOD["outline"])
    put(px, 8, 10, (210, 170, 50, 255))
    return px


def draw_wall_torch():
    px = blank(16, 16)
    fill_rect(px, 7, 7, 10, 15, WOOD["mid"])
    fill_rect(px, 6, 2, 11, 8, (230, 120, 30, 255))
    fill_rect(px, 7, 3, 10, 6, (255, 210, 80, 255))
    put(px, 8, 2, (255, 240, 180, 255))
    fill_rect(px, 4, 10, 12, 13, WOOD["dark"])
    return px


def draw_icon_from_tile(tile_px):
    return [row[:] for row in tile_px]


def icon_from_large(src, tw=16, th=16):
    sw, sh = len(src[0]), len(src)
    out = blank(tw, th)
    for y in range(th):
        for x in range(tw):
            sx = min(sw - 1, int(x * sw / tw))
            sy = min(sh - 1, int(y * sh / th))
            out[y][x] = src[sy][sx]
    return out


def write_tres_block(path, spec):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = [
        "[gd_resource type=\"Resource\" script_class=\"BlockData\" format=3]",
        "",
        "[ext_resource type=\"Script\" path=\"res://scripts/world/block_data.gd\" id=\"1_script\"]",
        "",
        "[resource]",
        "script = ExtResource(\"1_script\")",
    ]
    for k, v in spec.items():
        if k == "entity_scene" and v:
            continue
        lines.append(f"{k} = {v}")
    if spec.get("entity_scene"):
        pass
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def write_tres_item(path, spec, icon_res, scene_res=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ext = [
        "[gd_resource type=\"Resource\" script_class=\"ItemData\" format=3]",
        "",
        "[ext_resource type=\"Script\" path=\"res://scripts/items/item_data.gd\" id=\"1_script\"]",
        f"[ext_resource type=\"Texture2D\" path=\"{icon_res}\" id=\"2_icon\"]",
    ]
    if scene_res:
        ext.append(f"[ext_resource type=\"PackedScene\" path=\"{scene_res}\" id=\"3_scene\"]")
    body = [
        "",
        "[resource]",
        "script = ExtResource(\"1_script\")",
        f"id = {spec['id']}",
        f"display_name = \"{spec['name']}\"",
        f"description = \"{spec['desc']}\"",
        "icon = ExtResource(\"2_icon\")",
        "max_stack = 999",
        "item_type = 0",
        f"category = {spec['category']}",
        "equipment_slot = 0",
        f"placeable_block_id = {spec['block']}",
        f"building_material = {spec['mat']}",
        f"building_part_type = {spec['part']}",
        f"can_rotate = {str(spec.get('rotate', False)).lower()}",
        "held_scale = 1.0",
    ]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(ext + body) + "\n")


def main():
    atlas = blank(ATLAS_W * TILE, ATLAS_H * TILE)
    kinds_row = [
        ("foundation", WOOD),
        ("foundation", STONE),
        ("wall", WOOD),
        ("wall", STONE),
        ("bg", WOOD),
        ("bg", STONE),
        ("floor", WOOD),
        ("floor", STONE),
    ]
    for row, (kind, pal) in enumerate(kinds_row):
        for mask in range(16):
            draw_connected(atlas, mask * TILE, row * TILE, pal, mask, kind)
    for v in range(7):
        draw_roof(atlas, v * TILE, 8 * TILE, WOOD, v, straw=False)
        draw_roof(atlas, v * TILE, 9 * TILE, WOOD, v, straw=True)
    extras = [
        (0, 10, draw_beam),
        (1, 10, lambda p, x, y: draw_stairs(p, x, y, WOOD, False)),
        (2, 10, lambda p, x, y: draw_stairs(p, x, y, WOOD, True)),
        (3, 10, lambda p, x, y: draw_stairs(p, x, y, STONE, False)),
        (4, 10, lambda p, x, y: draw_stairs(p, x, y, STONE, True)),
        (5, 10, draw_ladder),
        (6, 10, lambda p, x, y: draw_platform(p, x, y, WOOD)),
        (7, 10, lambda p, x, y: draw_platform(p, x, y, STONE)),
        (8, 10, lambda p, x, y: draw_window(p, x, y, True)),
        (9, 10, lambda p, x, y: draw_window(p, x, y, False)),
        (10, 10, draw_barricade),
        (11, 10, draw_barrel),
        (12, 10, draw_shelf),
        (13, 10, draw_table),
        (14, 10, draw_chair),
        (15, 10, draw_sign),
        (0, 11, draw_rack),
        (1, 11, draw_wall_torch),
        (2, 11, draw_chest),
    ]
    for cx, cy, fn in extras:
        fn(atlas, cx * TILE, cy * TILE)

    kinds = ("single", "inner", "start", "end", "floor", "platform")
    for i, kind in enumerate(kinds):
        draw_stair_variant(atlas, i * TILE, 12 * TILE, WOOD, True, kind)
        draw_stair_variant(atlas, (i + 6) * TILE, 12 * TILE, WOOD, False, kind)
        draw_stair_variant(atlas, i * TILE, 13 * TILE, STONE, True, kind)
        draw_stair_variant(atlas, (i + 6) * TILE, 13 * TILE, STONE, False, kind)

    atlas_path = os.path.join(ROOT, "assets", "building", "building_atlas.png")
    write_png(atlas_path, ATLAS_W * TILE, ATLAS_H * TILE, atlas)

    def tile_at(cx, cy):
        return crop(atlas, cx * TILE, cy * TILE, TILE, TILE)

    icons = {
        "wood_foundation": tile_at(0, 0),
        "stone_foundation": tile_at(0, 1),
        "wood_wall": tile_at(0, 2),
        "stone_wall": tile_at(0, 3),
        "wood_background": tile_at(0, 4),
        "stone_background": tile_at(0, 5),
        "wood_floor": tile_at(0, 6),
        "stone_floor": tile_at(0, 7),
        "wood_roof": tile_at(0, 8),
        "straw_roof": tile_at(0, 9),
        "wood_beam": tile_at(0, 10),
        "wood_stairs": tile_at(2, 10),
        "stone_stairs": tile_at(4, 10),
        "wood_ladder": tile_at(5, 10),
        "wood_platform": tile_at(6, 10),
        "stone_platform": tile_at(7, 10),
        "wood_window": tile_at(8, 10),
        "glass_window": tile_at(9, 10),
        "wood_barricade": tile_at(10, 10),
        "wood_barrel": tile_at(11, 10),
        "wood_shelf": tile_at(12, 10),
        "wood_table": tile_at(13, 10),
        "wood_chair": tile_at(14, 10),
        "wood_sign": tile_at(15, 10),
        "weapon_rack": tile_at(0, 11),
        "wall_torch": tile_at(1, 11),
        "wood_chest": tile_at(2, 11),
    }
    door = draw_door_sprite(reinforced=False)
    rdoor = draw_door_sprite(reinforced=True)
    gate = draw_gate_sprite()
    bench = draw_workbench()
    anvil = draw_anvil()
    furnace = draw_furnace()
    sprites = {
        "wood_door": door,
        "reinforced_wood_door": rdoor,
        "wood_gate": gate,
        "workbench": bench,
        "anvil": anvil,
        "furnace": furnace,
        "wood_chest": draw_chest(),
        "wall_torch": draw_wall_torch(),
    }
    icons["wood_door"] = icon_from_large(door)
    icons["reinforced_wood_door"] = icon_from_large(rdoor)
    icons["wood_gate"] = icon_from_large(gate)
    icons["workbench"] = icon_from_large(bench)
    icons["anvil"] = icon_from_large(anvil)
    icons["furnace"] = icon_from_large(furnace)

    folders = {
        "wood_foundation": "foundations",
        "stone_foundation": "foundations",
        "wood_wall": "walls",
        "stone_wall": "walls",
        "wood_background": "backgrounds",
        "stone_background": "backgrounds",
        "wood_floor": "floors",
        "stone_floor": "floors",
        "wood_roof": "roofs",
        "straw_roof": "roofs",
        "wood_beam": "supports",
        "wood_stairs": "stairs",
        "stone_stairs": "stairs",
        "wood_ladder": "stairs",
        "wood_platform": "platforms",
        "stone_platform": "platforms",
        "wood_window": "windows",
        "glass_window": "windows",
        "wood_door": "doors",
        "reinforced_wood_door": "doors",
        "wood_gate": "defense",
        "wood_barricade": "defense",
        "wall_torch": "lights",
        "wood_chest": "furniture",
        "wood_barrel": "furniture",
        "wood_shelf": "furniture",
        "wood_table": "furniture",
        "wood_chair": "furniture",
        "wood_sign": "furniture",
        "weapon_rack": "furniture",
        "workbench": "stations",
        "anvil": "stations",
        "furnace": "stations",
    }
    icon_paths = {}
    for key, img in icons.items():
        folder = folders[key]
        path = os.path.join(ROOT, "assets", "building", folder, f"{key}_icon.png")
        write_png(path, 16, 16, img)
        icon_paths[key] = f"res://assets/building/{folder}/{key}_icon.png"
    for key, img in sprites.items():
        folder = folders[key]
        h, w = len(img), len(img[0])
        path = os.path.join(ROOT, "assets", "building", folder, f"{key}.png")
        write_png(path, w, h, img)

    # Block specs: id, name, atlas x,y, source, autotile, hardness, drop, solid, tool, power,
    # structural, role, weight, strength, max_h, foundation, beam, enemy, importance,
    # mat, part, flammable, bg, oneway, climb, orient, footprint, vision, map
    AXE, PICK = 2, 1
    CAT_BUILD, CAT_DEF, CAT_TECH = 6, 13, 14
    blocks = [
        dict(file="foundations/wood_foundation", id=31, display_name="Holzfundament", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=16, hardness=1.1, drop_item_id=62, solid="true", vision_occlusion=0.7, map_color="Color(0.45, 0.28, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=1, structural_weight=2, support_strength=8, max_horizontal_support=4, is_foundation_material="true", is_support_beam="false", enemy_break_cost=3, structural_importance=4, building_material=1, building_part_type=1, flammable="true"),
        dict(file="foundations/stone_foundation", id=32, display_name="Steinfundament", atlas_coords="Vector2i(0, 1)", atlas_source_id=1, autotile_count=16, hardness=1.8, drop_item_id=63, solid="true", vision_occlusion=0.85, map_color="Color(0.42, 0.44, 0.48, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="true", structural_role=1, structural_weight=4, support_strength=14, max_horizontal_support=6, is_foundation_material="true", is_support_beam="false", enemy_break_cost=6, structural_importance=6, building_material=2, building_part_type=1, flammable="false"),
        dict(file="walls/wood_wall", id=33, display_name="Holzwand", atlas_coords="Vector2i(0, 2)", atlas_source_id=1, autotile_count=16, hardness=1.0, drop_item_id=64, solid="true", vision_occlusion=0.75, map_color="Color(0.52, 0.32, 0.16, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=1, support_strength=5, max_horizontal_support=5, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=2, building_material=1, building_part_type=2, flammable="true"),
        dict(file="walls/stone_wall", id=34, display_name="Steinwand", atlas_coords="Vector2i(0, 3)", atlas_source_id=1, autotile_count=16, hardness=1.6, drop_item_id=65, solid="true", vision_occlusion=0.9, map_color="Color(0.5, 0.52, 0.56, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=3, support_strength=10, max_horizontal_support=6, is_foundation_material="false", is_support_beam="false", enemy_break_cost=5, structural_importance=3, building_material=2, building_part_type=2, flammable="false"),
        dict(file="backgrounds/wood_background", id=35, display_name="Holz-Hintergrundwand", atlas_coords="Vector2i(0, 4)", atlas_source_id=1, autotile_count=16, hardness=0.6, drop_item_id=66, solid="false", vision_occlusion=0.12, map_color="Color(0.32, 0.2, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=3, flammable="true", is_background="true"),
        dict(file="backgrounds/stone_background", id=36, display_name="Stein-Hintergrundwand", atlas_coords="Vector2i(0, 5)", atlas_source_id=1, autotile_count=16, hardness=0.9, drop_item_id=67, solid="false", vision_occlusion=0.16, map_color="Color(0.3, 0.32, 0.36, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=0, building_material=2, building_part_type=3, flammable="false", is_background="true"),
        dict(file="floors/wood_floor", id=37, display_name="Holzboden", atlas_coords="Vector2i(0, 6)", atlas_source_id=1, autotile_count=16, hardness=0.9, drop_item_id=68, solid="true", vision_occlusion=0.55, map_color="Color(0.48, 0.3, 0.16, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=1, support_strength=4, max_horizontal_support=6, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=1, building_material=1, building_part_type=4, flammable="true"),
        dict(file="floors/stone_floor", id=38, display_name="Steinboden", atlas_coords="Vector2i(0, 7)", atlas_source_id=1, autotile_count=16, hardness=1.4, drop_item_id=69, solid="true", vision_occlusion=0.7, map_color="Color(0.46, 0.48, 0.52, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=2, support_strength=8, max_horizontal_support=7, is_foundation_material="false", is_support_beam="false", enemy_break_cost=4, structural_importance=2, building_material=2, building_part_type=4, flammable="false"),
        dict(file="roofs/wood_roof", id=39, display_name="Holzdach", atlas_coords="Vector2i(0, 8)", atlas_source_id=1, autotile_count=7, hardness=0.8, drop_item_id=70, solid="true", vision_occlusion=0.5, map_color="Color(0.4, 0.22, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=5, structural_weight=1, support_strength=3, max_horizontal_support=4, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=3, building_material=1, building_part_type=5, flammable="true"),
        dict(file="roofs/straw_roof", id=40, display_name="Strohdach", atlas_coords="Vector2i(0, 9)", atlas_source_id=1, autotile_count=7, hardness=0.45, drop_item_id=71, solid="true", vision_occlusion=0.35, map_color="Color(0.7, 0.52, 0.18, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=5, structural_weight=1, support_strength=2, max_horizontal_support=3, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=2, building_material=1, building_part_type=5, flammable="true"),
        dict(file="supports/wood_beam", id=41, display_name="Holzbalken", atlas_coords="Vector2i(0, 10)", atlas_source_id=1, autotile_count=1, hardness=1.0, drop_item_id=72, solid="false", vision_occlusion=0.15, map_color="Color(0.4, 0.24, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=4, structural_weight=1, support_strength=8, max_horizontal_support=10, is_foundation_material="false", is_support_beam="false", enemy_break_cost=3, structural_importance=5, building_material=1, building_part_type=7, flammable="true"),
        dict(file="stairs/wood_stairs", id=42, display_name="Holztreppe", atlas_coords="Vector2i(1, 10)", atlas_source_id=1, autotile_count=1, hardness=0.9, drop_item_id=73, solid="true", vision_occlusion=0.2, map_color="Color(0.5, 0.32, 0.16, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=1, support_strength=4, max_horizontal_support=3, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=1, building_material=1, building_part_type=9, flammable="true", uses_orientation="true"),
        dict(file="stairs/stone_stairs", id=43, display_name="Steintreppe", atlas_coords="Vector2i(3, 10)", atlas_source_id=1, autotile_count=1, hardness=1.5, drop_item_id=74, solid="true", vision_occlusion=0.25, map_color="Color(0.48, 0.5, 0.54, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=2, support_strength=7, max_horizontal_support=4, is_foundation_material="false", is_support_beam="false", enemy_break_cost=4, structural_importance=2, building_material=2, building_part_type=9, flammable="false", uses_orientation="true"),
        dict(file="stairs/wood_ladder", id=44, display_name="Holzleiter", atlas_coords="Vector2i(5, 10)", atlas_source_id=1, autotile_count=1, hardness=0.7, drop_item_id=75, solid="false", vision_occlusion=0.08, map_color="Color(0.42, 0.26, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=10, flammable="true", is_climbable="true"),
        dict(file="platforms/wood_platform", id=45, display_name="Holzplattform", atlas_coords="Vector2i(6, 10)", atlas_source_id=1, autotile_count=1, hardness=0.8, drop_item_id=76, solid="true", vision_occlusion=0.1, map_color="Color(0.46, 0.3, 0.16, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=1, support_strength=3, max_horizontal_support=8, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=1, building_material=1, building_part_type=8, flammable="true", is_one_way="true"),
        dict(file="platforms/stone_platform", id=46, display_name="Steinplattform", atlas_coords="Vector2i(7, 10)", atlas_source_id=1, autotile_count=1, hardness=1.3, drop_item_id=77, solid="true", vision_occlusion=0.12, map_color="Color(0.44, 0.46, 0.5, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="true", structural_role=2, structural_weight=2, support_strength=6, max_horizontal_support=10, is_foundation_material="false", is_support_beam="false", enemy_break_cost=4, structural_importance=2, building_material=2, building_part_type=8, flammable="false", is_one_way="true"),
        dict(file="windows/wood_window", id=47, display_name="Holzfenster", atlas_coords="Vector2i(8, 10)", atlas_source_id=1, autotile_count=1, hardness=0.7, drop_item_id=80, solid="true", vision_occlusion=0.18, map_color="Color(0.35, 0.5, 0.55, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=0, building_material=1, building_part_type=12, flammable="true"),
        dict(file="windows/glass_window", id=48, display_name="Glasfenster", atlas_coords="Vector2i(9, 10)", atlas_source_id=1, autotile_count=1, hardness=0.5, drop_item_id=81, solid="true", vision_occlusion=0.12, map_color="Color(0.4, 0.62, 0.72, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=4, building_part_type=12, flammable="false"),
        dict(file="defense/wood_barricade", id=49, display_name="Holzbarrikade", atlas_coords="Vector2i(10, 10)", atlas_source_id=1, autotile_count=1, hardness=1.3, drop_item_id=93, solid="true", vision_occlusion=0.4, map_color="Color(0.36, 0.22, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=8, structural_importance=0, building_material=1, building_part_type=16, flammable="true"),
        dict(file="furniture/wood_barrel", id=50, display_name="Holzfass", atlas_coords="Vector2i(11, 10)", atlas_source_id=1, autotile_count=1, hardness=0.6, drop_item_id=84, solid="false", vision_occlusion=0.1, map_color="Color(0.4, 0.24, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="furniture/wood_shelf", id=51, display_name="Holzregal", atlas_coords="Vector2i(12, 10)", atlas_source_id=1, autotile_count=1, hardness=0.5, drop_item_id=85, solid="false", vision_occlusion=0.08, map_color="Color(0.38, 0.24, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="furniture/wood_table", id=52, display_name="Holztisch", atlas_coords="Vector2i(13, 10)", atlas_source_id=1, autotile_count=1, hardness=0.6, drop_item_id=86, solid="false", vision_occlusion=0.08, map_color="Color(0.42, 0.26, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="furniture/wood_chair", id=53, display_name="Holzstuhl", atlas_coords="Vector2i(14, 10)", atlas_source_id=1, autotile_count=1, hardness=0.45, drop_item_id=87, solid="false", vision_occlusion=0.06, map_color="Color(0.4, 0.25, 0.13, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="furniture/wood_sign", id=54, display_name="Holzschild", atlas_coords="Vector2i(15, 10)", atlas_source_id=1, autotile_count=1, hardness=0.4, drop_item_id=88, solid="false", vision_occlusion=0.05, map_color="Color(0.44, 0.3, 0.16, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="furniture/weapon_rack", id=55, display_name="Waffenhalter", atlas_coords="Vector2i(0, 11)", atlas_source_id=1, autotile_count=1, hardness=0.55, drop_item_id=89, solid="false", vision_occlusion=0.08, map_color="Color(0.36, 0.24, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=17, flammable="true"),
        dict(file="doors/wood_door", id=56, display_name="Holztür", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=1.2, drop_item_id=78, solid="false", vision_occlusion=0.2, map_color="Color(0.4, 0.24, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=5, structural_importance=0, building_material=1, building_part_type=11, flammable="true", footprint="Vector2i(1, 3)"),
        dict(file="doors/reinforced_wood_door", id=57, display_name="Verstärkte Holztür", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=2.0, drop_item_id=79, solid="false", vision_occlusion=0.25, map_color="Color(0.34, 0.22, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=12, structural_importance=0, building_material=1, building_part_type=11, flammable="true", footprint="Vector2i(1, 3)"),
        dict(file="defense/wood_gate", id=58, display_name="Holztor", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=1.8, drop_item_id=94, solid="false", vision_occlusion=0.3, map_color="Color(0.32, 0.2, 0.1, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=14, structural_importance=0, building_material=1, building_part_type=16, flammable="true", footprint="Vector2i(2, 3)"),
        dict(file="furniture/wood_chest", id=59, display_name="Holzkiste", atlas_coords="Vector2i(2, 11)", atlas_source_id=1, autotile_count=1, hardness=0.8, drop_item_id=83, solid="false", vision_occlusion=0.12, map_color="Color(0.42, 0.26, 0.12, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=2, structural_importance=0, building_material=1, building_part_type=14, flammable="true"),
        dict(file="stations/workbench", id=60, display_name="Werkbank", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=1.1, drop_item_id=90, solid="false", vision_occlusion=0.15, map_color="Color(0.4, 0.26, 0.14, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=3, structural_importance=0, building_material=1, building_part_type=15, flammable="true", footprint="Vector2i(2, 1)"),
        dict(file="stations/anvil", id=61, display_name="Amboss", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=2.4, drop_item_id=91, solid="false", vision_occlusion=0.18, map_color="Color(0.45, 0.46, 0.5, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=6, structural_importance=0, building_material=4, building_part_type=15, flammable="false", footprint="Vector2i(2, 1)"),
        dict(file="stations/furnace", id=62, display_name="Schmelzofen", atlas_coords="Vector2i(0, 0)", atlas_source_id=1, autotile_count=1, hardness=2.0, drop_item_id=92, solid="false", vision_occlusion=0.3, map_color="Color(0.55, 0.28, 0.16, 1)", required_tool=PICK, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=6, structural_importance=0, building_material=2, building_part_type=15, flammable="false", footprint="Vector2i(2, 2)"),
        dict(file="lights/wall_torch", id=63, display_name="Wandfackel", atlas_coords="Vector2i(1, 11)", atlas_source_id=1, autotile_count=1, hardness=0.3, drop_item_id=82, solid="false", vision_occlusion=0.02, map_color="Color(0.9, 0.55, 0.18, 1)", required_tool=AXE, required_tool_power=1, structural_enabled="false", structural_role=0, structural_weight=0, support_strength=0, max_horizontal_support=0, is_foundation_material="false", is_support_beam="false", enemy_break_cost=1, structural_importance=0, building_material=1, building_part_type=13, flammable="true", light_energy=1.1),
    ]

    # Entity blocks shouldn't create atlas tiles at 0,0 of building atlas overlapping foundation.
    # Use a dummy unused atlas cell for entity-only blocks: row 11 col 3+
    entity_atlas = {
        56: "Vector2i(3, 11)",
        57: "Vector2i(4, 11)",
        58: "Vector2i(5, 11)",
        60: "Vector2i(6, 11)",
        61: "Vector2i(7, 11)",
        62: "Vector2i(8, 11)",
    }
    for b in blocks:
        if b["id"] in entity_atlas:
            b["atlas_coords"] = entity_atlas[b["id"]]

    for b in blocks:
        path = os.path.join(ROOT, "resources", "blocks", "building", b["file"] + ".tres")
        spec = {k: v for k, v in b.items() if k != "file"}
        write_tres_block(path, spec)

    items = [
        dict(key="wood_foundation", id=62, name="Holzfundament", desc="Hölzerne Bodenverankerung für Spielergebäude.", block=31, mat=1, part=1, category=CAT_BUILD),
        dict(key="stone_foundation", id=63, name="Steinfundament", desc="Schweres Stein-Fundament. Stabiler als Holz.", block=32, mat=2, part=1, category=CAT_BUILD),
        dict(key="wood_wall", id=64, name="Holzwand", desc="Tragende Holzwand. Varianten entstehen anhand der Nachbarn.", block=33, mat=1, part=2, category=CAT_BUILD),
        dict(key="stone_wall", id=65, name="Steinwand", desc="Tragende Steinwand.", block=34, mat=2, part=2, category=CAT_BUILD),
        dict(key="wood_background", id=66, name="Holz-Hintergrundwand", desc="Optische Hinterwand. Trägt kein Dach.", block=35, mat=1, part=3, category=CAT_BUILD),
        dict(key="stone_background", id=67, name="Stein-Hintergrundwand", desc="Optische Stein-Hinterwand ohne Spielerkollision.", block=36, mat=2, part=3, category=CAT_BUILD),
        dict(key="wood_floor", id=68, name="Holzboden", desc="Sichtbarer Gebäudeboden aus Holz.", block=37, mat=1, part=4, category=CAT_BUILD),
        dict(key="stone_floor", id=69, name="Steinboden", desc="Sichtbarer Gebäudeboden aus Stein.", block=38, mat=2, part=4, category=CAT_BUILD),
        dict(key="wood_roof", id=70, name="Holzdach", desc="Modulares Holzdach. Die Form folgt den Nachbarn.", block=39, mat=1, part=5, category=CAT_BUILD),
        dict(key="straw_roof", id=71, name="Strohdach", desc="Leichtes, brennbares Dach für frühe Hütten.", block=40, mat=1, part=5, category=CAT_BUILD),
        dict(key="wood_beam", id=72, name="Holzbalken", desc="Horizontaler Balken. Überträgt Last über begrenzte Distanz.", block=41, mat=1, part=7, category=CAT_BUILD),
        dict(key="wood_stairs", id=73, name="Holztreppe", desc="Diagonale Holztreppe. Richtung und Verbindung entstehen automatisch.", block=42, mat=1, part=9, category=CAT_BUILD, rotate=True),
        dict(key="stone_stairs", id=74, name="Steintreppe", desc="Diagonale Steintreppe. Richtung und Verbindung entstehen automatisch.", block=43, mat=2, part=9, category=CAT_BUILD, rotate=True),
        dict(key="wood_ladder", id=75, name="Holzleiter", desc="Klettern nach oben und unten, ohne volle Blockkollision.", block=44, mat=1, part=10, category=CAT_BUILD),
        dict(key="wood_platform", id=76, name="Holzplattform", desc="Einweg-Plattform. Von unten durchspringen, mit Ducken fallen.", block=45, mat=1, part=8, category=CAT_BUILD),
        dict(key="stone_platform", id=77, name="Steinplattform", desc="Schwerere Einweg-Plattform.", block=46, mat=2, part=8, category=CAT_BUILD),
        dict(key="wood_door", id=78, name="Holztür", desc="Öffnen und schließen mit Interagieren.", block=56, mat=1, part=11, category=CAT_BUILD, rotate=True),
        dict(key="reinforced_wood_door", id=79, name="Verstärkte Holztür", desc="Dickeres Holz mit Metallbeschlägen. Später belagerungsfest.", block=57, mat=1, part=11, category=CAT_BUILD, rotate=True),
        dict(key="wood_window", id=80, name="Holzfenster", desc="Holzrahmen mit Öffnung. Später zerstörbar durch Gegner.", block=47, mat=1, part=12, category=CAT_BUILD),
        dict(key="glass_window", id=81, name="Glasfenster", desc="Teiltransparentes Glas, klar von Wänden unterscheidbar.", block=48, mat=4, part=12, category=CAT_BUILD),
        dict(key="wall_torch", id=82, name="Wandfackel", desc="Platzierbares Licht an Wänden und Hinterwänden.", block=63, mat=1, part=13, category=CAT_BUILD),
        dict(key="wood_chest", id=83, name="Holzkiste", desc="Platzierbare Kiste. Lager folgt später.", block=59, mat=1, part=14, category=CAT_BUILD),
        dict(key="wood_barrel", id=84, name="Holzfass", desc="Einrichtung. Später als Lager nutzbar.", block=50, mat=1, part=17, category=CAT_BUILD),
        dict(key="wood_shelf", id=85, name="Holzregal", desc="Dekoration ohne Statik.", block=51, mat=1, part=17, category=CAT_BUILD),
        dict(key="wood_table", id=86, name="Holztisch", desc="Möbel / Einrichtung.", block=52, mat=1, part=17, category=CAT_BUILD, rotate=True),
        dict(key="wood_chair", id=87, name="Holzstuhl", desc="Möbel / Einrichtung.", block=53, mat=1, part=17, category=CAT_BUILD, rotate=True),
        dict(key="wood_sign", id=88, name="Holzschild", desc="Platzierbares Schild. Texteditor folgt später.", block=54, mat=1, part=17, category=CAT_BUILD),
        dict(key="weapon_rack", id=89, name="Waffenhalter", desc="Dekoration. Später Item-Display möglich.", block=55, mat=1, part=17, category=CAT_BUILD),
        dict(key="workbench", id=90, name="Werkbank", desc="Arbeitsstation. Crafting kann später andocken.", block=60, mat=1, part=15, category=CAT_TECH),
        dict(key="anvil", id=91, name="Amboss", desc="Metall-Station für spätere Schmiede.", block=61, mat=4, part=15, category=CAT_TECH),
        dict(key="furnace", id=92, name="Schmelzofen", desc="Steinofen mit Glutöffnung. Animation folgt später.", block=62, mat=2, part=15, category=CAT_TECH),
        dict(key="wood_barricade", id=93, name="Holzbarrikade", desc="Zerstörbare Barriere. Später Gegnerblockade.", block=49, mat=1, part=16, category=CAT_DEF),
        dict(key="wood_gate", id=94, name="Holztor", desc="Großes Tor. Öffnen und schließen mit Interagieren.", block=58, mat=1, part=16, category=CAT_DEF, rotate=True),
    ]
    item_files = []
    for it in items:
        folder = folders[it["key"]]
        path = os.path.join(ROOT, "resources", "items", "building", folder, f"{it['key']}.tres")
        write_tres_item(path, it, icon_paths[it["key"]])
        item_files.append(f"res://resources/items/building/{folder}/{it['key']}.tres")

    # Patch catalogs
    patch_item_catalog(item_files)
    patch_block_catalog([f"res://resources/blocks/building/{b['file']}.tres" for b in blocks])
    print("generated", len(blocks), "blocks", len(items), "items")


def patch_item_catalog(new_paths):
    path = os.path.join(ROOT, "resources", "items", "item_catalog.tres")
    text = open(path, encoding="utf-8").read()
    # remove previously generated building entries
    lines = [ln for ln in text.splitlines() if "items/building/" not in ln]
    text = "\n".join(lines)
    # find last ext_resource id
    ids = []
    for ln in text.splitlines():
        if "id=\"" in ln and "ext_resource" in ln:
            ids.append(ln.split("id=\"")[1].split("\"")[0])
    start = 100
    inject = []
    names = []
    for i, p in enumerate(new_paths):
        eid = f"{start + i}_b"
        inject.append(f"[ext_resource type=\"Resource\" path=\"{p}\" id=\"{eid}\"]")
        names.append(f"ExtResource(\"{eid}\")")
    if "[resource]" in text:
        head, rest = text.split("[resource]", 1)
        head = head.rstrip() + "\n" + "\n".join(inject) + "\n\n[resource]"
        # items = [...]
        import re
        m = re.search(r"items = \[([^\]]*)\]", rest, re.S)
        if not m:
            raise SystemExit("item catalog items array missing")
        inner = m.group(1).rstrip()
        if not inner.endswith(","):
            inner = inner + ","
        inner = inner + " " + ", ".join(names)
        rest = rest[: m.start(1)] + inner + rest[m.end(1) :]
        open(path, "w", encoding="utf-8").write(head + rest if rest.startswith("\n") else head + "\n" + rest)


def patch_block_catalog(new_paths):
    path = os.path.join(ROOT, "resources", "blocks", "block_catalog.tres")
    text = open(path, encoding="utf-8").read()
    lines = [ln for ln in text.splitlines() if "blocks/building/" not in ln]
    text = "\n".join(lines)
    start = 200
    inject = []
    names = []
    for i, p in enumerate(new_paths):
        eid = f"{start + i}_bb"
        inject.append(f"[ext_resource type=\"Resource\" path=\"{p}\" id=\"{eid}\"]")
        names.append(f"ExtResource(\"{eid}\")")
    head, rest = text.split("[resource]", 1)
    head = head.rstrip() + "\n" + "\n".join(inject) + "\n\n[resource]"
    import re
    m = re.search(r"blocks = \[([^\]]*)\]", rest, re.S)
    inner = m.group(1).rstrip()
    if not inner.endswith(","):
        inner = inner + ","
    inner = inner + " " + ", ".join(names)
    rest = rest[: m.start(1)] + inner + rest[m.end(1) :]
    open(path, "w", encoding="utf-8").write(head + rest if rest.startswith("\n") else head + "\n" + rest)


if __name__ == "__main__":
    main()
