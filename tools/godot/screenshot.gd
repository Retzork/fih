extends SceneTree
## screenshot - a development aid, not a game entry point: boots `main.tscn`, saves the menu, presses
## Adventure, then saves the level. Run windowed (the headless driver renders nothing):
##   Godot --path . --audio-driver Dummy --script res://tools/godot/screenshot.gd
##
## `--audio-driver Dummy` is deliberate: the port starts muted (Q-0056), and keeping a capture run off
## WASAPI avoids the device-invalidation loop Godot can spin in when Windows drops the output device.

const MENU_FRAMES := 200
const LEVEL_FRAMES := 120


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in MENU_FRAMES:
		await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png("res://shot_menu.png")
	print("shot_menu.png ", shot.get_size())
	var selector := root.find_child("GameSelector", true, false)
	if selector == null:
		push_error("GameSelector never mounted")
	else:
		selector.press(1, {})
	for i in LEVEL_FRAMES:
		await process_frame
	# A pellet only lives a few hundred ms before a fish eats it, so drop one right before the shot.
	var level := root.find_child("Level", true, false)
	if level != null:
		level.drop_food(Vector2(250.0, 150.0))
		level.drop_food(Vector2(480.0, 320.0))
		for i in 3:
			await process_frame
	shot = root.get_texture().get_image()
	shot.save_png("res://shot_level.png")
	print("shot_level.png ", shot.get_size())
	# The shop opens from the port-only `S` key (Q-0052); give the dialog a few frames to draw.
	if level != null:
		level.open_store()
		for i in 12:
			await process_frame
		shot = root.get_texture().get_image()
		shot.save_png("res://shot_store.png")
		print("shot_store.png ", shot.get_size())
	quit(0)
