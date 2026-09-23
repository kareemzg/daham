@tool
class_name AnwaPanel
extends Control
## The twentieth star: the mansion's rhyme, and its name written by hand.
##
## This is not a riddle. The rhyme opens with the mansion's own name — «إذا طلع
## الشرطان، استوى الزمان» — so the answer is in the clue and always was. What
## the player does here is write it: seven letters off a wheel that carries
## nothing else, once per mansion, as the last act before the sky draws the
## figure and says the name back in gold.
##
## Nothing is lost here. A wrong spelling clears the row and costs no lantern.

## The card and the row are laid out against the 1080-wide reference, like
## everything else in `game.gd`, and scaled at draw time.
const PAD_X := 40.0
const PAD_Y := 32.0
const HEAD_SIZE := 30.0
const HEAD_LINE := 44.0
const SAJ_SIZE := 38.0
const SAJ_LINE := 62.0
const ASK_SIZE := 32.0
const ASK_LINE := 50.0
const SLOT := 104.0
const SLOT_GAP := 12.0
const ROW_TOP := 34.0

const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display_bold.tres")

var _card: GlossyPanel
var _head: Label
var _saj: Label
var _ask: Label
var _slots: Array[GlossyPanel] = []
var _letters: Array[Label] = []
## How many letters a hint has opened. They stay open for the rest of the round.
var _hinted: int = 0

## The name the player has to write, already normalised.
var answer: String = ""
## How many of its letters are showing, from the drag or from a hint.
var shown: int = 0
## Set once the name is right, so the row stops taking the drag's word.
var locked: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _card == null:
		_build()


func _build() -> void:
	_card = GlossyPanel.new()
	_card.style = GlossyPanel.Style.PANEL_NIGHT
	add_child(_card)

	_head = _label(UI_BOLD_FONT, Palette.TRAIL)
	_head.text = "سجعُ الأنواء"
	add_child(_head)

	_saj = _label(DISPLAY_FONT, Palette.CREAM)
	add_child(_saj)

	_ask = _label(UI_BOLD_FONT, Palette.MUTED)
	_ask.text = "فأيُّ منزلةٍ هذه؟"
	add_child(_ask)


func _label(font: Variant, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	# Never left to wrap itself: a Label with no width yet claims the height of
	# as many lines as it has words, and centres them off the bottom of the card.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## The rhyme and the name. Both are given whole; the breaking is done here.
func setup(saj: String, name: String) -> void:
	if _card == null:
		_build()
	answer = Arabic.normalise(name)
	shown = 0
	_hinted = 0
	locked = false
	_saj.text = break_saj(saj)
	_rebuild_slots()


## Two clauses to a line. Every rhyme in the book is four short clauses, and a
## Label that wraps on its own is the bug this avoids.
static func break_saj(saj: String) -> String:
	var parts := saj.split("،", false)
	var lines := PackedStringArray()
	var line := ""
	for i in parts.size():
		var clause := parts[i].strip_edges()
		if clause.is_empty():
			continue
		line += clause if line.is_empty() else "، " + clause
		if i % 2 == 1:
			lines.append(line)
			line = ""
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)


func _rebuild_slots() -> void:
	for panel in _slots:
		panel.queue_free()
	_slots.clear()
	_letters.clear()
	for i in answer.length():
		var panel := GlossyPanel.new()
		panel.style = GlossyPanel.Style.WELL
		add_child(panel)
		_slots.append(panel)
		var letter := _label(DISPLAY_FONT, Color("2B2620"))
		letter.text = answer[i]
		letter.visible = false
		panel.add_child(letter)
		_letters.append(letter)


## What the finger has spelled so far. Only a prefix of the name shows: spell
## «الشط» and the row holds «الش», because the fourth letter is not the answer's.
func show_progress(word: String) -> void:
	if locked:
		return
	var spelled := Arabic.normalise(word)
	var matched := 0
	while matched < spelled.length() and matched < answer.length():
		if spelled[matched] != answer[matched]:
			break
		matched += 1
	_paint(maxi(matched, _hinted))


## Opens the next letter the player has not got, free of charge: there is
## nothing to lose on this screen, so there is nothing to sell either.
func reveal_next() -> bool:
	if locked or _hinted >= answer.length():
		return false
	_hinted += 1
	_paint(_hinted)
	return true


func _paint(count: int) -> void:
	shown = clampi(count, 0, answer.length())
	for i in _slots.size():
		var on := i < shown
		_letters[i].visible = on
		_slots[i].style = (
			GlossyPanel.Style.TILE_GOLD if locked
			else (GlossyPanel.Style.TILE if on else GlossyPanel.Style.WELL)
		)


## The name is right. Every slot goes gold and the row stops listening.
func lock() -> void:
	locked = true
	_paint(answer.length())


## The row's own height at this scale, so the caller can find the card's.
func row_height(scale: float) -> float:
	return SLOT * scale


func relayout(scale: float) -> void:
	if _card == null or _slots.is_empty():
		return
	_head.add_theme_font_size_override("font_size", int(HEAD_SIZE * scale))
	_saj.add_theme_font_size_override("font_size", int(SAJ_SIZE * scale))
	_ask.add_theme_font_size_override("font_size", int(ASK_SIZE * scale))

	var lines := float(_saj.text.count("\n") + 1)
	var card_height := (
		PAD_Y * 2.0 + HEAD_LINE + lines * SAJ_LINE + 10.0 + ASK_LINE
	) * scale
	_card.position = Vector2(PAD_X * scale, 0.0)
	_card.size = Vector2(size.x - PAD_X * 2.0 * scale, card_height)

	var y := PAD_Y * scale
	for row: Array in [[_head, HEAD_LINE], [_saj, lines * SAJ_LINE], [_ask, ASK_LINE]]:
		var label := row[0] as Label
		var height := float(row[1]) * scale
		label.position = Vector2(_card.position.x, y)
		label.size = Vector2(_card.size.x, height)
		y += height + (10.0 * scale if label == _saj else 0.0)

	var pitch := SLOT + SLOT_GAP
	var span := minf(
		(SLOT * float(_slots.size()) + SLOT_GAP * float(_slots.size() - 1)) * scale,
		size.x - PAD_X * 2.0 * scale
	)
	# The row shrinks to fit rather than running off the edge: «الشرطان» is
	# seven letters and a narrow window is narrower than seven tiles.
	var cell := span / (float(_slots.size()) + (pitch / SLOT - 1.0) * float(_slots.size() - 1))
	var gap := cell * (SLOT_GAP / SLOT)
	var row_y := card_height + ROW_TOP * scale
	# Column 0 is the RIGHTMOST, as everywhere else in this game.
	var right := (size.x + span) * 0.5
	for i in _slots.size():
		_slots[i].position = Vector2(right - cell - float(i) * (cell + gap), row_y)
		_slots[i].size = Vector2(cell, cell)
		_slots[i].radius_override = cell * 0.22
		_letters[i].position = Vector2.ZERO
		_letters[i].size = Vector2(cell, cell)
		_letters[i].add_theme_font_size_override("font_size", int(cell * 0.56))


## Everything the panel needs from top to bottom, for the caller placing it.
func wanted_height(scale: float) -> float:
	if _saj == null:
		return 0.0
	var lines := float(_saj.text.count("\n") + 1)
	return (
		PAD_Y * 2.0 + HEAD_LINE + lines * SAJ_LINE + 10.0 + ASK_LINE + ROW_TOP + SLOT
	) * scale
