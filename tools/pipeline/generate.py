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

## A grid of this many words or more opens with one cell already filled.
GIFT_FROM = 10

## Cheap caps while asking "can this set interlock at all?", fuller ones once the
## set is settled and the arrangement itself matters.
PROBE_CAPS = {"solution_cap": 6, "node_cap": 6_000}
FINAL_CAPS = {"solution_cap": 64, "node_cap": 60_000}


## Levels in one season: seven mansions of twenty.
SEASON_LEVELS = 7 * mansions.LEVELS_PER_MANSION

## How wide the wheel is, one row per season and one rung per mansion.
##
## Two things are wrong with drawing a single curve across the whole year, and
## both were found by playing rather than by reading. The build ships a season
## at a time, so a year-long curve hands the first release nothing but its
## gentle end. And four bands over 140 levels means 35 levels with nothing
## moving at all: thirty-one levels in, every one of them had been a four-letter
## wheel with four grid words, and the player felt a flat line, which is what it
## was.
##
## So the mansion is the rung. Twenty-eight mansions, twenty-eight rungs, and a
## player already reads a mansion as a chapter, so the step lands somewhere they
## can feel. The rung's floor rises season by season, and `base_floor` keeps
## loosening across the year on top of it, so the same wheel is built from rarer
## words the later it appears.
##
## Each entry is (wheel width, grid words at the mansion's first level, grid
## words at its last). The words climb between the two across the mansion's
## twenty levels, so the pair is a small ramp rather than a setting.
##
## Two mansions can share a wheel width — there are seven mansions to a season
## and only four widths — and when they do, the second one starts where the
## first left off. Without that the twenty-first level was a plain repeat of the
## first, and forty levels covered the same ground twice.
##
## The tail of one mansion is allowed to be harder than the head of the next:
## a chapter opening a little gentler and then climbing past the last one is a
## rhythm, not a flat line. What must never happen is a mansion starting below
## the one before it **inside a season**, and `_rungs_rise` checks that.
##
## Across a season boundary it starts lower on purpose, and that is the price of
## the other decision: a build ships one season, so each season has to be a
## whole arc from a small wheel to a seven-letter one. The two cannot both hold
## — a year that never steps back would make summer nothing but seven-letter
## wheels. So the year is a sawtooth whose teeth rise: each season opens above
## the one before it, climbs further, and `base_floor` keeps loosening
## underneath, so summer's four-letter wheels are built from rarer words than
## spring's ever were.
## The word counts come from playing, not from the pipeline's comfort, and the
## wheel widths come from what was measured: a four-letter wheel lays out ten
## words four times in ten and costs nothing; a six-letter one carries fourteen
## comfortably but only a quarter of them reach fifteen; a seven-letter one
## reaches eighteen four times in ten. So the seven-letter wheel arrives at the
## fourth mansion, not the fifth — a six chokes above fourteen while a seven
## carries eighteen at twice the rate.
##
## The screen stopped being the ceiling when the board took the window's whole
## height: eighteen words lay out in about ten columns by twelve rows, which is
## a 33-point cell on a 19.5:9 phone. What costs now is the search, twenty-odd
## seconds a base, so a full run of the year is measured in hours rather than
## the fourteen seconds it once took.
SEASON_RUNGS = (
    (  # spring
        (4, 4, 10), (5, 10, 12), (6, 12, 14), (7, 15, 16), (7, 16, 18), (7, 18, 20), (7, 20, 22),
    ),
    (  # summer
        (5, 10, 12), (6, 12, 14), (7, 15, 16), (7, 16, 18), (7, 18, 20), (7, 20, 22), (7, 22, 22),
    ),
    (  # autumn
        (6, 12, 14), (7, 15, 16), (7, 16, 18), (7, 18, 20), (7, 20, 22), (7, 22, 22), (7, 22, 22),
    ),
    (  # winter
        (7, 15, 16), (7, 16, 18), (7, 18, 20), (7, 20, 22), (7, 22, 22), (7, 22, 22), (7, 22, 22),
    ),
)


def _rung(level: int) -> tuple[int, int, int]:
    season = min((level - 1) // SEASON_LEVELS, len(SEASON_RUNGS) - 1)
    mansion = ((level - 1) % SEASON_LEVELS) // mansions.LEVELS_PER_MANSION
    return SEASON_RUNGS[season][mansion]


def _rungs_rise() -> None:
    """Inside a season no mansion opens easier than the one before it, and each
    season opens above the last. The sawtooth between seasons is deliberate; a
    step backwards inside one is not."""
    opening = (0, 0)
    for season, rungs in enumerate(SEASON_RUNGS):
        if len(rungs) != 7:
            raise ValueError(f"season {season} has {len(rungs)} mansions, not 7")
        previous = (0, 0)
        for mansion, (width, low, high) in enumerate(rungs):
            if low > high or not 4 <= width <= 7 or not 4 <= low <= 22 or not 4 <= high <= 22:
                raise ValueError(f"season {season} mansion {mansion}: {(width, low, high)}")
            if (width, low) < previous:
                raise ValueError(
                    f"season {season} mansion {mansion} opens at {(width, low)}, "
                    f"below {previous} inside the same season"
                )
            previous = (width, low)
        if rungs[0][:2] < opening:
            raise ValueError(
                f"season {season} opens at {rungs[0][:2]}, below {opening}"
            )
        opening = rungs[0][:2]


_rungs_rise()


def base_lengths(level: int) -> tuple[int, int]:
    """How many letters the wheel holds. One width per mansion."""
    width = _rung(level)[0]
    return width, width


## No grid may be wider or taller than this. The board gives the grid about
## 47 per cent of a phone's height and the full width of the design, so at
## thirteen columns a cell is around 27 points — small but legible for an
## isolated Arabic letterform. Past that it is not a hard level, it is an
## unreadable one, and the search happily produced an eighteen-column grid.
MAX_SPAN = 13


def base_floor(level: int) -> float:
    """How well known the base word has to be. Eases off as the player learns.

    Two things loosen it, and both must. The first is the year: a player
    forty levels in knows the game. The second is the size of the grid, and
    leaving that out cost seventeen of the twenty levels in the last mansion
    of spring — they simply would not build. A grid of twenty-two words needs
    a base whose letters spell twenty-two other words, and demanding that it
    ALSO be among the hundred-odd commonest seven-letter words leaves a pool
    of 131 to search. Loosened by size, the same pool is 513.
    """
    share = min(level, mansions.TOTAL_LEVELS) / mansions.TOTAL_LEVELS
    year = 4.0 - share * 1.2
    room = 4.0 - 0.09 * (grid_target(level) - 4)
    return round(min(year, room), 2)


def grid_target(level: int) -> int:
    """How many words go in the grid, the base word included.

    The fine lever, and the one that was missing. Tying this to the wheel's
    width made width the only thing that ever moved, so the whole of a band felt
    like one level played over and over. Climbing it inside each mansion puts a
    step every five levels, and the two levers together mean something changes
    far more often than either alone.

    A narrow wheel carries more words than it looks: measured over sixty bases,
    seven in ten four-letter wheels lay out six words and two in three lay out
    seven, and five-letter wheels manage seven almost always.
    """
    _, low, high = _rung(level)
    steps = high - low + 1
    within = (level - 1) % mansions.LEVELS_PER_MANSION
    return low + min(within * steps // mansions.LEVELS_PER_MANSION, steps - 1)


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
    target = grid_target(level)
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
    if cols > MAX_SPAN or rows > MAX_SPAN:
        return None

    in_grid = set(words)
    bonus = sorted(
        (w for w in dict.fromkeys(spellable) if w not in in_grid),
        key=lambda w: (-lexicon.zipf[w], w),
    )[:MAX_BONUS]
    # The moon meter fills on bonus words. A level with none leaves it dead.
    if len(bonus) < MIN_BONUS:
        return None

    # Every other word the wheel can spell. Not a reward — the moon and the
    # coins belong to `bonus`, and `MAX_BONUS` caps that on purpose — but the
    # game needs to tell "a real word that is not in this level" from "not a
    # word". Without it the grid's own cap becomes a lie about Arabic: a wheel
    # of seven letters spells far more than sixty words, and the overflow was
    # being met with «ليست كلمة» and counted against the player's lanterns.
    # Two letters, because that is the shortest the wheel accepts.
    everything = lexicon.subwords(base, min_zipf=0.0, min_length=2)
    known = sorted(set(everything) - in_grid - set(bonus))

    # A letter given away, on the levels big enough to want one. The rule is the
    # grid's size rather than a schedule, so it arrives when the board starts
    # looking daunting and keeps pace if the ramp is ever retuned. The first
    # letter of the longest word: it is the word most worth a foothold, and its
    # first letter is where the eye goes in a right-to-left grid.
    gift = None
    if len(words) >= GIFT_FROM:
        longest = max(placements, key=lambda p: (len(p.word), p.word))
        gift = [longest.row, longest.col]

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
        "known": known,
        "gift": gift,
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

    # And each word has to be a run of its own. Matching multisets is not enough:
    # a word can sit inside another while some unrelated run spells it elsewhere,
    # and then the player fills every cell and the level never finishes.
    for entry in level["words"]:
        length = len(entry["text"])
        if entry["direction"] == "h":
            before = (entry["row"], entry["col"] - 1)
            after = (entry["row"], entry["col"] + length)
        else:
            before = (entry["row"] - 1, entry["col"])
            after = (entry["row"] + length, entry["col"])
        if before in cells or after in cells:
            raise AssertionError(
                f"{level['id']}: '{entry['text']}' is not a run of its own"
            )

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
