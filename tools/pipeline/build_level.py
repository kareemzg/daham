#!/usr/bin/env python3
"""Build one level JSON from a word list.

    python3 tools/pipeline/build_level.py --preview
    python3 tools/pipeline/build_level.py --write

Levels land in `data/levels/` and are never hand-edited: change the definition
here (or, later, the generator that feeds it) and rebuild.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import arabic
from crossword import Placement, grid_size, layout, render

REPO_ROOT = Path(__file__).resolve().parents[2]
LEVELS_DIR = REPO_ROOT / "data" / "levels"

# The sample level that runs through every design artboard and the engine slice.
SAMPLE = {
    "id": "m04-12",
    "mansion": 4,
    "mansion_name": "الدبران",
    "season": "spring",
    "index_in_mansion": 12,
    "words": ["كتاب", "كاتب", "كتب", "تاب", "بات"],
    "bonus": ["بكت", "كبت"],
}


def build(definition: dict) -> dict:
    words = [arabic.normalise(word) for word in definition["words"]]
    bonus = sorted({arabic.normalise(word) for word in definition["bonus"]})
    letters = arabic.letters_for(words)

    overlap = sorted(set(words) & set(bonus))
    if overlap:
        raise ValueError(f"words also listed as bonus: {overlap}")

    placements = layout(words)
    rows, cols = grid_size(placements)

    return {
        "id": definition["id"],
        "mansion": definition["mansion"],
        "mansion_name": definition["mansion_name"],
        "season": definition["season"],
        "index_in_mansion": definition["index_in_mansion"],
        "letters": letters,
        "grid": {"rows": rows, "cols": cols},
        "words": [
            {
                "text": p.word,
                "row": p.row,
                "col": p.col,
                "direction": p.direction,
            }
            for p in sorted(placements, key=lambda p: (p.row, p.col))
        ],
        "bonus": bonus,
    }


def _check(level: dict, placements: tuple[Placement, ...]) -> None:
    """Belt and braces: re-derive the grid from the exported JSON and compare."""
    from_json: dict[tuple[int, int], str] = {}
    for entry in level["words"]:
        for index, letter in enumerate(entry["text"]):
            if entry["direction"] == "h":
                cell = (entry["row"], entry["col"] + index)
            else:
                cell = (entry["row"] + index, entry["col"])
            assert from_json.get(cell, letter) == letter, f"clash at {cell}"
            from_json[cell] = letter
    from_placements: dict[tuple[int, int], str] = {}
    for placement in placements:
        for cell, letter in placement.cells():
            from_placements[cell] = letter
    assert from_json == from_placements, "exported JSON does not match the layout"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write the JSON to data/levels/")
    parser.add_argument("--preview", action="store_true", help="draw the grid in the terminal")
    args = parser.parse_args()

    level = build(SAMPLE)
    placements = layout([arabic.normalise(word) for word in SAMPLE["words"]])
    _check(level, placements)

    if args.preview or not args.write:
        rows, cols = level["grid"]["rows"], level["grid"]["cols"]
        print(f"{level['id']}  {rows}x{cols}  wheel: {' '.join(level['letters'])}")
        print(render(placements))
        for entry in level["words"]:
            direction = "أفقي" if entry["direction"] == "h" else "عمودي"
            print(f"  {entry['text']:<6} {direction}  row={entry['row']} col={entry['col']}")
        print(f"  bonus: {' '.join(level['bonus'])}")

    if args.write:
        LEVELS_DIR.mkdir(parents=True, exist_ok=True)
        path = LEVELS_DIR / f"{level['id']}.json"
        path.write_text(json.dumps(level, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {path.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
