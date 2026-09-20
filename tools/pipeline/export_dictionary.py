#!/usr/bin/env python3
"""Export the playable word list from the Arabic dictionary database.

    python3 tools/pipeline/export_dictionary.py --report
    python3 tools/pipeline/export_dictionary.py --write

Reads the SQLite built by the sibling `arabic-words-for-game` project and writes
`tools/pipeline/dictionary.tsv`: one line per word, `key<TAB>zipf`.

This file is BUILD INPUT, not a game asset. Nothing here ships: each level file
already carries its own grid words and bonus words, so the engine never needs to
look a word up at run time. Keeping it that way keeps the shipped game free of
anything derived from the dictionary's own sources.

Keys use the game's normalisation, not the database's. The database folds ة into
ه and ى into ي; this game keeps them apart, because the wheel only ever offers
the letters of the base word, so there is no ه/ة ambiguity to protect against,
and folding would spell مدرسه on the grid.
"""

from __future__ import annotations

import argparse
import sqlite3
from collections import Counter
from pathlib import Path

import arabic

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = (
    REPO_ROOT.parent / "arabic-words-for-game" / "data" / "out" / "arabic_dictionary.sqlite"
)
DEFAULT_OUT = REPO_ROOT / "tools" / "pipeline" / "dictionary.tsv"

## A wheel holds between three and seven letters.
MIN_LENGTH = 3
MAX_LENGTH = 7


def collect(source: Path) -> dict[str, float]:
    """Every playable key, each with the highest frequency any reading of it has.

    A key can have several readings (كتب is a noun and a verb, آثم and إثم share
    a skeleton). For the game they are one word, and the easiest reading is the
    one that decides how hard it is to think of.
    """
    if not source.exists():
        raise SystemExit(
            f"dictionary database not found: {source}\n"
            "Build it in the arabic-words-for-game project, or pass --source."
        )
    words: dict[str, float] = {}
    connection = sqlite3.connect(source)
    try:
        rows = connection.execute("SELECT skeleton, zipf FROM entries")
        for skeleton, zipf in rows:
            if not skeleton:
                continue
            key = arabic.normalise(skeleton)
            if not (MIN_LENGTH <= len(key) <= MAX_LENGTH):
                continue
            value = float(zipf or 0.0)
            if value > words.get(key, -1.0):
                words[key] = value
    finally:
        connection.close()
    return words


def report(words: dict[str, float]) -> None:
    print(f"keys: {len(words)}")

    lengths = Counter(len(k) for k in words)
    print("by length:")
    for n in sorted(lengths):
        print(f"  {n}: {lengths[n]}")

    # zipf 0 means "absent from the frequency list", not "rare". The list is not
    # exhaustive, so this bucket holds obscure words AND ordinary ones that the
    # frequency source simply never saw. Do not read it as a difficulty.
    print("by frequency:")
    print(f"  no frequency data (zipf = 0): {sum(1 for z in words.values() if z == 0.0)}")
    for cut in (1.5, 2.0, 2.5, 3.0, 3.5, 4.0):
        print(f"  zipf >= {cut}: {sum(1 for z in words.values() if z >= cut)}")

    letters = Counter()
    for key in words:
        letters.update(key)
    print(f"alphabet in use ({len(letters)} letters): {''.join(sorted(letters))}")
    if "ة" not in letters or "ى" not in letters:
        print("  WARNING: ة or ى is missing, so the keys were folded somewhere")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--report", action="store_true", help="describe the export")
    parser.add_argument("--write", action="store_true", help="write the TSV")
    args = parser.parse_args()

    words = collect(args.source)
    if args.report or not args.write:
        report(words)

    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as handle:
            handle.write("# key\tzipf — built by export_dictionary.py, do not hand-edit\n")
            for key in sorted(words):
                handle.write(f"{key}\t{words[key]:.2f}\n")
        size = args.out.stat().st_size
        print(f"wrote {args.out.relative_to(REPO_ROOT)}  {len(words)} words, {size // 1024} KB")


if __name__ == "__main__":
    main()
