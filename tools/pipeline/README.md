# Content pipeline

Generates the level JSON in `data/levels/`. Nothing in that folder is edited by
hand: change the definition here and rebuild.

```bash
python3 tools/pipeline/generate.py --count 20            # try it, print the grids
python3 tools/pipeline/generate.py --count 560 --write   # fill data/levels/
python3 tools/pipeline/build_level.py --write            # rebuild the test fixture
```

Generating all 560 levels takes about ten seconds and every one is verified
before it is written. Check the engine side too, which reads them back through
`Level` and validates each:

```bash
godot --path . --headless --script res://scenes/dev/validate_levels.gd
```

No dependencies beyond the standard library. Run it from the repo root.

## Files

- `arabic.py` — normalisation and Eastern Arabic digits. Mirrored in
  `scripts/arabic.gd`. If a rule changes here it must change there, or a player
  can spell a word the grid refuses.
- `crossword.py` — the layout search. Words interlock; the search keeps the most
  compact valid arrangement.
- `build_level.py` — the level definition and the JSON writer.
- `export_dictionary.py` — pulls the word list out of the dictionary database.
- `dictionary.tsv` — the result: 47,681 words, `key<TAB>zipf`. Generated, not
  hand-edited.

## The dictionary

```bash
python3 tools/pipeline/export_dictionary.py --report   # describe it
python3 tools/pipeline/export_dictionary.py --write    # write dictionary.tsv
```

It reads the SQLite built by the sibling `arabic-words-for-game` project. Pass
`--source` if that lives somewhere else.

**The dictionary is build input, not a game asset.** Each level file already
carries its own grid words and bonus words, so the engine never looks a word up
at run time and nothing derived from the dictionary's sources is shipped.

**Keys use this project's normalisation, not the database's.** The database folds
ة into ه and ى into ي; here they stay apart. In a wheel game the player can only
use the letters the wheel offers, so there is no ه/ة ambiguity to guard against,
and folding would spell مدرسه on the grid. The export re-derives every key from
the database's `skeleton` column and warns if ة or ى goes missing.

What the numbers look like, for picking cut-offs:

| filter | words |
|---|---|
| all, 3 to 7 letters | 47,681 |
| zipf >= 2.0 | 21,460 |
| zipf >= 2.5 | 16,363 |
| zipf >= 3.0 | 11,612 |
| no frequency data (zipf = 0) | 16,778 |

Two things to know before choosing a cut-off:

- **zipf 0 means "absent from the frequency list", not "rare".** A sample of that
  bucket is genuinely obscure — rare conjugations like تثابرن and اشتططتن — so
  dropping it is safe, but it is a judgement, not a fact the data states.
- **A few hundred entries carry a prefix**: 378 playable words start with the
  definite article, and a handful glue on a conjunction (والغنم). Legitimate
  words as far as the dictionary is concerned, weak as puzzle answers. Filter
  them in the level generator, not here.

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

## Generating levels

`generate.py` picks a base word for the wheel, finds every word spellable from
its letters, grows a set that interlocks, and leaves the rest as bonus words.

The whole first year builds: **560 of 560**, averaging 5.5 grid words and 34
bonus words. Grids run from four columns to eleven.

Two things decide whether a base word is used, and neither is "is it a common
word". A base can be known to everyone and still make a poor level: إياه spells
almost nothing. So a base is judged by what it yields — enough candidates to
fill a grid, and at least two bonus words so the moon meter has something to
fill.

The difficulty curve widens the wheel and lowers the frequency floor across the
year: four letters and only household words at level 1, seven letters and a
longer reach by level 560. `base_lengths()` and `base_floor()` hold it.

A level that will not interlock is skipped and the next base is tried, up to
forty per level, which is why the run always fills its quota.

The run is seeded, so rebuilding produces the same levels. Change the seed and
every level changes.

## The test fixture

`data/levels/sample.json` is hand-written by `build_level.py` and is what the
engine test checks. It deliberately carries the id `sample`, outside the
`mNN-NN` range the generator owns, so regenerating levels can never silently
change what the test asserts.

## Current state

The word list and all 560 levels exist. Still missing:

1. Export packaging. Godot does not import plain JSON, so `data/levels/` needs an
   explicit include filter in the export preset or the files will be missing from
   a built game. No export presets exist yet.
2. Progression: the engine plays whichever level `GameScreen.level_path` names
   and stops at the end. `GameScreen.show_level()` is the seam for the next one.
