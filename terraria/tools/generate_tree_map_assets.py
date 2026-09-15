"""Generate tree tiles, seed icons, map marker and simple SFX. Own pixel-art, no Terraria assets."""
from __future__ import annotations

import math
import os
import struct
import wave
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ATLAS_PATH = ROOT / "assets" / "world" / "tiles" / "terrain_atlas.png"
TILES = ROOT / "assets" / "world" / "tiles"
SEEDS = ROOT / "assets" / "items" / "seeds"
UI = ROOT / "assets" / "ui"
SFX = ROOT / "audio" / "sfx"

for folder in (TILES, SEEDS, UI, SFX):
    folder.mkdir(parents=True, exist_ok=True)


def rgba(hex_color: str) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 6:
        hex_color += "ff"
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4, 6))  # type: ignore[return-value]


def fill(img: Image.Image, color: str) -> None:
    img.paste(rgba(color), (0, 0, img.width, img.height))


def px(img: Image.Image, x: int, y: int, color: str) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgba(color))


def rect(img: Image.Image, x: int, y: int, w: int, h: int, color: str) -> None:
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(img, xx, yy, color)


def dither_fill(img: Image.Image, color_a: str, color_b: str, color_edge: str) -> None:
    fill(img, color_a)
    for y in range(16):
        for x in range(16):
            if x == 0 or y == 0 or x == 15 or y == 15:
                px(img, x, y, color_edge)
            elif (x + y * 3) % 5 == 0:
                px(img, x, y, color_b)


def draw_oak_wood(img: Image.Image) -> None:
    fill(img, "#6b3e1a")
    for y in range(16):
        for x in range(16):
            if x in (0, 15) or y in (0, 15):
                px(img, x, y, "#4a2810")
            elif x in (3, 8, 12):
                px(img, x, y, "#5a3314")
            elif x in (5, 10) and y % 4 == 2:
                px(img, x, y, "#8a5428")
            elif (x + y) % 7 == 0:
                px(img, x, y, "#7a4a22")


def draw_birch_wood(img: Image.Image) -> None:
    fill(img, "#e8e0c8")
    for y in range(16):
        for x in range(16):
            if x in (0, 15) or y in (0, 15):
                px(img, x, y, "#c4b898")
            elif x in (4, 11):
                px(img, x, y, "#d6cdb0")
            elif y in (3, 8, 13) and x in range(2, 7):
                px(img, x, y, "#2a2a28")
            elif y in (5, 11) and x in range(9, 14):
                px(img, x, y, "#3a3830")
            elif (x + y * 2) % 9 == 0:
                px(img, x, y, "#f4eed8")


def draw_pine_wood(img: Image.Image) -> None:
    fill(img, "#5a3418")
    for y in range(16):
        for x in range(16):
            if x in (0, 15) or y in (0, 15):
                px(img, x, y, "#3a2010")
            elif x in (2, 7, 13):
                px(img, x, y, "#4a2814")
            elif x in (5, 10) and y % 3 == 1:
                px(img, x, y, "#6e4020")
            elif (x * 2 + y) % 6 == 0:
                px(img, x, y, "#482414")


def draw_oak_leaves(img: Image.Image) -> None:
    fill(img, "#00000000")
    clusters = [
        (1, 1, "#3d8c2a"), (2, 1, "#2f7a20"), (3, 2, "#4aa032"), (4, 1, "#2f7a20"),
        (5, 2, "#3d8c2a"), (6, 1, "#246018"), (7, 2, "#3d8c2a"), (8, 1, "#4aa032"),
        (9, 2, "#2f7a20"), (10, 1, "#3d8c2a"), (11, 2, "#246018"), (12, 1, "#4aa032"),
        (13, 2, "#2f7a20"), (14, 1, "#3d8c2a"),
        (1, 4, "#2f7a20"), (2, 5, "#3d8c2a"), (3, 4, "#4aa032"), (4, 5, "#246018"),
        (5, 4, "#3d8c2a"), (6, 5, "#2f7a20"), (7, 4, "#4aa032"), (8, 5, "#3d8c2a"),
        (9, 4, "#246018"), (10, 5, "#4aa032"), (11, 4, "#2f7a20"), (12, 5, "#3d8c2a"),
        (13, 4, "#4aa032"), (14, 5, "#2f7a20"),
        (2, 7, "#3d8c2a"), (3, 8, "#246018"), (4, 7, "#2f7a20"), (5, 8, "#4aa032"),
        (6, 7, "#3d8c2a"), (7, 8, "#2f7a20"), (8, 7, "#246018"), (9, 8, "#3d8c2a"),
        (10, 7, "#4aa032"), (11, 8, "#2f7a20"), (12, 7, "#3d8c2a"), (13, 8, "#246018"),
        (1, 10, "#2f7a20"), (2, 11, "#3d8c2a"), (3, 10, "#4aa032"), (4, 11, "#2f7a20"),
        (5, 10, "#246018"), (6, 11, "#3d8c2a"), (7, 10, "#4aa032"), (8, 11, "#2f7a20"),
        (9, 10, "#3d8c2a"), (10, 11, "#246018"), (11, 10, "#4aa032"), (12, 11, "#2f7a20"),
        (13, 10, "#3d8c2a"), (14, 11, "#4aa032"),
        (3, 13, "#2f7a20"), (4, 14, "#3d8c2a"), (5, 13, "#246018"), (6, 14, "#4aa032"),
        (7, 13, "#2f7a20"), (8, 14, "#3d8c2a"), (9, 13, "#4aa032"), (10, 14, "#2f7a20"),
        (11, 13, "#3d8c2a"), (12, 14, "#246018"),
    ]
    for x, y, color in clusters:
        px(img, x, y, color)
        if (x + y) % 3 != 0:
            px(img, x, y + 1, color)


def draw_birch_leaves(img: Image.Image) -> None:
    fill(img, "#00000000")
    colors = ["#8fbf3a", "#b4d44a", "#6e9a28", "#c8e060"]
    for y in range(1, 15):
        for x in range(1, 15):
            if abs(x - 8) + abs(y - 8) > 8:
                continue
            if (x * 5 + y * 7) % 4 == 0:
                continue
            px(img, x, y, colors[(x + y) % 4])


def draw_pine_leaves(img: Image.Image) -> None:
    fill(img, "#00000000")
    colors = ["#1d5a32", "#164828", "#247844", "#0f3a22"]
    for y in range(16):
        width = max(1, 7 - abs(y - 8) // 2)
        for x in range(8 - width, 8 + width + 1):
            if (x + y) % 5 == 0:
                continue
            px(img, x, y, colors[(x + y) % 4])


def draw_oak_sapling(img: Image.Image) -> None:
    fill(img, "#00000000")
    stem = "#6b3e1a"
    leaf = "#3d8c2a"
    leaf2 = "#4aa032"
    for y in range(9, 16):
        px(img, 7, y, stem)
        px(img, 8, y, "#5a3314")
    rect(img, 5, 4, 6, 5, leaf)
    px(img, 6, 3, leaf2)
    px(img, 7, 2, leaf)
    px(img, 8, 3, leaf2)
    px(img, 9, 4, leaf)
    px(img, 4, 6, leaf2)
    px(img, 10, 6, leaf)


def draw_birch_sapling(img: Image.Image) -> None:
    fill(img, "#00000000")
    for y in range(8, 16):
        px(img, 7, y, "#e8e0c8")
        px(img, 8, y, "#d6cdb0")
    px(img, 7, 11, "#2a2a28")
    rect(img, 5, 3, 6, 5, "#8fbf3a")
    px(img, 7, 2, "#c8e060")
    px(img, 8, 2, "#b4d44a")
    px(img, 4, 5, "#6e9a28")
    px(img, 11, 5, "#b4d44a")


def draw_pine_sapling(img: Image.Image) -> None:
    fill(img, "#00000000")
    for y in range(10, 16):
        px(img, 7, y, "#5a3418")
        px(img, 8, y, "#4a2814")
    for y, w in ((2, 1), (3, 2), (4, 2), (5, 3), (6, 3), (7, 4), (8, 4), (9, 3)):
        for x in range(8 - w, 8 + w):
            px(img, x, y, "#1d5a32" if (x + y) % 2 == 0 else "#247844")


def draw_oak_seed(img: Image.Image) -> None:
    fill(img, "#00000000")
    rect(img, 5, 6, 6, 7, "#8a5428")
    rect(img, 4, 4, 8, 3, "#5a3314")
    px(img, 7, 3, "#3a2010")
    px(img, 8, 2, "#3a2010")
    px(img, 6, 8, "#6b3e1a")
    px(img, 9, 9, "#c48a48")


def draw_birch_seed(img: Image.Image) -> None:
    fill(img, "#00000000")
    rect(img, 6, 7, 4, 5, "#d8c878")
    px(img, 7, 6, "#c4b050")
    px(img, 8, 6, "#c4b050")
    for x, y in ((3, 5), (2, 6), (4, 4), (11, 5), (12, 6), (10, 4)):
        px(img, x, y, "#e8e8dc")
    px(img, 7, 9, "#8a7a30")


def draw_pine_seed(img: Image.Image) -> None:
    fill(img, "#00000000")
    for y, w in ((4, 2), (5, 3), (6, 3), (7, 4), (8, 3), (9, 3), (10, 2), (11, 2)):
        for x in range(8 - w, 8 + w):
            px(img, x, y, "#6a4020" if (x + y) % 2 else "#4a2c14")
    px(img, 7, 3, "#3a2010")
    px(img, 8, 3, "#3a2010")


def draw_marker(img: Image.Image) -> None:
    fill(img, "#00000000")
    # Bright downward arrow / pin so it stays readable on any terrain.
    for y, row in enumerate(
        [
            "001111100",
            "011111110",
            "111111111",
            "111111111",
            "111111111",
            "011111110",
            "001111100",
            "000111000",
            "000010000",
        ]
    ):
        for x, ch in enumerate(row):
            if ch == "1":
                color = "#fff4a0" if y < 6 else "#ffd24a"
                px(img, x + 3, y + 2, color)
    px(img, 7, 5, "#1a1408")
    px(img, 6, 5, "#fffaf0")
    px(img, 8, 5, "#fffaf0")


def write_wav(path: Path, samples: list[float], rate: int = 22050) -> None:
    with wave.open(str(path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        frames = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
        wav.writeframes(frames)


def make_wood_hit() -> list[float]:
    rate = 22050
    n = int(rate * 0.12)
    samples = []
    for i in range(n):
        t = i / rate
        env = math.exp(-t * 28.0)
        click = math.sin(2 * math.pi * 180 * t) * 0.45
        noise = ((i * 1103515245 + 12345) % 32768 / 32768.0 - 0.5) * 0.5
        thump = math.sin(2 * math.pi * 90 * t) * 0.35
        samples.append((click + noise + thump) * env)
    return samples


def make_tree_fall() -> list[float]:
    rate = 22050
    n = int(rate * 1.1)
    samples = []
    for i in range(n):
        t = i / rate
        env = min(1.0, t * 3.0) * math.exp(-max(0.0, t - 0.15) * 2.4)
        rumble = math.sin(2 * math.pi * (70 + t * 40) * t) * 0.4
        creak = math.sin(2 * math.pi * (220 - t * 80) * t) * 0.25
        noise = ((i * 214013 + 2531011) % 32768 / 32768.0 - 0.5) * (0.2 + t * 0.3)
        crash = 0.0
        if t > 0.85:
            crash = math.exp(-(t - 0.85) * 18.0) * (((i * 1103515245) % 32768 / 32768.0 - 0.5) * 0.8)
        samples.append((rumble + creak + noise + crash) * env * 0.9)
    return samples


def save_tile(name: str, drawer) -> Image.Image:
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    drawer(img)
    img.save(TILES / f"{name}.png")
    return img


def main() -> None:
    original = Image.open(ATLAS_PATH).convert("RGBA")
    atlas = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    atlas.paste(original, (0, 0))

    tiles = [
        ((0, 2), "oak_wood", draw_oak_wood),
        ((1, 2), "birch_wood", draw_birch_wood),
        ((2, 2), "pine_wood", draw_pine_wood),
        ((3, 2), "oak_leaves", draw_oak_leaves),
        ((4, 2), "birch_leaves", draw_birch_leaves),
        ((5, 2), "pine_leaves", draw_pine_leaves),
        ((6, 2), "oak_sapling", draw_oak_sapling),
        ((7, 2), "birch_sapling", draw_birch_sapling),
        ((0, 3), "pine_sapling", draw_pine_sapling),
    ]
    for (col, row), name, drawer in tiles:
        tile = save_tile(name, drawer)
        atlas.paste(tile, (col * 16, row * 16))

    atlas.save(ATLAS_PATH)

    oak_seed = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_oak_seed(oak_seed)
    oak_seed.save(SEEDS / "oak_seed.png")
    birch_seed = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_birch_seed(birch_seed)
    birch_seed.save(SEEDS / "birch_seed.png")
    pine_seed = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_pine_seed(pine_seed)
    pine_seed.save(SEEDS / "pine_seed.png")

    marker = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    draw_marker(marker)
    marker.save(UI / "map_player_marker.png")

    write_wav(SFX / "wood_hit.wav", make_wood_hit())
    write_wav(SFX / "tree_fall.wav", make_tree_fall())
    print("assets written")


if __name__ == "__main__":
    main()
