class_name HallScreen
extends Control
## HallScreen - the 4-tab hall of fame (P2.12 §10, SPECS §6).
##
## Tabs over the profile's records (high scores, challenge records, story mask).
## The profile fields exist; the recording side is P4.6 remainder, so a tab with no
## record reads "No entries yet" rather than inventing scores.

signal closed

const TABS := ["Time Trial", "Challenge", "Adventure", "Virtual Tank"]

var profile: Profile = null
var tab := 0

var _label: Label = null
var _tab_buttons: Array[Button] = []


func setup(source: Profile) -> void:
	profile = source


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.position = Vector2(60.0 + i * 130.0, 80.0)
		b.size = Vector2(120.0, 30.0)
		b.pressed.connect(func() -> void: tab = i; _refresh())
		UiFont.apply(b, UiFont.LABEL_FONT)
		add_child(b)
		_tab_buttons.append(b)
	_label = Label.new()
	_label.position = Vector2(80.0, 140.0)
	_label.size = Vector2(480.0, 120.0)
	UiFont.apply(_label, UiFont.LABEL_FONT)
	add_child(_label)
	var back := Button.new()
	back.text = "Back"
	back.position = Vector2(270.0, 320.0)
	back.size = Vector2(100.0, 30.0)
	UiFont.apply(back, UiFont.LABEL_FONT)
	back.pressed.connect(func() -> void: closed.emit())
	add_child(back)
	_refresh()


func _refresh() -> void:
	if _label == null or profile == null:
		return
	match tab:
		0:
			_label.text = "Time Trial: best money is not recorded yet."
		1:
			var beaten := 0
			for flag in profile.challenge_unlocks:
				if flag != 0:
					beaten += 1
			_label.text = "Challenge: %d tanks beaten." % beaten
		2:
			_label.text = "Adventure: tank %d level %d, %d shells." % [
				profile.tank, profile.level, profile.shells]
		3:
			_label.text = "Virtual Tank: a custom tank, not a score."
		_:
			_label.text = ""
