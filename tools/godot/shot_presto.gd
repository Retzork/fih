extends SceneTree
## Temporary capture aid for the R9 Presto UI (not a game entry point): boots the real main path,
## grants Presto, clears the other pets so the stage reads, then saves the "Recharging..." notice
## (a refused attempt) and the CHANGE-O picker windowed.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_presto.gd

const PET := preload("res://scripts/entities/pet.gd")
const NOTICE_OUT := "shot_presto_recharging.png"
const PICKER_OUT := "shot_presto_picker.png"


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	if game == null or content == null:
		push_error("autoloads missing: Game=%s Content=%s" % [game, content])
		quit(1)
		return
	print("PRESTO: waiting for content")
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
	print("PRESTO: content %d/%d selector=%s" % [content.loaded_count(), content.EXPECTED_TOTAL, selector])
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	# Presto plus a few owned pets, so the picker has candidates and the tank has a live Presto.
	for index in [0, 1, 6, 0x10, PET.PRESTO, 0x11]:
		game.profile.grant_pet(index)
	game.profile.tank = 1
	game.profile.level = 3
	selector.press(1, {})
	for i in 20:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	# A clean stage: keep only the Presto, parked in open water so the notice reads on its own.
	for entity in level.tank.entities.duplicate():
		var other := entity as Pet
		if other != null and other.index != PET.PRESTO:
			other.despawn()
	var presto: Pet = level.presto_pet()
	if presto == null:
		presto = level.tank.spawn_pet(PET.PRESTO, Vector2(300.0, 230.0))
	presto.position = Vector2(300.0, 230.0)
	presto.speed = 0.0
	# 1. The refused attempt: FUN_004F89A0's "Recharging..." over the pet.
	presto.recharge = PET.PRESTO_RECHARGE
	print("PRESTO: recharging attempt opened=", level.open_presto_picker(),
		" notice=", level.presto_notice_visible(), " at=", level.presto_notice_position())
	for i in 10:
		await process_frame
	var shot := root.get_texture().get_image()
	shot.save_png("res://" + NOTICE_OUT)
	print(NOTICE_OUT, " ", shot.get_size())
	# 2. The picker itself, now that the timer is spent.
	level.clear_presto_notice()
	presto.recharge = 0
	print("PRESTO: picker opened=", level.open_presto_picker(), " dialog=", root.get_node("Screens").dialog())
	for i in 14:
		await process_frame
	shot = root.get_texture().get_image()
	shot.save_png("res://" + PICKER_OUT)
	print(PICKER_OUT, " ", shot.get_size())
	quit(0)
