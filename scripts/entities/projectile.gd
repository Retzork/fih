class_name Projectile
extends SimEntity
## Alien projectile (`Sexy::Missle`, and `Sexy::Larva` for kinds 1/2), one class with three kinds
## (P2.10 §5). Ctor `FUN_004EAE40`, missile update `FUN_004FFB30`, homing `FUN_004FF4E0` and the
## on-target check `FUN_004FC070` (EV-0158). Click hit tests are `FUN_004FFAE0` (missile) and
## `FUN_004D82A0` (kinds 0/1).
##
## Field map: `kind` +0x19C, `target` +0x1A4, `phase` +0x1A0, `vx`/`vy` +0x168/+0x170, box +0x38/+0x3C,
## `speed_divisor` +0x188, `spawn_immunity` +0x17C (15), `expiry` +0x1A8 / `expiry_limit` +0x1AC
## (0/10), `flag_190` +0x190.
##
## The ctor's random-velocity branch is dead code (it tests the projectile's own kind, EV-0130),
## so a retail projectile starts still and is moved entirely by the homing body
## (`FUN_004FF4E0`, recovered in EV-0158): `+-0.2` steering steps toward the victim toward caps
## of `1.8`, with nearer caps `1.4`/`0.6` and a `0.1`-step vertical deadband around `+-0.2`.
## Ultravore victims (`+0x8C == 6`) get the wider `+200`/`+110` bands; everyone else the tighter
## `+80`/`+60` bands. The same body expires kinds 0/1 whose victim pointer is gone, and the
## on-target check kills the fish (or, when deflected, damages aliens/boss) in the same tick.


## `+0x19C`: 0 missile, 1 energy ball, 2 third variant.
enum Kind { MISSILE, BALL, FALLING }

## The three recovered projectile sheets (P2.10 §5). The dimensions match the kind's box: the
## missile and energy ball are 80x80, the falling shot is the 50x50 `BALLS` sheet.
const IMAGE_BY_KIND := {
	Kind.MISSILE: "IMAGE_MISSILE",
	Kind.BALL: "IMAGE_ENERGYBALL",
	Kind.FALLING: "IMAGE_BALLS",
}

## Ctor: 80x80 box and speed divisor 0.8, or 50x50 and 0.4 for kind 2.
const BOX_LARGE := 80.0
const BOX_SMALL := 50.0
const SPEED_DIVISOR := 0.8
const SPEED_DIVISOR_SMALL := 0.4
## `+0x17C` starts at 15 and counts down; clicking is ignored while it is >= 1.
const SPAWN_IMMUNITY := 15
## `+0x1A8`/`+0x1AC`: once `begin_expiry()` arms it, the shot is gone 10 ticks later.
const EXPIRY_LIMIT := 10
## Kind 2 only: `vy += 0.2` per tick while `flag_190` is set.
const GRAVITY := 0.2
## Kind 0 is clamped into the tank; kinds 1/2 die outside the wider rect (kind 1 only once deflected).
const CLAMP_LEFT := 10.0
const CLAMP_RIGHT := 550.0
const CLAMP_TOP := 95.0
const CLAMP_BOTTOM := 370.0
const DIE_LEFT := -20.0
const DIE_RIGHT := 580.0
const DIE_TOP := 45.0
const DIE_BOTTOM := 380.0
## Kind 0 click box: 60x60 centred on the object.
const MISSILE_HIT_BOX := 60.0
## Kind 1 click box: (x+10 .. x+70) in both axes.
const BALL_HIT_OFFSET := Vector2(10.0, 10.0)
const BALL_HIT_BOX := 60.0
## Kind 1 deflection: `((click - pos) - 40) / -5`, clamped to [-1, 1].
const DEFLECT_CENTER := 40.0
const DEFLECT_DIVISOR := -5.0
const DEFLECT_LIMIT := 1.0
## Homing (`FUN_004FF4E0`, EV-0158): `+-0.2` per tick toward caps of `1.8`, nearer caps
## `1.4`/`0.6`, and the fine vertical deadband `+-0.2` stepped by `0.1`.
const HOMING_STEP := 0.2
const HOMING_FINE_STEP := 0.1
const HOMING_CAP := 1.8
const HOMING_NEAR_CAP := 1.4
const HOMING_CENTER_CAP := 0.6
const HOMING_HALT := 0.6
const HOMING_FINE_LIMIT := 0.2
## Steering sample offset: the box centre (40 for the 80x80 kinds, 25 for the 50x50 kind).
const OFFSET_LARGE := 40.0
const OFFSET_SMALL := 25.0
## Homing target type that selects the wide bands (`+0x8C == 6`, the Ultravore type id).
const TYPE_ULTRAVORE := 6
## Wide (Ultravore) reach: `+200` far edge, `+110` mid edge, `+50`/`+80` inner split.
const WIDE_FAR := 200.0
const WIDE_MID := 110.0
const WIDE_INNER := 50.0
const WIDE_CENTER := 80.0
## Tight (everyone else) reach: `+80` far edge, `+60` mid edge, `+20`/`+40` inner split.
const TIGHT_FAR := 80.0
const TIGHT_MID := 60.0
const TIGHT_INNER := 20.0
const TIGHT_CENTER := 40.0
## On-target boxes (`FUN_004FC070`, EV-0158). Locked-victim: the `+40` sample point inside
## `(+10 .. +70)` x `(+10 .. +70)` (Ultravore `+8/+140` x `+4/+140`). Deflected ball vs aliens:
## `(+30 .. +140)` x `(+10 .. +150)`, 30 damage. Deflected ball vs fish: `(+10 .. box-10)` so
## Ultravore reads `150`.
const ALIEN_HIT_DAMAGE := 30
const KIND2_BOUNCE_DIVISOR := 1.5
const SPECIAL_DIVISOR := 0.6

## Emitted when the shot removes itself (expiry, bounds or being shot down).
signal removed(projectile)
## Kind 0 leaves an 8-px smoke trail on `rand % 3 == 0`; P4.4/P4.13 draw it.
signal smoke_requested(at: Vector2)
## A 2-px burst at the click point (missile shot down, ball deflected).
signal burst_requested(at: Vector2)
## The on-target check consumed the victim (`FUN_004FC070`). Undistracted shots remove
## themselves after this fires; a deflected ball survives fish hits (EV-0158).
signal hit_target(victim)

var kind := Kind.MISSILE
var vx := 0.0
var vy := 0.0
var box := BOX_LARGE
var speed_divisor := SPEED_DIVISOR
var spawn_immunity := SPAWN_IMMUNITY
## Universal timer (`+0x1A0`): 0..3 phase (`rand() & 3` at the ctor). The kind-2 bounce divisor reads it, so the
## port keeps it rather than constant-folding the decompile's `< 4` test (EV-0158). Named
## distinctly from `SimEntity.phase` (the tank phase) to avoid shadowing it.
var timer_1a0 := 0
## `+0x1A8`: 0 = not expiring; `begin_expiry()` arms it and it counts up to `expiry_limit`.
var expiry := 0
var expiry_limit := EXPIRY_LIMIT
## `+0x190`: set when a ball is deflected, and it gates kind 2's gravity and kind 1's bounds death.
var flag_190 := false
## `+0x1A4`: the homing victim. Also receives the victim's `+0x98` back-pointer (P2.10 §5.1).
var target: Node2D = null


static func create(kind_: int, pos: Vector2, target_: Node2D = null) -> Projectile:
	var shot := Projectile.new()
	shot.kind = kind_
	shot.position = pos
	shot.target = target_
	if kind_ == Kind.FALLING:
		shot.box = BOX_SMALL
		shot.speed_divisor = SPEED_DIVISOR_SMALL
	return shot


## Arm the 10-tick expiry (the "hit, now expire" counter of §5.3).
func begin_expiry() -> void:
	if expiry == 0:
		expiry = 1


static func image_id_for(kind_: int) -> String:
	return String(IMAGE_BY_KIND.get(kind_, "IMAGE_MISSILE"))


func image_id() -> String:
	return image_id_for(kind)


func is_deflected() -> bool:
	return flag_190


## Kind 2 is never clickable (`Larva::HitTest` has no case for it).
func is_clickable() -> bool:
	return kind != Kind.FALLING


func _advance() -> void:
	if expiry > 0:
		expiry += 1
		if expiry >= expiry_limit:
			_expire()
			return

	if _steer():
		return
	if not _check_bounds():
		return

	if kind == Kind.FALLING and flag_190:
		vy += GRAVITY

	position.x += vx / speed_divisor
	position.y += vy / speed_divisor

	if spawn_immunity > 0:
		spawn_immunity -= 1

	if kind == Kind.MISSILE and _roll(3) == 0:
		smoke_requested.emit(position)


## The homing body (`FUN_004FF4E0`) plus the on-target check (`FUN_004FC070`, EV-0158). Returns
## true when the update must stop (`Missle::Update` returns early): the shot expired or the
## on-target check consumed it. Order is the binary's: target-loss expiry, deflected shots skip
## steering, then `x` and `y` steering, then the hit check.
func _steer() -> bool:
	# Target-loss expiry: kinds 0/1 disappear when the victim is gone (`+0x1A4` null or the
	# victim's `+0x98` cleared). The `FUN_004D80C0` guard in the binary tests the shot's own
	# kind in {3,4,5} and is unreachable for kinds 0/1, so the port expires directly. Kind 2
	# never expires here; it flies on to its bounds/gravity rules.
	var has_target := _has_live_target()
	if not has_target and kind != Kind.FALLING:
		_expire()
		return true

	# A deflected ball (`+0x190`) does not steer; it goes straight to the on-target check.
	if flag_190:
		return _on_target()

	if kind == Kind.FALLING and not has_target:
		# No victim to steer at and no expiry rule: the falling shot keeps its velocity.
		return false

	if kind == Kind.FALLING and not _projectiles_exist() and not _food_exists():
		return _on_target()

	var offset := OFFSET_LARGE
	if kind == Kind.FALLING:
		offset = OFFSET_LARGE if _projectiles_exist() else OFFSET_SMALL

	var victim := target as Node2D
	if victim == null:
		return false
	var victim_type := _target_type(victim)
	var tx := float(int(victim.position.x))
	var ty := float(int(victim.position.y))
	if victim_type == TYPE_ULTRAVORE or (kind == Kind.FALLING and not _projectiles_exist()):
		_steer_wide(tx, ty, offset)
	else:
		_steer_tight(tx, ty, OFFSET_LARGE)
	return _on_target()


## The victim is live while it is a valid node, not despawned, and still locked onto this shot
## (`*(target + 0x98) == this`). A `FakeTarget` in the headless checks carries the same slot.
func _has_live_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var victim := target as SimEntity
	if victim != null and victim.dead:
		return false
	if target.has_method("lock_projectile"):
		# Duck-typed slot check: the lock must name this shot.
		var locked = target.get("locked_projectile")
		if locked == null:
			return false
		if locked != self:
			return false
	return true


func _projectiles_exist() -> bool:
	return tank != null and tank.has_method("projectile_count") and int(tank.projectile_count()) > 0


func _food_exists() -> bool:
	return tank != null and tank.has_method("food_count") and int(tank.food_count()) > 0


func _is_demo() -> bool:
	# `manager+0x880` (P2.8). The deflected-ball scan is skipped while it is set (EV-0158).
	return tank != null and bool(tank.get("demo_mode"))


## `*(target + 0x8C)`. Fish expose it via `obj_type()`; anything else reads as type 0 (Guppy),
## which the binary would treat as the gated type-0 case, not the Ultravore wide bands.
func _target_type(victim: Node2D) -> int:
	if victim.has_method("obj_type"):
		return int(victim.obj_type())
	return 0


## Wide bands (`LAB_004ff813`, EV-0158): the Ultravore victim. `offset` is 40 for kinds 0/1 and
## 25/40 for kind 2; the far edge is `+200`, the mid edge `+110`.
func _steer_wide(tx: float, ty: float, offset: float) -> void:
	var px := position.x + offset
	if px <= tx + WIDE_FAR:
		if px >= tx - 40.0:
			if px <= tx + WIDE_MID:
				if px < tx + WIDE_INNER:
					_approach_x(HOMING_NEAR_CAP)
				elif px < tx + WIDE_CENTER:
					_approach_x(HOMING_CENTER_CAP)
				elif vx > -HOMING_HALT:
					vx -= HOMING_STEP
			elif vx > -HOMING_NEAR_CAP:
				vx -= HOMING_STEP
		else:
			_approach_x(HOMING_CAP)
	elif vx > -HOMING_CAP:
		vx -= HOMING_STEP

	var py := position.y + offset
	if py > ty + WIDE_FAR:
		if vy > -HOMING_CAP:
			vy -= HOMING_STEP
		return
	if py < ty - 40.0:
		if vy < HOMING_CAP:
			vy += HOMING_STEP
		return
	if py > ty + WIDE_MID:
		if vy > -HOMING_NEAR_CAP:
			vy -= HOMING_STEP
		return
	_approach_y(HOMING_NEAR_CAP, py, ty)


## Tight bands (everyone else, `LAB` after the wide block, EV-0158): the sample is always
## `+40`, the far edge `+80`, the mid edge `+60`.
func _steer_tight(tx: float, ty: float, offset: float) -> void:
	var px := position.x + offset
	if px <= tx + TIGHT_FAR:
		if px >= tx:
			if px <= tx + TIGHT_MID:
				if px < tx + TIGHT_INNER:
					_approach_x(HOMING_NEAR_CAP)
				elif px < tx + TIGHT_CENTER:
					_approach_x(HOMING_CENTER_CAP)
				elif vx > -HOMING_HALT:
					vx -= HOMING_STEP
			elif vx > -HOMING_NEAR_CAP:
				vx -= HOMING_STEP
		else:
			_approach_x(HOMING_CAP)
	elif vx > -HOMING_CAP:
		vx -= HOMING_STEP

	var py := position.y + offset
	_approach_y_tight(py, ty)


## `vx` toward `desired` from below by one step (`uVar10 == 0` in the decompile). No clamp: a
## step may overshoot by one increment, as the fish approach does.
func _approach_x(desired: float) -> void:
	if vx < desired:
		vx += HOMING_STEP


## Wide-band `vy` toward the caps, with the inner `+-0.2` deadband stepped by `0.1`.
func _approach_y(desired: float, py: float, ty: float) -> void:
	if py < ty + WIDE_INNER:
		if vy < desired:
			vy += HOMING_STEP
		return
	if py <= ty + WIDE_CENTER:
		if py < ty + WIDE_CENTER and vy < HOMING_FINE_LIMIT:
			vy += HOMING_FINE_STEP
		return
	if vy > -HOMING_FINE_LIMIT:
		vy -= HOMING_FINE_STEP


## Tight-band `vy`: inner split at `+20`/`+40`, mid edge `+60`, far edge `+80`.
func _approach_y_tight(py: float, ty: float) -> void:
	if py <= ty + TIGHT_FAR:
		if py >= ty:
			if py <= ty + TIGHT_MID:
				if py < ty + TIGHT_INNER:
					if vy < HOMING_NEAR_CAP:
						vy += HOMING_STEP
				elif py < ty + TIGHT_CENTER:
					if vy < HOMING_FINE_LIMIT:
						vy += HOMING_FINE_STEP
				elif vy > -HOMING_FINE_LIMIT:
					vy -= HOMING_FINE_STEP
			elif vy > -HOMING_NEAR_CAP:
				vy -= HOMING_STEP
		elif vy < HOMING_CAP:
			vy += HOMING_STEP
	elif vy > -HOMING_CAP:
		vy -= HOMING_STEP


## The on-target check (`FUN_004FC070`, EV-0158). Returns true when the shot is consumed.
func _on_target() -> bool:
	if kind == Kind.BALL and flag_190 and not _is_demo():
		return _deflected_hit()
	if kind == Kind.FALLING:
		return _kind2_bounce()
	return _locked_hit()


## Undistracted shot vs its locked victim: the `+40` sample inside the victim's box kills the
## fish through its slot-77 consume (the port's `die()`) and consumes the shot.
func _locked_hit() -> bool:
	if not _has_live_target():
		return false
	var victim := target as Node2D
	var tx := float(int(victim.position.x))
	var ty := float(int(victim.position.y))
	var px := position.x + OFFSET_LARGE
	var py := position.y + OFFSET_LARGE
	var inside: bool
	if _target_type(victim) == TYPE_ULTRAVORE:
		inside = px > tx + 8.0 and px < tx + 140.0 and py > ty + 4.0 and py < ty + 140.0
	else:
		inside = px > tx + 10.0 and px < tx + 70.0 and py > ty + 10.0 and py < ty + 70.0
	if not inside:
		return false
	hit_target.emit(victim)
	if victim is Fish:
		(victim as Fish).die()
	elif victim.has_method("die"):
		victim.die()
	# `FUN_004D80E0`: the shot is consumed with its victim (the FakeTarget stand-in has no
	# death path, so the port expires it here rather than waiting for target loss).
	_expire()
	return true


## Kind 2 vs its victim (`FUN_004FC070`, EV-0158): a bounce, not a kill. The shot is deflected
## (`+0x190`), the victim's lock is cleared, the divisor becomes `1.5` and the velocity flips.
## The type-0x16/0x17 damage sub-branches name classes the port does not spawn here, so the
## port keeps the bounce only. The shot survives.
func _kind2_bounce() -> bool:
	if flag_190 or not _has_live_target():
		return false
	var victim := target as Node2D
	var tx := float(int(victim.position.x))
	var ty := float(int(victim.position.y))
	var px := position.x + OFFSET_SMALL
	var py := position.y + OFFSET_SMALL
	if px <= tx + 10.0 or px >= tx + 70.0 or py <= ty + 10.0 or py >= ty + 70.0:
		return false
	flag_190 = true
	if victim.has_method("unlock_projectile"):
		victim.unlock_projectile(self)
	target = null
	speed_divisor = KIND2_BOUNCE_DIVISOR if timer_1a0 < 4 else SPECIAL_DIVISOR
	vx = -vx
	vy = -vy
	return false


## A deflected ball (`FUN_004FC070`, EV-0158): 30 damage vs aliens/boss consumes the shot; fish
## hits kill the fish but the ball flies on.
func _deflected_hit() -> bool:
	if tank == null:
		return false
	for entity: SimEntity in tank.entities_in(Sim.Phase.ALIENS):
		if entity == null or entity.dead:
			continue
		if entity.has_method("resting") and bool(entity.get("resting")):
			continue
		var ax := float(int(entity.position.x))
		var ay := float(int(entity.position.y))
		var px := position.x + OFFSET_LARGE
		var py := position.y + OFFSET_LARGE
		var inside := px > ax + 30.0 and px < ax + 140.0 and py > ay + 10.0 and py < ay + 150.0
		if inside:
			hit_target.emit(entity)
			if entity is Boss:
				(entity as Boss).hit(ALIEN_HIT_DAMAGE, true, self)
			elif entity.has_method("hit"):
				entity.hit(ALIEN_HIT_DAMAGE, true)
			_expire()
			return true
	for entity: SimEntity in tank.entities_in(Sim.Phase.FISH):
		if entity == null or entity.dead:
			continue
		var fx := float(int(entity.position.x))
		var fy := float(int(entity.position.y))
		var px := position.x + OFFSET_LARGE
		var py := position.y + OFFSET_LARGE
		var high := 10.0
		if entity is Fish:
			high = float((entity as Fish).sprite_box) - 10.0
		else:
			high = 70.0
		var inside := px > fx + 10.0 and px < fx + high and py > fy + 10.0 and py < fy + high
		if inside:
			hit_target.emit(entity)
			if entity is Fish:
				(entity as Fish).die()
			elif entity.has_method("die"):
				entity.die()
			# The binary keeps scanning other fish lists and returns 0: deflect and fly on.
	return false


## Kind 0 clamps into the tank; kinds 1/2 remove themselves outside the wider rect.
func _check_bounds() -> bool:
	if kind == Kind.MISSILE:
		position.x = clampf(position.x, CLAMP_LEFT, CLAMP_RIGHT)
		position.y = clampf(position.y, CLAMP_TOP, CLAMP_BOTTOM)
		return true
	if kind == Kind.BALL and not flag_190:
		return true
	if not _inside_die_rect():
		_expire()
		return false
	return true


func _inside_die_rect() -> bool:
	return (
		position.x >= DIE_LEFT and position.x <= DIE_RIGHT
		and position.y >= DIE_TOP and position.y <= DIE_BOTTOM
	)


## Click routing (P2.10 §5.4). Returns true when the click was consumed.
func hit_test(click: Vector2) -> bool:
	if spawn_immunity >= 1 or dead:
		return false
	match kind:
		Kind.MISSILE:
			var missile_box := Rect2(
				position - Vector2(MISSILE_HIT_BOX * 0.5, MISSILE_HIT_BOX * 0.5),
				Vector2(MISSILE_HIT_BOX, MISSILE_HIT_BOX)
			)
			if missile_box.has_point(click):
				burst_requested.emit(click - Vector2(DEFLECT_CENTER, DEFLECT_CENTER))
				_expire()
				return true
		Kind.BALL:
			var ball_box := Rect2(position + BALL_HIT_OFFSET, Vector2(BALL_HIT_BOX, BALL_HIT_BOX))
			if ball_box.has_point(click):
				# `((click - pos) - 40) / -5`, clamped: a ball is knocked away from the click.
				vx = clampf(((click.x - position.x) - DEFLECT_CENTER) / DEFLECT_DIVISOR,
					-DEFLECT_LIMIT, DEFLECT_LIMIT)
				vy = clampf(((click.y - position.y) - DEFLECT_CENTER) / DEFLECT_DIVISOR,
					-DEFLECT_LIMIT, DEFLECT_LIMIT)
				flag_190 = true
				burst_requested.emit(click - Vector2(DEFLECT_CENTER, DEFLECT_CENTER))
				return true
	return false


## The victim's `+0x98` back-pointer (P2.10 §5.1). Only the tank's spawner sets the target; this
## keeps the lock and clears it when either side goes away.
func lock_target(victim: Node2D) -> void:
	target = victim


func release_target() -> void:
	if target != null and is_instance_valid(target) and target.has_method("unlock_projectile"):
		target.unlock_projectile(self)


func _expire() -> void:
	if dead:
		return
	removed.emit(self)
	despawn()


func _exit_tree() -> void:
	release_target()
	super()


func _roll(limit: int) -> int:
	if tank != null and tank.has_method("randi_below"):
		return tank.randi_below(limit)
	return 0
