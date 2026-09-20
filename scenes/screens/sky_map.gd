@tool
class_name SkyMap
extends Control
## The sky map, which is what "the main menu" means in this game.
##
## One season at a time: its seven mansions scattered across the sky on a dotted
## thread, finished ones drawn and named in gold, the current one ringed, the
## rest still dark. The card at the foot is where you left off, and the row
## below it is everything else there is to do.
##
## It draws no sky of its own. The shell behind it does.
##
## The figures are placeholders. The story calls for the real mansion shapes
## redrawn from al-Sufi rather than copied, and that is a drawing job which has
## not been done; these are seven abstract clusters so the screen can be built
## and judged meanwhile.

signal play_requested
signal settings_requested
signal mansion_opened(mansion: int)
signal daily_requested
signal cards_requested
signal shop_requested

const REF_WIDTH := 1080.0
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

## Where each mansion of a season sits, as a fraction of the field's box.
## Second and fourth are pulled apart on purpose: at the design's spacing the
## second mansion's name landed inside the ring the fourth wears.
const ANCHORS := [
	Vector2(0.775, 0.135), Vector2(0.585, 0.245), Vector2(0.285, 0.170),
	Vector2(0.505, 0.520), Vector2(0.235, 0.650), Vector2(0.760, 0.690),
	Vector2(0.445, 0.840),
]
## Each cluster's stars, in reference units from its anchor.
const SHAPES := [
	[Vector2(-44, -28), Vector2(0, 0), Vector2(44, 22), Vector2(66, -17)],
	[Vector2(-39, 17), Vector2(6, -22), Vector2(50, 6)],
	[Vector2(-33, -17), Vector2(-6, 11), Vector2(28, -6), Vector2(55, 17), Vector2(17, -33)],
	[Vector2(-55, 11), Vector2(-17, -22), Vector2(22, 6), Vector2(61, -17), Vector2(0, 33)],
	[Vector2(-39, -22), Vector2(0, 6), Vector2(39, -11)],
	[Vector2(-50, 6), Vector2(-11, -22), Vector2(28, 0), Vector2(55, 28)],
	[Vector2(-33, 11), Vector2(11, -17), Vector2(50, 11)],
]

var hud: HudBar
var settings_button: GlossyPanel
var play_button: GlossyPanel

## Which mansion the player is on, and how far into it.
var current_mansion: int = 1
var current_index: int = 1
## Which season the map is showing, which need not be the one being played.
var season_shown: int = 0

var _season_name: Label
var _season_count: Label
var _back_button: GlossyPanel
var _forward_button: GlossyPanel
var _card: GlossyPanel
var _card_name: Label
var _card_progress: Label
var _card_stars: StarDots
var _names: Array[Label] = []
var _entries: Array[GlossyPanel] = []
var _dots: Array[Control] = []
var _field := Rect2()


func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	for child in get_children():
		if child.owner == null:
			child.queue_free()
	_names.clear()
	_entries.clear()
	_dots.clear()

	hud = HudBar.new()
	hud.configure(UI_BOLD_FONT)
	add_child(hud)
	settings_button = hud.add_utility(
		UiIcon.Kind.SETTINGS, func() -> void: settings_requested.emit(), "الإعدادات"
	)

	_back_button = _arrow(false, "الفصل السابق")
	_forward_button = _arrow(true, "الفصل التالي")

	_season_name = _label(DISPLAY_FONT, Palette.CREAM)
	add_child(_season_name)
	_season_count = _label(UI_BOLD_FONT, Color("8FAEBF"))
	add_child(_season_count)

	for i in Mansions.SEASONS.size():
		var dot := Control.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)

	for i in Mansions.PER_SEASON:
		var name_label := _label(DISPLAY_FONT, Palette.GOLD)
		# A mansion's name is a target: tapping it opens its card.
		var press := Button.new()
		press.flat = true
		press.focus_mode = Control.FOCUS_ALL
		var slot := i
		press.pressed.connect(func() -> void:
			mansion_opened.emit(Mansions.of_season(season_shown)[slot]))
		name_label.add_child(press)
		name_label.set_meta("button", press)
		add_child(name_label)
		_names.append(name_label)

	_card = GlossyPanel.new()
	_card.style = GlossyPanel.Style.CHIP
	add_child(_card)
	_card_name = _label(DISPLAY_FONT, Palette.TILE_INK)
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_card_name)
	_card_progress = _label(UI_BOLD_FONT, Color("6B5942"))
	_card_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.add_child(_card_progress)
	_card_stars = StarDots.new()
	_card.add_child(_card_stars)
	play_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_EMBER, "واصل", UI_BOLD_FONT, Color("FFF4E8")
	)
	_card.add_child(play_button)
	(play_button.get_meta("button") as Button).pressed.connect(
		func() -> void: play_requested.emit())

	_entry(UiIcon.Kind.CLOCK, "التحدي اليومي", daily_requested)
	_entry(UiIcon.Kind.STAR, "بطاقات النجوم", cards_requested)
	_entry(UiIcon.Kind.COIN, "المتجر", shop_requested)


func _arrow(forward: bool, label_text: String) -> GlossyPanel:
	var panel := GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_CREAM, "‹" if forward else "›", UI_BOLD_FONT, Color("8A4A12")
	)
	add_child(panel)
	(panel.get_meta("button") as Button).pressed.connect(
		func() -> void: show_season(season_shown + (1 if forward else -1)))
	return panel


func _entry(kind: int, label_text: String, out: Signal) -> GlossyPanel:
	var panel := GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_RIVER, label_text, UI_BOLD_FONT, Color("E7D9BC")
	)
	add_child(panel)
	var icon := UiIcon.new()
	icon.kind = kind
	panel.add_child(icon)
	panel.set_meta("icon", icon)
	(panel.get_meta("button") as Button).pressed.connect(func() -> void: out.emit())
	_entries.append(panel)
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


## Where the player is. Everything before this mansion counts as finished.
func show_progress(level_id: String, coins: int, lanterns: int, moon: int) -> void:
	var place := Mansions.parse(level_id)
	if place != Vector2i.ZERO:
		current_mansion = place.x
		current_index = place.y
	hud.coins = coins
	hud.lanterns = lanterns
	hud.moon = moon
	show_season(Mansions.season_of(current_mansion))


func show_season(season: int) -> void:
	season_shown = clampi(season, 0, Mansions.SEASONS.size() - 1)
	_refresh()
	_layout()


## How far a mansion has got: 0 untouched, 20 finished.
func stars_of(mansion: int) -> int:
	if mansion < current_mansion:
		return Mansions.LEVELS_PER_MANSION
	if mansion > current_mansion:
		return 0
	return current_index - 1


func _refresh() -> void:
	if _season_name == null:
		return
	_season_name.text = Mansions.season_name(season_shown)
	var numbers := Mansions.of_season(season_shown)
	var done := 0
	for mansion in numbers:
		if stars_of(mansion) >= Mansions.LEVELS_PER_MANSION:
			done += 1
	_season_count.text = "%s منازل من %s" % [
		Arabic.eastern_digits(done), Arabic.eastern_digits(Mansions.PER_SEASON)
	]

	for i in _names.size():
		var mansion: int = numbers[i]
		var lit := stars_of(mansion)
		var label := _names[i]
		if lit >= Mansions.LEVELS_PER_MANSION:
			label.text = Mansions.name_of(mansion)
			label.add_theme_color_override("font_color", Palette.GOLD)
			(label.get_meta("button") as Button).disabled = false
		elif mansion == current_mansion:
			label.text = Mansions.name_of(mansion)
			label.add_theme_color_override("font_color", Palette.GOLD_LIGHT)
			(label.get_meta("button") as Button).disabled = false
		else:
			# A mansion with no stars keeps its name back: finding it out is the
			# reward for finishing it.
			label.text = "؟"
			label.add_theme_color_override("font_color", Color("6F8A9B"))
			(label.get_meta("button") as Button).disabled = true

	_card_name.text = Mansions.name_of(current_mansion)
	_card_progress.text = "النجمة %s من %s" % [
		Arabic.eastern_digits(current_index), Arabic.eastern_digits(Mansions.LEVELS_PER_MANSION)
	]
	_card_stars.setup(Mansions.LEVELS_PER_MANSION, current_index - 1)
	_back_button.visible = season_shown > 0
	_forward_button.visible = season_shown < Mansions.SEASONS.size() - 1
	queue_redraw()


func _layout() -> void:
	if _season_name == null or size.x <= 0.0:
		return
	var s := size.x / REF_WIDTH
	var margin := 60.0 * s

	hud.position = Vector2(0.0, 60.0 * s)
	hud.size = Vector2(size.x, HudBar.CHIP_HEIGHT * s)
	hud.relayout(s)

	var header_top := 210.0 * s
	var arrow := 100.0 * s
	_place_arrow(_back_button, Vector2(size.x - margin - arrow, header_top), arrow, s)
	_place_arrow(_forward_button, Vector2(margin, header_top), arrow, s)
	# The box is taller than the point size: Amiri's descenders run past it, and
	# a box sized by the number put the count inside the season's name.
	_season_name.position = Vector2(0.0, header_top - 22.0 * s)
	_season_name.size = Vector2(size.x, 116.0 * s)
	_season_name.add_theme_font_size_override("font_size", int(80.0 * s))
	_season_count.position = Vector2(0.0, header_top + 96.0 * s)
	_season_count.size = Vector2(size.x, 40.0 * s)
	_season_count.add_theme_font_size_override("font_size", int(32.0 * s))

	var dot_row := header_top + 148.0 * s
	var dot_gap := 20.0 * s
	var dot_side := 22.0 * s
	var row_width := dot_side * float(_dots.size()) + dot_gap * float(_dots.size() - 1)
	for i in _dots.size():
		_dots[i].position = Vector2(
			(size.x - row_width) * 0.5 + float(i) * (dot_side + dot_gap), dot_row)
		_dots[i].size = Vector2(dot_side, dot_side)

	# Bottom-up, so nothing is pinned to one phone's height.
	var floor_y := size.y - 60.0 * s
	var entry_height := 190.0 * s
	var entry_gap := 18.0 * s
	var entry_width := (size.x - margin * 2.0 - entry_gap * 2.0) / 3.0
	var entry_top := floor_y - entry_height
	for i in _entries.size():
		_place_entry(_entries[i],
			Vector2(size.x - margin - entry_width * float(i + 1) - entry_gap * float(i), entry_top),
			entry_width, entry_height, s)

	var card_height := 300.0 * s
	var card_top := entry_top - 44.0 * s - card_height
	_layout_card(Vector2(margin, card_top), size.x - margin * 2.0, card_height, s)

	_field = Rect2(
		Vector2(margin, dot_row + 56.0 * s),
		Vector2(size.x - margin * 2.0, maxf(card_top - 40.0 * s - (dot_row + 56.0 * s), 60.0 * s))
	)
	for i in _names.size():
		var at := _star_centre(i)
		_names[i].size = Vector2(320.0 * s, 52.0 * s)
		# Clear of the ring the current mansion wears, which is 66 units wide.
		_names[i].position = at + Vector2(-160.0 * s, 92.0 * s)
		_names[i].add_theme_font_size_override("font_size", int(42.0 * s))
		var press: Button = _names[i].get_meta("button")
		press.position = Vector2(80.0 * s, -80.0 * s)
		press.size = Vector2(160.0 * s, 150.0 * s)
	queue_redraw()


func _star_centre(slot: int) -> Vector2:
	return _field.position + ANCHORS[slot] * _field.size


func _layout_card(at: Vector2, width: float, height: float, s: float) -> void:
	_card.position = at
	_card.size = Vector2(width, height)
	_card.edge_override = 12.0 * s
	_card.radius_override = 40.0 * s
	var pad := 34.0 * s
	var inner := width - pad * 2.0

	_card_name.position = Vector2(pad, 18.0 * s)
	_card_name.size = Vector2(inner * 0.55, 62.0 * s)
	_card_name.add_theme_font_size_override("font_size", int(52.0 * s))
	_card_progress.position = Vector2(pad + inner * 0.55, 18.0 * s)
	_card_progress.size = Vector2(inner * 0.45, 62.0 * s)
	_card_progress.add_theme_font_size_override("font_size", int(32.0 * s))

	_card_stars.position = Vector2(pad, 92.0 * s)
	_card_stars.size = Vector2(inner, 22.0 * s)

	var button_height := 108.0 * s
	play_button.position = Vector2(pad, 140.0 * s)
	play_button.edge_override = 14.0 * s
	play_button.radius_override = button_height * 0.5
	play_button.size = Vector2(inner, button_height + 14.0 * s)
	var label: Label = play_button.get_meta("label")
	label.position = Vector2.ZERO
	label.size = Vector2(inner, button_height)
	label.add_theme_font_size_override("font_size", int(40.0 * s))
	var button: Button = play_button.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(inner, button_height)


func _place_arrow(panel: GlossyPanel, at: Vector2, side: float, s: float) -> void:
	panel.position = at
	panel.size = Vector2(side, side)
	panel.edge_override = 8.0 * s
	panel.radius_override = side * 0.5
	var label: Label = panel.get_meta("label")
	label.position = Vector2.ZERO
	label.size = Vector2(side, panel.face_height())
	label.add_theme_font_size_override("font_size", int(52.0 * s))
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)


func _place_entry(
	panel: GlossyPanel, at: Vector2, width: float, height: float, s: float
) -> void:
	panel.position = at
	panel.size = Vector2(width, height)
	panel.edge_override = 10.0 * s
	panel.radius_override = 30.0 * s
	var face := panel.face_height()
	var icon: UiIcon = panel.get_meta("icon")
	var art := 58.0 * s
	icon.size = Vector2(art, art)
	icon.position = Vector2((width - art) * 0.5, face * 0.24)
	var label: Label = panel.get_meta("label")
	label.position = Vector2(4.0 * s, face * 0.52)
	label.size = Vector2(width - 8.0 * s, face * 0.36)
	label.add_theme_font_size_override("font_size", int(26.0 * s))
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(width, height)


func _draw() -> void:
	if _field.size.x <= 0.0 or _names.is_empty():
		return
	var s := size.x / REF_WIDTH
	var numbers := Mansions.of_season(season_shown)

	# The thread that runs through the season, right to left.
	var thread := PackedVector2Array()
	for i in Mansions.PER_SEASON:
		thread.append(_star_centre(i))
	for i in thread.size() - 1:
		_dotted(thread[i], thread[i + 1], Color(Palette.MUTED, 0.3), 2.0 * s)

	for i in Mansions.PER_SEASON:
		var centre := _star_centre(i)
		var lit := stars_of(numbers[i])
		var done := lit >= Mansions.LEVELS_PER_MANSION
		var current: bool = numbers[i] == current_mansion
		var points := PackedVector2Array()
		for offset in SHAPES[i]:
			points.append(centre + offset * s)

		if done or current:
			# A finished mansion has its figure drawn; the current one shows
			# only as much of it as its stars have earned.
			var share := 1.0 if done else float(lit) / float(Mansions.LEVELS_PER_MANSION)
			var alpha := 0.75 if done else 0.28 + 0.4 * share
			draw_polyline(points, Color(Palette.GOLD_LIGHT, alpha), 2.6 * s, true)

		for j in points.size():
			var shown := done or (
				current and j < int(ceil(float(points.size())
					* float(lit) / float(Mansions.LEVELS_PER_MANSION)))
			)
			if shown:
				draw_circle(points[j], 16.0 * s, Color(Palette.GOLD_LIGHT, 0.22))
				draw_circle(points[j], 5.6 * s, Palette.GOLD_LIGHT)
			else:
				draw_circle(points[j], 5.2 * s, Color(Palette.DIM_STAR, 0.95))

		if current:
			draw_arc(centre, 66.0 * s, 0.0, TAU, 48, Color(Palette.GOLD, 0.85), 3.4 * s, true)


func _dotted(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	var span := to - from
	var length := span.length()
	if length <= 0.0:
		return
	var step := 16.0 * (size.x / REF_WIDTH)
	var direction := span / length
	var travelled := 0.0
	while travelled < length:
		var run := minf(step * 0.35, length - travelled)
		draw_line(from + direction * travelled, from + direction * (travelled + run), colour, width, true)
		travelled += step
