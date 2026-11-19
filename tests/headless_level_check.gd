extends SceneTree
## Headless check for the P4.4 level (the feeding loop).
##
##   & "<godot>" --headless --path . --script res://tests/headless_level_check.gd
##
## The level runs with `render = false`, so no Content access and no sprites - the same simulation the
## game runs, minus the drawing. Covers the starting population, click-to-feed, pickup routing, the
## AddMoney clamps, death + live successor (P2.4 Â§4) and the tank pause gate.

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const PetScript := preload("res://scripts/entities/pet.gd")
const FoodScript := preload("res://scripts/entities/food.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const DeadFishScript := preload("res://scripts/entities/dead_fish.gd")
const AlienScript := preload("res://scripts/entities/alien.gd")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")

const GUPPY := FishScript.Species.GUPPY


## Minimal stand-in for the `Game` autoload's shared pause flag (the production pause source).
class PauseSource:
	extends Node

	var gameplay_paused := false

var _failures := 0
var _checks := 0
var sim: Node
var level: Level


func _init() -> void:
	sim = SimScript.new()
	level = LevelScript.new()
	level.render = false
	level.setup(sim, 5150)
	# The cap has its own scenario in `_test_food_cap`; other scenarios drop freely.
	level.food_quantity = LevelScript.FOOD_QUANTITY_MAX

	_test_starting_population()
	_test_feeding()
	_test_click_routing()
	_test_money()
	_test_store()
	_test_coin_pickup()
	_test_death_and_successor()
	_test_fish_animation_speed()
	_test_food_animation()
	_test_hold_fire()
	_test_pause()
	_test_wave_spawn()
	_test_shooting()
	_test_alien_eating()
	_test_food_cap()
	_test_pet_session()
	_test_debug_actions()
	_test_hunger_hint()
	_test_hint_cache_on_load()
	_test_load_refresh()
	_test_wave_counter_reset()
	_test_loaded_store_rows()
	_test_time_trial_load()

	level.tank.shutdown()
	level.free()
	sim.free()

	if _failures == 0:
		print("headless_level_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_level_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


## The bottom HUD (D-0028): the base's "Tank  1-1" and the two hunger-hint wordings, both measured
## off the recording. The label itself needs a rendered HUD, so this drives `hint_text()` and the
## name format. D-0031 deleted the port's own bottom-right readout, so the name is the only one.
## A restored save brings its own tank, so the hint's per-tick cache must not survive `load_game()`:
## a restored `age_ticks` equal to the cached tick would hold the previous tank's wording (D-0035).
## The `Level` outlives the tank it draws, so a load has to re-derive or drop every per-tank value the
## save may contradict (D-0037). This drives the ones the headless run can see.
func _test_load_refresh() -> void:
	var path := "user://load_refresh_check.dat"
	level.tank_index = 1
	_expect(level.tank.tank_index == 1,
		"the level's tank index is the live tank's own `+0x3C8`, one field (D-0038)")
	level.level_index = 2
	level.egg_pieces = 2
	level.waves_spawned = 7
	# A finished level carried over from before: two restored pieces have to clear this (D-0041).
	level.completed = true
	_expect(level.save_game(path) == OK, "the load-refresh scenario writes a save")
	# Poison through the tank's field: the level's accessor has to read the same one back.
	level.tank.tank_index = 5
	_expect(level.tank_index == 5, "a write to the tank's field is what the level reads")
	level.level_index = 4
	level.egg_pieces = 1
	level.egg_price = 12345
	level.waves_spawned = 99
	level._composite_selection = 9
	level._composite_pending.append(4)
	level.show_presto_recharging(level.tank.spawn_pet(PetScript.PRESTO, Vector2(300.0, 200.0)))
	_expect(level.presto_notice_visible(), "the scenario raises a prestige notice before the load")
	_expect(level.load_game(path), "load_game reads that save back")
	_expect(level.tank_index == 1 and level.tank.tank_index == 1 and level.level_index == 2,
		"the one tank index and the level come from the save, not the tank that started the session")
	_expect(level.egg_pieces == 2, "the egg-piece count comes from the save, not the pre-load tank")
	_expect(level.waves_spawned == 7, "the wave counter comes from the save's `+0x45C` (got %d)" % level.waves_spawned)
	_expect(not level.completed, "two restored pieces is not a completed level, whatever the pre-load one was")
	# The file's 17-byte rows carry the slot but not the port-only `shelf`, so a load has to put it
	# back or the bar finds no row for any shelf and draws empty domes (D-0040).
	var stocked := level.tank_store.filter(func(row: Dictionary) -> bool:
		return int(row.get("slot", -1)) >= 0)
	_expect(not stocked.is_empty() and stocked.all(func(row: Dictionary) -> bool:
		return row.has("shelf")),
		"every restored store row gets its shelf back, so the bar draws it (D-0040)")
	_expect(level.egg_price == Progression.egg_price(1, 2, level.game_mode),
		"the egg price is re-derived for the restored tank and level")
	_expect(level._composite_selection == -1 and level._composite_pending.is_empty(),
		"a half-delivered composite spawn does not carry into the restored tank")
	_expect(not level.presto_notice_visible(), "no pre-load prestige notice survives the load")
	# The other direction: four pieces in the save is a completed level, so it cannot be bought again.
	level.egg_pieces = 4
	_expect(level.save_game(path) == OK, "a four-piece save is written")
	level.egg_pieces = 1
	_expect(level.load_game(path), "and read back")
	_expect(level.completed, "the restored four pieces mark the level completed (D-0041)")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## `Tank+0x45C` is cleared at session init (P2.6 §1.5's clear list), so a level start drops the
## counter a previous level left on the Level (D-0041).
func _test_wave_counter_reset() -> void:
	level.waves_spawned = 9
	level.start_level(1, 1)
	_expect(level.waves_spawned == 0,
		"a level start clears the wave counter a previous level left behind (got %d)" % level.waves_spawned)


## The save keeps only the 17-byte row (slot, price, base, increment, present), so the port's own
## row keys have to be re-derived: `shelf` places the dome (D-0040) and `free` is the tank-5 egg's
## recovered 0 price (D-0042). The roller's `slot -1` row carries keys no reader uses, so losing them
## changes nothing - what matters is that it takes no dome away from a real shelf.
func _test_loaded_store_rows() -> void:
	var path := "user://store_rows_check.dat"
	var five: Level = LevelScript.new()
	five.render = false
	five.setup(sim, 7373)
	five.start_level(5, 1)
	var egg := _row_of(five, Progression.EGG_ITEM)
	_expect(egg >= 0, "tank 5 stocks its free egg as a store row")
	if egg < 0:
		five.tank.shutdown()
		five.free()
		return
	_expect(bool(five.tank_store[egg].get("free", false)) and Store.price_known(five.tank_store[egg]),
		"the tank-5 egg row is priced as free (price 0 + the `free` key)")
	# A roller row as `roll_stock()` appends it: `slot -1` and the port-only kind keys.
	five.tank_store.append({
		"slot": -1, "price": 15000, "base": 15000, "increment": 0, "present": 0,
		"kind_roll": 3, "backdrop": 1,
	})
	_expect(five.save_game(path) == OK, "the tank-5 save is written")
	_expect(five.load_game(path), "and read back")
	var loaded_egg := _row_of(five, Progression.EGG_ITEM)
	_expect(loaded_egg >= 0 and bool(five.tank_store[loaded_egg].get("free", false)),
		"the free egg's flag is re-derived on load (D-0042)")
	_expect(loaded_egg >= 0 and Store.price_known(five.tank_store[loaded_egg]),
		"so the restored egg row still has a known price")
	_expect(loaded_egg >= 0 and int(StoreBar.row_at(five, 6).get("slot", -1)) == Progression.EGG_ITEM,
		"the egg's shelf still resolves to the egg row, not the roller")
	var roller := -1
	for i in five.tank_store.size():
		if int(five.tank_store[i].get("slot", -1)) == -1 and int(five.tank_store[i].get("price", 0)) == 15000:
			roller = i
	_expect(roller >= 0 and int(five.tank_store[roller].get("shelf", -1))
		== LevelScript.ROLLER_SHELF,
		"the roller's row comes back on the eighth store slot, not in array order (D-0048)")
	_expect(StoreBar.slot_rect(LevelScript.ROLLER_SHELF).size == Vector2.ZERO,
		"the in-tank bar has no eighth dome, so the roller is still undrawn there")
	_expect(loaded_egg >= 0 and five.buy_item(loaded_egg),
		"the free egg still buys through its store row")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	five.tank.shutdown()
	five.free()


## Time Trial counts ticks locally but saves the base's `+0x3B0` seconds, and its budget belongs to the
## tank the save names (300 s on tank 1, 600 s on the rest), so a load from another tank must replace
## both (D-0045). This loads a tank-1 save over a tank-2 run and a tank-2 save over the tank-1 run.
func _test_time_trial_load() -> void:
	var path := "user://time_trial_check.dat"
	var other := "user://time_trial_check2.dat"
	var ticks := LevelScript.TICKS_PER_SECOND
	# The save: tank 1, ten seconds in.
	var one: Level = LevelScript.new()
	one.render = false
	one.setup(sim, 6100)
	one.game_mode = LevelScript.MODE_TIME_TRIAL
	one.start_level(1, 1)
	one.time_trial_elapsed = 10 * ticks
	_expect(one.save_game(path) == OK, "the tank-1 Time Trial save is written")
	one.tank.shutdown()
	one.free()
	# The running session: tank 2, 500 s into its 600.
	var two: Level = LevelScript.new()
	two.render = false
	two.setup(sim, 6101)
	two.game_mode = LevelScript.MODE_TIME_TRIAL
	two.start_level(2, 1)
	_expect(two.time_trial_budget_ticks == 600 * ticks,
		"tank 2 opens on its 600 s budget (got %d ticks)" % two.time_trial_budget_ticks)
	two.time_trial_elapsed = 500 * ticks
	_expect(two.load_game(path), "the tank-1 save loads over the tank-2 run")
	_expect(two.tank_index == 1 and two.time_trial_budget_ticks == 300 * ticks,
		"the budget is re-derived for the restored tank 1 (got %d ticks)" % two.time_trial_budget_ticks)
	_expect(two.time_trial_elapsed == 10 * ticks,
		"the elapsed clock comes back from `+0x3B0` seconds (got %d ticks)" % two.time_trial_elapsed)
	_expect(two.time_trial_seconds_left() == 290,
		"the clock reads 290 s left on 1-1 (got %d)" % two.time_trial_seconds_left())
	# And back: a tank-2 save over the tank-1 run.
	var two_save: Level = LevelScript.new()
	two_save.render = false
	two_save.setup(sim, 6102)
	two_save.game_mode = LevelScript.MODE_TIME_TRIAL
	two_save.start_level(2, 1)
	two_save.time_trial_elapsed = 600 * ticks
	# A finished run writes the clock twice (`+0x3B0` and the `+0x3FC` end snapshot); they are the
	# same seconds, so a load must land on 600 s, not 1200.
	two_save.completed = true
	_expect(two_save.save_game(other) == OK, "the tank-2 Time Trial save is written")
	two_save.tank.shutdown()
	two_save.free()
	_expect(two.load_game(other), "the tank-2 save loads over the tank-1 run")
	_expect(two.time_trial_budget_ticks == 600 * ticks,
		"the tank-2 budget comes back (got %d ticks)" % two.time_trial_budget_ticks)
	_expect(two.time_trial_elapsed == 600 * ticks,
		"the end snapshot and the live clock are one quantity, not two (got %d ticks)" % two.time_trial_elapsed)
	for file in [path, other]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	two.tank.shutdown()
	two.free()


func _row_of(level_ref: Level, slot: int) -> int:
	for i in level_ref.tank_store.size():
		if int(level_ref.tank_store[i].get("slot", -1)) == slot:
			return i
	return -1


func _test_hint_cache_on_load() -> void:
	var path := "user://hint_cache_check.dat"
	_expect(level.save_game(path) == OK, "the hint-cache scenario writes a save")
	level.set("_hint_tick", 4096)
	_expect(level.load_game(path), "load_game reads that save back")
	_expect(int(level.get("_hint_tick")) == -1,
		"loading a save clears the hint's cached tick (D-0035)")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _test_hunger_hint() -> void:
	var constants: Dictionary = level.get_script().get_script_constant_map()
	_expect(not constants.has("LEVEL_PLATE_RECT") and not constants.has("LEVEL_LABEL_COLOR")
		and not constants.has("LEVEL_PLATE_SOURCE"),
		"the port-only bottom-right plate and its green readout are deleted, not moved (D-0031)")
	_expect(LevelScript.tank_name(1, 1) == "Tank  1-1" and LevelScript.tank_name(1, 3) == "Tank  1-3",
		"the bottom-left name is the level readout, with the recording's two-space gap")
	_expect(LevelScript.TANK_LABEL_RECT.position == Vector2(13, 453),
		"the name sits where the recording measures it (13, 453)")
	_expect(LevelScript.HINT_TEXT == "Fish are hungry! Click to drop food!",
		"the shallow hint is the recording's wording")
	_expect(LevelScript.HINT_TEXT_SEVERE == "Fish are REALLY hungry! Click to feed!",
		"the -200 hint is the recording's capitalised wording")
	_expect(LevelScript.HINT_TEXT_DYING == "Fish are about to die of hunger! Click on aquarium!",
		"the -400 hint is the base's dying wording (P2.3 §5)")
	_expect(LevelScript.HINT_RECT.position == Vector2(0, 448)
		and LevelScript.HINT_INK_RECT.position == Vector2(0, 457)
		and LevelScript.HINT_INK_RECT.size.y == 17,
		"the hint is lifted so its ink lands on the recording's 457..474 row (PLAN R29)")
	_expect(LevelScript.TANK_LABEL_COLOR == Color8(0xA8, 0x94, 0x60),
		"the tank name is the measured pale gold")
	_expect(UiFont.BOTTOM_NAME_FONT == "FONT_CONTINUUMBOLD12" and UiFont.BOTTOM_NAME_TRACKING == -1.0,
		"the name keeps ContinuumBold12 with 1 px of tracking trimmed (D-0034)")
	_expect(LevelScript.HINT_COLOR == Color8(0xAE, 0xF7, 0x62)
		and LevelScript.HINT_OUTLINE_COLOR == Color8(0x00, 0x4A, 0x00),
		"the hint is the measured lime on its dark green outline")
	var fish: Fish = _live_fish()[0]
	for other in _live_fish():
		other.fullness = 3000
	fish.fullness = 500
	_expect(level.hint_text() == "", "a fed tank shows no hint")
	fish.fullness = Fish.HUNGER_HINTS[0]
	_expect(level.hint_text() == LevelScript.HINT_TEXT, "the first warning line shows the shallow hint")
	fish.fullness = Fish.HUNGER_HINTS[1]
	_expect(level.hint_text() == LevelScript.HINT_TEXT_SEVERE,
		"the middle line (-200) shows the capitalised hint")
	fish.fullness = Fish.HUNGER_HINTS[2] + 1
	_expect(level.hint_text() == LevelScript.HINT_TEXT_SEVERE,
		"one point above -400 keeps the capitalised hint")
	fish.fullness = Fish.HUNGER_HINTS[2]
	_expect(level.hint_text() == LevelScript.HINT_TEXT_DYING,
		"the last warning line (-400) shows the dying hint")
	# A corpse still in the list is not a hungry fish, and a cleared tank has nothing to warn about.
	fish.dead = true
	_expect(level.hint_text() == "", "a dead fish raises no hint")
	fish.dead = false
	fish.fullness = 500
	for entity in level.tank.entities_in(SimScript.Phase.FISH).duplicate():
		level.tank.despawn(entity)
	_expect(level.hint_text() == "", "a cleared tank shows no hint")


func _test_starting_population() -> void:
	_expect(level.tank != null, "the level builds a tank")
	_expect(_live_fish().size() == LevelScript.STARTING_FISH,
		"the level starts with %d guppies (got %d)" % [LevelScript.STARTING_FISH, _live_fish().size()])
	var fish: Fish = _live_fish()[0]
	_expect(fish != null and fish.species == GUPPY, "the starting fish is a guppy")
	_expect(fish.phase == SimScript.Phase.FISH, "the guppy ticks in the FISH phase")
	_expect(fish.position.x >= LevelScript.SPAWN_MIN.x and fish.position.x <= LevelScript.SPAWN_MAX.x,
		"the spawn x is inside the tank band (%.0f)" % fish.position.x)
	_expect(level.money == LevelScript.STARTING_MONEY,
		"the wallet starts at 200 (SPECS §4.3, got %d)" % level.money)


func _test_feeding() -> void:
	var fish: Fish = _live_fish()[0]
	fish.fullness = 0
	# A pellet at the fish's centre: the eat window is Â±35 px around position + (40, 40).
	var pellet := level.drop_food(fish.position + Vector2(40.0, 40.0))
	_expect(level.tank.food_count() == 1, "drop_food adds one pellet")
	_expect(level.sounds_played.has("SOUND_DROPFOOD"), "the drop requests its sound (P4.13)")
	_expect(pellet.phase == SimScript.Phase.FOOD, "the pellet ticks in the FOOD phase")
	_step(1)
	_expect(fish.fullness >= 490, "a quality-0 pellet feeds 500 (fullness %d)" % fish.fullness)
	_expect(pellet.dead, "the eaten pellet is removed")
	_expect(level.tank.food_count() == 0, "the tank no longer counts the pellet")


func _test_click_routing() -> void:
	_expect(not level.try_collect(Vector2(10.0, 10.0)), "an empty click collects nothing")
	var at := Vector2(200.0, 180.0)
	level.drop_food(at)
	var pellets: Array = []
	for entity in level.tank.entities:
		if entity is Food:
			pellets.append(entity)
	_expect(pellets.size() == 1, "the click path can always drop a pellet")
	_expect((pellets[0] as Food).position == at, "the pellet lands where it was dropped")


func _test_money() -> void:
	level.money = 0
	level.money_earned = 0
	level.add_money(15)
	_expect(level.money == 15, "AddMoney adds 15")
	_expect(level.money_earned == 15, "the level total tracks earnings")
	level.add_money(10_000_000)
	_expect(level.money == LevelScript.MONEY_MAX, "the wallet clamps at 9,999,999")
	level.add_money(-5)
	_expect(level.money == LevelScript.MONEY_MAX, "a non-positive amount is ignored")


## P2.5 Â§2-Â§3: the buy hub's price, cap and refusal rules.
func _test_store() -> void:
	level.food_quantity = 1
	level.store_rows([0, 2, 3, 10, 6])
	_expect(level.tank_store.size() == 5, "store_rows builds the table")
	_expect(int(level.tank_store[0]["price"]) == 100 and int(level.tank_store[2]["price"]) == 300,
		"the rows carry the prices")

	level.money = 100
	var before := _live_fish().size()
	_expect(level.buy_item(0), "a guppy is bought with exactly its price")
	_expect(level.money == 0, "the price is spent")
	_expect(_live_fish().size() == before + 1, "the guppy spawns")

	_expect(not level.buy_item(0), "a purchase without money is refused")
	_expect(_live_fish().size() == before + 1, "the refused purchase spawns nothing")
	_expect(not level.buy_item(99), "an out-of-range row is refused")

	level.money = 300
	_expect(level.buy_item(2), "food quantity upgrades")
	_expect(level.food_quantity == 2 and level.money == 0, "the level rises and the money falls")
	# The weapon row has no recovered price (P2.5 Â§3), so the fixture gives it one.
	level.tank_store[3]["price"] = 300
	level.money = 300
	_expect(level.buy_item(3), "the weapon upgrades")
	_expect(level.weapon_level == 3, "the weapon level rises")
	_expect(level.tank.pet_capacity == 3, "the weapon level is the tank's +0x3E4 field")
	_expect(level.hold_fire_period() == 0, "hold-to-fire is locked below level 12")
	level.weapon_level = 12
	_expect(level.hold_fire_period() == 10, "level 12 fires on the 100 ms floor")
	level.weapon_level = 2

	level.money = 1000
	_expect(level.buy_item(4) == false, "an unimplemented item refuses (Q-0049)")
	_expect(level.money == 1000, "the refusal spends nothing")

	level.food_quantity = LevelScript.FOOD_QUANTITY_MAX
	_expect(not level.buy_item(2), "a capped upgrade refuses")
	_expect(level.money == 1000, "the capped refusal spends nothing")
	level.weapon_level = 2
	level.star_potion_armed = false
	level.store_rows([5])
	level.tank_store[0]["price"] = 500  # same fixture as the weapon row
	level.money = 500
	_expect(level.buy_item(0), "the star potion is bought")
	_expect(level.star_potion_armed, "the potion arms the next drop")
	_expect(not level.buy_item(0), "a second potion is refused while one is armed")
	_expect(level.money == 0, "the refusal spends nothing")
	# A manual drop spends the pellet price (5), so fund the wallet for the two drops below.
	level.money = 500
	var potion := level.drop_food(Vector2(300.0, 250.0))
	_expect(potion != null and potion.quality == 3, "the armed drop is a quality-3 pellet")
	_expect(not level.star_potion_armed, "the flag clears with the drop")
	_expect(level.money == 495, "the drop spends the 5-shell pellet price")
	var plain := level.drop_food(Vector2(320.0, 250.0))
	_expect(plain != null and plain.quality == 0, "the next drop is an ordinary pellet")
	level.store_rows([2])
	level.inflate_prices(10)
	_expect(int(level.tank_store[0]["price"]) == 200, "a zero increment never inflates")
	level.tank_store[0]["increment"] = 3
	level.inflate_prices(10)
	_expect(int(level.tank_store[0]["price"]) == 230, "the increment applies per tick")
	level.inflate_prices(100000)
	_expect(int(level.tank_store[0]["price"]) == Store.PRICE_CLAMP, "the price clamps at 99,999")
	level.tank_store[0]["increment"] = 3
	level.reset_prices()
	_expect(int(level.tank_store[0]["price"]) == 200, "reset_prices restores the base price")
	level.game_mode = level.MODE_CHALLENGE
	_step(5)
	_expect(int(level.tank_store[0]["price"]) == 215, "challenge mode inflates every tick")
	level.game_mode = 0
	_step(5)
	_expect(int(level.tank_store[0]["price"]) == 215, "adventure mode leaves prices alone")
	level.store_rows([])
	# The later scenarios drop freely, so the cap goes back to the maximum.
	level.food_quantity = LevelScript.FOOD_QUANTITY_MAX
	level.stock_default_store()
	_expect(level.tank_store.size() == 1, "tank 1 level 1 stocks the guppy alone (P2.6 Â§3)")
	level.start_level(1, 3)
	var stocked: Array = []
	for row: Dictionary in level.tank_store:
		stocked.append(int(row.get("slot", -1)))
	_expect(stocked == [0, 2, 3, 4, 10], "tank 1 level 3 stocks five items in shelf order")
	var all_sellable := true
	for row: Dictionary in level.tank_store:
		all_sellable = all_sellable and Store.is_available(int(row.get("slot", -1)))
	_expect(all_sellable, "every stocked row can be bought (Q-0052)")

	# The Beetlemuncher (item 8) is the one pet purchase the evidence binds end to end: store item 8
	# -> `FUN_00545080` -> `Sexy::Gekko` (EV-0056), and Gekko = Beetlemuncher (EV-0060). Tank 3
	# sells it from level 2 on, and the purchase spawns a real Gekko body through the fish path.
	level.start_level(3, 2)
	var beeties := _row_of(level, 8)
	_expect(beeties >= 0 and int(level.tank_store[beeties]["price"]) == 2000,
		"3-2 stocks the Beetlemuncher at 2000")
	var fish_before := _live_fish().size()
	level.money = 2500
	_expect(level.buy_item(beeties), "the Beetlemuncher is bought")
	_expect(level.money == 500, "its 2000-shell price is spent")
	var gekkos := 0
	for fish in _live_fish():
		if fish.species == FishScript.Species.GEKKO:
			gekkos += 1
	_expect(gekkos == 1, "the purchase spawns a Gekko body")
	_expect(_live_fish().size() == fish_before + 1, "exactly one fish enters the tank")
	level.money = 2000
	_expect(level.buy_item(beeties), "a second Beetlemuncher can be bought (no cap)")
	# The Guppycruncher beside it is still unbound, so it must keep refusing without charging.
	var crunchers := _row_of(level, 7)
	level.money = 5000
	_expect(crunchers >= 0 and not level.buy_item(crunchers),
		"the Guppycruncher still refuses (Q-0049)")
	_expect(level.money == 5000, "its refusal spends nothing")



## Pets enter with the session (P2.7 Â§2.2): owned flags spawn, unowned ones do not, and every pet has
## a `Content` body sheet so it is drawn (P2.15).
func _test_pet_session() -> void:
	level.tank.shutdown()
	level.spawn_guppy(Vector2(200.0, 200.0))
	var owner := level._profile()
	owner.grant_pet(PetScript.STINKY)
	owner.grant_pet(PetScript.ANGIE)
	_expect(level.spawn_owned_pets() == 2, "two owned pets enter the tank")
	var pets: Array[SimEntity] = level.tank.entities_in(SimScript.Phase.PETS)
	_expect(pets.size() == 2, "the tank holds exactly the owned pets (got %d)" % pets.size())
	var indexes: Array[int] = []
	for entity: SimEntity in pets:
		var pet := entity as Pet
		indexes.append(pet.index)
		_expect(pet.image_id() != "", "pet %d has a body sheet" % pet.index)
		_expect(pet.position.x >= LevelScript.PET_SPAWN_MIN.x and pet.position.x <= LevelScript.PET_SPAWN_MAX.x,
			"pet %d spawns inside the x band (%.0f)" % [pet.index, pet.position.x])
	_expect(indexes.has(PetScript.STINKY) and indexes.has(PetScript.ANGIE), "both owned pets are the spawned ones")


func _test_coin_pickup() -> void:
	level.money = 0
	var coin := level.tank.spawn_coin(1, Vector2(300.0, 300.0))
	_expect(level.tank.coin_count() == 1, "the coin is in the tank")
	var centre := coin.position + Vector2(36.0, 36.0)
	_expect(level.try_collect(centre), "a click on the coin centre picks it up")
	_expect(coin.dead, "the picked-up coin is removed")
	_expect(level.money == 15, "a kind-1 coin is worth 15 (got %d)" % level.money)


func _test_death_and_successor() -> void:
	# Deaths (P2.4 Â§4, EV-0053): the fish leaves an inert corpse that sinks while its own stage
	# counter falls, then detaches **silently**. Nothing spawns a replacement - a starved fish has to
	# be bought again. The live successor belongs to the corpse's revive branch (phase < 1), whose
	# writer is unrecovered (Q-0043), so it must not fire here.
	level.tank.shutdown()
	level.money = 0

	var stage0: Fish = level.spawn_guppy(Vector2(300.0, 200.0), 0)
	# A corpse keeps the fish's own velocity, so pin it still: the sink ramp is what is being checked.
	stage0.vx = 0.0
	stage0.vy = 0.0
	stage0.fullness = -500
	_step(1)
	_expect(stage0.dead, "a starving stage-0 fish dies")
	var corpses := _corpses()
	_expect(corpses.size() == 1, "death leaves a corpse (got %d)" % corpses.size())
	if corpses.size() == 1:
		var corpse: DeadFish = corpses[0]
		_expect(corpse.phase == SimScript.Phase.PARTICLES, "the corpse ticks in the PARTICLES phase")
		_expect(corpse.corpse_id == 0, "the corpse id is the dying fish's stage")
		_expect(corpse.stage <= DeadFishScript.STAGE_START, "and its own counter starts at 125 (EV-0052)")
		var sink_start := corpse.position.y
		var frame_start := corpse.sprite_frame()
		var vy_start := corpse.vy
		_step(10)
		# The spawner subtracts the drift from the fish's vy (EV-0052), so a corpse starts moving up
		# and the +0.05/tick ramp turns it around; the frame walks the sheet meanwhile.
		_expect(corpse.vy > vy_start, "the corpse's vy ramps toward the sink target")
		_expect(corpse.stage < DeadFishScript.STAGE_START, "the stage counter falls as soon as it passes 0x69")
		_expect(corpse.sprite_frame() >= frame_start and corpse.sprite_frame() <= 9,
			"the death frames walk the sheet (frame %d)" % corpse.sprite_frame())
		_step(140)
		_expect(corpse.position.y > sink_start,
			"then it sinks (%.1f -> %.1f)" % [sink_start, corpse.position.y])
	var removed_by := 150  # the ticks already stepped above count toward the fall
	while not _corpses().is_empty() and removed_by < 600:
		_step(1)
		removed_by += 1
	_expect(removed_by > 250 and removed_by < 450,
		"the corpse falls away once its stage counter reaches 0 (took %d ticks)" % removed_by)
	_expect(_live_fish().is_empty() and _corpses().is_empty(),
		"the corpse is removed silently and leaves no successor")

	# The same for a grown fish: the corpse id follows the stage, and still no free replacement.
	var grown: Fish = level.spawn_guppy(Vector2(320.0, 220.0), 2)
	grown.fullness = -500
	_step(1)
	var corpses2 := _corpses()
	_expect(corpses2.size() == 1, "the stage-2 death leaves a corpse")
	_expect(not corpses2.is_empty() and (corpses2[0] as DeadFish).corpse_id == 2,
		"its corpse id is the fish's stage")
	var guard := 0
	while not _corpses().is_empty() and guard < 400:
		_step(1)
		guard += 1
	_expect(_corpses().is_empty(), "the corpse eventually falls away")
	_expect(_live_fish().is_empty(), "and no live successor is spawned (got %d)" % _live_fish().size())
	_expect(guard > 250 and guard < 460, "it takes the same fall to disappear (got %d)" % guard)


## SPECS Â§3.5: level 12 holds fire every `hold_fire_period()` ticks, re-testing missiles then aliens.
## The pellet draws the simulation's own frame counter, ten ticks per sheet frame.
## The swim strip speeds up with the fish, and never leaves its clamp (presentation-only rule).
func _test_fish_animation_speed() -> void:
	# The swim column is a function of the tick, not a wall clock, and each fish starts its own
	# column when it spawns - two fish no longer paddle in step (Q-0057 records the cadence).
	_expect(AnimState.column_at(0, 0, 10) == 0, "a fresh fish starts on column 0")
	_expect(AnimState.column_at(0, AnimState.SHEET_FRAME_TICKS, 10) == 1, "one frame per SHEET_FRAME_TICKS")
	_expect(AnimState.column_at(0, AnimState.SHEET_FRAME_TICKS - 1, 10) == 0, "and holds until then")
	_expect(AnimState.column_at(0, AnimState.SHEET_FRAME_TICKS * 10, 10) == 0, "the column wraps at 10")
	_expect(AnimState.column_at(100, 100, 10) == 0, "playback starts at the spawn tick")
	_expect(AnimState.column_at(0, 120, 10) != AnimState.column_at(40, 120, 10), "two spawns are out of step")
	_expect(AnimState.column_at(0, 50, 1) == 0, "a one-column sheet never advances")


func _test_food_animation() -> void:
	level.tank.shutdown()
	level.money = 200
	var pellet := level.drop_food(Vector2(300.0, 200.0))
	_expect(pellet != null, "a pellet is dropped")
	if pellet == null:
		return
	pellet.anim_frame = 0
	pellet.anim_cycle = 3
	_expect(level._food_frame(pellet) == 0, "frame 0 starts the pellet animation")
	pellet.anim_frame = 2
	_expect(level._food_frame(pellet) == 0, "a column lasts anim_cycle ticks, so tick 2 is still column 0")
	pellet.anim_frame = 3
	_expect(level._food_frame(pellet) == 1, "tick 3 starts column 1 (D-0024)")
	pellet.anim_frame = 25
	_expect(level._food_frame(pellet) == 8, "25 ticks over three-tick columns is column 8")
	pellet.anim_frame = 29
	_expect(level._food_frame(pellet) == 9 and pellet.anim_frame < 30,
		"cycle 3 wraps at 29, so the last column drawn is 9")
	pellet.anim_frame = 0
	pellet.quality = 3
	_expect(level._food_frame(pellet) == 30, "a star-potion pellet draws the flask row (Q-0051)")
	pellet.variant = 2
	_expect(level._food_frame(pellet) == 40, "a breeding pellet draws the droplet row (Q-0051)")
	pellet.variant = 0
	pellet.quality = 0
	level.tank.shutdown()


func _test_hold_fire() -> void:
	level.tank.shutdown()
	var alien := level.tank.spawn_alien(0x01, Vector2(200.0, 250.0))
	level.alien_selection = 0
	var target := alien.position + Vector2(40.0, 40.0)
	level.fire_target = target
	level.holding_fire = true
	level.weapon_level = 2
	var hp := alien.hp
	_step(10)
	_expect(alien.hp == hp, "below level 12 a held button fires nothing")
	level.weapon_level = 12
	var shot := int(level.tank.shot_damage())
	_step(10)
	_expect(alien.hp == hp - shot, "level 12 fires once in the first ten ticks (got %d)" % (hp - alien.hp))
	_step(10)
	_expect(alien.hp == hp - shot * 2, "the next shot waits for the 100 ms floor")
	var other := level.tank.spawn_alien(0x01, Vector2(420.0, 300.0))
	level.aim(other.position + Vector2(40.0, 40.0))
	var other_hp := other.hp
	_step(10)
	_expect(other.hp == other_hp - shot, "held fire follows the new aim point")
	_expect(alien.hp == hp - shot * 2, "the old target stops taking hits")
	level.holding_fire = false
	_step(20)
	_expect(other.hp == other_hp - shot, "releasing stops the fire")
	level.weapon_level = 2
	level.tank.shutdown()


func _test_pause() -> void:
	level.tank.shutdown()
	var fish: Fish = level.spawn_guppy(Vector2(300.0, 200.0))
	fish.fullness = 500
	level.tank.paused = true
	_step(5)
	_expect(fish.fullness == 500, "the level pause gate freezes hunger")
	level.tank.paused = false
	_step(1)
	_expect(fish.fullness == 499, "unpausing resumes hunger (got %d)" % fish.fullness)
	# The production gate is `Tank.pause_source` (Game). Both the entities and Level's own clock
	# must freeze: `_on_sim_tick` used to advance age/particles/time-trial behind every modal.
	var source := PauseSource.new()
	level.tank.pause_source = source
	source.gameplay_paused = true
	var paused_age: int = level.tank.age_ticks
	_step(5)
	_expect(level.tank.age_ticks == paused_age, "the shared pause gate freezes the level clock")
	_expect(fish.fullness == 499, "the shared pause gate freezes hunger")
	source.gameplay_paused = false
	_step(1)
	_expect(level.tank.age_ticks == paused_age + 1, "clearing the shared pause resumes the level clock")
	_expect(fish.fullness == 498, "clearing the shared pause resumes hunger (got %d)" % fish.fullness)
	level.tank.pause_source = null
	source.free()


func _test_wave_spawn() -> void:
	level.tank.shutdown()
	# The production start arms the clock from the level's own table (P2.6 Â§8): tank 1 level 3 is
	# kind 2, with no `arm_wave` call from the test.
	level.start_level(1, 3)
	_step(WaveClockScript.WAVE_TICKS)
	_expect(level.tank.alien_count() == 1, "a completed wave spawns one alien")
	_expect(level.tank.aliens_present, "the level flags aliens as present")
	if level.tank.alien_count() == 1:
		var alien: Alien = level.tank.entities_in(SimPhaseALIENS())[0] as Alien
		_expect(alien.kind == 2, "the production wave uses the level's selection")
	# Composite recipes compose their member kinds at the one rolled point (P2.8 Â§4).
	level.tank.shutdown()
	level.arm_wave(0x09)
	_step(WaveClockScript.WAVE_TICKS)
	var kinds: Array[int] = []
	for entity: SimEntity in level.tank.entities_in(SimPhaseALIENS()):
		kinds.append((entity as Alien).kind)
	_expect(level.tank.alien_count() == 2 and kinds.has(1) and kinds.has(3), "0x09 composes kinds 1 and 3")
	level.arm_wave(0)


func _test_shooting() -> void:
	level.tank.shutdown()
	var alien: Alien = level.tank.spawn_alien(0x01, Vector2(300.0, 200.0))
	level.wire_alien(alien)
	_expect(not level.try_shoot(Vector2(500.0, 200.0)), "a click away from an alien misses")
	_expect(level.try_shoot(Vector2(320.0, 220.0)), "a click inside the 80x80 box hits")
	_expect(alien.hp == 44, "a shot does 3 * weapon_level = 6 (hp %d)" % alien.hp)

	var destructor: Alien = level.tank.spawn_alien(0x05, Vector2(260.0, 260.0))
	level.wire_alien(destructor)
	alien.position = Vector2(50.0, 100.0)
	level.spawn_guppy(Vector2(500.0, 350.0))
	_step(AlienScript.INTRO_TICKS + AlienScript.MISSILE_PERIOD)
	_expect(level.tank.projectile_count() == 1, "an attack request spawns a projectile")
	if level.tank.projectile_count() == 1:
		var shot: Projectile = level.tank.entities_in(SimPhasePROJECTILES())[0] as Projectile
		_step(16)
		_expect(level.try_hit_projectile(shot.position), "a mature missile can be clicked")
		_expect(shot.dead, "the clicked missile is destroyed")


func _test_alien_eating() -> void:
	level.tank.shutdown()
	var alien: Alien = level.tank.spawn_alien(0x01, Vector2(300.0, 200.0))
	level.wire_alien(alien)
	var fish: Fish = level.spawn_guppy(Vector2(330.0, 230.0))
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(fish.dead, "an alien eats a fish in reach")
	_expect(_corpses().size() == 1, "the eaten fish leaves a corpse")


func SimPhaseALIENS() -> int:
	return SimScript.Phase.ALIENS


func SimPhasePROJECTILES() -> int:
	return SimScript.Phase.PROJECTILES


# --- helpers -----------------------------------------------------------------

## P2.3 Â§2: at most `food_quantity` non-special pellets; specials are exempt.
func _test_food_cap() -> void:
	level.tank.shutdown()
	level.money = 200
	level.food_quantity = 1
	var first := level.drop_food(Vector2(200.0, 250.0))
	_expect(first != null, "the first pellet of a level-1 tank drops")
	_expect(level.drop_food(Vector2(220.0, 250.0)) == null, "the second pellet is refused at quantity 1")
	_expect(level.non_special_food() == 1, "the refused drop leaves one pellet")
	level.tank.despawn(first)
	var second := level.drop_food(Vector2(220.0, 250.0))
	_expect(second != null, "a free slot allows a drop again")
	var special: Food = FoodScript.create(Vector2(300.0, 250.0), 0, false, 1, 0, level.tank.rng)
	level.tank.spawn_at(special, SimScript.Phase.FOOD, special.position)
	_expect(level.non_special_food() == 1, "a special pellet is not counted by the cap")
	_expect(level.drop_food(Vector2(320.0, 250.0)) == null,
		"the special does not free a normal slot")
	level.tank.despawn(second)
	_expect(level.drop_food(Vector2(320.0, 250.0)) != null,
		"only the special is left, so the cap does not block")
	level.food_quantity = LevelScript.FOOD_QUANTITY_MAX


## D-0014: the port-only debug dispatcher, isolated on its own level so the egg completion cannot
## disturb the play-loop scenarios above.
func _test_debug_actions() -> void:
	var debug_sim: Node = SimScript.new()
	var debug_level: Level = LevelScript.new()
	debug_level.render = false
	debug_level.setup(debug_sim, 7777)
	debug_level.start_level(1, 3)

	debug_level.money = 0
	_expect(debug_level.debug_action(&"money"), "the debug panel's money action runs")
	_expect(debug_level.money == LevelScript.DEBUG_MONEY_STEP,
		"the money cheat adds its step through AddMoney (got %d)" % debug_level.money)
	_expect(not debug_level.debug_action(&"unknown"), "an unknown debug action changes nothing")

	var fish: Fish = null
	for entity in debug_level.tank.entities_in(SimScript.Phase.FISH):
		if entity is Fish and not entity.dead:
			fish = entity
			break
	_expect(fish != null, "the debug level has a live fish to grow")
	if fish != null:
		fish.stage = 0
		fish.food_points = 0
		debug_level.sounds_played.clear()
		_expect(debug_level.debug_action(&"grow"), "the grow action advances a stage-0 fish")
		_expect(fish.stage == 1 and fish.food_points == 0,
			"the guppy reaches stage 1 through the natural growth tail (got %d)" % fish.stage)
		_expect(debug_level.sounds_played.has("SOUND_GROW"),
			"debug growth still fires the grew cue")
		fish.stage = 2
		_expect(fish.debug_grow() and fish.stage == 4,
			"a stage-2 fish takes the natural overshoot form")
		_expect(not fish.debug_grow(), "a stage-4 fish refuses another growth step")
		fish.fullness = 0
		_expect(debug_level.debug_action(&"feed"), "the feed action fills the fish")
		_expect(fish.fullness == int(FishScript.SPECIES[fish.species]["eat_cap"]),
			"the fish reaches its species' eat cap (got %d)" % fish.fullness)
		_expect(not debug_level.debug_action(&"feed"), "a full tank refuses another feeding")

	# D-0019: the bar opens with the level's whole stock, so the reveal action has nothing to add on a
	# level that hides nothing (1-3) and reports no change.
	_expect(not debug_level.tank.store_locked and not debug_level.tank_store.is_empty(),
		"1-3 opens with its whole stock on the bar")
	_expect(debug_level.egg_price == 2000, "and the egg dome already priced")
	_expect(not debug_level.debug_action(&"reveal"),
		"the reveal action reports no change where the level hides nothing")

	# D-0018: NEXT LEVEL walks the profile on and asks its owner to restart (no award cards).
	var skips := []
	debug_level.skip_level_requested.connect(func() -> void: skips.append(true))
	var profile_level := int(debug_level._profile().level)
	_expect(debug_level.debug_action(&"next_level"), "the next-level action is dispatched")
	_expect(int(debug_level._profile().level) == profile_level + 1,
		"next level moves the profile on by one (got %d)" % int(debug_level._profile().level))
	_expect(skips.size() == 1, "and asks its owner to restart the level")

	debug_level.weapon_level = 2
	_expect(debug_level.debug_action(&"weapon") and debug_level.weapon_level == Store.WEAPON_MAX,
		"the weapon cheat jumps to level 12")
	_expect(not debug_level.debug_action(&"weapon"), "a maxed weapon refuses another jump")

	var guppies: int = debug_level.tank.entities_in(SimScript.Phase.FISH).size()
	_expect(debug_level.debug_action(&"guppy"), "the spawn cheat adds a guppy")
	_expect(debug_level.tank.entities_in(SimScript.Phase.FISH).size() == guppies + 1,
		"the spawned guppy joins the FISH phase")

	debug_level.egg_pieces = 1
	_expect(debug_level.debug_action(&"egg"), "the egg cheat buys a piece for free")
	_expect(debug_level.egg_pieces == 2, "the piece count rises to 2")
	debug_level.debug_action(&"egg")
	_expect(debug_level.debug_action(&"egg"), "the fourth piece completes the level")
	_expect(debug_level.egg_pieces == 4 and debug_level.completed,
		"the egg cheat reaches the normal completion path")
	_expect(not debug_level.debug_action(&"egg"), "a completed level refuses more egg pieces")

	var menu_hits := []
	var on_menu := func() -> void: menu_hits.append(true)
	debug_level.menu_requested.connect(on_menu)
	debug_level.request_menu()
	_expect(menu_hits.size() == 1, "the MENU request reaches Main's handler")
	debug_level.menu_requested.disconnect(on_menu)
	_expect(not debug_level.toggle_debug_panel(),
		"a render=false level has no debug panel to toggle")

	debug_level.tank.shutdown()
	debug_level.free()
	debug_sim.free()


func _live_fish() -> Array:
	var found: Array = []
	for entity in level.tank.entities:
		if entity is Fish and not entity.dead:
			found.append(entity)
	return found


func _corpses() -> Array:
	var found: Array = []
	for entity in level.tank.entities:
		if entity is DeadFish and not entity.dead:
			found.append(entity)
	return found


func _step(count: int) -> void:
	sim.flush_backlog()
	for i in count:
		sim.advance(SimScript.TICK_MS)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)

