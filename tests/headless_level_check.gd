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

	level.tank.shutdown()
	level.free()
	sim.free()

	if _failures == 0:
		print("headless_level_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_level_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_starting_population() -> void:
	_expect(level.tank != null, "the level builds a tank")
	_expect(_live_fish().size() == LevelScript.STARTING_FISH,
		"the level starts with %d guppies (got %d)" % [LevelScript.STARTING_FISH, _live_fish().size()])
	var fish: Fish = _live_fish()[0]
	_expect(fish != null and fish.species == GUPPY, "the starting fish is a guppy")
	_expect(fish.phase == SimScript.Phase.FISH, "the guppy ticks in the FISH phase")
	_expect(fish.position.x >= LevelScript.SPAWN_MIN.x and fish.position.x <= LevelScript.SPAWN_MAX.x,
		"the spawn x is inside the tank band (%.0f)" % fish.position.x)
	_expect(level.money == 0, "the wallet starts empty")


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
	var potion := level.drop_food(Vector2(300.0, 250.0))
	_expect(potion != null and potion.quality == 3, "the armed drop is a quality-3 pellet")
	_expect(not level.star_potion_armed, "the flag clears with the drop")
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
	var pellet := level.drop_food(Vector2(300.0, 200.0))
	_expect(pellet != null, "a pellet is dropped")
	if pellet == null:
		return
	pellet.anim_frame = 0
	_expect(level._food_frame(pellet) == 0, "frame 0 starts the pellet animation")
	pellet.anim_frame = 25
	_expect(level._food_frame(pellet) == 5, "25 ticks is the sixth tumbler column")
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

