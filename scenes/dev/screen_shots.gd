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
	await _save("screen_title")

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
