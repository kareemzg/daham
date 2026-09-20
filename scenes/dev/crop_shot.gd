extends SceneTree
## Crops a piece of the last slice screenshot and blows it up, for looking at
## one detail closely. Edit the region, then:
##
##   godot --path . --headless --script res://scenes/dev/crop_shot.gd
##
## Writes /tmp/hud_zoom.png. Nothing in the game depends on this.


func _initialize() -> void:
	var path := ProjectSettings.globalize_path("res://tools/out/game_slice.png")
	var img := Image.load_from_file(path)
	var region := img.get_region(Rect2i(360, 45, 700, 130))
	region.resize(region.get_width() * 4, region.get_height() * 4, Image.INTERPOLATE_NEAREST)
	region.save_png("/tmp/hud_zoom.png")
	print("saved /tmp/hud_zoom.png ", region.get_width(), "x", region.get_height())
	quit()
