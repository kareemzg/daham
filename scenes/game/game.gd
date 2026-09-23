@tool
class_name GameScreen
extends Control
## The playable slice: wheel, grid, and the rules that join them.
##
## Everything a player can do goes through `submit()` or a button handler, so
## the test harness in `scenes/dev/` drives the same code path as a finger on
## the glass.
##
## The chrome is built in code rather than in the scene file because every piece
## of it is the same `GlossyPanel` with a different preset. When the UI kit ships
## as SVG the presets become textures and this file barely changes.

signal word_resolved(word: String, result: int)
signal level_solved
## Every window offers it. Nothing listens yet: the main menu is not built, so
## the window closes and the player is back on the level. When a shell exists it
## connects here and nothing in this file changes.
signal menu_requested
## The gear. The shell owns the one settings window, because two of them would
## be two places for the switches to disagree about what is actually stored.
signal settings_requested
## The day's challenge is over. The shell pays for it and puts the journey
## back, because none of it belongs to the journey's own progress.
signal daily_finished
## Asked for from the card a finished mansion opens.
signal cards_requested

enum Result {
	CORRECT,  ## a grid word, found for the first time
	ALREADY_FOUND,  ## a grid word found earlier: pulse it, score nothing
	BONUS,  ## a valid word outside the grid: fills the moon
	BONUS_REPEAT,
	KNOWN,  ## a real word the wheel spells, but not one of this level's: free
	INVALID,  ## not a word: five of them in a level costs a lantern
	TOO_SHORT,  ## one letter or none: ignored entirely
}

const LANTERNS_MAX := 5
const MOON_PHASES := 8
## How many wrong guesses a level costs a lantern. A budget for the level, not
## a run: a correct word no longer wipes it, because wiping it meant a player
## who found something every few tries never paid for anything. `show_level()`
## is the only thing that clears it, so the budget is per level and survives a
## quit — which is the whole reason it is saved.
const WRONG_STREAK_COST := 5
const LEVEL_REWARD := 45
## What the cheapest tool costs, for the price tag beside the wheel. The four
## prices themselves live in `Tools`.
const HINT_COST := Tools.PRICES[Tools.Kind.SPYGLASS]
const MOON_REWARD := 30
## The twentieth star of a mansion. It happens once in twenty levels, so it
## has to be felt: about nine levels' worth.
const MANSION_REWARD := 400
const LANTERN_REFILL_COST := 100
## How long one lantern takes to come back on its own.
const LANTERN_REGEN_SECONDS := 1800
const TOAST_SECONDS := 1.1

## Design metrics, in the 1080-wide reference space; scaled by `_scale`.
const REF_WIDTH := 1080.0
const CELL := 124.0
const CELL_GAP := 16.0
## The disc's radius. It only has to contain the tiles: the orbit is 163 and
## the widest tile 80, so 243 is everything there is to hold. It sat at 277,
## and those 34 units of nothing were 50 off the grid's height once doubled —
## on a tall grid the cells are capped by height, so the padding was coming
## straight out of the letters.
const WHEEL_BODY := 252.0
const WHEEL_ORBIT := 163.0
const TILE_RADIUS := 80.0
const PREVIEW_SIZE := 100.0
const PREVIEW_PILL_HEIGHT := 144.0
const PREVIEW_PILL_MIN := 366.0
const PREVIEW_PILL_PAD := 72.0
const WHEEL_MARGIN := 46.0
const CHIP_HEIGHT := 92.0
const GRID_MARGIN := 60.0
const STARS_PER_MANSION := 20
const BUTTON_SIZE := 161.0

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

## Which level to play. Exported so the test scene can point at its own
## fixture instead of whatever level generation happens to have produced.
@export_file("*.json") var level_path: String = "res://data/levels/m01-01.json"

## Where progress is written. Empty turns saving off entirely, which is what the
## test scene does so that one run cannot change what the next one loads.
@export var progress_path: String = "user://progress.json"

var level: Level = null
var progress: Progress = Progress.new()
var lanterns: int = LANTERNS_MAX
var coins: int = 480
## How full the moon is, counted in bonus words. It belongs to the player, not
## to the level: a level yields two bonus words at its thinnest and the moon
## wants eight, so resetting it between levels would mean it never fills.
## `_full_moon()` is the one thing that empties it, and it pays out first.
var moon: int = 0
var wrong_streak: int = 0

var _bonus_found: Dictionary = {}
var _toast_until: float = 0.0
## The sky behind this screen. A shell that draws its own turns this off, so the
## two never stack and the background stays one continuous thing across screens.
@export var draws_sky: bool = true
var _sky: SkyBackdrop

## The counters at the top. Shared with the sky map, which shows the same three.
var hud: HudBar
var _preview_pill: GlossyPanel
## The four windows, public so tests and future screens can drive them.
var complete_window: SkyWindow
var lanterns_window: SkyWindow
var restart_window: SkyWindow
var wipe: MeteorWipe
var next_button: GlossyPanel
var refill_button: GlossyPanel
var restart_confirm_button: GlossyPanel
var hints_window: ShelfWindow
var finale: MansionFinale
var mansion_window: SkyWindow
var next_mansion_button: GlossyPanel
var _mansion_name: Label
var _mansion_figure: FigureView
var _jump_label: Label = null
## Level ids where the wheel's width or the grid's word count changes, read off
## the levels themselves rather than kept in a table beside the one the pipeline
## already has.
var _jump_steps: PackedStringArray = PackedStringArray()
var _mansion_line: StarLine
var _mansion_reward: Control
## How many of each tool the player owns, bought ahead from the shop.
var tools: Array[int] = [0, 0, 0, 0]
## True while this screen is playing the day's challenge instead of the
## journey. Nothing is written to the journey's save, no lantern is spent
## however badly it goes, and finishing reports rather than moving on.
var daily: bool = false
var daily_streak: int = 0
var daily_day: int = 0
var _complete_stars: StarDots
var _complete_reward: Control
var _clock_strip: Control

## Unix time when the next lantern comes back. Zero while they are full.
var _lantern_clock: int = 0
var _pending_level: Level = null
## Set when a guess filled the moon. The coins are already paid; this only tells
## the landing star to play the rings and let the chip empty afterwards.
var _full_moon_pending: bool = false

## What the moon chip is showing. `moon` is the truth and changes at once, so a
## save is never behind; this trails it until the flying star lands.
var _moon_shown: int = 0
## Public so tests can press them through their real Button node.
var hint_button: GlossyPanel
var shuffle_button: GlossyPanel
var settings_button: GlossyPanel
var restart_button: GlossyPanel
var _hint_cost: GlossyPanel

@onready var stars: StarBand = $StarBand
@onready var grid: WordGrid = $Grid
@onready var wheel: LetterWheel = $Wheel
@onready var caption: Label = $Caption
@onready var preview: Label = $Preview
@onready var toast: Label = $Toast


func _ready() -> void:
	# Only the out-of-lanterns window wants a frame clock, and it turns this on.
	set_process(false)
	_build_chrome()
	wheel.word_previewed.connect(_on_word_previewed)
	wheel.word_submitted.connect(_on_word_submitted)
	grid.cell_picked.connect(_on_cell_picked)
	resized.connect(_layout)
	_build_jump_bar()

	# Pick up where the player left off, in the middle of a level if that is
	# where they were.
	var saved: Progress = null
	var first: Level = null
	if not progress_path.is_empty():
		saved = Progress.read(progress_path)
		first = _level_by_id(saved.level_id)
		if first == null and not saved.level_id.is_empty():
			# The save names a level this build does not carry: a scope that
			# shrank, or a save written by a build with more seasons in it.
			# Losing the level is no reason to lose the coins, the lanterns,
			# the moon and the run, so the progress is kept and only the place
			# in it moves. What belonged to the lost level is dropped with it.
			push_warning("Game: saved level %s is not in this build" % saved.level_id)
			first = Level.load_from(level_path)
			if first != null:
				saved.level_id = first.id
				saved.found = PackedStringArray()
				saved.bonus_found = PackedStringArray()
				saved.revealed = []
				saved.wrong_streak = 0
	if first == null:
		saved = null
		first = Level.load_from(level_path)
	if first == null:
		push_error("Game: no level to play")
		return
	show_level(first)
	if saved != null:
		restore(saved)


## Public so the shell can fetch the day's challenge without owning the path.
func level_by_id(id: String) -> Level:
	return _level_by_id(id)


func _level_by_id(id: String) -> Level:
	if id.is_empty():
		return null
	# The shipped range is enforced here, not only by the export filter, so that
	# running from source behaves the way the build does. The filter leaves the
	# other seasons' files out of the export, but they are all still on disk in
	# the editor: without this the game happily plays a level no player can
	# reach, and every check of that seam passes against a file the build does
	# not carry. The hand-made fixture parses to nothing and is let through.
	var place := Mansions.parse(id)
	if place != Vector2i.ZERO and not Mansions.is_shipped(place.x):
		return null
	return Level.load_from("res://data/levels/%s.json" % id)


## The level after this one, or "" at the end of what this build carries.
##
## The boundary is `Mansions.is_shipped`, not the twenty-eighth mansion: the
## build ships a season at a time, and a level file past the shipped range is
## not in the export. Naming the next level anyway is what makes this dangerous
## rather than merely wrong — `_save_ahead()` would write that id, and the boot
## path throws the whole save away when it cannot load the level it names. A
## player who finished spring would come back to a fresh game.
func next_level_id() -> String:
	if level == null:
		return ""
	var mansion := level.mansion
	var index := level.index_in_mansion + 1
	if index > STARS_PER_MANSION:
		mansion += 1
		index = 1
	if not Mansions.is_shipped(mansion):
		return ""
	return Mansions.level_id(mansion, index)


## Puts a level on the screen and clears everything that belongs to the last one.
## This is the seam progression will use: the next level arrives through here.
func show_level(new_level: Level) -> void:
	level = new_level
	for problem in level.validate():
		push_error("Level %s: %s" % [level.id, problem])

	_bonus_found.clear()
	wrong_streak = 0
	_refresh_jump_label.call_deferred()
	# A chart left armed must not survive into a level it was not bought for.
	grid.picking = false
	if finale != null:
		finale.visible = false
	_hide_windows()

	grid.setup(level)
	# The gift is opened here rather than restored from the save. `show_level()`
	# always runs before `restore()`, so a level that has one always has it, and
	# a save cannot be the thing that remembers it — which matters because the
	# ramp can be retuned and a save written against the old one must not keep
	# opening a cell the level no longer gives away.
	if level.has_gift():
		grid.reveal_cell(level.gift, false)
	wheel.body_radius = WHEEL_BODY
	wheel.orbit_radius = WHEEL_ORBIT
	wheel.tile_radius = TILE_RADIUS
	wheel.setup(level.letters)
	stars.setup(STARS_PER_MANSION, level.index_in_mansion - 1)

	caption.text = "المنزلة %s — %s · النجمة %s من %s" % [
		Arabic.eastern_digits(level.mansion),
		level.mansion_name,
		Arabic.eastern_digits(level.index_in_mansion),
		Arabic.eastern_digits(STARS_PER_MANSION),
	]
	preview.text = ""
	toast.text = ""
	_layout()
	_refresh_chrome()


func _build_chrome() -> void:
	# Nodes built here are never given an `owner`, so they are not written into
	# the scene file. Clearing them first keeps an editor script reload from
	# stacking a second set on top of the first.
	for child in get_children():
		if child.owner == null:
			child.queue_free()

	# Behind everything, including the scene's own nodes.
	_sky = SkyBackdrop.new()
	_sky.visible = draws_sky
	add_child(_sky)
	move_child(_sky, 0)

	hud = HudBar.new()
	hud.moon_phases = MOON_PHASES
	hud.configure(UI_BOLD_FONT)
	add_child(hud)
	# The pill goes behind the preview label, which the scene file already owns.
	_preview_pill = GlossyPanel.new()
	_preview_pill.style = GlossyPanel.Style.PILL_RIVER
	add_child(_preview_pill)
	move_child(_preview_pill, preview.get_index())

	hint_button = _make_button(UiIcon.Kind.HINT, _on_hint_pressed, "تلميح")
	_hint_cost = GlossyPanel.new()
	_hint_cost.style = GlossyPanel.Style.TILE_GOLD
	add_child(_hint_cost)
	var cost_coin := UiIcon.new()
	cost_coin.kind = UiIcon.Kind.COIN
	_hint_cost.add_child(cost_coin)
	_hint_cost.set_meta("coin", cost_coin)
	var cost_label := _make_label(UI_BOLD_FONT, Color("4A3A08"))
	cost_label.text = Arabic.eastern_digits(HINT_COST)
	_hint_cost.add_child(cost_label)
	_hint_cost.set_meta("label", cost_label)

	shuffle_button = _make_button(UiIcon.Kind.SHUFFLE, _on_shuffle_pressed, "خلط الحروف")
	# Furthest out first: the gear at the very edge, restart inboard of it.
	settings_button = hud.add_utility(UiIcon.Kind.SETTINGS, _on_settings_pressed, "الإعدادات")
	restart_button = hud.add_utility(UiIcon.Kind.RESTART, _on_restart_pressed, "إعادة المحاولة")

	# The finale is a moment on the sky, above the board and under the windows:
	# the card it ends with has to cover it.
	finale = MansionFinale.new()
	add_child(finale)
	finale.finished.connect(_show_mansion_card)

	# The windows are built after every piece of chrome, so a window covers the
	# HUD. Built before, the chips and buttons would sit over the dim layer and
	# stay bright and tappable while a modal window was up.
	_build_windows()

	wipe = MeteorWipe.new()
	add_child(wipe)
	wipe.swap.connect(_onwipe_swap)


## The four windows. Each is the same `SkyWindow` with different parts, so the
## padding, the type sizes and the button heights cannot drift between them.
##
## Every one of them offers the way back to the main menu beside its own action:
## a player who cannot go on must never be left with only the action they cannot
## take.
func _build_windows() -> void:
	complete_window = _new_window()
	complete_window.set_crest(UiIcon.Kind.STAR)
	complete_window.set_title("اكتمل المستوى")
	complete_window.set_body("")
	_complete_stars = StarDots.new()
	complete_window.add_row(_complete_stars, 34.0)
	_complete_reward = _build_reward_row(complete_window)
	next_button = complete_window.add_button(GlossyPanel.Style.BUTTON_EMBER, "التالي")
	_wire(next_button, _on_next_pressed)
	_wire(_menu_button(complete_window), _on_menu_pressed)

	lanterns_window = _new_window()
	lanterns_window.set_crest(UiIcon.Kind.LANTERN, 0.0)
	lanterns_window.set_title("نفدت الفوانيس")
	lanterns_window.set_body("انطفأ آخر فانوس.\nاملأها لتكمل، أو عد لاحقاً.")
	_clock_strip = _build_clock_row(lanterns_window)
	refill_button = lanterns_window.add_button(
		GlossyPanel.Style.BUTTON_EMBER,
		"املأ الفوانيس — %s" % Arabic.eastern_digits(LANTERN_REFILL_COST),
		UiIcon.Kind.COIN
	)
	_wire(refill_button, _on_refill_pressed)
	_wire(_menu_button(lanterns_window), _on_menu_pressed)

	restart_window = _new_window()
	restart_window.set_crest(UiIcon.Kind.RESTART)
	restart_window.set_title("تبدأ المستوى من جديد؟")
	restart_window.set_body(
		"تعود الرقعة فارغة وتفقد\nالكلمات التي وجدتها.\nالفوانيس والعملات لا تُمسّ."
	)
	restart_confirm_button = restart_window.add_button(
		GlossyPanel.Style.BUTTON_EMBER, "ابدأ من جديد"
	)
	_wire(restart_confirm_button, _on_confirm_restart)
	_wire(
		restart_window.add_button(GlossyPanel.Style.BUTTON_CREAM, "إلغاء", -1, 92.0),
		_on_cancel_restart
	)
	_wire(_menu_button(restart_window, 78.0), _on_menu_pressed)

	hints_window = ShelfWindow.new()
	hints_window.configure_shelf(
		DISPLAY_FONT, UI_BOLD_FONT, UiIcon.Kind.SPYGLASS, "التلميحات",
		"أدوات الراصد. كلٌّ منها يكشف قدراً مختلفاً."
	)
	for kind in Tools.COUNT:
		hints_window.add_item(
			Tools.ICONS[kind], Tools.NAMES[kind], Tools.WHAT[kind], Tools.PRICES[kind]
		)
	hints_window.add_purse()
	hints_window.visible = false
	hints_window.dismiss_on_tap = true
	add_child(hints_window)
	hints_window.chosen.connect(_on_tool_chosen)
	hints_window.close_requested.connect(func() -> void: hints_window.close())

	mansion_window = _new_window()
	mansion_window.set_crest(UiIcon.Kind.STAR)
	mansion_window.set_title("اكتملت المنزلة")
	mansion_window.set_body("")
	_mansion_name = _make_label(DISPLAY_FONT, Palette.GOLD_DEEP)
	mansion_window.add_row(_mansion_name, 74.0, 6.0)
	_mansion_figure = FigureView.new()
	mansion_window.add_row(_mansion_figure, 190.0, 12.0)
	_mansion_line = StarLine.new()
	_mansion_line.configure()
	mansion_window.add_row(_mansion_line, StarLine.HEIGHT, 12.0)
	_mansion_reward = _build_reward_row(mansion_window)
	# No separator beside the number, so the middle dot cannot read as a zero.
	(_mansion_reward.get_meta("label") as Label).text = (
		"انضمّت إلى بطاقاتك %s" % Arabic.eastern_digits(MANSION_REWARD)
	)
	next_mansion_button = mansion_window.add_button(
		GlossyPanel.Style.BUTTON_EMBER, "إلى المنزلة التالية"
	)
	_wire(next_mansion_button, _on_next_pressed)
	_wire(
		mansion_window.add_button(
			GlossyPanel.Style.BUTTON_CREAM, "بطاقات النجوم", UiIcon.Kind.STAR_CARDS, 92.0
		),
		func() -> void: cards_requested.emit()
	)
	# You opened this one yourself and cancelling is free, so tapping the dark
	# outside it is the same as pressing cancel. The other two are asking you
	# something, and a stray tap must not answer for you.
	restart_window.dismiss_on_tap = true


func _new_window() -> SkyWindow:
	var window := SkyWindow.new()
	window.configure(DISPLAY_FONT, UI_BOLD_FONT)
	window.visible = false
	add_child(window)
	return window


func _wire(shell: GlossyPanel, handler: Callable) -> void:
	(shell.get_meta("button") as Button).pressed.connect(handler)


func _menu_button(window: SkyWindow, height: float = 92.0) -> GlossyPanel:
	return window.add_button(
		GlossyPanel.Style.BUTTON_CREAM, "القائمة الرئيسية", UiIcon.Kind.HOME, height
	)


## A tinted tray with a number and a coin centred in it as one pair.
func _build_reward_row(window: SkyWindow) -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.22), Color(0, 0, 0, 0), 24, 0)
	)
	row.add_child(tray)
	row.set_meta("tray", tray)
	var label := _make_label(UI_BOLD_FONT, Color("4A3A08"))
	label.text = "+%s" % Arabic.eastern_digits(LEVEL_REWARD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(label)
	row.set_meta("label", label)
	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	row.add_child(coin)
	row.set_meta("coin", coin)
	window.add_row(row, 104.0)
	return row


func _build_clock_row(window: SkyWindow) -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.22), Color(0, 0, 0, 0), 22, 0)
	)
	row.add_child(tray)
	row.set_meta("tray", tray)
	var label := _make_label(UI_BOLD_FONT, Color("6B5942"))
	row.add_child(label)
	row.set_meta("label", label)
	var face := UiIcon.new()
	face.kind = UiIcon.Kind.CLOCK
	row.add_child(face)
	row.set_meta("icon", face)
	window.add_row(row, 84.0)
	return row


func _make_label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


## A round cream button with an icon, and a real Button on top of it so the
## control is reachable by keyboard and by a screen reader, not just by tapping.
func _make_button(icon_kind: int, handler: Callable, label_text: String) -> GlossyPanel:
	var panel := GlossyPanel.new()
	panel.style = GlossyPanel.Style.BUTTON_CREAM
	add_child(panel)

	var icon := UiIcon.new()
	icon.kind = icon_kind
	panel.add_child(icon)
	panel.set_meta("icon", icon)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = label_text
	button.pressed.connect(handler)
	button.button_down.connect(func() -> void: panel.set_pressed(true))
	button.button_up.connect(func() -> void: panel.set_pressed(false))
	panel.add_child(button)
	panel.set_meta("button", button)
	return panel


# --- layout ------------------------------------------------------------------

func _scale() -> float:
	return size.x / REF_WIDTH if size.x > 0.0 else 1.0


func _layout() -> void:
	if level == null or hud == null:
		return
	var s := _scale()

	_sky.position = Vector2.ZERO
	_sky.size = size

	# Laid out bottom-up. The wheel is the fixed point, because it has to sit
	# under a thumb; everything else stacks upward from it. A Label refuses to
	# be shorter than its text, so read its height back instead of assuming it.
	# Size first, then the radii: the wheel places its tiles from its own rect,
	# and a radius set against last frame's size puts them somewhere else.
	var span := WHEEL_BODY * s * 2.0
	wheel.size = Vector2(span, span)
	wheel.position = Vector2((size.x - span) * 0.5, size.y - span - WHEEL_MARGIN * s)
	wheel.body_radius = WHEEL_BODY * s
	wheel.orbit_radius = WHEEL_ORBIT * s
	wheel.tile_radius = TILE_RADIUS * s

	preview.add_theme_font_size_override("font_size", int(PREVIEW_SIZE * s))
	preview.size = Vector2(size.x, PREVIEW_SIZE * s)
	preview.position = Vector2(0.0, wheel.position.y - 14.0 * s - preview.size.y)
	_place_preview_pill()

	# The header is anchored to the top of the screen. The caption used to sit
	# 34 units below the chips for no reason anyone can see; a tall grid is
	# capped by height, so that gap was cells.
	caption.position = Vector2(0.0, 172.0 * s)
	caption.size = Vector2(size.x, 56.0 * s)
	caption.add_theme_font_size_override("font_size", int(34.0 * s))

	stars.position = Vector2(70.0 * s, 236.0 * s)
	stars.size = Vector2(size.x - 140.0 * s, 150.0 * s)

	toast.add_theme_font_size_override("font_size", int(36.0 * s))
	toast.size = Vector2(size.x, 60.0 * s)

	# The grid gets whatever is left between the header and the preview, and
	# sits in the middle of it. Chaining it straight to the preview instead
	# would pin it to the bottom of that gap whenever the grid is short.
	var band_top := stars.position.y + stars.size.y + 12.0 * s + toast.size.y + 12.0 * s
	# Down to the wheel, not down to the preview. The preview's strip was held
	# empty for the one second a finger is on the wheel, and on a grid capped
	# by height those 134 units were coming out of every cell on the board.
	# The pill is a later child than the grid, so it simply draws over the last
	# row while a word is being spelled — and that is the row a player looking
	# at the wheel is not reading. The toast keeps its own strip above the
	# grid: a message there would sit on the letter just won.
	var band_bottom := wheel.position.y - 20.0 * s

	# Cells shrink to fit. Generated grids run from four columns to eleven, and a
	# fixed cell size pushed nearly half of them off the side of the screen.
	var pitch := (CELL + CELL_GAP) * s
	pitch = minf(pitch, (size.x - GRID_MARGIN * 2.0 * s) / float(level.cols))
	pitch = minf(pitch, (band_bottom - band_top) / float(level.rows))
	grid.gap = pitch * (CELL_GAP / (CELL + CELL_GAP))
	grid.cell_size = pitch - grid.gap
	var grid_extent := grid.grid_size()
	grid.size = grid_extent
	grid.position = Vector2(
		(size.x - grid_extent.x) * 0.5,
		band_top + maxf(0.0, (band_bottom - band_top - grid_extent.y) * 0.5)
	)

	# The toast never lands on the grid: a message over a cell hides the letter
	# the player just earned.
	toast.position = Vector2(0.0, grid.position.y - 12.0 * s - toast.size.y)

	_layout_chips(s)
	_layout_buttons(s)

	wipe.position = Vector2.ZERO
	wipe.size = size
	_layout_windows(s)
	queue_redraw()


func _layout_windows(s: float) -> void:
	for window: SkyWindow in [
		complete_window, lanterns_window, restart_window, hints_window, mansion_window
	]:
		window.position = Vector2.ZERO
		window.size = size
		# relayout() stacks the parts and sizes the panel, so it has to run
		# before anything reads a row's size.
		window.relayout(s)

	_layout_pair_row(_complete_reward, s, 150.0, 62.0, 44.0)
	_layout_pair_row(_mansion_reward, s, 440.0, 52.0, 30.0)
	_mansion_name.add_theme_font_size_override("font_size", int(62.0 * s))
	_mansion_line.relayout(s)
	finale.position = Vector2.ZERO
	finale.size = size
	_layout_pair_row(_clock_strip, s, 330.0, 44.0, 30.0)

## A tray with a label and an icon centred inside it as one pair: the reward in
## the level-complete window, the countdown in the out-of-lanterns one. Centring
## them as a pair is what stops the number floating away from its icon.
func _layout_pair_row(
	row: Control, s: float, text_width: float, icon_side: float, font_size: float
) -> void:
	var tray: Panel = row.get_meta("tray")
	tray.position = Vector2.ZERO
	tray.size = row.size

	var label: Label = row.get_meta("label")
	var icon: UiIcon = row.get_meta("coin") if row.has_meta("coin") else row.get_meta("icon")
	var text := text_width * s
	var side := icon_side * s
	var gap := 18.0 * s
	var left := (row.size.x - (text + gap + side)) * 0.5
	label.position = Vector2(left, 0.0)
	label.size = Vector2(text, row.size.y)
	label.add_theme_font_size_override("font_size", int(font_size * s))
	icon.size = Vector2(side, side)
	icon.position = Vector2(left + text + gap, (row.size.y - side) * 0.5)


## The counters and the utility buttons are one object now, shared with the sky
## map. All this screen owes it is where to sit.
func _layout_chips(s: float) -> void:
	hud.position = Vector2(0.0, 60.0 * s)
	hud.size = Vector2(size.x, HudBar.CHIP_HEIGHT * s)
	hud.relayout(s)


func _layout_buttons(s: float) -> void:
	var button_size := BUTTON_SIZE * s
	var margin := 40.0 * s
	var middle := wheel.position.y + wheel.size.y * 0.42

	# Hint on the reading-start side (right), shuffle opposite it.
	_place_button(hint_button, Vector2(size.x - margin - button_size, middle), button_size)
	_place_button(shuffle_button, Vector2(margin, middle), button_size)

	var cost_width := 132.0 * s
	var cost_height := 67.0 * s
	_hint_cost.size = Vector2(cost_width, cost_height)
	_hint_cost.position = Vector2(
		hint_button.position.x + (button_size - cost_width) * 0.5,
		hint_button.position.y + hint_button.size.y + 8.0 * s
	)
	_hint_cost.edge_override = 0.0
	var cost_face := _hint_cost.face_height()
	# Right to left: the coin first, then what it costs.
	var cost_coin: UiIcon = _hint_cost.get_meta("coin")
	var coin_side := 36.0 * s
	cost_coin.size = Vector2(coin_side, coin_side)
	cost_coin.position = Vector2(cost_width - 20.0 * s - coin_side, (cost_face - coin_side) * 0.5)
	var cost_label: Label = _hint_cost.get_meta("label")
	cost_label.position = Vector2(20.0 * s, 0.0)
	cost_label.size = Vector2(cost_coin.position.x - 31.0 * s, cost_face)
	cost_label.add_theme_font_size_override("font_size", int(33.0 * s))


func _place_button(panel: GlossyPanel, at: Vector2, button_size: float) -> void:
	var edge := 14.0 * _scale()
	panel.position = at
	panel.size = Vector2(button_size, button_size + edge)
	panel.edge_override = edge
	panel.radius_override = button_size * 0.5
	var face := panel.face_height()
	var icon: UiIcon = panel.get_meta("icon")
	icon.size = Vector2(button_size * 0.56, button_size * 0.56)
	icon.position = Vector2((button_size - icon.size.x) * 0.5, (face - icon.size.y) * 0.5)
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = panel.size


func _place_preview_pill() -> void:
	if _preview_pill == null:
		return
	var s := _scale()
	var text := preview.text
	if text.is_empty():
		_preview_pill.visible = false
		return
	_preview_pill.visible = true
	var font_size := int(PREVIEW_SIZE * s)
	var text_width := DISPLAY_FONT.get_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size
	).x
	var pill_width := maxf(text_width + PREVIEW_PILL_PAD * 2.0 * s, PREVIEW_PILL_MIN * s)
	var pill_height := PREVIEW_PILL_HEIGHT * s
	_preview_pill.size = Vector2(pill_width, pill_height)
	_preview_pill.position = Vector2(
		(size.x - pill_width) * 0.5,
		preview.position.y + (preview.size.y - pill_height) * 0.5
	)
	_preview_pill.radius_override = (pill_height - 8.0 * s) * 0.5


# --- rules -------------------------------------------------------------------

func _on_word_previewed(word: String) -> void:
	preview.text = word
	preview.add_theme_color_override(
		"font_color", Palette.CREAM if word.is_empty() else Color("FFF6E2")
	)
	_place_preview_pill()


func _on_word_submitted(word: String) -> void:
	submit(word)


func _on_shuffle_pressed() -> void:
	wheel.shuffle_letters()


## The hint button opens the shelf rather than spending anything: there are
## four tools now, and which one a player wants is their choice, not the
## cheapest by default.
func _on_hint_pressed() -> void:
	for kind in Tools.COUNT:
		hints_window.rows[kind].set_owned(tools[kind])
	hints_window.show_purse(coins)
	_open(hints_window)


func _on_tool_chosen(kind: int) -> void:
	if kind < 0 or kind >= Tools.COUNT:
		return
	if tools[kind] > 0:
		tools[kind] -= 1
	elif coins >= Tools.PRICES[kind]:
		coins -= Tools.PRICES[kind]
	else:
		_say("العملات لا تكفي")
		return
	hints_window.close()
	use_tool(kind)


## Spends nothing: the paying happened above. Public so a test can drive a tool
## without going through the window.
func use_tool(kind: int) -> void:
	if level == null:
		return
	match kind:
		Tools.Kind.SPYGLASS:
			var cell := grid.hint_cell()
			if cell.x < 0:
				_say("لا شيء يحتاج تلميحاً")
			else:
				grid.reveal_cell(cell)
				_say("كُشف حرف")
		Tools.Kind.ASTROLABE:
			var opened := 0
			for entry in level.words:
				var text: String = entry["text"]
				if grid.is_found(text):
					continue
				var cells := level.cells_of(entry)
				if cells.is_empty() or grid.is_revealed_at(cells[0]):
					continue
				grid.reveal_cell(cells[0])
				opened += 1
			_say("كُشف أول حرف من %s كلمات" % Arabic.eastern_digits(opened))
		Tools.Kind.CHART:
			# The only tool that waits. It stays armed until a cell is chosen,
			# because it was paid for and a player who looks away keeps it.
			grid.picking = true
			_say("اختر خانة")
		Tools.Kind.WORD:
			var revealed := false
			for entry in level.words:
				var text: String = entry["text"]
				if not grid.is_found(text):
					grid.reveal(text)
					_say("كُشفت %s" % text)
					revealed = true
					break
			if not revealed:
				_say("لم تبقَ كلمة")
	_refresh_chrome()
	if grid.is_solved():
		_finish_level()
	else:
		save()


func _on_cell_picked(cell: Vector2i) -> void:
	grid.reveal_cell(cell)
	_say("كُشف حرف")
	_refresh_chrome()
	if grid.is_solved():
		_finish_level()
	else:
		save()


# --- jumping about, for looking at the curve ---------------------------------

## A bar for hopping straight to where the difficulty changes.
##
## Only in a debug build, so a release cannot show it whatever anyone forgets.
## It lives on its own `CanvasLayer` and never enters `_layout()`: a tool for
## looking at the game must not be able to move the game it is looking at.
##
## It is deliberately plain. Nothing here is a `GlossyPanel` and nothing is
## measured against the 1080 reference, because it is not part of the design and
## should never be mistaken for it.
func _build_jump_bar() -> void:
	if not OS.is_debug_build():
		return
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0, 0, 0, 0.55)
	skin.content_margin_left = 10.0
	skin.content_margin_right = 10.0
	skin.content_margin_top = 4.0
	skin.content_margin_bottom = 4.0
	bar.add_theme_stylebox_override("panel", skin)
	layer.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)

	var back := Button.new()
	back.text = "السابقة"
	back.pressed.connect(func() -> void: _jump(-1))
	row.add_child(back)

	_jump_label = Label.new()
	_jump_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_jump_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_jump_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_jump_label)

	var forward := Button.new()
	forward.text = "التالية"
	forward.pressed.connect(func() -> void: _jump(1))
	row.add_child(forward)
	_refresh_jump_label()


## Where the shape of a level changes, in order. Worked out once, by reading
## every shipped level: the ramp lives in the pipeline, and a copy of it here
## would be a second truth to keep in step.
func _difficulty_steps() -> PackedStringArray:
	if not _jump_steps.is_empty():
		return _jump_steps
	var previous := Vector2i(-1, -1)
	for mansion in Mansions.SHIPPED:
		for index in Mansions.LEVELS_PER_MANSION:
			var id := Mansions.level_id(mansion + 1, index + 1)
			var candidate := _level_by_id(id)
			if candidate == null:
				continue
			var shape := Vector2i(candidate.letters.size(), candidate.words.size())
			if shape != previous:
				_jump_steps.append(id)
				previous = shape
	return _jump_steps


func _jump(direction: int) -> void:
	var steps := _difficulty_steps()
	if steps.is_empty() or level == null:
		return
	# Where this level sits among the steps: the last one at or before it.
	var at := 0
	for i in steps.size():
		if steps[i] <= level.id:
			at = i
	var target := clampi(at + direction, 0, steps.size() - 1)
	# Already standing on a step, so a nudge forward means the next one.
	if steps[at] != level.id and direction > 0:
		target = mini(at + 1, steps.size() - 1)
	var upcoming := _level_by_id(steps[target])
	if upcoming == null:
		return
	_hide_windows()
	show_level(upcoming)
	save()
	_refresh_jump_label()


func _refresh_jump_label() -> void:
	if _jump_label == null or level == null:
		return
	_jump_label.text = "%s — عجلة %d، كلمات %d" % [
		level.id, level.letters.size(), level.words.size()
	]


## The one entry point for a spelled word. Returns what happened.
func submit(raw: String) -> int:
	var word := Arabic.normalise(raw)
	var result := _classify(word)
	var finished := false
	var spent_last := false
	match result:
		Result.CORRECT:
			grid.reveal(word)
			_say("كلمة صحيحة")
			if grid.is_solved():
				_finish_level()
				finished = true
		Result.ALREADY_FOUND:
			grid.nudge(word)
			_say("وجدتها سابقاً")
		Result.BONUS:
			_bonus_found[word] = true
			moon = mini(moon + 1, MOON_PHASES)
			# The payout is state, so it lands on the guess. Waiting for the
			# star to arrive would put half a second between earning the coins
			# and owning them, and the save at the end of this call happens
			# inside that gap.
			if moon >= MOON_PHASES:
				coins += MOON_REWARD
				moon = 0
				_full_moon_pending = true
			_celebrate_bonus(word)
		Result.BONUS_REPEAT:
			_flash_preview(word)
		Result.KNOWN:
			# It costs nothing and earns nothing. The player spelled real Arabic;
			# this level simply does not want it, and saying «ليست كلمة» to
			# «نسر» would be the game being wrong rather than being hard.
			_say("كلمة صحيحة، ليست من هذه المرحلة")
		Result.INVALID:
			wrong_streak += 1
			if wrong_streak >= WRONG_STREAK_COST:
				wrong_streak = 0
				# The daily challenge costs no lantern, which is a promise its
				# window makes in so many words.
				if not daily:
					lanterns = maxi(lanterns - 1, 0)
				_say("انطفأ فانوس" if not daily else "خمس محاولات خاطئة")
				# The clock starts on the first lantern lost, not on the last:
				# a player who is down to four is already waiting for one back.
				if _lantern_clock <= 0:
					_lantern_clock = (
						int(Time.get_unix_time_from_system()) + LANTERN_REGEN_SECONDS
					)
				spent_last = lanterns <= 0
			else:
				_say("ليست كلمة")
		Result.TOO_SHORT:
			pass
	_refresh_chrome()
	# After every guess, not on the way out: a swipe-away never reaches a quit
	# handler, and a run of wrong guesses that a quit erases costs nothing.
	#
	# Except on the guess that ends the level. _finish_level() has already
	# written the save that points at the next one; saving this moment over it
	# would reopen the game on a solved grid with no window and no way forward.
	if result != Result.TOO_SHORT and not finished:
		save()
	if spent_last and not daily:
		show_out_of_lanterns()
	word_resolved.emit(word, result)
	return result


func _classify(word: String) -> int:
	if word.length() < 2:
		return Result.TOO_SHORT
	if level.has_grid_word(word):
		return Result.ALREADY_FOUND if grid.is_found(word) else Result.CORRECT
	if level.is_bonus(word):
		return Result.BONUS_REPEAT if _bonus_found.has(word) else Result.BONUS
	if level.is_known(word):
		return Result.KNOWN
	return Result.INVALID


# --- what a found word looks like ------------------------------------------

## A bonus word is a light found outside the figure, so it goes to the moon
## rather than to the mansion's stars. The word itself is never written down:
## the player just spelled it and knows it; what they need to see is its effect.
func _celebrate_bonus(word: String) -> void:
	var s := _scale()
	preview.text = word
	preview.add_theme_color_override("font_color", Color("4A3A08"))
	_preview_pill.style = GlossyPanel.Style.TILE_GOLD
	_preview_pill.modulate.a = 1.0
	_place_preview_pill()

	var from := _preview_pill.position + _preview_pill.size * 0.5
	var to := hud.position + hud.moon_icon_centre()

	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(_fly_star.bind(from, to))
	tween.tween_interval(0.12)
	tween.tween_property(_preview_pill, "modulate:a", 0.0, 0.16)
	tween.tween_callback(_clear_preview)


## Already found: one gold blink, no star, no counter. The difference between
## "you found it" and "you found it a minute ago" has to read without reading.
func _flash_preview(word: String) -> void:
	preview.text = word
	preview.add_theme_color_override("font_color", Color("4A3A08"))
	_preview_pill.style = GlossyPanel.Style.TILE_GOLD
	_preview_pill.modulate.a = 1.0
	_place_preview_pill()
	var tween := create_tween()
	tween.tween_interval(0.22)
	tween.tween_property(_preview_pill, "modulate:a", 0.0, 0.12)
	tween.tween_callback(_clear_preview)


func _clear_preview() -> void:
	preview.text = ""
	preview.add_theme_color_override("font_color", Palette.CREAM)
	_preview_pill.style = GlossyPanel.Style.PILL_RIVER
	_preview_pill.modulate.a = 1.0
	_place_preview_pill()


func _fly_star(from: Vector2, to: Vector2) -> void:
	var s := _scale()
	var star := UiIcon.new()
	star.kind = UiIcon.Kind.STAR
	var side := 50.0 * s
	star.size = Vector2(side, side)
	star.position = from - star.size * 0.5
	add_child(star)

	# A curve, not a ruled line: it bends away from the straight path so the
	# star looks thrown rather than dragged.
	var bend := (from + to) * 0.5 + Vector2(-70.0 * s, -30.0 * s)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			var inverse := 1.0 - t
			var at := inverse * inverse * from + 2.0 * inverse * t * bend + t * t * to
			star.position = at - star.size * 0.5,
		0.0, 1.0, 0.4
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		star.queue_free()
		_land_star(to)
	)


func _land_star(at: Vector2) -> void:
	# The chip shows the moon full for a beat before it empties, even though the
	# coins were paid half a second ago.
	_moon_shown = MOON_PHASES if _full_moon_pending else moon
	_refresh_chrome()
	hud.punch_moon()
	_float_gain(at, "+%s" % Arabic.eastern_digits(1))
	if _full_moon_pending:
		_full_moon_pending = false
		_show_full_moon(at)


## A small number that rises off a chip and fades, for a gain too small to
## deserve a toast.
func _float_gain(at: Vector2, text: String) -> void:
	var s := _scale()
	var label := _make_label(UI_BOLD_FONT, Palette.GOLD_LIGHT)
	label.text = text
	label.size = Vector2(160.0 * s, 48.0 * s)
	label.position = at - label.size * 0.5
	label.add_theme_font_size_override("font_size", int(34.0 * s))
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0 * s, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(label.queue_free)


## The rings and the toast for a moon that just filled. The coins and the reset
## already happened, back in submit(); this is only the part that catches up.
func _show_full_moon(at: Vector2) -> void:
	_burst(at)
	_say("اكتمل البدر — +%s" % Arabic.eastern_digits(MOON_REWARD))
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void:
		_moon_shown = moon
		_refresh_chrome()
	)


## Two rings of light widening out of a point and fading.
func _burst(at: Vector2) -> void:
	var s := _scale()
	for index in 2:
		var ring := UiIcon.new()
		ring.kind = UiIcon.Kind.STAR
		ring.modulate = Color(Palette.GOLD_LIGHT, 0.0)
		var side := 90.0 * s
		ring.size = Vector2(side, side)
		ring.pivot_offset = ring.size * 0.5
		ring.position = at - ring.size * 0.5
		add_child(ring)
		var tween := ring.create_tween()
		tween.tween_interval(0.09 * float(index))
		var grow := tween.parallel()
		grow.tween_property(ring, "scale", Vector2(3.4, 3.4), 0.6)
		grow.tween_property(ring, "modulate:a", 0.0, 0.6).from(0.55)
		tween.chain().tween_callback(ring.queue_free)


# --- windows -----------------------------------------------------------------

## Opens one window and makes sure no other is in the way. Laying out first
## matters: a window whose body just changed is a different height, and opening
## it before the stack is rebuilt shows it mid-resize.
func _open(window: SkyWindow) -> void:
	_hide_windows()
	_layout_windows(_scale())
	window.open()


func _hide_windows() -> void:
	for window: SkyWindow in [
		complete_window, lanterns_window, restart_window, hints_window, mansion_window
	]:
		if window != null:
			window.visible = false


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_restart_pressed() -> void:
	_open(restart_window)


func _on_cancel_restart() -> void:
	restart_window.close()


func _on_confirm_restart() -> void:
	restart_window.close()
	restart_level()


## Puts the level back the way it started. The lanterns and the coins are not
## touched: starting over is not the same as skipping, and the window says so.
func restart_level() -> void:
	if level == null:
		return
	show_level(level)
	save()
	_say("بدأ المستوى من جديد")


func _on_menu_pressed() -> void:
	_hide_windows()
	# Leaving a finished level is accepting it. Without this the screen keeps
	# the solved grid, the map still points at the level just played, and
	# carrying on reopens a level the player already finished. Only "next"
	# advanced, and "next" is not the only door out of that window.
	move_on_if_finished()
	menu_requested.emit()


## Steps to the next level when this one is done, wherever the player is
## leaving from. False at the end of the year, and on a level still being
## played, so calling it twice costs nothing.
func move_on_if_finished() -> bool:
	if daily or level == null or not grid.is_solved():
		return false
	var next := next_level_id()
	if next.is_empty():
		return false
	var upcoming := _level_by_id(next)
	if upcoming == null:
		return false
	show_level(upcoming)
	save()
	return true


## The window that ends a run. It has no cross: the ways out of it are to refill
## or to leave, and both are on it.
func show_out_of_lanterns() -> void:
	if _lantern_clock <= 0:
		_lantern_clock = int(Time.get_unix_time_from_system()) + LANTERN_REGEN_SECONDS
	_refresh_clock()
	_open(lanterns_window)
	set_process(true)


func _on_refill_pressed() -> void:
	if not refill_lanterns():
		_say("العملات لا تكفي")


func refill_lanterns() -> bool:
	if coins < LANTERN_REFILL_COST:
		return false
	coins -= LANTERN_REFILL_COST
	lanterns = LANTERNS_MAX
	_lantern_clock = 0
	_refresh_chrome()
	lanterns_window.close()
	set_process(false)
	save()
	return true


## Hands back any lanterns earned since the clock last ran, including the ones
## earned while the game was closed: the clock is a moment in time, not a
## countdown that only ticks while someone is watching.
func _tick_lanterns() -> void:
	if _lantern_clock <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	while _lantern_clock > 0 and now >= _lantern_clock and lanterns < LANTERNS_MAX:
		lanterns += 1
		_lantern_clock += LANTERN_REGEN_SECONDS
	if lanterns >= LANTERNS_MAX:
		_lantern_clock = 0
	_refresh_chrome()


func _refresh_clock() -> void:
	var label: Label = _clock_strip.get_meta("label")
	if _lantern_clock <= 0:
		label.text = "الفوانيس ممتلئة"
		return
	var left := maxi(_lantern_clock - int(Time.get_unix_time_from_system()), 0)
	var seconds := Arabic.eastern_digits(left % 60)
	if left % 60 < 10:
		seconds = Arabic.eastern_digits(0) + seconds
	label.text = "يعود فانوس بعد %s:%s" % [Arabic.eastern_digits(left / 60), seconds]


# --- moving between levels ---------------------------------------------------

## Everything drawn on the sky. The sky itself is not in the list: it never
## moves, which is what makes the game read as one place.
func _content_nodes() -> Array[Control]:
	return [
		caption, stars, toast, grid, preview, _preview_pill, wheel,
		hud, hint_button, shuffle_button, _hint_cost,
	]


func _fade_content(to: float, seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	for node in _content_nodes():
		tween.tween_property(node, "modulate:a", to, seconds)


func _on_next_pressed() -> void:
	var next := next_level_id()
	if next.is_empty():
		_say("انتهت السنة")
		return
	_pending_level = _level_by_id(next)
	if _pending_level == null:
		_say("المستوى التالي غير موجود")
		return
	_hide_windows()
	finale.visible = false
	wipe.play()
	_fade_content(0.0, MeteorWipe.DURATION * 0.45)


func _onwipe_swap() -> void:
	if _pending_level == null:
		return
	show_level(_pending_level)
	_pending_level = null
	save()
	for node in _content_nodes():
		node.modulate.a = 0.0
	_fade_content(1.0, MeteorWipe.DURATION * 0.45)


func _finish_level() -> void:
	if daily:
		# Nothing here belongs to the journey: no reward, no star, no save, and
		# no next level. The shell settles the day and puts the journey back.
		daily_finished.emit()
		return
	coins += LEVEL_REWARD
	stars.light_next()
	_refresh_chrome()
	if level.index_in_mansion >= STARS_PER_MANSION:
		_finish_mansion()
		return
	complete_window.set_body("%s · النجمة %s من %s" % [
		level.mansion_name,
		Arabic.eastern_digits(level.index_in_mansion),
		Arabic.eastern_digits(STARS_PER_MANSION),
	])
	_complete_stars.setup(STARS_PER_MANSION, level.index_in_mansion)
	(_complete_reward.get_meta("label") as Label).text = (
		"+%s" % Arabic.eastern_digits(LEVEL_REWARD)
	)
	_open(complete_window)
	_save_ahead()
	level_solved.emit()


## The save points at the next level with a clean slate, so closing the game at
## the completion window and reopening it starts the next one rather than
## replaying this one.
func _save_ahead() -> void:
	var next := next_level_id()
	if next.is_empty() or progress_path.is_empty():
		return
	var ahead := Progress.new()
	ahead.level_id = next
	ahead.coins = coins
	ahead.lanterns = lanterns
	ahead.moon = moon
	ahead.tools = tools.duplicate()
	ahead.daily_streak = daily_streak
	ahead.daily_day = daily_day
	ahead.write(progress_path)


## The twentieth star of a mansion: the board goes, the figure writes itself,
## and the name gathers out of stardust. The card comes after, not over it.
func _finish_mansion() -> void:
	coins += MANSION_REWARD
	_refresh_chrome()
	_save_ahead()
	level_solved.emit()
	_fade_content(0.0, 0.45)
	finale.position = Vector2.ZERO
	finale.size = size
	finale.play(level.mansion)


func _show_mansion_card() -> void:
	if level == null:
		return
	var mansion := level.mansion
	_mansion_name.text = Mansions.name_of(mansion)
	# The season first, so the middle dot never lands beside the number.
	mansion_window.set_body("%s · المنزلة %s" % [
		Mansions.season_name(Mansions.season_of(mansion)),
		Arabic.eastern_digits(mansion),
	])
	_mansion_figure.figure = Mansions.figure_of(mansion)
	_mansion_line.show_mansion(mansion)
	_open(mansion_window)


# --- saving ------------------------------------------------------------------

## Everything worth keeping about this moment, level included.
func capture() -> Progress:
	var snapshot := Progress.new()
	snapshot.level_id = level.id if level != null else ""
	snapshot.coins = coins
	snapshot.lanterns = lanterns
	snapshot.wrong_streak = wrong_streak
	snapshot.moon = moon
	snapshot.lantern_clock = _lantern_clock
	snapshot.tools = tools.duplicate()
	snapshot.daily_streak = daily_streak
	snapshot.daily_day = daily_day
	for word in level.word_texts():
		if grid.is_found(word):
			snapshot.found.append(word)
	for word in _bonus_found:
		snapshot.bonus_found.append(word)
	snapshot.revealed = grid.hinted_cells()
	return snapshot


## Puts a snapshot back on the screen. The level must already be showing.
func restore(saved: Progress) -> void:
	if level == null or saved.level_id != level.id:
		return
	coins = saved.coins
	lanterns = saved.lanterns
	wrong_streak = saved.wrong_streak
	moon = saved.moon
	_moon_shown = saved.moon
	_lantern_clock = saved.lantern_clock
	tools = saved.tools.duplicate()
	daily_streak = saved.daily_streak
	daily_day = saved.daily_day
	# Lanterns keep coming back while the game is shut, so a returning player
	# collects the wait they already served rather than starting it again.
	_tick_lanterns()
	for word in saved.found:
		grid.reveal(word, false)
	for cell in saved.revealed:
		grid.reveal_cell(cell, false)
	for word in saved.bonus_found:
		_bonus_found[word] = true
	_refresh_chrome()


func save() -> void:
	if daily:
		return
	if progress_path.is_empty() or level == null:
		return
	capture().write(progress_path)


func _notification(what: int) -> void:
	# A backstop only. Saving after every guess is what actually defends the
	# lantern count; a force quit never reaches these.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save()


## The lantern at `index`, counting from the right. For tests and for tweens.
func lantern_icon(index: int) -> UiIcon:
	return hud.lantern_icon(index) if hud != null else null


func bonus_found_count() -> int:
	return _bonus_found.size()


func _refresh_chrome() -> void:
	if hud == null:
		return
	hud.coins = coins
	hud.lanterns = lanterns
	# `_moon_shown`, not `moon`: the chip waits for the flying star to land.
	hud.moon = _moon_shown


func _say(message: String) -> void:
	toast.text = message
	_toast_until = float(Time.get_ticks_msec()) / 1000.0 + TOAST_SECONDS
	set_process(true)


## Two jobs share the frame clock: clearing a toast once its moment is up, and
## counting the wait down while the out-of-lanterns window is open. It switches
## itself off when neither wants it, because the project runs in low-processor
## mode and nothing else on this screen needs a tick.
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var wanted := false

	if not toast.text.is_empty():
		if float(Time.get_ticks_msec()) / 1000.0 >= _toast_until:
			toast.text = ""
		else:
			wanted = true

	if lanterns_window != null and lanterns_window.visible:
		_tick_lanterns()
		_refresh_clock()
		if lanterns > 0:
			lanterns_window.close()
			save()
		else:
			wanted = true

	if not wanted:
		set_process(false)
