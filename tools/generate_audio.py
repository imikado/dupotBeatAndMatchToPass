#!/usr/bin/env python3
"""Generate the retro sound effects and music loop used by the game.

Pure Python (no dependency). Run from the project root:
    python3 tools/generate_audio.py
Files are written to src/Common/Audio/sounds/.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "src", "Common", "Audio", "sounds")

random.seed(42)


# ---------- oscillators ----------
def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def saw(phase):
    return 2.0 * (phase % 1.0) - 1.0


def noise(_phase=0):
    return random.uniform(-1.0, 1.0)


# ---------- helpers ----------
def tone(duration, freq_start, freq_end=None, wave_fn=square, volume=0.5,
         attack=0.005, release=None, duty=0.5, vibrato=0.0, curve=1.0):
    """A single voice with a frequency sweep and a linear envelope."""
    if freq_end is None:
        freq_end = freq_start
    if release is None:
        release = duration
    n = int(duration * RATE)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = (i / n) ** curve
        freq = freq_start + (freq_end - freq_start) * k
        if vibrato:
            freq *= 1.0 + 0.04 * math.sin(2 * math.pi * vibrato * t)
        phase += freq / RATE
        if wave_fn is square:
            s = square(phase, duty)
        else:
            s = wave_fn(phase)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        remaining = duration - t
        if remaining < release:
            env *= max(0.0, remaining / release)
        out.append(s * env * volume)
    return out


def noise_burst(duration, volume=0.5, lowpass_start=1.0, lowpass_end=0.05, attack=0.002):
    """Filtered noise: lowpass coefficient sweeps from start to end (1 = no filter)."""
    n = int(duration * RATE)
    out = []
    y = 0.0
    for i in range(n):
        t = i / RATE
        a = lowpass_start + (lowpass_end - lowpass_start) * (i / n)
        y += a * (noise() - y)
        env = min(1.0, t / attack) * (1.0 - i / n)
        out.append(y * env * volume)
    return out


def mix(*tracks):
    length = max(len(tr) for tr in tracks)
    out = [0.0] * length
    for tr in tracks:
        for i, s in enumerate(tr):
            out[i] += s
    return out


def concat(*tracks):
    out = []
    for tr in tracks:
        out.extend(tr)
    return out


def silence(duration):
    return [0.0] * int(duration * RATE)


def offset(track, delay):
    return silence(delay) + track


def note_freq(name):
    """'A4' -> 440 Hz, supports sharps like 'C#5'."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semis += 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


def arpeggio(notes, step, wave_fn=square, volume=0.35, duty=0.5, tail=0.0):
    parts = []
    for i, n in enumerate(notes):
        d = step + (tail if i == len(notes) - 1 else 0.0)
        parts.append(tone(d, note_freq(n), wave_fn=wave_fn, volume=volume, duty=duty,
                          release=d * 0.6))
    return concat(*parts)


def write(name, samples, peak=0.9):
    m = max(1e-9, max(abs(s) for s in samples))
    gain = peak / m if m > peak else 1.0
    path = os.path.join(OUT_DIR, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767)) for s in samples))
    print("wrote", os.path.relpath(path))


# ---------- sound effects ----------
def sfx():
    write("swing", mix(
        noise_burst(0.12, volume=0.5, lowpass_start=0.6, lowpass_end=0.08),
        tone(0.1, 900, 300, wave_fn=triangle, volume=0.15)))

    write("hit", mix(
        tone(0.09, 220, 60, volume=0.5, duty=0.25),
        noise_burst(0.06, volume=0.6, lowpass_start=0.9, lowpass_end=0.3)))

    write("enemy_die", mix(
        concat(tone(0.06, 520, 400, volume=0.35, duty=0.25),
               tone(0.06, 390, 300, volume=0.35, duty=0.25),
               tone(0.12, 290, 90, volume=0.35, duty=0.25)),
        noise_burst(0.25, volume=0.35, lowpass_start=0.5, lowpass_end=0.02)))

    write("player_hurt", mix(
        tone(0.25, 380, 110, wave_fn=saw, volume=0.45, vibrato=30),
        noise_burst(0.08, volume=0.4)))

    write("thunder", mix(
        noise_burst(0.08, volume=0.9, lowpass_start=1.0, lowpass_end=0.6),
        noise_burst(0.7, volume=0.8, lowpass_start=0.35, lowpass_end=0.01),
        tone(0.5, 70, 35, volume=0.35, release=0.4)))

    write("energy", tone(0.12, 700, 1400, wave_fn=triangle, volume=0.35, curve=0.5))

    write("barrier_open", mix(
        arpeggio(["C5", "E5", "G5", "C6"], 0.07, duty=0.25, volume=0.3, tail=0.2),
        offset(arpeggio(["E5", "G5", "C6", "E6"], 0.07, wave_fn=triangle, volume=0.25,
                        tail=0.2), 0.035)))

    write("bottle", arpeggio(["G5", "B5", "D6", "G6"], 0.06, wave_fn=triangle, volume=0.4,
                             tail=0.15))

    write("combo", concat(tone(0.06, note_freq("B5"), volume=0.3, duty=0.25, release=0.02),
                          tone(0.18, note_freq("E6"), volume=0.3, duty=0.25, release=0.15)))

    write("spider_shot", tone(0.14, 1200, 250, volume=0.25, duty=0.125))

    write("mana_ready", arpeggio(["A5", "E6"], 0.07, wave_fn=triangle, volume=0.3, tail=0.1))

    write("level_complete", mix(
        arpeggio(["C5", "E5", "G5", "C6", "G5", "C6"], 0.11, duty=0.25, volume=0.3, tail=0.4),
        arpeggio(["C3", "C3", "G3", "G3", "C3", "C3"], 0.11, wave_fn=triangle, volume=0.4,
                 tail=0.4)))

    write("gameover", mix(
        arpeggio(["G4", "F#4", "F4", "E4"], 0.22, duty=0.5, volume=0.3, tail=0.5),
        arpeggio(["G2", "F#2", "F2", "E2"], 0.22, wave_fn=triangle, volume=0.4, tail=0.5)))

    write("menu_move", tone(0.05, note_freq("E6"), wave_fn=square, volume=0.2, duty=0.25,
                            release=0.04))

    write("menu_select", concat(tone(0.05, note_freq("C6"), volume=0.25, duty=0.25, release=0.02),
                                tone(0.12, note_freq("G6"), volume=0.25, duty=0.25, release=0.1)))

    write("logo", mix(
        arpeggio(["C5", "G5", "C6", "E6"], 0.06, wave_fn=triangle, volume=0.3, tail=0.6),
        offset(tone(0.8, note_freq("C4"), wave_fn=triangle, volume=0.3, release=0.7), 0.18)))

    write("pause", concat(tone(0.06, note_freq("G5"), volume=0.2, duty=0.5, release=0.03),
                          tone(0.1, note_freq("C5"), volume=0.2, duty=0.5, release=0.08)))

    write("go", mix(
        tone(0.08, note_freq("A5"), volume=0.3, duty=0.25, release=0.03),
        offset(tone(0.3, note_freq("A6"), volume=0.3, duty=0.25, release=0.25), 0.1)))


# ---------- music loop ----------
def music():
    bpm = 132
    beat = 60.0 / bpm
    step = beat / 4  # sixteenth note
    bars = 8
    total = int(bars * 16 * step * RATE)
    out = [0.0] * total

    def put(track, at_step):
        start = int(at_step * step * RATE)
        for i, s in enumerate(track):
            if start + i < total:
                out[start + i] += s

    # A minor - F - C - G progression, twice
    chords = [
        ("A2", ["A4", "C5", "E5"]),
        ("F2", ["F4", "A4", "C5"]),
        ("C3", ["C5", "E5", "G5"]),
        ("G2", ["G4", "B4", "D5"]),
    ] * 2
    melody = [
        # (step in bar, note, length in steps) - played on bars 5 to 8
        [(0, "E5", 3), (4, "A5", 3), (8, "G5", 2), (10, "E5", 2), (12, "C5", 4)],
        [(0, "F5", 3), (4, "A5", 3), (8, "C6", 4), (12, "A5", 4)],
        [(0, "G5", 3), (4, "E5", 3), (8, "C5", 2), (10, "D5", 2), (12, "E5", 4)],
        [(0, "D5", 3), (4, "B4", 3), (8, "G4", 4), (12, "B4", 4)],
    ]

    for bar, (bass, arp) in enumerate(chords):
        base = bar * 16
        bass_f = note_freq(bass)
        # driving bass: eighth notes, octave jump on off-beats
        for e in range(8):
            f = bass_f * (2 if e % 2 else 1)
            put(tone(step * 1.8, f, wave_fn=triangle, volume=0.45, release=step), base + e * 2)
        # arpeggio
        for s in range(16):
            n = arp[s % 3]
            put(tone(step * 0.9, note_freq(n), volume=0.07, duty=0.125, release=step * 0.6),
                base + s)
        # drums
        for b in range(4):
            put(tone(0.12, 150, 45, volume=0.5, release=0.1), base + b * 4)  # kick
            put(noise_burst(0.03, volume=0.12, lowpass_start=1.0, lowpass_end=0.8),
                base + b * 4 + 2)  # hat
            if b % 2 == 1:
                put(noise_burst(0.12, volume=0.3, lowpass_start=0.7, lowpass_end=0.2),
                    base + b * 4)  # snare
        # lead melody on the second half
        if bar >= 4:
            for st, n, ln in melody[bar - 4]:
                put(tone(step * ln * 0.95, note_freq(n), volume=0.13, duty=0.25,
                         release=step * ln * 0.5, vibrato=5), base + st)

    write("music", out, peak=0.6)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    sfx()
    music()
