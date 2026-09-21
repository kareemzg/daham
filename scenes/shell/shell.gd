class_name Shell
extends Control
## The one place the game lives: it owns the sky, the meteor and the windows
## that belong to no single screen, and swaps what sits on them.
##
## The sky is here rather than in each screen because it never transitions. A
## screen fades out and another fades in over the same stars, which is what
## makes the game read as one place instead of a stack of screens.

enum Screen { TITLE, MAP, GAME }

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
var game: GameScreen
## One settings window for the whole game. Two would be two places for the
## switches to disagree about what is actually stored.
var settings_window: SettingsWindow
var mansion_window: SkyWindow
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

	game = GAME_SCENE.instantiate()
	game.draws_sky = false
	game.progress_path = progress_path
	game.visible = false
	add_child(game)
	game.menu_requested.connect(func() -> void: go_to(Screen.MAP))
	game.settings_requested.connect(open_settings)

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
	var back := mansion_window.add_button(
		GlossyPanel.Style.BUTTON_CREAM, "عودة إلى الخريطة", UiIcon.Kind.HOME, 92.0
	)
	(back.get_meta("button") as Button).pressed.connect(
		func() -> void: mansion_window.close())

	wipe = MeteorWipe.new()
	add_child(wipe)
	wipe.swap.connect(_on_swap)

	resized.connect(_layout)
	_refresh_title()
	_layout()


func _scale() -> float:
	return maxf(size.x, 1.0) / 1080.0


func _screen(which: int) -> Control:
	match which:
		Screen.TITLE:
			return title
		Screen.MAP:
			return map
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
			var saved := game.capture()
			map.show_progress(saved.level_id, saved.coins, saved.lanterns, saved.moon)


func _refresh_title() -> void:
	var place := Mansions.parse(game.level.id if game != null and game.level != null else "")
	title.show_place(place.x, place.y)


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


## The card for one mansion. The named-star lines are not here yet: the story
## calls for about two hundred and fifty of them and they are a writing job that
## has not been done, so the card shows what the game actually knows.
func open_mansion(mansion: int) -> void:
	var lit := map.stars_of(mansion)
	mansion_window.set_title(Mansions.name_of(mansion))
	mansion_window.set_body("%s · %s\nالنجمة %s من %s" % [
		Mansions.season_name(Mansions.season_of(mansion)),
		"المنزلة %s" % Arabic.eastern_digits(mansion),
		Arabic.eastern_digits(lit),
		Arabic.eastern_digits(Mansions.LEVELS_PER_MANSION),
	])
	_layout()
	mansion_window.open()


func _layout() -> void:
	if sky == null or size.x <= 0.0:
		return
	var s := _scale()
	for node: Control in [sky, title, map, game, wipe, settings_window, mansion_window]:
		node.position = Vector2.ZERO
		node.size = size
	settings_window.relayout(s)
	mansion_window.relayout(s)
