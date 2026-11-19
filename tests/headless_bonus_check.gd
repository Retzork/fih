extends SceneTree
## Headless check for the tank-complete bonus round (P2.6 §6, EV-0068/EV-0069/EV-0072).
##
##   & "<godot>" --headless --path . --script res://tests/headless_bonus_check.gd
##
## Covers the recovered state machine on its own (the 160-frame wait, the duration formula, the
## timer and the end gate), then drives the live level through the same path `Main` uses: a 1-5
## completion, `begin_bonus_round`, the wait, shells routed into `Tank+0x3F4` instead of the wallet,
## and one `bonus_finished` carrying exactly those shells. The payout switch and which completions
## open a round are pinned too.

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const BonusRoundScript := preload("res://scripts/tank/bonus_round.gd")
const BonusScreenScript := preload("res://scripts/ui/bonus_screen.gd")
const ProgressionScript := preload("res://scripts/progression/progression.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_durations()
	_test_wait()
	_test_expiry_and_gate()
	_test_shells()
	_test_payout()
	_test_which_completions()
	_test_level_round()

	if _failures == 0:
		print("headless_bonus_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_bonus_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


## `FUN_00537E20`'s `base + clamp(level,1,6) - 1` (`§6.1`). A normal completion runs it at the
## sentinel, so tanks 1/2/3 get 15/20/25 s; the per-level Bonus Adventure shape is pinned too.
func _test_durations() -> void:
	_expect(BonusRoundScript.seconds_for(1, 6) == 15, "tank 1 at the sentinel runs 15 s")
	_expect(BonusRoundScript.seconds_for(2, 6) == 20, "tank 2 at the sentinel runs 20 s")
	_expect(BonusRoundScript.seconds_for(3, 6) == 25, "tank 3 at the sentinel runs 25 s")
	_expect(BonusRoundScript.seconds_for(1, 1) == 10, "tank 1 level 1 runs the 10 s base")
	_expect(BonusRoundScript.seconds_for(4, 5) == 29, "tank 4 level 5 is base 25 + 4")
	_expect(BonusRoundScript.seconds_for(5, 1) == 10, "tank 5 uses the 10 s base")
	_expect(BonusRoundScript.seconds_for(9, 6) == 15, "an unknown tank falls back to the base")
	_expect(BonusRoundScript.time_text(90) == "Time Remaining: 1:30", "the HUD string is %d:%02d")
	_expect(BonusRoundScript.time_text(5) == "Time Remaining: 0:05", "a short clock zero-pads")
	_expect(BonusRoundScript.time_text(-3) == "Time Remaining: 0:00", "a passed clock clamps at 0")


## `+0x444 - +0x2A8 > 0x9F`: 160 frames of wait, and the strict `>` puts the start on the 160th
## tick after the finalizer's anchor.
func _test_wait() -> void:
	var round: BonusRound = BonusRoundScript.new()
	round.begin(1, 6, 36)
	_expect(not round.is_playing() and not round.is_closed(), "a fresh round waits")
	_expect(round.duration_ticks == 540, "15 s is 540 ticks at 36 Hz")
	var start_tick := -1
	for i in 200:
		var event := round.tick(true)
		if event == &"start":
			start_tick = i + 1
			break
	_expect(start_tick == 160, "the round starts on tick 160, not before")
	_expect(round.is_playing(), "the start puts the round into play")
	_expect(round.elapsed == 0, "FUN_00537F40 resets the round's own clock")


## The timer runs `+0x3BC` ticks, then the end gate needs an empty coin list and the pre-increment
## `+0x3F8 > 100` (`§6.2`). A coin still on the field holds the round open.
func _test_expiry_and_gate() -> void:
	var round: BonusRound = BonusRoundScript.new()
	round.begin(1, 6, 36)
	for i in 160:
		round.tick(true)
	var finished := false
	for i in 540:
		if round.tick(false) == &"finish":
			finished = true
	_expect(not finished, "a coin on the field blocks the end gate")
	_expect(round.is_playing(), "the round is still playing after 540 played ticks")
	_expect(round.tick(false) == &"", "the expiry tick itself does not finish with a coin up")
	_expect(round.tick(true) == &"finish", "the gate opens once the field is clear")
	_expect(round.is_closed(), "finishing closes the round")
	_expect(round.seconds_left() == 0, "a closed round reports no time left")


func _test_shells() -> void:
	var round: BonusRound = BonusRoundScript.new()
	round.begin(1, 6, 36)
	round.add_shells(15)
	round.add_shells(0)
	round.add_shells(-4)
	_expect(round.shells == 15, "only positive shell values are added")
	_expect(round.seconds_left() == 0, "the clock only runs in play")
	for i in 160:
		round.tick(true)
	_expect(round.seconds_left() == 15, "+0x3BC - +0x3B0 reads the full 15 s at the start")
	round.tick(true)
	_expect(round.seconds_left() == 14, "a played tick is 1/36 of a second")


## The recovered switch (`FUN_0051C8E0`, EV-0069): a normal Adventure tank pays the round's own
## `Tank+0x3F4`; tank 5 pays the pet count instead; Time Trial and Challenge keep their rules.
func _test_payout() -> void:
	_expect(BonusScreenScript.payout_for(1, 0, 500, 1, 1234) == 1234,
		"a normal Adventure tank pays the round's shells")
	_expect(BonusScreenScript.payout_for(3, 0, 500, 1, 0) == 0,
		"a round that collected nothing pays nothing")
	_expect(BonusScreenScript.payout_for(5, 0, 500, 3, 700) == 10000,
		"tank 5 pays its pet-count bonus, not the round")
	_expect(BonusScreenScript.payout_for(1, 1, 400, 1, 900) == 20,
		"Time Trial pays money*5/100")
	_expect(BonusScreenScript.payout_for(4, 4, 400, 1, 900) == 20000,
		"Challenge pays the tank's flat reward")


## Which completions run the round: Adventure tanks 1-3 at level 5 only (`§6.1`). Tank 4's level 5
## goes straight to tank 5 and tank 5 uses the fast path.
func _test_which_completions() -> void:
	_expect(ProgressionScript.has_bonus_round(1, 5, 0), "1-5 runs a round")
	_expect(ProgressionScript.has_bonus_round(2, 5, 0), "2-5 runs a round")
	_expect(ProgressionScript.has_bonus_round(3, 5, 0), "3-5 runs a round")
	_expect(not ProgressionScript.has_bonus_round(4, 5, 0), "4-5 goes straight to tank 5")
	_expect(not ProgressionScript.has_bonus_round(5, 1, 0), "tank 5 uses the fast path")
	_expect(not ProgressionScript.has_bonus_round(1, 4, 0), "a mid-tank level runs no round")
	_expect(not ProgressionScript.has_bonus_round(1, 5, 1), "Time Trial runs no round")
	_expect(not ProgressionScript.has_bonus_round(1, 5, 4), "Challenge runs no round")


## The live path: 1-5 completes, the tank is finalized, the wait runs, a shell collected during the
## round lands in `Tank+0x3F4` (not the wallet) and the end gate hands exactly that total to Main.
func _test_level_round() -> void:
	var sim := SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 6100)
	level.start_level(1, 5)
	level.money = 20000
	_expect(level.buy_egg() and level.buy_egg() and level.buy_egg(), "three egg pieces complete 1-5")
	_expect(level.completed, "the level is complete")
	_expect(level.profile.level == ProgressionScript.LEVEL_SENTINEL,
		"completion advances into the sentinel")

	# `FUN_00537E20`'s field half.
	level.tank.spawn_alien(1, Vector2(200.0, 200.0))
	var finished: Array[int] = []
	level.bonus_finished.connect(func(total: int) -> void: finished.append(total))
	level.begin_bonus_round(1, 6)
	_expect(level.is_bonus_active(), "the level owns a waiting round")
	_expect(level.tank.alien_count() == 0, "the finalizer clears the alien list")
	_expect(level.tank.projectile_count() == 0, "the finalizer clears the shots")
	_expect(level.tank.waves_disabled, "the wave clock is disarmed for the round")
	_expect(level.bonus.duration_ticks == 540, "1-5 gets the recovered 15 s at the sentinel")

	# The wait is on the tank's own tick clock.
	_step(sim, 159)
	_expect(not level.bonus.is_playing(), "159 ticks in the round has not started")
	_step(sim, 1)
	_expect(level.bonus.is_playing(), "the 160th tick starts the round")

	# A shell collected now is bonus shells, not wallet money.
	var wallet := level.money
	var coin := level.tank.spawn_coin(0x01, Vector2(240.0, 240.0))
	var value := coin.amount()
	_expect(value > 0, "the coin carries a value")
	_expect(level.try_collect(Vector2(240.0, 240.0) + Coin.COLLECT_CENTER),
		"the click takes the coin")
	_expect(level.bonus_shells == value, "the shell lands in the bonus counter")
	_expect(level.money == wallet, "the shell does not enter the wallet during the round")

	# The clock runs out with nothing left to collect, and the round ends once.
	_step(sim, 540)
	_expect(finished.is_empty(), "the round is still open one tick before expiry")
	_expect(level.tank.coin_count() == 0, "the field is clear for the end gate")
	_step(sim, 1)
	_expect(finished.size() == 1, "the round finishes exactly once")
	if finished.size() == 1:
		_expect(finished[0] == value, "the finish carries the round's shells")
	_expect(not level.is_bonus_active(), "the level drops the finished round")
	_expect(not level.tank.waves_disabled, "the wave clock is released")
	var next := ProgressionScript.resolve_start(1, ProgressionScript.LEVEL_SENTINEL)
	_expect(int(next["tank"]) == 2 and int(next["level"]) == 1,
		"the post-bonus start lands on 2-1")

	level.tank.shutdown()
	level.free()
	sim.free()


func _step(sim_node: Node, count: int) -> void:
	sim_node.flush_backlog()
	for i in count:
		sim_node.advance(SimScript.TICK_MS)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
