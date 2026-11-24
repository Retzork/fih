class_name PetsScreen
extends Control
## PetsScreen - the shipped 24-pet chooser (P2.12 §10.6/§11, EV-0136; R60).
##
## The screen is a 24-button grid, not a text list. The recovered layout (`FUN_00527820`) is the grid
## origin `(0x19, 0x5E)`, a `0x5A x 0x53` cell on a `0x53` row pitch, and a five-column stagger whose
## run breaks at i = 5, 10, 15, 19, 22 - so the rows hold 5/5/5/4/3/2 buttons. Each button is a
## `PetButtonWidget`, hidden when the pet is not owned (`FUN_00501410(i) == 0`), and the widget's art
## is the shipped `PETBUTTON` cell with its `PETBUTTONHOLE`, `PETBUTTONREFLECT` and `PETBUTTONRING`
## companions (the ring is drawn on a selected pet). The per-row indent and the ship's four
## `PETBUTTON` cells (the widget's state sheet) are port fits: the note records the break points and
## the cell, not the row x or the cell order (Q-0063).
##
## Buttons: id 99 "Click Here To Continue" at `(0xE1, 0xFA, 0xBA)` and id 100 "Menu" at
## `(0x20D, 4, 0x50)`. Outside the Virtual Tank the ctor clears `profile+0x5A` and the confirm writes
## the 24 flag bytes back (`FUN_005289F0`); with fewer than three pets selected the binary asks
## "Select More Pets?" first, so the click path asks and the already-answered path continues
## (`press_confirm`). The selection cap is `+0x130 = min(profile+0xB4, profile+0x18)` clamped to 4;
## `+0xB4` has no located writer, so the clamp is the figure the port can use.

signal confirm_pressed(selected: Array[int])
## The recovered "Menu" button (id 100).
signal menu_pressed

const SCREEN_SIZE := Vector2(640.0, 480.0)
const BACKGROUND_ID := "IMAGE_SCREENBACK"
const BUTTON_ID := "IMAGE_PETBUTTON"
const RING_ID := "IMAGE_PETBUTTONRING"
const REFLECT_ID := "IMAGE_PETBUTTONREFLECT"
const HOLE_ID := "IMAGE_PETBUTTONHOLE"

## `FUN_00527820`'s grid: `+0x118 = 0x19`, `+0x11C = 0x5E`, cell `0x5A x 0x53`, row pitch `0x53`.
const GRID_ORIGIN := Vector2(25.0, 94.0)
const CELL := Vector2(90.0, 83.0)
const ROW_PITCH := 83.0
## The column run breaks at i = 5, 10, 15, 19, 22.
const ROW_COUNTS := [5, 5, 5, 4, 3, 2]
const MAX_COLUMNS := 5

## id 99 at `(0xE1, 0xFA, 0xBA)` and id 100 at `(0x20D, 4, 0x50)`; the ctor passes a width only, so
## the row height is the port's (the Hatch card's convention).
const CONTINUE_RECT := Rect2(225.0, 250.0, 186.0, 30.0)
const MENU_RECT := Rect2(525.0, 4.0, 80.0, 26.0)
const CONTINUE_LABEL := "Click Here To Continue"
const MENU_LABEL := "Menu"
const CONTINUE_COLOR := Color(1.0, 240.0 / 255.0, 0.0)

## The pet's own cell inside the button.
const PORTRAIT_SIZE := Vector2(60.0, 60.0)
## `PETBUTTON` ships four 90x83 faces: cell 0 is the gold dome and cells 1-3 are flat purple / gold /
## cyan colourways of the same dome. Which face the base uses for which state is unread (Q-0063), so
## the port marks a selection with the bright gold face - shipped art, but the cell choice is a port
## fit. `PETBUTTONRING` is a ~2 px gold outline (734 lit pixels in the masked cell), which vanishes
## against the gold dome at 1:1, so it is drawn on top rather than relied on alone.
const NORMAL_FRAME := 0
const SELECTED_FRAME := 2
const SELECTED_TINT := Color(1.0, 1.0, 1.0)
## Everything unselected is dimmed, so no idle button can be mistaken for the lit one.
const UNSELECTED_TINT := Color(0.55, 0.55, 0.6)
## The selection cap is the mode-0 clamp of `+0x130` (Q-0063).
const SELECTION_CAP := 4
## The confirm gate: fewer than three selected pets asks before continuing (`FUN_005289F0`).
const MIN_PETS := 3
const ASK_TITLE := "Select More Pets?"
const ASK_FEW_PETS := "Are you sure you want to continue to the next level without selecting 3 pets?"
const ASK_AT_CAP := "Are you sure you want to continue to the next level without selecting at least 3 pets?"

var profile: Profile = null

var _cells: Dictionary = {}
var _rings: Dictionary = {}
var _domes: Dictionary = {}
var _dome_textures: Dictionary = {}
var _message: Label = null
var _viewport: Control = null
var _grid: Control = null
var _scroll_y := 0.0


## Resolve an autoload only when the screen is inside the tree; the `--script` suites build the
## screen standalone, where `/root/...` does not exist and the art is simply absent.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func setup(source: Profile) -> void:
	profile = source
	if profile != null:
		# Outside the Virtual Tank the ctor clears the pending selection (`profile+0x5A`).
		profile.selected_pets.fill(0)


# --- layout (pure, so it is checkable headlessly) ----------------------------

static func row_counts() -> Array:
	return ROW_COUNTS


## The first grid index of `row`.
static func row_start(row: int) -> int:
	var total := 0
	for i in clampi(row, 0, ROW_COUNTS.size()):
		total += int(ROW_COUNTS[i])
	return total


static func row_of(index: int) -> int:
	var row := 0
	while row < ROW_COUNTS.size() - 1 and index >= row_start(row + 1):
		row += 1
	return row


## The button's rect on the 640x480 screen. The stagger indents a short row by half a cell per
## missing column - that x offset is the port's fit, the origin/cell/pitch/run lengths are recovered.
static func grid_rect(index: int) -> Rect2:
	var row := row_of(index)
	var count := int(ROW_COUNTS[row])
	var column := index - row_start(row)
	var indent := float(MAX_COLUMNS - count) * CELL.x * 0.5
	return Rect2(GRID_ORIGIN + Vector2(indent + float(column) * CELL.x, float(row) * ROW_PITCH), CELL)


## The "Select More Pets?" body, chosen the way the binary chooses it: the shorter wording when the
## selection cap itself is under four (`screen+0x130 < 4`), the "at least 3" wording otherwise.
static func ask_body(cap: int) -> String:
	return ASK_FEW_PETS if cap < 4 else ASK_AT_CAP


# --- selection state --------------------------------------------------------

## Whether the screen offers a button at all: an unowned pet's widget is hidden (`FUN_00501410`).
func is_available(index: int) -> bool:
	return profile != null and profile.owns_pet(index)


func selected_count() -> int:
	if profile == null:
		return 0
	return profile.selected_pets.count(1)


func selected() -> Array[int]:
	var out: Array[int] = []
	if profile == null:
		return out
	for i in profile.selected_pets.size():
		if profile.selected_pets[i] != 0:
			out.append(i)
	return out


## `+0x130`: at most four pets, and never more than the player owns.
func selection_cap() -> int:
	if profile == null:
		return 0
	return mini(SELECTION_CAP, profile.pet_count())


## Toggle one pet the way a button click does. Returns the new state. An unowned pet and a pet past
## the cap both refuse.
func toggle(index: int) -> bool:
	if not is_available(index):
		return false
	if profile.selected_pets[index] != 0:
		profile.selected_pets[index] = 0
		_refresh_selection()
		return false
	if selected_count() >= selection_cap():
		return false
	profile.selected_pets[index] = 1
	_refresh_selection()
	return true


## The continue click. Fewer than three pets selected asks first and changes nothing until the
## already-answered path runs (`FUN_005289F0`'s "Select More Pets?" box).
func request_confirm() -> bool:
	if selected_count() < MIN_PETS:
		_show_ask()
		return false
	_apply()
	return true


## The answered path: write the selection back and continue. `Main` and the suites drive this.
func press_confirm() -> void:
	_apply()


func _apply() -> void:
	_message_text("")
	confirm_pressed.emit(selected())


func _show_ask() -> void:
	_message_text("%s %s" % [ASK_TITLE, ask_body(selection_cap())])


func _message_text(text: String) -> void:
	if _message == null:
		return
	_message.text = text
	_message.visible = text != ""


# --- the screen -------------------------------------------------------------

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background()
	_add_grid()
	for i in Profile.PET_SLOTS:
		_add_pet_button(i)
	_add_continue()
	_add_menu()
	_add_message()
	_refresh_selection()


func _add_background() -> void:
	var content := _autoload("Content")
	if content == null or not content.has_image(BACKGROUND_ID):
		return
	var texture: Texture2D = content.texture(BACKGROUND_ID)
	if texture == null:
		return
	var back := TextureRect.new()
	back.name = "Background"
	back.texture = texture
	back.size = SCREEN_SIZE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# `SCREENBACK` is the screens' tiling backdrop; the pet grid sits on it at 1:1.
	back.stretch_mode = TextureRect.STRETCH_TILE
	back.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


## The ctor's scroll panel (`+0xFC`, `FUN_0045DA10`): the six recovered rows are 94 + 6*83 = 592 px
## tall, so the last rows sit below the 480-px screen and the panel scrolls to them. The port uses a
## clipped Control with the wheel moving it, so no engine scrollbar art is invented. The clip stops
## one row above the id-99 button (`0xFA`), because rows 2-5 would otherwise draw through its text;
## the panel's own rect is not in the note, so that cut is the port's (Q-0063).
func _add_grid() -> void:
	_viewport = Control.new()
	_viewport.name = "Viewport"
	_viewport.position = Vector2.ZERO
	_viewport.size = Vector2(SCREEN_SIZE.x, CONTINUE_RECT.position.y)
	_viewport.clip_contents = true
	_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_viewport)
	_grid = Control.new()
	_grid.name = "Grid"
	_grid.size = Vector2(SCREEN_SIZE.x, content_height())
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_grid)


## Height of the whole grid, in grid coordinates.
static func content_height() -> float:
	return GRID_ORIGIN.y + float(ROW_COUNTS.size()) * ROW_PITCH


func scroll_y() -> float:
	return _scroll_y


## Wheel scrolling, clamped to the grid. One notch is one row.
func scroll_by(amount: float) -> void:
	if _grid == null:
		return
	_scroll_y = clampf(_scroll_y + amount, 0.0, maxf(content_height() - _viewport.size.y, 0.0))
	_grid.position.y = -_scroll_y


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not (event as InputEventMouseButton).pressed:
		return
	match (event as InputEventMouseButton).button_index:
		MOUSE_BUTTON_WHEEL_DOWN:
			scroll_by(ROW_PITCH)
		MOUSE_BUTTON_WHEEL_UP:
			scroll_by(-ROW_PITCH)


func _add_pet_button(index: int) -> void:
	var cell := Control.new()
	cell.name = "Pet%d" % index
	cell.position = grid_rect(index).position
	cell.size = CELL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.visible = is_available(index)
	if _grid == null:
		return
	_grid.add_child(cell)
	_cells[index] = cell

	# `PETBUTTONHOLE` and `PETBUTTONREFLECT` resolve to the sheets' alpha companions
	# (`petbuttonhole_.png`, `petbuttonreflect_.png`): they are masks, not colour art, so they are not
	# drawn as layers - drawing them just keyed to nothing (Q-0063).
	var dome := _add_layer(cell, "Button", BUTTON_ID, 0)
	if dome != null:
		_domes[index] = dome
	var portrait := _pet_texture(index)
	if portrait != null:
		var art := TextureRect.new()
		art.name = "Art"
		art.texture = portrait
		art.size = PORTRAIT_SIZE
		art.position = (CELL - PORTRAIT_SIZE) * 0.5
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(art)
	var ring := _add_layer(cell, "Ring", RING_ID)
	if ring != null:
		ring.visible = false
		_rings[index] = ring

	var button := Button.new()
	button.name = "Hit"
	button.position = Vector2.ZERO
	button.size = CELL
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.tooltip_text = Progression.pet_name(index)
	button.pressed.connect(_on_pet_pressed.bind(index))
	cell.add_child(button)


func _on_pet_pressed(index: int) -> void:
	toggle(index)


## One composed sheet cell as a TextureRect at the button's own origin.
func _add_layer(parent: Control, node_name: String, id: String, frame: int = 0) -> TextureRect:
	var texture := _cell_texture(id, frame)
	if texture == null:
		return null
	var layer := TextureRect.new()
	layer.name = node_name
	layer.texture = texture
	layer.position = Vector2.ZERO
	layer.size = CELL
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


## A pet's own first cell, the art the tank spawns (`Pet.IMAGES`).
func _pet_texture(index: int) -> Texture2D:
	var id := String(Pet.IMAGES.get(index, ""))
	if id == "":
		return null
	return _cell_texture(id, 0)


## One cell of a shipped sheet with its alpha companion. Most sheets are masked art (their
## transparency lives in `assets_raw/masks/`); a sheet without a mask keeps the colour-key path.
func _cell_texture(id: String, frame: int) -> Texture2D:
	var content := _autoload("Content")
	if content == null or not content.has_image(id):
		return null
	var texture: Texture2D = null
	var frames: SpriteFrames = content.sprite_frames(id)
	if frames != null and frames.get_frame_count("default") > 0:
		texture = frames.get_frame_texture("default",
			clampi(frame, 0, frames.get_frame_count("default") - 1))
	else:
		texture = content.texture(id)
	if texture == null:
		return null
	var res: ImageRes = content.image(id)
	var mask := HatchScreen.mask_for(res.path) if res != null else null
	var composed := HatchScreen.masked_cell(texture, mask)
	return composed if composed != null else SpriteKey.keyed(texture)


func _add_continue() -> void:
	var button := Button.new()
	button.name = "Continue"
	button.text = CONTINUE_LABEL
	button.position = CONTINUE_RECT.position
	button.size = CONTINUE_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", CONTINUE_COLOR)
	button.add_theme_color_override("font_hover_color", CONTINUE_COLOR)
	button.add_theme_color_override("font_pressed_color", CONTINUE_COLOR)
	UiFont.apply(button, UiFont.LABEL_FONT)
	button.pressed.connect(request_confirm)
	add_child(button)


func _add_menu() -> void:
	var button := Button.new()
	button.name = "Menu"
	button.text = MENU_LABEL
	button.position = MENU_RECT.position
	button.size = MENU_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", CONTINUE_COLOR)
	UiFont.apply(button, UiFont.SELECTOR_SMALL_FONT)
	button.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(button)


## The "Select More Pets?" notice. The binary opens a message box; the port shows the same two
## strings in the screen and keeps the pending answer one click away (see `request_confirm`).
func _add_message() -> void:
	_message = Label.new()
	_message.name = "Ask"
	_message.position = Vector2(100.0, 300.0)
	_message.size = Vector2(440.0, 40.0)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	_message.visible = false
	UiFont.apply(_message, UiFont.TINY_FONT)
	add_child(_message)


## A selected pet draws the bright gold face **and** its ring; everything else keeps the plain gold
## face, dimmed. `dome_frame`/`button_tint` are the single source of the pair.
static func dome_frame(selected: bool) -> int:
	return SELECTED_FRAME if selected else NORMAL_FRAME


static func button_tint(selected: bool) -> Color:
	return SELECTED_TINT if selected else UNSELECTED_TINT


## The composed `PETBUTTON` face for a state, kept so a click swaps a texture instead of redrawing it.
## A coloured face is a flat rectangle on its sheet, so it is clipped to the gold dome's silhouette
## (`NORMAL_FRAME`'s keyed alpha) - otherwise its corners spill across the button as a square.
func _dome_texture(frame: int) -> Texture2D:
	if _dome_textures.has(frame):
		return _dome_textures[frame]
	var face := _cell_texture(BUTTON_ID, frame)
	if face != null and frame != NORMAL_FRAME:
		face = _clip_to_dome(face)
	_dome_textures[frame] = face
	return face


func _clip_to_dome(face: Texture2D) -> Texture2D:
	var dome := _cell_texture(BUTTON_ID, NORMAL_FRAME)
	if dome == null:
		return face
	var silhouette := dome.get_image()
	var image := face.get_image()
	if silhouette == null or image == null or image.get_size() != silhouette.get_size():
		return face
	image = image.duplicate() as Image
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(pixel.r, pixel.g, pixel.b,
				pixel.a * silhouette.get_pixel(x, y).a))
	return ImageTexture.create_from_image(image)


func _refresh_selection() -> void:
	if profile == null:
		return
	for index in _rings:
		var selected := int(profile.selected_pets[index]) != 0
		(_rings[index] as TextureRect).visible = selected
		if _domes.has(index):
			var dome := _domes[index] as TextureRect
			var face := _dome_texture(dome_frame(selected))
			if face != null:
				dome.texture = face
			dome.modulate = button_tint(selected)
