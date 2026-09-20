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
	# Eleven already lit, plus one per word found and one for the hinted letter.
	_check_equal("stars lit", game.stars.lit, level.index_in_mansion - 1 + 6)

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

	_finish()


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
