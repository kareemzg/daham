class_name Mansions
extends RefCounted
## The twenty-eight lunar mansions, in order, and the four seasons over them.
##
## Mirrors `tools/pipeline/mansions.py`, which is what stamps each level file
## with its mansion and season. The table is here as well because the sky map
## draws all twenty-eight and must not read five hundred and sixty level files
## to learn their names.

const LEVELS_PER_MANSION := 20
const PER_SEASON := 7

const SEASONS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := {
	"spring": "الربيع", "summer": "الصيف", "autumn": "الخريف", "winter": "الشتاء",
}

## Index 0 is the first mansion of the year; mansion numbers are one-based.
const NAMES := [
	"الشرطان", "البطين", "الثريا", "الدبران", "الهقعة", "الهنعة", "الذراع",
	"النثرة", "الطرف", "الجبهة", "الزبرة", "الصرفة", "العواء", "السماك",
	"الغفر", "الزبانى", "الإكليل", "القلب", "الشولة", "النعائم", "البلدة",
	"سعد الذابح", "سعد بلع", "سعد السعود", "سعد الأخبية",
	"الفرغ المقدم", "الفرغ المؤخر", "بطن الحوت",
]

const COUNT := 28
const TOTAL_LEVELS := COUNT * LEVELS_PER_MANSION


static func name_of(mansion: int) -> String:
	if mansion < 1 or mansion > COUNT:
		return ""
	return NAMES[mansion - 1]


## 0 for spring, 3 for winter.
static func season_of(mansion: int) -> int:
	return clampi((mansion - 1) / PER_SEASON, 0, SEASONS.size() - 1)


static func season_name(season: int) -> String:
	return SEASON_NAMES.get(SEASONS[clampi(season, 0, SEASONS.size() - 1)], "")


## The mansion numbers of one season, in order.
static func of_season(season: int) -> Array[int]:
	var first := clampi(season, 0, SEASONS.size() - 1) * PER_SEASON + 1
	var numbers: Array[int] = []
	for i in PER_SEASON:
		numbers.append(first + i)
	return numbers


static func level_id(mansion: int, index_in_mansion: int) -> String:
	return "m%02d-%02d" % [mansion, index_in_mansion]


## Splits an id back into its mansion and its place in it. Returns Vector2i.ZERO
## for anything that is not a generated id, the hand-made fixture included.
static func parse(id: String) -> Vector2i:
	if id.length() != 6 or not id.begins_with("m") or id[3] != "-":
		return Vector2i.ZERO
	var mansion := id.substr(1, 2).to_int()
	var index := id.substr(4, 2).to_int()
	if mansion < 1 or mansion > COUNT or index < 1 or index > LEVELS_PER_MANSION:
		return Vector2i.ZERO
	return Vector2i(mansion, index)
