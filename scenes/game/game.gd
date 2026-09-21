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

enum Result {
	CORRECT,  ## a grid word, found for the first time
	ALREADY_FOUND,  ## a grid word found earlier: pulse it, score nothing
	BONUS,  ## a valid word outside the grid: fills the moon
	BONUS_REPEAT,
	INVALID,  ## not a word: five in a row costs a lantern
	TOO_SHORT,  ## one letter or none: ignored entirely
}

const LANTERNS_MAX := 5
const MOON_PHASES := 8
const WRONG_STREAK_COST := 5
const LEVEL_REWARD := 45
const HINT_COST := 50
const MOON_REWARD := 30
const LANTERN_REFILL_COST := 100
## How long one lantern takes to come back on its own.
const LANTERN_REGEN_SECONDS := 1800
const TOAST_SECONDS := 1.1

## Design metrics, in the 1080-wide reference space; scaled by `_scale`.
const REF_WIDTH := 1080.0
const CELL := 124.0
const CELL_GAP := 16.0
const WHEEL_BODY := 277.0
const WHEEL_ORBIT := 163.0
const TILE_RADIUS := 80.0
const PREVIEW_SIZE := 100.0
const PREVIEW_PILL_HEIGHT := 144.0
const PREVIEW_PILL_MIN := 366.0
const PREVIEW_PILL_PAD := 72.0
const WHEEL_MARGIN := 62.0
const CHIP_HEIGHT := 92.0
const GRID_MARGIN := 60.0
const STARS_PER_MANSION := 20
const MANSION_COUNT := 28
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
	resized.connect(_layout)

	# Pick up where the player left off, in the middle of a level if that is
	# where they were.
	var saved: Progress = null
	var first: Level = null
	if not progress_path.is_empty():
		saved = Progress.read(progress_path)
		first = _level_by_id(saved.level_id)
	if first == null:
		saved = null
		first = Level.load_from(level_path)
	if first == null:
		push_error("Game: no level to play")
		return
	show_level(first)
	if saved != null:
		restore(saved)


func _level_by_id(id: String) -> Level:
	if id.is_empty():
		return null
	return Level.load_from("res://data/levels/%s.json" % id)


## The level after this one, or "" at the end of the year.
func next_level_id() -> String:
	if level == null:
		return ""
	var mansion := level.mansion
	var index := level.index_in_mansion + 1
	if index > STARS_PER_MANSION:
		mansion += 1
		index = 1
	if mansion > MANSION_COUNT:
		return ""
	return "m%02d-%02d" % [mansion, index]


## Puts a level on the screen and clears everything that belongs to the last one.
## This is the seam progression will use: the next level arrives through here.
func show_level(new_level: Level) -> void:
	level = new_level
	for problem in level.validate():
		push_error("Level %s: %s" % [level.id, problem])

	_bonus_found.clear()
	wrong_streak = 0
	_hide_windows()

	grid.setup(level)
	wheel.body_radius = WHEEL_BODY
	wheel.orbit_radius = WHEEL_ORBIT
	wheel.tile_radius = TILE_RADIUS
	wheel.setup(level.letters)
	stars.setup(STARS_PER_MANSION, level.index_in_mansion - 1)

	caption.text = "المنزلة %s · %s · النجمة %s من %s" % [
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
		"املأ الفوانيس · %s" % Arabic.eastern_digits(LANTERN_REFILL_COST),
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
	wheel.body_radius = WHEEL_BODY * s
	wheel.orbit_radius = WHEEL_ORBIT * s
	wheel.tile_radius = TILE_RADIUS * s
	var span := wheel.body_radius * 2.0
	wheel.size = Vector2(span, span)
	wheel.position = Vector2((size.x - span) * 0.5, size.y - span - WHEEL_MARGIN * s)

	preview.add_theme_font_size_override("font_size", int(PREVIEW_SIZE * s))
	preview.size = Vector2(size.x, PREVIEW_SIZE * s)
	preview.position = Vector2(0.0, wheel.position.y - 14.0 * s - preview.size.y)
	_place_preview_pill()

	# The header is anchored to the top of the screen.
	caption.position = Vector2(0.0, 186.0 * s)
	caption.size = Vector2(size.x, 56.0 * s)
	caption.add_theme_font_size_override("font_size", int(34.0 * s))

	stars.position = Vector2(70.0 * s, 250.0 * s)
	stars.size = Vector2(size.x - 140.0 * s, 150.0 * s)

	toast.add_theme_font_size_override("font_size", int(36.0 * s))
	toast.size = Vector2(size.x, 60.0 * s)

	# The grid gets whatever is left between the header and the preview, and
	# sits in the middle of it. Chaining it straight to the preview instead
	# would pin it to the bottom of that gap whenever the grid is short.
	var band_top := stars.position.y + stars.size.y + 12.0 * s + toast.size.y + 12.0 * s
	var band_bottom := preview.position.y - 20.0 * s

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
	for window: SkyWindow in [complete_window, lanterns_window, restart_window]:
		window.position = Vector2.ZERO
		window.size = size
		# relayout() stacks the parts and sizes the panel, so it has to run
		# before anything reads a row's size.
		window.relayout(s)

	_layout_pair_row(_complete_reward, s, 150.0, 62.0, 44.0)
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


func _on_hint_pressed() -> void:
	var cell := grid.hint_cell()
	if cell.x < 0:
		_say("لا شيء يحتاج تلميحاً")
		return
	if coins < HINT_COST:
		_say("العملات لا تكفي")
		return
	coins -= HINT_COST
	grid.reveal_cell(cell)
	_refresh_chrome()
	_say("كُشف حرف")
	if grid.is_solved():
		_finish_level()
	else:
		save()


## The one entry point for a spelled word. Returns what happened.
func submit(raw: String) -> int:
	var word := Arabic.normalise(raw)
	var result := _classify(word)
	var finished := false
	var spent_last := false
	match result:
		Result.CORRECT:
			grid.reveal(word)
			wrong_streak = 0
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
			wrong_streak = 0
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
		Result.INVALID:
			wrong_streak += 1
			if wrong_streak >= WRONG_STREAK_COST:
				wrong_streak = 0
				lanterns = maxi(lanterns - 1, 0)
				_say("انطفأ فانوس")
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
	if spent_last:
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
	_say("اكتمل البدر · +%s" % Arabic.eastern_digits(MOON_REWARD))
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
	for window: SkyWindow in [complete_window, lanterns_window, restart_window]:
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
	menu_requested.emit()


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
	complete_window.close()
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
	coins += LEVEL_REWARD
	stars.light_next()
	_refresh_chrome()
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
	# The save now points at the next level with a clean slate, so closing the
	# game here and reopening it starts the next one rather than replaying this.
	# Moving the screen there needs the level-complete screen first.
	var next := next_level_id()
	if not next.is_empty() and not progress_path.is_empty():
		var ahead := Progress.new()
		ahead.level_id = next
		ahead.coins = coins
		ahead.lanterns = lanterns
		ahead.moon = moon
		ahead.write(progress_path)
	level_solved.emit()


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
