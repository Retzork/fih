class_name OptionCheck
extends Control
## One checkbox in the base Options panel: the 46x45 `Checkbutton`/`unCheckbutton` art plus its
## label, drawn at the offsets measured from the 640x480 reference (the label starts 39 px after
## the icon's left edge, inside the texture's transparent padding).
##
## A Godot `CheckBox` adds its theme stylebox content margins around the icon and text, which
## pushed "CUSTOM CURSORS" past the panel edge, so this small Control draws the two pieces itself.
## It still behaves like a toggle: a left click anywhere on the row flips `button_pressed` and
## emits `toggled`. `Content` is resolved lazily; the `--script` suites fall back to flat blocks.

signal toggled(pressed: bool)

const CHECKED_ID := "IMAGE_CHECKED"
const UNCHECKED_ID := "IMAGE_UNCHECKED"
const ICON_SIZE := Vector2(46.0, 45.0)
## Reference offset: icon left -> label left.
const TEXT_OFFSET := 39.0

## Text to draw; set before the node enters the tree.
var label_text := ""
## Row width; the label gets the rest after `TEXT_OFFSET`.
var row_width := 150.0
## Toggle state; writing it after the node is ready emits `toggled`.
var button_pressed := false:
	set(value):
		if value == button_pressed:
			return
		button_pressed = value
		_refresh()
		if _ready_done and not _silent:
			toggled.emit(button_pressed)

var _icon: Control = null
var _label: Label = null
var _checked_texture: Texture2D = null
var _unchecked_texture: Texture2D = null
var _ready_done := false
var _silent := false


func _ready() -> void:
	size = Vector2(row_width, ICON_SIZE.y)
	custom_minimum_size = size
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_checked_texture = _texture(CHECKED_ID)
	_unchecked_texture = _texture(UNCHECKED_ID)
	_build_icon()
	_build_label()
	_refresh()
	_ready_done = true


func _build_icon() -> void:
	if _checked_texture != null:
		_icon = TextureRect.new()
		_icon.texture = _checked_texture
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		var block := ColorRect.new()
		block.color = Color8(0x28, 0x54, 0xC8)
		_icon = block
	_icon.name = "Icon"
	_icon.position = Vector2.ZERO
	_icon.size = ICON_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)


func _build_label() -> void:
	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.position = Vector2(TEXT_OFFSET, 0.0)
	_label.size = Vector2(maxf(size.x - TEXT_OFFSET, 0.0), ICON_SIZE.y)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(_label, UiFont.STORE_OUTLINE_FONT)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_shadow_color", Color8(0x20, 0x10, 0x00))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)


## Seed the state without emitting, mirroring `BaseButton.set_pressed_no_signal()`.
func set_pressed_no_signal(pressed: bool) -> void:
	_silent = true
	button_pressed = pressed
	_silent = false
	_refresh()


func _refresh() -> void:
	if _icon == null:
		return
	var texture := _checked_texture if button_pressed else _unchecked_texture
	if _icon is TextureRect:
		(_icon as TextureRect).texture = texture
		_icon.visible = texture != null
	elif _icon is ColorRect:
		_icon.visible = true


func _texture(image_id: String) -> Texture2D:
	if not is_inside_tree():
		return null
	var content := get_node_or_null("/root/Content")
	if content == null or not content.has_image(image_id):
		return null
	# `Checkbutton`/`unCheckbutton` are opaque masked sheets (P3.3): compose the alpha companion or
	# the brown square around the circle draws over the brass panel.
	return MaskAlpha.compose(content.texture(image_id))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		button_pressed = not button_pressed
		accept_event()
