class_name SkyBackdrop
extends Control
## The night sky: one gradient and one field of stars, behind every screen.
##
## It is a single object on purpose. The sky never transitions; screens fade in
## and out over it. Two screens each drawing their own sky would flicker at the
## seam even when both draw exactly the same thing, and the game would read as a
## stack of screens instead of one place.

var stars: StarField
var _sky: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = _make_sky()
	stars = StarField.new()
	add_child(stars)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		stars.position = Vector2.ZERO
		stars.size = size
		queue_redraw()


func _make_sky() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		Palette.SKY_TOP, Palette.SKY_MID, Palette.SKY_LOW, Palette.SKY_BOTTOM
	])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 8
	texture.height = 256
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	return texture


func _draw() -> void:
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false)
