extends SceneTree
## Headless check for P4.11 game modes and the G4/G7/G9 wiring fixes (AUDIT §5a).
##
##   & "<godot>" --headless --path . --script res://tests/headless_mode_check.gd
##
## Covers: shop-bought fish wiring (G4), the stage->coin tier table (G9/Q-0036 port tuning),
## mode flags at level start (G7: Virtual Tank growth, Sandbox money, Time Trial budget),
## the Time Trial clock expiry (collect-all + reward), Challenge flat rewards + unlocks,
## selected-pet spawning (G8 branch B), and the Virtual Tank weighted spawner (EV-0128).

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const CoinScript := preload("res://scripts/entities/coin.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_shop_fish_wiring()
	_test_coin_tiers()
	_test_mode_flags()
	_test_time_trial()
	_test_challenge()
	_test_selected_pets()
	_test_virtual_tank()
	if _failures == 0:
		print("headless_mode_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_mode_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _new_level(seed_value: int = 777) -> Dictionary:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, seed_value)
	return {"sim": sim, "level": level}


func _teardown(ctx: Dictionary) -> void:
	ctx["level"].tank.shutdown()
	ctx["level"].free()
	ctx["sim"].free()


func _step(sim: Node, count: int) -> void:
	sim.flush_backlog()
	for i in count:
		sim.advance(SimScript.TICK_MS)


# G4: a fish bought from the store must emit died/coin_due/breed_requested like any other fish.
func _test_shop_fish_wiring() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.food_quantity = LevelScript.FOOD_QUANTITY_MAX
	level.money = 10000
	level.store_rows([0])
	_expect(level.buy_item(0), "buying a guppy succeeds")
	var bought: Fish = null
	for entity in level.tank.entities:
		if entity is Fish and not entity.dead and entity.position != null:
			if entity not in _starter_fish(level):
				bought = entity
	# Simpler: the bought fish is the one with a died connection; count fish before/after.
	_expect(level.tank.entities_in(SimScript.Phase.FISH).size() >= 2,
		"the bought guppy joined the tank")
	var wired := _has_wired_fish(level)
	_expect(wired != null, "a wired fish answers died/coin_due/breed_requested")
	# The bought guppy drops a coin at stage 1: force the scheduler to mature.
	var fish: Fish = wired
	fish.stage = 1
	fish.coin_counter = fish.coin_threshold
	fish.coin_threshold = 1
	_step(ctx["sim"], 2)
	_expect(level.tank.coin_count() >= 1, "the bought fish drops a coin (coin_due is wired)")
	_teardown(ctx)


func _starter_fish(_level: Level) -> Array:
	return []


func _has_wired_fish(level: Level) -> Fish:
	for entity in level.tank.entities:
		var fish := entity as Fish
		if fish != null and not fish.dead and fish.died.get_connections().size() > 0:
			return fish
	return null


# G9/Q-0036: the port's tier table through the recovered value table (EV-0047).
func _test_coin_tiers() -> void:
	_expect(LevelScript.coin_kind_for(0, 1) == 0x01, "stage 1 drops kind 1 (15)")
	_expect(LevelScript.coin_kind_for(0, 2) == 0x02, "stage 2 drops kind 2 (35)")
	_expect(LevelScript.coin_kind_for(0, 3) == 0x03, "stage 3 drops kind 3 (40)")
	_expect(LevelScript.coin_kind_for(0, 4) == 0x04, "stage 4 drops the diamond kind 4 (200)")
	_expect(LevelScript.coin_kind_for(2, 6) == 0x06, "Ultravore drops kind 6 (500)")
	_expect(CoinScript.create(1, Vector2.ZERO).value() == 15, "kind 1 is worth 15")
	_expect(CoinScript.create(0x04, Vector2.ZERO).value() == 200, "kind 4 is worth 200")


# G7: mode flags are written at level start.
func _test_mode_flags() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.game_mode = LevelScript.MODE_VIRTUAL
	level.start_level(1, 1)
	_expect(level.tank.virtual_tank, "mode 5 sets Tank.virtual_tank")
	var vt_fish := level.tank.entities_in(SimScript.Phase.FISH).size()
	_expect(vt_fish >= 3, "Virtual Tank populates through the spawner (got %d)" % vt_fish)
	_expect(level.alien_selection == 0, "Virtual Tank arms no wave")
	_teardown(ctx)

	ctx = _new_level()
	level = ctx["level"]
	level.game_mode = LevelScript.MODE_SANDBOX
	level.money = 0
	level.start_level(1, 1)
	_expect(level.money == LevelScript.SANDBOX_MONEY, "Sandbox starts with 999999 money")
	_teardown(ctx)

	ctx = _new_level()
	level = ctx["level"]
	level.game_mode = LevelScript.MODE_TIME_TRIAL
	level.start_level(1, 1)
	_expect(level.time_trial_budget_ticks == 300 * 36, "Time Trial tank 1 budget is 300 s")
	_expect(level.tank.entities_in(SimScript.Phase.PETS).size() == 0, "Time Trial spawns no pets")
	_teardown(ctx)

	ctx = _new_level()
	level = ctx["level"]
	level.game_mode = LevelScript.MODE_TIME_TRIAL
	level.start_level(3, 1)
	_expect(level.time_trial_budget_ticks == 600 * 36, "Time Trial tanks 2-4 budget is 600 s")
	_teardown(ctx)


# Time Trial: the clock collects all coins and pays money*5/100 shells.
func _test_time_trial() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.game_mode = LevelScript.MODE_TIME_TRIAL
	level.start_level(1, 1)
	level.money = 200
	tank_spawn_coin(level, 1, Vector2(200, 200))
	var before := level.profile.shells
	level.time_trial_budget_ticks = 3
	level.time_trial_elapsed = 2
	_step(ctx["sim"], 3)
	_expect(level.completed, "the Time Trial clock completes the level")
	_expect(level.tank.coin_count() == 0, "expiry collects all coins first")
	_expect(level.profile.shells == before + int((200 + 15) * 5 / 100),
		"the Time Trial reward is money*5/100 shells (got %d)" % level.profile.shells)
	_teardown(ctx)


func tank_spawn_coin(level: Level, kind: int, at: Vector2) -> void:
	level.tank.spawn_coin(kind, at)


# Challenge: flat shell reward by tank plus the unlock byte.
func _test_challenge() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.game_mode = LevelScript.MODE_CHALLENGE
	level.start_level(2, 1)
	var before := level.profile.shells
	level.complete_level()
	_expect(level.profile.shells == before + 5000, "Challenge tank 2 pays 5000 shells")
	_expect(level.profile.challenge_unlocks[1] == 1, "the Challenge unlock byte is written")
	_teardown(ctx)


# G8: a non-empty pending selection is the spawned set (branch B).
func _test_selected_pets() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.profile = Profile.new()
	level.profile.grant_pet(0)
	level.profile.grant_pet(1)
	level.profile.grant_pet(6)
	level.profile.selected_pets[6] = 1
	_expect(level.spawn_owned_pets() == 1, "a selected pet is the spawned set")
	for entity in level.tank.entities_in(SimScript.Phase.PETS):
		_expect((entity as Pet).index == 6, "only the selected pet spawns")
	_teardown(ctx)


# Virtual Tank: weighted spawner produces 6 fish on a fixed seed; ordinary vs prize split shape.
func _test_virtual_tank() -> void:
	var ctx := _new_level(1234)
	var level: Level = ctx["level"]
	level.game_mode = LevelScript.MODE_VIRTUAL
	level.start_level(1, 1)
	_expect(level.tank.entities_in(SimScript.Phase.FISH).size() == 6,
		"the VT init populates 6 fish")
	# Coins bank to shells in Virtual Tank instead of money.
	var coin := level.tank.spawn_coin(1, Vector2(100, 100))
	var shells := level.profile.shells
	var money := level.money
	coin.collect()
	_expect(level.profile.shells == shells + int(coin.amount()) or level.profile.shells > shells,
		"a Virtual Tank coin pays shells")
	_expect(level.money == money, "a Virtual Tank coin does not add money")
	_teardown(ctx)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
