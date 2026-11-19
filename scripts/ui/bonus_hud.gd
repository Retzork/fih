class_name BonusHud
extends Control
## The bonus round's HUD (`FUN_0053EAF0`, EV-0069): "BONUS ROUND", "Collect as many shells as you
## can!", the round's shell total (`Tank+0x3F4`) and "Time Remaining: %d:%02d" from
## `Tank+0x3BC - Tank+0x3B0` while `Tank+0x2A4` is set.
##
## The recovered evidence gives the strings and the counter fields, not the widget rects or fonts -
## the original builds this HUD inside its own overlay - so the layout and the font choice are the
## port's (D-0051). `refresh()` is driven from the level's tick, like the hunger hint (D-0032): a
## frame without a tick does no work.

## The recovered strings (`§6.3`).
const TITLE_TEXT := "BONUS ROUND"
const SUBTITLE_TEXT := "Collect as many shells as you can!"

var _title: Label = null
var _subtitle: Label = null
var _shells: Label = null
var _time: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _add_label("Title", TITLE_TEXT, Vector2(0.0, 84.0), Vector2(640.0, 26.0),
		HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle = _add_label("Subtitle", SUBTITLE_TEXT, Vector2(0.0, 108.0), Vector2(640.0, 20.0),
		HORIZONTAL_ALIGNMENT_CENTER)
	_shells = _add_label("Shells", "0", Vector2(0.0, 138.0), Vector2(640.0, 22.0),
		HORIZONTAL_ALIGNMENT_CENTER)
	_time = _add_label("Time", "", Vector2(0.0, 164.0), Vector2(640.0, 20.0),
		HORIZONTAL_ALIGNMENT_CENTER)


func _add_label(node_name: String, text: String, at: Vector2, box: Vector2,
		align: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.size = box
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color8(0xAE, 0xF7, 0x62))
	label.add_theme_color_override("font_outline_color", Color8(0x00, 0x4A, 0x00))
	label.add_theme_constant_override("outline_size", 2)
	# `FONT_CONTINUUMBOLD14` is the shipped font that draws the bottom hunger hint in mixed case,
	# so the recovered sentence-case subtitle is not forced into caps (the HUD font is not
	# recovered - D-0051).
	UiFont.apply(label, UiFont.BOTTOM_HINT_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


## The visible state: the shells collected so far, the clock text while the round runs, and the
## waiting line before it starts (the HUD is up from the finalizer, like `FUN_0053EAF0`).
func show_state(shells: int, seconds_left: int, running: bool) -> void:
	if _shells == null:
		return
	_shells.text = str(shells)
	_time.text = BonusRound.time_text(seconds_left) if running else ""
