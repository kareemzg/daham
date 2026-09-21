class_name SkyPopup
extends Control
## A window that opens the way a star does: a point of light that widens into
## the panel, with a halo that overtakes it and fades.
##
## Callers size `panel` and fill it with children, then call `open()`. The dim
## layer behind swallows taps, so nothing underneath reacts while it is up.

signal closed

const DIM_COLOUR := Color("04121C")
const DIM_ALPHA := 0.55
const OPEN_SECONDS := 0.2
const CLOSE_SECONDS := 0.13

## The window itself. Add your content to this, not to the popup.
var panel: GlossyPanel

## How far the content hangs above the panel's top edge, for a crest badge that
## straddles it. The panel is pushed down by half of this so the window still
## reads as centred rather than sitting low on the screen.
var overhang: float = 0.0

var _dim := ColorRect.new()
var _halo := TextureRect.new()
var _halo_texture: GradientTexture2D


## Whether tapping the dark outside the panel closes the window. True for a
## window you opened yourself and can simply leave; false for one that is asking
## you something, where dismissing it by accident would skip the answer.
var dismiss_on_tap: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_dim.color = DIM_COLOUR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_halo_texture = _make_halo()
	_halo.texture = _halo_texture
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.stretch_mode = TextureRect.STRETCH_SCALE
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_halo)

	panel = GlossyPanel.new()
	panel.style = GlossyPanel.Style.CHIP
	add_child(panel)


func _make_halo() -> GradientTexture2D:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([
		Color(Palette.GOLD_LIGHT, 0.42), Color(Palette.GOLD_LIGHT, 0.14),
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
		_place()


func _place() -> void:
	_dim.position = Vector2.ZERO
	_dim.size = size
	panel.position = (size - panel.size) * 0.5 + Vector2(0.0, overhang * 0.5)
	panel.pivot_offset = panel.size * 0.5
	var reach := panel.size * 2.0
	_halo.size = reach
	_halo.position = (size - reach) * 0.5
	_halo.pivot_offset = reach * 0.5


func _gui_input(event: InputEvent) -> void:
	if not dismiss_on_tap or panel == null:
		return
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# The crest straddles the panel's top edge, so the window is taller than its
	# panel and a tap on the badge must not read as a tap outside.
	var reach := Rect2(
		panel.position - Vector2(0.0, overhang), panel.size + Vector2(0.0, overhang)
	)
	if not reach.has_point(click.position):
		accept_event()
		close()


func open() -> void:
	_place()
	visible = true
	_dim.modulate.a = 0.0
	_dim.color = Color(DIM_COLOUR, DIM_ALPHA)
	panel.scale = Vector2(0.6, 0.6)
	panel.modulate.a = 0.0
	_halo.scale = Vector2(0.15, 0.15)
	_halo.modulate.a = 1.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, OPEN_SECONDS)
	# Alpha beats scale so the window never reads as a ghost being stretched.
	tween.tween_property(panel, "modulate:a", 1.0, OPEN_SECONDS * 0.6)
	tween.tween_property(panel, "scale", Vector2.ONE, OPEN_SECONDS) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The halo runs ahead of the panel and is gone by the time it settles.
	tween.tween_property(_halo, "scale", Vector2.ONE, OPEN_SECONDS)
	tween.tween_property(_halo, "modulate:a", 0.0, OPEN_SECONDS)


func close() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 0.0, CLOSE_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, CLOSE_SECONDS)
	tween.tween_property(panel, "scale", Vector2(0.85, 0.85), CLOSE_SECONDS)
	tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


## Skips the animation. For tests, and for a player who taps through.
func settle() -> void:
	visible = true
	_place()
	_dim.modulate.a = 1.0
	panel.scale = Vector2.ONE
	panel.modulate.a = 1.0
	_halo.modulate.a = 0.0
