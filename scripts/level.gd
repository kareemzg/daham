class_name Level
extends RefCounted
## One level, loaded from the JSON that `tools/pipeline/build_level.py` writes.
##
## Grid coordinates are logical, not visual. `row` grows downward. `col` grows
## LEFTWARD: column 0 is the rightmost column, because the grid reads right to
## left. A horizontal word fills `col, col + 1, ...` with its first letter in
## the rightmost of those cells; a vertical word fills `row, row + 1, ...`.

const HORIZONTAL := "h"
const VERTICAL := "v"

var id: String = ""
var mansion: int = 0
var mansion_name: String = ""
var season: String = ""
var index_in_mansion: int = 0
var letters: PackedStringArray = PackedStringArray()
var rows: int = 0
var cols: int = 0
## Each entry: {text: String, row: int, col: int, direction: String}
var words: Array[Dictionary] = []
var bonus: PackedStringArray = PackedStringArray()

var _cells: Dictionary = {}  # Vector2i -> String


static func load_from(path: String) -> Level:
	if not FileAccess.file_exists(path):
		push_error("Level not found: %s" % path)
		return null
	var raw := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Level is not a JSON object: %s" % path)
		return null

	var level := Level.new()
	level.id = parsed.get("id", "")
	level.mansion = int(parsed.get("mansion", 0))
	level.mansion_name = parsed.get("mansion_name", "")
	level.season = parsed.get("season", "")
	level.index_in_mansion = int(parsed.get("index_in_mansion", 0))
	for letter in parsed.get("letters", []):
		level.letters.append(Arabic.normalise(str(letter)))
	var grid: Dictionary = parsed.get("grid", {})
	level.rows = int(grid.get("rows", 0))
	level.cols = int(grid.get("cols", 0))
	for entry in parsed.get("words", []):
		level.words.append({
			"text": Arabic.normalise(str(entry.get("text", ""))),
			"row": int(entry.get("row", 0)),
			"col": int(entry.get("col", 0)),
			"direction": str(entry.get("direction", HORIZONTAL)),
		})
	for word in parsed.get("bonus", []):
		level.bonus.append(Arabic.normalise(str(word)))
	level._build_cells()
	return level


func _build_cells() -> void:
	_cells.clear()
	for entry in words:
		var text: String = entry["text"]
		for i in text.length():
			_cells[cell_at(entry, i)] = text[i]


## The grid cell holding letter `index` of a placed word.
func cell_at(entry: Dictionary, index: int) -> Vector2i:
	if entry["direction"] == HORIZONTAL:
		return Vector2i(int(entry["row"]), int(entry["col"]) + index)
	return Vector2i(int(entry["row"]) + index, int(entry["col"]))


## Every cell of a placed word, in reading order.
func cells_of(entry: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var text: String = entry["text"]
	for i in text.length():
		out.append(cell_at(entry, i))
	return out


## All filled cells: Vector2i(row, col) -> letter.
func cells() -> Dictionary:
	return _cells.duplicate()


func word_entry(text: String) -> Dictionary:
	for entry in words:
		if entry["text"] == text:
			return entry
	return {}


func has_grid_word(text: String) -> bool:
	return not word_entry(text).is_empty()


func is_bonus(text: String) -> bool:
	return bonus.has(text)


func word_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in words:
		out.append(entry["text"])
	return out


## Sanity check for generated data: every level must be solvable from its wheel.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if rows <= 0 or cols <= 0:
		problems.append("grid has no size")
	if letters.is_empty():
		problems.append("no wheel letters")
	for entry in words:
		var text: String = entry["text"]
		if not _spellable(text):
			problems.append("'%s' cannot be spelled from the wheel" % text)
		for cell in cells_of(entry):
			if cell.x < 0 or cell.y < 0 or cell.x >= rows or cell.y >= cols:
				problems.append("'%s' falls outside the grid at %s" % [text, cell])
				break
	for word in bonus:
		if has_grid_word(word):
			problems.append("'%s' is listed both as a grid word and a bonus word" % word)
	return problems


func _spellable(text: String) -> bool:
	var pool: Dictionary = {}
	for letter in letters:
		pool[letter] = int(pool.get(letter, 0)) + 1
	for i in text.length():
		var letter := text[i]
		var left := int(pool.get(letter, 0))
		if left <= 0:
			return false
		pool[letter] = left - 1
	return true
