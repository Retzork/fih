class_name Food
extends SimEntity
## Food pellet (type id 0x1C). Behaviour from `Food::Update` `FUN_004F8AA0` and the play ctor
## `FUN_004EF840` (P2.3 §1, EV-0045). Every constant below is the note's field/step number.
##
## Field map (`+offset` from the note): `quality` +0x188 (0..2 manual, 1 non-manual, 3 star potion),
## `kind` +0x18C (drift direction and "special" status), `variant` +0x194, `landed` +0x190,
## `gate` +0x184, `homing` +0x185, `lifetime` +0x60, `inedible` +0x198, `anim_frame` +0x5E,
## `anim_cycle` +0x5F.
##
## Q-0035 (closed, EV-0160/EV-0161): `Food::Update` step 4 only bobs when `landed` is already set, and
## nothing writes `+0x190` after construction - the flag is the ctor's `param_4`. Exactly one caller
## passes `flag = 1`: Angie's food re-lay (`FUN_004FE740`, 0x4FF2AA), which removes an ordinary pellet
## in her 30 px contact box and re-drops it landed at the same point, so that pellet bobs. The click
## and feed drops pass `flag = 0`, so dropped food falls, arms the 15-tick bottom life and sinks out.
## There is no landing transition to port; do not invent one.
##
## Deviation (D-0012): `SETTLE_TICKS` (one constant, shipped 20) is the single gate for a
## deliberately non-faithful rest - a dropped pellet pauses on its death line that many ticks, then
## resumes the faithful sink-out. Setting the constant to 0 restores the original behaviour exactly.
##
## The bottom branch *is* recovered (EV-0159): step 8's remaining call `FUN_004D62D0` is a void
## function whose whole body arms the lifetime counter (`+0x180`) to 15 when it is below 1, so an
## uneaten pellet sinks past the line and is removed 15 ticks later by step 3 - it is not held at the
## line and it is not bounced.

## Step 4: fall speed while airborne (`y += 1.5`).
const FALL_SPEED := 1.5
## Ctor: `vy = -2.0`, drift `vx = kind == 2 ? +2 : -2`; step 6 decays `vy`/`vx` by 0.05 per tick.
const INITIAL_VY := -2.0
const INITIAL_VX := 2.0
const DRIFT_DECAY := 0.05
## Step 7: horizontal clamp.
const X_MIN := 20.0
const X_MAX := 550.0
## Step 8: death lines, and the star potion's shallower one.
const DEATH_Y := 410.0
const STAR_DEATH_Y := 400.0
## Step 8's bottom branch `FUN_004D62D0`: `if (this+0x180 < 1) this+0x180 = 0xf` - the pellet keeps
## sinking and step 3 removes it when the 15 ticks run out (EV-0159).
const BOTTOM_LIFETIME := 15
## D-0012, the one knob: ticks a dropped pellet rests on the tank floor before sinking out.
## 0 = the faithful behaviour (no rest).
const SETTLE_TICKS := 20
## Step 4 homing (only when something sets `homing`): approach (550, 30) in sevenths, leave at x < 40.
const HOMING_TARGET := Vector2(550.0, 30.0)
const HOMING_DIVISOR := 7.0
const SUCK_OUT_X := 40.0
## Step 2: `[0x5E]` is the sheet frame itself - it advances one frame per tick and wraps at
## `[0x5F] * 10 - 1`, so the 10 is the sheet's column count, not a tick delay per frame. The pellet
## sheet is 10x5: cycle 3 uses rows 0-2 (30 frames), cycle 4 rows 0-3 (40), which is exactly the
## wrap range.
const ANIM_FRAMES_PER_CYCLE := 10
## Quality 3 = star potion (splashes on death); variant 2 = breeding pellet (removed silently).
const QUALITY_STAR := 3
const VARIANT_BREEDING := 2
## Step 5 bob bands, top to bottom: depth -> rise per tick.
const BOB_BANDS := [
	[150.0, 8.0],
	[135.0, 2.5],
	[130.0, 1.5],
	[125.0, 1.0],
	[120.0, 0.5],
]

var quality := 0
var kind := 0
var variant := 0
var landed := false
## Set once this pellet has taken its D-0012 rest, so it parks only a single time.
var settled := false
## Remaining ticks of that rest.
var settle_ticks := 0
var gate := false
var homing := false
## Ticks until the pellet removes itself; 0 = never (normal pellets do not expire, P2.3 §1.3).
var lifetime := 0
## While non-zero the pellet is inedible (variant 2 starts at 0x14).
var inedible := 0
var vx := 0.0
var vy := INITIAL_VY
var anim_frame := 0
var anim_cycle := 3


## Build a pellet. `quality` is the dropper's food quality (0..3); `landed`/`variant`/`kind` are the
## ctor's `flag`/`param_5`/`param_3`.
static func create(
	pos: Vector2,
	kind_: int = 0,
	landed_: bool = false,
	variant_: int = 0,
	quality_: int = 0,
	rng: RandomNumberGenerator = null
) -> Food:
	var pellet := Food.new()
	pellet.position = pos
	pellet.kind = kind_
	pellet.landed = landed_
	pellet.variant = variant_
	pellet.quality = quality_
	# Ctor: vx sign from kind, and the animation cycle is 3 or 4 (one bit of RNG).
	pellet.vx = INITIAL_VX if kind_ == 2 else -INITIAL_VX
	var cycle_bit := 0
	if rng != null:
		cycle_bit = rng.randi() & 1
	pellet.anim_cycle = 3 + cycle_bit
	if variant_ == VARIANT_BREEDING:
		pellet.inedible = 0x14
	return pellet


## Edible pellets are what fish may target (P2.3 §7 gates on the countdown).
func is_edible() -> bool:
	return inedible == 0


## "Special" pellets are exempt from the `food_quantity` cap (P2.3 §2).
func is_special() -> bool:
	return kind != 0 or variant != 0


func is_star_potion() -> bool:
	return quality == QUALITY_STAR


func death_line() -> float:
	return STAR_DEATH_Y if is_star_potion() else DEATH_Y


func _advance() -> void:
	# Step 2: animation and the inedible countdown.
	anim_frame = (anim_frame + 1) % maxi(anim_cycle * ANIM_FRAMES_PER_CYCLE, 1)
	if inedible > 0:
		inedible -= 1

	# Step 3: lifetime, when the pellet has one.
	if lifetime > 0:
		lifetime -= 1
		if lifetime == 0:
			despawn()
			return

	# Deviation D-0012: the pellet pauses on the floor - animation keeps running, position does not.
	if settle_ticks > 0:
		settle_ticks -= 1
		return

	# Step 4: fall, homing, or the landed bob.
	if not landed or gate:
		if homing:
			position.x += (HOMING_TARGET.x - position.x) / HOMING_DIVISOR
			position.y += (HOMING_TARGET.y - position.y) / HOMING_DIVISOR
			if position.x < SUCK_OUT_X:
				despawn()
				return
		else:
			position.y += FALL_SPEED
	else:
		_bob()

	# Step 6: drift decay (kind 0 never drifts).
	_drift()

	# Step 7: horizontal clamp.
	position.x = clampf(position.x, X_MIN, X_MAX)

	# Step 8: the death line.
	if position.y > death_line():
		_on_death_line()


## Step 5: rise in depth bands, and flip `gate` at the top so the next tick falls again.
func _bob() -> void:
	for band: Array in BOB_BANDS:
		if position.y >= float(band[0]):
			position.y -= float(band[1])
			return
	gate = true


## Step 6: `vy` decays toward 0 and drags `y`; `vx` decays toward 0 in the kind's direction.
func _drift() -> void:
	if kind == 0:
		return
	if vy < 0.0:
		vy += DRIFT_DECAY
		position.y += vy
	if kind == 2:
		if vx > 0.0:
			vx -= DRIFT_DECAY
			position.x += vx
	elif kind == 1:
		if vx < 0.0:
			vx += DRIFT_DECAY
			position.x += vx


## Step 8's three branches: star potions splash and vanish, breeding pellets vanish silently, and an
## ordinary pellet gets a 15-tick life (`FUN_004D62D0`, EV-0159) so it sinks out of the tank. `y` is
## deliberately not clamped: the callee is void, the assignment the first reading saw had no value
## source, and a pellet that stopped dead on the line would freeze in the tank forever.
func _on_death_line() -> void:
	if is_star_potion():
		despawn()
		return
	if variant == VARIANT_BREEDING:
		despawn()
		return
	if SETTLE_TICKS > 0 and not settled:
		# Deviation D-0012: one brief rest on the floor; the next crossing arms the sink-out life.
		settled = true
		settle_ticks = SETTLE_TICKS
		position.y = death_line()
		vy = 0.0
		return
	if lifetime < 1:
		lifetime = BOTTOM_LIFETIME
