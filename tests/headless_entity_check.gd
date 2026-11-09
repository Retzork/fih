extends SceneTree
## Headless check for the entity seam and the Food rules (P4.3).
##
##   & "<godot>" --headless --path . --script res://tests/headless_entity_check.gd
##
## Covers what P4.4+ will build on: entities tick only through `Sim` in the phase the tank assigned,
## despawn unregisters, teardown clears, the pause gate holds the whole level, the RNG is per-tank and
## reproducible, and `Food::Update`'s decoded steps (fall 1.5, drift decay, x clamp, death lines,
## the `FUN_004D62D0` bottom life (EV-0159),
## star/breeding removals, lifetime, inedible countdown, animation wrap, bob bands) match P2.3 §1.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const FoodScript := preload("res://scripts/entities/food.gd")

var _failures := 0
var _checks := 0


class Probe extends SimEntity:
	var log: Array
	var tag: String

	func _init(shared_log: Array = [], label: String = "probe") -> void:
		log = shared_log
		tag = label

	func _advance() -> void:
		log.append(tag)


class PauseStub extends Node:
	var gameplay_paused := false


func _init() -> void:
	var sim: Node = SimScript.new()
	var tank: Tank = TankScript.new()
	tank.setup(sim, 424242)

	var order: Array = []
	var fish := Probe.new(order, "fish")
	var food_probe := Probe.new(order, "food")

	tank.spawn(fish, SimScript.Phase.FISH)
	tank.spawn(food_probe, SimScript.Phase.FOOD)
	_expect(tank.entity_count() == 2, "tank tracks both entities")

	# --- the tank is the only thing that registers ----------------------------------
	_expect(fish.phase == SimScript.Phase.FISH and food_probe.phase == SimScript.Phase.FOOD,
		"spawn assigns the phase to the entity")
	_expect(tank.layer_for(SimScript.Phase.FISH).get_child_count() == 1, "entity is parented to its phase layer")
	_expect(tank.layer_for(SimScript.Phase.FOOD).z_index < tank.layer_for(SimScript.Phase.FISH).z_index,
		"food draws under fish (layer order)")

	_ticks(sim, 1)
	_expect(order == ["fish", "food"], "one tick runs entities in phase order, got %s" % [order])
	_expect(fish.ticks_alive == 1 and food_probe.ticks_alive == 1, "each entity counted one tick")

	# --- despawn unregisters ------------------------------------------------------
	order.clear()
	food_probe.despawn()
	_expect(food_probe.dead, "despawn marks the entity dead")
	_expect(tank.entity_count() == 1, "despawn drops it from the tank's live entities")
	_ticks(sim, 1)
	_expect(order == ["fish"], "a despawned entity is no longer ticked, got %s" % [order])

	# --- pause gate ---------------------------------------------------------------
	order.clear()
	tank.paused = true
	_ticks(sim, 1)
	_expect(order.is_empty(), "the level pause stops every entity")
	tank.paused = false
	var stub := PauseStub.new()
	stub.gameplay_paused = true
	tank.pause_source = stub
	_ticks(sim, 1)
	_expect(order.is_empty(), "the app-level pause gate stops every entity")
	stub.gameplay_paused = false
	_ticks(sim, 1)
	_expect(order == ["fish"], "clearing both gates resumes ticking, got %s" % [order])
	tank.pause_source = null

	# --- teardown -----------------------------------------------------------------
	tank.shutdown()
	_expect(tank.entity_count() == 0, "shutdown despawns everything")
	order.clear()
	_ticks(sim, 10)
	_expect(order.is_empty(), "nothing ticks after teardown")

	# --- one seeded RNG per tank --------------------------------------------------
	var a: Tank = TankScript.new()
	var b: Tank = TankScript.new()
	var c: Tank = TankScript.new()
	a.setup(sim, 7)
	b.setup(sim, 7)
	c.setup(sim, 8)
	var a_seq: Array = []
	var b_seq: Array = []
	var c_seq: Array = []
	for i in 5:
		a_seq.append(a.rng.randi_range(0, 449))
		b_seq.append(b.rng.randi_range(0, 449))
		c_seq.append(c.rng.randi_range(0, 449))
	_expect(a_seq == b_seq, "same seed reproduces the same rolls (%s)" % [a_seq])
	_expect(a_seq != c_seq, "a different seed gives different rolls (%s vs %s)" % [a_seq, c_seq])
	_expect(a_seq[0] >= 0 and a_seq[0] <= 449, "roll shape is 0..449, i.e. rand%450")

	# --- Food: construction and counters -----------------------------------------
	var f: Food = FoodScript.create(Vector2(300.0, 50.0), 0, false, 0, 0, tank.rng)
	_expect(f.anim_cycle == 3 or f.anim_cycle == 4, "animation cycle is 3 or 4 ticks of frames")
	_expect(f.vx < 0.0 and f.vy == FoodScript.INITIAL_VY, "ctor drift is leftward and rising")
	var drifting: Food = FoodScript.create(Vector2(300.0, 300.0), 2, true, 0, 0, tank.rng)
	_expect(drifting.vx > 0.0, "kind 2 drifts the other way")

	tank.spawn_at(f, SimScript.Phase.FOOD, Vector2(300.0, 50.0))
	var start_y := f.position.y
	_ticks(sim, 10)
	_expect(is_equal_approx(f.position.y - start_y, 15.0), "10 ticks of fall = 15 px (got %s)" % (f.position.y - start_y))

	var before_frame := f.anim_frame
	_ticks(sim, 1)
	_expect(f.anim_frame == (before_frame + 1) % (f.anim_cycle * 10), "animation advances one frame per tick")

	# --- Food: drift decay and clamp ---------------------------------------------
	var drifter: Food = FoodScript.create(Vector2(300.0, 300.0), 1, false, 0, 0, tank.rng)
	var vx0 := drifter.vx
	tank.spawn_at(drifter, SimScript.Phase.FOOD, Vector2(300.0, 300.0))
	_ticks(sim, 10)
	_expect(is_equal_approx(drifter.vx - vx0, 0.5), "10 ticks of drift decay = 0.5 (%.2f -> %.2f)" % [vx0, drifter.vx])

	var wall: Food = FoodScript.create(Vector2(25.0, 60.0), 1, false, 0, 0, tank.rng)
	tank.spawn_at(wall, SimScript.Phase.FOOD, Vector2(25.0, 60.0))
	_ticks(sim, 40)
	_expect(wall.position.x >= FoodScript.X_MIN, "x clamps at %s (got %.1f)" % [FoodScript.X_MIN, wall.position.x])

	# --- Food: death lines --------------------------------------------------------
	var star: Food = FoodScript.create(Vector2(300.0, 390.0), 0, false, 0, 3, tank.rng)
	_expect(star.death_line() == FoodScript.STAR_DEATH_Y, "a star potion dies at 400, not 410")
	tank.spawn_at(star, SimScript.Phase.FOOD, Vector2(300.0, 390.0))
	_ticks(sim, 10)
	_expect(star.dead, "the star potion is removed at its line")

	var breeder: Food = FoodScript.create(Vector2(300.0, 405.0), 0, false, 2, 1, tank.rng)
	_expect(breeder.inedible == 0x14, "a breeding pellet starts inedible for 0x14 ticks")
	_expect(breeder.is_special() and not breeder.is_edible(), "it is special and inedible")
	tank.spawn_at(breeder, SimScript.Phase.FOOD, Vector2(300.0, 405.0))
	_ticks(sim, 10)
	_expect(breeder.dead, "the breeding pellet is removed at the bottom without a splash")

	# Deviation D-0012 (`Food.SETTLE_TICKS`, shipped 20), then the faithful tail: an ordinary pellet
	# pauses on the floor, resumes sinking, arms `FUN_004D62D0`'s 15-tick life and step 3 removes it.
	var bottom: Food = FoodScript.create(Vector2(300.0, 405.0), 0, false, 0, 0, tank.rng)
	tank.spawn_at(bottom, SimScript.Phase.FOOD, Vector2(300.0, 405.0))
	# 405 -> 411 in four ticks, the tick that reaches the line.
	_ticks(sim, 4)
	_expect(not bottom.dead, "the pellet survives the tick it reaches the floor")
	_expect(is_equal_approx(bottom.position.y, FoodScript.DEATH_Y),
		"D-0012: it parks on the death line (got %.1f)" % bottom.position.y)
	_expect(bottom.lifetime == 0, "D-0012: the rest arms no bottom life yet")
	_ticks(sim, FoodScript.SETTLE_TICKS)
	_expect(not bottom.dead and is_equal_approx(bottom.position.y, FoodScript.DEATH_Y),
		"D-0012: it rests for the whole SETTLE_TICKS window")
	_ticks(sim, 1)
	_expect(bottom.position.y > FoodScript.DEATH_Y,
		"D-0012: it resumes sinking after the rest (got %.1f)" % bottom.position.y)
	_expect(bottom.lifetime == FoodScript.BOTTOM_LIFETIME,
		"crossing the line again arms the 15-tick life (got %d)" % bottom.lifetime)
	_ticks(sim, FoodScript.BOTTOM_LIFETIME)
	_expect(bottom.dead, "it is removed when that bottom life runs out")

	# --- Food: lifetime and the landed bob ----------------------------------------
	var timer: Food = FoodScript.create(Vector2(300.0, 100.0), 0, false, 0, 0, tank.rng)
	timer.lifetime = 5
	tank.spawn_at(timer, SimScript.Phase.FOOD, Vector2(300.0, 100.0))
	_ticks(sim, 5)
	_expect(timer.dead, "a pellet with a lifetime removes itself when it hits 0")

	var bobber: Food = FoodScript.create(Vector2(300.0, 200.0), 0, true, 0, 0, tank.rng)
	tank.spawn_at(bobber, SimScript.Phase.FOOD, Vector2(300.0, 200.0))
	_ticks(sim, 1)
	_expect(is_equal_approx(bobber.position.y, 192.0), "a landed pellet rises 8 px from >=150 (got %.1f)" % bobber.position.y)
	# 28 more ticks walk the bands down to 119.5; the tick after that flips the gate (step 5's else).
	_ticks(sim, 28)
	var top_y := bobber.position.y
	_expect(top_y <= 120.0, "the bob tops out just under 120 (got %.1f)" % top_y)
	_ticks(sim, 1)
	_expect(bobber.gate, "the gate flips on the tick after it tops out (y=%.1f)" % bobber.position.y)
	_ticks(sim, 10)
	_expect(bobber.position.y > top_y + 10.0, "with the gate set it falls again (%.1f -> %.1f)" % [top_y, bobber.position.y])

	# --- Food: homing -------------------------------------------------------------
	var sucked: Food = FoodScript.create(Vector2(100.0, 300.0), 0, false, 0, 0, tank.rng)
	sucked.homing = true
	tank.spawn_at(sucked, SimScript.Phase.FOOD, Vector2(100.0, 300.0))
	_ticks(sim, 1)
	_expect(is_equal_approx(sucked.position.x, 100.0 + (550.0 - 100.0) / 7.0),
		"homing is a seventh of the remaining distance per tick (got %.2f)" % sucked.position.x)
	_expect(sucked.position.y < 300.0, "homing also rises toward y 30")

	tank.shutdown()
	sim.free()
	tank.free()
	a.free()
	b.free()
	c.free()
	stub.free()

	if _failures == 0:
		print("headless_entity_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_entity_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


## Exactly `count` logic ticks, with no carried backlog from a previous scenario.
func _ticks(sim: Node, count: int) -> void:
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
