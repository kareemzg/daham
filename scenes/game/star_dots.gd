class_name StarDots
extends Control
## The row of small stars in the level-complete window: one per level in the
## mansion, the finished ones gold.
##
## `StarBand` does the same job over the sky, where a star is a glow. On cream a
## glow is invisible, so these are small solid dots with a rim instead.

const GAP_SHARE := 0.62  ## gap as a fraction of a dot's diameter

var count: int = 20:
	set(value):
		count = maxi(value, 1)
		queue_redraw()

var lit: int = 0:
	set(value):
		lit = clampi(value, 0, count)
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
	# Fit the row to the width: N dots and N-1 gaps, the gap a share of a dot.
	var pitch := size.x / (float(count) + GAP_SHARE * float(count - 1))
	var radius := minf(pitch, size.y) * 0.5
	var step := pitch * (1.0 + GAP_SHARE)
	var middle := size.y * 0.5
	for i in count:
		# Right to left: the first star of the mansion is the rightmost one.
		var x := size.x - radius - float(i) * step
		if i < lit:
			draw_circle(Vector2(x, middle), radius, Palette.GOLD)
			draw_arc(Vector2(x, middle), radius, 0.0, TAU, 20, Palette.GOLD_DEEP, radius * 0.22, true)
		else:
			draw_circle(Vector2(x, middle), radius * 0.82, Color("D9CCB4"))
