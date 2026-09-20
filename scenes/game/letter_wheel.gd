@tool
class_name LetterWheel
extends Control
## The letter wheel and the drag that spells a word.
##
## Tiles sit on a circle, first letter at the top, running counter-clockwise so
## the reading order matches the right-to-left feel of the rest of the screen.
## The public `begin_at` / `extend_to` / `finish` API is what input calls and
## what tests drive, so the word logic can be checked without faking events.
##
## Children are ordered disc, trail, tiles, which is also their draw order.

signal word_previewed(word: String)
signal word_submitted(word: String)

const LETTER_FONT := preload("res://assets/fonts/arabic_ui_bold.tres")
const EDGE_SHARE := 0.069

## Centre to tile centre. In the design this is about twice the tile's own
## radius, which is what seats the tiles inside the body instead of on its rim.
var orbit_radius: float = 163.0:
	set(value):
		orbit_radius = value
		_place()

## The visible disc. Bigger than orbit + tile, so the tiles sit within it.
var body_radius: float = 277.0:
	set(value):
		body_radius = value
		_place()

var tile_radius: float = 80.0:
	set(value):
		tile_radius = value
		_place()

## How forgiving the hit test is; fingers are not precise.
var hit_slack: float = 1.15

var _letters: PackedStringArray = PackedStringArray()
var _selection: PackedInt32Array = PackedInt32Array()
var _pointer: Vector2 = Vector2.ZERO
var _dragging: bool = false

var _disc: GlossyPanel = null
var _trail: Control = null
var _tiles: Array[GlossyPanel] = []
var _labels: Array[Label] = []


func setup(letters: PackedStringArray) -> void:
	_letters = letters
	_selection = PackedInt32Array()
	_dragging = false

	for child in get_children():
		child.queue_free()
	_tiles.clear()
	_labels.clear()

	_disc = GlossyPanel.new()
	_disc.style = GlossyPanel.Style.DISC
	add_child(_disc)

	_trail = Control.new()
	_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail.draw.connect(_paint_trail)
	add_child(_trail)

	for letter in _letters:
		var tile := GlossyPanel.new()
		tile.style = GlossyPanel.Style.WHEEL_TILE
		add_child(tile)
		_tiles.append(tile)

		var label := Label.new()
		label.text = letter
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# One letter per Label: the wheel always shows isolated letterforms.
		label.text_direction = Control.TEXT_DIRECTION_RTL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", LETTER_FONT)
		label.add_theme_color_override("font_color", Palette.TILE_INK)
		tile.add_child(label)
		_labels.append(label)

	var span := body_radius * 2.0
	custom_minimum_size = Vector2(span, span)
	size = Vector2(span, span)
	_place()


func _place() -> void:
	if _disc == null or not is_instance_valid(_disc):
		return
	# The node's rect is the circle; the hard edge hangs below it, the way every
	# other panel's does. The caller owns `size`, so it is not set here.
	var span := body_radius * 2.0
	var body_edge := body_radius * 0.033

	# The body fills the node; the tiles orbit inside it.
	_disc.size = Vector2(span, span + body_edge)
	_disc.position = Vector2.ZERO
	_disc.edge_override = body_edge
	_disc.radius_override = body_radius

	_trail.position = Vector2.ZERO
	_trail.size = size

	var diameter := tile_radius * 2.0
	var edge := diameter * EDGE_SHARE
	# The design sets the letter at about half the tile's diameter.
	var font_size := int(tile_radius * 1.03)
	for i in _tiles.size():
		var tile: GlossyPanel = _tiles[i]
		tile.size = Vector2(diameter, diameter + edge)
		tile.position = tile_centre(i) - Vector2(diameter, diameter) * 0.5
		tile.edge_override = edge
		tile.radius_override = diameter * 0.5
		var label: Label = _labels[i]
		label.position = Vector2.ZERO
		label.size = Vector2(diameter, diameter)
		label.add_theme_font_size_override("font_size", font_size)
	_refresh_selection()


func letter_count() -> int:
	return _letters.size()


## The letters in wheel order.
func letters() -> PackedStringArray:
	return _letters.duplicate()


## What the tiles actually show. Should always equal `letters()`; if it drifts,
## a shuffle has moved the data without moving the faces.
func shown_letters() -> PackedStringArray:
	var out := PackedStringArray()
	for label in _labels:
		out.append(label.text)
	return out


func centre() -> Vector2:
	return Vector2(body_radius, body_radius)


func tile_centre(index: int) -> Vector2:
	var count := _letters.size()
	if count == 0:
		return centre()
	var angle := -PI * 0.5 - float(index) * TAU / float(count)
	return centre() + Vector2(cos(angle), sin(angle)) * orbit_radius


func index_at(local_position: Vector2) -> int:
	var reach := tile_radius * hit_slack
	var best := -1
	var best_distance := reach
	for i in _letters.size():
		var distance := local_position.distance_to(tile_centre(i))
		if distance <= best_distance:
			best_distance = distance
			best = i
	return best


func current_word() -> String:
	var word := ""
	for index in _selection:
		word += _letters[index]
	return word


func shuffle_letters() -> void:
	if _dragging:
		return
	var pool := Array(_letters)
	pool.shuffle()
	_letters = PackedStringArray(pool)
	for i in _labels.size():
		_labels[i].text = _letters[i]


func begin_at(local_position: Vector2) -> void:
	_dragging = true
	_selection = PackedInt32Array()
	_pointer = local_position
	extend_to(local_position)


func extend_to(local_position: Vector2) -> void:
	if not _dragging:
		return
	_pointer = local_position
	var hit := index_at(local_position)
	if _trail != null:
		_trail.queue_redraw()
	if hit < 0:
		return
	var count := _selection.size()
	# Sliding back onto the previous tile un-picks the last one.
	if count >= 2 and _selection[count - 2] == hit:
		_selection.remove_at(count - 1)
		_refresh_selection()
		word_previewed.emit(current_word())
		return
	if _selection.has(hit):
		return
	_selection.append(hit)
	_refresh_selection()
	word_previewed.emit(current_word())


func finish() -> String:
	if not _dragging:
		return ""
	_dragging = false
	var word := current_word()
	_selection = PackedInt32Array()
	_refresh_selection()
	word_previewed.emit("")
	word_submitted.emit(word)
	return word


func cancel() -> void:
	_dragging = false
	_selection = PackedInt32Array()
	_refresh_selection()
	word_previewed.emit("")


func _refresh_selection() -> void:
	for i in _tiles.size():
		var picked := _selection.has(i)
		_tiles[i].style = (
			GlossyPanel.Style.WHEEL_TILE_PICKED if picked else GlossyPanel.Style.WHEEL_TILE
		)
		_labels[i].add_theme_color_override(
			"font_color", Palette.CREAM if picked else Palette.TILE_INK
		)
	if _trail != null:
		_trail.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# The project turns mouse into touch and Godot turns touch into mouse, so
	# handling the mouse side alone covers desktop and device both.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		if button.pressed:
			begin_at(button.position)
		else:
			finish()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		extend_to((event as InputEventMouseMotion).position)
		accept_event()


func _paint_trail() -> void:
	if _selection.is_empty() or _trail == null:
		return
	var points := PackedVector2Array()
	for index in _selection:
		points.append(tile_centre(index))
	if _dragging:
		points.append(_pointer)
	if points.size() < 2:
		return
	# One stroke, the width and opacity the design draws it at.
	_trail.draw_polyline(points, Color(Palette.TRAIL, 0.72), tile_radius * 0.55, true)
