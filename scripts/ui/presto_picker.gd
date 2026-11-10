class_name PrestoPicker
extends Control
## The "PRESTO CHANGE-O" pet picker (P2.7 §3.3/§4.20, EV-0100; R9 follow-up).
##
## `FUN_0054C6F0` allocates a `Sexy::PetDialog` (0x2F8 bytes) through `FUN_005355C0` and pushes
## screen id 0x1F. It is a modal dialog over the tank, so the game pauses while it is up and the
## `Screens` single-dialog slot owns where it lives - the same contract as `StoreScreen`.
##
## Recovered: the dialog's identity/title, the screen id and that it is Presto's picker.
## **Not recovered**, so bound rather than guessed: the picker's own list (the wiki's "every
## unlocked pet" is the only statement about it) and the input that opens it (EV-0106 says the
## right-click binding was never traced). The port offers the **owned** pets minus the current one,
## and `Level` binds the port-only `P` key next to its existing `S` shop key (Q-0061).
##
## The swap and its gate are `Pet.transform_to` / `can_transform` (`FUN_004F89A0` +
## `FUN_004F2650(+0x238) < 1`); "Recharging..." is the reason the dialog refuses to open, not a
## timer this dialog draws.

signal closed

const TITLE := "PRESTO CHANGE-O"
## The screen id `FUN_0054C6F0` pushes.
const SCREEN_ID := 0x1F
## `FUN_004F89A0`'s failure text, drawn at `(x + width/2 - 20, y - 10)` over the pet. The dialog only
## opens once the timer is spent, so this is the explanation line here.
const RECHARGING_TEXT := "Recharging..."
const PANEL_RECT := Rect2(150.0, 96.0, 340.0, 288.0)
const TITLE_OFFSET := Vector2(0.0, 8.0)
const LIST_OFFSET := Vector2(20.0, 44.0)
const COLUMNS := 3
const ROW_HEIGHT := 28.0
const CELL_WIDTH := 100.0

## The level the swap happens in and the pet being transformed. `setup()` runs before the screen
## enters the tree, like every other dialog.
var level: Level = null
var pet: Pet = null


func setup(source: Level, source_pet: Pet) -> void:
	level = source
	pet = source_pet


## Resolve an autoload only inside the tree: the `--script` suites drive `press()`/`candidates()`
## on a standalone picker, where `/root/...` is an error and a missing autoload is normal.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


## The pet indices the dialog offers: owned, and never the pet doing the transforming
## (`FUN_004F89A0` ignores a same-index target). Sorted by roster index.
func candidates() -> Array[int]:
	var out: Array[int] = []
	if level == null or pet == null:
		return out
	var owner_profile := level._profile()
	for index in Progression.PET_NAMES.size():
		if index == pet.index or not owner_profile.owns_pet(index):
			continue
		out.append(index)
	return out


## Take one pick. Returns whether the swap happened; a refused pick leaves the dialog open, which is
## what `FUN_004F89A0`'s own early exits do.
func press(index: int) -> bool:
	if pet == null or not is_instance_valid(pet) or not candidates().has(index):
		return false
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	var swapped := pet.transform_to(index)
	if swapped:
		close()
	return swapped


## Close the dialog and let the tank run again.
func close() -> void:
	var game := _autoload("Game")
	if game != null:
		game.gameplay_paused = false
	var screens := _autoload("Screens")
	if screens != null:
		screens.close_dialog()
	if level != null and level.presto_picker == self:
		level.presto_picker = null
	closed.emit()
	queue_free()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel())
	for index in candidates():
		add_child(_pet_button(index))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _panel() -> Control:
	var back := ColorRect.new()
	back.name = "Panel"
	back.color = Color(0.05, 0.12, 0.2, 0.92)
	back.position = PANEL_RECT.position
	back.size = PANEL_RECT.size
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Label.new()
	title.name = "Title"
	title.text = TITLE
	title.position = TITLE_OFFSET
	title.size = Vector2(PANEL_RECT.size.x, 28.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	UiFont.apply(title, UiFont.LABEL_FONT)
	back.add_child(title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Pick a pet to become"
	hint.position = Vector2(TITLE_OFFSET.x, 26.0)
	hint.size = Vector2(PANEL_RECT.size.x, 18.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(hint, UiFont.TINY_FONT)
	back.add_child(hint)
	var cancel := Button.new()
	cancel.name = "Cancel"
	cancel.text = "Cancel"
	cancel.position = Vector2(PANEL_RECT.size.x - 90.0, PANEL_RECT.size.y - 34.0)
	cancel.size = Vector2(70.0, 26.0)
	UiFont.apply(cancel, UiFont.TINY_FONT)
	cancel.pressed.connect(close)
	back.add_child(cancel)
	return back


func _pet_button(index: int) -> Button:
	var button := Button.new()
	button.name = "Pet%d" % index
	var column := candidates().find(index) % COLUMNS
	var row := candidates().find(index) / COLUMNS
	button.position = LIST_OFFSET + Vector2(column * CELL_WIDTH, row * ROW_HEIGHT)
	button.size = Vector2(CELL_WIDTH - 6.0, ROW_HEIGHT - 4.0)
	button.text = Progression.pet_name(index)
	UiFont.apply(button, UiFont.TINY_FONT)
	button.pressed.connect(press.bind(index))
	return button
