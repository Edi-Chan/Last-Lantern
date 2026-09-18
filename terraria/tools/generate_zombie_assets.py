#!/usr/bin/env python3
"""Pixelgenaue Zombie-Sprites und SFX fuer Last Lantern. Kein Anti-Aliasing."""

from __future__ import annotations

import array
import math
import os
import struct
import wave
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITE_DIR = os.path.join(ROOT, "assets", "enemies", "zombie")
AUDIO_DIR = os.path.join(ROOT, "audio", "sfx")
FRAMES_PATH = os.path.join(ROOT, "resources", "enemies", "zombie_frames.tres")

W, H = 48, 64


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: str, w: int, h: int, buf: bytearray) -> None:
    raw = bytearray()
    row = w * 4
    for y in range(h):
        raw.append(0)
        raw.extend(buf[y * row : (y + 1) * row])
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", ihdr))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))


def new_buf() -> bytearray:
    return bytearray(W * H * 4)


def pset(buf: bytearray, x: int, y: int, c: tuple[int, int, int, int]) -> None:
    if c[3] <= 0 or x < 0 or y < 0 or x >= W or y >= H:
        return
    i = (y * W + x) * 4
    buf[i] = c[0]
    buf[i + 1] = c[1]
    buf[i + 2] = c[2]
    buf[i + 3] = c[3]


def pget(buf: bytearray, x: int, y: int) -> tuple[int, int, int, int]:
    if x < 0 or y < 0 or x >= W or y >= H:
        return (0, 0, 0, 0)
    i = (y * W + x) * 4
    return (buf[i], buf[i + 1], buf[i + 2], buf[i + 3])


def fill_rect(
    buf: bytearray,
    x: int,
    y: int,
    w: int,
    h: int,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    hi: tuple[int, int, int, int] | None = None,
    sh: tuple[int, int, int, int] | None = None,
) -> None:
    for dy in range(h):
        for dx in range(w):
            px, py = x + dx, y + dy
            col = fill
            if outline is not None and (dx == 0 or dy == 0 or dx == w - 1 or dy == h - 1):
                col = outline
            elif hi is not None and dx == 1 and dy > 0 and dy < h - 1:
                col = hi
            elif sh is not None and dx == w - 2 and dy > 0 and dy < h - 1:
                col = sh
            pset(buf, px, py, col)


def stamp_hole(buf: bytearray, x: int, y: int) -> None:
    pset(buf, x, y, (0, 0, 0, 0))


PAL_NORMAL = {
    "out": (22, 17, 14, 255),
    "skin": (168, 170, 154, 255),
    "skin_hi": (196, 196, 180, 255),
    "skin_sh": (132, 136, 122, 255),
    "skin_sick": (150, 158, 138, 255),
    "hair": (46, 40, 34, 255),
    "hair_d": (28, 24, 20, 255),
    "shirt": (90, 82, 70, 255),
    "shirt_hi": (114, 104, 90, 255),
    "shirt_sh": (66, 60, 52, 255),
    "shirt_dirt": (74, 68, 54, 255),
    "pants": (50, 54, 60, 255),
    "pants_hi": (64, 68, 74, 255),
    "pants_sh": (36, 40, 46, 255),
    "shoe": (44, 38, 32, 255),
    "shoe_d": (30, 26, 22, 255),
    "eye": (26, 22, 20, 255),
    "eye_in": (40, 32, 30, 255),
    "mouth": (72, 44, 42, 255),
    "wound": (110, 78, 74, 255),
    "nail": (90, 84, 78, 255),
}

PAL_DARK = {
    "out": (6, 4, 8, 255),
    "skin": (46, 42, 54, 255),
    "skin_hi": (64, 56, 74, 255),
    "skin_sh": (28, 24, 36, 255),
    "skin_sick": (40, 32, 52, 255),
    "hair": (10, 8, 14, 255),
    "hair_d": (4, 3, 6, 255),
    "shirt": (20, 16, 26, 255),
    "shirt_hi": (34, 26, 42, 255),
    "shirt_sh": (12, 10, 16, 255),
    "shirt_dirt": (16, 12, 22, 255),
    "pants": (14, 12, 18, 255),
    "pants_hi": (24, 20, 30, 255),
    "pants_sh": (8, 6, 12, 255),
    "shoe": (8, 6, 10, 255),
    "shoe_d": (4, 3, 6, 255),
    "eye": (28, 8, 12, 255),
    "eye_in": (186, 36, 58, 255),
    "mouth": (48, 16, 28, 255),
    "wound": (72, 18, 32, 255),
    "nail": (70, 40, 52, 255),
    "glow": (210, 64, 88, 255),
    "glow_core": (255, 150, 164, 255),
    "violet": (48, 24, 64, 255),
}


def draw_arm(buf, x, y, length, swing, pal, front: bool, grab: bool = False) -> None:
    # swing > 0 streckt den Arm nach vorn (rechts), < 0 nach hinten.
    out, fill, hi, sh = pal["out"], pal["skin"], pal["skin_hi"], pal["skin_sh"]
    w = 4 if front else 3
    # Oberarm
    fill_rect(buf, x, y, w, 7, fill, out, hi if front else None, sh)
    # Unterarm folgt dem Swing
    ux = x + (2 if swing > 0 else (-1 if swing < 0 else 0))
    uy = y + 6
    uw = w + (1 if abs(swing) >= 3 else 0)
    uh = max(6, length - 7)
    if swing >= 4:
        ux += 2
        uy -= 1
        uw = 8
        uh = 4
        fill_rect(buf, ux, uy, uw, uh, fill, out, hi, sh)
        hx = ux + uw - 3
        hy = uy - 1 if grab else uy + 1
        fill_rect(buf, hx, hy, 4, 4, pal["skin_sick"], out, hi, sh)
        pset(buf, hx + 3, hy + 1, pal["nail"])
        pset(buf, hx + 3, hy + 3, pal["nail"])
        return
    if swing <= -3:
        fill_rect(buf, x - 5, y + 1, 6, 4, fill, out, hi, sh)
        fill_rect(buf, x - 7, y + 2, 4, 4, pal["skin_sick"], out, hi, sh)
        return
    fill_rect(buf, ux, uy, max(3, uw - 1), uh, fill, out, hi if front else None, sh)
    hx = ux + (2 if swing >= 0 else -1)
    hy = uy + uh - 3
    fill_rect(buf, hx, hy, 4, 4, pal["skin_sick"], out, hi, sh)
    pset(buf, hx + 3, hy + 1, pal["nail"])
    pset(buf, hx + 3, hy + 2, pal["nail"])


def draw_leg(buf, x, y, pal, lift: int, forward: int, front: bool) -> None:
    out = pal["out"]
    fill = pal["pants"]
    hi = pal["pants_hi"] if front else None
    sh = pal["pants_sh"]
    h = 16 - max(0, lift)
    ly = y + lift
    lx = x + forward
    fill_rect(buf, lx, ly, 6 if front else 5, h, fill, out, hi, sh)
    # Unterschenkel-Schmutz
    pset(buf, lx + 1, ly + h - 6, pal["shirt_dirt"])
    pset(buf, lx + 3, ly + h - 5, pal["shirt_dirt"])
    shoe_y = ly + h - 4
    shoe_x = lx - 1 + max(0, forward)
    fill_rect(buf, shoe_x, shoe_y, 7, 4, pal["shoe"], out, None, pal["shoe_d"])
    pset(buf, shoe_x + 5, shoe_y + 1, pal["shoe_d"])


def draw_head(buf, x, y, pal, dark: bool, tilt: int, mouth_open: int, hurt: bool, dead: bool) -> None:
    out = pal["out"]
    fill_rect(buf, x, y, 12, 12, pal["skin"], out, pal["skin_hi"], pal["skin_sh"])
    # Haar, unordentlich
    fill_rect(buf, x - 1, y - 3, 14, 5, pal["hair"], out)
    for dx, dy in ((0, -1), (2, -2), (5, -3), (8, -2), (11, -1), (12, 1), (1, 2), (10, 2)):
        pset(buf, x + dx, y + dy, pal["hair_d"])
    pset(buf, x + 3, y + 1, pal["hair"])
    pset(buf, x + 8, y, pal["hair_d"])
    # Augenhoehlen
    eye_y = y + 5 + tilt
    pset(buf, x + 3, eye_y, pal["eye"])
    pset(buf, x + 4, eye_y, pal["eye"])
    pset(buf, x + 8, eye_y, pal["eye"])
    pset(buf, x + 9, eye_y, pal["eye"])
    if dead:
        pset(buf, x + 3, eye_y, pal["eye"])
        pset(buf, x + 4, eye_y + 1, pal["eye"])
        pset(buf, x + 8, eye_y + 1, pal["eye"])
        pset(buf, x + 9, eye_y, pal["eye"])
    elif dark:
        pset(buf, x + 3, eye_y, pal["eye_in"])
        pset(buf, x + 4, eye_y, pal.get("glow", pal["eye_in"]))
        pset(buf, x + 8, eye_y, pal["eye_in"])
        pset(buf, x + 9, eye_y, pal.get("glow", pal["eye_in"]))
        pset(buf, x + 4, eye_y - 1, pal.get("glow_core", pal["eye_in"]))
        pset(buf, x + 9, eye_y - 1, pal.get("glow_core", pal["eye_in"]))
        pset(buf, x + 2, eye_y, pal.get("violet", pal["out"]))
        pset(buf, x + 10, eye_y, pal.get("violet", pal["out"]))
    else:
        pset(buf, x + 4, eye_y, pal["eye_in"])
        pset(buf, x + 9, eye_y, pal["eye_in"])
    # Wange / Verwesung
    pset(buf, x + 2, y + 8, pal["skin_sick"])
    pset(buf, x + 10, y + 7, pal["wound"])
    if hurt:
        pset(buf, x + 6, y + 8, pal["wound"])
    # Mund
    my = y + 9 + mouth_open
    pset(buf, x + 5, my, pal["mouth"])
    pset(buf, x + 6, my, pal["mouth"])
    pset(buf, x + 7, my, pal["mouth"])
    if mouth_open > 0:
        pset(buf, x + 6, my + 1, pal["out"])
    # Kiefer leicht vor
    pset(buf, x + 11, y + 8, pal["skin_sh"])


def draw_torso(buf, x, y, pal, dark: bool) -> None:
    out = pal["out"]
    fill_rect(buf, x, y, 14, 17, pal["shirt"], out, pal["shirt_hi"], pal["shirt_sh"])
    # Kragen / Riss
    fill_rect(buf, x + 4, y, 6, 3, pal["skin_sick"], out, pal["skin_hi"], pal["skin_sh"])
    pset(buf, x + 3, y + 2, pal["shirt_dirt"])
    pset(buf, x + 10, y + 3, pal["shirt_dirt"])
    pset(buf, x + 2, y + 8, pal["shirt_dirt"])
    pset(buf, x + 11, y + 10, pal["shirt_sh"])
    pset(buf, x + 5, y + 12, pal["out"])
    pset(buf, x + 6, y + 13, pal["out"])
    pset(buf, x + 7, y + 12, pal["shirt_dirt"])
    pset(buf, x + 8, y + 15, pal["out"])
    pset(buf, x + 1, y + 14, pal["shirt_dirt"])
    # leichte Verletzung an der Seite
    pset(buf, x + 12, y + 7, pal["wound"])
    pset(buf, x + 12, y + 8, pal["skin_sh"])
    if dark:
        pset(buf, x + 6, y + 6, pal.get("violet", pal["shirt_sh"]))
        pset(buf, x + 7, y + 9, pal.get("violet", pal["shirt_sh"]))
        pset(buf, x + 4, y + 11, pal["shirt_sh"])


def draw_zombie(pose: dict, dark: bool = False) -> bytearray:
    pal = PAL_DARK if dark else PAL_NORMAL
    buf = new_buf()
    fallen = pose.get("fallen", 0)

    if fallen >= 2:
        # Liegend, Kopf rechts.
        y = 52 + min(fallen, 3)
        fill_rect(buf, 8, y + 6, 28, 6, pal["shirt"], pal["out"], pal["shirt_hi"], pal["shirt_sh"])
        fill_rect(buf, 6, y + 7, 8, 5, pal["pants"], pal["out"], pal["pants_hi"], pal["pants_sh"])
        fill_rect(buf, 4, y + 8, 6, 4, pal["shoe"], pal["out"])
        draw_head(buf, 32, y, pal, dark, 1, 1, False, True)
        fill_rect(buf, 20, y + 2, 10, 4, pal["skin"], pal["out"], pal["skin_hi"], pal["skin_sh"])
        if fallen >= 3:
            pset(buf, 36, y + 5, pal["mouth"])
        return buf

    hunch = pose.get("hunch", 3)
    bob = pose.get("bob", 0)
    base_x = 24
    foot_y = 63 + pose.get("sink", 0)

    # Beine zuerst
    draw_leg(
        buf,
        base_x - 6 + hunch // 2,
        foot_y - 18 + bob,
        pal,
        pose.get("leg_back_lift", 0),
        pose.get("leg_back_fwd", -1),
        False,
    )
    draw_leg(
        buf,
        base_x + 1 + hunch // 2,
        foot_y - 18 + bob,
        pal,
        pose.get("leg_front_lift", 0),
        pose.get("leg_front_fwd", 1),
        True,
    )

    torso_x = base_x - 7 + hunch + pose.get("torso_x", 0)
    torso_y = foot_y - 35 + bob + pose.get("torso_y", 0)
    # Hinterer Arm
    draw_arm(
        buf,
        torso_x - 2 + pose.get("arm_back_x", 0),
        torso_y + 2 + pose.get("arm_back_y", 0),
        16,
        pose.get("arm_back_swing", 1),
        pal,
        False,
    )
    draw_torso(buf, torso_x, torso_y, pal, dark)
    # Vorderer Arm
    draw_arm(
        buf,
        torso_x + 12 + pose.get("arm_front_x", 0),
        torso_y + 1 + pose.get("arm_front_y", 0),
        16 + pose.get("arm_len", 0),
        pose.get("arm_front_swing", 2),
        pal,
        True,
        grab=pose.get("grab", False),
    )

    head_x = torso_x + 3 + hunch + pose.get("head_x", 0)
    head_y = torso_y - 11 + pose.get("head_y", 0)
    draw_head(
        buf,
        head_x,
        head_y,
        pal,
        dark,
        pose.get("tilt", 0),
        pose.get("mouth", 0),
        pose.get("hurt", False),
        pose.get("dead", False),
    )
    return buf


def pose_idle(i: int) -> dict:
    bob = (0, 1, 0, 0)[i]
    head = (0, 1, 0, -1)[i]
    swing = (2, 2, 1, 2)[i]
    return {
        "hunch": 3,
        "bob": bob,
        "head_y": head,
        "tilt": 0 if i != 2 else 1,
        "arm_front_swing": swing,
        "arm_back_swing": 1,
        "mouth": 1 if i == 1 else 0,
    }


def pose_walk(i: int) -> dict:
    # Unregelmaessiges Schlurfen: langer linker Zug, kurzer rechter.
    cycle = [
        {"leg_front_lift": 0, "leg_front_fwd": 3, "leg_back_lift": 2, "leg_back_fwd": -2, "bob": 1, "arm_front_swing": 3, "arm_back_swing": 0},
        {"leg_front_lift": 0, "leg_front_fwd": 4, "leg_back_lift": 1, "leg_back_fwd": -3, "bob": 0, "arm_front_swing": 2, "arm_back_swing": 1},
        {"leg_front_lift": 2, "leg_front_fwd": 0, "leg_back_lift": 0, "leg_back_fwd": 1, "bob": 1, "arm_front_swing": 1, "arm_back_swing": 2},
        {"leg_front_lift": 3, "leg_front_fwd": -1, "leg_back_lift": 0, "leg_back_fwd": 3, "bob": 0, "arm_front_swing": 0, "arm_back_swing": 2},
        {"leg_front_lift": 1, "leg_front_fwd": 1, "leg_back_lift": 0, "leg_back_fwd": 2, "bob": 1, "arm_front_swing": 2, "arm_back_swing": 1},
        {"leg_front_lift": 0, "leg_front_fwd": 2, "leg_back_lift": 1, "leg_back_fwd": -1, "bob": 0, "arm_front_swing": 3, "arm_back_swing": 0},
    ][i]
    cycle.update({"hunch": 4, "head_x": 1 if i % 2 == 0 else 0, "mouth": 1 if i in (1, 4) else 0})
    return cycle


def pose_attack(i: int) -> dict:
    frames = [
        {"hunch": 3, "arm_front_swing": 1, "arm_back_swing": 1, "head_x": 0, "grab": False},
        {"hunch": 2, "arm_front_swing": -3, "arm_back_swing": -1, "head_x": -1, "torso_x": -1, "grab": False},
        {"hunch": 2, "arm_front_swing": -4, "arm_back_swing": -2, "head_x": -1, "torso_x": -2, "mouth": 1},
        {"hunch": 5, "arm_front_swing": 6, "arm_back_swing": 3, "head_x": 2, "torso_x": 2, "grab": True, "mouth": 1},
        {"hunch": 5, "arm_front_swing": 5, "arm_back_swing": 2, "head_x": 1, "torso_x": 1, "grab": True},
        {"hunch": 3, "arm_front_swing": 2, "arm_back_swing": 1, "head_x": 0, "torso_x": 0},
    ]
    return frames[i]


def pose_hurt(i: int) -> dict:
    frames = [
        {"hunch": 2, "torso_x": -2, "head_x": -1, "hurt": True, "arm_front_swing": -1, "bob": 0},
        {"hunch": 1, "torso_x": -3, "head_x": -2, "hurt": True, "arm_front_swing": -2, "bob": 1, "mouth": 1},
        {"hunch": 3, "torso_x": -1, "head_x": 0, "hurt": False, "arm_front_swing": 1, "bob": 0},
    ]
    return frames[i]


def pose_death(i: int) -> dict:
    if i >= 5:
        return {"fallen": 2 + (1 if i >= 6 else 0), "dead": True}
    frames = [
        {"hunch": 2, "torso_x": -2, "hurt": True, "mouth": 1, "arm_front_swing": -2},
        {"hunch": 4, "sink": 4, "torso_y": 2, "head_y": 2, "leg_front_lift": 3, "mouth": 1, "dead": False},
        {"hunch": 6, "sink": 8, "torso_y": 4, "head_x": 3, "head_y": 3, "leg_front_lift": 5, "mouth": 1, "dead": True},
        {"hunch": 7, "sink": 12, "torso_y": 6, "head_x": 4, "head_y": 5, "arm_front_swing": 4, "dead": True},
        {"hunch": 8, "sink": 16, "torso_y": 8, "head_x": 6, "head_y": 6, "dead": True, "fallen": 1},
    ]
    return frames[i]


def pose_transform(i: int) -> dict:
    frames = [
        {"hunch": 3, "mouth": 0, "arm_front_swing": 2},
        {"hunch": 4, "mouth": 1, "head_y": -1, "arm_front_swing": 1},
        {"hunch": 5, "mouth": 1, "head_y": 0, "torso_x": 1},
        {"hunch": 4, "mouth": 1, "arm_front_swing": 3},
        {"hunch": 4, "mouth": 0, "arm_front_swing": 3, "head_x": 1},
    ]
    return frames[i]


def pose_dark_walk(i: int) -> dict:
    p = pose_walk(i)
    p["hunch"] = 5
    p["arm_front_swing"] = min(4, p.get("arm_front_swing", 2) + 1)
    p["head_x"] = 1
    return p


def pose_dark_attack(i: int) -> dict:
    p = pose_attack(i)
    p["hunch"] = p.get("hunch", 3) + 1
    p["mouth"] = 1
    return p


def draw_smoke_particle(size: int = 16) -> bytearray:
    buf = bytearray(size * size * 4)
    cx = cy = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            dx = x - cx
            dy = y - cy
            d = math.sqrt(dx * dx + dy * dy) / (size * 0.48)
            if d >= 1.0:
                continue
            # Harte Pixelstufen, kein weicher Verlauf.
            if d < 0.28:
                a, col = 200, (18, 14, 22)
            elif d < 0.52:
                a, col = 150, (12, 10, 16)
            elif d < 0.78:
                a, col = 90, (8, 6, 12)
            else:
                a, col = 40, (6, 4, 10)
            i = (y * size + x) * 4
            buf[i] = col[0]
            buf[i + 1] = col[1]
            buf[i + 2] = col[2]
            buf[i + 3] = a
    return buf


def draw_ember(size: int = 6) -> bytearray:
    buf = bytearray(size * size * 4)
    cx = cy = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy)
            if d > 2.2:
                continue
            if d < 0.8:
                col, a = (180, 40, 70), 220
            elif d < 1.6:
                col, a = (90, 20, 80), 140
            else:
                col, a = (40, 12, 50), 70
            i = (y * size + x) * 4
            buf[i] = col[0]
            buf[i + 1] = col[1]
            buf[i + 2] = col[2]
            buf[i + 3] = a
    return buf


def write_small_png(path: str, size: int, buf: bytearray) -> None:
    raw = bytearray()
    row = size * 4
    for y in range(size):
        raw.append(0)
        raw.extend(buf[y * row : (y + 1) * row])
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n")
        fh.write(chunk(b"IHDR", ihdr))
        fh.write(chunk(b"IDAT", zlib.compress(bytes(raw), 9)))
        fh.write(chunk(b"IEND", b""))


def write_wav(path: str, samples: list[float], rate: int = 22050) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = array.array("h", [int(max(-1.0, min(1.0, s)) * 32767) for s in samples])
    with wave.open(path, "w") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(rate)
        fh.writeframes(data.tobytes())


def env(t: float, attack: float, hold: float, release: float) -> float:
    if t < attack:
        return t / max(attack, 1e-6)
    if t < attack + hold:
        return 1.0
    if t < attack + hold + release:
        return 1.0 - (t - attack - hold) / max(release, 1e-6)
    return 0.0


def noise(i: int, seed: int = 1) -> float:
    x = (i * 1103515245 + 12345 + seed * 9973) & 0x7FFFFFFF
    return (x / 0x7FFFFFFF) * 2.0 - 1.0


def make_sfx() -> None:
    rate = 22050

    def tone(dur: float, freq: float, amp: float, n_amt: float = 0.2, slide: float = 0.0, seed: int = 1) -> list[float]:
        n = int(dur * rate)
        out = []
        for i in range(n):
            t = i / rate
            f = freq + slide * t
            s = math.sin(2 * math.pi * f * t) * amp
            s += noise(i, seed) * n_amt * amp
            s *= env(t, 0.02, dur * 0.45, dur * 0.5)
            out.append(s)
        return out

    write_wav(os.path.join(AUDIO_DIR, "zombie_idle.wav"), tone(0.55, 92, 0.22, 0.35, -12, 3))
    growl = tone(0.4, 110, 0.28, 0.4, 40, 7)
    write_wav(os.path.join(AUDIO_DIR, "zombie_detect.wav"), growl)
    atk = []
    n = int(0.28 * rate)
    for i in range(n):
        t = i / rate
        s = noise(i, 11) * 0.35 * env(t, 0.01, 0.05, 0.2)
        s += math.sin(2 * math.pi * (70 - 80 * t) * t) * 0.3 * env(t, 0.005, 0.04, 0.18)
        atk.append(s)
    write_wav(os.path.join(AUDIO_DIR, "zombie_attack.wav"), atk)
    hurt = []
    n = int(0.18 * rate)
    for i in range(n):
        t = i / rate
        s = noise(i, 21) * 0.4 * env(t, 0.005, 0.03, 0.12)
        s += math.sin(2 * math.pi * 180 * t) * 0.18 * env(t, 0.005, 0.02, 0.1)
        hurt.append(s)
    write_wav(os.path.join(AUDIO_DIR, "zombie_hurt.wav"), hurt)
    death = tone(0.85, 70, 0.3, 0.45, -50, 13)
    write_wav(os.path.join(AUDIO_DIR, "zombie_death.wav"), death)
    rumble = []
    n = int(1.8 * rate)
    for i in range(n):
        t = i / rate
        s = math.sin(2 * math.pi * 38 * t) * 0.12
        s += math.sin(2 * math.pi * 52 * t) * 0.06
        s += noise(i, 31) * 0.05
        rumble.append(s * 0.7)
    write_wav(os.path.join(AUDIO_DIR, "zombie_darkness.wav"), rumble)


ANIMATIONS = [
    ("idle", [pose_idle(i) for i in range(4)], False, 4.0, True),
    ("walk", [pose_walk(i) for i in range(6)], False, 5.0, True),
    ("attack", [pose_attack(i) for i in range(6)], False, 10.0, False),
    ("hurt", [pose_hurt(i) for i in range(3)], False, 14.0, False),
    ("death", [pose_death(i) for i in range(8)], False, 8.0, False),
    ("transform", [pose_transform(i) for i in range(5)], False, 8.0, False),
    ("dark_idle", [pose_idle(i) | {"hunch": 4} for i in range(4)], True, 5.0, True),
    ("dark_walk", [pose_dark_walk(i) for i in range(6)], True, 8.0, True),
    ("dark_attack", [pose_dark_attack(i) for i in range(6)], True, 13.0, False),
    ("dark_hurt", [pose_hurt(i) | {"hunch": 3} for i in range(3)], True, 14.0, False),
    ("dark_death", [pose_death(i) for i in range(8)], True, 8.0, False),
]


def write_frames() -> list[tuple[str, str]]:
    os.makedirs(SPRITE_DIR, exist_ok=True)
    saved: list[tuple[str, str]] = []
    for name, poses, dark, _speed, _loop in ANIMATIONS:
        for i, pose in enumerate(poses):
            if name == "transform":
                # Erst normal, zuletzt finster.
                use_dark = dark or i >= 3
            else:
                use_dark = dark
            buf = draw_zombie(pose, use_dark)
            fname = f"{name}_{i}.png"
            path = os.path.join(SPRITE_DIR, fname)
            write_png(path, W, H, buf)
            saved.append((name, fname))
    write_small_png(os.path.join(SPRITE_DIR, "smoke_puff.png"), 16, draw_smoke_particle(16))
    write_small_png(os.path.join(SPRITE_DIR, "dark_ember.png"), 6, draw_ember(6))
    return saved


def write_sprite_frames() -> None:
    lines = ["[gd_resource type=\"SpriteFrames\" load_steps=100 format=3]\n"]
    ext_id = 1
    ids: dict[str, str] = {}
    for name, poses, _dark, _speed, _loop in ANIMATIONS:
        for i in range(len(poses)):
            fname = f"{name}_{i}.png"
            key = f"{name}_{i}"
            rid = f"{ext_id}_{key.replace('_', '')}"
            ids[key] = rid
            lines.append(
                f'[ext_resource type="Texture2D" path="res://assets/enemies/zombie/{fname}" id="{rid}"]'
            )
            ext_id += 1
    lines.append("")
    lines.append("[resource]")
    lines.append("animations = [")
    anim_blocks = []
    for name, poses, _dark, speed, loop in ANIMATIONS:
        frames = []
        for i in range(len(poses)):
            key = f"{name}_{i}"
            frames.append(
                "{\n"
                '"duration": 1.0,\n'
                f'"texture": ExtResource("{ids[key]}")\n'
                "}"
            )
        loop_s = "true" if loop else "false"
        block = (
            "{\n"
            '"frames": [' + ", ".join(frames) + "],\n"
            f'"loop": {loop_s},\n'
            f'"name": &"{name}",\n'
            f'"speed": {speed}\n'
            "}"
        )
        anim_blocks.append(block)
    lines.append(",\n".join(anim_blocks))
    lines.append("]")
    os.makedirs(os.path.dirname(FRAMES_PATH), exist_ok=True)
    with open(FRAMES_PATH, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


def main() -> None:
    write_frames()
    write_sprite_frames()
    make_sfx()
    print("Zombie assets written.")


if __name__ == "__main__":
    main()
