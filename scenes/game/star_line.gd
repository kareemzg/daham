class_name StarLine
extends Control
## What a mansion's name means, and the modern name of its brightest star.
##
## Shared by the card opened from the map and the one the twentieth star opens,
## because they are the same line and a second copy would be a second place for
## it to fall out of step with the table it comes from.

const UI_BOLD_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
const HEIGHT := 104.0

var _tray: Panel
var _meaning: Label
var _latin: Label


func configure() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tray = Panel.new()
	_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.TILE_BORDER, 0.22), Color(0, 0, 0, 0), 30, 0)
	)
	add_child(_tray)

	_meaning = _label(Color("4A3A2A"), Control.TEXT_DIRECTION_RTL)
	add_child(_meaning)
	# The Latin name runs the other way: forced into the paragraph's direction
	# its letters come out in the wrong order.
	_latin = _label(Color("8A7A62"), Control.TEXT_DIRECTION_LTR)
	add_child(_latin)


func _label(colour: Color, direction: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text_direction = direction
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UI_BOLD_FONT)
	label.add_theme_color_override("font_color", colour)
	return label


func show_mansion(mansion: int) -> void:
	_meaning.text = Mansions.meaning_of(mansion)
	_latin.text = Mansions.latin_of(mansion)
	# البلدة is named for being empty of bright stars: the blank is the truth,
	# so the line goes rather than sitting there showing nothing.
	_latin.visible = not _latin.text.is_empty()


func meaning_text() -> String:
	return _meaning.text


func latin_label() -> Label:
	return _latin


func relayout(s: float) -> void:
	if _tray == null:
		return
	_tray.position = Vector2.ZERO
	_tray.size = size
	_meaning.position = Vector2(16.0 * s, 8.0 * s)
	_meaning.size = Vector2(size.x - 32.0 * s, 48.0 * s)
	_meaning.add_theme_font_size_override("font_size", int(32.0 * s))
	_latin.position = Vector2(16.0 * s, 56.0 * s)
	_latin.size = Vector2(size.x - 32.0 * s, 40.0 * s)
	_latin.add_theme_font_size_override("font_size", int(26.0 * s))
