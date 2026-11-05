extends SceneTree
## Headless check for the Projectile entity (P4.3/P4.10).
##
##   & "<godot>" --headless --path . --script res://tests/headless_projectile_check.gd
##
## Covers the ctor constants per kind (P2.10 §5.2), spawn immunity, the 10-tick expiry, the per-kind
## bounds rule, kind 2's gravity, movement through the speed divisor, both click hit-tests, the smoke
## trail roll and the victim lock. Homing is NOT covered: its body is missing (Q-0041), so a shot starts
## still and `_steer()` does nothing.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const ProjectileScript := preload("res://scripts/entities/projectile.gd")

const MISSILE := ProjectileScript.Kind.MISSILE
const BALL := ProjectileScript.Kind.BALL
const FALLING := ProjectileScript.Kind.FALLING

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


## Victim stand-in for the `+0x98` back-pointer, duck-typed like the alien will be.
class FakeTarget:
	extends Node2D
	var locked: Node = null

	func lock_projectile(shot) -> void:
		locked = shot

	func unlock_projectile(shot) -> void:
		if locked == shot:
			locked = null


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 31337)

	_test_ctor_constants()
	_test_spawn_and_phase()
	_test_immunity()
	_test_expiry()
	_test_bounds()
	_test_gravity()
	_test_movement()
	_test_hit_tests()
	_test_smoke()
	_test_victim_lock()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_projectile_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_projectile_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


# --- scenarios ---------------------------------------------------------------

func _test_ctor_constants() -> void:
	var missile: Projectile = ProjectileScript.create(MISSILE, Vector2(300.0, 200.0))
	_expect(missile.box == ProjectileScript.BOX_LARGE, "a missile is 80x80")
	_expect(missile.speed_divisor == ProjectileScript.SPEED_DIVISOR, "a missile divides speed by 0.8")
	_expect(missile.spawn_immunity == 15, "spawn immunity starts at 15")
	_expect(missile.expiry == 0 and missile.expiry_limit == 10, "expiry starts 0/10")
	_expect(missile.vx == 0.0 and missile.vy == 0.0, "a spawned shot starts still (the random branch is dead code)")
	_expect(not missile.flag_190, "the flag starts clear")
	_expect(missile.target == null, "a shot without a target has none")
	missile.free()

	var falling: Projectile = ProjectileScript.create(FALLING, Vector2(300.0, 200.0))
	_expect(falling.box == ProjectileScript.BOX_SMALL, "kind 2 is 50x50")
	_expect(falling.speed_divisor == ProjectileScript.SPEED_DIVISOR_SMALL, "kind 2 divides speed by 0.4")
	falling.free()


func _test_spawn_and_phase() -> void:
	tank.shutdown()
	var shot: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	_expect(shot.phase == SimScript.Phase.PROJECTILES, "shots tick in the PROJECTILES phase")
	_expect(tank.layer_for(SimScript.Phase.PROJECTILES).get_child_count() == 1,
		"the shot is parented to the projectile layer")
	_expect(shot.position == Vector2(300.0, 200.0), "the spawn position is kept")


func _test_immunity() -> void:
	tank.shutdown()
	var shot: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	_expect(not shot.hit_test(Vector2(300.0, 200.0)), "a shot cannot be clicked while immune")
	_step(15)
	_expect(shot.spawn_immunity == 0, "immunity runs out after 15 ticks (got %d)" % shot.spawn_immunity)
	_expect(shot.hit_test(Vector2(300.0, 200.0)), "a matured shot accepts a click")


func _test_expiry() -> void:
	tank.shutdown()
	var shot: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0))
	var removed: Array[Projectile] = []
	shot.removed.connect(func(p) -> void: removed.append(p))
	shot.begin_expiry()
	_expect(shot.expiry == 1, "begin_expiry arms the counter at 1")
	_step(8)
	_expect(not shot.dead and removed.is_empty(), "the shot survives 8 of its 10 expiry ticks")
	_step(1)
	_expect(shot.dead, "the shot is removed on the 9th tick after arming (counter reaches 10)")
	_expect(removed.size() == 1, "removal emits once, got %d" % removed.size())
	shot.begin_expiry()
	_expect(shot.expiry == ProjectileScript.EXPIRY_LIMIT, "begin_expiry on a dead shot changes nothing")


func _test_bounds() -> void:
	# Kind 0 is clamped into the tank rather than dying.
	tank.shutdown()
	var missile: Projectile = tank.spawn_projectile(MISSILE, Vector2(600.0, 400.0))
	_step(1)
	_expect(not missile.dead, "a missile is never killed by the bounds")
	_expect(missile.position == Vector2(550.0, 370.0),
		"a missile is clamped to 10..550 x 95..370 (got %s)" % missile.position)

	# Kind 2 dies outside the wider rect.
	tank.shutdown()
	var falling: Projectile = tank.spawn_projectile(FALLING, Vector2(0.0, 0.0))
	_step(1)
	_expect(falling.dead, "kind 2 dies outside -20..580 x 45..380")

	# Kind 1 survives until it is deflected, then the same rect applies.
	tank.shutdown()
	var ball: Projectile = tank.spawn_projectile(BALL, Vector2(-40.0, 10.0))
	_step(1)
	_expect(not ball.dead, "an undeflected ball ignores the bounds rect")
	ball.flag_190 = true
	_step(1)
	_expect(ball.dead, "a deflected ball dies outside the rect")


func _test_gravity() -> void:
	tank.shutdown()
	var falling: Projectile = tank.spawn_projectile(FALLING, Vector2(300.0, 200.0))
	_step(1)
	_expect(falling.vy == 0.0, "kind 2 has no gravity before it is set")
	falling.flag_190 = true
	_step(1)
	_expect(is_equal_approx(falling.vy, 0.2), "kind 2 gains 0.2 vy per tick (got %.2f)" % falling.vy)
	_expect(is_equal_approx(falling.position.y, 200.5),
		"0.2 vy over the 0.4 divisor moves 0.5 px (got %.2f)" % falling.position.y)


func _test_movement() -> void:
	tank.shutdown()
	var missile: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	missile.vx = 2.0
	missile.vy = -1.6
	_step(1)
	_expect(is_equal_approx(missile.position.x, 302.5), "vx 2 at divisor 0.8 moves 2.5 px")
	_expect(is_equal_approx(missile.position.y, 198.0), "vy -1.6 at divisor 0.8 moves -2 px")


func _test_hit_tests() -> void:
	# Kind 0: 60x60 box, destroyed by the click.
	tank.shutdown()
	var missile: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	_step(15)
	var bursts: Array[Vector2] = []
	missile.burst_requested.connect(func(at: Vector2) -> void: bursts.append(at))
	_expect(not missile.hit_test(Vector2(340.0, 200.0)), "31 px from a missile is a miss")
	_expect(missile.hit_test(Vector2(329.0, 200.0)), "29 px from a missile is a hit")
	_expect(missile.dead, "the missile is shot down")
	_expect(bursts.size() == 1 and bursts[0] == Vector2(289.0, 160.0),
		"the burst lands at (click - 40), got %s" % [bursts])

	# Kind 1: deflection formula, `((click - pos) - 40) / -5` clamped to [-1, 1].
	tank.shutdown()
	var ball: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0))
	_step(15)
	_expect(not ball.hit_test(Vector2(300.0, 200.0)), "the ball box starts 10 px in from the origin")
	_expect(ball.hit_test(Vector2(340.0, 240.0)), "the centre offset of the ball box is a hit")
	_expect(ball.vx == 0.0 and ball.vy == 0.0, "a click on the box centre deflects to zero velocity")
	_expect(ball.flag_190, "a deflection sets the flag")

	ball.spawn_immunity = 0
	_expect(ball.hit_test(Vector2(369.0, 240.0)), "a click near the box edge also hits")
	_expect(ball.vx == -1.0, "the deflection is clamped at -1 (got %.2f)" % ball.vx)

	# Kind 2 is not clickable at all.
	tank.shutdown()
	var falling: Projectile = tank.spawn_projectile(FALLING, Vector2(300.0, 200.0))
	_step(15)
	_expect(not falling.is_clickable(), "kind 2 is not clickable")
	_expect(not falling.hit_test(Vector2(300.0, 200.0)), "clicking kind 2 consumes nothing")
	_expect(not falling.dead, "kind 2 survives the click")


func _test_smoke() -> void:
	tank.shutdown()
	tank.set_seed(99)
	var missile: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	var puffs: Array[Vector2] = []
	missile.smoke_requested.connect(func(at: Vector2) -> void: puffs.append(at))
	_step(40)
	_expect(puffs.size() > 0, "a missile leaves smoke on rand%%3 == 0 (%d in 40 ticks)" % puffs.size())

	var ball: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0))
	var ball_puffs: Array[Vector2] = []
	ball.smoke_requested.connect(func(at: Vector2) -> void: ball_puffs.append(at))
	_step(40)
	_expect(ball_puffs.is_empty(), "only kind 0 smokes (kind 1 smoked %d times)" % ball_puffs.size())


func _test_victim_lock() -> void:
	tank.shutdown()
	var victim := FakeTarget.new()
	var shot: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0), victim)
	_expect(victim.locked == shot, "the spawner locks the victim onto the shot")
	shot.release_target()
	_expect(victim.locked == null, "releasing the shot clears the victim's pointer")
	victim.free()


# --- helpers -----------------------------------------------------------------

## Exactly `count` logic ticks with no carried backlog.
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
