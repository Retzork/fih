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
	## Set on the probe that unhooks itself mid-tick (the death path's shape).
	var sim: Node = null
	var self_unregister := false

	func _init(shared_log: Array, label: String) -> void:
		log = shared_log
		tag = label

	func _sim_tick() -> void:
		log.append(tag)
		if self_unregister and sim != null:
			sim.unregister(self)


func _init() -> void:
	var sim: Node = SimScript.new()
	var order: Array = []

	# 1. Short frames accumulate; nothing runs until a whole slice exists.
	_expect(sim.advance(0.0) == 0, "advance(0) runs no ticks")
	var tick_ms: float = SimScript.TICK_MS
	_expect(sim.advance(tick_ms * 0.4) == 0, "a sub-slice frame runs no tick")
	_expect(sim.tick_count == 0, "tick counter untouched by partial frames")

	# 2. The rest of the slice completes exactly one tick.
	_expect(sim.advance(tick_ms * 0.6) == 1, "the remaining 60% completes exactly one tick")
	_expect(sim.tick_count == 1, "tick counter advanced by one")

	# 3. Exactly the cap's worth of slices runs the cap.
	_expect(sim.advance(tick_ms * SimScript.MAX_TICKS_PER_FRAME) == SimScript.MAX_TICKS_PER_FRAME,
		"a full cap of slices runs %d ticks" % SimScript.MAX_TICKS_PER_FRAME)

	# 4. Catch-up is capped: half a second still runs at most 10 ticks.
	var capped: int = sim.advance(500.0)
	_expect(capped == SimScript.MAX_TICKS_PER_FRAME, "500 ms is capped at %d ticks (ran %d)" % [
		SimScript.MAX_TICKS_PER_FRAME, capped])

	# 5. A huge stall is clamped to 1 s of backlog, so it can never run more than the cap either.
	var stalled: int = sim.advance(5000.0)
	_expect(stalled == SimScript.MAX_TICKS_PER_FRAME, "a 5 s stall does not spiral (ran %d)" % stalled)
	_expect(sim.backlog_ms() <= SimScript.MAX_BACKLOG_MS, "backlog stays <= %.0f ms" % SimScript.MAX_BACKLOG_MS)
	_expect(sim.backlog_ms() >= SimScript.MAX_BACKLOG_MS - SimScript.MAX_TICKS_PER_FRAME * SimScript.TICK_MS - 0.5,
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
	sim.advance(SimScript.TICK_MS)
	_expect(order == ["fish", "pets", "aliens"], "one tick runs phases in order, got %s" % [order])

	# 7. Re-registering moves a node instead of duplicating it.
	order.clear()
	sim.register_phase(SimScript.Phase.CLOCK, fish)
	sim.advance(SimScript.TICK_MS)
	_expect(order == ["fish", "pets", "aliens"], "moving a node to an earlier phase reorders it, got %s" % [order])

	# 8. Unregister / clear stop the callbacks.
	sim.unregister(pets)
	order.clear()
	sim.advance(SimScript.TICK_MS)
	_expect(order == ["fish", "aliens"], "unregister removes only that node, got %s" % [order])
	sim.clear_registrations()
	order.clear()
	sim.advance(SimScript.TICK_MS)
	_expect(order.is_empty(), "clear_registrations stops every callback, got %s" % [order])

	# 9. Freed nodes are skipped rather than crashing the tick.
	var doomed := Probe.new(order, "doomed")
	sim.register_phase(SimScript.Phase.PARTICLES, doomed)
	doomed.free()
	order.clear()
	sim.advance(SimScript.TICK_MS)
	_expect(order.is_empty(), "a freed registrant is skipped, got %s" % [order])

	# 9b. A node that unhooks itself inside `_sim_tick()` (a corpse removing itself) must not shrink
	# the bucket under the walk - the rest of that phase still ticks this frame.
	var quitter := Probe.new(order, "quitter")
	var middle := Probe.new(order, "middle")
	var tail := Probe.new(order, "tail")
	quitter.sim = sim
	quitter.self_unregister = true
	sim.register_phase(SimScript.Phase.FISH, quitter)
	sim.register_phase(SimScript.Phase.FISH, middle)
	sim.register_phase(SimScript.Phase.FISH, tail)
	order.clear()
	sim.advance(SimScript.TICK_MS)
	_expect(order == ["quitter", "middle", "tail"], "a self-unregistering node does not skip its peers, got %s" % [order])
	order.clear()
	sim.advance(SimScript.TICK_MS)
	_expect(order == ["middle", "tail"], "and it is gone from the next tick, got %s" % [order])
	sim.clear_registrations()

	# 10. The tick->seconds helper is the only place ticks become seconds.
	_expect(is_equal_approx(sim.ticks_to_seconds(roundi(SimScript.TICKS_PER_SECOND)), 1.0),
		"one second worth of ticks is 1 s at %d Hz" % roundi(SimScript.TICKS_PER_SECOND))
	# Q-0034's adopted reading: the wiki-calibrated timers, not the wrapper's 10 ms interval.
	_expect(is_equal_approx(SimScript.TICKS_PER_SECOND, 36.0), "the simulation runs the 36 Hz reading (Q-0034)")

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
