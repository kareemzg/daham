extends Control
## Boots the real shell scene, with the real paths, on a cleared user folder —
## the way a phone boots after the app's data is wiped.
##
##   godot --path . res://scenes/dev/cold_probe.tscn

const SHOT := "res://tools/out/cold_probe.png"


func _ready() -> void:
	OS.low_processor_usage_mode = false
	Progress.clear("user://progress.json")
	GameSettings.clear("user://settings.json")
	print("cleared: progress exists = %s, settings exist = %s" % [
		FileAccess.file_exists("user://progress.json"),
		FileAccess.file_exists("user://settings.json"),
	])

	var shell: Shell = load("res://scenes/shell/shell.tscn").instantiate()
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame

	print("settings_path = '%s'   tour_done = %s" % [
		shell.settings_path, shell.settings.tour_done])
	print("level = %s   parse = %s" % [
		shell.game.level.id if shell.game.level != null else "<null>",
		Mansions.parse(shell.game.level.id) if shell.game.level != null else "-"])
	print("cold_open.visible = %s   title.visible = %s   showing = %d" % [
		shell.cold_open.visible, shell.title.visible, shell.showing])
	print("game.teaching = %s   game.visible = %s" % [
		shell.game.teaching, shell.game.visible])

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path(SHOT))
	print("wrote %s" % SHOT)
	get_tree().quit()
