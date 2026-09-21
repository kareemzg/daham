class_name ShelfWindow
extends SkyWindow
## A window that lists things bought with coins: the observer's tools, and the
## shop. The two are the same shape, so they are one class.
##
## A price the player cannot afford is greyed, never hidden. Hiding it would
## teach them nothing about what the tool is or what it would take.

signal chosen(index: int)

var rows: Array[ToolRow] = []

var _purse: Control
var _costs: Array[int] = []
var _notes: Array[Control] = []


func configure_shelf(
	display_font: Font, ui_font: Font, crest_kind: int, title: String, blurb: String
) -> void:
	configure(display_font, ui_font)
	set_crest(crest_kind)
	set_title(title)
	set_body(blurb)
	add_close_cross()


func add_item(kind: int, title: String, what: String, cost: int) -> ToolRow:
	var row := ToolRow.new()
	row.configure(kind, title, what, cost)
	row.pressed.connect(func() -> void: chosen.emit(_index_of(row)))
	add_row(row, ToolRow.HEIGHT, 12.0)
	rows.append(row)
	_costs.append(cost)
	return row


func _index_of(row: ToolRow) -> int:
	return rows.find(row)


## The purse, and which lines it can reach. Called every time the window opens,
## because coins change between openings.
func show_purse(coins: int) -> void:
	for i in rows.size():
		rows[i].affordable = coins >= _costs[i]
	if _purse != null:
		(_purse.get_meta("label") as Label).text = "معك %s" % Arabic.eastern_digits(coins)


func add_purse() -> Control:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := _label(_ui_font, Color("6B5942"))
	strip.add_child(label)
	strip.set_meta("label", label)
	var coin := UiIcon.new()
	coin.kind = UiIcon.Kind.COIN
	strip.add_child(coin)
	strip.set_meta("coin", coin)
	add_row(strip, 58.0, 16.0)
	_purse = strip
	return strip


## A small aside under the list, for something true about the shelf that is not
## one of its lines.
func add_note(text: String, lines: int = 2) -> Control:
	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := Panel.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override(
		"panel", Palette.card(Color(Palette.GOLD_DEEP, 0.14), Color(0, 0, 0, 0), 30, 0)
	)
	strip.add_child(tray)
	strip.set_meta("tray", tray)
	var label := _label(_ui_font, Color("7A6647"))
	label.text = text
	strip.add_child(label)
	strip.set_meta("label", label)
	add_row(strip, 40.0 * float(lines) + 24.0, 14.0)
	_notes.append(strip)
	return strip


func relayout(s: float) -> void:
	super.relayout(s)
	for row in rows:
		row.relayout(s)
	for strip in _notes:
		var tray: Panel = strip.get_meta("tray")
		tray.position = Vector2.ZERO
		tray.size = strip.size
		var text: Label = strip.get_meta("label")
		text.position = Vector2(20.0 * s, 0.0)
		text.size = Vector2(strip.size.x - 40.0 * s, strip.size.y)
		text.add_theme_font_size_override("font_size", int(26.0 * s))

	if _purse == null:
		return
	# The number and the coin read as one thing, so they are centred as a pair.
	var label: Label = _purse.get_meta("label")
	var coin: UiIcon = _purse.get_meta("coin")
	label.add_theme_font_size_override("font_size", int(32.0 * s))
	var side := 46.0 * s
	var text := label.get_minimum_size().x
	var left := (_purse.size.x - (text + 14.0 * s + side)) * 0.5
	label.position = Vector2(left, 0.0)
	label.size = Vector2(text, _purse.size.y)
	coin.size = Vector2(side, side)
	coin.position = Vector2(left + text + 14.0 * s, (_purse.size.y - side) * 0.5)
