extends SceneTree
## Temporary R8 capture aid (not a game entry point). Boots the real main path, starts a
## requested tank/level windowed, stages the threat and saves a screenshot.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_r8.gd -- tank=2 level=4 out=shot_r8_2_4.png
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_r8.gd -- tank=1 level=2 stage=coins out=shot_r8_coins.png
##
## Outputs are written under `docs/captures/`. Pass `--audio-driver Dummy`: a capture run needs no sound, and staying off WASAPI keeps the audio
## device (which Godot re-opens in a tight loop when Windows invalidates it - see the 2026-11-10
## godot.log) out of a debug run that can hang.

func _initialize() -> void:
	_run()


func _advance_ticks(ticks: int) -> void:
	var sim := root.get_node_or_null("Sim")
	for i in ticks:
		sim.call("advance", sim.TICK_MS)


func _first_fish(level: Level) -> Fish:
	for e in level.tank.entities:
		if e is Fish and not e.dead:
			return e
	return null


func _first_coin(level: Level) -> Coin:
	for e in level.tank.entities:
		if e is Coin and not e.dead:
			return e
	return null


func _run() -> void:
	var tank_no := 2
	var level_no := 4
	var out := "shot_r8_2_4.png"
	var stage := "wave"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tank="):
			tank_no = int(arg.trim_prefix("tank="))
		elif arg.begins_with("level="):
			level_no = int(arg.trim_prefix("level="))
		elif arg.begins_with("out="):
			out = arg.trim_prefix("out=")
		elif arg.begins_with("stage="):
			stage = arg.trim_prefix("stage=")
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	# Autoloads are nodes under root; resolve them without relying on global names in --script mode.
	var game := root.get_node_or_null("Game")
	var sim := root.get_node_or_null("Sim")
	if game == null or sim == null:
		push_error("autoloads missing: Game=%s Sim=%s" % [game, sim])
		quit(1)
		return
	# Let the Content LoadingThread phase finish behind the menu. The load is budgeted per frame, so
	# a fixed frame count races it (the first run of the day imports textures and stalls): poll for
	# the selector the loading phase mounts instead.
	print("R8: waiting for content")
	var selector := root.find_child("GameSelector", true, false)
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null:
			break
	# The selector mounts before the LoadingThread phase is done: a capture taken at 312/326 shows
	# art that is simply not loaded yet (seen on the 5-1 boss run, 2026-11-10), so finish the phase
	# before staging anything.
	var content := root.get_node_or_null("Content")
	if content != null:
		for i in 2400:
			if content.is_phase_complete(content.Phase.LOADING):
				break
			content.pump(50.0)
			await process_frame
		print("R8: content loaded; profile=", game.profile)
	game.profile.tank = tank_no
	game.profile.level = level_no
	if selector == null:
		push_error("GameSelector never mounted (content did not finish loading)")
		quit(1)
		return
	selector.press(1, {})
	print("R8: pressed adventure")
	for i in 12:
		await process_frame
	var level: Level = root.find_child("Level", true, false)
	print("R8: level=", level)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	if tank_no == 5:
		# `start_level` already spawned Cyrax; run past the 300-tick arrival and the first
		# 75-tick Minisylvester, then let a pulse wave join.
		print("R8: advancing boss")
		for i in 45:
			sim.call("advance", 1000.0)
		print("R8: boss advanced, aliens=", level.tank.alien_count())
		for i in 30:
			await process_frame
	else:
		# Force this level's stored wave to arrive now, then let it play.
		if stage == "wave":
			print("R8: arming wave selection=", level.alien_selection)
			level.arm_wave(level.alien_selection, 5)
			for i in 20:
				print("R8: advance ", i, " aliens=", level.tank.alien_count())
				sim.call("advance", 1000.0)
			print("R8: wave advanced, aliens=", level.tank.alien_count())
			for e in level.tank.entities:
				print("R8: entity ", e.get_class(), " ", e)
		elif stage == "coins":
			# R8's coin-drop criterion, through the real path: feed a live fish, let it grow and run
			# its slot-81 counter until a coin exists, then shoot the frame.
			print("R8: staging coin drops")
			for attempt in 80:
				var fish = _first_fish(level)
				if fish == null:
					print("R8: no live fish to feed")
					break
				level.drop_food(fish.position + Vector2(40.0, 40.0))
				_advance_ticks(40)
				if _first_coin(level) != null:
					print("R8: coin dropped after ", attempt, " feeds")
					break
			for i in 12:
				await process_frame
		elif stage == "alien":
			print("R8: spawning single alien")
			var one = level.tank.spawn_alien(5, Vector2(200.0, 220.0))
			level.wire_alien(one)
		for i in 30:
			print("R8: frame ", i, " valid=", is_instance_valid(level),
				" completed=", level.completed, " entities=", level.tank.entities.size(),
				" aliens=", level.tank.alien_count())
			await process_frame
		# A Destructor volley against a fish, so missiles are on screen.
		if stage == "wave":
			print("R8: spawning destructor")
			level.spawn_guppy(Vector2(500.0, 300.0), 2)
			var destructor = level.tank.spawn_alien(5, Vector2(200.0, 220.0))
			level.wire_alien(destructor)
			destructor.attack_timer = 1
			for i in 8:
				print("R8: volley advance ", i, " projectiles=", level.tank.projectile_count())
				sim.call("advance", 1000.0)
			print("R8: volley advanced, projectiles=", level.tank.projectile_count())
			for i in 10:
				print("R8: volley frame ", i)
				await process_frame
	if content != null:
		print("R8: content %d/%d" % [content.loaded_count(), content.EXPECTED_TOTAL])
	print("R8: taking screenshot")
	var shot := root.get_texture().get_image()
	print("R8: saving ", out, " size=", shot.get_size())
	shot.save_png("res://docs/captures/" + out)
	print(out, " ", shot.get_size())
	quit(0)
