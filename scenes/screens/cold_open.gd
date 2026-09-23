class_name ColdOpen
extends Control
## The very first thing the game shows, once in a player's life.
##
## Not a menu. A dark sky with one figure faint in it, three lines of why, and
## a single button. The title screen comes after this and on every launch but
## the first, because a title screen is for coming back to a game you already
## know you want to play.
##
## It draws no sky of its own — the shell's is the only one there is — and it
## leans on that sky being dimmed while it is up, which is the same lever the
## lanterns pull.

signal begin_requested
signal skip_requested

## How much light the sky has behind this screen. Darker than a player with no
## lanterns left, because nothing has been lit yet.
const SKY_LIGHT := 0.42
const REF_WIDTH := 1080.0

const DISPLAY_FONT := preload("res://assets/fonts/arabic_display_bold.tres")
const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")

var begin_button: GlossyPanel
var skip_button: Button

var _figure: FigureView
var _title: Label
var _lines: Label


func _ready() -> void:
	if _title != null:
		return
	_figure = FigureView.new()
	# الشرطان, the first mansion, faint. The player will not learn its name for
	# twenty levels, and nothing here says it.
	_figure.figure = Mansions.figure_of(1)
	_figure.modulate = Color(1, 1, 1, 0.5)
	add_child(_figure)

	_title = _label(DISPLAY_FONT, Palette.CREAM)
	_title.text = "سماءُ العربِ منطفئة"
	add_child(_title)

	_lines = _label(UI_BOLD_FONT, Color("9FB6C8"))
	# Broken by hand. A Label that wraps itself claims the height it works out
	# at no width, which on a first layout is every word on its own line.
	_lines.text = (
		"ثمانٍ وعشرون منزلةً سمّاها العرب،\n"
		+ "وفي كلِّ منزلةٍ عشرون نجمة.\n"
		+ "كلُّ نجمةٍ تُضاء بكلمة."
	)
	add_child(_lines)

	begin_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_CREAM, "أَضِئْ أوّلَ نجم", UI_BOLD_FONT, Color("5A431A")
	)
	add_child(begin_button)
	(begin_button.get_meta("button") as Button).pressed.connect(
		func() -> void: begin_requested.emit())

	var skip_shell := Control.new()
	add_child(skip_shell)
	set_meta("skip_shell", skip_shell)
	var skip_label := _label(UI_BOLD_FONT, Color("4E6F8C"))
	skip_label.text = "تخطِّ التعريف"
	skip_shell.add_child(skip_label)
	skip_shell.set_meta("label", skip_label)
	skip_button = Button.new()
	skip_button.flat = true
	skip_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	skip_shell.add_child(skip_button)
	skip_button.pressed.connect(func() -> void: skip_requested.emit())

	resized.connect(_layout)
	_layout()


func _label(font: Font, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = Control.TEXT_DIRECTION_RTL
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	if _title == null or size.x <= 0.0:
		return
	var s := size.x / REF_WIDTH
	var margin := 96.0 * s

	var box := minf(420.0 * s, size.y * 0.24)
	_figure.size = Vector2(box, box)
	_figure.position = Vector2((size.x - box) * 0.5, size.y * 0.22)

	_title.add_theme_font_size_override("font_size", int(92.0 * s))
	# Amiri's descenders run well past the point size, so the box is sized by
	# the line the next one has to clear and not by the size.
	_title.size = Vector2(size.x, 150.0 * s)
	_title.position = Vector2(0.0, size.y * 0.5)

	_lines.add_theme_font_size_override("font_size", int(38.0 * s))
	_lines.size = Vector2(size.x, 3.0 * 68.0 * s)
	_lines.position = Vector2(0.0, _title.position.y + _title.size.y + 30.0 * s)

	var button_height := 118.0 * s
	begin_button.size = Vector2(size.x - margin * 2.0, button_height)
	begin_button.position = Vector2(margin, size.y - 240.0 * s)
	var label: Label = begin_button.get_meta("label")
	label.position = Vector2.ZERO
	label.size = begin_button.size
	label.add_theme_font_size_override("font_size", int(42.0 * s))

	var skip_shell: Control = get_meta("skip_shell")
	skip_shell.size = Vector2(size.x * 0.5, 80.0 * s)
	skip_shell.position = Vector2(
		size.x * 0.25, begin_button.position.y + button_height + 22.0 * s
	)
	var skip_label: Label = skip_shell.get_meta("label")
	skip_label.position = Vector2.ZERO
	skip_label.size = skip_shell.size
	skip_label.add_theme_font_size_override("font_size", int(30.0 * s))
