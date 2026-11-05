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
## Tank 5 level 1 starts with Cyrax, so there is no wave in that level. The wave leg uses tank 1
## level 3 (selection 2) and the boss leg uses tank 5 level 1; both start from the menu.

const MainScene := preload("res://scenes/main.tscn")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")
const BossScript := preload("res://scripts/entities/boss.gd")

var _checks := 0
var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = await _start_from_menu(1, 3)
	if main == null or main._level == null:
		_teardown(main)
		_finish()
		return
	var level = main._level
	_expect(level.tank_index == 1 and level.level_index == 3,
		"the menu starts the profile's level 1-3 (got %d-%d)" % [level.tank_index, level.level_index])
	_expect(level.game_mode == Game.Mode.ADVENTURE,
		"the menu writes adventure mode into the level")
	# `start_level` must have armed the wave from the recovered table; the test does not call it.
	_expect(level.alien_selection == 2,
		"the production start arms 1-3's wave selection 2 (got %d)" % level.alien_selection)
	_step(WaveClockScript.WAVE_TICKS)
	_expect(level.tank.alien_count() == 1,
		"one wave alien spawned after %d ticks (got %d)" % [WaveClockScript.WAVE_TICKS, level.tank.alien_count()])
	_expect(level.tank.aliens_present, "the spawned wave raises the tank's aliens-present flag")
	var alien: Alien = _first_alien(level.tank)
	_expect(alien != null and alien.kind == 2,
		"the wave used the level's kind 2 (got %s)" % (str(alien.kind) if alien != null else "none"))

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

	_teardown(boss_main)
	await get_tree().process_frame
	_finish()


## Mount the real Main scene and press Adventure. Returns Main with `_level` set, or null.
func _start_from_menu(tank_no: int, level_no: int):
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
