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

## What each name means, one line apiece. Mine to begin with, from the classical
## sources the story bible names; the first eight are now Kareem's, checked
## against Ibn Qutaybah. The seventh was wrong: الذراع of the mansions is the
## lion's **drawn-in** forearm, not the outstretched one — الذراع المبسوطة is a
## different pair of stars and not a mansion at all.
##
## The rest of each mansion's lore — its shape, its rain, its season, the rhyme
## and the verse — lives in `data/mansion-lore.json`, which is hand-written and
## never generated. Only the gloss is here, because the map and the card read it
## without loading anything.
const MEANINGS := [
	"العلامتان اللتان تُشرطان أول السنة",
	"بطن الحمل الصغير",
	"الكثيرة، لازدحام نجومها",
	"التابع، لأنه يتبع الثريا",
	"أثر بروك البعير في الأرض",
	"السمة تُوسم بها الإبل",
	"ذراع الأسد المقبوضة",
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

## How many mansions this build actually carries, counted from the first.
##
## The table describes the whole year because the sky map draws the whole year,
## but a build ships a season at a time: the first release is spring alone, the
## seven mansions from الشرطان to الذراع, and each later season is an update.
## Everything that asks "is there a level here" must ask this and not `COUNT`,
## because a level file outside the shipped range is not in the export at all.
## Raise it by `PER_SEASON` to ship the next season; nothing else moves.
const SHIPPED := 7
const SHIPPED_LEVELS := SHIPPED * LEVELS_PER_MANSION


## Whether this build carries any level of that mansion.
static func is_shipped(mansion: int) -> bool:
	return mansion >= 1 and mansion <= SHIPPED


## Whether this build carries the whole of that season, zero-based.
static func season_shipped(season: int) -> bool:
	return (season + 1) * PER_SEASON <= SHIPPED


## How many whole seasons are in this build.
static func shipped_seasons() -> int:
	return SHIPPED / PER_SEASON


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


const LORE_PATH := "res://data/mansion-lore.json"

static var _figures: Dictionary = {}
## The rhyme the tradition hangs on each mansion, keyed by number. It is
## what the twentieth star reads out before the player writes the name.
static var _saj: Dictionary = {}
## The mansion's verse, split into a poet and two hemistichs. Only the
## mansions whose line is whole and attributed have one.
static var _verses: Dictionary = {}
static var _lore_read: bool = false


## Everything the game draws of one mansion's figure:
##   points       its own stars, in a 100-unit box
##   mags         their visual magnitudes, one per point
##   behind       the fainter stars of the figure it belongs to
##   behind_mags  theirs
##   join         pairs of indexes into `points`; empty means a cluster
##
## A mansion is not a picture but one to nine real stars, so the figure is a
## projection of the sky rather than a drawing. `tools/pipeline/figures.py`
## does the projecting and writes it into `data/mansion-lore.json`; only the
## mansions read from Ibn Qutaybah have one, and the rest still fall back to
## the placeholder clusters below.
static func figure_of(mansion: int) -> Dictionary:
	if mansion < 1 or mansion > COUNT:
		return _empty_figure()
	_read_lore()
	if _figures.has(mansion):
		return _figures[mansion]
	# No reading yet: the placeholder, as one chain at a uniform brightness.
	var points: Array = SHAPES[(mansion - 1) % PER_SEASON]
	var join: Array = []
	for i in maxi(points.size() - 1, 0):
		join.append(Vector2i(i, i + 1))
	var mags: Array = []
	for i in points.size():
		mags.append(3.0)
	return {
		"points": points.duplicate(), "mags": mags,
		"behind": [], "behind_mags": [], "join": join, "real": false,
	}


static func _empty_figure() -> Dictionary:
	return {"points": [], "mags": [], "behind": [], "behind_mags": [], "join": [], "real": false}


static func _read_lore() -> void:
	if _lore_read:
		return
	_lore_read = true
	if not FileAccess.file_exists(LORE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LORE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Mansions: %s is not readable" % LORE_PATH)
		return
	var mansions: Variant = (parsed as Dictionary).get("mansions", {})
	if typeof(mansions) != TYPE_DICTIONARY:
		return
	for key in (mansions as Dictionary):
		var entry: Variant = mansions[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var number := int(str(key))
		var saj := str((entry as Dictionary).get("saj", "")).strip_edges()
		if not saj.is_empty():
			_saj[number] = saj
		var verse: Variant = (entry as Dictionary).get("verse", null)
		if typeof(verse) == TYPE_DICTIONARY:
			var built := _build_verse(verse as Dictionary)
			if not built.is_empty():
				_verses[number] = built
		if not (entry as Dictionary).has("figure"):
			continue
		var built := _build_figure((entry as Dictionary)["figure"])
		if not built.is_empty():
			_figures[number] = built


static func _build_figure(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var figure := _empty_figure()
	figure["real"] = true
	for field in [["stars", "points", "mags"], ["behind", "behind", "behind_mags"]]:
		for star in (raw as Dictionary).get(field[0], []):
			if typeof(star) != TYPE_DICTIONARY:
				continue
			figure[field[1]].append(Vector2(
				float((star as Dictionary).get("x", 0.0)),
				float((star as Dictionary).get("y", 0.0))
			))
			figure[field[2]].append(float((star as Dictionary).get("mag", 3.0)))
	for pair in (raw as Dictionary).get("join", []):
		if pair is Array and (pair as Array).size() == 2:
			figure["join"].append(Vector2i(int(pair[0]), int(pair[1])))
	return figure if not figure["points"].is_empty() else {}


## The mansion's rhyme, or "" where nobody has written one down yet.
##
## Hand-written in `data/mansion-lore.json` from Ibn Qutaybah and reviewed by
## Kareem; the pipeline never touches it. The twentieth star of a mansion reads
## it out, and the answer is the mansion's own name — which the rhyme opens
## with, because that is how these rhymes are built.
static func saj_of(mansion: int) -> String:
	_read_lore()
	return str(_saj.get(mansion, ""))


## The mansion's verse: who said it, and its two hemistichs as word lists.
##
## Empty where nobody has settled the line yet. `bayt` in the lore file is the
## hand-written prose and stays untouched; `verse` beside it is the same line
## split for the board to arrange, and the poet is the reward for arranging it.
static func verse_of(mansion: int) -> Dictionary:
	_read_lore()
	return _verses.get(mansion, {})


static func has_verse(mansion: int) -> bool:
	return not verse_of(mansion).is_empty()


static func _build_verse(raw: Dictionary) -> Dictionary:
	var poet := str(raw.get("poet", "")).strip_edges()
	var sadr := str(raw.get("sadr", "")).split(" ", false)
	var ajz := str(raw.get("ajz", "")).split(" ", false)
	# A verse the mode cannot use is no verse: it needs both halves to arrange
	# and a name to give back.
	if poet.is_empty() or sadr.size() < 2 or ajz.size() < 2:
		return {}
	return {"poet": poet, "sadr": sadr, "ajz": ajz}


## The figure's own stars as plain points. Every older caller wants this.
static func shape_of(mansion: int) -> Array:
	return figure_of(mansion)["points"]


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
