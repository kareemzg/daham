# Content pipeline

Generates the level JSON in `data/levels/`. Nothing in that folder is edited by
hand: change the definition here and rebuild.

```bash
python3 tools/pipeline/build_level.py --preview   # draw the grid in the terminal
python3 tools/pipeline/build_level.py --write     # write data/levels/<id>.json
```

No dependencies beyond the standard library. Run it from the repo root.

## Files

- `arabic.py` — normalisation and Eastern Arabic digits. Mirrored in
  `scripts/arabic.gd`. If a rule changes here it must change there, or a player
  can spell a word the grid refuses.
- `crossword.py` — the layout search. Words interlock; the search keeps the most
  compact valid arrangement.
- `build_level.py` — the level definition and the JSON writer.

## Grid coordinates

Logical, not visual. `row` grows downward. **`col` grows leftward: column 0 is
the rightmost column**, because the grid reads right to left. A horizontal word
fills `col, col + 1, ...` with its first letter in the rightmost of those cells.
A vertical word fills `row, row + 1, ...` from the top.

`scripts/level.gd` reads the same convention, and `WordGrid.cell_rect()` is the
one place that turns a column into an x position.

## What makes a layout valid

One rule covers everything: **every maximal run of two or more adjacent filled
cells, horizontally or vertically, must be exactly one of the level's words.**

That forbids two words sitting side by side and accidentally spelling a third,
and it forbids a word being extended by a neighbour. The search rejects any
arrangement that breaks it, so a generated grid cannot contain a run the player
can see but not enter.

## Current state

One hand-written level, `m04-12`, the sample that runs through the design canvas
and the engine slice. Still missing, in rough order of need:

1. An Arabic dictionary source, normalised, with a frequency or familiarity cut
   so levels do not demand obscure words.
2. A letter-set chooser: pick a 4 to 7 letter base word, find every sub-word,
   decide which go in the grid and which become bonus words.
3. A difficulty curve across the 560 levels of the first year.
4. Export packaging. Godot does not import plain JSON, so `data/levels/` needs an
   explicit include filter in the export preset or the files will be missing from
   a built game. No export presets exist yet.
