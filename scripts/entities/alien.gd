class_name Alien
extends SimEntity
## Alien (P2.8). One entity with a `kind` field and a `kind -> AlienDef` table - the original does not
## have a class per species (SPECS §3.5). Kinds 9..0xC are composite spawn recipes, not entities, so
## they are absent here and handled by `WaveClock`.
##
## Recovered here: the hp/speed table, the movement bands and wander re-roll, the 7-tick intro drift,
## the three attacks (missiles_3, balls_2, rest_cycle) as timers that emit spawn requests, the chase +
## reach-test eating model, and the shot-death path (a Diamond when no boss is alive).
##
## Q-0045 (open): the note gives the wander as a "quadrant wander" with 0.1 steps and a 20-tick/10 %
## re-roll but not how the target quadrant is chosen, nor the bottom lane's y for kinds 5/6, nor
## Bilaterus' head hp (its two heads are 100 each) or Cyrax's profile-scaled hp. The wander target is
## therefore a random point in the band and the bottom lane uses the lower quarter of the band; both
## are flagged, not settled.

const DEFS := {
	0x01: {"hp": 50, "speed": 2.0, "band": "full", "attack": "none"},
	0x02: {"hp": 60, "speed": 1.6, "band": "full", "attack": "none"},
	0x03: {"hp": 130, "speed": 1.2, "band": "full", "attack": "none"},
	0x04: {"hp": 100, "speed": 1.6, "band": "full", "attack": "none", "eats_pellets": true},
	0x05: {"hp": 150, "speed": 1.2, "band": "bottom", "attack": "missiles_3"},
	0x06: {"hp": 220, "speed": 3.5, "band": "bottom", "attack": "balls_2"},
	0x07: {"hp": 260, "speed": 0.5, "band": "full", "attack": "rest_cycle"},
	0x08: {"hp": 0, "speed": 1.0, "band": "full", "attack": "heads"},
	0x14: {"hp": 1, "speed": 1.0, "band": "mini", "attack": "none"},
	0x15: {"hp": 5000, "speed": 2.0, "band": "full", "attack": "boss"},
}

## The image each kind binds in `FUN_004DAE20` (P2.8 §3). Kinds 1 and 2 share the Sylvester sheet;
## Cyrax uses `IMAGE_BOSS`, not the Sylvester row. `Bilaterus` has no playback metadata, so the
## level draws its first cell rather than cycling all 80 cells.
const IMAGE_BY_KIND := {
	0x01: "IMAGE_SYLV", 0x02: "IMAGE_SYLV", 0x03: "IMAGE_BALROG", 0x04: "IMAGE_GUS",
	0x05: "IMAGE_DESTRUCTOR", 0x06: "IMAGE_ULYSSES", 0x07: "IMAGE_PSYCHOSQUID",
	0x08: "IMAGE_BILATERUS", 0x14: "IMAGE_MINISYLV", 0x15: "IMAGE_BOSS",
}

## The drawn box (`+0x38/+0x3C`, P2.8 §2.1): 160x160, except Minisylvester's 80x80. The entity
## position is the box centre, so a sprite of this size is centred on it.
const BOX_LARGE := 160.0
const BOX_MINI := 80.0

## Bands: full x -10..490 / y 85..290; the mini variant 10..540 / 95..370 (SPECS §3.5).
const BAND_FULL := Rect2(-10.0, 85.0, 500.0, 205.0)
const BAND_MINI := Rect2(10.0, 95.0, 530.0, 275.0)
## Kinds 5/6 sit on a bottom lane; only its lower edge is given by the table's band (Q-0045).
const BAND_BOTTOM := Rect2(-10.0, 250.0, 500.0, 40.0)
## Wander: 0.1 steering steps, capped, re-rolled after 20 ticks at 10 %.
const STEER := 0.1
const STEER_CAP := 1.8
const GUS_STEER := 0.3
const GUS_CAP := 3.0
const WANDER_REROLL_TICKS := 20
const WANDER_REROLL_CHANCE := 10
## Intro: ±3 px/tick drift for 7 ticks before normal movement.
const INTRO_TICKS := 7
const INTRO_DRIFT := 3.0
## missiles_3: 75 ticks between shots, then a `rand % 50 + 150` gap; balls_2 shares the base period.
const MISSILE_PERIOD := 75
const MISSILE_TAIL_BASE := 150
const MISSILE_TAIL_SPAN := 50
const ATTACK_SHOTS := 3
## Psychosquid's rest cycle.
const REST_TICKS := 400
## Reach boxes (centre to centre): ±45 x / ±65 y, mini ±30, type 6 ±70/±85.
const REACH_X := 45.0
const REACH_Y := 65.0
const REACH_MINI := 30.0
const REACH_ULYSSES_X := 70.0
const REACH_ULYSSES_Y := 85.0
## Death: kind 4 Diamond, value 200 (P2.5).
const DIAMOND_KIND := 0x04

## Asked to spawn a projectile: kind 0 missile, kind 1 energy ball (P2.10 §5).
signal attack_requested(shot_kind: int, at: Vector2, target: Node2D)
## `from_shot == false` means the alien died without a shot and every effect is skipped.
signal died(alien, from_shot: bool)
## Sound cues for the audio layer (P4.13).
signal cue(name: String)

var kind := 0x01
var hp := 0
var speed := 1.0
var eats_pellets := false
var vx := 0.0
var vy := 0.0
var wander_target := Vector2.ZERO
var wander_timer := 0
var intro_timer := INTRO_TICKS
var intro_dir := 1.0
var attack_timer := 0
var shots_left := ATTACK_SHOTS
var resting := false
var rest_timer := 0

## `+0x98`: the "incoming projectile" back-pointer (P2.10 §5.1). Aliens are not homing victims in
## retail play (the picker scans the fish lists), but a deflected ball can hit one (EV-0158), so
## the slot exists for parity with `Fish` and clears with the same rules.
var locked_projectile: Node2D = null



static func create(kind_: int, pos: Vector2) -> Alien:
	var alien := Alien.new()
	if not DEFS.has(kind_):
		push_error("Alien.create: unknown kind %d" % kind_)
		kind_ = 0x01
	alien.kind = kind_
	alien.position = pos
	var def: Dictionary = DEFS[kind_]
	alien.hp = int(def["hp"])
	alien.speed = float(def["speed"])
	alien.eats_pellets = bool(def.get("eats_pellets", false))
	alien.wander_target = pos
	alien.attack_timer = MISSILE_PERIOD
	return alien


static func image_id_for(kind_: int) -> String:
	return String(IMAGE_BY_KIND.get(kind_, "IMAGE_SYLV"))


func image_id() -> String:
	return image_id_for(kind)


func def() -> Dictionary:
	return DEFS[kind]


func attack() -> String:
	return String(DEFS[kind]["attack"])


func is_mini() -> bool:
	return int(DEFS[kind]["hp"]) == 1


## Drawn box size (P2.8 §2.1), used to centre the sprite and place the HP bar.
func box_size() -> float:
	return BOX_MINI if is_mini() else BOX_LARGE


## `+0x1F8`, the hp copied at spawn: the HP-bar denominator (P2.9 §5). Bilaterus' body has none
## (its two heads each carry 100), so it is 0 and no bar is drawn.
func initial_hp() -> int:
	return int(DEFS[kind]["hp"])


## The movement band for this kind (Q-0045 on the bottom lane's height).
func band() -> Rect2:
	match String(DEFS[kind]["band"]):
		"mini":
			return BAND_MINI
		"bottom":
			return BAND_BOTTOM
		_:
			return BAND_FULL


func _advance() -> void:
	if intro_timer > 0:
		intro_timer -= 1
		position.x += intro_dir * INTRO_DRIFT / speed
		_clamp()
		return

	var target := _nearest_target()
	if target != null:
		_steer_to(target.position)
		_move()
		if _in_reach(target):
			_consume(target)
	else:
		_wander()
		_move()
	_tick_attack()
	_tick_rest()


## Kinds 5 and 6 never eat (SPECS §3.5); Gus eats pellets; everyone else hunts fish.
func _nearest_target() -> Node2D:
	if kind == 0x05 or kind == 0x06 or tank == null:
		return null
	var best: Node2D = null
	var best_distance := INF
	var phase := Sim.Phase.FOOD if eats_pellets else Sim.Phase.FISH
	for entity: SimEntity in tank.entities_in(phase):
		var distance := position.distance_squared_to(entity.position)
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best


## The projectile target picker (`FUN_004E8DF0`, P2.8 §8.2, EV-0158): the *farthest* eligible
## fish, not the nearest one the alien chases. Types 5-0xA (Oscar/Ultravore/Beetlemuncher and the
## two neighbours) are unconditional; type 0 (Guppy) is gated by `FUN_00500FF0`, whose body is
## unrecovered, so the port treats every live fish as eligible and keeps the gate open as a
## documented approximation. No eligible fish means no shot (the caller in `_tick_shots` holds the
## volley). Kinds 5/6 never chase (`_nearest_target` returns null for them) but *do* shoot at
## this target, which is why the two pickers are separate.
func _farthest_target() -> Node2D:
	if tank == null:
		return null
	var best: Node2D = null
	var best_distance := -1.0
	for entity: SimEntity in tank.entities_in(Sim.Phase.FISH):
		var distance := position.distance_squared_to(entity.position)
		if distance > best_distance:
			best_distance = distance
			best = entity
	return best


func _steer_to(at: Vector2) -> void:
	var step := GUS_STEER if eats_pellets else STEER
	var cap := GUS_CAP if eats_pellets else STEER_CAP
	var dx := at.x - position.x
	var dy := at.y - position.y
	if absf(dx) > 1.0:
		vx = clampf(vx + signf(dx) * step, -cap, cap)
	if absf(dy) > 1.0:
		vy = clampf(vy + signf(dy) * step, -cap, cap)


func _wander() -> void:
	wander_timer += 1
	if wander_timer > WANDER_REROLL_TICKS:
		wander_timer = 0
		if _roll(WANDER_REROLL_CHANCE) == 0:
			wander_target = _random_point()
	_steer_to(wander_target)


func _random_point() -> Vector2:
	var b := band()
	return Vector2(
		b.position.x + float(_roll(int(b.size.x))),
		b.position.y + float(_roll(int(b.size.y)))
	)


func _move() -> void:
	position.x += vx / speed
	position.y += vy / speed
	_clamp()


func _clamp() -> void:
	var b := band()
	position.x = clampf(position.x, b.position.x, b.position.x + b.size.x)
	position.y = clampf(position.y, b.position.y, b.position.y + b.size.y)


## Centre-to-centre reach test; the Ulysses (6) and mini boxes differ (SPECS §3.5).
func _in_reach(target: Node2D) -> bool:
	var dx := absf(target.position.x - position.x)
	var dy := absf(target.position.y - position.y)
	if is_mini():
		return dx <= REACH_MINI and dy <= REACH_MINI
	if kind == 0x06:
		return dx <= REACH_ULYSSES_X and dy <= REACH_ULYSSES_Y
	return dx <= REACH_X and dy <= REACH_Y


func _consume(target: Node2D) -> void:
	if target is Fish:
		(target as Fish).die()
	elif target is Food:
		target.despawn()


## Attacks are data-driven timers that only ask for the projectile; the spawner is the tank's.
func _tick_attack() -> void:
	match attack():
		"missiles_3":
			_tick_shots(0)
		"balls_2":
			_tick_shots(1)
		"rest_cycle":
			pass  # handled by `_tick_rest`
		_:
			pass


func _tick_shots(shot_kind: int) -> void:
	attack_timer -= 1
	if attack_timer > 0:
		return
	# `FUN_004E8DF0` returns the farthest eligible fish; no eligible target means no shot
	# (P2.8 §8.2, EV-0158). The volley counter does not advance on a held shot.
	var target := _farthest_target()
	if target == null:
		attack_timer = MISSILE_PERIOD
		return
	attack_requested.emit(shot_kind, position, target)
	cue.emit("missile" if shot_kind == 0 else "ball")
	shots_left -= 1
	if shots_left <= 0:
		shots_left = ATTACK_SHOTS
		attack_timer = MISSILE_TAIL_BASE + _roll(MISSILE_TAIL_SPAN)
	else:
		attack_timer = MISSILE_PERIOD


## Psychosquid alternates a slow rest with a fast swim every 400 ticks.
func _tick_rest() -> void:
	if attack() != "rest_cycle":
		return
	rest_timer += 1
	if rest_timer < REST_TICKS:
		return
	rest_timer = 0
	resting = not resting
	speed = 2.0 if resting else 0.5


## A shot hit. `from_shot == false` skips the Diamond and every effect (SPECS §3.5).
func hit(damage: int, from_shot: bool = true) -> void:
	if dead:
		return
	hp -= damage
	if hp <= 0:
		die(from_shot)


func lock_projectile(shot) -> void:
	locked_projectile = shot


func unlock_projectile(shot) -> void:
	if locked_projectile == shot:
		locked_projectile = null



func die(from_shot: bool = true) -> void:
	if dead:
		return
	_release_projectile_lock()
	died.emit(self, from_shot)
	if from_shot and not (tank != null and bool(tank.boss_alive)):
		tank.spawn_coin(DIAMOND_KIND, position)
	despawn()


func _release_projectile_lock() -> void:
	if locked_projectile != null:
		var shot := locked_projectile
		locked_projectile = null
		if is_instance_valid(shot) and shot.has_method("release_target"):
			shot.release_target()


func _exit_tree() -> void:
	_release_projectile_lock()
	super()



func _roll(limit: int) -> int:
	if limit <= 1:
		return 0
	if tank != null and tank.has_method("randi_below"):
		return tank.randi_below(limit)
	return 0
