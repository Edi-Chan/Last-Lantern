#!/usr/bin/env python3
"""Last Lantern player/armor sheets. Original 40x56 side-view pixel art. No third-party art."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image

W, H = 40, 56
FOOT_Y = 55
MAX_COLS = 6
ROOT = Path(__file__).resolve().parents[1]
PLAYER = ROOT / "assets" / "player"
SHEETS = PLAYER / "sheets"
ARMOR = PLAYER / "armor"
ICONS = ROOT / "assets" / "items" / "equipment"
RES = ROOT / "resources" / "player"

ANIMS = [
    ("idle", 4, 6.0, True),
    ("idle_alt", 3, 5.0, True),
    ("walk", 6, 10.0, True),
    ("run", 6, 14.0, True),
    ("crouch_idle", 2, 5.0, True),
    ("crouch_walk", 4, 8.0, True),
    ("jump_start", 2, 14.0, False),
    ("jump", 2, 8.0, True),
    ("fall", 2, 8.0, True),
    ("land", 2, 12.0, False),
    ("swim_idle", 4, 6.0, True),
    ("swim", 6, 10.0, True),
    ("ladder_idle", 1, 5.0, True),
    ("ladder_climb", 4, 8.0, True),
    ("hurt", 2, 12.0, False),
    ("death", 4, 8.0, False),
    ("sleep", 2, 3.0, True),
    ("use_swing", 6, 16.0, False),
    ("use_overhead", 5, 14.0, False),
    ("use_thrust", 5, 14.0, False),
    ("use_chop", 5, 14.0, False),
    ("use_mine", 5, 14.0, False),
    ("use_stab", 4, 18.0, False),
    ("bow_draw", 3, 10.0, False),
    ("bow_release", 3, 14.0, False),
    ("block_place", 3, 12.0, False),
    ("interact", 3, 10.0, False),
    ("use_tool", 1, 5.0, True),
]

LAYERS = ["body", "hair_back", "hair_front", "shirt", "pants", "shoes", "composed"]
ARMOR_KINDS = ["helmet", "chest", "legs"]

OUT = (36, 24, 18, 255)
HAIR = (122, 72, 38, 255)
HAIR_D = (90, 50, 26, 255)
SKIN = (224, 176, 138, 255)
SKIN_D = (196, 140, 108, 255)
SHIRT = (52, 108, 176, 255)
SHIRT_D = (36, 78, 138, 255)
PANTS = (118, 74, 44, 255)
PANTS_D = (86, 52, 32, 255)
SHOE = (62, 42, 32, 255)
SHOE_D = (42, 28, 22, 255)
EYE_W = (245, 242, 235, 255)
EYE = (40, 28, 22, 255)
MOUTH = (150, 80, 70, 255)

HELM = (176, 182, 188, 255)
HELM_D = (118, 124, 132, 255)
HELM_O = (58, 62, 70, 255)
HELM_S = (214, 220, 226, 255)
VISOR = (28, 32, 40, 255)
CHEST = (154, 162, 172, 255)
CHEST_D = (98, 106, 116, 255)
CHEST_O = (52, 56, 64, 255)
CHEST_S = (198, 206, 214, 255)
LEG = (132, 138, 148, 255)
LEG_D = (82, 88, 98, 255)
LEG_O = (46, 50, 58, 255)
LEG_S = (176, 182, 192, 255)
BRONZE = (184, 128, 56, 255)
BRONZE_D = (128, 82, 34, 255)
BOOT = (58, 40, 30, 255)
BOOT_S = (92, 64, 44, 255)

WOOD = (168, 118, 62, 255)
WOOD_D = (112, 72, 36, 255)
WOOD_O = (62, 38, 18, 255)
WOOD_S = (204, 158, 96, 255)
WOOD_STRAP = (86, 52, 28, 255)

SHIRT_RGB = {SHIRT[:3], SHIRT_D[:3]}
PANTS_RGB = {PANTS[:3], PANTS_D[:3], SHOE[:3], SHOE_D[:3]}
HAIR_RGB = {HAIR[:3], HAIR_D[:3]}
HEAD_SKIN_RGB = {SKIN[:3], SKIN_D[:3], EYE_W[:3], EYE[:3], MOUTH[:3]}


def blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def px(img, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((int(x), int(y)), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            px(img, x, y, c)


def oval(img, cx, cy, rx, ry, c):
    rx = max(rx, 1)
    ry = max(ry, 1)
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.05:
                px(img, x, y, c)


def outline_from(src, dest, color=OUT):
    for y in range(H):
        for x in range(W):
            if src.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or dest.getpixel((nx, ny))[3] == 0:
                    px(dest, nx, ny, color)


def blit_opaque(src, dest):
    for y in range(H):
        for x in range(W):
            p = src.getpixel((x, y))
            if p[3] > 0:
                dest.putpixel((x, y), p)


def finish_layer(fill, outline_color=OUT):
    img = blank()
    outline_from(fill, img, outline_color)
    blit_opaque(fill, img)
    return img


def rgb(c):
    return c[:3]


def lerp(a, b, t):
    return a + (b - a) * t


def pose(anim: str, i: int, n: int) -> dict:
    crouch = anim.startswith("crouch")
    swim = anim.startswith("swim")
    ladder = anim.startswith("ladder")
    death = anim == "death"
    sleep = anim == "sleep"
    hurt = anim == "hurt"
    land = anim == "land"
    jump = anim in ("jump", "jump_start")
    fall = anim == "fall"
    t = i / max(n - 1, 1)

    head_y = 11
    torso_bot = 35
    foot_y = FOOT_Y
    lean = 0
    if crouch:
        head_y = 18
        torso_bot = 40
    if jump:
        head_y = 10 if anim == "jump_start" else 9
        torso_bot = 33
        foot_y = 54 if anim == "jump_start" else 53
    if fall:
        head_y = 10
        torso_bot = 34
        foot_y = 54
    if land:
        head_y = 13 + i
        torso_bot = 37 + i
        foot_y = FOOT_Y
    if swim:
        head_y = 16
        torso_bot = 30
        foot_y = 50
        lean = 3
    if ladder:
        head_y = 10
        torso_bot = 34
        foot_y = FOOT_Y
    if hurt:
        head_y = 12
        torso_bot = 36
        lean = -2
    if death:
        head_y = 16 + i * 2
        torso_bot = 38 + i
        lean = 2 + i
        foot_y = FOOT_Y
    if sleep:
        head_y = 20
        torso_bot = 36
        lean = 4
    if anim == "idle":
        head_y = 11 - (1 if i in (1, 2) else 0)
    if anim == "idle_alt":
        head_y = 11
        lean = 1 if i == 1 else 0
    if anim == "run":
        lean = 2
        head_y = 10

    front_dx, back_dx = 0, 0
    arm_front, arm_back = (0, 0), (0, 0)
    cycle = 2.0 * math.pi * (i / max(n, 1))

    front_lift, back_lift = 0, 0
    if anim == "walk":
        s = math.sin(cycle)
        # Enge Seitansicht: Beine bleiben unter der Hüfte, Schritt über Lift statt Grätsche.
        walk_legs = (
            (1, -1, 0, 1),
            (2, -1, 0, 0),
            (1, 0, 1, 0),
            (-1, 1, 1, 0),
            (-2, 1, 0, 0),
            (0, 1, 0, 1),
        )
        front_dx, back_dx, front_lift, back_lift = walk_legs[min(i, len(walk_legs) - 1)]
        arm_front = (int(round(-3 * s)), 1)
        arm_back = (int(round(3 * s)), 1)
    elif anim == "run":
        s = math.sin(cycle)
        run_legs = (
            (2, -2, 0, 2),
            (3, -1, 0, 1),
            (1, 0, 2, 0),
            (-2, 2, 2, 0),
            (-3, 1, 1, 0),
            (0, 2, 0, 2),
        )
        front_dx, back_dx, front_lift, back_lift = run_legs[min(i, len(run_legs) - 1)]
        arm_front = (int(round(-4 * s)), 2)
        arm_back = (int(round(4 * s)), 2)
    elif anim == "crouch_walk":
        s = math.sin(cycle)
        front_dx, back_dx = int(round(3 * s)), int(round(-3 * s))
        arm_front = (int(round(-2 * s)), 1)
        arm_back = (int(round(2 * s)), 1)
    elif anim == "crouch_idle":
        arm_front, arm_back = (1, 1), (-1, 1)
        front_dx, back_dx = 1, -1
    elif anim == "jump_start":
        front_dx, back_dx = 1, -1
        arm_front, arm_back = (2, 1), (-1, 1)
        if i == 1:
            front_dx, back_dx = 2, -2
            arm_front, arm_back = (3, -2), (-2, 0)
    elif anim == "jump":
        front_dx, back_dx = 2, -3
        arm_front, arm_back = (3, -3), (-2, -1)
        if i == 1:
            front_dx, back_dx = 3, -2
            arm_front, arm_back = (4, -2), (-3, 0)
    elif anim == "fall":
        front_dx, back_dx = 3, -3
        arm_front, arm_back = (4, 2), (-3, 1)
        if i == 1:
            arm_front, arm_back = (5, 3), (-4, 2)
    elif anim == "land":
        front_dx, back_dx = 2, -2
        arm_front, arm_back = (2, 2), (-2, 2)
    elif anim == "swim" or anim == "swim_idle":
        s = math.sin(cycle)
        front_dx, back_dx = int(round(5 * s)), int(round(-4 * s))
        arm_front = (int(round(4 * math.cos(cycle))), int(round(-2 * s)))
        arm_back = (int(round(-3 * math.cos(cycle))), int(round(2 * s)))
    elif anim == "ladder_climb":
        s = 1 if i % 2 == 0 else -1
        front_dx, back_dx = 2 * s, -2 * s
        arm_front, arm_back = (1, -6 if s > 0 else -2), (-2, -2 if s > 0 else -6)
    elif anim == "ladder_idle":
        arm_front, arm_back = (1, -5), (-2, -3)
        front_dx, back_dx = 1, -1
    elif anim == "hurt":
        front_dx, back_dx = -1, 1
        arm_front, arm_back = (-3, 0), (2, 1)
    elif anim == "death":
        front_dx, back_dx = 3 + i, -2
        arm_front, arm_back = (4, 2 + i), (-3, 3)
    elif anim == "sleep":
        front_dx, back_dx = 4, -1
        arm_front, arm_back = (3, 2), (-1, 2)
    elif anim == "use_swing":
        # anticipation, swing, impact, follow, recover
        swings = [(-2, -5), (-3, -6), (4, -2), (7, 1), (5, 2), (1, 0)]
        arm_front = swings[min(i, len(swings) - 1)]
        arm_back = (-1, 1)
        front_dx, back_dx = 1, -1
    elif anim == "use_overhead":
        overhead = [(-1, -6), (-2, -8), (3, -3), (6, 2), (2, 1)]
        arm_front = overhead[min(i, len(overhead) - 1)]
        arm_back = (-1, 1)
    elif anim == "use_chop":
        chops = [(-2, -6), (-3, -8), (2, -1), (6, 3), (2, 1)]
        arm_front = chops[min(i, len(chops) - 1)]
        arm_back = (-1, 1)
    elif anim == "use_mine":
        mines = [(-1, -5), (-2, -7), (3, -1), (6, 2), (1, 0)]
        arm_front = mines[min(i, len(mines) - 1)]
        arm_back = (-1, 1)
    elif anim == "use_thrust":
        thrusts = [(2, 0), (-2, 1), (8, 0), (6, 0), (1, 0)]
        arm_front = thrusts[min(i, len(thrusts) - 1)]
        arm_back = (-1, 1)
    elif anim == "use_stab":
        stabs = [(1, 0), (-2, 1), (7, 0), (1, 0)]
        arm_front = stabs[min(i, len(stabs) - 1)]
        arm_back = (-1, 1)
    elif anim == "bow_draw":
        arm_front = (4, -1)
        arm_back = (-3 - i, 0)
        front_dx, back_dx = 1, -1
    elif anim == "bow_release":
        rel = [(4, -1), (6, 0), (3, 1)]
        arm_front = rel[min(i, len(rel) - 1)]
        arm_back = (0, 0)
    elif anim == "block_place":
        places = [(2, 1), (4, 3), (1, 0)]
        arm_front = places[min(i, len(places) - 1)]
        arm_back = (-1, 1)
    elif anim == "interact":
        acts = [(2, 0), (3, -2), (2, 0)]
        arm_front = acts[min(i, len(acts) - 1)]
        arm_back = (-1, 1)
    elif anim == "use_tool":
        arm_front, arm_back = (6, -4), (-1, 1)
        front_dx, back_dx = 1, -1
    elif anim == "idle_alt" and i == 1:
        arm_front, arm_back = (1, -1), (-1, 1)

    return {
        "anim": anim,
        "i": i,
        "head_y": head_y,
        "torso_top": head_y + 8,
        "torso_bot": torso_bot,
        "foot_y": foot_y,
        "front_dx": front_dx,
        "back_dx": back_dx,
        "front_lift": front_lift,
        "back_lift": back_lift,
        "arm_front": arm_front,
        "arm_back": arm_back,
        "crouch": crouch,
        "swim": swim,
        "ladder": ladder,
        "cx": 20 + lean,
        "t": t,
    }


def leg_geom(p):
    cx = p["cx"]
    hip = p["torso_bot"]
    foot = p["foot_y"]
    back_x = cx - 3 + p["back_dx"]
    front_x = cx + 1 + p["front_dx"]
    back_foot = foot - int(p.get("back_lift", 0))
    front_foot = foot - int(p.get("front_lift", 0))
    return back_x, front_x, back_foot, front_foot, hip


def draw_body(p):
    fill = blank()
    cx = p["cx"]
    hy = p["head_y"]
    oval(fill, cx + 1, hy + 1, 6, 8, SKIN)
    rect(fill, cx + 2, hy - 2, cx + 8, hy + 7, SKIN)
    oval(fill, cx + 4, hy + 1, 5, 7, SKIN)
    rect(fill, cx + 3, hy - 1, cx + 9, hy + 6, SKIN)
    oval(fill, cx - 4, hy + 2, 2, 2, SKIN_D)
    rect(fill, cx, hy + 8, cx + 3, p["torso_top"] + 1, SKIN)
    rect(fill, cx - 2, p["torso_top"], cx + 3, p["torso_bot"] - 1, SKIN_D)
    ax, ay = p["arm_back"]
    arm_x = cx - 5 + ax
    arm_y0 = p["torso_top"] + 2 + ay
    arm_y1 = arm_y0 + (8 if p["crouch"] else 11)
    if p["swim"]:
        arm_y1 = arm_y0 + 8
    rect(fill, arm_x, arm_y0, arm_x + 2, arm_y1, SKIN_D)
    rect(fill, arm_x, arm_y1, arm_x + 2, arm_y1 + 3, SKIN_D)
    fx, fy = p["arm_front"]
    far_x = cx + 4 + fx
    far_y0 = p["torso_top"] + 1 + fy
    if p["anim"].startswith("use_") or p["anim"] in ("bow_draw", "bow_release", "block_place", "interact"):
        rect(fill, cx + 3, far_y0, far_x + 2, far_y0 + 3, SKIN)
        rect(fill, far_x + 1, far_y0 - 1, far_x + 5, far_y0 + 2, SKIN)
    else:
        far_y1 = far_y0 + (7 if p["crouch"] else 10)
        rect(fill, far_x, far_y0, far_x + 3, far_y1, SKIN)
        rect(fill, far_x + 1, far_y1, far_x + 3, far_y1 + 4, SKIN)
    hip = p["torso_bot"]
    back_x, front_x, back_foot, front_foot, _hip = leg_geom(p)
    rect(fill, back_x, hip - 1, back_x + 3, back_foot - 3, SKIN_D)
    rect(fill, front_x, hip - 1, front_x + 4, front_foot - 3, SKIN)
    img = finish_layer(fill)
    eye_x, eye_y = cx + 5, hy + 1
    px(img, eye_x, eye_y, EYE_W)
    px(img, eye_x + 1, eye_y, EYE)
    px(img, eye_x, eye_y + 1, EYE)
    px(img, cx + 8, hy + 3, SKIN_D)
    px(img, cx + 9, hy + 3, SKIN_D)
    px(img, cx + 9, hy + 4, SKIN)
    px(img, cx + 7, hy + 6, MOUTH)
    return img, fill


def draw_hair_back(p):
    fill = blank()
    cx = p["cx"]
    hy = p["head_y"]
    oval(fill, cx - 2, hy, 6, 7, HAIR)
    rect(fill, cx - 7, hy - 2, cx + 1, hy + 6, HAIR)
    rect(fill, cx - 6, hy - 7, cx + 2, hy, HAIR)
    rect(fill, cx - 5, hy - 8, cx + 1, hy - 2, HAIR_D)
    return finish_layer(fill)


def draw_hair_front(p):
    fill = blank()
    cx = p["cx"]
    hy = p["head_y"]
    rect(fill, cx - 1, hy - 7, cx + 4, hy - 3, HAIR)
    rect(fill, cx - 4, hy - 6, cx + 1, hy - 2, HAIR_D)
    rect(fill, cx + 2, hy - 4, cx + 5, hy - 2, HAIR)
    return finish_layer(fill)


def draw_shirt(p):
    fill = blank()
    cx = p["cx"]
    rect(fill, cx - 3, p["torso_top"], cx + 4, p["torso_bot"], SHIRT)
    rect(fill, cx - 2, p["torso_top"] + 1, cx + 3, p["torso_bot"], SHIRT)
    rect(fill, cx - 3, p["torso_top"], cx - 2, p["torso_bot"] - 2, SHIRT_D)
    ax, ay = p["arm_back"]
    arm_x = cx - 5 + ax
    arm_y0 = p["torso_top"] + 2 + ay
    arm_y1 = arm_y0 + (6 if p["crouch"] else 8)
    rect(fill, arm_x, arm_y0, arm_x + 2, arm_y1, SHIRT_D)
    fx, fy = p["arm_front"]
    far_x = cx + 4 + fx
    far_y0 = p["torso_top"] + 1 + fy
    if p["anim"].startswith("use_") or p["anim"] in ("bow_draw", "bow_release", "block_place", "interact"):
        rect(fill, cx + 3, far_y0, far_x + 2, far_y0 + 3, SHIRT)
    else:
        far_y1 = far_y0 + (5 if p["crouch"] else 7)
        rect(fill, far_x, far_y0, far_x + 3, far_y1, SHIRT)
    return finish_layer(fill)


def draw_pants(p):
    fill = blank()
    back_x, front_x, back_foot, front_foot, hip = leg_geom(p)
    rect(fill, back_x, hip - 1, back_x + 3, back_foot - 3, PANTS_D)
    rect(fill, front_x, hip - 1, front_x + 4, front_foot - 3, PANTS)
    return finish_layer(fill)


def draw_shoes(p):
    fill = blank()
    back_x, front_x, back_foot, front_foot, _hip = leg_geom(p)
    rect(fill, back_x - 1, back_foot - 2, back_x + 4, back_foot, SHOE)
    rect(fill, front_x - 1, front_foot - 2, front_x + 6, front_foot, SHOE)
    rect(fill, front_x + 4, front_foot - 1, front_x + 6, front_foot, SHOE_D)
    return finish_layer(fill)


def compose_fill(p, body_fill, shirt, pants, shoes, hair_back, hair_front):
    fill = blank()
    for layer in (hair_back, body_fill, pants, shoes, shirt, hair_front):
        src = layer if layer.mode == "RGBA" else layer
        for y in range(H):
            for x in range(W):
                pix = src.getpixel((x, y))
                if pix[3] > 0:
                    fill.putpixel((x, y), pix)
    return fill


def collect_pts(src, predicate):
    pts = []
    for y in range(H):
        for x in range(W):
            pix = src.getpixel((x, y))
            if pix[3] > 0 and predicate(x, y, pix):
                pts.append((x, y))
    return pts


def dilate_pts(pts, radius=1):
    found = set(pts)
    extra = set()
    for x, y in pts:
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H:
                    extra.add((nx, ny))
    found.update(extra)
    return found


def paint_points(fill, pts, color, dark, shine, cx):
    for x, y in pts:
        if x < cx - 1:
            fill.putpixel((x, y), dark)
        elif x > cx + 2 and (x + y) % 7 == 0:
            fill.putpixel((x, y), shine)
        else:
            fill.putpixel((x, y), color)


def draw_helmet(p, base_fill, pal=None):
    pal = pal or (HELM, HELM_D, HELM_S, HELM_O, VISOR, BRONZE)
    color, dark, shine, outline, visor, gem = pal
    fill = blank()
    cx = p["cx"]
    hy = p["head_y"]
    torso_top = p["torso_top"]

    def is_head(_x, y, pix):
        tone = rgb(pix)
        if tone in HAIR_RGB:
            return True
        if y >= torso_top:
            return False
        return tone in HEAD_SKIN_RGB and y <= hy + 7

    pts = dilate_pts(collect_pts(base_fill, is_head), 1)
    extra = []
    for x, y in list(pts):
        extra.append((x, max(0, y - 1)))
        extra.append((x, min(H - 1, y + 1)))
        extra.append((max(0, x - 1), y))
        extra.append((min(W - 1, x + 1), y))
    pts = set(pts)
    pts.update(extra)
    paint_points(fill, pts, color, dark, shine, cx)
    rect(fill, cx - 5, hy - 8, cx + 4, hy - 3, shine)
    rect(fill, cx + 2, hy - 1, cx + 9, hy + 3, visor)
    rect(fill, cx - 2, hy + 6, cx + 4, hy + 9, dark)
    px(fill, cx + 8, hy, shine)
    px(fill, cx - 4, hy - 7, gem)
    px(fill, cx + 3, hy - 7, gem)
    return finish_layer(fill, outline)


def draw_chest(p, base_fill, pal=None):
    pal = pal or (CHEST, CHEST_D, CHEST_S, CHEST_O, BRONZE, BRONZE_D)
    color, dark, shine, outline, gem, gem_d = pal
    fill = blank()
    cx = p["cx"]
    top = p["torso_top"]
    bot = p["torso_bot"]

    def is_shirt(_x, y, pix):
        return rgb(pix) in SHIRT_RGB and y <= bot + 1

    pts = dilate_pts(collect_pts(base_fill, is_shirt), 1)
    extra = set()
    fx, fy = p["arm_front"]
    far_x = cx + 4 + fx
    far_y0 = top + 1 + fy
    for x in range(far_x - 1, far_x + 4):
        for y in range(far_y0 - 1, far_y0 + 7):
            extra.add((x, y))
    ax, ay = p["arm_back"]
    arm_x = cx - 6 + ax
    arm_y0 = top + 2 + ay
    for x in range(arm_x, arm_x + 4):
        for y in range(arm_y0, arm_y0 + 7):
            extra.add((x, y))
    for x in range(cx - 5, cx + 6):
        extra.add((x, top - 1))
        extra.add((x, bot))
        extra.add((x, bot + 1))
    pts = set(pts)
    pts.update((x, y) for x, y in extra if 0 <= x < W and 0 <= y < H)
    paint_points(fill, pts, color, dark, shine, cx)
    rect(fill, cx - 2, top + 2, cx + 3, top + 5, shine)
    rect(fill, cx - 4, bot - 1, cx + 5, bot + 1, gem_d)
    rect(fill, cx - 3, bot, cx + 4, bot + 1, gem)
    px(fill, cx - 2, top + 7, gem)
    px(fill, cx + 3, top + 7, gem)
    return finish_layer(fill, outline)


def draw_legs(p, base_fill, pal=None):
    pal = pal or (LEG, LEG_D, LEG_S, LEG_O, BOOT, BOOT_S, BRONZE, BRONZE_D)
    color, dark, shine, outline, boot, boot_s, gem, gem_d = pal
    fill = blank()
    cx = p["cx"]
    hip = p["torso_bot"]
    back_x, front_x, back_foot, front_foot, _hip = leg_geom(p)

    def is_legs(_x, y, pix):
        return rgb(pix) in PANTS_RGB and y >= hip - 2

    pts = dilate_pts(collect_pts(base_fill, is_legs), 1)
    extra = set()
    for x in range(back_x - 2, back_x + 5):
        for y in range(hip - 2, back_foot + 1):
            extra.add((x, y))
    for x in range(front_x - 2, front_x + 7):
        for y in range(hip - 2, front_foot + 1):
            extra.add((x, y))
    for x in range(cx - 5, cx + 6):
        for y in range(hip - 2, hip + 3):
            extra.add((x, y))
    pts = set(pts)
    pts.update((x, y) for x, y in extra if 0 <= x < W and 0 <= y < H)
    paint_points(fill, pts, color, dark, shine, cx)
    rect(fill, back_x - 2, back_foot - 3, back_x + 4, back_foot, boot)
    rect(fill, front_x - 2, front_foot - 3, front_x + 6, front_foot, boot)
    rect(fill, front_x - 1, front_foot - 2, front_x + 5, front_foot - 1, boot_s)
    knee_y = hip + 6
    rect(fill, front_x, knee_y, front_x + 4, knee_y + 2, gem)
    rect(fill, back_x, hip + 5, back_x + 3, hip + 6, gem_d)
    return finish_layer(fill, outline)


WOOD_HELM_PAL = (WOOD, WOOD_D, WOOD_S, WOOD_O, (40, 28, 18, 255), WOOD_STRAP)
WOOD_CHEST_PAL = (WOOD, WOOD_D, WOOD_S, WOOD_O, WOOD_STRAP, WOOD_D)
WOOD_LEG_PAL = (WOOD, WOOD_D, WOOD_S, WOOD_O, (72, 44, 24, 255), (108, 72, 40, 255), WOOD_STRAP, WOOD_D)


def icon(kind, wood=False):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    c, d, s, o = (WOOD, WOOD_D, WOOD_S, WOOD_O) if wood else (HELM if kind == "helmet" else CHEST if kind == "chest" else LEG,
                                                              HELM_D if kind == "helmet" else CHEST_D if kind == "chest" else LEG_D,
                                                              HELM_S if kind == "helmet" else CHEST_S if kind == "chest" else LEG_S,
                                                              HELM_O if kind == "helmet" else CHEST_O if kind == "chest" else LEG_O)
    if wood:
        c, d, s, o = WOOD, WOOD_D, WOOD_S, WOOD_O

    def p(x, y, col):
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((x, y), col)

    def r(x0, y0, x1, y1, col):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                p(x, y, col)

    if kind == "helmet":
        r(2, 1, 13, 12, o)
        r(3, 2, 12, 11, c)
        r(4, 2, 11, 4, s)
        r(6, 6, 13, 9, VISOR if not wood else (40, 28, 18, 255))
        r(4, 11, 11, 13, d)
        p(4, 2, BRONZE if not wood else WOOD_STRAP)
        p(11, 2, BRONZE if not wood else WOOD_STRAP)
    elif kind == "chest":
        r(2, 2, 13, 14, o)
        r(3, 3, 12, 13, c)
        r(4, 4, 11, 6, s)
        r(3, 12, 12, 14, BRONZE_D if not wood else WOOD_D)
        r(4, 13, 11, 14, BRONZE if not wood else WOOD_STRAP)
        p(5, 8, BRONZE if not wood else WOOD_STRAP)
        p(10, 8, BRONZE if not wood else WOOD_STRAP)
        r(3, 3, 4, 11, d)
    else:
        r(2, 2, 13, 14, o)
        r(3, 3, 7, 11, c)
        r(8, 3, 12, 11, c)
        r(3, 3, 4, 10, d)
        r(4, 7, 6, 9, BRONZE if not wood else WOOD_STRAP)
        r(9, 8, 11, 9, BRONZE if not wood else WOOD_STRAP)
        r(3, 12, 12, 14, BOOT if not wood else (72, 44, 24, 255))
        r(4, 12, 11, 13, BOOT_S if not wood else (108, 72, 40, 255))
    return img


def save(img, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def write_import(path: Path):
    rel = path.as_posix()
    text = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://gen_{path.stem}_{path.parent.name}"
path=".godot/imported/{path.name}-pending.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{path.relative_to(ROOT).as_posix()}"
dest_files=["res://.godot/imported/{path.name}-pending.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    (Path(str(path) + ".import")).write_text(text, encoding="utf-8")


def write_spriteframes(name: str, sheet_rel: str, out_path: Path):
    atlas_ids = []
    subs = []
    idx = 0
    for row, (anim, frames, fps, loop) in enumerate(ANIMS):
        for f in range(frames):
            sid = f"a{idx}"
            atlas_ids.append((anim, f, sid, row, f))
            subs.append(
                f'[sub_resource type="AtlasTexture" id="{sid}"]\n'
                f'atlas = ExtResource("1_sheet")\n'
                f"region = Rect2({f * W}, {row * H}, {W}, {H})\n"
            )
            idx += 1
    anim_blocks = []
    grouped = {}
    for anim, f, sid, _row, _col in atlas_ids:
        grouped.setdefault(anim, []).append(sid)
    for anim, frames, fps, loop in ANIMS:
        frame_entries = ",\n".join(
            '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid for sid in grouped[anim]
        )
        anim_blocks.append(
            "{\n"
            f'"frames": [{frame_entries}],\n'
            f'"loop": {"true" if loop else "false"},\n'
            f'"name": &"{anim}",\n'
            f'"speed": {fps}\n'
            "}"
        )
    load_steps = 2 + idx
    content = (
        f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]\n\n'
        f'[ext_resource type="Texture2D" path="res://{sheet_rel}" id="1_sheet"]\n\n'
        + "\n".join(subs)
        + "\n[resource]\nanimations = ["
        + ", ".join(anim_blocks)
        + "]\n"
    )
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(content, encoding="utf-8")
    print("wrote", out_path.relative_to(ROOT))


def main():
    SHEETS.mkdir(parents=True, exist_ok=True)
    ARMOR.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)
    RES.mkdir(parents=True, exist_ok=True)

    layer_sheets = {key: Image.new("RGBA", (MAX_COLS * W, len(ANIMS) * H), (0, 0, 0, 0)) for key in LAYERS}
    metal_sheets = {key: Image.new("RGBA", (MAX_COLS * W, len(ANIMS) * H), (0, 0, 0, 0)) for key in ARMOR_KINDS}
    wood_sheets = {key: Image.new("RGBA", (MAX_COLS * W, len(ANIMS) * H), (0, 0, 0, 0)) for key in ARMOR_KINDS}
    legacy = {}
    # Armor overlays/icons are owned by gen_armor_visuals.py. This script still
    # builds metal/wood fills for legacy per-frame snapshots only.

    for row, (anim, frames, _fps, _loop) in enumerate(ANIMS):
        for i in range(frames):
            p = pose(anim, i, frames)
            body, body_fill = draw_body(p)
            hair_b = draw_hair_back(p)
            hair_f = draw_hair_front(p)
            shirt = draw_shirt(p)
            pants = draw_pants(p)
            shoes = draw_shoes(p)
            composed = blank()
            for layer in (hair_b, body, pants, shoes, shirt, hair_f):
                blit_opaque(layer, composed)
            fill = blank()
            blit_opaque(body_fill, fill)
            blit_opaque(shirt, fill)
            blit_opaque(pants, fill)
            blit_opaque(shoes, fill)
            blit_opaque(hair_b, fill)
            blit_opaque(hair_f, fill)
            helm = draw_helmet(p, fill)
            chest = draw_chest(p, fill)
            legs = draw_legs(p, fill)
            whelm = draw_helmet(p, fill, WOOD_HELM_PAL)
            wchest = draw_chest(p, fill, WOOD_CHEST_PAL)
            wlegs = draw_legs(p, fill, WOOD_LEG_PAL)

            x, y = i * W, row * H
            layer_sheets["body"].paste(body, (x, y))
            layer_sheets["hair_back"].paste(hair_b, (x, y))
            layer_sheets["hair_front"].paste(hair_f, (x, y))
            layer_sheets["shirt"].paste(shirt, (x, y))
            layer_sheets["pants"].paste(pants, (x, y))
            layer_sheets["shoes"].paste(shoes, (x, y))
            layer_sheets["composed"].paste(composed, (x, y))
            metal_sheets["helmet"].paste(helm, (x, y))
            metal_sheets["chest"].paste(chest, (x, y))
            metal_sheets["legs"].paste(legs, (x, y))
            wood_sheets["helmet"].paste(whelm, (x, y))
            wood_sheets["chest"].paste(wchest, (x, y))
            wood_sheets["legs"].paste(wlegs, (x, y))

            if anim == "idle" and i == 0:
                legacy["player_idle"] = composed
                legacy["helmet_idle"] = helm
                legacy["chest_idle"] = chest
                legacy["legs_idle"] = legs
            if anim == "walk" and i == 0:
                legacy["player_walk_a"] = composed
                legacy["helmet_walk_a"] = helm
                legacy["chest_walk_a"] = chest
                legacy["legs_walk_a"] = legs
            if anim == "walk" and i == 3:
                legacy["player_walk_b"] = composed
                legacy["helmet_walk_b"] = helm
                legacy["chest_walk_b"] = chest
                legacy["legs_walk_b"] = legs
            if anim == "run" and i == 0:
                legacy["player_run_a"] = composed
                legacy["helmet_run_a"] = helm
                legacy["chest_run_a"] = chest
                legacy["legs_run_a"] = legs
            if anim == "run" and i == 3:
                legacy["player_run_b"] = composed
                legacy["helmet_run_b"] = helm
                legacy["chest_run_b"] = chest
                legacy["legs_run_b"] = legs
            if anim == "jump" and i == 0:
                legacy["player_jump"] = composed
                legacy["helmet_jump"] = helm
                legacy["chest_jump"] = chest
                legacy["legs_jump"] = legs
            if anim == "fall" and i == 0:
                legacy["player_fall"] = composed
                legacy["helmet_fall"] = helm
                legacy["chest_fall"] = chest
                legacy["legs_fall"] = legs
            if anim == "use_mine" and i == 2:
                legacy["player_use_tool"] = composed
                legacy["helmet_use_tool"] = helm
                legacy["chest_use_tool"] = chest
                legacy["legs_use_tool"] = legs
            if anim == "crouch_idle" and i == 0:
                legacy["player_crouch_idle"] = composed
                legacy["helmet_crouch_idle"] = helm
                legacy["chest_crouch_idle"] = chest
                legacy["legs_crouch_idle"] = legs
            if anim == "crouch_walk" and i == 0:
                legacy["player_crouch_walk_a"] = composed
                legacy["helmet_crouch_walk_a"] = helm
                legacy["chest_crouch_walk_a"] = chest
                legacy["legs_crouch_walk_a"] = legs
            if anim == "crouch_walk" and i == 2:
                legacy["player_crouch_walk_b"] = composed
                legacy["helmet_crouch_walk_b"] = helm
                legacy["chest_crouch_walk_b"] = chest
                legacy["legs_crouch_walk_b"] = legs

    for key, img in layer_sheets.items():
        path = SHEETS / f"{key}.png"
        save(img, path)
        print("wrote", path.relative_to(ROOT))
    for key, img in metal_sheets.items():
        path = SHEETS / f"armor_metal_{key}.png"
        save(img, path)
        print("wrote", path.relative_to(ROOT))
    # Unique per-material armor sheets/icons/frames: python terraria/tools/gen_armor_visuals.py

    for stem, img in legacy.items():
        if stem.startswith("player_"):
            save(img, PLAYER / f"{stem}.png")
        else:
            save(img, ARMOR / f"{stem}.png")

    save(icon("helmet"), ICONS / "test_helmet.png")
    save(icon("chest"), ICONS / "test_chestplate.png")
    save(icon("legs"), ICONS / "test_leggings.png")

    frames_map = {
        "body_frames.tres": "assets/player/sheets/body.png",
        "hair_back_frames.tres": "assets/player/sheets/hair_back.png",
        "hair_front_frames.tres": "assets/player/sheets/hair_front.png",
        "shirt_frames.tres": "assets/player/sheets/shirt.png",
        "pants_frames.tres": "assets/player/sheets/pants.png",
        "shoes_frames.tres": "assets/player/sheets/shoes.png",
        "player_frames.tres": "assets/player/sheets/composed.png",
        "armor_helmet_frames.tres": "assets/player/sheets/armor_metal_helmet.png",
        "armor_chest_frames.tres": "assets/player/sheets/armor_metal_chest.png",
        "armor_legs_frames.tres": "assets/player/sheets/armor_metal_legs.png",
    }
    for fname, rel in frames_map.items():
        write_spriteframes(fname, rel, RES / fname)
    print("sheets", MAX_COLS * W, "x", len(ANIMS) * H, "anims", len(ANIMS))


if __name__ == "__main__":
    main()
