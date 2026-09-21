extends Control
## Records the twentieth star, for watching.
##
##   godot --path . --fixed-fps 30 --write-movie tools/out/finale/f.png \
##       res://scenes/dev/finale_reel.tscn
##
## Nothing here re-implements the moment. It restores the last level of a
## mansion with one word left, then spells that word, so what lands in the
## frames is the same code a player sees.

const FPS := 30.0

var _game: GameScreen


func _ready() -> void:
	OS.low_processor_usage_mode = false
	_game = $Game
	await get_tree().process_frame
	await get_tree().process_frame
	_play()


## Under --fixed-fps a frame is always 1/FPS, so counting frames is what keeps
## the reel the same length every time it is recorded.
func _wait(seconds: float) -> void:
	for i in int(round(seconds * FPS)):
		await get_tree().process_frame


func _play() -> void:
	var last := Level.load_from("res://data/levels/m04-20.json")
	_game.show_level(last)

	# Four of the five words already found: the board a player would be looking
	# at with one word left in the twentieth level of الدبران.
	var saved := Progress.new()
	saved.level_id = last.id
	saved.coins = 980
	saved.lanterns = 4
	saved.moon = 5
	saved.found = PackedStringArray(["عام", "دعم", "معا", "عدم"])
	_game.restore(saved)
	await _wait(0.7)

	# The last word. Everything after this is the game's own.
	_game.submit("اعتمد")
	await _wait(6.8)

	get_tree().quit()
