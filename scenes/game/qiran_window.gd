class_name QiranWindow
extends SkyWindow
## القِران: which mansion the moon is in tonight, and whether it is yours.
##
## Two faces, and which one shows is not a design choice but a fact about the
## sky. When the moon lodges in a mansion the player has lit, that mansion is
## open tonight without lanterns. When it lodges anywhere else — which is most
## nights, because a build carries one season of four — the window says so
## plainly, keeps the name back, and names the soonest night that is theirs.
##
## Nothing here is scheduled or hashed. `Qiran` works it out from the date.

signal play_requested

var play_button: GlossyPanel
## The mansion's figure, or nothing at all when the moon is somewhere the
## player has not reached: a figure would give the name away as surely as the
## name would.
var figure: FigureView

var _where: Label
var _moon: UiIcon
var _nights: Control
var _play_label: Label
var _play_button: Button
var _unknown: Label


func configure_qiran(display_font: Font, ui_font: Font) -> void:
	configure(display_font, ui_font)
	set_crest(UiIcon.Kind.MOON)
	set_title("القِران")
	add_close_cross()

	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure = FigureView.new()
	stage.add_child(figure)
	_unknown = _label(display_font, Color("4E6F8C"))
	_unknown.text = "؟"
	stage.add_child(_unknown)
	# The same moon the HUD draws, at the same phase the sky is at tonight.
	_moon = UiIcon.new()
	_moon.kind = UiIcon.Kind.MOON
	stage.add_child(_moon)
	add_row(stage, 230.0, 10.0)
	set_meta("stage", stage)

	_where = _label(display_font, Color("6B5942"))
	add_row(_where, 60.0, 4.0)

	_nights = _build_nights(ui_font)

	play_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_EMBER, "العبْ فيها الليلة", ui_font, Color("FFF4E8")
	)
	panel.add_child(play_button)
	_play_label = play_button.get_meta("label")
	_play_button = play_button.get_meta("button")
	_play_button.pressed.connect(func() -> void: play_requested.emit())
	_buttons.append({"shell": play_button, "height": BUTTON_HEIGHT, "gap": GAP})


func _build_nights(ui_font: Font) -> Control:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.22), Color(0, 0, 0, 0), 30, 0)
	)
	strip.add_child(tray)
	strip.set_meta("tray", tray)
	var label := _label(ui_font, Color("4A3A08"))
	strip.add_child(label)
	strip.set_meta("label", label)
	add_row(strip, 84.0, 14.0)
	return strip


## `reached` is how many mansions the player has finished.
func show_night(day: int, reached: int) -> void:
	var mansion := Qiran.mansion_on(day)
	var open := Qiran.open_tonight(day, reached)
	_moon.level = Qiran.illumination(day)

	figure.visible = open
	_unknown.visible = not open
	var nights: Label = _nights.get_meta("label")

	if open:
		figure.figure = Mansions.figure_of(mansion)
		_where.text = Mansions.name_of(mansion)
		_where.add_theme_color_override("font_color", Palette.GOLD_DEEP)
		set_body("الليلةَ القمرُ في منزلةٍ أضأتَها.\nالعبْ فيها بلا فانوس، مهما أخطأت.")
		nights.text = "ولا تُكتب خسارةٌ على هذه الليلة"
		play_button.style = GlossyPanel.Style.BUTTON_EMBER
		_play_label.add_theme_color_override("font_color", Color("FFF4E8"))
		_play_label.text = "العبْ فيها الليلة"
		_play_button.disabled = false
		return

	# The name is the reward for finishing the mansion, so it is kept back here
	# exactly as the map keeps it back.
	_where.text = "منزلةٌ لم تبلغْها"
	_where.add_theme_color_override("font_color", Color("6B5942"))
	set_body("القمرُ ينزل كلَّ ليلةٍ منزلةً من ثمانٍ وعشرين.\nاسمُ هذه يبقى لك حتى تُضيئها بيدك.")
	var soon := Qiran.next_open(day, reached)
	if soon.is_empty():
		nights.text = "أتمِمْ منزلةً واحدة، يَصِرْ لك قِران"
	elif int(soon["nights"]) == 0:
		nights.text = "أقربُ قِرانٍ لك: الليلة"
	else:
		nights.text = "%s بعد %s ليال" % [
			Mansions.name_of(int(soon["mansion"])),
			Arabic.eastern_digits(int(soon["nights"])),
		]
	play_button.style = GlossyPanel.Style.BUTTON_MUTED
	_play_label.add_theme_color_override("font_color", Color("6B5D48"))
	_play_label.text = "أكملِ الرحلة"
	# Enabled, and it closes the window. The night is not on offer; leaving is.
	_play_button.disabled = false


func relayout(s: float) -> void:
	super.relayout(s)
	_where.add_theme_font_size_override("font_size", int(44.0 * s))
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stage: Control = get_meta("stage")
	var box := minf(stage.size.y, stage.size.x * 0.5)
	# The figure to one side and the moon to the other, near enough to read as
	# one thing: the moon IS in that mansion, not beside it.
	figure.size = Vector2(box, box)
	figure.position = Vector2(stage.size.x * 0.5 + 8.0 * s, (stage.size.y - box) * 0.5)
	_unknown.size = figure.size
	_unknown.position = figure.position
	_unknown.add_theme_font_size_override("font_size", int(box * 0.6))
	_unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var face := box * 0.72
	_moon.size = Vector2(face, face)
	_moon.position = Vector2(
		stage.size.x * 0.5 - face - 8.0 * s, (stage.size.y - face) * 0.5
	)

	var tray: Panel = _nights.get_meta("tray")
	tray.position = Vector2.ZERO
	tray.size = _nights.size
	var label: Label = _nights.get_meta("label")
	label.add_theme_font_size_override("font_size", int(30.0 * s))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2.ZERO
	label.size = _nights.size
