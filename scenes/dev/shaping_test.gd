extends Control
## Renders one frame of Arabic text and saves it to tools/out/shaping_test.png.
## Run from the project folder:
##   godot --path . res://scenes/dev/shaping_test.tscn
## If the letters come out connected and right-to-left, the text server works.

func _ready() -> void:
	# The project runs in low-processor mode (redraw only on change), which can
	# stall the frame_post_draw await below. Force continuous drawing for the test.
	OS.low_processor_usage_mode = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var out_dir := ProjectSettings.globalize_path("res://tools/out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var err := img.save_png(out_dir.path_join("shaping_test.png"))
	print("shaping_test: save_png -> ", error_string(err))
	print("shaping_test: text server = ", TextServerManager.get_primary_interface().get_name())
	get_tree().quit()
