extends SceneTree
## Windowed confirmation of the tank-complete bonus round (not a game entry point): boots the real
## main path, plays 1-5 to its egg, walks the Hatch -> Pets cards, lets the finalized tank wait its
## 160 ticks, then captures the live round and its HUD, collects a coin, and runs the clock out to
## the BonusScreen.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_bonus.gd

const OUT_WAIT := "shot_bonus_wait.png"
const OUT_PLAY := "shot_bonus_play.png"
const OUT_CARD := "shot_bonus_card.png"

var _fails := 0


func _initialize() -> void:
	_run()


func _shot(out: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("res://docs/captures/" + out)
	print("SHOT: ", out, " ", image.get_size())


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	var sim := root.get_node_or_null("Sim")
	if game == null or content == null or sim == null:
		push_error("autoloads missing")
		quit(1)
		return
	var selector: Node = null
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null and content.is_phase_complete(content.Phase.LOADING):
			break
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	# 1-5 in Adventure, so the completion is a tank final with a bonus round.
	game.profile.tank = 1
	game.profile.level = 5
	selector.press(1, {})
	await _frames(12)
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	print("BONUS: 1-5 mounted, pieces=", level.egg_pieces, " price=", level.egg_price)
	level.money = 20000
	for i in 3:
		level.buy_egg()
	await _frames(6)
	var hatch: HatchScreen = root.find_child("HatchScreen", true, false)
	_check(hatch != null, "the Hatch card follows the completion")
	_check(level.is_bonus_active() == false, "the round waits for the cards")
	if hatch != null:
		hatch.press_ok()
	await _frames(6)
	var pets: PetsScreen = root.find_child("PetsScreen", true, false)
	_check(pets != null, "the Pets card follows Hatch")
	if pets != null:
		pets.press_confirm()
	await _frames(4)
	_check(level.is_bonus_active(), "Pets hands over to the bonus round")
	_check(root.find_child("BonusHud", true, false) != null, "the round's HUD is mounted")
	_check(not level.bonus.is_playing(), "the round is still in its 160-tick wait")
	print("BONUS: waiting, phase=", level.bonus.phase, " duration=", level.bonus.duration_ticks)
	_shot(OUT_WAIT)

	# Uncapped frames carry too little game time, so the 160-tick wait is driven through the real
	# driver rather than by counting frames.
	for i in 200:
		sim.advance(1000.0 / sim.TICKS_PER_SECOND)
		if level.bonus == null or level.bonus.is_playing():
			break
	await _frames(2)
	_check(level.bonus != null and level.bonus.is_playing(), "the round starts after the wait")
	# One real shell through the level's own click path, so the HUD's counter moves.
	var coin := level.tank.spawn_coin(0x01, Vector2(300.0, 300.0))
	var value := coin.amount()
	level.try_collect(Vector2(300.0, 300.0) + Coin.COLLECT_CENTER)
	await _frames(3)
	_check(level.bonus_shells == value, "a clicked shell shows up in the round's counter")
	print("BONUS: playing, shells=", level.bonus_shells, " time=", level.bonus.seconds_left())
	_shot(OUT_PLAY)

	# Run the clock out through the real driver, collecting anything the fish drop on the way.
	var finished := false
	for i in 900:
		sim.advance(1000.0 / sim.TICKS_PER_SECOND)
		if level.bonus != null:
			for entity in level.tank.coins():
				level.try_collect(entity.position + Coin.COLLECT_CENTER)
		if not level.is_bonus_active():
			finished = true
			break
	_check(finished, "the round's clock runs out and the gate closes")
	await _frames(6)
	var card: BonusScreen = root.find_child("BonusScreen", true, false)
	_check(card != null, "the BonusScreen opens after the round")
	print("BONUS: card payout=", card.payout if card != null else -1,
		" shells=", game.profile.shells)
	_shot(OUT_CARD)
	quit(0 if _fails == 0 else 1)
