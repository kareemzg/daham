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
var _sky: GradientTexture2D

var _chip_coins: GlossyPanel
var _chip_moon: GlossyPanel
var _chip_lanterns: GlossyPanel
var _coin_label: Label
var _moon_label: Label
var _moon_icon: UiIcon
var _lantern_icons: Array[UiIcon] = []
var _sky_stars: StarField
var _preview_pill: GlossyPanel
## Public so tests and future screens can drive them.
var popup: SkyPopup
var wipe: MeteorWipe
var _complete_title: Label
var _complete_line: Label
var _complete_reward: Label
var next_button: GlossyPanel
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
var _hint_cost: GlossyPanel

@onready var stars: StarBand = $StarBand
@onready var grid: WordGrid = $Grid
@onready var wheel: LetterWheel = $Wheel
@onready var caption: Label = $Caption
@onready var preview: Label = $Preview
@onready var toast: Label = $Toast


func _ready() -> void:
	_sky = _make_sky()
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
	popup.visible = false

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


func _make_sky() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Palette.SKY_TOP, Palette.SKY_MID, Palette.SKY_LOW, Palette.SKY_BOTTOM
	])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture


# --- building the chrome -----------------------------------------------------

func _build_chrome() -> void:
	# Nodes built here are never given an `owner`, so they are not written into
	# the scene file. Clearing them first keeps an editor script reload from
	# stacking a second set on top of the first.
	for child in get_children():
		if child.owner == null:
			child.queue_free()
	_lantern_icons.clear()

	# Behind everything, including the scene's own nodes.
	_sky_stars = StarField.new()
	add_child(_sky_stars)
	move_child(_sky_stars, 0)

	_chip_lanterns = _make_chip()
	for i in LANTERNS_MAX:
		var lamp := UiIcon.new()
		lamp.kind = UiIcon.Kind.LANTERN
		_chip_lanterns.add_child(lamp)
		_lantern_icons.append(lamp)

	_chip_moon = _make_chip()
	_moon_icon = UiIcon.new()
	_moon_icon.kind = UiIcon.Kind.MOON
	_chip_moon.add_child(_moon_icon)
	_moon_label = _make_label(UI_BOLD_FONT, Palette.TILE_INK)
	_chip_moon.add_child(_moon_label)

	_chip_coins = _make_chip()
	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	_chip_coins.add_child(coin)
	_coin_label = _make_label(UI_BOLD_FONT, Palette.TILE_INK)
	_chip_coins.add_child(_coin_label)

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

	popup = SkyPopup.new()
	add_child(popup)
	_build_complete_panel()

	wipe = MeteorWipe.new()
	add_child(wipe)
	wipe.swap.connect(_onwipe_swap)


## The one window the game has so far: what you see when a level is done.
func _build_complete_panel() -> void:
	_complete_title = _make_label(DISPLAY_FONT, Palette.TILE_INK)
	_complete_title.text = "اكتمل المستوى"
	popup.panel.add_child(_complete_title)

	var star := UiIcon.new()
	star.kind = UiIcon.Kind.STAR
	popup.panel.add_child(star)
	popup.panel.set_meta("star", star)

	_complete_line = _make_label(UI_BOLD_FONT, Color("6B5942"))
	popup.panel.add_child(_complete_line)

	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	popup.panel.add_child(coin)
	popup.panel.set_meta("coin", coin)

	_complete_reward = _make_label(UI_BOLD_FONT, Color("4A3A08"))
	popup.panel.add_child(_complete_reward)

	next_button = GlossyPanel.new()
	next_button.style = GlossyPanel.Style.BUTTON_EMBER
	popup.panel.add_child(next_button)
	var label := _make_label(UI_BOLD_FONT, Color("FFF4E8"))
	label.text = "التالي"
	next_button.add_child(label)
	next_button.set_meta("label", label)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_on_next_pressed)
	button.button_down.connect(func() -> void: next_button.set_pressed(true))
	button.button_up.connect(func() -> void: next_button.set_pressed(false))
	next_button.add_child(button)
	next_button.set_meta("button", button)


func _make_chip() -> GlossyPanel:
	var chip := GlossyPanel.new()
	chip.style = GlossyPanel.Style.CHIP
	add_child(chip)
	return chip


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
	if level == null or _chip_coins == null:
		return
	var s := _scale()

	_sky_stars.position = Vector2.ZERO
	_sky_stars.size = size

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
	popup.position = Vector2.ZERO
	popup.size = size
	_layout_complete_panel(s)
	queue_redraw()


func _layout_complete_panel(s: float) -> void:
	var panel := popup.panel
	panel.size = Vector2(760.0 * s, 720.0 * s)
	panel.edge_override = 12.0 * s
	panel.radius_override = 52.0 * s
	var face := panel.face_height()

	_complete_title.position = Vector2(0.0, 48.0 * s)
	_complete_title.size = Vector2(panel.size.x, 70.0 * s)
	_complete_title.add_theme_font_size_override("font_size", int(58.0 * s))

	var star: UiIcon = panel.get_meta("star")
	var star_side := 210.0 * s
	star.size = Vector2(star_side, star_side)
	star.position = Vector2((panel.size.x - star_side) * 0.5, 140.0 * s)

	_complete_line.position = Vector2(0.0, 372.0 * s)
	_complete_line.size = Vector2(panel.size.x, 46.0 * s)
	_complete_line.add_theme_font_size_override("font_size", int(30.0 * s))

	# The number and the coin read as one thing, so they are centred as one and
	# the number hugs the coin instead of floating in its own box.
	var coin: UiIcon = panel.get_meta("coin")
	var coin_side := 60.0 * s
	var text_width := 150.0 * s
	var pair := text_width + 18.0 * s + coin_side
	var pair_left := (panel.size.x - pair) * 0.5
	_complete_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_complete_reward.position = Vector2(pair_left, 444.0 * s)
	_complete_reward.size = Vector2(text_width, coin_side)
	_complete_reward.add_theme_font_size_override("font_size", int(42.0 * s))
	coin.size = Vector2(coin_side, coin_side)
	coin.position = Vector2(pair_left + text_width + 18.0 * s, 444.0 * s)

	var button_width := 380.0 * s
	var button_height := 108.0 * s
	next_button.position = Vector2((panel.size.x - button_width) * 0.5, face - button_height - 44.0 * s)
	next_button.size = Vector2(button_width, button_height + 14.0 * s)
	next_button.edge_override = 14.0 * s
	next_button.radius_override = button_height * 0.5
	var label: Label = next_button.get_meta("label")
	label.position = Vector2.ZERO
	label.size = Vector2(button_width, button_height)
	label.add_theme_font_size_override("font_size", int(40.0 * s))
	var button: Button = next_button.get_meta("button")
	button.position = Vector2.ZERO
	button.size = next_button.size


func _layout_chips(s: float) -> void:
	var height := CHIP_HEIGHT * s
	var top := 60.0 * s
	var margin := 60.0 * s
	var gap := 18.0 * s
	var font_size := int(34.0 * s)
	var icon := 46.0 * s

	# Right to left: lanterns, then the moon meter, then coins.
	var lantern_pitch := 44.0 * s
	var lantern_width := lantern_pitch * LANTERNS_MAX + 30.0 * s
	var x := size.x - margin - lantern_width
	_chip_lanterns.position = Vector2(x, top)
	_chip_lanterns.size = Vector2(lantern_width, height)
	var face := _chip_lanterns.face_height()
	for i in _lantern_icons.size():
		var lamp: UiIcon = _lantern_icons[i]
		# The lantern art is two units wide to three tall, as the design draws it.
		var lamp_height := icon
		var lamp_width := minf(lamp_height * (2.0 / 3.0), lantern_pitch - 6.0 * s)
		lamp.size = Vector2(lamp_width, lamp_height)
		lamp.position = Vector2(
			lantern_width - 15.0 * s - float(i + 1) * lantern_pitch
				+ (lantern_pitch - lamp_width) * 0.5,
			(face - lamp_height) * 0.5
		)

	var moon_width := 156.0 * s
	x -= gap + moon_width
	_chip_moon.position = Vector2(x, top)
	_chip_moon.size = Vector2(moon_width, height)
	face = _chip_moon.face_height()
	_moon_icon.size = Vector2(icon, icon)
	_moon_icon.position = Vector2(moon_width - icon - 16.0 * s, (face - icon) * 0.5)
	_moon_label.size = Vector2(moon_width - icon - 30.0 * s, face)
	_moon_label.position = Vector2(8.0 * s, 0.0)
	_moon_label.add_theme_font_size_override("font_size", font_size)

	var coin_width := 196.0 * s
	x -= gap + coin_width
	_chip_coins.position = Vector2(x, top)
	_chip_coins.size = Vector2(coin_width, height)
	face = _chip_coins.face_height()
	var coin_icon: UiIcon = _chip_coins.get_child(0)
	coin_icon.size = Vector2(icon, icon)
	coin_icon.position = Vector2(coin_width - icon - 16.0 * s, (face - icon) * 0.5)
	_coin_label.size = Vector2(coin_width - icon - 30.0 * s, face)
	_coin_label.position = Vector2(8.0 * s, 0.0)
	_coin_label.add_theme_font_size_override("font_size", font_size)


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
	var to := _chip_moon.position + _moon_icon.position + _moon_icon.size * 0.5

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
	_chip_moon.pivot_offset = _chip_moon.size * 0.5
	var punch := _chip_moon.create_tween()
	punch.tween_property(_chip_moon, "scale", Vector2(1.2, 1.2), 0.08)
	punch.tween_property(_chip_moon, "scale", Vector2.ONE, 0.1)
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


# --- moving between levels ---------------------------------------------------

## Everything drawn on the sky. The sky itself is not in the list: it never
## moves, which is what makes the game read as one place.
func _content_nodes() -> Array[Control]:
	return [
		caption, stars, toast, grid, preview, _preview_pill, wheel,
		_chip_coins, _chip_moon, _chip_lanterns, hint_button, shuffle_button, _hint_cost,
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
	popup.close()
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
	_complete_line.text = "%s · النجمة %s من %s" % [
		level.mansion_name,
		Arabic.eastern_digits(level.index_in_mansion),
		Arabic.eastern_digits(STARS_PER_MANSION),
	]
	_complete_reward.text = "+%s" % Arabic.eastern_digits(LEVEL_REWARD)
	popup.open()
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
	return _lantern_icons[index] if index < _lantern_icons.size() else null


func bonus_found_count() -> int:
	return _bonus_found.size()


func _refresh_chrome() -> void:
	if _coin_label == null:
		return
	_coin_label.text = Arabic.eastern_digits(coins)
	_moon_label.text = "%s / %s" % [
		Arabic.eastern_digits(_moon_shown), Arabic.eastern_digits(MOON_PHASES)
	]
	_moon_icon.level = float(_moon_shown) / float(MOON_PHASES)
	for i in _lantern_icons.size():
		_lantern_icons[i].level = 1.0 if i < lanterns else 0.0


func _say(message: String) -> void:
	toast.text = message
	_toast_until = float(Time.get_ticks_msec()) / 1000.0 + TOAST_SECONDS
	set_process(true)


func _process(_delta: float) -> void:
	if float(Time.get_ticks_msec()) / 1000.0 >= _toast_until:
		toast.text = ""
		set_process(false)


func _draw() -> void:
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
