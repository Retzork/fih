class_name Boss
extends Alien
## Cyrax (alien kind 0x15), the tank-5 boss (P2.9 §10, SPECS §3.6). It reuses `Alien` for the table,
## phases and death plumbing and replaces the update: arrival, intro, minion cadence, alien pulse, the
## 10-tick damage cooldown and the wave freeze.
##
## Field meanings: `max_hp` is `5000 - 125 * clamp(profile_counter - 1, 0, 20)`, the arrival delay is
## 300 ticks and the intro drift 15, minions come every 75 ticks at `+40,+40`, and the pulse every 300
## ticks but only while the field is clear. Waves are frozen until he dies and disabled afterwards.
##
## Q-0047 (open): the minion kind and the pulse content are not named by the note, so the level spawns
## a Sylvester for both; the boss HP bar is UI (P4.5). Damage per shot is `3 * pet_capacity` (30 at the
## boss's forced capacity 10), which the shooter computes - the boss only enforces the cooldown.

const KIND := 0x15
const MAX_HP := 5000
const HP_STEP := 125
const PROFILE_CLAMP := 20
const ARRIVAL_TICKS := 300
const INTRO_TICKS_BOSS := 15
const BOSS_INTRO_DRIFT := 3.0
const MINION_TICKS := 75
const PULSE_TICKS := 300
const MINION_OFFSET := Vector2(40.0, 40.0)
## At most one hit per 10 ticks per attacker.
const HIT_COOLDOWN := 10
const Y_MIN := 85.0
const Y_MAX := 290.0
const SPEED := 2.0
## The boss forces the pet capacity to 10, so a shot does 30 (P2.9 §10).
const FORCED_PET_CAPACITY := 10

signal minion_requested(at: Vector2)
signal pulse_requested(at: Vector2)

var max_hp := MAX_HP
var arrival_timer := ARRIVAL_TICKS
var minion_timer := MINION_TICKS
var pulse_timer := PULSE_TICKS
var profile_counter := 1

var _last_hit: Dictionary = {}


## `hp = 5000 - 125 * clamp(profile_counter - 1, 0, 20)`.
static func max_hp_for(counter: int) -> int:
	return MAX_HP - HP_STEP * clampi(counter - 1, 0, PROFILE_CLAMP)


static func create(counter: int, pos: Vector2) -> Boss:
	var boss := Boss.new()
	boss.kind = KIND
	boss.profile_counter = counter
	boss.max_hp = max_hp_for(counter)
	boss.hp = boss.max_hp
	boss.speed = SPEED
	boss.position = Vector2(pos.x, clampf(pos.y, Y_MIN, Y_MAX))
	boss.wander_target = boss.position
	return boss


func is_arriving() -> bool:
	return arrival_timer > 0


## While arriving the boss cannot be hit and does nothing; then a 15-tick intro, then the fight.
func _advance() -> void:
	if arrival_timer > 0:
		arrival_timer -= 1
		return
	if intro_timer > 0:
		intro_timer -= 1
		position.x += intro_dir * BOSS_INTRO_DRIFT / SPEED
		position.y = clampf(position.y, Y_MIN, Y_MAX)
		return

	_wander()
	_move()
	position.y = clampf(position.y, Y_MIN, Y_MAX)

	minion_timer -= 1
	if minion_timer <= 0:
		minion_timer = MINION_TICKS
		minion_requested.emit(position + MINION_OFFSET)

	pulse_timer -= 1
	if pulse_timer <= 0:
		pulse_timer = PULSE_TICKS
		if _field_clear():
			pulse_requested.emit(position)


## The pulse cadence only fires while no other alien is on the field. The boss is itself an ALIENS
## entity, so the count has to exclude `self`.
func _field_clear() -> bool:
	if tank == null:
		return false
	for entity in tank.entities_in(Sim.Phase.ALIENS):
		if entity != self:
			return false
	return true


## The shared damage pool with the 10-tick per-attacker cooldown; a null attacker bypasses it.
func hit(damage: int, from_shot: bool = true, attacker: Object = null) -> void:
	if dead or arrival_timer > 0:
		return
	if attacker != null:
		if _last_hit.has(attacker) and ticks_alive - int(_last_hit[attacker]) < HIT_COOLDOWN:
			return
		_last_hit[attacker] = ticks_alive
	super.hit(damage, from_shot)


## Death: the boss clears `boss_alive`, unfreezes the clock and then disables waves permanently.
func die(from_shot: bool = true) -> void:
	if dead:
		return
	super.die(from_shot)
	if tank != null:
		tank.boss_alive = false
		tank.wave_frozen = false
		tank.waves_disabled = true
