class_name MansionCard
extends SkyPopup
## One mansion's card: everything the tradition says about it, and everything
## the player earned in it, each thing in a tray of its own.
##
## **It is built to the shop's measurements, not to its own.** Cream trays on an
## indigo face, the same `Palette.TRAY` at the same radius, the same 26-unit
## inner padding and the same 44-unit margin `SkyWindow` gives every window.
## The first draft of this card invented a tinted capsule per kind of content
## and its own spacing, and it read as a different game — a window is the shop,
## the shelf, the settings and this, and they are one thing four times.
##
## What differs from a shop row is only the register: a heading in ember over a
## body in ink, sized the way the shop sizes a tool's name over what it does.
## Short trays sit two to a row and long ones take the row to themselves.
##
## The figure sits on the night, not on the disc's own face: the ring is the
## season's colour and what it rings is a piece of sky.
##
## There is no star row and no way-out button: the cross in the top corner is
## the whole of the chrome, because a card is a thing you opened and can simply
## close.

const WIDTH := 760.0
## The window's own margin and the shop row's own padding, unchanged.
const PAD := 44.0
const GAP := 16.0
const DISC := 200.0
const DISC_GAP := 24.0

const NAME_SIZE := 58.0
const NAME_LINE := 78.0
const LATIN_SIZE := 24.0
const LATIN_LINE := 34.0
const SEASON_SIZE := 28.0
const SEASON_LINE := 42.0
## Ember over ink, 36 over 28 — the shop's own step from a tool's name to what
## it does, which is what makes a heading read as one.
const HEAD_SIZE := 36.0
const HEAD_LINE := 52.0
const BODY_SIZE := 28.0
const BODY_LINE := 44.0
const SAJ_SIZE := 34.0
const SAJ_LINE := 56.0
const TRAY_PAD_X := 26.0
const TRAY_TOP := 20.0
const TRAY_BOTTOM := 22.0
const TRAY_GAP := 2.0
const TRAY_RADIUS := 38.0
const CROSS := 72.0
## Ember deepened enough to carry small text on cream. `Palette.EMBER` itself
## comes out at three to one against `Palette.TRAY`, which is the floor for
## large type and under it for anything else.
const HEAD_INK := Color("BE5216")
const BODY_INK := Color("4A3E2E")

var _display_font: Font
var _ui_font: Font
var _ui_medium: Font
var _amiri: Font

var _disc: GlossyPanel
var _well: Panel
var _figure: FigureView
var _name: Label
var _latin: Label
var _season: Label
var _cross: GlossyPanel
## One entry per capsule: its panel, its two labels, and how tall it wants to be.
var _cells: Array = []
## Each row is an array of indices into `_cells`. One index is a full-width row.
var _rows: Array = []
var _scale: float = 1.0


func configure(display_font: Font, ui_font: Font, ui_medium: Font, amiri: Font) -> void:
	_display_font = display_font
	_ui_font = ui_font
	_ui_medium = ui_medium
	_amiri = amiri
	dismiss_on_tap = true
	panel.style = GlossyPanel.Style.PANEL_NIGHT

	_disc = GlossyPanel.new()
	_disc.style = GlossyPanel.Style.BUTTON_RIVER
	panel.add_child(_disc)
	# The ring is the season's colour and what it rings is the night. Drawn
	# straight onto the disc's own face the figure sat on teal, which is a
	# constellation on a coin rather than a constellation in the sky.
	_well = Panel.new()
	_well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_disc.add_child(_well)
	_figure = FigureView.new()
	_disc.add_child(_figure)

	_name = _label(_display_font, Palette.GOLD_LIGHT)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(_name)
	_latin = _label(_ui_medium, Color("9FC0CF"))
	_latin.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_latin.text_direction = Control.TEXT_DIRECTION_LTR
	panel.add_child(_latin)
	_season = _label(_ui_font, Palette.SEASON_SPRING)
	_season.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	panel.add_child(_season)

	_cross = GlossyPanel.new()
	_cross.style = GlossyPanel.Style.BUTTON_CREAM
	panel.add_child(_cross)
	var mark := _label(_ui_font, Color("6B5942"))
	mark.text = "×"
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cross.add_child(mark)
	_cross.set_meta("label", mark)
	var button := Button.new()
	Sound.taps(button)
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "إغلاق"
	button.pressed.connect(func() -> void: close_requested.emit())
	button.button_down.connect(func() -> void: _cross.set_pressed(true))
	button.button_up.connect(func() -> void: _cross.set_pressed(false))
	_cross.add_child(button)
	_cross.set_meta("button", button)


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	# RTL: LEFT is the start of the line, which is the right-hand side.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


## Fills the card and lays it out. Everything the file is silent about is simply
## left off, so a mansion nobody has written up shows fewer capsules rather than
## empty ones.
func show_mansion(mansion: int, screen_scale: float) -> void:
	_scale = screen_scale
	var hue := Palette.season_colour(mansion)
	_disc.hue = hue
	_figure.figure = Mansions.figure_of(mansion)
	_name.text = Mansions.name_of(mansion)
	_latin.text = Mansions.latin_of(mansion)
	_latin.visible = not _latin.text.is_empty()
	_season.text = "%s — المنزلة %s من %s" % [
		Mansions.season_name(Mansions.season_of(mansion)),
		Arabic.eastern_digits(mansion),
		Arabic.eastern_digits(Mansions.COUNT),
	]
	_season.add_theme_color_override("font_color", hue)

	for cell: Dictionary in _cells:
		(cell["panel"] as Node).queue_free()
	_cells.clear()
	_rows.clear()

	var meaning := Mansions.meaning_of(mansion)
	if not meaning.is_empty():
		_row([_cell("ما يعنيه", meaning)])
	var alt := Mansions.alt_of(mansion)
	var latin := Mansions.latin_of(mansion)
	var pair: Array[int] = []
	if not alt.is_empty():
		pair.append(_cell("ويُسمّى أيضاً", alt))
	if not latin.is_empty():
		pair.append(_cell("في الأطالس", latin, false, true))
	if not pair.is_empty():
		_row(pair)
	var when := Mansions.time_of(mansion)
	var naw := Mansions.naw_of(mansion)
	var weather: Array[int] = []
	if not when.is_empty():
		weather.append(_cell("متى يطلع", when))
	if not naw.is_empty():
		weather.append(_cell("نوءُه", naw))
	if not weather.is_empty():
		_row(weather)
	var saj := Mansions.saj_of(mansion)
	if not saj.is_empty():
		_row([_cell("السجع", AnwaPanel.break_saj(saj), true)])
	if Mansions.has_verse(mansion):
		var verse := Mansions.verse_of(mansion)
		# `verse_of` hands back each hemistich as its own words, because the
		# tenth star's mode arranges them one by one. The card wants the line.
		var lines := "%s\n%s" % [
			" ".join(verse.get("sadr", PackedStringArray())),
			" ".join(verse.get("ajz", PackedStringArray())),
		]
		_row([_cell("البيت", lines, true, false, str(verse.get("poet", "")))])

	_relayout()


func _row(indices: Array) -> void:
	_rows.append(indices)


## Builds one tray and returns its index. Every tray is the same cream as the
## shop's rows — the season's colour is the disc's ring and nothing else, because
## a colour per kind of content made the card a different game from the window
## beside it. `ltr` is for the Latin name, the one value here that is not Arabic.
func _cell(head: String, body: String, amiri: bool = false,
		ltr: bool = false, sign: String = "") -> int:
	var shell := Panel.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shell)

	var head_label := _label(_ui_font, HEAD_INK)
	head_label.text = head
	shell.add_child(head_label)

	var body_label := _label(_amiri if amiri else _ui_medium, Palette.TILE_INK)
	body_label.text = body
	if ltr:
		body_label.text_direction = Control.TEXT_DIRECTION_LTR
	shell.add_child(body_label)

	var sign_label: Label = null
	if not sign.is_empty():
		sign_label = _label(_ui_font, BODY_INK)
		sign_label.text = "— %s" % sign
		sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		shell.add_child(sign_label)

	_cells.append({
		"panel": shell, "head": head_label, "body": body_label, "sign": sign_label,
		"amiri": amiri, "lines": 1, "height": 0.0,
	})
	return _cells.size() - 1


func relayout(screen_scale: float) -> void:
	_scale = screen_scale
	_relayout()


## Breaks `text` into lines that fit `width`, and returns them joined by
## newlines. A Label left to wrap itself refuses to be shorter than the height
## it works out at its own minimum width — one short word a line — so the card
## would claim a dozen lines for a clause of five words. Breaking it here means
## the capsule knows its own height before it is drawn.
static func wrap_to(text: String, font: Font, size: int, width: float) -> String:
	var out := PackedStringArray()
	for paragraph in text.split("\n", false):
		var line := ""
		for word in (paragraph as String).split(" ", false):
			var tried := word if line.is_empty() else line + " " + word
			if not line.is_empty() and font.get_string_size(
					tried, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = tried
		if not line.is_empty():
			out.append(line)
	return "\n".join(out)


func _relayout() -> void:
	if _disc == null or _display_font == null:
		return
	var s := _scale
	var width := WIDTH * s
	var pad := PAD * s
	var inner := width - pad * 2.0
	var gap := GAP * s

	# Every tray's text is broken to its own column first, because the panel's
	# height is the sum of what the rows turn out to be.
	for row: Array in _rows:
		var slot := inner if row.size() < 2 else (inner - gap) * 0.5
		var text_width := slot - TRAY_PAD_X * 2.0 * s
		var tallest := 0.0
		for index: int in row:
			tallest = maxf(tallest, _measure(_cells[index], text_width, s))
		for index: int in row:
			(_cells[index] as Dictionary)["height"] = tallest

	var y := pad
	var side := DISC * s
	_disc.position = Vector2(width - pad - side, y)
	_disc.size = Vector2(side, side)
	_disc.edge_override = 8.0 * s
	_disc.radius_override = side * 0.5
	var well := side - 22.0 * s
	_well.position = Vector2((side - well) * 0.5, (_disc.face_height() - well) * 0.5)
	_well.size = Vector2(well, well)
	_well.add_theme_stylebox_override(
		"panel", Palette.card(Color("0C2231"), Color(0, 0, 0, 0), int(well * 0.5), 0)
	)
	_figure.position = _well.position
	_figure.size = _well.size

	# The name block is centred against the disc rather than hung from the top,
	# so the two read as one row however long the name is.
	var text_left := pad
	var text_width := inner - side - DISC_GAP * s
	var block := (NAME_LINE + LATIN_LINE + SEASON_LINE) * s
	var block_y := y + (side - block) * 0.5
	_name.add_theme_font_size_override("font_size", int(NAME_SIZE * s))
	_name.position = Vector2(text_left, block_y)
	_name.size = Vector2(text_width, NAME_LINE * s)
	_latin.add_theme_font_size_override("font_size", int(LATIN_SIZE * s))
	_latin.position = Vector2(text_left, block_y + NAME_LINE * s)
	_latin.size = Vector2(text_width, LATIN_LINE * s)
	_season.add_theme_font_size_override("font_size", int(SEASON_SIZE * s))
	_season.position = Vector2(text_left, block_y + (NAME_LINE + LATIN_LINE) * s)
	_season.size = Vector2(text_width, SEASON_LINE * s)

	y += side + gap
	for row: Array in _rows:
		var slot := inner if row.size() < 2 else (inner - gap) * 0.5
		var x := width - pad - slot
		var tallest := 0.0
		for index: int in row:
			var cell: Dictionary = _cells[index]
			_place_cell(cell, Vector2(x, y), slot, s)
			tallest = maxf(tallest, float(cell["height"]))
			x -= slot + gap
		y += tallest + gap
	y += pad - gap

	panel.size = Vector2(width, y)
	# The window's own corner and edge, not the preset's fraction. Left alone,
	# `PANEL_NIGHT`'s radius is 0.22 of the panel's shorter side — 167 units on a
	# card this wide, where every other window in the game rounds at 52.
	panel.edge_override = 12.0 * s
	panel.radius_override = 52.0 * s
	_place_cross(s)
	_place()


## How tall a tray has to be once its text is broken to `text_width`.
func _measure(cell: Dictionary, text_width: float, s: float) -> float:
	var amiri: bool = cell["amiri"]
	var size := int((SAJ_SIZE if amiri else BODY_SIZE) * s)
	var line := (SAJ_LINE if amiri else BODY_LINE) * s
	var body: Label = cell["body"]
	body.text = wrap_to(body.text, body.get_theme_font("font"), size, text_width)
	var lines := body.text.count("\n") + 1
	cell["lines"] = lines
	var height := (
		TRAY_TOP * s + HEAD_LINE * s + TRAY_GAP * s + line * float(lines) + TRAY_BOTTOM * s
	)
	if cell["sign"] != null:
		height += (HEAD_LINE + 4.0) * s
	return height


func _place_cell(cell: Dictionary, at: Vector2, slot: float, s: float) -> void:
	var shell: Panel = cell["panel"]
	var height: float = cell["height"]
	shell.position = at
	shell.size = Vector2(slot, height)
	shell.add_theme_stylebox_override(
		"panel", Palette.card(Palette.TRAY, Color(0, 0, 0, 0), int(TRAY_RADIUS * s), 0)
	)

	var pad_x := TRAY_PAD_X * s
	var text_width := slot - pad_x * 2.0
	var head: Label = cell["head"]
	head.add_theme_font_size_override("font_size", int(HEAD_SIZE * s))
	head.position = Vector2(pad_x, TRAY_TOP * s)
	head.size = Vector2(text_width, HEAD_LINE * s)

	var amiri: bool = cell["amiri"]
	var line := (SAJ_LINE if amiri else BODY_LINE) * s
	var body: Label = cell["body"]
	body.add_theme_font_size_override("font_size", int((SAJ_SIZE if amiri else BODY_SIZE) * s))
	body.position = Vector2(pad_x, TRAY_TOP * s + HEAD_LINE * s + TRAY_GAP * s)
	body.size = Vector2(text_width, line * float(cell["lines"]))

	if cell["sign"] != null:
		var sign: Label = cell["sign"]
		sign.add_theme_font_size_override("font_size", int(SEASON_SIZE * s))
		sign.position = Vector2(pad_x, body.position.y + body.size.y + 4.0 * s)
		sign.size = Vector2(text_width, HEAD_LINE * s)


## The cross sits in the panel's top-LEFT corner, which is the far end of the
## reading order — the figure's disc holds the near one. `position` is not
## mirrored by the project's right-to-left layout, whatever a container would
## do: x zero is the left edge and that is where this goes.
func _place_cross(s: float) -> void:
	var side := CROSS * s
	_cross.position = Vector2(26.0 * s, 26.0 * s)
	_cross.size = Vector2(side, side)
	_cross.edge_override = 6.0 * s
	_cross.radius_override = side * 0.5
	var mark: Label = _cross.get_meta("label")
	mark.position = Vector2.ZERO
	mark.size = Vector2(side, _cross.face_height())
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.add_theme_font_size_override("font_size", int(46.0 * s))
	var button: Button = _cross.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)
