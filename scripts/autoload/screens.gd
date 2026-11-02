extends Node
## Screens - the screen stack and the single modal slot.
##
## Screens are plain Control subtrees, ported as data + one id-dispatched handler (SPECS.md §6,
## P2.12). This autoload only manages *where* they live in the tree; it knows nothing about any
## concrete screen. The host CanvasLayer is registered once by Main.
##
## Dialogs are modal: the original has exactly one add-window slot, so a second `open_dialog()`
## while one is open is a bug in the caller, not a stack.

signal screen_changed(screen_id: StringName)

## CanvasLayer that receives screens (set by Main._ready()).
@export var layer_path: NodePath

var _layer: Node
var _current: Control
var _dialog: Control


func attach(layer: Node) -> void:
	_layer = layer


func current() -> Control:
	return _current


func dialog() -> Control:
	return _dialog


## Replace the active screen. The previous one is freed after the new one is shown, so a screen may
## open its successor from a button callback without pulling the tree out from under itself.
func replace(screen: Control, screen_id: StringName = &"") -> void:
	if _layer == null:
		push_error("Screens.attach() was never called")
		return
	var previous := _current
	_current = screen
	_layer.add_child(screen)
	if previous != null:
		previous.queue_free()
	screen_changed.emit(screen_id)


## Open the modal dialog slot. Returns false (and leaves the tree untouched) when one is already
## open, which is what the original's single slot does.
func open_dialog(dialog: Control) -> bool:
	if _dialog != null:
		push_warning("a dialog is already open")
		return false
	_dialog = dialog
	_layer.add_child(dialog)
	return true


func close_dialog() -> void:
	if _dialog == null:
		return
	_dialog.queue_free()
	_dialog = null
