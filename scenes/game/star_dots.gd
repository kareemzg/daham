class_name StarDots
extends Control
## The row of small stars in the level-complete window: one per level in the
## mansion, the finished ones gold.
##
## `StarBand` does the same job over the sky, where a star is a glow. On cream a
## glow is invisible, so these are small solid dots with a rim instead.

const GAP_SHARE := 0.62  ## gap as a fraction of a dot's diameter
## A capsule bar's gap, as a share of its own height. The design draws four
## units of gap to seven of height, and taking it from the height is what keeps
## the ratio right at any size without the bar being told the screen's scale.
const CAPSULE_GAP_SHARE := 0.571

var count: int = 20:
	set(value):
		count = maxi(value, 1)
		queue_redraw()

var lit: int = 0:
	set(value):
		lit = clampi(value, 0, count)
		queue_redraw()

## Two shapes for two places. The level-complete window shows small round stars
## with air between them; the sky map's card shows a bar of capsules that fills
## its width. The design draws them differently, so this does too.
var capsule: bool = false:
	set(value):
		capsule = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func setup(total: int, already_lit: int) -> void:
	count = total
	lit = already_lit


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if capsule:
		_draw_capsules()
		return
	# Fit the row to the width: N dots and N-1 gaps, the gap a share of a dot.
	var pitch := size.x / (float(count) + GAP_SHARE * float(count - 1))
	var radius := minf(pitch, size.y) * 0.5
	var step := pitch * (1.0 + GAP_SHARE)
	var middle := size.y * 0.5
	for i in count:
		# Right to left: the first star of the mansion is the rightmost one.
		var x := size.x - radius - float(i) * step
		if i < lit:
			draw_circle(Vector2(x, middle), radius, Palette.GOLD, true, -1.0, true)
			draw_arc(Vector2(x, middle), radius, 0.0, TAU, 20, Palette.GOLD_DEEP, radius * 0.22, true)
		else:
			draw_circle(Vector2(x, middle), radius * 0.82, Color("D9CCB4"), true, -1.0, true)


## Segments that share the width between them, each one fully rounded.
func _draw_capsules() -> void:
	var gap := size.y * CAPSULE_GAP_SHARE
	var width := (size.x - gap * float(count - 1)) / float(count)
	var radius := size.y * 0.5
	for i in count:
		# Right to left: the first star of the mansion is the rightmost segment.
		var x := size.x - width - float(i) * (width + gap)
		var colour := Palette.GOLD if i < lit else Color("D9CCB4")
		draw_style_box(_capsule_box(colour, radius), Rect2(Vector2(x, 0.0), Vector2(width, size.y)))


func _capsule_box(fill: Color, radius: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(maxf(radius, 1.0)))
	box.anti_aliasing = true
	return box
