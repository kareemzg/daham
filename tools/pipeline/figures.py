#!/usr/bin/env python3
"""Turn each mansion's stars into the points the game draws.

    python3 tools/pipeline/figures.py            # print them
    python3 tools/pipeline/figures.py --write    # into data/mansion-lore.json

A mansion is not a picture. It is one to nine real stars, and `FigureView`
already takes a list of points and fits them to its box. So the figure is a
projection, not a drawing: right ascension, declination and magnitude go in,
and points in a hundred-unit box come out.

Two things the projection must get right. East is LEFT in the sky, so the
right ascension axis is negated; and the dot's size comes from the star's
magnitude, without which الثريا is nine identical dots inside one degree
instead of the six bright and three faint that the tradition describes.

The stars themselves are the judgement call, and `STARS` below records it.
Where the common tables disagree with Ibn Qutaybah, Ibn Qutaybah wins and the
note says why: this is a game about the Arabs' sky, and the tables are written
from the Greek one.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LORE = REPO_ROOT / "data" / "mansion-lore.json"

## The box a figure is fitted into before the engine scales it again.
BOX = 100.0


def ra(h: int, m: int, s: float) -> float:
    """Right ascension, hours to degrees."""
    return (h + m / 60 + s / 3600) * 15.0


def dec(d: int, m: int, s: float) -> float:
    """Declination, sexagesimal to degrees."""
    return math.copysign(abs(d) + m / 60 + s / 3600, d)


## name, right ascension, declination, visual magnitude.
CATALOGUE = {
    # الحمل
    "α Ari": (ra(2, 7, 10.29), dec(23, 27, 46.0), 2.01),
    "β Ari": (ra(1, 54, 38.35), dec(20, 48, 29.9), 2.64),
    "γ Ari": (ra(1, 53, 31.80), dec(19, 17, 45.0), 4.62),
    "35 Ari": (ra(2, 43, 27.11), dec(27, 42, 25.8), 4.65),
    "39 Ari": (ra(2, 47, 54.44), dec(29, 14, 50.7), 4.52),
    "41 Ari": (ra(2, 49, 58.99), dec(27, 15, 38.8), 3.61),
    # الثور: الثريا ثم القلاص (Hyades)
    "η Tau": (ra(3, 47, 29.06), dec(24, 6, 18.9), 2.85),
    "27 Tau": (ra(3, 49, 9.73), dec(24, 3, 12.7), 3.62),
    "17 Tau": (ra(3, 44, 52.52), dec(24, 6, 48.4), 3.72),
    "20 Tau": (ra(3, 45, 49.59), dec(24, 22, 4.3), 3.87),
    "23 Tau": (ra(3, 46, 19.56), dec(23, 56, 54.5), 4.14),
    "19 Tau": (ra(3, 45, 12.48), dec(24, 28, 2.6), 4.30),
    "28 Tau": (ra(3, 49, 11.20), dec(24, 8, 12.6), 5.05),
    "16 Tau": (ra(3, 44, 48.20), dec(24, 17, 22.5), 5.45),
    "21 Tau": (ra(3, 46, 2.89), dec(24, 31, 40.8), 6.43),
    "α Tau": (ra(4, 35, 55.20), dec(16, 30, 35.1), 0.87),
    "θ2 Tau": (ra(4, 28, 39.67), dec(15, 52, 15.4), 3.40),
    "γ Tau": (ra(4, 19, 47.53), dec(15, 37, 39.7), 3.65),
    "δ1 Tau": (ra(4, 22, 56.03), dec(17, 32, 33.3), 3.77),
    "ε Tau": (ra(4, 28, 36.93), dec(19, 10, 49.9), 3.53),
    # الجوزاء عند العرب: رأسها
    "λ Ori": (ra(5, 35, 8.28), dec(9, 56, 3.0), 3.47),
    "φ1 Ori": (ra(5, 34, 49.24), dec(9, 29, 22.5), 4.39),
    "φ2 Ori": (ra(5, 36, 54.33), dec(9, 17, 29.1), 4.09),
    # ذراع الأسد وميسانها
    "γ Gem": (ra(6, 37, 42.70), dec(16, 23, 57.9), 1.93),
    "ξ Gem": (ra(6, 45, 17.43), dec(12, 53, 45.8), 3.35),
    "α Gem": (ra(7, 34, 36.00), dec(31, 53, 19.1), 1.90),
    "β Gem": (ra(7, 45, 19.36), dec(28, 1, 34.7), 1.16),
}


## Per mansion: its own stars, how they join, the fainter stars of its figure
## behind them, and where the reading came from.
##
## `join` is pairs of indexes into `stars`, not one chain: a figure branches,
## and a cluster has no lines at all — a line drawn through الثريا would say
## something about those stars that is not true.
STARS = {
    1: {
        "stars": ["β Ari", "γ Ari"],
        "join": [[0, 1]],
        "behind": ["α Ari"],
        "note": "ابن قتيبة: «كوكبان، يقال إنهما قرنا الحمل». والقرنان β وγ؛ "
                "أما α (الرأس) فتجعلها بعض الجداول الأجنبية من المنزلة، وليست منها.",
    },
    2: {
        "stars": ["35 Ari", "39 Ari", "41 Ari"],
        "join": [[0, 1], [1, 2], [2, 0]],
        "behind": ["α Ari", "β Ari"],
        "note": "«ثلاثة كواكب خفية كأنها أثافي» — والأثافي ثلاثة أحجار تُنصب "
                "للقدر، فالوصل بينها مثلّث لا خطّ.",
    },
    3: {
        "stars": ["η Tau", "27 Tau", "17 Tau", "20 Tau", "23 Tau",
                  "19 Tau", "28 Tau", "16 Tau", "21 Tau"],
        "join": [],
        "behind": [],
        "note": "«ستة أنجم ظاهرة، في خللها نجوم كثيرة خفية» — عنقود لا صورة، "
                "فلا خطوط. وأقدارها من 2.85 إلى 6.43 هي ما يصدّق النصّ.",
    },
    4: {
        "stars": ["α Tau"],
        "join": [],
        "behind": ["θ2 Tau", "γ Tau", "δ1 Tau", "ε Tau"],
        "note": "«كوكب أحمر منير يتلو الثريا» — نجمٌ واحد عند ابن قتيبة. "
                "والقلاص خلفه تُظهر أنه رأس الثور، وهي أول مثال على الصورة الباهتة.",
    },
    5: {
        "stars": ["λ Ori", "φ1 Ori", "φ2 Ori"],
        "join": [[0, 1], [0, 2]],
        "behind": [],
        "note": "«ثلاثة كواكب صغار، كأثافيّ القِدر، في رأس الجوزاء».",
    },
    6: {
        "stars": ["γ Gem", "ξ Gem"],
        "join": [[0, 1]],
        "behind": [],
        "note": "«نجمان مضيئان متساويان في القدر» — والقدران هنا 1.93 و3.35، "
                "وليسا متساويين. يحتاج تحقيقاً: بعض المصادر تجعلها γ وμ.",
    },
    7: {
        "stars": ["α Gem", "β Gem"],
        "join": [[0, 1]],
        "behind": [],
        "note": "«كوكبان، بينهما قيد سوط» — وبينهما نحو أربع درجات ونصف، "
                "فالوصف دقيق. وهي الذراع المقبوضة؛ والمبسوطة نجمان آخران "
                "وليست من المنازل.",
    },
}


def project(names: list[str]) -> tuple[list[dict], float, tuple[float, float]]:
    """Stars onto a tangent plane about their own centre, east to the left."""
    rows = [(n,) + CATALOGUE[n] for n in names]
    ra0 = sum(r[1] for r in rows) / len(rows)
    de0 = sum(r[2] for r in rows) / len(rows)
    squash = math.cos(math.radians(de0))
    flat = []
    for name, r, d, mag in rows:
        offset = ((r - ra0 + 540) % 360) - 180
        flat.append((name, -offset * squash, -(d - de0), mag))
    return flat, ra0, (ra0, de0)


def fit(flat: list, own: int) -> tuple[list[dict], float]:
    """Into a BOX-wide square, framed on the MANSION, not on what is behind it.

    Framing on everything let one distant background star decide the scale:
    البطين's three faint stars sit ten degrees from the ram's horn, and
    including the horn squashed the mansion into a corner of its own card. So
    the frame comes from the mansion's stars and the figure behind may run off
    the edge, which is what a figure behind is supposed to do.
    """
    frame = flat[:own] if own else flat
    xs = [f[1] for f in frame]
    ys = [f[2] for f in frame]
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    if span <= 1e-9:                      # a one-star mansion: الدبران
        xs = [f[1] for f in flat]
        ys = [f[2] for f in flat]
        span = max(max(xs) - min(xs), max(ys) - min(ys), 1e-9)
    scale = BOX / span
    mid_x = (max(xs) + min(xs)) / 2
    mid_y = (max(ys) + min(ys)) / 2
    out = [
        {"star": n, "x": round((x - mid_x) * scale, 1),
         "y": round((y - mid_y) * scale, 1), "mag": m}
        for n, x, y, m in flat
    ]
    return out, span


def figure(mansion: int) -> dict:
    """One mansion's figure: its own stars, the faint ones, the joins."""
    spec = STARS[mansion]
    names = spec["stars"] + spec["behind"]
    flat, _, _ = project(names)
    own = len(spec["stars"])
    points, span = fit(flat, own)
    return {
        "stars": points[:own],
        "behind": points[own:],
        "join": spec["join"],
        "span_deg": round(span, 2),
        "note": spec["note"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true", help="into data/mansion-lore.json")
    args = parser.parse_args()

    figures = {str(n): figure(n) for n in sorted(STARS)}
    for n, f in figures.items():
        mags = [p["mag"] for p in f["stars"]]
        print("%-3s %d نجماً%s  اتّساع %.2f°  أقدار %.2f–%.2f  %s" % (
            n, len(f["stars"]),
            " (+%d خلفها)" % len(f["behind"]) if f["behind"] else "        ",
            f["span_deg"], min(mags), max(mags),
            "عنقود" if not f["join"] else "%d خطاً" % len(f["join"])))

    if not args.write:
        return
    lore = json.loads(LORE.read_text(encoding="utf-8"))
    for n, f in figures.items():
        lore["mansions"].setdefault(n, {})["figure"] = f
    LORE.write_text(json.dumps(lore, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("\nwrote %d figures into %s" % (len(figures), LORE.relative_to(REPO_ROOT)))


if __name__ == "__main__":
    main()
