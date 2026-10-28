"""Synthesises the short game sound effects into assets/audio/*.wav (stdlib only).

Run from the repo root: python tool/make_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def env(i, n, attack=0.01, release=0.6):
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = math.exp(-t / release * 4)
    return a * r


def tone(freq, dur, vol=0.5, shape="sine", decay=0.5):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        ph = 2 * math.pi * freq * i / RATE
        if shape == "sine":
            s = math.sin(ph)
        elif shape == "soft":
            s = math.sin(ph) + 0.35 * math.sin(2 * ph) + 0.15 * math.sin(3 * ph)
        else:
            s = 1.0 if math.sin(ph) > 0 else -1.0
        out.append(s * vol * env(i, n, 0.005, decay))
    return out


def noise(dur, vol=0.4, lo=0.0, decay=0.3, seed=1):
    rnd = random.Random(seed)
    n = int(RATE * dur)
    out, prev = [], 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        prev = prev * lo + x * (1 - lo)  # lo near 1 = darker noise
        out.append(prev * vol * env(i, n, 0.002, decay))
    return out


def sweep(f0, f1, dur, vol=0.4, decay=0.6):
    n = int(RATE * dur)
    out, ph = [], 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * i / n
        ph += 2 * math.pi * f / RATE
        out.append(math.sin(ph) * vol * env(i, n, 0.005, decay))
    return out


def mix(*parts):
    n = max(len(p) for p in parts)
    return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out


def delay(p, secs):
    return [0.0] * int(RATE * secs) + p


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def chip_clack(seed, f=2400):
    return mix(noise(0.05, 0.5, 0.2, 0.15, seed), tone(f, 0.07, 0.35, "sine", 0.2))


save("click", mix(tone(1200, 0.04, 0.4, "sine", 0.2), noise(0.015, 0.2, 0.3, 0.2, 3)))
save("card_deal", mix(noise(0.14, 0.45, 0.55, 0.35, 5), sweep(900, 300, 0.12, 0.15, 0.4)))
save("card_flip", mix(noise(0.09, 0.4, 0.4, 0.3, 7), sweep(600, 1400, 0.08, 0.15, 0.3)))
save("chip", seq(chip_clack(11), chip_clack(12, 2800), gap=0.025))
save("bet", mix(seq(chip_clack(21), chip_clack(22, 2900), chip_clack(23, 2600), gap=0.03)))
save("raise", seq(chip_clack(31), chip_clack(32, 2800), chip_clack(33, 3100),
                  tone(880, 0.12, 0.3, "soft", 0.5), gap=0.03))
save("fold", mix(noise(0.2, 0.35, 0.7, 0.4, 41), sweep(500, 150, 0.2, 0.3, 0.4)))
save("timer_warning", seq(tone(1500, 0.07, 0.4, "sine", 0.3), tone(1500, 0.07, 0.4, "sine", 0.3), gap=0.06))
save("room_join", seq(tone(660, 0.1, 0.4, "soft", 0.5), tone(990, 0.16, 0.4, "soft", 0.5), gap=0.02))
save("game_start", seq(tone(440, 0.1, 0.35, "soft", 0.5), tone(554, 0.1, 0.35, "soft", 0.5),
                       tone(659, 0.18, 0.4, "soft", 0.5), gap=0.01))
win = seq(*[tone(f, 0.14, 0.4, "soft", 0.6) for f in (523, 659, 784)], gap=0.0)
win += mix(tone(1047, 0.5, 0.4, "soft", 0.9), tone(784, 0.5, 0.3, "soft", 0.9), tone(659, 0.5, 0.25, "soft", 0.9))
save("win", win)
save("lose", seq(tone(392, 0.16, 0.35, "soft", 0.6), tone(330, 0.16, 0.35, "soft", 0.6),
                 tone(262, 0.4, 0.35, "soft", 0.9), gap=0.0))
print("wrote", len(list(OUT.glob("*.wav"))), "files to", OUT)
