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
const FROST_SHADER := preload("res://assets/ui/frost.gdshader")
## The hue each counter takes on the hub, from the same family the dock's
## doors draw on: copper, gold, violet, and a slate for the gear so it does not
## compete with the three readings beside it.
const HUE_LANTERNS := "E89A54"
const HUE_COINS := "F5CE58"
const HUE_MOON := "A98BD6"
## The gear takes `Palette.SLATE`, like every other piece of hub furniture.

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
## Where the last lantern's breathing is in its cycle.
var _pulse: float = 0.0
var _utilities: Array[GlossyPanel] = []
var _copy: BackBufferCopy
var _frost: ColorRect
var _frost_material: ShaderMaterial
var _hair: ColorRect


## A frosted strip behind the chips, so the top of the screen is one surface
## rather than four floating patches — the same pane the dock uses.
##
## Off on the play screen, and that is not an oversight: the teaching level
## brings the counters in one at a time, and a strip would either stand there
## empty before the first one arrives or have to grow with them. The hub has no
## lesson to protect, so the hub is where it is on.
var frosted: bool = false:
	set(value):
		if frosted == value:
			return
		frosted = value
		if _frost != null:
			_frost.visible = value
		if _hair != null:
			_hair.visible = value
		# The two bars speak one language: the dock's doors are tinted tiles
		# with a hard bottom edge, so the counters above are the same tile in
		# the same geometry — only wider, because they carry a reading as well
		# as an icon. Each takes the hue of what it counts.
		for pair: Array in [
			[_chip_lanterns, HUE_LANTERNS], [_chip_coins, HUE_COINS],
			[_chip_moon, HUE_MOON],
		]:
			var chip: GlossyPanel = pair[0]
			if chip == null:
				continue
			chip.style = GlossyPanel.Style.BUTTON_RIVER if value else GlossyPanel.Style.CHIP
			chip.hue = Color(pair[1] as String) if value else Color(0, 0, 0, 0)
		# The faces are light whichever hue they take, so the reading stays dark.
		for label: Label in [_coin_label, _moon_label]:
			if label != null:
				label.add_theme_color_override("font_color", Palette.TILE_INK)
		for panel: GlossyPanel in _utilities:
			panel.style = GlossyPanel.Style.BUTTON_RIVER if value else GlossyPanel.Style.BUTTON_CREAM
			panel.hue = Palette.SLATE if value else Color(0, 0, 0, 0)
		queue_redraw()


func configure(font: Font) -> void:
	_font = font
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_copy = BackBufferCopy.new()
	# The whole viewport, not a rect. `COPY_MODE_RECT` takes its rect in the
	# node's own space and a pane parked at the bottom of the screen copied a
	# region that was never drawn, so the blur sampled black and the pane came
	# out near-opaque whatever its tint said.
	_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(_copy)
	_frost_material = ShaderMaterial.new()
	_frost_material.shader = FROST_SHADER
	_frost = ColorRect.new()
	_frost.material = _frost_material
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost.visible = frosted
	add_child(_frost)
	# The zenith is the darkest part of the sky, so a dark pane over it is
	# invisible. This one is lighter than what it covers, and a hairline along
	# its lower edge is what actually says "a surface ends here".
	_hair = ColorRect.new()
	_hair.color = Color(Palette.MILKY_VIOLET, 0.38)
	_hair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hair.visible = frosted
	add_child(_hair)

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
	# The hub's utilities are tiles like everything else up there. Read here
	# and not only in the setter: a utility is added AFTER the screen has said
	# whether it is frosted, so the setter's loop found an empty list.
	panel.style = (
		GlossyPanel.Style.BUTTON_RIVER if frosted else GlossyPanel.Style.BUTTON_CREAM
	)
	if frosted:
		panel.hue = Palette.SLATE
	add_child(panel)

	var icon := UiIcon.new()
	icon.kind = icon_kind
	panel.add_child(icon)
	panel.set_meta("icon", icon)

	var button := Button.new()
	Sound.taps(button)
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


## The one lantern left breathes, so the warning arrives before the window does.
func _process(delta: float) -> void:
	if _lamps.is_empty():
		return
	var alight := lanterns == 1
	if not alight and is_equal_approx(_pulse, 0.0):
		return
	_pulse = fmod(_pulse + delta, TAU) if alight else 0.0
	var lamp := _lamps[0]
	var swell := 1.0 if not alight else 1.0 + 0.16 * (0.5 + 0.5 * sin(_pulse * 3.4))
	lamp.pivot_offset = lamp.size * 0.5
	lamp.scale = Vector2(swell, swell)
	lamp.modulate = Color(1, 1, 1) if not alight else Color(
		1.0, 1.0, 1.0, 0.78 + 0.22 * (0.5 + 0.5 * sin(_pulse * 3.4))
	)


## Which counters are on screen. Every one of them is on from the second level
## onward; during a first run they arrive one at a time, each at the moment it
## starts to mean something.
func show_chips(lanterns_on: bool, coins_on: bool, moon_on: bool) -> void:
	if _chip_lanterns == null:
		return
	_chip_lanterns.visible = lanterns_on
	_chip_coins.visible = coins_on
	_chip_moon.visible = moon_on


## Draws attention to a counter the first time it appears, once.
func announce(chip: String) -> void:
	var node: GlossyPanel = {
		"lanterns": _chip_lanterns, "coins": _chip_coins, "moon": _chip_moon,
	}.get(chip, null)
	if node == null or not node.visible:
		return
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.6, 0.6)
	node.modulate.a = 0.0
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, 0.24)


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
	if _frost != null:
		# It reaches above its own top so it runs under the notch and the
		# status bar, and its rounded corners are the lower pair only — the
		# mirror of the dock, which is rounded on top and square at the bottom.
		var over := 120.0 * s
		_frost.position = Vector2(0.0, -over)
		_frost.size = Vector2(size.x, height + over + 16.0 * s)
		_frost_material.set_shader_parameter("rect_size", _frost.size)
		_frost_material.set_shader_parameter("corner_radius", 44.0 * s)
		_frost_material.set_shader_parameter("corners", Vector4(0.0, 0.0, 1.0, 1.0))
		_frost_material.set_shader_parameter("blur_radius", 16.0)
		_frost_material.set_shader_parameter("rim_width", 0.0)
		_frost_material.set_shader_parameter(
			"tint", Color(0.16, 0.17, 0.36, 0.42)
		)
		_hair.position = Vector2(0.0, height + 14.0 * s)
		_hair.size = Vector2(size.x, 2.0 * s)
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

	# Only what is on screen takes room. During a first run the counters arrive
	# one at a time, and a hidden one holding its slot open would leave a gap
	# where the player can see something is missing.
	var moon_slot := (moon_width + gap) if _chip_moon.visible else 0.0
	var coin_slot := (coin_width + gap) if _chip_coins.visible else 0.0

	var x := margin + moon_slot + coin_slot
	_chip_lanterns.position = Vector2(x, 0.0)
	_chip_lanterns.size = Vector2(lantern_width, height)
	_shape(_chip_lanterns, height)
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

	_place_chip(_chip_coins, margin + moon_slot, coin_width, height, icon, font_size,
		_coin_label, _chip_coins.get_meta("icon"))
	_place_chip(_chip_moon, margin, moon_width, height, icon, font_size,
		_moon_label, _moon_icon)


func _place_chip(
	chip: GlossyPanel, x: float, width: float, height: float, icon: float,
	font_size: int, label: Label, art: UiIcon
) -> void:
	chip.position = Vector2(x, 0.0)
	chip.size = Vector2(width, height)
	_shape(chip, height)
	var face := chip.face_height()
	art.size = Vector2(icon, icon)
	art.position = Vector2(width - icon - 16.0 * (height / CHIP_HEIGHT), (face - icon) * 0.5)
	label.size = Vector2(width - icon - 30.0 * (height / CHIP_HEIGHT), face)
	label.position = Vector2(8.0 * (height / CHIP_HEIGHT), 0.0)
	label.add_theme_font_size_override("font_size", font_size)


## The dock's tile, in the dock's proportion: a rounded square with the hard
## bottom edge, so the two bars read as one kit rather than two.
func _shape(chip: GlossyPanel, height: float) -> void:
	if not frosted:
		chip.radius_override = -1.0
		chip.edge_override = -1.0
		return
	chip.radius_override = height * 0.30
	chip.edge_override = height * 0.085


func _place_util(panel: GlossyPanel, x: float, top: float, side: float, s: float) -> void:
	panel.position = Vector2(x, top)
	panel.size = Vector2(side, side)
	panel.edge_override = 8.0 * s
	# On the hub the gear is a rounded square like every other tile; on the
	# play screen it keeps the round utility shape it has always had.
	panel.radius_override = (side * 0.30) if frosted else (side * 0.5)
	var icon: UiIcon = panel.get_meta("icon")
	var art := side * 0.52
	icon.size = Vector2(art, art)
	icon.position = Vector2((side - art) * 0.5, (panel.face_height() - art) * 0.5)
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)
