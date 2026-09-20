@tool
class_name WordGrid
extends Control
## The crossword grid: empty wells that turn into letter tiles as words are found.
##
## Column 0 is the RIGHTMOST column (see `Level`), so the x of a cell counts back
## from the right edge of the grid. `cell_rect()` is the only place that turns a
## column index into an x position.
##
## Each cell is a `GlossyPanel` node rather than a shape drawn in `_draw()`, so a
## cell can be tweened on its own when its word lands.

signal word_revealed(word: String)

const LETTER_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
## Share of a cell's height taken by the hard edge it sits on.
const EDGE_SHARE := 0.0625

var cell_size: float = 140.0:
	set(value):
		cell_size = value
		_place()

var gap: float = 20.0:
	set(value):
		gap = value
		_place()

var _level: Level = null
var _cells: Dictionary = {}  # Vector2i -> String
var _revealed: Dictionary = {}  # Vector2i -> true
var _found: Dictionary = {}  # word -> true
var _panels: Dictionary = {}  # Vector2i -> GlossyPanel
var _labels: Dictionary = {}  # Vector2i -> Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(level: Level) -> void:
	_level = level
	_cells = level.cells()
	_revealed.clear()
	_found.clear()
	for panel in _panels.values():
		panel.queue_free()
	_panels.clear()
	_labels.clear()

	for cell in _cells:
		var panel := GlossyPanel.new()
		panel.style = GlossyPanel.Style.WELL
		add_child(panel)
		_panels[cell] = panel

		var label := Label.new()
		label.text = _cells[cell]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# One letter per Label, so the text server always shapes it isolated.
		# Never put a whole word here: the grid never shows joined script.
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", LETTER_FONT)
		label.add_theme_color_override("font_color", Palette.TILE_INK)
		label.visible = false
		panel.add_child(label)
		_labels[cell] = label

	# No custom_minimum_size: the caller positions this control and sets its cell
	# size, and a minimum recorded here would stop it shrinking for a wider grid.
	_place()


func grid_size() -> Vector2:
	if _level == null:
		return Vector2.ZERO
	var pitch := cell_size + gap
	return Vector2(_level.cols * pitch - gap, _level.rows * pitch - gap)


## The face of a cell, without the hard edge that hangs below it.
func cell_rect(cell: Vector2i) -> Rect2:
	var pitch := cell_size + gap
	# Column 0 sits at the right edge, so walk leftward as the index grows.
	var x := grid_size().x - float(cell.y) * pitch - cell_size
	var y := float(cell.x) * pitch
	return Rect2(Vector2(x, y), Vector2(cell_size, cell_size))


func _edge_for(cell: Vector2i) -> float:
	return 0.0 if not _revealed.has(cell) else cell_size * EDGE_SHARE


func _place() -> void:
	if _level == null or _panels.is_empty():
		return
	size = grid_size()
	var font_size := int(cell_size * 0.542)
	for cell in _panels:
		var rect: Rect2 = cell_rect(cell)
		var edge: float = _edge_for(cell)
		var panel: GlossyPanel = _panels[cell]
		panel.position = rect.position
		panel.size = Vector2(rect.size.x, rect.size.y + edge)
		panel.pivot_offset = panel.size * 0.5
		panel.edge_override = edge

		var label: Label = _labels[cell]
		label.position = Vector2.ZERO
		label.size = rect.size
		label.add_theme_font_size_override("font_size", font_size)


func is_found(word: String) -> bool:
	return _found.has(word)


func is_revealed_at(cell: Vector2i) -> bool:
	return _revealed.has(cell)


func found_count() -> int:
	return _found.size()


func revealed_count() -> int:
	return _revealed.size()


## Cells opened by a hint: revealed, but not covered by any finished word. These
## are the ones a save has to remember by hand, since replaying the found words
## rebuilds all the others.
func hinted_cells() -> Array[Vector2i]:
	var covered: Dictionary = {}
	for word in _found:
		for cell in _level.cells_of(_level.word_entry(word)):
			covered[cell] = true
	var out: Array[Vector2i] = []
	for cell in _revealed:
		if not covered.has(cell):
			out.append(cell)
	return out


func is_solved() -> bool:
	return _level != null and _found.size() == _level.words.size()


## Reveals a grid word. Returns false if it is not in this grid, or already found.
func reveal(word: String, animate: bool = true) -> bool:
	if _level == null or _found.has(word):
		return false
	var entry := _level.word_entry(word)
	if entry.is_empty():
		return false
	_found[word] = true
	for cell in _level.cells_of(entry):
		_revealed[cell] = true
		var panel: GlossyPanel = _panels[cell]
		panel.style = GlossyPanel.Style.TILE
		_labels[cell].visible = true
		if animate:
			_punch(panel)
	_place()
	word_revealed.emit(word)
	return true


## The cell a hint should open: the first still-hidden letter of a word the
## player has not finished. Returns Vector2i(-1, -1) when there is nothing left.
func hint_cell() -> Vector2i:
	if _level == null:
		return Vector2i(-1, -1)
	for entry in _level.words:
		if _found.has(entry["text"]):
			continue
		for cell in _level.cells_of(entry):
			if not _revealed.has(cell):
				return cell
	return Vector2i(-1, -1)


## Opens one letter. A word whose every letter is now showing counts as found.
func reveal_cell(cell: Vector2i, animate: bool = true) -> void:
	if _level == null or not _cells.has(cell) or _revealed.has(cell):
		return
	_revealed[cell] = true
	var panel: GlossyPanel = _panels[cell]
	panel.style = GlossyPanel.Style.TILE
	_labels[cell].visible = true
	if animate:
		_punch(panel)
	_place()
	for entry in _level.words:
		var text: String = entry["text"]
		if _found.has(text):
			continue
		var complete := true
		for word_cell in _level.cells_of(entry):
			if not _revealed.has(word_cell):
				complete = false
				break
		if complete:
			_found[text] = true
			word_revealed.emit(text)


## Pulses the cells of an already-found word, without scoring it again.
func nudge(word: String) -> void:
	if _level == null:
		return
	var entry := _level.word_entry(word)
	if entry.is_empty():
		return
	for cell in _level.cells_of(entry):
		_punch(_panels[cell])


func _punch(panel: GlossyPanel) -> void:
	if not is_inside_tree():
		return
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE
	var tween := panel.create_tween()
	tween.tween_property(panel, "scale", Vector2(1.14, 1.14), 0.09)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.13).set_trans(Tween.TRANS_BACK)
