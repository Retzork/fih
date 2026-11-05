extends SceneTree
## Headless check for the Cyrax boss (P4.9).
##
##   & "<godot>" --headless --path . --script res://tests/headless_boss_check.gd
##
## Covers the hp formula, spawn flags (boss alive, waves frozen, forced pet capacity), the 300-tick
## arrival immunity, the 15-tick intro, the 75-tick minion cadence at +40/+40, the 300-tick pulse that
## only fires on a clear field, the 10-tick per-attacker hit cooldown, and the death flags that
## unfreeze and then permanently disable the wave clock.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const BossScript := preload("res://scripts/entities/boss.gd")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")
const LevelScript := preload("res://scripts/tank/level.gd")

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 777)

	_test_hp_formula()
	_test_spawn()
	_test_arrival()
	_test_minions()
	_test_pulse()
	_test_hit_cooldown()
	_test_death_and_waves()
	_test_damage_and_schedule()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_boss_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_boss_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_hp_formula() -> void:
	_expect(BossScript.max_hp_for(1) == 5000, "profile 1 gives 5000 hp")
	_expect(BossScript.max_hp_for(2) == 4875, "profile 2 subtracts one 125 step")
	_expect(BossScript.max_hp_for(21) == 2500, "profile 21 is the floor (got %d)" % BossScript.max_hp_for(21))
	_expect(BossScript.max_hp_for(40) == 2500, "the clamp holds above 21")
	_expect(BossScript.max_hp_for(0) == 5000, "a zero profile clamps to the first step")


func _test_spawn() -> void:
	tank.shutdown()
	var boss: Boss = tank.spawn_boss(2, Vector2(300.0, 400.0))
	_expect(boss.phase == SimScript.Phase.ALIENS, "the boss ticks in the ALIENS phase")
	_expect(boss.hp == 4875 and boss.max_hp == 4875, "the spawn uses the formula's hp")
	_expect(boss.position.y == 290.0, "the boss y clamps to 290 (got %.0f)" % boss.position.y)
	_expect(boss.is_arriving(), "the boss starts its arrival")
	_expect(tank.boss_alive, "the tank flags a live boss")
	_expect(tank.wave_frozen, "the boss freezes the wave clock")
	_expect(tank.pet_capacity == 10, "the boss forces pet capacity 10 (got %d)" % tank.pet_capacity)


func _test_arrival() -> void:
	boss_attack(tank_boss())
	_expect(tank.boss_alive, "the boss is still alive before the shot test")


func _test_minions() -> void:
	tank.shutdown()
	var boss: Boss = tank.spawn_boss(1, Vector2(300.0, 200.0))
	var minions: Array[Vector2] = []
	var origins: Array[Vector2] = []
	boss.minion_requested.connect(func(at: Vector2) -> void:
		minions.append(at)
		origins.append(boss.position))
	_step(BossScript.ARRIVAL_TICKS)
	_expect(not boss.is_arriving(), "the arrival ends after 300 ticks")
	_step(BossScript.INTRO_TICKS_BOSS)
	_expect(boss.intro_timer == 0, "the 15-tick intro ends next")
	_step(BossScript.MINION_TICKS)
	_expect(minions.size() == 1, "the first minion comes 75 ticks into the fight")
	if minions.size() == 1:
		var off := minions[0] - origins[0]
		_expect(absf(off.x - BossScript.MINION_OFFSET.x) < 0.01
			and absf(off.y - BossScript.MINION_OFFSET.y) < 0.01,
			"the minion spawns at +40,+40 (got %s)" % off)


func _test_pulse() -> void:
	tank.shutdown()
	var boss: Boss = tank.spawn_boss(1, Vector2(300.0, 200.0))
	var pulses: Array[Vector2] = []
	boss.pulse_requested.connect(func(at: Vector2) -> void: pulses.append(at))
	_step(BossScript.ARRIVAL_TICKS + BossScript.INTRO_TICKS_BOSS)
	tank.spawn_alien(0x01, Vector2(200.0, 200.0))
	_step(BossScript.PULSE_TICKS)
	_expect(pulses.is_empty(), "no pulse while the field is not clear")
	tank.shutdown()
	boss = tank.spawn_boss(1, Vector2(300.0, 200.0))
	boss.pulse_requested.connect(func(at: Vector2) -> void: pulses.append(at))
	_step(BossScript.ARRIVAL_TICKS + BossScript.INTRO_TICKS_BOSS + BossScript.PULSE_TICKS)
	_expect(pulses.size() == 1, "a clear field pulses every 300 ticks (got %d)" % pulses.size())


func _test_hit_cooldown() -> void:
	tank.shutdown()
	var boss: Boss = tank.spawn_boss(1, Vector2(300.0, 200.0))
	_step(BossScript.ARRIVAL_TICKS + BossScript.INTRO_TICKS_BOSS)
	var attacker := Node.new()
	var before := boss.hp
	boss.hit(30, true, attacker)
	_expect(boss.hp == before - 30, "a shot takes 30 hp")
	boss.hit(30, true, attacker)
	_expect(boss.hp == before - 30, "the same attacker cannot hit again inside 10 ticks")
	_step(10)
	boss.hit(30, true, attacker)
	_expect(boss.hp == before - 60, "the next hit lands after the cooldown")
	boss.hit(30, true, null)
	_expect(boss.hp == before - 90, "a null attacker bypasses the cooldown")
	attacker.free()


func _test_death_and_waves() -> void:
	tank.shutdown()
	tank.wave_frozen = false
	tank.waves_disabled = false
	var clock: WaveClock = tank.spawn_wave_clock()
	clock.selection = 0x01
	_step(10)
	_expect(clock.timer == 10, "an armed clock ticks with no boss")

	var boss: Boss = tank.spawn_boss(1, Vector2(300.0, 200.0))
	var frozen_at := clock.timer
	_step(10)
	_expect(clock.timer == frozen_at, "the live boss freezes the clock")
	_step(BossScript.ARRIVAL_TICKS + BossScript.INTRO_TICKS_BOSS)
	boss.hit(5000, true, null)
	_expect(boss.dead, "the boss dies at 0 hp")
	_expect(not tank.boss_alive, "death clears boss_alive")
	_expect(tank.waves_disabled, "waves are disabled after the boss")
	var after := clock.timer
	_step(20)
	_expect(clock.timer == after, "the clock stays stopped after the boss")


func _test_damage_and_schedule() -> void:
	tank.shutdown()
	_expect(tank.shot_damage() == 6, "a normal shot does 6 (3 * capacity 2)")
	tank.spawn_boss(1, Vector2(300.0, 200.0))
	_expect(tank.shot_damage() == 30, "a boss shot does 30 (3 * capacity 10)")
	_expect(LevelScript.boss_kind_for(5, 1) == BossScript.KIND, "tank 5 level 1 schedules Cyrax")
	_expect(LevelScript.boss_kind_for(5, 2) == 0, "tank 5 level 2 has no boss")
	_expect(LevelScript.boss_kind_for(4, 4) == 0, "tank 4 has no boss")


# --- helpers -----------------------------------------------------------------

func tank_boss() -> Boss:
	for entity in tank.entities:
		if entity is Boss:
			return entity
	return null


func boss_attack(boss: Boss) -> void:
	if boss == null:
		_expect(false, "a boss exists")
		return
	var hp := boss.hp
	boss.hit(100, true, null)
	_expect(boss.hp == hp, "a shot during the arrival is ignored")


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
