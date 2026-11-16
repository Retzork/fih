extends Node
## Game - application state that outlives a level: the active mode, the profile, and the shared
## pause gates.
##
## Deliberately thin: this file owns *where the app is*, not what a level does. Level start, the
## store, progression and saves are P4.4-P4.12 and live in their own nodes; they read `mode` from
## here. See docs/ARCHITECTURE.md §4 and docs/SPECS.md §5.

## Mode is an input to level start, never derived (SPECS.md §5, P2.11/EV-0126).
enum Mode {
	ADVENTURE = 0,
	TIME_TRIAL = 1,
	UNUSED = 2,
	SANDBOX = 3,
	CHALLENGE = 4,
	VIRTUAL_TANK = 5,
}

## Tank save suffix per mode (P2.13/EV-0142: `userdata\%s%d.dat`).
const SAVE_SUFFIX := {
	Mode.ADVENTURE: "adv",
	Mode.TIME_TRIAL: "tim",
	Mode.SANDBOX: "snd",
	Mode.CHALLENGE: "sur",
	Mode.VIRTUAL_TANK: "sim",
}

signal mode_changed(mode: int)
## The Options "Show Money" checkbox changed; the in-tank wallet plate follows it.
signal show_money_changed(show: bool)

## Active mode. Written only by the main-menu buttons and the level-start dispatcher.
var mode: int = Mode.ADVENTURE

## The Adventure profile (P4.6): tank/level, Shells, owned pets and the menu gates. Levels read
## it through `Level.profile`, so a headless check can hand a Level its own without the autoload.
var profile := Profile.new()

## Shared pause gate - the original's `Tank+0x94`. Pets and alien actions read this; it is not a
## scene-tree pause, because the UI and screens keep updating while gameplay is held.
var gameplay_paused := false

## OptionsDialog's "Show Money" checkbox (P2.12 §11): the HUD money line toggles on it.
var show_money := true:
	set(value):
		if value == show_money:
			return
		show_money = value
		show_money_changed.emit(value)

## OptionsDialog's "Custom Cursors" checkbox. The base dialog carries the control (P2.12 §11.3,
## ids 7/8/9); the port has no custom-cursor layer reconstructed yet, so this is a stored
## preference only (port stub, D-0016).
var custom_cursors := false

## OptionsDialog's "Hardware Acceleration" checkbox. Godot picks its rendering driver at boot, so
## the port stores the choice but cannot switch it at runtime (port stub, D-0016).
var hardware_acceleration := false


func set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	# Virtual Tank plays no music, so the mode gate is honoured at the switch, not at level start.
	var audio := get_node_or_null("/root/Audio")
	if audio != null and silences_music():
		audio.stop_music()
	mode_changed.emit(mode)


## Save-file stem for the active mode, e.g. "adv3". P4.12 builds the path.
func save_stem(profile_slot: int) -> String:
	return "%s%d" % [SAVE_SUFFIX.get(mode, "adv"), profile_slot]


func is_adventure() -> bool:
	return mode == Mode.ADVENTURE


## Virtual Tank plays no music and runs its own init (SPECS.md §5, P2.14/EV-0148).
func silences_music() -> bool:
	return mode == Mode.VIRTUAL_TANK
