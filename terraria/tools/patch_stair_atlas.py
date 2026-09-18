#!/usr/bin/env python3
"""Patch only stair tiles into the existing building atlas. Does not rewrite .tres files."""
from __future__ import annotations

import os
import struct
import zlib
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from generate_building_parts import (  # noqa: E402
    ATLAS_H,
    ATLAS_W,
    TILE,
    STONE,
    WOOD,
    blank,
    crop,
    draw_stair_variant,
    write_png,
)


def read_png(path: str):
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    w = h = 0
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        tag = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if tag == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
        elif tag == b"IDAT":
            idat += chunk
        elif tag == b"IEND":
            break
    raw = zlib.decompress(idat)
    pixels = []
    i = 0
    bpp = 4
    for _y in range(h):
        filt = raw[i]
        i += 1
        row = bytearray(raw[i : i + w * bpp])
        i += w * bpp
        if filt == 1:
            for x in range(len(row)):
                left = row[x - bpp] if x >= bpp else 0
                row[x] = (row[x] + left) & 255
        elif filt == 2:
            up = pixels[-1] if pixels else [(0, 0, 0, 0)] * w
            for x in range(w):
                for c in range(4):
                    row[x * 4 + c] = (row[x * 4 + c] + up[x][c]) & 255
        elif filt != 0:
            raise RuntimeError("unsupported PNG filter %d" % filt)
        pixels.append([tuple(row[x * 4 : x * 4 + 4]) for x in range(w)])
    return pixels


def blit(dst, src, ox, oy):
    for y, row in enumerate(src):
        for x, pix in enumerate(row):
            if 0 <= oy + y < len(dst) and 0 <= ox + x < len(dst[0]):
                dst[oy + y][ox + x] = pix


def main():
    atlas_path = os.path.join(ROOT, "assets", "building", "building_atlas.png")
    old = read_png(atlas_path)
    canvas = blank(ATLAS_W * TILE, ATLAS_H * TILE)
    blit(canvas, old, 0, 0)
    kinds = ("single", "inner", "start", "end", "floor", "platform")
    draw_stair_variant(canvas, 1 * TILE, 10 * TILE, WOOD, False, "inner")
    draw_stair_variant(canvas, 2 * TILE, 10 * TILE, WOOD, True, "inner")
    draw_stair_variant(canvas, 3 * TILE, 10 * TILE, STONE, False, "inner")
    draw_stair_variant(canvas, 4 * TILE, 10 * TILE, STONE, True, "inner")
    for i, kind in enumerate(kinds):
        draw_stair_variant(canvas, i * TILE, 12 * TILE, WOOD, True, kind)
        draw_stair_variant(canvas, (i + 6) * TILE, 12 * TILE, WOOD, False, kind)
        draw_stair_variant(canvas, i * TILE, 13 * TILE, STONE, True, kind)
        draw_stair_variant(canvas, (i + 6) * TILE, 13 * TILE, STONE, False, kind)
    write_png(atlas_path, ATLAS_W * TILE, ATLAS_H * TILE, canvas)

    def tile_at(cx, cy):
        return crop(canvas, cx * TILE, cy * TILE, TILE, TILE)

    write_png(os.path.join(ROOT, "assets", "building", "stairs", "wood_stairs_icon.png"), 16, 16, tile_at(1, 12))
    write_png(os.path.join(ROOT, "assets", "building", "stairs", "stone_stairs_icon.png"), 16, 16, tile_at(1, 13))
    print("patched", atlas_path, "size", ATLAS_W * TILE, "x", ATLAS_H * TILE)


if __name__ == "__main__":
    main()
