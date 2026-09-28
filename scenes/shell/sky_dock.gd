@tool
class_name SkyDock
extends Control
## The whole bottom of the hub, as ONE piece: the mansion's card and the bar of
## doors joined inside a single frosted pane.
##
## The screen used to carry fourteen separate outlines — four HUD chips, a gear,
## an arrow, the card, the bar, five discs, five labels — and read, in Kareem's
## words, «رقعٌ مجمّعة». Fewer outlines containing more is the whole idea:
##
##  * one pane, not two. What divides the card from the bar is a 2px line with
##    a margin either side — a divider, not a second border.
##  * corners on the outside only: rounded at the top, square at the bottom,
##    because the bottom meets the edge of the screen.
##  * one shadow for the assembly, thrown upward, never one per piece.
##  * the sky's own doors, not a second set: the bar emits the signals the map
##    already had, and the map's row stands down.
##  * «السماء» is notched into the top edge of the bar and crosses the divider,
##    which is what ties the two halves together by eye rather than by a rule.
##
## The face is frosted rather than opaque: the Milky Way passes through it and a
## bright star shows as a smudge, so the dock belongs to the same night as the
## sky instead of sitting on a picture of one. That needs `BackBufferCopy`, and
## therefore needs the dock NOT to be on a `CanvasLayer` — `Shell` is a plain
## `Control`, which is why it lives there.

signal play_requested
signal chosen(tab: int)

## «واصل» breathes: the one thing on the screen that moves, so the eye finds
## the way on without being told. Slow — two and a half seconds — and small,
## because a button that pulses hard reads as an advertisement. It stops while
## the finger is down, or the press and the breath fight each other.
const CALL_SECONDS := 2.5
const CALL_DEPTH := 0.035
const CALL_FPS := 24.0

enum Tab { DAILY, QIRAN, SKY, CARDS, SHOP }

const FROST_SHADER := preload("res://assets/ui/frost.gdshader")

## Every number is in the 1080-wide reference space, like the rest of the game.
const PAD_X := 40.0
const RADIUS := 56.0
const NAME_SIZE := 56.0
const NOTE_SIZE := 29.0
const DOTS_HEIGHT := 22.0
const PLAY_HEIGHT := 104.0

## The card's parts, and its height as the SUM of them — never a number
## standing beside them. Guessed, it disagreed with the layout by thirteen
## units and pushed the bar's labels off the bottom of the screen: visible on
## the collection, where the dock is the bar alone, and gone on the map. A
## derived constant cannot drift from the layout that uses it.
const CARD_TOP := 20.0
const NAME_LINE := NAME_SIZE * 1.34
const AFTER_NAME := 10.0
const AFTER_DOTS := 14.0
## The centre disc climbs out of the bar and over this gap, so the gap is what
## keeps it off «واصل». It was sixteen and the star sat on the word.
const AFTER_PLAY := 38.0
const DIVIDER := 2.0
const CARD_HEIGHT := (
	CARD_TOP + NAME_LINE + AFTER_NAME + DOTS_HEIGHT + AFTER_DOTS
	+ PLAY_HEIGHT + AFTER_PLAY + DIVIDER
)
const BAR_HEIGHT := 224.0
const HEIGHT := CARD_HEIGHT + BAR_HEIGHT
const SIDE_DISC := 92.0
## How much of its slot a disc fills. The rest is the gap between them.
const DISC_SHARE := 0.46
const LABEL_SIZE := 26.0
const ICON_SHARE := 0.54
## How far a pressed control sinks: exactly what its hard edge gives up, so
## nothing above it moves. A scale would shake the text and read as rubber.
const SINK := 0.72

## Four doors, and no «السماء» among them. The sky is not one section of five:
## it is the room the others open off, and every road already passes through
## it — so a tab for it was a button that meant "you are here". Dropping it
## gave the four their full share of the width and took the raised disc off
## «واصل» in the same move.
const TABS := [
	{"tab": Tab.DAILY, "icon": UiIcon.Kind.DIPPER, "text": "اليومي", "hue": "E89A54"},
	{"tab": Tab.QIRAN, "icon": UiIcon.Kind.MOON, "text": "القِران", "hue": "C36B7E"},
	{"tab": Tab.CARDS, "icon": UiIcon.Kind.STAR_CARDS, "text": "البطاقات", "hue": "A98BD6"},
	{"tab": Tab.SHOP, "icon": UiIcon.Kind.SHOP, "text": "المتجر", "hue": "3FA89B"},
]

var _copy: BackBufferCopy
var _frost: ColorRect
var _frost_material: ShaderMaterial
var _divider: ColorRect
var _name: Label
var _note: Label
var _dots: StarDots
var _play: GlossyPanel
var _slots: Array = []
var _call: float = 0.0
var _since_call: float = 0.0
var _play_down: bool = false
var _display_font: Font
var _ui_font: Font


func configure(display_font: Font, ui_font: Font) -> void:
	_display_font = display_font
	_ui_font = ui_font
	mouse_filter = Control.MOUSE_FILTER_PASS

	# The copy has to run before the frost samples the screen, so it is the
	# first child: a buffer one frame stale makes the blur lag the sky's drift.
	_copy = BackBufferCopy.new()
	# The whole viewport, not a rect. `COPY_MODE_RECT` takes its rect in the
	# node's own space and a pane parked at the bottom of the screen copied a
	# region that was never drawn, so the blur sampled black and the pane came
	# out near-opaque whatever its tint said.
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)

	_frost_material = ShaderMaterial.new()
	_frost_material.shader = FROST_SHADER
	_frost = ColorRect.new()
	_frost.material = _frost_material
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frost)

	_name = _label(_display_font, Palette.GOLD_LIGHT, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(_name)
	_note = _label(_ui_font, Color("C4B6DC"), HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(_note)

	_dots = StarDots.new()
	add_child(_dots)

	_play = GlossyPanel.new()
	_play.style = GlossyPanel.Style.BUTTON_EMBER
	add_child(_play)
	var play_label := _label(_display_font, Color("FFF3E2"), HORIZONTAL_ALIGNMENT_CENTER)
	play_label.text = "واصل"
	_play.add_child(play_label)
	_play.set_meta("label", play_label)
	var play_button := Button.new()
	Sound.taps(play_button)
	play_button.flat = true
	play_button.focus_mode = Control.FOCUS_ALL
	play_button.tooltip_text = "واصل"
	play_button.button_down.connect(func() -> void:
		_play_down = true
		_play.set_pressed(true))
	play_button.button_up.connect(func() -> void:
		_play_down = false
		_play.set_pressed(false))
	play_button.pressed.connect(func() -> void:
		_play.set_pressed(false)
		play_requested.emit())
	_play.add_child(play_button)
	_play.set_meta("button", play_button)

	# A line with a margin either side, never a second border.
	_divider = ColorRect.new()
	_divider.color = Color(Palette.MILKY_VIOLET, 0.26)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_divider)

	for spec: Dictionary in TABS:
		_slots.append(_slot(spec))
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not visible or not shows_card or _play == null:
		return
	_call += delta
	_since_call += delta
	if _since_call < 1.0 / CALL_FPS:
		return
	_since_call = 0.0
	if _play_down:
		_play.modulate = Color(1, 1, 1)
		return
	# Brightness, not scale: scaling the button shakes its word, and this one
	# sits directly under a row of text that must not move with it.
	var breath := 1.0 + CALL_DEPTH * (1.0 - cos(_call * TAU / CALL_SECONDS))
	_play.modulate = Color(breath, breath, breath)


func _label(font: Font, colour: Color, align: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


func _slot(spec: Dictionary) -> Dictionary:
	var disc := GlossyPanel.new()
	disc.style = GlossyPanel.Style.BUTTON_RIVER
	disc.hue = Color(spec["hue"] as String)
	add_child(disc)

	# The icons are the ones the game already has, unchanged.
	var icon := UiIcon.new()
	icon.kind = spec["icon"]
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(icon)

	var label := _label(_display_font,
		Color(spec["hue"] as String).lightened(0.32), HORIZONTAL_ALIGNMENT_CENTER)
	label.text = spec["text"]
	add_child(label)

	var button := Button.new()
	Sound.taps(button)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = spec["text"]
	var slot := {"tab": spec["tab"], "disc": disc, "icon": icon, "label": label,
		"button": button, "down": false}
	button.button_down.connect(func() -> void: _press(slot, true))
	button.button_up.connect(func() -> void: _press(slot, false))
	button.pressed.connect(func() -> void:
		_press(slot, false)
		chosen.emit(spec["tab"]))
	add_child(button)
	return slot


## The disc gives up its hard edge and drops by the same amount, so its face
## moves and its label does not. A ring of its own colour blooms and goes.
func _press(slot: Dictionary, down: bool) -> void:
	slot["down"] = down
	var disc: GlossyPanel = slot["disc"]
	disc.set_pressed(down)
	disc.modulate = Color(0.88, 0.88, 0.88) if down else Color(1, 1, 1)


func show_progress(mansion: int, index: int, total: int) -> void:
	_name.text = Mansions.name_of(mansion)
	_note.text = "النجمة %s من %s" % [
		Arabic.eastern_digits(index), Arabic.eastern_digits(total)
	]
	_dots.setup(total, maxi(index - 1, 0))


## Which door stands open, so the dock says where the player is.
func mark(tab: int) -> void:
	for slot: Dictionary in _slots:
		var lit: bool = slot["tab"] == tab
		(slot["label"] as Label).modulate = Color(1, 1, 1) if lit else Color(1, 1, 1, 0.7)
		if not bool(slot["down"]):
			(slot["disc"] as GlossyPanel).modulate = (
				Color(1.16, 1.16, 1.16) if lit else Color(0.84, 0.88, 0.94)
			)


## Whether the card half is shown. The collection has no mansion in hand, so
## there the dock is the bar alone — and the pane shrinks to match rather than
## leaving a hole where the card was.
var shows_card: bool = true:
	set(value):
		shows_card = value
		for node: Control in [_name, _note, _dots, _play, _divider]:
			if node != null:
				node.visible = value


func wanted_height(s: float) -> float:
	return (HEIGHT if shows_card else BAR_HEIGHT) * s


func buttons() -> Array[Button]:
	var out: Array[Button] = []
	out.append(_play.get_meta("button") as Button)
	for slot: Dictionary in _slots:
		out.append(slot["button"])
	return out


func relayout(s: float) -> void:
	if _frost == null or size.x <= 0.0:
		return
	var pad := PAD_X * s
	var inner := size.x - pad * 2.0

	_frost.position = Vector2.ZERO
	_frost.size = size
	_frost_material.set_shader_parameter("rect_size", size)
	_frost_material.set_shader_parameter("corner_radius", RADIUS * s)
	# Top corners only: the bottom of the assembly is the bottom of the screen.
	_frost_material.set_shader_parameter("corners", Vector4(1.0, 1.0, 0.0, 0.0))
	_frost_material.set_shader_parameter("blur_radius", 18.0)
	_frost_material.set_shader_parameter("rim_width", 2.0 * s)

	var y := 0.0
	if shows_card:
		y = CARD_TOP * s
		var name_line := NAME_LINE * s
		_name.add_theme_font_size_override("font_size", int(NAME_SIZE * s))
		_note.add_theme_font_size_override("font_size", int(NOTE_SIZE * s))
		# Both take the whole row and pull to opposite ends: RTL mirrors x, so
		# splitting the row into two boxes by hand puts them on top of each
		# other. LEFT is the start of the line, which is the right-hand side.
		for label: Label in [_name, _note]:
			label.position = Vector2(pad, y)
			label.size = Vector2(inner, name_line)
		y += name_line + AFTER_NAME * s

		_dots.position = Vector2(pad, y)
		_dots.size = Vector2(inner, DOTS_HEIGHT * s)
		y += DOTS_HEIGHT * s + AFTER_DOTS * s

		_play.position = Vector2(pad, y)
		_play.size = Vector2(inner, PLAY_HEIGHT * s)
		_play.radius_override = 34.0 * s
		# Centred in the FACE, which is the panel less its hard bottom edge —
		# centring in the whole rect drops the word onto that edge.
		var play_label: Label = _play.get_meta("label")
		play_label.add_theme_font_size_override("font_size", int(41.0 * s))
		play_label.position = Vector2.ZERO
		play_label.size = Vector2(inner, _play.face_height())
		play_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var play_button: Button = _play.get_meta("button")
		play_button.position = Vector2.ZERO
		play_button.size = _play.size
		# The centre disc climbs out of the bar and over this gap, so the gap is
		# what keeps it off «واصل». It was sixteen and the star sat on the word.
		y += PLAY_HEIGHT * s + AFTER_PLAY * s

		_divider.position = Vector2(pad * 0.7, y)
		_divider.size = Vector2(size.x - pad * 1.4, DIVIDER * s)
		y += DIVIDER * s

	var bar_top := y
	var count := float(_slots.size())
	var slot_width := size.x / count
	for i in _slots.size():
		var slot: Dictionary = _slots[i]
		var disc: GlossyPanel = slot["disc"]
		# The disc takes a share of its slot rather than a fixed number, so the
		# four spread across whatever width the screen has instead of sitting
		# in the middle of it with air on both sides.
		var side := minf(slot_width * DISC_SHARE, SIDE_DISC * 1.5 * s)
		var mid_x := size.x - (float(i) + 0.5) * slot_width
		var top := bar_top + 20.0 * s
		disc.size = Vector2(side, side)
		disc.position = Vector2(mid_x - side * 0.5, top)
		# A rounded square for a door, a circle for the sky. The design draws
		# them that way and it is doing work: the round one is the odd one out,
		# which is how the eye finds the middle without a label.
		disc.radius_override = side * 0.30

		var icon: UiIcon = slot["icon"]
		var reach := side * ICON_SHARE
		icon.size = Vector2(reach, reach)
		icon.position = Vector2((side - reach) * 0.5, (disc.face_height() - reach) * 0.5)

		# Sized by the line that has to clear, not by the point size: Amiri and
		# Plex both hang below the baseline.
		var label: Label = slot["label"]
		var line := LABEL_SIZE * s
		label.add_theme_font_size_override("font_size", int(line))
		var box := line * 1.9
		label.size = Vector2(slot_width, box)
		label.position = Vector2(mid_x - slot_width * 0.5, top + side + 2.0 * s)

		var button: Button = slot["button"]
		button.position = Vector2(mid_x - slot_width * 0.5, top)
		button.size = Vector2(slot_width, side + box)
