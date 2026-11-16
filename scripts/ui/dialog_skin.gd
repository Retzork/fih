class_name DialogSkin
extends RefCounted
## The base game's modal skin, shared by every port dialog built on it (`OptionsDialog`,
## `DebugDialog`).
##
## One owner for the art (P3.3): both shipped sheets are opaque and carry their alpha in the
## `masks/_<file>` companion, so every copy goes through `MaskAlpha.compose()`; the 9-slice margins
## and the three button frames are measured once here instead of per dialog.

const PANEL_IMAGE := "IMAGE_DIALOG"
const BUTTON_IMAGE := "IMAGE_DIALOGBUTTON"

## `Dialogue-panel.png` is 240x240; these margins keep the corner brackets, the title plaque and the
## side plates out of the stretched middle.
const PANEL_PATCH := Vector2i(32, 44)
## `DialogButton2.png` is a three-frame 96x33 strip (purple / hover blue / pressed dark blue).
const BUTTON_FRAME := Vector2(96.0, 33.0)
const TITLE_COLOR := Color8(0xFF, 0xD8, 0x20)


## A shipped sheet composed with its mask, or null when Content does not carry it.
static func masked(content: Node, image_id: String) -> Texture2D:
	if content == null or not content.has_image(image_id):
		return null
	return MaskAlpha.compose(content.texture(image_id))


## The brass panel: the masked 9-slice, or a flat copper block when Content is absent.
static func panel(rect: Rect2, content: Node) -> Control:
	var texture := masked(content, PANEL_IMAGE)
	var node: Control
	if texture != null:
		var nine := NinePatchRect.new()
		nine.texture = texture
		nine.patch_margin_left = PANEL_PATCH.x
		nine.patch_margin_right = PANEL_PATCH.x
		nine.patch_margin_top = PANEL_PATCH.y
		nine.patch_margin_bottom = PANEL_PATCH.y
		node = nine
	else:
		var flat := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color8(0xC0, 0x88, 0x38)
		style.border_color = Color8(0x60, 0x40, 0x10)
		style.set_border_width_all(4)
		flat.add_theme_stylebox_override("panel", style)
		node = flat
	node.name = "Panel"
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


## The title plaque's lettering, centred over the panel's top band.
static func title(text: String, panel_size: Vector2, at := Vector2(0.0, 14.0)) -> Label:
	var label := Label.new()
	label.name = "Title"
	label.text = text
	label.position = at
	label.size = Vector2(panel_size.x, 26.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(label, UiFont.SELECTOR_BIG_FONT)
	label.add_theme_color_override("font_color", TITLE_COLOR)
	label.add_theme_color_override("font_shadow_color", Color8(0x20, 0x10, 0x00))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


## A `DialogButton2` button at the requested rect. Every dialog row uses this, so the three frames,
## the white lettering and the pointing hand stay identical.
static func button(node_name: String, text: String, at: Vector2, size: Vector2,
		content: Node) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = at
	button.size = size
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UiFont.apply(button, UiFont.STORE_OUTLINE_FONT)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sheet := masked(content, BUTTON_IMAGE)
	if sheet != null:
		button.add_theme_stylebox_override("normal", _frame(sheet, 0))
		button.add_theme_stylebox_override("hover", _frame(sheet, 1))
		button.add_theme_stylebox_override("pressed", _frame(sheet, 2))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


## One 96x33 frame of the button strip, stretched to the button's rect.
static func _frame(sheet: Texture2D, frame: int) -> StyleBoxTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(BUTTON_FRAME.x * frame, 0.0, BUTTON_FRAME.x, BUTTON_FRAME.y)
	var style := StyleBoxTexture.new()
	style.texture = atlas
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style
