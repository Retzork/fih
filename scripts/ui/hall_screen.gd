class_name HallScreen
extends Control
## HallScreen - the 4-tab hall of fame (P2.12 §10, SPECS §6).
##
## Tabs over the profile's records (level elapsed times, challenge records, story mask). The level
## completion writes them (D-0053); a tab with no record still reads "No entries yet" rather than
## inventing scores.

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
	if _label == null:
		return
	_label.text = summary_text(profile, tab)


## The label text per tab, split out so the headless suites can pin it.
static func summary_text(source: Profile, which: int) -> String:
	if source == null:
		return ""
	match which:
		0:
			var fastest := source.fastest_level_time(Level.MODE_TIME_TRIAL)
			if fastest.is_empty():
				return "Time Trial: No entries yet."
			return "Time Trial: best %s on tank %d level %d." % [
				_clock(int(fastest["seconds"])), int(fastest["tank"]), int(fastest["level"])]
		1:
			var lines: Array[String] = []
			for tank_no in range(1, Profile.CHALLENGE_SLOTS):
				var record := source.challenge_record(tank_no)
				if record.is_empty():
					continue
				lines.append("Tank %d - %s (best %s, %d runs)" % [tank_no,
					_clock(int(record["seconds"])), _clock(int(record["best"])), int(record["runs"])])
			if lines.is_empty():
				var beaten := 0
				for flag in source.challenge_unlocks:
					if flag != 0:
						beaten += 1
				if beaten == 0:
					return "Challenge: No entries yet."
				return "Challenge: %d tanks beaten, no times recorded yet." % beaten
			return "Challenge:\n" + "\n".join(lines)
		2:
			# Mode 0 is Adventure; the record table is shared, the tab filters by mode (D-0053).
			var timed := 0
			for key in source.level_times:
				if String(key).begins_with("0:"):
					timed += 1
			var fastest := source.fastest_level_time(0)
			if fastest.is_empty():
				return "Adventure: No entries yet."
			return "Adventure: %d levels timed. Fastest %s on tank %d level %d." % [timed,
				_clock(int(fastest["seconds"])), int(fastest["tank"]), int(fastest["level"])]
		3:
			return "Virtual Tank: a custom tank, not a score."
		_:
			return ""


static func _clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
