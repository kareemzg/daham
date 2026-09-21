class_name MansionFinale
extends Control
## The twentieth star. The board is gone and the sky is left alone: the stars
## light one by one, the lines come in from the right the way the language
## reads, and then the name gathers itself out of stardust and glows.
##
## This is the moment the whole game is arranged around, so it is a moment and
## not a window: the window comes after it.

signal finished

const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
const STAR_SECONDS := 0.17
const LINE_SECONDS := 0.55
## How long the finished figure is left alone before the card is offered.
const HOLD := 0.7

var name_view: StardustName

var _subtitle: Label
var _shape: Array = []
var _lit: float = 0.0:
	set(value):
		_lit = value
		queue_redraw()
var _drawn: float = 0.0:
	set(value):
		_drawn = value
		queue_redraw()
var _field := Rect2()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	name_view = StardustName.new()
	add_child(name_view)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.text_direction = Control.TEXT_DIRECTION_RTL
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.text = "اكتملت نجومها العشرون"
	_subtitle.add_theme_font_override("font", UI_BOLD_FONT)
	_subtitle.add_theme_color_override("font_color", Palette.MUTED)
	_subtitle.modulate.a = 0.0
	add_child(_subtitle)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		relayout()


func relayout() -> void:
	if size.x <= 0.0:
		return
	var s := size.x / 1080.0
	_field = Rect2(
		Vector2(size.x * 0.12, size.y * 0.2),
		Vector2(size.x * 0.76, size.y * 0.26)
	)
	name_view.position = Vector2(0.0, size.y * 0.5)
	name_view.size = Vector2(size.x, 170.0 * s)
	name_view.set_font_size(int(150.0 * s))
	_subtitle.position = Vector2(0.0, size.y * 0.5 + 180.0 * s)
	_subtitle.size = Vector2(size.x, 56.0 * s)
	_subtitle.add_theme_font_size_override("font_size", int(36.0 * s))
	queue_redraw()


## Runs the whole moment for one mansion.
func play(mansion: int) -> void:
	# The lines come in from the right, so the path is walked from its
	# right-hand end whichever way the shape happens to be stored.
	_shape = Mansions.shape_of(mansion).duplicate()
	if _shape.size() >= 2 and _shape[0].x < _shape[_shape.size() - 1].x:
		_shape.reverse()

	visible = true
	modulate.a = 1.0
	_lit = 0.0
	_drawn = 0.0
	_subtitle.modulate.a = 0.0
	name_view.setup(Mansions.name_of(mansion), int(150.0 * (size.x / 1080.0)))
	relayout()

	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _lit = v,
		0.0, float(_shape.size()), float(_shape.size()) * STAR_SECONDS)
	tween.tween_method(func(v: float) -> void: _drawn = v, 0.0, 1.0, LINE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(name_view.play)
	await name_view.formed
	var after := create_tween()
	after.tween_property(_subtitle, "modulate:a", 1.0, 0.35)
	after.tween_interval(HOLD)
	after.tween_callback(func() -> void: finished.emit())


## Skips the whole thing, for tests and for a player who taps through.
func settle(mansion: int) -> void:
	_shape = Mansions.shape_of(mansion)
	visible = true
	_lit = float(_shape.size())
	_drawn = 1.0
	name_view.setup(Mansions.name_of(mansion), int(150.0 * (size.x / 1080.0)))
	name_view.settle()
	_subtitle.modulate.a = 1.0
	relayout()


func _points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if _shape.size() < 2 or _field.size.x <= 0.0:
		return points
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for p: Vector2 in _shape:
		low = low.min(p)
		high = high.max(p)
	var span := high - low
	var fit := minf(_field.size.x / maxf(span.x, 1.0), _field.size.y / maxf(span.y, 1.0))
	var offset := _field.position + (_field.size - span * fit) * 0.5 - low * fit
	for p: Vector2 in _shape:
		points.append(p * fit + offset)
	return points


func _draw() -> void:
	var points := _points()
	if points.size() < 2:
		return
	var s := size.x / 1080.0

	# Each joint reveals in turn, so the figure is written rather than switched on.
	var joints := points.size() - 1
	for i in joints:
		var share := clampf(_drawn * float(joints) - float(i), 0.0, 1.0)
		if share <= 0.0:
			continue
		draw_line(
			points[i], points[i].lerp(points[i + 1], share),
			Color(Palette.GOLD_LIGHT, 0.75), 5.0 * s, true
		)

	for i in points.size():
		var arrival := clampf(_lit - float(i), 0.0, 1.0)
		if arrival <= 0.0:
			continue
		draw_circle(points[i], 46.0 * s * arrival,
			Color(Palette.GOLD_LIGHT, 0.22 * arrival), true, -1.0, true)
		draw_circle(points[i], 14.0 * s * arrival, Palette.GOLD_LIGHT, true, -1.0, true)
