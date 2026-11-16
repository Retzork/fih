class_name HatchScreen
extends Control
## HatchScreen - the awarded-pet card (P2.6 §1.2/§10.4, SPECS §6).
##
## The screen is the recovered 640x480 `HATCHSCREEN` incubator (P2.12 §10.2): the pet display panel
## at the `+0x90` image widget's rect, the `HATCHANIMATION` egg-crack strip as it hatches, the pet's
## own sheet once the crack plays out, "Please Wait..." on the art's purple plate at the id-99 rect
## and "Menu" at the id-100 rect.
##
## Completion grants the pet and advances the profile; this screen only displays the award. Tank 4
## level 5 shows card 999 ("Evil Alien Mastermind") with no grant. Continue -> PetsScreen (the
## selection), which `Main` mounts next.

signal continue_pressed
## The recovered "Menu" button (id 100). In the original it leaves the hatch flow for the main menu
## (Virtual Tank goes back to the tank instead - that mode branch is not wired in the port).
signal menu_pressed

const SCREEN_SIZE := Vector2(640.0, 480.0)
const BACKGROUND_ID := "IMAGE_HATCHSCREEN"
const CRACK_ID := "IMAGE_HATCHANIMATION"
const CRACK_CELL := Vector2(57.0, 60.0)
const CRACK_FRAMES := 3
const PET_CELL := Vector2(80.0, 80.0)

## `+0x90`: the image widget that shows the hatching pet.
const PANEL_RECT := Rect2(190.0, 220.0, 258.0, 200.0)
## id 99, the plate the art already draws: rect (0xBA, 0x1BD, 0x108).
const CONTINUE_RECT := Rect2(186.0, 445.0, 264.0, 30.0)
## id 100: rect (0x20D, 4, 0x50).
const MENU_RECT := Rect2(525.0, 4.0, 80.0, 26.0)
const CONTINUE_TEXT := "Please Wait..."
const MENU_TEXT := "Menu"
## The id-99 per-character fill `0xFF,0xF0,0`.
const CONTINUE_COLOR := Color(1.0, 240.0 / 255.0, 0.0)
## Port clock for the crack: the strip carries no `framedelay`, so the three cells share one hold
## (Q-0060 records the timing as the port's).
const CRACK_SECONDS := 0.3

var pet_index := 0

var _crack: TextureRect = null
var _crack_textures: Array[Texture2D] = []
var _pet: TextureRect = null
var _elapsed := 0.0


func setup(index: int) -> void:
	pet_index = index


func card_name() -> String:
	return Progression.pet_name(pet_index)


## The crack cell to draw at `elapsed` seconds, clamped to the strip's last cell.
static func crack_frame(elapsed: float) -> int:
	return clampi(int(elapsed / CRACK_SECONDS), 0, CRACK_FRAMES - 1)


## Whether the pet has replaced the crack: the whole strip has played.
static func hatched(elapsed: float) -> bool:
	return elapsed >= CRACK_SECONDS * CRACK_FRAMES


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background()
	_add_crack()
	_add_pet()
	_add_continue()
	_add_menu()


func _process(delta: float) -> void:
	if hatched(_elapsed):
		return
	_elapsed += delta
	if _crack != null:
		_crack.visible = not hatched(_elapsed)
		if _crack.visible:
			_set_crack_frame(crack_frame(_elapsed))
	if _pet != null and hatched(_elapsed):
		_pet.visible = true


## The pet's own sheet, first cell - the same art the tank spawns.
func _add_pet() -> void:
	var content := _autoload("Content")
	if content == null:
		return
	var id := String(Pet.IMAGES.get(pet_index, ""))
	if id == "" or not content.has_image(id):
		return
	var frames: SpriteFrames = content.sprite_frames(id)
	if frames == null or frames.get_frame_count("default") == 0:
		return
	var texture := frames.get_frame_texture("default", 0)
	if texture == null:
		return
	# The pet sheets are masked art as well (P3.3): their black background is only opaque because
	# the alpha lives in `assets_raw/masks/`. `MaskAlpha` uses the mask's luminance, so it also
	# works for sheets keyed on a colour (`HATCHANIMATION`'s brown field); the cell is composed on
	# its own so the whole 800x240 sheet is never walked. Brinkley has no mask, so he keeps the
	# colour-key path.
	var res: ImageRes = content.image(id)
	var composed := masked_cell(texture, mask_for(res.path) if res != null else null)
	_pet = TextureRect.new()
	_pet.name = "Pet"
	_pet.texture = composed if composed != null else SpriteKey.keyed(texture)
	_pet.size = PET_CELL
	_pet.position = PANEL_RECT.position + (PANEL_RECT.size - PET_CELL) * 0.5
	_pet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pet.visible = false
	add_child(_pet)


func _add_crack() -> void:
	var content := _autoload("Content")
	if content == null or not content.has_image(CRACK_ID):
		return
	# `HATCHANIMATION` is a 3-cell strip, so its `texture` is only the first cell. Use the
	# `SpriteFrames` sequence (framemap already applied) or the later cells would be cut out of empty
	# space.
	var frames: SpriteFrames = content.sprite_frames(CRACK_ID)
	if frames == null or frames.get_frame_count("default") == 0:
		return
	# The cells sit on a brown field, so black colour-keying leaves a box: compose each cell with
	# the sheet's alpha companion instead (P3.3).
	var res: ImageRes = content.image(CRACK_ID)
	var mask := mask_for(res.path) if res != null else null
	_crack_textures.clear()
	for index in frames.get_frame_count("default"):
		var frame := frames.get_frame_texture("default", index)
		if frame == null:
			continue
		var composed := masked_cell(frame, mask)
		_crack_textures.append(composed if composed != null else SpriteKey.keyed(frame))
	if _crack_textures.is_empty():
		return
	_crack = TextureRect.new()
	_crack.name = "EggCrack"
	_crack.texture = _crack_textures[0]
	_crack.size = CRACK_CELL
	_crack.position = PANEL_RECT.position + (PANEL_RECT.size - CRACK_CELL) * 0.5
	_crack.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_crack.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crack)
	_set_crack_frame(0)


## The strip's cells are pre-composed at load, so the frame is a direct texture swap.
func _set_crack_frame(index: int) -> void:
	if _crack == null or _crack_textures.is_empty():
		return
	_crack.texture = _crack_textures[clampi(index, 0, _crack_textures.size() - 1)]


## One cell of a masked sheet (P3.3): `texture.get_image()` is the cell itself, even for the
## `AtlasTexture` frames of an animated sheet, while the mask holds the whole strip. Compose just
## the overlapping rectangle and hand back a standalone texture. Null when the sheet has no mask.
static func masked_cell(texture: Texture2D, mask: Image) -> Texture2D:
	if texture == null or mask == null:
		return null
	var cell := texture.get_image()
	if cell == null:
		return null
	var region := Rect2i(Vector2i.ZERO, cell.get_size())
	if texture is AtlasTexture:
		region = Rect2i((texture as AtlasTexture).region)
	if region.position.x < 0 or region.position.y < 0:
		return null
	if region.end.x > mask.get_width() or region.end.y > mask.get_height():
		return null
	var composed := MaskAlpha.apply(cell, mask.get_region(region))
	if composed == null:
		return null
	return ImageTexture.create_from_image(composed)


## The alpha companion for an `assets_raw` sheet (P3.3): `masks/_<file>` for most, `<stem>_` for
## the original suffix convention (`tailflop_.png`). Returns null when the sheet has none.
static func mask_for(image_path: String) -> Image:
	return MaskAlpha.mask_for(image_path)


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
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _add_continue() -> void:
	var button := Button.new()
	button.name = "PleaseWait"
	button.text = CONTINUE_TEXT
	button.position = CONTINUE_RECT.position
	button.size = CONTINUE_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", CONTINUE_COLOR)
	button.add_theme_color_override("font_hover_color", CONTINUE_COLOR)
	button.add_theme_color_override("font_pressed_color", CONTINUE_COLOR)
	UiFont.apply(button, UiFont.LABEL_FONT)
	button.pressed.connect(func() -> void: continue_pressed.emit())
	add_child(button)


func _add_menu() -> void:
	var button := Button.new()
	button.name = "Menu"
	button.text = MENU_TEXT
	button.position = MENU_RECT.position
	button.size = MENU_RECT.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", Color(1.0, 240.0 / 255.0, 0.0))
	UiFont.apply(button, UiFont.LABEL_FONT)
	button.pressed.connect(func() -> void: menu_pressed.emit())
	add_child(button)


## Resolve an autoload only when the screen is inside the scene tree; the `--script` suites build the
## screen standalone, where `/root/...` does not exist and the art is simply absent.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


## Test hook: the OK/continue button.
func press_ok() -> void:
	continue_pressed.emit()
