class_name FigureView
extends Control
## One mansion's figure, drawn to fit whatever box it is given.
##
## The map draws its own, because there each star is lit or dark by how far the
## player has got. Here the mansion is finished, so the whole figure shows.

var shape: Array = []:
	set(value):
		shape = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if shape.size() < 2 or size.x <= 0.0 or size.y <= 0.0:
		return
	# Fit the drawing to the box rather than to a fixed scale: the same figure
	# appears small on the map and large on a card.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in shape:
		low = low.min(point)
		high = high.max(point)
	var span := high - low
	var margin := minf(size.x, size.y) * 0.16
	var room := size - Vector2(margin, margin) * 2.0
	var fit := minf(
		room.x / maxf(span.x, 1.0), room.y / maxf(span.y, 1.0)
	)
	var offset := (size - span * fit) * 0.5 - low * fit

	var points := PackedVector2Array()
	for point: Vector2 in shape:
		points.append(point * fit + offset)
	draw_polyline(points, Color(Palette.GOLD_DEEP, 0.7), maxf(size.y * 0.025, 1.5), true)
	for point in points:
		draw_circle(point, size.y * 0.075, Color(Palette.GOLD_LIGHT, 0.2), true, -1.0, true)
		draw_circle(point, size.y * 0.045, Palette.GOLD, true, -1.0, true)
