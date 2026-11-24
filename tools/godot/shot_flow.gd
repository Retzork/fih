extends SceneTree
## Temporary 5-1 completion capture aid (not a game entry point): boots the real main path, takes the
## free egg dome to the fourth piece, then saves the Hatch/Pets/Bonus cards and the next level.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_flow.gd

func _initialize() -> void:
	_run()


func _shot(out: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("res://docs/captures/" + out)
	print(out, " ", image.get_size())


func _run() -> void:
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
		if selector != null and content.is_phase_complete(content.Phase.LOADING):
			break
	game.profile.tank = 5
	game.profile.level = 1
	selector.press(1, {})
	for i in 12:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	print("FLOW: 5-1 mounted, egg pieces=", level.egg_pieces, " price=", level.egg_price)
	# The free egg dome is store slot 6; the same press path the player uses.
	level.store_bar.press(EggWidget.SLOT)
	for i in 12:
		await process_frame
	var hatch: HatchScreen = root.find_child("HatchScreen", true, false)
	if hatch == null:
		push_error("HatchScreen never mounted")
		quit(1)
		return
	for i in 12:
		await process_frame
	print("FLOW: hatch crack=", hatch.get_node_or_null("EggCrack") != null,
		" pet=", hatch.get_node_or_null("Pet") != null)
	_shot("shot_tank5_award.png")
	for i in 240:
		await process_frame
		if hatch.hatched(hatch._elapsed):
			break
	print("FLOW: hatched after ", hatch._elapsed, " s")
	_shot("shot_tank5_hatched.png")
	hatch.press_ok()
	for i in 10:
		await process_frame
	var pets: PetsScreen = root.find_child("PetsScreen", true, false)
	print("FLOW: pets screen=", pets)
	_shot("shot_tank5_pets.png")
	if pets != null:
		pets.press_confirm()
	for i in 10:
		await process_frame
	var bonus: BonusScreen = root.find_child("BonusScreen", true, false)
	print("FLOW: bonus screen=", bonus)
	_shot("shot_tank5_bonus.png")
	if bonus != null:
		bonus.press_continue()
	for i in 20:
		await process_frame
	var next_level: Level = root.find_child("Level", true, false)
	print("FLOW: next level=", next_level,
		" tank/level=", game.profile.tank, "/", game.profile.level)
	_shot("shot_tank5_next.png")
	quit(0)
