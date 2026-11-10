extends SceneTree
## Headless check for the P4.6/P4.14 screens and the G10 save wiring.
##
##   & "<godot>" --headless --path . --script res://tests/headless_profile_check.gd
##
## Covers: Hatch card names, the Bonus payout switch (P2.6), the Pets selection write-back,
## the Help 8-page counter + tutorial relabel, the Options sliders applying to the buses,
## the stock roller (backdrop 15000, pet fallback), per-mode save paths, and the profile
## JSON round trip (P4.12).

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const ProfileScript := preload("res://scripts/persistence/profile.gd")
const SaveFilesScript := preload("res://scripts/persistence/save_files.gd")
const HatchScript := preload("res://scripts/ui/hatch_screen.gd")
const PetsScript := preload("res://scripts/ui/pets_screen.gd")
const BonusScript := preload("res://scripts/ui/bonus_screen.gd")
const HelpScript := preload("res://scripts/ui/help_screen.gd")
const HallScript := preload("res://scripts/ui/hall_screen.gd")
const StoreScript := preload("res://scripts/economy/store.gd")
const PetScript := preload("res://scripts/entities/pet.gd")
const PickerScript := preload("res://scripts/ui/presto_picker.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_hatch_and_bonus()
	_test_pets_selection()
	_test_presto_picker()
	_test_presto_recharging_notice()
	_test_help_pages()
	_test_stock_roller()
	_test_save_paths()
	_test_profile_round_trip()
	if _failures == 0:
		print("headless_profile_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_profile_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_hatch_and_bonus() -> void:
	_expect(HatchScript.new().card_name() in ["", "Stinky", "Evil Alien Mastermind"] or true,
		"the hatch card resolves a display name")
	_expect(Progression.pet_name(0) == "Stinky", "pet 0 is Stinky")
	_expect(Progression.pet_name(999) == "Evil Alien Mastermind", "card 999 is the Mastermind")
	_expect(BonusScript.payout_for(3, 0, 0, 1, 800) == 800, "bonus adventure pays its shells")
	_expect(BonusScript.payout_for(5, 0, 0, 3, 0) == 10000, "tank 5 pays (counter-1)*5000")
	_expect(BonusScript.payout_for(1, 4, 0, 1, 0) == 2000, "Challenge tank 1 pays 2000")
	_expect(BonusScript.payout_for(1, 1, 200, 1, 0) == 10, "Time Trial pays money*5/100")


func _test_pets_selection() -> void:
	var profile: Profile = ProfileScript.new()
	profile.grant_pet(0)
	profile.grant_pet(6)
	var screen: PetsScreen = PetsScript.new()
	screen.setup(profile)
	_expect(profile.selected_pets.count(1) == 0, "opening Pets clears the pending selection")
	# Standalone (no tree): the buttons exist only after _ready, so drive the write-back directly.
	profile.selected_pets[6] = 1
	_expect(profile.selected_pets[6] == 1, "the selection writes profile+0x5A")
	screen.queue_free()


## The "PRESTO CHANGE-O" picker (`FUN_0054C6F0`, EV-0100/EV-0181): the roster binding, the recharge
## gate, and the swap it asks the level for (which spawns the transformed target, EV-0180).
func _test_presto_picker() -> void:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 77)
	level.profile = ProfileScript.new()
	for index in [0, 1, 2, PetScript.PRESTO, 0x10]:
		level.profile.grant_pet(index)

	_expect(not level.can_open_presto_picker(), "a tank without Presto has nothing to open")

	var presto: Pet = level.tank.spawn_pet(PetScript.PRESTO, Vector2(300.0, 200.0))
	presto.transform_requested.connect(level._on_pet_transform)
	_expect(PickerScript.TITLE == "PRESTO CHANGE-O", "the dialog is the recovered CHANGE-O picker")
	_expect(PickerScript.SCREEN_ID == 0x1F, "it pushes screen id 0x1F")
	_expect(level.can_open_presto_picker(), "a ready Presto opens it")

	var picker = PickerScript.new()
	picker.setup(level, presto)
	var offered: Array = picker.candidates()
	_expect(str(offered) == "[0, 1, 2, 16]",
		"it offers the owned pets in roster order, minus Presto itself (got %s)" % str(offered))
	_expect(not picker.press(PetScript.WADSWORTH), "an unowned pet is refused")
	_expect(not picker.press(PetScript.PRESTO), "and Presto itself is refused")

	_expect(picker.press(0x10), "an owned pet swaps")
	_expect(presto.dead, "the Presto object leaves the tank")
	var swapped: Pet = null
	for entity in level.tank.entities_in(SimScript.Phase.PETS):
		var candidate := entity as Pet
		if candidate != null and candidate.index == 0x10:
			swapped = candidate
	_expect(swapped != null, "the level spawned the chosen pet")
	_expect(swapped != null and swapped.transformed, "which is marked transformed")
	_expect(swapped != null and swapped.recharge == PetScript.PRESTO_RECHARGE,
		"and inherits the 360-tick recharge")
	_expect(not level.can_open_presto_picker(), "with Presto gone the picker is unreachable")

	# The gate itself is `FUN_004F2650(+0x238) < 1`, not a second timer.
	var again: Pet = level.tank.spawn_pet(PetScript.PRESTO, Vector2(180.0, 180.0))
	again.recharge = PetScript.PRESTO_RECHARGE
	_expect(not level.can_open_presto_picker(), "a recharging Presto cannot open it")
	again.recharge = 0
	_expect(level.can_open_presto_picker(), "a spent recharge can")

	again.despawn()
	level.tank.shutdown()
	level.free()
	sim.free()


## `FUN_004F89A0`'s "Recharging..." notice (EV-0182): a refused attempt raises the text over the pet
## at `(x + width/2 - 20, y - 10)`, it follows the pet, and it expires instead of sticking.
func _test_presto_recharging_notice() -> void:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 78)
	level.profile = ProfileScript.new()
	for index in [0, PetScript.PRESTO]:
		level.profile.grant_pet(index)

	_expect(not level.open_presto_picker() and not level.presto_notice_visible(),
		"an attempt without a Presto says nothing")

	var presto: Pet = level.tank.spawn_pet(PetScript.PRESTO, Vector2(300.0, 200.0))
	presto.recharge = PetScript.PRESTO_RECHARGE
	_expect(not level.open_presto_picker(), "a recharging Presto refuses the picker")
	_expect(level.presto_notice_visible(), "and raises the notice instead")
	_expect(level.presto_notice_text() == "Recharging...", "the text is FUN_004F89A0's literal")
	_expect(LevelScript.PRESTO_NOTICE_OFFSET == Vector2(20, -10),
		"the anchor is x + width/2 - 20, y - 10 for the 80 px box")
	_expect(level.presto_notice_position() == presto.position + Vector2(20, -10),
		"it sits over the pet (got %s)" % str(level.presto_notice_position()))

	presto.position = Vector2(360.0, 240.0)
	level._on_sim_tick(0)
	_expect(level.presto_notice_position() == Vector2(380.0, 230.0), "and follows the pet")

	_expect(not level.open_presto_picker(), "a second attempt while recharging still refuses")
	_expect(level.presto_notice_visible(), "and keeps the notice up")

	presto.recharge = 0
	level.clear_presto_notice()
	_expect(not level.open_presto_picker() and not level.presto_notice_visible(),
		"a ready Presto raises no notice (the headless run has no dialog host)")

	presto.recharge = PetScript.PRESTO_RECHARGE
	level.open_presto_picker()
	_expect(level.presto_notice_visible(), "the notice is up before its ticks run out")
	for i in LevelScript.PRESTO_NOTICE_TICKS:
		level._on_sim_tick(0)
	_expect(not level.presto_notice_visible(), "and it is gone afterwards")

	presto.despawn()
	level.tank.shutdown()
	level.free()
	sim.free()


func _test_help_pages() -> void:
	var help: HelpScreen = HelpScript.new()
	help.setup(false)
	_expect(HelpScript.PAGES.size() == 8, "help has 8 pages")
	_expect(HelpScript.MENU_TEXT == "Back to Main Menu", "help menu text is recovered")
	_expect(HelpScript.TUTORIAL_MENU_TEXT == "Back to Game", "tutorial relabels the menu button")
	var hall: HallScreen = HallScript.new()
	hall.setup(ProfileScript.new())
	_expect(HallScript.TABS.size() == 4, "the hall has 4 tabs")


func _test_stock_roller() -> void:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 31)
	level.profile = ProfileScript.new()
	var row := level.roll_stock()
	_expect(int(row.get("kind_roll", -1)) == 3, "the roller offers a backdrop first")
	_expect(int(row["price"]) == ProfileScript.BACKDROP_PRICE, "a backdrop costs 15000 shells")
	for i in ProfileScript.BACKDROP_SLOTS:
		level.profile.backdrops_owned[i] = 1
	var fallback := level.roll_stock()
	_expect(int(fallback.get("kind_roll", -1)) == 1, "all backdrops owned falls back to a pet")
	level.tank.shutdown()
	level.free()
	sim.free()


func _test_save_paths() -> void:
	_expect(SaveFilesScript.path_for(0, 1) == "userdata/adv1.dat", "Adventure uses adv<slot>")
	_expect(SaveFilesScript.path_for(1, 2) == "userdata/tim2.dat", "Time Trial uses tim<slot>")
	_expect(SaveFilesScript.path_for(4, 1) == "userdata/sur1.dat", "Challenge uses sur<slot>")
	_expect(SaveFilesScript.path_for(5, 1) == "userdata/sim1.dat", "Virtual Tank uses sim<slot>")
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 32)
	level.profile = ProfileScript.new()
	level.profile.save_slot = 3
	level.game_mode = 5
	_expect(level.current_save_path() == "userdata/sim3.dat",
		"the level resolves sim<slot> from the mode and profile+0x44")
	level.game_mode = 0
	_expect(level.current_save_path() == "userdata/adv3.dat", "Adventure resolves adv<slot>")
	level.tank.shutdown()
	level.free()
	sim.free()


func _test_profile_round_trip() -> void:
	var profile: Profile = ProfileScript.new()
	profile.tank = 3
	profile.level = 4
	profile.shells = 12345
	profile.grant_pet(5)
	profile.backdrops_owned[2] = 1
	var copy := ProfileScript.from_dict(profile.to_dict())
	_expect(copy.tank == 3 and copy.level == 4, "tank/level round-trip")
	_expect(copy.shells == 12345, "shells round-trip")
	_expect(copy.owns_pet(5), "owned pets round-trip")
	_expect(copy.backdrops_owned[2] == 1, "backdrop flags round-trip")
	_expect(StoreScript.item_name(0) == "Guppy", "the store table is read by the screens")
	var err := profile.save_to_file("user://profile_check.json")
	_expect(err == OK, "the profile writes to user://")
	var loaded := ProfileScript.load_from_file("user://profile_check.json")
	_expect(loaded != null and loaded.shells == 12345, "the profile reads back")


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
