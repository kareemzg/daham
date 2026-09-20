# رحلة الشاوي (working title)

Arabic word-puzzle game: a letter wheel plus a crossword grid. Story: «سماء العرب». Most bright stars
carry Arabic names; every word lights a star, and each finished chapter draws a lunar mansion and
writes its name back into the sky. The Arab-cities journey survives as side events.

Targets: iOS, Android, macOS, Windows, Linux (Steam). Engine: Godot 4, GDScript.

## Layout

- `scenes/game/` the playable slice: `game.tscn` is the run scene. `scenes/dev/` holds developer test scenes. `scenes/main.tscn` is the old title placeholder, not wired up.
- `scripts/` shared GDScript: `arabic.gd` (normalisation, Eastern digits), `level.gd` (level JSON) and `progress.gd` (the save file).
- `assets/ui/icons/` the icon set as SVG, imported at five times its 64px box. Godot rasterises SVG with ThorVG, which does paths, strokes and gradients but not filters, masks or text.
- `assets/ui/glossy_panel.gdshader` the one shader the whole interface is drawn with: a rounded rect with a three-stop gradient, run down the face or outward from a point, plus a top highlight, a same-hue border, the hard bottom edge and an optional dark inner rim. `assets/ui/panel_shadow.gdshader` draws what goes under it, a soft drop shadow or a hard ring. `GlossyPanel` wraps both with a preset per element, every number in the 1080-wide reference space.
- `assets/fonts/` bundled Amiri (display, manuscript text) and IBM Plex Sans Arabic (UI), both under the SIL Open Font License with the license file beside each family. Scenes reference the `.tres` FontVariation resources, not the TTFs directly. `assets/theme/default_theme.tres` makes Plex the default font for every Control.
- `data/levels/` 560 generated levels plus the hand-written `sample.json` the test runs against. Produced by `tools/pipeline/`, never edited by hand.
- `tools/pipeline/` Python content pipeline: crossword layout and level export. See its README.
- `docs/` design documents: `story-sky.md` is the story bible; `claude-design-prompt.md` keeps the palette, type and motion spec (its story sections are superseded).

## Arabic text rules

- Wheel tiles and grid cells show isolated letterforms. The drag preview and all prose show connected script.
- Alif forms are normalized to bare ا on the wheel and grid. ة, ى and standalone ء stay distinct.
- The project locale is Arabic and the root layout direction is right-to-left.

## Playable slice

`godot --path .` runs the gameplay screen: wheel, drag, crossword grid, lanterns,
moon meter and star band, on the sample level `data/levels/m04-12.json`.

Check it before committing engine changes:

```bash
godot --path . --quit-after 900 res://scenes/dev/game_test.tscn
```

105 checks covering level data, Arabic normalisation, the drag path through real
input events, the word rules, the lantern penalty, the hint and shuffle buttons,
the save round-trip, what a quit leaves behind, the moon filling across levels,
and the on-screen layout. It exits non-zero on failure and writes
`tools/out/game_slice.png` to look at. Some checks read pixels back out of that
frame, because layout maths can be right while nothing is painted, and a spent
lantern has to actually look different from a lit one.

## Watching the motion

A screenshot cannot show an animation. This records one, driving the real game
through a bonus word, the level-complete window and the move to the next level:

```bash
godot --path . --fixed-fps 30 --write-movie tools/out/reel/f.png res://scenes/dev/motion_reel.tscn
```

`--fixed-fps` is what makes it watchable: every frame advances by the same slice
of time, so the recording plays back at the speed the game actually runs rather
than at whatever speed the machine managed. Turn the frames into a GIF with:

```bash
ffmpeg -framerate 30 -i tools/out/reel/f%08d.png -vf "scale=380:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse" -loop 0 tools/out/motion_reel.gif
```

The reel re-implements nothing. It restores a part-played level and then calls
the same methods a player's fingers would, so a motion that is wrong on screen
is wrong in the recording too.

## Editing the look

A step-by-step guide in Arabic, for changing colours, sizes and icons without
writing new code, is in [docs/tweaking-the-look.md](docs/tweaking-the-look.md).


`GameScreen`, `WordGrid`, `LetterWheel`, `GlossyPanel`, `UiIcon` and `StarBand`
are `@tool` scripts, so opening `scenes/game/game.tscn` in the Godot editor draws
the real screen: real tiles, real icons, the level loaded from JSON. Panel
presets, icon kinds and their levels are exported, so the Inspector edits them.

What the editor cannot do yet is move things: the chips, buttons, preview pill,
grid cells and wheel tiles are created in code, so they have no entry in the
Scene dock and cannot be dragged. Positions come from `_layout()` in `game.gd`,
which stacks the screen bottom-up from the wheel. Moving that into the scene file
with anchors and containers is the next step if drag-and-drop matters more than
the layout checks in the slice test.

Nodes built in code are never given an `owner`, so nothing generated is written
back into the scene file.

## Shaping test

```bash
godot --path . --quit-after 400 res://scenes/dev/shaping_test.tscn
```

Writes `tools/out/shaping_test.png`. The first line must render as connected words, right to left. The frame cap is a backstop so the run can never hang.

## Editing

Scenes and the inspector: the Godot editor (`godot -e --path .`). GDScript: VS Code with the `godot-tools` extension; `.vscode/` already points it at the installed Godot and has launch configs for the main scene and the shaping test. Set Godot to open scripts in VS Code under Editor Settings, Text Editor, External.
