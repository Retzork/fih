class_name Projectile
extends SimEntity
## Alien projectile (`Sexy::Missle`, and `Sexy::Larva` for kinds 1/2), one class with three kinds
## (P2.10 §5). Ctor `FUN_004EAE40`, missile update `FUN_004FFB30`, hit tests `FUN_004FFAE0` (missile)
## and `FUN_004D82A0` (kinds 0/1).
##
## Field map: `kind` +0x19C, `target` +0x1A4, `vx`/`vy` +0x168/+0x170, box +0x38/+0x3C,
## `speed_divisor` +0x188, `spawn_immunity` +0x17C (15), `expiry` +0x1A8 / `expiry_limit` +0x1AC
## (0/10), `flag_190` +0x190.
##
## Q-0041 (open): the homing body `FUN_004FF4E0` was never decompiled, and the ctor's random-velocity
## branch is dead code (it tests the projectile's own kind, EV-0130), so a retail projectile starts
## still and is moved entirely by that missing function. `_steer()` is therefore an explicit no-op:
## a spawned shot has zero velocity until the homing body is recovered. Everything else in the update
## (expiry, bounds, gravity, movement, immunity, smoke, hit tests) is implemented as written.

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

## Emitted when the shot removes itself (expiry, bounds or being shot down).
signal removed(projectile)
## Kind 0 leaves an 8-px smoke trail on `rand % 3 == 0`; P4.4/P4.13 draw it.
signal smoke_requested(at: Vector2)
## A 2-px burst at the click point (missile shot down, ball deflected).
signal burst_requested(at: Vector2)

var kind := Kind.MISSILE
var vx := 0.0
var vy := 0.0
var box := BOX_LARGE
var speed_divisor := SPEED_DIVISOR
var spawn_immunity := SPAWN_IMMUNITY
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

	_steer()
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


## `FUN_004FF4E0` is not in the decompile (Q-0041) - the shot keeps whatever velocity it has.
func _steer() -> void:
	pass


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
