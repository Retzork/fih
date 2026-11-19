extends SceneTree
## Temporary capture aid for R35 (not a game entry point): boots the real 1-1 tank, writes a scratch
## tank 2-3 save, loads it under the running 1-1, and reads the tank name, the wallet, the store bar's
## rows and the egg dome (a) before the load, (b) right after the call and (c) one tick later, saving
## both frames.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_load_refresh.gd

const LevelScript := preload("res://scripts/tank/level.gd")
const ProgressionScript := preload("res://scripts/progression/progression.gd")

const BEFORE_OUT := "shot_load_refresh_before.png"
const AFTER_OUT := "shot_load_refresh_after.png"
const SAVE := "user://load_refresh_shot.dat"

var _fails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	var sim := root.get_node_or_null("Sim")
	if game == null or content == null or sim == null:
		push_error("autoloads missing: Game=%s Content=%s Sim=%s" % [game, content, sim])
		quit(1)
		return
	var selector: Node = null
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null:
			break
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	for i in 2400:
		if content.is_phase_complete(content.Phase.LOADING):
			break
		content.pump(50.0)
		await process_frame
	print("LOAD: content %d/%d" % [content.loaded_count(), content.EXPECTED_TOTAL])

	# 1. The live tank: adventure 1-1.
	game.profile.tank = 1
	game.profile.level = 1
	selector.press(1, {})
	for i in 90:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	level.store_bar.refresh()
	level.egg_widget.refresh()
	var before := _state(level)
	print("BEFORE: ", before)
	_check(level.tank_label.text == "Tank  1-1", "the live tank starts on 1-1")
	_check(level.money == 200, "the live tank starts on the 200 wallet (got %d)" % level.money)
	var shot := root.get_texture().get_image()
	shot.save_png("res://" + BEFORE_OUT)
	print(BEFORE_OUT, " ", shot.get_size())

	# 2. A save from another tank: 2-3, wallet 4321, two egg pieces, its own stock table.
	var scratch: Level = LevelScript.new()
	scratch.render = false
	scratch.setup(sim, 9001)
	scratch.tank_index = 2
	scratch.level_index = 3
	scratch.money = 4321
	scratch.egg_pieces = 2
	scratch.stock_default_store()
	scratch.egg_price = ProgressionScript.egg_price(2, 3, scratch.game_mode)
	var wanted := _expected_rows(scratch)
	print("SAVE: tank=", scratch.tank_index, " level=", scratch.level_index,
		" money=", scratch.money, " pieces=", scratch.egg_pieces, " price=", scratch.egg_price,
		" rows=", wanted)
	print("SAVE TABLE: ", _table(scratch))
	var err: int = scratch.save_game(SAVE)
	scratch.tank.shutdown()
	scratch.free()
	_check(err == OK, "the 2-3 save is written (%s)" % error_string(err))

	# 3. Load it under the running 1-1. The name is refreshed inside the call; the bar and the dome
	#    only repaint from the tank's tick (D-0037), so the three reads below say which is which.
	var loaded: bool = level.load_game(SAVE)
	print("AFTER CALL: ", _state(level))
	_check(loaded, "load_game reads the 2-3 save")
	_check(level.tank_label.text == "Tank  2-3",
		"the tank name is the restored 2-3 right after the call")

	for i in 14:
		await process_frame
	var after := _state(level)
	print("AFTER TICK: ", after)
	shot = root.get_texture().get_image()
	shot.save_png("res://" + AFTER_OUT)
	print(AFTER_OUT, " ", shot.get_size())

	# 4. Everything reads the restored save, not the pre-load tank.
	_check(level.tank_label.text == "Tank  2-3", "the name stays 2-3 after the tick")
	_check(level.money == 4321, "the wallet is the restored 4321 (got %d)" % level.money)
	_check(String(after["money_text"]) == "4321",
		"the bar's wallet number repainted to 4321 (got %s)" % after["money_text"])
	_check(int(after["pieces"]) == 2, "the egg dome counts the restored 2 pieces (got %d)" % after["pieces"])
	_check(String(after["dome_price"]) == "$%d" % int(level.egg_price),
		"the egg dome prices the restored tank (got %s)" % after["dome_price"])
	_check(after["rows"] == wanted,
		"the bar's rows are the restored 2-3 stock\n  want %s\n  got  %s" % [wanted, after["rows"]])
	_check(after["rows"] != before["rows"], "the bar's rows actually changed from the 1-1 stock")

	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	if _fails == 0:
		print("LOAD REFRESH: PASS")
		quit(0)
	else:
		printerr("LOAD REFRESH: %d FAILURE(S)" % _fails)
		quit(1)


## The live level's four surfaces, as a dictionary the checks compare.
func _state(level: Level) -> Dictionary:
	var pieces := 0
	var tooltip := String(level.egg_widget.tooltip_text)
	var slash := tooltip.find("/")
	if slash > 0:
		pieces = int(tooltip.substr(4, slash - 4))
	return {
		"name": String(level.tank_label.text),
		"money": int(level.money),
		"money_text": String(level.store_bar._money_label.text),
		"dome_price": String(level.egg_widget._price.text),
		"pieces": pieces,
		"rows": _rows(level),
		"table": _table(level),
	}


## The price texts the bar should draw for a level's table, one per shelf 0..6: empty where the
## shelf is unstocked or the egg's own dome draws it. Computed from the table, so the scratch level
## (which has no bar) can supply the expectation.
func _expected_rows(level: Level) -> Array[String]:
	var out: Array[String] = []
	for shelf in 7:
		var found := {}
		for row: Dictionary in level.tank_store:
			if int(row.get("shelf", -1)) == shelf:
				found = row
				break
		if found.is_empty() or int(found.get("slot", -1)) == ProgressionScript.EGG_ITEM:
			out.append("")
			continue
		out.append("$%d" % int(found.get("price", 0)))
	return out


## `shelf:slot@price` per row, for the log.
func _table(level: Level) -> String:
	var parts: Array[String] = []
	for row: Dictionary in level.tank_store:
		parts.append("%s:%s@%s" % [row.get("shelf", "-"), row.get("slot", "-"), row.get("price", "-")])
	return ", ".join(parts)


## What the bar actually draws: the price label it holds per shelf, in shelf order.
func _rows(level: Level) -> Array[String]:
	var out: Array[String] = []
	for label: Label in level.store_bar._prices:
		out.append(String(label.text))
	return out


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
		return
	_fails += 1
	printerr("  FAIL ", what)
