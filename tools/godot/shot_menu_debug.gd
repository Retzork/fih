extends SceneTree
## Windowed verification aid for the 2026-11-14 MENU -> Options pass (not a game entry point).
## Boots the real main path, starts Adventure, clicks the tank MENU button and checks that the
## base-art Options dialog opens over a *frozen* tank: the level clock, the wave clock and fish
## hunger must not advance while it is up. It then drives the port-only debug buttons (money,
## guppy, grow) through the real dialog, captures `shot_menu_options.png`, exercises the Help
## replacement (Escape closes it), and finally leaves through Back to Main Menu. Leg 2 drives the
## F1/F2/F3/F10 keys on a fresh tank.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_menu_debug.gd

func _initialize() -> void:
	_run()


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event, true)
	var up := event.duplicate()
	up.pressed = false
	root.push_input(up, true)


func _click(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	var up := down.duplicate()
	up.pressed = false
	root.push_input(up, true)


func _shot(out: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://" + out)
	print("SHOT ", out, " ", image.get_size())


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


## A texture whose alpha companion was composed (P3.3): native size and a clear corner.
func _masked_art(texture: Texture2D, expected: Vector2i) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	return image != null and image.get_size() == expected and image.get_pixel(0, 0).a < 0.01


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var main := scene
	var content := root.get_node_or_null("Content")
	var game := root.get_node_or_null("Game")
	var sim := root.get_node_or_null("Sim")
	if content == null or game == null or sim == null:
		push_error("autoloads missing")
		quit(1)
		return

	print("PROBE: waiting for the selector")
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
	print("PROBE: content loaded ", content.loaded_count(), "/", content.EXPECTED_TOTAL)

	# --- leg 1: tank -> MENU -> Options -> debug -> Help -> Back to Menu ----
	selector.press(1, {})
	await _wait(30)
	var level: Level = main._level
	if level == null:
		push_error("Adventure did not mount a Level")
		quit(1)
		return
	var menu_save := "user://shot_menu_debug.dat"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(menu_save))
	level.save_path = menu_save
	print("PROBE: level mounted tank=", level.tank_index, " level=", level.level_index,
		" money=", level.money)
	await _shot("shot_menu_tank.png")

	var menu: Button = level.store_bar.get_node_or_null("Menu") as Button
	if menu == null:
		push_error("the StoreBar has no MENU button")
		quit(1)
		return
	print("PROBE: MENU rect=", menu.get_global_rect())
	_click(menu)
	await _wait(8)
	if main._options_dialog == null:
		print("PROBE: synthetic click did not open Options; calling press_menu()")
		level.store_bar.press_menu()
		await _wait(8)
	var options: OptionsDialog = main._options_dialog
	if options == null or main._level != level or not game.gameplay_paused:
		push_error("MENU did not open the in-tank Options dialog over a paused tank")
		quit(1)
		return
	if FileAccess.file_exists(menu_save):
		push_error("opening Options alone wrote a save")
		quit(1)
		return

	# The dialog is the base art, not a generic panel. The sheets are masked (P3.3), so a clear
	# corner proves the alpha companion was composed instead of drawing an opaque rectangle.
	var panel := options.panel as NinePatchRect
	if panel == null or not _masked_art(panel.texture, Vector2i(240, 240)):
		push_error("Options is not drawing the masked base Dialogue-panel art")
		quit(1)
		return
	var music_track: TextureRect = null
	if options.music_slider != null:
		music_track = options.music_slider.get_node_or_null("Track") as TextureRect
	var sfx_thumb: TextureRect = null
	if options.sfx_slider != null:
		sfx_thumb = options.sfx_slider.get_node_or_null("Thumb") as TextureRect
	if music_track == null or not _masked_art(music_track.texture, Vector2i(156, 17)) \
			or sfx_thumb == null or not _masked_art(sfx_thumb.texture, Vector2i(33, 32)):
		push_error("Options sliders are not drawing the masked base SLIDERTRACK/SLIDERWIDGET art")
		quit(1)
		return
	var check_icon := options.control(&"Fullscreen").get_node_or_null("Icon") as TextureRect
	if check_icon == null or not _masked_art(check_icon.texture, Vector2i(46, 45)):
		push_error("Options checkboxes are not drawing the masked Checkbutton art")
		quit(1)
		return
	if options.control(&"Title") == null or (options.control(&"Title") as Label).text != "OPTIONS":
		push_error("Options has no OPTIONS title plaque")
		quit(1)
		return
	if options.control(&"BackToMenu") == null or not options.control(&"BackToMenu").visible:
		push_error("in-level Options does not show Back to Main Menu")
		quit(1)
		return
	if options.control(&"Debug") == null or not options.control(&"Debug").visible:
		push_error("in-level Options does not show the port-only DEBUG row")
		quit(1)
		return

	# Real pause: the shared gate is wired into the tank and the level clock stops.
	if level.tank.pause_source != game or not level.tank.is_paused():
		push_error("the Options pause did not reach Tank.is_paused()")
		quit(1)
		return
	var paused_age: int = level.tank.age_ticks
	var paused_wave: int = level.wave.timer if level.wave != null else -1
	var fish_before: int = level.tank.entities_in(sim.Phase.FISH).size()
	var watched: Fish = null
	for entity in level.tank.entities_in(sim.Phase.FISH):
		if entity is Fish and not entity.dead:
			watched = entity
			break
	var paused_fullness: int = watched.fullness if watched != null else -1
	await _wait(30)
	if level.tank.age_ticks != paused_age:
		push_error("the level clock advanced while Options was open (%d -> %d)"
			% [paused_age, level.tank.age_ticks])
		quit(1)
		return
	if level.wave != null and level.wave.timer != paused_wave:
		push_error("the wave clock advanced while Options was open (%d -> %d)"
			% [paused_wave, level.wave.timer])
		quit(1)
		return
	if watched != null and watched.fullness != paused_fullness:
		push_error("fish hunger advanced while Options was open (%d -> %d)"
			% [paused_fullness, watched.fullness])
		quit(1)
		return
	print("PROBE: pause frozen age=", paused_age, " wave=", paused_wave,
		" fullness=", paused_fullness)

	# The debug controls are their own dialog (D-0017). Capture Options, open DEBUG, drive the same
	# three actions through Main, capture the debug dialog, then CLOSE back to Options.
	await _shot("shot_menu_options.png")
	var money_before: int = level.money
	var debug_row := options.control(&"Debug") as Button
	if debug_row == null:
		push_error("the Options dialog has no DEBUG row")
		quit(1)
		return
	_click(debug_row)
	await _wait(6)
	if main._debug_dialog == null:
		print("PROBE: synthetic DEBUG click missed; emitting debug_requested")
		options.debug_requested.emit()
		await _wait(6)
	var debug_dialog: DebugDialog = main._debug_dialog
	if debug_dialog == null or main._level != level or not game.gameplay_paused:
		push_error("DEBUG did not open the debug dialog over the paused tank")
		quit(1)
		return
	var debug_panel := debug_dialog.panel as NinePatchRect
	if debug_panel == null or not _masked_art(debug_panel.texture, Vector2i(240, 240)):
		push_error("the debug dialog is not drawing the masked base Dialogue-panel art")
		quit(1)
		return
	if main._options_dialog != null:
		push_error("Options stayed open behind the debug dialog")
		quit(1)
		return
	var money_button := debug_dialog.debug_button_for(&"money")
	if money_button == null:
		push_error("the debug dialog has no money button")
		quit(1)
		return
	_click(money_button)
	await _wait(3)
	if level.money != money_before + Level.DEBUG_MONEY_STEP:
		print("PROBE: synthetic money click missed; emitting pressed")
		money_button.pressed.emit()
		await _wait(3)
	if level.money != money_before + Level.DEBUG_MONEY_STEP:
		push_error("the debug dialog's money button did not add %d (money %d)"
			% [Level.DEBUG_MONEY_STEP, level.money])
		quit(1)
		return
	var guppy_button := debug_dialog.debug_button_for(&"guppy")
	if guppy_button == null:
		push_error("the debug dialog has no guppy button")
		quit(1)
		return
	guppy_button.pressed.emit()
	await _wait(3)
	if level.tank.entities_in(sim.Phase.FISH).size() != fish_before + 1:
		push_error("the debug dialog's guppy button did not spawn a fish")
		quit(1)
		return
	var new_fish: Fish = null
	for entity in level.tank.entities_in(sim.Phase.FISH):
		if entity is Fish and not entity.dead and entity != watched:
			new_fish = entity
	var grow_button := debug_dialog.debug_button_for(&"grow")
	if grow_button == null:
		push_error("the debug dialog has no grow button")
		quit(1)
		return
	grow_button.pressed.emit()
	await _wait(3)
	if new_fish != null and new_fish.stage <= 0:
		push_error("the debug dialog's grow button did not advance the new guppy")
		quit(1)
		return
	print("PROBE: debug money ", money_before, " -> ", level.money,
		" fish ", fish_before, " -> ", level.tank.entities_in(sim.Phase.FISH).size(),
		" new_stage=", new_fish.stage if new_fish != null else -1,
		" still_paused=", level.tank.is_paused())
	await _shot("shot_debug_dialog.png")
	var debug_close := debug_dialog.panel.get_node_or_null("Close") as Button
	if debug_close == null:
		push_error("the debug dialog has no CLOSE button")
		quit(1)
		return
	_click(debug_close)
	await _wait(6)
	if main._debug_dialog != null:
		print("PROBE: synthetic CLOSE click missed; emitting closed")
		debug_dialog.closed.emit()
		await _wait(6)
	if main._debug_dialog != null or main._options_dialog == null or not game.gameplay_paused:
		push_error("CLOSE did not hand the modal slot back to Options")
		quit(1)
		return
	options = main._options_dialog
	print("PROBE: debug closed, back in Options")

	var ok := options.control(&"OK") as Button
	if ok == null:
		push_error("the Options dialog has no OK button")
		quit(1)
		return
	_click(ok)
	await _wait(8)
	if main._options_dialog != null:
		print("PROBE: synthetic OK click missed; emitting closed")
		options.closed.emit()
		await _wait(8)
	print("PROBE: OK closed=", main._options_dialog == null,
		" level_kept=", main._level == level,
		" paused=", game.gameplay_paused)
	if main._options_dialog != null or main._level != level or game.gameplay_paused:
		push_error("OK did not close Options and resume the same tank")
		quit(1)
		return

	# Resume really ticks again.
	var resumed_age: int = level.tank.age_ticks
	await _wait(5)
	if level.tank.age_ticks <= resumed_age:
		push_error("the level clock did not resume after OK")
		quit(1)
		return
	print("PROBE: resumed age ", resumed_age, " -> ", level.tank.age_ticks)

	# Reopen, then Help replaces Options with the existing Help screen and keeps the tank paused.
	_click(menu)
	await _wait(8)
	if main._options_dialog == null:
		print("PROBE: synthetic second MENU click missed; calling press_menu()")
		level.store_bar.press_menu()
		await _wait(8)
	options = main._options_dialog
	if options == null:
		push_error("MENU did not reopen Options")
		quit(1)
		return
	var help_button := options.control(&"Help") as Button
	if help_button == null:
		push_error("the Options dialog has no Help button")
		quit(1)
		return
	_click(help_button)
	await _wait(8)
	if main._help_dialog == null:
		print("PROBE: synthetic Help click missed; emitting help_requested")
		options.help_requested.emit()
		await _wait(8)
	if main._help_dialog == null or not game.gameplay_paused or not level.tank.is_paused():
		push_error("Help did not replace Options over the paused tank")
		quit(1)
		return
	await _shot("shot_menu_help.png")
	_key(KEY_ESCAPE)
	await _wait(8)
	if main._help_dialog != null or game.gameplay_paused:
		push_error("Escape did not close Help and resume the tank")
		quit(1)
		return
	print("PROBE: Help closed on Escape, paused=", game.gameplay_paused)

	# Reopen once more and leave through Back to Main Menu.
	_click(menu)
	await _wait(8)
	if main._options_dialog == null:
		print("PROBE: synthetic third MENU click missed; calling press_menu()")
		level.store_bar.press_menu()
		await _wait(8)
	options = main._options_dialog
	if options == null:
		push_error("MENU did not reopen Options for the leave path")
		quit(1)
		return
	var back := options.control(&"BackToMenu") as Button
	if back == null:
		push_error("the Options dialog has no Back to Menu button")
		quit(1)
		return
	_click(back)
	await _wait(8)
	if main._level != null:
		print("PROBE: synthetic Back to Menu click missed; emitting back_to_menu")
		options.back_to_menu.emit()
		await _wait(8)
	print("PROBE: Back to Menu released=", main._level == null,
		" selector=", main._selector is GameSelector,
		" save=", FileAccess.file_exists(menu_save))
	await _shot("shot_menu_return.png")
	if main._level != null or not (main._selector is GameSelector):
		push_error("Back to Menu did not return to the main menu")
		quit(1)
		return

	# --- leg 2: F1 panel and the debug keys ----------------------------------
	selector = main._selector
	selector.press(1, {})
	await _wait(30)
	level = main._level
	if level == null:
		push_error("Adventure did not mount a Level the second time")
		quit(1)
		return
	level.save_path = "user://shot_menu_debug.dat"

	_key(KEY_F1)
	await _wait(4)
	var panel_visible: bool = level.debug_panel != null and level.debug_panel.visible
	var keys_money_before: int = level.money
	_key(KEY_F2)
	await _wait(3)
	var keys_money_after: int = level.money
	var keys_fish_before: int = level.tank.entities_in(sim.Phase.FISH).size()
	var stage_before := -1
	for entity in level.tank.entities_in(sim.Phase.FISH):
		if entity is Fish and not entity.dead:
			stage_before = entity.stage
			break
	_key(KEY_F3)
	await _wait(3)
	var stage_after := -1
	for entity in level.tank.entities_in(sim.Phase.FISH):
		if entity is Fish and not entity.dead:
			stage_after = entity.stage
			break
	_key(KEY_F10)
	await _wait(3)
	var keys_fish_after: int = level.tank.entities_in(sim.Phase.FISH).size()
	print("PROBE: F1 visible=", panel_visible,
		" money ", keys_money_before, " -> ", keys_money_after,
		" stage ", stage_before, " -> ", stage_after,
		" fish ", keys_fish_before, " -> ", keys_fish_after)
	await _shot("shot_debug_panel.png")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_menu_debug.dat"))
	print("PROBE: done")
	quit(0)
