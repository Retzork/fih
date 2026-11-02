extends SceneTree
## Headless check for the Sim tick driver (P4.1).
##
##   & "<godot>" --headless --path . --script res://tests/headless_sim_check.gd
##
## Exits 0 only when every rule of docs/SPECS.md §1.1 holds. Autoloads are not instantiated under
## `--script`, so the driver is constructed directly - which is why `advance()` is free of engine
## timers and scene-tree state.

const SimScript := preload("res://scripts/autoload/sim.gd")

var _failures := 0
var _checks := 0


class Probe extends Node:
	var log: Array
	var tag: String

	func _init(shared_log: Array, label: String) -> void:
		log = shared_log
		tag = label

	func _sim_tick() -> void:
		log.append(tag)


func _init() -> void:
	var sim: Node = SimScript.new()
	var order: Array = []

	# 1. Short frames accumulate; nothing runs until a whole slice exists.
	_expect(sim.advance(0.0) == 0, "advance(0) runs no ticks")
	_expect(sim.advance(4.0) == 0, "a 4 ms frame runs no tick")
	_expect(sim.tick_count == 0, "tick counter untouched by partial frames")

	# 2. 6 more ms completes the first 10 ms slice.
	_expect(sim.advance(6.0) == 1, "4+6 ms completes exactly one 10 ms tick")
	_expect(sim.tick_count == 1, "tick counter advanced by one")

	# 3. A 100 ms frame is 10 ticks - the per-frame cap and the exact multiple coincide.
	_expect(sim.advance(100.0) == SimScript.MAX_TICKS_PER_FRAME, "100 ms = 10 ticks")

	# 4. Catch-up is capped: half a second still runs at most 10 ticks.
	var capped: int = sim.advance(500.0)
	_expect(capped == SimScript.MAX_TICKS_PER_FRAME, "500 ms is capped at %d ticks (ran %d)" % [
		SimScript.MAX_TICKS_PER_FRAME, capped])

	# 5. A huge stall is clamped to 1 s of backlog, so it can never run more than the cap either.
	var stalled: int = sim.advance(5000.0)
	_expect(stalled == SimScript.MAX_TICKS_PER_FRAME, "a 5 s stall does not spiral (ran %d)" % stalled)
	_expect(sim.backlog_ms() <= SimScript.MAX_BACKLOG_MS, "backlog stays <= %.0f ms" % SimScript.MAX_BACKLOG_MS)
	_expect(sim.backlog_ms() >= SimScript.MAX_BACKLOG_MS - SimScript.MAX_TICKS_PER_FRAME * SimScript.TICK_MS,
		"the clamp keeps pending time instead of discarding it (%.0f ms left)" % sim.backlog_ms())

	# From here on the scenarios need a clean clock: the tests above deliberately left a backlog.
	sim.flush_backlog()
	_expect(sim.backlog_ms() == 0.0, "flush_backlog drops pending time")

	# 6. Phase order is the contract from SPECS.md §9.1.
	var fish := Probe.new(order, "fish")
	var pets := Probe.new(order, "pets")
	var aliens := Probe.new(order, "aliens")
	sim.register_phase(SimScript.Phase.FISH, fish)
	sim.register_phase(SimScript.Phase.PETS, pets)
	sim.register_phase(SimScript.Phase.ALIENS, aliens)
	order.clear()
	sim.advance(10.0)
	_expect(order == ["fish", "pets", "aliens"], "one tick runs phases in order, got %s" % [order])

	# 7. Re-registering moves a node instead of duplicating it.
	order.clear()
	sim.register_phase(SimScript.Phase.CLOCK, fish)
	sim.advance(10.0)
	_expect(order == ["fish", "pets", "aliens"], "moving a node to an earlier phase reorders it, got %s" % [order])

	# 8. Unregister / clear stop the callbacks.
	sim.unregister(pets)
	order.clear()
	sim.advance(10.0)
	_expect(order == ["fish", "aliens"], "unregister removes only that node, got %s" % [order])
	sim.clear_registrations()
	order.clear()
	sim.advance(10.0)
	_expect(order.is_empty(), "clear_registrations stops every callback, got %s" % [order])

	# 9. Freed nodes are skipped rather than crashing the tick.
	var doomed := Probe.new(order, "doomed")
	sim.register_phase(SimScript.Phase.PARTICLES, doomed)
	doomed.free()
	order.clear()
	sim.advance(10.0)
	_expect(order.is_empty(), "a freed registrant is skipped, got %s" % [order])

	# 10. The tick->seconds helper is the only place ticks become seconds.
	_expect(is_equal_approx(sim.ticks_to_seconds(100), 1.0), "100 ticks = 1 s at %d Hz" % roundi(SimScript.TICKS_PER_SECOND))

	fish.free()
	pets.free()
	aliens.free()
	sim.free()
	if _failures == 0:
		print("headless_sim_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_sim_check: %d FAILURE(S)" % _failures)
		quit(1)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
