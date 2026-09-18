#!/usr/bin/env python3
"""Original synthesized SFX for Last Lantern. No third-party game samples."""

from __future__ import annotations

import math
import os
import random
import struct
import wave

RATE = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SFX = os.path.join(ROOT, "audio", "sfx")
AMB = os.path.join(ROOT, "audio", "ambient")


def clamp(v: float, lo: float = -1.0, hi: float = 1.0) -> float:
    return lo if v < lo else hi if v > hi else v


def env(t: float, attack: float, hold: float, release: float) -> float:
    if t < 0.0:
        return 0.0
    if t < attack:
        return t / max(attack, 1e-4)
    if t < attack + hold:
        return 1.0
    if t < attack + hold + release:
        return 1.0 - (t - attack - hold) / max(release, 1e-4)
    return 0.0


def noise(i: int, seed: int) -> float:
    x = (i * 1103515245 + 12345 + seed * 9973) & 0x7FFFFFFF
    return (x / 2147483647.0) * 2.0 - 1.0


def lowpass(samples: list[float], alpha: float) -> list[float]:
    out: list[float] = []
    acc = 0.0
    for s in samples:
        acc = acc + alpha * (s - acc)
        out.append(acc)
    return out


def highpass(samples: list[float], alpha: float) -> list[float]:
    lp = lowpass(samples, alpha)
    return [s - l for s, l in zip(samples, lp)]


def mix_tone(n: int, freq: float, amp: float, slide: float = 0.0, seed: int = 1) -> list[float]:
    out = [0.0] * n
    for i in range(n):
        t = i / RATE
        f = freq + slide * t
        out[i] = math.sin(2.0 * math.pi * f * t) * amp
        out[i] += noise(i, seed) * amp * 0.08
    return out


def write_wav(path: os.PathLike[str] | str, samples: list[float], loop: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max((abs(s) for s in samples), default=1.0)
    gain = 0.92 / peak if peak > 0.92 else 1.0
    with wave.open(str(path), "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(clamp(s * gain) * 32767.0)) for s in samples)
        wav.writeframes(frames)
    if loop:
        _write_import(path, loop_mode=1)


def _write_import(path: os.PathLike[str] | str, loop_mode: int = 0) -> None:
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    text = (
        "[remap]\n\n"
        'importer="wav"\n'
        'type="AudioStreamWAV"\n'
        f'path="res://.godot/imported/{os.path.basename(path)}.sample"\n\n'
        "[deps]\n\n"
        f'source_file="res://{rel}"\n'
        f'dest_files=["res://.godot/imported/{os.path.basename(path)}.sample"]\n\n'
        "[params]\n\n"
        "force/8_bit=false\n"
        "force/mono=false\n"
        "force/max_rate=false\n"
        "force/max_rate_hz=44100\n"
        "edit/trim=false\n"
        "edit/normalize=false\n"
        f"edit/loop_mode={loop_mode}\n"
        "edit/loop_begin=0\n"
        "edit/loop_end=-1\n"
        "compress/mode=2\n"
    )
    with open(str(path) + ".import", "w", encoding="utf-8") as handle:
        handle.write(text)


def burst(dur: float, fn, seed: int = 1) -> list[float]:
    n = max(8, int(dur * RATE))
    return [fn(i / RATE, i, seed) for i in range(n)]


def step_grass(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        rustle = noise(i, s) * 0.55 + noise(i * 3, s + 4) * 0.25
        rustle *= env(t, 0.004, 0.02, 0.07)
        body = math.sin(2 * math.pi * (90 + seed) * t) * 0.12 * env(t, 0.002, 0.01, 0.05)
        return rustle * 0.7 + body

    return lowpass(burst(0.12, fn, seed), 0.35)


def step_dirt(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        thud = math.sin(2 * math.pi * (68 + seed * 2) * t) * 0.5 * env(t, 0.002, 0.018, 0.07)
        grit = noise(i, s) * 0.28 * env(t, 0.001, 0.012, 0.05)
        return thud + grit

    return lowpass(burst(0.13, fn, seed), 0.28)


def step_stone(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        click = math.sin(2 * math.pi * (420 + seed * 18) * t) * 0.22 * env(t, 0.001, 0.008, 0.03)
        body = math.sin(2 * math.pi * (140 + seed * 6) * t) * 0.28 * env(t, 0.002, 0.012, 0.05)
        dry = highpass([noise(i, s) * 0.35 * env(t, 0.001, 0.01, 0.04)], 0.45)[0] if False else noise(i, s) * 0.22 * env(t, 0.001, 0.01, 0.04)
        return click + body + dry

    return burst(0.11, fn, seed)


def step_sand(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        hiss = noise(i, s) * 0.5 + noise(i + 17, s + 3) * 0.2
        return hiss * env(t, 0.006, 0.03, 0.09)

    return highpass(burst(0.14, fn, seed), 0.22)


def step_wood(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        knock = math.sin(2 * math.pi * (190 + seed * 8) * t) * 0.42 * env(t, 0.001, 0.012, 0.06)
        hollow = math.sin(2 * math.pi * (95 + seed * 4) * t) * 0.18 * env(t, 0.003, 0.02, 0.07)
        tap = noise(i, s) * 0.12 * env(t, 0.001, 0.006, 0.03)
        return knock + hollow + tap

    return burst(0.12, fn, seed)


def step_metal(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        ping = math.sin(2 * math.pi * (880 + seed * 40) * t) * 0.18 * env(t, 0.001, 0.01, 0.08)
        plate = math.sin(2 * math.pi * (220 + seed * 10) * t) * 0.28 * env(t, 0.002, 0.02, 0.08)
        tick = noise(i, s) * 0.16 * env(t, 0.001, 0.006, 0.03)
        return ping + plate + tick

    return burst(0.14, fn, seed)


def jump_sfx(seed: int = 2) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        whoosh = noise(i, s) * 0.22 * env(t, 0.004, 0.03, 0.08)
        lift = math.sin(2 * math.pi * (240 - 90 * t) * t) * 0.35 * env(t, 0.004, 0.04, 0.08)
        return whoosh + lift

    return burst(0.16, fn, seed)


def land_sfx(seed: int, heavy: bool) -> list[float]:
    amp = 0.7 if heavy else 0.42

    def fn(t: float, i: int, s: int) -> float:
        thud = math.sin(2 * math.pi * (72 + seed) * t) * amp * env(t, 0.002, 0.02, 0.1)
        dust = noise(i, s) * (0.32 if heavy else 0.18) * env(t, 0.001, 0.015, 0.08)
        return thud + dust

    return lowpass(burst(0.18 if heavy else 0.12, fn, seed), 0.32)


def hit_dirt(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        return (math.sin(2 * math.pi * 70 * t) * 0.35 + noise(i, s) * 0.4) * env(t, 0.002, 0.02, 0.05)

    return lowpass(burst(0.09, fn, seed), 0.3)


def hit_stone(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        click = math.sin(2 * math.pi * (760 + seed * 30) * t) * 0.28 * env(t, 0.001, 0.008, 0.03)
        chip = noise(i, s) * 0.38 * env(t, 0.001, 0.012, 0.04)
        body = math.sin(2 * math.pi * 160 * t) * 0.2 * env(t, 0.002, 0.01, 0.04)
        return click + chip + body

    return burst(0.08, fn, seed)


def hit_ore(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        metal = math.sin(2 * math.pi * (980 + seed * 45) * t) * 0.24 * env(t, 0.001, 0.012, 0.05)
        stone = math.sin(2 * math.pi * 180 * t) * 0.22 * env(t, 0.002, 0.012, 0.04)
        chip = noise(i, s) * 0.3 * env(t, 0.001, 0.01, 0.04)
        return metal + stone + chip

    return burst(0.1, fn, seed)


def hit_wood(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        chop = math.sin(2 * math.pi * (210 + seed * 8) * t) * 0.45 * env(t, 0.002, 0.018, 0.06)
        fiber = noise(i, s) * 0.22 * env(t, 0.003, 0.02, 0.05)
        return chop + fiber

    return burst(0.11, fn, seed)


def hit_plant(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        snip = noise(i, s) * 0.45 * env(t, 0.002, 0.01, 0.04)
        leaf = math.sin(2 * math.pi * (520 + seed * 20) * t) * 0.12 * env(t, 0.002, 0.015, 0.05)
        return snip + leaf

    return highpass(burst(0.09, fn, seed), 0.28)


def break_block(kind: str, seed: int) -> list[float]:
    table = {
        "dirt": (hit_dirt, 0.22, 0.7),
        "stone": (hit_stone, 0.24, 0.85),
        "ore": (hit_ore, 0.26, 0.9),
        "wood": (hit_wood, 0.28, 0.8),
        "plant": (hit_plant, 0.18, 0.7),
        "sand": (hit_dirt, 0.2, 0.65),
    }
    base_fn, dur, amp = table[kind]
    head = [s * 1.15 * amp for s in base_fn(seed)]
    n = int(dur * RATE)
    tail = []
    for i in range(n):
        t = i / RATE
        crumble = noise(i, seed + 9) * 0.35 * env(t, 0.004, 0.05, dur - 0.06)
        if kind in ("stone", "ore"):
            crumble += math.sin(2 * math.pi * (140 - 40 * t) * t) * 0.15 * env(t, 0.002, 0.04, 0.12)
        tail.append(crumble)
    out = head + [0.0] * 40 + tail
    return out


def place_block(kind: str, seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        if kind == "wood":
            return math.sin(2 * math.pi * (240 + seed * 6) * t) * 0.4 * env(t, 0.002, 0.02, 0.06) + noise(i, s) * 0.1 * env(t, 0.001, 0.01, 0.04)
        if kind == "metal":
            return math.sin(2 * math.pi * (700 + seed * 20) * t) * 0.22 * env(t, 0.001, 0.015, 0.07) + math.sin(2 * math.pi * 180 * t) * 0.2 * env(t, 0.002, 0.02, 0.05)
        if kind == "dirt":
            return (math.sin(2 * math.pi * 90 * t) * 0.28 + noise(i, s) * 0.25) * env(t, 0.003, 0.02, 0.06)
        return (math.sin(2 * math.pi * (160 + seed * 8) * t) * 0.32 + noise(i, s) * 0.16) * env(t, 0.002, 0.018, 0.05)

    return burst(0.12, fn, seed)


def swing_air(kind: str, seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        whoosh = noise(i, s) * 0.42 * env(t, 0.008, 0.04, 0.08)
        if kind == "sword":
            blade = math.sin(2 * math.pi * (1400 - 900 * t) * t) * 0.16 * env(t, 0.004, 0.03, 0.06)
            return whoosh * 0.85 + blade
        if kind == "spear":
            thrust = noise(i, s + 2) * 0.38 * env(t, 0.002, 0.02, 0.05)
            return thrust + math.sin(2 * math.pi * (900 - 400 * t) * t) * 0.1 * env(t, 0.002, 0.02, 0.04)
        if kind == "lantern":
            warm = math.sin(2 * math.pi * (220 + 40 * math.sin(t * 18)) * t) * 0.22 * env(t, 0.01, 0.08, 0.12)
            shimmer = math.sin(2 * math.pi * (540 + seed * 12) * t) * 0.12 * env(t, 0.02, 0.1, 0.14)
            air = noise(i, s) * 0.12 * env(t, 0.01, 0.06, 0.1)
            return warm + shimmer + air
        return whoosh + math.sin(2 * math.pi * (180 - 40 * t) * t) * 0.12 * env(t, 0.006, 0.04, 0.07)

    dur = 0.28 if kind == "lantern" else 0.16 if kind == "spear" else 0.2
    return burst(dur, fn, seed)


def impact(kind: str, seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        body = math.sin(2 * math.pi * (130 + seed * 6) * t) * 0.4 * env(t, 0.001, 0.012, 0.05)
        slap = noise(i, s) * 0.35 * env(t, 0.001, 0.01, 0.04)
        if kind == "lantern":
            glow = math.sin(2 * math.pi * (360 + 80 * math.sin(t * 30)) * t) * 0.28 * env(t, 0.004, 0.04, 0.1)
            spark = noise(i, s + 5) * 0.18 * env(t, 0.002, 0.03, 0.08)
            return glow + spark + body * 0.45
        return body + slap

    return burst(0.18 if kind == "lantern" else 0.1, fn, seed)


def bow_draw(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        creak = math.sin(2 * math.pi * (90 + 25 * t) * t) * 0.22 * env(t, 0.02, 0.12, 0.08)
        grain = noise(i, s) * 0.12 * env(t, 0.03, 0.1, 0.08)
        return creak + grain

    return burst(0.28, fn, seed)


def bow_release(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        snap = noise(i, s) * 0.4 * env(t, 0.001, 0.012, 0.05)
        string = math.sin(2 * math.pi * (420 - 180 * t) * t) * 0.22 * env(t, 0.002, 0.03, 0.06)
        return snap + string

    return burst(0.14, fn, seed)


def pickup(seed: int) -> list[float]:
    def fn(t: float, i: int, s: int) -> float:
        blip = math.sin(2 * math.pi * (620 + seed * 30 + 180 * t) * t) * 0.28 * env(t, 0.004, 0.03, 0.08)
        soft = math.sin(2 * math.pi * 240 * t) * 0.1 * env(t, 0.006, 0.04, 0.07)
        return blip + soft

    return burst(0.16, fn, seed)


def ui_click(seed: int, kind: str) -> list[float]:
    base = {"open": 320.0, "close": 240.0, "click": 480.0, "tab": 400.0, "ok": 520.0, "fail": 160.0}[kind]
    dur = 0.18 if kind in ("open", "close", "ok", "fail") else 0.08

    def fn(t: float, i: int, s: int) -> float:
        tone = math.sin(2 * math.pi * (base + (40 if kind == "ok" else -30 if kind == "fail" else 0) * t) * t)
        tone *= 0.28 if kind != "fail" else 0.22
        tick = noise(i, s) * (0.08 if kind != "fail" else 0.16)
        return (tone + tick) * env(t, 0.004, 0.02, dur - 0.03)

    return burst(dur, fn, seed)


def wind_loop() -> list[float]:
    n = int(4.0 * RATE)
    out = [0.0] * n
    acc = 0.0
    for i in range(n):
        acc = acc * 0.995 + noise(i, 41) * 0.005
        t = i / RATE
        gust = 0.55 + 0.45 * math.sin(2 * math.pi * 0.18 * t + 0.4)
        rumble = math.sin(2 * math.pi * 42 * t) * 0.08 + math.sin(2 * math.pi * 27 * t) * 0.05
        out[i] = (acc * 6.0 * gust + rumble) * 0.55
    # fade seams for looping
    fade = int(0.12 * RATE)
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[-1 - i] *= k
    for i in range(fade):
        out[i] += out[n - fade + i] * (1.0 - i / fade) * 0.0
    return out


def thunder(near: bool) -> list[float]:
    dur = 1.6 if near else 1.1
    n = int(dur * RATE)
    out = [0.0] * n
    acc = 0.0
    for i in range(n):
        t = i / RATE
        acc = acc * 0.97 + noise(i, 77 if near else 88) * 0.03
        crack = 0.0
        if near and t < 0.08:
            crack = noise(i, 12) * 0.7 * env(t, 0.002, 0.01, 0.06)
        boom = acc * (0.9 if near else 0.45) * env(t, 0.02, 0.15, dur - 0.2)
        low = math.sin(2 * math.pi * (38 - 8 * t) * t) * (0.35 if near else 0.18) * env(t, 0.03, 0.2, dur - 0.25)
        out[i] = crack + boom + low
    return lowpass(out, 0.18 if near else 0.12)


def warning_rumble() -> list[float]:
    n = int(2.4 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = math.sin(2 * math.pi * 46 * t) * 0.16 + math.sin(2 * math.pi * 31 * t) * 0.1
        s += noise(i, 19) * 0.08
        s *= env(t, 0.2, 1.4, 0.7)
        out.append(s)
    return out


def lantern_hum() -> list[float]:
    n = int(3.0 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        warm = math.sin(2 * math.pi * 110 * t) * 0.07
        glow = math.sin(2 * math.pi * 165 * t) * 0.04
        shimmer = math.sin(2 * math.pi * (220 + 6 * math.sin(2 * math.pi * 0.4 * t)) * t) * 0.025
        out.append(warm + glow + shimmer)
    fade = int(0.2 * RATE)
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[-1 - i] *= k
    return out


def darkness_loop() -> list[float]:
    n = int(2.2 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        s = math.sin(2 * math.pi * 36 * t) * 0.09 + math.sin(2 * math.pi * 51 * t) * 0.05
        s += noise(i, 33) * 0.04
        breath = math.sin(2 * math.pi * 0.7 * t) * 0.03
        out.append((s + breath) * 0.85)
    fade = int(0.15 * RATE)
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[-1 - i] *= k
    return out


def save_variants(prefix: str, builder, count: int = 4) -> None:
    for i in range(count):
        write_wav(os.path.join(SFX, f"{prefix}_{i + 1:02d}.wav"), builder(i + 3))


def main() -> None:
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(AMB, exist_ok=True)
    random.seed(18)

    save_variants("step_grass", step_grass)
    save_variants("step_dirt", step_dirt)
    save_variants("step_stone", step_stone)
    save_variants("step_sand", step_sand)
    save_variants("step_wood", step_wood)
    save_variants("step_metal", step_metal)

    write_wav(os.path.join(SFX, "footstep.wav"), step_dirt(4))
    write_wav(os.path.join(SFX, "jump.wav"), jump_sfx())
    write_wav(os.path.join(SFX, "land_01.wav"), land_sfx(3, False))
    write_wav(os.path.join(SFX, "land_02.wav"), land_sfx(6, False))
    write_wav(os.path.join(SFX, "land_03.wav"), land_sfx(9, True))

    for i in range(3):
        write_wav(os.path.join(SFX, f"hit_dirt_{i + 1:02d}.wav"), hit_dirt(i + 2))
        write_wav(os.path.join(SFX, f"hit_stone_{i + 1:02d}.wav"), hit_stone(i + 4))
        write_wav(os.path.join(SFX, f"hit_ore_{i + 1:02d}.wav"), hit_ore(i + 5))
        write_wav(os.path.join(SFX, f"hit_wood_{i + 1:02d}.wav"), hit_wood(i + 3))
        write_wav(os.path.join(SFX, f"hit_plant_{i + 1:02d}.wav"), hit_plant(i + 6))
        write_wav(os.path.join(SFX, f"break_dirt_{i + 1:02d}.wav"), break_block("dirt", i + 2))
        write_wav(os.path.join(SFX, f"break_stone_{i + 1:02d}.wav"), break_block("stone", i + 4))
        write_wav(os.path.join(SFX, f"break_ore_{i + 1:02d}.wav"), break_block("ore", i + 5))
        write_wav(os.path.join(SFX, f"break_wood_{i + 1:02d}.wav"), break_block("wood", i + 3))
        write_wav(os.path.join(SFX, f"break_plant_{i + 1:02d}.wav"), break_block("plant", i + 6))
        write_wav(os.path.join(SFX, f"place_stone_{i + 1:02d}.wav"), place_block("stone", i + 2))
        write_wav(os.path.join(SFX, f"place_wood_{i + 1:02d}.wav"), place_block("wood", i + 3))
        write_wav(os.path.join(SFX, f"place_dirt_{i + 1:02d}.wav"), place_block("dirt", i + 4))
        write_wav(os.path.join(SFX, f"place_metal_{i + 1:02d}.wav"), place_block("metal", i + 5))

    write_wav(os.path.join(SFX, "mine_hit.wav"), hit_stone(3))
    write_wav(os.path.join(SFX, "block_break.wav"), break_block("stone", 4))
    write_wav(os.path.join(SFX, "block_place.wav"), place_block("stone", 2))
    write_wav(os.path.join(SFX, "wood_hit.wav"), hit_wood(4))
    write_wav(os.path.join(SFX, "tree_fall.wav"), break_block("wood", 8) + [0.0] * 2000 + land_sfx(8, True))

    write_wav(os.path.join(SFX, "swing.wav"), swing_air("tool", 3))
    write_wav(os.path.join(SFX, "swing_sword.wav"), swing_air("sword", 4))
    write_wav(os.path.join(SFX, "swing_spear.wav"), swing_air("spear", 5))
    write_wav(os.path.join(SFX, "swing_lantern.wav"), swing_air("lantern", 6))
    write_wav(os.path.join(SFX, "hit_impact.wav"), impact("generic", 3))
    write_wav(os.path.join(SFX, "hit_lantern.wav"), impact("lantern", 7))
    write_wav(os.path.join(SFX, "bow_draw.wav"), bow_draw(3))
    write_wav(os.path.join(SFX, "bow_release.wav"), bow_release(4))
    write_wav(os.path.join(SFX, "arrow_impact.wav"), impact("generic", 9))
    write_wav(os.path.join(SFX, "pickup.wav"), pickup(2))
    write_wav(os.path.join(SFX, "pickup_02.wav"), pickup(5))

    write_wav(os.path.join(SFX, "ui_open.wav"), ui_click(2, "open"))
    write_wav(os.path.join(SFX, "ui_close.wav"), ui_click(3, "close"))
    write_wav(os.path.join(SFX, "ui_click.wav"), ui_click(4, "click"))
    write_wav(os.path.join(SFX, "ui_tab.wav"), ui_click(5, "tab"))
    write_wav(os.path.join(SFX, "ui_craft_ok.wav"), ui_click(6, "ok"))
    write_wav(os.path.join(SFX, "ui_craft_fail.wav"), ui_click(7, "fail"))

    write_wav(os.path.join(AMB, "wind_finsternis.wav"), wind_loop(), loop=True)
    write_wav(os.path.join(AMB, "thunder_near.wav"), thunder(True))
    write_wav(os.path.join(AMB, "thunder_far.wav"), thunder(False))
    write_wav(os.path.join(AMB, "fog_warning.wav"), warning_rumble())
    write_wav(os.path.join(AMB, "lantern_hum.wav"), lantern_hum(), loop=True)
    write_wav(os.path.join(SFX, "zombie_darkness.wav"), darkness_loop(), loop=True)

    print("generated original sfx into", SFX, "and", AMB)


if __name__ == "__main__":
    main()
