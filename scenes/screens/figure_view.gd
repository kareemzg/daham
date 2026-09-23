class_name FigureView
extends Control
## One mansion's figure, drawn to fit whatever box it is given.
##
## The map draws its own, because there each star is lit or dark by how far the
## player has got. Here the mansion is finished, so the whole figure shows.

## The whole figure, as `Mansions.figure_of()` gives it.
var figure: Dictionary = {}:
	set(value):
		figure = value
		queue_redraw()

## Just the points, for a caller that has nothing else. Setting this builds a
## figure of one chain at a uniform brightness — and drops whatever stood
## behind it, which is why every caller that has a real figure sets `figure`.
var shape: Array = []:
	set(value):
		var join: Array = []
		for i in maxi(value.size() - 1, 0):
			join.append(Vector2i(i, i + 1))
		var mags: Array = []
		for i in value.size():
			mags.append(3.0)
		figure = {"points": value, "mags": mags, "behind": [], "behind_mags": [], "join": join}
	get:
		return figure.get("points", [])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## How big a dot is, from the star's visual magnitude.
##
## This is not decoration: it is the figure. الثريا is nine stars inside one
## degree, and only the spread from 2.85 to 6.43 tells it from a smudge of
## identical dots — which is exactly what the tradition says of it, «ستة أنجم
## ظاهرة، في خللها نجوم كثيرة خفية». Drawn all the same size, the reading and
## the drawing contradict each other.
##
## Magnitude runs backwards: the brightest stars are near zero, the faintest
## the game shows are past six.
func _dot(mag: float, unit: float) -> float:
	return maxf(unit * (0.090 - 0.0105 * clampf(mag, 0.0, 7.0)), unit * 0.016)


func _draw() -> void:
	var points: Array = figure.get("points", [])
	if points.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var behind: Array = figure.get("behind", [])
	var mags: Array = figure.get("mags", [])
	var behind_mags: Array = figure.get("behind_mags", [])
	var join: Array = figure.get("join", [])

	# The box is framed on the mansion's own stars; whatever is behind may run
	# off the edge, which is what a figure behind is for. A one-star mansion
	# (الدبران) has no span of its own, so it borrows the whole reading's.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in points:
		low = low.min(point)
		high = high.max(point)
	if low.is_equal_approx(high):
		for point: Vector2 in behind:
			low = low.min(point)
			high = high.max(point)
	var span := high - low
	var margin := minf(size.x, size.y) * 0.16
	var room := size - Vector2(margin, margin) * 2.0
	var fit := minf(room.x / maxf(span.x, 1.0), room.y / maxf(span.y, 1.0))
	var offset := (size - span * fit) * 0.5 - low * fit
	var unit := size.y

	# Behind first, and dimmer: it is context, never the subject.
	for i in behind.size():
		var at: Vector2 = (behind[i] as Vector2) * fit + offset
		var mag: float = behind_mags[i] if i < behind_mags.size() else 4.0
		draw_circle(at, _dot(mag, unit) * 0.8, Color(Palette.FIGURE_FAINT, 0.55), true, -1.0, true)

	var placed := PackedVector2Array()
	for point: Vector2 in points:
		placed.append(point * fit + offset)

	# Pairs, not a chain. A figure branches — the three stars of الهقعة meet at
	# one of them — and a cluster has no lines at all, because a line through
	# الثريا would claim a shape those stars do not have.
	var width := maxf(unit * 0.025, 1.5)
	for pair: Vector2i in join:
		if pair.x < 0 or pair.y < 0 or pair.x >= placed.size() or pair.y >= placed.size():
			continue
		draw_line(placed[pair.x], placed[pair.y], Color(Palette.GOLD_DEEP, 0.7), width, true)

	for i in placed.size():
		var mag: float = mags[i] if i < mags.size() else 3.0
		var core := _dot(mag, unit)
		draw_circle(placed[i], core * 1.7, Color(Palette.GOLD_LIGHT, 0.2), true, -1.0, true)
		draw_circle(placed[i], core, Palette.GOLD, true, -1.0, true)
