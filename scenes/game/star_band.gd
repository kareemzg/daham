@tool
class_name StarBand
extends Control
## The mansion figure above the grid: one star per level in the mansion.
##
## The arc is placeholder geometry. The real shapes come from redrawn
## constellation figures, one file per mansion; this only proves the lighting.
##
## Stars are drawn as glowing points rather than star sprites on purpose: a
## five-pointed sprite reads as a prize, a bright dot with a halo reads as a sky.
## Everything scales off the band's height, so the look holds at any size.

@export var total: int = 20:
	set(value):
		total = maxi(value, 1)
		_rebuild()

@export var lit: int = 0:
	set(value):
		lit = clampi(value, 0, total)
		queue_redraw()

## The halo, as a share of the band's height, and never wider than half the gap
## between two stars: at exactly half, two neighbours meet where both have faded
## to nothing, so they never bleed into each other.
const HALO_SHARE := 0.42
const HALO_PITCH_LIMIT := 0.5
const CORE_SHARE := 0.055

var _points: PackedVector2Array = PackedVector2Array()
var _halo: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()


func setup(star_count: int, already_lit: int) -> void:
	total = star_count
	lit = already_lit
	_rebuild()


func light_next() -> void:
	lit = mini(lit + 1, total)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()


func _rebuild() -> void:
	_points = PackedVector2Array()
	if total <= 0 or size.x <= 0.0:
		return
	# A shallow arc that reads as a figure rather than a progress bar. Laid out
	# right to left, so the first star lit is the rightmost.
	var margin := size.x * 0.08
	var span := size.x - margin * 2.0
	for i in total:
		var t := float(i) / float(maxi(total - 1, 1))
		var x := size.x - margin - t * span
		var wobble := sin(t * PI * 2.4) * size.y * 0.26
		_points.append(Vector2(x, size.y * 0.5 + wobble))
	queue_redraw()


## One radial gradient, tinted per star. Stacked circles used to do this job,
## but every ring had a visible rim; a gradient falls off smoothly and costs one
## draw call however big the halo gets.
func _halo_texture() -> GradientTexture2D:
	if _halo != null:
		return _halo
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.18), Color(1, 1, 1, 0.0)
	])
	_halo = GradientTexture2D.new()
	_halo.gradient = ramp
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)
	_halo.width = 128
	_halo.height = 128
	return _halo


func _glow(at: Vector2, radius: float, colour: Color, strength: float) -> void:
	draw_texture_rect(
		_halo_texture(),
		Rect2(at - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		false,
		Color(colour, strength)
	)


func _draw() -> void:
	if _points.size() < 2:
		return
	# The joining lines stay faint until the whole figure is lit.
	var complete := lit >= total
	var line_colour: Color = Palette.GOLD_LIGHT if complete else Palette.DIM_STAR
	draw_polyline(_points, Color(line_colour, 0.75 if complete else 0.28), 2.0, true)

	var core := size.y * CORE_SHARE
	var pitch: float = size.y
	if _points.size() > 1:
		pitch = absf(_points[1].x - _points[0].x)
	var halo := minf(size.y * HALO_SHARE, pitch * HALO_PITCH_LIMIT)
	for i in _points.size():
		var at: Vector2 = _points[i]
		if i < lit:
			_glow(at, halo, Palette.GOLD_LIGHT, 0.62)
			draw_circle(at, core, Palette.GOLD_LIGHT)
			# A white pinpoint keeps the centre from reading as flat gold.
			draw_circle(at, core * 0.45, Color(1, 1, 1, 0.95))
		elif i == lit:
			# The one this level will light: still dim, but ringed and glowing.
			_glow(at, halo * 0.8, Palette.GOLD, 0.42)
			draw_arc(at, core * 2.2, 0.0, TAU, 32, Palette.GOLD, 2.5, true)
			draw_circle(at, core * 0.7, Color(Palette.GOLD_LIGHT, 0.9))
		else:
			draw_circle(at, core * 0.55, Palette.DIM_STAR)
