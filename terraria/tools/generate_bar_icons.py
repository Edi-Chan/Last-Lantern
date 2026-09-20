"""Generiert 16x16-Barren-Icons im Pixel-Stil des Projekts."""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BARS = [
    dict(key="copper", color=(196, 108, 42)),
    dict(key="tin", color=(196, 204, 210)),
    dict(key="ferrite", color=(176, 64, 48)),
    dict(key="aurel", color=(232, 186, 48)),
    dict(key="cobalt", color=(48, 96, 210)),
    dict(key="veyrite", color=(148, 64, 196)),
    dict(key="cryonite", color=(72, 210, 220), sparkle=(240, 250, 255)),
    dict(key="ignitium", color=(232, 86, 28), sparkle=(255, 220, 120)),
    dict(key="voidium", color=(58, 24, 78), sparkle=(140, 90, 200)),
    dict(key="astralith", color=(186, 140, 255), sparkle=(240, 230, 255)),
]


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


def put(img, x, y, color):
    if 0 <= y < len(img) and 0 <= x < len(img[0]):
        img[y][x] = color


def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3)) + (255,)


def draw_ingot(img, x0, y0, width, height, base, light, mid, dark, shadow):
    for y in range(height):
        for x in range(width):
            px = x0 + x
            py = y0 + y
            if y == 0:
                color = light
            elif y == height - 1:
                color = shadow
            elif x == 0:
                color = dark
            elif x == width - 1:
                color = mix(mid, light, 0.35)
            elif y == 1 and x in (1, width - 2):
                color = light
            else:
                color = mid if (x + y) % 2 == 0 else base
            put(img, px, py, color)


def make_bar_icon(color, sparkle=None):
    img = [[(0, 0, 0, 0) for _ in range(16)] for _ in range(16)]
    base = color + (255,)
    light = mix(color, (255, 255, 255, 255), 0.48)
    mid = mix(color, (255, 255, 255, 255), 0.18)
    dark = mix(color, (24, 18, 16, 255), 0.35)
    shadow = mix(color, (0, 0, 0, 255), 0.55)

    draw_ingot(img, 2, 10, 10, 3, base, light, mid, dark, shadow)
    draw_ingot(img, 4, 7, 9, 3, base, light, mid, dark, shadow)
    draw_ingot(img, 3, 4, 9, 3, base, light, mid, dark, shadow)

    if sparkle:
        put(img, 4, 4, sparkle + (255,))
        put(img, 10, 7, sparkle + (255,))
        put(img, 8, 10, sparkle + (255,))

    return img


def main() -> None:
    out_dir = os.path.join(ROOT, "assets", "items", "bars")
    for bar in BARS:
        icon = make_bar_icon(bar["color"], bar.get("sparkle"))
        write_png(os.path.join(out_dir, f"{bar['key']}_bar.png"), icon)
    print(f"generated {len(BARS)} bar icons in {out_dir}")


if __name__ == "__main__":
    main()
