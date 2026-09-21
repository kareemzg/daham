extends Control
## Drives the way in and checks it.
##
##   godot --path . --quit-after 900 res://scenes/dev/shell_test.tscn
##
## Exits 0 when every check passes, 1 otherwise, so it can gate a commit.

const SAVE := "user://shell_test_progress.json"
const SETTINGS := "user://shell_test_settings.json"

var shell: Shell
var _failures: PackedStringArray = PackedStringArray()
var _checks: int = 0


func _ready() -> void:
	OS.low_processor_usage_mode = false
	Progress.clear(SAVE)
	GameSettings.clear(SETTINGS)
	var saved := Progress.new()
	saved.level_id = "m04-12"
	saved.coins = 525
	saved.lanterns = 3
	saved.moon = 4
	saved.write(SAVE)

	shell = Shell.new()
	shell.progress_path = SAVE
	shell.settings_path = SETTINGS
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func _check(label: String, condition: bool) -> void:
	_checks += 1
	if condition:
		print("  ok    %s" % label)
	else:
		_failures.append(label)
		print("  FAIL  %s" % label)


func _check_equal(label: String, actual: Variant, expected: Variant) -> void:
	_check("%s (got %s, want %s)" % [label, actual, expected], actual == expected)


func _press(panel: GlossyPanel) -> void:
	(panel.get_meta("button") as Button).pressed.emit()


func _arrive() -> void:
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout


## A click on the dim layer, clear of the panel and of the crest above it.
func _tap_outside(window: SkyPopup) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(window.size.x * 0.5, window.size.y - 8.0)
	window._gui_input(click)


func _run() -> void:
	print("=== the mansion table ===")
	_check_equal("twenty-eight mansions", Mansions.NAMES.size(), Mansions.COUNT)
	_check_equal("the fourth is الدبران", Mansions.name_of(4), "الدبران")
	_check_equal("it is a spring mansion", Mansions.season_of(4), 0)
	_check_equal("the eighth starts summer", Mansions.season_of(8), 1)
	_check_equal("the last is winter", Mansions.season_of(28), 3)
	_check_equal("a season holds seven", Mansions.of_season(2).size(), 7)
	_check_equal("autumn starts at fifteen", Mansions.of_season(2)[0], 15)
	_check_equal("an id splits back", Mansions.parse("m04-12"), Vector2i(4, 12))
	# The hand-made fixture sits outside the generated range on purpose.
	_check_equal("the fixture is not a place", Mansions.parse("sample"), Vector2i.ZERO)
	_check_equal("nor is a mansion past the year", Mansions.parse("m99-01"), Vector2i.ZERO)

	print("=== it opens on the title, where the save left off ===")
	_check_equal("the title is showing", shell.showing, Shell.Screen.TITLE)
	_check("the map is not", not shell.map.visible)
	_check("the game is not", not shell.game.visible)
	_check_equal("the game reopened the saved level", shell.game.level.id, "m04-12")

	print("=== the title goes to the map, under a meteor ===")
	_press(shell.title.map_button)
	_check_equal("the screen has not changed yet", shell.showing, Shell.Screen.TITLE)
	await _arrive()
	_check_equal("it arrived at the map", shell.showing, Shell.Screen.MAP)
	_check("the map is showing", shell.map.visible)
	_check("the title is gone", not shell.title.visible)

	print("=== the map knows where the player is ===")
	_check_equal("on the fourth mansion", shell.map.current_mansion, 4)
	_check_equal("at its twelfth star", shell.map.current_index, 12)
	_check_equal("showing spring", shell.map.season_shown, 0)
	_check_equal("its coins came across", shell.map.hud.coins, 525)
	_check_equal("its lanterns too", shell.map.hud.lanterns, 3)
	# Everything before the current mansion is finished, and nothing after.
	_check_equal("the third is finished", shell.map.stars_of(3), 20)
	_check_equal("the fourth is part way", shell.map.stars_of(4), 11)
	_check_equal("the fifth is untouched", shell.map.stars_of(5), 0)

	print("=== the seasons turn ===")
	shell.map.show_season(1)
	_check_equal("summer is showing", shell.map.season_shown, 1)
	_check("there is a way back", shell.map._back_button.visible)
	shell.map.show_season(0)
	_check_equal("spring again", shell.map.season_shown, 0)
	# Spring is the first season; offering a way further back would be a lie.
	_check("no way back from the first", not shell.map._back_button.visible)

	print("=== a finished mansion opens its card ===")
	shell.map.mansion_opened.emit(3)
	shell.mansion_window.settle()
	_check("the card is up", shell.mansion_window.visible)
	_check_equal("it is the third mansion", shell.mansion_window.title_label.text, "الثريا")
	_check("it names the season", shell.mansion_window.body_label.text.contains("الربيع"))
	var bottom: float = (
		shell.mansion_window.body_label.position.y + shell.mansion_window.body_label.size.y
	)
	_check(
		"its prose fits the panel (%0.0f <= %0.0f)" % [bottom, shell.mansion_window.panel.size.y],
		bottom <= shell.mansion_window.panel.size.y
	)
	shell.mansion_window.visible = false

	print("=== the one settings window ===")
	_press(shell.map.settings_button)
	shell.settings_window.settle()
	_check("settings opened from the map", shell.settings_window.visible)
	_check_equal("music starts on", shell.settings.music, true)
	shell.settings_window.rows[1].button.pressed.emit()
	_check_equal("the switch turned it off", shell.settings.music, false)
	_check_equal("...and wrote it down", GameSettings.read(SETTINGS).music, false)
	_check_equal("...leaving sound alone", GameSettings.read(SETTINGS).sound, true)

	# The play screen's gear opens this same window, so the two can never
	# disagree about what is stored.
	shell.settings_window.visible = false
	shell.game.settings_requested.emit()
	shell.settings_window.settle()
	_check("the play screen's gear opens it too", shell.settings_window.visible)
	_check_equal("...showing what was just stored", shell.settings_window.rows[1].on, false)
	shell.settings_window.visible = false

	# Both of these are windows the player opened and can simply leave.
	print("=== the mansion card says what the name means ===")
	shell.open_mansion(3)
	shell.mansion_window.settle()
	_check_equal("it is الثريا", shell.mansion_window.title_label.text, "الثريا")
	_check_equal(
		"...with what the name means",
		(shell._star_line.get_meta("meaning") as Label).text, Mansions.meaning_of(3)
	)
	_check_equal(
		"...and the modern name of its brightest star",
		(shell._star_line.get_meta("latin") as Label).text, "Pleiades"
	)
	_check_equal("...and its figure", shell._figure.shape.size(), Mansions.shape_of(3).size())
	# البلدة is named for being empty of bright stars, so it has no Latin name
	# and the line must disappear rather than sit there blank.
	shell.open_mansion(21)
	_check("البلدة hides the Latin line", not (shell._star_line.get_meta("latin") as Label).visible)
	shell.mansion_window.visible = false

	print("=== the collection ===")
	shell.go_to(Shell.Screen.CARDS)
	await _arrive()
	_check_equal("the map opens the collection", shell.showing, Shell.Screen.CARDS)
	_check_equal("one line per mansion", shell.cards.rows.size(), Mansions.COUNT)
	# The player is on the fourth mansion's twelfth star.
	_check_equal("the third is a card", shell.cards.rows[2].state, CardRow.State.DONE)
	_check_equal("the fourth is being played", shell.cards.rows[3].state, CardRow.State.NOW)
	_check_equal("the fifth is not reached", shell.cards.rows[4].state, CardRow.State.LOCKED)
	# Learning the name is the reward for finishing, so nothing may leak it.
	_check(
		"a mansion not reached keeps its name back",
		not shell.cards.rows[4]._name.text.contains(Mansions.name_of(5))
	)
	_check("...and a card that is earned shows it",
		shell.cards.rows[2]._name.text == Mansions.name_of(3))
	_check("only an earned card can be opened", shell.cards.rows[4]._button.disabled)
	_check("...and an earned one can", not shell.cards.rows[2]._button.disabled)

	shell.cards.rows[2].pressed.emit()
	shell.mansion_window.settle()
	_check("tapping a card opens it", shell.mansion_window.visible)
	_check_equal("...on that mansion", shell.mansion_window.title_label.text, Mansions.name_of(3))
	shell.mansion_window.visible = false

	_press(shell.cards.back_button)
	await _arrive()
	_check_equal("the way back lands on the map", shell.showing, Shell.Screen.MAP)

	print("=== the shop ===")
	shell.game.coins = 500
	shell.game.tools = [0, 0, 0, 0]
	shell.open_shop()
	shell.shop_window.settle()
	_check("the shop opened", shell.shop_window.visible)
	shell.shop_window.rows[1].pressed.emit()
	_check_equal("three spyglasses arrive", shell.game.tools[Tools.Kind.SPYGLASS], 3)
	_check_equal("...and cost their price", shell.game.coins, 380)

	shell.game.lanterns = 1
	shell.shop_window.rows[0].pressed.emit()
	_check_equal("the refill fills them", shell.game.lanterns, GameScreen.LANTERNS_MAX)
	_check_equal("...and costs its price", shell.game.coins, 280)

	shell.game.coins = 10
	shell.shop_window.show_purse(shell.game.coins)
	var owned: int = shell.game.tools[Tools.Kind.ASTROLABE]
	shell.shop_window.rows[2].pressed.emit()
	_check_equal("what you cannot afford takes nothing", shell.game.coins, 10)
	_check_equal("...and gives nothing", shell.game.tools[Tools.Kind.ASTROLABE], owned)
	# The line stays on screen greyed: hiding it would teach the player nothing.
	_check("...but the line is still shown", not shell.shop_window.rows[2].affordable)
	shell.shop_window.visible = false

	print("=== tapping outside a window closes it ===")
	shell.map.mansion_opened.emit(3)
	shell.mansion_window.settle()
	_check("the mansion card is up", shell.mansion_window.visible)
	_tap_outside(shell.mansion_window)
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.08).timeout
	_check("a tap outside closes it", not shell.mansion_window.visible)

	_press(shell.map.settings_button)
	shell.settings_window.settle()
	_check("settings is up", shell.settings_window.visible)
	_tap_outside(shell.settings_window)
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.08).timeout
	_check("...and a tap outside closes that too", not shell.settings_window.visible)

	print("=== the map goes to the game, and the game comes back ===")
	_press(shell.map.play_button)
	await _arrive()
	_check_equal("it arrived at the game", shell.showing, Shell.Screen.GAME)
	_check("the game is showing", shell.game.visible)
	# The shell draws the sky, so the screen on it must not draw a second one.
	_check("the game draws no sky of its own", not shell.game.draws_sky)

	shell.game.menu_requested.emit()
	await _arrive()
	_check_equal("the way out lands on the map", shell.showing, Shell.Screen.MAP)

	# The whole of the reported fault, end to end: finish a level, take the map
	# instead of "next", then carry on. It used to reopen the level just solved.
	print("=== finish a level, go to the map, then carry on ===")
	shell.go_to(Shell.Screen.GAME)
	await _arrive()
	shell.game.show_level(Level.load_from("res://data/levels/sample.json"))
	for word in ["كتاب", "كاتب", "كتب", "تاب", "بات"]:
		shell.game.submit(word)
	_check("the level is finished", shell.game.complete_window.visible)

	var menu: GlossyPanel = null
	for panel in shell.game.complete_window.buttons():
		if (panel.get_meta("label") as Label).text == "القائمة الرئيسية":
			menu = panel
	_check("the window offers the map", menu != null)
	(menu.get_meta("button") as Button).pressed.emit()
	await _arrive()
	_check_equal("it lands on the map", shell.showing, Shell.Screen.MAP)
	_check_equal("the map has moved on", shell.map.current_index, 13)

	_press(shell.map.play_button)
	await _arrive()
	_check_equal("carrying on opens the next level", shell.game.level.id, "m04-13")
	_check("...which has still to be played", not shell.game.grid.is_solved())

	print("=== when a run of days stands, and when it does not ===")
	var day := Daily.today()
	_check_equal("a run never started is dark", Daily.lit(0, 0, day), 0)
	_check_equal("one played today stands", Daily.lit(4, day, day), 4)
	_check_equal("one played yesterday stands", Daily.lit(4, day - 1, day), 4)
	# A day missed is the whole rule of a streak, and the window says so.
	_check_equal("a day missed puts it out", Daily.lit(4, day - 2, day), 0)
	_check_equal("finishing adds one", Daily.advanced(4, day - 1, day), 5)
	_check_equal("the seventh begins a new week", Daily.advanced(7, day - 1, day), 1)
	_check_equal("a broken run starts again at one", Daily.advanced(5, day - 9, day), 1)
	_check_equal(
		"the same day gives the same level", Daily.level_for(day), Daily.level_for(day)
	)
	_check(
		"...a different day a different one",
		Daily.level_for(day) != Daily.level_for(day + 1)
	)
	_check("...and it is a level that exists", shell.game.level_by_id(Daily.level_for(day)) != null)

	print("=== playing the day's challenge ===")
	var journey: String = shell.game.level.id
	shell.game.daily_streak = 0
	shell.game.daily_day = 0
	shell.game.lanterns = 3
	shell.open_daily()
	shell.daily_window.settle()
	_check("the map opens it", shell.daily_window.visible)

	_check("the challenge starts", shell.start_daily())
	await _arrive()
	_check("the screen is on the challenge", shell.game.daily)
	_check_equal("...and showing the game", shell.showing, Shell.Screen.GAME)

	# The window promises this in so many words, so it has to hold.
	var lanterns_before: int = shell.game.lanterns
	shell.game.show_level(Level.load_from("res://data/levels/sample.json"))
	for i in GameScreen.WRONG_STREAK_COST:
		shell.game.submit("باك")
	_check_equal("five wrong guesses cost no lantern", shell.game.lanterns, lanterns_before)

	var purse: int = shell.game.coins
	for word in ["كتاب", "كاتب", "كتب", "تاب", "بات"]:
		shell.game.submit(word)
	await _arrive()
	_check_equal("finishing lights the first star", shell.game.daily_streak, 1)
	_check_equal("...and pays the day", shell.game.coins, purse + Daily.DAY_REWARD)
	_check("...and leaves the challenge behind", not shell.game.daily)
	_check_equal("...and puts the journey back", shell.game.level.id, journey)
	shell.daily_window.visible = false

	print("=== the seventh day ===")
	shell.game.daily_streak = 6
	shell.game.daily_day = day - 1
	shell.game.lanterns = 2
	purse = shell.game.coins
	_check("it starts again", shell.start_daily())
	await _arrive()
	shell.game.show_level(Level.load_from("res://data/levels/sample.json"))
	for word in ["كتاب", "كاتب", "كتب", "تاب", "بات"]:
		shell.game.submit(word)
	await _arrive()
	_check_equal("the week closes", shell.game.daily_streak, Daily.STREAK_LENGTH)
	_check_equal(
		"...and pays the week on top of the day",
		shell.game.coins, purse + Daily.DAY_REWARD + Daily.WEEK_REWARD
	)
	_check_equal("...and returns a lantern", shell.game.lanterns, 3)
	shell.daily_window.visible = false

	_finish()


func _finish() -> void:
	Progress.clear(SAVE)
	GameSettings.clear(SETTINGS)
	print("")
	if _failures.is_empty():
		print("=== %d checks, 0 failed ===" % _checks)
		get_tree().quit(0)
		return
	print("=== %d checks, %d failed ===" % [_checks, _failures.size()])
	for failure in _failures:
		print("  FAILED: %s" % failure)
	get_tree().quit(1)
