extends SceneTree
## Windowed observation for the load repaint (not a game entry point): boots the real 1-1 tank, loads a
## tank 3 level 4 save while the tick is held by the pause gate, and captures three moments - before
## the load, right after the call with no tick, and after the first tick - as state reads *and* as
## pixel crops of the price band, the wallet and the egg dome. The frames are saved for eyeballing.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_load_refresh.gd

const LevelScript := preload("res://scripts/tank/level.gd")
const ProgressionScript := preload("res://scripts/progression/progression.gd")

const SAVE := "user://load_refresh_shot.dat"
const OUT_BEFORE := "shot_load_refresh_before.png"
const OUT_STALE := "shot_load_refresh_stale.png"
const OUT_AFTER := "shot_load_refresh_after.png"

## The captures are the window at 2x the 640x480 logical frame.
const SCALE := 2
## The seven price plates' band, slot-local y 45..60: below every dome, so the guppy's swim animation
## cannot move these pixels - only a price string can.
const BAND_RECT := Rect2i(0, 88, 1000, 36)
## The wallet number's plate (logical 534..617 x 39..59).
const WALLET_RECT := Rect2i(1068, 78, 166, 40)
## The egg's own dome slot: logical slot 6 at x 436, the 58x60 widget over the seventh dome.
const EGG_RECT := Rect2i(868, 0, 124, 150)
## The bottom-left tank name, kept left of the centred hunger hint.
const NAME_RECT := Rect2i(26, 906, 360, 44)

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

	# 1. The live tank: adventure 1-1, ticking.
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

	# 2. Hold the tick so the "before repaint" frame is deterministic. The pause gate is the same flag
	#    a modal raises; `_on_sim_tick` returns early while it is set.
	game.gameplay_paused = true
	for i in 4:
		await process_frame
	var ticks_before := int(level.tank.age_ticks)
	var before := _state(level)
	var frames := _capture()
	_save_now(OUT_BEFORE)
	print("BEFORE: ", before)
	_check(String(before["name"]) == "Tank  1-1", "the live tank is 1-1")
	_check(int(before["money"]) == 200, "the live tank holds the 200 wallet (got %d)" % before["money"])

	# 3. A save from another tank and level: 3-4, its own wallet, pieces and stock.
	var scratch: Level = LevelScript.new()
	scratch.render = false
	scratch.setup(sim, 9001)
	scratch.tank_index = 3
	scratch.level_index = 4
	scratch.money = 4321
	scratch.egg_pieces = 2
	scratch.stock_default_store()
	scratch.egg_price = ProgressionScript.egg_price(3, 4, scratch.game_mode)
	var wanted := _expected_rows(scratch)
	var want_price := "$%d" % int(scratch.egg_price)
	print("SAVE: tank=3 level=4 money=4321 pieces=2 egg_price=", scratch.egg_price, " rows=", wanted)
	print("SAVE TABLE: ", _table(scratch))
	var err: int = scratch.save_game(SAVE)
	scratch.tank.shutdown()
	scratch.free()
	_check(err == OK, "the 3-4 save is written (%s)" % error_string(err))

	# 4. Load it with the tick still held: the name is refreshed inside the call, the bar and dome are
	#    not - their repaint lives in `_on_sim_tick`, which cannot run while paused.
	var loaded: bool = level.load_game(SAVE)
	# One rendered frame with the tick still held: the name's text was set inside the call, the bar's
	# repaint lives in `_on_sim_tick` and cannot have run.
	for i in 3:
		await process_frame
	var right := _state(level)
	print("AFTER CALL (paused): ", right)
	_check(loaded, "load_game reads the 3-4 save")
	_check(String(right["name"]) == "Tank  3-4", "the name is the restored 3-4 right after the call")
	_check(String(right["money_text"]) == "200",
		"the bar still shows the old wallet with the tick held (got %s)" % right["money_text"])

	var stale := _capture()
	_save_now(OUT_STALE)
	print("STALE PIXELS: band=%d wallet=%d egg=%d name=%d" % [
		stale["band"], stale["wallet"], stale["egg"], stale["name"]])
	_check(stale["wallet"] == frames["wallet"],
		"the wallet's pixels are still the pre-load 200 (no tick ran)")
	_check(stale["band"] == frames["band"],
		"the price band has not repainted yet")
	_check(stale["egg"] == frames["egg"],
		"the egg dome has not repainted yet")
	_check(stale["name"] != frames["name"],
		"the name label did repaint during the call (its pixels already say 3-4)")

	# 5. Release the pause: the next tick repaints the bar and the dome from the restored values.
	game.gameplay_paused = false
	var waited := 0
	for i in 120:
		await process_frame
		waited += 1
		if int(level.tank.age_ticks) != ticks_before:
			break
	for i in 2:
		await process_frame
	var after := _state(level)
	var fresh := _capture()
	_save_now(OUT_AFTER)
	print("AFTER TICK: ", after)
	print("AFTER PIXELS: band=%d wallet=%d egg=%d name=%d" % [
		fresh["band"], fresh["wallet"], fresh["egg"], fresh["name"]])
	_check(int(level.tank.age_ticks) != ticks_before,
		"a tick ran after unpausing (%d frames)" % waited)
	_check(fresh["wallet"] != frames["wallet"], "the wallet's pixels repainted")
	_check(fresh["band"] != frames["band"], "the price band's pixels repainted")
	_check(fresh["egg"] != frames["egg"], "the egg dome's pixels repainted")
	_check(String(after["money_text"]) == "4321",
		"the bar draws the restored wallet (got %s)" % after["money_text"])
	_check(String(after["dome_price"]) == want_price,
		"the dome draws the restored price %s (got %s)" % [want_price, after["dome_price"]])
	_check(int(after["pieces"]) == 2, "the dome draws the restored 2 pieces (got %d)" % after["pieces"])
	_check(after["rows"] == wanted,
		"the bar's shelves are the restored 3-4 stock\n  want %s\n  got  %s" % [wanted, after["rows"]])

	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	game.gameplay_paused = false
	if _fails == 0:
		print("LOAD REPAINT: PASS")
		quit(0)
	else:
		printerr("LOAD REPAINT: %d FAILURE(S)" % _fails)
		quit(1)


func _capture() -> Dictionary:
	var image := root.get_texture().get_image()
	return {
		"band": _fingerprint(image, BAND_RECT),
		"wallet": _fingerprint(image, WALLET_RECT),
		"egg": _fingerprint(image, EGG_RECT),
		"name": _fingerprint(image, NAME_RECT),
	}


## The crop's bytes, folded into one number: two equal values mean those pixels did not change.
func _fingerprint(image: Image, rect: Rect2i) -> int:
	var data := image.get_region(rect).get_data()
	var sum := 0
	for byte in data:
		sum = (sum * 31 + int(byte)) & 0x7FFFFFFF
	return sum


func _save_now(path: String) -> void:
	root.get_texture().get_image().save_png("res://" + path)
	print(path, " saved")


## The four surfaces the repaint question is about, read off the live widgets.
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
