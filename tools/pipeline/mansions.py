"""The 28 lunar mansions, which are the chapters of the first year.

Seven to a season, twenty levels to a mansion: 560 levels. The names and their
order follow `docs/story-sky.md`; the season boundaries there are sequential and
are meant to be checked against the classical anwaa calendars before release.
"""

from __future__ import annotations

LEVELS_PER_MANSION = 20

SEASONS = ("spring", "summer", "autumn", "winter")

## In order. Index 0 is the first mansion of the year.
MANSIONS = (
    # الربيع
    "الشرطان", "البطين", "الثريا", "الدبران", "الهقعة", "الهنعة", "الذراع",
    # الصيف
    "النثرة", "الطرف", "الجبهة", "الزبرة", "الصرفة", "العواء", "السماك",
    # الخريف
    "الغفر", "الزبانى", "الإكليل", "القلب", "الشولة", "النعائم", "البلدة",
    # الشتاء
    "سعد الذابح", "سعد بلع", "سعد السعود", "سعد الأخبية",
    "الفرغ المقدم", "الفرغ المؤخر", "بطن الحوت",
)

TOTAL_LEVELS = len(MANSIONS) * LEVELS_PER_MANSION


def place(level: int) -> dict:
    """Where a global level number sits: which mansion, which season, which star.

    `level` counts from 1. Level 1 is the first star of the first mansion.
    """
    if not 1 <= level <= TOTAL_LEVELS:
        raise ValueError(f"level {level} is outside 1..{TOTAL_LEVELS}")
    mansion_index = (level - 1) // LEVELS_PER_MANSION
    return {
        "mansion": mansion_index + 1,
        "mansion_name": MANSIONS[mansion_index],
        "season": SEASONS[mansion_index // 7],
        "index_in_mansion": (level - 1) % LEVELS_PER_MANSION + 1,
    }


def level_id(level: int) -> str:
    spot = place(level)
    return "m%02d-%02d" % (spot["mansion"], spot["index_in_mansion"])
