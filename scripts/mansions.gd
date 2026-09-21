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

## What each name means, one line apiece. A first draft from the classical
## sources the story bible names, for Kareem to check against them: the tradition
## is consistent on these, but a gloss is a translation and translations argue.
const MEANINGS := [
	"العلامتان اللتان تُشرطان أول السنة",
	"بطن الحمل الصغير",
	"الكثيرة، لازدحام نجومها",
	"التابع، لأنه يتبع الثريا",
	"أثر بروك البعير في الأرض",
	"السمة تُوسم بها الإبل",
	"ذراع الأسد المبسوطة",
	"أنف الأسد",
	"عينا الأسد ونظرته",
	"جبهة الأسد",
	"كاهل الأسد وشعر عنقه",
	"انصراف البرد عند طلوعها",
	"العوّاء يعوي خلف الأسد",
	"الرافع، وهو الأعزل لا رمح معه",
	"الغطاء، لخفاء نجومها",
	"قرنا العقرب",
	"إكليل جبهة العقرب",
	"قلب العقرب",
	"ذنب العقرب مرفوعاً بشوكته",
	"النعام الوارد والصادر",
	"الفرجة الخالية من النجوم",
	"السعد الذي يذبح",
	"السعد البالع",
	"أسعد السعود",
	"سعد الخيام",
	"فم الدلو المقدَّم",
	"فم الدلو المؤخَّر",
	"بطن السمكة",
]

## The modern Latin name of the mansion's brightest star, where the tradition
## agrees on one. البلدة has none: it is named for being empty of bright stars,
## so an empty string there is the truth and not a gap.
const LATIN := [
	"Sheratan", "Botein", "Pleiades", "Aldebaran", "Meissa", "Alhena", "Pollux",
	"Praesepe", "Alterf", "Regulus", "Zosma", "Denebola", "Zavijava", "Spica",
	"Syrma", "Zubenelgenubi", "Acrab", "Antares", "Shaula", "Nunki", "",
	"Algedi", "Albali", "Sadalsuud", "Sadachbia", "Markab", "Algenib", "Mirach",
]

## Seven placeholder figures, one per place in a season, in reference units from
## the cluster's centre. The real shapes are a drawing job the story asks to be
## redrawn from al-Sufi rather than copied, and nobody has done it.
const SHAPES := [
	[Vector2(-44, -28), Vector2(0, 0), Vector2(44, 22), Vector2(66, -17)],
	[Vector2(-39, 17), Vector2(6, -22), Vector2(50, 6)],
	[Vector2(-33, -17), Vector2(-6, 11), Vector2(28, -6), Vector2(55, 17), Vector2(17, -33)],
	[Vector2(-55, 11), Vector2(-17, -22), Vector2(22, 6), Vector2(61, -17), Vector2(0, 33)],
	[Vector2(-39, -22), Vector2(0, 6), Vector2(39, -11)],
	[Vector2(-50, 6), Vector2(-11, -22), Vector2(28, 0), Vector2(55, 28)],
	[Vector2(-33, 11), Vector2(11, -17), Vector2(50, 11)],
]

const COUNT := 28
const TOTAL_LEVELS := COUNT * LEVELS_PER_MANSION


static func name_of(mansion: int) -> String:
	if mansion < 1 or mansion > COUNT:
		return ""
	return NAMES[mansion - 1]


static func meaning_of(mansion: int) -> String:
	if mansion < 1 or mansion > COUNT:
		return ""
	return MEANINGS[mansion - 1]


static func latin_of(mansion: int) -> String:
	if mansion < 1 or mansion > COUNT:
		return ""
	return LATIN[mansion - 1]


## The figure for a mansion, by its place in its season.
static func shape_of(mansion: int) -> Array:
	if mansion < 1 or mansion > COUNT:
		return []
	return SHAPES[(mansion - 1) % PER_SEASON]


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
