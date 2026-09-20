"""Crossword layout for Arabic word-puzzle levels.

Coordinates are logical, not visual:

* ``row`` grows downward, as on screen.
* ``col`` grows **leftward**: column 0 is the RIGHTMOST column, because the
  grid is read right to left. A horizontal word occupies ``col, col+1, ...``
  with its first letter in the rightmost of those cells.
* A vertical word occupies ``row, row+1, ...``, first letter at the top.

A layout is valid when every maximal run of two or more adjacent filled cells,
horizontally or vertically, is exactly one of the level's words. That single
rule covers both "words must interlock" and "no accidental word formed by two
words sitting side by side".
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterator

HORIZONTAL = "h"
VERTICAL = "v"

## The search is exhaustive, which is fine for five words and ruinous for eight.
## These caps trade "the most compact arrangement that exists" for "a compact
## arrangement, found in bounded time". Raise them when a level matters more than
## the clock; the generator lowers them when it is only asking "is this even
## possible?".
SOLUTION_CAP = 64
NODE_CAP = 60_000


class LayoutFailed(ValueError):
    """No valid interlocking arrangement was found within the caps."""

Cell = tuple[int, int]
Grid = dict[Cell, str]


@dataclass(frozen=True)
class Placement:
    """One word pinned to the grid."""

    word: str
    row: int
    col: int
    direction: str

    def cells(self) -> Iterator[tuple[Cell, str]]:
        for i, letter in enumerate(self.word):
            if self.direction == HORIZONTAL:
                yield (self.row, self.col + i), letter
            else:
                yield (self.row + i, self.col), letter


def _apply(grid: Grid, placement: Placement) -> Grid | None:
    """Return a new grid with `placement` added, or None if a letter clashes."""
    merged = dict(grid)
    for cell, letter in placement.cells():
        existing = merged.get(cell)
        if existing is not None and existing != letter:
            return None
        merged[cell] = letter
    return merged


def _runs(grid: Grid) -> Iterator[str]:
    """Yield every maximal run of two or more adjacent filled cells."""
    for fixed_index, step_index, step in ((0, 1, HORIZONTAL), (1, 0, VERTICAL)):
        lines: dict[int, list[int]] = {}
        for cell in grid:
            lines.setdefault(cell[fixed_index], []).append(cell[step_index])
        for fixed, moving in lines.items():
            moving.sort()
            run: list[str] = []
            previous: int | None = None
            for position in moving:
                cell = (fixed, position) if step == HORIZONTAL else (position, fixed)
                if previous is not None and position != previous + 1:
                    if len(run) > 1:
                        yield "".join(run)
                    run = []
                run.append(grid[cell])
                previous = position
            if len(run) > 1:
                yield "".join(run)


def _could_still_become_a_word(run: str, words: tuple[str, ...]) -> bool:
    """A run only ever grows, so it must already sit inside some target word."""
    return any(run in word for word in words)


def _is_complete(grid: Grid, words: tuple[str, ...]) -> bool:
    found = sorted(_runs(grid))
    return found == sorted(words)


def _crossing_placements(grid: Grid, word: str) -> Iterator[Placement]:
    """Every way to hang `word` off a letter already on the grid."""
    for (row, col), letter in grid.items():
        for index, candidate in enumerate(word):
            if candidate != letter:
                continue
            yield Placement(word, row, col - index, HORIZONTAL)
            yield Placement(word, row - index, col, VERTICAL)


def _normalise(placements: tuple[Placement, ...]) -> tuple[tuple[Placement, ...], int, int]:
    """Shift a solution so its top-right corner is (0, 0); return it with its size."""
    grid: Grid = {}
    for placement in placements:
        grid = _apply(grid, placement) or grid
    min_row = min(row for row, _ in grid)
    min_col = min(col for _, col in grid)
    rows = max(row for row, _ in grid) - min_row + 1
    cols = max(col for _, col in grid) - min_col + 1
    shifted = tuple(
        Placement(p.word, p.row - min_row, p.col - min_col, p.direction) for p in placements
    )
    return shifted, rows, cols


def layout(
    words: list[str],
    *,
    solution_cap: int = SOLUTION_CAP,
    node_cap: int = NODE_CAP,
) -> tuple[Placement, ...]:
    """Find a compact valid layout for `words`.

    Stops once `solution_cap` arrangements have been found or `node_cap` grids
    have been tried, then returns the most compact of whatever it has.

    Raises LayoutFailed when the words cannot interlock within those bounds.
    """
    if not words:
        raise LayoutFailed("no words to lay out")
    targets = tuple(words)
    ordered = sorted(words, key=len, reverse=True)
    solutions: list[tuple[tuple[Placement, ...], int, int]] = []
    nodes = 0

    def search(grid: Grid, placed: tuple[Placement, ...], remaining: tuple[str, ...]) -> None:
        nonlocal nodes
        if len(solutions) >= solution_cap or nodes >= node_cap:
            return
        if not remaining:
            if _is_complete(grid, targets):
                solutions.append(_normalise(placed))
            return
        head, *rest = remaining
        seen: set[Placement] = set()
        for placement in _crossing_placements(grid, head):
            if placement in seen:
                continue
            seen.add(placement)
            candidate = _apply(grid, placement)
            if candidate is None:
                continue
            if not all(_could_still_become_a_word(run, targets) for run in _runs(candidate)):
                continue
            nodes += 1
            search(candidate, placed + (placement,), tuple(rest))
            if len(solutions) >= solution_cap or nodes >= node_cap:
                return

    first = Placement(ordered[0], 0, 0, HORIZONTAL)
    search(_apply({}, first) or {}, (first,), tuple(ordered[1:]))

    if not solutions:
        raise LayoutFailed(f"no valid interlocking layout for {words}")

    # Most compact first, then the squarest, then stable by word order.
    solutions.sort(key=lambda item: (item[1] * item[2], abs(item[1] - item[2]), item[1]))
    return solutions[0][0]


def grid_size(placements: tuple[Placement, ...]) -> tuple[int, int]:
    """Rows and columns spanned by a normalised layout."""
    grid: Grid = {}
    for placement in placements:
        grid = _apply(grid, placement) or grid
    rows = max(row for row, _ in grid) + 1
    cols = max(col for _, col in grid) + 1
    return rows, cols


def render(placements: tuple[Placement, ...]) -> str:
    """Draw the layout the way it reads on screen, for eyeballing in a terminal."""
    grid: Grid = {}
    for placement in placements:
        grid = _apply(grid, placement) or grid
    rows, cols = grid_size(placements)
    lines = []
    for row in range(rows):
        # col 0 is rightmost, so walk the columns backwards when printing.
        line = " ".join(grid.get((row, col), "·") for col in reversed(range(cols)))
        lines.append(line)
    return "\n".join(lines)
