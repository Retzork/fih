class_name DeadFish
extends SimEntity
## `DeadFish` (type id 0x1B) - the corpse a fish leaves behind (P2.4 §4, `FUN_004F64E0`).
##
## The corpse is a separate, **inert** object (`FUN_00542EE0(obj, 0)`), not a state of `Fish`, and it
## does not replace the fish. Its natural lifecycle (EV-0053) is: it sinks while its own stage counter
## `+0x1A0` falls one step a tick, and when that counter drops below 1 it detaches **silently**. A
## starved fish is therefore gone - the player buys a new one.
##
## The live successor the ctor spawn table describes belongs to the other branch: when the phase
## counter `+0x190` drops below 1 the corpse plays its death sound, detaches and spawns a live creature
## by id. That counter is written by **Angie's** contact handoff (`FUN_004D5630`: 100 -> 10, P2.7
## §4.19, EV-0099), so the branch is reachable in play as soon as an Angie pet is in the tank; the
## 1..10 countdown it starts is played out here (Q-0043).
##
## Field map (the note's offsets): stage `+0x1A0`, corpse id `+0x1A4`, phase `+0x190`, frame `+0x18C`,
## vx `+0x170`, vy `+0x178`, float-up byte `+0x188`, jitter `+0x198`, speed `+0x180`, facing `+0x158`.

## Ctor initial values (EV-0052): stage 125, phase 100, jitter 1.0, box 80x80 (160x160 for id 6).
const STAGE_START := 0x7D
const PHASE_START := 100
## The phase Angie's contact write leaves (`+0x190` = 10); below 1 the revive spawns (EV-0053/EV-0099).
const REVIVE_PHASE := 10
const JITTER_START := 1.0
## Below this y at spawn (or below this vy) the sink velocity is reduced by the 1.0 drift, else 2.0.
const NEAR_FLOOR_Y := 115.0
const ARRIVAL_VY := -3.0
const DRIFT_NEAR := 1.0
const DRIFT_FAR := 2.0

## Physics (P2.4 §4): vx decays 0.03/tick, vy ramps 0.05/tick toward the sink target, jitter decays.
const VX_DECAY := 0.03
const VY_RAMP := 0.05
const SINK_TARGET := 2.0
const RISE_TARGET := -1.5
const JITTER_DECAY := 0.02
const SPEED_DIVISOR := 0.8
## Clamps: x 10..540, y 85..(370 for ids 8/9, 310 for id 6, else 380).
const X_MIN := 10.0
const X_MAX := 540.0
const Y_MIN := 85.0
const Y_MAX := 380.0
const Y_MAX_NARROW := 310.0
const Y_MAX_TALL := 370.0

## The stage counter crossed below 1: the corpse is done and leaves nothing behind.
signal removed(corpse)
## The revive branch (`phase_counter < 1`) asked for a live creature. Unreached by the natural path (Q-0043).
signal successor_requested(species: int, stage: int, at: Vector2, facing: int)

var species := 0
## `+0x1A4`: the dying fish's stage, which is also the corpse id the spawn table keys on.
var corpse_id := 0
## `+0x1A0`: the corpse's own countdown, **not** the fish's stage. Falls to 0 and removes it.
var stage := STAGE_START
var phase_counter := PHASE_START  # `+0x190`
var frame := 0
var facing := 1
var vx := 0.0
var vy := 0.0
var speed := SPEED_DIVISOR
## `+0x188`: nonzero floats the corpse up instead of letting it sink.
var float_up := false
var jitter := JITTER_START
## Angie's handoff started the revive countdown, so the drawn cell comes from `frame`, not the stage.
var reviving := false


static func create(
	species_: int,
	corpse_id_: int,
	pos: Vector2,
	facing_: int = 1,
	vx_: float = 0.0,
	vy_: float = 0.0,
	speed_: float = SPEED_DIVISOR
) -> DeadFish:
	var corpse := DeadFish.new()
	corpse.species = species_
	corpse.corpse_id = corpse_id_
	corpse.position = pos
	corpse.facing = facing_
	corpse.vx = vx_
	# The spawner subtracts the drift from the parent's vy (EV-0052): 1.0 near the floor or already
	# rising fast, 2.0 otherwise, so a fresh corpse always starts falling.
	corpse.vy = vy_ - (DRIFT_NEAR if pos.y < NEAR_FLOOR_Y or vy_ < ARRIVAL_VY else DRIFT_FAR)
	corpse.speed = maxf(speed_, 0.01)
	corpse.frame = corpse.sprite_frame()
	return corpse


func _advance() -> void:
	if phase_counter < 1:
		_revive()
		return
	if phase_counter <= REVIVE_PHASE:
		# Angie's handoff set the phase to 10: the counter ticks down while the corpse plays its
		# revive cells, and at 0 the branch above hands the tank a live fish (EV-0053).
		reviving = true
		phase_counter -= 1
		frame = clampi(phase_counter, 0, REVIVE_PHASE - 1)
		_sink()
		return
	# `+0x1A0` falls one step a tick once the corpse is past the stage threshold or has sunk far
	# enough: y > 300/365 for ids 6 and 8/9, y > 370 otherwise (EV-0053).
	if stage > 0x69 or position.y > _stage_drop_y():
		stage -= 1
	if stage < 1:
		_remove()
		return
	_sink()
	frame = sprite_frame()


## The y past which the stage counter starts falling, by corpse id (EV-0053).
func _stage_drop_y() -> float:
	if corpse_id == 6:
		return 300.0
	if corpse_id == 8 or corpse_id == 9:
		return 365.0
	return 370.0


## The corpse's descent: horizontal velocity decays, vertical ramps toward the sink target (or floats
## up when `float_up` is set and wraps back once it reaches the rise target), then both are applied
## through the speed divisor. Jitter decays while the corpse is still a small creature's (stage < 0x69).
func _sink() -> void:
	if vx > 0.0:
		vx = maxf(vx - VX_DECAY, 0.0)
	elif vx < 0.0:
		vx = minf(vx + VX_DECAY, 0.0)

	if float_up:
		vy = maxf(vy - VY_RAMP, RISE_TARGET)
		if vy <= RISE_TARGET:
			float_up = false
	else:
		vy = minf(vy + VY_RAMP, SINK_TARGET)

	if stage < 0x69 and jitter > 0.0:
		jitter = maxf(jitter - JITTER_DECAY, 0.0)

	position.x = clampf(position.x + vx / speed, X_MIN, X_MAX)
	position.y = clampf(position.y + vy / speed, Y_MIN, _y_max())


func _y_max() -> float:
	if corpse_id == 6:
		return Y_MAX_NARROW
	if corpse_id == 8 or corpse_id == 9:
		return Y_MAX_TALL
	return Y_MAX


## The frame rule of P2.4 §4, kept as data: id 8/9 pin their own death frames, every other id picks
## 6/7/8/9 from the **stage counter** (a pet corpse, stage > 0x69, walks the sheet backwards in twos).
func sprite_frame() -> int:
	if reviving:
		return clampi(frame, 0, 9)
	if corpse_id == 8 or corpse_id == 9:
		if stage > 0x69:
			return 9 - int((stage - 0x6A) / 2)
		return 9
	if stage == 0x65 or stage == 0x66:
		return 7
	if stage == 0x67 or stage == 0x68:
		return 8
	if stage > 0x69:
		return 9 - int((stage - 0x6A) / 2)
	return 6 if stage <= 100 else 9


## Natural end (stage < 1): detach silently, spawn nothing.
func _remove() -> void:
	removed.emit(self)
	despawn()


## The revive branch (`phase_counter < 1`): the original plays sound `0x125`, detaches, then spawns a live
## creature through the id table on `+0x1A4`. Its writer is unrecovered, so nothing here sets
## `phase < 1` on its own (Q-0043); the port keeps the branch so the missing trigger is one wire away.
func _revive() -> void:
	if corpse_id >= 1:
		successor_requested.emit(species, corpse_id, position, facing)
	removed.emit(self)
	despawn()
