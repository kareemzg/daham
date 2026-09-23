@tool
class_name TitleScreen
extends Control
## The way in: the name, where you stopped, and two ways forward.
##
## It draws no sky. The shell behind it does, because the sky never transitions
## and two of them would flicker at the seam.

signal play_requested
signal map_requested
signal settings_requested
signal cards_requested
signal shop_requested

const REF_WIDTH := 1080.0
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

var play_button: GlossyPanel
var map_button: GlossyPanel
var settings_button: GlossyPanel

var _title: Label
var _subtitle: Label
var _where: Label
var _version: Label
var _round: Array[GlossyPanel] = []


func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	for child in get_children():
		if child.owner == null:
			child.queue_free()
	_round.clear()

	_title = _label(DISPLAY_FONT, Palette.GOLD_LIGHT)
	_title.text = "سماء العرب"
	add_child(_title)

	_subtitle = _label(UI_BOLD_FONT, Palette.MUTED)
	_subtitle.text = "سمِّ النجوم، تُضئ السماء"
	add_child(_subtitle)

	_where = _label(UI_BOLD_FONT, Color("8FAEBF"))
	add_child(_where)

	play_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_EMBER, "واصل", UI_BOLD_FONT, Color("FFF4E8")
	)
	add_child(play_button)
	(play_button.get_meta("button") as Button).pressed.connect(
		func() -> void: play_requested.emit())

	map_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_CREAM, "خريطة السماء", UI_BOLD_FONT, Color("5A431A")
	)
	add_child(map_button)
	(map_button.get_meta("button") as Button).pressed.connect(
		func() -> void: map_requested.emit())

	settings_button = _round_button(UiIcon.Kind.SETTINGS, "الإعدادات", settings_requested)
	_round_button(UiIcon.Kind.STAR, "بطاقات النجوم", cards_requested)
	_round_button(UiIcon.Kind.COIN, "المتجر", shop_requested)

	_version = _label(UI_BOLD_FONT, Color("5E7A8C"))
	_version.text = "نسخة ٠٫١ — عنوان مؤقّت"
	add_child(_version)


func _round_button(kind: int, label_text: String, out: Signal) -> GlossyPanel:
	var panel := GlossyPanel.make_round(kind, label_text)
	add_child(panel)
	(panel.get_meta("button") as Button).pressed.connect(func() -> void: out.emit())
	_round.append(panel)
	return panel


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


## Where the player stopped, for the line above the button.
func show_place(mansion: int, index_in_mansion: int) -> void:
	if _where == null:
		return
	if mansion < 1:
		_where.text = "سماء جديدة"
		(play_button.get_meta("label") as Label).text = "ابدأ"
		return
	_where.text = "المنزلة %s — %s · النجمة %s من %s" % [
		Arabic.eastern_digits(mansion),
		Mansions.name_of(mansion),
		Arabic.eastern_digits(index_in_mansion),
		Arabic.eastern_digits(Mansions.LEVELS_PER_MANSION),
	]
	(play_button.get_meta("label") as Label).text = "واصل"


func _layout() -> void:
	if _title == null or size.x <= 0.0:
		return
	var s := size.x / REF_WIDTH

	# Amiri's ascenders and descenders run well past the point size, so the box
	# is taller than the type and the next line clears the whole box, not the
	# number. Sized by the number, the subtitle landed inside the title.
	_title.position = Vector2(0.0, size.y * 0.2)
	_title.size = Vector2(size.x, 232.0 * s)
	_title.add_theme_font_size_override("font_size", int(150.0 * s))

	_subtitle.position = Vector2(0.0, size.y * 0.2 + 250.0 * s)
	_subtitle.size = Vector2(size.x, 56.0 * s)
	_subtitle.add_theme_font_size_override("font_size", int(42.0 * s))

	# Bottom-up: the version line sits on the floor, the round row above it, and
	# the two big buttons above that, so nothing is pinned to a phone's height.
	var floor_y := size.y - 60.0 * s
	_version.size = Vector2(size.x, 40.0 * s)
	_version.position = Vector2(0.0, floor_y - 40.0 * s)
	_version.add_theme_font_size_override("font_size", int(30.0 * s))

	var round_side := 122.0 * s
	var round_gap := 38.0 * s
	var round_top := _version.position.y - 44.0 * s - round_side
	var row_width := round_side * float(_round.size()) + round_gap * float(_round.size() - 1)
	for i in _round.size():
		_place_round(_round[i],
			Vector2((size.x - row_width) * 0.5 + float(i) * (round_side + round_gap), round_top),
			round_side, s)

	var button_width := 681.0 * s
	var map_height := 133.0 * s
	var play_height := 155.0 * s
	var map_top := round_top - 60.0 * s - map_height
	_place_wide(map_button, Vector2((size.x - button_width) * 0.5, map_top),
		button_width, map_height, s)
	var play_top := map_top - 26.0 * s - play_height
	_place_wide(play_button, Vector2((size.x - button_width) * 0.5, play_top),
		button_width, play_height, s)

	_where.size = Vector2(size.x, 44.0 * s)
	_where.position = Vector2(0.0, play_top - 52.0 * s)
	_where.add_theme_font_size_override("font_size", int(32.0 * s))


## A few stars behind the name, so the screen is a sky and not a black page.
func _draw() -> void:
	if size.x <= 0.0:
		return
	var s := size.x / REF_WIDTH
	var middle := Vector2(size.x * 0.5, size.y * 0.47)
	var figure := PackedVector2Array()
	for offset in [
		Vector2(268, -36), Vector2(150, -96), Vector2(28, -60), Vector2(-88, -104),
		Vector2(-208, -52), Vector2(-296, 40),
	]:
		figure.append(middle + offset * s)
	draw_polyline(figure, Color(Palette.GOLD_LIGHT, 0.16), 2.4 * s, true)
	var branch := PackedVector2Array([
		middle + Vector2(28, -60) * s, middle + Vector2(60, 76) * s,
		middle + Vector2(176, 116) * s,
	])
	draw_polyline(branch, Color(Palette.GOLD_LIGHT, 0.16), 2.4 * s, true)
	for point in figure:
		draw_circle(point, 16.0 * s, Color(Palette.GOLD_LIGHT, 0.09), true, -1.0, true)
		draw_circle(point, 5.0 * s, Color(Palette.GOLD_LIGHT, 0.4), true, -1.0, true)
	for point in [branch[1], branch[2]]:
		draw_circle(point, 4.4 * s, Color(Palette.GOLD_LIGHT, 0.3), true, -1.0, true)


func _place_wide(
	panel: GlossyPanel, at: Vector2, width: float, height: float, s: float
) -> void:
	panel.position = at
	panel.edge_override = 14.0 * s
	panel.radius_override = height * 0.5
	panel.size = Vector2(width, height + 14.0 * s)
	var label: Label = panel.get_meta("label")
	label.position = Vector2.ZERO
	label.size = Vector2(width, height)
	label.add_theme_font_size_override("font_size", int(40.0 * s))
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(width, height)


func _place_round(panel: GlossyPanel, at: Vector2, side: float, s: float) -> void:
	panel.position = at
	panel.size = Vector2(side, side)
	panel.edge_override = 10.0 * s
	panel.radius_override = side * 0.5
	var icon: UiIcon = panel.get_meta("icon")
	var art := side * 0.52
	icon.size = Vector2(art, art)
	icon.position = Vector2((side - art) * 0.5, (panel.face_height() - art) * 0.5)
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)
