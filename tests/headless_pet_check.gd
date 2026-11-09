extends SceneTree
## Headless check for the Pet base (P4.3/P4.7 foundation).
##
##   & "<godot>" --headless --path . --script res://tests/headless_pet_check.gd
##
## Covers the 24-entry roster table (P2.7 §1), the update gates (§3.1), Stinky's bottom-lane coin chase
## with his hide counter and coin predicate (§4.1), and Niko's 1224/1233/1440/1450 pearl cycle (§4.2).
## The other 22 pets idle by design (Q-0044), so nothing here asserts their behaviour.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const PetScript := preload("res://scripts/entities/pet.gd")
const DeadFishScript := preload("res://scripts/entities/dead_fish.gd")
const CoinScript := preload("res://scripts/entities/coin.gd")

const STINKY := PetScript.STINKY
const NIKO := PetScript.NIKO

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 90210)

	_test_roster()
	_test_spawn()
	_test_gates()
	_test_stinky_hide()
	_test_stinky_chase()
	_test_coin_predicate()
	_test_niko_cycle()
	_test_angie_revive()
	_test_angie_relay()
	_test_timer_drops()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_pet_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_pet_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_roster() -> void:
	_expect(PetScript.DEFS.size() == PetScript.PET_COUNT, "the table has 24 pets (got %d)" % PetScript.DEFS.size())
	_expect(not PetScript.DEFS.has(999), "the display-only 999 card is not a pet")
	var other := 0
	var fish := 0
	for index: int in PetScript.DEFS:
		if int(PetScript.DEFS[index]["family"]) == PetScript.Family.OTHER:
			other += 1
		else:
			fish += 1
	_expect(other == 5, "five OtherTypePet entries (got %d)" % other)
	_expect(fish == 19, "nineteen FishTypePet entries (got %d)" % fish)
	_expect(float(PetScript.DEFS[STINKY]["speed"]) == 1.2, "Stinky's speed is 1.2")
	_expect(float(PetScript.DEFS[STINKY]["fixed_y"]) == 370.0, "Stinky's lane is y 370")
	_expect(int(PetScript.DEFS[NIKO]["period"]) == PetScript.NIKO_PEARL, "Niko's period is the pearl tick")
	_expect(String(PetScript.DEFS[NIKO]["name"]) == "Niko the Oyster", "Niko's display name is the roster's")


func _test_spawn() -> void:
	tank.shutdown()
	var stinky: Pet = tank.spawn_pet(STINKY, Vector2(300.0, 200.0))
	_expect(stinky.phase == SimScript.Phase.PETS, "pets tick in the PETS phase")
	_expect(stinky.position.y == 370.0, "Stinky is forced onto the bottom lane (got %.0f)" % stinky.position.y)
	_expect(stinky.speed == 1.2, "the spawn copies the table speed")
	_expect(stinky.family() == PetScript.Family.OTHER, "Stinky is an OtherTypePet")
	_expect(not stinky.is_fish_type(), "Stinky is not a FishTypePet")

	var niko: Pet = tank.spawn_pet(NIKO, Vector2(310.0, 210.0))
	_expect(niko.position == Vector2(310.0, 210.0), "Niko keeps his spawn position (no perch in the ctor)")
	_expect(niko.is_fish_type() == false and niko.family() == PetScript.Family.OTHER, "Niko is an OtherTypePet")


func _test_gates() -> void:
	tank.shutdown()
	var niko: Pet = tank.spawn_pet(NIKO, Vector2(300.0, 200.0))
	tank.paused = true
	_step(5)
	_expect(niko.action_timer == 0, "the pause gate freezes the slot-81 counter")
	tank.paused = false

	tank.tank_index = 5
	_step(5)
	_expect(niko.action_timer == 0, "tank 5 skips the action tick")
	tank.tank_index = 0

	tank.aliens_present = true
	_step(5)
	_expect(niko.action_timer == 0, "hostile aliens freeze a non-Stanley pet")
	tank.aliens_present = false

	_step(5)
	_expect(niko.action_timer == 5, "the open gate advances one tick per tick (got %d)" % niko.action_timer)


func _test_stinky_hide() -> void:
	tank.shutdown()
	var stinky: Pet = tank.spawn_pet(STINKY, Vector2(100.0, 370.0))
	tank.spawn_coin(1, Vector2(500.0, 200.0))
	tank.pet_sources_busy = true
	_step(3)
	_expect(stinky.hide_counter == 3, "the hide counter climbs while a source is busy (got %d)" % stinky.hide_counter)
	_expect(not stinky.is_hidden(), "three ticks is not hidden yet")
	_step(10)
	_expect(stinky.hide_counter == PetScript.STINKY_HIDE_MAX, "the counter caps at 9")
	_expect(stinky.is_hidden(), "a full counter means hidden")
	tank.pet_sources_busy = false
	_step(4)
	_expect(stinky.hide_counter == 5, "the counter falls when the sources clear (got %d)" % stinky.hide_counter)


func _test_stinky_chase() -> void:
	tank.shutdown()
	var stinky: Pet = tank.spawn_pet(STINKY, Vector2(100.0, 370.0))
	var coin: Coin = tank.spawn_coin(1, Vector2(140.0, 370.0))
	_step(1)
	_expect(stinky.position.x > 100.0, "Stinky steps toward the coin (%.1f)" % stinky.position.x)
	_expect(stinky.position.y == 370.0, "the chase never leaves the lane")

	# Contact: a coin already inside the pickup square is taken on the next tick. A coin at distance is
	# not reachable, because a landed coin climbs out of the lane (see the climber case below).
	tank.shutdown()
	stinky = tank.spawn_pet(STINKY, Vector2(100.0, 370.0))
	var near: Coin = tank.spawn_coin(1, Vector2(110.0, 370.0))
	_step(1)
	_expect(near.dead, "a coin inside the pickup square is collected")
	_expect(stinky.position.y == 370.0, "collection keeps the lane")

	# Pinned, not approved: Q-0040 records that the note lands coins at y 370 and then applies the
	# 120..150 staged rise table, which makes a landed coin climb off the floor.
	tank.shutdown()
	var climber: Coin = tank.spawn_coin(1, Vector2(300.0, 368.0))
	_step(10)
	_expect(climber.position.y < 368.0 and climber.position.y > 300.0,
		"a landed coin climbs into the band (%.1f)" % climber.position.y)


func _test_coin_predicate() -> void:
	tank.shutdown()
	var stinky: Pet = tank.spawn_pet(STINKY, Vector2(100.0, 370.0))
	var bomb: Coin = CoinScript.create(PetScript.COIN_BOMB, Vector2.ZERO)
	var snot: Coin = CoinScript.create(PetScript.COIN_SNOT, Vector2.ZERO)
	var pearl: Coin = CoinScript.create(PetScript.PEARL_KIND, Vector2.ZERO)
	var star: Coin = CoinScript.create(PetScript.COIN_STAR, Vector2.ZERO)
	var silver: Coin = CoinScript.create(0x01, Vector2.ZERO)
	var claimed: Coin = CoinScript.create(0x01, Vector2.ZERO)
	claimed.claimed = true

	_expect(not stinky.accepts_coin(bomb), "kind 0x11 (bomb) is excluded")
	_expect(not stinky.accepts_coin(snot), "kind 0x12 (snot) is excluded")
	_expect(not stinky.accepts_coin(pearl), "Niko's pearl is clickable, not collector-valid")
	_expect(stinky.accepts_coin(star), "a star is collectable with no Penta")
	tank.penta_present = true
	_expect(not stinky.accepts_coin(star), "the star pair is excluded while a Penta exists")
	tank.penta_present = false
	_expect(stinky.accepts_coin(silver), "a plain coin is collectable")
	_expect(not stinky.accepts_coin(claimed), "an already-claimed coin is skipped")
	for coin: Coin in [bomb, snot, pearl, star, silver, claimed]:
		coin.free()


func _test_niko_cycle() -> void:
	tank.shutdown()
	var niko: Pet = tank.spawn_pet(NIKO, Vector2(300.0, 200.0))
	_step(PetScript.NIKO_PEARL - 1)
	_expect(niko.action_timer == PetScript.NIKO_PEARL - 1, "the counter reaches 1232 before the pearl")
	_expect(tank.coin_count() == 0, "no pearl before 1233")

	_step(1)
	_expect(tank.coin_count() == 1, "the pearl spawns at tick 1233")
	var coins := tank.coins()
	if coins.size() == 1:
		_expect(coins[0].kind == PetScript.PEARL_KIND, "the pearl is coin kind 0x0F")
		# Niko wanders (P2.7 §4.2: no perch), so the drop is measured from his live position.
		# The coin falls 1.5 in the same tick, hence the 3 px window.
		_expect((coins[0].position - niko.position).distance_to(PetScript.PEARL_OFFSET) < 3.0,
			"the pearl spawns at (x+1, y-2) (got %s, pet %s)" % [str(coins[0].position), str(niko.position)])
		_expect(coins[0].value() == 250, "the pearl is worth 250")
	_expect(niko.pearl_taken, "the open-animation flag is set")

	_step(PetScript.NIKO_CLOSE - PetScript.NIKO_PEARL)
	_expect(niko.action_timer <= PetScript.NIKO_RESET_MAX - 1,
		"the cycle resets to rand%%50 at 1450 (got %d)" % niko.action_timer)
	_expect(not niko.pearl_taken, "the pearl flag clears for the next cycle")


# --- helpers -----------------------------------------------------------------


## Angie's food re-lay (`FUN_004FE740`, 0x4FF2AA, EV-0161): a kind-0 pellet in her 30 px box is removed
## and re-dropped with `flag = 1`, so the replacement is `landed` and bobs; every other kind is left
## alone and mode 5 does not re-lay at all.
func _test_angie_relay() -> void:
	tank.shutdown()
	tank.virtual_tank = false
	tank.aliens_present = false
	var angie: Pet = tank.spawn_pet(PetScript.ANGIE, Vector2(200.0, 200.0))

	# Sampled centres are Angie+40 and pellet+20, so (215,205) sits 5/15 px away - inside the box.
	var drifting: Food = tank.spawn_food(Vector2(215.0, 205.0), 1, 0)
	_step(1)
	_expect(not drifting.dead, "a drifting (kind 1) pellet is left alone")
	drifting.despawn()

	var plain: Food = tank.spawn_food(Vector2(215.0, 205.0), 0, 2)
	_step(1)
	_expect(plain.dead, "a kind-0 pellet in the box is taken")
	var live: Array[Food] = []
	for entity in tank.entities_in(Sim.Phase.FOOD):
		var pellet := entity as Food
		if pellet != null and not pellet.dead:
			live.append(pellet)
	_expect(live.size() == 1, "exactly one pellet replaces it (got %d)" % live.size())
	if live.size() == 1:
		_expect(live[0].landed, "the re-laid pellet is constructed landed (flag = 1)")
		_expect(live[0].quality == 2, "and keeps the taken pellet's quality (got %d)" % live[0].quality)
		_expect(is_equal_approx(live[0].position.x, 215.0), "at the same point")

	# The branch is gated on mode 5 (Virtual Tank): no re-lay there.
	tank.virtual_tank = true
	var gated: Food = tank.spawn_food(Vector2(215.0, 205.0), 0, 0)
	_step(1)
	_expect(not gated.dead, "Virtual Tank does not re-lay pellets")
	gated.despawn()
	tank.virtual_tank = false
	angie.despawn()


## Angie (P2.7 §4.19, EV-0099): contact rewrites a fresh corpse's phase 100 -> 10, the corpse counts
## down, and the revive branch spawns a live creature by its `+0x1A4` id (P2.4 §4, EV-0053).
func _test_angie_revive() -> void:
	tank.shutdown()
	var angie: Pet = tank.spawn_pet(PetScript.ANGIE, Vector2(200.0, 200.0))
	var corpse: DeadFish = tank.spawn_dead_fish(0, 2, Vector2(210.0, 200.0), 1, 0.0, 0.0)
	var revived: Array = []
	corpse.successor_requested.connect(func(species: int, stage: int, at: Vector2, facing: int) -> void:
		revived.append([species, stage, at, facing]))

	# A corpse already past the death window (`+0x1A0 <= 0x5F`) is not a target.
	corpse.stage = PetScript.ANGIE_TARGET_STAGE
	_step(1)
	_expect(corpse.phase_counter == DeadFishScript.PHASE_START, "Angie ignores a corpse whose stage is spent")

	# A fresh corpse within 30 px is taken, and the countdown starts at 10.
	corpse.stage = DeadFishScript.STAGE_START
	_step(1)
	_expect(corpse.reviving and corpse.phase_counter <= DeadFishScript.REVIVE_PHASE,
		"contact starts the 10-tick countdown (phase %d)" % corpse.phase_counter)
	_expect(corpse.sprite_frame() >= 0 and corpse.sprite_frame() <= 9, "the revive cells stay inside the row")

	# Ten ticks later the branch fires exactly once and the corpse is gone.
	var reentered := 0
	while not corpse.dead and reentered < 20:
		_step(1)
		reentered += 1
	_expect(revived.size() == 1, "the revive asks for exactly one successor (got %d)" % revived.size())
	_expect(revived.size() == 1 and int(revived[0][1]) == 2, "the successor keeps the corpse id")
	_expect(corpse.dead, "the revived corpse leaves the tank")
	_expect(reentered >= 8 and reentered <= 12, "the countdown runs its ten ticks (took %d)" % reentered)
	_expect(tank.corpses().is_empty(), "no corpse is left behind")

	angie.despawn()



## The plain slot-81 timer droppers: Vert's 216 ticks with coin kind 2 (P2.7 §4.7, EV-0087) and
## Shrapnel's ctor-rolled 633..652 with the 0x11 bomb (P2.7 §4.12, EV-0092).
func _test_timer_drops() -> void:
	tank.shutdown()
	var vert: Pet = tank.spawn_pet(PetScript.VERT, Vector2(200.0, 200.0))
	_step(PetScript.VERT_PERIOD - 1)
	_expect(tank.coin_count() == 0, "Vert holds his drop for the whole 216-tick period")
	_step(1)
	var coins: Array[Coin] = tank.coins()
	_expect(coins.size() == 1, "Vert drops one coin per period (got %d)" % coins.size())
	if coins.size() == 1:
		_expect(coins[0].kind == PetScript.VERT_DROP, "Vert's coin is kind 2 (got %d)" % coins[0].kind)
		# Vert swims (FishTypePet steer), so the drop is measured from his live position.
		# The coin falls 1.5 in the same tick, hence the 3 px window.
		_expect((coins[0].position - vert.position).distance_to(PetScript.VERT_OFFSET) < 3.0,
			"Vert drops beside himself at +15,+10 (got %s, pet %s)" % [str(coins[0].position), str(vert.position)])
	# The first coin expires while the next period runs, so the second drop is simply a fresh coin.
	_step(PetScript.VERT_PERIOD)
	var fresh := false
	for coin: Coin in tank.coins():
		fresh = fresh or coin.age < 30
	_expect(fresh, "the counter restarts, so a second coin is dropped")

	tank.shutdown()
	var shrapnel: Pet = tank.spawn_pet(PetScript.SHRAPNEL, Vector2(200.0, 200.0))
	_expect(shrapnel.drop_period >= PetScript.SHRAPNEL_MIN and shrapnel.drop_period <= PetScript.SHRAPNEL_MAX,
		"Shrapnel's ctor rolls 633..652 (got %d)" % shrapnel.drop_period)
	shrapnel.drop_period = 40
	_step(39)
	_expect(tank.coin_count() == 0, "Shrapnel holds his drop until the rolled period")
	_step(1)
	var bombs: Array[Coin] = tank.coins()
	_expect(bombs.size() == 1 and bombs[0].kind == PetScript.SHRAPNEL_DROP,
		"Shrapnel drops the 0x11 bomb coin")
	if bombs.size() == 1:
		_expect(CoinScript.VALUES.get(bombs[0].kind, 0) == 150, "the bomb coin is worth 150")

	tank.shutdown()
	var nose: Pet = tank.spawn_pet(PetScript.NOSTRADAMUS, Vector2(220.0, 220.0))
	_expect(nose.drop_period >= PetScript.NOSTRADAMUS_MIN
		and nose.drop_period < PetScript.NOSTRADAMUS_MIN + PetScript.NOSTRADAMUS_SPAN,
		"Nostradamus' ctor rolls 300..599 (got %d)" % nose.drop_period)
	nose.drop_period = 12
	_step(11)
	_expect(tank.coin_count() == 0, "Nostradamus holds the snot until the rolled period")
	_step(1)
	var snot: Array[Coin] = tank.coins()
	_expect(snot.size() == 1 and snot[0].kind == PetScript.SNOT_DROP, "he sneezes the 0x12 snot coin")
	if snot.size() == 1:
		_expect((snot[0].position - nose.position).distance_to(PetScript.SNOT_OFFSET) < 3.0,
			"the snot lands at +15,+10")


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
