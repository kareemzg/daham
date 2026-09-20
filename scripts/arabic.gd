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
