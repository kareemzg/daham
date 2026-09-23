class_name Arabic
extends RefCounted
## Arabic text rules, shared with `tools/pipeline/arabic.py`.
##
## The pipeline normalises words before they are baked into a level, and the
## game normalises whatever the player spells. If these two drift apart, a
## player can spell a word the grid will not accept. Change both or neither.

## أ إ آ ٱ all fold to bare ا on the wheel, in the grid and in the dictionary.
## ة, ى and standalone ء stay distinct: to a player they are different letters.
const ALIF_FORMS := {
	0x0623: "ا",  # أ
	0x0625: "ا",  # إ
	0x0622: "ا",  # آ
	0x0671: "ا",  # ٱ
}

const EASTERN_ZERO := 0x0660
const MIDDLE_DOT := 0x00B7
const TATWEEL := 0x0640
const SUPERSCRIPT_ALIF := 0x0670
const DIACRITIC_FIRST := 0x064B  # fathatan
const DIACRITIC_LAST := 0x0652  # sukun


## Strips diacritics and folds the alif forms. Everything else is left alone.
static func normalise(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code == TATWEEL or code == SUPERSCRIPT_ALIF:
			continue
		if code >= DIACRITIC_FIRST and code <= DIACRITIC_LAST:
			continue
		if ALIF_FORMS.has(code):
			out += ALIF_FORMS[code]
		else:
			out += String.chr(code)
	return out


## Renders a number with Eastern Arabic digits, as every UI string must.
static func eastern_digits(value: Variant) -> String:
	var out := ""
	for i in str(value).length():
		var code := str(value).unicode_at(i)
		if code >= 0x30 and code <= 0x39:
			out += String.chr(EASTERN_ZERO + code - 0x30)
		else:
			out += String.chr(code)
	return out


## The middle dot must never touch an Eastern Arabic digit.
##
## «٠» is itself a dot, so «المنزلة ٤ · الدبران» reads as «المنزلة ٤٠ الدبران»,
## and «بنات نعش · ٤ من ٧» was read in play as «٤٠». Between two words the dot
## is fine and reads as a dot; where a number is on either side of it, use «—»,
## which no one can mistake for a digit.
##
## Returns the offending fragment so a failure names itself, or "" when clean.
static func dot_beside_digit(text: String) -> String:
	for i in text.length():
		if text.unicode_at(i) != MIDDLE_DOT:
			continue
		if _digit_beside(text, i, -1) or _digit_beside(text, i, 1):
			return text.substr(maxi(0, i - 7), 15)
	return ""


## Looks past any run of spaces: a dot two spaces from a number still reads
## against it.
static func _digit_beside(text: String, from: int, step: int) -> bool:
	var i := from + step
	while i >= 0 and i < text.length():
		var code := text.unicode_at(i)
		if code == 0x20:
			i += step
			continue
		return code >= EASTERN_ZERO and code <= EASTERN_ZERO + 9
	return false
