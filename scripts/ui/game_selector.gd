class_name GameSelector
extends Control
## GameSelector - the main menu (SPECS.md §6, P4.14). Eight buttons, dispatched by id exactly like
## `FUN_0051F160` (EV-0131): the listener takes the id and switches, it holds no state of its own.
##
## Only two ids write a mode here (1 -> adventure, 2 -> virtual tank), plus the two gated ones
## (8 -> time trial, 9 -> challenge). `choose()` returns what a press *would* do so the gates can be
## tested without a tree; `press()` applies it.
##
## The screen is the 640x480 `SELECTORSCREEN` art (mermaid + the telephone-box button panel), drawn
## at 1:1 because the project canvas is 640x480. The ctor `FUN_0052E070` places its eight buttons on
## that panel at fixed rects, so this file uses those rects instead of a container layout; the panel's
## purple slots are empty in the art, hence the text labels drawn over them.

signal start_requested(mode: int)

## The menu mermaid's tail is a **separate sprite** over the baked art: `MERYLTAIL`
## (`tailflop.png`, 8 cells of 238x165) from `resources.xml`. The backdrop keeps a resting tail of
## her own, but its pale filling reads as unfinished (in-game the tail is the sprite), so the port
## draws the sprite over it. The cell offset is a **port placement** - the note recovers the sheet and
## its timing, not the screen position - and Q-0055 records it. The sheet has no transparency:
## `masks/tailflop_.png` is its alpha layer (P3.3), composed in at load time by `MaskAlpha`.
const TAIL_OFFSET := Vector2(114.0, 274.0)
const TAIL_CELL := Vector2(238.0, 165.0)
## The idle pose: cell 2 of the strip is the gentle S-curve that covers the baked tail's footprint.
const TAIL_REST_FRAME := 2
## `MERYLTAIL`'s own playback (P2.15 §8.5): `anim="once"`, `framemap="7,6,5,4,3,2,1,0"`,
## `framedelay="2"`, `begindelay="3"` - so it plays once, two ticks a frame after a three-tick hold,
## and it starts when the sprite does. On the port's 36 Hz clock (Q-0034) that is ~56 ms a frame
## after ~83 ms, keeping the recovered delays as integer tick counts rather than re-deriving them.
## The port plays that flop when the menu opens and then returns to the rest pose instead of holding
## cell 0, because the backdrop's own tail is drawn under it (Q-0055).
const TAIL_PLAY_ORDER := [7, 6, 5, 4, 3, 2, 1, 0]
const TAIL_FRAME_TICKS := 2
const TAIL_BEGIN_TICKS := 3
## Read as raw files: `Content.texture()` hands back the first cell of an animated sheet, while the
## alpha composite needs the whole strip to line up with the whole mask.
const TAIL_SHEET_PATH := "res://assets_raw/images/tailflop.png"
const TAIL_MASK_PATH := "res://assets_raw/masks/tailflop_.png"

## Button id -> what the listener does with it (EV-0131).
const ACTIONS := {
	1: "mode",
	2: "mode",
	3: "options",
	4: "quit",
	6: "hall",
	7: "help",
	8: "mode",
	9: "mode",
}

## Button id -> the mode it writes.
const MODE_OF := {1: 0, 2: 5, 8: 1, 9: 4}

## The gates: time trial needs tank 2 unlocked (`profile+0x1C >= 2`), challenge needs a finished
## adventure (`profile+0x59 != 0`). Both show "Not Yet!" and change nothing.
const TANKS_NEEDED := 2

const SCREEN_SIZE := Vector2(640.0, 480.0)
## The ctor passes no height for the three bottom text buttons (the evidence records '-'), so they
## use this row height inside the art's small purple slot.
const TEXT_ROW_HEIGHT := 22.0

## Button id -> rect on the 640x480 screen (`FUN_0052E070`, EV-0131): the two image buttons
## (1 "Adventure", 2 "Virtual Tank") are 0xD9x0x42 and 0xD5x0x30 (8 "Time Trial", 9 "Challenge"),
## the text buttons 6 "Hall of Fame", 3 "Options", 7 "Help" and 4 "Quit" carry a width only.
const RECTS := {
	1: Rect2(357.0, 48.0, 217.0, 66.0),
	8: Rect2(359.0, 142.0, 213.0, 48.0),
	9: Rect2(359.0, 212.0, 213.0, 48.0),
	2: Rect2(357.0, 287.0, 217.0, 66.0),
	6: Rect2(401.0, 380.0, 127.0, TEXT_ROW_HEIGHT),
	3: Rect2(325.0, 412.0, 92.0, TEXT_ROW_HEIGHT),
	7: Rect2(419.0, 412.0, 93.0, TEXT_ROW_HEIGHT),
	4: Rect2(514.0, 412.0, 89.0, TEXT_ROW_HEIGHT),
}

## The big image buttons carry their label in art-sized slots, the bottom row is small text.
const BIG_IDS := [1, 8, 9, 2]

var _status: Label
var _tail: Sprite2D = null
var _tail_frames: Array[Texture2D] = []
## When the flop started, in logic ticks, and the texture it last drew.
var _tail_started := 0
var _tail_drawn := -1


## Resolve an autoload only when the menu is inside the scene tree. The menu check drives `choose()`
## and `press()` without adding the screen, where an absolute `/root/...` lookup is an engine error.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Menu music is the startup pair (P2.14 §4.1: the state `SexyApp::Init` leaves the app in).
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_music_pair(audio.PAIR_STARTUP)
	_add_background()
	_add_mermaid_tail()
	for id in [1, 8, 9, 2, 6, 3, 7, 4]:
		var rect: Rect2 = RECTS[id]
		var button := Button.new()
		button.name = "Button%d" % id
		button.text = label_for(id)
		button.position = rect.position
		button.size = rect.size
		# The art already holds the slot, so the button draws only the text.
		for style in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color(1, 1, 1))
		button.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.55))
		button.add_theme_color_override("font_pressed_color", Color(1, 0.78, 0.30))
		# The ctor preloads the two outline fonts (ids 0x61/0x62, P2.12 §4): the 17 px one for the
		# art-sized slots, the 10 px one for the small text buttons. The outline is baked into the
		# BMFont, so no engine outline is added on top (Q-0059).
		UiFont.apply(button, UiFont.SELECTOR_BIG_FONT if int(id) in BIG_IDS
			else UiFont.SELECTOR_SMALL_FONT)
		button.pressed.connect(func() -> void: press(int(id)))
		add_child(button)
	_status = Label.new()
	_status.name = "Status"
	_status.text = ""
	_status.position = Vector2(20.0, 452.0)
	_status.size = Vector2(300.0, 22.0)
	_status.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	UiFont.apply(_status, UiFont.SELECTOR_SMALL_FONT)
	add_child(_status)


## Draw the mermaid's tail over the baked art and play its one-shot flop. Without the sheet, the
## mask, or `MaskAlpha`, the screen keeps the art as it is.
func _add_mermaid_tail() -> void:
	# Export-safe (F1): `Image.load_from_file` warns "will not work on export" for imported
	# PNGs. Loading the imported textures and taking their images works in the editor and
	# in an export.
	var base_image := _texture_image(TAIL_SHEET_PATH)
	if base_image == null:
		return
	var mask_image := _texture_image(TAIL_MASK_PATH)
	if mask_image == null:
		return
	var sheet := MaskAlpha.apply(base_image, mask_image)
	if sheet == null:
		push_warning("MERYLTAIL: the sheet and its mask are different sizes")
		return
	var atlas := ImageTexture.create_from_image(sheet)
	_tail_frames.clear()
	for cell in TAIL_PLAY_ORDER:
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2(cell * TAIL_CELL.x, 0.0, TAIL_CELL.x, TAIL_CELL.y)
		_tail_frames.append(region)
	if _tail_frames.is_empty():
		return
	_tail = Sprite2D.new()
	_tail.name = "MermaidTail"
	_tail.centered = false
	_tail.position = TAIL_OFFSET
	add_child(_tail)
	# Playback starts now, on the same clock the rest of the game uses.
	var sim := _autoload("Sim")
	_tail_started = sim.tick_count if sim != null else 0
	# Draw the rest pose now and let `_process` start the flop after `TAIL_BEGIN_TICKS`; drawing at
	# `TAIL_BEGIN_TICKS` here would show the first flop cell for one frame before the hold.
	_draw_tail(_tail_started)


## The imported texture's image for an `assets_raw` PNG (export-safe, F1).
static func _texture_image(path: String) -> Image:
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var image := texture.get_image()
	return image


## Playback position on the strip, or -1 once the one-shot flop is over.
func tail_position(tick: int) -> int:
	var elapsed := tick - _tail_started - TAIL_BEGIN_TICKS
	if elapsed < 0:
		return -1
	var position := int(elapsed / TAIL_FRAME_TICKS)
	if position >= TAIL_PLAY_ORDER.size():
		return -1
	return position


## The strip cell drawn at `tick`: the rest pose before and after the flop.
func tail_cell(tick: int) -> int:
	var position := tail_position(tick)
	if position < 0:
		return TAIL_REST_FRAME
	return int(TAIL_PLAY_ORDER[position])


func _draw_tail(tick: int) -> void:
	if _tail == null or _tail_frames.is_empty():
		return
	var cell := tail_cell(tick)
	if cell == _tail_drawn:
		return
	_tail_drawn = cell
	var index := TAIL_PLAY_ORDER.find(cell)
	_tail.texture = _tail_frames[index if index >= 0 else 0]


func _process(_delta: float) -> void:
	if _tail == null:
		return
	var sim := _autoload("Sim")
	_draw_tail(sim.tick_count if sim != null else 0)


## The menu art (`SELECTORSCREEN`, 640x480). Without it the screen stays on the project clear colour.
func _add_background() -> void:
	var content := _autoload("Content")
	if content == null or not content.has_image("IMAGE_SELECTORSCREEN"):
		return
	var texture: Texture2D = content.texture("IMAGE_SELECTORSCREEN")
	if texture == null:
		return
	var back := TextureRect.new()
	back.name = "Background"
	back.texture = texture
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


## The on-screen text of a button (the original's labels; the art is Q-0030's area).
static func label_for(id: int) -> String:
	match id:
		1:
			return "Adventure"
		2:
			return "Virtual Tank"
		8:
			return "Time Trial"
		9:
			return "Challenge"
		3:
			return "Options"
		4:
			return "Quit"
		6:
			return "Hall of Fame"
		7:
			return "Help"
	return ""


## What pressing `button_id` does, given the profile: `{"action": ...}` where action is `mode`
## (with `mode`), `not_yet` (with `mode`), `options`, `quit`, `hall`, `help` or `ignored`.
static func choose(button_id: int, profile: Dictionary) -> Dictionary:
	if not ACTIONS.has(button_id):
		return {"action": "ignored"}
	var action := String(ACTIONS[button_id])
	if action != "mode":
		return {"action": action}
	var mode := int(MODE_OF[button_id])
	if button_id == 8 and int(profile.get("tanks_unlocked", 1)) < TANKS_NEEDED:
		return {"action": "not_yet", "mode": mode}
	if button_id == 9 and not bool(profile.get("adventure_done", false)):
		return {"action": "not_yet", "mode": mode}
	return {"action": "mode", "mode": mode}


## Apply a press. Options/hall/help mount their screens (P4.14); without the screen layer
## (standalone checks) they only report.
func press(button_id: int, profile: Dictionary = {}) -> Dictionary:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	var result := choose(button_id, profile)
	match String(result["action"]):
		"mode":
			# Looked up, not referenced: autoloads do not exist under `--script` (see the test notes).
			var game := _autoload("Game")
			if game != null:
				game.set_mode(int(result["mode"]))
			start_requested.emit(int(result["mode"]))
		"not_yet":
			if _status != null:
				_status.text = "Not Yet!"
		"quit":
			get_tree().quit()
		"options":
			_open_options()
		"hall":
			_open_hall()
		"help":
			_open_help()
		_:
			if _status != null and String(result["action"]) != "ignored":
				_status.text = "%s is not ported yet (Q-0050)" % label_for(button_id)
	return result


func _open_options() -> void:
	var screens := _autoload("Screens")
	var game := _autoload("Game")
	if screens == null:
		if _status != null:
			_status.text = "Options is not ported yet (Q-0050)"
		return
	var dialog := OptionsDialog.new()
	dialog.name = "OptionsDialog"
	dialog.closed.connect(func() -> void: screens.close_dialog())
	dialog.back_to_menu.connect(func() -> void:
		screens.close_dialog()
		if game != null:
			game.gameplay_paused = false)
	if not screens.open_dialog(dialog):
		dialog.queue_free()


func _open_hall() -> void:
	var screens := _autoload("Screens")
	var game := _autoload("Game")
	if screens == null:
		if _status != null:
			_status.text = "Hall of Fame is not ported yet (Q-0050)"
		return
	var screen := HallScreen.new()
	screen.name = "HallScreen"
	if game != null:
		screen.setup(game.profile)
	screen.closed.connect(func() -> void: screen.queue_free())
	screens.open_dialog(screen)


func _open_help() -> void:
	var screens := _autoload("Screens")
	if screens == null:
		if _status != null:
			_status.text = "Help is not ported yet (Q-0050)"
		return
	var screen := HelpScreen.new()
	screen.name = "HelpScreen"
	screen.closed.connect(func() -> void: screen.queue_free())
	screens.open_dialog(screen)
