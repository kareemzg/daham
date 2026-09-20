"""Arabic text rules shared by the level pipeline.

The same normalisation runs in the engine (`scripts/arabic.gd`). If you change
a rule here, change it there too, or generated levels stop matching what the
player types.
"""

from __future__ import annotations

# أ إ آ ٱ all collapse to bare ا on the wheel, in the grid and in the dictionary.
# ة, ى and standalone ء stay distinct: they are different letters to the player.
_ALIF_FORMS = {
    "أ": "ا",  # أ
    "إ": "ا",  # إ
    "آ": "ا",  # آ
    "ٱ": "ا",  # ٱ
}

_DIACRITICS = dict.fromkeys(range(0x064B, 0x0653))  # fathatan .. sukun
_DIACRITICS[0x0640] = None  # tatweel
_DIACRITICS[0x0670] = None  # superscript alif

_EASTERN_DIGITS = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def normalise(text: str) -> str:
    """Strip diacritics and fold the alif forms. Everything else is left alone."""
    stripped = text.translate(_DIACRITICS)
    return "".join(_ALIF_FORMS.get(char, char) for char in stripped)


def eastern_digits(value: int | str) -> str:
    """Render a number with Eastern Arabic digits, as every UI string must."""
    return str(value).translate(_EASTERN_DIGITS)


def letters_for(words: list[str]) -> list[str]:
    """The wheel letters: the letters of the longest word, which covers the rest.

    Raises ValueError if a shorter word needs a letter the longest one lacks,
    which would make the level unsolvable.
    """
    longest = max(words, key=len)
    pool: dict[str, int] = {}
    for letter in longest:
        pool[letter] = pool.get(letter, 0) + 1
    for word in words:
        needed: dict[str, int] = {}
        for letter in word:
            needed[letter] = needed.get(letter, 0) + 1
        for letter, count in needed.items():
            if pool.get(letter, 0) < count:
                raise ValueError(
                    f"'{word}' needs {count}x '{letter}' but the wheel from '{longest}' has "
                    f"{pool.get(letter, 0)}"
                )
    return list(longest)
