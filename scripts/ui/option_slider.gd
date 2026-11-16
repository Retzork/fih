class_name OptionSlider
extends Control
## One horizontal volume slider in the game's own art: the 156x17 `SLIDERTRACK` under the 33x32
## `SLIDERWIDGET` thumb. The base `OptionsDialog` builds its two sliders with `FUN_0046F360`
## (P2.12 §11.3); the engine's HSlider stretches its theme track to the control height, so this
## small Control draws the two textures at their native sizes instead.
##
## `value` is the mixer percentage (0..100). The dialog seeds it before connecting
## `value_changed`, and both mouse drags and Left/Right adjust it. It resolves `Content` lazily
## and falls back to flat colour blocks in the `--script` suites, where no autoloads exist.

signal value_changed(value: float)

const TRACK_ID := "IMAGE_SLIDERTRACK"
const THUMB_ID := "IMAGE_SLIDERTHUMB"
const TRACK_SIZE := Vector2(156.0, 17.0)
const THUMB_SIZE := Vector2(33.0, 32.0)
const STEP := 5.0

var _value := 0.0
var value: float:
	get:
		return _value
	set(new_value):
		new_value = clampf(new_value, 0.0, 100.0)
		if is_equal_approx(new_value, _value):
			return
		_value = new_value
		_update_thumb()
		if _ready_done:
			value_changed.emit(_value)

var _ready_done := false
var _dragging := false
var _track: Control = null
var _thumb: Control = null


func _ready() -> void:
	custom_minimum_size = Vector2(TRACK_SIZE.x, THUMB_SIZE.y)
	if size.x <= 0.0:
		size = Vector2(TRACK_SIZE.x, THUMB_SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_track = _add_part("Track", TRACK_ID, TRACK_SIZE, Vector2(0.0, (THUMB_SIZE.y - TRACK_SIZE.y) * 0.5))
	_thumb = _add_part("Thumb", THUMB_ID, THUMB_SIZE, Vector2.ZERO)
	_update_thumb()
	_ready_done = true


## A texture part at its native size, or a flat colour block when Content is absent.
func _add_part(part_name: String, image_id: String, part_size: Vector2, at: Vector2) -> Control:
	var part: Control
	var texture := _texture(image_id)
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		part = rect
	else:
		var block := ColorRect.new()
		block.color = Color8(0xC0, 0x88, 0x38) if part_name == "Track" else Color8(0x28, 0x54, 0xC8)
		part = block
	part.name = part_name
	part.position = at
	part.size = part_size
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(part)
	return part


func _texture(image_id: String) -> Texture2D:
	if not is_inside_tree():
		return null
	var content := get_node_or_null("/root/Content")
	if content == null or not content.has_image(image_id):
		return null
	# The track and thumb ship as opaque masked sheets (P3.3); without the mask their brown
	# background would draw as a tile over the panel.
	return MaskAlpha.compose(content.texture(image_id))


## Keep the thumb inside the track: 0 puts its left edge at the track start, 100 its right edge at
## the track end.
func _update_thumb() -> void:
	if _thumb == null:
		return
	var travel := maxf(size.x - THUMB_SIZE.x, 0.0)
	_thumb.position = Vector2(roundf((_value / 100.0) * travel), 0.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			grab_focus()
			_set_from_x(event.position.x)
		else:
			_dragging = false
		accept_event()
		return
	if event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			value -= STEP
			accept_event()
		elif event.keycode == KEY_RIGHT:
			value += STEP
			accept_event()


## The pointer drives the thumb's centre, so a click on the thumb does not jump its value.
func _set_from_x(x: float) -> void:
	var travel := maxf(size.x - THUMB_SIZE.x, 1.0)
	var ratio := clampf((x - THUMB_SIZE.x * 0.5) / travel, 0.0, 1.0)
	value = ratio * 100.0
