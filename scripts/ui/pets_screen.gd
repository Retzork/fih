class_name PetsScreen
extends Control
## PetsScreen - the 24-button pet selection (P2.12 §5 / EV-0136, SPECS §6).
##
## The pending selection lives at `profile+0x5A` (24 bytes, cleared on every open
## outside Virtual Tank). Confirm writes it back and the tank spawns it (branch B).
## Virtual Tank diffs against the open-time snapshot; the port takes the same buttons
## with the profile's owned flags as the gate.

signal confirm_pressed(selected: Array[int])

var profile: Profile = null
var _buttons: Array[CheckButton] = []


func setup(source: Profile) -> void:
	profile = source
	if profile != null:
		profile.selected_pets.fill(0)


func selected() -> Array[int]:
	var out: Array[int] = []
	for i in _buttons.size():
		if _buttons[i].button_pressed:
			out.append(i)
	return out


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "Choose your pets"
	title.position = Vector2(220.0, 20.0)
	title.size = Vector2(200.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(title, UiFont.LABEL_FONT)
	add_child(title)
	for i in Profile.PET_SLOTS:
		var b := CheckButton.new()
		b.text = Progression.PET_NAMES[i]
		b.position = Vector2(40.0 + (i % 8) * 140.0, 60.0 + (i / 8) * 40.0)
		b.size = Vector2(130.0, 30.0)
		b.disabled = profile != null and not profile.owns_pet(i)
		if profile != null and profile.selected_pets[i] != 0:
			b.button_pressed = true
		UiFont.apply(b, UiFont.TINY_FONT)
		add_child(b)
		_buttons.append(b)
	var confirm := Button.new()
	confirm.text = "Confirm"
	confirm.position = Vector2(270.0, 220.0)
	confirm.size = Vector2(100.0, 30.0)
	UiFont.apply(confirm, UiFont.LABEL_FONT)
	confirm.pressed.connect(_on_confirm)
	add_child(confirm)


func _on_confirm() -> void:
	var chosen := selected()
	if profile != null:
		profile.selected_pets.fill(0)
		for index in chosen:
			if index >= 0 and index < 24:
				profile.selected_pets[index] = 1
	confirm_pressed.emit(chosen)


func press_confirm() -> void:
	_on_confirm()
