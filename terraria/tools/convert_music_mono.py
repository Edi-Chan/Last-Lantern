#!/usr/bin/env python3
"""Macht Musik-WAVs mono, damit Godot sie wie die SFX abspielt."""

from __future__ import annotations

import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC = os.path.join(ROOT, "audio", "music")


def convert(path: str) -> None:
    with wave.open(path, "r") as wav:
        channels = wav.getnchannels()
        rate = wav.getframerate()
        frames = wav.readframes(wav.getnframes())
        samples = np.frombuffer(frames, dtype="<i2").astype(np.float32)
    if channels > 1:
        samples = samples.reshape(-1, channels).mean(axis=1)
    peak = float(np.max(np.abs(samples))) if samples.size else 1.0
    if peak > 1e-6:
        samples = samples * (28000.0 / peak)
    pcm = np.clip(samples, -32767, 32767).astype("<i2")
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(pcm.tobytes())
    print("mono", os.path.basename(path), pcm.size)


def main() -> None:
    for name in os.listdir(MUSIC):
        if name.endswith(".wav"):
            convert(os.path.join(MUSIC, name))


if __name__ == "__main__":
    main()
