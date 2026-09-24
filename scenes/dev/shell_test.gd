extends Control
## Drives the way in and checks it.
##
##   godot --path . res://scenes/dev/shell_test.tscn
##
## Exits 0 when every check passes, 1 otherwise, so it can gate a commit.

const SAVE := "user://shell_test_progress.json"
const SETTINGS := "user://shell_test_settings.json"

var shell: Shell
var _failures: PackedStringArray = PackedStringArray()
var _done: bool = false
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

	print("=== the figures are real stars, not placeholders ===")
	var real := 0
	var faults := PackedStringArray()
	for mansion in Mansions.SHIPPED:
		var f := Mansions.figure_of(mansion + 1)
		var points: Array = f["points"]
		var mags: Array = f["mags"]
		if points.is_empty():
			faults.append("%d has no points" % (mansion + 1))
			continue
		if mags.size() != points.size():
			faults.append("%d has %d points but %d magnitudes" % [mansion + 1, points.size(), mags.size()])
		for pair: Vector2i in (f["join"] as Array):
			if pair.x < 0 or pair.y < 0 or pair.x >= points.size() or pair.y >= points.size():
				faults.append("%d joins stars that are not there: %s" % [mansion + 1, pair])
		if f["real"]:
			real += 1
	_check_equal("every shipped mansion has a real figure", real, Mansions.SHIPPED)
	if faults.size() > 0:
		for fault in faults:
			print("      %s" % fault)
	_check_equal("...and none of them is malformed", faults.size(), 0)

	# الثريا is nine stars inside one degree; only the spread of brightness
	# tells it from a smudge, and no line may be drawn through a cluster.
	var thurayya := Mansions.figure_of(3)
	_check_equal("الثريا is nine stars", (thurayya["points"] as Array).size(), 9)
	_check_equal("...joined by nothing, because it is a cluster",
		(thurayya["join"] as Array).size(), 0)
	var mags: Array = thurayya["mags"]
	var spread: float = 0.0
	for m: float in mags:
		spread = maxf(spread, m - (mags as Array).min())
	_check("...and its magnitudes really do spread (%0.2f)" % spread, spread > 3.0)

	# الدبران is one star; what makes it a figure is the herd behind it.
	var dabaran := Mansions.figure_of(4)
	_check_equal("الدبران is one star", (dabaran["points"] as Array).size(), 1)
	_check("...and it has a figure behind it", (dabaran["behind"] as Array).size() > 0)

	# الهقعة branches: two lines meeting at one star, not a chain.
	var haqa := Mansions.figure_of(5)
	_check_equal("الهقعة branches from one star", (haqa["join"] as Array).size(), 2)

	print("=== what this build actually carries ===")
	_check_equal("spring is shipped whole", Mansions.shipped_seasons(), 1)
	_check("the first mansion is in", Mansions.is_shipped(1))
	_check("the last of spring is in", Mansions.is_shipped(Mansions.SHIPPED))
	_check("the first of summer is not", not Mansions.is_shipped(Mansions.SHIPPED + 1))
	_check("nor is the last of the year", not Mansions.is_shipped(Mansions.COUNT))
	_check("mansion zero is not a mansion", not Mansions.is_shipped(0))
	_check_equal("a hundred and forty levels", Mansions.SHIPPED_LEVELS, 140)
	_check("spring is whole", Mansions.season_shipped(0))
	_check("summer is not", not Mansions.season_shipped(1))

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
		shell._star_line.meaning_text(), Mansions.meaning_of(3)
	)
	_check_equal(
		"...and the modern name of its brightest star",
		shell._star_line.latin_label().text, "Pleiades"
	)
	_check_equal("...and its figure", shell._figure.shape.size(), Mansions.shape_of(3).size())
	# البلدة is named for being empty of bright stars, so it has no Latin name
	# and the line must disappear rather than sit there blank.
	shell.open_mansion(21)
	_check("البلدة hides the Latin line", not shell._star_line.latin_label().visible)
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

	# The game targets desktop as well as phones, and the project stretches the
	# viewport sideways on a wide window. Everything is laid out against a
	# portrait board, so the board is fitted and centred rather than stretched.
	print("=== a window of another shape ===")
	var was := shell.size
	# What a 1440 by 900 desktop window becomes in canvas units.
	shell.size = Vector2(3072.0, 1920.0)
	shell._layout()
	var area := shell.board()
	_check(
		"the board keeps its shape (%0.3f)" % (area.size.x / area.size.y),
		absf(area.size.x / area.size.y - 1080.0 / 1920.0) < 0.002
	)
	_check("...and fits inside the window", area.size.x <= 3072.0 and area.size.y <= 1920.0)
	_check(
		"...and is centred", absf(area.position.x + area.size.x * 0.5 - 1536.0) < 1.5
	)
	_check_equal("the play screen sits on it", shell.game.size, area.size)

	print("=== and it keeps clear of a notch ===")
	# No system reports one on a desktop, so one is put there by hand: the
	# numbers an iPhone with a Dynamic Island gives, in canvas units.
	shell.safe_area_override = Vector4(120.0, 0.0, 68.0, 0.0)
	shell._layout()
	var notched := shell.board()
	_check_equal("the board starts below the island", notched.position.y, 120.0)
	_check_equal("...and ends above the home bar",
		notched.position.y + notched.size.y, shell.size.y - 68.0)
	_check("...so the screens lose exactly that much (%0.0f)"
		% (area.size.y - notched.size.y), is_equal_approx(
			area.size.y - notched.size.y, 188.0))
	_check_equal("the play screen moved with it", shell.game.position.y, 120.0)
	_check("...and the sky did not: it is the room, not the board",
		shell.sky.position == Vector2.ZERO and shell.sky.size == shell.size)
	_check("...nor did the meteor",
		shell.wipe.position == Vector2.ZERO and shell.wipe.size == shell.size)

	shell.safe_area_override = Vector4(-1.0, 0.0, 0.0, 0.0)
	shell._layout()
	_check_equal("and putting it back restores the board", shell.board(), area)

	# The wheel places its disc and tiles from its own rect. They used to be
	# placed from the rect it had a moment before, and on a wide window the
	# whole wheel was drawn outside the board.
	var worst := 0.0
	for child in shell.game.wheel.get_children():
		var part := child as Control
		if part == null:
			continue
		worst = maxf(worst, -part.position.x)
		worst = maxf(worst, part.position.x + part.size.x - shell.game.wheel.size.x)
	_check("the wheel's parts stay on the wheel (worst %0.1f)" % worst, worst <= 1.0)

	shell.size = was
	shell._layout()

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
	# Every day of a whole cycle, not just today. The file is on disk either way
	# when the test runs from source, so existence proves nothing: what has to
	# hold is that the level is inside the shipped range, because that is what
	# the export carries. This is the check that would have caught «العب» doing
	# nothing on six days out of seven.
	var unshipped := 0
	var repeats := 0
	for i in Mansions.SHIPPED_LEVELS:
		var id := Daily.level_for(day + i)
		if not Mansions.is_shipped(Mansions.parse(id).x):
			unshipped += 1
		if i > 0 and id == Daily.level_for(day + i - 1):
			repeats += 1
	_check_equal("every day of a cycle is a shipped level", unshipped, 0)
	_check_equal("...and no day repeats the day before", repeats, 0)

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

	await _check_darkness()

	await _check_qiran()

	await _check_the_way_in()

	await _check_the_workbench()

	_check_separators()

	_finish()


## Same rule as the slice test, over the screens this one builds: the title
## carries «المنزلة ٤ — الدبران · النجمة ١٢ من ٢٠», and the map its own lines.
## Every screen the shell made is still a child here, shown or hidden.
## The workbench. It is a dev tool, but a dev tool whose buttons do nothing
## wastes the time it exists to save — and a dead button has shipped here once.
func _check_the_workbench() -> void:
	print("=== the workbench reaches the moments ===")
	_check("a debug build has one", shell.admin != null)
	if shell.admin == null:
		return
	var admin := shell.admin

	# Every button in it, pressed. Not to check what each one does — the checks
	# below do that — but because one that errors takes the whole panel with it.
	var buttons := 0
	for node in _every_node(admin):
		if node is Button:
			buttons += 1
	_check("...with buttons on it (%d)" % buttons, buttons >= 20)

	admin._go("m01-10")
	await _arrive()
	_check_equal("it goes to a level by name", shell.game.level.id, "m01-10")
	_check("...and that one is the verse", shell.game.in_bayt)

	admin._go("m01-01")
	_check_equal("...and back", shell.game.level.id, "m01-01")
	admin._solve(1)
	_check_equal("it solves a level but for one word",
		shell.game.grid.found_count(), shell.game.level.words.size() - 1)

	admin._set_lanterns(1)
	_check_equal("it sets the lanterns", shell.game.lanterns, 1)
	_check("...and the sky goes with them", shell.sky.light < 1.0)
	admin._add_coins(1000)
	_check("it fills the purse", shell.game.coins >= 1000)

	admin._at_the_twentieth()
	await _arrive()
	_check_equal("it stands on the twentieth star",
		shell.game.level.index_in_mansion, Mansions.LEVELS_PER_MANSION)
	_check_equal("...with one word left to play",
		shell.game.level.words.size() - shell.game.grid.found_count(), 1)

	# A conjunction needs a finished mansion, so stand somewhere that has one.
	admin._go("m04-05")
	await _arrive()
	_check_equal("three mansions are behind the player now", shell.mansions_reached(), 3)
	admin._open_qiran_night(true)
	_check("it finds a night the moon is in a lit mansion", shell.qiran_window.visible)
	_check("...and that night is really open",
		not shell.qiran_window._play_label.text.is_empty()
			and shell.qiran_window.figure.visible)
	shell.qiran_window.visible = false

	admin._open_qiran_night(false)
	_check("...and a night it is not", not shell.qiran_window.figure.visible)
	shell.qiran_window.visible = false

	# And with nothing finished it says why rather than looking broken.
	admin._go("m01-02")
	await _arrive()
	admin._open_qiran_night(true)
	_check("with no mansion finished it says so", not shell.qiran_window.visible)
	_check("...naming the reason", admin._note.text.contains("لا منزلة"))

	var gift := admin._first_level_with_gift()
	var gift_level := shell.game.level_by_id(gift)
	_check("it finds a level that opens a cell (%s)" % gift,
		gift_level != null and gift_level.has_gift())
	var widest := admin._widest_wheel()
	var widest_level := shell.game.level_by_id(widest)
	_check_equal("...and the widest wheel in the build (%s)" % widest,
		widest_level.letters.size() if widest_level != null else 0, 7)

	admin._wipe()
	await _arrive()
	_check_equal("it wipes back to the first level", shell.game.level.id, "m01-01")
	_check_equal("...with nothing in the purse", shell.game.coins, 0)
	_check_equal("...and the lanterns full", shell.game.lanterns, GameScreen.LANTERNS_MAX)


## A player opening the game for the first time: a dark sky, then a board with
## nothing on it but the wheel, and the counters arriving one at a time.
func _check_the_way_in() -> void:
	print("=== the way in, once in a player's life ===")
	var save := "user://tour_test_progress.json"
	var kept := "user://tour_test_settings.json"
	Progress.clear(save)
	GameSettings.clear(kept)

	var fresh := Shell.new()
	fresh.progress_path = save
	fresh.settings_path = kept
	fresh.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fresh)
	await get_tree().process_frame
	await get_tree().process_frame

	_check("it opens on the dark sky, not the title", fresh.cold_open.visible)
	_check("...and the title is behind it", not fresh.title.visible)
	_check("...and the sky is darker than any lantern makes it",
		fresh.sky.light < GameScreen.LANTERN_LIGHT[0])
	_check_equal("...on the first level of the first mansion",
		fresh.game.level.id, "m01-01")
	# Tapped, not called: the first button a player ever presses shipped with
	# no hit area, because `make_button` left sizing to the caller and this
	# caller forgot. Checking the signal fires is not checking the button works.
	var hit: Button = fresh.cold_open.begin_button.get_meta("button")
	_check("the button that begins it has a hit area (%0.0f x %0.0f)"
		% [hit.size.x, hit.size.y], hit.size.x > 100.0 and hit.size.y > 40.0)
	_check("...and so does the one that skips it",
		fresh.cold_open.skip_button.size.x > 100.0)

	fresh.cold_open.begin_requested.emit()
	await get_tree().create_timer(MeteorWipe.DURATION + 0.25).timeout
	_check("it goes straight into the level", fresh.showing == Shell.Screen.GAME)
	_check("...teaching", fresh.game.teaching)
	_check("...with nothing on the board but the wheel",
		not fresh.game.hud._chip_lanterns.visible
			and not fresh.game.hud._chip_coins.visible
			and not fresh.game.hud._chip_moon.visible)
	_check("...no hint button", not fresh.game.hint_button.visible)
	_check("...and no price tag", not fresh.game._hint_cost.visible)

	# «حسم» is real Arabic and not in this grid, so it is the first bonus word.
	fresh.game.submit("حسم")
	_check("the moon arrives on the first word outside the grid",
		fresh.game.hud._chip_moon.visible)
	_check("...and says so", fresh.game._coach.visible)
	_check("...but the lanterns are still nowhere",
		not fresh.game.hud._chip_lanterns.visible)

	# «محس» is the one three-letter run of ح س ا م that is not a word.
	var lamps: int = fresh.game.lanterns
	fresh.game.submit("محس")
	_check("the lanterns arrive on the first wrong guess",
		fresh.game.hud._chip_lanterns.visible)
	_check_equal("...before any is lost", fresh.game.lanterns, lamps)
	# A counter that is not on screen must not hold its place open either.
	fresh.game._layout()
	_check("...and the counters that are not there leave no gap (%0.0f)"
		% fresh.game.hud._chip_lanterns.position.x,
		fresh.game.hud._chip_lanterns.position.x
			< fresh.game.hud._chip_moon.position.x + 300.0 * fresh.game._scale())

	for word in ["حسام", "حماس", "امس", "اسم"]:
		fresh.game.submit(word)
	_check("the level is finished", fresh.game.grid.is_solved())
	_check("...and the teaching is over", not fresh.game.teaching)
	_check("...everything is on the board now",
		fresh.game.hud._chip_lanterns.visible and fresh.game.hud._chip_coins.visible
			and fresh.game.hud._chip_moon.visible and fresh.game.hint_button.visible)
	_check("...and it is written down", GameSettings.read(kept).tour_done)

	fresh.queue_free()
	await get_tree().process_frame

	# A second launch: the same save, the same settings, and no tour.
	var again := Shell.new()
	again.progress_path = save
	again.settings_path = kept
	again.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(again)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("coming back opens on the title", not again.cold_open.visible)
	_check("...and teaches nothing", not again.game.teaching)
	again.queue_free()
	await get_tree().process_frame
	Progress.clear(save)
	GameSettings.clear(kept)


## The moon lodges in a new mansion every night, and the arithmetic says which.
func _check_qiran() -> void:
	print("=== the moon lodges in a mansion every night ===")
	# Two nights worked out by hand against the same formulae, so a change to
	# the constants cannot pass quietly.
	var night_in_saad := _day_of(2026, 9, 23)
	var night_in_sharatan := _day_of(2026, 9, 28)
	_check_equal("23 Sep 2026 is سعد السعود", Qiran.mansion_on(night_in_saad), 24)
	_check_equal("28 Sep 2026 is الشرطان", Qiran.mansion_on(night_in_sharatan), 1)
	_check_equal("...and the moon is all but full then (%d%%)"
		% int(round(Qiran.illumination(night_in_sharatan) * 100.0)),
		int(round(Qiran.illumination(night_in_sharatan) * 100.0)), 97)
	_check("...and emptying, not filling", not Qiran.waxing(night_in_sharatan))

	# The whole reason they are called the moon's mansions. Not quite one a
	# night: the moon runs from about 11.8° a day at its furthest to 15.4° at
	# its nearest, against a mansion of 12.86°, so it now and then lingers a
	# night or skips one. What must hold is that it works its way round.
	var lingered := 0
	var longest := 0
	var run := 0
	var visited := {}
	for ahead in 28:
		var here := Qiran.mansion_on(night_in_saad + ahead)
		if ahead > 0 and here == Qiran.mansion_on(night_in_saad + ahead - 1):
			lingered += 1
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
		visited[here] = true
	_check("it moves on nearly every night (%d lingered of 28)" % lingered, lingered <= 3)
	_check("...and never for more than one night over (%d)" % longest, longest <= 1)
	_check("...and works round the year (%d of 28)" % visited.size(), visited.size() >= 26)

	print("=== but only a mansion you have lit opens ===")
	# The save this test runs on sits at m04-12, so three mansions are finished.
	_check_equal("three mansions are behind the player", shell.mansions_reached(), 3)
	_check("سعد السعود is not one of them",
		not Qiran.open_tonight(night_in_saad, 3))
	_check("الشرطان is", Qiran.open_tonight(night_in_sharatan, 3))
	var soon := Qiran.next_open(night_in_saad, 3)
	_check_equal("...and it is the next one the player can take",
		int(soon.get("mansion", 0)), 1)
	_check_equal("...five nights off", int(soon.get("nights", -1)), 5)
	_check("a player who has finished nothing is told so",
		Qiran.next_open(night_in_saad, 0).is_empty())

	# The night's level is never the verse or the rhyme: those belong to the
	# night the mansion was first finished.
	for ahead in 28:
		var id := Qiran.level_for(night_in_saad + ahead, 1)
		var index := Mansions.parse(id).y
		if index == 10 or index == 20:
			_check("the visit never opens on the verse or the rhyme (%s)" % id, false)
			break

	print("=== a night played aside changes nothing ===")
	shell.open_qiran(night_in_saad)
	_check("the window is up", shell.qiran_window.visible)
	_check("...and offers no night, only the way out",
		shell.qiran_window._play_label.text == "أكملِ الرحلة")
	_check("...which is a button that works",
		not shell.qiran_window._play_button.disabled)
	_check("...and pressing it starts no night", not shell.start_qiran(night_in_saad))
	_check("...and keeps the name back", shell.qiran_window._where.text == "منزلةٌ لم تبلغْها")
	_check("...showing no figure either", not shell.qiran_window.figure.visible)
	shell.qiran_window.visible = false

	shell.open_qiran(night_in_sharatan)
	_check("on its own night the mansion is named",
		shell.qiran_window._where.text == Mansions.name_of(1))
	_check("...and the figure is shown", shell.qiran_window.figure.visible)
	_check("...and it can be entered", not shell.qiran_window._play_button.disabled)

	var journey := shell.game.level.id
	var purse: int = shell.game.coins
	var lamps: int = shell.game.lanterns
	_check("the night starts", shell.start_qiran(night_in_sharatan))
	await _arrive()
	_check("it is a conjunction night", shell.game.qiran)
	_check("...in tonight's mansion (%s)" % shell.game.level.id,
		Mansions.parse(shell.game.level.id).x == 1)

	# Five wrong guesses, which on the journey would cost a lantern.
	for i in GameScreen.WRONG_STREAK_COST:
		shell.game.submit("ززز")
	_check_equal("no lantern is spent, however badly it goes",
		shell.game.lanterns, lamps)

	shell.game.qiran_finished.emit()
	await _arrive()
	_check_equal("the journey comes back where it was", shell.game.level.id, journey)
	_check_equal("...with its coins untouched", shell.game.coins, purse)
	_check_equal("...and its lanterns", shell.game.lanterns, lamps)
	_check("...and the night is over", not shell.game.qiran)
	shell.qiran_window.visible = false
	shell.go_to(Shell.Screen.MAP)
	await _arrive()


## Days since the epoch, the way `Daily.today()` counts them.
func _day_of(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day,
		"hour": 0, "minute": 0, "second": 0,
	}) / 86400.0)


## There is no losing in this game, only light that lessens.
func _check_darkness() -> void:
	print("=== the lanterns take the light with them ===")
	shell.go_to(Shell.Screen.GAME)
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout

	shell.game.lanterns = 5
	shell.game._refresh_chrome()
	var full: float = shell.sky.light
	_check_equal("five lanterns is the sky as designed", full, 1.0)

	shell.game.lanterns = 3
	shell.game._refresh_chrome()
	var middling: float = shell.sky.light
	_check("three is darker (%0.2f < %0.2f)" % [middling, full], middling < full)
	_check_equal("...and the disc is still full (%0.2f)" % shell.game.wheel.light,
		shell.game.wheel.light, 1.0)

	shell.game.lanterns = 1
	shell.game._refresh_chrome()
	_check("one is darker still (%0.2f < %0.2f)" % [shell.sky.light, middling],
		shell.sky.light < middling)
	_check("...and now the disc goes with it (%0.2f)" % shell.game.wheel.light,
		shell.game.wheel.light < 1.0)
	_check("the stars dim less than the sky does",
		shell.sky.stars.light > shell.sky.light)

	shell.game.lanterns = 0
	shell.game._refresh_chrome()
	_check("none is the darkest (%0.2f)" % shell.sky.light, shell.sky.light < 0.6)
	_check("...but never black", shell.sky.light > 0.4)

	print("=== the question comes after the first dark, not before ===")
	_check("nothing was asked on the way in", not shell.notify_window.visible)
	_check("...and the settings have not been written to", not shell.settings.notify_asked)

	shell.game.lanterns = 0
	shell.game.show_out_of_lanterns()
	_check("the lanterns window is up", shell.game.lanterns_window.visible)
	_check("...and the question waits behind it", not shell.notify_window.visible)

	shell.game.lanterns_window.close()
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.1).timeout
	shell.notify_window.settle()
	_check("it is asked once that window is gone", shell.notify_window.visible)

	for panel in shell.notify_window.buttons():
		if (panel.get_meta("label") as Label).text == "نعم، أنبئني":
			(panel.get_meta("button") as Button).pressed.emit()
	_check("the answer is kept", shell.settings.notify)
	_check("...and the asking is over", shell.settings.notify_asked)
	_check_equal("...and it survives a read", GameSettings.read(SETTINGS).notify, true)

	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.1).timeout
	shell.game.lanterns = 0
	shell.game.show_out_of_lanterns()
	shell.game.lanterns_window.close()
	await get_tree().create_timer(SkyPopup.CLOSE_SECONDS + 0.1).timeout
	_check("and it is never asked again", not shell.notify_window.visible)
	shell.game.lanterns = 5
	shell.game._refresh_chrome()


func _check_separators() -> void:
	print("=== no dot beside a number ===")
	var bad := PackedStringArray()
	for node in _every_node(self):
		var texts := PackedStringArray()
		if node is Label:
			texts.append((node as Label).text)
		elif node is Button:
			texts.append((node as Button).text)
		if node is Control:
			texts.append((node as Control).tooltip_text)
		for text in texts:
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


func _finish() -> void:
	_done = true
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
