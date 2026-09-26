"""Generiert kleine, duenne Pixel-Maus und Crosshair."""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "cursor")

OUTLINE = (10, 8, 6, 255)
CREAM = (248, 236, 206, 255)
RED = (214, 62, 48, 255)
EMPTY = (0, 0, 0, 0)


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, pixels: list) -> None:
    h = len(pixels)
    w = len(pixels[0])
    raw = b""
    for row in pixels:
        raw += b"\x00"
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(png)


def blank(size: int = 16) -> list:
    return [[EMPTY for _ in range(size)] for _ in range(size)]


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def paint(img, rows, ox=0, oy=0):
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "X":
                put(img, ox + x, oy + y, OUTLINE)
            elif ch in (".", "o"):
                put(img, ox + x, oy + y, CREAM)
            elif ch == "R":
                put(img, ox + x, oy + y, RED)


def make_pointer():
    img = blank()
    paint(img, [
        "X",
        "XX",
        "X.X",
        "X..X",
        "X...X",
        "X....X",
        "X.....X",
        "X......X",
        "X.....X",
        "X..XX",
        "X.X  X",
        "XX    X",
        "X",
    ], 1, 1)
    return img


def make_crosshair(fill):
    img = blank()
    c = 7
    arms = [
        (c, 2), (c, 3), (c, 4),
        (c, 10), (c, 11), (c, 12),
        (2, c), (3, c), (4, c),
        (10, c), (11, c), (12, c),
    ]
    for x, y in arms:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if abs(nx - c) <= 1 and abs(ny - c) <= 1:
                    continue
                if 0 <= nx < 16 and 0 <= ny < 16 and img[ny][nx][3] == 0:
                    put(img, nx, ny, OUTLINE)
    for x, y in arms:
        put(img, x, y, fill)
    return img


def main():
    write_png(os.path.join(OUT, "pointer.png"), make_pointer())
    write_png(os.path.join(OUT, "crosshair.png"), make_crosshair(CREAM))
    write_png(os.path.join(OUT, "target.png"), make_crosshair(RED))
    print("cursor assets ->", OUT)


if __name__ == "__main__":
    main()
