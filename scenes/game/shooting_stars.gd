@tool
class_name ShootingStars
extends Control
## Shooting stars across the night, at no fixed place and no fixed hour.
##
## Not `MeteorWipe`, which is the hard streak a screen change rides on. This is
## the sky being alive: one every few seconds, somewhere else each time, drawn
## as a gradient that fades into nothing at its tail so it reads as light
## passing rather than a line laid down.
##
## It sits above `StarField` and touches none of it. The field is the sky's
## standing population; this is what crosses it.

## How long a single streak takes, end to end.
const FLIGHT := 0.9
## The gap between them, drawn from this range so the rhythm never settles.
const GAP_MIN := 2.6
const GAP_MAX := 7.4
## How many may be in the air at once. Two is enough that the sky can surprise
## you and few enough that it never reads as rain.
const MOST := 2
## Length as a share of the shorter side, and the same for the head's radius.
const LENGTH_MIN := 0.17
const LENGTH_MAX := 0.30
const HEAD := 2.6
const WIDTH := 3.2
## Sixty is wasteful for a streak this soft; the eye cannot tell.
const FPS := 30.0

## Scales the brightness, so the lanterns take the meteors with the rest.
var light: float = 1.0:
	set(value):
		light = clampf(value, 0.0, 1.0)

var _live: Array = []
var _next: float = 1.2
var _since_redraw: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Seeded from the clock and not from a constant: the whole point is that
	# two runs are not the same sky. `StarField` is the opposite on purpose —
	# its field is fixed so a screenshot is comparable.
	_rng.randomize()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	_next -= delta
	if _next <= 0.0 and _live.size() < MOST:
		_launch()
		_next = _rng.randf_range(GAP_MIN, GAP_MAX)

	var still: Array = []
	for streak: Dictionary in _live:
		streak["age"] = float(streak["age"]) + delta
		if float(streak["age"]) < FLIGHT:
			still.append(streak)
	_live = still

	_since_redraw += delta
	if _since_redraw >= 1.0 / FPS:
		_since_redraw = 0.0
		queue_redraw()


## Somewhere in the upper two thirds, running down and across. Never from a
## corner and never along an edge: a streak that grazes the frame reads as a
## scratch on the glass rather than a thing in the sky.
func _launch() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var reach := minf(size.x, size.y) * _rng.randf_range(LENGTH_MIN, LENGTH_MAX)
	# Down and to the left, roughly, with enough spread that no two look alike.
	var angle := deg_to_rad(_rng.randf_range(152.0, 208.0))
	var from := Vector2(
		_rng.randf_range(0.18, 0.96) * size.x,
		_rng.randf_range(0.05, 0.62) * size.y
	)
	_live.append({
		"from": from,
		"to": from + Vector2(cos(angle), -sin(angle)) * reach,
		"age": 0.0,
		# Mostly the cream of an ordinary star; now and then the red or the
		# blue-white the tradition names, so the sky agrees with itself.
		"tint": _tint(),
	})


func _tint() -> Color:
	var pick := _rng.randf()
	if pick < 0.12:
		return Palette.STAR_RED
	if pick < 0.30:
		return Palette.STAR_BLUE
	if pick < 0.46:
		return Palette.GOLD_LIGHT
	return Palette.CREAM


func _draw() -> void:
	if _live.is_empty():
		return
	var scale := maxf(size.x / 1080.0, 0.3)
	for streak: Dictionary in _live:
		var age := float(streak["age"]) / FLIGHT
		# In fast, out slow, and never at full for long: a meteor is a glimpse.
		var strength := sin(pow(age, 0.55) * PI) * light
		if strength <= 0.01:
			continue
		var from: Vector2 = streak["from"]
		var to: Vector2 = streak["to"]
		var head := from.lerp(to, age)
		var tint: Color = streak["tint"]
		# The tail is drawn as a run of short segments fading to nothing,
		# because `draw_line` takes one colour and a streak that ends abruptly
		# reads as a stick. Godot's own gradient line would need a texture; the
		# segments cost less and fade exactly where they should.
		var tail := head.lerp(from, 0.85)
		var steps := 14
		for i in steps:
			var a := head.lerp(tail, float(i) / float(steps))
			var b := head.lerp(tail, float(i + 1) / float(steps))
			var along := 1.0 - float(i) / float(steps)
			draw_line(a, b, Color(tint, strength * along * along * 0.9),
				WIDTH * scale * along, true)
		draw_circle(head, HEAD * scale, Color(tint, strength), true, -1.0, true)
		draw_circle(head, HEAD * 2.6 * scale, Color(tint, strength * 0.22), true, -1.0, true)
