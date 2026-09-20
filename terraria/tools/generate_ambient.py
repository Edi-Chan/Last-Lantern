#!/usr/bin/env python3
"""Hintergrund-Ambient: Wind, Voegel, Insekten, Hoehle."""

from __future__ import annotations

import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio", "ambient", "world")
RES = os.path.join(ROOT, "resources", "audio", "ambient")
RATE = 22050


def write_wav(path: str, samples: np.ndarray, loop: bool) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = float(np.max(np.abs(samples))) if samples.size else 1.0
    if peak > 1e-8:
        samples = samples * (0.92 / peak)
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    rel = os.path.relpath(path, ROOT).replace("\\", "/")
    name = os.path.basename(path)
    with open(path + ".import", "w", encoding="utf-8") as handle:
        handle.write(
            "[remap]\n\n"
            'importer="wav"\n'
            'type="AudioStreamWAV"\n'
            f'path="res://.godot/imported/{name}.sample"\n\n'
            "[deps]\n\n"
            f'source_file="res://{rel}"\n'
            f'dest_files=["res://.godot/imported/{name}.sample"]\n\n'
            "[params]\n\n"
            "force/8_bit=false\n"
            "force/mono=false\n"
            "force/max_rate=false\n"
            "force/max_rate_hz=44100\n"
            "edit/trim=false\n"
            "edit/normalize=false\n"
            f"edit/loop_mode={1 if loop else 0}\n"
            "edit/loop_begin=0\n"
            "edit/loop_end=-1\n"
            "compress/mode=0\n"
        )


def one_pole(x: np.ndarray, cutoff: float) -> np.ndarray:
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    a = float(np.clip(alpha, 0.01, 0.9))
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def seamless(x: np.ndarray, fade: float = 0.6) -> np.ndarray:
    n = int(fade * RATE)
    if n <= 0 or n * 2 >= x.size:
        return x
    ramp = np.linspace(0.0, 1.0, n)
    x = x.copy()
    x[:n] = x[:n] * ramp + x[-n:] * (1.0 - ramp)
    return x[:-n]


def wind(dur: float, cutoff: float, amount: float, gust: float) -> np.ndarray:
    n = int((dur + 0.6) * RATE)
    t = np.arange(n) / RATE
    noise = one_pole(np.random.randn(n), cutoff)
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * gust * t)
    lfo2 = 0.7 + 0.3 * np.sin(2 * np.pi * (gust * 0.37) * t + 1.2)
    return seamless(noise * lfo * lfo2 * amount)


def rustle(dur: float) -> np.ndarray:
    base = wind(dur, 1400.0, 0.55, 0.11)
    ticks = np.zeros_like(base)
    rng = np.random.default_rng(4)
    for _ in range(40):
        pos = int(rng.uniform(0, ticks.size - 800))
        length = int(rng.uniform(200, 900))
        env = np.hanning(length)
        ticks[pos:pos + length] += env * rng.normal(0, 0.12, length)
    return np.clip(base + one_pole(ticks, 2200.0), -1.0, 1.0)


def chirp(freq: float, dur: float, sweep: float, seed: int) -> np.ndarray:
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    f = freq + sweep * t / max(dur, 0.01)
    tone = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    tone += 0.25 * np.sin(4 * np.pi * np.cumsum(f) / RATE)
    env = np.hanning(n) ** 0.7
    air = one_pole(np.random.default_rng(seed).normal(0, 0.04, n), 3000.0)
    return (tone * 0.55 + air) * env


def birds_loop(dur: float, seed: int) -> np.ndarray:
    n = int((dur + 0.6) * RATE)
    mix = wind(dur, 900.0, 0.08, 0.08)
    mix = np.pad(mix, (0, max(0, n - mix.size)))[:n]
    rng = np.random.default_rng(seed)
    t = 0.3
    while t < dur - 0.4:
        freq = float(rng.uniform(1800, 4200))
        length = float(rng.uniform(0.08, 0.22))
        note = chirp(freq, length, float(rng.uniform(-400, 900)), int(rng.integers(1, 99)))
        start = int(t * RATE)
        end = min(n, start + note.size)
        mix[start:end] += note[: end - start] * 0.85
        t += float(rng.uniform(0.35, 1.4))
    return seamless(mix)


def crickets(dur: float) -> np.ndarray:
    n = int((dur + 0.6) * RATE)
    t = np.arange(n) / RATE
    pulse = (np.sin(2 * np.pi * 18.0 * t) > 0.55).astype(np.float64)
    tone = np.sin(2 * np.pi * 5200 * t) * pulse
    tone *= 0.35 + 0.15 * np.sin(2 * np.pi * 0.2 * t)
    bed = wind(dur, 600.0, 0.12, 0.05)
    bed = np.pad(bed, (0, max(0, n - bed.size)))[:n]
    return seamless(one_pole(tone, 4000.0) * 0.45 + bed)


def cave(dur: float) -> np.ndarray:
    low = wind(dur, 280.0, 0.5, 0.04)
    mid = wind(dur, 700.0, 0.18, 0.07)
    n = min(low.size, mid.size)
    return low[:n] * 0.7 + mid[:n] * 0.3


def drip(seed: int) -> np.ndarray:
    n = int(0.55 * RATE)
    t = np.arange(n) / RATE
    env = np.exp(-t * 9.0)
    tone = np.sin(2 * np.pi * (920 - 180 * t) * t) * env
    tone += 0.2 * np.sin(2 * np.pi * 1840 * t) * env
    click = np.zeros(n)
    click[:80] = np.hanning(80) * 0.4
    return np.clip(tone * 0.7 + click, -1, 1)


def owl() -> np.ndarray:
    n = int(1.1 * RATE)
    t = np.arange(n) / RATE
    env = np.concatenate([np.hanning(int(0.35 * RATE)), np.zeros(n - int(0.35 * RATE))])
    env2 = np.zeros(n)
    start = int(0.45 * RATE)
    env2[start:start + int(0.38 * RATE)] = np.hanning(int(0.38 * RATE))
    tone = np.sin(2 * np.pi * 310 * t) + 0.3 * np.sin(2 * np.pi * 155 * t)
    return (tone * (env + 0.85 * env2)) * 0.45


def bird_call(seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    parts = []
    for _ in range(int(rng.integers(2, 4))):
        parts.append(chirp(float(rng.uniform(2100, 3800)), float(rng.uniform(0.07, 0.16)), float(rng.uniform(-200, 700)), seed))
        parts.append(np.zeros(int(rng.uniform(0.04, 0.1) * RATE)))
    return np.concatenate(parts)


LAYERS = [
    {
        "id": "wind_grass",
        "display": "Wind Wiese",
        "volume_db": -11.0,
        "kind": 0,
        "biomes": ["grassland"],
        "depth_layers": ["surface"],
        "day_phases": ["morning", "noon", "evening"],
        "build": lambda: wind(10.0, 700.0, 0.42, 0.09),
        "loop": True,
    },
    {
        "id": "wind_night",
        "display": "Nachtwind",
        "volume_db": -10.0,
        "kind": 0,
        "depth_layers": ["surface"],
        "day_phases": ["night"],
        "build": lambda: wind(12.0, 500.0, 0.5, 0.06),
        "loop": True,
    },
    {
        "id": "wind_forest",
        "display": "Blaetter",
        "volume_db": -9.0,
        "kind": 0,
        "biomes": ["forest"],
        "depth_layers": ["surface"],
        "build": rustle,
        "args": (11.0,),
        "loop": True,
    },
    {
        "id": "wind_sand",
        "display": "Sandwind",
        "volume_db": -8.0,
        "kind": 0,
        "biomes": ["sand"],
        "depth_layers": ["surface"],
        "build": lambda: wind(10.0, 1600.0, 0.48, 0.13),
        "loop": True,
    },
    {
        "id": "wind_cave",
        "display": "Hoehlenwind",
        "volume_db": -8.0,
        "kind": 0,
        "depth_layers": ["underground", "deep"],
        "fog_states": ["clear", "warning", "fog_active", "fog_ending"],
        "build": lambda: cave(12.0),
        "loop": True,
    },
    {
        "id": "birds_day",
        "display": "Voegel Wiese",
        "volume_db": -7.0,
        "kind": 0,
        "biomes": ["grassland"],
        "depth_layers": ["surface"],
        "day_phases": ["morning", "noon"],
        "build": lambda: birds_loop(12.0, 11),
        "loop": True,
    },
    {
        "id": "birds_forest",
        "display": "Voegel Wald",
        "volume_db": -6.5,
        "kind": 0,
        "biomes": ["forest"],
        "depth_layers": ["surface"],
        "day_phases": ["morning", "noon", "evening"],
        "build": lambda: birds_loop(12.0, 29),
        "loop": True,
    },
    {
        "id": "crickets_night",
        "display": "Grillen",
        "volume_db": -9.0,
        "kind": 0,
        "depth_layers": ["surface"],
        "day_phases": ["evening", "night"],
        "build": lambda: crickets(10.0),
        "loop": True,
    },
    {
        "id": "bird_call",
        "display": "Vogelruf",
        "volume_db": -6.0,
        "kind": 1,
        "biomes": ["grassland", "forest"],
        "depth_layers": ["surface"],
        "day_phases": ["morning", "noon", "evening"],
        "oneshot_min": 3.5,
        "oneshot_max": 8.0,
        "build": lambda: bird_call(7),
        "loop": False,
    },
    {
        "id": "owl",
        "display": "Eule",
        "volume_db": -8.0,
        "kind": 1,
        "depth_layers": ["surface"],
        "day_phases": ["night"],
        "oneshot_min": 8.0,
        "oneshot_max": 16.0,
        "build": owl,
        "loop": False,
    },
    {
        "id": "drip",
        "display": "Tropfen",
        "volume_db": -7.0,
        "kind": 1,
        "depth_layers": ["underground", "deep"],
        "fog_states": ["clear", "warning", "fog_active", "fog_ending"],
        "oneshot_min": 1.6,
        "oneshot_max": 4.5,
        "build": lambda: drip(3),
        "loop": False,
    },
]


def names(key: str, spec: dict, default=None) -> str:
    values = spec.get(key, default if default is not None else [])
    if not values:
        return "Array[StringName]([])"
    inner = ", ".join(f'&"{v}"' for v in values)
    return f"Array[StringName]([{inner}])"


def write_layer(spec: dict) -> str:
    path = os.path.join(RES, f"{spec['id']}.tres")
    wav = f"res://audio/ambient/world/{spec['id']}.wav"
    text = (
        "[gd_resource type=\"Resource\" script_class=\"AmbientLayerData\" load_steps=2 format=3]\n\n"
        "[ext_resource type=\"Script\" path=\"res://scripts/audio/ambient_layer_data.gd\" id=\"1_script\"]\n\n"
        "[resource]\n"
        "script = ExtResource(\"1_script\")\n"
        f"id = &\"{spec['id']}\"\n"
        f"display_name = \"{spec['display']}\"\n"
        f"stream_path = \"{wav}\"\n"
        f"volume_db = {spec['volume_db']}\n"
        f"kind = {spec['kind']}\n"
        "fade_seconds = 1.6\n"
        f"oneshot_min = {spec.get('oneshot_min', 4.0)}\n"
        f"oneshot_max = {spec.get('oneshot_max', 10.0)}\n"
        "priority = 0\n"
        "enabled = true\n"
        "scenes = Array[StringName]([&\"world\"])\n"
        f"biomes = {names('biomes', spec)}\n"
        f"day_phases = {names('day_phases', spec)}\n"
        f"depth_layers = {names('depth_layers', spec)}\n"
        f"fog_states = {names('fog_states', spec, ['clear'])}\n"
        "interiors = Array[StringName]([&\"WORLD\"])\n"
    )
    os.makedirs(RES, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return f"res://resources/audio/ambient/{spec['id']}.tres"


def write_catalog(paths: list[str]) -> None:
    lines = [
        f"[gd_resource type=\"Resource\" script_class=\"AmbientCatalog\" load_steps={2 + len(paths)} format=3]",
        "",
        "[ext_resource type=\"Script\" path=\"res://scripts/audio/ambient_catalog.gd\" id=\"1_script\"]",
    ]
    for i, path in enumerate(paths, start=2):
        lines.append(f"[ext_resource type=\"Resource\" path=\"{path}\" id=\"{i}_layer\"]")
    lines += ["", "[resource]", "script = ExtResource(\"1_script\")"]
    refs = ", ".join(f"ExtResource(\"{i}_layer\")" for i in range(2, 2 + len(paths)))
    lines.append(f"layers = [{refs}]")
    lines.append("")
    with open(os.path.join(RES, "ambient_catalog.tres"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def main() -> None:
    np.random.seed(21)
    os.makedirs(AUDIO, exist_ok=True)
    paths: list[str] = []
    for spec in LAYERS:
        print("ambient", spec["id"])
        args = spec.get("args", ())
        samples = np.asarray(spec["build"](*args), dtype=np.float64)
        write_wav(os.path.join(AUDIO, f"{spec['id']}.wav"), samples, spec["loop"])
        paths.append(write_layer(spec))
    write_catalog(paths)
    print("done", len(paths))


if __name__ == "__main__":
    main()
