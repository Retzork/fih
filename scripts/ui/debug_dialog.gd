class_name DebugDialog
extends Control
## The port-only debug controls in their own modal (D-0014, D-0017).
##
## The shipped game has no cheat console or debug menu (P2.17 found no such strings), so every
## button here is a playtest aid, not recovered behaviour. It was split out of `OptionsDialog` in
## the 2026-11-16 owner review: the dark grid pasted over the Options panel's bottom frame read as
## broken art next to the shipped `Dialogue-panel`.
##
## The buttons only emit `action_requested`; `Level.debug_action()` owns the effects, the same
## dispatcher the F2..F10 keys and the F1 panel use. Show Money is the TankScreen INI option (P2.5,
## `TankScreen+0x83C`), not a base Options checkbox, which is why it lives here.

signal closed
signal action_requested(action: StringName)

## The panel sits inside the 640x480 reference like the base dialog, a little lower and narrower so
## it reads as its own window rather than an Options variant.
const PANEL_RECT := Rect2(164.0, 62.0, 312.0, 336.0)
const TITLE := "DEBUG"
const SUBTITLE := "PORT-ONLY (D-0014)"
const GRID_AT := Vector2(22.0, 66.0)
const COLUMNS := 2
const BUTTON_SIZE := Vector2(130.0, 33.0)
const GRID_GAP := Vector2(8.0, 6.0)
const CLOSE_AT := Vector2(22.0, 244.0)
const CLOSE_SIZE := Vector2(268.0, 33.0)

## `[id, label]` in grid order; the ids are `Level.debug_action()`'s, the labels are the buttons'.
const ACTIONS := [
	["money", "MONEY +1000"],
	["grow", "GROW FISH"],
	["feed", "FEED FISH"],
	["egg", "EGG +1"],
	["weapon", "MAX WEAPON"],
	["reveal", "REVEAL STORE"],
	["guppy", "SPAWN GUPPY"],
]

## Port-only: the Show Money toggle, seeded from the shared setting.
var show_money_box: Button = null
var panel: Control = null
var _buttons: Dictionary = {}


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var content := _autoload("Content")
	panel = DialogSkin.panel(PANEL_RECT, content)
	add_child(panel)
	panel.add_child(DialogSkin.title(TITLE, Vector2(PANEL_RECT.size.x, 26.0)))

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = SUBTITLE
	subtitle.position = Vector2(0.0, 44.0)
	subtitle.size = Vector2(PANEL_RECT.size.x, 16.0)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(subtitle, UiFont.TINY_FONT)
	subtitle.add_theme_color_override("font_color", Color8(0xFF, 0xE8, 0xA0))
	panel.add_child(subtitle)

	_build_grid(content)
	_build_show_money(content)
	var close := DialogSkin.button("Close", "CLOSE", CLOSE_AT, CLOSE_SIZE, content)
	close.pressed.connect(_on_close)
	panel.add_child(close)


## The seven actions in two columns; the eighth cell is the Show Money toggle.
func _build_grid(content: Node) -> void:
	for index in ACTIONS.size():
		var entry: Array = ACTIONS[index]
		var action := StringName(entry[0])
		var at := GRID_AT + Vector2(
			(index % COLUMNS) * (BUTTON_SIZE.x + GRID_GAP.x),
			float(index / COLUMNS) * (BUTTON_SIZE.y + GRID_GAP.y))
		var button := DialogSkin.button("Debug_" + String(action), String(entry[1]), at,
			BUTTON_SIZE, content)
		button.pressed.connect(_on_action_pressed.bind(action))
		panel.add_child(button)
		_buttons[action] = button


func _build_show_money(content: Node) -> void:
	# The TankScreen's ShowMoney option (P2.5), not a base Options checkbox. The label carries the
	# state because the debug grid has no checkbox art.
	var index := ACTIONS.size()
	var at := GRID_AT + Vector2(
		(index % COLUMNS) * (BUTTON_SIZE.x + GRID_GAP.x),
		float(index / COLUMNS) * (BUTTON_SIZE.y + GRID_GAP.y))
	var game := _autoload("Game")
	var show_on := game != null and bool(game.show_money)
	show_money_box = DialogSkin.button("ShowMoney", _show_money_text(show_on), at, BUTTON_SIZE,
		content)
	show_money_box.toggle_mode = true
	show_money_box.set_pressed_no_signal(show_on)
	show_money_box.toggled.connect(_on_show_money)
	panel.add_child(show_money_box)


## The debug button for an action id, or null. Used by the headless checks and the windowed probe.
func debug_button_for(action: StringName) -> Button:
	var button: Button = _buttons.get(action)
	return button if button != null and is_instance_valid(button) else null


## Close the dialog and let its owner decide what comes back.
func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()


func _on_close() -> void:
	_play_click()
	closed.emit()


func _on_action_pressed(action: StringName) -> void:
	_play_click()
	action_requested.emit(action)


func _on_show_money(pressed: bool) -> void:
	_play_click()
	if show_money_box != null:
		show_money_box.text = _show_money_text(pressed)
	var game := _autoload("Game")
	if game != null:
		game.show_money = pressed


func _show_money_text(show: bool) -> String:
	return "SHOW MONEY: ON" if show else "SHOW MONEY: OFF"


func _play_click() -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
