class_name CardRow
extends Control
## One mansion's line in the collection, in one of three states.
##
## Finished: its figure, its name, what the name means, and the modern name of
## its brightest star. Being played: the name shows because the player is in it,
## the figure is dim, and the count says how far. Not reached: a question mark
## where both the figure and the name would be, because learning the name is the
## reward for finishing the mansion and nothing may give it away early.

signal pressed

enum State { DONE, NOW, LOCKED }

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
## Reference units, in the 1080-wide space.
const HEIGHT := 180.0
const PAD := 30.0

var state: int = State.LOCKED
var mansion: int = 0

var _shell: GlossyPanel
var _thumb: Panel
var _figure: FigureView
var _mark: Label
var _name: Label
var _under: Label
var _trail: Label
var _button: Button
var _scale: float = 1.0


func configure() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shell = GlossyPanel.new()
	_shell.style = GlossyPanel.Style.PANEL_NIGHT
	add_child(_shell)

	_thumb = Panel.new()
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_thumb)

	_figure = FigureView.new()
	add_child(_figure)

	_mark = _label(UI_BOLD_FONT, Color("4E6E80"))
	_mark.text = "؟"
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_mark)

	_name = _label(DISPLAY_FONT, Palette.CREAM)
	add_child(_name)
	_under = _label(UI_BOLD_FONT, Color("7A96A8"))
	add_child(_under)

	_trail = _label(UI_BOLD_FONT, Color("9FC3D0"))
	_trail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_trail)

	_button = Button.new()
	_button.flat = true
	_button.focus_mode = Control.FOCUS_ALL
	_button.pressed.connect(func() -> void: pressed.emit())
	add_child(_button)


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	# RTL: LEFT is the start of the line, which is the right-hand side.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


## `lit` is how many of the mansion's twenty stars are alight.
func show_mansion(number: int, lit: int, total: int) -> void:
	mansion = number
	if lit >= total:
		state = State.DONE
	elif lit > 0:
		state = State.NOW
	else:
		state = State.LOCKED

	_shell.style = (
		GlossyPanel.Style.CHIP if state == State.DONE else GlossyPanel.Style.PANEL_NIGHT
	)
	_shell.modulate = Color(1.18, 1.18, 1.18) if state == State.NOW else Color(1, 1, 1)
	_figure.shape = Mansions.shape_of(number) if state != State.LOCKED else []
	_figure.modulate = Color(1, 1, 1) if state == State.DONE else Color(0.45, 0.58, 0.66)
	_figure.visible = state != State.LOCKED
	_mark.visible = state == State.LOCKED

	match state:
		State.DONE:
			_name.text = Mansions.name_of(number)
			_name.add_theme_color_override("font_color", Palette.TILE_INK)
			_under.text = Mansions.meaning_of(number)
			_under.add_theme_color_override("font_color", Color("6B5942"))
			_trail.text = Mansions.latin_of(number)
			_trail.text_direction = Control.TEXT_DIRECTION_LTR
			_trail.add_theme_color_override("font_color", Color("8A7A62"))
		State.NOW:
			_name.text = Mansions.name_of(number)
			_name.add_theme_color_override("font_color", Palette.MUTED)
			_under.text = "تكتمل عند نجمتها العشرين"
			_under.add_theme_color_override("font_color", Color("7A96A8"))
			# The map calls this "star twelve of twenty", counting the one being
			# played. Two screens must not count the same progress differently.
			_trail.text = "%s / %s" % [
				Arabic.eastern_digits(mini(lit + 1, total)), Arabic.eastern_digits(total)
			]
			_trail.text_direction = Control.TEXT_DIRECTION_RTL
			_trail.add_theme_color_override("font_color", Color("9FC3D0"))
		State.LOCKED:
			_name.text = "؟"
			_name.add_theme_color_override("font_color", Color("6F8A9B"))
			_under.text = "لم تُفتح بعد"
			_under.add_theme_color_override("font_color", Color("7A96A8"))
			_trail.text = ""

	# Only a finished mansion has a card to open.
	_button.disabled = state != State.DONE
	_button.tooltip_text = Mansions.name_of(number) if state == State.DONE else ""
	_place()


func apply_scale(s: float) -> void:
	_scale = s
	custom_minimum_size = Vector2(0.0, HEIGHT * s)
	_place()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()


func _place() -> void:
	if _shell == null or size.x <= 0.0:
		return
	var s := _scale
	var pad := PAD * s
	_shell.position = Vector2.ZERO
	_shell.size = size
	_shell.edge_override = 8.0 * s
	_shell.radius_override = 42.0 * s
	var face := _shell.face_height()

	var thumb := Vector2(156.0 * s, 132.0 * s)
	var thumb_x := size.x - pad - thumb.x
	var thumb_y := (face - thumb.y) * 0.5
	_thumb.position = Vector2(thumb_x, thumb_y)
	_thumb.size = thumb
	_thumb.add_theme_stylebox_override(
		"panel", Palette.card(Color("0C2231"), Color(0, 0, 0, 0), int(30.0 * s), 0)
	)
	_figure.position = _thumb.position
	_figure.size = thumb
	_mark.position = _thumb.position
	_mark.size = thumb
	_mark.add_theme_font_size_override("font_size", int(60.0 * s))

	var trail_width := 220.0 * s
	_trail.add_theme_font_size_override("font_size", int(30.0 * s))
	_trail.position = Vector2(pad, 0.0)
	_trail.size = Vector2(trail_width, face)

	var text_left := pad + trail_width + 16.0 * s
	var width := maxf(thumb_x - 18.0 * s - text_left, 20.0)
	_name.add_theme_font_size_override("font_size", int(52.0 * s))
	_name.position = Vector2(text_left, face * 0.14)
	_name.size = Vector2(width, face * 0.42)
	_under.add_theme_font_size_override("font_size", int(29.0 * s))
	_under.position = Vector2(text_left, face * 0.56)
	_under.size = Vector2(width, face * 0.34)

	_button.position = Vector2.ZERO
	_button.size = size
