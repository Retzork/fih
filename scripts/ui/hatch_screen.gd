class_name HatchScreen
extends Control
## HatchScreen - the awarded-pet card (P2.6 §1.2/§10.4, SPECS §6).
##
## Completion grants the pet and advances the profile; this screen only displays the
## award. Tank 4 level 5 shows card 999 ("Evil Alien Mastermind") with no grant.
## OK -> PetsScreen (the selection), which `Main` mounts next.

signal continue_pressed

var pet_index := 0

const SCREEN_SIZE := Vector2(640.0, 480.0)


func setup(index: int) -> void:
	pet_index = index


func card_name() -> String:
	return Progression.pet_name(pet_index)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "You got a pet!"
	title.position = Vector2(220.0, 120.0)
	title.size = Vector2(200.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(title, UiFont.LABEL_FONT)
	add_child(title)
	var card := Label.new()
	card.text = card_name()
	card.position = Vector2(170.0, 170.0)
	card.size = Vector2(300.0, 40.0)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(card, UiFont.LABEL_FONT)
	add_child(card)
	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(270.0, 250.0)
	ok.size = Vector2(100.0, 30.0)
	UiFont.apply(ok, UiFont.LABEL_FONT)
	ok.pressed.connect(func() -> void: continue_pressed.emit())
	add_child(ok)


## Test hook: the OK button.
func press_ok() -> void:
	continue_pressed.emit()
