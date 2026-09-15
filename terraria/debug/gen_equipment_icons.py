"""Erzeugt 16x16-Platzhalter-Icons fuer Ausruestungsitems.

Aufruf aus dem Projektwurzelverzeichnis:  python debug/gen_equipment_icons.py
"""

import os

from PIL import Image

OUT_DIR = os.path.join("assets", "items", "equipment")

CLEAR = (0, 0, 0, 0)
EDGE = (58, 62, 74, 255)
METAL = (140, 148, 164, 255)
METAL_LIGHT = (186, 194, 208, 255)
METAL_DARK = (96, 103, 118, 255)
VISOR = (38, 42, 52, 255)


def draw(pixels, rect, color):
    x0, y0, x1, y1 = rect
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            pixels[x, y] = color


def make_helmet():
    image = Image.new("RGBA", (16, 16), CLEAR)
    px = image.load()
    draw(px, (3, 2, 12, 12), EDGE)
    draw(px, (4, 3, 11, 11), METAL)
    draw(px, (4, 3, 11, 4), METAL_LIGHT)   # Lichtkante oben
    draw(px, (4, 10, 11, 11), METAL_DARK)  # Schattenkante unten
    draw(px, (5, 6, 10, 8), VISOR)         # Sehschlitz
    draw(px, (7, 6, 8, 8), METAL_DARK)     # Nasensteg
    return image


def make_chestplate():
    image = Image.new("RGBA", (16, 16), CLEAR)
    px = image.load()
    draw(px, (2, 3, 13, 13), EDGE)
    draw(px, (3, 4, 12, 12), METAL)
    draw(px, (3, 4, 12, 5), METAL_LIGHT)   # Schulterpartie
    draw(px, (3, 11, 12, 12), METAL_DARK)
    draw(px, (6, 3, 9, 5), CLEAR)          # Halsausschnitt
    draw(px, (6, 4, 9, 5), EDGE)
    draw(px, (7, 7, 8, 10), METAL_DARK)    # Mittelnaht
    return image


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, builder in (("helmet_placeholder.png", make_helmet),
                          ("chestplate_placeholder.png", make_chestplate)):
        path = os.path.join(OUT_DIR, name)
        builder().save(path)
        print(path)


if __name__ == "__main__":
    main()
