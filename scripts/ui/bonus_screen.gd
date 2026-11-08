class_name BonusScreen
extends Control
## BonusScreen - the tank-complete bonus card (P2.6 §4/§10.6, SPECS §6).
##
## The payout is the recovered switch: Adventure non-tank-5 -> bonus shells, tank 5 ->
## `clamp(max(1,counter-1)*5000, 0, 25000)`, Time Trial -> `money*5/100`, Challenge ->
## 2000/5000/10000/20000 by tank. Continue branches by the `manager+0x738` byte in the
## original; the port continues to the next level.

signal continue_pressed

var payout := 0
var tank_no := 1
var mode := 0


static func payout_for(tank_no: int, mode: int, money: int, counter: int, bonus_shells: int) -> int:
	if mode == 1:
		return int(money * 5 / 100)
	if mode == 4:
		return int({1: 2000, 2: 5000, 3: 10000, 4: 20000}.get(tank_no, 0))
	if mode == 0 and tank_no == 5:
		return clampi(maxi(1, counter - 1) * 5000, 0, 25000)
	return bonus_shells


func setup(tank_: int, mode_: int, payout_: int) -> void:
	tank_no = tank_
	mode = mode_
	payout = payout_


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "BONUS!"
	title.position = Vector2(220.0, 160.0)
	title.size = Vector2(200.0, 30.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(title, UiFont.LABEL_FONT)
	add_child(title)
	var card := Label.new()
	card.text = str(payout)
	card.position = Vector2(220.0, 200.0)
	card.size = Vector2(200.0, 30.0)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.apply(card, UiFont.LABEL_FONT)
	add_child(card)
	var go := Button.new()
	go.text = "Continue"
	go.position = Vector2(270.0, 250.0)
	go.size = Vector2(100.0, 30.0)
	UiFont.apply(go, UiFont.LABEL_FONT)
	go.pressed.connect(func() -> void: continue_pressed.emit())
	add_child(go)


func press_continue() -> void:
	continue_pressed.emit()
