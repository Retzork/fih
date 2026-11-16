class_name DebugPanel
extends Control
## Port-only debug controls over the tank (F1). This panel has **no counterpart in the shipped
## game**: the binary exposes no cheat console or debug menu (the P2.17 string search found none),
## so everything here is a playtest aid, not recovered behavior (D-0014).
##
## The buttons only emit `action_requested`; `Level.debug_action()` owns the effects. Keeping the
## dispatch in the level means the same actions are reachable from the keyboard and from the
## headless checks, where this Control is never built (`render = false`).

signal action_requested(action: StringName)

## `[id, label]` in panel order. The label carries the shortcut the level binds.
const ACTIONS := [
	["money", "F2   Money +1000"],
	["grow", "F3   Grow all fish"],
	["feed", "F4   Feed all fish"],
	["egg", "F6   Egg piece +1"],
	["weapon", "F7   Max weapon"],
	["reveal", "F8   Reveal store"],
	["guppy", "F10  Spawn guppy"],
]

## Where the panel sits when open (the left side of the tank, clear of the store bar).
const PANEL_RECT := Rect2(12.0, 96.0, 210.0, 254.0)

var _buttons: Array[Button] = []


## Build the panel. Follows `StoreBar.setup()`: the controls exist fully before the panel is added
## to the tree, so the headless checks can instantiate it without a Content autoload. It needs no
## `Level` reference - the owner connects `action_requested` - which keeps `Level` free to preload
## this script without a class cycle.
func setup() -> void:
	position = PANEL_RECT.position
	size = PANEL_RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := Panel.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Actions"
	box.position = Vector2(8.0, 8.0)
	box.size = PANEL_RECT.size - Vector2(16.0, 16.0)
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var title := Label.new()
	title.name = "Title"
	title.text = "DEBUG (F1)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color8(0xFF, 0xF0, 0x00))
	UiFont.apply(title, UiFont.SMALL_FONT)
	box.add_child(title)
	for entry: Array in ACTIONS:
		var action := StringName(entry[0])
		var button := Button.new()
		button.name = "Action_" + String(action)
		button.text = String(entry[1])
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		UiFont.apply(button, UiFont.SMALL_FONT)
		button.pressed.connect(_on_action_pressed.bind(action))
		box.add_child(button)
		_buttons.append(button)


## The button a headless check (or a future key hint) can press by action id, or null.
func button_for(action: StringName) -> Button:
	for button in _buttons:
		if String(button.name).trim_prefix("Action_") == String(action):
			return button
	return null


func _on_action_pressed(action: StringName) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	action_requested.emit(action)


## Resolve an autoload only inside the tree; the checks run this panel standalone.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)
