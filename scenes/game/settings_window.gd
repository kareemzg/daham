class_name SettingsWindow
extends SkyWindow
## The settings window, shared by the play screen and the sky map.
##
## Both screens carry the gear, and a second copy of the switches would be a
## second place for them to fall out of step with what is actually stored.

signal menu_requested
signal changed(key: String, on: bool)

## The notification sits with the sound switches because it is the same kind
## of thing: something the game may do to the player when they are not looking.
## It is asked about once, the first time the lanterns run out, and this row is
## where that answer is changed afterwards.
const KEYS := ["sound", "music", "haptics", "notify"]
const LABELS := ["المؤثرات الصوتية", "الموسيقى", "الاهتزاز", "أنبئني حين تعود الفوانيس"]

var rows: Array[SkyToggle] = []
var _language: Control


func configure_settings(display_font: Font, ui_font: Font) -> void:
	configure(display_font, ui_font)
	set_crest(UiIcon.Kind.SETTINGS)
	set_title("الإعدادات")

	for i in KEYS.size():
		var row := SkyToggle.new()
		row.label_text = LABELS[i]
		add_row(row, 92.0, 14.0)
		var key: String = KEYS[i]
		row.toggled.connect(func(on: bool) -> void: changed.emit(key, on))
		rows.append(row)

	_language = _build_language_row()

	var menu := add_button(
		GlossyPanel.Style.BUTTON_CREAM, "القائمة الرئيسية", UiIcon.Kind.HOME, 92.0
	)
	(menu.get_meta("button") as Button).pressed.connect(func() -> void: menu_requested.emit())

	add_close_cross()


func _build_language_row() -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.2), Color(0, 0, 0, 0), 26, 0)
	)
	row.add_child(tray)
	row.set_meta("tray", tray)
	var name_label := _label(_ui_font, Color("4A3A2A"))
	name_label.text = "اللغة"
	# In a label whose direction is RTL these follow the reading order, not the
	# screen: LEFT is the start of the line, which is the right-hand side.
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	row.set_meta("name", name_label)
	var value := _label(_ui_font, Color("6B5942"))
	value.text = "العربية"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	row.set_meta("value", value)
	add_row(row, 92.0, 14.0)
	return row


## Puts the stored answers on the switches, for opening the window.
func show_values(settings: GameSettings) -> void:
	var values := [settings.sound, settings.music, settings.haptics, settings.notify]
	for i in rows.size():
		rows[i].on = values[i]


func relayout(s: float) -> void:
	super.relayout(s)

	for row in rows:
		row.style(_ui_font, Color("4A3A2A"), int(32.0 * s))

	var tray: Panel = _language.get_meta("tray")
	tray.position = Vector2.ZERO
	tray.size = _language.size
	var pad := 26.0 * s
	# The setting's name sits flush against the far right, its answer against
	# the far left, both measured to their text for the same reason the switch
	# rows are: an RTL label leaves a gap between its last glyph and its box.
	var name_label: Label = _language.get_meta("name")
	name_label.add_theme_font_size_override("font_size", int(32.0 * s))
	var name_width: float = name_label.get_minimum_size().x
	name_label.position = Vector2(_language.size.x - pad - name_width, 0.0)
	name_label.size = Vector2(name_width, _language.size.y)
	var value: Label = _language.get_meta("value")
	value.add_theme_font_size_override("font_size", int(30.0 * s))
	var value_width: float = value.get_minimum_size().x
	value.position = Vector2(pad, 0.0)
	value.size = Vector2(value_width, _language.size.y)
