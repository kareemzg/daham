@tool
class_name StarCardsScreen
extends Control
## The collection: twenty-eight mansions grouped by their season, scrolling
## past. Finishing a mansion is what turns its line from a question mark into a
## card with a name and a meaning, so this screen is the reward the game keeps
## promising rather than a menu.
##
## It draws no sky. The shell behind it does.

signal back_requested
signal mansion_opened(mansion: int)

const REF_WIDTH := 1080.0
const DISPLAY_FONT := preload("res://assets/fonts/arabic_display.tres")
const DISPLAY_BOLD_FONT := preload("res://assets/fonts/arabic_display_bold.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

var back_button: GlossyPanel
var rows: Array[CardRow] = []

var _title: Label
var _summary: GlossyPanel
var _summary_name: Label
var _summary_count: Label
var _ticks: StarDots
var _scroll: ScrollContainer
var _column: VBoxContainer
var _heads: Array[Control] = []


func _ready() -> void:
	_build()
	resized.connect(_layout)
	_layout()


func _build() -> void:
	for child in get_children():
		if child.owner == null:
			child.queue_free()
	rows.clear()
	_heads.clear()

	back_button = GlossyPanel.make_round(UiIcon.Kind.HOME, "عودة إلى الخريطة")
	add_child(back_button)
	(back_button.get_meta("button") as Button).pressed.connect(
		func() -> void: back_requested.emit())

	_title = _label(DISPLAY_BOLD_FONT, Palette.CREAM)
	_title.text = "بطاقات النجوم"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_title)

	_summary = GlossyPanel.new()
	_summary.style = GlossyPanel.Style.PANEL_NIGHT
	add_child(_summary)
	_summary_name = _label(UI_BOLD_FONT, Color("E7D9BC"))
	_summary_name.text = "منازل اكتملت"
	_summary.add_child(_summary_name)
	_summary_count = _label(UI_BOLD_FONT, Palette.GOLD_LIGHT)
	_summary_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.add_child(_summary_count)
	_ticks = StarDots.new()
	_ticks.capsule = true
	_ticks.dim = Color("2C5E73")
	_ticks.count = Mansions.COUNT
	_summary.add_child(_ticks)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_column)

	for season in Mansions.SEASONS.size():
		_column.add_child(_season_head(season))
		for mansion in Mansions.of_season(season):
			var row := CardRow.new()
			row.configure()
			var number := mansion
			row.pressed.connect(func() -> void: mansion_opened.emit(number))
			_column.add_child(row)
			rows.append(row)


## A row laid out by a container rather than by hand. Positioned by hand it
## read its own width before the column had given it one, so the season's name
## sat off the right edge and only the count showed.
func _season_head(season: int) -> Control:
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _label(DISPLAY_BOLD_FONT, Palette.CREAM)
	name_label.text = Mansions.season_name(season)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	head.set_meta("name", name_label)
	var count := _label(UI_BOLD_FONT, Color("8FAEBF"))
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(count)
	head.set_meta("count", count)
	head.set_meta("season", season)
	_heads.append(head)
	return head


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	return label


## How many stars each mansion has lit, given where the player has got to.
func show_progress(current_mansion: int, current_index: int) -> void:
	if rows.is_empty():
		return
	var done := 0
	for i in rows.size():
		var mansion := i + 1
		var lit := 0
		if mansion < current_mansion:
			lit = Mansions.LEVELS_PER_MANSION
		elif mansion == current_mansion:
			lit = current_index - 1
		rows[i].show_mansion(mansion, lit, Mansions.LEVELS_PER_MANSION)
		if lit >= Mansions.LEVELS_PER_MANSION:
			done += 1

	_summary_count.text = "%s من %s" % [
		Arabic.eastern_digits(done), Arabic.eastern_digits(Mansions.COUNT)
	]
	_ticks.lit = done

	for head in _heads:
		var season: int = head.get_meta("season")
		var in_season := 0
		for mansion in Mansions.of_season(season):
			if mansion < current_mansion:
				in_season += 1
		(head.get_meta("count") as Label).text = "%s من %s" % [
			Arabic.eastern_digits(in_season), Arabic.eastern_digits(Mansions.PER_SEASON)
		]


func _layout() -> void:
	if _title == null or size.x <= 0.0:
		return
	var s := size.x / REF_WIDTH
	var margin := 60.0 * s

	var round_side := 122.0 * s
	back_button.position = Vector2(size.x - margin - round_side, 60.0 * s)
	back_button.size = Vector2(round_side, round_side)
	back_button.edge_override = 10.0 * s
	back_button.radius_override = round_side * 0.5
	var icon: UiIcon = back_button.get_meta("icon")
	var art := round_side * 0.5
	icon.size = Vector2(art, art)
	icon.position = Vector2((round_side - art) * 0.5, (back_button.face_height() - art) * 0.5)
	var button: Button = back_button.get_meta("button")
	button.position = Vector2.ZERO
	button.size = Vector2(round_side, round_side)

	_title.add_theme_font_size_override("font_size", int(62.0 * s))
	_title.position = Vector2(margin, 54.0 * s)
	_title.size = Vector2(size.x - margin * 2.0 - round_side - 20.0 * s, round_side)

	var summary_height := 150.0 * s
	_summary.position = Vector2(margin, 214.0 * s)
	_summary.size = Vector2(size.x - margin * 2.0, summary_height)
	_summary.edge_override = 8.0 * s
	_summary.radius_override = 44.0 * s
	var pad := 34.0 * s
	var inner := _summary.size.x - pad * 2.0
	_summary_name.add_theme_font_size_override("font_size", int(32.0 * s))
	_summary_name.position = Vector2(pad + inner * 0.5, 18.0 * s)
	_summary_name.size = Vector2(inner * 0.5, 46.0 * s)
	_summary_count.add_theme_font_size_override("font_size", int(32.0 * s))
	_summary_count.position = Vector2(pad, 18.0 * s)
	_summary_count.size = Vector2(inner * 0.5, 46.0 * s)
	_ticks.position = Vector2(pad, 80.0 * s)
	_ticks.size = Vector2(inner, 18.0 * s)

	var top := 214.0 * s + summary_height + 30.0 * s
	_scroll.position = Vector2(margin, top)
	_scroll.size = Vector2(size.x - margin * 2.0, maxf(size.y - 60.0 * s - top, 100.0))
	_column.add_theme_constant_override("separation", int(14.0 * s))

	for head in _heads:
		head.custom_minimum_size = Vector2(0.0, 80.0 * s)
		head.add_theme_constant_override("separation", int(16.0 * s))
		(head.get_meta("name") as Label).add_theme_font_size_override(
			"font_size", int(48.0 * s))
		(head.get_meta("count") as Label).add_theme_font_size_override(
			"font_size", int(30.0 * s))

	for row in rows:
		row.apply_scale(s)
