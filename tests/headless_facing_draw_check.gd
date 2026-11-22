extends SceneTree
## Headless check of the drawn side (D-0060): the shipped swim cell art faces left, so the mirror
## flag belongs to the right-facing fish. `Level._sync_visuals` maps `flip_h` from the fish's own
## flag and the corpse follows the same convention; before the fix every fish was drawn mirrored
## while moving left and swam tail-first.
##
## The other suites run with `render = false`, so this boots the real main scene (which loads the
## content registry) and reads the sprites the level actually builds.
##   & "<godot>" --headless --path . --script res://tests/headless_facing_draw_check.gd

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var selector: Node = await _wait_node("GameSelector", 6000)
	_expect(selector != null, "the menu mounts")
	if selector == null:
		_finish()
		return
	selector.press(1, {})
	var level: Level = await _wait_node("Level", 200) as Level
	_expect(level != null, "Adventure starts 1-1")
	if level == null:
		_finish()
		return
	await _frames(3)
	for facing in [-1, 1]:
		var fish: Fish = level.tank.spawn_fish(Fish.Species.GUPPY, Vector2(200.0 + 120.0 * facing, 200.0), 0, facing)
		# Latch the side through the motion tail and draw one frame by hand: a live frame would let the
		# swim machine pick its own direction first, and this check is about the draw, not the swimmer.
		fish.vx = float(facing)
		fish.vy = 0.0
		fish._tick_motion()
		level._process(0.0)
		var visual: Sprite2D = fish.get_meta("visual") as Sprite2D
		_expect(visual != null, "facing %d gets a sprite" % facing)
		if visual == null:
			continue
		_expect(visual.flip_h == (facing > 0),
			"facing %d is drawn %s" % [facing, "mirrored" if facing > 0 else "as painted"])
		_expect(visual.position.is_equal_approx(fish.visual_offset()),
			"facing %d is drawn at the fish's own offset" % facing)
		# The painted art is not centred in its 80 px cell, so the side is judged against the art centre
		# (row 0: 38 px into the cell, drawn at `visual_offset()`).
		var art_centre := fish.position.x + fish.visual_offset().x + float(Fish.ART_CENTRES_X[fish.sprite_row()])
		var ahead := fish.mouth_point().x - art_centre
		_expect(ahead < 0.0 if facing < 0 else ahead > 0.0,
			"facing %d has its mouth on the side it swims to (%.1f from the art centre)" % [facing, ahead])
	# The corpse keeps the fish's facing and takes the cell shift on its mirrored side.
	for facing in [-1, 1]:
		var corpse: DeadFish = level.tank.spawn_dead_fish(Fish.Species.GUPPY, 0, Vector2(300.0, 220.0), facing)
		if corpse == null:
			_expect(false, "the tank spawns a corpse")
			continue
		await _frames(2)
		var body: Sprite2D = corpse.get_meta("visual") as Sprite2D
		_expect(body != null, "facing %d corpse gets a sprite" % facing)
		if body == null:
			continue
		_expect(body.flip_h == (facing > 0),
			"facing %d corpse is drawn %s" % [facing, "mirrored" if facing > 0 else "as painted"])
		_expect(is_equal_approx(body.position.x, 40.0 if facing > 0 else 20.0),
			"facing %d corpse takes the %d px cell shift (x %.1f)" % [facing, 40 if facing > 0 else 20, body.position.x])
	if level.tank != null:
		level.tank.shutdown()
	main.queue_free()
	await _frames(3)
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("headless_facing_draw_check: PASS (%d assertions)" % _checks)
		quit(0)
		return
	printerr("headless_facing_draw_check: FAILURE (%d of %d assertions failed)" % [_fails, _checks])
	quit(1)


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
