#!/usr/bin/env python3
"""Turn the word list into levels.

    python3 tools/pipeline/generate.py --count 20            # try it, print it
    python3 tools/pipeline/generate.py --count 560 --write   # fill data/levels/

For each level it picks a base word for the wheel, finds every word spellable
from its letters, chooses a handful that interlock into a crossword, and leaves
the rest as bonus words. A level that will not interlock is skipped and the next
base is tried, so the run always produces the number of levels asked for or says
why it could not.
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import arabic
import mansions
from crossword import LayoutFailed, _runs, grid_size, layout, render
from lexicon import Lexicon

REPO_ROOT = Path(__file__).resolve().parents[2]
LEVELS_DIR = REPO_ROOT / "data" / "levels"

## A word has to be common enough to be worth putting in the grid, and the
## bonus list can reach further down: finding an unexpected word is a reward,
## being unable to finish the grid is not.
GRID_ZIPF = 2.5
BONUS_ZIPF = 1.6
MAX_BONUS = 60

## Quality gates. A base word can be common and still make a poor level: إياه is
## known to everyone and its letters spell almost nothing. Rather than guess at
## which words are pronouns and particles, judge a base by what it yields.
MIN_BONUS = 2
MIN_GRID_WORDS = 4

## Cheap caps while asking "can this set interlock at all?", fuller ones once the
## set is settled and the arrangement itself matters.
PROBE_CAPS = {"solution_cap": 6, "node_cap": 6_000}
FINAL_CAPS = {"solution_cap": 64, "node_cap": 60_000}


def base_lengths(level: int) -> tuple[int, int]:
    """How many letters the wheel holds, widening across the year."""
    if level <= 40:
        return 4, 4
    if level <= 140:
        return 4, 5
    if level <= 300:
        return 5, 6
    return 6, 7


def base_floor(level: int) -> float:
    """How well known the base word has to be. Eases off as the player learns."""
    share = min(level, mansions.TOTAL_LEVELS) / mansions.TOTAL_LEVELS
    return round(4.0 - share * 1.2, 2)


def grid_target(base_length: int) -> int:
    """How many words go in the grid, the base word included."""
    return {4: 4, 5: 5, 6: 6, 7: 7}.get(base_length, 5)


def choose_grid_words(base: str, candidates: list[str], target: int) -> list[str]:
    """Grow a set of words that interlock, best-known first.

    Each candidate is accepted only if the whole set still lays out with it, so
    whatever comes back is known to be buildable. Adding a word can break a set
    that worked without it, which is why this tests the set and not the word.
    """
    chosen = [base]
    for word in candidates:
        if len(chosen) >= target:
            break
        try:
            layout(chosen + [word], **PROBE_CAPS)
        except LayoutFailed:
            continue
        chosen.append(word)
    return chosen


def build(level: int, base: str, lexicon: Lexicon) -> dict | None:
    """One level, or None when this base will not make one."""
    spellable = lexicon.subwords(base, min_zipf=BONUS_ZIPF)
    if not spellable:
        return None

    for_grid = sorted(
        (w for w in spellable if lexicon.zipf[w] >= GRID_ZIPF),
        key=lambda w: (-lexicon.zipf[w], -len(w), w),
    )
    target = grid_target(len(base))
    # A thin pool cannot fill a grid, and trying to lay one out is the expensive
    # part, so bail before it rather than after.
    if len(for_grid) < target - 1:
        return None
    words = choose_grid_words(base, for_grid, target)
    if len(words) < max(MIN_GRID_WORDS, target - 1):
        return None

    try:
        placements = layout(words, **FINAL_CAPS)
    except LayoutFailed:
        return None
    rows, cols = grid_size(placements)

    in_grid = set(words)
    bonus = sorted(
        (w for w in dict.fromkeys(spellable) if w not in in_grid),
        key=lambda w: (-lexicon.zipf[w], w),
    )[:MAX_BONUS]
    # The moon meter fills on bonus words. A level with none leaves it dead.
    if len(bonus) < MIN_BONUS:
        return None

    return {
        **{"id": mansions.level_id(level)},
        **mansions.place(level),
        "letters": arabic.letters_for(words),
        "grid": {"rows": rows, "cols": cols},
        "words": [
            {"text": p.word, "row": p.row, "col": p.col, "direction": p.direction}
            for p in sorted(placements, key=lambda p: (p.row, p.col))
        ],
        "bonus": sorted(bonus),
        "_placements": placements,
    }


def generate(count: int, start: int, seed: int, lexicon: Lexicon) -> tuple[list[dict], list[int]]:
    """Levels `start` .. `start + count - 1`, plus the ones that could not be built."""
    rng = random.Random(seed)
    used_bases: set[str] = set()
    built: list[dict] = []
    skipped: list[int] = []

    for level in range(start, start + count):
        low, high = base_lengths(level)
        pool = [
            base
            for base in lexicon.bases(
                min_length=low, max_length=high, min_zipf=base_floor(level)
            )
            if base not in used_bases
        ]
        # Shuffled so consecutive levels are not all near-synonyms from the top
        # of the frequency list, seeded so a rebuild produces the same levels.
        rng.shuffle(pool)

        made = None
        for base in pool[:40]:
            made = build(level, base, lexicon)
            if made is not None:
                used_bases.add(base)
                break
        if made is None:
            skipped.append(level)
        else:
            built.append(made)
    return built, skipped


def verify(level: dict) -> None:
    """Re-read the exported level the way the engine will, and check it holds.

    The layout search already guarantees a valid grid; this catches the step
    after it, where coordinates are written out and could be written wrong.
    """
    cells: dict[tuple[int, int], str] = {}
    for entry in level["words"]:
        for index, letter in enumerate(entry["text"]):
            if entry["direction"] == "h":
                cell = (entry["row"], entry["col"] + index)
            else:
                cell = (entry["row"] + index, entry["col"])
            if cells.get(cell, letter) != letter:
                raise AssertionError(f"{level['id']}: letters clash at {cell}")
            cells[cell] = letter
        if not 0 <= entry["row"] < level["grid"]["rows"]:
            raise AssertionError(f"{level['id']}: '{entry['text']}' starts outside the grid")

    runs = sorted(_runs(cells))
    expected = sorted(entry["text"] for entry in level["words"])
    if runs != expected:
        raise AssertionError(f"{level['id']}: grid reads {runs}, expected {expected}")

    pool = list(level["letters"])
    for entry in level["words"]:
        left = list(pool)
        for letter in entry["text"]:
            if letter not in left:
                raise AssertionError(
                    f"{level['id']}: '{entry['text']}' needs letters the wheel lacks"
                )
            left.remove(letter)
    if set(level["bonus"]) & {entry["text"] for entry in level["words"]}:
        raise AssertionError(f"{level['id']}: a word is both a grid word and a bonus word")


def write(levels: list[dict]) -> None:
    LEVELS_DIR.mkdir(parents=True, exist_ok=True)
    for level in levels:
        payload = {k: v for k, v in level.items() if not k.startswith("_")}
        path = LEVELS_DIR / f"{payload['id']}.json"
        path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )


def describe(level: dict) -> str:
    rows, cols = level["grid"]["rows"], level["grid"]["cols"]
    lines = [
        f"{level['id']}  {level['mansion_name']}  {rows}x{cols}"
        f"  wheel: {' '.join(level['letters'])}"
        f"  grid: {len(level['words'])}  bonus: {len(level['bonus'])}",
        render(level["_placements"]),
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--count", type=int, default=10)
    parser.add_argument("--start", type=int, default=1, help="first global level number")
    parser.add_argument("--seed", type=int, default=20260920)
    parser.add_argument("--write", action="store_true", help="write data/levels/")
    parser.add_argument("--quiet", action="store_true", help="counts only, no grids")
    args = parser.parse_args()

    lexicon = Lexicon.load()
    print(f"word list: {len(lexicon)} words")

    built, skipped = generate(args.count, args.start, args.seed, lexicon)
    for level in built:
        verify(level)
    if not args.quiet:
        for level in built:
            print()
            print(describe(level))

    print()
    print(f"built {len(built)} of {args.count}")
    if skipped:
        print(f"could not build: {skipped}")
    if built:
        grid_words = sum(len(l["words"]) for l in built) / len(built)
        bonus_words = sum(len(l["bonus"]) for l in built) / len(built)
        print(f"average grid words {grid_words:.1f}, average bonus words {bonus_words:.1f}")

    if args.write:
        write(built)
        print(f"wrote {len(built)} files to {LEVELS_DIR.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
