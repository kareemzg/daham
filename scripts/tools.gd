class_name Tools
extends RefCounted
## The observer's four instruments, in the order the shop lists them.
##
## One table so a price never differs between the window that sells a tool and
## the screen that spends it.

enum Kind { SPYGLASS, ASTROLABE, CHART, WORD }

const COUNT := 4

const NAMES := ["المنظار", "الأسطرلاب", "الخريطة", "كشف كلمة"]
const WHAT := [
	"يكشف حرفاً واحداً",
	"أول حرف من كل كلمة",
	"تختار الخانة التي تُكشف",
	"كلمة كاملة من الرقعة",
]
## A level pays forty-five, so the spyglass costs about one level and a whole
## word costs five or six. Balance, not arithmetic: change them here.
const PRICES := [50, 150, 100, 250]

const ICONS := [
	UiIcon.Kind.SPYGLASS, UiIcon.Kind.ASTROLABE, UiIcon.Kind.CHART, UiIcon.Kind.WORD_REVEAL,
]


static func name_of(kind: int) -> String:
	return NAMES[kind] if kind >= 0 and kind < COUNT else ""


static func price_of(kind: int) -> int:
	return PRICES[kind] if kind >= 0 and kind < COUNT else 0
