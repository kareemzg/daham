class_name SkyToggle
extends Control
## One row of the settings window: a label on the right, a switch on the left.
##
## The switch is drawn rather than built from panels: it is two rounded shapes
## and a knob that slides, and a `GlossyPanel` pair would be heavier than the
## thing it draws.

signal toggled(on: bool)

const TRACK_WIDTH := 116.0  ## reference units, scaled like everything else
const TRACK_HEIGHT := 64.0

var label_text: String = "":
	set(value):
		label_text = value
		if _label != null:
			_label.text = value

var on: bool = true:
	set(value):
		on = value
		queue_redraw()

var _label := Label.new()
## Public: a test presses the same Button a finger does.
var button := Button.new()


func _init() -> void:
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.text_direction = Control.TEXT_DIRECTION_RTL
	add_child(_label)

	# A real Button on top, so the row is reachable by keyboard and by a screen
	# reader rather than only by tapping a drawing.
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.toggle_mode = false
	button.pressed.connect(_on_pressed)
	add_child(button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		button.position = Vector2.ZERO
		button.size = size
		queue_redraw()


func style(font: Font, colour: Color, font_size: int) -> void:
	_label.add_theme_font_override("font", font)
	_label.add_theme_color_override("font_color", colour)
	_label.add_theme_font_size_override("font_size", font_size)
	button.tooltip_text = label_text


func _on_pressed() -> void:
	on = not on
	toggled.emit(on)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := size.y / 92.0  # the row's own height in reference units
	var track := Vector2(TRACK_WIDTH * s, TRACK_HEIGHT * s)
	var pad := 22.0 * s

	# The row's own tray, so a switch reads as a setting and not as loose art.
	draw_style_box(
		_rounded(Color(Palette.TILE_BORDER, 0.2), Color(Palette.TILE_BORDER, 0.0), 26.0 * s),
		Rect2(Vector2.ZERO, size)
	)

	# The switch takes the left of the row and the words take the rest, so the
	# label starts where the track ends rather than on top of it.
	var left := pad
	var text_left := left + track.x + 18.0 * s
	_label.position = Vector2(text_left, 0.0)
	_label.size = Vector2(maxf(size.x - text_left - pad, 0.0), size.y)

	var top := (size.y - track.y) * 0.5
	var radius := track.y * 0.5
	var track_rect := Rect2(Vector2(left, top), track)
	var face := Palette.RIVER if on else Color("C2B49A")
	var rim := Palette.RIVER_DEEP if on else Color("A2937C")
	draw_style_box(_rounded(face, rim, radius), track_rect)

	# In Arabic the switch travels the way the text does: off sits at the start
	# of the track, on at its end.
	var knob_radius := radius - 4.0 * s
	var knob_x := left + (knob_radius + 4.0 * s if on else track.x - knob_radius - 4.0 * s)
	draw_circle(Vector2(knob_x, top + radius), knob_radius, Color("FFFBF0"))


func _rounded(fill: Color, border: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(int(maxf(2.0, radius * 0.12)))
	box.set_corner_radius_all(int(radius))
	return box
