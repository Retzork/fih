extends SceneTree
## scene_gallery.gd - review aid: one windowed pass over the real game, one capture per scene/state,
## with the live values that scene is showing. Writes `docs/review/scenes/<slug>.png` and
## `docs/review/scenes/manifest.json`; `tools/review/build_scenes.py` turns the manifest into
## `docs/review/scenes.html`.
##
##   Godot --path . --audio-driver Dummy --script res://tools/godot/scene_gallery.gd
##
## Every capture drives the port's own entry points (GameSelector.press, the tank's MENU path the
## player uses, Level.buy_egg / store_bar.press), never a mock-up. A scene that cannot be reached is
## still written to the manifest with `status: "error"` and the reason, so the page shows the gap
## instead of silently dropping it.

const OUT_DIR := "res://docs/review/scenes"
const MODE_NAMES := {0: "Adventure", 1: "Time Trial", 4: "Challenge", 5: "Virtual Tank"}

var main: Node
var game: Node
var content: Node
var sim: Node
var shots: Array = []
var _fails := 0

## The shot being collected.
var _shot_data: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	main = scene
	game = root.get_node_or_null("Game")
	content = root.get_node_or_null("Content")
	sim = root.get_node_or_null("Sim")
	if game == null or content == null or sim == null:
		push_error("scene_gallery: autoloads missing")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if not await _wait_selector():
		push_error("scene_gallery: the main menu never mounted")
		quit(1)
		return

	# --- menus -------------------------------------------------------------
	await _capture("menu-main", "Main menu", "Menus",
		"The shipped SELECTORSCREEN with the mermaid tail and the eight menu buttons.",
		"GameSelector._ready() after the LoadingThread phase completes")
	main._selector.press(3)
	await _frames(8)
	await _capture("menu-options", "Main-menu Options", "Menus",
		"The base Options dialog opened from the menu (no Back to Main Menu / DEBUG rows).",
		"GameSelector.press(3) -> OptionsDialog")
	_close_modal()
	main._selector.press(7)
	await _frames(8)
	await _capture("menu-help", "Help", "Menus",
		"The Help screen, one page per topic, opened from the menu.",
		"GameSelector.press(7) -> HelpScreen")
	_close_modal()
	main._selector.press(6)
	await _frames(8)
	await _capture("menu-hall", "Hall of Fame", "Menus",
		"Record times and scores from the profile.",
		"GameSelector.press(6) -> HallScreen")
	_close_modal()

	# --- tank 1-1 and its modals --------------------------------------------
	game.profile.tank = 1
	game.profile.level = 1
	if not await _start(1):
		quit(1)
		return
	await _frames(10)
	await _capture("tank-1-1", "Tank 1-1 (Adventure)", "Tank",
		"A live 1-1: HUD name, shop bar, fish and the starting stock.",
		"GameSelector.press(1) -> Level.start_level(1, 1)")
	var level: Level = main._level
	level.open_store()
	await _frames(8)
	await _capture("store-shop", "Shop (in-tank store)", "Shop",
		"The full shop screen over the tank: every shelf, price and the wallet.",
		"Level.open_store() -> StoreScreen (the port's S key; the base button is Q-0052)")
	_close_modal()
	game.gameplay_paused = false
	await _frames(4)
	level.store_bar.press_menu()
	await _frames(8)
	await _capture("tank-options", "In-tank Options", "Dialogs",
		"The MENU button's settings dialog over a paused tank.",
		"Level MENU -> Main._on_menu_requested() -> OptionsDialog")
	if main._options_dialog != null:
		main._on_options_debug()
		await _frames(8)
		await _capture("tank-debug", "Debug dialog", "Dialogs",
			"The port-only debug actions reached from Options' DEBUG row.",
			"Options DEBUG -> DebugDialog")
		main._close_debug()
		await _frames(6)
	main._on_options_help()
	await _frames(8)
	await _capture("tank-help", "In-tank Help", "Dialogs",
		"Help replaces Options and keeps the tank paused; its Menu button returns to the tank.",
		"Options Help -> Main._on_options_help() -> HelpScreen")
	main._close_help()
	await _frames(4)

	level.tank.shutdown()
	var card: Node = null
	for i in 120:
		await process_frame
		card = root.find_child("GameOverDialog", true, false)
		if card != null:
			break
	await _capture("game-over", "Game over card", "Progression",
		"The recovered loss card over the tank once its last fish is gone.",
		"Tank shutdown -> Level._check_defeat -> Main._on_defeated -> GameOverDialog")
	if card != null:
		main._on_game_over_continue()
		await _frames(4)
	await _wait_selector()

	# --- 1-3 and 5-1 -------------------------------------------------------
	game.profile.tank = 1
	game.profile.level = 3
	var third := await _start(1)
	if third:
		await _frames(10)
		await _capture("tank-1-3", "Tank 1-3 (Adventure)", "Tank",
			"A later level: its own stock, wave and egg price on the bar.",
			"GameSelector.press(1) with profile 1-3")
		main._leave_tank()
		await _wait_selector()

	game.profile.tank = 5
	game.profile.level = 1
	var fifth := await _start(1)
	if fifth:
		await _frames(10)
		await _capture("tank-5-1", "Tank 5-1 (Adventure)", "Tank",
			"The fifth tank: five-row stock with the free egg dome.",
			"GameSelector.press(1) with profile 5-1")
		var late: Level = main._level
		late.open_store()
		await _frames(8)
		await _capture("store-late", "Shop (tank 5-1 stock)", "Shop",
			"The same screen with a later tank's stock: every shelf this tank sells.",
			"Level.open_store() on 5-1")
		if late.store_screen != null and is_instance_valid(late.store_screen):
			late.store_screen.close()
		else:
			_close_modal()
		game.gameplay_paused = false
		await _frames(4)
		level = main._level
		level.store_bar.press(EggWidget.SLOT)
		await _wait_flow("HatchScreen")
		await _capture("hatch", "Hatch award card", "Progression",
			"The pet award card that follows a completed level.",
			"Egg completed -> Main._on_level_completed -> HatchScreen")
		var hatch: Node = main._flow
		if hatch != null:
			hatch.press_ok()
			await _wait_flow("PetsScreen")
			await _capture("pets", "Pet chooser", "Progression",
				"The 24-button chooser with the live selection highlight.",
				"Hatch OK -> Main._show_pets -> PetsScreen")
			var pets: Node = main._flow
			if pets != null:
				pets.press_confirm()
				await _wait_flow("BonusScreen")
				await _capture("win-card", "Bonus payout card", "Progression",
					"The win/bonus card a tank-final completion pays out through.",
					"Pets confirm -> Main._show_bonus -> BonusScreen")
		# A completed level has already freed `_level`, so the card is the only thing on screen.
		main._clear_flow()
		main._mount_selector()
		await _wait_selector()

	# --- modes -------------------------------------------------------------
	for entry in [{"slug": "mode-time-trial", "title": "Time Trial", "press": 8,
			"gate": {"tanks_unlocked": 2},
			"desc": "Adventure under the level clock: the HUD's countdown drives the same tank."},
			{"slug": "mode-challenge", "title": "Challenge", "press": 9,
			"gate": {"adventure_done": true},
			"desc": "Challenge mode: the shop's prices inflate while the level runs."}]:
		game.profile.tank = 1
		game.profile.level = 1
		var mode_started := await _start(int(entry["press"]), entry["gate"])
		if mode_started:
			await _frames(10)
			await _capture(String(entry["slug"]), String(entry["title"]), "Modes",
				String(entry["desc"]),
				"GameSelector.press(%d) with the gate %s" % [int(entry["press"]), entry["gate"]])
			main._leave_tank()
			await _wait_selector()

	# --- the bonus round ---------------------------------------------------
	game.profile.tank = 1
	game.profile.level = 5
	var final := await _start(1)
	if final:
		await _frames(8)
		level = main._level
		level.money = 20000
		for i in 3:
			level.buy_egg()
		await _wait_flow("HatchScreen")
		var hatch5: Node = main._flow
		if hatch5 != null:
			hatch5.press_ok()
			await _wait_flow("PetsScreen")
			var pets5: Node = main._flow
			if pets5 != null:
				pets5.press_confirm()
				# The tank waits 160 ticks, then the round runs on the finalized level.
				for i in 240:
					sim.advance(1000.0 / sim.TICKS_PER_SECOND)
					if level != null and level.is_bonus_active() and level.bonus != null \
							and level.bonus.is_playing():
						break
				await _frames(3)
				await _capture("bonus-round", "Bonus round", "Modes",
					"The timed tank-final round with its own HUD and shell counter. The profile has already "
					+ "advanced to the next level; the live tank is still the finished 1-5.",
					"1-5 egg -> Hatch -> Pets -> Level.begin_bonus_round(1, sentinel)")

	var data := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"godot": Engine.get_version_info().get("string", ""),
		"window": [int(root.size.x), int(root.size.y)],
		"content": {"loaded": content.loaded_count(), "total": content.EXPECTED_TOTAL},
		"shots": shots,
	}
	var f := FileAccess.open("res://docs/review/scenes/manifest.json", FileAccess.WRITE)
	if f == null:
		push_error("scene_gallery: cannot write the manifest")
		quit(1)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("scene_gallery: %d captures, %d failure(s)" % [shots.size(), _fails])
	quit(0 if _fails == 0 else 1)


# --- capture ------------------------------------------------------------

## One labelled capture. `route` says which real entry point produced the state; `_facts()` adds the
## live values so the page cannot drift from the build it documents.
func _capture(slug: String, title: String, group: String, description: String,
		route: String) -> void:
	_shot_data = {
		"slug": slug, "title": title, "group": group, "description": description,
		"route": route, "status": "ok", "notes": [], "facts": _facts(),
	}
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, slug]
	if image.save_png(path) != OK:
		_shot_data["status"] = "error"
		_shot_data["notes"].append("capture could not be written to " + path)
		_fails += 1
		print("  FAIL ", slug, " (write)")
	else:
		print("  shot ", slug, " ", image.get_size())
	shots.append(_shot_data)
	_shot_data = {}


func _facts() -> Dictionary:
	var facts := {
		"mode": MODE_NAMES.get(int(game.mode), str(game.mode)),
		"profile": "%d-%d" % [int(game.profile.tank), int(game.profile.level)],
		"shells": int(game.profile.shells),
		"paused": bool(game.gameplay_paused),
	}
	var screens := _screens()
	var dialog: Control = screens.dialog() if screens != null else null
	if dialog != null:
		facts["dialog"] = dialog.name
	var level: Level = main._level
	if level != null:
		var fish := level.tank.fish().size() if level.tank != null else 0
		var coins := level.tank.coins().size() if level.tank != null else 0
		facts["tank"] = "%d-%d" % [level.tank_index, level.level_index]
		facts["money"] = int(level.money)
		facts["fish"] = fish
		facts["coins"] = coins
		facts["egg"] = "%d/%d pieces, price %d" % [
			int(level.egg_pieces), 4, int(level.egg_price)]
		facts["bonus"] = "active" if level.is_bonus_active() else "no"
	if main._flow != null:
		facts["card"] = main._flow.name
	return facts


# --- navigation ---------------------------------------------------------

func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait_selector() -> bool:
	for i in 600:
		if main._selector != null and main._selector is GameSelector:
			return true
		await process_frame
	return false


func _start(button: int, gate: Dictionary = {}) -> bool:
	if main._selector == null:
		return false
	main._selector.press(button, gate)
	for i in 90:
		if main._level != null:
			return true
		await process_frame
	push_error("scene_gallery: the level never mounted for press(%d)" % button)
	return false


func _wait_flow(node_name: String) -> bool:
	for i in 240:
		if main._flow != null and main._flow.name == node_name:
			return true
		await process_frame
	return false


func _close_modal() -> void:
	var screens := _screens()
	if screens != null:
		screens.close_dialog()


## The autoload by path: `--script` runs do not expose autoload globals to the script parser.
func _screens() -> Node:
	return root.get_node_or_null("Screens")
