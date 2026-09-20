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

const LEVEL_PATH := "res://data/levels/m04-12.json"
const LANTERNS_MAX := 5
const MOON_PHASES := 8
const WRONG_STREAK_COST := 5
const LEVEL_REWARD := 45
const HINT_COST := 50
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
const BUTTON_SIZE := 161.0

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

var level: Level = null
var lanterns: int = LANTERNS_MAX
var coins: int = 480
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
	level = Level.load_from(LEVEL_PATH)
	if level == null:
		push_error("Game: no level to play")
		return
	for problem in level.validate():
		push_error("Level %s: %s" % [level.id, problem])

	grid.cell_size = CELL
	grid.gap = CELL_GAP
	grid.setup(level)
	wheel.body_radius = WHEEL_BODY
	wheel.orbit_radius = WHEEL_ORBIT
	wheel.tile_radius = TILE_RADIUS
	wheel.setup(level.letters)
	stars.setup(20, level.index_in_mansion - 1)

	caption.text = "المنزلة %s · %s · النجمة %s من %s" % [
		Arabic.eastern_digits(level.mansion),
		level.mansion_name,
		Arabic.eastern_digits(level.index_in_mansion),
		Arabic.eastern_digits(20),
	]
	preview.text = ""
	toast.text = ""

	_build_chrome()
	wheel.word_previewed.connect(_on_word_previewed)
	wheel.word_submitted.connect(_on_word_submitted)
	resized.connect(_layout)
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
	grid.cell_size = CELL * s
	grid.gap = CELL_GAP * s
	var grid_extent := grid.grid_size()
	grid.size = grid_extent
	var band_top := stars.position.y + stars.size.y + 12.0 * s + toast.size.y + 12.0 * s
	var band_bottom := preview.position.y - 20.0 * s
	grid.position = Vector2(
		(size.x - grid_extent.x) * 0.5,
		maxf(band_top, band_top + (band_bottom - band_top - grid_extent.y) * 0.5)
	)

	# The toast never lands on the grid: a message over a cell hides the letter
	# the player just earned.
	toast.position = Vector2(0.0, grid.position.y - 12.0 * s - toast.size.y)

	_layout_chips(s)
	_layout_buttons(s)
	queue_redraw()


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
	stars.light_next()
	_refresh_chrome()
	_say("كُشف حرف")
	if grid.is_solved():
		_finish_level()


## The one entry point for a spelled word. Returns what happened.
func submit(raw: String) -> int:
	var word := Arabic.normalise(raw)
	var result := _classify(word)
	match result:
		Result.CORRECT:
			grid.reveal(word)
			stars.light_next()
			wrong_streak = 0
			_say("+%s نجمة" % Arabic.eastern_digits(1))
			if grid.is_solved():
				_finish_level()
		Result.ALREADY_FOUND:
			grid.nudge(word)
			_say("وجدتها سابقاً")
		Result.BONUS:
			_bonus_found[word] = true
			moon = mini(moon + 1, MOON_PHASES)
			wrong_streak = 0
			_say("كلمة إضافية")
		Result.BONUS_REPEAT:
			_say("كلمة إضافية سابقة")
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


func _finish_level() -> void:
	coins += LEVEL_REWARD
	_refresh_chrome()
	_say("اكتمل المستوى · +%s" % Arabic.eastern_digits(LEVEL_REWARD))
	level_solved.emit()


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
		Arabic.eastern_digits(moon), Arabic.eastern_digits(MOON_PHASES)
	]
	_moon_icon.level = float(moon) / float(MOON_PHASES)
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
