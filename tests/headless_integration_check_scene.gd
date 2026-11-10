extends Node
## Headless integration check: menu -> level -> wave -> boss through the production entry points.
##
##   & "<godot>" --headless --path . res://tests/headless_integration_check.tscn --quit-after 1200
##
## This suite is scene-backed on purpose: `--script` does not expose the project autoloads, so it
## cannot load `main.gd` (which names `Screens`, `Content`, `Audio`, `Sim` and `Game`). Running this
## scene loads the same autoloads and the real `scenes/main.tscn` the game boots.
##
## The test never calls `Level.start_level`, `Level.arm_wave` or `Level.start_boss`. It presses the
## Adventure button on the mounted `GameSelector`; `Main._on_start_requested` then resolves the
## profile start, builds the level and calls `start_level`. The wave is advanced through the shared
## `Sim`, and tank 5 level 1's scheduled boss is spawned by that same `start_level` call.
##
## Tank 5 level 1 starts with Cyrax, so there is no wave in that level. The wave leg uses tank 2
## level 4 (selection 5, a Destructor whose real attack produces a missile) and the boss leg uses
## tank 5 level 1; both start from the menu.

const MainScene := preload("res://scenes/main.tscn")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")
const AlienScript := preload("res://scripts/entities/alien.gd")
const BossScript := preload("res://scripts/entities/boss.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = await _start_from_menu(2, 4, true)
	if main == null or main._level == null:
		_teardown(main)
		_finish()
		return
	var level = main._level
	_expect(level.tank_index == 2 and level.level_index == 4,
		"the menu starts the profile's level 2-4 (got %d-%d)" % [level.tank_index, level.level_index])
	_expect(level.game_mode == Game.Mode.ADVENTURE,
		"the menu writes adventure mode into the level")
	# `start_level` must have armed the wave from the recovered table; the test does not call it.
	_expect(level.alien_selection == 5,
		"the production start arms 2-4's wave selection 5 (got %d)" % level.alien_selection)
	_step(WaveClockScript.WAVE_TICKS)
	_expect(level.tank.alien_count() == 1,
		"one wave alien spawned after %d ticks (got %d)" % [WaveClockScript.WAVE_TICKS, level.tank.alien_count()])
	_expect(level.tank.aliens_present, "the spawned wave raises the tank's aliens-present flag")
	var alien: Alien = _first_alien(level.tank)
	_expect(alien != null and alien.kind == 5,
		"the wave used the level's kind 5 (got %s)" % (str(alien.kind) if alien != null else "none"))
	_expect(alien != null and _visual_source(alien) == "IMAGE_DESTRUCTOR",
		"the Destructor carries its recovered sprite")
	var alien_sprite := _visual_node(alien)
	_expect(alien_sprite != null and alien_sprite.centered,
		"the alien sprite is centred on its 160x160 box")
	var alien_bar := _health_bar(alien)
	_expect(alien_bar != null and alien_bar.visible,
		"the Destructor draws an HP bar")
	_expect(alien_bar != null and alien_bar.position == Vector2(-70.0, 77.0),
		"the bar sits at x 10 / y box-3 inside the box (got %s)" % [_bar_position(alien)])
	_expect(_health_fill(alien) != null and _health_fill(alien).texture != null
		and roundf(_health_fill(alien).region_rect.size.x) == 127.0,
		"a full bar keeps the whole 127-px fill")
	# The bar is a draw rule over `hp / hp0`: 75 of 150 leaves half the fill.
	if alien != null:
		alien.hit(75)
	# Drive the render pass explicitly: `process_frame` resumes before `Level._process` runs.
	level._process(0.0)
	_expect(_health_fill(alien) != null and roundf(_health_fill(alien).region_rect.size.x) == 64.0,
		"at half hp the fill is cut to 64 px (got %s)" % [_fill_width(alien)])

	# No eligible fish means no shot (EV-0158). The 3000-tick wave wait starves the stock
	# guppies, so restock one live victim if they are gone.
	if _live_fish(level.tank).is_empty():
		level.spawn_guppy(Vector2(460.0, 200.0))
	# The Destructor's own 75-tick timer asks the tank for a missile; the spawn path builds its
	# sprite. Its 7-tick intro runs before the attack timer starts counting down.
	_step(AlienScript.INTRO_TICKS + AlienScript.MISSILE_PERIOD)
	_expect(level.tank.projectile_count() == 1,
		"the Destructor's attack spawned one projectile (got %d)" % level.tank.projectile_count())
	var shot: Projectile = _first_projectile(level.tank)
	_expect(shot != null and _visual_source(shot) == "IMAGE_MISSILE",
		"the missile carries its recovered sprite")
	var shot_sprite := _visual_node(shot)
	_expect(shot_sprite != null and shot_sprite.centered,
		"the missile sprite is centred on its 80x80 box")

	# Every UI surface must use the game's own BMFonts at their native pixel size (P2.15 §6), not
	# the engine default scaled to a made-up size.
	var shop: StoreScreen = StoreScreen.new()
	shop.name = "ShopProbe"
	shop.setup(level)
	add_child(shop)
	_expect(_uses_font(shop.get_node_or_null("Shells"), UiFont.STORE_FONT),
		"the store shell counter uses ContinuumBold12 (P2.12 §6)")
	_expect(_uses_font(shop.get_node_or_null("Price0"), UiFont.STORE_FONT),
		"the store price line uses the store font")
	shop.queue_free()
	_expect(_uses_font(level.store_bar.get_node_or_null("Slot0/Price"), UiFont.SMALL_FONT),
		"the in-tank bar price uses the 8 px bold font")
	var bar_bg = level.store_bar.get_node_or_null("Background")
	_expect(bar_bg is TextureRect and bar_bg.texture == Content.texture("IMAGE_MENUBAR"),
		"the level bar draws the recovered MENUBAR art")
	var wallet = level.store_bar.get_node_or_null("Money")
	_expect(wallet != null and wallet.text == str(level.money),
		"the MENUBAR wallet plate shows the tank's money")
	_expect(level.store_bar.get_node("Slot6/Price").text == "",
		"an unstocked dome is empty (no SOLD text)")
	_expect(_uses_font(level.egg_widget.get_node_or_null("Buy/Price"), UiFont.SMALL_FONT),
		"the egg price uses the bar's 8 px bold font")
	# The counts live on the bar itself (the egg dome and the MENUBAR's wallet plate); a second text
	# line under the buy row is a port artifact the owner had removed.
	_expect(level.get_node_or_null("Hud/Info") == null,
		"no info line sits below the buy row")
	_expect(level.egg_widget.position == StoreBar.slot_rect(EggWidget.SLOT).position,
		"the egg widget sits in the bar's empty dome (got %s)" % str(level.egg_widget.position))

	_teardown(main)
	await get_tree().process_frame

	var boss_main = await _start_from_menu(5, 1)
	if boss_main == null or boss_main._level == null:
		_teardown(boss_main)
		_finish()
		return
	var boss_level = boss_main._level
	_expect(boss_level.tank_index == 5 and boss_level.level_index == 1,
		"the menu starts the profile's level 5-1 (got %d-%d)" % [boss_level.tank_index, boss_level.level_index])
	_expect(boss_level.tank.boss_alive, "the scheduled Cyrax boss is alive")
	_expect(boss_level.tank.wave_frozen, "the scheduled boss freezes the wave clock")
	_expect(boss_level.alien_selection == BossScript.KIND,
		"tank 5 level 1 arms the boss kind 0x15 (got %d)" % boss_level.alien_selection)
	var boss: Boss = _first_boss(boss_level.tank)
	_expect(boss != null and boss.kind == BossScript.KIND,
		"the boss entity is Cyrax (got %s)" % (str(boss.kind) if boss != null else "none"))
	_expect(boss != null and boss.hp == BossScript.MAX_HP,
		"the first boss spawn uses 5000 hp (got %s)" % (str(boss.hp) if boss != null else "none"))
	_expect(boss != null and _visual_source(boss) == "IMAGE_BOSS",
		"Cyrax carries the recovered boss sprite")
	var boss_bar := _health_bar(boss)
	_expect(boss_bar != null and boss_bar.visible, "Cyrax always draws an HP bar")
	_expect(boss_bar != null and boss_bar.position == Vector2(-70.0, 77.0),
		"the boss bar uses the same box rule (got %s)" % [_bar_position(boss)])

	# --- 5-1's completion, end to end: the free egg dome is the fourth piece, then Main's
	# Hatch -> Pets -> Bonus flow runs and hands the profile on to 5-2.
	_expect(boss_level.egg_pieces == 3 and boss_level.egg_price == 0,
		"5-1 opens on three pieces with a free egg (got %d at %d)" % [boss_level.egg_pieces, boss_level.egg_price])
	_expect(boss_level.egg_widget.visible,
		"tank 5 draws the same egg dome as the other tanks")
	# The bar redraws on the sim tick (`refresh_if_changed`), so give the level one tick: a level
	# that never ticks (a paused scene) still shows the pre-start rows.
	_step(1)
	var egg_row: Dictionary = StoreBar.row_at(boss_level, EggWidget.SLOT)
	_expect(int(egg_row.get("slot", -1)) == Progression.EGG_ITEM and Store.price_known(egg_row),
		"the seventh dome holds tank 5's free egg row (got %s)" % str(egg_row))
	_expect(boss_level.store_bar.get_node("Slot6/Name").text == ""
		and boss_level.store_bar.get_node("Slot6/Price").text == "",
		"the bar leaves the egg dome to the widget (no text over the art)")
	_expect(boss_level.egg_widget.get_node("Buy/Price").text == "FREE",
		"the free row prices as FREE rather than '0' or the '?' unknown marker")
	_expect(not boss_level.egg_widget.get_node("Buy").disabled,
		"the egg dome is clickable at 200 money")
	var shells_before: int = Game.profile.shells
	var money_before: int = boss_level.money
	var awards: Array = []
	boss_level.level_completed.connect(func(t: int, l: int, pet: int) -> void:
		awards.append([t, l, pet]))
	_expect(boss_level.store_bar.press(EggWidget.SLOT), "the free egg dome buys the fourth piece")
	_expect(boss_level.egg_pieces == 4 and boss_level.completed,
		"the fourth piece completes 5-1 (got %d pieces)" % boss_level.egg_pieces)
	_expect(boss_level.money == money_before,
		"the free row takes nothing from the purse (got %d -> %d)" % [money_before, boss_level.money])
	_expect(awards.size() == 1 and int(awards[0][2]) == Progression.FINAL_BOSS_PET,
		"the completion reports Presto once (got %s)" % str(awards))
	_expect(Game.profile.owns_pet(Progression.FINAL_BOSS_PET),
		"Presto lands on the profile")
	# The win bonus (5000, SPECS §1.2) and the bonus card's own payout (5000, §4.3) are both
	# banked by the completion: the card displays a figure that is already on the profile.
	_expect(Game.profile.shells == shells_before + Progression.FINAL_BOSS_SHELLS + 5000,
		"the win bonus and the card payout bank once each (got %d shells)" % Game.profile.shells)
	_expect(Game.profile.tank == 5 and Game.profile.level == 2 and Game.profile.bonus_adventure
		and Game.profile.tank5_wins == 1,
		"the profile moves to the 5-2 victory gate with the win counted")
	# Main's own handler has run: it frees the level and mounts the award card.
	_expect(boss_main._level == null, "Main releases the completed level")
	_expect(boss_main._flow is HatchScreen and boss_main._flow.pet_index == Progression.FINAL_BOSS_PET,
		"the between-level flow opens on Presto's award card")
	if boss_main._flow is HatchScreen:
		boss_main._flow.press_ok()
	_expect(boss_main._flow is PetsScreen, "the award card leads to the pet selection")
	if boss_main._flow is PetsScreen:
		boss_main._flow.press_confirm()
	# `payout_for(5, ADVENTURE, money, tank5_wins=1, 0)` = clamp(max(1, 0) * 5000, 0, 25000).
	_expect(boss_main._flow is BonusScreen and boss_main._flow.payout == 5000,
		"the bonus card shows the tank-5 payout (got %s)" % str(boss_main._flow.payout if boss_main._flow is BonusScreen else "none"))
	if boss_main._flow is BonusScreen:
		boss_main._flow.press_continue()
	_expect(Game.profile.shells == shells_before + Progression.FINAL_BOSS_SHELLS + 5000,
		"continuing past the card does not pay it again (got %d shells)" % Game.profile.shells)
	_expect(boss_main._level != null and boss_main._level.tank_index == 5 and boss_main._level.level_index == 2,
		"Continue starts the profile's 5-2 (got %s)" % ("%d-%d" % [boss_main._level.tank_index, boss_main._level.level_index] if boss_main._level != null else "none"))

	_teardown(boss_main)
	await get_tree().process_frame
	_finish()


## Mount the real Main scene and press Adventure. Returns Main with `_level` set, or null.
func _start_from_menu(tank_no: int, level_no: int, check_fonts := false):
	Game.profile = Profile.new()
	Game.profile.tank = tank_no
	Game.profile.level = level_no
	var main = MainScene.instantiate()
	add_child(main)
	# Main pumps Content until LoadingThread finishes, then mounts GameSelector on its screen layer.
	for i in 1200:
		main._process(0.016)
		if main._selector != null:
			break
	_expect(main._selector != null, "Main mounts the production menu")
	if main._selector == null:
		return main
	_expect(main._selector is GameSelector, "the mounted menu is a GameSelector")
	if check_fonts:
		_expect(_uses_font(main._selector.get_node_or_null("Button1"), UiFont.SELECTOR_BIG_FONT),
			"the art-slot buttons use the 17 px JungleFever outline font")
		_expect(_uses_font(main._selector.get_node_or_null("Button3"), UiFont.SELECTOR_SMALL_FONT),
			"the small text buttons use the 10 px JungleFever outline font")
	main._selector.press(1, {})
	_expect(main._level != null, "pressing Adventure starts a level through Main")
	return main


func _first_alien(tank) -> Alien:
	for entity in tank.entities:
		if entity is Alien and not entity.dead:
			return entity as Alien
	return null


func _first_boss(tank) -> Boss:
	for entity in tank.entities:
		if entity is Boss and not entity.dead:
			return entity as Boss
	return null


func _first_projectile(tank) -> Projectile:
	for entity in tank.entities:
		if entity is Projectile and not entity.dead:
			return entity as Projectile
	return null


func _live_fish(tank) -> Array:
	var found: Array = []
	for entity in tank.entities:
		if entity is Fish and not entity.dead:
			found.append(entity)
	return found


## The sprite's content id, or "" when the entity has no visual (rendering off or image missing).
func _visual_source(entity) -> String:
	var visual := _visual_node(entity)
	if visual == null:
		return ""
	return String(visual.get_meta("source", ""))


## A control uses `id` and the manifest's native pixel size (no scaled bitmap glyphs).
func _uses_font(control, id: String) -> bool:
	if control == null:
		return false
	return UiFont.applied_id(control) == id \
		and int(control.get_theme_font_size("font_size")) == int(Content.font_size(id))


func _visual_node(entity) -> Sprite2D:
	if entity == null:
		return null
	return entity.get_node_or_null("Visual") as Sprite2D


func _health_bar(entity) -> Node2D:
	if entity == null:
		return null
	return entity.get_node_or_null("HealthBar") as Node2D


func _health_fill(entity) -> Sprite2D:
	var bar := _health_bar(entity)
	if bar == null:
		return null
	return bar.get_node_or_null("Fill") as Sprite2D


func _bar_position(entity) -> String:
	var bar := _health_bar(entity)
	return str(bar.position) if bar != null else "none"


func _fill_width(entity) -> String:
	var fill := _health_fill(entity)
	return str(fill.region_rect.size.x) if fill != null else "none"


func _step(count: int) -> void:
	Sim.flush_backlog()
	for i in count:
		Sim.advance(Sim.TICK_MS)


func _teardown(main) -> void:
	if main != null:
		if main._level != null:
			main._level.tank.shutdown()
		main.free()
	Sim.clear_registrations()
	Sim.flush_backlog()


func _finish() -> void:
	if _checks == 0:
		print("headless_integration_check: no assertions ran")
		get_tree().quit(1)
		return
	if _failures > 0:
		printerr("headless_integration_check: %d FAILURE(S) of %d" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("headless_integration_check: PASS (%d assertions)" % _checks)
	get_tree().quit(0)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
