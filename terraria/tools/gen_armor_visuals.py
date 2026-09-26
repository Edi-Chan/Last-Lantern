#!/usr/bin/env python3
"""Unique Last Lantern armor overlays + inventory icons.

Frame contract matches PlayerAnimationContract / gen_player_sprites.py:
40x56 cells, 6 columns, one animation row. Armor is overlay-only.
Does not rewrite body, hair, shirt, pants, or shoes sheets.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_player_sprites import (  # noqa: E402
    ANIMS,
    H,
    HAIR_RGB,
    HEAD_SKIN_RGB,
    ICONS,
    MAX_COLS,
    PANTS_RGB,
    RES,
    ROOT,
    SHEETS,
    SHIRT_RGB,
    W,
    blank,
    blit_opaque,
    collect_pts,
    dilate_pts,
    draw_body,
    draw_hair_back,
    draw_hair_front,
    draw_pants,
    draw_shirt,
    draw_shoes,
    finish_layer,
    leg_geom,
    outline_from,
    pose,
    px,
    rect,
    rgb,
    save,
    write_spriteframes,
)

MATERIALS = [
    "wood",
    "copper",
    "tin",
    "ferrite",
    "aurel",
    "cobalt",
    "veyrite",
    "cryonite",
    "ignitium",
    "voidium",
    "astralith",
]

PIECES = ("helmet", "chest", "legs")
ITEM_DIR = ROOT / "resources" / "items" / "equipment"


def C(r, g, b, a=255):
    return (r, g, b, a)


PALETTES = {
    "wood": {
        "mid": C(154, 104, 52),
        "dark": C(98, 62, 28),
        "deep": C(62, 38, 16),
        "shine": C(198, 148, 88),
        "accent": C(86, 52, 28),
        "joint": C(118, 78, 44),
        "glow": C(204, 158, 96),
        "boot": C(72, 44, 24),
        "boot_s": C(108, 72, 40),
        "outline": C(46, 26, 12),
        "visor": C(40, 26, 16),
        "detail": C(168, 118, 62),
    },
    "copper": {
        "mid": C(188, 108, 52),
        "dark": C(124, 62, 28),
        "deep": C(78, 38, 16),
        "shine": C(228, 158, 92),
        "accent": C(156, 92, 44),
        "joint": C(96, 56, 32),
        "glow": C(236, 176, 110),
        "boot": C(78, 42, 24),
        "boot_s": C(118, 68, 38),
        "outline": C(52, 28, 14),
        "visor": C(28, 18, 14),
        "detail": C(210, 132, 68),
    },
    "tin": {
        "mid": C(186, 196, 204),
        "dark": C(128, 138, 148),
        "deep": C(78, 86, 96),
        "shine": C(230, 236, 240),
        "accent": C(112, 78, 52),
        "joint": C(96, 68, 46),
        "glow": C(214, 222, 228),
        "boot": C(70, 52, 40),
        "boot_s": C(108, 82, 62),
        "outline": C(48, 54, 62),
        "visor": C(36, 32, 30),
        "detail": C(168, 176, 186),
    },
    "ferrite": {
        "mid": C(78, 82, 88),
        "dark": C(48, 50, 56),
        "deep": C(28, 30, 34),
        "shine": C(148, 152, 158),
        "accent": C(92, 70, 48),
        "joint": C(58, 48, 40),
        "glow": C(168, 170, 176),
        "boot": C(36, 32, 30),
        "boot_s": C(64, 58, 54),
        "outline": C(16, 16, 18),
        "visor": C(12, 12, 14),
        "detail": C(104, 108, 114),
    },
    "aurel": {
        "mid": C(168, 128, 68),
        "dark": C(108, 74, 34),
        "deep": C(64, 42, 18),
        "shine": C(220, 184, 112),
        "accent": C(196, 152, 64),
        "joint": C(86, 56, 28),
        "glow": C(236, 204, 128),
        "boot": C(58, 38, 20),
        "boot_s": C(92, 64, 32),
        "outline": C(42, 26, 12),
        "visor": C(28, 18, 10),
        "detail": C(188, 148, 78),
    },
    "cobalt": {
        "mid": C(52, 92, 148),
        "dark": C(28, 54, 96),
        "deep": C(16, 32, 62),
        "shine": C(110, 162, 214),
        "accent": C(156, 210, 230),
        "joint": C(64, 52, 40),
        "glow": C(140, 196, 228),
        "boot": C(28, 28, 36),
        "boot_s": C(48, 56, 72),
        "outline": C(10, 18, 36),
        "visor": C(12, 16, 24),
        "detail": C(72, 118, 176),
    },
    "veyrite": {
        "mid": C(46, 62, 54),
        "dark": C(28, 40, 34),
        "deep": C(16, 24, 20),
        "shine": C(78, 108, 88),
        "accent": C(72, 168, 108),
        "joint": C(40, 52, 44),
        "glow": C(96, 196, 132),
        "boot": C(22, 28, 24),
        "boot_s": C(40, 56, 44),
        "outline": C(8, 14, 12),
        "visor": C(10, 22, 16),
        "detail": C(58, 86, 70),
    },
    "cryonite": {
        "mid": C(148, 186, 204),
        "dark": C(78, 118, 142),
        "deep": C(40, 68, 88),
        "shine": C(214, 236, 246),
        "accent": C(188, 230, 246),
        "joint": C(96, 128, 148),
        "glow": C(230, 246, 255),
        "boot": C(48, 68, 86),
        "boot_s": C(92, 132, 156),
        "outline": C(28, 46, 62),
        "visor": C(24, 40, 54),
        "detail": C(168, 208, 224),
    },
    "ignitium": {
        "mid": C(42, 28, 24),
        "dark": C(24, 16, 14),
        "deep": C(12, 8, 8),
        "shine": C(78, 48, 38),
        "accent": C(220, 86, 28),
        "joint": C(48, 28, 20),
        "glow": C(255, 148, 48),
        "boot": C(18, 12, 10),
        "boot_s": C(52, 28, 20),
        "outline": C(6, 4, 4),
        "visor": C(80, 24, 10),
        "detail": C(62, 36, 28),
    },
    "voidium": {
        "mid": C(28, 18, 36),
        "dark": C(16, 10, 22),
        "deep": C(8, 6, 12),
        "shine": C(52, 36, 68),
        "accent": C(92, 42, 148),
        "joint": C(36, 22, 48),
        "glow": C(148, 78, 210),
        "boot": C(10, 8, 14),
        "boot_s": C(32, 20, 44),
        "outline": C(4, 2, 8),
        "visor": C(18, 8, 28),
        "detail": C(44, 28, 58),
    },
    "astralith": {
        "mid": C(48, 44, 78),
        "dark": C(28, 26, 48),
        "deep": C(16, 14, 30),
        "shine": C(98, 96, 142),
        "accent": C(196, 210, 255),
        "joint": C(64, 56, 92),
        "glow": C(236, 242, 255),
        "boot": C(18, 16, 32),
        "boot_s": C(52, 48, 82),
        "outline": C(10, 8, 20),
        "visor": C(20, 18, 36),
        "detail": C(72, 68, 112),
    },
}


def shade_pts(fill, pts, pal, cx, grain="metal"):
    mid, dark, shine = pal["mid"], pal["dark"], pal["shine"]
    for x, y in pts:
        if fill.getpixel((x, y))[3] > 0:
            continue
        if x < cx - 2:
            col = dark
        elif x > cx + 3 and (x * 3 + y) % 9 == 0:
            col = shine
        else:
            col = mid
        if grain == "wood" and (y + x // 2) % 4 == 0:
            col = pal["dark"] if col != shine else pal["shine"]
        elif grain == "organic" and (x + y * 2) % 6 == 0:
            col = pal["detail"]
        elif grain == "ice" and (x + y) % 8 == 0:
            col = pal["shine"]
        elif grain == "void" and (x * y) % 11 == 0:
            col = pal["deep"]
        fill.putpixel((x, y), col)


def put(fill, x, y, c):
    px(fill, x, y, c)


def coverage_helmet(p, composed):
    hy = p["head_y"]
    torso_top = p["torso_top"]

    def is_head(_x, y, pix):
        tone = rgb(pix)
        if tone in HAIR_RGB:
            return True
        if y >= torso_top:
            return False
        return tone in HEAD_SKIN_RGB and y <= hy + 7

    return dilate_pts(collect_pts(composed, is_head), 1)


def coverage_chest(p, composed):
    bot = p["torso_bot"]

    def is_shirt(_x, y, pix):
        return rgb(pix) in SHIRT_RGB and y <= bot + 1

    return dilate_pts(collect_pts(composed, is_shirt), 1)


def coverage_legs(p, composed):
    hip = p["torso_bot"]

    def is_legs(_x, y, pix):
        return rgb(pix) in PANTS_RGB and y >= hip - 2

    return dilate_pts(collect_pts(composed, is_legs), 1)


def extra_rect(pts, x0, y0, x1, y1):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            if 0 <= x < W and 0 <= y < H:
                pts.add((x, y))


def draw_helmet(mat: str, p, composed):
    pal = PALETTES[mat]
    fill = blank()
    cx, hy = p["cx"], p["head_y"]
    pts = set(coverage_helmet(p, composed))
    extra_rect(pts, cx - 6, hy - 8, cx + 5, hy + 2)

    if mat == "ferrite":
        extra_rect(pts, cx - 7, hy - 9, cx + 6, hy + 8)
        extra_rect(pts, cx - 5, hy + 6, cx + 5, hy + 10)
    elif mat == "wood":
        extra_rect(pts, cx - 7, hy - 7, cx + 6, hy + 1)
        extra_rect(pts, cx - 6, hy - 9, cx + 4, hy - 4)
    elif mat == "tin":
        extra_rect(pts, cx - 6, hy - 7, cx + 5, hy + 1)
    elif mat == "aurel":
        extra_rect(pts, cx, hy - 11, cx + 2, hy - 7)
        extra_rect(pts, cx - 5, hy - 8, cx + 6, hy + 3)
    elif mat == "cryonite":
        extra_rect(pts, cx - 1, hy - 12, cx + 1, hy - 8)
        extra_rect(pts, cx + 3, hy - 11, cx + 4, hy - 8)
        extra_rect(pts, cx - 4, hy - 10, cx - 3, hy - 8)
    elif mat == "voidium":
        extra_rect(pts, cx - 8, hy - 10, cx - 5, hy - 4)
        extra_rect(pts, cx + 5, hy - 9, cx + 7, hy - 2)
    elif mat == "astralith":
        extra_rect(pts, cx - 2, hy - 11, cx - 1, hy - 8)
        extra_rect(pts, cx + 1, hy - 12, cx + 2, hy - 8)
        extra_rect(pts, cx + 4, hy - 10, cx + 5, hy - 8)
    elif mat == "ignitium":
        extra_rect(pts, cx - 7, hy - 8, cx + 6, hy + 4)
        extra_rect(pts, cx - 8, hy - 4, cx - 6, hy + 1)
        extra_rect(pts, cx + 6, hy - 5, cx + 8, hy)
    elif mat == "veyrite":
        extra_rect(pts, cx - 7, hy - 8, cx + 5, hy + 4)
        extra_rect(pts, cx - 3, hy - 10, cx + 1, hy - 7)
    elif mat == "cobalt":
        extra_rect(pts, cx - 6, hy - 9, cx + 6, hy + 3)
        extra_rect(pts, cx - 2, hy - 10, cx + 4, hy - 8)
    elif mat == "copper":
        extra_rect(pts, cx - 6, hy - 8, cx + 6, hy + 5)

    grain = {
        "wood": "wood",
        "veyrite": "organic",
        "cryonite": "ice",
        "voidium": "void",
        "ignitium": "void",
        "astralith": "ice",
    }.get(mat, "metal")
    shade_pts(fill, pts, pal, cx, grain)

    if mat == "wood":
        rect(fill, cx - 6, hy - 8, cx + 4, hy - 5, pal["shine"])
        rect(fill, cx - 6, hy - 4, cx + 5, hy - 2, pal["mid"])
        rect(fill, cx - 5, hy - 1, cx + 4, hy + 1, pal["dark"])
        for x in range(cx - 5, cx + 5, 3):
            put(fill, x, hy - 6, pal["accent"])
        rect(fill, cx - 1, hy + 6, cx + 4, hy + 8, pal["accent"])
        put(fill, cx - 4, hy + 2, pal["accent"])
        put(fill, cx + 5, hy + 2, pal["accent"])
    elif mat == "copper":
        rect(fill, cx - 5, hy - 8, cx + 5, hy - 3, pal["shine"])
        rect(fill, cx + 3, hy - 1, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 6, hy, pal["deep"])
        for x in (cx - 4, cx + 3):
            put(fill, x, hy - 6, pal["accent"])
            put(fill, x, hy + 3, pal["accent"])
        rect(fill, cx - 2, hy + 6, cx + 4, hy + 8, pal["dark"])
    elif mat == "tin":
        rect(fill, cx - 6, hy - 7, cx + 5, hy - 4, pal["shine"])
        rect(fill, cx + 4, hy - 1, cx + 8, hy + 2, pal["visor"])
        rect(fill, cx - 3, hy + 5, cx + 3, hy + 7, pal["joint"])
        put(fill, cx - 5, hy - 5, pal["joint"])
        put(fill, cx + 4, hy - 5, pal["joint"])
    elif mat == "ferrite":
        rect(fill, cx - 6, hy - 9, cx + 5, hy - 2, pal["dark"])
        rect(fill, cx - 4, hy - 8, cx + 3, hy - 4, pal["mid"])
        rect(fill, cx + 2, hy, cx + 7, hy + 2, pal["visor"])
        rect(fill, cx + 3, hy + 1, cx + 6, hy + 1, pal["deep"])
        rect(fill, cx - 4, hy + 7, cx + 5, hy + 10, pal["deep"])
        put(fill, cx - 6, hy - 2, pal["shine"])
    elif mat == "aurel":
        rect(fill, cx, hy - 11, cx + 2, hy - 8, pal["accent"])
        put(fill, cx + 1, hy - 12, pal["shine"])
        rect(fill, cx - 5, hy - 8, cx + 6, hy - 3, pal["shine"])
        rect(fill, cx + 4, hy - 1, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 5, hy, pal["accent"])
        rect(fill, cx - 1, hy + 6, cx + 4, hy + 8, pal["accent"])
    elif mat == "cobalt":
        rect(fill, cx - 5, hy - 9, cx + 6, hy - 5, pal["shine"])
        rect(fill, cx - 2, hy - 10, cx + 3, hy - 9, pal["accent"])
        put(fill, cx + 1, hy - 10, pal["glow"])
        rect(fill, cx + 3, hy - 1, cx + 8, hy + 2, pal["visor"])
        rect(fill, cx - 3, hy + 6, cx + 4, hy + 8, pal["dark"])
    elif mat == "veyrite":
        rect(fill, cx - 4, hy - 9, cx + 3, hy - 4, pal["mid"])
        put(fill, cx - 1, hy - 10, pal["glow"])
        put(fill, cx, hy - 9, pal["accent"])
        rect(fill, cx + 3, hy, cx + 7, hy + 3, pal["visor"])
        put(fill, cx + 5, hy + 1, pal["glow"])
        put(fill, cx - 3, hy + 3, pal["glow"])
        put(fill, cx + 2, hy + 6, pal["accent"])
    elif mat == "cryonite":
        put(fill, cx, hy - 12, pal["glow"])
        put(fill, cx + 1, hy - 11, pal["accent"])
        put(fill, cx - 1, hy - 11, pal["shine"])
        put(fill, cx + 4, hy - 11, pal["glow"])
        put(fill, cx - 4, hy - 10, pal["accent"])
        rect(fill, cx - 5, hy - 8, cx + 5, hy - 3, pal["shine"])
        rect(fill, cx + 3, hy, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 6, hy + 1, pal["glow"])
    elif mat == "ignitium":
        rect(fill, cx - 6, hy - 8, cx + 5, hy - 2, pal["dark"])
        put(fill, cx - 2, hy - 6, pal["accent"])
        put(fill, cx, hy - 5, pal["glow"])
        put(fill, cx + 1, hy - 4, pal["accent"])
        rect(fill, cx + 2, hy, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 5, hy + 1, pal["glow"])
        put(fill, cx - 7, hy - 2, pal["accent"])
        put(fill, cx + 7, hy - 3, pal["glow"])
    elif mat == "voidium":
        rect(fill, cx - 6, hy - 8, cx + 5, hy - 2, pal["dark"])
        extra_rect(set(), 0, 0, 0, 0)
        put(fill, cx - 7, hy - 8, pal["accent"])
        put(fill, cx - 8, hy - 6, pal["glow"])
        put(fill, cx + 6, hy - 7, pal["deep"])
        rect(fill, cx + 3, hy, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 5, hy + 1, pal["glow"])
        put(fill, cx + 6, hy, pal["accent"])
        put(fill, cx - 2, hy + 3, pal["accent"])
    else:  # astralith
        put(fill, cx - 2, hy - 11, pal["accent"])
        put(fill, cx + 1, hy - 12, pal["glow"])
        put(fill, cx + 2, hy - 11, pal["accent"])
        put(fill, cx + 5, hy - 10, pal["shine"])
        rect(fill, cx - 5, hy - 8, cx + 6, hy - 3, pal["shine"])
        rect(fill, cx + 3, hy - 1, cx + 8, hy + 2, pal["visor"])
        put(fill, cx + 1, hy - 6, pal["glow"])
        put(fill, cx - 1, hy - 5, pal["accent"])
        rect(fill, cx - 2, hy + 6, cx + 4, hy + 8, pal["accent"])

    return finish_layer(fill, pal["outline"])


def draw_chest(mat: str, p, composed):
    pal = PALETTES[mat]
    fill = blank()
    cx = p["cx"]
    top, bot = p["torso_top"], p["torso_bot"]
    pts = set(coverage_chest(p, composed))
    fx, fy = p["arm_front"]
    far_x = cx + 4 + fx
    far_y0 = top + 1 + fy
    ax, ay = p["arm_back"]
    arm_x = cx - 6 + ax
    arm_y0 = top + 2 + ay
    extra_rect(pts, far_x - 1, far_y0 - 1, far_x + 3, far_y0 + 7)
    extra_rect(pts, arm_x, arm_y0, arm_x + 3, arm_y0 + 7)
    extra_rect(pts, cx - 5, top - 1, cx + 5, bot + 1)

    if mat == "ferrite":
        extra_rect(pts, cx - 7, top - 1, cx + 7, top + 6)
        extra_rect(pts, cx - 6, top + 6, cx + 6, bot + 2)
    elif mat == "tin":
        extra_rect(pts, cx - 4, top, cx + 4, bot)
    elif mat == "aurel":
        extra_rect(pts, cx - 3, bot - 2, cx + 3, bot + 1)
        extra_rect(pts, cx - 5, top, cx + 5, top + 8)
    elif mat == "wood":
        extra_rect(pts, cx - 6, top, cx + 6, bot + 1)
    elif mat == "ignitium":
        extra_rect(pts, cx - 6, top - 1, cx + 6, bot + 1)
    elif mat == "voidium":
        extra_rect(pts, cx - 6, top, cx + 6, bot + 1)
    elif mat == "astralith":
        extra_rect(pts, cx - 6, top - 1, cx + 6, bot + 1)

    grain = {
        "wood": "wood",
        "veyrite": "organic",
        "cryonite": "ice",
        "voidium": "void",
        "ignitium": "void",
    }.get(mat, "metal")
    shade_pts(fill, pts, pal, cx, grain)

    if mat == "wood":
        rect(fill, cx - 5, top, cx + 5, top + 4, pal["shine"])
        rect(fill, cx - 5, top + 5, cx + 5, top + 9, pal["mid"])
        rect(fill, cx - 5, top + 10, cx + 5, bot, pal["dark"])
        rect(fill, cx - 1, top + 2, cx, bot - 1, pal["accent"])
        put(fill, cx - 4, top + 3, pal["accent"])
        put(fill, cx + 4, top + 3, pal["accent"])
        put(fill, cx - 4, top + 8, pal["accent"])
        put(fill, cx + 4, top + 8, pal["accent"])
        rect(fill, cx - 6, top + 1, cx - 4, top + 4, pal["dark"])
        rect(fill, cx + 4, top + 1, cx + 6, top + 4, pal["mid"])
    elif mat == "copper":
        rect(fill, cx - 3, top + 2, cx + 3, top + 5, pal["shine"])
        put(fill, cx - 4, top + 4, pal["accent"])
        put(fill, cx + 4, top + 4, pal["accent"])
        put(fill, cx - 4, top + 8, pal["accent"])
        put(fill, cx + 4, top + 8, pal["accent"])
        rect(fill, cx - 4, bot - 1, cx + 4, bot + 1, pal["dark"])
        rect(fill, cx - 6, top + 1, cx - 4, top + 5, pal["dark"])
        rect(fill, cx + 4, top + 1, cx + 6, top + 5, pal["shine"])
    elif mat == "tin":
        rect(fill, cx - 3, top + 1, cx + 3, top + 3, pal["shine"])
        rect(fill, cx - 3, top + 6, cx + 3, top + 7, pal["joint"])
        rect(fill, cx - 3, top + 11, cx + 3, top + 12, pal["joint"])
        rect(fill, cx - 5, top + 2, cx - 3, top + 6, pal["joint"])
        rect(fill, cx + 3, top + 2, cx + 5, top + 6, pal["joint"])
        rect(fill, cx - 3, bot, cx + 3, bot + 1, pal["accent"])
    elif mat == "ferrite":
        rect(fill, cx - 7, top, cx - 4, top + 6, pal["dark"])
        rect(fill, cx + 4, top, cx + 7, top + 6, pal["mid"])
        rect(fill, cx - 3, top + 2, cx + 3, bot - 1, pal["mid"])
        rect(fill, cx - 2, top + 3, cx + 2, top + 8, pal["shine"])
        rect(fill, cx - 5, bot, cx + 5, bot + 2, pal["deep"])
        put(fill, cx, top + 10, pal["accent"])
    elif mat == "aurel":
        rect(fill, cx - 2, top + 2, cx + 2, top + 6, pal["shine"])
        put(fill, cx, top + 7, pal["accent"])
        put(fill, cx - 1, top + 8, pal["accent"])
        put(fill, cx + 1, top + 8, pal["accent"])
        put(fill, cx, top + 9, pal["deep"])
        rect(fill, cx - 5, top + 1, cx - 3, top + 4, pal["accent"])
        rect(fill, cx + 3, top + 1, cx + 5, top + 4, pal["shine"])
        rect(fill, cx - 3, bot - 1, cx + 3, bot + 1, pal["accent"])
    elif mat == "cobalt":
        rect(fill, cx - 4, top + 1, cx + 4, top + 6, pal["mid"])
        rect(fill, cx - 2, top + 2, cx + 2, top + 4, pal["shine"])
        put(fill, cx, top + 3, pal["accent"])
        rect(fill, cx - 5, top, cx - 3, top + 5, pal["dark"])
        rect(fill, cx + 3, top, cx + 5, top + 5, pal["shine"])
        rect(fill, cx - 4, bot - 2, cx + 4, bot + 1, pal["joint"])
        put(fill, cx - 3, bot - 1, pal["accent"])
        put(fill, cx + 3, bot - 1, pal["accent"])
    elif mat == "veyrite":
        rect(fill, cx - 2, top + 3, cx + 2, top + 8, pal["dark"])
        put(fill, cx, top + 5, pal["glow"])
        put(fill, cx - 1, top + 6, pal["accent"])
        put(fill, cx + 1, top + 6, pal["accent"])
        put(fill, cx, top + 9, pal["glow"])
        put(fill, cx - 4, top + 8, pal["accent"])
        put(fill, cx + 4, top + 10, pal["glow"])
        rect(fill, cx - 4, bot, cx + 4, bot + 1, pal["dark"])
    elif mat == "cryonite":
        rect(fill, cx - 2, top + 3, cx + 2, top + 7, pal["shine"])
        put(fill, cx, top + 4, pal["glow"])
        put(fill, cx - 1, top + 5, pal["accent"])
        put(fill, cx + 1, top + 5, pal["accent"])
        put(fill, cx, top + 2, pal["glow"])
        rect(fill, cx - 5, top + 1, cx - 3, top + 4, pal["accent"])
        rect(fill, cx + 4, top + 1, cx + 6, top + 3, pal["glow"])
        rect(fill, cx - 4, bot, cx + 4, bot + 1, pal["dark"])
    elif mat == "ignitium":
        rect(fill, cx - 2, top + 3, cx + 2, top + 8, pal["deep"])
        put(fill, cx, top + 5, pal["glow"])
        put(fill, cx, top + 6, pal["accent"])
        put(fill, cx - 1, top + 7, pal["accent"])
        put(fill, cx + 1, top + 4, pal["glow"])
        put(fill, cx - 4, top + 6, pal["accent"])
        put(fill, cx + 4, top + 9, pal["glow"])
        put(fill, cx + 3, top + 11, pal["accent"])
        rect(fill, cx - 5, bot, cx + 5, bot + 1, pal["deep"])
    elif mat == "voidium":
        rect(fill, cx - 2, top + 4, cx + 2, top + 8, pal["deep"])
        put(fill, cx, top + 6, pal["glow"])
        put(fill, cx - 1, top + 5, pal["accent"])
        put(fill, cx + 1, top + 7, pal["accent"])
        put(fill, cx - 4, top + 7, pal["accent"])
        put(fill, cx + 5, top + 4, pal["glow"])
        put(fill, cx + 3, top + 11, pal["accent"])
        rect(fill, cx - 5, bot, cx + 5, bot + 1, pal["deep"])
    else:
        rect(fill, cx - 3, top + 2, cx + 3, top + 7, pal["shine"])
        put(fill, cx, top + 4, pal["glow"])
        put(fill, cx - 1, top + 5, pal["accent"])
        put(fill, cx + 1, top + 5, pal["accent"])
        put(fill, cx, top + 6, pal["accent"])
        put(fill, cx - 2, top + 3, pal["glow"])
        rect(fill, cx - 6, top, cx - 4, top + 5, pal["accent"])
        rect(fill, cx + 4, top, cx + 6, top + 5, pal["shine"])
        rect(fill, cx - 4, bot - 1, cx + 4, bot + 1, pal["accent"])

    if p["anim"].startswith("use_") or p["anim"] in ("bow_draw", "bow_release", "block_place", "interact"):
        rect(fill, cx + 3, far_y0, far_x + 2, far_y0 + 3, pal["mid"])

    return finish_layer(fill, pal["outline"])


def draw_legs(mat: str, p, composed):
    pal = PALETTES[mat]
    fill = blank()
    cx = p["cx"]
    hip = p["torso_bot"]
    pts = set(coverage_legs(p, composed))
    back_x, front_x, back_foot, front_foot, _hip = leg_geom(p)
    extra_rect(pts, back_x - 2, hip - 2, back_x + 4, back_foot)
    extra_rect(pts, front_x - 2, hip - 2, front_x + 6, front_foot)
    extra_rect(pts, cx - 5, hip - 2, cx + 5, hip + 3)

    if mat == "ferrite":
        extra_rect(pts, back_x - 3, hip - 1, back_x + 5, back_foot)
        extra_rect(pts, front_x - 3, hip - 1, front_x + 7, front_foot)
    elif mat == "tin":
        extra_rect(pts, back_x - 1, hip, back_x + 4, back_foot - 1)
        extra_rect(pts, front_x - 1, hip, front_x + 5, front_foot - 1)
    elif mat == "cryonite":
        extra_rect(pts, front_x + 5, hip + 4, front_x + 6, hip + 8)

    grain = {
        "wood": "wood",
        "veyrite": "organic",
        "cryonite": "ice",
        "voidium": "void",
        "ignitium": "void",
    }.get(mat, "metal")
    shade_pts(fill, pts, pal, cx, grain)

    knee_f = hip + 6
    knee_b = hip + 5
    rect(fill, back_x - 2, back_foot - 3, back_x + 4, back_foot, pal["boot"])
    rect(fill, front_x - 2, front_foot - 3, front_x + 6, front_foot, pal["boot"])
    rect(fill, front_x - 1, front_foot - 2, front_x + 5, front_foot - 1, pal["boot_s"])

    if mat == "wood":
        rect(fill, front_x, hip, front_x + 4, hip + 4, pal["shine"])
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["accent"])
        rect(fill, back_x, knee_b, back_x + 3, knee_b + 1, pal["accent"])
        put(fill, front_x + 1, hip + 2, pal["accent"])
        put(fill, back_x + 1, hip + 2, pal["accent"])
    elif mat == "copper":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["shine"])
        put(fill, front_x + 1, knee_f + 1, pal["accent"])
        rect(fill, back_x, knee_b, back_x + 3, knee_b + 1, pal["dark"])
        rect(fill, front_x, hip, front_x + 4, hip + 2, pal["mid"])
    elif mat == "tin":
        rect(fill, front_x + 1, knee_f, front_x + 3, knee_f + 1, pal["shine"])
        rect(fill, back_x + 1, knee_b, back_x + 2, knee_b, pal["joint"])
        rect(fill, front_x, hip, front_x + 4, hip + 1, pal["joint"])
        rect(fill, front_x + 1, hip + 8, front_x + 3, hip + 9, pal["joint"])
    elif mat == "ferrite":
        rect(fill, front_x - 1, knee_f - 1, front_x + 5, knee_f + 3, pal["dark"])
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["shine"])
        rect(fill, back_x - 1, knee_b - 1, back_x + 4, knee_b + 2, pal["deep"])
        rect(fill, cx - 5, hip - 1, cx + 5, hip + 3, pal["mid"])
    elif mat == "aurel":
        rect(fill, front_x, knee_f, front_x + 3, knee_f + 1, pal["accent"])
        put(fill, front_x + 1, hip + 2, pal["accent"])
        rect(fill, back_x, hip + 1, back_x + 3, hip + 2, pal["shine"])
        rect(fill, front_x, hip, front_x + 4, hip + 1, pal["accent"])
    elif mat == "cobalt":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["shine"])
        put(fill, front_x + 2, knee_f + 1, pal["accent"])
        rect(fill, back_x, knee_b, back_x + 3, knee_b + 2, pal["dark"])
        rect(fill, front_x, hip, front_x + 4, hip + 2, pal["mid"])
    elif mat == "veyrite":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 1, pal["dark"])
        put(fill, front_x + 2, knee_f, pal["glow"])
        put(fill, back_x + 1, hip + 3, pal["accent"])
        put(fill, front_x + 1, hip + 8, pal["glow"])
    elif mat == "cryonite":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["shine"])
        put(fill, front_x + 2, knee_f, pal["glow"])
        put(fill, front_x + 5, hip + 5, pal["accent"])
        put(fill, front_x + 6, hip + 6, pal["glow"])
        put(fill, back_x, hip + 4, pal["accent"])
    elif mat == "ignitium":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["dark"])
        put(fill, front_x + 2, knee_f + 1, pal["glow"])
        put(fill, front_x + 1, hip + 3, pal["accent"])
        put(fill, back_x + 1, hip + 8, pal["glow"])
        put(fill, front_x + 3, hip + 10, pal["accent"])
    elif mat == "voidium":
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 1, pal["deep"])
        put(fill, front_x + 2, knee_f, pal["glow"])
        put(fill, back_x + 1, hip + 3, pal["accent"])
        put(fill, front_x + 4, hip + 9, pal["accent"])
    else:
        rect(fill, front_x, knee_f, front_x + 4, knee_f + 2, pal["shine"])
        put(fill, front_x + 2, knee_f, pal["glow"])
        put(fill, front_x + 1, hip + 2, pal["accent"])
        put(fill, back_x + 1, hip + 2, pal["accent"])
        put(fill, front_x + 3, hip + 8, pal["glow"])
        rect(fill, cx - 4, hip - 1, cx + 4, hip + 1, pal["accent"])

    return finish_layer(fill, pal["outline"])


def icon_for(mat: str, kind: str) -> Image.Image:
    pal = PALETTES[mat]
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def p(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((x, y), c)

    def r(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                p(x, y, c)

    o, m, dk, s = pal["outline"], pal["mid"], pal["dark"], pal["shine"]
    a, g, v, j = pal["accent"], pal["glow"], pal["visor"], pal["joint"]
    boot, boot_s = pal["boot"], pal["boot_s"]

    if kind == "helmet":
        r(3, 3, 12, 11, o)
        r(4, 4, 11, 10, m)
        r(5, 4, 10, 5, s)
        r(4, 4, 5, 9, dk)
        r(7, 6, 12, 9, v)
        r(5, 10, 10, 12, dk)
        if mat == "wood":
            r(3, 2, 12, 5, pal["detail"])
            r(4, 3, 11, 4, s)
            p(5, 4, a)
            p(10, 4, a)
            r(4, 6, 6, 9, m)
            r(7, 6, 12, 9, v)
            r(6, 11, 9, 13, a)
        elif mat == "copper":
            r(4, 2, 11, 4, s)
            p(5, 3, a)
            p(10, 3, a)
            r(8, 6, 12, 8, v)
            r(6, 11, 9, 12, dk)
        elif mat == "tin":
            r(4, 2, 11, 5, s)
            r(6, 5, 12, 10, v)
            r(5, 11, 10, 12, j)
        elif mat == "ferrite":
            r(2, 2, 13, 13, o)
            r(3, 3, 12, 12, dk)
            r(4, 4, 10, 8, m)
            r(7, 6, 11, 8, v)
            r(5, 11, 10, 13, pal["deep"])
        elif mat == "aurel":
            r(7, 1, 9, 3, a)
            p(8, 0, s)
            r(4, 3, 12, 5, s)
            p(8, 7, a)
            r(6, 11, 9, 12, a)
        elif mat == "cobalt":
            r(5, 1, 10, 3, dk)
            p(8, 1, g)
            r(4, 3, 11, 5, s)
            r(7, 6, 12, 9, v)
        elif mat == "veyrite":
            r(4, 2, 10, 5, pal["detail"])
            p(7, 2, g)
            p(8, 7, g)
            p(5, 8, a)
            r(7, 6, 11, 9, v)
        elif mat == "cryonite":
            p(8, 0, g)
            p(6, 1, s)
            p(10, 1, a)
            p(4, 2, a)
            r(4, 3, 11, 5, s)
            r(7, 6, 12, 9, v)
            p(11, 7, g)
        elif mat == "ignitium":
            r(3, 3, 12, 11, pal["deep"])
            r(4, 4, 11, 9, dk)
            p(6, 5, a)
            p(8, 6, g)
            p(10, 8, a)
            r(7, 6, 12, 8, v)
            p(12, 4, g)
        elif mat == "voidium":
            r(2, 2, 4, 7, pal["deep"])
            p(2, 2, a)
            r(4, 3, 12, 11, dk)
            r(7, 6, 12, 9, v)
            p(9, 7, g)
            p(11, 4, a)
        else:
            p(5, 1, a)
            p(8, 0, g)
            p(11, 1, a)
            r(4, 3, 12, 5, s)
            p(8, 4, g)
            r(7, 6, 12, 9, v)
            r(6, 11, 9, 12, a)
    elif kind == "chest":
        r(2, 3, 13, 14, o)
        r(3, 4, 12, 13, m)
        r(4, 5, 11, 7, s)
        r(3, 4, 4, 12, dk)
        r(2, 4, 3, 8, dk)
        r(12, 4, 13, 8, m)
        if mat == "wood":
            r(3, 4, 12, 6, pal["detail"])
            r(3, 8, 12, 9, pal["detail"])
            r(3, 12, 12, 13, pal["detail"])
            p(5, 6, a)
            p(10, 6, a)
            p(5, 10, a)
            p(10, 10, a)
        elif mat == "copper":
            p(5, 6, a)
            p(10, 6, a)
            p(5, 10, a)
            p(10, 10, a)
            r(4, 12, 11, 14, dk)
        elif mat == "tin":
            r(4, 7, 11, 8, j)
            r(4, 11, 11, 12, j)
            r(2, 5, 3, 8, j)
            r(12, 5, 13, 8, j)
        elif mat == "ferrite":
            r(1, 3, 4, 9, dk)
            r(11, 3, 14, 9, m)
            r(5, 5, 10, 11, s)
            r(3, 12, 12, 14, pal["deep"])
        elif mat == "aurel":
            r(4, 5, 5, 7, a)
            r(10, 5, 11, 7, s)
            p(8, 8, a)
            p(7, 9, a)
            p(9, 9, a)
            p(8, 10, dk)
            r(5, 13, 10, 14, a)
        elif mat == "cobalt":
            p(8, 7, g)
            r(3, 12, 12, 14, j)
            p(4, 13, a)
            p(11, 13, a)
            r(2, 4, 4, 8, dk)
        elif mat == "veyrite":
            p(8, 8, g)
            p(7, 9, a)
            p(9, 9, a)
            p(5, 11, g)
            p(11, 7, a)
        elif mat == "cryonite":
            p(8, 6, g)
            p(7, 7, a)
            p(9, 7, s)
            p(4, 5, a)
            p(12, 5, g)
        elif mat == "ignitium":
            r(6, 6, 9, 11, pal["deep"])
            p(8, 8, g)
            p(7, 9, a)
            p(8, 10, a)
            p(5, 12, a)
            p(11, 7, g)
        elif mat == "voidium":
            r(6, 6, 9, 11, pal["deep"])
            p(8, 8, g)
            p(5, 9, a)
            p(11, 6, a)
            p(10, 12, g)
        else:
            p(8, 7, g)
            p(7, 8, a)
            p(9, 8, a)
            r(2, 4, 4, 8, a)
            r(11, 4, 13, 8, s)
            r(5, 13, 10, 14, a)
    else:
        r(2, 2, 6, 11, o)
        r(9, 2, 13, 11, o)
        r(3, 3, 5, 10, m)
        r(10, 3, 12, 10, m)
        r(3, 3, 3, 9, dk)
        r(2, 11, 13, 14, boot)
        r(3, 12, 12, 13, boot_s)
        if mat == "wood":
            r(3, 3, 5, 6, pal["detail"])
            r(3, 7, 5, 8, a)
            r(10, 8, 12, 9, a)
        elif mat == "copper":
            r(3, 7, 5, 9, a)
            r(10, 7, 12, 8, s)
        elif mat == "tin":
            r(3, 6, 5, 7, j)
            r(10, 7, 12, 8, j)
        elif mat == "ferrite":
            r(1, 6, 6, 10, dk)
            r(9, 6, 14, 10, m)
            r(3, 7, 5, 9, s)
        elif mat == "aurel":
            r(3, 6, 5, 7, a)
            r(10, 6, 12, 7, a)
        elif mat == "cobalt":
            r(3, 7, 5, 9, s)
            p(4, 8, g)
            r(10, 7, 12, 9, dk)
        elif mat == "veyrite":
            p(4, 7, g)
            p(11, 8, a)
        elif mat == "cryonite":
            p(4, 7, g)
            p(12, 6, a)
            p(5, 5, s)
        elif mat == "ignitium":
            p(4, 7, g)
            p(5, 9, a)
            p(11, 8, a)
        elif mat == "voidium":
            p(4, 7, g)
            p(11, 6, a)
        else:
            p(4, 6, g)
            p(11, 6, a)
            r(3, 3, 5, 4, s)
    return img


def composed_base(p):
    body, body_fill = draw_body(p)
    hair_b = draw_hair_back(p)
    hair_f = draw_hair_front(p)
    shirt = draw_shirt(p)
    pants = draw_pants(p)
    shoes = draw_shoes(p)
    fill = blank()
    blit_opaque(body_fill, fill)
    blit_opaque(shirt, fill)
    blit_opaque(pants, fill)
    blit_opaque(shoes, fill)
    blit_opaque(hair_b, fill)
    blit_opaque(hair_f, fill)
    player = blank()
    for layer in (hair_b, body, pants, shoes, shirt, hair_f):
        blit_opaque(layer, player)
    return fill, player, body, shirt, pants, shoes, hair_b, hair_f


def write_import_like(_path: Path, _template: Path):
    # Godot erzeugt .import selbst. Keine UID-Kopien schreiben.
    return


def patch_item_resources():
    mapping = {}
    for mat in MATERIALS:
        mapping[mat] = {
            "helmet": f"res://resources/player/armor_{mat}_helmet_frames.tres",
            "chestplate": f"res://resources/player/armor_{mat}_chest_frames.tres",
            "leggings": f"res://resources/player/armor_{mat}_legs_frames.tres",
        }
    files = list(ITEM_DIR.glob("*.tres")) + list((ITEM_DIR / "metal").glob("*.tres"))
    for path in files:
        text = path.read_text(encoding="utf-8")
        stem = path.stem
        mat = None
        piece = None
        for m in MATERIALS:
            if stem.startswith(m + "_"):
                mat = m
                rest = stem[len(m) + 1 :]
                if rest in mapping[m]:
                    piece = rest
                break
        if mat is None or piece is None:
            continue
        frames = mapping[mat][piece]
        text = re.sub(
            r'\[ext_resource type="SpriteFrames" path="res://resources/player/[^"]+" id="3_frames"\]',
            f'[ext_resource type="SpriteFrames" path="{frames}" id="3_frames"]',
            text,
        )
        text = re.sub(r"\narmor_modulate = Color\([^)]+\)", "", text)
        if "armor_modulate" not in text:
            text = text.rstrip() + "\narmor_modulate = Color(1, 1, 1, 1)\n"
        path.write_text(text, encoding="utf-8")
        print("patched", path.relative_to(ROOT))


def build_preview(idle_frames: dict[str, dict[str, Image.Image]], player_idle: Image.Image):
    gap = 8
    cols = len(MATERIALS)
    cell_w, cell_h = W + gap, H + 16
    img = Image.new("RGBA", (cols * cell_w + gap, cell_h + 8), (18, 16, 22, 255))
    draw = ImageDraw.Draw(img)
    for i, mat in enumerate(MATERIALS):
        x = gap + i * cell_w
        y = 12
        composed = player_idle.copy()
        for kind in ("legs", "chest", "helmet"):
            blit_opaque(idle_frames[mat][kind], composed)
        img.paste(composed, (x, y), composed)
        draw.text((x + 2, 1), mat[:8], fill=(220, 214, 200, 255))
    out = SHEETS / "armor_sets_preview.png"
    save(img, out)
    print("wrote", out.relative_to(ROOT))
    return out


def write_preview_scene():
    scene_dir = ROOT / "scenes" / "debug"
    scene_dir.mkdir(parents=True, exist_ok=True)
    tscn = scene_dir / "armor_set_preview.tscn"
    tscn.write_text(
        """[gd_scene load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/player/sheets/armor_sets_preview.png" id="1_tex"]

[node name="ArmorSetPreview" type="Node2D"]

[node name="Background" type="ColorRect" parent="."]
z_index = -1
offset_left = -32.0
offset_top = -32.0
offset_right = 560.0
offset_bottom = 120.0
mouse_filter = 2
color = Color(0.07, 0.06, 0.09, 1)

[node name="Sets" type="Sprite2D" parent="."]
texture_filter = 0
position = Vector2(264, 48)
texture = ExtResource("1_tex")
centered = true

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(264, 48)
zoom = Vector2(2.5, 2.5)
""",
        encoding="utf-8",
    )
    print("wrote", tscn.relative_to(ROOT))


def main():
    SHEETS.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)
    RES.mkdir(parents=True, exist_ok=True)

    sheets = {
        mat: {kind: Image.new("RGBA", (MAX_COLS * W, len(ANIMS) * H), (0, 0, 0, 0)) for kind in PIECES}
        for mat in MATERIALS
    }
    idle = {mat: {} for mat in MATERIALS}
    player_idle = None
    template_import = ROOT / "assets" / "player" / "sheets" / "armor_wood_helmet.png.import"

    drawers = {"helmet": draw_helmet, "chest": draw_chest, "legs": draw_legs}

    for row, (anim, frames, _fps, _loop) in enumerate(ANIMS):
        for i in range(frames):
            p = pose(anim, i, frames)
            fill, player, *_rest = composed_base(p)
            if anim == "idle" and i == 0:
                player_idle = player
            x, y = i * W, row * H
            for mat in MATERIALS:
                for kind in PIECES:
                    piece = drawers[kind](mat, p, fill)
                    sheets[mat][kind].paste(piece, (x, y))
                    if anim == "idle" and i == 0:
                        idle[mat][kind] = piece

    for mat in MATERIALS:
        for kind in PIECES:
            img = sheets[mat][kind]
            path = SHEETS / f"armor_{mat}_{kind}.png"
            save(img, path)
            print("wrote", path.relative_to(ROOT))
            write_import_like(path, template_import)
            write_spriteframes(
                f"armor_{mat}_{kind}_frames.tres",
                f"assets/player/sheets/armor_{mat}_{kind}.png",
                RES / f"armor_{mat}_{kind}_frames.tres",
            )
        for kind, item_kind in (("helmet", "helmet"), ("chest", "chestplate"), ("legs", "leggings")):
            ipath = ICONS / f"{mat}_{item_kind}.png"
            save(icon_for(mat, kind), ipath)
            print("wrote", ipath.relative_to(ROOT))

    if player_idle is not None:
        build_preview(idle, player_idle)
    write_preview_scene()
    patch_item_resources()
    print("armor visuals done")


if __name__ == "__main__":
    main()
