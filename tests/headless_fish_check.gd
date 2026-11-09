extends SceneTree
## Headless check for the Fish entity (P4.3).
##
##   & "<godot>" --headless --path . --script res://tests/headless_fish_check.gd
##
## Covers the ctor tuning (P2.4 §1-§3), hunger/death (P2.3 §5), the swim machine including the
## default modes >= 5 (P2.2 §5.3), food approach/eat/acceptance (P2.2 §5.5, P2.3 §7), nutrition and
## the shared growth tail (P2.3 §7.5), the star potion and breeding pellet, and the coin scheduler
## (P2.3 §8, P2.4 §6). No rendering/audio: those are P4.4/P4.13.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const FoodScript := preload("res://scripts/entities/food.gd")

const GUPPY := FishScript.Species.GUPPY
const OSCAR := FishScript.Species.OSCAR
const ULTRA := FishScript.Species.ULTRA
const GEKKO := FishScript.Species.GEKKO
const SYLVESTER := FishScript.Species.MINISYLVESTER
const BALL := FishScript.Species.BALL
const BI := FishScript.Species.BILATERUS

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 424242)

	_test_spawn_defaults()
	_test_hunger_and_death()
	_test_swim_machine()
	_test_food_approach_and_eating()
	_test_acceptance()
	_test_nutrition_and_growth()
	_test_star_and_breeding()
	_test_coin_scheduler()
	_test_species_defaults()
	_test_state_round_trip()
	_test_rng_reproducibility()
	_test_hungry_art()
	_test_sprite_binding()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_fish_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_fish_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


# --- scenarios ---------------------------------------------------------------

func _test_spawn_defaults() -> void:
	tank.shutdown()
	tank.set_seed(100)
	var fish: Fish = tank.spawn_fish(GUPPY, Vector2(300.0, 200.0), -1, 1)
	_expect(fish.species == GUPPY and fish.stage == 0, "guppy spawns at species 0 / stage 0")
	_expect(fish.phase == SimScript.Phase.FISH, "spawn_fish assigns the FISH phase")
	_expect(tank.layer_for(SimScript.Phase.FISH).get_child_count() == 1, "fish is parented to the fish layer")
	_expect(fish.fullness >= 400 and fish.fullness <= 599, "hunger starts 400..599 (got %d)" % fish.fullness)
	_expect(fish.food_needed >= 4 and fish.food_needed <= 6, "growth threshold starts 4..6 (got %d)" % fish.food_needed)
	_expect(fish.speed_divisor in FishScript.SPEED_CLASSES, "speed divisor is one of 2.0/1.8/1.6")
	_expect(fish.min_x == 10.0 and fish.min_y == 95.0 and fish.max_x == 540.0 and fish.max_y == 370.0,
		"common ctor bounds are 10..540 x 95..370")
	_expect(fish.can_seek, "a guppy can seek food")
	_expect(fish.facing == 1 and not fish.flip, "forced facing 1 is not flipped")
	_expect(fish.coin_threshold >= 150 and fish.coin_threshold <= 349,
		"guppy coin threshold starts 150..349 (got %d)" % fish.coin_threshold)
	_expect(fish.swim_mode >= 0 and fish.swim_mode <= 9, "initial swim mode is rand%10")
	_expect(fish.mode_timer == FishScript.MODE_TIMER_START, "mode timer starts at 40")
	_expect(fish.sprite_row() == 0, "stage 0 draws row 0")
	fish.stage = 3
	_expect(fish.sprite_row() == 2, "stage 3 folds to row 2")
	fish.stage = 4
	_expect(fish.sprite_row() == 3, "stage 4 folds to row 3")


func _test_hunger_and_death() -> void:
	tank.shutdown()
	tank.set_seed(101)
	var fish: Fish = _quiet_fish(Vector2(300.0, 200.0))
	fish.fullness = 500
	_step(10)
	_expect(fish.fullness == 490, "hunger drops 1/tick (500 -> %d)" % fish.fullness)

	# The floor is only reachable on the death tick: -999 decays to -1000 and dies.
	var floor_died: Array = []
	fish.died.connect(func(_f) -> void: floor_died.append(true))
	fish.fullness = -999
	_step(1)
	_expect(fish.fullness == FishScript.HUNGER_FLOOR and fish.dead,
		"hunger clamps at -1000 and dies below -499")
	_expect(floor_died.size() == 1, "the die path emits died once")

	# Hints fire once per starvation episode, in level order.
	var hungry: Fish = _quiet_fish(Vector2(300.0, 200.0))
	var warnings: Array = []
	hungry.hunger_warning.connect(func(level: int) -> void: warnings.append(level))
	hungry.fullness = 0
	_step(1)
	hungry.fullness = -199
	_step(1)
	hungry.fullness = -399
	_step(1)
	_expect(warnings == [1, 2, 3], "hints fire at -1/-200/-400, got %s" % [warnings])

	# Death is terminal for the fish: it reports it once and leaves the corpse to the level.
	var deaths: Array = []
	hungry.died.connect(func(_f) -> void: deaths.append(true))
	hungry.fullness = -499
	_step(1)
	_expect(hungry.dead, "hunger below -499 kills the fish")
	_expect(deaths.size() == 1, "the death is reported once")
	_expect(not tank.entities.has(hungry), "a dead fish leaves the tank")


func _test_swim_machine() -> void:
	tank.shutdown()
	tank.set_seed(102)
	var fish: Fish = _quiet_fish(Vector2(300.0, 200.0))
	fish.speed_divisor = 2.0

	# Mode 0: vy +0.5, glide 0.25, and the vx==0 sink ladder adds 1.0 before integration.
	_set_swim(fish, 0, 0)
	fish.vx = 0.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vy == 0.5, "mode 0 sets vy +0.5")
	_expect(is_equal_approx(fish.position.y, 200.625), "mode 0 net y = 200.625 (got %.3f)" % fish.position.y)

	# Modes 1/2: the -8 dash.
	_set_swim(fish, 1, 0)
	fish.position = Vector2(300.0, 200.0)
	fish.vx = 0.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vy == -8.0, "mode 1 dashes to vy -8")
	_expect(is_equal_approx(fish.position.y, 196.25), "mode 1 net y = 196.25 (got %.3f)" % fish.position.y)

	_set_swim(fish, 2, 0)
	fish.position = Vector2(300.0, 200.0)
	fish.vx = 0.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vy == -8.0, "mode 2 dashes to vy -8")

	# Modes 3/4: the 40-tick cruise steps.
	_set_swim(fish, 3, 40)
	fish.vx = 0.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vx == -1.0 and fish.vy == 1.0, "mode 3 steps vx to -1 and vy to +1")
	_set_swim(fish, 4, 40)
	fish.vx = 0.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vx == 1.0, "mode 4 steps vx to +1")
	_set_swim(fish, 3, 0)
	fish.position.y = 250.0
	_step(1)
	_expect(fish.swim_mode == 0, "modes 3/4 fall back to mode 0 above y 240")

	# Modes >= 5: the decompiler's else branch (slow rise + 175/250 zigzag).
	_set_swim(fish, 5, 40)
	fish.position = Vector2(200.0, 200.0)
	fish.vx = 0.0
	fish.vy = 0.0
	fish.turn_dir = 1
	_step(1)
	_expect(fish.vy == -0.5 and fish.vx == 1.0 and fish.turn_dir == 1,
		"hover (y>=115) rises at -0.5 and moves right")
	_set_swim(fish, 5, 40)
	fish.position = Vector2(260.0, 200.0)
	fish.vx = 0.0
	fish.turn_dir = 1
	_step(1)
	_expect(fish.turn_dir == -1 and fish.vx == -1.0, "hover turns left past x 250")
	_set_swim(fish, 5, 40)
	fish.position = Vector2(300.0, 100.0)
	fish.vy = 0.0
	_step(1)
	_expect(fish.vy == -0.1, "hover above y 115 rises at the slow -0.1")

	# Mode 0x7B: drag after 30 ticks and a wall flip after 50.
	_set_swim(fish, 0x7B, 31)
	fish.position = Vector2(300.0, 200.0)
	fish.vx = 3.0
	fish.vy = 3.0
	_step(1)
	_expect(is_equal_approx(fish.vx, 2.85) and is_equal_approx(fish.vy, 2.85),
		"drift drags vx/vy by 0.95 after 30 ticks")
	_set_swim(fish, 0x7B, 51)
	fish.position = Vector2(530.0, 200.0)
	fish.vx = 3.0
	fish.vy = 0.0
	_step(1)
	_expect(fish.vx < 0.0, "drift flips vx at the right margin")
	_expect(fish.swim_mode >= 1 and fish.swim_mode <= 9, "drift re-rolls to 1..9")

	# The 20-tick random switch timer always resets; the 10% roll may keep the mode.
	_set_swim(fish, 0, 0)
	fish.random_timer = FishScript.RANDOM_SWITCH_TICKS
	_step(1)
	_expect(fish.random_timer == 0, "the random-switch timer resets after 20 ticks")


func _test_food_approach_and_eating() -> void:
	tank.shutdown()
	tank.set_seed(103)
	var fish: Fish = _quiet_fish(Vector2(200.0, 200.0), -1, 300)
	fish.speed_divisor = 2.0
	fish.vx = 0.0
	fish.vy = 0.0
	var pellet: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(is_equal_approx(fish.vx, 1.3), "approach adds +1.3 for a far pellet (x)")
	_expect(is_equal_approx(fish.vy, -1.0), "approach adds -1.0 for a pellet below")
	_step(1)
	_expect(is_equal_approx(fish.vx, 2.6), "the same band adds again next tick")
	_expect(is_equal_approx(fish.vy, -2.0), "vy falls another 1.0")
	_step(1)
	_expect(is_equal_approx(fish.vy, -3.0), "vy clamps at -3")

	# The eat window: fish center at the pellet consumes it.
	tank.shutdown()
	tank.set_seed(104)
	fish = _quiet_fish(Vector2(360.0, 160.0), -1, 0)
	pellet = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(pellet.dead, "a pellet inside the 35 px window is consumed")
	_expect(fish.fullness == 499, "quality 0 adds +500 after the hunger tick (got %d)" % fish.fullness)
	_expect(fish.food_points == 1, "quality 0 awards 1 food point")
	_expect(fish.eat_fx_timer == 8, "eating starts the 8-tick eat-fx timer")

	# Cap: a fish stops seeking at 500, so the cap is observed from just below it.
	tank.shutdown()
	tank.set_seed(1041)
	var capped: Fish = _quiet_fish(Vector2(360.0, 160.0), -1, 499)
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(capped.fullness == 800, "quality 0 caps at 800 (got %d)" % capped.fullness)


func _test_acceptance() -> void:
	tank.shutdown()
	tank.set_seed(105)
	var fish: Fish = _quiet_fish(Vector2(360.0, 160.0), -1, 300)

	var homing: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	homing.homing = true
	_step(1)
	_expect(not homing.dead, "a homing pellet is not accepted")
	homing.despawn()

	var inedible: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	inedible.inedible = 5
	_step(1)
	_expect(not inedible.dead, "an inedible pellet is not accepted")
	inedible.despawn()

	var variant_one: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0, 1)
	_step(1)
	_expect(not variant_one.dead, "variant 1 (non-breeding special) is not accepted")
	variant_one.despawn()

	# A breeding pellet needs the pre-stage-3 and fullness < 108 gate (P2.3 §7.4).
	tank.shutdown()
	tank.set_seed(1051)
	var small: Fish = _quiet_fish(Vector2(360.0, 160.0), 0, 50)
	var breed_requested: Array = []
	small.breed_requested.connect(func(species, _at, _fa) -> void: breed_requested.append(species))
	var breeding: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0, 2)
	breeding.inedible = 0
	_step(1)
	_expect(breeding.dead, "a pre-stage-3 fish consumes a breeding pellet")
	_expect(breed_requested == [GUPPY], "the breeding pellet requests a new guppy")
	_expect(small.fullness == 49, "the breeding pellet adds no nutrition (got %d)" % small.fullness)

	tank.shutdown()
	tank.set_seed(1052)
	var full: Fish = _quiet_fish(Vector2(360.0, 160.0), 0, 109)
	var breeding_two: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0, 2)
	breeding_two.inedible = 0
	_step(1)
	_expect(not breeding_two.dead, "a fish at fullness 109 rejects a breeding pellet")
	breeding_two.despawn()

	tank.shutdown()
	tank.set_seed(1053)
	var grown: Fish = _quiet_fish(Vector2(360.0, 160.0), 3, 50)
	var breeding_three: Food = _spawn_food(Vector2(400.0, 200.0), 0, 0, 0, 2)
	breeding_three.inedible = 0
	_step(1)
	_expect(not breeding_three.dead, "a stage-3 fish rejects a breeding pellet")


func _test_nutrition_and_growth() -> void:
	# Quality table on a guppy.
	_expect(_eat_value(GUPPY, 0, 0, -1) == 499, "guppy quality 0 -> 499")
	_expect(_eat_value(GUPPY, 1, 0, -1) == 699, "guppy quality 1 -> 699")
	_expect(_eat_value(GUPPY, 2, 0, -1) == 1099, "guppy quality 2 -> 1099")
	_expect(_eat_value(OSCAR, 0, 0, -1) == 899, "carnivore +900 cap 1300 -> 899")
	_expect(_eat_value(ULTRA, 0, 0, -1) == 899, "ultravore +900 cap 1300 -> 899")
	_expect(_eat_value(GEKKO, 0, 0, -1) == 699, "beetlemuncher +700 cap 1000 -> 699")
	_expect(_eat_value(SYLVESTER, 0, 0, -1) == 699, "minisylvester +700 cap 1000 -> 699")
	_expect(_eat_value(BALL, 0, 0, -1) == 699, "ball fish +700 cap 1000 -> 699")
	_expect(_eat_value(BI, 0, 0, -1) == 699, "bilaterus +700 cap 1000 -> 699")

	tank.shutdown()
	tank.set_seed(106)
	var fish: Fish = _quiet_fish(Vector2(360.0, 160.0), 0, 0)
	fish.food_needed = 4
	fish.food_points = 3
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(fish.stage == 1 and fish.food_points == 0, "points >= threshold grows 0 -> 1 and resets points")
	_expect(fish.grow_timer == FishScript.GROW_POP_TICKS, "a stage-up starts the 10-tick grow pop")

	# Stage 2 + huge overshoot -> stage 4 (the second `if`, not an else).
	tank.shutdown()
	tank.set_seed(1061)
	var fat: Fish = _quiet_fish(Vector2(360.0, 160.0), 2, 0)
	fat.food_needed = 4
	fat.food_points = 15 * 4 - 1
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 2)
	_step(1)
	_expect(fat.stage == 4, "15 x threshold overshoot at stage 2 -> stage 4")

	# Sylvester's stage 1 -> 2 is the 160x160 form with the shifted position.
	tank.shutdown()
	tank.set_seed(1062)
	var syl: Fish = _quiet_fish(Vector2(360.0, 160.0), 1, 0, SYLVESTER)
	syl.food_needed = 4
	syl.food_points = 3
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(syl.stage == 2 and syl.sprite_box == 160, "minisylvester grows to the 160x160 form")
	_expect(syl.min_x == 0.0 and syl.max_y == 310.0, "the big form uses 0..480 x 75..310")
	_expect(syl.position.x < 330.0, "the big-form position shifts left by 40 px (%.1f)" % syl.position.x)

	tank.shutdown()
	tank.set_seed(1063)
	var ball: Fish = _quiet_fish(Vector2(360.0, 160.0), 0, 0, BALL)
	ball.food_needed = 4
	ball.food_points = 3
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 0)
	_step(1)
	_expect(ball.stage == 1 and ball.sprite_box == 50, "ball fish grows in place without a size change")


func _test_star_and_breeding() -> void:
	tank.shutdown()
	tank.set_seed(107)
	var tiny: Fish = _quiet_fish(Vector2(360.0, 160.0), 0, 0)
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 3)
	_step(1)
	_expect(tiny.dead, "a star potion kills a stage-0 guppy")

	tank.shutdown()
	tank.set_seed(1071)
	var medium: Fish = _quiet_fish(Vector2(360.0, 160.0), 1, 0)
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 3)
	_step(1)
	_expect(medium.dead, "a star potion kills a stage-1 guppy")

	tank.shutdown()
	tank.set_seed(1072)
	var big: Fish = _quiet_fish(Vector2(360.0, 160.0), 2, 0)
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 3)
	_step(1)
	_expect(not big.dead and big.stage == 3, "a star potion promotes stage 2 to stage 3")
	_expect(big.fullness == 1099, "the star potion adds +1100 (got %d)" % big.fullness)

	tank.shutdown()
	tank.set_seed(1073)
	var older: Fish = _quiet_fish(Vector2(360.0, 160.0), 3, 0)
	_spawn_food(Vector2(400.0, 200.0), 0, 0, 3)
	_step(1)
	_expect(not older.dead and older.stage == 3 and older.fullness == 1099,
		"a stage-3 guppy just gets the +1100 feed")


func _test_coin_scheduler() -> void:
	tank.shutdown()
	tank.set_seed(108)
	var baby: Fish = _quiet_fish(Vector2(300.0, 200.0), 0, 800)
	baby.coin_threshold = 1
	_step(3)
	_expect(baby.coin_counter == 0, "stage 0 never advances the coin counter")

	var adult: Fish = _quiet_fish(Vector2(300.0, 200.0), 1, 800)
	adult.coin_threshold = 5
	_step(1)
	_expect(adult.coin_counter == 1, "stage 1 starts counting")
	var drops: Array = []
	adult.coin_due.connect(func(_f) -> void: drops.append(true))
	adult.coin_counter = 4
	_step(1)
	_expect(drops.size() == 1 and adult.coin_counter == 0,
		"counter >= threshold drops a coin and resets")

	# Food suppresses slot 81 (`FUN_004DA780` is the pending-object predicate).
	var fed: Fish = _quiet_fish(Vector2(300.0, 200.0), 1, 800)
	fed.coin_threshold = 1
	fed.coin_counter = 1
	var fed_drops: Array = []
	fed.coin_due.connect(func(_f) -> void: fed_drops.append(true))
	var meal: Food = _spawn_food(Vector2(500.0, 100.0), 0, 0, 0)
	_step(1)
	_expect(fed_drops.is_empty(), "a pellet in the tank suppresses the coin drop")
	meal.despawn()
	_step(1)
	_expect(fed_drops.size() == 1, "removing the pellet lets the next tick drop")


func _test_species_defaults() -> void:
	tank.shutdown()
	tank.set_seed(109)
	var oscar: Fish = tank.spawn_fish(OSCAR, Vector2(300.0, 200.0))
	_expect(oscar.stage == 5 and not oscar.can_seek, "carnivore starts at stage 5 and cannot seek pellets")
	_expect(oscar.fullness >= 600 and oscar.fullness <= 799, "carnivore hunger starts 600..799")
	_expect(oscar.min_y == 105.0 and oscar.max_y == 360.0, "carnivore band is 105..360")

	var ultra: Fish = tank.spawn_fish(ULTRA, Vector2(300.0, 200.0))
	_expect(ultra.stage == 6 and ultra.sprite_box == 160, "ultravore starts at stage 6 with a 160x160 box")
	_expect(ultra.min_x == 0.0 and ultra.min_y == 75.0 and ultra.max_x == 480.0 and ultra.max_y == 310.0,
		"ultravore band is 0..480 x 75..310")
	_expect(ultra.fullness >= 600 and ultra.fullness <= 799, "ultravore hunger starts 600..799")

	var gekko: Fish = tank.spawn_fish(GEKKO, Vector2(300.0, 200.0))
	_expect(gekko.stage == 7 and not gekko.can_seek, "beetlemuncher starts at stage 7 and cannot seek")

	var syl: Fish = tank.spawn_fish(SYLVESTER, Vector2(300.0, 200.0))
	_expect(syl.stage == 1, "minisylvester starts at stage 1")

	var ball: Fish = tank.spawn_fish(BALL, Vector2(300.0, 200.0))
	_expect(ball.stage == 0 and ball.sprite_box == 50, "ball fish starts at stage 0 with a 50x50 box")

	var bi: Fish = tank.spawn_fish(BI, Vector2(300.0, 200.0))
	_expect(bi.stage == 0 and bi.sprite_box == 80, "bilaterus starts at stage 0 with an 80x80 box")


## P2.13 note #11: fish keep their tier, position and hunger; coins/food are rebuilt on load.
func _test_state_round_trip() -> void:
	tank.shutdown()
	var fish: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(200.0, 250.0), 1, -1)
	fish.fullness = 123
	fish.food_points = 2
	var state := fish.to_state()
	_expect(int(state["species"]) == FishScript.Species.GUPPY, "the record carries the species")
	_expect(int(state["stage"]) == 1, "the record carries the stage")
	_expect(not state.has("coins") and not state.has("food"), "the record leaves out rebuildable state")
	tank.despawn(fish)
	var restored: Fish = FishScript.from_state(tank, state)
	_expect(restored != null, "the state rebuilds a fish")
	if restored == null:
		return
	_expect(restored.phase == SimScript.Phase.FISH, "the rebuilt fish is in the FISH phase")
	_expect(restored.position == Vector2(200.0, 250.0), "the position survives")
	_expect(restored.stage == 1 and restored.fullness == 123 and restored.food_points == 2,
		"the stage, hunger and growth points survive")
	_expect(restored.facing == -1, "the facing survives")
	_expect(restored.to_state() == state, "the record is stable across the round trip")


func _test_rng_reproducibility() -> void:
	var a: Tank = TankScript.new()
	var b: Tank = TankScript.new()
	a.setup(sim, 777)
	b.setup(sim, 777)
	var fa: Fish = FishScript.create(GUPPY, Vector2(300.0, 200.0), a.rng, -1, 1)
	var fb: Fish = FishScript.create(GUPPY, Vector2(300.0, 200.0), b.rng, -1, 1)
	_expect(
		fa.fullness == fb.fullness
		and fa.speed_divisor == fb.speed_divisor
		and fa.food_needed == fb.food_needed
		and fa.swim_mode == fb.swim_mode
		and fa.coin_threshold == fb.coin_threshold
		and fa.turn_dir == fb.turn_dir,
		"the same tank seed produces the same fish tuning"
	)
	fa.free()
	fb.free()
	a.free()
	b.free()


# --- helpers -----------------------------------------------------------------

func _quiet_fish(pos: Vector2, stage: int = -1, fullness: int = 800, species: int = GUPPY) -> Fish:
	var fish: Fish = tank.spawn_fish(species, pos, stage, 1)
	fish.fullness = fullness
	return fish


func _spawn_food(pos: Vector2, kind: int, landed: bool, quality: int, variant: int = 0) -> Food:
	var pellet: Food = FoodScript.create(pos, kind, landed, variant, quality, tank.rng)
	return tank.spawn_at(pellet, SimScript.Phase.FOOD, pos) as Food


## One measured eat: returns the fullness after one tick (hunger tick included).
func _eat_value(species: int, quality: int, variant: int, stage: int) -> int:
	tank.shutdown()
	tank.set_seed(200 + quality + species)
	var fish: Fish = tank.spawn_fish(species, Vector2(360.0, 160.0), stage, 1)
	fish.fullness = 0
	var pellet: Food = FoodScript.create(Vector2(400.0, 200.0), 0, false, variant, quality, tank.rng)
	pellet.inedible = 0
	tank.spawn_at(pellet, SimScript.Phase.FOOD, Vector2(400.0, 200.0))
	_step(1)
	return fish.fullness


func _set_swim(fish: Fish, mode: int, timer: int) -> void:
	fish.swim_mode = mode
	fish.mode_timer = timer
	fish.random_timer = 0
	fish.dart_timer = 0


## Exactly `count` logic ticks with no carried backlog.
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


## `EV-0164`: the draw row per stage and species, and `FUN_004D5AA0`'s state sheets.
func _test_sprite_binding() -> void:
	var fish: Fish = _quiet_fish(Vector2(200.0, 200.0), 0, 500)
	_expect(fish.sprite_row() == 0, "stage 0 draws row 0")
	fish.stage = 1
	_expect(fish.sprite_row() == 1, "stage 1 draws row 1")
	fish.stage = 2
	_expect(fish.sprite_row() == 2, "stage 2 draws row 2")
	fish.stage = 3
	_expect(fish.sprite_row() == 2, "stage 3 draws row 2, not 3")
	fish.stage = 4
	_expect(fish.sprite_row() == 3, "stage 4 draws row 3, not 4")

	fish.stage = 0
	fish.fullness = 500
	fish.eat_fx_timer = 0
	fish.digest_timer = 0
	_expect(fish.draw_state() == "swim", "an idle fish is in the swim state")
	_expect(fish.draw_image() == "IMAGE_SMALLSWIM", "a fed swimmer draws SMALLSWIM")
	fish.fullness = 200
	_expect(fish.draw_image() == "IMAGE_HUNGRYSWIM", "a hungry swimmer draws HUNGRYSWIM")
	fish.eat_fx_timer = 1
	_expect(fish.draw_state() == "eat", "the eat-fx timer switches to the eat state")
	_expect(fish.draw_image() == "IMAGE_HUNGRYEAT", "a hungry eater draws HUNGRYEAT")
	fish.fullness = 500
	_expect(fish.draw_image() == "IMAGE_SMALLEAT", "a fed eater draws SMALLEAT")
	fish.eat_fx_timer = 0
	fish.digest_timer = 100
	_expect(fish.draw_state() == "swim", "digest 100 is still the swim state")
	fish.digest_timer = 101
	_expect(fish.draw_state() == "eat", "digest past 100 is the eat state")
	fish.digest_timer = 0

	var oscar: Fish = _quiet_fish(Vector2(200.0, 200.0), 5, 900)
	oscar.species = Fish.Species.OSCAR
	_expect(oscar.sprite_row() == 4, "the carnivore keeps row 4 at every stage")
	oscar.stage = 6
	_expect(oscar.sprite_row() == 4, "and row 4 does not follow the stage")
	_expect(oscar.draw_image() == "IMAGE_SMALLSWIM", "the carnivore uses the same state sheet")


## `FUN_004D6F30`: hungry art below 301 fullness, and never at stage 3 or above.
func _test_hungry_art() -> void:
	var fish: Fish = _quiet_fish(Vector2(200.0, 200.0), 0, 500)
	fish.fullness = 500
	_expect(not fish.uses_hungry_art(), "a fed stage-0 fish keeps its normal art")
	fish.fullness = 300
	_expect(fish.uses_hungry_art(), "below 301 fullness the hungry art is used")
	fish.fullness = 301
	_expect(not fish.uses_hungry_art(), "301 is the boundary and stays normal")
	fish.fullness = 0
	fish.stage = 3
	_expect(not fish.uses_hungry_art(), "stage 3 never shows the hungry art")
	fish.stage = 0
