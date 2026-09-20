#!/usr/bin/env python3
"""Generates placeholder pixel-art assets for the Last Lantern main menu."""

from __future__ import annotations

import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "main_menu")
W, H = 480, 270


def save(name: str, img: Image.Image) -> None:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", path)


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def gradient_sky() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top = (11, 14, 23)
    mid = (16, 20, 33)
    bot = (23, 26, 39)
    for y in range(H):
        t = y / max(H - 1, 1)
        if t < 0.55:
            tt = t / 0.55
            c = tuple(lerp(top[i], mid[i], tt) for i in range(3))
        else:
            tt = (t - 0.55) / 0.45
            c = tuple(lerp(mid[i], bot[i], tt) for i in range(3))
        for x in range(W):
            img.putpixel((x, y), (*c, 255))
    return img


def stars() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    coords = [
        (42, 18), (88, 34), (130, 12), (176, 28), (220, 16), (280, 22), (340, 10),
        (390, 30), (430, 14), (60, 52), (150, 44), (250, 38), (320, 48), (410, 40),
        (24, 70), (112, 62), (198, 58), (288, 66), (372, 54), (452, 68),
    ]
    for x, y in coords:
        draw.rectangle((x, y, x + 1, y + 1), fill=(230, 235, 245, 210))
        if (x + y) % 3 == 0:
            draw.rectangle((x, y + 2, x + 1, y + 3), fill=(200, 210, 230, 140))
    return img


def mountains() -> Image.Image:
    img = Image.new("RGBA", (W, 80), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    col = (12, 16, 24, 255)
    pts = [(0, 80), (0, 52), (40, 34), (78, 48), (120, 22), (170, 40), (220, 18),
           (270, 36), (320, 24), (360, 42), (400, 28), (440, 44), (480, 30), (480, 80)]
    draw.polygon(pts, fill=col)
    col2 = (8, 11, 18, 255)
    pts2 = [(0, 80), (0, 62), (55, 50), (110, 58), (180, 46), (250, 56), (330, 48),
            (410, 58), (480, 50), (480, 80)]
    draw.polygon(pts2, fill=col2)
    return img


def forest_layer(height: int, dark: tuple[int, int, int], count: int) -> Image.Image:
    img = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    import random
    rng = random.Random(count * 17)
    x = -8
    while x < W + 8:
        tw = rng.randint(14, 28)
        th = rng.randint(height - 8, height + 18)
        trunk_w = max(2, tw // 6)
        tx = x + tw // 2
        draw.rectangle((tx - trunk_w, height - 8, tx + trunk_w, height), fill=(dark[0] // 2, dark[1] // 2, dark[2] // 2, 255))
        crown = [
            (x, height - 8),
            (x + tw // 2, height - th),
            (x + tw, height - 8),
        ]
        draw.polygon(crown, fill=(*dark, 255))
        x += tw - rng.randint(4, 10)
    return img


def base_hut() -> Image.Image:
    img = Image.new("RGBA", (140, 96), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # ground
    draw.rectangle((0, 78, 140, 96), fill=(18, 20, 16, 255))
    # hut body
    draw.rectangle((34, 44, 96, 78), fill=(48, 38, 28, 255))
    draw.rectangle((34, 44, 96, 48), fill=(58, 48, 34, 255))
    # roof
    draw.polygon([(28, 44), (65, 22), (102, 44)], fill=(36, 30, 24, 255))
    # door
    draw.rectangle((58, 56, 72, 78), fill=(24, 18, 14, 255))
    # barricade left
    for i in range(4):
        bx = 18 + i * 4
        draw.rectangle((bx, 58 - i, bx + 3, 78), fill=(40, 32, 24, 255))
    # barricade right
    for i in range(3):
        bx = 100 + i * 5
        draw.rectangle((bx, 60 - i, bx + 3, 78), fill=(40, 32, 24, 255))
    # crate
    draw.rectangle((104, 66, 122, 78), fill=(52, 42, 30, 255))
    draw.line((104, 72, 122, 72), fill=(42, 34, 24, 255))
    # workbench silhouette
    draw.rectangle((8, 68, 26, 78), fill=(44, 36, 28, 255))
    draw.rectangle((8, 64, 24, 68), fill=(50, 40, 30, 255))
    return img


def lantern_sprite() -> Image.Image:
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((10, 4, 13, 8), fill=(70, 58, 40, 255))
    draw.rectangle((7, 8, 16, 22), fill=(58, 46, 32, 255))
    draw.rectangle((8, 9, 15, 21), fill=(255, 184, 74, 220))
    draw.rectangle((10, 12, 13, 17), fill=(255, 220, 140, 255))
    draw.rectangle((8, 22, 15, 24), fill=(50, 40, 28, 255))
    draw.rectangle((9, 24, 14, 30), fill=(42, 34, 24, 255))
    return img


def lantern_icon() -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    small = lantern_sprite().resize((12, 16), Image.NEAREST)
    img.paste(small, (2, 0), small)
    return img


def lantern_glow() -> Image.Image:
    img = Image.new("RGBA", (96, 96), (0, 0, 0, 0))
    cx, cy = 48, 48
    for y in range(96):
        for x in range(96):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d > 48:
                continue
            t = 1.0 - d / 48.0
            a = int((t ** 1.8) * 120)
            r = int(255 * t + 200 * (1 - t))
            g = int(184 * t + 120 * (1 - t))
            b = int(74 * t + 40 * (1 - t))
            img.putpixel((x, y), (r, g, b, a))
    return img


def foreground() -> Image.Image:
    img = Image.new("RGBA", (W, 64), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 24, W, 64), fill=(8, 10, 8, 255))
    import random
    rng = random.Random(9)
    for _ in range(80):
        x = rng.randint(0, W - 1)
        h = rng.randint(2, 8)
        c = rng.choice([(22, 28, 18), (18, 24, 14), (28, 34, 20)])
        draw.rectangle((x, 24 - h, x + 1, 24), fill=(*c, 255))
    for x in range(0, W, 18):
        draw.rectangle((x + 4, 18, x + 10, 24), fill=(14, 18, 12, 255))
    return img


def fog_strip() -> Image.Image:
    img = Image.new("RGBA", (W, 64), (0, 0, 0, 0))
    for y in range(64):
        t = abs(y - 32) / 32.0
        a = int((1.0 - t) * 55)
        for x in range(W):
            img.putpixel((x, y), (180, 170, 200, a))
    return img


def cloud() -> Image.Image:
    img = Image.new("RGBA", (64, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    col = (40, 44, 58, 90)
    draw.ellipse((4, 10, 24, 22), fill=col)
    draw.ellipse((16, 6, 40, 20), fill=col)
    draw.ellipse((32, 8, 58, 22), fill=col)
    return img


def eyes() -> Image.Image:
    img = Image.new("RGBA", (12, 6), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((1, 2, 3, 4), fill=(180, 40, 50, 220))
    draw.rectangle((8, 2, 10, 4), fill=(180, 40, 50, 220))
    return img


def zombie_silhouette() -> Image.Image:
    img = Image.new("RGBA", (14, 24), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    col = (16, 12, 18, 200)
    draw.rectangle((5, 2, 9, 6), fill=col)
    draw.rectangle((4, 6, 10, 16), fill=col)
    draw.rectangle((3, 8, 4, 14), fill=col)
    draw.rectangle((10, 8, 11, 14), fill=col)
    draw.rectangle((4, 16, 6, 23), fill=col)
    draw.rectangle((8, 16, 10, 23), fill=col)
    return img


def vignette() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy = W // 2, H // 2
    max_d = ((cx ** 2 + cy ** 2) ** 0.5)
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            t = min(1.0, d / max_d)
            a = int((t ** 1.4) * 150)
            img.putpixel((x, y), (0, 0, 0, a))
    return img


def dust_particle() -> Image.Image:
    img = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.point((1, 1), fill=(255, 210, 140, 180))
    draw.point((2, 2), fill=(255, 230, 170, 140))
    return img


def main() -> None:
    save("sky_gradient.png", gradient_sky())
    save("stars.png", stars())
    save("mountains.png", mountains())
    save("forest_far.png", forest_layer(100, (14, 18, 16), 3))
    save("forest_mid.png", forest_layer(88, (10, 14, 12), 5))
    save("base_hut.png", base_hut())
    save("foreground.png", foreground())
    save("lantern.png", lantern_sprite())
    save("lantern_icon.png", lantern_icon())
    save("lantern_glow.png", lantern_glow())
    save("fog_strip.png", fog_strip())
    save("cloud.png", cloud())
    save("eyes.png", eyes())
    save("zombie_sil.png", zombie_silhouette())
    save("vignette.png", vignette())
    save("dust.png", dust_particle())
    print("Done.")


if __name__ == "__main__":
    main()
