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
signal qiran_requested
signal cards_requested
signal shop_requested

const REF_WIDTH := 1080.0
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const TITLE_FONT := preload("res://assets/fonts/arabic_title.tres")
const DISPLAY_BOLD_FONT := preload("res://assets/fonts/arabic_display_bold.tres")
## Amiri Bold is a naskh and reads light beside Plex Bold. This one is
## emboldened on top of it, for the two names that have to carry a card.
const DISPLAY_HEAVY_FONT := preload("res://assets/fonts/arabic_display_heavy.tres")
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
## One breath every three and a half seconds, which is about a resting one.
const PULSE_SECONDS := 3.5
const PULSE_FPS := 12.0
## How much of the brightness the breath takes at its lowest.
const PULSE_DEPTH := 0.3

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
## True when the shell's dock carries the card and the doors instead. The map
## is then the sky and its season heading, and nothing else — which is what it
## was always trying to be.
var chrome_hidden: bool = false:
	set(value):
		if chrome_hidden == value:
			return
		chrome_hidden = value
		entries_hidden = value
		if _card != null:
			_card.visible = not value
		_layout()

## True when the shell's bar carries these doors instead.
var entries_hidden: bool = false:
	set(value):
		if entries_hidden == value:
			return
		entries_hidden = value
		_layout()

var _entries: Array[GlossyPanel] = []
var _dots: Array[Control] = []
var _field := Rect2()
## The current mansion breathes: its stars are the ones still being earned, and
## a map where exactly one thing moves says where to look without a word.
var _pulse: float = 0.0
var _since_pulse: float = 0.0


func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	_since_pulse += delta
	if _since_pulse >= 1.0 / PULSE_FPS:
		_since_pulse = 0.0
		queue_redraw()


func _build() -> void:
	for child in get_children():
		if child.owner == null:
			child.queue_free()
	_names.clear()
	_entries.clear()
	_dots.clear()

	hud = HudBar.new()
	hud.configure(UI_BOLD_FONT)
	# The hub's top is one surface, like its bottom. The play screen's is not:
	# the tour brings those counters in one at a time.
	hud.frosted = true
	add_child(hud)
	settings_button = hud.add_utility(
		UiIcon.Kind.SETTINGS, func() -> void: settings_requested.emit(), "الإعدادات"
	)

	_back_button = _arrow(false, "الفصل السابق")
	_forward_button = _arrow(true, "الفصل التالي")

	_season_name = _label(TITLE_FONT, Palette.CREAM)
	add_child(_season_name)
	_season_count = _label(UI_BOLD_FONT, Color("8FAEBF"))
	add_child(_season_count)

	for i in Mansions.SEASONS.size():
		var dot := Control.new()
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)

	for i in Mansions.PER_SEASON:
		var name_label := _label(TITLE_FONT, Palette.GOLD)
		# A mansion's name is a target: tapping it opens its card.
		var press := Button.new()
		Sound.taps(press)
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
	_card_name = _label(DISPLAY_HEAVY_FONT, Palette.TILE_INK)
	# In a label whose direction is RTL these two follow the reading order, not
	# the screen: LEFT is the start of the line, which is the right-hand side.
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_card.add_child(_card_name)
	_card_progress = _label(UI_BOLD_FONT, Color("6B5942"))
	_card_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card.add_child(_card_progress)
	_card_stars = StarDots.new()
	_card_stars.capsule = true
	_card.add_child(_card_stars)
	play_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_EMBER, "واصل", UI_BOLD_FONT, Color("FFF4E8")
	)
	_card.add_child(play_button)
	(play_button.get_meta("button") as Button).pressed.connect(
		func() -> void: play_requested.emit())

	_entry(UiIcon.Kind.DIPPER, "التحدي اليومي", daily_requested)
	_entry(UiIcon.Kind.MOON, "القِران", qiran_requested)
	_entry(UiIcon.Kind.STAR_CARDS, "بطاقات النجوم", cards_requested)
	_entry(UiIcon.Kind.SHOP, "المتجر", shop_requested)


## Drawn, not typed. The angle-quote characters are bidi-mirrored, so inside an
## Arabic label each one renders as its opposite and both arrows point inward.
func _arrow(forward: bool, label_text: String) -> GlossyPanel:
	var panel := GlossyPanel.make_round(
		UiIcon.Kind.CHEVRON_NEXT if forward else UiIcon.Kind.CHEVRON_PREV,
		label_text, Palette.SLATE
	)
	add_child(panel)
	(panel.get_meta("button") as Button).pressed.connect(
		func() -> void: show_season(season_shown + (1 if forward else -1)))
	return panel


func _entry(kind: int, label_text: String, out: Signal) -> GlossyPanel:
	var panel := GlossyPanel.make_button(
		GlossyPanel.Style.PANEL_NIGHT, label_text, UI_BOLD_FONT, Color("E7D9BC")
	)
	add_child(panel)
	var icon := UiIcon.new()
	icon.kind = kind
	panel.add_child(icon)
	panel.set_meta("icon", icon)
	var note := _label(UI_BOLD_FONT, Color("8FAEBF"))
	panel.add_child(note)
	panel.set_meta("note", note)
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

	# The numbers under each entry. The daily streak is not tracked yet, so it
	# reads zero rather than borrowing the design's example.
	var finished := current_mansion - 1
	# In the order the entries were added: the day, the night, the cards, the
	# shop. One short line each, and the conjunction's is the only one the sky
	# decides.
	var day := Daily.today()
	var soon := Qiran.next_open(day, finished)
	var tonight := "—"
	if Qiran.open_tonight(day, finished):
		tonight = "الليلة"
	elif not soon.is_empty():
		tonight = "بعد %s ليال" % Arabic.eastern_digits(int(soon["nights"]))
	var notes := [
		"%s من %s" % [Arabic.eastern_digits(0), Arabic.eastern_digits(7)],
		tonight,
		Arabic.eastern_digits(finished),
		"منظار · أسطرلاب",
	]
	for i in _entries.size():
		(_entries[i].get_meta("note") as Label).text = notes[i]
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
	# The display face hangs further below the baseline than Amiri did, so the
	# box grew with it. Sizing a label by its point size is the mistake this
	# project keeps re-learning; a face swap is when it bites again.
	_season_name.size = Vector2(size.x, 132.0 * s)
	_season_name.add_theme_font_size_override("font_size", int(76.0 * s))
	_season_count.position = Vector2(0.0, header_top + 124.0 * s)
	_season_count.size = Vector2(size.x, 40.0 * s)
	_season_count.add_theme_font_size_override("font_size", int(32.0 * s))

	var dot_row := header_top + 176.0 * s
	var dot_gap := 20.0 * s
	var dot_side := 22.0 * s
	var row_width := dot_side * float(_dots.size()) + dot_gap * float(_dots.size() - 1)
	for i in _dots.size():
		_dots[i].position = Vector2(
			(size.x - row_width) * 0.5 + float(i) * (dot_side + dot_gap), dot_row)
		_dots[i].size = Vector2(dot_side, dot_side)

	# Bottom-up, so nothing is pinned to one phone's height.
	var floor_y := size.y - 60.0 * s
	# The bar along the bottom of the shell carries these same four doors. Two
	# rows of the same four buttons, one directly above the other, is the
	# duplication this project refuses everywhere else — so when the bar is up
	# the row is not merely hidden, it gives its room back to the card.
	var entry_height := 0.0 if entries_hidden else 236.0 * s
	var entry_gap := 0.0 if entries_hidden else 25.0 * s
	# Divided by however many there are. It was three for as long as there were
	# three, and adding a fourth put it off the edge.
	var count := maxf(float(_entries.size()), 1.0)
	var entry_width := (
		size.x - margin * 2.0 - entry_gap * (count - 1.0)
	) / count
	var entry_top := floor_y - entry_height
	for i in _entries.size():
		_entries[i].visible = not entries_hidden
		if entries_hidden:
			continue
		_place_entry(_entries[i],
			Vector2(size.x - margin - entry_width * float(i + 1) - entry_gap * float(i), entry_top),
			entry_width, entry_height, s)

	var card_height := 0.0 if chrome_hidden else 330.0 * s
	var card_top := entry_top - (0.0 if chrome_hidden else 40.0 * s) - card_height
	if not chrome_hidden:
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

	# The name takes the reading start, which in Arabic is the right, and the
	# count sits opposite it. They were the other way round.
	_card_name.position = Vector2(pad + inner * 0.45, 20.0 * s)
	_card_name.size = Vector2(inner * 0.55, 66.0 * s)
	_card_name.add_theme_font_size_override("font_size", int(52.0 * s))
	_card_progress.position = Vector2(pad, 20.0 * s)
	_card_progress.size = Vector2(inner * 0.45, 66.0 * s)
	_card_progress.add_theme_font_size_override("font_size", int(32.0 * s))

	# Clear of the name's box, not of its point size: Amiri hangs below both.
	_card_stars.position = Vector2(pad, 124.0 * s)
	_card_stars.size = Vector2(inner, 19.0 * s)

	var button_height := 108.0 * s
	play_button.position = Vector2(pad, 180.0 * s)
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
	var icon: UiIcon = panel.get_meta("icon")
	var art := side * 0.46
	icon.size = Vector2(art, art)
	icon.position = Vector2((side - art) * 0.5, (panel.face_height() - art) * 0.5)
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(side, side)


func _place_entry(
	panel: GlossyPanel, at: Vector2, width: float, height: float, s: float
) -> void:
	panel.position = at
	panel.size = Vector2(width, height)
	panel.edge_override = 10.0 * s
	panel.radius_override = 44.0 * s
	# Straight off the design, scaled: ten units of air above the icon and nine
	# below the last line, with the icon, the name and the number between them.
	# The box follows the drawing's own shape. The seven stars of بنات نعش are
	# more than twice as wide as they are tall, and a square box shrank them to
	# a third of the size of the other two.
	var icon: UiIcon = panel.get_meta("icon")
	var art := 60.0 * s
	var drawing := icon.texture()
	var art_width := art * (float(drawing.get_width()) / float(maxi(drawing.get_height(), 1)))
	icon.size = Vector2(art_width, art)
	icon.position = Vector2((width - art_width) * 0.5, 28.0 * s)
	var label: Label = panel.get_meta("label")
	label.position = Vector2(4.0 * s, 99.0 * s)
	label.size = Vector2(width - 8.0 * s, 46.0 * s)
	label.add_theme_font_size_override("font_size", int(36.0 * s))
	var note: Label = panel.get_meta("note")
	note.position = Vector2(4.0 * s, 156.0 * s)
	note.size = Vector2(width - 8.0 * s, 43.0 * s)
	note.add_theme_font_size_override("font_size", int(33.0 * s))
	var button: Button = panel.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(width, height)


func _draw() -> void:
	if _field.size.x <= 0.0 or _names.is_empty():
		return
	var s := size.x / REF_WIDTH
	var numbers := Mansions.of_season(season_shown)
	# Between 1 - PULSE_DEPTH and 1, never past either: a star that breathes
	# out to nothing reads as a fault, and one that breathes past full reads as
	# a flash.
	var breath := 1.0 - PULSE_DEPTH * 0.5 * (1.0 - cos(_pulse * TAU / PULSE_SECONDS))

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
			var alpha := 0.75 if done else (0.28 + 0.4 * share) * breath
			draw_polyline(points, Color(Palette.GOLD_LIGHT, alpha), 2.6 * s, true)

		for j in points.size():
			var shown := done or (
				current and j < int(ceil(float(points.size())
					* float(lit) / float(Mansions.LEVELS_PER_MANSION)))
			)
			if shown:
				# Only the current mansion's stars breathe. A finished one is
				# finished: making it move too would say there is still
				# something to do there.
				var halo := 0.22 * (breath if current else 1.0)
				var core := 1.0 if done else breath
				draw_circle(points[j], 16.0 * s, Color(Palette.GOLD_LIGHT, halo), true, -1.0, true)
				draw_circle(
					points[j], 5.6 * s, Color(Palette.GOLD_LIGHT, core), true, -1.0, true
				)
			else:
				draw_circle(points[j], 5.2 * s, Color(Palette.DIM_STAR, 0.95), true, -1.0, true)

		if current:
			draw_arc(
				centre, 66.0 * s, 0.0, TAU, 48,
				Color(Palette.GOLD, 0.85 * breath), 3.4 * s, true
			)


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
