class_name MeteorWipe
extends Control
## A shooting star crossing the screen, used to change what is on the sky.
##
## The streak runs from the upper right to the lower left, the way the language
## reads. `swap` fires as it passes the middle, which is when the caller changes
## the content behind it.
##
## The design draws a hard edge with the old screen on one side and the new one
## on the other. That needs both screens rendered into textures, which is a
## structural change to how the screen is built. This is the same streak with a
## cross-fade behind it instead: close enough to judge the motion by, and honest
## about which half is missing.

signal swap
signal finished

const DURATION := 0.45
## Lean of the streak off vertical, in degrees, and how wide its core is.
const LEAN := 17.0
const CORE_WIDTH := 40.0
const GLOW_WIDTH := 120.0

var _progress: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func play() -> void:
	visible = true
	_progress = 0.0
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		visible = false
		_progress = -1.0
		finished.emit()
	)


func _set_progress(value: float) -> void:
	var was := _progress
	_progress = value
	if was < 0.5 and value >= 0.5:
		swap.emit()
	queue_redraw()


func _draw() -> void:
	if _progress < 0.0 or size.x <= 0.0:
		return
	var scale := maxf(size.x / 1080.0, 0.25)
	var lean := tan(deg_to_rad(LEAN)) * size.y
	# Travel far enough past each edge that the streak is fully off screen at
	# both ends, leaning included.
	var start := size.x + lean + GLOW_WIDTH * scale
	var head_x := start - _progress * (start + lean + GLOW_WIDTH * scale)

	_band(head_x, lean, GLOW_WIDTH * scale, Color(Palette.GOLD_LIGHT, 0.22))
	_band(head_x, lean, CORE_WIDTH * scale, Color(Palette.GOLD_LIGHT, 0.55))
	_band(head_x, lean, CORE_WIDTH * scale * 0.35, Color(1, 1, 1, 0.9))

	# The head sits a little ahead of the band, on the way down.
	var head := Vector2(head_x - lean * _progress, size.y * _progress)
	draw_circle(head, 46.0 * scale, Color(Palette.GOLD_LIGHT, 0.3), true, -1.0, true)
	draw_circle(head, 7.0 * scale, Color(1, 1, 1, 0.95), true, -1.0, true)


func _band(head_x: float, lean: float, width: float, colour: Color) -> void:
	var half := width * 0.5
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(head_x + half, 0.0),
			Vector2(head_x - half, 0.0),
			Vector2(head_x - lean - half, size.y),
			Vector2(head_x - lean + half, size.y),
		]),
		colour
	)
