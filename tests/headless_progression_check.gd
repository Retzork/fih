extends SceneTree
## Headless check for P2.6 progression: the per-tank store table, egg prices and pieces, the pet
## award, the advance rule and the level's own completion path (Q-0053 covers what is not ported).
##
##   & "<godot>" --headless --path . --script res://tests/headless_progression_check.gd

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const StoreScript := preload("res://scripts/economy/store.gd")
const ProgressionScript := preload("res://scripts/progression/progression.gd")
const ProfileScript := preload("res://scripts/persistence/profile.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_egg_table()
	_test_store_table()
	_test_awards()
	_test_advance()
	_test_profile()
	_test_level_completion()
	_test_challenge_completion()
	_test_final_level()
	if _failures == 0:
		print("headless_progression_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_progression_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _test_egg_table() -> void:
	_expect(ProgressionScript.egg_pieces_at_start(1) == 1, "a normal level starts with one egg piece")
	_expect(ProgressionScript.egg_pieces_at_start(5) == 3, "tank 5 starts at three pieces")
	_expect(ProgressionScript.EGG_PIECES_TO_COMPLETE == 4, "four pieces complete a level")
	_expect(ProgressionScript.egg_price(1, 1) == 150, "tank 1 level 1's egg costs 150")
	_expect(ProgressionScript.egg_price(1, 5) == 5000, "tank 1 level 5's egg costs 5000")
	_expect(ProgressionScript.egg_price(2, 3) == 5000, "tank 2 level 3's egg costs 5000")
	_expect(ProgressionScript.egg_price(4, 5) == 99999, "tank 4 level 5's egg costs 99999")
	_expect(ProgressionScript.egg_price(5, 1) == 0, "tank 5's egg is free")
	_expect(ProgressionScript.egg_price(2, 1, ProgressionScript.MODE_CHALLENGE) == 5000,
		"challenge overrides tank 2's egg to 5000")
	_expect(ProgressionScript.egg_price(3, 1, ProgressionScript.MODE_CHALLENGE) == 15000,
		"challenge overrides tank 3's egg to 15000")
	_expect(ProgressionScript.egg_price(4, 1, ProgressionScript.MODE_CHALLENGE) == 25000,
		"challenge overrides tank 4's egg to 25000")
	_expect(ProgressionScript.egg_price(1, 1, ProgressionScript.MODE_CHALLENGE) == ProgressionScript.PRICE_UNKNOWN,
		"challenge on tank 1 has no recovered egg price")
	_expect(ProgressionScript.egg_price(1, 1, ProgressionScript.MODE_TIME_TRIAL) == 100,
		"time trial's egg costs 100")
	_expect(ProgressionScript.egg_price(1, 6) == ProgressionScript.PRICE_UNKNOWN,
		"the sentinel level has no egg price")


func _test_store_table() -> void:
	var l1 := ProgressionScript.store_rows(1, 1)
	_expect(l1.size() == 1 and int(l1[0]["slot"]) == 0, "tank 1 level 1 sells only the guppy")
	_expect(int(l1[0]["price"]) == 100 and int(l1[0]["shelf"]) == 0, "the guppy is 100 at shelf 0")
	var l3 := ProgressionScript.store_rows(1, 3)
	var ids: Array = []
	for row: Dictionary in l3:
		ids.append(int(row["slot"]))
	_expect(ids == [0, 2, 3, 4, 10], "tank 1 level 3 stocks five items in shelf order")
	_expect(int(l3[3]["price"]) == 1000 and int(l3[3]["shelf"]) == 3, "the carnivore is 1000 at shelf 3")
	var t2 := ProgressionScript.store_rows(2, 1)
	_expect(t2.size() == 4, "tank 2 level 1 hides two of its six items")
	var t2_has_6 := false
	for row: Dictionary in t2:
		if int(row["slot"]) == 6:
			t2_has_6 = true
	_expect(not t2_has_6, "the starcatcher is hidden on tank 2 level 1")
	var t4 := ProgressionScript.store_rows(4, 5)
	_expect(int(t4[t4.size() - 1]["slot"]) == 10 and int(t4[t4.size() - 1]["price"]) == 5000,
		"tank 4's weapon upgrade costs 5000")
	var tank5 := ProgressionScript.store_rows(5, 1)
	_expect(tank5.size() == 1 and int(tank5[0]["slot"]) == ProgressionScript.EGG_ITEM,
		"tank 5 sells only the egg piece")
	_expect(int(tank5[0]["price"]) == 0 and bool(tank5[0]["free"]), "the tank-5 egg is free, not unrecovered")
	_expect(StoreScript.price_known(tank5[0]), "a free row is sellable despite its 0")
	_expect(int(tank5[0]["shelf"]) == 6, "the egg sits at store slot 6")


func _test_awards() -> void:
	_expect(ProgressionScript.offered_pet(1, 1) == 0, "1-1 awards Stinky")
	_expect(ProgressionScript.offered_pet(1, 5) == 4, "1-5 awards Zorf")
	_expect(ProgressionScript.offered_pet(2, 1) == 5, "2-1 awards Clyde")
	_expect(ProgressionScript.offered_pet(3, 5) == 14, "3-5 awards Rhubarb")
	_expect(ProgressionScript.offered_pet(4, 4) == 18, "4-4 awards Angie")
	_expect(ProgressionScript.offered_pet(4, 5) == ProgressionScript.PET_CARD,
		"4-5 awards the 999 card instead of Presto")
	_expect(ProgressionScript.offered_pet(5, 1) == 19, "5-1 awards Presto")
	_expect(ProgressionScript.pet_name(0) == "Stinky", "index 0 is Stinky")
	_expect(ProgressionScript.pet_name(19) == "Presto", "index 19 is Presto")
	_expect(ProgressionScript.pet_name(999) == "Evil Alien Mastermind", "999 is the card's name")
	_expect(ProgressionScript.pet_name(24) == "", "an index past the roster has no name")


func _test_advance() -> void:
	var a := ProgressionScript.advance(1, 1)
	_expect(int(a["tank"]) == 1 and int(a["level"]) == 2, "1-1 advances to 1-2")
	var sentinel := ProgressionScript.advance(1, 5)
	_expect(int(sentinel["level"]) == 6, "1-5 advances into the level-6 sentinel")
	var after := ProgressionScript.advance(1, 6)
	_expect(int(after["tank"]) == 2 and int(after["level"]) == 1, "the sentinel resolves to 2-1")
	var tank4 := ProgressionScript.advance(4, 5)
	_expect(int(tank4["tank"]) == 5 and int(tank4["level"]) == 1, "4-5 jumps to 5-1 with no bonus")
	var tank5 := ProgressionScript.advance(5, 1)
	_expect(int(tank5["level"]) == 2 and bool(tank5["bonus_adventure"]) and int(tank5["tank5_wins"]) == 1,
		"5-1 advances to 5-2, sets the Bonus Adventure flag and counts the win")
	var resolved := ProgressionScript.resolve_start(1, 6)
	_expect(int(resolved["tank"]) == 2 and int(resolved["level"]) == 1,
		"a start on the sentinel runs the next tank")


func _test_profile() -> void:
	var profile: Profile = ProfileScript.new()
	_expect(profile.pet_count() == 0 and profile.tank == 1, "a fresh profile owns nothing and starts at 1-1")
	_expect(profile.grant_pet(3) and profile.owns_pet(3), "granting a pet marks its byte")
	_expect(not profile.grant_pet(3), "a second grant of the same pet changes nothing")
	_expect(profile.pet_count() == 1, "the owned count follows the bytes")
	_expect(not profile.grant_pet(24), "index 24 is outside the roster")
	profile.shells = ProfileScript.SHELLS_MAX - 10
	_expect(profile.add_shells(5000) == ProfileScript.SHELLS_MAX, "Shells clamp at 9,999,999")
	_expect(profile.add_shells(-999999999) == 0, "Shells clamp at 0")
	profile.tank = 3
	_expect(profile.tanks_unlocked() == 3, "the tank reached is what the menus gate on")
	_expect(not profile.adventure_done(), "the adventure is not done before the Bonus Adventure flag")
	profile.bonus_adventure = true
	_expect(profile.adventure_done(), "the Bonus Adventure flag is the menu's 'adventure done'")


func _make_level(seed_value: int) -> Level:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, seed_value)
	return level


func _test_level_completion() -> void:
	var level := _make_level(4100)
	var profile: Profile = ProfileScript.new()
	level.profile = profile
	var seen: Array = []
	level.level_completed.connect(func(tank_no: int, level_no: int, pet: int) -> void:
		seen.append([tank_no, level_no, pet]))
	level.start_level(1, 1)
	_expect(level.tank_index == 1 and level.level_index == 1, "the level records 1-1")
	_expect(level.egg_pieces == 1 and level.egg_price == 150, "1-1 opens with one piece at 150")
	_expect(level.tank_store.size() == 1, "1-1's shop has the guppy alone")
	level.money = 1000
	_expect(level.egg_widget != null, "the tank has an egg widget")
	if level.egg_widget == null:
		level.tank.shutdown()
		level.free()
		return
	_expect(level.egg_widget.press(), "the egg widget buys the first piece")
	_expect(level.money == 850 and level.egg_pieces == 2, "150 comes out of the shells per piece")
	_expect(not level.completed and seen.is_empty(), "two pieces do not complete the level")
	_expect(level.egg_widget.press() and level.egg_widget.press(), "the second and third pieces are bought")
	_expect(level.completed, "the fourth piece completes the level")
	_expect(level.money == 550, "three pieces cost 450")
	_expect(not level.egg_widget.press(), "a completed level refuses another piece")
	_expect(seen.size() == 1 and int(seen[0][2]) == 0, "the completion awards Stinky")
	_expect(profile.owns_pet(0), "the profile records the pet")
	_expect(profile.tank == 1 and profile.level == 2, "the profile advances to 1-2")
	level.tank.shutdown()
	level.free()


func _test_challenge_completion() -> void:
	var level := _make_level(4200)
	var profile: Profile = ProfileScript.new()
	level.profile = profile
	level.game_mode = ProgressionScript.MODE_CHALLENGE
	var seen: Array = []
	level.level_completed.connect(func(_t: int, _l: int, pet: int) -> void:
		seen.append(pet))
	level.start_level(2, 1)
	_expect(level.egg_price == 5000, "challenge's tank-2 egg is 5000")
	level.money = 25000
	_expect(level.buy_egg() and level.buy_egg() and level.buy_egg(), "three pieces are bought")
	_expect(level.completed and profile.pet_count() == 0, "challenge grants no pet")
	_expect(int(profile.challenge_unlocks[1]) == 1, "it records the tank-2 challenge unlock")
	_expect(profile.tank == 1 and profile.level == 1, "challenge leaves the adventure's position alone")
	_expect(seen.size() == 1 and int(seen[0]) == -1, "the completion reports no pet award")
	level.tank.shutdown()
	level.free()


func _test_final_level() -> void:
	var level := _make_level(4300)
	var profile: Profile = ProfileScript.new()
	level.profile = profile
	var seen: Array = []
	level.level_completed.connect(func(tank_no: int, level_no: int, pet: int) -> void:
		seen.append([tank_no, level_no, pet]))
	level.start_level(5, 1)
	_expect(level.egg_pieces == 3 and level.egg_price == 0, "tank 5 opens at three pieces, free")
	_expect(level.tank_store.size() == 1 and int(level.tank_store[0]["shelf"]) == 6,
		"tank 5's only row is the egg on the bar's seventh dome")
	_expect(StoreScript.price_known(level.tank_store[0]),
		"the free row is a known price, not the unrecovered marker")
	_expect(level.egg_widget.visible, "tank 5 draws the egg in its dome like the other tanks")
	var purse: int = level.money
	_expect(level.buy_item(0), "the single shelf buys the tank-5 egg")
	_expect(level.money == purse, "the free purchase leaves the purse alone (got %d)" % level.money)
	_expect(level.completed, "one purchase completes tank 5")
	_expect(not level.buy_item(0) and not level.buy_egg(), "a completed tank refuses the egg row")
	_expect(level.egg_pieces == 4, "no fifth piece is recorded")
	_expect(seen.size() == 1, "the completion fires once (got %d)" % seen.size())
	_expect(profile.owns_pet(ProgressionScript.FINAL_BOSS_PET), "5-1 grants Presto")
	_expect(profile.shells == ProgressionScript.FINAL_BOSS_SHELLS, "and pays 5000 Shells")
	_expect(profile.tank5_wins == 1 and profile.bonus_adventure, "the profile records the win")
	_expect(profile.tank == 5 and profile.level == 2, "the profile sits on the 5-2 victory gate")
	level.tank.shutdown()
	level.free()
