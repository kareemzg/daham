extends Control
## Draws one icon at a ladder of sizes and saves it, so "the icons look
## pixelated" can be measured instead of argued about.
##
##   godot --path . res://scenes/dev/icon_probe.tscn
##
## It draws straight into `_draw()` rather than placing `UiIcon` nodes: the
## project is RTL and a Control's x is mirrored, which put every icon off the
## left of the screen. `draw_texture_rect` is what `UiIcon` calls anyway, so
## this measures the same path with none of the layout in the way.

const SHOT := "res://tools/out/icon_probe.png"
const ICON := preload("res://assets/ui/icons/settings.svg")
const SIZES := [24, 30, 46, 64, 92, 128, 184, 256, 360]


func _ready() -> void:
	OS.low_processor_usage_mode = false
	await get_tree().process_frame
	await get_tree().process_frame
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(SHOT))
	print("source texture %d x %d" % [ICON.get_width(), ICON.get_height()])
	var x := 20.0
	for side in SIZES:
		print("  %3d px at x %.0f" % [side, x])
		x += float(side) + 24.0
	print("wrote %s  (%d x %d)" % [SHOT, shot.get_width(), shot.get_height()])
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("F6EEDC"))
	var x := 20.0
	var y := 120.0
	for side in SIZES:
		draw_texture_rect(ICON, Rect2(Vector2(x, y), Vector2(side, side)), false)
		x += float(side) + 24.0
		if x + float(side) > size.x:
			x = 20.0
			y += 400.0
