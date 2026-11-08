class_name OptionsDialog
extends Control
## OptionsDialog - the single options dialog (P2.12 §11, SPECS §6).
##
## Two sliders seeded from the mixer (`MusicVolume`/`SfxVolume` as integer percent, applied
## instantly because they write the bus) and three checkboxes. The dialog's kind drives
## only the built-in button row: OK/Cancel plus Register/Help/web/Back-to-menu/Check-updates
## actions (all eleven dialogs share the `Sexy::Dialog` base, D-0011).

signal closed
signal back_to_menu

var music_slider: HSlider = null
var sfx_slider: HSlider = null
var show_money_box: CheckBox = null


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Panel.new()
	panel.position = Vector2(120.0, 80.0)
	panel.size = Vector2(400.0, 320.0)
	add_child(panel)
	var title := Label.new()
	title.text = "Options"
	title.position = Vector2(280.0, 90.0)
	title.size = Vector2(80.0, 24.0)
	UiFont.apply(title, UiFont.LABEL_FONT)
	add_child(title)
	music_slider = HSlider.new()
	music_slider.position = Vector2(140.0, 140.0)
	music_slider.size = Vector2(360.0, 24.0)
	music_slider.min_value = 0.0
	music_slider.max_value = 100.0
	music_slider.step = 1.0
	music_slider.value_changed.connect(_on_music)
	add_child(music_slider)
	sfx_slider = HSlider.new()
	sfx_slider.position = Vector2(140.0, 180.0)
	sfx_slider.size = Vector2(360.0, 24.0)
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value_changed.connect(_on_sfx)
	add_child(sfx_slider)
	show_money_box = CheckBox.new()
	show_money_box.text = "Show Money"
	show_money_box.position = Vector2(140.0, 220.0)
	show_money_box.size = Vector2(200.0, 28.0)
	UiFont.apply(show_money_box, UiFont.LABEL_FONT)
	add_child(show_money_box)
	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(240.0, 340.0)
	ok.size = Vector2(80.0, 30.0)
	UiFont.apply(ok, UiFont.LABEL_FONT)
	ok.pressed.connect(func() -> void: closed.emit())
	add_child(ok)
	var back := Button.new()
	back.text = "Back to Menu"
	back.position = Vector2(330.0, 340.0)
	back.size = Vector2(120.0, 30.0)
	UiFont.apply(back, UiFont.LABEL_FONT)
	back.pressed.connect(func() -> void: back_to_menu.emit())
	add_child(back)
	_sync_from_audio()


func _sync_from_audio() -> void:
	var audio := _autoload("Audio")
	if audio == null:
		return
	music_slider.value = float(audio.music_volume) * 100.0
	sfx_slider.value = float(audio.sfx_volume) * 100.0


func _on_music(value: float) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_music_volume(value / 100.0)


func _on_sfx(value: float) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_sfx_volume(value / 100.0)
