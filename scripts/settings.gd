class_name GameSettings
extends RefCounted
## What the player chose in the settings window, kept between runs.
##
## Nothing reads these yet: the game has no audio and no haptics. They are
## stored anyway so the window does something real instead of drawing switches
## that forget, and so the day sound arrives it has somewhere to look.

const DEFAULT_PATH := "user://settings.json"
const VERSION := 1

var sound: bool = true
var music: bool = true
var haptics: bool = true
## Only Arabic exists. The row is in the window because the design has it, and
## because adding a second language later should not move anything.
var language: String = "ar"


static func read(path: String = DEFAULT_PATH) -> GameSettings:
	var settings := GameSettings.new()
	if not FileAccess.file_exists(path):
		return settings
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		push_error("Settings: cannot read %s" % path)
		return settings
	var parsed: Variant = JSON.parse_string(handle.get_as_text())
	handle.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Settings: %s is not a settings file, starting fresh" % path)
		return settings
	var data: Dictionary = parsed
	settings.sound = bool(data.get("sound", true))
	settings.music = bool(data.get("music", true))
	settings.haptics = bool(data.get("haptics", true))
	settings.language = str(data.get("language", "ar"))
	return settings


func write(path: String = DEFAULT_PATH) -> bool:
	var payload := {
		"version": VERSION,
		"sound": sound,
		"music": music,
		"haptics": haptics,
		"language": language,
	}
	# Beside the real file, then moved into place, as the save does: a kill
	# mid-write leaves the old settings rather than half a file.
	var temporary := path + ".part"
	var handle := FileAccess.open(temporary, FileAccess.WRITE)
	if handle == null:
		push_error("Settings: cannot write %s (%s)" % [temporary, FileAccess.get_open_error()])
		return false
	handle.store_string(JSON.stringify(payload))
	handle.close()
	var error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)
	)
	if error != OK:
		push_error("Settings: cannot replace %s (%s)" % [path, error_string(error)])
		return false
	return true


static func clear(path: String = DEFAULT_PATH) -> void:
	for candidate in [path, path + ".part"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
