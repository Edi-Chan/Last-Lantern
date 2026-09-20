#!/usr/bin/env python3
"""Schneidet echte Vogelaufnahmen in kurze, zufaellig spielbare Rufe."""

from __future__ import annotations

import os
import subprocess
import wave

import imageio_ffmpeg
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "ambient", "world")
RATE = 22050
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def decode(path: str) -> np.ndarray:
    tmp = path + ".pcm.wav"
    subprocess.run(
        [FFMPEG, "-y", "-i", path, "-ac", "1", "-ar", str(RATE), "-acodec", "pcm_s16le", tmp],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    with wave.open(tmp, "r") as wav:
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").astype(np.float32) / 32768.0
    os.remove(tmp)
    return samples


def write_wav(path: str, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples))) if samples.size else 1.0
    if peak > 1e-6:
        samples = samples * (0.55 / peak)
    fade = min(int(0.025 * RATE), max(1, samples.size // 6))
    samples = samples.copy()
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def bursts(samples: np.ndarray) -> list[tuple[int, int]]:
    win = int(0.03 * RATE)
    energy = np.convolve(samples ** 2, np.ones(win) / win, mode="same")
    thresh = max(float(np.median(energy)) * 8.0, 0.0008)
    active = energy > thresh
    ranges: list[tuple[int, int]] = []
    start = None
    for i, flag in enumerate(active):
        if flag and start is None:
            start = i
        elif not flag and start is not None:
            if i - start > int(0.07 * RATE):
                ranges.append((max(0, start - int(0.04 * RATE)), min(samples.size, i + int(0.08 * RATE))))
            start = None
    if start is not None and samples.size - start > int(0.07 * RATE):
        ranges.append((start, samples.size))
    return ranges


def main() -> None:
    sources = [
        os.path.join(OUT, "raw_chirp.wav"),
        os.path.join(OUT, "raw_birds.ogg"),
    ]
    clips: list[np.ndarray] = []
    for src in sources:
        if not os.path.exists(src):
            continue
        samples = decode(src)
        found = bursts(samples)
        if not found:
            clips.append(samples[: min(samples.size, int(1.6 * RATE))])
            continue
        for a, b in found:
            clip = samples[a:b]
            if clip.size > int(2.4 * RATE):
                clip = clip[: int(2.4 * RATE)]
            if clip.size > int(0.08 * RATE):
                clips.append(clip)
    if not clips:
        raise SystemExit("no bird clips")
    while len(clips) < 6:
        clips.append(clips[len(clips) % max(1, len(clips))])
    for i, clip in enumerate(clips[:8], start=1):
        path = os.path.join(OUT, f"bird_{i:02d}.wav")
        write_wav(path, clip)
        print("wrote", os.path.basename(path), clip.size)
    for name in ("raw_chirp.wav", "raw_birds.ogg"):
        raw = os.path.join(OUT, name)
        if os.path.exists(raw):
            os.remove(raw)


if __name__ == "__main__":
    main()
