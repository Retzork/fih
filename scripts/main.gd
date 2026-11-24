extends Node2D
## Main - the boot scene. It owns almost nothing on purpose: it attaches the screen layer to the
## Screens autoload, drives the debug overlay (P2.1/EV-0035: `FPS: %d` per 1000 ms window) and mounts
## the P4.4 level once the content phases have finished.
##
## The overlay starts hidden (D-0030): its label sits in the tank screen's bottom row, exactly where
## the measured `Tank  1-1` name and the hunger hint are drawn (D-0028), and it covered both during
## play. F12 brings the counters back for a debugging session without touching the base HUD.
##
## Everything else is a screen (docs/ARCHITECTURE.md §3). Main also drives the P4.2 content load:
## Init is already done by the Content autoload, Register is pulled before the first menu, and the
## LoadingThread phase is pumped here a slice at a time until P4.5's loading screen takes the bar.

@onready var _screens_layer: CanvasLayer = $Screens
@onready var _info: Label = $Debug/Info

## The overlay's toggle. `Level` already owns F1..F10/S/P for its own debug aids, so the stats line
## takes the free F12 rather than sharing one of those.

var _level: Level = null
var _selector: GameSelector = null
## The in-tank settings dialog opened by MENU (D-0015), null while it is closed.
var _options_dialog: OptionsDialog = null
## The in-tank Help modal opened from Options, null while it is closed.
var _help_dialog: Control = null
## The port-only debug dialog opened from Options' DEBUG row (D-0017), null while it is closed.
var _debug_dialog: DebugDialog = null
## The "GAME OVER" card the level raises when its last fish dies (EV-0249), null while it is closed.
var _game_over_dialog: GameOverDialog = null
const STATS_KEY := KEY_F12

var _frames := 0
var _elapsed := 0.0
var _flow: Control = null
## A tank-final completion that still owes its bonus round (P2.6 §1.4): `{"tank", "level"}` while
## the Hatch/Pets cards are up and the live tank waits, empty otherwise.
var _pending_bonus: Dictionary = {}


## F12 shows or hides the FPS/tick line. It is hidden by default and costs nothing while hidden:
## `_process` keeps its one-second window but stops formatting the string.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == STATS_KEY:
		toggle_stats()
		get_viewport().set_input_as_handled()


## Flip the debug overlay's visibility; returns whether it is now showing.
func toggle_stats() -> bool:
	_info.visible = not _info.visible
	return _info.visible


func _ready() -> void:
	Screens.attach(_screens_layer)
	# Boot order (SPECS.md §2.2): Init is already resolved by the Content autoload's _ready(), which
	# runs before any scene. Register must be present before the first menu or dialog, and the bulk
	# of the assets loads behind the loading bar - P4.5 draws that bar, the debug overlay shows
	# progress until then.
	Content.ensure_phase(Content.Phase.REGISTER)
	Content.start_phase(Content.Phase.LOADING)
	# `SexyApp::Init` asks for the startup pair while the app is still booting (P2.14 §4.1), so the
	# theme plays under the loading screen instead of starting once the menu mounts.
	Audio.set_music_pair(Audio.PAIR_STARTUP)


## A menu choice: the level needs the LoadingThread images for its sprites, which are already in.
func _on_start_requested(mode: int) -> void:
	if _selector != null:
		_selector.queue_free()
		_selector = null
	if _level != null:
		return
	_level = Level.new()
	_level.name = "Level"
	_level.game_mode = mode
	add_child(_level)
	_level.setup(Sim, 4242)
	_level.profile = Game.profile
	_level.level_completed.connect(_on_level_completed)
	_level.defeated.connect(_on_defeated)
	_level.menu_requested.connect(_on_menu_requested)
	_level.skip_level_requested.connect(_on_level_skip)
	# P2.6 §1.1: the adventure's current tank and level, with that tank's store table and egg price.
	var start := Progression.resolve_start(Game.profile.tank, Game.profile.level)
	Game.profile.tank = int(start["tank"])
	Game.profile.level = int(start["level"])
	Game.profile.sessions_started += 1
	_level.start_level(Game.profile.tank, Game.profile.level)


## The tank MENU button (TankScreen id 99). The binary tears the tank screen down with
## `FUN_0054AED0()` and rebuilds the main menu with `FUN_00552100()` (EV-0189); the owner asked for
## the port's MENU to open the settings UI first instead (D-0015). OK/Escape closes the dialog and
## resumes the same tank; the dialog's "Back to Menu" runs the binary's leave-tank path below.
func _on_menu_requested() -> void:
	if _level == null or _options_dialog != null:
		return
	var dialog := OptionsDialog.new()
	dialog.name = "OptionsDialog"
	dialog.in_level = true
	dialog.closed.connect(_close_options)
	dialog.back_to_menu.connect(_leave_tank)
	dialog.debug_requested.connect(_on_options_debug)
	dialog.help_requested.connect(_on_options_help)
	if not Screens.open_dialog(dialog):
		dialog.queue_free()
		return
	_options_dialog = dialog
	# A held fire button must not keep aiming behind the modal.
	_level.holding_fire = false
	Game.gameplay_paused = true


## Options' DEBUG row: swap the settings dialog for the port-only debug dialog (D-0017). The
## Screens autoload owns a single modal slot, so Options closes first - the same handover the Help
## path does - and the tank stays paused.
func _on_options_debug() -> void:
	if _level == null or _options_dialog == null or _debug_dialog != null:
		return
	Screens.close_dialog()
	_options_dialog = null
	var dialog := DebugDialog.new()
	dialog.name = "DebugDialog"
	dialog.closed.connect(_close_debug)
	dialog.action_requested.connect(_on_debug_action)
	if not Screens.open_dialog(dialog):
		dialog.queue_free()
		return
	_debug_dialog = dialog


## A debug button: run the port-only action on the live level. `Level.debug_action()` is the same
## dispatcher the F2..F10 keys use (D-0014); the tank stays paused while it runs.
func _on_debug_action(action: StringName) -> void:
	if _level == null:
		return
	_level.debug_action(action)


## Close the debug dialog and go back to Options, so the owner returns to the settings rather than
## to a resumed tank they did not ask for (D-0017).
func _close_debug() -> void:
	if _debug_dialog == null:
		return
	Screens.close_dialog()
	_debug_dialog = null
	_on_menu_requested()


## Options' Help button: replace the dialog with the existing Help modal and keep the tank paused.
## The HelpScreen's own Menu button returns to the tank (`_close_help`), not the main menu.
func _on_options_help() -> void:
	if _level == null or _options_dialog == null:
		return
	Screens.close_dialog()
	_options_dialog = null
	var wrapper := Control.new()
	wrapper.name = "HelpDialog"
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.add_child(dim)
	var help := HelpScreen.new()
	help.name = "HelpScreen"
	help.setup(true)
	help.closed.connect(_close_help)
	wrapper.add_child(help)
	if not Screens.open_dialog(wrapper):
		wrapper.queue_free()
		return
	_help_dialog = wrapper


## Close the in-tank Help modal and resume the same tank.
func _close_help() -> void:
	if _help_dialog == null:
		return
	Screens.close_dialog()
	_help_dialog = null
	Game.gameplay_paused = false


## Drop the debug dialog without reopening Options (the level is going away).
func _close_debug_only() -> void:
	_debug_dialog = null
	Screens.close_dialog()


## Close the in-tank Options dialog and resume the same level.
func _close_options() -> void:
	if _options_dialog == null:
		return
	Screens.close_dialog()
	_options_dialog = null
	Game.gameplay_paused = false


## The tank lost: `Level._check_defeat` has already collected every coin (EV-0249), so this only shows
## the recovered card and holds the tank behind it, the same way Options holds it. The card's id is
## the base's 17 (EV-0252), but what its button leads to is still open (Q-0065), so the click takes
## the leave-tank path below as a named fit.
func _on_defeated() -> void:
	if _level == null or _game_over_dialog != null:
		return
	if _options_dialog != null:
		_close_options()
	if _debug_dialog != null:
		_close_debug_only()
	_level.holding_fire = false
	Game.gameplay_paused = true
	var dialog := GameOverDialog.new()
	dialog.name = "GameOverDialog"
	dialog.continue_pressed.connect(_on_game_over_continue)
	if not Screens.open_dialog(dialog):
		dialog.queue_free()
		return
	_game_over_dialog = dialog


func _on_game_over_continue() -> void:
	Screens.close_dialog()
	_game_over_dialog = null
	_leave_tank()


## The binary's id-99 leave-tank path: save as a port safety net (D-0014, because menu starts do
## not auto-resume yet), free the level's entities and mount a fresh `GameSelector` immediately.
func _leave_tank() -> void:
	_close_options()
	_pending_bonus = {}
	if _level == null:
		return
	var err: Error = _level.save_game()
	if err != OK:
		push_warning("Main: could not save before returning to the menu (error %d)" % err)
	Game.gameplay_paused = false
	if _level.tank != null:
		_level.tank.shutdown()
	_level.queue_free()
	_level = null
	_mount_selector()


## The port-only NEXT LEVEL (D-0018). `Level.debug_next_level()` already walked the profile on, so
## this only closes whatever modal is up and swaps the level - the Hatch/Pets/Bonus cards are
## skipped on purpose.
func _on_level_skip() -> void:
	if _level == null:
		return
	_pending_bonus = {}
	if _debug_dialog != null:
		_close_debug_only()
	if _options_dialog != null:
		_close_options()
	var mode: int = Game.mode
	Game.gameplay_paused = false
	if _level.tank != null:
		_level.tank.shutdown()
	_level.queue_free()
	_level = null
	_on_start_requested(mode)


## A completed level: the profile has already advanced (P2.6 §1.2/§10.4). The between-level
## flow is Hatch (award card) -> Pets (selection) -> Bonus (payout) -> next level (P4.6). A tank's
## level-5 completion on tanks 1-3 inserts the bonus round between Pets and the card: the tank stays
## live, finalized and frozen, and `begin_bonus_round` runs the 160-tick wait (P2.6 §1.4/§6.2).
func _on_level_completed(tank_no: int, level_no: int, pet_index: int) -> void:
	# A debug action (the egg button) can complete the level while Options is open. Close the
	# modals first so the Hatch/Pets/Bonus flow is not left under a dead dialog.
	if _options_dialog != null:
		_close_options()
	if _debug_dialog != null:
		_close_debug_only()
	if _help_dialog != null:
		_close_help()
	var payload := 0
	if _level != null:
		payload = BonusScreen.payout_for(tank_no, Game.mode, _level.money,
			Game.profile.tank5_wins, 0)
		# SPECS §4.3 pays every bonus out through the clamped Shells setter. Time Trial and
		# Challenge already bank their reward in `Level.complete_level`, so only the adventure's
		# own payout (the tank-5 win bonus) is credited here, once, with the card that shows it.
		if Game.mode == Game.Mode.ADVENTURE:
			Game.profile.add_shells(payload)
		if Progression.has_bonus_round(tank_no, level_no, Game.mode):
			# The finalizer and the round run after the Hatch/Pets cards, so the tank is held
			# here (paused) instead of being freed.
			_pending_bonus = {"tank": tank_no, "level": level_no}
			Game.gameplay_paused = true
			_show_hatch(pet_index, tank_no, level_no, payload)
			return
		_level.queue_free()
		_level = null
	_show_hatch(pet_index, tank_no, level_no, payload)


func _show_hatch(pet_index: int, tank_no: int, level_no: int, payload: int) -> void:
	_clear_flow()
	var screen := HatchScreen.new()
	screen.name = "HatchScreen"
	screen.setup(pet_index)
	screen.continue_pressed.connect(func() -> void: _show_pets(tank_no, level_no, payload))
	_screens_layer.add_child(screen)
	_flow = screen


func _show_pets(tank_no: int, level_no: int, payload: int) -> void:
	_clear_flow()
	var screen := PetsScreen.new()
	screen.name = "PetsScreen"
	screen.setup(Game.profile)
	screen.confirm_pressed.connect(func(_chosen: Array[int]) -> void:
		_show_bonus(tank_no, level_no, payload))
	_screens_layer.add_child(screen)
	_flow = screen


func _show_bonus(tank_no: int, level_no: int, payload: int) -> void:
	_clear_flow()
	if not _pending_bonus.is_empty() and _level != null:
		# P2.6 §6: the round runs on the finalized tank, then `_on_bonus_finished` pays its
		# `Tank+0x3F4` total through this same card.
		# `FUN_00537E20` reads `Tank+0x3CC`, which the sentinel restart has already set to 6, so a
		# tank final runs at level 6 (15/20/25 s) even though the played level was 5 (P2.6 §6.1).
		_level.begin_bonus_round(int(_pending_bonus["tank"]), Progression.LEVEL_SENTINEL)
		_level.bonus_finished.connect(_on_bonus_finished)
		Game.gameplay_paused = false
		return
	var screen := BonusScreen.new()
	screen.name = "BonusScreen"
	screen.setup(tank_no, Game.mode, payload)
	screen.continue_pressed.connect(func() -> void:
		_clear_flow()
		_on_start_requested(Game.mode))
	_screens_layer.add_child(screen)
	_flow = screen


## The round's end gate (P2.6 §6.2): `FUN_00501370` has already advanced the profile at completion,
## the score record is still unported (Q-0053), and `FUN_0054BF60` opens the BonusScreen. In normal
## Adventure the card pays the round's `Tank+0x3F4` shells (EV-0069), so they are banked here once.
func _on_bonus_finished(shells: int) -> void:
	if _level == null or _pending_bonus.is_empty():
		return
	var tank_no := int(_pending_bonus["tank"])
	var level_no := int(_pending_bonus["level"])
	_pending_bonus = {}
	Game.gameplay_paused = true
	if Game.mode == Game.Mode.ADVENTURE and shells > 0:
		Game.profile.add_shells(shells)
	_level.tank.shutdown()
	_level.queue_free()
	_level = null
	_show_bonus(tank_no, level_no, shells)


func _clear_flow() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.queue_free()
	_flow = null


## Mount the main menu once the content is loaded and nothing else owns the screen. `_flow` guards
## the between-level cards: a completed level nulls `_level` while Hatch/Pets/Bonus are up, and the
## menu must not draw under them. The menu comes first (P4.14): its buttons write `Game.mode` and
## ask for the level. The tank MENU button calls this directly so the return is one frame.
func _mount_selector() -> void:
	if _selector != null or _level != null or _flow != null:
		return
	if not Content.is_phase_complete(Content.Phase.LOADING):
		return
	_selector = GameSelector.new()
	_selector.name = "GameSelector"
	_selector.start_requested.connect(_on_start_requested)
	_screens_layer.add_child(_selector)


func _process(delta: float) -> void:
	# ~4 ms of loading per frame: finishes in a second or two and keeps the window responsive.
	if not Content.is_phase_complete(Content.Phase.LOADING):
		Content.pump(4.0)
	elif _level == null and _selector == null and _flow == null:
		_mount_selector()
	_elapsed += delta
	_frames += 1
	if _elapsed < 1.0:
		return
	if _info.visible:
		_info.text = "FPS: %d  tick %d  (%.0f Hz, %d this frame)  content %d/%d" % [
			roundi(_frames / _elapsed),
			Sim.tick_count,
			Sim.TICKS_PER_SECOND,
			Sim.last_ticks_per_frame,
			Content.loaded_count(),
			Content.EXPECTED_TOTAL,
		]
	_frames = 0
	_elapsed = 0.0
