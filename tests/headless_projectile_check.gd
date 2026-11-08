extends SceneTree
## Headless check for the Projectile entity (P4.3/P4.10).
##
##   & "<godot>" --headless --path . --script res://tests/headless_projectile_check.gd
##
## Covers the ctor constants per kind (P2.10 §5.2), spawn immunity, the 10-tick expiry, the per-kind
## bounds rule, kind 2's gravity, movement through the speed divisor, both click hit-tests, the smoke
## trail roll, the victim lock, and the homing body (`FUN_004FF4E0`/`FUN_004FC070`, EV-0158):
## steering toward the victim, target-loss expiry, locked-victim kills and deflected-ball hits.
## Null-target kinds 0/1 expire on the first tick (`FUN_004FF4E0`), so every long-lived shot in
## these tests spawns with a `FakeTarget` victim.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const ProjectileScript := preload("res://scripts/entities/projectile.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const AlienScript := preload("res://scripts/entities/alien.gd")

const MISSILE := ProjectileScript.Kind.MISSILE
const BALL := ProjectileScript.Kind.BALL
const FALLING := ProjectileScript.Kind.FALLING

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank
var _victims: Array[Node2D] = []


## Victim stand-in for the `+0x98` back-pointer, duck-typed like `Fish`.
class FakeTarget:
	extends Node2D
	var locked_projectile: Node = null

	func lock_projectile(shot) -> void:
		locked_projectile = shot

	func unlock_projectile(shot) -> void:
		if locked_projectile == shot:
			locked_projectile = null

	func obj_type() -> int:
		return 0


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 31337)

	_test_ctor_constants()
	_test_images()
	_test_spawn_and_phase()
	_test_immunity()
	_test_expiry()
	_test_bounds()
	_test_gravity()
	_test_movement()
	_test_hit_tests()
	_test_smoke()
	_test_victim_lock()
	_test_homing()
	_test_locked_hit()
	_test_deflected_hit()

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


func _test_images() -> void:
	_expect(ProjectileScript.image_id_for(MISSILE) == "IMAGE_MISSILE", "kind 0 draws IMAGE_MISSILE")
	_expect(ProjectileScript.image_id_for(BALL) == "IMAGE_ENERGYBALL", "kind 1 draws IMAGE_ENERGYBALL")
	_expect(ProjectileScript.image_id_for(FALLING) == "IMAGE_BALLS", "kind 2 draws IMAGE_BALLS")


func _test_spawn_and_phase() -> void:
	tank.shutdown()
	# Kind 2 has no target-loss expiry, so it can spawn bare; kinds 0/1 need a victim (EV-0158).
	var shot: Projectile = tank.spawn_projectile(FALLING, Vector2(300.0, 200.0))
	_expect(shot.phase == SimScript.Phase.PROJECTILES, "shots tick in the PROJECTILES phase")
	_expect(tank.layer_for(SimScript.Phase.PROJECTILES).get_child_count() == 1,
		"the shot is parented to the projectile layer")
	_expect(shot.position == Vector2(300.0, 200.0), "the spawn position is kept")


## A shot with a live victim far enough away that a short step run cannot reach its box.
func _locked(kind: int, at: Vector2, victim_at: Vector2) -> Projectile:
	_cleanup_victims()
	var victim := FakeTarget.new()
	victim.position = victim_at
	_victims.append(victim)
	return tank.spawn_projectile(kind, at, victim)


func _cleanup_victims() -> void:
	for victim in _victims:
		if is_instance_valid(victim):
			victim.free()
	_victims.clear()
	tank.shutdown()


func _test_immunity() -> void:
	_cleanup_victims()
	var shot: Projectile = _locked(MISSILE, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
	_expect(not shot.hit_test(Vector2(300.0, 200.0)), "a shot cannot be clicked while immune")
	_step(15)
	_expect(shot.spawn_immunity == 0, "immunity runs out after 15 ticks (got %d)" % shot.spawn_immunity)
	_expect(shot.hit_test(shot.position), "a matured shot accepts a click")


func _test_expiry() -> void:
	_cleanup_victims()
	var shot: Projectile = _locked(BALL, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
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
	_cleanup_victims()
	var missile: Projectile = _locked(MISSILE, Vector2(600.0, 400.0), Vector2(300.0, 200.0))
	_step(1)
	_expect(not missile.dead, "a missile is never killed by the bounds")
	_expect(missile.position.x >= 10.0 and missile.position.x <= 550.0
		and missile.position.y >= 95.0 and missile.position.y <= 370.0,
		"a missile is clamped to 10..550 x 95..370 (got %s)" % missile.position)

	# Kind 2 dies outside the wider rect.
	tank.shutdown()
	var falling: Projectile = tank.spawn_projectile(FALLING, Vector2(0.0, 0.0))
	_step(1)
	_expect(falling.dead, "kind 2 dies outside -20..580 x 45..380")

	# Kind 1 survives until it is deflected, then the same rect applies.
	_cleanup_victims()
	var ball: Projectile = _locked(BALL, Vector2(-40.0, 10.0), Vector2(500.0, 200.0))
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
	_cleanup_victims()
	# Victim at +30 x keeps the homing step from touching the seed velocities (px is 10 px right
	# of the victim, inside the 1.4 band where both seeds are already at/above the cap).
	var missile: Projectile = _locked(MISSILE, Vector2(300.0, 200.0), Vector2(330.0, 200.0))
	missile.vx = 2.0
	missile.vy = -1.6
	_step(1)
	_expect(is_equal_approx(missile.position.x, 302.5), "vx 2 at divisor 0.8 moves 2.5 px")
	_expect(is_equal_approx(missile.position.y, 198.0), "vy -1.6 at divisor 0.8 moves -2 px")


func _test_hit_tests() -> void:
	# Kind 0: 60x60 box, destroyed by the click. Clicks are relative to the drifted position.
	_cleanup_victims()
	var missile: Projectile = _locked(MISSILE, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
	_step(15)
	var bursts: Array[Vector2] = []
	missile.burst_requested.connect(func(at: Vector2) -> void: bursts.append(at))
	var miss_at := missile.position + Vector2(31.0, 0.0)
	var hit_at := missile.position + Vector2(29.0, 0.0)
	_expect(not missile.hit_test(miss_at), "31 px from a missile is a miss")
	_expect(missile.hit_test(hit_at), "29 px from a missile is a hit")
	_expect(missile.dead, "the missile is shot down")
	_expect(bursts.size() == 1 and bursts[0] == hit_at - Vector2(40.0, 40.0),
		"the burst lands at (click - 40), got %s" % [bursts])

	# Kind 1: deflection formula, `((click - pos) - 40) / -5` clamped to [-1, 1].
	_cleanup_victims()
	var ball: Projectile = _locked(BALL, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
	_step(15)
	_expect(not ball.hit_test(ball.position), "the ball box starts 10 px in from the origin")
	_expect(ball.hit_test(ball.position + Vector2(40.0, 40.0)), "the centre offset of the ball box is a hit")
	_expect(ball.vx == 0.0 and ball.vy == 0.0, "a click on the box centre deflects to zero velocity")
	_expect(ball.flag_190, "a deflection sets the flag")

	ball.spawn_immunity = 0
	_expect(ball.hit_test(ball.position + Vector2(69.0, 40.0)), "a click near the box edge also hits")
	_expect(ball.vx == -1.0, "the deflection is clamped at -1 (got %.2f)" % ball.vx)

	# Kind 2 is not clickable at all.
	tank.shutdown()
	var falling: Projectile = tank.spawn_projectile(FALLING, Vector2(300.0, 200.0))
	_step(15)
	_expect(not falling.is_clickable(), "kind 2 is not clickable")
	_expect(not falling.hit_test(Vector2(300.0, 200.0)), "clicking kind 2 consumes nothing")
	_expect(not falling.dead, "kind 2 survives the click")


func _test_smoke() -> void:
	_cleanup_victims()
	tank.set_seed(99)
	var missile: Projectile = _locked(MISSILE, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
	var puffs: Array[Vector2] = []
	missile.smoke_requested.connect(func(at: Vector2) -> void: puffs.append(at))
	_step(40)
	_expect(puffs.size() > 0, "a missile leaves smoke on rand%%3 == 0 (%d in 40 ticks)" % puffs.size())

	var ball: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0), missile.target)
	var ball_puffs: Array[Vector2] = []
	ball.smoke_requested.connect(func(at: Vector2) -> void: ball_puffs.append(at))
	_step(40)
	_expect(ball_puffs.is_empty(), "only kind 0 smokes (kind 1 smoked %d times)" % ball_puffs.size())


func _test_victim_lock() -> void:
	_cleanup_victims()
	var victim := FakeTarget.new()
	_victims.append(victim)
	var shot: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0), victim)
	_expect(victim.locked_projectile == shot, "the spawner locks the victim onto the shot")
	shot.release_target()
	_expect(victim.locked_projectile == null, "releasing the shot clears the victim's pointer")


## Homing (`FUN_004FF4E0`, EV-0158): a shot left of its victim steers right toward the 1.8 cap,
## and a shot right of it steers left. Target-loss expiry: kinds 0/1 disappear when the lock is
## cleared; kind 2 flies on.
func _test_homing() -> void:
	_cleanup_victims()
	var left: Projectile = _locked(MISSILE, Vector2(100.0, 200.0), Vector2(300.0, 200.0))
	_step(1)
	_expect(left.vx > 0.0, "a shot left of its victim gains rightward velocity (got %.2f)" % left.vx)
	_expect(left.position.x > 100.0, "the shot moves toward the victim")

	_cleanup_victims()
	var right: Projectile = _locked(MISSILE, Vector2(400.0, 200.0), Vector2(300.0, 200.0))
	_step(1)
	_expect(right.vx < 0.0, "a shot right of its victim gains leftward velocity (got %.2f)" % right.vx)

	_cleanup_victims()
	var bare: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0))
	_step(1)
	_expect(bare.dead, "a missile with no victim expires on the first tick")

	_cleanup_victims()
	var lost: Projectile = _locked(MISSILE, Vector2(100.0, 200.0), Vector2(500.0, 200.0))
	lost.release_target()
	_step(1)
	_expect(lost.dead, "a missile whose lock is cleared expires")

	_cleanup_victims()
	var falling: Projectile = _locked(FALLING, Vector2(300.0, 200.0), Vector2(500.0, 200.0))
	falling.release_target()
	_step(1)
	_expect(not falling.dead, "kind 2 does not expire on target loss")


## Locked-victim kill (`FUN_004FC070`, EV-0158): the `+40` sample inside the 10..70 box consumes
## the shot and kills a real fish (the slot-77 consume is `die()` in the port).
func _test_locked_hit() -> void:
	_cleanup_victims()
	var victim := FakeTarget.new()
	victim.position = Vector2(310.0, 200.0)
	_victims.append(victim)
	var shot: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0), victim)
	var hits: Array = []
	shot.hit_target.connect(func(v) -> void: hits.append(v))
	_step(1)
	_expect(shot.dead, "the locked hit consumes the shot")
	_expect(hits.size() == 1 and hits[0] == victim, "the hit reports its victim")

	# A real fish dies to the same box.
	tank.shutdown()
	var fish: Fish = tank.spawn_fish(0, Vector2(310.0, 200.0), 0, 1)
	var shot2: Projectile = tank.spawn_projectile(MISSILE, Vector2(300.0, 200.0), fish)
	_step(1)
	_expect(fish.dead, "an undistracted shot kills the fish in its box")
	_expect(shot2.dead, "and is consumed doing it")


## Deflected ball (`FUN_004FC070`, EV-0158): 30 damage vs an alien consumes the shot; fish hits
## kill the fish but the ball flies on.
func _test_deflected_hit() -> void:
	# Alien: 30 damage, shot consumed. The ball still needs a live victim or target-loss
	# expiry would eat it first (EV-0158).
	tank.shutdown()
	tank.boss_alive = false
	var victim := FakeTarget.new()
	victim.position = Vector2(500.0, 200.0)
	_victims.append(victim)
	var alien: Alien = tank.spawn_alien(0x01, Vector2(300.0, 200.0))
	var ball: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0), victim)
	ball.flag_190 = true
	ball.vx = 1.0
	ball.vy = 0.0
	_step(1)
	_expect(alien.hp == 20, "a deflected ball does 30 damage (hp %d)" % alien.hp)
	_expect(ball.dead, "the alien hit consumes the deflected ball")

	# Fish: dies, ball survives.
	tank.shutdown()
	var fish: Fish = tank.spawn_fish(0, Vector2(310.0, 200.0), 0, 1)
	var remover := FakeTarget.new()
	remover.position = Vector2(500.0, 200.0)
	_victims.append(remover)
	var ball2: Projectile = tank.spawn_projectile(BALL, Vector2(300.0, 200.0), remover)
	ball2.flag_190 = true
	ball2.vx = 1.0
	ball2.vy = 0.0
	_step(1)
	_expect(fish.dead, "a deflected ball kills the fish it passes through")
	_expect(not ball2.dead, "but the ball flies on")


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
