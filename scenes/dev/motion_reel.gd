extends Control
## Records the three motions as a frame sequence, so they can be watched.
##
##   godot --path . --fixed-fps 30 --write-movie tools/out/reel/f.png \
##       res://scenes/dev/motion_reel.tscn
##
## Nothing here re-implements an animation. It restores a part-played level and
## then drives the game through real calls, so what lands in the frames is the
## same code a player sees. With --fixed-fps every frame advances by the same
## slice of time, so the reel plays back at the speed the game runs.

const FPS := 30.0

var _game: GameScreen


func _ready() -> void:
	OS.low_processor_usage_mode = false
	_game = $Game
	await get_tree().process_frame
	await get_tree().process_frame
	_play()


## Timers are wall-clock; under --fixed-fps a frame is always 1/FPS, so counting
## frames is what keeps the reel the same length every time it is recorded.
func _wait(seconds: float) -> void:
	for i in int(round(seconds * FPS)):
		await get_tree().process_frame


func _play() -> void:
	# Open on a level nearly done: four of the five words, three bonus words
	# already in the moon. No animation, the way reopening the game looks.
	var saved := Progress.new()
	saved.level_id = _game.level.id
	saved.coins = 480
	saved.lanterns = 5
	saved.moon = 3
	saved.found = PackedStringArray(["كتاب", "كاتب", "كتب", "تاب"])
	saved.bonus_found = PackedStringArray(["كبت"])
	_game.restore(saved)

	await _wait(0.5)

	# One: a bonus word. A star leaves the preview and climbs to the moon.
	_game.submit("بكت")
	await _wait(1.2)

	# Two: the last grid word. The level ends and the window blooms open.
	_game.submit("بات")
	await _wait(1.7)

	# Three: the meteor, which carries the next level in behind it.
	(_game.next_button.get_meta("button") as Button).pressed.emit()
	await _wait(1.3)

	get_tree().quit()
