class_name Sound
extends RefCounted
## Every sound the game makes, asked for from one place.
##
## Static, like `Mansions` and `Progress`, because a sound is wanted from the
## wheel, the grid, the finale and the shell alike, and threading a player
## down through all of them would put plumbing in every file it passed.
##
## But unlike those, this one owns nodes in the scene tree, and that is the
## one way the idiom goes wrong: `shell_test` builds three Shells and frees
## two, so a static that simply kept whatever the last `attach()` made ends up
## holding dead nodes while a live Shell plays on in silence.
##
## So `attach()` is safe to call as many times as there are Shells. It builds
## the pool only when there is not a live one already, and otherwise just
## rebinds the switches to the Shell that asked. Everything here checks the
## node is alive before touching it.
##
## The players hang off the Shell and not off the tree's root, which was the
## first thing tried: the root is busy setting up children while a Shell is
## being added, so `add_child()` on it during `_ready()` fails outright and
## leaves six valid, parentless players that refuse to play.
##
## The files under `assets/audio/` are placeholders written by
## `tools/make_sounds.py`. Decision 6 in `docs/to-launch.md` is a licensed
## pack; when it arrives each file is replaced by one of its own under the
## same name and nothing in this script changes.

## One tile crossed on the wheel.
const LETTER := &"letter"
## A word that was in the grid.
const WORD_OK := &"word_ok"
## A word Arabic has and the grid does not: the moon fills.
const WORD_BONUS := &"word_bonus"
## Not a word.
const WORD_NO := &"word_no"
## The grid is full.
const LEVEL_DONE := &"level_done"
## One star lights.
const STAR := &"star"
## Twenty stars, and the figure draws.
const MANSION := &"mansion"
## The moon comes full and pays out.
const MOON := &"moon"
## Any button at all.
const TAP := &"tap"
## A window widening out of a point of light.
const WINDOW := &"window"

const BANK := {
	LETTER: preload("res://assets/audio/letter.wav"),
	WORD_OK: preload("res://assets/audio/word_ok.wav"),
	WORD_BONUS: preload("res://assets/audio/word_bonus.wav"),
	WORD_NO: preload("res://assets/audio/word_no.wav"),
	LEVEL_DONE: preload("res://assets/audio/level_done.wav"),
	STAR: preload("res://assets/audio/star.wav"),
	MANSION: preload("res://assets/audio/mansion.wav"),
	MOON: preload("res://assets/audio/moon.wav"),
	TAP: preload("res://assets/audio/tap.wav"),
	WINDOW: preload("res://assets/audio/window.wav"),
}
const PAD := preload("res://assets/audio/music.wav")

## How many effects may sound at once. A drag across a seven-letter wheel is
## the busiest moment there is, and its ticks are 75ms apart.
const VOICES := 6
## The pad sits under the effects rather than beside them.
const MUSIC_DB := -9.0
## A letter's pitch climbs as the word grows. Four per cent a letter: enough
## to feel the word building, little enough that the seventh is not a shriek.
const LETTER_STEP := 0.04
const LETTER_CAP := 7

static var _players: Array[AudioStreamPlayer] = []
static var _music: AudioStreamPlayer = null
static var _settings: GameSettings = null
static var _turn := 0


## Build the players under `host` and read the switches from `settings`.
## Called once by `Shell`; calling it again replaces what was there, which is
## what a second Shell in the same run needs.
static func attach(host: Node, settings: GameSettings) -> void:
	_settings = settings
	if host == null or not is_instance_valid(host) or host.get_tree() == null:
		return
	if not _built():
		_players.clear()
		for i in VOICES:
			var player := AudioStreamPlayer.new()
			player.name = "Sfx%d" % i
			host.add_child(player)
			_players.append(player)
		_music = AudioStreamPlayer.new()
		_music.name = "Music"
		_music.stream = PAD
		_music.volume_db = MUSIC_DB
		host.add_child(_music)
	refresh()


## Whether the pool is there, alive, and actually in the tree. A second Shell
## must not double the players; a Shell that died must not leave the next one
## mute; and a player that never got parented must not count as one that did —
## `playing` on a node outside the tree is an error, not a sound.
static func _built() -> bool:
	if not is_instance_valid(_music) or not _music.is_inside_tree():
		return false
	if _players.size() != VOICES:
		return false
	for player in _players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			return false
	return true


## After a switch is thrown, or after `attach()`.
static func refresh() -> void:
	if not is_instance_valid(_music):
		return
	var wanted := _settings != null and _settings.music
	if wanted and not _music.playing:
		_music.play()
	elif not wanted and _music.playing:
		_music.stop()


static func play(which: StringName, pitch: float = 1.0) -> void:
	if _settings != null and not _settings.sound:
		return
	if not BANK.has(which):
		push_error("no sound named %s" % which)
		return
	var player := _free_player()
	if player == null:
		return
	player.stream = BANK[which]
	player.pitch_scale = pitch
	player.play()


## The tick for the nth letter of the word being spelled, counting from one.
static func letter(index: int) -> void:
	play(LETTER, 1.0 + LETTER_STEP * float(clampi(index, 1, LETTER_CAP) - 1))


## Give a button its tap. Every button in the game goes through here, and a
## test walks both scene trees and fails on any that did not: `make_button()`
## looked like the one place a button is born, and there were ten others.
##
## The handler is named rather than a lambda so the test can recognise it in
## `pressed.get_connections()`. An anonymous one is invisible to the check,
## which would leave the rule as a sentence again.
static func taps(button: BaseButton) -> void:
	if button == null or button.pressed.is_connected(_tap):
		return
	button.pressed.connect(_tap)


static func _tap() -> void:
	play(TAP)


## A short buzz in the hand. Handheld only — a desktop has nothing to shake,
## and the Android build needs `permissions/vibrate` or this is silence that
## looks like code.
static func buzz(milliseconds: int) -> void:
	if _settings != null and not _settings.haptics:
		return
	if not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(milliseconds)


## How many effects are sounding. The tests watch this rather than watching
## that `play()` was called: a call is not a sound.
static func voices_playing() -> int:
	var count := 0
	for player in _players:
		if is_instance_valid(player) and player.playing:
			count += 1
	return count


static func music_playing() -> bool:
	return is_instance_valid(_music) and _music.playing


## The next player that is not busy, or the oldest if they all are. Stealing
## the oldest is right for this game: the sound being cut is the one that
## started longest ago, which is the one nearest finished anyway.
static func _free_player() -> AudioStreamPlayer:
	var alive: Array[AudioStreamPlayer] = []
	for player in _players:
		if is_instance_valid(player):
			alive.append(player)
	if alive.is_empty():
		return null
	for player in alive:
		if not player.playing:
			return player
	_turn = (_turn + 1) % alive.size()
	return alive[_turn]
