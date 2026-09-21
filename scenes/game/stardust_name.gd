class_name StardustName
extends Control
## A name gathering itself out of stardust, letter by letter, and then glowing
## the way the stars it was made from do.
##
## The letters are revealed after shaping rather than by growing the string, so
## the word is laid out once and each glyph simply arrives. Growing the string
## instead would reshape it on every letter and the ones already placed would
## jump between their medial and final forms.

signal formed

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const MOTES := 16
## How long one letter takes to gather, and how long the glow takes to come up.
const LETTER_SECONDS := 0.2
const GLOW_SECONDS := 0.9

var label: Label

## 0 while the name is dust, 1 when every letter has arrived.
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		if label != null:
			label.visible_characters = int(round(progress * float(label.text.length())))
		queue_redraw()

## Comes up once the name is whole.
var glow: float = 0.0:
	set(value):
		glow = clampf(value, 0.0, 1.0)
		queue_redraw()

var _halo: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", DISPLAY_FONT)
	label.add_theme_color_override("font_color", Palette.GOLD_LIGHT)
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.visible_characters = 0
	add_child(label)
	_halo = _make_halo()


func _make_halo() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	ramp.colors = PackedColorArray([
		Color(Palette.GOLD_LIGHT, 0.5), Color(Palette.GOLD_LIGHT, 0.16),
		Color(Palette.GOLD_LIGHT, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = ramp
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		label.position = Vector2.ZERO
		label.size = size
		queue_redraw()


## Sets the words. It does NOT reset the gathering: a resize calls the layout,
## the layout used to call this, and a name half formed went back to dust in the
## middle of forming.
func setup(text: String, font_size: int) -> void:
	label.text = text
	set_font_size(font_size)


func set_font_size(font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	queue_redraw()


## Gathers the name, then lights it. `formed` fires when both are done.
func play() -> void:
	progress = 0.0
	glow = 0.0
	label.visible_characters = 0
	var seconds := maxf(float(label.text.length()) * LETTER_SECONDS, 0.4)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: progress = v, 0.0, 1.0, seconds)
	tween.tween_method(func(v: float) -> void: glow = v, 0.0, 1.0, GLOW_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: formed.emit())


## Skips the gathering. For tests, and for a player who taps through.
func settle() -> void:
	progress = 1.0
	glow = 1.0


func _draw() -> void:
	if label == null or label.text.is_empty() or size.x <= 0.0:
		return
	var count := label.text.length()
	var span := 1.0 / float(count)

	for i in count:
		var bounds := label.get_character_bounds(i)
		if bounds.size.x <= 0.0:
			continue
		var centre := bounds.position + bounds.size * 0.5
		var arrival := clampf((progress - float(i) * span) / span, 0.0, 1.0)
		if arrival <= 0.0:
			continue
		if arrival < 1.0:
			_dust(i, centre, bounds.size, arrival)
		elif glow > 0.0:
			var reach := maxf(bounds.size.x, bounds.size.y * 0.5) * 2.4
			var box := Rect2(centre - Vector2(reach, reach) * 0.5, Vector2(reach, reach))
			draw_texture_rect(_halo, box, false, Color(1, 1, 1, glow * 0.85))


## The motes for one letter, drawn from a seed so they do not crawl between
## frames. They come in from a ring and settle onto the glyph.
func _dust(index: int, centre: Vector2, letter: Vector2, arrival: float) -> void:
	var rng := RandomNumberGenerator.new()
	var reach := maxf(letter.x, letter.y) * 1.6
	for m in MOTES:
		rng.seed = hash(Vector2i(index, m))
		var angle := rng.randf() * TAU
		var away := reach * (0.6 + rng.randf() * 0.9)
		var spot := centre + Vector2(cos(angle), sin(angle)) * away * (1.0 - arrival)
		spot += Vector2(
			rng.randf_range(-letter.x, letter.x), rng.randf_range(-letter.y, letter.y)
		) * 0.35 * (1.0 - arrival)
		# Bright as they gather, gone by the time the letter is whole.
		var alpha := arrival * (1.0 - arrival) * 3.2
		draw_circle(
			spot, maxf(letter.y * 0.035, 1.0) * (0.6 + arrival * 0.8),
			Color(Palette.GOLD_LIGHT, clampf(alpha, 0.0, 0.9)), true, -1.0, true
		)
