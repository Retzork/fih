class_name WaveClock
extends SimEntity
## The alien wave clock (P2.8 §3, SPECS §3.5). A 3000-tick counter that only advances while a wave is
## armed (`Tank`'s stored alien selection is non-zero), no boss is alive, and the alien and projectile
## lists are empty - otherwise it freezes, which is what makes an invasion "one wave at a time".
##
## The milestones fire in the fixed order message -> warp hole + coordinate roll -> sound -> warning ->
## event -> spawn, and the spawn point is rolled **once** and reused for the second member of a
## composite selection (kinds 9..0xC are recipes, not entities).
##
## The clock asks; it never spawns. `alien_spawn_requested` is the level's cue, exactly like the fish's
## successor signal, so wave composition stays with the level and the boss's frozen-wave rule stays here.

const WAVE_TICKS := 3000
## `x = rand%450 + 20`, `y = rand%195 + 105`.
const SPAWN_X_BASE := 20
const SPAWN_X_SPAN := 450
const SPAWN_Y_BASE := 105
const SPAWN_Y_SPAN := 195
## Composite selections spawn two entities at the one rolled point.
const COMPOSITE := [0x09, 0x0A, 0x0B, 0x0C]
const MILESTONES := ["message", "warp", "sound", "warning", "event"]

signal milestone(name: String)
signal alien_spawn_requested(selection: int, at: Vector2)
## Emitted once after all members of a wave have been requested; the level re-rolls its stored type.
signal wave_spawned(selection: int)

var timer := 0
## The tank's stored spawn selection (not the instance's kind).
var selection := 0


## Whether the wave clock may advance this tick.
func gate_open() -> bool:
	if selection == 0 or tank == null:
		return false
	if bool(tank.boss_alive) or bool(tank.wave_frozen) or bool(tank.waves_disabled):
		return false
	if tank.alien_count() > 0:
		return false
	return tank.projectile_count() == 0


func composite() -> bool:
	return selection in COMPOSITE


func _advance() -> void:
	if not gate_open():
		return
	timer += 1
	if timer < WAVE_TICKS:
		return
	timer = 0
	_start_wave()


func _start_wave() -> void:
	var at := roll_spawn_point()
	for step: String in MILESTONES:
		milestone.emit(step)
	var members := 2 if composite() else 1
	for i in members:
		alien_spawn_requested.emit(selection, at)
	wave_spawned.emit(selection)


## One roll, reused by both members of a composite wave.
func roll_spawn_point() -> Vector2:
	return Vector2(
		SPAWN_X_BASE + tank.randi_below(SPAWN_X_SPAN),
		SPAWN_Y_BASE + tank.randi_below(SPAWN_Y_SPAN)
	)
