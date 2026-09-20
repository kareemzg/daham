@tool
class_name UiIcon
extends Control
## One icon, drawn from an SVG under `assets/ui/icons/`.
##
## The SVGs are imported at five times their 64px box, so the same file stays
## crisp on a HUD chip and on a button. Godot rasterises SVG through ThorVG,
## which handles paths, strokes and gradients but not filters, masks or text:
## keep new icons to those primitives.
##
## `@tool` so an icon shows itself in the Godot editor, not just at run time.

enum Kind { LANTERN, COIN, MOON, HINT, SHUFFLE, SETTINGS, STAR }

const COIN := preload("res://assets/ui/icons/coin.svg")
const LANTERN_ON := preload("res://assets/ui/icons/lantern_on.svg")
const LANTERN_OFF := preload("res://assets/ui/icons/lantern_off.svg")
const MOON_DISC := preload("res://assets/ui/icons/moon_disc.svg")
const HINT := preload("res://assets/ui/icons/hint.svg")
const SHUFFLE := preload("res://assets/ui/icons/shuffle.svg")
const SETTINGS := preload("res://assets/ui/icons/settings.svg")
const STAR_LIT := preload("res://assets/ui/icons/star_lit.svg")
const STAR_DIM := preload("res://assets/ui/icons/star_dim.svg")

@export var kind: Kind = Kind.COIN:
	set(value):
		kind = value
		queue_redraw()

## Lanterns and stars read this as lit or spent; the moon reads it as its phase.
@export_range(0.0, 1.0) var level: float = 1.0:
	set(value):
		level = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func texture() -> Texture2D:
	match kind:
		Kind.LANTERN:
			return LANTERN_ON if level > 0.5 else LANTERN_OFF
		Kind.COIN:
			return COIN
		Kind.MOON:
			return MOON_DISC
		Kind.HINT:
			return HINT
		Kind.SHUFFLE:
			return SHUFFLE
		Kind.SETTINGS:
			return SETTINGS
		Kind.STAR:
			return STAR_LIT if level > 0.5 else STAR_DIM
	return COIN


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Fit the art inside the box without stretching it. The lantern is taller
	# than it is wide, so assuming a square would squash it.
	var art := texture()
	var art_size := Vector2(art.get_width(), art.get_height())
	var fit := minf(size.x / art_size.x, size.y / art_size.y)
	var drawn := art_size * fit
	var box := Rect2((size - drawn) * 0.5, drawn)
	draw_texture_rect(art, box, false)
	if kind == Kind.MOON:
		_draw_moon_phase(box)


## The lit part of the moon, over the disc but inside its rim. Drawn rather than
## stored because it changes with every bonus word.
func _draw_moon_phase(box: Rect2) -> void:
	if level <= 0.01:
		return
	var middle := box.position + box.size * 0.5
	var radius := box.size.x * 0.4
	var points := PackedVector2Array()
	var steps := 36
	# Waxing from the right: the outer half-disc, then an edge that starts as a
	# straight line and bulges left until the disc is full.
	for i in steps + 1:
		var angle := -PI * 0.5 + float(i) / float(steps) * PI
		points.append(middle + Vector2(cos(angle), sin(angle)) * radius)
	for i in steps + 1:
		var angle := PI * 0.5 - float(i) / float(steps) * PI
		points.append(
			middle + Vector2(cos(angle) * radius * (1.0 - 2.0 * level), sin(angle) * radius)
		)
	draw_colored_polygon(points, Palette.GOLD_LIGHT)
	# draw_colored_polygon has no antialiasing, so the crescent's curve comes out
	# stepped. Tracing the same outline with an antialiased line smooths it.
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Palette.GOLD_LIGHT, 1.5, true)
