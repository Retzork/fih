extends SceneTree
## Temporary capture aid for the tank store bar (not a game entry point): boots the real main path and
## saves the MENUBAR strip for the tank/level in SHOT_TANK / SHOT_LEVEL (default 1-3).
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_bar.gd
const DEFAULT_TANK := 1
const DEFAULT_LEVEL := 3


func _initialize() -> void:
	_run()


func _run() -> void:
	var tank := DEFAULT_TANK
	var lvl := DEFAULT_LEVEL
	if OS.get_environment("SHOT_TANK") != "":
		tank = int(OS.get_environment("SHOT_TANK"))
	if OS.get_environment("SHOT_LEVEL") != "":
		lvl = int(OS.get_environment("SHOT_LEVEL"))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	if game == null or content == null:
		push_error("autoloads missing")
		quit(1)
		return
	var selector := root.find_child("GameSelector", true, false)
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null:
			break
	for i in 2400:
		if content.is_phase_complete(content.Phase.LOADING):
			break
		content.pump(50.0)
		await process_frame
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	game.profile.tank = tank
	game.profile.level = lvl
	selector.press(1, {})
	for i in 40:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	level.money = 5000
	# The bar opens with the level's whole stock (D-0019), so the capture only has to redraw it with
	# the bigger purse.
	if level.store_bar != null:
		level.store_bar.refresh()
	if level.egg_widget != null:
		level.egg_widget.refresh()
	for i in 8:
		await process_frame
	var out := "shot_bar_tank%d.png" % tank
	var shot := root.get_texture().get_image()
	shot.save_png("res://docs/captures/" + out)
	print("SHOT ", out, " ", shot.get_size(), " ", tank, "-", lvl)
	quit(0)
