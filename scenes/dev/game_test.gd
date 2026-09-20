extends Control
## Drives the playable slice and checks it, then saves a screenshot.
##
##   godot --path . --quit-after 600 res://scenes/dev/game_test.tscn
##
## Exits 0 when every check passes, 1 otherwise, so it can gate a commit.
## Writes tools/out/game_slice.png for looking at.

const SHOT_PATH := "res://tools/out/game_slice.png"

var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0

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
	_check("preview clears the grid (%s <= %s)" % [grid_bottom, game.preview.position.y], grid_bottom <= game.preview.position.y)
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
	_check_equal("hint charges its cost", game.coins, coins_before - GameScreen.HINT_COST)
	_check_equal("hint opens one letter", game.grid.revealed_count(), revealed_before + 1)
	_check_equal("hint does not finish a word", game.grid.found_count(), 1)

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

	# Generated grids run from four columns to eleven. The fixture is six, so on
	# its own it would never catch a layout that cannot shrink.
	print("=== the widest level in the game still fits ===")
	var widest := Level.load_from("res://data/levels/m27-12.json")
	_check("the widest level loads", widest != null)
	if widest != null:
		_check_equal("it is the eleven-column one", widest.cols, 11)
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
		# Seven letters on the wheel at the four-letter tile size overlap.
		_check_equal("its wheel holds seven letters", game.wheel.letter_count(), 7)
		var spacing: float = 2.0 * game.wheel.orbit_radius * sin(PI / 7.0)
		var drawn: float = game.wheel.effective_tile_radius() * 2.0
		_check("its tiles keep clear (%0.1f <= %0.1f)" % [drawn, spacing], drawn <= spacing)

	_check_saving()
	await _check_autosave()
	await _check_finish_save()
	_check_full_moon()

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
	_check("the window is up", first.popup.visible)
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
	_check("...and no window in the way", not second.popup.visible)
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
	_check("the window opened when the grid was solved", game.popup.visible)
	game.popup.settle()
	await _save_shot("level_complete")

	var before := game.level.id
	(game.next_button.get_meta("button") as Button).pressed.emit()
	_check_equal("the level has not changed yet", game.level.id, before)
	# The wipe swaps the content as it crosses the middle.
	await get_tree().create_timer(MeteorWipe.DURATION + 0.15).timeout
	_check_equal("it moved on to the next level", game.level.id, "m04-13")
	_check("the window is gone", not game.popup.visible)
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
	print("=== %s checks, %s failed ===" % [_checks, _failures.size()])
	for failure in _failures:
		print("  FAILED: %s" % failure)
	get_tree().quit(1 if _failures.size() > 0 else 0)
