extends SceneTree
## Temporary R54 re-check aid (not a game entry point). Boots the real main path, clears the tank,
## stages four guppies that are moving left and right, and saves a screenshot with each fish's
## velocity labelled, so the drawn head can be compared with the direction of travel.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_facing.gd
##
## Windowed only: the headless driver renders nothing. Output goes to `docs/captures/shot_facing.png`
## (that folder is gitignored through `.gdignore`). R51 (EV-0232) made `flip` the "drawn mirrored"
## flag on the right-facing side; this run checks whether that already answers R54's
## "swimming direction is wrong" report.

const OUT := "res://docs/captures/shot_facing.png"

## position, stage, vx. Two stages per direction so the row's own art is covered.
const CASES := [
	{"pos": Vector2(150.0, 170.0), "stage": 0, "vx": 3.0},
	{"pos": Vector2(150.0, 330.0), "stage": 2, "vx": 3.0},
	{"pos": Vector2(490.0, 170.0), "stage": 0, "vx": -3.0},
	{"pos": Vector2(490.0, 330.0), "stage": 2, "vx": -3.0},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var sim := root.get_node_or_null("Sim")
	var content := root.get_node_or_null("Content")
	if game == null or sim == null:
		push_error("autoloads missing: Game=%s Sim=%s" % [game, sim])
		quit(1)
		return
	var selector: Node = null
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null:
			break
	if content != null:
		for i in 2400:
			if content.is_phase_complete(content.Phase.LOADING):
				break
			content.pump(50.0)
			await process_frame
	if selector == null:
		push_error("GameSelector never mounted (content did not finish loading)")
		quit(1)
		return
	selector.press(1, {})
	for i in 12:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	# A clean frame: only the staged fish are in the tank.
	for e in level.tank.entities.duplicate():
		if e is Fish and not e.dead:
			e.despawn()
	var fish_list: Array = []
	for c in CASES:
		var fish: Fish = level.spawn_guppy(c["pos"], int(c["stage"]), 0)
		fish.vx = float(c["vx"])
		fish.vy = 0.0
		fish.facing = 1 if fish.vx > 0.0 else -1
		fish_list.append(fish)
	# `Fish._tick_motion` latches `facing`/`flip` from `vx` (D-0060), so give it two slices.
	for i in 2:
		sim.call("advance", sim.TICK_MS)
	# Freeze the tank so the capture shows exactly the state that was measured.
	game.gameplay_paused = true
	for i in 6:
		await process_frame
	for i in fish_list.size():
		var fish: Fish = fish_list[i]
		var visual: Sprite2D = null
		if fish.has_meta("visual"):
			visual = fish.get_meta("visual")
		print("FACING %d stage=%d pos=(%.0f,%.0f) vx=%.1f facing=%d flip=%s draw_flip=%s" % [
			i, fish.stage, fish.position.x, fish.position.y, fish.vx, fish.facing,
			str(fish.flip), str(visual.flip_h) if visual != null else "n/a"])
		var label := Label.new()
		label.text = "vx=+3" if fish.vx > 0.0 else "vx=-3"
		label.position = fish.position + Vector2(-46.0, -60.0)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		label.add_theme_font_size_override("font_size", 12)
		level.add_child(label)
	for i in 4:
		await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png(OUT)
	print("shot_facing.png ", shot.get_size())
	quit(0)
