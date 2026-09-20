@tool
class_name StarField
extends Control
## The night sky behind everything: scattered stars that twinkle.
##
## This is the background the design draws and the engine was missing. It is not
## the mansion figure; that is `StarBand`, and it sits in front of this.
##
## The field is laid out from a fixed seed, so it is the same sky on every run
## and in the screenshot test. Positions are stored as fractions of the control,
## which means a resize moves the stars without rebuilding them.
##
## Stars keep to the side margins and the strip above the header, the way the
## design places them. Scattering them evenly puts one behind a line of text,
## where it reads as a stray full stop rather than a star.

## Twinkling asks for a redraw every frame, which cancels the project's
## low-processor mode. Capping the rate keeps the effect while halving the cost
## on a 60Hz screen; the eye cannot follow a star's flicker any faster.
const TWINKLE_FPS := 24.0
const SKY_SEED := 20260920
const STAR_COUNT := 130
## The brightest few get a cross of light. More than a handful looks like snow.
const GLINT_COUNT := 7
## How far in from each edge a star may sit, as a share of the width.
const MARGIN_SHARE := 0.28
## Above this line sits only the HUD, which is opaque and covers whatever is
## behind it, so the full width is free there. It has to stay clear of the
## caption below the HUD: a glint landing on that line reads as a stray mark in
## the middle of a sentence.
const FREE_TOP := 0.085

var _at: PackedVector2Array = PackedVector2Array()
var _radius: PackedFloat32Array = PackedFloat32Array()
var _base: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _speed: PackedFloat32Array = PackedFloat32Array()
var _tint: PackedColorArray = PackedColorArray()
var _since_redraw: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scatter()
	# A still sky in the editor: a preview that redraws forever makes the whole
	# editor busy for no gain.
	set_process(not Engine.is_editor_hint())


func _scatter() -> void:
	_at.clear()
	_radius.clear()
	_base.clear()
	_phase.clear()
	_speed.clear()
	_tint.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = SKY_SEED
	for i in STAR_COUNT:
		# Biased upward: the sky is darkest at the top, so that is where a star
		# reads. Near the bottom the gradient is light enough to swallow them.
		var y := pow(rng.randf(), 1.7)
		var x := rng.randf()
		if y >= FREE_TOP:
			# Below the free strip, hug one margin or the other. Squaring the
			# inset crowds them toward the screen edge instead of the content.
			var inset := pow(rng.randf(), 1.6) * MARGIN_SHARE
			x = inset if rng.randf() < 0.5 else 1.0 - inset
		_at.append(Vector2(x, y))
		_radius.append(rng.randf_range(1.4, 4.2))
		_base.append(rng.randf_range(0.22, 0.85))
		_phase.append(rng.randf_range(0.0, TAU))
		# Slow, and all different, so the field never pulses in step.
		_speed.append(rng.randf_range(0.5, 1.9))
		var pick := rng.randf()
		if pick < 0.12:
			_tint.append(Palette.GOLD_LIGHT)
		elif pick < 0.24:
			_tint.append(Palette.TRAIL)
		else:
			_tint.append(Palette.CREAM)
	queue_redraw()


func _process(delta: float) -> void:
	_since_redraw += delta
	if _since_redraw >= 1.0 / TWINKLE_FPS:
		_since_redraw = 0.0
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _at.is_empty():
		return
	var scale := maxf(size.x / 1080.0, 0.25)
	var now := float(Time.get_ticks_msec()) / 1000.0
	for i in _at.size():
		var at := _at[i] * size
		# Never fully out: a star that blinks to nothing reads as a dead pixel.
		var wave := sin(now * _speed[i] + _phase[i])
		var alpha := _base[i] * (0.58 + 0.42 * wave)
		# The size breathes with the brightness. Alpha alone reads as a fade;
		# the two together read as a sparkle.
		var radius := _radius[i] * scale * (0.85 + 0.15 * wave)
		draw_circle(at, radius, Color(_tint[i], alpha))
		if i < GLINT_COUNT:
			_glint(at, radius * 3.6, Color(_tint[i], alpha * 0.55))


## A four-armed cross of light, the way a bright star reads through an eyelash.
func _glint(at: Vector2, reach: float, colour: Color) -> void:
	draw_line(at - Vector2(reach, 0.0), at + Vector2(reach, 0.0), colour, 1.5, true)
	draw_line(at - Vector2(0.0, reach), at + Vector2(0.0, reach), colour, 1.5, true)
