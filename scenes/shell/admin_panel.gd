class_name AdminPanel
extends CanvasLayer
## A workbench for reaching any moment in the game without playing to it.
##
## Debug builds only, the same gate the jump bar uses: `OS.is_debug_build()`
## returns false in a release, so `Shell` never builds one and a player never
## sees it. It lives in a shipped path because the export filter drops
## `scenes/dev/*` from every build including the debug one, so a dev tool that
## has to run in a debug build cannot live there.
##
## It drives the real paths — `show_level()`, `submit()`, `open_qiran()` — and
## never reaches past them into private state, so what it reaches is what a
## player would reach, arrived at faster.

const LEVEL_SIZE := 22
const TAG := "⚙"

var _shell: Shell
var _sheet: PanelContainer
var _where: LineEdit
var _note: Label


static func attach(shell: Shell) -> AdminPanel:
	if not OS.is_debug_build():
		return null
	var panel := AdminPanel.new()
	panel._shell = shell
	panel.layer = 129
	shell.add_child(panel)
	panel._build()
	return panel


func _build() -> void:
	var opener := Button.new()
	opener.text = TAG
	opener.tooltip_text = "لوحة التجربة"
	opener.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	opener.offset_left = 8.0
	opener.offset_top = -56.0
	opener.offset_right = 56.0
	opener.offset_bottom = -8.0
	opener.pressed.connect(func() -> void: _sheet.visible = not _sheet.visible)
	add_child(opener)

	_sheet = PanelContainer.new()
	_sheet.visible = false
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	# In viewport units (1080 x 1920), which is what a CanvasLayer measures in,
	# so the sheet is the same share of the screen on every phone. Tall enough
	# that the last row is not below the fold on a first look.
	_sheet.offset_left = -470.0
	_sheet.offset_right = 470.0
	_sheet.offset_top = -660.0
	_sheet.offset_bottom = 660.0
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.02, 0.07, 0.11, 0.96)
	skin.border_color = Color(0.5, 0.82, 0.86, 0.5)
	skin.set_border_width_all(2)
	skin.set_corner_radius_all(14)
	skin.set_content_margin_all(12.0)
	_sheet.add_theme_stylebox_override("panel", skin)
	add_child(_sheet)

	var scroll := ScrollContainer.new()
	_sheet.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)

	_note = Label.new()
	_note.text = "لوحة التجربة — نسخة التصحيح وحدها"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)

	# Straight to a level by its id, for anything the buttons below do not name.
	var go_row := HBoxContainer.new()
	column.add_child(go_row)
	_where = LineEdit.new()
	_where.placeholder_text = "m01-10"
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where.text_submitted.connect(func(text: String) -> void: _go(text))
	go_row.add_child(_where)
	_button(go_row, "اذهب", func() -> void: _go(_where.text))

	_heading(column, "لحظات")
	var moments := _row(column)
	_button(moments, "بيت شعر", func() -> void: _go("m01-10"))
	_button(moments, "الأنواء", func() -> void: _at_the_twentieth())
	_button(moments, "أتمّ المنزلة", func() -> void: _finish_mansion())
	var moments2 := _row(column)
	_button(moments2, "رقعة بهدية", func() -> void: _go(_first_level_with_gift()))
	_button(moments2, "أوسع عجلة", func() -> void: _go(_widest_wheel()))
	_button(moments2, "حلّ المرحلة", func() -> void: _solve(0))
	var moments3 := _row(column)
	_button(moments3, "حلّ إلّا كلمة", func() -> void: _solve(1))
	_button(moments3, "اكتمل البدر", func() -> void: _fill_moon())

	_heading(column, "الحال")
	var state := _row(column)
	for count in [5, 3, 1, 0]:
		_button(state, "%d فوانيس" % count, func() -> void: _set_lanterns(count))
	var purse := _row(column)
	_button(purse, "+١٠٠٠ عملة", func() -> void: _add_coins(1000))
	_button(purse, "صفّر العملات", func() -> void: _add_coins(-_shell.game.coins))
	_button(purse, "سلسلة ٦ أيام", func() -> void: _set_streak(6))

	_heading(column, "نوافذ وأحداث")
	var windows := _row(column)
	_button(windows, "القِران مفتوح", func() -> void: _open_qiran_night(true))
	_button(windows, "القِران بعيد", func() -> void: _open_qiran_night(false))
	_button(windows, "التحدي اليومي", func() -> void: _shell.open_daily())
	var windows2 := _row(column)
	_button(windows2, "نفدت الفوانيس", func() -> void: _out_of_lanterns())
	_button(windows2, "بطاقة المنزلة", func() -> void:
		_shell.open_mansion(maxi(_mansion_now(), 1)))
	_button(windows2, "المتجر", func() -> void: _shell.open_shop())

	_heading(column, "من البداية")
	var start := _row(column)
	_button(start, "أعد الجولة التعريفية", _restart_tour)
	_button(start, "امسح الحفظ", _wipe)

	_heading(column, "شاشات")
	var screens := _row(column)
	_button(screens, "الخريطة", func() -> void: _shell.go_to(Shell.Screen.MAP))
	_button(screens, "اللعب", func() -> void: _shell.go_to(Shell.Screen.GAME))
	_button(screens, "البطاقات", func() -> void: _shell.go_to(Shell.Screen.CARDS))
	_button(screens, "العنوان", func() -> void: _shell.go_to(Shell.Screen.TITLE))


func _heading(into: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("7FD0DA"))
	into.add_child(label)


func _row(into: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	into.add_child(row)
	return row


func _button(into: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	into.add_child(button)
	return button


func _say(text: String) -> void:
	_note.text = text


# --- what the buttons do -----------------------------------------------------

func _mansion_now() -> int:
	if _shell.game.level == null:
		return 0
	return Mansions.parse(_shell.game.level.id).x


## Straight to a level, through the same door the journey uses.
func _go(id: String) -> void:
	var level := _shell.game.level_by_id(id.strip_edges())
	if level == null:
		_say("لا مستوى بهذا الاسم في هذا البناء: %s" % id)
		return
	# The tour would strip the screen bare on the way past, which is never what
	# someone reaching for a level wants to look at.
	_shell.game.teaching = false
	_shell.game.show_level(level)
	_shell.game.save()
	if _shell.showing != Shell.Screen.GAME:
		_shell.go_to(Shell.Screen.GAME)
	_say("على %s" % level.id)
	_sheet.visible = false


## The twentieth of whichever mansion is open, solved down to its last word, so
## the next guess runs the rhyme and then the sky.
func _at_the_twentieth() -> void:
	var mansion := maxi(_mansion_now(), 1)
	_go(Mansions.level_id(mansion, Mansions.LEVELS_PER_MANSION))
	_solve(1)
	_say("النجمة ٢٠ — كلمةٌ واحدة تبقى، فتبدأ الأنواء")


## Every word but `leave` of them, through `submit()` so nothing is skipped.
func _solve(leave: int) -> void:
	var game := _shell.game
	if game.level == null:
		return
	var left := PackedStringArray()
	for word in game.level.word_texts():
		if not game.grid.is_found(word):
			left.append(word)
	for i in maxi(left.size() - leave, 0):
		game.submit(left[i])
	_sheet.visible = false


func _finish_mansion() -> void:
	_at_the_twentieth()
	var game := _shell.game
	for word in game.level.word_texts():
		if not game.grid.is_found(word):
			game.submit(word)
	if game.in_anwa:
		game.submit(Mansions.name_of(game.level.mansion))
	_say("المنزلة تُختم")


func _fill_moon() -> void:
	var game := _shell.game
	game.moon = GameScreen.MOON_PHASES - 1
	game._moon_shown = game.moon
	game._refresh_chrome()
	_say("القمر على بُعد كلمةٍ إضافيّةٍ واحدة من البدر")
	_sheet.visible = false


func _set_lanterns(count: int) -> void:
	_shell.game.lanterns = count
	_shell.game._refresh_chrome()
	_say("الفوانيس %d — والسماء معها" % count)


func _out_of_lanterns() -> void:
	_shell.game.lanterns = 0
	_shell.game.show_out_of_lanterns()
	_sheet.visible = false


func _add_coins(amount: int) -> void:
	_shell.game.coins = maxi(_shell.game.coins + amount, 0)
	_shell.game._refresh_chrome()
	_shell.game.save()
	_say("العملات %d" % _shell.game.coins)


func _set_streak(days: int) -> void:
	_shell.game.daily_streak = days
	_shell.game.daily_day = Daily.today() - 1
	_shell.game.save()
	_say("سلسلة %d أيام، واليوم لم يُلعب" % days)


## A night the moon really does lodge in a mansion the player has lit, or one
## it really does not. Both are found by walking the dates, not by pretending.
func _open_qiran_night(open: bool) -> void:
	var reached := _shell.mansions_reached()
	if open and reached < 1:
		# Not a missing night: the player has finished nothing, so no night is
		# theirs. Saying "no such night" would send someone hunting a bug.
		_say("لا منزلة أُتمّت بعد، فلا قِران. اذهب إلى m02-01 أوّلاً")
		return
	var day := Daily.today()
	for ahead in 40:
		if Qiran.open_tonight(day + ahead, reached) == open:
			_shell.open_qiran(day + ahead)
			_say("ليلة %s %s" % [
				Mansions.name_of(Qiran.mansion_on(day + ahead)),
				"(بعد %d ليلة)" % ahead if ahead > 0 else "(الليلة)",
			])
			_sheet.visible = false
			return
	_say("لا ليلة كهذه في أربعين ليلة")


func _restart_tour() -> void:
	_shell.settings.tour_done = false
	if not _shell.settings_path.is_empty():
		_shell.settings.write(_shell.settings_path)
	_wipe()
	_say("امسح التطبيق وافتحه من جديد لترى السماء المنطفئة")


func _wipe() -> void:
	if not _shell.game.progress_path.is_empty():
		Progress.clear(_shell.game.progress_path)
	_go("m01-01")
	_shell.game.coins = 0
	_shell.game.lanterns = GameScreen.LANTERNS_MAX
	_shell.game.moon = 0
	_shell.game._moon_shown = 0
	_shell.game.daily_streak = 0
	_shell.game._refresh_chrome()
	_shell.game.save()
	_say("الحفظ مُسح، ونحن على m01-01")


## The first shipped level that opens with a cell already given away.
func _first_level_with_gift() -> String:
	for mansion in range(1, Mansions.SHIPPED + 1):
		for index in range(1, Mansions.LEVELS_PER_MANSION + 1):
			var id := Mansions.level_id(mansion, index)
			var level := _shell.game.level_by_id(id)
			if level != null and level.has_gift():
				return id
	return "m01-01"


## The widest wheel this build carries, which is where the board is hardest.
func _widest_wheel() -> String:
	var best := "m01-01"
	var widest := 0
	for mansion in range(1, Mansions.SHIPPED + 1):
		for index in range(1, Mansions.LEVELS_PER_MANSION + 1):
			var id := Mansions.level_id(mansion, index)
			var level := _shell.game.level_by_id(id)
			if level != null and level.letters.size() > widest:
				widest = level.letters.size()
				best = id
	return best
