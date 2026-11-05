extends SceneTree
## Headless check for the Alien entity and the wave clock (P4.3/P4.8).
##
##   & "<godot>" --headless --path . --script res://tests/headless_alien_check.gd
##
## Covers the kind table (P2.8 §11), the movement bands and intro drift, the attack timers, the chase +
## reach-test eating, the shot-death Diamond rule, and the 3000-tick wave clock's gate, milestone order,
## one-roll spawn point and composite double spawn.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const AlienScript := preload("res://scripts/entities/alien.gd")
const FishScript := preload("res://scripts/entities/fish.gd")

const SYLVESTER := 0x01
const DESTRUCTOR := 0x05
const ULYSSES := 0x06
const PSYCHOSQUID := 0x07
const MINI := 0x14

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 424242)

	_test_table()
	_test_images()
	_test_boxes_and_hp()
	_test_spawn_and_bands()
	_test_attacks()
	_test_eating()
	_test_death()
	_test_wave_clock()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_alien_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_alien_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_table() -> void:
	var expected := {
		0x01: [50, 2.0], 0x02: [60, 1.6], 0x03: [130, 1.2], 0x04: [100, 1.6],
		0x05: [150, 1.2], 0x06: [220, 3.5], 0x07: [260, 0.5], 0x14: [1, 1.0], 0x15: [5000, 2.0],
	}
	for kind: int in expected:
		var def: Dictionary = AlienScript.DEFS[kind]
		_expect(int(def["hp"]) == int(expected[kind][0]) and float(def["speed"]) == float(expected[kind][1]),
			"kind 0x%X is hp %d / speed %.1f" % [kind, expected[kind][0], expected[kind][1]])
	_expect(not AlienScript.DEFS.has(0x09), "kinds 9..0xC are recipes, not entities")
	_expect(not AlienScript.DEFS.has(0x0C), "kind 0xC is a recipe too")


func _test_images() -> void:
	var expected := {
		0x01: "IMAGE_SYLV", 0x02: "IMAGE_SYLV", 0x03: "IMAGE_BALROG", 0x04: "IMAGE_GUS",
		0x05: "IMAGE_DESTRUCTOR", 0x06: "IMAGE_ULYSSES", 0x07: "IMAGE_PSYCHOSQUID",
		0x08: "IMAGE_BILATERUS", 0x14: "IMAGE_MINISYLV", 0x15: "IMAGE_BOSS",
	}
	for kind: int in expected:
		_expect(AlienScript.image_id_for(kind) == expected[kind],
			"kind 0x%X draws %s" % [kind, expected[kind]])


## P2.9 §5's HP bar divides by the spawn hp (`+0x1F8`) inside the alien's own box, so both values
## come from the entity: 160 box for every kind except the 80x80 Minisylvester, and 0 hp for
## Bilaterus, whose body has none (its two heads carry 100 each).
func _test_boxes_and_hp() -> void:
	var sylvester: Alien = AlienScript.create(SYLVESTER, Vector2.ZERO)
	var mini: Alien = AlienScript.create(MINI, Vector2.ZERO)
	var bilaterus: Alien = AlienScript.create(0x08, Vector2.ZERO)
	_expect(sylvester.box_size() == 160.0, "the alien box is 160x160")
	_expect(mini.box_size() == 80.0, "the Minisylvester box is 80x80")
	_expect(sylvester.initial_hp() == 50, "the HP bar divides by the spawn hp (50)")
	_expect(bilaterus.initial_hp() == 0, "Bilaterus has no body hp, so it gets no bar")
	sylvester.free()
	mini.free()
	bilaterus.free()


func _test_spawn_and_bands() -> void:
	tank.shutdown()
	var alien: Alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	_expect(alien.phase == SimScript.Phase.ALIENS, "aliens tick in the ALIENS phase")
	_expect(alien.hp == 50, "the spawn takes the table hp")
	_expect(alien.intro_timer == AlienScript.INTRO_TICKS, "the intro drift starts at 7 ticks")

	var start_x := alien.position.x
	_step(1)
	_expect(alien.position.x != start_x, "the intro drifts horizontally")

	_step(6)
	_expect(alien.intro_timer == 0, "the intro ends after 7 ticks")

	var wide: Alien = tank.spawn_alien(SYLVESTER, Vector2(600.0, 400.0))
	_step(1)
	_expect(wide.position.x <= 490.0 and wide.position.y <= 290.0,
		"the full band clamps to x -10..490 / y 85..290 (got %s)" % wide.position)

	var mini: Alien = tank.spawn_alien(MINI, Vector2(600.0, 400.0))
	_step(1)
	_expect(mini.position.x == 540.0 and mini.position.y == 370.0,
		"the mini band is 10..540 / 95..370 (got %s)" % mini.position)


func _test_attacks() -> void:
	tank.shutdown()
	var destructor: Alien = tank.spawn_alien(DESTRUCTOR, Vector2(300.0, 200.0))
	var shots: Array[int] = []
	destructor.attack_requested.connect(func(kind: int, _at: Vector2, _t) -> void: shots.append(kind))
	_step(AlienScript.INTRO_TICKS)
	_expect(shots.is_empty(), "no shots during the intro")
	_step(AlienScript.MISSILE_PERIOD)
	_expect(shots == [0], "the first missile fires after 75 ticks, got %s" % [shots])
	_step(AlienScript.MISSILE_PERIOD)
	_expect(shots.size() == 2, "the second missile follows 75 ticks later")
	_step(AlienScript.MISSILE_PERIOD)
	_expect(shots.size() == 3, "the third missile completes the volley")
	_expect(destructor.attack_timer >= AlienScript.MISSILE_TAIL_BASE
		and destructor.attack_timer < AlienScript.MISSILE_TAIL_BASE + AlienScript.MISSILE_TAIL_SPAN,
		"the tail gap is rand%%50 + 150 (got %d)" % destructor.attack_timer)

	tank.shutdown()
	var squid: Alien = tank.spawn_alien(PSYCHOSQUID, Vector2(300.0, 200.0))
	_expect(not squid.resting and squid.speed == 0.5, "the Psychosquid starts slow")
	_step(AlienScript.INTRO_TICKS + AlienScript.REST_TICKS)
	_expect(squid.resting and squid.speed == 2.0, "400 ticks flip it to the fast half")
	_step(AlienScript.REST_TICKS)
	_expect(not squid.resting and squid.speed == 0.5, "another 400 flips it back")


func _test_eating() -> void:
	tank.shutdown()
	var alien: Alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	var fish: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(330.0, 230.0), 0, 1)
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(fish.dead, "a fish inside ±45/±65 is eaten")

	tank.shutdown()
	alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	var far: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(430.0, 200.0), 0, 1)
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(not far.dead, "a fish at 130 px is out of reach")

	tank.shutdown()
	var mini: Alien = tank.spawn_alien(MINI, Vector2(300.0, 200.0))
	var mid: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(400.0, 200.0), 0, 1)
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(not mid.dead, "the mini reach is ±30, so 100 px misses")

	tank.shutdown()
	mini = tank.spawn_alien(MINI, Vector2(300.0, 200.0))
	var close: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(320.0, 200.0), 0, 1)
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(close.dead, "a mini eats inside its ±30 box")

	tank.shutdown()
	var destructor: Alien = tank.spawn_alien(DESTRUCTOR, Vector2(300.0, 200.0))
	var safe: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(305.0, 205.0), 0, 1)
	_step(AlienScript.INTRO_TICKS + 1)
	_expect(not safe.dead, "kinds 5 and 6 never eat")


func _test_death() -> void:
	tank.shutdown()
	tank.boss_alive = false
	var alien: Alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	var deaths: Array = []
	alien.died.connect(func(_a, from_shot: bool) -> void: deaths.append(from_shot))
	alien.hit(20)
	_expect(alien.hp == 30 and not alien.dead, "a 20-damage shot leaves 30 hp")
	alien.hit(30)
	_expect(alien.dead, "the next 30 kills it")
	_expect(deaths == [true], "the death reports a shot")
	_expect(tank.coin_count() == 1, "a shot death drops one coin")
	if tank.coin_count() == 1:
		_expect(tank.coins()[0].kind == AlienScript.DIAMOND_KIND, "the drop is the kind-4 Diamond")

	tank.shutdown()
	tank.boss_alive = true
	var boss_time: Alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	boss_time.hit(60)
	_expect(tank.coin_count() == 0, "no Diamond while a boss is alive")

	tank.shutdown()
	tank.boss_alive = false
	var quiet: Alien = tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	quiet.die(false)
	_expect(tank.coin_count() == 0, "a non-shot death drops nothing")
	_expect(quiet.dead, "the alien is removed either way")


func _test_wave_clock() -> void:
	tank.shutdown()
	var clock: WaveClock = tank.spawn_wave_clock()
	var spawns: Array = []
	var marks: Array[String] = []
	clock.alien_spawn_requested.connect(func(sel: int, at: Vector2) -> void: spawns.append([sel, at]))
	clock.milestone.connect(func(name: String) -> void: marks.append(name))

	_step(10)
	_expect(clock.timer == 0, "an unarmed wave clock does not tick")

	clock.selection = SYLVESTER
	_step(10)
	_expect(clock.timer == 10, "an armed clock advances one tick per tick")

	tank.spawn_alien(SYLVESTER, Vector2(300.0, 200.0))
	_step(10)
	_expect(clock.timer == 10, "the clock freezes while an alien is alive")

	tank.shutdown()
	clock = tank.spawn_wave_clock()
	clock.alien_spawn_requested.connect(func(sel: int, at: Vector2) -> void: spawns.append([sel, at]))
	clock.milestone.connect(func(name: String) -> void: marks.append(name))
	clock.selection = SYLVESTER
	_step(WaveClock.WAVE_TICKS)
	_expect(spawns.size() == 1, "one wave spawns one alien")
	_expect(marks == WaveClock.MILESTONES, "the milestones keep their order, got %s" % [marks])
	if spawns.size() == 1:
		var at: Vector2 = spawns[0][1]
		_expect(at.x >= 20.0 and at.x < 470.0 and at.y >= 105.0 and at.y < 300.0,
			"the spawn point is x 20..469 / y 105..299 (got %s)" % at)

	spawns.clear()
	clock.selection = 0x09
	_step(WaveClock.WAVE_TICKS)
	_expect(spawns.size() == 2, "a composite selection spawns two entities")
	if spawns.size() == 2:
		_expect(spawns[0][1] == spawns[1][1], "both members reuse the one rolled point")


# --- helpers -----------------------------------------------------------------

func _step(count: int) -> void:
	sim.flush_backlog()
	for i in count:
		sim.advance(SimScript.TICK_MS)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
