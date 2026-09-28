#!/usr/bin/env python3
"""Write the placeholder sounds into assets/audio/.

    python3 tools/make_sounds.py

These are scaffolding, not the game's sound. Decision 6 in `docs/to-launch.md`
is a licensed pack, and when it arrives each file here is replaced by one of
its own with the same name. They exist because a silent game cannot be played
to judge *when* a sound should fire, and that judgement is the part no asset
pack can make for us.

Everything is generated from arithmetic, so there is no licence to check and
nothing to attribute. Tuned to maqam Hijaz on D: the augmented second between
E-flat and F-sharp is what makes a chime sound like this sky rather than a
hotel lobby, and it costs nothing to pick the right notes.

Sample rates differ on purpose: the pad has nothing above a few hundred Hz, so
22 kHz is transparent for it and halves a file that would otherwise be the
largest thing in the repo after the fonts.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"

SFX_RATE = 44100
PAD_RATE = 22050

# Maqam Hijaz on D. The third is raised and the second lowered, so D->E-flat
# ->F-sharp is a semitone then an augmented second: the interval the ear reads
# as "this is not a Western scale".
D2, D3 = 73.416, 146.832
D4, EB4, FS4, G4, A4, BB4 = 293.665, 311.127, 369.994, 391.995, 440.0, 466.164
C5, D5, EB5, FS5, A5 = 523.251, 587.330, 622.254, 739.989, 880.0
D6 = 1174.66


def snap(freq: float, seconds: float) -> float:
    """The nearest frequency that completes whole cycles in `seconds`.

    A loop whose partials are cut mid-cycle clicks at the seam however
    carefully the envelope is shaped. Snapping every frequency to a multiple
    of 1/length makes the last sample meet the first exactly.
    """
    step = 1.0 / seconds
    return max(round(freq / step), 1) * step


def pluck(t: float, decay: float) -> float:
    """Struck and let go: no attack to speak of, then an exponential tail."""
    attack = min(t / 0.004, 1.0)
    return attack * math.exp(-t * decay)


def swell(t: float, length: float) -> float:
    """Comes up and goes down again, for anything that should feel arrived-at
    rather than struck."""
    x = t / length
    return math.sin(math.pi * min(x, 1.0)) ** 1.4


def render(length: float, voice, rate: int = SFX_RATE) -> list[float]:
    frames = int(length * rate)
    return [voice(i / rate) for i in range(frames)]


def bell(freq: float, decay: float = 6.0, detune: float = 1.004):
    """A struck tone with two inharmonic partials. Perfect harmonics sound
    like a test signal; the fifth and the slightly sharp octave are what make
    it read as something hit."""
    def voice(t: float) -> float:
        a = math.sin(2 * math.pi * freq * t)
        b = 0.42 * math.sin(2 * math.pi * freq * 2 * detune * t)
        c = 0.18 * math.sin(2 * math.pi * freq * 2.76 * t)
        return (a + b + c) * pluck(t, decay)
    return voice


def sequence(notes: list[tuple[float, float, float]], decay: float = 6.0):
    """Notes as (frequency, start, gain), all ringing on past each other."""
    voices = [(bell(f, decay), start, gain) for f, start, gain in notes]
    def voice(t: float) -> float:
        out = 0.0
        for v, start, gain in voices:
            if t >= start:
                out += gain * v(t - start)
        return out
    return voice


def normalise(samples: list[float], peak: float) -> list[float]:
    loudest = max((abs(s) for s in samples), default=0.0)
    if loudest <= 0.0:
        return samples
    return [s * peak / loudest for s in samples]


def write(name: str, samples: list[float], rate: int = SFX_RATE, peak: float = 0.5,
          fade: bool = True) -> None:
    samples = normalise(samples, peak)
    # A few milliseconds of fade at each end. Without it the first and last
    # sample are a step, and a step is a click.
    #
    # Never on the pad: it loops, and a fade to silence at both ends is a dip
    # you hear every twelve seconds — which is worse than the click it would
    # have prevented, and the snapping has already prevented that.
    edge = min(int(0.004 * rate), len(samples) // 2) if fade else 0
    for i in range(edge):
        k = i / edge
        samples[i] *= k
        samples[-1 - i] *= k
    raw = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    path = OUT / name
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(rate)
        f.writeframes(raw)
    print("  %-14s %5.2fs  %6.1f KB" % (name, len(samples) / rate, len(raw) / 1024))


# --- the seven the game asks for, plus the pad -------------------------------

def letter() -> list[float]:
    """One tile crossed. Played at a rising pitch as the word grows, so it is
    short and plain: anything with character becomes maddening at seven a
    second."""
    return render(0.075, lambda t: math.sin(2 * math.pi * A5 * t) * pluck(t, 46.0))


def word_ok() -> list[float]:
    """A word that is in the grid. A rising fourth, settled."""
    return render(0.55, sequence([(A4, 0.0, 1.0), (D5, 0.085, 0.95)]))


def word_bonus() -> list[float]:
    """A word the grid does not want but Arabic does. Brighter, and it climbs
    further: this is the moon filling."""
    return render(0.75, sequence(
        [(A4, 0.0, 0.8), (C5, 0.075, 0.85), (D5, 0.15, 0.95), (FS5, 0.225, 0.7)], decay=5.0))


def word_no() -> list[float]:
    """Not a word. There is no losing in this game, so this is a soft low
    knock and not a buzzer — the darkness is the pressure, not the noise."""
    def voice(t: float) -> float:
        a = math.sin(2 * math.pi * 98.0 * t)
        b = 0.3 * math.sin(2 * math.pi * 146.0 * t)
        return (a + b) * pluck(t, 17.0)
    return render(0.22, voice)


def level_done() -> list[float]:
    """The grid is full. The Hijaz tetrachord going up, unhurried."""
    return render(1.3, sequence(
        [(D4, 0.0, 0.9), (EB4, 0.13, 0.85), (FS4, 0.26, 0.9), (A4, 0.39, 1.0),
         (D5, 0.58, 0.8)], decay=4.2))


def star() -> list[float]:
    """One star lights. High, thin, and it hangs about afterwards."""
    def voice(t: float) -> float:
        tremolo = 1.0 + 0.3 * math.sin(2 * math.pi * 7.0 * t)
        a = math.sin(2 * math.pi * D6 * t)
        b = 0.5 * math.sin(2 * math.pi * A5 * t)
        c = 0.25 * math.sin(2 * math.pi * (D6 * 1.5) * t)
        return (a + b + c) * tremolo * pluck(t, 3.4)
    return render(1.0, voice)


def mansion() -> list[float]:
    """Twenty stars, and the figure draws. The only sound here with a bottom
    to it."""
    def voice(t: float) -> float:
        body = (math.sin(2 * math.pi * D2 * t)
                + 0.8 * math.sin(2 * math.pi * D3 * t)
                + 0.55 * math.sin(2 * math.pi * A4 * t)
                + 0.35 * math.sin(2 * math.pi * FS5 * t)
                + 0.2 * math.sin(2 * math.pi * D6 * t))
        return body * swell(t, 2.1) * (0.6 + 0.4 * math.exp(-t * 0.8))
    return render(2.1, voice)


def moon() -> list[float]:
    """The moon comes full and pays out."""
    def voice(t: float) -> float:
        a = math.sin(2 * math.pi * A4 * t)
        b = 0.7 * math.sin(2 * math.pi * D5 * t)
        c = 0.4 * math.sin(2 * math.pi * A5 * t)
        return (a + b + c) * swell(t, 1.0)
    return render(1.0, voice)


## How long the loop runs, and how far past its end it is rendered so a
## string still ringing at the seam comes back in at the beginning.
MUSIC_LENGTH = 24.0
MUSIC_OVERHANG = 4.0

D2_L, D3_L = 73.416, 146.832
A3_L, BB3_L, D4_L, EB4_L, FS4_L = 220.0, 233.082, 293.665, 311.127, 369.994


def _blank() -> list[float]:
    return [0.0] * int((MUSIC_LENGTH + MUSIC_OVERHANG) * PAD_RATE)


def _wrap(buf: list[float]) -> list[float]:
    """Fold the overhang onto the start. A tail that runs off the end of the
    loop is exactly the tail that should already be sounding when it begins
    again, so the seam has a string still ringing over it rather than silence
    meeting an attack."""
    keep = int(MUSIC_LENGTH * PAD_RATE)
    out = buf[:keep]
    for i in range(keep, len(buf)):
        out[i - keep] += buf[i]
    return out


def _drone(buf: list[float], freq: float, gain: float) -> None:
    f = snap(freq, MUSIC_LENGTH)
    for i in range(len(buf)):
        buf[i] += gain * math.sin(2 * math.pi * f * (i / PAD_RATE))


def _breathe(buf: list[float], period: float, depth: float) -> None:
    f = snap(1.0 / period, MUSIC_LENGTH)
    for i in range(len(buf)):
        wave = 0.5 * (1.0 - math.cos(2 * math.pi * f * (i / PAD_RATE)))
        buf[i] *= 1.0 - depth + depth * wave


def _pluck(buf: list[float], at: float, freq: float, gain: float, seed: int) -> None:
    """Karplus-Strong: a burst of noise in a delay line, averaged as it goes
    round. Two lines of arithmetic, and it sounds like a string being plucked,
    which no stack of sine waves ever does."""
    start_at = int(at * PAD_RATE)
    n = max(int(PAD_RATE / freq), 2)
    rng = random.Random(seed)
    line = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    # Low-pass the excitation twice, or the attack is a click and not a pluck.
    for _ in range(2):
        line = [(line[i] + line[i - 1]) * 0.5 for i in range(n)]
    for i in range(int(PAD_RATE * 3.2)):
        here = start_at + i
        if here >= len(buf):
            break
        value = line[i % n]
        buf[here] += value * gain
        line[i % n] = (value + line[(i + 1) % n]) * 0.5 * 0.9965


def music() -> list[float]:
    """One quiet layer: an oud heard from a long way off.

    Kareem chose it from four — a drone, this, wind over sand, and a turning
    figure — and the reason it wins is the silence. A phrase, then nothing for
    seconds. Background music for a word game is played for an hour at a time,
    and anything with a tune to follow becomes a thing to resent; what carries
    an hour is something that speaks now and then and is otherwise quiet.

    Maqam Hijaz on D, the same as every chime, so the two agree.
    """
    buf = _blank()
    _drone(buf, D2_L, 0.24)
    _drone(buf, D3_L, 0.09)
    # Nothing starts at zero. A pluck is a step out of silence, and every other
    # one is masked by what is already sounding — at the seam it is not, so the
    # loop ticked once a bar until the phrase was nudged off the line.
    phrase = [
        (0.4, D4_L), (1.5, EB4_L), (3.0, FS4_L), (5.8, D4_L),
        (9.0, A3_L), (10.2, BB3_L), (11.6, A3_L), (15.0, D4_L),
        (18.4, FS4_L), (19.6, EB4_L), (21.0, D4_L),
    ]
    for i, (at, freq) in enumerate(phrase):
        _pluck(buf, at, freq, 0.34, 1000 + i)
    _breathe(buf, MUSIC_LENGTH, 0.12)
    return _wrap(buf)


def tap() -> list[float]:
    """Any button. Lower and woodier than the wheel's tick so the two are not
    mistaken for each other — a tap is a decision and a tick is a letter."""
    def voice(t: float) -> float:
        a = math.sin(2 * math.pi * 520.0 * t)
        b = 0.35 * math.sin(2 * math.pi * 1560.0 * t)
        return (a + b) * pluck(t, 58.0)
    return render(0.055, voice)


def window() -> list[float]:
    """A window opening. The motion is a point of light widening into a panel,
    so the sound rises into place rather than landing on it."""
    def voice(t: float) -> float:
        x = t / 0.34
        sweep = A4 * (1.0 + 1.2 * min(x, 1.0) ** 0.7)
        rising = math.sin(2 * math.pi * sweep * t) * 0.6
        settle = bell(D5, 5.0)(max(t - 0.14, 0.0)) * 0.8 if t >= 0.14 else 0.0
        return rising * swell(t, 0.34) + settle
    return render(0.5, voice)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    print("writing placeholder sounds to %s" % OUT)
    for name, make in (
        ("letter.wav", letter), ("word_ok.wav", word_ok), ("word_bonus.wav", word_bonus),
        ("word_no.wav", word_no), ("level_done.wav", level_done), ("star.wav", star),
        ("mansion.wav", mansion), ("moon.wav", moon),
        ("tap.wav", tap), ("window.wav", window),
    ):
        write(name, make())
    # Quieter than the effects, and it never stops, so it must sit under them.
    write("music.wav", music(), PAD_RATE, peak=0.22, fade=False)


if __name__ == "__main__":
    main()
