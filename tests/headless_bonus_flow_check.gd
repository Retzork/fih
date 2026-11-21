extends SceneTree
## Headless check of the real between-level flow for the tank-complete bonus round (P2.6 §6,
## D-0051): boots the actual `main.tscn`, finishes 1-5/2-5/3-5 through the egg, walks Hatch ->
## Pets and asserts `Main` hands the finalized tank to `begin_bonus_round` with the per-tank
## duration, that the 160-tick wait and the timer run on the live level, that the round's shells are
## banked exactly once when the end gate closes, that the BonusScreen card carries them, and that
## Continue starts the next tank. Tank 4's level 5 is the fast path: a card, no round.
##
## `headless_bonus_check` pins `BonusRound` and the level's own round; this one pins `Main`'s wiring
## between them, which is the part that can regress into "a finished tank jumps straight on".
##   & "<godot>" --headless --path . --script res://tests/headless_bonus_flow_check.gd

## `begin_bonus_round` at the sentinel: base(tank) + 6 - 1 seconds at 36 ticks a second.
const DURATION_TICKS := {1: 540, 2: 720, 3: 900}

var _fails := 0
var _checks := 0
var _sim: Node = null


func _initialize() -> void:
	_run()


func _run() -> void:
	_sim = root.get_node_or_null("Sim")
	if _sim == null:
		push_error("Sim autoload missing")
		quit(1)
		return
	for tank in [1, 2, 3]:
		await _check_round(tank, int(DURATION_TICKS[tank]))
	await _check_fast_path()
	if _fails == 0:
		print("headless_bonus_flow_check: PASS (%d assertions)" % _checks)
		quit(0)
		return
	printerr("headless_bonus_flow_check: FAILURE (%d of %d assertions failed)" % [_fails, _checks])
	quit(1)


## Mount the real main scene on a chosen tank/level and press Adventure.
func _boot(tank_no: int, level_no: int) -> Dictionary:
	var game := root.get_node_or_null("Game")
	if game != null:
		game.mode = 0
		game.profile.tank = tank_no
		game.profile.level = level_no
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var selector: Node = await _wait_node("GameSelector", 6000)
	_expect(selector != null, "the menu mounts")
	if selector == null:
		return {}
	selector.press(1, {})
	var level: Level = await _wait_node("Level", 120) as Level
	_expect(level != null, "Adventure starts %d-%d" % [tank_no, level_no])
	return {"main": main, "level": level, "game": game}


## One tank final: cards, round, payout, next tank.
func _check_round(tank_no: int, duration_ticks: int) -> void:
	var boot := await _boot(tank_no, 5)
	var level: Level = boot.get("level") as Level
	if level == null:
		return
	var game: Node = boot["game"]
	level.money = 200000
	var bought := 0
	for i in 3:
		if level.buy_egg():
			bought += 1
	_expect(bought == 3, "tank %d level 5 completes through the egg" % tank_no)
	await _frames(4)
	var hatch: Node = await _wait_node("HatchScreen")
	_expect(hatch != null, "the Hatch card follows the completion")
	_expect(not level.is_bonus_active(), "the round waits until the cards are done")
	if hatch != null:
		hatch.press_ok()
		await _frames(3)
	var pets: Node = await _wait_node("PetsScreen")
	_expect(pets != null, "the Pets card follows Hatch")
	if pets != null:
		pets.press_confirm()
	await _frames(4)
	_expect(level.is_bonus_active(), "Pets hands the final tank to the round")
	_expect(root.find_child("BonusHud", true, false) != null, "the round's HUD is mounted")
	if level.bonus == null:
		await _drop(boot)
		return
	_expect(level.bonus.duration_ticks == duration_ticks,
		"tank %d runs its %d s at the sentinel" % [tank_no, duration_ticks / 36])
	_expect(not level.bonus.is_playing(), "the round is in its 160-tick wait")
	var started := false
	for i in 400:
		if level.bonus == null:
			break
		if level.bonus.is_playing():
			started = true
			break
		_sim.advance(1000.0 / int(_sim.TICKS_PER_SECOND))
	_expect(started, "the round starts after the wait")
	if not started:
		await _drop(boot)
		return
	# A shell collected during the round is the round's, not the wallet's.
	var wallet := level.money
	var coin := level.tank.spawn_coin(0x01, Vector2(300.0, 300.0))
	var value := coin.amount()
	_expect(level.try_collect(Vector2(300.0, 300.0) + Coin.COLLECT_CENTER),
		"the click takes a shell")
	_expect(level.bonus_shells == value, "the shell goes to the round's counter")
	_expect(level.money == wallet, "and not into the wallet")
	var shells_before := int(game.profile.shells)
	var finished := false
	for i in 1400:
		_sim.advance(1000.0 / int(_sim.TICKS_PER_SECOND))
		if level.is_bonus_active() and level.tank != null:
			for entity in level.tank.coins():
				level.try_collect(entity.position + Coin.COLLECT_CENTER)
		if not level.is_bonus_active():
			finished = true
			break
	_expect(finished, "the clock runs out and the end gate closes")
	# The finish runs inside a tick and frees the finalized tank; let the tree process that before
	# the card is looked up, or the freed node still sitting there answers first.
	await _frames(6)
	var card: BonusScreen = await _wait_node("BonusScreen", 120) as BonusScreen
	_expect(card != null, "the BonusScreen opens after the round")
	if card != null:
		_expect(card.payout >= value, "the card pays the round's shells")
		_expect(int(game.profile.shells) == shells_before + card.payout,
			"the round's shells are banked exactly once")
		card.press_continue()
		await _frames(8)
		var next: Level = await _wait_node("Level", 120) as Level
		_expect(next != null and next.tank_index == tank_no + 1 and next.level_index == 1,
			"Continue starts %d-1" % (tank_no + 1))
		if next != null and next.tank != null:
			next.tank.shutdown()
	await _drop(boot)


## Tank 4's level 5 goes straight to tank 5: a card, never a round.
func _check_fast_path() -> void:
	var boot := await _boot(4, 5)
	var level: Level = boot.get("level") as Level
	if level == null:
		return
	level.money = 400000
	var bought := 0
	for i in 3:
		if level.buy_egg():
			bought += 1
	_expect(bought == 3, "tank 4 level 5 completes through the egg")
	await _frames(4)
	var hatch: Node = await _wait_node("HatchScreen")
	_expect(hatch != null, "tank 4 level 5 shows the Hatch card")
	if hatch != null:
		hatch.press_ok()
		await _frames(3)
	var pets: Node = await _wait_node("PetsScreen")
	if pets != null:
		pets.press_confirm()
	await _frames(8)
	_expect(root.find_child("BonusHud", true, false) == null, "tank 4 mounts no round HUD")
	var card: BonusScreen = await _wait_node("BonusScreen", 120) as BonusScreen
	_expect(card != null, "tank 4 goes straight to the BonusScreen")
	if card != null:
		card.press_continue()
		await _frames(8)
		var next: Level = await _wait_node("Level", 120) as Level
		_expect(next != null and next.tank_index == 5 and next.level_index == 1,
			"Continue starts 5-1")
		if next != null and next.tank != null:
			next.tank.shutdown()
	await _drop(boot)


func _drop(boot: Dictionary) -> void:
	var main: Node = boot.get("main")
	if main != null and is_instance_valid(main):
		main.queue_free()
	await _frames(4)


func _wait_node(node_name: String, frames: int = 300) -> Node:
	for i in frames:
		var node := root.find_child(node_name, true, false)
		if node != null:
			return node
		await process_frame
	return null


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)
