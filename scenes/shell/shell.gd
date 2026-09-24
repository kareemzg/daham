class_name Shell
extends Control
## The one place the game lives: it owns the sky, the meteor and the windows
## that belong to no single screen, and swaps what sits on them.
##
## The sky is here rather than in each screen because it never transitions. A
## screen fades out and another fades in over the same stars, which is what
## makes the game read as one place instead of a stack of screens.

enum Screen { TITLE, MAP, GAME, CARDS }

const GAME_SCENE := preload("res://scenes/game/game.tscn")
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

## Empty turns saving off, which is what the test scene does so that one run
## cannot change what the next one loads.
@export var progress_path: String = "user://progress.json"
@export var settings_path: String = "user://settings.json"

var sky: SkyBackdrop
var wipe: MeteorWipe
var title: TitleScreen
var map: SkyMap
var cards: StarCardsScreen
var game: GameScreen
## One settings window for the whole game. Two would be two places for the
## switches to disagree about what is actually stored.
var settings_window: SettingsWindow
var mansion_window: SkyWindow
var shop_window: ShelfWindow
var daily_window: DailyWindow
## Which mansion the moon is in tonight, and whether it is the player's.
var qiran_window: QiranWindow
## The way in, over everything, once in a player's life.
var cold_open: ColdOpen
## The workbench for reaching any moment without playing to it. Null in a
## release build, where `AdminPanel.attach()` declines to make one.
var admin: AdminPanel
## Overrides what the system says the safe area is, as (top, right, bottom,
## left) in canvas units. A negative first value means "ask the system". It is
## here so a notch can be looked at on a desktop, where no system reports one.
var safe_area_override: Vector4 = Vector4(-1.0, 0.0, 0.0, 0.0)
## Asked once, the first time the lanterns run out. See `_ask_about_notice()`.
var notify_window: SkyWindow
var _owed_notice_question: bool = false
## The journey's state, held while the day's challenge is played over it.
var _journey: Progress = null
var _figure: FigureView
var _star_line: StarLine
var settings: GameSettings = GameSettings.new()

var showing: int = Screen.TITLE
var _pending: int = -1


func _ready() -> void:
	if not settings_path.is_empty():
		settings = GameSettings.read(settings_path)

	sky = SkyBackdrop.new()
	add_child(sky)

	title = TitleScreen.new()
	add_child(title)
	title.play_requested.connect(func() -> void: go_to(Screen.GAME))
	title.map_requested.connect(func() -> void: go_to(Screen.MAP))
	title.settings_requested.connect(open_settings)

	map = SkyMap.new()
	map.visible = false
	add_child(map)
	map.play_requested.connect(func() -> void: go_to(Screen.GAME))
	map.settings_requested.connect(open_settings)
	map.mansion_opened.connect(open_mansion)
	map.shop_requested.connect(open_shop)
	map.cards_requested.connect(func() -> void: go_to(Screen.CARDS))
	map.daily_requested.connect(open_daily)
	map.qiran_requested.connect(open_qiran)

	cards = StarCardsScreen.new()
	cards.visible = false
	add_child(cards)
	cards.back_requested.connect(func() -> void: go_to(Screen.MAP))
	cards.mansion_opened.connect(open_mansion)

	game = GAME_SCENE.instantiate()
	game.draws_sky = false
	game.progress_path = progress_path
	game.visible = false
	add_child(game)
	game.menu_requested.connect(func() -> void: go_to(Screen.MAP))
	game.settings_requested.connect(open_settings)
	game.daily_finished.connect(_on_daily_finished)
	game.qiran_finished.connect(_on_qiran_finished)
	game.tour_finished.connect(_on_tour_finished)
	game.cards_requested.connect(func() -> void: go_to(Screen.CARDS))
	# The sky is the shell's, so the darkness the lanterns cause has to come
	# across as a message. It follows the player between screens, because it
	# belongs to the player and not to the screen they are on.
	game.light_changed.connect(func(light: float) -> void: sky.light = light)
	game.lanterns_emptied.connect(_on_lanterns_emptied)

	settings_window = SettingsWindow.new()
	settings_window.configure_settings(DISPLAY_FONT, UI_BOLD_FONT)
	settings_window.visible = false
	# Opened by the player and closed the same way: a tap on the dark outside.
	settings_window.dismiss_on_tap = true
	add_child(settings_window)
	settings_window.changed.connect(_on_setting_changed)
	settings_window.close_requested.connect(func() -> void: settings_window.close())
	settings_window.menu_requested.connect(func() -> void:
		settings_window.close()
		go_to(Screen.MAP)
	)

	mansion_window = SkyWindow.new()
	mansion_window.configure(DISPLAY_FONT, UI_BOLD_FONT)
	mansion_window.set_crest(UiIcon.Kind.STAR)
	mansion_window.visible = false
	mansion_window.dismiss_on_tap = true
	add_child(mansion_window)
	_figure = FigureView.new()
	mansion_window.add_row(_figure, 210.0, 18.0)
	_star_line = _build_star_line()
	var back := mansion_window.add_button(
		GlossyPanel.Style.BUTTON_CREAM, "عودة إلى الخريطة", UiIcon.Kind.HOME, 92.0
	)
	(back.get_meta("button") as Button).pressed.connect(
		func() -> void: mansion_window.close())
	mansion_window.close_requested.connect(func() -> void: mansion_window.close())
	mansion_window.add_close_cross()

	# The question about the notification. It is built here with every other
	# window, and opened only after the lanterns have run out for the first time.
	notify_window = SkyWindow.new()
	notify_window.configure(DISPLAY_FONT, UI_BOLD_FONT)
	notify_window.set_crest(UiIcon.Kind.LANTERN)
	notify_window.set_title("أُنبئك حين تعود؟")
	# Broken by hand: a Label left to wrap itself claims a height it works out
	# at zero width, which on a window's first layout is every word on a line.
	notify_window.set_body("إشعارٌ واحد حين تمتلئ فوانيسك.\nلا شيء غيره.")
	notify_window.visible = false
	add_child(notify_window)
	var yes := notify_window.add_button(
		GlossyPanel.Style.BUTTON_EMBER, "نعم، أنبئني", UiIcon.Kind.LANTERN
	)
	(yes.get_meta("button") as Button).pressed.connect(
		func() -> void: _answer_notice(true))
	var later := notify_window.add_button(
		GlossyPanel.Style.BUTTON_CREAM, "لاحقاً", -1, 92.0
	)
	(later.get_meta("button") as Button).pressed.connect(
		func() -> void: _answer_notice(false))

	shop_window = ShelfWindow.new()
	shop_window.configure_shelf(
		DISPLAY_FONT, UI_BOLD_FONT, UiIcon.Kind.SHOP, "المتجر",
		"تُشترى بالعملات التي تكسبها من المستويات."
	)
	# The one price, read from where it is spent. A shop that sells a refill
	# for less than the screen charges is two prices for one thing.
	shop_window.add_item(
		UiIcon.Kind.LANTERN, "املأ الفوانيس", "الخمسة كاملة",
		GameScreen.LANTERN_REFILL_COST
	)
	shop_window.add_item(UiIcon.Kind.SPYGLASS, "ثلاثة مناظير", "بدل ١٥٠، توفّر ٣٠", 120)
	shop_window.add_item(UiIcon.Kind.ASTROLABE, "أسطرلابان", "بدل ٣٠٠، توفّر ٦٠", 240)
	shop_window.add_purse()
	shop_window.add_note(
		"حزم العملات بمال حقيقي تظهر في نسخة الهاتف وحدها.\nنسخة سطح المكتب مدفوعة مرّة واحدة."
	)
	shop_window.visible = false
	shop_window.dismiss_on_tap = true
	add_child(shop_window)
	shop_window.chosen.connect(_on_shop_chosen)
	shop_window.close_requested.connect(func() -> void: shop_window.close())

	daily_window = DailyWindow.new()
	daily_window.configure_daily(DISPLAY_FONT, UI_BOLD_FONT)
	daily_window.visible = false
	daily_window.dismiss_on_tap = true
	add_child(daily_window)
	daily_window.play_requested.connect(start_daily)
	daily_window.close_requested.connect(func() -> void: daily_window.close())

	qiran_window = QiranWindow.new()
	qiran_window.configure_qiran(DISPLAY_FONT, UI_BOLD_FONT)
	qiran_window.visible = false
	qiran_window.dismiss_on_tap = true
	add_child(qiran_window)
	# On a night that is not the player's the same button reads «أكملِ الرحلة»
	# and does that: a button the player can press and that does nothing is
	# worse than one that is greyed.
	qiran_window.play_requested.connect(func() -> void:
		if not start_qiran():
			qiran_window.close())
	qiran_window.close_requested.connect(func() -> void: qiran_window.close())

	# Built after the screens and before the wipe, so it covers the title and
	# the meteor passes over it rather than under.
	cold_open = ColdOpen.new()
	cold_open.visible = false
	add_child(cold_open)
	cold_open.begin_requested.connect(_begin_tour)
	cold_open.skip_requested.connect(_skip_tour)

	wipe = MeteorWipe.new()
	add_child(wipe)
	wipe.swap.connect(_on_swap)

	resized.connect(_layout)
	_refresh_title()
	_layout()
	_open_cold()
	# Debug builds only; it returns null in a release and nothing is built.
	admin = AdminPanel.attach(self)
	if OS.is_debug_build():
		# Printed once, so a phone can be asked what it really is instead of
		# guessed at from a screenshot.
		var window := DisplayServer.window_get_size()
		print("[screen] window %d x %d   canvas %.0f x %.0f   safe area %s" % [
			window.x, window.y, size.x, size.y, DisplayServer.get_display_safe_area()
		])
		print("[screen] inset (top, right, bottom, left) = %s   board = %s" % [
			safe_inset(), board()
		])



## Shows the way in again, now, without the app being reinstalled. The admin
## panel calls it; nothing in the game does.
func replay_tour() -> void:
	settings.tour_done = false
	if not settings_path.is_empty():
		settings.write(settings_path)
	game.teaching = false
	if showing != Screen.TITLE:
		_screen(showing).visible = false
		showing = Screen.TITLE
	_layout()
	_open_cold()


## A first run opens on the dark sky rather than on the title. Everything else
## is already built behind it, so skipping is instant and beginning is a fade.
func _open_cold() -> void:
	if settings.tour_done or settings_path.is_empty():
		return
	# A save that already has a journey in it is not a first run, whatever the
	# settings say: a settings file lost or cleared must not re-teach a player
	# who is nineteen mansions in.
	if game.level != null and Mansions.parse(game.level.id) != Vector2i(1, 1):
		settings.tour_done = true
		settings.write(settings_path)
		return
	title.visible = false
	cold_open.visible = true
	sky.light = ColdOpen.SKY_LIGHT


## «أَضِئْ أوّلَ نجم»: straight into the first level, with nothing on screen but
## the board and the wheel.
func _begin_tour() -> void:
	game.teaching = true
	game._refresh_chrome()
	_leave_cold()
	showing = Screen.TITLE
	go_to(Screen.GAME)


## «تخطِّ التعريف»: the title, and everything on from the start.
func _skip_tour() -> void:
	_on_tour_finished()
	_leave_cold()
	title.visible = true


func _leave_cold() -> void:
	var fade := cold_open.create_tween()
	fade.tween_property(cold_open, "modulate:a", 0.0, 0.35)
	fade.tween_callback(func() -> void:
		cold_open.visible = false
		cold_open.modulate.a = 1.0)
	# The sky comes back to whatever the lanterns say it should be.
	game._refresh_light()


## The first level is done, or the tour was skipped. Either way it is over.
func _on_tour_finished() -> void:
	game.teaching = false
	if settings.tour_done or settings_path.is_empty():
		return
	settings.tour_done = true
	settings.write(settings_path)


## The screens are laid out against a 1080 by 1920 board. On a window of
## another shape the board is fitted inside it and centred rather than stretched
## to fill: the project's own stretch grows the viewport sideways, and a screen
## that read its own width came out three times too big on a desktop window with
## half of it off the edge.
const BOARD := Vector2(1080.0, 1920.0)


## What a notch, a status bar and a gesture bar take off the window, in canvas
## units, as (top, right, bottom, left).
##
## The sky keeps the whole window — it is the room the game is played in, and a
## night that stopped short of the notch would read as a picture of a night. It
## is the board that moves in, because a lantern under a camera cutout is a
## lantern the player cannot see or press.
##
## `DisplayServer` answers in device pixels and the board is measured in canvas
## units, so the ratio between them is what converts. On a desktop, and on any
## phone without a cutout, every side comes back zero.
func safe_inset() -> Vector4:
	if safe_area_override.x >= 0.0:
		return safe_area_override
	var window := DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0 or size.x <= 0.0:
		return Vector4.ZERO
	# The safe area is the DISPLAY's, in screen coordinates, and it only
	# describes this window when this window is the whole screen. A window on a
	# desktop has nothing over it: asking anyway handed back the Mac's menu bar
	# as a 448-unit notch and pushed the board down the screen.
	if window != DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var per_pixel := size.x / float(window.x)
	return Vector4(
		maxf(float(safe.position.y), 0.0) * per_pixel,
		maxf(float(window.x - safe.position.x - safe.size.x), 0.0) * per_pixel,
		maxf(float(window.y - safe.position.y - safe.size.y), 0.0) * per_pixel,
		maxf(float(safe.position.x), 0.0) * per_pixel
	)


## What the board has to lay itself out inside, once the notch is taken off.
func _safe_room() -> Vector2:
	var inset := safe_inset()
	return Vector2(
		maxf(size.x - inset.w - inset.y, 1.0), maxf(size.y - inset.x - inset.z, 1.0)
	)


func _scale() -> float:
	var room := _safe_room()
	return maxf(minf(room.x / BOARD.x, room.y / BOARD.y), 0.01)


## Where the board sits inside the window, and how big it is.
##
## The width is the design's: 1080 reference units, scaled so the whole board
## fits. The height is **all of it**. The scale is chosen so 1920 units already
## fit, so anything past that is room the window has and the design did not ask
## for, and letterboxing it away was throwing 18 to 20 per cent of the screen
## off the top and bottom of every modern phone — 460 pixels on a 19.5:9 one,
## where the grid was being squeezed into 39 per cent of the height. A screen
## laid out from `size.y` simply gets more; one anchored to the top is unmoved.
func board() -> Rect2:
	var scale := _scale()
	var inset := safe_inset()
	var room := _safe_room()
	# `_scale()` already measured against the room, so the width fits by
	# construction; clamping it again only moved the answer by a float's worth
	# and broke a test that compares the rect exactly.
	var area := Vector2(BOARD.x * scale, maxf(BOARD.y * scale, room.y))
	var at := Vector2(inset.w, inset.x) + ((room - area) * 0.5).floor()
	return Rect2(at, area)


func _screen(which: int) -> Control:
	match which:
		Screen.TITLE:
			return title
		Screen.MAP:
			return map
		Screen.CARDS:
			return cards
	return game


## Moves to another screen under a meteor, which swaps them as it crosses.
func go_to(target: int) -> void:
	if target == showing or _pending >= 0:
		return
	_pending = target
	wipe.play()
	var leaving := _screen(showing)
	var fade := create_tween()
	fade.tween_property(leaving, "modulate:a", 0.0, MeteorWipe.DURATION * 0.45)


func _on_swap() -> void:
	if _pending < 0:
		return
	_screen(showing).visible = false
	showing = _pending
	_pending = -1
	var arriving := _screen(showing)
	_refresh(showing)
	arriving.modulate.a = 0.0
	arriving.visible = true
	_layout()
	var fade := create_tween()
	fade.tween_property(arriving, "modulate:a", 1.0, MeteorWipe.DURATION * 0.45)


func _refresh(which: int) -> void:
	match which:
		Screen.TITLE:
			_refresh_title()
		Screen.MAP:
			# Whatever door the player left by, a finished level is behind them.
			game.move_on_if_finished()
			var saved := game.capture()
			map.show_progress(saved.level_id, saved.coins, saved.lanterns, saved.moon)
		Screen.CARDS:
			var here := place()
			cards.show_progress(here.x, here.y)


func _refresh_title() -> void:
	var here := place()
	title.show_place(here.x, here.y)


## Where the player is, as mansion and place in it. Read from the level the play
## screen is holding, so every screen agrees however the player got there.
func place() -> Vector2i:
	if game == null or game.level == null:
		return Vector2i.ZERO
	return Mansions.parse(game.level.id)


## The lanterns have gone out. The question waits for the window that tells
## the player so to close: two windows at once would be one of them unread.
func _on_lanterns_emptied() -> void:
	if settings.notify_asked:
		return
	if _owed_notice_question:
		return
	_owed_notice_question = true
	game.lanterns_window.closed.connect(_ask_about_notice, CONNECT_ONE_SHOT)


func _ask_about_notice() -> void:
	_owed_notice_question = false
	if settings.notify_asked or showing != Screen.GAME:
		return
	notify_window.open()


## Either answer settles it for good: the question is asked once.
func _answer_notice(yes: bool) -> void:
	settings.notify = yes
	settings.notify_asked = true
	# Nothing schedules anything yet — a local notification needs a platform
	# plugin this project does not carry. What is stored is the promise, so the
	# day the plugin lands it has an answer waiting and the player is not asked
	# twice.
	if not settings_path.is_empty():
		settings.write(settings_path)
	notify_window.close()


func open_settings() -> void:
	settings_window.show_values(settings)
	_layout()
	settings_window.open()


func _on_setting_changed(key: String, on: bool) -> void:
	match key:
		"sound":
			settings.sound = on
		"music":
			settings.music = on
		"haptics":
			settings.haptics = on
	# Nothing plays yet: the game has no audio. Storing the answer is what makes
	# the window real rather than a drawing of a window.
	if not settings_path.is_empty():
		settings.write(settings_path)


## The card for one mansion: its figure, what its name means, and the modern
## name of its brightest star where the tradition agrees on one.
##
## The per-star cards the story asks for, about two hundred and fifty of them,
## are still unwritten; this is the mansion's own line, which the game knows.
func open_mansion(mansion: int) -> void:
	var here := place()
	var lit := Mansions.LEVELS_PER_MANSION if mansion < here.x else (
		here.y - 1 if mansion == here.x else 0
	)
	mansion_window.set_title(Mansions.name_of(mansion))
	mansion_window.set_body("%s · %s\nالنجمة %s من %s" % [
		Mansions.season_name(Mansions.season_of(mansion)),
		"المنزلة %s" % Arabic.eastern_digits(mansion),
		Arabic.eastern_digits(lit),
		Arabic.eastern_digits(Mansions.LEVELS_PER_MANSION),
	])
	_figure.figure = Mansions.figure_of(mansion)
	_star_line.show_mansion(mansion)
	_layout()
	mansion_window.open()


## The daily challenge. A run only stands if the last one played was today or
## yesterday, so the window works the standing out rather than trusting the
## number it was saved with.
func open_daily() -> void:
	var day := Daily.today()
	daily_window.show_state(
		Daily.lit(game.daily_streak, game.daily_day, day),
		Daily.played_today(game.daily_day, day),
		Daily.seconds_left_today()
	)
	_layout()
	daily_window.open()


## How many mansions the player has finished, which is what decides whether
## tonight's conjunction is theirs to enter.
func mansions_reached() -> int:
	if game.level == null:
		return 0
	return maxi(Mansions.parse(game.level.id).x - 1, 0)


## `day` is days since the epoch, as `Daily.today()` counts them. It is a
## parameter so a test can stand on a night the sky is not on tonight; nothing
## in the game passes it.
func open_qiran(day: int = -1) -> void:
	if day < 0:
		day = Daily.today()
	qiran_window.show_night(day, mansions_reached())
	_layout()
	qiran_window.open()


## A night in the mansion the moon lodges in. The journey is kept aside exactly
## as it is for the daily challenge; the difference is that nothing is paid and
## nothing is owed, because the only thing on offer is that the mansion opens
## at all when the lanterns are out.
func start_qiran(day: int = -1) -> bool:
	if day < 0:
		day = Daily.today()
	if not Qiran.open_tonight(day, mansions_reached()):
		return false
	var level := game.level_by_id(Qiran.level_for(day, Qiran.mansion_on(day)))
	if level == null:
		return false
	qiran_window.close()
	_journey = game.capture()
	game.qiran = true
	game.show_level(level)
	go_to(Screen.GAME)
	return true


func _on_qiran_finished() -> void:
	game.qiran = false
	_put_journey_back()
	go_to(Screen.MAP)
	open_qiran()


## Starts the day's level over the journey, keeping the journey aside.
func start_daily() -> bool:
	var level := game.level_by_id(Daily.level_for(Daily.today()))
	if level == null:
		return false
	daily_window.close()
	_journey = game.capture()
	game.daily = true
	game.show_level(level)
	go_to(Screen.GAME)
	return true


## Settles the day and puts the journey back exactly where it was. Coins, the
## lanterns and the run itself carry over; nothing else the challenge touched
## belongs to the journey.
func _on_daily_finished() -> void:
	var day := Daily.today()
	var standing := Daily.advanced(game.daily_streak, game.daily_day, day)
	game.daily_streak = standing
	game.daily_day = day
	game.coins += Daily.DAY_REWARD
	if standing >= Daily.STREAK_LENGTH:
		game.coins += Daily.WEEK_REWARD
		game.lanterns = mini(game.lanterns + 1, GameScreen.LANTERNS_MAX)

	game.daily = false
	_put_journey_back()
	go_to(Screen.MAP)
	open_daily()


## Puts the journey back exactly where it was. Coins, the lanterns and the run
## carry over from whatever was played aside; nothing else does.
func _put_journey_back() -> void:
	if _journey == null:
		return
	var back := game.level_by_id(_journey.level_id)
	if back != null:
		_journey.coins = game.coins
		_journey.lanterns = game.lanterns
		_journey.daily_streak = game.daily_streak
		_journey.daily_day = game.daily_day
		game.show_level(back)
		game.restore(_journey)
	_journey = null
	game.save()


func open_shop() -> void:
	shop_window.show_purse(game.coins)
	_layout()
	shop_window.open()


## Index follows the order the lines were added: lanterns, spyglasses, astrolabes.
func _on_shop_chosen(index: int) -> void:
	var costs := [100, 120, 240]
	if index < 0 or index >= costs.size() or game.coins < int(costs[index]):
		return
	game.coins -= int(costs[index])
	match index:
		0:
			game.lanterns = GameScreen.LANTERNS_MAX
		1:
			game.tools[Tools.Kind.SPYGLASS] += 3
		2:
			game.tools[Tools.Kind.ASTROLABE] += 2
	game.save()
	shop_window.show_purse(game.coins)
	map.show_progress(game.level.id, game.coins, game.lanterns, game.moon)


func _build_star_line() -> StarLine:
	var line := StarLine.new()
	line.configure()
	mansion_window.add_row(line, StarLine.HEIGHT, 14.0)
	return line


func _layout_star_line(s: float) -> void:
	if _star_line != null:
		_star_line.relayout(s)


func _layout() -> void:
	# A window with no size yet would give every screen a board a few pixels
	# across, and the screens would lay themselves out against that.
	if sky == null or size.x < 2.0 or size.y < 2.0:
		return
	var s := _scale()
	var area := board()

	# The sky and the meteor fill the window: the sky is the room the game is
	# played in, and a meteor that stopped at the board's edge would read as a
	# thing on a card rather than a thing in the sky.
	for node: Control in [sky, wipe]:
		node.position = Vector2.ZERO
		node.size = size

	for node: Control in [title, map, cards, game, cold_open]:
		node.position = area.position
		node.size = area.size

	# Windows centre on the whole window, so they are never off to one side.
	for node: Control in [
		settings_window, mansion_window, shop_window, daily_window, notify_window,
		qiran_window,
	]:
		node.position = Vector2.ZERO
		node.size = size
	settings_window.relayout(s)
	mansion_window.relayout(s)
	_layout_star_line(s)
	shop_window.relayout(s)
	daily_window.relayout(s)
	qiran_window.relayout(s)
	notify_window.relayout(s)
