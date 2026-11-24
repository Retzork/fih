class_name GameOverDialog
extends Control
## GameOverDialog - the base game's loss card (R65, EV-0249).
##
## The original's loss is a message dialog, not a screen of its own: `Tank::Update`
## (`FUN_00547610`, 0x548F34..0x548FB4) collects every coin (`FUN_0053C2D0`), clears `Tank+0x4EE`
## and builds `FUN_0054B5B0(0x11, 1, ...)` out of three shipped strings - "GAME OVER" (0x5A86DC) as
## the title, "Oops!  All of your fish have died!" (0x5A86E8) as the body and "Click to Continue"
## (0x5A8360) as the single button. This is that card on the shared `DialogSkin` panel.
##
## The card's id is recovered: every `FUN_0054B5B0` call site pushes its key, and the loss is id 17
## (`0x11`), beside the rescue hint's id 16 (`0x10`) - EV-0252. `WinFishApp::NewDialog` (0x54B940)
## does not branch on the key, so 17 names this card in the app's dialog map rather than a screen
## class. What its button leads to is still open (Q-0065), so the card only emits `continue_pressed`
## and `Main` takes the tank down its leave-tank path.
##
## The owner (`Main`) owns the tank's pause, exactly like `OptionsDialog`.

signal continue_pressed

## The base's message-dialog keys: `PUSH 0x11` at both loss call sites (0x5490B8 and the mode-5
## branch that jumps there) and `PUSH 0x10` on the rescue hint (0x548ED5) - EV-0252.
const DIALOG_ID := 17
const RESCUE_DIALOG_ID := 16
const TITLE_TEXT := "GAME OVER"
const BODY_TEXT := "Oops!  All of your fish have died!"
const BUTTON_TEXT := "Click to Continue"

## Sized around the base's title plaque, three body lines and one 33-px button row.
const PANEL_RECT := Rect2(170.0, 126.0, DialogSkin.PANEL_WIDTH, 220.0)
const BUTTON_SIZE := Vector2(264.0, 33.0)
const BUTTON_RECT := Rect2(18.0, 160.0, 264.0, 33.0)

var panel: Control = null


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = DialogSkin.panel(PANEL_RECT, _autoload("Content"))
	add_child(panel)
	panel.add_child(DialogSkin.title(TITLE_TEXT, Vector2(PANEL_RECT.size.x, 26.0)))
	var body := Label.new()
	body.name = "Body"
	body.text = BODY_TEXT
	body.position = Vector2(24.0, 58.0)
	body.size = Vector2(PANEL_RECT.size.x - 48.0, 84.0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(body, UiFont.SMALL_FONT)
	panel.add_child(body)
	var button := DialogSkin.button(
		"Continue", BUTTON_TEXT, BUTTON_RECT.position, BUTTON_SIZE, _autoload("Content"))
	button.pressed.connect(_on_continue)
	panel.add_child(button)
	button.grab_focus()


## The card has one action, so Enter, Space and Escape all take it: the player must not be able to get
## stuck on a modal that only answers to a mouse click.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			_on_continue()
			get_viewport().set_input_as_handled()


func _on_continue() -> void:
	var audio := _autoload("Audio")
	if audio != null and audio.has_method("play_click"):
		audio.play_click()
	continue_pressed.emit()
