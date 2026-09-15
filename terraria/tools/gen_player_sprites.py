#!/usr/bin/env python3
"""Original 40x56 side-view player + armor overlay frames. No third-party art."""

from pathlib import Path

from PIL import Image

W, H = 40, 56
ROOT = Path(__file__).resolve().parents[1]
PLAYER = ROOT / "assets" / "player"
ARMOR = ROOT / "assets" / "player" / "armor"
ICONS = ROOT / "assets" / "items" / "equipment"

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


def pose(name):
    crouch = name.startswith("crouch")
    jump = name == "jump"
    fall = name == "fall"
    tool = name == "use_tool"
    head_y = 18 if crouch else 11
    if jump:
        head_y = 9
    if fall:
        head_y = 10
    torso_top = head_y + 8
    torso_bot = 40 if crouch else 35
    if jump:
        torso_bot = 33
    if fall:
        torso_bot = 34
    foot_y = 55
    if jump:
        foot_y = 52
    if fall:
        foot_y = 54

    front_dx = 0
    back_dx = 0
    arm_front = (0, 0)
    arm_back = (0, 0)
    if name in ("walk_a", "crouch_walk_a"):
        front_dx, back_dx = 3, -3
        arm_front, arm_back = (2, 1), (-2, 1)
    elif name in ("walk_b", "crouch_walk_b"):
        front_dx, back_dx = -3, 3
        arm_front, arm_back = (-2, 1), (2, 1)
    elif name == "run_a":
        front_dx, back_dx = 5, -4
        arm_front, arm_back = (3, 2), (-3, 2)
    elif name == "run_b":
        front_dx, back_dx = -4, 5
        arm_front, arm_back = (-3, 2), (3, 2)
    elif jump:
        front_dx, back_dx = 2, -2
        arm_front, arm_back = (3, -3), (-2, -1)
    elif fall:
        front_dx, back_dx = 3, -3
        arm_front, arm_back = (4, 2), (-3, 1)
    elif tool:
        arm_front, arm_back = (6, -4), (-1, 1)

    return {
        "head_y": head_y,
        "torso_top": torso_top,
        "torso_bot": torso_bot,
        "foot_y": foot_y,
        "front_dx": front_dx,
        "back_dx": back_dx,
        "arm_front": arm_front,
        "arm_back": arm_back,
        "crouch": crouch,
        "tool": tool,
        "cx": 20,
    }


def draw_base(p):
    img = blank()
    fill = blank()
    cx = p["cx"]
    hy = p["head_y"]
    # Profile head: back (left) hair mass, face and nose on the right.
    oval(fill, cx + 1, hy + 1, 6, 8, SKIN)
    rect(fill, cx + 2, hy - 2, cx + 8, hy + 7, SKIN)
    oval(fill, cx + 4, hy + 1, 5, 7, SKIN)
    oval(fill, cx - 2, hy, 6, 7, HAIR)
    rect(fill, cx - 7, hy - 2, cx + 1, hy + 6, HAIR)
    rect(fill, cx - 6, hy - 7, cx + 4, hy, HAIR)
    rect(fill, cx - 5, hy - 8, cx + 3, hy - 2, HAIR_D)
    # Face stays skin; cut hair off the front.
    rect(fill, cx + 3, hy - 1, cx + 9, hy + 6, SKIN)
    oval(fill, cx - 4, hy + 2, 2, 2, SKIN_D)
    # Neck and slim side torso.
    rect(fill, cx, hy + 8, cx + 3, p["torso_top"] + 1, SKIN)
    rect(fill, cx - 3, p["torso_top"], cx + 4, p["torso_bot"], SHIRT)
    rect(fill, cx - 2, p["torso_top"] + 1, cx + 3, p["torso_bot"], SHIRT)
    rect(fill, cx - 3, p["torso_top"], cx - 2, p["torso_bot"] - 2, SHIRT_D)
    # Rear arm mostly hidden behind the torso.
    ax, ay = p["arm_back"]
    arm_x = cx - 5 + ax
    arm_y0 = p["torso_top"] + 2 + ay
    arm_y1 = arm_y0 + (8 if p["crouch"] else 11)
    rect(fill, arm_x, arm_y0, arm_x + 2, arm_y1, SHIRT_D)
    rect(fill, arm_x, arm_y1, arm_x + 2, arm_y1 + 3, SKIN_D)
    # Visible front arm on the facing side.
    fx, fy = p["arm_front"]
    far_x = cx + 4 + fx
    far_y0 = p["torso_top"] + 1 + fy
    if p["tool"]:
        rect(fill, cx + 3, far_y0, far_x + 2, far_y0 + 3, SHIRT)
        rect(fill, far_x + 1, far_y0 - 1, far_x + 5, far_y0 + 2, SKIN)
    else:
        far_y1 = far_y0 + (7 if p["crouch"] else 10)
        rect(fill, far_x, far_y0, far_x + 3, far_y1, SHIRT)
        rect(fill, far_x + 1, far_y1, far_x + 3, far_y1 + 4, SKIN)
    hip = p["torso_bot"]
    foot = p["foot_y"]
    back_x = cx - 3 + p["back_dx"]
    front_x = cx + 1 + p["front_dx"]
    rect(fill, back_x, hip - 1, back_x + 3, foot - 3, PANTS_D)
    rect(fill, front_x, hip - 1, front_x + 4, foot - 3, PANTS)
    rect(fill, back_x - 1, foot - 2, back_x + 4, foot, SHOE)
    rect(fill, front_x - 1, foot - 2, front_x + 6, foot, SHOE)
    rect(fill, front_x + 4, foot - 1, front_x + 6, foot, SHOE_D)
    outline_from(fill, img)
    blit_opaque(fill, img)
    eye_x, eye_y = cx + 5, hy + 1
    px(img, eye_x, eye_y, EYE_W)
    px(img, eye_x + 1, eye_y, EYE)
    px(img, eye_x, eye_y + 1, EYE)
    px(img, cx + 8, hy + 3, SKIN_D)
    px(img, cx + 9, hy + 3, SKIN_D)
    px(img, cx + 9, hy + 4, SKIN)
    px(img, cx + 7, hy + 6, MOUTH)
    rect(img, cx - 1, hy - 7, cx + 4, hy - 3, HAIR)
    rect(img, cx - 4, hy - 6, cx + 1, hy - 2, HAIR_D)
    return img, fill


def mask_region(fill, colors):
    img = blank()
    for y in range(H):
        for x in range(W):
            if fill.getpixel((x, y))[:3] in colors:
                img.putpixel((x, y), fill.getpixel((x, y)))
    return img


def rgb(c):
    return c[:3]


SHIRT_RGB = {rgb(SHIRT), rgb(SHIRT_D)}
PANTS_RGB = {rgb(PANTS), rgb(PANTS_D), rgb(SHOE), rgb(SHOE_D)}
HAIR_RGB = {rgb(HAIR), rgb(HAIR_D)}
HEAD_SKIN_RGB = {rgb(SKIN), rgb(SKIN_D), rgb(EYE_W), rgb(EYE), rgb(MOUTH)}
BRONZE = (184, 128, 56, 255)
BRONZE_D = (128, 82, 34, 255)
BOOT = (58, 40, 30, 255)
BOOT_S = (92, 64, 44, 255)


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


def finish_layer(fill, outline_color):
    img = blank()
    outline_from(fill, img, outline_color)
    blit_opaque(fill, img)
    return img


def draw_helmet(p, base_fill):
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
        # Gesicht und Schädel, nicht den Hals unter hy+8.
        if tone in HEAD_SKIN_RGB and y <= hy + 7:
            return True
        return False

    pts = dilate_pts(collect_pts(base_fill, is_head), 1)
    # Helmkuppe 1 px hoeher, Visier und Nackenschutz etwas groesser als Haar.
    extra = []
    for x, y in list(pts):
        extra.append((x, max(0, y - 1)))
        extra.append((x, min(H - 1, y + 1)))
        extra.append((max(0, x - 1), y))
        extra.append((min(W - 1, x + 1), y))
    pts = set(pts)
    pts.update(extra)
    paint_points(fill, pts, HELM, HELM_D, HELM_S, cx)
    rect(fill, cx - 5, hy - 8, cx + 4, hy - 3, HELM_S)
    rect(fill, cx + 2, hy - 1, cx + 9, hy + 3, VISOR)
    rect(fill, cx - 2, hy + 6, cx + 4, hy + 9, HELM_D)
    px(fill, cx + 8, hy, HELM_S)
    px(fill, cx - 4, hy - 7, BRONZE)
    px(fill, cx + 3, hy - 7, BRONZE)
    return finish_layer(fill, HELM_O)


def draw_chest(p, base_fill):
    fill = blank()
    cx = p["cx"]
    top = p["torso_top"]
    bot = p["torso_bot"]

    def is_shirt(_x, y, pix):
        if rgb(pix) not in SHIRT_RGB:
            return False
        # Unterkante der Hose nicht mit Brustpanzer vollflaechig uebermalen,
        # aber das Shirt bis zur Huefte inkl. 1 px Ueberlappung decken.
        return y <= bot + 1

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
    paint_points(fill, pts, CHEST, CHEST_D, CHEST_S, cx)
    rect(fill, cx - 2, top + 2, cx + 3, top + 5, CHEST_S)
    rect(fill, cx - 4, bot - 1, cx + 5, bot + 1, BRONZE_D)
    rect(fill, cx - 3, bot, cx + 4, bot + 1, BRONZE)
    px(fill, cx - 2, top + 7, BRONZE)
    px(fill, cx + 3, top + 7, BRONZE)
    return finish_layer(fill, CHEST_O)


def draw_legs(p, base_fill):
    fill = blank()
    cx = p["cx"]
    hip = p["torso_bot"]
    foot = p["foot_y"]

    def is_legs(_x, y, pix):
        return rgb(pix) in PANTS_RGB and y >= hip - 2

    pts = dilate_pts(collect_pts(base_fill, is_legs), 1)
    extra = set()
    back_x = cx - 3 + p["back_dx"]
    front_x = cx + 1 + p["front_dx"]
    for x in range(back_x - 2, back_x + 5):
        for y in range(hip - 2, foot + 1):
            extra.add((x, y))
    for x in range(front_x - 2, front_x + 7):
        for y in range(hip - 2, foot + 1):
            extra.add((x, y))
    for x in range(cx - 5, cx + 6):
        for y in range(hip - 2, hip + 3):
            extra.add((x, y))
    pts = set(pts)
    pts.update((x, y) for x, y in extra if 0 <= x < W and 0 <= y < H)
    paint_points(fill, pts, LEG, LEG_D, LEG_S, cx)
    # Stiefel bis zur Fusszeile, Knieplatten extra breit.
    rect(fill, back_x - 2, foot - 3, back_x + 4, foot, BOOT)
    rect(fill, front_x - 2, foot - 3, front_x + 6, foot, BOOT)
    rect(fill, front_x - 1, foot - 2, front_x + 5, foot - 1, BOOT_S)
    knee_y = hip + 6
    rect(fill, front_x, knee_y, front_x + 4, knee_y + 2, BRONZE)
    rect(fill, back_x, hip + 5, back_x + 3, hip + 6, BRONZE_D)
    return finish_layer(fill, LEG_O)


def uncovered_count(base_fill, armor, colors, y_min=0, y_max=H - 1):
    n = 0
    for y in range(y_min, y_max + 1):
        for x in range(W):
            if rgb(base_fill.getpixel((x, y))) in colors and armor.getpixel((x, y))[3] == 0:
                n += 1
    return n


def icon(kind):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))

    def p(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16:
            img.putpixel((x, y), c)

    def r(x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                p(x, y, c)

    if kind == "helmet":
        r(2, 1, 13, 12, HELM_O)
        r(3, 2, 12, 11, HELM)
        r(4, 2, 11, 4, HELM_S)
        r(6, 6, 13, 9, VISOR)
        r(4, 11, 11, 13, HELM_D)
        p(4, 2, BRONZE)
        p(11, 2, BRONZE)
    elif kind == "chest":
        r(2, 2, 13, 14, CHEST_O)
        r(3, 3, 12, 13, CHEST)
        r(4, 4, 11, 6, CHEST_S)
        r(3, 12, 12, 14, BRONZE_D)
        r(4, 13, 11, 14, BRONZE)
        p(5, 8, BRONZE)
        p(10, 8, BRONZE)
        r(3, 3, 4, 11, CHEST_D)
    else:
        r(2, 2, 13, 14, LEG_O)
        r(3, 3, 7, 11, LEG)
        r(8, 3, 12, 11, LEG)
        r(3, 3, 4, 10, LEG_D)
        r(4, 7, 6, 9, BRONZE)
        r(9, 8, 11, 9, BRONZE)
        r(3, 12, 12, 14, BOOT)
        r(4, 12, 11, 13, BOOT_S)
    return img


FRAMES = {
    "idle": "idle",
    "walk_a": "walk_a",
    "walk_b": "walk_b",
    "run_a": "run_a",
    "run_b": "run_b",
    "jump": "jump",
    "fall": "fall",
    "use_tool": "use_tool",
    "crouch_idle": "crouch_idle",
    "crouch_walk_a": "crouch_walk_a",
    "crouch_walk_b": "crouch_walk_b",
}


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print("wrote", path.relative_to(ROOT))


def main():
    PLAYER.mkdir(parents=True, exist_ok=True)
    ARMOR.mkdir(parents=True, exist_ok=True)
    ICONS.mkdir(parents=True, exist_ok=True)
    leaks = []
    for pose_name, file_stem in FRAMES.items():
        p = pose(pose_name)
        _base, base_fill = draw_base(p)
        helmet = draw_helmet(p, base_fill)
        chest = draw_chest(p, base_fill)
        legs = draw_legs(p, base_fill)
        save(helmet, ARMOR / f"helmet_{file_stem}.png")
        save(chest, ARMOR / f"chest_{file_stem}.png")
        save(legs, ARMOR / f"legs_{file_stem}.png")
        hair_leak = uncovered_count(base_fill, helmet, HAIR_RGB)
        shirt_leak = uncovered_count(base_fill, chest, SHIRT_RGB)
        pants_leak = uncovered_count(base_fill, legs, PANTS_RGB)
        if hair_leak or shirt_leak or pants_leak:
            leaks.append((file_stem, hair_leak, shirt_leak, pants_leak))
    save(icon("helmet"), ICONS / "test_helmet.png")
    save(icon("chest"), ICONS / "test_chestplate.png")
    save(icon("legs"), ICONS / "test_leggings.png")
    if leaks:
        print("coverage leaks (hair, shirt, pants):")
        for row in leaks:
            print(" ", row)
    else:
        print("coverage ok: hair/shirt/pants fully covered on all frames")


if __name__ == "__main__":
    main()
