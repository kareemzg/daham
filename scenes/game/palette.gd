class_name Palette
extends RefCounted
## Placeholder colours for the engine slice, taken from the approved UI sample.
##
## These are stand-ins. When the UI kit ships as SVG/nine-slice files, the tiles
## and panels become textures and only the text colours stay here.

# The sky is not one colour going darker. It runs from indigo at the zenith to
# a teal horizon, because the lore it is built from says so in three places —
# and because a four-stop navy ramp made everything that stood on it read as
# washed out, whatever colour the thing itself was.
const SKY_TOP := Color("0A0B26")
const SKY_MID := Color("0E2440")
const SKY_LOW := Color("13445C")
const SKY_BOTTOM := Color("1A6470")

## المجرّة, the band. «ثمانية كواكب: أربعة في المجرّة تُسمّى الواردة» — it is in
## النعائم's own description, and it is the one thing that makes a night read as
## deep rather than merely dark.
const MILKY_VIOLET := Color("7B5CA8")
const MILKY_ROSE := Color("C98BA0")

# Star colour, from what the tradition actually says. الدبران is «كوكب أحمر
# منير» and القلب «كوكب أحمر»; the bright pairs are white; البطين والغفر are
# «كواكب خفية», which is what FIGURE_FAINT already was.
const STAR_RED := Color("E2624A")
const STAR_BLUE := Color("BFE3F5")

## One hue per season, because twenty-eight mansions ARE four sevens. It is a
## description of the structure, not decoration laid over it.
const SEASON_SPRING := Color("6FD8C4")
const SEASON_SUMMER := Color("FFD968")
const SEASON_AUTUMN := Color("E89A54")
const SEASON_WINTER := Color("A98BD6")
const SEASON_COLOURS := [SEASON_SPRING, SEASON_SUMMER, SEASON_AUTUMN, SEASON_WINTER]

const TILE_FACE := Color("FCF2DC")
const TILE_EDGE := Color("B99A66")
const TILE_BORDER := Color("C9A97A")
const TILE_INK := Color("2B2620")

# The well has to read as a hole punched in the sky, so it is darker than the
# darkest sky stop and its border is lighter than any of them. Matching the sky
# more closely makes the empty cells vanish on a phone.
const WELL_FACE := Color("04121C")
const WELL_BORDER := Color("2C5E73")

const RIVER := Color("2E7D8C")
const RIVER_LIGHT := Color("5FB0BE")
const RIVER_DEEP := Color("1B4F5C")
const RIVER_EDGE := Color("0F2C34")
const TRAIL := Color("7FD0DA")

const GOLD := Color("E9B92C")
const GOLD_LIGHT := Color("FFE38A")
const GOLD_DEEP := Color("9A7A15")

## The stars of the wider figure behind a mansion — the lion a mansion is only
## the brow of. Cold and dim against the mansion's own gold, because it is
## context and must never compete with its subject.
const FIGURE_FAINT := Color("6E8BA6")

const TAMR := Color("D08A47")
const TAMR_DEEP := Color("8A4A12")

const EMBER := Color("E8641B")
const OKRA := Color("7CB342")
## The hub's furniture — the gear, the home button, the season arrows. A slate
## that belongs to the night without competing with the coloured tiles that
## carry a meaning beside it.
const SLATE := Color("6E86B0")
const MUTED := Color("BFD6E0")
const DIM_STAR := Color("7A96A8")
const CREAM := Color("F6EEDC")
## The strip a row sits in. Opaque, because a translucent light tint over the
## window's indigo reads grey — the same arithmetic that turned gold at half
## opacity over navy into ash.
const TRAY := Color("F1E2C2")
## The same strip where the row is about gold: a coin, a price, a reward.
const TRAY_WARM := Color("F7E7B4")
const LANTERN_OFF := Color("8C9AA6")


## The hue of whichever season a mansion belongs to, 1 to 28.
static func season_colour(mansion: int) -> Color:
	return SEASON_COLOURS[Mansions.season_of(mansion)]


## A flat card: rounded rect, border, no gradient. The kit replaces it later.
static func card(fill: Color, border: Color, radius: int, border_width: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box
