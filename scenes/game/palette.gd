class_name Palette
extends RefCounted
## Placeholder colours for the engine slice, taken from the approved UI sample.
##
## These are stand-ins. When the UI kit ships as SVG/nine-slice files, the tiles
## and panels become textures and only the text colours stay here.

const SKY_TOP := Color("071729")
const SKY_MID := Color("0C2A40")
const SKY_LOW := Color("12384D")
const SKY_BOTTOM := Color("16455A")

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
const MUTED := Color("BFD6E0")
const DIM_STAR := Color("7A96A8")
const CREAM := Color("F6EEDC")
const LANTERN_OFF := Color("8C9AA6")


## A flat card: rounded rect, border, no gradient. The kit replaces it later.
static func card(fill: Color, border: Color, radius: int, border_width: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	return box
