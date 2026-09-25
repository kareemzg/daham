@tool
class_name GlossyPanel
extends Control
## A single rounded panel: `assets/ui/glossy_panel.gdshader` over
## `assets/ui/panel_shadow.gdshader`.
##
## The node owns two internal ColorRects, because a ColorRect is what hands a
## shader a clean 0..1 UV over its own rect. The face fills this node exactly;
## the shadow sits behind it on a larger quad that hangs outside the node's
## bounds, so giving something a shadow never moves anything the layout placed.
##
## Internal children are invisible to `get_children()` and are never written into
## a scene file, so callers can still `add_child()` labels and icons and have
## them land on top of the face.
##
## The node's rect includes the hard bottom edge. `face_height()` gives the part
## a caption or icon should be centred in.

enum Style {
	TILE,  ## a found letter: cream paper
	TILE_GOLD,  ## a doubled letter, and the hint's price tag
	WELL,  ## an empty grid cell: a hole in the sky
	CHIP,  ## a HUD counter
	DISC,  ## the wheel body
	WHEEL_TILE,
	WHEEL_TILE_PICKED,
	BUTTON_EMBER,  ## the one primary action on a screen
	BUTTON_RIVER,
	BUTTON_CREAM,
	PILL_RIVER,  ## the drag preview strip
	PANEL_NIGHT,  ## a card that sits ON the sky: dark face, teal rim
	BUTTON_MUTED,  ## a price you cannot afford: shown, never hidden
}

const FACE_SHADER := preload("res://assets/ui/glossy_panel.gdshader")
const SHADOW_SHADER := preload("res://assets/ui/panel_shadow.gdshader")

@export var style: Style = Style.TILE:
	set(value):
		style = value
		_apply()

## Extra pixels of hard edge under the face. -1 keeps the preset's own value.
@export var edge_override: float = -1.0:
	set(value):
		edge_override = value
		_apply()

## Corner radius in pixels. -1 keeps the preset's own value; pass half the width
## for a disc.
@export var radius_override: float = -1.0:
	set(value):
		radius_override = value
		_apply()

var _face := ColorRect.new()
var _shadow := ColorRect.new()
var _face_material := ShaderMaterial.new()
var _shadow_material := ShaderMaterial.new()


## Every number here is in the 1080-wide reference space, same as the layout.
## `shadow_blur` is a soft drop shadow; `shadow_spread` is a hard ring.
static func preset(for_style: int) -> Dictionary:
	match for_style:
		Style.TILE:
			return {
				"face_top": Color("FFFBF0"), "face_bottom": Color("F0DFBC"),
				"border_color": Palette.TILE_BORDER, "border_width": 3.0,
				"edge_color": Palette.TILE_EDGE, "bottom_edge": 7.0,
				"highlight": 0.55, "highlight_height": 0.2, "inner_shadow": 0.0,
				"radius": 0.2,
				"shadow_offset": 14.0, "shadow_blur": 22.0,
				"shadow_color": Color(0, 0, 0, 0.35),
			}
		Style.TILE_GOLD:
			return {
				"face_top": Color("FFE9A6"), "face_bottom": Color("F5CE58"),
				"border_color": Color("B8901E"), "border_width": 3.0,
				"edge_color": Palette.GOLD_DEEP, "bottom_edge": 6.0,
				"highlight": 0.5, "highlight_height": 0.2, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_offset": 10.0, "shadow_blur": 16.0,
				"shadow_color": Color(0, 0, 0, 0.3),
			}
		Style.WELL:
			return {
				"face_top": Color("07202F"), "face_bottom": Color("0B2B3C"),
				"border_color": Palette.WELL_BORDER, "border_width": 2.5,
				"edge_color": Palette.WELL_FACE, "bottom_edge": 0.0,
				"highlight": 0.0, "highlight_height": 0.2, "inner_shadow": 0.85,
				"radius": 0.2,
			}
		Style.CHIP:
			return {
				"face_top": Color("FFFBF0"), "face_bottom": Color("F0DFBC"),
				"border_color": Palette.TILE_BORDER, "border_width": 3.0,
				"edge_color": Palette.TILE_EDGE, "bottom_edge": 4.0,
				"highlight": 0.55, "highlight_height": 0.22, "inner_shadow": 0.0,
				"radius": 0.32,
				"shadow_offset": 17.0, "shadow_blur": 28.0,
				"shadow_color": Color(0, 0, 0, 0.35),
			}
		Style.DISC:
			# The one radial face: light from above centre, so the wheel reads as
			# a dome rather than a flat disc. Plus the dark rim inside its bottom.
			return {
				"face_top": Color("2F8594"), "face_mid": Color("1F6572"),
				"face_bottom": Color("163F4C"), "mid_stop": 0.55,
				"radial": 1.0, "gradient_center": Vector2(0.5, 0.3),
				"border_color": Palette.RIVER_EDGE, "border_width": 4.0,
				"edge_color": Color("0A2029"), "bottom_edge": 9.0,
				"highlight": 0.0, "highlight_height": 0.1, "inner_shadow": 0.0,
				"inner_top": 8.0, "inner_top_color": Color(1, 1, 1, 0.18),
				"inner_bottom": 17.0, "inner_bottom_color": Color(0, 0, 0, 0.18),
				"radius": 0.5,
				"shadow_offset": 39.0, "shadow_blur": 66.0,
				"shadow_color": Color(0, 0, 0, 0.45),
			}
		Style.WHEEL_TILE:
			return {
				"face_top": Color("FFFBF0"), "face_bottom": Color("F3E4C6"),
				"border_color": Palette.TILE_BORDER, "border_width": 3.0,
				"edge_color": Palette.TILE_EDGE, "bottom_edge": 8.0,
				"highlight": 0.6, "highlight_height": 0.26, "inner_shadow": 0.0,
				"radius": 0.5,
			}
		Style.WHEEL_TILE_PICKED:
			# No soft shadow: the design rings a picked tile instead.
			return {
				"face_top": Palette.RIVER_LIGHT, "face_bottom": Palette.RIVER,
				"border_color": Palette.RIVER_DEEP, "border_width": 3.0,
				"edge_color": Palette.RIVER_EDGE, "bottom_edge": 8.0,
				"highlight": 0.35, "highlight_height": 0.28, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_spread": 11.0, "shadow_color": Color(Palette.TRAIL, 0.22),
			}
		Style.BUTTON_EMBER:
			return {
				"face_top": Color("FF9A52"), "face_bottom": Color("D4560F"),
				"border_color": Color("C4500F"), "border_width": 3.0,
				"edge_color": Color("A8420C"), "bottom_edge": 9.0,
				"highlight": 0.4, "highlight_height": 0.24, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_offset": 22.0, "shadow_blur": 39.0,
				"shadow_color": Color(0, 0, 0, 0.4),
			}
		Style.BUTTON_RIVER:
			return {
				"face_top": Palette.RIVER_LIGHT, "face_bottom": Color("23707E"),
				"border_color": Palette.RIVER_DEEP, "border_width": 3.0,
				"edge_color": Palette.RIVER_EDGE, "bottom_edge": 9.0,
				"highlight": 0.36, "highlight_height": 0.24, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_offset": 22.0, "shadow_blur": 39.0,
				"shadow_color": Color(0, 0, 0, 0.4),
			}
		Style.PANEL_NIGHT:
			return {
				"face_top": Color("12384D"), "face_bottom": Color("0A2230"),
				"border_color": Color("2C5E73"), "border_width": 5.0,
				"edge_color": Color("081B26"), "bottom_edge": 11.0,
				"highlight": 0.0, "highlight_height": 0.0, "inner_shadow": 0.0,
				"inner_top": 3.0, "inner_top_color": Color(Color("7FD0DA"), 0.35),
				"radius": 0.22,
				"shadow_offset": 14.0, "shadow_blur": 26.0,
				"shadow_color": Color(0, 0, 0, 0.45),
			}
		Style.BUTTON_MUTED:
			return {
				"face_top": Color("D9CCB4"), "face_bottom": Color("C2B49A"),
				"border_color": Color("A2937C"), "border_width": 3.0,
				"edge_color": Color("9A8C74"), "bottom_edge": 6.0,
				"highlight": 0.14, "highlight_height": 0.3, "inner_shadow": 0.0,
				"radius": 0.34,
				"shadow_offset": 0.0, "shadow_blur": 0.0,
				"shadow_color": Color(0, 0, 0, 0.0),
			}
		Style.BUTTON_CREAM:
			return {
				"face_top": Color("FFFBF0"), "face_bottom": Color("F3E4C6"),
				"border_color": Palette.TILE_BORDER, "border_width": 3.0,
				"edge_color": Palette.TILE_EDGE, "bottom_edge": 9.0,
				"highlight": 0.6, "highlight_height": 0.26, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_offset": 22.0, "shadow_blur": 39.0,
				"shadow_color": Color(0, 0, 0, 0.4),
			}
		Style.PILL_RIVER:
			return {
				"face_top": Palette.RIVER, "face_bottom": Color("1F6572"),
				"border_color": Color("143C46"), "border_width": 3.0,
				"edge_color": Palette.RIVER_EDGE, "bottom_edge": 8.0,
				"highlight": 0.28, "highlight_height": 0.3, "inner_shadow": 0.0,
				"radius": 0.5,
				"shadow_offset": 22.0, "shadow_blur": 39.0,
				"shadow_color": Color(0, 0, 0, 0.4),
			}
	return preset(Style.TILE)


## A button made of this panel: a label on it and a real `Button` on top, so the
## control is reachable by keyboard and by a screen reader and not only by
## tapping a drawing. The caller connects `get_meta("button").pressed`.
static func make_button(style_preset: int, text: String, font: Font, ink: Color) -> GlossyPanel:
	var shell := GlossyPanel.new()
	shell.style = style_preset

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", ink)
	shell.add_child(label)
	shell.set_meta("label", label)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	# Anchored rather than sized by the caller. Every caller that placed one of
	# these sized it by hand, and the first one that forgot shipped a button
	# with no hit area at all — on the first screen a player ever sees, which
	# is the one nobody had tapped on a phone.
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.tooltip_text = text
	button.button_down.connect(func() -> void: shell.set_pressed(true))
	button.button_up.connect(func() -> void: shell.set_pressed(false))
	shell.add_child(button)
	shell.set_meta("button", button)
	return shell


## The same, with an icon in place of words. `label_text` names it for a screen
## reader, since there is nothing to read.
static func make_round(icon_kind: int, label_text: String) -> GlossyPanel:
	var shell := GlossyPanel.new()
	shell.style = Style.BUTTON_CREAM

	var icon := UiIcon.new()
	icon.kind = icon_kind
	shell.add_child(icon)
	shell.set_meta("icon", icon)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = label_text
	button.button_down.connect(func() -> void: shell.set_pressed(true))
	button.button_up.connect(func() -> void: shell.set_pressed(false))
	shell.add_child(button)
	shell.set_meta("button", button)
	return shell


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_shadow.color = Color.WHITE
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadow_material.shader = SHADOW_SHADER
	_shadow.material = _shadow_material
	add_child(_shadow, false, Node.INTERNAL_MODE_FRONT)

	_face.color = Color.WHITE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_material.shader = FACE_SHADER
	_face.material = _face_material
	add_child(_face, false, Node.INTERNAL_MODE_FRONT)


func _ready() -> void:
	_apply()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply()


## Height of the face, without the hard edge underneath it.
func face_height() -> float:
	return maxf(size.y - _edge_pixels(), 1.0)


func _edge_pixels() -> float:
	if edge_override >= 0.0:
		return edge_override
	return float(preset(style).get("bottom_edge", 0.0)) * _pixel_scale()


## The presets are written against the 1080-wide reference, same as the layout.
func _pixel_scale() -> float:
	var viewport_width := 1080.0
	var root := get_viewport()
	if root != null and root.get_visible_rect().size.x > 0.0:
		viewport_width = root.get_visible_rect().size.x
	return maxf(viewport_width / 1080.0, 0.25)


func _apply() -> void:
	if _face_material == null:
		return
	var data := preset(style)
	var scale := _pixel_scale()
	var radius: float = radius_override
	if radius < 0.0:
		radius = float(data["radius"]) * minf(size.x, face_height())

	_face.position = Vector2.ZERO
	_face.size = size
	var top: Color = data["face_top"]
	var bottom: Color = data["face_bottom"]
	_face_material.set_shader_parameter("rect_size", size)
	_face_material.set_shader_parameter("corner_radius", radius)
	_face_material.set_shader_parameter("face_top", top)
	_face_material.set_shader_parameter("face_mid", data.get("face_mid", top.lerp(bottom, 0.5)))
	_face_material.set_shader_parameter("face_bottom", bottom)
	_face_material.set_shader_parameter("mid_stop", data.get("mid_stop", 0.5))
	_face_material.set_shader_parameter("radial", data.get("radial", 0.0))
	_face_material.set_shader_parameter(
		"gradient_center", data.get("gradient_center", Vector2(0.5, 0.3))
	)
	_face_material.set_shader_parameter("border_color", data["border_color"])
	_face_material.set_shader_parameter("border_width", float(data["border_width"]) * scale)
	_face_material.set_shader_parameter("edge_color", data["edge_color"])
	_face_material.set_shader_parameter("bottom_edge", _edge_pixels())
	_face_material.set_shader_parameter("highlight", data["highlight"])
	_face_material.set_shader_parameter("highlight_height", data["highlight_height"])
	_face_material.set_shader_parameter("inner_shadow", data["inner_shadow"])
	_face_material.set_shader_parameter("inner_top", float(data.get("inner_top", 0.0)) * scale)
	_face_material.set_shader_parameter(
		"inner_top_color", data.get("inner_top_color", Color(1, 1, 1, 0.18))
	)
	_face_material.set_shader_parameter(
		"inner_bottom", float(data.get("inner_bottom", 0.0)) * scale
	)
	_face_material.set_shader_parameter(
		"inner_bottom_color", data.get("inner_bottom_color", Color(0, 0, 0, 0.18))
	)

	var blur := float(data.get("shadow_blur", 0.0)) * scale
	var spread := float(data.get("shadow_spread", 0.0)) * scale
	var offset := float(data.get("shadow_offset", 0.0)) * scale
	var pad := blur + spread
	_shadow.visible = pad > 0.0
	if _shadow.visible:
		_shadow.size = size + Vector2(pad, pad) * 2.0
		_shadow.position = Vector2(-pad, -pad + offset)
		_shadow_material.set_shader_parameter("rect_size", _shadow.size)
		_shadow_material.set_shader_parameter("corner_radius", radius)
		_shadow_material.set_shader_parameter("blur", blur)
		_shadow_material.set_shader_parameter("spread", spread)
		_shadow_material.set_shader_parameter(
			"shadow_color", data.get("shadow_color", Color(0, 0, 0, 0.4))
		)


## Presses the panel down onto its edge, the only press feedback the design uses.
func set_pressed(pressed: bool) -> void:
	var full := float(preset(style).get("bottom_edge", 0.0)) * _pixel_scale()
	edge_override = full * 0.25 if pressed else full
	position.y += (full * 0.75) * (1.0 if pressed else -1.0)
