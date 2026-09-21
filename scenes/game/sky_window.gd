class_name SkyWindow
extends SkyPopup
## A window built from the standard parts, stacked top to bottom: a crest badge
## that overhangs the top edge, a title, an optional line or two of prose, any
## rows the window needs, and its buttons at the foot.
##
## Describing a window instead of positioning one is what keeps four of them
## consistent. The padding, the gaps, the type sizes and the button heights live
## here once, so a new window is a handful of calls and cannot drift.
##
## Every number below is in the 1080-wide reference space and is multiplied by
## the screen's scale in `relayout()`, exactly as `game.gd` does.

const WIDTH := 760.0
const PAD_X := 44.0
const CREST := 172.0
const CREST_ICON := 92.0
const TITLE_SIZE := 58.0
const TITLE_LINE := 78.0
const BODY_SIZE := 30.0
const BODY_LINE := 44.0
const BUTTON_HEIGHT := 108.0
const GHOST_HEIGHT := 76.0
const GAP := 24.0
const TOP_PAD := 26.0
const BOTTOM_PAD := 40.0

## The round badge over the top edge, and the icon inside it.
var crest: GlossyPanel
var crest_icon: UiIcon
## Present only when `add_close_cross()` was called.
var close_button: GlossyPanel
var title_label: Label
var body_label: Label

var _display_font: Font
var _ui_font: Font
var _rows: Array = []
var _buttons: Array = []
var _body_lines: int = 0


## Fonts come from the screen, so a window never reaches for a resource itself.
func configure(display_font: Font, ui_font: Font) -> void:
	_display_font = display_font
	_ui_font = ui_font
	panel.style = GlossyPanel.Style.CHIP

	crest = GlossyPanel.new()
	crest.style = GlossyPanel.Style.BUTTON_CREAM
	panel.add_child(crest)
	crest_icon = UiIcon.new()
	crest.add_child(crest_icon)

	title_label = _label(_display_font, Palette.TILE_INK)
	panel.add_child(title_label)

	body_label = _label(_ui_font, Color("6B5942"))
	body_label.visible = false
	panel.add_child(body_label)

	# The crest hangs half its height above the panel, so centring the panel
	# alone would sit the whole window low. `overhang` pushes it back down.
	overhang = CREST * 0.5


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


func set_crest(kind: int, level: float = 1.0) -> void:
	crest_icon.kind = kind
	crest_icon.level = level


func set_title(text: String) -> void:
	title_label.text = text


## Break the prose yourself with newlines. A Label that wraps on its own refuses
## to be shorter than the height it works out at its own minimum width, which is
## one short word per line: it claimed twenty-seven lines for a caption of five
## words and centred them off the bottom of the panel. Breaking the lines here
## means the window knows its own height before it is drawn.
func set_body(text: String) -> void:
	body_label.text = text
	body_label.visible = not text.is_empty()
	_body_lines = 0 if text.is_empty() else text.count("\n") + 1


## A strip of the window's own: a star row, a countdown, a settings switch.
func add_row(node: Control, height: float, gap: float = GAP) -> Control:
	panel.add_child(node)
	_rows.append({"node": node, "height": height, "gap": gap})
	return node


## Returns the panel. Connect through `panel.get_meta("button").pressed`, the
## same way the screen's own buttons work, so the control is reachable by
## keyboard and by a screen reader and not only by tapping a drawing.
func add_button(
	style: int, text: String, icon_kind: int = -1, height: float = BUTTON_HEIGHT,
	gap: float = GAP
) -> GlossyPanel:
	var shell := GlossyPanel.new()
	shell.style = style
	panel.add_child(shell)

	var ink := Color("FFF4E8") if style == GlossyPanel.Style.BUTTON_EMBER else Color("5A431A")
	var label := _label(_ui_font, ink)
	label.text = text
	shell.add_child(label)
	shell.set_meta("label", label)

	if icon_kind >= 0:
		var icon := UiIcon.new()
		icon.kind = icon_kind
		shell.add_child(icon)
		shell.set_meta("icon", icon)

	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = text
	button.pressed.connect(func() -> void: shell.set_pressed(false))
	button.button_down.connect(func() -> void: shell.set_pressed(true))
	button.button_up.connect(func() -> void: shell.set_pressed(false))
	shell.add_child(button)
	shell.set_meta("button", button)

	_buttons.append({"shell": shell, "height": height, "gap": gap})
	return shell


## The corner cross. A window you opened yourself closes without having to
## leave where you are, and every such window wants the same one.
func add_close_cross() -> GlossyPanel:
	close_button = GlossyPanel.new()
	close_button.style = GlossyPanel.Style.BUTTON_CREAM
	panel.add_child(close_button)
	var cross := _label(_ui_font, Color("6B5942"))
	cross.text = "×"
	close_button.add_child(cross)
	close_button.set_meta("label", cross)
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = "إغلاق"
	button.pressed.connect(func() -> void: close_requested.emit())
	button.button_down.connect(func() -> void: close_button.set_pressed(true))
	button.button_up.connect(func() -> void: close_button.set_pressed(false))
	close_button.add_child(button)
	close_button.set_meta("button", button)
	return close_button


func _layout_close_cross(s: float) -> void:
	if close_button == null:
		return
	var side := 72.0 * s
	close_button.position = Vector2(28.0 * s, 26.0 * s)
	close_button.size = Vector2(side, side)
	close_button.edge_override = 6.0 * s
	close_button.radius_override = side * 0.5
	var cross: Label = close_button.get_meta("label")
	cross.position = Vector2.ZERO
	cross.size = Vector2(side, close_button.face_height())
	cross.add_theme_font_size_override("font_size", int(46.0 * s))
	var button: Button = close_button.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)


## The buttons, in the order they were added. A window that draws a way out but
## never wires it should fail a test, and that needs reaching them.
func buttons() -> Array[GlossyPanel]:
	var shells: Array[GlossyPanel] = []
	for entry: Dictionary in _buttons:
		shells.append(entry["shell"])
	return shells


## Stacks everything and gives the panel the height it needs. Call it whenever
## the screen resizes, before or after the window is open.
func relayout(s: float) -> void:
	var width := WIDTH * s
	var inner := width - PAD_X * 2.0 * s
	var crest_side := CREST * s
	var y := crest_side * 0.5 + TOP_PAD * s

	title_label.position = Vector2(PAD_X * s, y)
	title_label.size = Vector2(inner, TITLE_LINE * s)
	title_label.add_theme_font_size_override("font_size", int(TITLE_SIZE * s))
	y += TITLE_LINE * s

	if body_label.visible:
		body_label.add_theme_font_size_override("font_size", int(BODY_SIZE * s))
		body_label.size = Vector2(inner, float(_body_lines) * BODY_LINE * s)
		# A line wider than the panel would push the box out; centring on what
		# it settles at keeps the words in the middle either way.
		body_label.position = Vector2(
			(width - body_label.size.x) * 0.5, y + GAP * 0.5 * s
		)
		var body_height := body_label.size.y
		y += GAP * 0.5 * s + body_height

	for row: Dictionary in _rows:
		var node: Control = row["node"]
		y += float(row["gap"]) * s
		node.position = Vector2(PAD_X * s, y)
		node.size = Vector2(inner, float(row["height"]) * s)
		y += float(row["height"]) * s

	for entry: Dictionary in _buttons:
		var shell: GlossyPanel = entry["shell"]
		var height := float(entry["height"]) * s
		y += float(entry["gap"]) * s
		shell.position = Vector2(PAD_X * s, y)
		# The bottom edge is drawn below the face, so the node is taller than
		# the face by that much and the next thing down has to clear it.
		shell.edge_override = 14.0 * s
		shell.radius_override = height * 0.5
		shell.size = Vector2(inner, height + 14.0 * s)
		_layout_button_contents(shell, inner, height, s)
		y += height + 14.0 * s

	panel.edge_override = 12.0 * s
	panel.radius_override = 52.0 * s
	panel.size = Vector2(width, y + BOTTOM_PAD * s)

	crest.size = Vector2(crest_side, crest_side)
	crest.position = Vector2((width - crest_side) * 0.5, -crest_side * 0.5)
	crest.edge_override = 10.0 * s
	crest.radius_override = crest_side * 0.5
	var icon_side := CREST_ICON * s
	var drawing := crest_icon.texture()
	var aspect := float(drawing.get_width()) / float(maxi(drawing.get_height(), 1))
	# A wide drawing keeps its width and gives up height, so it fills the badge
	# instead of being letterboxed into a squiggle.
	var icon_size := (
		Vector2(icon_side * 1.5, icon_side * 1.5 / aspect) if aspect > 1.4
		else Vector2(icon_side, icon_side)
	)
	crest_icon.size = icon_size
	crest_icon.position = (
		Vector2(crest_side, crest.face_height()) - icon_size
	) * 0.5

	_layout_close_cross(s)
	overhang = crest_side * 0.5
	_place()


func _layout_button_contents(shell: GlossyPanel, width: float, height: float, s: float) -> void:
	var label: Label = shell.get_meta("label")
	var font_size := int(36.0 * s)
	label.add_theme_font_size_override("font_size", font_size)
	var button: Button = shell.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(width, height)

	if not shell.has_meta("icon"):
		label.position = Vector2.ZERO
		label.size = Vector2(width, height)
		return

	# Icon and words read as one thing, so they are centred as one pair. In
	# Arabic the icon leads, which puts it on the right.
	var icon: UiIcon = shell.get_meta("icon")
	var icon_side := height * 0.46
	var text_width := minf(label.get_minimum_size().x, width - icon_side - 40.0 * s)
	var pair := text_width + 16.0 * s + icon_side
	var left := (width - pair) * 0.5
	label.position = Vector2(left, 0.0)
	label.size = Vector2(text_width, height)
	icon.size = Vector2(icon_side, icon_side)
	icon.position = Vector2(left + text_width + 16.0 * s, (height - icon_side) * 0.5)
