extends SceneTree
## Measurement aid (not a game entry point): boots the real 1-1 tank, starves its guppies to the -400
## warning line so the dying hint is up, and scans the rendered frame for the hint's lime to report the
## painted row band in logical pixels (the capture is 2x).
##   Godot --path . --audio-driver Dummy --script res://tools/godot/measure_hint.gd

const HINT_LIME := Color8(0xAE, 0xF7, 0x62)
const OUT := "shot_hint_ink.png"
const SCALE := 2


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var content := root.get_node_or_null("Content")
	if content == null:
		push_error("Content missing")
		quit(1)
		return
	var selector: Node = null
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null:
			break
		if content.is_phase_complete(content.Phase.LOADING):
			content.pump(50.0)
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	for i in 2400:
		if content.is_phase_complete(content.Phase.LOADING):
			break
		content.pump(50.0)
		await process_frame
	var game := root.get_node_or_null("Game")
	game.profile.tank = 1
	game.profile.level = 1
	selector.press(1, {})
	for i in 60:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	# Every fish on the -400 line, so the deepest wording is the one on screen.
	for entity in level.tank.entities_in(Sim.Phase.FISH):
		var fish := entity as Fish
		if fish != null and not fish.dead:
			fish.fullness = Fish.HUNGER_HINTS[2]
	for i in 6:
		await process_frame
	var label: Label = level.get("hint_label")
	print("HINT: visible=", label.visible, " text=", label.text,
		" rect=", label.position, " size=", label.size)
	if not label.visible:
		push_error("the hint never came up")
		quit(1)
		return

	var image := root.get_texture().get_image()
	image.save_png("res://" + OUT)
	var min_y := 99999
	var max_y := -1
	var min_x := 99999
	var max_x := -1
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if absf(colour.r - HINT_LIME.r) < 0.06 \
					and absf(colour.g - HINT_LIME.g) < 0.06 \
					and absf(colour.b - HINT_LIME.b) < 0.08:
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if max_y < 0:
		push_error("no hint ink found")
		quit(1)
		return
	print("INK: rows %.1f..%.1f  x %.1f..%.1f (logical)" % [
		float(min_y) / SCALE, float(max_y) / SCALE,
		float(min_x) / SCALE, float(max_x) / SCALE])
	print("WANT: rows 457..474 (the recording), ink box y 457 h 17")
	print(OUT, " ", image.get_size())
	quit(0)
