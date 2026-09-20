class_name Progress
extends RefCounted
## What the player has done, saved often enough that quitting cannot undo it.
##
## The point is not convenience, it is that a half-played level has to survive a
## force quit. Without mid-level saving a player who is about to lose a lantern
## can swipe the app away and come back with it, and the cost of a wrong guess
## stops meaning anything. So this records the middle of a level too: the words
## already found, the letters a hint opened, and above all the run of wrong
## guesses, which is the thing a quit would otherwise erase.
##
## Writes go through a temporary file and a rename, because the moment a save
## matters most is exactly the moment the process may be killed: a half-written
## file would lose everything rather than the last word.

const DEFAULT_PATH := "user://progress.json"
const VERSION := 1

var level_id: String = ""
var coins: int = 480
var lanterns: int = 5
## How many wrong guesses in a row. Persisted on purpose: see the note above.
var wrong_streak: int = 0
var moon: int = 0
## Unix time when the next lantern comes back on its own, zero while full. A
## moment rather than a remaining duration, so the wait keeps running while
## the game is closed instead of pausing the moment the app is swiped away.
var lantern_clock: int = 0
var found: PackedStringArray = PackedStringArray()
var bonus_found: PackedStringArray = PackedStringArray()
## Cells a hint opened that no finished word covers, as Vector2i(row, col).
var revealed: Array[Vector2i] = []


static func read(path: String = DEFAULT_PATH) -> Progress:
	"""The saved game, or a fresh one when there is none or it will not parse."""
	var progress := Progress.new()
	if not FileAccess.file_exists(path):
		return progress
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Progress: %s is not readable, starting fresh" % path)
		return progress
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		# A save from another build. Losing it beats loading it wrong.
		push_warning("Progress: save version %s is not %s, starting fresh" % [
			data.get("version"), VERSION
		])
		return progress

	progress.level_id = str(data.get("level_id", ""))
	progress.coins = int(data.get("coins", progress.coins))
	progress.lanterns = int(data.get("lanterns", progress.lanterns))
	progress.wrong_streak = int(data.get("wrong_streak", 0))
	progress.moon = int(data.get("moon", 0))
	progress.lantern_clock = int(data.get("lantern_clock", 0))
	for word in data.get("found", []):
		progress.found.append(str(word))
	for word in data.get("bonus_found", []):
		progress.bonus_found.append(str(word))
	for cell in data.get("revealed", []):
		if cell is Array and cell.size() == 2:
			progress.revealed.append(Vector2i(int(cell[0]), int(cell[1])))
	return progress


func write(path: String = DEFAULT_PATH) -> bool:
	"""Save. Returns false if it could not be written, which is worth knowing."""
	var cells: Array = []
	for cell in revealed:
		cells.append([cell.x, cell.y])
	var payload := {
		"version": VERSION,
		"level_id": level_id,
		"coins": coins,
		"lanterns": lanterns,
		"wrong_streak": wrong_streak,
		"moon": moon,
		"lantern_clock": lantern_clock,
		"found": Array(found),
		"bonus_found": Array(bonus_found),
		"revealed": cells,
	}

	# Write beside the real file, then move it into place. A rename is atomic, so
	# a kill during the write leaves the previous save intact instead of a
	# truncated one.
	var temporary := path + ".part"
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		push_error("Progress: cannot write %s (%s)" % [temporary, FileAccess.get_open_error()])
		return false
	handle.store_string(JSON.stringify(payload))
	handle.close()

	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if error != OK:
		push_error("Progress: cannot replace %s (%s)" % [path, error_string(error)])
		return false
	return true


static func clear(path: String = DEFAULT_PATH) -> void:
	for candidate in [path, path + ".part"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
