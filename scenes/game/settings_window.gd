class_name SettingsWindow
extends SkyWindow
## The settings window, shared by the play screen and the sky map.
##
## Both screens carry the gear, and a second copy of the switches would be a
## second place for them to fall out of step with what is actually stored.

signal menu_requested
signal close_requested
signal changed(key: String, on: bool)

const KEYS := ["sound", "music", "haptics"]
const LABELS := ["المؤثرات الصوتية", "الموسيقى", "الاهتزاز"]

var rows: Array[SkyToggle] = []
var close_button: GlossyPanel
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

	# The corner cross, as the design draws it: a window you opened yourself
	# closes without having to leave where you are.
	close_button = GlossyPanel.new()
	close_button.style = GlossyPanel.Style.BUTTON_CREAM
	panel.add_child(close_button)
	var cross := _label(ui_font, Color("6B5942"))
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
	var values := [settings.sound, settings.music, settings.haptics]
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
	# The setting's name takes the reading start, which is the right; its answer
	# sits opposite. They were the other way round.
	var name_label: Label = _language.get_meta("name")
	name_label.position = Vector2(_language.size.x * 0.5, 0.0)
	name_label.size = Vector2(_language.size.x * 0.5 - pad, _language.size.y)
	name_label.add_theme_font_size_override("font_size", int(32.0 * s))
	var value: Label = _language.get_meta("value")
	value.position = Vector2(pad, 0.0)
	value.size = Vector2(_language.size.x * 0.5 - pad, _language.size.y)
	value.add_theme_font_size_override("font_size", int(30.0 * s))

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
