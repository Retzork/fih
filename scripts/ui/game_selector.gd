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

## The mermaid's tail is **baked into `SELECTORSCREEN`**: the backdrop paints her resting tail in
## full. `MERYLTAIL` (`tailflop.png`) is the separate animated overlay the original flops with, but
## its cells are flat thin shapes with no matching placement recovered; drawing one over the baked
## tail produced a green strap across it on screen. The port therefore leaves the baked art alone
## and Q-0055 records the missing one-shot overlay as an open visual item (no placement evidence).
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
