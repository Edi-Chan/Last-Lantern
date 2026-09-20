#!/usr/bin/env python3
"""Erzeugt loopbare Folklore-BGM (Floete, Gitarre, Pad) fuer Last Lantern."""

from __future__ import annotations

import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio", "music")
RES = os.path.join(ROOT, "resources", "audio", "music")
RATE = 22050
DURATION = 20.0
FADE = 0.9

PITCH = {
    "C2": 65.41, "D2": 73.42, "E2": 82.41, "F2": 87.31, "G2": 98.00, "A2": 110.00, "B2": 123.47,
    "C3": 130.81, "D3": 146.83, "Eb3": 155.56, "E3": 164.81, "F3": 174.61, "G3": 196.00, "Ab3": 207.65,
    "A3": 220.00, "Bb3": 233.08, "B3": 246.94, "C4": 261.63, "D4": 293.66, "Eb4": 311.13, "E4": 329.63,
    "F4": 349.23, "G4": 392.00, "Ab4": 415.30, "A4": 440.00, "Bb4": 466.16, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "F5": 698.46, "G5": 783.99, "A5": 880.00,
}


def hz(name: str) -> float:
    return PITCH[name]


def t_axis(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / RATE


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    env = np.zeros(n, dtype=np.float64)
    na, nd, nr = int(a * RATE), int(d * RATE), int(r * RATE)
    ns = max(0, n - na - nd - nr)
    i = 0
    if na:
        env[i:i + na] = np.linspace(0.0, 1.0, na, endpoint=False)
        i += na
    if nd:
        env[i:i + nd] = np.linspace(1.0, s, nd, endpoint=False)
        i += nd
    if ns:
        env[i:i + ns] = s
        i += ns
    if nr and i < n:
        env[i:] = np.linspace(s, 0.0, n - i)
    return env


def lowpass(x: np.ndarray, alpha: float) -> np.ndarray:
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def one_pole(x: np.ndarray, cutoff: float) -> np.ndarray:
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    return lowpass(x, float(np.clip(alpha, 0.01, 0.95)))


def pan_stereo(mono: np.ndarray, pan: float) -> np.ndarray:
    angle = (np.clip(pan, -1.0, 1.0) + 1.0) * 0.25 * np.pi
    left = mono * np.cos(angle)
    right = mono * np.sin(angle)
    return np.stack([left, right], axis=1)


def add(mix: np.ndarray, stereo: np.ndarray, at: float) -> None:
    start = int(at * RATE)
    end = min(mix.shape[0], start + stereo.shape[0])
    if start >= mix.shape[0] or end <= start:
        return
    mix[start:end] += stereo[: end - start]


def guitar(freq: float, dur: float, brightness: float = 0.968, pluck: float = 0.18) -> np.ndarray:
    n = int(dur * RATE)
    period = max(8, int(RATE / freq))
    noise = (np.random.rand(period) * 2.0 - 1.0)
    cut = max(2, int(period * pluck))
    noise[cut:] *= 0.15
    noise = one_pole(noise, 2400.0)
    buf = np.zeros(n + period, dtype=np.float64)
    buf[:period] = noise
    for i in range(period, n + period):
        avg = 0.5 * (buf[i - period] + buf[i - period + 1])
        buf[i] = brightness * avg
    body = buf[:n]
    body *= adsr(n, 0.004, 0.08, 0.55, min(0.55, dur * 0.45))
    body += 0.08 * np.sin(2 * np.pi * freq * 0.5 * t_axis(n)) * adsr(n, 0.01, 0.2, 0.2, 0.4)
    return body * 0.55


def flute(freq: float, dur: float, breath: float = 0.035) -> np.ndarray:
    n = int(dur * RATE)
    t = t_axis(n)
    vib = 1.0 + 0.011 * np.sin(2 * np.pi * 5.1 * t + 0.4)
    phase = np.cumsum(2 * np.pi * freq * vib / RATE)
    tone = (
        0.72 * np.sin(phase)
        + 0.16 * np.sin(2 * phase)
        + 0.05 * np.sin(3 * phase)
    )
    air = one_pole(np.random.randn(n) * breath, 1800.0)
    env = adsr(n, 0.08, 0.12, 0.78, min(0.35, dur * 0.25))
    return (tone + air) * env * 0.42


def pad(freqs: list[float], dur: float, warmth: float = 0.16) -> np.ndarray:
    n = int(dur * RATE)
    t = t_axis(n)
    sig = np.zeros(n)
    for i, f in enumerate(freqs):
        det = 1.0 + (i - 1) * 0.0024
        sig += np.sin(2 * np.pi * f * det * t) / max(1, len(freqs))
        sig += 0.35 * np.sin(2 * np.pi * f * 0.5 * det * t) / max(1, len(freqs))
    sig = one_pole(sig, 900.0)
    env = adsr(n, 1.4, 1.0, warmth, 2.2)
    return sig * env * 0.22


def bass(freq: float, dur: float) -> np.ndarray:
    n = int(dur * RATE)
    t = t_axis(n)
    sig = 0.7 * np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(2 * np.pi * freq * 2 * t)
    return sig * adsr(n, 0.02, 0.12, 0.55, 0.35) * 0.28


def wind(dur: float, amount: float) -> np.ndarray:
    n = int(dur * RATE)
    noise = one_pole(np.random.randn(n), 700.0)
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * 0.07 * t_axis(n))
    return noise * lfo * amount


def make_seamless(stereo: np.ndarray) -> np.ndarray:
    fade = int(FADE * RATE)
    head = stereo[:fade].copy()
    tail = stereo[-fade:].copy()
    ramp = np.linspace(0.0, 1.0, fade)[:, None]
    stereo[:fade] = head * ramp + tail * (1.0 - ramp)
    return stereo[:-fade]


def limit(stereo: np.ndarray, peak: float = 0.89) -> np.ndarray:
    m = np.max(np.abs(stereo))
    if m < 1e-8:
        return stereo
    return stereo * (peak / m)


def write_wav(path: str, stereo: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(stereo, -1.0, 1.0)
    frames = (data * 32767.0).astype("<i2").tobytes()
    with wave.open(path, "w") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(frames)
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
            "edit/loop_mode=1\n"
            "edit/loop_begin=0\n"
            "edit/loop_end=-1\n"
            "compress/mode=0\n"
        )


def place_chords(mix: np.ndarray, chords: list[list[str]], beat: float, style: str) -> None:
    extra = FADE
    total = DURATION + extra
    t = 0.0
    i = 0
    while t < total:
        names = chords[i % len(chords)]
        root = hz(names[0])
        add(mix, pan_stereo(bass(root * 0.5 if root > 90 else root, beat * 1.8), 0.0), t)
        for j, note in enumerate(names):
            g = guitar(hz(note), beat * 2.1, 0.972 if style != "night" else 0.96, 0.16 + 0.03 * j)
            add(mix, pan_stereo(g, -0.28 + j * 0.12), t + j * 0.045)
        if style == "day":
            add(mix, pan_stereo(guitar(hz(names[-1]) * 2.0, beat * 0.55, 0.95, 0.3), 0.22), t + beat * 0.5)
        t += beat
        i += 1


def place_flute(mix: np.ndarray, melody: list[tuple[str, float]], start: float, beat: float, pan: float) -> None:
    extra = FADE
    total = DURATION + extra
    t = start
    i = 0
    while t < total:
        name, length = melody[i % len(melody)]
        if name != "rest":
            note = flute(hz(name), length * beat * 0.96)
            add(mix, pan_stereo(note, pan), t)
        t += length * beat
        i += 1


def place_pad(mix: np.ndarray, chords: list[list[str]], beat: float, warmth: float) -> None:
    extra = FADE
    total = DURATION + extra
    t = 0.0
    i = 0
    hold = beat * 4
    while t < total:
        freqs = [hz(n) for n in chords[i % len(chords)]]
        add(mix, pan_stereo(pad(freqs, hold + 1.2, warmth), 0.0), t)
        t += hold
        i += 1


def render_track(spec: dict) -> np.ndarray:
    n = int((DURATION + FADE) * RATE)
    mix = np.zeros((n, 2), dtype=np.float64)
    chords: list[list[str]] = spec["chords"]
    beat: float = spec["beat"]
    style: str = spec["style"]
    add(mix, pan_stereo(wind(DURATION + FADE, spec.get("wind", 0.03)), 0.0), 0.0)
    place_pad(mix, chords, beat, spec.get("warmth", 0.16))
    place_chords(mix, chords, beat, style)
    if spec.get("melody"):
        place_flute(mix, spec["melody"], spec.get("melody_start", beat * 2), beat, spec.get("flute_pan", 0.32))
    if spec.get("melody_b"):
        place_flute(mix, spec["melody_b"], spec.get("melody_b_start", beat * 8), beat, -0.18)
    return limit(make_seamless(mix))


TRACKS = [
    {
        "id": "menu",
        "display": "Hauptmenue",
        "priority": 5,
        "scenes": ["menu"],
        "beat": 0.92,
        "style": "night",
        "warmth": 0.2,
        "wind": 0.04,
        "chords": [["A2", "E3", "A3", "C4"], ["F3", "A3", "C4", "F4"], ["C3", "G3", "C4", "E4"], ["G2", "D3", "G3", "B3"]],
        "melody": [("E5", 2), ("D5", 1), ("C5", 1), ("A4", 2), ("C5", 1), ("E5", 1), ("G5", 2), ("E5", 2), ("D5", 2), ("rest", 2)],
    },
    {
        "id": "grassland_day",
        "display": "Wiese Tag",
        "priority": 10,
        "scenes": ["world"],
        "biomes": ["grassland"],
        "day_phases": ["morning", "noon"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 0.72,
        "style": "day",
        "warmth": 0.14,
        "wind": 0.02,
        "chords": [["C3", "E3", "G3", "C4"], ["G2", "D3", "G3", "B3"], ["A2", "E3", "A3", "C4"], ["F3", "A3", "C4", "F4"]],
        "melody": [("G4", 1), ("A4", 1), ("C5", 2), ("E5", 1), ("D5", 1), ("C5", 2), ("G4", 1), ("E4", 1), ("G4", 2), ("rest", 2)],
    },
    {
        "id": "grassland_evening",
        "display": "Wiese Abend",
        "priority": 12,
        "scenes": ["world"],
        "biomes": ["grassland"],
        "day_phases": ["evening"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 0.82,
        "style": "day",
        "warmth": 0.2,
        "wind": 0.03,
        "chords": [["G2", "D3", "G3", "B3"], ["E3", "G3", "B3", "E4"], ["C3", "E3", "G3", "C4"], ["D3", "F3", "A3", "D4"]],
        "melody": [("B4", 2), ("G4", 1), ("A4", 1), ("D5", 2), ("B4", 2), ("G4", 2), ("rest", 2)],
    },
    {
        "id": "grassland_night",
        "display": "Wiese Nacht",
        "priority": 12,
        "scenes": ["world"],
        "biomes": ["grassland"],
        "day_phases": ["night"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 0.98,
        "style": "night",
        "warmth": 0.22,
        "wind": 0.05,
        "chords": [["A2", "E3", "A3", "C4"], ["F3", "A3", "C4"], ["D3", "A3", "D4"], ["E3", "G3", "B3"]],
        "melody": [("E5", 2), ("C5", 2), ("A4", 2), ("rest", 1), ("G4", 1), ("A4", 2), ("rest", 2)],
    },
    {
        "id": "forest_day",
        "display": "Wald Tag",
        "priority": 10,
        "scenes": ["world"],
        "biomes": ["forest"],
        "day_phases": ["morning", "noon", "evening"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 0.78,
        "style": "day",
        "warmth": 0.18,
        "wind": 0.035,
        "flute_pan": 0.4,
        "chords": [["G2", "D3", "G3", "B3"], ["C3", "E3", "G3", "C4"], ["E3", "G3", "B3", "E4"], ["D3", "A3", "D4"]],
        "melody": [("D5", 2), ("E5", 1), ("G5", 2), ("E5", 1), ("D5", 2), ("B4", 2), ("G4", 2), ("rest", 2)],
        "melody_b": [("G4", 4), ("A4", 2), ("B4", 2), ("rest", 4)],
    },
    {
        "id": "forest_night",
        "display": "Wald Nacht",
        "priority": 12,
        "scenes": ["world"],
        "biomes": ["forest"],
        "day_phases": ["night"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 1.05,
        "style": "night",
        "warmth": 0.24,
        "wind": 0.06,
        "chords": [["E3", "G3", "B3"], ["C3", "G3", "C4"], ["A2", "E3", "A3"], ["B2", "F3", "B3"]],
        "melody": [("E5", 3), ("B4", 1), ("C5", 2), ("G4", 2), ("rest", 2), ("A4", 2)],
    },
    {
        "id": "sand_day",
        "display": "Sand Tag",
        "priority": 10,
        "scenes": ["world"],
        "biomes": ["sand"],
        "day_phases": ["morning", "noon", "evening"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 0.86,
        "style": "day",
        "warmth": 0.1,
        "wind": 0.055,
        "chords": [["D3", "A3", "D4"], ["G2", "D3", "G3"], ["A2", "E3", "A3"], ["C3", "G3", "C4"]],
        "melody": [("A4", 2), ("G4", 1), ("A4", 1), ("D5", 2), ("rest", 2), ("E5", 1), ("D5", 1), ("A4", 2), ("rest", 2)],
    },
    {
        "id": "sand_night",
        "display": "Sand Nacht",
        "priority": 12,
        "scenes": ["world"],
        "biomes": ["sand"],
        "day_phases": ["night"],
        "depth_layers": ["surface"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 1.08,
        "style": "night",
        "warmth": 0.18,
        "wind": 0.07,
        "chords": [["D3", "A3"], ["F3", "C4"], ["G2", "D3"], ["A2", "E3"]],
        "melody": [("D5", 3), ("rest", 1), ("A4", 2), ("rest", 2)],
    },
    {
        "id": "underground",
        "display": "Hoehle",
        "priority": 40,
        "scenes": ["world"],
        "depth_layers": ["underground"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 1.12,
        "style": "night",
        "warmth": 0.28,
        "wind": 0.04,
        "chords": [["D2", "A2", "D3"], ["F2", "C3"], ["G2", "D3"], ["A2", "E3"]],
        "melody": [("A4", 3), ("rest", 1), ("F4", 2), ("D4", 2), ("rest", 4)],
    },
    {
        "id": "deep",
        "display": "Tiefe",
        "priority": 45,
        "scenes": ["world"],
        "depth_layers": ["deep"],
        "fog_states": ["clear"],
        "interiors": ["WORLD"],
        "beat": 1.25,
        "style": "night",
        "warmth": 0.32,
        "wind": 0.05,
        "chords": [["C2", "G2", "C3"], ["Ab3", "C4"], ["G2", "D3"], ["Eb3", "Bb3"]],
        "melody": [("G4", 4), ("rest", 2), ("Eb4", 2), ("rest", 4)],
    },
    {
        "id": "fog",
        "display": "Finsternis",
        "priority": 80,
        "scenes": ["world"],
        "fog_states": ["warning", "fog_active", "fog_ending"],
        "beat": 1.18,
        "style": "night",
        "warmth": 0.3,
        "wind": 0.09,
        "chords": [["C3", "Ab3", "C4"], ["Eb3", "Bb3"], ["G2", "D3", "G3"], ["Ab3", "Eb4"]],
        "melody": [("C5", 3), ("Ab4", 1), ("G4", 2), ("rest", 2), ("Eb4", 2), ("rest", 2)],
    },
    {
        "id": "interior",
        "display": "Innenraum",
        "priority": 70,
        "scenes": ["world"],
        "interiors": ["FORGE_INTERIOR"],
        "beat": 0.88,
        "style": "day",
        "warmth": 0.2,
        "wind": 0.015,
        "chords": [["C3", "E3", "G3"], ["A2", "E3", "A3"], ["F3", "A3", "C4"], ["G2", "D3", "G3"]],
        "melody": [("E4", 2), ("G4", 2), ("A4", 2), ("G4", 1), ("E4", 1), ("C4", 2), ("rest", 2)],
    },
]


def names_array(key: str, spec: dict) -> str:
    values = spec.get(key, [])
    if not values:
        return "Array[StringName]([])"
    inner = ", ".join(f'&"{v}"' for v in values)
    return f"Array[StringName]([{inner}])"


def write_track_tres(spec: dict) -> str:
    path = os.path.join(RES, f"{spec['id']}.tres")
    wav = f"res://audio/music/{spec['id']}.wav"
    text = (
        "[gd_resource type=\"Resource\" script_class=\"MusicTrackData\" load_steps=3 format=3]\n\n"
        "[ext_resource type=\"Script\" path=\"res://scripts/audio/music_track_data.gd\" id=\"1_script\"]\n"
        f"[ext_resource type=\"AudioStream\" path=\"{wav}\" id=\"2_stream\"]\n\n"
        "[resource]\n"
        "script = ExtResource(\"1_script\")\n"
        f"id = &\"{spec['id']}\"\n"
        f"display_name = \"{spec['display']}\"\n"
        "stream = ExtResource(\"2_stream\")\n"
        f"stream_path = \"{wav}\"\n"
        "volume_db = -3.0\n"
        "crossfade_seconds = 2.8\n"
        f"priority = {spec['priority']}\n"
        "enabled = true\n"
        f"scenes = {names_array('scenes', spec)}\n"
        f"biomes = {names_array('biomes', spec)}\n"
        f"day_phases = {names_array('day_phases', spec)}\n"
        f"depth_layers = {names_array('depth_layers', spec)}\n"
        f"fog_states = {names_array('fog_states', spec)}\n"
        f"interiors = {names_array('interiors', spec)}\n"
        "cues = Array[StringName]([])\n"
    )
    os.makedirs(RES, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    return f"res://resources/audio/music/{spec['id']}.tres"


def write_catalog(paths: list[str]) -> None:
    lines = [
        f"[gd_resource type=\"Resource\" script_class=\"MusicCatalog\" load_steps={2 + len(paths)} format=3]",
        "",
        "[ext_resource type=\"Script\" path=\"res://scripts/audio/music_catalog.gd\" id=\"1_script\"]",
    ]
    for i, path in enumerate(paths, start=2):
        lines.append(f"[ext_resource type=\"Resource\" path=\"{path}\" id=\"{i}_track\"]")
    lines.append("")
    lines.append("[resource]")
    lines.append("script = ExtResource(\"1_script\")")
    refs = ", ".join(f"ExtResource(\"{i}_track\")" for i in range(2, 2 + len(paths)))
    lines.append(f"tracks = [{refs}]")
    lines.append("fallback_id = &\"menu\"")
    lines.append("")
    with open(os.path.join(RES, "music_catalog.tres"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def main() -> None:
    np.random.seed(19)
    os.makedirs(AUDIO, exist_ok=True)
    paths: list[str] = []
    for spec in TRACKS:
        print("render", spec["id"])
        stereo = render_track(spec)
        write_wav(os.path.join(AUDIO, f"{spec['id']}.wav"), stereo)
        paths.append(write_track_tres(spec))
    write_catalog(paths)
    print("done", len(paths), "tracks")


if __name__ == "__main__":
    main()
