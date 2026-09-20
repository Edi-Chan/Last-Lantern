#!/usr/bin/env python3
"""Laedt echte CC0/Mixkit-Vogelrufe und speichert sie als kurze Mono-WAVs."""

from __future__ import annotations

import io
import os
import subprocess
import urllib.request
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "ambient", "world")
RATE = 22050

# Mixkit License / Wikimedia Commons / Freesound previews (CC0 or Mixkit).
SOURCES = [
    ("bird_01", "https://cdn.freesound.org/previews/510/510314_10368014-lq.mp3"),
    ("bird_02", "https://cdn.freesound.org/previews/182/182502_3394150-lq.mp3"),
    ("bird_03", "https://cdn.freesound.org/previews/276/276470_5123851-lq.mp3"),
    ("bird_04", "https://assets.mixkit.co/sfx/preview/mixkit-little-bird-calling-chirp-21.mp3"),
    ("bird_05", "https://assets.mixkit.co/sfx/preview/mixkit-double-little-bird-chirp-21.mp3"),
    ("bird_06", "https://assets.mixkit.co/sfx/preview/mixkit-melodic-songbird-chirp-21.mp3"),
    ("bird_07", "https://upload.wikimedia.org/wikipedia/commons/4/4d/Erithacus_rubecula_song.ogg"),
]


def to_mono_pcm(path: str) -> np.ndarray | None:
    tmp_wav = path + ".tmp.wav"
    import imageio_ffmpeg

    cmd = [
        imageio_ffmpeg.get_ffmpeg_exe(),
        "-y", "-i", path, "-ac", "1", "-ar", str(RATE),
        "-acodec", "pcm_s16le", tmp_wav,
    ]
    try:
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError):
        return None
    with wave.open(tmp_wav, "r") as wav:
        frames = wav.readframes(wav.getnframes())
        samples = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    os.remove(tmp_wav)
    return samples


def trim_quiet(samples: np.ndarray, thresh: float = 0.02) -> np.ndarray:
    amp = np.abs(samples)
    if amp.size == 0:
        return samples
    keep = np.where(amp > thresh)[0]
    if keep.size == 0:
        return samples[: int(0.4 * RATE)]
    start = max(0, int(keep[0]) - int(0.04 * RATE))
    end = min(samples.size, int(keep[-1]) + int(0.08 * RATE))
    cut = samples[start:end]
    if cut.size > int(2.8 * RATE):
        cut = cut[: int(2.8 * RATE)]
    fade = min(int(0.03 * RATE), cut.size // 4)
    if fade > 0:
        cut = cut.copy()
        cut[:fade] *= np.linspace(0, 1, fade)
        cut[-fade:] *= np.linspace(1, 0, fade)
    return cut


def write_wav(path: str, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples))) if samples.size else 1.0
    if peak > 1e-6:
        samples = samples * (0.72 / peak)
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    saved: list[str] = []
    for name, url in SOURCES:
        raw = os.path.join(OUT, f"_{name}_raw")
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "LastLantern/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
            ext = ".mp3"
            if url.endswith(".ogg"):
                ext = ".ogg"
            raw_path = raw + ext
            with open(raw_path, "wb") as handle:
                handle.write(data)
            samples = to_mono_pcm(raw_path)
            os.remove(raw_path)
            if samples is None or samples.size < RATE * 0.08:
                print("skip", name)
                continue
            out = os.path.join(OUT, f"{name}.wav")
            write_wav(out, trim_quiet(samples))
            saved.append(out)
            print("ok", name, os.path.getsize(out))
        except Exception as exc:
            print("fail", name, exc)
    print("saved", len(saved))


if __name__ == "__main__":
    main()
