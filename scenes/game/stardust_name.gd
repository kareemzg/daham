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
## Dense enough that the dust reads as the letter itself coming apart, which is
## what the reference does and sixteen motes never could.
const MOTES := 200
## How long one letter takes to gather, and how long the glow takes to come up.
const LETTER_SECONDS := 0.26
const GLOW_SECONDS := 0.9
## The band of the line box the letters actually sit in. The box is the whole
## line, ascenders and descenders included, and dust spread over all of it would
## sit well above and below the ink.
const INK_TOP := 0.3
const INK_BOTTOM := 0.82
## How many letters' worth of time one letter takes to gather. Above one the
## letters overlap, which is what gives the plume a length: without it only one
## letter is ever in flight and the dust reads as a sprinkle, not a stream.
const OVERLAP := 2.4

var label: Label

## 0 while the name is dust, 1 when every letter has arrived.
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		_reveal()
		queue_redraw()

## Comes up once the name is whole.
var glow: float = 0.0:
	set(value):
		glow = clampf(value, 0.0, 1.0)
		_shine()
		queue_redraw()

## Copies of the word behind it, a little larger and faint, added together.
## A radial texture over each letter's box glows its empty corners too and comes
## out a grey smudge; light shaped like the letters is what a glow is.
var _glows: Array[Label] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The dust and the halo are light, so they ADD to the sky rather than being
	# laid over it. Mixed normally, gold at low opacity turns grey against the
	# navy and the plume reads as ash instead of stars.
	var lit := CanvasItemMaterial.new()
	lit.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = lit

	for i in 3:
		var bloom := _make_label()
		bloom.add_theme_color_override("font_color", Palette.GOLD_LIGHT)
		add_child(bloom)
		_glows.append(bloom)

	label = _make_label()
	# Its own material, or it would inherit the additive one above and the
	# letters would blow out.
	label.material = CanvasItemMaterial.new()
	label.add_theme_color_override("font_color", Palette.GOLD_LIGHT)
	add_child(label)


func _make_label() -> Label:
	var made := Label.new()
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	made.text_direction = Control.TEXT_DIRECTION_RTL
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_override("font", DISPLAY_FONT)
	made.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	made.visible_characters = 0
	return made


## The glow copies follow the reveal exactly, so a letter starts glowing as it
## lands rather than waiting for the rest of the name.
func _reveal() -> void:
	if label == null:
		return
	var shown := int(round(progress * float(label.text.length())))
	label.visible_characters = shown
	for bloom in _glows:
		bloom.visible_characters = shown


func _shine() -> void:
	for i in _glows.size():
		_glows[i].modulate.a = (0.1 + glow * 0.14) * (1.0 - float(i) * 0.28)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place()
		queue_redraw()


func _place() -> void:
	if label == null:
		return
	label.position = Vector2.ZERO
	label.size = size
	for i in _glows.size():
		var bloom := _glows[i]
		bloom.position = Vector2.ZERO
		bloom.size = size
		bloom.pivot_offset = size * 0.5
		# Each copy a little wider than the last, so their edges stack into a
		# soft rim instead of one hard outline.
		bloom.scale = Vector2.ONE * (1.0 + 0.016 * float(i + 1))


## Sets the words. It does NOT reset the gathering: a resize calls the layout,
## the layout used to call this, and a name half formed went back to dust in the
## middle of forming.
func setup(text: String, font_size: int) -> void:
	label.text = text
	for bloom in _glows:
		bloom.text = text
	set_font_size(font_size)
	_reveal()
	_shine()


func set_font_size(font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	for bloom in _glows:
		bloom.add_theme_font_size_override("font_size", font_size)
	_place()
	queue_redraw()


## Gathers the name, then lights it. `formed` fires when both are done.
func play() -> void:
	progress = 0.0
	glow = 0.0
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
	var step := 1.0 / (float(count) + OVERLAP - 1.0)
	var s := size.x / 1080.0

	for i in count:
		var bounds := label.get_character_bounds(i)
		if bounds.size.x <= 0.0:
			continue
		var arrival := clampf((progress - float(i) * step) / (step * OVERLAP), 0.0, 1.0)
		if arrival <= 0.0:
			continue

		# A landed letter is drawn and glowing already; only the ones still on
		# their way need dust.
		if arrival >= 1.0:
			continue

		# The ink band of the letter, not its whole line box.
		var ink := Rect2(
			Vector2(bounds.position.x, bounds.position.y + bounds.size.y * INK_TOP),
			Vector2(bounds.size.x, bounds.size.y * (INK_BOTTOM - INK_TOP))
		)
		Stardust.over_rect(self, ink, arrival, i, s, MOTES)
