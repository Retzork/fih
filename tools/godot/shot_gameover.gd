extends SceneTree
## Windowed confirmation of the recovered loss card (R65, EV-0249): boots 1-1 through the real main
## path, empties the tank, and captures the "GAME OVER" card `Main` mounts for `Level.defeated`.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_gameover.gd

const OUT_CARD := "shot_gameover.png"
const OUT_ZOOM := "shot_gameover_zoom.png"

var _fails := 0


func _initialize() -> void:
	_run()


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(out: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("res://docs/captures/" + out)
	print("SHOT: ", out, " ", image.get_size())


func _shot_zoom(out: String, logical: Rect2, factor: int) -> void:
	var image := root.get_texture().get_image()
	var window_scale := float(image.get_width()) / 640.0
	var region := Rect2i(
		Vector2i(logical.position * window_scale), Vector2i(logical.size * window_scale))
	var crop := image.get_region(region)
	crop.resize(crop.get_width() * factor, crop.get_height() * factor, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://docs/captures/" + out)
	print("SHOT: ", out, " ", crop.get_size())


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	if game == null or content == null:
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
	game.profile.tank = 1
	game.profile.level = 1
	selector.press(1, {})
	await _frames(12)
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	_check(not level.tank.fish().is_empty(), "1-1 opens with its starter fish")
	# The last fish gone: the tank's own defeat check has to notice within a tick or two.
	level.tank.shutdown()
	var dialog: Node = null
	for i in 120:
		await process_frame
		dialog = root.find_child("GameOverDialog", true, false)
		if dialog != null:
			break
	_check(level.game_over, "the level latches its loss")
	_check(dialog != null, "Main mounts the GAME OVER card")
	_check(game.gameplay_paused, "the tank is held behind the card")
	_check(dialog.panel.get_node_or_null("Title").text == GameOverDialog.TITLE_TEXT,
		"the card's plaque reads GAME OVER")
	await _frames(4)
	_shot(OUT_CARD)
	_shot_zoom(OUT_ZOOM, Rect2(150.0, 110.0, 340.0, 250.0), 2)
	print("CARD: title=%s body=%s button=%s" % [
		GameOverDialog.TITLE_TEXT, GameOverDialog.BODY_TEXT, GameOverDialog.BUTTON_TEXT])
	if _fails == 0:
		print("shot_gameover: PASS")
		quit(0)
	else:
		printerr("shot_gameover: %d FAILURE(S)" % _fails)
		quit(1)
