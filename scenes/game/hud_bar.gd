class_name HudBar
extends Control
## The counters across the top of every screen: lanterns, coins and the moon,
## with the round utility buttons opposite them.
##
## One object because three screens show the same three numbers. A bar built
## three times drifts three ways, and the numbers are the first thing a player
## looks at on any of them.
##
## The owner gives it the full screen width and `CHIP_HEIGHT * scale` of height;
## everything inside is laid out from those.

const LANTERNS_MAX := 5
## Reference units, in the 1080-wide space, same as the screens.
const CHIP_HEIGHT := 92.0
const MARGIN := 60.0
const GAP := 18.0
const UTIL := 88.0

var lanterns: int = LANTERNS_MAX:
	set(value):
		lanterns = value
		_refresh()

var coins: int = 0:
	set(value):
		coins = value
		_refresh()

var moon: int = 0:
	set(value):
		moon = value
		_refresh()

var moon_phases: int = 8

var _font: Font
var _chip_lanterns: GlossyPanel
var _chip_coins: GlossyPanel
var _chip_moon: GlossyPanel
var _coin_label: Label
var _moon_label: Label
var _moon_icon: UiIcon
var _lamps: Array[UiIcon] = []
var _utilities: Array[GlossyPanel] = []


func configure(font: Font) -> void:
	_font = font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_chip_lanterns = _chip()
	for i in LANTERNS_MAX:
		var lamp := UiIcon.new()
		lamp.kind = UiIcon.Kind.LANTERN
		_chip_lanterns.add_child(lamp)
		_lamps.append(lamp)

	_chip_coins = _chip()
	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	_chip_coins.add_child(coin)
	_chip_coins.set_meta("icon", coin)
	_coin_label = _label()
	_chip_coins.add_child(_coin_label)

	_chip_moon = _chip()
	_moon_icon = UiIcon.new()
	_moon_icon.kind = UiIcon.Kind.MOON
	_chip_moon.add_child(_moon_icon)
	_moon_label = _label()
	_chip_moon.add_child(_moon_label)

	_refresh()


## Round buttons sit at the reading start, which in Arabic is the right, in the
## order they are added: the first one added is the furthest out.
func add_utility(icon_kind: int, handler: Callable, label_text: String) -> GlossyPanel:
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

	_utilities.append(panel)
	return panel


## The lantern at `index`, counting from the right. For tests and for tweens.
func lantern_icon(index: int) -> UiIcon:
	return _lamps[index] if index >= 0 and index < _lamps.size() else null


## Where the moon chip's face sits, in the bar's own space. The star a bonus
## word throws flies to this point, so the bar has to answer for it rather than
## the screen guessing where its own chip ended up.
func moon_icon_centre() -> Vector2:
	if _chip_moon == null:
		return Vector2.ZERO
	return _chip_moon.position + _moon_icon.position + _moon_icon.size * 0.5


## The chip's flinch when the star lands on it.
func punch_moon() -> void:
	if _chip_moon == null:
		return
	_chip_moon.pivot_offset = _chip_moon.size * 0.5
	var punch := _chip_moon.create_tween()
	punch.tween_property(_chip_moon, "scale", Vector2(1.2, 1.2), 0.08)
	punch.tween_property(_chip_moon, "scale", Vector2.ONE, 0.1)


func _chip() -> GlossyPanel:
	var panel := GlossyPanel.new()
	panel.style = GlossyPanel.Style.CHIP
	add_child(panel)
	return panel


func _label() -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Palette.TILE_INK)
	if _font != null:
		label.add_theme_font_override("font", _font)
	return label


func _refresh() -> void:
	if _coin_label == null:
		return
	_coin_label.text = Arabic.eastern_digits(coins)
	_moon_label.text = "%s / %s" % [
		Arabic.eastern_digits(moon), Arabic.eastern_digits(moon_phases)
	]
	_moon_icon.level = float(moon) / float(maxi(moon_phases, 1))
	for i in _lamps.size():
		_lamps[i].level = 1.0 if i < lanterns else 0.0


func relayout(s: float) -> void:
	if _chip_lanterns == null:
		return
	var height := CHIP_HEIGHT * s
	var margin := MARGIN * s
	var gap := GAP * s
	var font_size := int(34.0 * s)
	var icon := 46.0 * s

	# The utility buttons take the reading start; the counters sit opposite
	# them, lanterns first, then coins, then the moon.
	var util := UTIL * s
	var util_top := (height - util) * 0.5
	for i in _utilities.size():
		_place_util(_utilities[i], size.x - margin - util * float(i + 1) - gap * float(i),
			util_top, util, s)

	var lantern_pitch := 44.0 * s
	var lantern_width := lantern_pitch * LANTERNS_MAX + 30.0 * s
	var coin_width := 196.0 * s
	var moon_width := 156.0 * s

	var x := margin + moon_width + gap + coin_width + gap
	_chip_lanterns.position = Vector2(x, 0.0)
	_chip_lanterns.size = Vector2(lantern_width, height)
	var face := _chip_lanterns.face_height()
	for i in _lamps.size():
		# The lantern art is two units wide to three tall, as the design draws it.
		var lamp_width := minf(icon * (2.0 / 3.0), lantern_pitch - 6.0 * s)
		_lamps[i].size = Vector2(lamp_width, icon)
		_lamps[i].position = Vector2(
			lantern_width - 15.0 * s - float(i + 1) * lantern_pitch
				+ (lantern_pitch - lamp_width) * 0.5,
			(face - icon) * 0.5
		)

	_place_chip(_chip_coins, margin + moon_width + gap, coin_width, height, icon, font_size,
		_coin_label, _chip_coins.get_meta("icon"))
	_place_chip(_chip_moon, margin, moon_width, height, icon, font_size,
		_moon_label, _moon_icon)


func _place_chip(
	chip: GlossyPanel, x: float, width: float, height: float, icon: float,
	font_size: int, label: Label, art: UiIcon
) -> void:
	chip.position = Vector2(x, 0.0)
	chip.size = Vector2(width, height)
	var face := chip.face_height()
	art.size = Vector2(icon, icon)
	art.position = Vector2(width - icon - 16.0 * (height / CHIP_HEIGHT), (face - icon) * 0.5)
	label.size = Vector2(width - icon - 30.0 * (height / CHIP_HEIGHT), face)
	label.position = Vector2(8.0 * (height / CHIP_HEIGHT), 0.0)
	label.add_theme_font_size_override("font_size", font_size)


func _place_util(panel: GlossyPanel, x: float, top: float, side: float, s: float) -> void:
	panel.position = Vector2(x, top)
	panel.size = Vector2(side, side)
	panel.edge_override = 8.0 * s
	panel.radius_override = side * 0.5
	var icon: UiIcon = panel.get_meta("icon")
	var art := side * 0.52
	icon.size = Vector2(art, art)
	icon.position = Vector2((side - art) * 0.5, (panel.face_height() - art) * 0.5)
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)
