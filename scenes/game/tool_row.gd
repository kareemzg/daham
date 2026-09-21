class_name ToolRow
extends Control
## One line of the hints window or the shop: a drawing, a name, what it does,
## and what it costs.
##
## A price you cannot afford is greyed, never hidden. A player has to know the
## tool exists and what it would take, or the shop teaches them nothing.

signal pressed

const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
## Reference units, in the 1080-wide space.
const HEIGHT := 140.0
const PAD := 26.0

var affordable: bool = true:
	set(value):
		affordable = value
		if price != null:
			price.style = (
				GlossyPanel.Style.BUTTON_EMBER if affordable
				else GlossyPanel.Style.BUTTON_MUTED
			)
			_price_label.add_theme_color_override(
				"font_color", Color("FFF4E8") if affordable else Color("6B5D48")
			)

var price: GlossyPanel
var icon: UiIcon

var _tray: Panel
var _name: Label
var _what: Label
var _price_label: Label
var _coin: UiIcon


func configure(kind: int, title: String, what: String, cost: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tray = Panel.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.22), Color(0, 0, 0, 0), 38, 0)
	)
	add_child(_tray)

	icon = UiIcon.new()
	icon.kind = kind
	add_child(icon)

	_name = _label(Palette.TILE_INK)
	_name.text = title
	add_child(_name)

	_what = _label(Color("6B5942"))
	_what.text = what
	add_child(_what)

	price = GlossyPanel.new()
	price.style = GlossyPanel.Style.BUTTON_EMBER
	add_child(price)
	_price_label = _label(Color("FFF4E8"))
	_price_label.text = Arabic.eastern_digits(cost)
	price.add_child(_price_label)
	_coin = UiIcon.new()
	_coin.kind = UiIcon.Kind.COIN
	price.add_child(_coin)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "%s · %s" % [title, Arabic.eastern_digits(cost)]
	button.pressed.connect(func() -> void: pressed.emit())
	button.button_down.connect(func() -> void: price.set_pressed(true))
	button.button_up.connect(func() -> void: price.set_pressed(false))
	add_child(button)
	set_meta("button", button)


func _label(colour: Color) -> Label:
	var label := Label.new()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_BOLD_FONT)
	label.add_theme_color_override("font_color", colour)
	return label


## Called when the count a player already owns changes, so the line can say so.
func set_owned(owned: int) -> void:
	if _what == null:
		return
	_what.set_meta("owned", owned)


func relayout(s: float) -> void:
	if _tray == null:
		return
	_tray.position = Vector2.ZERO
	_tray.size = size
	var pad := PAD * s

	# The drawing leads, at the reading start, which in Arabic is the right.
	var art := 84.0 * s
	var drawing := icon.texture()
	var art_width := art * (float(drawing.get_width()) / float(maxi(drawing.get_height(), 1)))
	icon.size = Vector2(art_width, art)
	icon.position = Vector2(size.x - pad - art_width, (size.y - art) * 0.5)

	# The price sits opposite it, sized to the number it holds.
	_price_label.add_theme_font_size_override("font_size", int(38.0 * s))
	var coin_side := 44.0 * s
	var number := _price_label.get_minimum_size().x
	var pill_width := number + coin_side + 44.0 * s
	var pill_height := 88.0 * s
	price.position = Vector2(pad, (size.y - pill_height) * 0.5)
	price.edge_override = 8.0 * s
	price.radius_override = 28.0 * s
	price.size = Vector2(pill_width, pill_height + 8.0 * s)
	_price_label.position = Vector2(16.0 * s, 0.0)
	_price_label.size = Vector2(number, pill_height)
	_coin.size = Vector2(coin_side, coin_side)
	_coin.position = Vector2(pill_width - coin_side - 16.0 * s, (pill_height - coin_side) * 0.5)

	var button: Button = get_meta("button")
	button.position = Vector2.ZERO
	button.size = size

	# The words take what is left between them.
	var text_right := size.x - pad - art_width - 18.0 * s
	var text_left := pad + pill_width + 18.0 * s
	var width := maxf(text_right - text_left, 10.0)
	_name.add_theme_font_size_override("font_size", int(40.0 * s))
	_what.add_theme_font_size_override("font_size", int(30.0 * s))
	var owned: int = _what.get_meta("owned", 0)
	_name.position = Vector2(text_left, size.y * 0.16)
	_name.size = Vector2(width, 44.0 * s)
	_what.position = Vector2(text_left, size.y * 0.54)
	_what.size = Vector2(width, 38.0 * s)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_what.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if owned > 0:
		_what.add_theme_color_override("font_color", Palette.GOLD_DEEP)
	else:
		_what.add_theme_color_override("font_color", Color("6B5942"))
