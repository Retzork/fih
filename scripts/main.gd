extends Node2D
## Main - the boot scene. It owns almost nothing on purpose: it attaches the screen layer to the
## Screens autoload, drives the debug overlay (P2.1/EV-0035: `FPS: %d` per 1000 ms window) and mounts
## the P4.4 level once the content phases have finished.
##
## Everything else is a screen (docs/ARCHITECTURE.md §3). Main also drives the P4.2 content load:
## Init is already done by the Content autoload, Register is pulled before the first menu, and the
## LoadingThread phase is pumped here a slice at a time until P4.5's loading screen takes the bar.

@onready var _screens_layer: CanvasLayer = $Screens
@onready var _info: Label = $Debug/Info

var _level: Level = null
var _selector: GameSelector = null
var _frames := 0
var _elapsed := 0.0
var _flow: Control = null


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
	# P2.6 §1.1: the adventure's current tank and level, with that tank's store table and egg price.
	var start := Progression.resolve_start(Game.profile.tank, Game.profile.level)
	Game.profile.tank = int(start["tank"])
	Game.profile.level = int(start["level"])
	Game.profile.sessions_started += 1
	_level.start_level(Game.profile.tank, Game.profile.level)


## A completed level: the profile has already advanced (P2.6 §1.2/§10.4). The between-level
## flow is Hatch (award card) -> Pets (selection) -> Bonus (payout) -> next level (P4.6).
func _on_level_completed(tank_no: int, level_no: int, pet_index: int) -> void:
	var payload := 0
	if _level != null:
		payload = BonusScreen.payout_for(tank_no, Game.mode, _level.money,
			Game.profile.tank5_wins, 0)
		# SPECS §4.3 pays every bonus out through the clamped Shells setter. Time Trial and
		# Challenge already bank their reward in `Level.complete_level`, so only the adventure's
		# own payout (the tank-5 win bonus) is credited here, once, with the card that shows it.
		if Game.mode == Game.Mode.ADVENTURE:
			Game.profile.add_shells(payload)
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
	var screen := BonusScreen.new()
	screen.name = "BonusScreen"
	screen.setup(tank_no, Game.mode, payload)
	screen.continue_pressed.connect(func() -> void:
		_clear_flow()
		_on_start_requested(Game.mode))
	_screens_layer.add_child(screen)
	_flow = screen


func _clear_flow() -> void:
	if _flow != null and is_instance_valid(_flow):
		_flow.queue_free()
	_flow = null


func _process(delta: float) -> void:
	# ~4 ms of loading per frame: finishes in a second or two and keeps the window responsive.
	if not Content.is_phase_complete(Content.Phase.LOADING):
		Content.pump(4.0)
	elif _level == null and _selector == null and _flow == null:
		# `_flow` guards the between-level screens: a completed level nulls `_level` while Hatch,
		# Pets and Bonus are up, and mounting the menu under them would draw it behind the cards.
		# The menu comes first (P4.14): its buttons write `Game.mode` and ask for the level.
		_selector = GameSelector.new()
		_selector.name = "GameSelector"
		_selector.start_requested.connect(_on_start_requested)
		_screens_layer.add_child(_selector)
	_elapsed += delta
	_frames += 1
	if _elapsed < 1.0:
		return
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
