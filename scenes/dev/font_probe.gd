extends Control
## Puts candidate faces beside the ones the game uses, on the game's own strings.
##
##   godot --path . res://scenes/dev/font_probe.tscn
##
## A specimen poster tells you what a font looks like at its best. This tells
## you what it looks like carrying «المنزلة ٤ — الدبران» and a fully vocalised
## line of verse, which is the only question that matters here.
##
## Candidates are read from wherever they sit on disk, so a face can be judged
## before it is copied into `assets/` and before anything is decided about its
## licence. `FontFile.load_dynamic_font()` takes a filesystem path, not a
## `res://` one, which is what makes that possible.
##
## It draws in `_draw()` and not with Labels, for the reason `icon_probe` does:
## the project is RTL, a Control's x is mirrored, and a column placed by hand
## walks off the edge.

const SHOT := "res://tools/out/font_probe.png"
const UI := preload("res://assets/fonts/arabic_ui_bold.tres")
const AMIRI := preload("res://assets/fonts/arabic_display_bold.tres")

## Absolute paths, and the colour each is drawn in.
const CANDIDATES := [
	["~/Downloads/Beiruti/static/Beiruti-Bold.ttf", "Beiruti Bold", "FFE38A"],
	["~/Downloads/Beiruti/static/Beiruti-Regular.ttf", "Beiruti Regular", "F0B07A"],
	["~/Downloads/OMNES-ARABIC-BOLD.ttf", "Omnes Bold", "8FE0D0"],
]

const LINES := [
	["اسم اللعبة", "نجمتك", 50],
	["الشرطة والأرقام", "المنزلة ٤ — النجمة ١٢ من ٢٠", 30],
	["أزرار", "واصل · المتجر · البطاقات", 30],
	["تشكيل", "سُهَيْل ٧٢٠٤", 34],
	["شطر بيت مشكول", "سَرَتْ عَلَيْهِ شَمَالٌ غَيْرُ مِشْفِقَةٍ", 30],
	["نثر", "الصفحةُ ليست بطاقةَ أرقام، هي سماؤك", 28],
]

var _faces: Array = []


func _ready() -> void:
	OS.low_processor_usage_mode = false
	for spec: Array in CANDIDATES:
		var path: String = spec[0]
		var on_disk := (
			ProjectSettings.globalize_path(path) if path.begins_with("res://")
			else path.replace("~", OS.get_environment("HOME"))
		)
		if not FileAccess.file_exists(on_disk):
			push_warning("no font at %s" % on_disk)
			continue
		var face := FontFile.new()
		face.load_dynamic_font(on_disk)
		_faces.append([face, spec[1] as String, Color(spec[2] as String)])
	# The game's own two, always last, so the eye compares against them.
	_faces.append([AMIRI, "Amiri", Color("8FD0FF")])
	_faces.append([UI, "Plex", Color("A8D6CE")])
	queue_redraw()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var shot := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tools/out"))
	shot.save_png(ProjectSettings.globalize_path(SHOT))
	print("wrote ", SHOT)
	for face: Array in _faces:
		print("  %s" % face[1])
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0A0B26"))
	if _faces.is_empty():
		return
	var right := size.x - 36.0
	var wide := 940.0
	var y := 52.0

	# The key, so a colour means a face without counting rows.
	var key := ""
	for face: Array in _faces:
		key += ("  |  " if key != "" else "") + (face[1] as String)
	draw_string(UI, Vector2(right - wide, y), key,
		HORIZONTAL_ALIGNMENT_RIGHT, wide, 20, Color("7F93A8"))
	y += 22.0
	var swatch := right
	for face: Array in _faces:
		var label: String = face[1]
		var span := UI.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 32.0
		draw_rect(Rect2(Vector2(swatch - span + 6.0, y), Vector2(span - 12.0, 5.0)),
			face[2] as Color)
		swatch -= span
	y += 32.0

	for row: Array in LINES:
		var text: String = row[1]
		var at: int = row[2]
		draw_string(UI, Vector2(right - wide, y), row[0] as String,
			HORIZONTAL_ALIGNMENT_RIGHT, wide, 18, Color("6F8196"))
		y += 28.0
		for face: Array in _faces:
			draw_string(face[0] as Font, Vector2(right - wide, y), text,
				HORIZONTAL_ALIGNMENT_RIGHT, wide, at, face[2] as Color)
			y += float(at) * 1.5
		y += 22.0
