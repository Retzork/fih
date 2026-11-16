class_name OptionsDialog
extends Control
## OptionsDialog - the base game's Options panel (P2.12 §11, D-0016).
##
## The shipped dialog is the brass `Dialogue-panel` with an "OPTIONS" title plaque, two sliders
## (Music / Sound FX), three checkboxes (Fullscreen / Custom Cursors / Hardware Acceleration) and
## Help/OK buttons (P2.12 §11.3: slider ids 5/6, checkbox ids 7/8/9, button ids 0-4). The Steam
## build hides Register, the web link and Check Updates through the manager flags, which is why the
## reference screenshot shows only Help and OK. In a live tank the same dialog also carries
## "MAIN MENU" (the `+0x18C` byte's visible state) and the port-only DEBUG entry.
##
## The debug controls live in their own `DebugDialog` (D-0017): the owner asked for them to stop
## sharing this panel, where the dark grid covered the base panel's bottom frame. Only the DEBUG
## button that opens it stays here, and only in-level.
##
## The dialog does not pause the tank itself; its owner (`Main` in-level, `GameSelector` on the
## menu) owns the pause and the leave path.

signal closed
signal back_to_menu
signal help_requested
signal debug_requested

const OptionSliderScript := preload("res://scripts/ui/option_slider.gd")
const OptionCheckScript := preload("res://scripts/ui/option_check.gd")

## The panel rects measured from the 640x480 reference screenshot. Menu mode is the visible base
## panel; in-level adds the MAIN MENU / DEBUG row, so the panel grows downward.
const PANEL_MENU_RECT := Rect2(154.0, 32.0, 328.0, 312.0)
const PANEL_LEVEL_RECT := Rect2(154.0, 14.0, 328.0, 384.0)

const BUTTON_SIZE := Vector2(288.0, 33.0)
const HALF_BUTTON_WIDTH := 140.0
## The first button row's y; each following row sits one button height (+5) lower.
const BUTTON_TOP := 221.0
const BUTTON_PITCH := 38.0

## True when the dialog is mounted over a live tank (`Main`). The base menu path leaves it false.
var in_level := false

var music_slider: Control = null
var sfx_slider: Control = null

## The brass art panel; every base control is positioned inside it, not on the full-rect dialog.
var panel: Control = null
var _panel_rect := PANEL_MENU_RECT


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_rect = PANEL_LEVEL_RECT if in_level else PANEL_MENU_RECT
	panel = DialogSkin.panel(_panel_rect, _autoload("Content"))
	add_child(panel)
	panel.add_child(DialogSkin.title("OPTIONS", Vector2(_panel_rect.size.x, 26.0)))
	_build_sliders()
	_build_checkboxes()
	_build_buttons()
	# OK is the dialog's default action; the focus style is empty, so this only helps the keyboard.
	var ok := control(&"OK") as Button
	if ok != null:
		ok.grab_focus()


# --- construction ------------------------------------------------------------

func _build_sliders() -> void:
	_add_label("MusicLabel", "MUSIC", Vector2(34.0, 61.0), Vector2(100.0, 20.0))
	_add_label("SoundLabel", "SOUND FX", Vector2(34.0, 94.0), Vector2(100.0, 20.0))

	var audio := _autoload("Audio")
	music_slider = OptionSliderScript.new()
	music_slider.name = "Music"
	music_slider.position = Vector2(144.0, 53.0)
	music_slider.size = Vector2(156.0, 32.0)
	if audio != null:
		music_slider.value = float(audio.music_volume) * 100.0
	music_slider.value_changed.connect(_on_music)
	panel.add_child(music_slider)

	sfx_slider = OptionSliderScript.new()
	sfx_slider.name = "SoundFX"
	sfx_slider.position = Vector2(144.0, 86.0)
	sfx_slider.size = Vector2(156.0, 32.0)
	if audio != null:
		sfx_slider.value = float(audio.sfx_volume) * 100.0
	sfx_slider.value_changed.connect(_on_sfx)
	panel.add_child(sfx_slider)


func _build_checkboxes() -> void:
	var game := _autoload("Game")
	var fullscreen := false
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		fullscreen = mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	var custom := game != null and bool(game.custom_cursors)
	var hardware := game != null and bool(game.hardware_acceleration)
	# One box per row (owner review 2026-11-16): side by side, "FULLSCREEN" ran into the second
	# box's icon because the 8 px outlined font is wider than the reference's label. The 46x45
	# `Checkbutton` texture is mostly transparent padding, so 34 px rows do not collide.
	_add_check("Fullscreen", "FULLSCREEN", Vector2(26.0, 112.0), 270.0, fullscreen, _on_fullscreen)
	_add_check("CustomCursors", "CUSTOM CURSORS", Vector2(26.0, 146.0), 270.0, custom,
		_on_custom_cursors)
	_add_check("HardwareAcceleration", "HARDWARE ACCELERATION", Vector2(26.0, 180.0), 270.0,
		hardware, _on_hardware)


func _build_buttons() -> void:
	_add_dialog_button("Help", "HELP", Vector2(18.0, BUTTON_TOP), BUTTON_SIZE, _on_help)
	_add_dialog_button("OK", "OK", Vector2(18.0, BUTTON_TOP + BUTTON_PITCH), BUTTON_SIZE, _on_ok)
	if not in_level:
		return
	# The leave path and the port-only debug entry share one row so the base panel stays compact.
	var row := BUTTON_TOP + BUTTON_PITCH * 2.0
	var half := Vector2(HALF_BUTTON_WIDTH, BUTTON_SIZE.y)
	_add_dialog_button("BackToMenu", "MAIN MENU", Vector2(18.0, row), half, _on_back)
	_add_dialog_button("Debug", "DEBUG", Vector2(18.0 + HALF_BUTTON_WIDTH + 8.0, row), half,
		_on_debug)


# --- widgets -----------------------------------------------------------------

func _add_label(node_name: String, text: String, at: Vector2, box_size: Vector2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.size = box_size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(label, UiFont.STORE_OUTLINE_FONT)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color8(0x20, 0x10, 0x00))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(label)
	return label


## `OptionCheck` draws the native 46x45 art and the 39 px label offset itself: a Godot CheckBox
## adds stylebox content margins around the icon, which pushed the labels past the panel.
func _add_check(node_name: String, text: String, at: Vector2, width: float, pressed: bool,
		callback: Callable) -> Control:
	var box := OptionCheckScript.new()
	box.name = node_name
	box.label_text = text
	box.row_width = width
	box.position = at
	box.set_pressed_no_signal(pressed)
	box.toggled.connect(callback)
	panel.add_child(box)
	return box


func _add_dialog_button(node_name: String, text: String, at: Vector2, box_size: Vector2,
		callback: Callable) -> Button:
	var button := DialogSkin.button(node_name, text, at, box_size, _autoload("Content"))
	button.pressed.connect(callback)
	panel.add_child(button)
	return button


# --- public helpers ----------------------------------------------------------

## Resolve a base control by name. The base widgets are positioned inside the art panel, so callers
## that only know the base names (`OK`, `Help`, `BackToMenu`, `Music`, ...) come through here.
func control(node_name: StringName) -> Control:
	if panel == null:
		return null
	return panel.get_node_or_null(NodePath(node_name)) as Control


## Set the Music slider from a percentage. The checks use this instead of reaching through the
## untyped Control (the slider is a preloaded script, not a global class, so no cache is needed).
func set_music_percent(percent: float) -> void:
	if music_slider != null:
		music_slider.set("value", percent)


## Set the Sound FX slider from a percentage.
func set_sfx_percent(percent: float) -> void:
	if sfx_slider != null:
		sfx_slider.set("value", percent)


# --- actions -----------------------------------------------------------------

## Escape is the same as OK: close the dialog and let its owner resume the game.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_ok()
		get_viewport().set_input_as_handled()


func _on_ok() -> void:
	_play_click()
	closed.emit()


func _on_back() -> void:
	_play_click()
	back_to_menu.emit()


func _on_help() -> void:
	_play_click()
	help_requested.emit()


## The port-only DEBUG entry: the owner (`Main`) swaps this dialog for a `DebugDialog`.
func _on_debug() -> void:
	_play_click()
	debug_requested.emit()


func _on_music(value: float) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_music_volume(value / 100.0)


func _on_sfx(value: float) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_sfx_volume(value / 100.0)


func _on_fullscreen(pressed: bool) -> void:
	_play_click()
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _on_custom_cursors(pressed: bool) -> void:
	_play_click()
	var game := _autoload("Game")
	if game != null:
		game.custom_cursors = pressed


func _on_hardware(pressed: bool) -> void:
	_play_click()
	var game := _autoload("Game")
	if game != null:
		game.hardware_acceleration = pressed


func _play_click() -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
