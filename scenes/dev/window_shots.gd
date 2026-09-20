extends Control
## Renders each window over a played-in level, for looking at.
##
##   godot --path . --quit-after 600 res://scenes/dev/window_shots.tscn
##
## Layout maths can be right while a window still reads wrong, so this exists to
## be looked at rather than to pass.

@onready var game: GameScreen = $Game


func _ready() -> void:
	OS.low_processor_usage_mode = false
	await get_tree().process_frame
	await get_tree().process_frame
	await _shoot()
	get_tree().quit()


func _played_in() -> Progress:
	var saved := Progress.new()
	saved.level_id = game.level.id
	saved.coins = 480
	saved.lanterns = 5
	saved.moon = 4
	saved.found = PackedStringArray(["كتاب", "كتب"])
	return saved


func _shoot() -> void:
	game.show_level(game.level)
	game.restore(_played_in())
	await _save("win_play")

	for word in ["كاتب", "تاب", "بات"]:
		game.submit(word)
	game.complete_window.settle()
	await _save("win_complete")

	game.show_level(game.level)
	game.restore(_played_in())
	game.lanterns = 0
	game.show_out_of_lanterns()
	game.lanterns_window.settle()
	await _save("win_lanterns")

	game.show_level(game.level)
	game.restore(_played_in())
	(game.restart_button.get_meta("button") as Button).pressed.emit()
	game.restart_window.settle()
	await _save("win_restart")

	(game.settings_button.get_meta("button") as Button).pressed.emit()
	game.settings_window.settle()
	await _save("win_settings")


func _save(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	image.save_png(ProjectSettings.globalize_path("res://tools/out/%s.png" % name))
	print("  shot -> tools/out/%s.png" % name)
