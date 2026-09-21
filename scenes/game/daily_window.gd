class_name DailyWindow
extends SkyWindow
## The daily challenge, opened from the sky map.
##
## Everything the window promises has to stay true elsewhere: no lantern is
## spent here however badly the level goes, and a day missed puts the run back
## to nothing.

signal play_requested

var dipper: DipperView
var play_button: GlossyPanel

var _count: Label
var _reward: Control
var _play_label: Label
var _play_button: Button


func configure_daily(display_font: Font, ui_font: Font) -> void:
	configure(display_font, ui_font)
	set_crest(UiIcon.Kind.DIPPER)
	set_title("التحدي اليومي")
	set_body("نجمة كل يوم.\nالسبع تُتمّ بنات نعش.")
	add_close_cross()

	dipper = DipperView.new()
	add_row(dipper, 250.0, 10.0)

	_count = _label(display_font, Color("6B5942"))
	add_row(_count, 56.0, 4.0)

	_reward = _build_reward(ui_font)

	play_button = GlossyPanel.make_button(
		GlossyPanel.Style.BUTTON_EMBER, "العب اليوم", ui_font, Color("FFF4E8")
	)
	panel.add_child(play_button)
	_play_label = play_button.get_meta("label")
	_play_button = play_button.get_meta("button")
	_play_button.pressed.connect(func() -> void: play_requested.emit())
	_buttons.append({"shell": play_button, "height": BUTTON_HEIGHT, "gap": GAP})

	add_note_row(ui_font)


func _build_reward(ui_font: Font) -> Control:
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
	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	strip.add_child(coin)
	strip.set_meta("coin", coin)
	add_row(strip, 84.0, 10.0)
	return strip


func add_note_row(ui_font: Font) -> void:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.GOLD_DEEP, 0.14), Color(0, 0, 0, 0), 30, 0)
	)
	strip.add_child(tray)
	strip.set_meta("tray", tray)
	var label := _label(ui_font, Color("7A6647"))
	label.text = "لا يكلّف فانوساً مهما أخطأت.\nويوم واحد يفوتك يعيد السلسلة إلى الصفر."
	strip.add_child(label)
	strip.set_meta("label", label)
	add_row(strip, 104.0, 12.0)
	set_meta("note", strip)


## `standing` is how many stars are alight, `played` whether today is done.
func show_state(standing: int, played: bool, seconds_left: int) -> void:
	dipper.lit = standing
	dipper.today_star = -1 if played else standing
	# No separator beside the number: a middle dot between Arabic text and an
	# Arabic-Indic number is pushed to the far side of the number by the bidi
	# algorithm, and «٠» is itself a dot, so «· ٤» reads as «٤٠».
	_count.text = "بنات نعش %s من %s" % [
		Arabic.eastern_digits(standing), Arabic.eastern_digits(Daily.STREAK_LENGTH)
	]
	_count.add_theme_color_override(
		"font_color", Palette.GOLD_DEEP if standing >= Daily.STREAK_LENGTH else Color("6B5942")
	)

	var reward: Label = _reward.get_meta("label")
	if standing + 1 >= Daily.STREAK_LENGTH and not played:
		reward.text = "تمام الأسبوع: %s" % Arabic.eastern_digits(
			Daily.DAY_REWARD + Daily.WEEK_REWARD)
	elif played and standing >= Daily.STREAK_LENGTH:
		reward.text = "اكتملت بنات نعش"
	else:
		reward.text = "اليوم: %s" % Arabic.eastern_digits(Daily.DAY_REWARD)

	if played:
		play_button.style = GlossyPanel.Style.BUTTON_MUTED
		_play_label.add_theme_color_override("font_color", Color("6B5D48"))
		_play_label.text = "عد غداً %s" % _clock(seconds_left)
		_play_button.disabled = true
		set_body("أُضيئت نجمة اليوم.\nتعود التالية غداً.")
	else:
		play_button.style = GlossyPanel.Style.BUTTON_EMBER
		_play_label.add_theme_color_override("font_color", Color("FFF4E8"))
		_play_label.text = "العب اليوم"
		_play_button.disabled = false
		set_body("نجمة كل يوم.\nالسبع تُتمّ بنات نعش.")


func _clock(seconds: int) -> String:
	var left := maxi(seconds, 0)
	var minutes := Arabic.eastern_digits(left / 60 % 60)
	if left / 60 % 60 < 10:
		minutes = Arabic.eastern_digits(0) + minutes
	return "%s:%s" % [Arabic.eastern_digits(left / 3600), minutes]


func relayout(s: float) -> void:
	super.relayout(s)
	_count.add_theme_font_size_override("font_size", int(40.0 * s))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var tray: Panel = _reward.get_meta("tray")
	tray.position = Vector2.ZERO
	tray.size = _reward.size
	var label: Label = _reward.get_meta("label")
	var coin: UiIcon = _reward.get_meta("coin")
	label.add_theme_font_size_override("font_size", int(32.0 * s))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var side := 46.0 * s
	var text := label.get_minimum_size().x
	var left := (_reward.size.x - (text + 14.0 * s + side)) * 0.5
	label.position = Vector2(left, 0.0)
	label.size = Vector2(text, _reward.size.y)
	coin.size = Vector2(side, side)
	coin.position = Vector2(left + text + 14.0 * s, (_reward.size.y - side) * 0.5)

	var note: Control = get_meta("note")
	var note_tray: Panel = note.get_meta("tray")
	note_tray.position = Vector2.ZERO
	note_tray.size = note.size
	var note_label: Label = note.get_meta("label")
	note_label.position = Vector2(18.0 * s, 0.0)
	note_label.size = Vector2(note.size.x - 36.0 * s, note.size.y)
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.add_theme_font_size_override("font_size", int(26.0 * s))
