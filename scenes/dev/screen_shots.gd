extends Control
## Renders the way in, for looking at.
##
##   godot --path . --quit-after 900 res://scenes/dev/screen_shots.tscn
##
## Writes tools/out/screen_*.png: the title, the sky map, a mansion card, and
## settings over the map.

const SAVE := "user://screen_shots_progress.json"

var shell: Shell


func _ready() -> void:
	OS.low_processor_usage_mode = false
	# A known place in the year, so the shots are the same every time.
	var saved := Progress.new()
	saved.level_id = "m04-12"
	saved.coins = 525
	saved.lanterns = 3
	saved.moon = 4
	saved.write(SAVE)

	shell = Shell.new()
	shell.progress_path = SAVE
	shell.settings_path = ""
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot()
	Progress.clear(SAVE)
	get_tree().quit()


func _shoot() -> void:
	# The way in, before anything else: a dark sky and a bare first level.
	# Driven through the real shell so these are the screens, not a pose.
	shell.settings.tour_done = false
	shell.game.progress_path = ""
	var first := Level.load_from("res://data/levels/m01-01.json")
	if first != null:
		shell.title.visible = false
		shell.cold_open.visible = true
		shell.sky.light = ColdOpen.SKY_LIGHT
		await _save("screen_cold")
		shell.cold_open.visible = false
		shell.title.visible = true
		shell.game.teaching = true
		shell.game.show_level(first)
		shell.game._refresh_chrome()
		shell._screen(shell.showing).visible = false
		shell.showing = Shell.Screen.GAME
		shell.game.visible = true
		await _save("screen_tour_bare")
		shell.game.submit("حسم")
		await _save("screen_tour_moon")
		shell.game.submit("محس")
		await _save("screen_tour_lantern")
		shell.game.teaching = false
		shell.game._coach.visible = false
		shell.game._refresh_chrome()
		shell.game.visible = false
		shell.showing = Shell.Screen.TITLE
		shell.title.visible = true
		shell.game.show_level(Level.load_from("res://data/levels/m04-12.json"))
		shell.game.progress_path = SAVE

	await _save("screen_title")

	# The workbench, open. Debug builds only, so this shot exists and the
	# release the player gets has no such thing in it.
	if shell.admin != null:
		shell.admin._sheet.visible = true
		await _save("screen_admin")
		shell.admin._sheet.visible = false

	shell.go_to(Shell.Screen.MAP)
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout
	await _save("screen_map")

	shell.map.show_season(1)
	await _save("screen_map_summer")
	shell.map.show_season(0)

	shell.open_mansion(3)
	shell.mansion_window.settle()
	await _save("screen_mansion")
	shell.mansion_window.visible = false

	shell.open_settings()
	shell.settings_window.settle()
	await _save("screen_settings")
	shell.settings_window.visible = false

	shell.open_shop()
	shell.shop_window.settle()
	await _save("screen_shop")
	shell.shop_window.visible = false

	# Four days behind, today still to play; then today done; then the week.
	shell.game.daily_streak = 4
	shell.game.daily_day = Daily.today() - 1
	shell.open_daily()
	shell.daily_window.settle()
	await _save("screen_daily")

	shell.game.daily_streak = 5
	shell.game.daily_day = Daily.today()
	shell.open_daily()
	shell.daily_window.settle()
	await _save("screen_daily_done")

	shell.game.daily_streak = 7
	shell.open_daily()
	shell.daily_window.settle()
	await _save("screen_daily_week")
	shell.daily_window.visible = false

	# The conjunction, on a night that is the player's and on one that is not.
	# Both are real nights: 28 Sep 2026 puts the moon in الشرطان, 23 Sep in
	# سعد السعود, which this save has not reached.
	shell.open_qiran(int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 9, "day": 28,
		"hour": 0, "minute": 0, "second": 0}) / 86400.0))
	shell.qiran_window.settle()
	await _save("screen_qiran_open")
	shell.open_qiran(int(Time.get_unix_time_from_datetime_dict({
		"year": 2026, "month": 9, "day": 23,
		"hour": 0, "minute": 0, "second": 0}) / 86400.0))
	shell.qiran_window.settle()
	await _save("screen_qiran_far")
	shell.qiran_window.visible = false

	shell.go_to(Shell.Screen.CARDS)
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout
	await _save("screen_cards")
	# And further down, where nothing has been opened yet.
	shell.cards._scroll.scroll_vertical = 1400
	await _save("screen_cards_down")
	shell.go_to(Shell.Screen.MAP)
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout

	shell.go_to(Shell.Screen.GAME)
	await get_tree().create_timer(MeteorWipe.DURATION + 0.2).timeout

	# The light going out of the sky, lantern by lantern. Four shots, because
	# the whole point is that the steps are felt one at a time.
	for count in [5, 3, 1]:
		shell.game.lanterns = count
		shell.game._refresh_chrome()
		await _save("screen_dark_%d" % count)
	shell.game.lanterns = 0
	shell.game._refresh_chrome()
	shell.game.show_out_of_lanterns()
	shell.game.lanterns_window.settle()
	await _save("screen_dark_0")
	shell.game.lanterns_window.visible = false
	shell.notify_window.open()
	shell.notify_window.settle()
	await _save("screen_notify")
	shell.notify_window.visible = false
	shell.game.lanterns = 3
	shell.game._refresh_chrome()

	# The tenth star: the mansion's line, scattered and half put back.
	var verse := Level.load_from("res://data/levels/m01-10.json")
	if verse != null:
		shell.game.progress_path = ""
		shell.game.show_level(verse)
		await _save("screen_bayt")
		for i in 5:
			shell.game.bayt.reveal_next()
		await _save("screen_bayt_half")
		var guard := 0
		while not shell.game.bayt.solved and guard < 40:
			shell.game.bayt.reveal_next()
			guard += 1
		shell.game.complete_window.visible = false
		await _save("screen_bayt_done")

	# The rhyme, which comes before the twentieth star is drawn. Driven through
	# `_begin_anwa()` rather than posed, so the shot is the real screen.
	var last := Level.load_from("res://data/levels/m04-20.json")
	if last != null:
		shell.game.progress_path = ""
		shell.game.show_level(last)
		shell.game._begin_anwa()
		await _save("screen_anwa")
		shell.game.anwa.show_progress("الدبر")
		await _save("screen_anwa_writing")
		shell.game.anwa.lock()
		await _save("screen_anwa_done")
		for node in shell.game._content_nodes():
			node.modulate.a = 1.0

	# The twentieth star, at three moments.
	var finale := shell.game.finale
	finale.position = Vector2.ZERO
	finale.size = shell.game.size
	finale.settle(4)
	finale._lit = 3.0
	finale._drawn = 0.35
	finale.name_view.progress = 0.0
	finale.name_view.glow = 0.0
	finale._subtitle.modulate.a = 0.0
	for node in shell.game._content_nodes():
		node.modulate.a = 0.0
	await _save("screen_mansion_drawing")

	finale._lit = 5.0
	finale._drawn = 1.0
	finale.name_view.progress = 0.55
	await _save("screen_mansion_forming")

	finale.settle(4)
	finale._subtitle.modulate.a = 1.0
	await _save("screen_mansion_named")

	shell.game._show_mansion_card()
	shell.game.mansion_window.settle()
	await _save("screen_mansion_card")
	shell.game.mansion_window.visible = false
	finale.visible = false
	for node in shell.game._content_nodes():
		node.modulate.a = 1.0

	(shell.game.hint_button.get_meta("button") as Button).pressed.emit()
	shell.game.hints_window.settle()
	await _save("screen_hints")


func _save(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	image.save_png(ProjectSettings.globalize_path("res://tools/out/%s.png" % name))
	print("  shot -> tools/out/%s.png" % name)
