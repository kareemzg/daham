class_name DipperView
extends Control
## بنات نعش: the bier of four and the three daughters behind it.
##
## The figure is the daily run's gauge, not a bar standing beside one. Four days
## close the bier; seven draw the whole thing.

const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
const BOX := Vector2(330.0, 150.0)
const STARS := [
	Vector2(40, 44), Vector2(40, 104), Vector2(112, 114), Vector2(118, 48),
	Vector2(178, 36), Vector2(238, 58), Vector2(292, 100),
]
const BIER := [0, 1, 2, 3, 0]
const HANDLE := [3, 4, 5, 6]
## Where each day's number sits, chosen one by one to fall outside the figure.
## Always below, and the first and fourth landed inside the bier.
const LABELS := [
	Vector2(0, -20), Vector2(0, 32), Vector2(0, 32), Vector2(6, -20),
	Vector2(0, -20), Vector2(0, 32), Vector2(0, 32),
]

var lit: int = 0:
	set(value):
		lit = clampi(value, 0, STARS.size())
		queue_redraw()

## The star waiting to be lit today, ringed in ember. -1 when today is done.
var today_star: int = -1:
	set(value):
		today_star = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := minf(size.x / BOX.x, size.y / BOX.y)
	var offset := (size - BOX * fit) * 0.5
	var at := func(i: int) -> Vector2: return STARS[i] * fit + offset

	_line(BIER, at, fit, lit >= 4)
	_line(HANDLE, at, fit, lit >= STARS.size())

	var font := UI_BOLD_FONT
	var digits := int(13.0 * fit)
	for i in STARS.size():
		var point: Vector2 = at.call(i)
		var colour := Color("A2937C")
		if i < lit:
			draw_circle(point, 15.0 * fit, Color(Palette.GOLD_LIGHT, 0.4), true, -1.0, true)
			draw_circle(point, 6.5 * fit, Palette.GOLD_LIGHT, true, -1.0, true)
			colour = Palette.GOLD_DEEP
		elif i == today_star:
			draw_arc(point, 13.0 * fit, 0.0, TAU, 40, Palette.EMBER, 2.6 * fit, true)
			draw_circle(point, 4.5 * fit, Palette.EMBER, true, -1.0, true)
			colour = Palette.EMBER
		else:
			draw_circle(point, 4.5 * fit, Color("8A7A62", 0.55), true, -1.0, true)
		var text := Arabic.eastern_digits(i + 1)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, digits).x
		draw_string(
			font, point + (LABELS[i] * fit) + Vector2(-width * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, digits, colour
		)


func _line(path: Array, at: Callable, fit: float, bright: bool) -> void:
	var points := PackedVector2Array()
	for i in path:
		points.append(at.call(i))
	draw_polyline(
		points, Color(Palette.GOLD_DEEP, 0.7 if bright else 0.28), 2.4 * fit, true
	)
