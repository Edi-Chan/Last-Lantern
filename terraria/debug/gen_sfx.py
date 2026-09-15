"""Erzeugt die Platzhalter-Soundeffekte unter audio/sfx als 16-Bit-Mono-WAV.

Aufruf aus dem Projektwurzelverzeichnis:  python debug/gen_sfx.py
Reine Standardbibliothek, damit kein numpy/scipy noetig ist.
"""

import array
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join("audio", "sfx")


# --- Bausteine ---------------------------------------------------------------

def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def noise(duration, seed=None):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(int(SAMPLE_RATE * duration))]


def tone(duration, freq_start, freq_end=None, wave_form="sine"):
    """Oszillator mit linearem Frequenz-Sweep."""
    n = int(SAMPLE_RATE * duration)
    freq_end = freq_start if freq_end is None else freq_end
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(n - 1, 1)
        freq = freq_start + (freq_end - freq_start) * t
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        if wave_form == "square":
            out.append(1.0 if math.sin(phase) >= 0.0 else -1.0)
        elif wave_form == "saw":
            out.append(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0)
        elif wave_form == "triangle":
            out.append(2.0 * abs(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0) - 1.0)
        else:
            out.append(math.sin(phase))
    return out


def lowpass(samples, cutoff_start, cutoff_end=None):
    """Einpoliger Tiefpass, Cutoff darf ueber die Laenge wandern."""
    cutoff_end = cutoff_start if cutoff_end is None else cutoff_end
    out = []
    prev = 0.0
    n = len(samples)
    for i, s in enumerate(samples):
        t = i / max(n - 1, 1)
        cutoff = cutoff_start + (cutoff_end - cutoff_start) * t
        alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)
        prev += alpha * (s - prev)
        out.append(prev)
    return out


def highpass(samples, cutoff):
    return [s - lp for s, lp in zip(samples, lowpass(samples, cutoff))]


def envelope(samples, attack=0.005, decay_curve=3.0, hold=0.0):
    """Kurzer Attack, danach exponentieller Abfall auf 0."""
    n = len(samples)
    attack_n = max(int(SAMPLE_RATE * attack), 1)
    hold_n = int(SAMPLE_RATE * hold)
    out = []
    for i, s in enumerate(samples):
        if i < attack_n:
            gain = i / attack_n
        elif i < attack_n + hold_n:
            gain = 1.0
        else:
            t = (i - attack_n - hold_n) / max(n - attack_n - hold_n, 1)
            gain = math.pow(1.0 - t, decay_curve)
        out.append(s * gain)
    return out


def mix(*layers):
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, s in enumerate(layer):
            out[i] += s
    return out


def normalize(samples, peak=0.85):
    top = max((abs(s) for s in samples), default=0.0)
    if top < 1e-6:
        return samples
    factor = peak / top
    return [s * factor for s in samples]


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    data = array.array("h")
    for s in normalize(samples):
        data.append(int(max(-1.0, min(1.0, s)) * 32767))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(data.tobytes())
    print("%s  %d frames" % (path, len(data)))


# --- Einzelne Effekte --------------------------------------------------------

def make_footstep():
    """Kurzer, dumpfer Erd-/Kiesschritt."""
    body = lowpass(noise(0.09, seed=11), 1400, 500)
    thump = tone(0.09, 120.0, 70.0, "sine")
    return envelope(mix(body, [s * 0.5 for s in thump]), attack=0.001, decay_curve=3.5)


def make_jump():
    """Aufsteigender Blip."""
    base = tone(0.14, 260.0, 620.0, "square")
    air = [s * 0.25 for s in highpass(noise(0.14, seed=5), 2500)]
    return envelope(mix([s * 0.6 for s in base], air), attack=0.004, decay_curve=2.2)


def make_swing():
    """Whoosh: gefiltertes Rauschen mit wanderndem Cutoff."""
    body = lowpass(noise(0.22, seed=23), 700, 3200)
    body = highpass(body, 400)
    return envelope(body, attack=0.03, decay_curve=2.0, hold=0.02)


def make_mine_hit():
    """Einzelner Pickel-Treffer auf Stein."""
    click = highpass(noise(0.06, seed=37), 2200)
    thud = tone(0.06, 220.0, 130.0, "triangle")
    return envelope(mix([s * 0.7 for s in click], [s * 0.6 for s in thud]),
                    attack=0.001, decay_curve=4.0)


def make_block_break():
    """Block zerbricht: Rauschbruch mit abfallender Tonhoehe."""
    rubble = lowpass(noise(0.3, seed=71), 3500, 600)
    crack = tone(0.3, 380.0, 90.0, "saw")
    return envelope(mix(rubble, [s * 0.35 for s in crack]),
                    attack=0.001, decay_curve=2.4, hold=0.02)


def make_block_place():
    """Block wird gesetzt: kurzer, fester Thump."""
    thump = tone(0.13, 190.0, 95.0, "sine")
    grit = [s * 0.35 for s in lowpass(noise(0.13, seed=97), 2000, 700)]
    return envelope(mix(thump, grit), attack=0.002, decay_curve=3.0)


def make_pickup():
    """Zweitoniger, aufsteigender Aufsammel-Blip."""
    first = envelope(tone(0.07, 660.0, 660.0, "square"), attack=0.003, decay_curve=2.0)
    second = envelope(tone(0.1, 990.0, 1050.0, "square"), attack=0.003, decay_curve=2.5)
    return [s * 0.8 for s in (first + second)]


EFFECTS = {
    "footstep.wav": make_footstep,
    "jump.wav": make_jump,
    "swing.wav": make_swing,
    "mine_hit.wav": make_mine_hit,
    "block_break.wav": make_block_break,
    "block_place.wav": make_block_place,
    "pickup.wav": make_pickup,
}


def main():
    for name, builder in EFFECTS.items():
        write_wav(name, builder())


if __name__ == "__main__":
    main()
