extends SceneTree
## Loads every level in data/levels/ through the engine's own reader and checks it.
##
##   godot --path . --headless --script res://scenes/dev/validate_levels.gd
##
## The generator verifies its own output in Python. This verifies the other side
## of the handover: that `Level` parses each file, that the coordinates land
## inside the grid, and that every word can be spelled from the wheel. Exits
## non-zero if any level fails, so it can gate a commit.

const LEVELS_DIR := "res://data/levels"


func _initialize() -> void:
	var directory := DirAccess.open(LEVELS_DIR)
	if directory == null:
		print("cannot open ", LEVELS_DIR)
		quit(1)
		return

	var names := PackedStringArray()
	for file_name in directory.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name)
	names.sort()

	var failures := 0
	var total_words := 0
	var total_bonus := 0
	var biggest := Vector2i.ZERO
	for file_name in names:
		var level := Level.load_from(LEVELS_DIR.path_join(file_name))
		if level == null:
			print("  FAIL  %s: did not load" % file_name)
			failures += 1
			continue
		var problems := level.validate()
		if not problems.is_empty():
			failures += 1
			for problem in problems:
				print("  FAIL  %s: %s" % [file_name, problem])
			continue
		total_words += level.words.size()
		total_bonus += level.bonus.size()
		biggest = Vector2i(maxi(biggest.x, level.rows), maxi(biggest.y, level.cols))

	var good := names.size() - failures
	print("levels: %s, valid: %s, failed: %s" % [names.size(), good, failures])
	if good > 0:
		print("average grid words %.1f, average bonus words %.1f" % [
			float(total_words) / good, float(total_bonus) / good
		])
		print("largest grid: %s rows x %s cols" % [biggest.x, biggest.y])
	quit(1 if failures > 0 else 0)
