extends Node
## Sim - the fixed-timestep simulation driver.
##
## Mirrors the original's loop (SPECS.md §1.1, P2.1/EV-0034): the wrapper accumulates real time and
## runs whole 10 ms logic slices, at most MAX_TICKS_PER_FRAME of them per rendered frame, with the
## backlog clamped to MAX_BACKLOG_MS so a stall cannot produce a spiral of catch-up work.
##
## Q-0034 is unresolved: P2.1 read a 10 ms interval from the SexyAppBase ctor (100 Hz) while every
## gameplay timer in P2.7-P2.9 calibrates at ~36 Hz. TICK_MS is therefore THE single place the rate
## is defined - change it here (and TICKS_PER_SECOND with it), never in a subsystem.
##
## Systems do not use Godot's _physics_process. They register a phase and implement:
##
##     func _sim_tick() -> void
##
## and Sim calls them in the fixed order below, once per logic tick. The order is load-bearing
## (SPECS.md §9.1): a system that runs on its own timer breaks the wave clock's pause contract and
## the pet gates, which read the same tick counters.

## Fixed update order for one logic tick (SPECS.md §9.1).
enum Phase {
	CLOCK,        ## timers, level clock, wave countdown
	FISH,         ## hunger, movement, growth
	PETS,         ## gated pet updates
	ALIENS,       ## movement, eating, attacks
	PROJECTILES,  ## missiles, larvae, balls
	COLLISION,    ## contact, collection, damage resolution
	FOOD,         ## pellet physics, expiry
	PARTICLES,    ## effects, debris, corpses
	COUNT,
}

## One logic slice. Q-0034: 10.0 = the ctor constant (100 Hz); 27.78 would be the ~36 Hz reading.
const TICK_MS := 10.0
const TICKS_PER_SECOND := 1000.0 / TICK_MS
## The original pumps at most 10 single-tick updates per Process() call (P2.1).
const MAX_TICKS_PER_FRAME := 10
## If more than this is pending, the original rewinds its `last` stamp instead of catching up.
const MAX_BACKLOG_MS := 1000.0
## `mUpdateMultiplier` (`this+0x70`): per-tick damping factor consumers may apply (P2.1).
const UPDATE_MULTIPLIER := 0.85

## Emitted after every logic tick, with the new tick index. Use for HUD/observers only - per-entity
## work belongs in `_sim_tick()`.
signal ticked(tick: int)

var tick_count := 0
## How many slices the last frame ran (0 when the frame was shorter than TICK_MS).
var last_ticks_per_frame := 0

var _backlog_ms := 0.0
var _phases: Array = []


func _ready() -> void:
	_ensure_phases()
	# Run before ordinary nodes so a tick is complete before anything else sees the frame.
	process_priority = -100


func _process(delta: float) -> void:
	advance(delta * 1000.0)


## Advance the simulation by `delta_ms` of real time. Returns the number of ticks run.
## Pure with respect to the scene tree (no engine timers), so it is directly testable -
## see `tests/headless_sim_check.gd`.
func advance(delta_ms: float) -> int:
	_ensure_phases()
	if delta_ms > 0.0:
		_backlog_ms = minf(_backlog_ms + delta_ms, MAX_BACKLOG_MS)
	var steps := 0
	while _backlog_ms >= TICK_MS and steps < MAX_TICKS_PER_FRAME:
		_backlog_ms -= TICK_MS
		_tick()
		steps += 1
	last_ticks_per_frame = steps
	return steps


## Register `node` for one phase of the tick. Re-registering the same node in another phase moves it.
func register_phase(phase: int, node: Node) -> void:
	_ensure_phases()
	if not node.has_method("_sim_tick"):
		push_error("Sim.register_phase: %s has no _sim_tick()" % node)
		return
	unregister(node)
	(_phases[phase] as Array).append(node)


func unregister(node: Node) -> void:
	_ensure_phases()
	for bucket in _phases:
		(bucket as Array).erase(node)


## Pending time not yet consumed by a tick (0..MAX_BACKLOG_MS). Exposed for tests and the debug
## overlay; simulation code never reads it.
func backlog_ms() -> float:
	return _backlog_ms


## Drop pending time without running it - for screen transitions and level teardown, where carrying
## a frame hitch into fresh state would pop the first frames of the new scene.
func flush_backlog() -> void:
	_backlog_ms = 0.0


## Drops all registrations (level teardown). Tick counters are preserved.
func clear_registrations() -> void:
	_ensure_phases()
	for bucket in _phases:
		(bucket as Array).clear()


## Ticks -> seconds. All simulation state is integer ticks; convert only for UI and tooltips
## (SPECS.md §1.2, P2.7 §7.2).
func ticks_to_seconds(ticks: int) -> float:
	return float(ticks) / TICKS_PER_SECOND


func _tick() -> void:
	tick_count += 1
	for phase in Phase.COUNT:
		var bucket: Array = _phases[phase]
		# Indexed loop: `_sim_tick()` may despawn entities (level teardown, sells, transforms).
		# The element is deliberately untyped - assigning a freed instance to a typed `Node`
		# variable is an error, and a freed registrant must simply be skipped.
		for i in bucket.size():
			var node = bucket[i]
			if is_instance_valid(node):
				node._sim_tick()
	ticked.emit(tick_count)


func _ensure_phases() -> void:
	if _phases.size() == Phase.COUNT:
		return
	_phases.resize(Phase.COUNT)
	for i in Phase.COUNT:
		if _phases[i] == null:
			_phases[i] = []
