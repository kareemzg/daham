extends Control
## Drives the playable slice and checks it, then saves a screenshot.
##
##   godot --path . res://scenes/dev/game_test.tscn
##
## Exits 0 when every check passes, 1 otherwise, so it can gate a commit.
## Writes tools/out/game_slice.png for looking at.

const SHOT_PATH := "res://tools/out/game_slice.png"

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0
var _done: bool = false

@onready var game: GameScreen = $Game


func _ready() -> void:
	# The project runs in low-processor mode, which stalls frame_post_draw.
	OS.low_processor_usage_mode = false
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _check_equal(label: String, actual: Variant, expected: Variant) -> void:
	_check("%s (got %s, want %s)" % [label, actual, expected], actual == expected)


func _run() -> void:
	print("=== level data ===")
	var level := game.level
	_check("level loaded", level != null)
	if level == null:
		_finish()
		return
	_check_equal("level id", level.id, "sample")
	_check_equal("grid rows", level.rows, 4)
	_check_equal("grid cols", level.cols, 6)
	_check_equal("grid words", level.words.size(), 5)
	_check_equal("wheel letters", level.letters.size(), 4)
	_check_equal("level validates", level.validate().size(), 0)
	# 13 cells, not 5 words x their lengths: the words share their crossings.
	_check_equal("filled cells", level.cells().size(), 13)
	# Row 2, column 5 is the far LEFT of the third row: the alif of بات.
	_check_equal("crossing cell reads right to left", level.cells().get(Vector2i(2, 5), ""), "ا")

	# Every shipped level, not one sample. A grid is generated, so a fault in
	# the pipeline shows up in a handful of files somewhere in the middle of the
	# season and in none of the ones anybody opens by hand: the level that would
	# not finish was the fifteenth, and six of the five hundred and sixty were
	# like it.
	print("=== every shipped level holds together ===")
	var faults := PackedStringArray()
	var counted := 0
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var id := Mansions.level_id(mansion + 1, index + 1)
			var shipped := Level.load_from("res://data/levels/%s.json" % id)
			if shipped == null:
				faults.append("%s will not load" % id)
				continue
			counted += 1
			for problem in shipped.validate():
				faults.append("%s: %s" % [id, problem])
	_check_equal("all of the season is there", counted,
		Mansions.SHIPPED * Mansions.LEVELS_PER_MANSION)
	if faults.size() > 0:
		for fault in faults:
			print("      %s" % fault)
	_check_equal("...and every one of them validates", faults.size(), 0)

	# The check that would have caught it, proved against a grid built to fail.
	# «با» laid across «باب» adds no cell of its own, so finding the longer word
	# leaves the shorter one unfound with nothing left on the board to reveal.
	var nested := Level.new()
	nested.rows = 1
	nested.cols = 3
	nested.letters = PackedStringArray(["ب", "ا"])
	nested.words = [
		{"text": "باب", "row": 0, "col": 0, "direction": Level.HORIZONTAL},
		{"text": "با", "row": 0, "col": 0, "direction": Level.HORIZONTAL},
	]
	nested._build_cells()
	var complaint := ""
	for problem in nested.validate():
		if problem.contains("run of its own"):
			complaint = problem
	_check("a word hiding inside another is refused (%s)" % complaint, complaint != "")

	print("=== layout has no overlaps ===")
	var toast_bottom: float = game.toast.position.y + game.toast.size.y
	var grid_top: float = game.grid.position.y
	var grid_bottom: float = grid_top + game.grid.size.y
	var preview_bottom: float = game.preview.position.y + game.preview.size.y
	var wheel_top: float = game.wheel.position.y
	var wheel_bottom: float = wheel_top + game.wheel.size.y
	var stars_bottom: float = game.stars.position.y + game.stars.size.y
	_check("toast clears the grid (%s <= %s)" % [toast_bottom, grid_top], toast_bottom <= grid_top)
	_check("star band clears the toast (%s <= %s)" % [stars_bottom, game.toast.position.y], stars_bottom <= game.toast.position.y)
	_check("preview clears the wheel (%s <= %s)" % [preview_bottom, wheel_top], preview_bottom <= wheel_top)
	# The grid runs down to the wheel now, so it no longer clears the preview —
	# it passes under it. What has to hold instead: the grid stops above the
	# wheel, and the preview is a later child, so the pill draws over the last
	# row for the second a word is being spelled rather than being fenced out
	# of a strip that is empty the rest of the time.
	_check("grid clears the wheel (%s <= %s)" % [grid_bottom, wheel_top], grid_bottom <= wheel_top)
	_check(
		"the preview draws over the grid, not beside it (%d > %d)"
		% [game.preview.get_index(), game.grid.get_index()],
		game.preview.get_index() > game.grid.get_index()
	)
	_check(
		"...and so does its pill",
		game._preview_pill != null and game._preview_pill.get_index() > game.grid.get_index()
	)
	# An empty preview must not sit on the board: the pill hides itself, and
	# the label has nothing to paint.
	_check("an idle preview covers nothing",
		game.preview.text.is_empty() and not game._preview_pill.visible)
	_check("wheel fits on screen (%s <= %s)" % [wheel_bottom, game.size.y], wheel_bottom <= game.size.y)
	# The design seats the tiles inside the disc. Grow a tile far enough and it
	# climbs onto the rim instead, which no other check would notice.
	var tile_reach: float = game.wheel.orbit_radius + game.wheel.tile_radius
	_check(
		"wheel tiles stay inside the disc (%s <= %s)" % [tile_reach, game.wheel.body_radius],
		tile_reach <= game.wheel.body_radius
	)

	print("=== arabic rules ===")
	_check_equal("diacritics stripped", Arabic.normalise("كِتَابٌ"), "كتاب")
	_check_equal("hamza alif folded", Arabic.normalise("أكل"), "اكل")
	_check_equal("taa marbuta kept", Arabic.normalise("كاتبة"), "كاتبة")
	_check_equal("eastern digits", Arabic.eastern_digits(480), "٤٨٠")

	print("=== drag through real input ===")
	await _drag_wheel([0, 1, 2, 3])  # ك ت ا ب
	_check("كتاب found by dragging", game.grid.is_found("كتاب"))
	_check_equal("one word found", game.grid.found_count(), 1)

	print("=== word rules ===")
	_check_equal("repeat of a found word", game.submit("كتاب"), GameScreen.Result.ALREADY_FOUND)
	_check_equal("still one word found", game.grid.found_count(), 1)
	_check_equal("normalised repeat", game.submit("كتأب"), GameScreen.Result.ALREADY_FOUND)
	_check_equal("bonus word", game.submit("بكت"), GameScreen.Result.BONUS)
	_check_equal("moon advanced", game.moon, 1)
	_check_equal("bonus repeat", game.submit("بكت"), GameScreen.Result.BONUS_REPEAT)
	_check_equal("moon unchanged", game.moon, 1)
	_check_equal("non-word", game.submit("باك"), GameScreen.Result.INVALID)
	_check_equal("wrong streak counted", game.wrong_streak, 1)
	_check_equal("single letter ignored", game.submit("ك"), GameScreen.Result.TOO_SHORT)

	print("=== lantern rule: five wrong in a row ===")
	_check_equal("lanterns before", game.lanterns, 5)
	for i in 4:
		game.submit("تبك")
	_check_equal("a lantern goes out on the fifth", game.lanterns, 4)
	_check_equal("streak reset", game.wrong_streak, 0)

	print("=== wheel backtracking ===")
	game.wheel.begin_at(game.wheel.tile_centre(0))
	game.wheel.extend_to(game.wheel.tile_centre(1))
	game.wheel.extend_to(game.wheel.tile_centre(2))
	_check_equal("three letters picked", game.wheel.current_word(), "كتا")
	game.wheel.extend_to(game.wheel.tile_centre(1))
	_check_equal("sliding back un-picks", game.wheel.current_word(), "كت")

	# Hold this half-drawn drag for the screenshot: it shows the trail and the
	# connected preview strip at the same time.
	await _screenshot()
	await _check_sky_twinkles()
	game.wheel.cancel()

	print("=== buttons ===")
	var before_shuffle := Array(game.wheel.letters())
	before_shuffle.sort()
	(game.shuffle_button.get_meta("button") as Button).pressed.emit()
	var after_shuffle := Array(game.wheel.letters())
	after_shuffle.sort()
	_check_equal("shuffle keeps the same letters", after_shuffle, before_shuffle)
	# The faces must move with the data, or a drag spells one word and shows another.
	_check_equal(
		"tiles show what the wheel holds",
		Array(game.wheel.shown_letters()),
		Array(game.wheel.letters())
	)

	var coins_before := game.coins
	var revealed_before := game.grid.revealed_count()
	(game.hint_button.get_meta("button") as Button).pressed.emit()
	# The button opens the shelf now; which tool to spend on is the player's.
	_check("the hint button opens the shelf", game.hints_window.visible)
	_check_equal("...and spends nothing by itself", game.coins, coins_before)
	game.hints_window.rows[Tools.Kind.SPYGLASS].pressed.emit()
	_check_equal(
		"the spyglass charges its price",
		game.coins, coins_before - Tools.PRICES[Tools.Kind.SPYGLASS]
	)
	_check_equal("...and opens one letter", game.grid.revealed_count(), revealed_before + 1)
	_check_equal("...without finishing a word", game.grid.found_count(), 1)

	print("=== finishing the level ===")
	for word in ["كاتب", "كتب", "تاب", "بات"]:
		_check_equal("found %s" % word, game.submit(word), GameScreen.Result.CORRECT)
	_check("level solved", game.grid.is_solved())
	_check_equal(
		"reward paid", game.coins, 480 - GameScreen.HINT_COST + GameScreen.LEVEL_REWARD
	)
	# Eleven for the levels behind this one, plus the one this level just earned.
	_check_equal("stars lit", game.stars.lit, level.index_in_mansion)

	await _check_level_complete()

	# The fixture is six columns and four letters, so on its own it would never
	# catch a layout that cannot shrink. The widest level is found rather than
	# named: the levels are generated, so naming one ties this check to a
	# particular run of the pipeline and it breaks on the next regeneration for
	# no reason. Searching the shipped season also keeps it honest about what a
	# player of this build actually reaches.
	print("=== the widest level in the game still fits ===")
	var widest: Level = null
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var candidate := Level.load_from(
				"res://data/levels/%s.json" % Mansions.level_id(mansion + 1, index + 1)
			)
			if candidate != null and (widest == null or candidate.cols > widest.cols):
				widest = candidate
	_check("the widest shipped level loads", widest != null)
	if widest != null:
		print("  (it is %s, %d columns, %d letters)" % [
			widest.id, widest.cols, widest.letters.size()
		])
		# Nine is the number that matters: past it the grid has to shrink its
		# cells rather than the screen growing, which is the case that broke.
		_check("it is a wide one (%d columns)" % widest.cols, widest.cols >= 9)
		game.show_level(widest)
		var left: float = game.grid.position.x
		var right: float = left + game.grid.size.x
		var bottom: float = game.grid.position.y + game.grid.size.y
		_check("it starts on screen (%s >= 0)" % left, left >= 0.0)
		_check("it ends on screen (%s <= %s)" % [right, game.size.x], right <= game.size.x)
		_check(
			"it clears the preview (%s <= %s)" % [bottom, game.preview.position.y],
			bottom <= game.preview.position.y
		)
		_check("its cells shrank (%s < %s)" % [game.grid.cell_size, GameScreen.CELL],
			game.grid.cell_size < GameScreen.CELL)

	# The fullest wheel is a separate search from the widest grid. They used to
	# be the same level and the checks were written as one; they are not the
	# same level any more, and a wheel check riding on a grid search silently
	# stops testing the wheel the day the pipeline runs again.
	var fullest: Level = null
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var candidate := Level.load_from(
				"res://data/levels/%s.json" % Mansions.level_id(mansion + 1, index + 1)
			)
			if candidate != null and (
				fullest == null or candidate.letters.size() > fullest.letters.size()
			):
				fullest = candidate
	_check("a fullest wheel was found", fullest != null)
	if fullest != null:
		print("  (the fullest wheel is %s, %d letters)" % [fullest.id, fullest.letters.size()])
		# Seven letters on the wheel at the four-letter tile size overlap.
		_check_equal("the shipped season reaches seven letters", fullest.letters.size(), 7)
		game.show_level(fullest)
		var count := game.wheel.letter_count()
		var spacing: float = 2.0 * game.wheel.orbit_radius * sin(PI / float(count))
		var drawn: float = game.wheel.effective_tile_radius() * 2.0
		_check("its tiles keep clear (%0.1f <= %0.1f)" % [drawn, spacing], drawn <= spacing)

	_check_saving()
	await _check_autosave()
	await _check_finish_save()
	await _check_shipped_edge()
	_check_save_version()
	await _check_word_budget()
	_check_jump_bar()
	await _check_gift()
	_check_full_moon()
	await _check_windows()
	_check_smooth_edges()
	_check_separators()
	await _check_tools()
	_check_leaving_a_finished_level()
	await _check_mansion_finale()

	_finish()


## The reason mid-level saving exists: a player about to lose a lantern must not
## be able to swipe the app away and come back with it. So the run of wrong
## guesses has to survive a quit, and so does everything else mid-level.
func _check_saving() -> void:
	print("=== a force quit cannot undo progress ===")
	var save_path := "user://progress_test.json"
	Progress.clear(save_path)

	# Put the game in the middle of a level, three wrong guesses deep.
	var fixture := Level.load_from("res://data/levels/sample.json")
	game.show_level(fixture)
	game.submit("كتاب")
	game.submit("بكت")
	for i in 3:
		game.submit("باك")
	var hint_cell := game.grid.hint_cell()
	game.grid.reveal_cell(hint_cell)

	var before := game.capture()
	_check_equal("the streak is captured", before.wrong_streak, 3)
	_check("the save is written", before.write(save_path))

	var reloaded := Progress.read(save_path)
	_check_equal("level survives", reloaded.level_id, "sample")
	_check_equal("streak survives the quit", reloaded.wrong_streak, 3)
	_check_equal("coins survive", reloaded.coins, before.coins)
	_check_equal("lanterns survive", reloaded.lanterns, before.lanterns)
	_check_equal("found words survive", Array(reloaded.found), Array(before.found))
	_check_equal("bonus words survive", Array(reloaded.bonus_found), Array(before.bonus_found))
	_check_equal("the hinted letter survives", reloaded.revealed, before.revealed)

	# The other half: a fresh screen plus that file has to come back the same.
	game.show_level(fixture)
	_check_equal("a fresh level starts empty", game.grid.found_count(), 0)
	_check_equal("...and with no streak", game.wrong_streak, 0)
	# A new level no longer empties the moon, so move it by hand: otherwise the
	# check below would pass even if restore() never touched it.
	game.moon = 7
	game.restore(reloaded)
	_check("كتاب is found again", game.grid.is_found("كتاب"))
	_check_equal("the streak is back", game.wrong_streak, 3)
	_check_equal("the moon is back", game.moon, before.moon)
	_check("the hinted letter is back", game.grid.is_revealed_at(hint_cell))

	# Two more wrong guesses, not five: quitting did not buy a fresh run.
	var lanterns_before := game.lanterns
	for i in 2:
		game.submit("باك")
	_check_equal(
		"the streak carries on from where it stopped", game.lanterns, lanterns_before - 1
	)

	Progress.clear(save_path)
	_check("the test save is cleaned up", not FileAccess.file_exists(save_path))


## The checks above drive save and restore by hand. This one leaves the game to
## do it: play a little, throw the screen away, open a new one, and see whether
## it comes back where it was. Nothing calls save() here.
func _check_autosave() -> void:
	print("=== the game saves itself as it is played ===")
	var save_path := "user://progress_auto_test.json"
	Progress.clear(save_path)
	var scene: PackedScene = load("res://scenes/game/game.tscn")

	var first: GameScreen = scene.instantiate()
	first.level_path = "res://data/levels/sample.json"
	first.progress_path = save_path
	add_child(first)
	await get_tree().process_frame
	first.submit("كتاب")
	first.submit("باك")
	first.submit("باك")
	_check("a save appeared without being asked for", FileAccess.file_exists(save_path))
	first.queue_free()
	await get_tree().process_frame

	# A different starting level on purpose: if the save is ignored, this is the
	# level that shows, and the check below fails loudly instead of passing by luck.
	var second: GameScreen = scene.instantiate()
	second.level_path = "res://data/levels/m01-01.json"
	second.progress_path = save_path
	add_child(second)
	await get_tree().process_frame
	_check_equal("it reopens the level it left", second.level.id, "sample")
	_check("...with the word still found", second.grid.is_found("كتاب"))
	_check_equal("...and the streak still counting", second.wrong_streak, 2)
	second.queue_free()
	await get_tree().process_frame
	Progress.clear(save_path)


## The build ships a season at a time, so the year the mansion table describes
## is longer than the levels on disk. Two things have to hold at that seam.
##
## First, nothing may name a level past it. `_save_ahead()` writes whatever
## `next_level_id()` returns, and the boot path drops the entire save when it
## cannot load the level a save names — so naming «m08-01» after the last level
## of spring would send a player who finished the season back to a new game
## with no coins, no lanterns and no run.
##
## Second, a save that names a missing level has to cost the player that level
## and nothing else. It can happen without any bug: a build that ships fewer
## seasons than the one that wrote the save.
func _check_shipped_edge() -> void:
	print("=== the edge of what this build carries ===")
	var scene: PackedScene = load("res://scenes/game/game.tscn")
	var last := Mansions.level_id(Mansions.SHIPPED, GameScreen.STARS_PER_MANSION)

	var edge: GameScreen = scene.instantiate()
	edge.level_path = "res://data/levels/%s.json" % last
	edge.progress_path = ""
	add_child(edge)
	await get_tree().process_frame
	_check_equal("the last shipped level is where it should be", edge.level.id, last)
	_check_equal("nothing comes after it", edge.next_level_id(), "")
	edge.queue_free()
	await get_tree().process_frame

	var before: GameScreen = scene.instantiate()
	before.level_path = "res://data/levels/%s.json" % Mansions.level_id(
		Mansions.SHIPPED, GameScreen.STARS_PER_MANSION - 1
	)
	before.progress_path = ""
	add_child(before)
	await get_tree().process_frame
	_check_equal("...but the one before it still leads on", before.next_level_id(), last)
	before.queue_free()
	await get_tree().process_frame

	# A save pointing at a season this build does not carry.
	var save_path := "user://progress_scope_test.json"
	Progress.clear(save_path)
	var stale := Progress.new()
	stale.level_id = Mansions.level_id(Mansions.SHIPPED + 1, 1)
	stale.coins = 777
	stale.lanterns = 2
	stale.moon = 5
	stale.daily_streak = 4
	stale.found = PackedStringArray(["كتاب"])
	stale.wrong_streak = 3
	stale.write(save_path)

	var back: GameScreen = scene.instantiate()
	back.level_path = "res://data/levels/m01-01.json"
	back.progress_path = save_path
	add_child(back)
	await get_tree().process_frame
	_check("it opens on a level that is in the build", Mansions.is_shipped(back.level.mansion))
	_check_equal("...and the coins survived", back.coins, 777)
	_check_equal("...and the lanterns", back.lanterns, 2)
	_check_equal("...and the moon", back.moon, 5)
	_check_equal("...and the run of days", back.daily_streak, 4)
	# What belonged to the level that went is the only thing that goes with it.
	_check("...while the lost level's words did not follow", not back.grid.is_found("كتاب"))
	_check_equal("...nor its streak of wrong guesses", back.wrong_streak, 0)
	back.queue_free()
	await get_tree().process_frame
	Progress.clear(save_path)


## A big grid opens with one cell already filled.
##
## It is not in the save and must not be: `show_level()` always runs before
## `restore()`, so the level itself is what remembers, and a save written when
## the ramp was tuned differently cannot keep opening a cell that is no longer
## given away.
func _check_gift() -> void:
	print("=== the letter a big grid gives away ===")
	var scene: PackedScene = load("res://scenes/game/game.tscn")
	var giving: Level = null
	var plain: Level = null
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var candidate := Level.load_from(
				"res://data/levels/%s.json" % Mansions.level_id(mansion + 1, index + 1)
			)
			if candidate == null:
				continue
			if candidate.has_gift() and giving == null:
				giving = candidate
			if not candidate.has_gift() and plain == null:
				plain = candidate
	_check("some level gives a letter", giving != null)
	_check("...and the small ones do not", plain != null)
	if giving == null or plain == null:
		return
	print("      %s gives %s; %s gives none" % [giving.id, giving.gift, plain.id])
	_check("a giving level is a big one (%d words)" % giving.words.size(),
		giving.words.size() >= 10)
	_check("...and a plain one is not (%d words)" % plain.words.size(),
		plain.words.size() < 10)

	var screen: GameScreen = scene.instantiate()
	screen.level_path = "res://data/levels/%s.json" % giving.id
	screen.progress_path = ""
	add_child(screen)
	await get_tree().process_frame
	_check("the cell is open before a single word is found",
		screen.grid.is_revealed_at(giving.gift))
	_check("...and it is not the whole word", not screen.grid.is_solved())
	screen.queue_free()
	await get_tree().process_frame

	# The save is not what remembers it: a fresh screen on the same level, with
	# a save that knows nothing of the gift, still opens it.
	var save_path := "user://progress_gift_test.json"
	Progress.clear(save_path)
	var blank := Progress.new()
	blank.level_id = giving.id
	blank.write(save_path)
	var again: GameScreen = scene.instantiate()
	again.level_path = "res://data/levels/%s.json" % giving.id
	again.progress_path = save_path
	add_child(again)
	await get_tree().process_frame
	_check("a save that never heard of it still opens it",
		again.grid.is_revealed_at(giving.gift))
	again.queue_free()
	await get_tree().process_frame
	Progress.clear(save_path)


## The jump bar is a tool for watching the curve, so it has to agree with the
## curve. It reads the levels rather than keeping its own copy of the ramp, and
## this checks that what it reads is what the pipeline wrote.
func _check_jump_bar() -> void:
	print("=== jumping to where the difficulty changes ===")
	_check("the bar exists in a debug build", game._jump_label != null)
	var steps := game._difficulty_steps()
	print("      %s" % " ".join(steps))
	_check("there are several steps (%d)" % steps.size(), steps.size() >= 10)
	_check_equal("the first is the first level", steps[0], Mansions.level_id(1, 1))

	# Each step really is a change, and nothing between two steps changes.
	var wrong := PackedStringArray()
	var previous := Vector2i(-1, -1)
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var id := Mansions.level_id(mansion + 1, index + 1)
			var lv := Level.load_from("res://data/levels/%s.json" % id)
			if lv == null:
				continue
			var shape := Vector2i(lv.letters.size(), lv.words.size())
			var changed := shape != previous
			if changed != steps.has(id):
				wrong.append(id)
			previous = shape
	_check_equal("every step is a change and every change is a step", wrong.size(), 0)


## Two rules that were decided by playing, and cost nothing to get wrong quietly.
##
## The budget is per level, not a run: a correct word used to wipe the count, so
## a player who found something every few tries never paid for a wrong guess at
## all. And a real Arabic word the wheel spells, which this level happens not to
## name, is free — it is not a reward and not a mistake.
func _check_word_budget() -> void:
	print("=== the wrong-guess budget, and a real word that is not here ===")
	var scene: PackedScene = load("res://scenes/game/game.tscn")

	# A level with a `known` word to try, found rather than named.
	var subject: Level = null
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var candidate := Level.load_from(
				"res://data/levels/%s.json" % Mansions.level_id(mansion + 1, index + 1)
			)
			if candidate != null and candidate.known.size() > 0:
				subject = candidate
				break
		if subject != null:
			break
	_check("a level carries words it does not score", subject != null)
	if subject == null:
		return

	var screen: GameScreen = scene.instantiate()
	screen.level_path = "res://data/levels/%s.json" % subject.id
	screen.progress_path = ""
	add_child(screen)
	await get_tree().process_frame

	var known_word: String = subject.known[0]
	var coins_before := screen.coins
	var moon_before := screen.moon
	_check_equal("a real word that is not here is its own answer",
		screen.submit(known_word), GameScreen.Result.KNOWN)
	_check_equal("...it costs nothing", screen.wrong_streak, 0)
	_check_equal("...and earns nothing", screen.coins, coins_before)
	_check_equal("...not even a sliver of moon", screen.moon, moon_before)

	# Four wrong, then a real find, then one more wrong. Under the old rule the
	# find wiped the count and the fifth mistake was free.
	var lanterns_before := screen.lanterns
	for i in 4:
		screen.submit("ززز%d" % i)
	_check_equal("four wrong guesses are counted", screen.wrong_streak, 4)
	screen.submit(subject.words[0]["text"])
	_check_equal("...and finding a word does not wipe them", screen.wrong_streak, 4)
	screen.submit("ززززز")
	_check_equal("the fifth costs a lantern", screen.lanterns, lanterns_before - 1)
	_check_equal("...and the budget starts over", screen.wrong_streak, 0)
	screen.queue_free()
	await get_tree().process_frame


## A save written by another build has to be refused, not half-read.
##
## The levels were regenerated, so a version-1 save names ids whose puzzles have
## changed underneath it: restoring one would hand the grid words that are not
## in it. Refusing the file loses a game; reading it wrong corrupts one.
func _check_save_version() -> void:
	print("=== a save from another build ===")
	var save_path := "user://progress_version_test.json"
	Progress.clear(save_path)

	var current := Progress.new()
	current.coins = 999
	current.write(save_path)
	_check_equal("a save of this version reads back", Progress.read(save_path).coins, 999)

	# The same file, aged by one version and nothing else.
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	raw["version"] = Progress.VERSION - 1
	var handle := FileAccess.open(save_path, FileAccess.WRITE)
	handle.store_string(JSON.stringify(raw))
	handle.close()
	var stale := Progress.read(save_path)
	_check_equal("one from the build before is refused", stale.coins, Progress.new().coins)
	_check_equal("...and nothing of it leaks through", stale.level_id, "")
	Progress.clear(save_path)


## The level-complete window is a place a player can quit from, and the most
## tempting one: the reward is already paid. Whatever is saved there has to lead
## somewhere. A save holding the level just solved would reopen on a finished
## grid with no window, no button and no way on.
func _check_finish_save() -> void:
	print("=== quitting while the level-complete window is up ===")
	var save_path := "user://progress_finish_test.json"
	Progress.clear(save_path)
	var scene: PackedScene = load("res://scenes/game/game.tscn")

	var first: GameScreen = scene.instantiate()
	first.level_path = "res://data/levels/sample.json"
	first.progress_path = save_path
	add_child(first)
	await get_tree().process_frame
	# A bonus word first, so the moon is not empty when the level ends. The star
	# for it is still in the air when the save is written, which is the point:
	# `moon` moves at once and only the chip waits.
	first.submit("بكت")
	for word in ["كتاب", "كاتب", "كتب", "تاب", "بات"]:
		first.submit(word)
	_check("the level was solved", first.grid.is_solved())
	_check("the window is up", first.complete_window.visible)

	# This screen has just been built, so this is the window's FIRST layout, and
	# that is where a self-wrapping Label went wrong: with no width yet it
	# wrapped at nothing, claimed the height of twenty-seven lines, and centred
	# five words somewhere off the bottom of the panel. Checked on a screen that
	# has been laid out all run, it would have looked fine.
	var body: Label = first.complete_window.body_label
	var planned: float = float(body.text.count("\n") + 1) * SkyWindow.BODY_LINE * first._scale()
	_check(
		"its prose is the height the window planned (%0.0f <= %0.0f)"
			% [body.size.y, planned + 2.0],
		body.size.y <= planned + 2.0
	)
	var coins_at_window: int = first.coins
	# The quit: no handler runs, the screen simply stops existing.
	first.queue_free()
	await get_tree().process_frame

	var saved := Progress.read(save_path)
	_check_equal("the save points at the next level", saved.level_id, "m04-13")
	_check_equal("...holding none of the solved level", saved.found.size(), 0)
	_check_equal("...and keeping the reward", saved.coins, coins_at_window)
	_check_equal("...and carrying the moon", saved.moon, 1)

	# The other half: the game has to actually open there and be playable.
	var second: GameScreen = scene.instantiate()
	second.level_path = "res://data/levels/sample.json"
	second.progress_path = save_path
	add_child(second)
	await get_tree().process_frame
	_check_equal("it reopens on the next level", second.level.id, "m04-13")
	_check("...with a grid still to solve", not second.grid.is_solved())
	_check("...and no window in the way", not second.complete_window.visible)
	_check_equal("...and the moon where it was", second.moon, 1)
	second.queue_free()
	await get_tree().process_frame
	Progress.clear(save_path)


## Eight bonus words inside one level is out of reach, so until the moon began
## carrying across levels this payout could never fire at all. Now it can, and
## the coins have to land on the guess rather than on the star half a second
## later: submit() writes a save inside that gap.
func _check_full_moon() -> void:
	print("=== the moon fills across levels and pays out ===")
	var fixture := Level.load_from("res://data/levels/sample.json")
	game.show_level(fixture)
	game.moon = 0
	var coins_before: int = game.coins

	# Two bonus words a level, four levels. The moon does not care which level
	# they came from, which is the whole point of it carrying.
	for round_index in 4:
		game.show_level(fixture)
		_check_equal(
			"the moon survived the move to level %s" % (round_index + 1),
			game.moon, round_index * 2
		)
		game.submit("بكت")
		game.submit("كبت")

	_check_equal("the moon emptied once it filled", game.moon, 0)
	_check_equal(
		"...and paid out on the guess", game.coins, coins_before + GameScreen.MOON_REWARD
	)
	# The star is still in the air here. What is saved has to be the paid-out
	# state, or a quit in that half second loses the reward and leaves a moon
	# stuck at full, which no later bonus word could ever empty.
	var snapshot := game.capture()
	_check_equal(
		"a quit before the star lands keeps the coins",
		snapshot.coins, coins_before + GameScreen.MOON_REWARD
	)
	_check_equal("...and an empty moon, not a stuck full one", snapshot.moon, 0)


## The four windows, driven through their real buttons.
##
## The rule that matters most here is the one the player asked for: every window
## offers the way back to the main menu beside its own action. A player out of
## lanterns, facing a refill they cannot afford, must not be shut in a box.
func _check_windows() -> void:
	print("=== every window offers the way out ===")
	var windows := {
		"اكتمل المستوى": game.complete_window,
		"نفدت الفوانيس": game.lanterns_window,
		"إعادة المحاولة": game.restart_window,
	}
	for name in windows:
		var window: SkyWindow = windows[name]
		var found := false
		for shell in window.buttons():
			if (shell.get_meta("label") as Label).text == "القائمة الرئيسية":
				found = true
		_check("%s offers the main menu" % name, found)

	# A Label that wraps on its own once claimed twenty-seven lines for a caption
	# of five words and centred them off the bottom of the panel. Every number
	# in the window was right; only the drawing was wrong.
	print("=== a window's words stay inside it ===")
	for name in windows:
		var window: SkyWindow = windows[name]
		_check("%s says something" % name, window.body_label.visible)
		if not window.body_label.visible:
			continue
		var bottom: float = window.body_label.position.y + window.body_label.size.y
		_check(
			"%s: the prose fits the panel (%0.0f <= %0.0f)"
				% [name, bottom, window.panel.size.y],
			bottom <= window.panel.size.y
		)
		_check(
			"%s: ...and does not spill out the sides (%0.0f <= %0.0f)"
				% [name, window.body_label.size.x, window.panel.size.x],
			window.body_label.size.x <= window.panel.size.x
		)
		var shells := window.buttons()
		var last: GlossyPanel = shells[shells.size() - 1]
		var foot: float = last.position.y + last.size.y
		_check(
			"%s: its last button is on the panel (%0.0f <= %0.0f)"
				% [name, foot, window.panel.size.y],
			foot <= window.panel.size.y
		)

	print("=== the restart button ===")
	var fixture := Level.load_from("res://data/levels/sample.json")
	game.show_level(fixture)
	game.submit("كتاب")
	var coins_before: int = game.coins
	var lanterns_before: int = game.lanterns
	(game.restart_button.get_meta("button") as Button).pressed.emit()
	_check("it asks before it throws anything away", game.restart_window.visible)
	_check_equal("...and the level is untouched meanwhile", game.grid.found_count(), 1)
	(game.restart_confirm_button.get_meta("button") as Button).pressed.emit()
	_check_equal("confirming starts the level over", game.grid.found_count(), 0)
	# The window says the lanterns and coins are not touched. They must not be.
	_check_equal("...without costing a lantern", game.lanterns, lanterns_before)
	_check_equal("...or a coin", game.coins, coins_before)

	print("=== running out of lanterns ===")
	game.show_level(fixture)
	game.lanterns = 1
	game.coins = GameScreen.LANTERN_REFILL_COST + 300
	for i in GameScreen.WRONG_STREAK_COST:
		game.submit("باك")
	_check_equal("the last lantern went out", game.lanterns, 0)
	_check("the window opened on the guess that spent it", game.lanterns_window.visible)
	_check("a wait started", game.capture().lantern_clock > 0)

	var purse: int = game.coins
	_check("the refill went through", game.refill_lanterns())
	_check_equal(
		"...and cost its price", game.coins, purse - GameScreen.LANTERN_REFILL_COST
	)
	_check_equal("...and filled them", game.lanterns, GameScreen.LANTERNS_MAX)
	_check_equal("...and ended the wait", game.capture().lantern_clock, 0)
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.08).timeout
	_check("...and closed the window", not game.lanterns_window.visible)

	game.coins = GameScreen.LANTERN_REFILL_COST - 1
	_check("a refill you cannot afford is refused", not game.refill_lanterns())
	_check_equal("...and takes nothing", game.coins, GameScreen.LANTERN_REFILL_COST - 1)

	# The gear does not open a window here. The shell owns the one settings
	# window, so two of them can never disagree about what is stored.
	# A window you opened yourself closes when you tap the dark outside it. One
	# that is asking you something does not: a stray tap must not answer for you.
	print("=== tapping outside a window ===")
	(game.restart_button.get_meta("button") as Button).pressed.emit()
	game.restart_window.settle()
	_check("the restart window is up", game.restart_window.visible)
	_tap_outside(game.restart_window)
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.08).timeout
	_check("a tap outside cancels it", not game.restart_window.visible)

	game.show_level(fixture)
	game.lanterns = 1
	for i in GameScreen.WRONG_STREAK_COST:
		game.submit("باك")
	game.lanterns_window.settle()
	_check("the out-of-lanterns window is up", game.lanterns_window.visible)
	_tap_outside(game.lanterns_window)
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.08).timeout
	_check("...and a tap outside will not dismiss it", game.lanterns_window.visible)
	game.lanterns_window.visible = false
	game.lanterns = GameScreen.LANTERNS_MAX

	print("=== the gear asks the shell ===")
	var asked_settings := [false]
	game.settings_requested.connect(func() -> void: asked_settings[0] = true)
	(game.settings_button.get_meta("button") as Button).pressed.emit()
	_check("the gear asks for settings", asked_settings[0])

	print("=== the main menu button ===")
	var asked := [false]
	game.menu_requested.connect(func() -> void: asked[0] = true)
	game.restart_window.settle()
	var menu: GlossyPanel = null
	for shell in game.restart_window.buttons():
		if (shell.get_meta("label") as Label).text == "القائمة الرئيسية":
			menu = shell
	(menu.get_meta("button") as Button).pressed.emit()
	_check("pressing it asks for the menu", asked[0])
	_check("...and takes the window away", not game.restart_window.visible)


## Godot's drawing calls take antialiasing as an argument and it defaults to
## off. Sixteen of them defaulted their way into a sky full of jagged stars, and
## nothing on screen looked wrong in a way any other check could see: the shapes
## were in the right places, with the right colours, and chewed at the edges.
func _check_smooth_edges() -> void:
	print("=== hand-drawn shapes ask for smooth edges ===")
	var calls := ["draw_circle(", "draw_polyline(", "draw_arc(", "draw_line("]
	var rough := PackedStringArray()
	for path in _scripts_under("res://scenes"):
		var text := FileAccess.get_file_as_string(path)
		var line_number := 0
		# A call wrapped over several lines is still one call: gather it until
		# its brackets balance, or a smoothed one reads as a rough one.
		var gathered := ""
		var began := 0
		for line in text.split("\n"):
			line_number += 1
			var trimmed := line.strip_edges()
			if gathered.is_empty():
				var starts := false
				for call in calls:
					if trimmed.begins_with(call):
						starts = true
				if not starts:
					continue
				gathered = trimmed
				began = line_number
			else:
				gathered += trimmed
			if gathered.count("(") > gathered.count(")"):
				continue
			if not gathered.ends_with("true)"):
				rough.append("%s:%s" % [path.get_file(), began])
			gathered = ""
	_check(
		"nothing is drawn with hard edges (%s)"
			% ("none" if rough.is_empty() else ", ".join(rough)),
		rough.is_empty()
	)


## The middle dot must not touch a number anywhere a player can read it.
##
## It had slipped into five strings at once, and no grep could see them: every
## one is built by `%` at runtime, so the dot and the digit only meet on the
## screen. This reads the screens instead.
func _check_separators() -> void:
	print("=== no dot beside a number ===")
	var bad := PackedStringArray()
	for node in _every_node(self):
		for text in _readable(node):
			var hit := Arabic.dot_beside_digit(text)
			if not hit.is_empty():
				bad.append("%s «%s»" % [node.name, hit])
	_check(
		"no dot lands beside a digit (%s)"
			% ("none" if bad.is_empty() else ", ".join(bad)),
		bad.is_empty()
	)


func _every_node(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_every_node(child))
	return out


## Everything on a node that a player ends up reading.
func _readable(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	if node is Control:
		out.append((node as Control).tooltip_text)
	return out


func _scripts_under(root: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_scripts_under(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## A click on the dim layer, well clear of the panel and of the crest that
## straddles its top edge.
func _tap_outside(window: SkyPopup) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(window.size.x * 0.5, window.size.y - 8.0)
	window._gui_input(click)


## The four tools, each driven the way a finger would drive it.
func _check_tools() -> void:
	print("=== the observer's four tools ===")
	var fixture := Level.load_from("res://data/levels/sample.json")

	game.show_level(fixture)
	game.coins = 1000
	var before: int = game.grid.revealed_count()
	game.use_tool(Tools.Kind.ASTROLABE)
	# Five words, none found, so five first letters. Two of them share a cell,
	# so what matters is that it opened several and not one.
	_check(
		"the astrolabe opens a letter in every word (%s -> %s)"
			% [before, game.grid.revealed_count()],
		game.grid.revealed_count() >= before + 4
	)

	game.show_level(fixture)
	_check_equal("a fresh level closes them again", game.grid.revealed_count(), 0)
	game.use_tool(Tools.Kind.WORD)
	_check_equal("the word tool finds a whole word", game.grid.found_count(), 1)

	game.show_level(fixture)
	game.use_tool(Tools.Kind.CHART)
	_check("the chart waits for a cell", game.grid.picking)
	# Through the grid's own input, not the signal: what disarms the chart is
	# the tap landing on a cell, and emitting the signal would skip that.
	var cell: Vector2i = fixture.cells().keys()[0]
	var rect := game.grid.cell_rect(cell)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.position + rect.size * 0.5
	game.grid._gui_input(click)
	_check("...and opens the one chosen", game.grid.is_revealed_at(cell))
	_check("...then stops waiting", not game.grid.picking)
	# A chart left armed must not survive into a level it was not bought for.
	game.use_tool(Tools.Kind.CHART)
	game.show_level(fixture)
	_check("a new level disarms it", not game.grid.picking)

	print("=== paying for a tool ===")
	game.show_level(fixture)
	game.coins = Tools.PRICES[Tools.Kind.WORD] - 1
	game.tools = [0, 0, 0, 0]
	var purse: int = game.coins
	game._on_tool_chosen(Tools.Kind.WORD)
	_check_equal("a tool you cannot afford takes nothing", game.coins, purse)
	_check_equal("...and does nothing", game.grid.found_count(), 0)

	# One bought ahead from the shop is spent before any coin is.
	game.tools[Tools.Kind.WORD] = 1
	game._on_tool_chosen(Tools.Kind.WORD)
	_check_equal("one owned is spent first", game.tools[Tools.Kind.WORD], 0)
	_check_equal("...leaving the coins alone", game.coins, purse)
	_check_equal("...and still doing its work", game.grid.found_count(), 1)

	var snapshot := game.capture()
	_check_equal("the shelf is saved", snapshot.tools.size(), Tools.COUNT)
	game.tools[Tools.Kind.SPYGLASS] = 3
	snapshot = game.capture()
	game.tools = [0, 0, 0, 0]
	game.restore(snapshot)
	_check_equal("...and comes back", game.tools[Tools.Kind.SPYGLASS], 3)


## Reported from play: finish a level, choose the map instead of "next", then
## press carry on, and the same solved level comes back.
##
## Pressing "next" advances; leaving by any other door did not, so the screen
## still held the level just solved and the map still pointed at it.
func _check_leaving_a_finished_level() -> void:
	print("=== leaving a finished level by the other door ===")
	var fixture := Level.load_from("res://data/levels/sample.json")
	game.show_level(fixture)
	for word in ["كتاب", "كاتب", "كتب", "تاب", "بات"]:
		game.submit(word)
	_check("the level is solved", game.grid.is_solved())
	_check("the window is up", game.complete_window.visible)

	game._on_menu_pressed()
	_check_equal("leaving it moves on to the next level", game.level.id, "m04-13")
	_check("...which has still to be played", not game.grid.is_solved())
	_check("...and no window is in the way", not game.complete_window.visible)


## The twentieth star of a mansion, which the game is arranged around.
func _check_mansion_finale() -> void:
	print("=== the twentieth star ===")
	var last := Level.load_from("res://data/levels/m04-20.json")
	_check("the last level of a mansion loads", last != null)
	if last == null:
		return
	_check_equal("it is the twentieth", last.index_in_mansion, GameScreen.STARS_PER_MANSION)

	# The save is watched through this whole block: the ceremony sits after
	# `_save_ahead()`, so a write from inside it would put the player back on
	# the solved grid with nothing to press.
	var ahead := "user://progress_anwa_test.json"
	Progress.clear(ahead)
	var was_path: String = game.progress_path
	game.progress_path = ahead

	game.show_level(last)
	var purse: int = game.coins
	var guard := 0
	while not game.grid.is_solved() and guard < 20:
		game.use_tool(Tools.Kind.WORD)
		guard += 1
	_check("it was solved", game.grid.is_solved())
	_check_equal(
		"a finished mansion pays more than a level",
		game.coins, purse + GameScreen.LEVEL_REWARD + GameScreen.MANSION_REWARD
	)
	_check("...and the usual window stays away", not game.complete_window.visible)

	print("=== the rhyme comes before the sky draws ===")
	_check("the ceremony opened instead", game.in_anwa)
	_check("...with the rhyme showing", game.anwa.visible)
	_check("...and the grid gone", not game.grid.visible)
	_check("...and the finale waiting", not game.finale.visible)
	var name := Arabic.normalise(Mansions.name_of(4))
	_check_equal("the wheel carries the name, letter for letter",
		game.wheel.letter_count(), name.length())
	var on_wheel: Array = Array(game.wheel.letters())
	on_wheel.sort()
	var wanted: Array = []
	for i in name.length():
		wanted.append(name[i])
	wanted.sort()
	_check_equal("...the same letters, ألف twice over", on_wheel, wanted)
	_check_equal("the save already points past the mansion",
		Progress.read(ahead).level_id, "m05-01")

	var lamps: int = game.lanterns
	game.submit("الدبر")
	_check_equal("a wrong name costs no lantern", game.lanterns, lamps)
	_check("...and the ceremony stays up", game.in_anwa)
	_check_equal("...and writes nothing over the save ahead",
		Progress.read(ahead).level_id, "m05-01")

	# The hint opens a letter here rather than selling one.
	var coins_before: int = game.coins
	game.anwa.reveal_next()
	_check_equal("a hint opens the first letter", game.anwa.shown, 1)
	_check_equal("...and costs nothing", game.coins, coins_before)

	game.submit(Mansions.name_of(4))
	_check("the name is written", game.anwa.locked)
	await get_tree().create_timer(GameScreen.ANWA_HOLD + 0.2).timeout
	# The moment replaces the usual window rather than coming after it: two
	# windows in a row on the same screen would kill it.
	_check("the finale runs after it", game.finale.visible)
	_check("...and the rhyme is gone", not game.in_anwa)
	Progress.clear(ahead)
	game.progress_path = was_path

	game.finale.settle(last.mansion)
	game._show_mansion_card()
	game.mansion_window.settle()
	_check("the card opens after it", game.mansion_window.visible)
	_check_equal("...naming the mansion", game._mansion_name.text, Mansions.name_of(4))
	_check("...and what the name means",
		game._mansion_line.meaning_text() == Mansions.meaning_of(4))

	var asked := [false]
	game.cards_requested.connect(func() -> void: asked[0] = true)
	for shell in game.mansion_window.buttons():
		if (shell.get_meta("label") as Label).text == "بطاقات النجوم":
			(shell.get_meta("button") as Button).pressed.emit()
	_check("it offers the collection", asked[0])

	print("=== the name gathers out of stardust ===")
	var name_view := game.finale.name_view
	name_view.setup(Mansions.name_of(4), 100)
	name_view.progress = 0.0
	_check_equal("nothing shows at the start", name_view.label.visible_characters, 0)
	name_view.progress = 0.5
	_check(
		"half way, half the letters (%s of %s)"
			% [name_view.label.visible_characters, name_view.label.text.length()],
		name_view.label.visible_characters > 0
			and name_view.label.visible_characters < name_view.label.text.length()
	)
	# The layout used to call setup(), and setup() used to reset the gathering,
	# so a resize in the middle of forming put the name back to dust.
	game.finale.relayout()
	_check_equal("a resize does not put it back to dust", name_view.progress, 0.5)
	name_view.progress = 1.0
	_check_equal(
		"at the end every letter is there",
		name_view.label.visible_characters, name_view.label.text.length()
	)
	# Revealed after shaping, so the glyphs do not change form as they arrive.
	_check_equal(
		"the letters are revealed after shaping",
		name_view.label.visible_characters_behavior, TextServer.VC_CHARS_AFTER_SHAPING
	)


func _drag_wheel(indices: Array) -> void:
	# Pushed as one burst, with no frame waits in between. Waiting would let a
	# real mouse event from the machine running the test slip in and end the
	# drag early, which made this check flaky.
	var wheel := game.wheel
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = wheel.global_position + wheel.tile_centre(indices[0])
	get_viewport().push_input(press, true)

	for i in range(1, indices.size()):
		var move := InputEventMouseMotion.new()
		move.position = wheel.global_position + wheel.tile_centre(indices[i])
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(move, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = wheel.global_position + wheel.tile_centre(indices[indices.size() - 1])
	get_viewport().push_input(release, true)
	await get_tree().process_frame


## The window that ends a level, and the move to the next one.
func _check_level_complete() -> void:
	print("=== the level-complete window ===")
	_check("the window opened when the grid was solved", game.complete_window.visible)
	game.complete_window.settle()
	await _save_shot("level_complete")

	var before := game.level.id
	(game.next_button.get_meta("button") as Button).pressed.emit()
	_check_equal("the level has not changed yet", game.level.id, before)
	# The wipe swaps the content as it crosses the middle.
	await get_tree().create_timer(MeteorWipe.DURATION + 0.15).timeout
	_check_equal("it moved on to the next level", game.level.id, "m04-13")
	_check("the window is gone", not game.complete_window.visible)
	_check_equal("the new level starts empty", game.grid.found_count(), 0)
	# The moon is the player's, not the level's. Emptying it here would mean it
	# never fills: a level yields two bonus words at its thinnest, and the moon
	# wants eight.
	_check_equal("the moon carries into the next level", game.moon, 1)


func _save_shot(name: String) -> void:
	var image := await _grab()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	image.save_png(ProjectSettings.globalize_path("res://tools/out/%s.png" % name))
	print("  shot -> tools/out/%s.png" % name)


func _grab() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


## A still frame cannot show an animation. Two frames half a second apart can:
## if the sky is twinkling, pixels in the star margin will have moved.
func _check_sky_twinkles() -> void:
	print("=== the sky twinkles ===")
	var before := await _grab()
	await get_tree().create_timer(0.5).timeout
	var after := await _grab()

	var to_pixels := float(before.get_width()) / game.size.x
	# The left margin, where the stars sit and nothing is drawn over them.
	var strip := Rect2i(
		2, int(200.0 * to_pixels),
		int(280.0 * to_pixels), int(1300.0 * to_pixels)
	)
	var a := before.get_region(strip)
	var b := after.get_region(strip)
	var moved := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var pixel_a := a.get_pixel(x, y)
			var pixel_b := b.get_pixel(x, y)
			if absf(pixel_a.get_luminance() - pixel_b.get_luminance()) > 0.004:
				moved += 1
	_check("the sky changes between frames (%s pixels moved)" % moved, moved > 20)


func _screenshot() -> void:
	var image := await _grab()
	var out_dir := ProjectSettings.globalize_path("res://tools/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err := image.save_png(ProjectSettings.globalize_path(SHOT_PATH))
	print("  screenshot -> %s (%s)" % [SHOT_PATH, error_string(err)])
	_check_cells_drawn(image)


## Reads the rendered frame back. Layout maths can be right while nothing is
## actually painted, and an empty cell that matches the sky is invisible to a
## player even though every other check passes.
func _check_cells_drawn(image: Image) -> void:
	print("=== every cell is actually painted ===")
	# The window is smaller than the viewport, so the captured frame is scaled.
	var to_pixels := Vector2(image.get_width(), image.get_height()) / game.size
	var cells := game.level.cells()
	var missing := 0
	var invisible := 0
	for cell in cells:
		var rect: Rect2 = game.grid.cell_rect(cell)
		var centre: Vector2 = game.grid.position + rect.position + rect.size * 0.5
		var revealed: bool = game.grid.is_revealed_at(cell)
		# The faces are gradients now, so check brightness rather than an exact
		# colour: a found tile is cream, an empty well is darker than the sky.
		var sky := image.get_pixelv(
			Vector2i(Vector2(game.grid.position.x - 24.0, centre.y) * to_pixels)
		)
		# Three points away from the glyph; any one of them proves the fill.
		var probes: Array[Vector2] = [
			centre + Vector2(0.0, -rect.size.y * 0.34),
			centre + Vector2(rect.size.x * 0.3, 0.0),
			centre + Vector2(-rect.size.x * 0.3, 0.0),
		]
		var painted := false
		var readable := false
		for probe in probes:
			var got := image.get_pixelv(Vector2i(probe * to_pixels))
			var lit := got.get_luminance()
			if revealed and lit > 0.6:
				painted = true
				readable = true
				break
			if not revealed and lit < sky.get_luminance():
				painted = true
				if sky.get_luminance() - lit > 0.01:
					readable = true
				break
		if not painted:
			missing += 1
			print("    cell %s (%s) not painted" % [cell, "tile" if revealed else "well"])
		if not readable:
			invisible += 1
	_check_equal("all %s cells painted" % cells.size(), missing, 0)
	_check_equal("every cell reads against the sky", invisible, 0)

	# A spent lantern has to look spent. Both icons are the same silhouette, so
	# only the pixels can tell whether the lit and unlit art actually differ.
	var lit_icon := game.lantern_icon(0)
	var spent_icon := game.lantern_icon(GameScreen.LANTERNS_MAX - 1)
	if lit_icon != null and spent_icon != null:
		var lit_sample := image.get_pixelv(
			Vector2i((lit_icon.global_position + lit_icon.size * 0.5) * to_pixels)
		)
		var spent_sample := image.get_pixelv(
			Vector2i((spent_icon.global_position + spent_icon.size * 0.5) * to_pixels)
		)
		var difference: float = lit_sample.get_luminance() - spent_sample.get_luminance()
		_check(
			"a lit lantern is brighter than a spent one (by %0.3f)" % difference,
			difference > 0.05
		)


func _finish() -> void:
	_done = true
	print("=== %s checks, %s failed ===" % [_checks, _failures.size()])
	for failure in _failures:
		print("  FAILED: %s" % failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)

## The frame cap is the test's own, not the command line's.
##
## `--quit-after N` quits with code 0, so a run cut short by it reads as a
## passing one, and a failure it never reached is never printed. This counts the
## frames itself and quits 2 with a sentence saying what happened. Run the scene
## without `--quit-after`, or with a larger one as an outer backstop.
const FRAME_BUDGET := 4000

var _frames: int = 0


func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _frames < FRAME_BUDGET:
		return
	_done = true
	print("")
	print("=== CUT SHORT after %d checks and %d frames ===" % [_checks, _frames])
	print("    the run never reached its end: raise FRAME_BUDGET or find the hang")
	get_tree().quit(2)
