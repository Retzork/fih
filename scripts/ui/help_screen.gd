class_name HelpScreen
extends Control
## HelpScreen - the 8-page help/tutor screen (P2.12 §10, SPECS §6).
##
## The same screen serves help and the tutorial: the tutorial hides "Click Here To
## Continue" and relabels Menu to "Back to Game". The page counter is at `+0xA4`.

signal closed

const PAGES := [
	"Click to drop food. Fish eat to grow.",
	"Grown fish drop coins. Click coins for money.",
	"Buy more fish and upgrades in the store.",
	"Aliens eat your fish. Shoot them to defend.",
	"Watch the wave clock. One wave at a time.",
	"Pet friends help collect coins and fight.",
	"Buy the egg pieces to finish the level.",
	"Each tank has five levels. Good luck!",
]
const NEXT_TEXT := "Next Page"
const CONTINUE_TEXT := "Click Here To Continue"
const MENU_TEXT := "Back to Main Menu"
const TUTORIAL_MENU_TEXT := "Back to Game"

var page := 0
var tutorial := false

var _label: Label = null
var _next: Button = null
var _menu: Button = null


func setup(tutorial_: bool = false) -> void:
	tutorial = tutorial_


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.position = Vector2(80.0, 120.0)
	_label.size = Vector2(480.0, 120.0)
	UiFont.apply(_label, UiFont.LABEL_FONT)
	add_child(_label)
	_next = Button.new()
	_next.position = Vector2(270.0, 300.0)
	_next.size = Vector2(100.0, 30.0)
	UiFont.apply(_next, UiFont.LABEL_FONT)
	_next.pressed.connect(_on_next)
	add_child(_next)
	_menu = Button.new()
	_menu.position = Vector2(250.0, 360.0)
	_menu.size = Vector2(140.0, 30.0)
	UiFont.apply(_menu, UiFont.LABEL_FONT)
	_menu.pressed.connect(func() -> void: closed.emit())
	add_child(_menu)
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = "Page %d/8: %s" % [page + 1, String(PAGES[page])]
	_next.text = CONTINUE_TEXT if (tutorial or page >= PAGES.size() - 1) else NEXT_TEXT
	_menu.text = TUTORIAL_MENU_TEXT if tutorial else MENU_TEXT


func _on_next() -> void:
	if page + 1 < PAGES.size():
		page += 1
		_refresh()
	else:
		closed.emit()
