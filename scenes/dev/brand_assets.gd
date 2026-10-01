@tool
extends Control
## Writes every raster the stores and the engine need out of the brand SVGs.
##
## Run it once after touching `icon.svg` or anything under `assets/brand/`:
##   godot --path . res://scenes/dev/brand_assets.tscn
##
## It rasterises with Godot's own ThorVG, so what lands in the APK is what the
## engine would have drawn — no second rasteriser to disagree with the game.
## The splash is the exception and cannot be an SVG: it carries the wordmark,
## ThorVG ignores text, so it is drawn with the shipped Beiruti face into a
## transparent SubViewport and captured.
##
## It also writes `tools/out/brand_sizes.png`: the icon at 180, 120, 60 and 48,
## drawn at those sizes rather than scaled down from one big one. That is the
## only test that says whether the mark survives a home screen.

const BRAND := "res://assets/brand/"
const TITLE_FONT := "res://assets/fonts/arabic_title.tres"
const SPLASH := 640
## The wordmark under the mark. The splash is the first second of the game and
## the only place outside the store where the name is set by itself.
const WORDMARK := "نجمتك"
## How much of the splash the mark takes, and the wordmark under it.
const MARK_SCALE := 1.9
const WORDMARK_SIZE := 128

## Counted like every other dev scene: `--quit-after` exits 0, so a run it cuts
## short would read as a passing one.
const FRAME_BUDGET := 600

var _frames := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	OS.low_processor_usage_mode = false
	await get_tree().process_frame

	_raster("res://icon.svg", 1.0, "icon_1024.png")
	_raster("res://icon.svg", 192.0 / 1024.0, "icon_192.png")
	_raster(BRAND + "adaptive_foreground.svg", 1.0, "adaptive_foreground.png")
	_raster(BRAND + "adaptive_background.svg", 1.0, "adaptive_background.png")

	await _write_splash()
	await _write_sizes()

	print("brand: wrote the icons, the splash and tools/out/brand_sizes.png")
	get_tree().quit()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames > FRAME_BUDGET:
		push_error("brand_assets ran past %d frames without finishing." % FRAME_BUDGET)
		get_tree().quit(2)


## One SVG to one PNG, at the size the SVG declares times `scale`.
func _raster(path: String, scale: float, out_name: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty():
		push_error("brand: could not read %s" % path)
		get_tree().quit(2)
		return
	var image := Image.new()
	var err := image.load_svg_from_string(source, scale)
	if err != OK or image.is_empty():
		push_error("brand: ThorVG refused %s (%d)" % [path, err])
		get_tree().quit(2)
		return
	image.save_png(ProjectSettings.globalize_path(BRAND + out_name))


## The splash: the mark over the wordmark, on nothing. Godot draws it centred
## on `boot_splash/bg_color`, so anything painted behind it here would be a
## rectangle of sky sitting on a screen of sky.
func _write_splash() -> void:
	var mark := Image.new()
	var source := FileAccess.get_file_as_string(BRAND + "mark.svg")
	if mark.load_svg_from_string(source, MARK_SCALE) != OK:
		push_error("brand: ThorVG refused mark.svg")
		get_tree().quit(2)
		return

	var view := SubViewport.new()
	view.size = Vector2i(SPLASH, SPLASH)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)

	# Drawn on a Node2D and not laid out with Controls. The project's layout
	# direction is RTL, which mirrors a Control's x — the same thing that put
	# every icon off the left of the screen in `icon_probe`, and it mirrored the
	# mark here twice before it was recognised. A Node2D has no layout to mirror,
	# so the coordinates below mean what they say.
	var page := Node2D.new()
	view.add_child(page)

	var art := ImageTexture.create_from_image(mark)
	var font: Font = load(TITLE_FONT)
	# The mark's own art sits inside its 200-unit box from y 16 to 178, so its
	# foot on the page is the image's top plus that, scaled.
	var art_top := 70.0
	var art_foot := art_top + 178.0 * MARK_SCALE
	var baseline := art_foot + 40.0 + font.get_ascent(WORDMARK_SIZE)
	page.draw.connect(func() -> void:
		page.draw_texture(art, Vector2((SPLASH - art.get_width()) * 0.5, art_top))
		var run := font.get_string_size(WORDMARK, HORIZONTAL_ALIGNMENT_LEFT, -1, WORDMARK_SIZE)
		page.draw_string(font, Vector2((SPLASH - run.x) * 0.5, baseline), WORDMARK,
			HORIZONTAL_ALIGNMENT_LEFT, -1, WORDMARK_SIZE, Palette.GOLD_LIGHT)
	)
	page.queue_redraw()

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := view.get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(BRAND + "splash.png"))
	view.queue_free()


## The icon at the sizes a phone actually draws it, each rasterised at its own
## size. Scaling one big raster down would flatter it.
func _write_sizes() -> void:
	var sizes := [180, 120, 60, 48]
	var pad := 28
	var width := pad
	for size: int in sizes:
		width += size + pad
	var sheet := Image.create(width, 180 + pad * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("070B22"))

	var source := FileAccess.get_file_as_string("res://icon.svg")
	var at := pad
	for size: int in sizes:
		var one := Image.new()
		if one.load_svg_from_string(source, float(size) / 1024.0) != OK:
			push_error("brand: ThorVG refused icon.svg at %d" % size)
			get_tree().quit(2)
			return
		one.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(one, Rect2i(Vector2i.ZERO, one.get_size()),
			Vector2i(at, pad + 180 - size))
		at += size + pad

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	sheet.save_png(ProjectSettings.globalize_path("res://tools/out/brand_sizes.png"))
	await get_tree().process_frame
