class_name SkyBackdrop
extends Control
## The night sky: one gradient and one field of stars, behind every screen.
##
## It is a single object on purpose. The sky never transitions; screens fade in
## and out over it. Two screens each drawing their own sky would flicker at the
## seam even when both draw exactly the same thing, and the game would read as a
## stack of screens instead of one place.

const MILKY_VIOLET := Palette.MILKY_VIOLET
const MILKY_ROSE := Palette.MILKY_ROSE

## How slowly the band crosses. Ninety seconds for one full swing: slow enough
## that nobody catches it moving, fast enough that a screen looked at twice is
## not the same picture. A sky that turns is a place; a sky that holds still is
## a wallpaper.
const DRIFT_SECONDS := 90.0
## How far it travels, as a share of the width.
const DRIFT_SHARE := 0.10
## The band has no detail, so it needs no frame rate. Eight is under a third of
## what `StarField` already costs and the motion still reads as continuous.
const DRIFT_FPS := 8.0

var stars: StarField
## The sky's standing population is `stars`; these are what crosses it.
var meteors: ShootingStars
var _sky: GradientTexture2D
var _milky: GradientTexture2D
var _drift: float = 0.0
var _since_redraw: float = 0.0

## How much light is left in the sky, 1.0 down to about half.
##
## There is no losing in this game, only light that lessens: every lantern the
## player spends takes a degree off the sky and off the wheel's disc, and
## nothing is said about it. The stars dim less than the gradient does, so a
## darker sky reads as deeper night rather than as a screen turned down.
var light: float = 1.0:
	set(value):
		var next := clampf(value, 0.0, 1.0)
		if is_equal_approx(next, light):
			return
		light = next
		# The declaration's own initialiser can run before `_init()` has made
		# the field, so this is not a needless guard.
		if stars != null:
			stars.light = 0.5 + 0.5 * light
		if meteors != null:
			meteors.light = 0.5 + 0.5 * light
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Still in the editor, like the star field: a preview that redraws forever
	# makes the whole editor busy for no gain.
	set_process(not Engine.is_editor_hint())
	_sky = _make_sky()
	_milky = _make_milky()
	stars = StarField.new()
	add_child(stars)
	meteors = ShootingStars.new()
	add_child(meteors)


func _process(delta: float) -> void:
	_drift += delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / DRIFT_FPS:
		_since_redraw = 0.0
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		stars.position = Vector2.ZERO
		stars.size = size
		meteors.position = Vector2.ZERO
		meteors.size = size
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


## المجرّة: a soft diagonal band, violet through dusty rose and back.
##
## It is drawn as a stretched gradient rather than as particles because it has
## no detail to lose — it is a wash, and a wash costs one quad. The angle comes
## from `fill_from`/`fill_to`, so the band is diagonal without a rotation.
func _make_milky() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.34, 0.5, 0.66, 1.0])
	ramp.colors = PackedColorArray([
		Color(MILKY_VIOLET, 0.0),
		Color(MILKY_VIOLET, 0.30),
		Color(MILKY_ROSE, 0.26),
		Color(MILKY_VIOLET, 0.24),
		Color(MILKY_VIOLET, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.width = 128
	texture.height = 128
	texture.fill_from = Vector2(0.12, 0.0)
	texture.fill_to = Vector2(0.88, 1.0)
	return texture


func _draw() -> void:
	# Multiplied rather than washed with black: the hue stays, only the
	# brightness goes, which is what a night getting darker looks like.
	draw_texture_rect(_sky, Rect2(Vector2.ZERO, size), false, Color(light, light, light))
	# The band dims with the sky, and a little faster: the lanterns take the
	# faint things first, which is what a darkening night does.
	var band := light * light
	# Drawn wider than the control and slid inside that margin, so the band's
	# own faded ends never walk into view at the edges.
	var reach := size.x * DRIFT_SHARE
	var swing := sin(_drift * TAU / DRIFT_SECONDS) * reach
	draw_texture_rect(
		_milky,
		Rect2(Vector2(-reach + swing, 0.0), Vector2(size.x + reach * 2.0, size.y)),
		false, Color(1, 1, 1, band)
	)
