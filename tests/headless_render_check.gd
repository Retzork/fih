extends SceneTree
## headless_render_check - the level's effect layer (`Level._sync_fx`), the one drawing path the rest
## of the suites cannot reach: they run the level with `render = false`, so no sprite is ever built.
##
##   & "<godot>" --headless --path . --script res://tests/headless_render_check.gd
##
## Why it exists: `_sync_fx` used to trim the `FxLayer` with
## `while get_child_count() > wanted.size(): get_child(...).queue_free()`. `queue_free()` only queues a
## node, so the child count never fell inside the frame, the loop never returned and the main thread
## froze the frame an effect expired on (a click's laser spark lives 5 ticks - 139 ms at 36 Hz). That
## spin is what the 2026-11-10 godot.log stops inside and what Windows logged as Application Hang for
## the Godot binary, so the pool size is now pinned to the effect lists in both directions here.

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")

## The spark's own geometry: `FUN_00543640(x - 0x28, y - 0x28)` (`Level.spawn_laser`).
const SPARK_OFFSET := Vector2(40.0, 40.0)

var _checks := 0
var _failures := 0
var sim: Node
var level: Level


func _init() -> void:
	sim = SimScript.new()
	level = LevelScript.new()
	# The starting guppies are built without sprites, exactly as the other suites build them; the
	# drawing pass is switched on afterwards so `_process` runs `_sync_fx` the way the game does.
	level.render = false
	level.setup(sim, 9001)
	level.render = true

	_test_pool_grows()
	_test_pool_shrinks()
	_test_pool_reuses_dots()
	_test_effects_expire_between_frames()

	level.tank.shutdown()
	level.free()
	sim.free()

	if _checks == 0:
		print("headless_render_check: no assertions ran")
		quit(1)
		return
	if _failures > 0:
		print("headless_render_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)
		return
	print("headless_render_check: PASS (%d assertions)" % _checks)
	quit(0)


## One dot per effect, placed and styled from the effect's own record.
func _test_pool_grows() -> void:
	_clear_effects()
	level.spawn_particle(Vector2(100.0, 120.0), "smoke", 10)
	level.spawn_particle(Vector2(130.0, 140.0), "burst", 10)
	level.spawn_laser(Vector2(200.0, 200.0))
	level._process(0.0)
	var fx := _fx()
	_expect(fx != null, "the first drawing pass builds the FxLayer")
	_expect(fx != null and fx.get_child_count() == 3,
		"one dot per effect (got %d of 3)" % (fx.get_child_count() if fx != null else -1))
	if fx == null:
		return
	var smoke := fx.get_child(0) as Sprite2D
	_expect(smoke.position == Vector2(100.0, 120.0), "the smoke dot sits on its particle")
	_expect(smoke.modulate == Color(0.8, 0.8, 0.8, 0.6), "smoke is the grey 60% dot")
	var burst := fx.get_child(1) as Sprite2D
	_expect(burst.modulate == Color(1.0, 0.85, 0.3), "the burst dot is the warm dot")
	var spark := fx.get_child(2) as Sprite2D
	_expect(spark.position == Vector2(200.0, 200.0) - SPARK_OFFSET,
		"the spark sits at the click minus (40,40)")
	_expect(spark.scale == Vector2(4.0, 2.0), "the spark is the flat 4x2 streak")


## The regression: the effect lists empty while the layer still holds dots. Before the fix this call
## never returned - it is the frame the whole game froze on.
func _test_pool_shrinks() -> void:
	_clear_effects()
	level._process(0.0)
	var fx := _fx()
	_expect(fx != null and fx.get_child_count() == 0,
		"expired effects release their dots (got %d)" % (fx.get_child_count() if fx != null else -1))
	level._process(0.0)
	_expect(fx != null and fx.get_child_count() == 0, "an empty layer stays empty on the next frame")


func _test_pool_reuses_dots() -> void:
	_clear_effects()
	for i in 3:
		level.spawn_particle(Vector2(10.0 * (i + 1), 10.0 * (i + 1)), "smoke", 10)
	level._process(0.0)
	var fx := _fx()
	if fx == null or fx.get_child_count() != 3:
		_expect(false, "three particles build three dots before the reuse check")
		return
	var survivor := fx.get_child(0)
	level.particles.remove_at(2)
	level.particles.remove_at(1)
	level._process(0.0)
	_expect(fx.get_child_count() == 1, "shrinking to one effect leaves one dot")
	_expect(fx.get_child(0) == survivor, "the surviving dot is reused, not rebuilt")
	level.particles[0]["pos"] = Vector2(77.0, 88.0)
	level.particles.append({"pos": Vector2(99.0, 111.0), "life": 10, "kind": "burst"})
	level._process(0.0)
	_expect(fx.get_child_count() == 2, "a new effect adds one dot")
	_expect((fx.get_child(0) as Sprite2D).position == Vector2(77.0, 88.0),
		"the reused dot follows the moved particle")


## The crash scenario end to end: a click's spark and a particle age out through the shared tick, then
## the next frame pass draws an empty layer and returns.
func _test_effects_expire_between_frames() -> void:
	_clear_effects()
	level.spawn_laser(Vector2(300.0, 260.0))
	level.spawn_particle(Vector2(310.0, 270.0), "burst", 3)
	level._process(0.0)
	_expect(_fx() != null and _fx().get_child_count() == 2, "the click draws its spark and the burst")
	_step(6)
	_expect(level.laser_sparks.is_empty(), "the spark's 5 ticks run out")
	_expect(level.particles.is_empty(), "the 3-tick particle runs out")
	level._process(0.0)
	_expect(_fx() != null and _fx().get_child_count() == 0,
		"the frame after the effects expire draws nothing and returns")


func _fx() -> Node2D:
	return level._fx_layer


func _clear_effects() -> void:
	level.particles.clear()
	level.laser_sparks.clear()


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
