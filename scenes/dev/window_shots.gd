extends Control
## Renders each window over a played-in level, for looking at.
##
##   godot --path . res://scenes/dev/window_shots.tscn
##
## Layout maths can be right while a window still reads wrong, so this exists to
## be looked at rather than to pass.

@onready var game: GameScreen = $Game


## Frames the scene gives itself. Counted here rather than passed on the command
## line, for the reason the tests are: `--quit-after` exits 0, so a run it cuts
## short looks like a run that finished. This one was cut short for eight days
## and `win_settings.png` quietly stayed at the version before the fourth switch
## was added.
const FRAME_BUDGET := 1400

var _frames := 0


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > FRAME_BUDGET:
		push_error("window_shots ran past %d frames without finishing" % FRAME_BUDGET)
		get_tree().quit(2)


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

	# The settings window is NOT shot here. It belongs to the shell, and
	# `screen_shots.tscn` already takes it from there — `screen_settings.png`.
	# This scene drives a bare `GameScreen`, which has not owned that window
	# since it moved, and the shot it used to take went stale for eight days
	# without anyone noticing because `--quit-after` cut the run before it.


func _save(name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	image.save_png(ProjectSettings.globalize_path("res://tools/out/%s.png" % name))
	print("  shot -> tools/out/%s.png" % name)
