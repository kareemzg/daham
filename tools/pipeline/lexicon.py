"""The word list, indexed so sub-words are one dictionary lookup away.

`dictionary.tsv` is written by `export_dictionary.py` and holds every key with
the highest frequency any reading of it has, on the Zipf scale: roughly 7 for
"في", 4 for an everyday word, 2 for one you would have to reach for, 0 for one
the frequency source never saw at all.
"""

from __future__ import annotations

import itertools
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parent / "dictionary.tsv"

## Words whose first letters are a glued-on particle. They are real words, but a
## grid answer of والغنم or الارض is a worse puzzle than غنم or ارض.
GLUED_PREFIXES = ("وال", "فال", "بال", "كال", "لل")


class Lexicon:
    """Every word, plus the letter-signature index the generator searches."""

    def __init__(self) -> None:
        self.zipf: dict[str, float] = {}
        self._by_signature: dict[str, list[str]] = {}

    @classmethod
    def load(cls, path: Path = DEFAULT_PATH) -> "Lexicon":
        if not path.exists():
            raise SystemExit(
                f"word list not found: {path}\n"
                "Run: python3 tools/pipeline/export_dictionary.py --write"
            )
        lexicon = cls()
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("#"):
                    continue
                key, _, zipf = line.rstrip("\n").partition("\t")
                if not key:
                    continue
                lexicon.zipf[key] = float(zipf or 0.0)
                lexicon._by_signature.setdefault(signature(key), []).append(key)
        return lexicon

    def __len__(self) -> int:
        return len(self.zipf)

    def subwords(self, base: str, *, min_zipf: float, min_length: int = 3) -> list[str]:
        """Every word spellable from `base`'s letters, `base` itself excluded.

        Each letter may be used at most as often as it appears in `base`, which
        is what the wheel enforces, so this is exactly the set of words the
        player could possibly spell.
        """
        found: list[str] = []
        seen: set[str] = set()
        for size in range(min_length, len(base) + 1):
            for positions in itertools.combinations(range(len(base)), size):
                sig = signature("".join(base[i] for i in positions))
                if sig in seen:
                    continue
                seen.add(sig)
                for word in self._by_signature.get(sig, ()):
                    if word != base and self.zipf[word] >= min_zipf:
                        found.append(word)
        return found

    def bases(self, *, min_length: int, max_length: int, min_zipf: float) -> list[str]:
        """Words fit to sit on the wheel, best known first."""
        out = [
            key
            for key, zipf in self.zipf.items()
            if min_length <= len(key) <= max_length
            and zipf >= min_zipf
            and is_plain(key)
        ]
        out.sort(key=lambda key: (-self.zipf[key], key))
        return out


def signature(word: str) -> str:
    """The letters of a word, sorted. Two words share one iff they are anagrams."""
    return "".join(sorted(word))


def is_plain(word: str) -> bool:
    """False for words carrying a glued-on particle, which make weak answers."""
    if word.startswith(GLUED_PREFIXES):
        return False
    # The definite article is fine inside a word but tedious as the answer.
    return not word.startswith("ال")
