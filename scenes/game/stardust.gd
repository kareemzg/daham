class_name Stardust
extends RefCounted
## The one dust the game uses, so a name and a constellation are made of the
## same stuff.
##
## Dense, blown in from one side rather than gathered from a ring, drawn as
## short streaks so it reads as moving, and gone by the time the thing it is
## making has arrived. In Arabic the writing runs right to left, so the dust
## comes from the left: it is always ahead of the edge that is forming.
##
## Gold, the colour of the stars and of everything it builds. Nothing else.

## Where the dust blows in from. Left and a little high.
const WIND := Vector2(-1.0, -0.28)
## How far out it starts, in reference units at a 1080-wide screen.
const REACH := 150.0
## How much of a thing's arrival the motes are spread over, so some are still
## far out while others have landed and the plume has length.
const STAGGER := 0.6


## Dust making a rectangle of ink: one letter of a word.
static func over_rect(
	canvas: CanvasItem, box: Rect2, arrival: float, key: int, s: float, motes: int
) -> void:
	var rng := RandomNumberGenerator.new()
	for m in motes:
		rng.seed = hash(Vector2i(key, m))
		var home := box.position + Vector2(
			rng.randf() * box.size.x, rng.randf() * box.size.y
		)
		_mote(canvas, home, arrival, rng, s)


## Dust making a line: one joint of a constellation.
static func along_line(
	canvas: CanvasItem, from: Vector2, to: Vector2, arrival: float, key: int,
	s: float, motes: int
) -> void:
	var rng := RandomNumberGenerator.new()
	for m in motes:
		rng.seed = hash(Vector2i(key, m))
		var home := from.lerp(to, rng.randf())
		home += Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 7.0 * s
		_mote(canvas, home, arrival, rng, s)


## One mote on its way in. `arrival` is how far the thing it belongs to has
## come; the mote takes its own slice of that, which is what gives the plume
## its length.
static func _mote(
	canvas: CanvasItem, home: Vector2, arrival: float, rng: RandomNumberGenerator, s: float
) -> void:
	var delay := rng.randf() * STAGGER
	var t := clampf((arrival - delay) / (1.0 - STAGGER), 0.0, 1.0)
	if t <= 0.0:
		return

	var travel := pow(1.0 - t, 1.5)
	# Most motes stay near what they are building and a few reach far out, so
	# the plume is thick at its head and thins away rather than spreading evenly.
	var away := REACH * s * (0.12 + pow(rng.randf(), 1.9) * 2.0)
	var drift := Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.9, 0.55))
	var spot := home + (WIND.normalized() * away + drift * away * 0.55) * travel

	# Bright on the way in and gone as it lands, so the dust never muddies the
	# ink it made.
	# Added light at half strength over a navy sky comes out a warm grey, which
	# is ash and not stars. The motes are bright or they are nothing.
	var alpha := pow(1.0 - t, 0.55) * clampf(t / 0.08, 0.0, 1.0) * (0.82 + rng.randf() * 0.18)
	if alpha <= 0.01:
		return

	# Two golds only: the stars' own, and a paler one for the few that catch.
	var colour := Palette.GOLD_LIGHT if rng.randf() < 0.9 else Color("FFF6D6")
	var width := (1.0 + rng.randf() * 1.6) * s
	# Grains with a little motion in them, not rain: a long tail at this size
	# reads as a dash rather than a speck of light travelling.
	var tail := WIND.normalized() * (3.0 * s + rng.randf() * 8.0 * s)
	canvas.draw_line(spot, spot + tail, Color(colour, alpha), width, true)
