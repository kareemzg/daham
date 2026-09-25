@tool
class_name BaytPanel
extends Control
## اكشف البيت: two hemistichs taken apart, and put back a word at a time.
##
## Once in every mansion the grid stands aside for the line the tradition hangs
## on that mansion. Its words are scattered below; a tap sends one flying to the
## next empty place, a tap on a placed word sends it back. When every place is
## full the line is read: right, and the poet's name is given back; wrong, and
## only the words that are out of order return to the pool.
##
## Nothing is lost here either. What is being asked for is an order, and a
## player who has the order half right should be told which half.

signal completed
signal missed

const PAD_X := 30.0
const WORD_SIZE := 52.0
const SLOT_H := 112.0
const SLOT_GAP := 14.0
const ROW_GAP := 20.0
const POOL_TOP := 52.0
const POOL_GAP := 16.0
const POET_TOP := 34.0
const POET_SIZE := 44.0
const POET_LINE := 62.0
const ASK_SIZE := 28.0
const ASK_LINE := 42.0
const ASK_GAP := 26.0

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display_bold.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

## The line, as two lists of words in their right order.
var _sadr: PackedStringArray = PackedStringArray()
var _ajz: PackedStringArray = PackedStringArray()
var _poet: String = ""

## One entry per place in the line: the pool index sitting there, or -1.
var _filled: PackedInt32Array = PackedInt32Array()
## The scattered words, in the order they are shown. Never re-sorted: a tile
## that moved while the player was looking at it would be a different game.
var _pool: PackedStringArray = PackedStringArray()

var _slots: Array[GlossyPanel] = []
var _slot_labels: Array[Label] = []
var _tiles: Array[GlossyPanel] = []
var _tile_labels: Array[Label] = []
var _poet_label: Label
var _caller: Label
var _ask: Label
var _flyer: Control
var _scale: float = 1.0

## True once the line has been read back right.
var solved: bool = false
## How many full readings the player has asked for, right or wrong.
##
## It is shown after the first miss and nothing else happens to it: no lantern,
## no cap, no denominator. A player who is on their fifth try should be able to
## feel it, and a number with a «من ٥» after it would be a threat the game does
## not keep — nothing waits at five.
var tries: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `verse` is what `Mansions.verse_of()` gives: poet, sadr, ajz.
func setup(verse: Dictionary, shuffle_seed: int) -> void:
	_sadr = PackedStringArray(verse.get("sadr", []))
	_ajz = PackedStringArray(verse.get("ajz", []))
	_poet = str(verse.get("poet", ""))
	solved = false
	tries = 0

	_filled = PackedInt32Array()
	for i in _sadr.size() + _ajz.size():
		_filled.append(-1)

	# Shuffled from the level's own seed, so the same verse is scattered the
	# same way twice running and a player who quits mid-line comes back to the
	# board they left.
	var words := PackedStringArray()
	words.append_array(_sadr)
	words.append_array(_ajz)
	var order: Array[int] = []
	for i in words.size():
		order.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = shuffle_seed
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep := order[i]
		order[i] = order[j]
		order[j] = keep
	_pool = PackedStringArray()
	for i in order:
		_pool.append(words[i])

	_rebuild()


## The word wanted at each place, in reading order: the first hemistich, then
## the second.
func _wanted(place: int) -> String:
	return _sadr[place] if place < _sadr.size() else _ajz[place - _sadr.size()]


func _rebuild() -> void:
	for node in _slots + _tiles:
		node.queue_free()
	for old in [_poet_label, _caller, _ask]:
		if old != null:
			old.queue_free()
	if _flyer != null:
		_flyer.queue_free()
	_slots.clear()
	_slot_labels.clear()
	_tiles.clear()
	_tile_labels.clear()

	for place in _filled.size():
		var slot := GlossyPanel.new()
		slot.style = GlossyPanel.Style.WELL
		add_child(slot)
		_slots.append(slot)
		# Empty. `_paint()` fills it with the word the player actually placed —
		# never with the word that belongs there, which is the answer.
		var label := _label(DISPLAY_FONT, Palette.TILE_INK)
		label.visible = false
		slot.add_child(label)
		_slot_labels.append(label)
		var button := _button(slot)
		var here := place
		button.pressed.connect(func() -> void: _take_back(here))

	for i in _pool.size():
		var tile := GlossyPanel.new()
		tile.style = GlossyPanel.Style.TILE
		add_child(tile)
		_tiles.append(tile)
		var label := _label(DISPLAY_FONT, Palette.TILE_INK)
		label.text = _pool[i]
		tile.add_child(label)
		_tile_labels.append(label)
		var button := _button(tile)
		var which := i
		button.pressed.connect(func() -> void: place_word(which))

	_ask = _label(UI_BOLD_FONT, Palette.DIM_STAR)
	_ask.text = "رتّبِ البيت. انقرِ الكلمةَ فتطيرَ إلى موضعها."
	add_child(_ask)

	_caller = _label(UI_BOLD_FONT, Palette.TRAIL)
	_caller.text = "القائل"
	add_child(_caller)

	_poet_label = _label(DISPLAY_FONT, Palette.DIM_STAR)
	_poet_label.text = "؟"
	add_child(_poet_label)

	_flyer = Control.new()
	_flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flyer.visible = false
	add_child(_flyer)
	var flying := GlossyPanel.new()
	flying.style = GlossyPanel.Style.TILE_GOLD
	_flyer.add_child(flying)
	_flyer.set_meta("panel", flying)
	var flying_label := _label(DISPLAY_FONT, Palette.TILE_INK)
	flying.add_child(flying_label)
	_flyer.set_meta("label", flying_label)


func _label(font: Variant, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(on: Control) -> Button:
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	on.add_child(button)
	on.set_meta("button", button)
	return button


# --- the move ---------------------------------------------------------------

## A tap on a scattered word. It goes to the next empty place, right to left
## across the first hemistich and then the second — which is the order a reader
## would fill them in, and the order that makes the arrangement the puzzle.
func place_word(which: int) -> bool:
	if solved or which < 0 or which >= _pool.size():
		return false
	if _filled.has(which):
		return false
	var place := _filled.find(-1)
	if place < 0:
		return false
	_filled[place] = which
	_fly(which, place)
	_paint()
	if not _filled.has(-1):
		_read_back()
	return true


## A tap on a placed word sends it back to where it came from.
func _take_back(place: int) -> void:
	if solved or place < 0 or place >= _filled.size() or _filled[place] < 0:
		return
	_filled[place] = -1
	_paint()


## Every place is full, so the line can be read. The words that sit where they
## belong stay; the rest go back. Telling the player which half they had is the
## whole point of asking for an order.
func _read_back() -> void:
	var wrong := 0
	for place in _filled.size():
		if _pool[_filled[place]] != _wanted(place):
			_filled[place] = -1
			wrong += 1
	tries += 1
	if wrong == 0:
		solved = true
		_poet_label.text = _poet
		_poet_label.add_theme_color_override("font_color", Palette.GOLD_LIGHT)
		_ask.visible = false
		_paint()
		completed.emit()
		return
	_paint()
	_ask.text = "المحاولةُ %s" % _ordinal(tries + 1)
	missed.emit()


## «الثانية», «الثالثة» … The feminine forms, because a محاولة is feminine.
## Past ten it is a numeral, which is where counting them stops being a nudge
## and starts being a tally.
static func _ordinal(nth: int) -> String:
	const NAMES := [
		"الأولى", "الثانية", "الثالثة", "الرابعة", "الخامسة",
		"السادسة", "السابعة", "الثامنة", "التاسعة", "العاشرة",
	]
	if nth >= 1 and nth <= NAMES.size():
		return NAMES[nth - 1]
	return Arabic.eastern_digits(nth)


## Opens the next empty place with the word it wants, as a hint does.
func reveal_next() -> bool:
	if solved:
		return false
	var place := _filled.find(-1)
	if place < 0:
		return false
	var wanted := _wanted(place)
	for i in _pool.size():
		if _pool[i] == wanted and not _filled.has(i):
			return place_word(i)
	return false


func _paint() -> void:
	for place in _slots.size():
		var taken := _filled[place] >= 0
		# The word the player chose. Writing `_wanted(place)` here instead was
		# the bug that made every tap look right and every line read wrong:
		# the board showed the answer back while `_read_back()` judged the
		# choice, so a player could arrange a verse that looked perfect and be
		# told it was not.
		_slot_labels[place].text = _pool[_filled[place]] if taken else ""
		_slot_labels[place].visible = taken
		_slots[place].style = (
			GlossyPanel.Style.TILE_GOLD if solved
			else (GlossyPanel.Style.TILE if taken else GlossyPanel.Style.WELL)
		)
	for i in _tiles.size():
		var used := _filled.has(i)
		_tiles[i].modulate = Color(1, 1, 1, 0.28 if used else 1.0)
		(_tiles[i].get_meta("button") as Button).disabled = used or solved


## The word arcs from its tile to its place. It is the one thing this mode does
## that the crossword does not, so it is not decoration: it is what a tap means.
func _fly(which: int, place: int) -> void:
	if _flyer == null or which >= _tiles.size() or place >= _slots.size():
		return
	var from: Vector2 = _tiles[which].position + _tiles[which].size * 0.5
	var to: Vector2 = _slots[place].position + _slots[place].size * 0.5
	var panel: GlossyPanel = _flyer.get_meta("panel")
	var label: Label = _flyer.get_meta("label")
	label.text = _pool[which]
	label.add_theme_font_size_override("font_size", int(WORD_SIZE * _scale))
	panel.size = _tiles[which].size
	panel.position = -panel.size * 0.5
	label.size = panel.size
	label.position = Vector2.ZERO
	_flyer.visible = true
	_flyer.position = from
	var lift := minf(120.0 * _scale, absf(to.y - from.y) * 0.5 + 40.0 * _scale)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			# A straight line reads as a slide; the lift is what makes it fly.
			_flyer.position = from.lerp(to, t) - Vector2(0.0, sin(t * PI) * lift),
		0.0, 1.0, 0.34
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void: _flyer.visible = false)


# --- the board ---------------------------------------------------------------


func _width_of(text: String, scale: float) -> float:
	var font: Font = DISPLAY_FONT
	return font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(WORD_SIZE * scale)
	).x


## The width every empty place is drawn at: the widest word in the line.
##
## Sized to its own word, a place told the player which word went in it before
## they had chosen anything — the shape of the empty board was the answer. One
## width for all of them says nothing, and it does not move when a word lands.
func _slot_width(scale: float) -> float:
	var widest := 0.0
	for text in _pool:
		widest = maxf(widest, _width_of(text, scale))
	return maxf(widest + 34.0 * scale, 70.0 * scale)


## Words laid right to left, wrapping when the line runs out of room. `fixed`
## above zero gives every item that width instead of its own.
func _lay_row(
	items: Array, texts: PackedStringArray, top: float, scale: float, gap: float,
	fixed: float = 0.0
) -> float:
	var pad := PAD_X * scale
	var inner := size.x - pad * 2.0
	var height := SLOT_H * scale
	var widths := PackedFloat32Array()
	for text in texts:
		widths.append(
			fixed if fixed > 0.0
			else maxf(_width_of(text, scale) + 34.0 * scale, 70.0 * scale)
		)

	var lines: Array[PackedInt32Array] = []
	var line := PackedInt32Array()
	var run := 0.0
	for i in items.size():
		var next := widths[i] + (gap if not line.is_empty() else 0.0)
		if not line.is_empty() and run + next > inner:
			lines.append(line)
			line = PackedInt32Array()
			run = 0.0
			next = widths[i]
		line.append(i)
		run += next
	if not line.is_empty():
		lines.append(line)

	var y := top
	for row in lines:
		var span := 0.0
		for i in row:
			span += widths[i]
		span += gap * float(row.size() - 1)
		# Column 0 is the rightmost, as everywhere else in this game.
		var right := (size.x + span) * 0.5
		for i in row:
			var node: Control = items[i]
			node.size = Vector2(widths[i], height)
			node.position = Vector2(right - widths[i], y)
			if node is GlossyPanel:
				(node as GlossyPanel).radius_override = height * 0.24
			right -= widths[i] + gap
		y += height + gap
	return y - gap


func relayout(scale: float) -> void:
	if _slots.is_empty():
		return
	_scale = scale
	var gap := SLOT_GAP * scale
	for label in _slot_labels + _tile_labels:
		label.add_theme_font_size_override("font_size", int(WORD_SIZE * scale))

	_ask.add_theme_font_size_override("font_size", int(ASK_SIZE * scale))
	_ask.position = Vector2(0.0, 0.0)
	_ask.size = Vector2(size.x, ASK_LINE * scale)

	var sadr_slots: Array = _slots.slice(0, _sadr.size())
	var ajz_slots: Array = _slots.slice(_sadr.size())
	var top := _ask.size.y + ASK_GAP * scale
	# One width across both hemistichs, or the narrower row would still say
	# which words are short.
	var slot := _slot_width(scale)
	var bottom := _lay_row(sadr_slots, _sadr, top, scale, gap, slot)
	bottom = _lay_row(ajz_slots, _ajz, bottom + ROW_GAP * scale, scale, gap, slot)

	_caller.add_theme_font_size_override("font_size", int(ASK_SIZE * scale))
	_caller.position = Vector2(0.0, bottom + POET_TOP * scale)
	_caller.size = Vector2(size.x, ASK_LINE * scale)
	_poet_label.add_theme_font_size_override("font_size", int(POET_SIZE * scale))
	_poet_label.position = Vector2(0.0, _caller.position.y + _caller.size.y)
	_poet_label.size = Vector2(size.x, POET_LINE * scale)

	var pool_top := _poet_label.position.y + _poet_label.size.y + POOL_TOP * scale
	bottom = _lay_row(_tiles, _pool, pool_top, scale, POOL_GAP * scale)
	for i in _slots.size():
		_slot_labels[i].size = _slots[i].size
		_slot_labels[i].position = Vector2.ZERO
	for i in _tiles.size():
		_tile_labels[i].size = _tiles[i].size
		_tile_labels[i].position = Vector2.ZERO
	_paint()


## How tall the whole board wants to be, for the screen placing it. Measured by
## laying it out, because the rows wrap and nothing else can know how many.
func wanted_height(scale: float, width: float) -> float:
	if _slots.is_empty():
		return 0.0
	var was := size
	size = Vector2(width, was.y)
	relayout(scale)
	var deepest := 0.0
	for node in _slots + _tiles:
		deepest = maxf(deepest, node.position.y + node.size.y)
	size = was
	return deepest
