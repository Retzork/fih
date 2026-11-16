class_name Fish
extends SimEntity
## Fish (P2.2 §4-§6, P2.3 §5-§7, P2.4 §1-§5). One script for the seven Fish species because the
## original's seven classes share `Fish::Update` (slot 22, `FUN_004F6970`) and the hunger, consume
## and growth tails; only the ctor tuning and a few consume numbers differ, so they live in
## `SPECIES` as data.
##
## Not in this entity: Penta/Grubber (the note's "creatures", not Fish), pets (`FishTypePet`), the
## DeadFish corpse (P4.4 will spawn it from `died`/`successor_requested`) and the coin object itself
## (`coin_due` leaves the kind to the coin system because the stage -> kind table is open, Q-0036).
##
## Field offsets are the note's `+0x..` so every constant can be traced back:
##   `+0x158` x, `+0x160` y, `+0x168` vx, `+0x170` vy, `+0x178` turn dir, `+0x180` speed divisor,
##   `+0x190` bottom/max y, `+0x194` left, `+0x198` top/min y, `+0x19C` right, `+0x1A0` stage,
##   `+0x1A4` food points, `+0x1A8` points needed, `+0x1AC` swim mode, `+0x1B0` mode timer,
##   `+0x1B4` random-switch timer, `+0x1BC` target/rhythm timer, `+0x1C4` facing,
##   `+0x1CC` grow-pop timer, `+0x208` dart timer, `+0x20C`/`+0x218` knockback,
##   `+0x220`/`+0x224` coin counter/threshold, `+0x229` seek gate.
##
## Q-0037: the shared consume tail's stage comparisons are implemented literally. Oscar/Ultra/Gekko
## start at stages 5/6/7, so they never take the `stage < 2` growth branch; whether the overshoot
## branch (15 x threshold points -> stage 4) is reachable for them in play is unverified.
## Q-0038: slot 84 and `Fish::Update`'s food-seek branch both steer toward food with the same normal
## acceleration bands; this script implements one combined seek+eat path instead of double-steering.
## The `+0x229` gate only suppresses active steering, so a non-seeker still eats a pellet inside the
## window. Q-0039: the swim target-timer seed comes from `FUN_00564160` (= CRT `ftol`, EV-0118); its
## float operand is not in the decompile, so `_roll_target_timer()` uses `rand % 6` as a placeholder.

enum Species { GUPPY, OSCAR, ULTRA, GEKKO, MINISYLVESTER, BALL, BILATERUS }

## Constructor data: `FUN_004DE370` for the common defaults, then the per-species init helpers
## (`FUN_004D84C0` Oscar, `FUN_004D9EE0` Ultra, `FUN_004D72B0` Gekko, `FUN_004D95C0` Sylvester,
## `FUN_004DB2A0` Ball, `FUN_004DB820` Bi). `coin_min/span` is `rand%200 + base`.
const SPECIES := {
	Species.GUPPY: {
		"type_id": 0x00, "name": "Guppy", "stage": 0,
		"hunger_min": 400, "hunger_span": 200, "can_seek": true,
		"eat_amount": 500, "eat_cap": 800,
		"min_x": 10.0, "min_y": 95.0, "max_x": 540.0, "max_y": 370.0, "box": 80,
		"coin_min": 150, "coin_span": 200,
	},
	Species.OSCAR: {
		"type_id": 0x05, "name": "Carnivore", "stage": 5,
		"hunger_min": 600, "hunger_span": 200, "can_seek": false,
		"eat_amount": 900, "eat_cap": 1300,
		"min_x": 10.0, "min_y": 105.0, "max_x": 540.0, "max_y": 360.0, "box": 80,
		"coin_min": 200, "coin_span": 250,
	},
	Species.ULTRA: {
		"type_id": 0x06, "name": "Ultravore", "stage": 6,
		"hunger_min": 600, "hunger_span": 200, "can_seek": false,
		"eat_amount": 900, "eat_cap": 1300,
		"min_x": 0.0, "min_y": 75.0, "max_x": 480.0, "max_y": 310.0, "box": 160,
		"coin_min": 200, "coin_span": 250,
	},
	Species.GEKKO: {
		"type_id": 0x07, "name": "Beetlemuncher", "stage": 7,
		"hunger_min": 400, "hunger_span": 200, "can_seek": false,
		"eat_amount": 700, "eat_cap": 1000,
		"min_x": 10.0, "min_y": 105.0, "max_x": 540.0, "max_y": 360.0, "box": 80,
		"coin_min": 200, "coin_span": 250,
	},
	Species.MINISYLVESTER: {
		"type_id": 0x22, "name": "Minisylvester", "stage": 1,
		"hunger_min": 400, "hunger_span": 200, "can_seek": true,
		"eat_amount": 700, "eat_cap": 1000,
		"min_x": 10.0, "min_y": 105.0, "max_x": 540.0, "max_y": 360.0, "box": 80,
		"coin_min": 200, "coin_span": 250,
	},
	Species.BALL: {
		"type_id": 0x23, "name": "Ball Fish", "stage": 0,
		"hunger_min": 400, "hunger_span": 200, "can_seek": true,
		"eat_amount": 700, "eat_cap": 1000,
		"min_x": 10.0, "min_y": 105.0, "max_x": 540.0, "max_y": 360.0, "box": 50,
		"coin_min": 200, "coin_span": 250,
	},
	Species.BILATERUS: {
		"type_id": 0x24, "name": "Bilaterus Head", "stage": 0,
		"hunger_min": 400, "hunger_span": 200, "can_seek": true,
		"eat_amount": 700, "eat_cap": 1000,
		"min_x": 10.0, "min_y": 105.0, "max_x": 540.0, "max_y": 360.0, "box": 80,
		"coin_min": 200, "coin_span": 250,
	},
}

## `FUN_004DE370`: three speed classes, picked with rand%3.
const SPEED_CLASSES := [2.0, 1.8, 1.6]
## `FUN_004DE370`: `+0x1B0 = 0x28`; mode 0's glide and modes 1-4's 40-tick steps key off it.
const MODE_TIMER_START := 40
## Update tail: after >20 ticks, 10% chance to reroll the swim mode to `rand%9 + 1`.
const RANDOM_SWITCH_TICKS := 20
const RANDOM_SWITCH_CHANCE := 10
## Swim machine glide (px/tick before the speed divisor): modes 0 (0.25), 1-4 (0.5).
const GLIDE_SLOW := 0.25
const GLIDE_FAST := 0.5
## Modes 1/2 write -8.0 into vy (the decompiler's 0xC0200000 high-dword preset).
const DART_VY := -8.0
const MODE0_VY := 0.5
const MODE3_TARGET_VY := 3.0
## Mode 0x7B: drag after 30 ticks, reroll after 50, wall margin 20.
const DRIFT_DRAG_TICKS := 30
const DRIFT_REROLL_TICKS := 50
const DRIFT_DRAG := 0.95
const DRIFT_MARGIN := 20.0
## Modes >= 5 ("else" branch): y-dependent rise, zigzag between x 175 and 250.
const HOVER_SLOW_Y := 115.0
const HOVER_VY_LOW := -0.1
const HOVER_VY_HIGH := -0.5
const HOVER_LEFT := 175.0
const HOVER_RIGHT := 250.0
## Common tail: x/y clamps, wall-approach damping, and the integer-vx sink ladder.
const WALL_DAMP := 0.1
const WALL_LEFT := 15.0
const SINK_LADDER := {0.0: 1.0, 1.0: 0.75, 2.0: 0.5, 3.0: 0.25}
const SMALL_TANK_MAX_Y := 321.0
const DRIFT_UP := 0.25
## Hunger (P2.3 §5/§10): -1/tick, floor -1000, hints at -1/-200/-400, death below -499.
const HUNGER_DECAY := 1
const HUNGER_FLOOR := -1000
const HUNGER_DEATH := -500
const HUNGER_SEEK_LIMIT := 500
const HUNGER_HINTS := [-1, -200, -400]
## Eating (P2.3 §7.3): ~35 px eat window, ~50 px mouth-open anticipation, measured from the mouth
## (D-0024). The windows are the recovered numbers; what moved is the point they are measured from.
const EAT_WINDOW := 35.0
const EAT_ANTICIPATION := 50.0
## The mouth in the 80x80 body cell, measured off `SMALLSWIM`'s stage-0 frame: the fish spans x 23..54,
## y 24..54 of the cell and its mouth is the front tip at (24, 43), i.e. 16 px ahead of the cell centre
## and 3 px below it, mirrored by facing. Feeding used to be measured from the body centre, so a pellet
## 30 px from the mouth still vanished - the owner's "collision is way off" (D-0024).
const MOUTH_AHEAD := 16.0
const MOUTH_DROP := 3.0
const EAT_FX_TICKS := 8
const ANTICIPATION_TICKS := 0x14
## Food approach (P2.2 §5.5): ±5/±10 px bands; vx ±4, vy -3..+4.
const APPROACH_NEAR := 5.0
const APPROACH_FAR := 10.0
const APPROACH_VX_COARSE := 1.3
const APPROACH_VX_FINE := 0.2
const APPROACH_VX_HAIR := 0.05
const APPROACH_VY_COARSE := 1.0
const APPROACH_VY_UP := 0.7
const APPROACH_VY_FINE := 0.5
const APPROACH_VY_DOWN := 1.3
const APPROACH_VX_LIMIT := 4.0
const APPROACH_VY_MIN := -3.0
const APPROACH_VY_MAX := 4.0
## Shelter approach (p2.3 §6, EV-0090): the three `+/-5/3/1` steps, against the same 5/10 px bands
## `_steer_to` uses. The note gives the steps and the target, not the band distances.
const SHELTER_COARSE := 5.0
const SHELTER_FINE := 3.0
const SHELTER_HAIR := 1.0
## Growth (P2.3 §7.5): 0/1 -> 2 by points, stage 2 -> 4 only on huge overshoot.
const GROW_POP_TICKS := 10
const GUPPY_OVERSHOOT_MULT := 15
const VIRTUAL_OVERSHOOT_MULT := 8
## Star potion (P2.3 §7.5): quality 3 kills stage <= 1, promotes stage 2, feeds the rest.
const STAR_FEED := 1100
const STAR_CAP := 1400
## Coin scheduler (P2.3 §8, P2.4 §6): mode 5 adjusts the threshold by difficulty and can rewind a
## starving fish's counter. Normal mode is the plain `counter >= threshold`.
const COIN_HUNGRY_REWIND := 0x5A
const COIN_MIN_THRESHOLD := 360
const COIN_DIFFICULTY_STEP := -0x21C

## Emitted when fullness crosses -1, -200 or -400 (level 1/2/3).
signal hunger_warning(level: int)
## Emitted once when the fish dies (hunger, star potion, later predation).
signal died(fish)
## A breeding pellet (Food.variant 2) turn: the level spawns a new Guppy (P2.3 §7.5).
signal breed_requested(species: int, at: Vector2, facing: int)
## A stage change; `stage` is the new value (also covers the star-potion 2 -> 3 promotion).
signal grew(fish, stage: int)
## The drop counter matured. The coin system owns the stage -> kind/value mapping (Q-0036).
signal coin_due(fish)

## Persistable state (P2.13 implementation note #11): only what cannot be rebuilt. Food, coins,
## projectiles and particles are deliberately absent - a load rebuilds them.
func to_state() -> Dictionary:
	return {
		"species": species,
		"stage": stage,
		"x": position.x,
		"y": position.y,
		"facing": facing,
		"fullness": fullness,
		"food_points": food_points,
	}


## Rebuild a fish from `to_state()`. `Tank.spawn_fish` keeps registration ownership, so the entity
## still never registers itself.
static func from_state(tank_node, state: Dictionary) -> Fish:
	var species_id := int(state["species"])
	var facing_id := int(state["facing"])
	var fish: Fish = tank_node.spawn_fish(species_id,
		Vector2(float(state["x"]), float(state["y"])), int(state["stage"]), facing_id)
	if fish != null:
		fish.fullness = int(state["fullness"])
		fish.food_points = int(state["food_points"])
	return fish


var species := Species.GUPPY
var stage := 0
var virtual_tank := false
var sprite_box := 80
var can_seek := true

## `+0x98`: the "incoming projectile" back-pointer (P2.10 §5.1, EV-0124/EV-0158). The tank's
## projectile spawner locks the victim onto the shot; `FUN_004FF4E0` reads a cleared pointer as
## "target lost" and expires the shot. Cleared when the fish dies or leaves the tree.
var locked_projectile: Node2D = null


## `+0x158/+0x160` are the note's doubles; `position` is the Godot equivalent.
var vx := 0.0
var vy := -0.5
var speed_divisor := 2.0
var facing := 1
var flip := false
var min_x := 10.0
var min_y := 95.0
var max_x := 540.0
var max_y := 370.0

var fullness := 500
var food_points := 0
var food_needed := 5
var hunger_frozen := false
var _warned: Array[bool] = [false, false, false]

var swim_mode := 0
var mode_timer := MODE_TIMER_START
var random_timer := 0
var target_timer := 0
var turn_dir := 1
var dart_timer := 0
var knockback_timer := 0
var knockback_offset := 0.0
var misc_timer := 0
var grow_timer := 0
var eat_fx_timer := 0
var digest_timer := 0

var coin_counter := 0
var coin_threshold := 200
var coin_drops := 0

## `+0xF6`/`+0xF8`: the two alternate speed divisors (0.3 when the selector is 0, else 0.8).
var slow_override := false
var slow_selector := 0
## `+0x1D0`: demo/alternate draw flag; also blocks the stage-4 overshoot.
var alt_flag := 0


## Build a fish with the species ctor's tuning. `stage_` < 0 keeps the species default; `facing_`
## 0 rolls a side, -1/+1 forces it. `rng` must be the tank stream (SPECS.md §9.8).
static func create(
	species_: int,
	pos: Vector2,
	rng: RandomNumberGenerator,
	stage_: int = -1,
	facing_: int = 0,
	virtual_tank_: bool = false
) -> Fish:
	var fish := Fish.new()
	fish._configure(species_, pos, rng, stage_, facing_, virtual_tank_)
	return fish


func _configure(
	species_: int,
	pos: Vector2,
	rng: RandomNumberGenerator,
	stage_: int,
	facing_: int,
	virtual_tank_: bool
) -> void:
	if not SPECIES.has(species_):
		push_error("Fish.create: unknown species %d" % species_)
		species_ = Species.GUPPY
	if rng == null:
		# The tank owns the only stream; a null here is a spawn-path bug, not a reason to use the
		# global RNG. A fixed local stream keeps the failure deterministic and loud.
		push_error("Fish.create: rng is null - spawn through Tank")
		rng = RandomNumberGenerator.new()
		rng.seed = 0

	species = species_
	virtual_tank = virtual_tank_
	var def: Dictionary = SPECIES[species]
	position = pos
	stage = stage_ if stage_ >= 0 else int(def["stage"])
	sprite_box = int(def["box"])
	can_seek = bool(def["can_seek"])
	min_x = float(def["min_x"])
	min_y = float(def["min_y"])
	max_x = float(def["max_x"])
	max_y = float(def["max_y"])

	speed_divisor = float(SPEED_CLASSES[rng.randi_range(0, SPEED_CLASSES.size() - 1)])
	if facing_ == 0:
		flip = (rng.randi() & 1) == 1
	else:
		flip = facing_ < 0
	facing = -1 if flip else 1
	# Common ctor: one side gets vx -0.1, the other 0; vy is always -0.5.
	vx = -0.1 if flip else 0.0
	vy = -0.5

	fullness = int(def["hunger_min"]) + rng.randi_range(0, int(def["hunger_span"]) - 1)
	food_points = 0
	food_needed = (
		rng.randi_range(0, 8) + 12 if virtual_tank
		else rng.randi_range(0, 2) + 4
	)

	mode_timer = MODE_TIMER_START
	swim_mode = rng.randi_range(0, 9)
	turn_dir = 1 if (rng.randi() & 1) == 0 else -1
	target_timer = 0

	coin_counter = 0
	if virtual_tank:
		coin_threshold = rng.randi_range(0, 199) + 4320
	else:
		coin_threshold = int(def["coin_min"]) + rng.randi_range(0, int(def["coin_span"]) - 1)

	if species == Species.MINISYLVESTER and stage >= 2:
		_apply_sylvester_size(2)


## Per-species sprite binding (`EV-0164`). Every specimen class overrides the fish draw slot 83, and
## each one fixes its own row on the shared state sheet: the guppy's row follows its stage, the
## carnivore's is row 4 (`FUN_004E2480` sources `y 0x140`). `image` is set only for a species whose
## draw swaps in a sheet of its own; empty means the state sheet [`draw_image`] returns.
## Recovered: GUPPY (stage rows) and OSCAR (row 4). The other five classes also override the draw
## slot but their bodies are not decompiled yet - Gekko `0x4E17F0`, Ultra `0x4E3A10`, Sylvester
## `0x4E3420`, Ball `0x4DB3B0`, Bi `0x4DB9B0` - so they keep the port's earlier stand-in (their
## same-named sheet at cell 0, or the guppy body for the two with no swim sheet), per Q-0042.
const SPECIES_DRAW := {
	Species.GUPPY: {"image": "", "row": -1},
	Species.OSCAR: {"image": "", "row": 4},
	Species.ULTRA: {"image": "IMAGE_ULTRA", "row": 0},
	Species.GEKKO: {"image": "IMAGE_GEKKO", "row": 0},
	Species.BALL: {"image": "IMAGE_BALLS", "row": 0},
}

## The state sheets `FUN_004D5AA0` returns, `[normal, hungry]` (`EV-0164`). It yields a runtime-table
## index; that table carries 16 entries before the first manifest image, and four independent
## families confirm the `- 0x10` offset: `0x9B/0x9C` = SMALLTURN/HUNGRYTURN, `0x9E..0xA0` =
## SIMTURN1..3, `0xA5..0xA7` = SIMEAT1..3 and `0xA8..0xAA` = SIMSWIM1..3.
const STATE_SHEETS := {
	"swim": ["IMAGE_SMALLSWIM", "IMAGE_HUNGRYSWIM"],
	"eat": ["IMAGE_SMALLEAT", "IMAGE_HUNGRYEAT"],
	"turn": ["IMAGE_SMALLTURN", "IMAGE_HUNGRYTURN"],
}


## `FUN_004D5AA0`'s state split: eat art while the eat-fx timer runs (`+0x1C8`) or the fed countdown
## is past 100 (`+0x108`), otherwise the swim sheet. The turn sheet (`+0x1C4`) stays unwired: the
## port's `facing` is a latched side that is never 0, while the recovered test treats 0 as "not
## turning", so binding it would make turn art the default (Q-0042).
func draw_state() -> String:
	if eat_fx_timer >= 1 or digest_timer > 100:
		return "eat"
	return "swim"


## The sheet this fish draws this tick.
func draw_image() -> String:
	var def: Dictionary = SPECIES_DRAW.get(species, {"image": "", "row": -1})
	var fixed := String(def["image"])
	if fixed != "":
		return fixed
	var pair: Array = STATE_SHEETS[draw_state()]
	return String(pair[1] if uses_hungry_art() else pair[0])


## The draw row for a species at a given stage (`EV-0164`): the guppy rule is 0/1/2 as-is, 3 -> 2,
## 4 -> 3; a species whose draw fixes its row ignores the stage.
static func row_for(species_: int, stage_: int) -> int:
	var def: Dictionary = SPECIES_DRAW.get(species_, {"image": "", "row": -1})
	var fixed := int(def["row"])
	if fixed >= 0:
		return fixed
	if stage_ == 3:
		return 2
	if stage_ == 4:
		return 3
	return stage_


func sprite_row() -> int:
	return Fish.row_for(species, stage)


func _advance() -> void:
	_tick_effect_timers()
	_tick_hunger()
	if dead:
		return

	# Wadsworth's shelter is `FUN_004F6970`'s top branch and outranks food seeking (p2.3 §6, EV-0090):
	# a hidden Wadsworth exists, `+0x229` is set, and the fish is at stage 0/1.
	if is_sheltering():
		_steer_to_shelter(tank.wadsworth_mouth)
	else:
		var target := _find_food()
		var feeding := target != null and fullness < HUNGER_SEEK_LIMIT
		if feeding:
			# `can_seek` is the `+0x229` gate: it suppresses active steering only. Non-seekers still take
			# the eat window when a pellet drifts into range, because the shared update calls slot 84.
			if can_seek:
				_steer_to(target)
			_try_eat(target)
			if dead:
				return
		if not (feeding and can_seek):
			_swim()

	# Update tail order (FUN_004F6970): mode timers -> slot 81 coin scheduler -> dart/knockback ->
	# clamps -> integration. The coin scheduler only runs when the target/food lists are empty.
	_tick_mode_timers()
	if _food_in_tank() == 0:
		_tick_coin_drop()
	_tick_motion()


# --- hunger -----------------------------------------------------------------

func _tick_hunger() -> void:
	if not hunger_frozen:
		fullness = maxi(fullness - HUNGER_DECAY, HUNGER_FLOOR)
	if fullness > 0:
		_warned = [false, false, false]
	for i in HUNGER_HINTS.size():
		var line: int = HUNGER_HINTS[i]
		if fullness <= line and not _warned[i]:
			_warned[i] = true
			hunger_warning.emit(i + 1)
	if fullness < -499:
		die()


## Hungry-alt art (`FUN_004D6F30`, P2.3 §6): `[0x9C] < 301` and `[0x148] < 3` (stage 3 and up never
## show it). The original also requires `[0xA0] == 0` and `Tank+0x4FF` for the stage half - the tank
## flag is unbound, so it is treated as clear rather than guessed.
## `[0xA0]` (hit flash) is not modelled in the port yet, so that clause is omitted.
func uses_hungry_art() -> bool:
	return fullness < 301 and stage < 3


## Death entry (slot 88's shared body). Death leaves a corpse and **nothing else**: the corpse
## sinks and is removed silently, so a starved fish is gone (P2.4 §4, EV-0053). The live successor
## belongs to the corpse's revive branch, whose trigger is unrecovered (Q-0043).
func die() -> void:
	if dead:
		return
	_release_projectile_lock()
	died.emit(self)
	despawn()


## The projectile lock (`+0x98`, P2.10 §5.1). The spawner sets it; a cleared pointer is how the
## homing body (`FUN_004FF4E0`) knows the victim is gone (EV-0158).
func lock_projectile(shot) -> void:
	locked_projectile = shot


func unlock_projectile(shot) -> void:
	if locked_projectile == shot:
		locked_projectile = null


## `+0x8C` (the object type / prize kind, EV-0138). The homing body branches on `+0x8C == 6`
## (Ultravore) for its wider steering bands, so the projectile reads the type through this
## accessor rather than guessing from the species enum.
func obj_type() -> int:
	return int(SPECIES[species]["type_id"])


func _release_projectile_lock() -> void:
	if locked_projectile != null:
		var shot := locked_projectile
		locked_projectile = null
		if is_instance_valid(shot) and shot.has_method("release_target"):
			shot.release_target()


func _exit_tree() -> void:
	_release_projectile_lock()
	super()



func _tick_effect_timers() -> void:
	if grow_timer > 0:
		grow_timer -= 1
	if eat_fx_timer > 0:
		eat_fx_timer -= 1
	if digest_timer > 0:
		digest_timer -= 1


# --- food choice and approach ------------------------------------------------

func _food_in_tank() -> int:
	if tank != null and tank.has_method("food_count"):
		return tank.food_count()
	return 0


func _find_food() -> Food:
	if tank == null or not tank.has_method("nearest_food"):
		return null
	var pellet: Food = tank.nearest_food(position + Vector2(40.0, 40.0))
	if pellet == null or not _accepts(pellet):
		return null
	return pellet


## `FUN_004D5F20`: reject homing/inedible pellets; only variant 0 is normal food. A breeding pellet
## (variant 2) is accepted only pre-stage-3 and while fullness < 108, or in Virtual Tank.
func _accepts(pellet: Food) -> bool:
	if pellet.homing or not pellet.is_edible():
		return false
	if pellet.variant != Food.VARIANT_BREEDING:
		return pellet.variant == 0
	if virtual_tank:
		return true
	return stage < 3 and fullness < 108


## P2.2 §5.5 steering: dx against the pellet, dy against 20 px above it, ±5/±10 bands. The original
## tests the velocity limit *before* each step, so a step may overshoot it by one increment.
func _steer_to(pellet: Food) -> void:
	var dx := position.x - pellet.position.x
	if dx > APPROACH_FAR:
		if vx > -APPROACH_VX_LIMIT:
			vx -= APPROACH_VX_COARSE
	elif dx > APPROACH_NEAR:
		if vx > -APPROACH_VX_LIMIT:
			vx -= APPROACH_VX_FINE
	elif dx > 0.0:
		if vx > -APPROACH_VX_LIMIT:
			vx -= APPROACH_VX_HAIR
	elif dx >= -APPROACH_NEAR:
		if vx < APPROACH_VX_LIMIT:
			vx += APPROACH_VX_HAIR
	elif dx >= -APPROACH_FAR:
		if vx < APPROACH_VX_LIMIT:
			vx += APPROACH_VX_FINE
	else:
		if vx < APPROACH_VX_LIMIT:
			vx += APPROACH_VX_COARSE

	var dy := position.y - (pellet.position.y - 20.0)
	if dy > APPROACH_NEAR:
		if vy > APPROACH_VY_MIN:
			vy -= APPROACH_VY_COARSE
	elif dy > 0.0:
		if vy > APPROACH_VY_MIN:
			vy -= APPROACH_VY_FINE
	elif dy >= -APPROACH_NEAR:
		if vy < APPROACH_VY_MAX:
			vy += APPROACH_VY_UP
	else:
		if vy < APPROACH_VY_MAX:
			vy += APPROACH_VY_DOWN

	if int(position.y) <= int(min_y) and vy < 0.0:
		vy = 0.0
	if target_timer < 5:
		target_timer += 1


## `FUN_004F6970`'s shelter branch (p2.3 §6, EV-0090): `DAT_005e89d0 != 0 && fish+0x229 &&
## stage[0x1A0] <= 1`. The port's `can_seek` is that `+0x229` byte and `stage` is `+0x1A0`, so the
## condition is the recovered one; the mouth point comes from the tank's serialized globals.
func is_sheltering() -> bool:
	if tank == null or not can_seek or stage > 1:
		return false
	return int(tank.wadsworth_count) > 0


## The shelter follow's own accel ladder: +/-5 far, +/-3 near, +/-1 inside the hair band, against the
## mouth point rather than 20 px above a pellet.
func _steer_to_shelter(mouth: Vector2) -> void:
	var dx := position.x - mouth.x
	if dx > APPROACH_FAR:
		vx = maxf(vx - SHELTER_COARSE, -APPROACH_VX_LIMIT)
	elif dx > APPROACH_NEAR:
		vx = maxf(vx - SHELTER_FINE, -APPROACH_VX_LIMIT)
	elif dx > 0.0:
		vx = maxf(vx - SHELTER_HAIR, -APPROACH_VX_LIMIT)
	elif dx >= -APPROACH_NEAR:
		vx = minf(vx + SHELTER_HAIR, APPROACH_VX_LIMIT)
	elif dx >= -APPROACH_FAR:
		vx = minf(vx + SHELTER_FINE, APPROACH_VX_LIMIT)
	else:
		vx = minf(vx + SHELTER_COARSE, APPROACH_VX_LIMIT)

	var dy := position.y - mouth.y
	if dy > APPROACH_NEAR:
		vy = maxf(vy - SHELTER_FINE, APPROACH_VY_MIN)
	elif dy > 0.0:
		vy = maxf(vy - SHELTER_HAIR, APPROACH_VY_MIN)
	elif dy >= -APPROACH_NEAR:
		vy = minf(vy + SHELTER_HAIR, APPROACH_VY_MAX)
	else:
		vy = minf(vy + SHELTER_FINE, APPROACH_VY_MAX)

	if int(position.y) <= int(min_y) and vy < 0.0:
		vy = 0.0
	if target_timer < 5:
		target_timer += 1


## The mouth point: the cell centre offset by the measured mouth tip, flipped with the facing.
func mouth_point() -> Vector2:
	return position + Vector2(40.0 + facing * MOUTH_AHEAD, 40.0 + MOUTH_DROP)


## P2.3 §7.3: a ~35 px window consumes, ~50 px only opens the mouth (anticipation) - both from the
## mouth, so the pellet is taken at the face rather than at the belly (D-0024).
func _try_eat(pellet: Food) -> void:
	var mouth := mouth_point()
	var dx := absf(mouth.x - pellet.position.x)
	var dy := absf(mouth.y - pellet.position.y)
	if dx <= EAT_WINDOW and dy <= EAT_WINDOW:
		_consume(pellet)
	elif dx <= EAT_ANTICIPATION and dy <= EAT_ANTICIPATION:
		eat_fx_timer = maxi(eat_fx_timer, ANTICIPATION_TICKS)


# --- eating, nutrition and growth --------------------------------------------

func _consume(pellet: Food) -> void:
	# Breeding pellet: mode 5 caps fullness, otherwise a pre-stage-3 fish turns it into a new guppy.
	if pellet.variant == Food.VARIANT_BREEDING:
		if virtual_tank:
			fullness = mini(fullness + 30, 30)
		elif stage < 3:
			breed_requested.emit(species, position, facing)
		pellet.despawn()
		eat_fx_timer = maxi(eat_fx_timer, EAT_FX_TICKS)
		return

	var quality := pellet.quality
	if species == Species.GUPPY:
		if quality == 3:
			_star_potion()
			pellet.despawn()
			return
		var amount := 0
		var cap := 0
		var points := 0
		if quality == 0:
			amount = 500
			cap = 800
			points = 1
		elif quality == 1:
			amount = 700
			cap = 1000
			points = 1 if virtual_tank else 2
		elif virtual_tank:
			amount = 500
			cap = 800
			points = 2
		else:
			amount = 1100
			cap = 1400
			points = 3
		fullness = mini(fullness + amount, cap)
		food_points += points
		_apply_growth()
	else:
		# The carnivore/ultravore bodies add +900 (cap 1300); Gekko/Sylvester/Ball/Bi add +700
		# (cap 1000). The point award is the shared quality table.
		var def: Dictionary = SPECIES[species]
		fullness = mini(fullness + int(def["eat_amount"]), int(def["eat_cap"]))
		if quality == 0:
			food_points += 1
		elif quality == 1:
			food_points += 1 if virtual_tank else 2
		elif quality == 3:
			pass
		else:
			food_points += 2 if virtual_tank else 3
		_apply_growth()

	pellet.despawn()
	eat_fx_timer = maxi(eat_fx_timer, EAT_FX_TICKS)


func _star_potion() -> void:
	if stage <= 1:
		die()
		return
	fullness = mini(fullness + STAR_FEED, STAR_CAP)
	if stage == 2:
		stage = 3
		grew.emit(self, stage)


## P2.3 §7.5's shared tail: `stage < 2` grows one step; a huge overshoot at stage > 1 turns the
## fish into the "diminutive" stage 4. The overshoot check is a second `if`, not an `else`.
func _apply_growth() -> void:
	if food_points < food_needed:
		return
	if stage < 2:
		stage += 1
		food_points = 0
		grow_timer = GROW_POP_TICKS
		if species == Species.MINISYLVESTER and stage == 2:
			_apply_sylvester_size(2)
		grew.emit(self, stage)
	var overshoot := (VIRTUAL_OVERSHOOT_MULT if virtual_tank else GUPPY_OVERSHOOT_MULT) * food_needed
	if overshoot <= food_points and stage > 1 and stage != 4 and alt_flag == 0:
		stage = 4
		grew.emit(self, stage)


## Port-only debug growth (D-0014): one natural step, with the same `grew` signal and Sylvester
## resize as eating would produce. Stage > 1 takes the natural overshoot form (4), and a fish
## already at 4 - or a species whose `stage` is a sprite row (5/6/7) - refuses.
func debug_grow() -> bool:
	if dead or stage >= 4:
		return false
	if stage < 2:
		stage += 1
	else:
		stage = 4
	food_points = 0
	grow_timer = GROW_POP_TICKS
	fullness = maxi(fullness, 500)
	if species == Species.MINISYLVESTER and stage == 2:
		_apply_sylvester_size(2)
	grew.emit(self, stage)
	return true


## Port-only debug feeding (D-0014): fill the fish to its species' own eat cap.
func debug_feed() -> bool:
	if dead:
		return false
	var cap := int(SPECIES[species]["eat_cap"])
	if fullness >= cap:
		return false
	fullness = cap
	return true


## `FUN_004D9D50(2)`: Sylvester's stage-1 -> stage-2 form is 160x160 with a widened tank band and
## the position shifted back by the 40 px the box grew on each side.
func _apply_sylvester_size(new_stage: int) -> void:
	if new_stage == 2:
		sprite_box = 160
		position -= Vector2(40.0, 40.0)
		min_x = 0.0
		min_y = 75.0
		max_x = 480.0
		max_y = 310.0
	else:
		sprite_box = 80
		position += Vector2(40.0, 40.0)
		min_x = 10.0
		min_y = 105.0
		max_x = 540.0
		max_y = 360.0


# --- swim machine ------------------------------------------------------------

func _swim() -> void:
	match swim_mode:
		0x7B:
			_swim_drift()
		0:
			_swim_mode0()
		1:
			_swim_dash(1)
		2:
			_swim_dash(-1)
		3:
			_swim_cruise(-1)
		4:
			_swim_cruise(1)
		_:
			_swim_hover()


## Mode 0: level out at vy +0.5, glide 0.25/tick, and every 40 ticks pull vx toward 0 by 0.5.
func _swim_mode0() -> void:
	if dart_timer == 0:
		vy = MODE0_VY
	if mode_timer >= MODE_TIMER_START:
		mode_timer = 0
		if vx < -0.5:
			vx += 0.5
		elif vx > 0.5:
			vx -= 0.5
		target_timer = _roll_target_timer()
	position.y -= GLIDE_SLOW / speed_divisor


## Modes 1/2: -8 dash on entry, glide 0.5/tick, and every 40 ticks step vx toward +1/-1.
func _swim_dash(direction: int) -> void:
	if dart_timer == 0:
		vy = DART_VY
	if mode_timer > MODE_TIMER_START - 1:
		mode_timer = 0
		var target := float(direction)
		if vx < target:
			vx += 1.0
		elif vx > target:
			vx -= 1.0
		target_timer = _roll_target_timer()
	position.y -= GLIDE_FAST / speed_divisor


## Modes 3/4: every 40 ticks step vx toward ∓1 and vy toward +3; above y 240 fall back to mode 0.
func _swim_cruise(direction: int) -> void:
	if mode_timer > MODE_TIMER_START - 1:
		mode_timer = 0
		var target_x := float(direction)
		if vx < target_x:
			vx += 1.0
		elif vx > target_x:
			vx -= 1.0
		if vy < MODE3_TARGET_VY:
			vy += 1.0
		else:
			vy -= 1.0
		if target_timer < 5:
			if vy < 4.0:
				target_timer += 1
		else:
			target_timer -= 1
	if position.y > 240.0:
		swim_mode = 0
	position.y -= GLIDE_FAST / speed_divisor


## Mode 0x7B: drag after 30 ticks, reroll after 50, bounce at the 20 px margins or rand%3.
func _swim_drift() -> void:
	if mode_timer > DRIFT_DRAG_TICKS:
		if absf(vx) > 2.0:
			vx *= DRIFT_DRAG
		if absf(vy) > 2.0:
			vy *= DRIFT_DRAG
	if mode_timer > DRIFT_REROLL_TICKS:
		mode_timer = 0
		swim_mode = rng_type_id_range()
		if (
			position.x > max_x - DRIFT_MARGIN
			or position.x < min_x + DRIFT_MARGIN
			or _roll(3) == 0
		):
			vx = -vx


## Modes >= 5 (the decompiler's `else`): slow rise, then a horizontal zigzag between x 175/250.
func _swim_hover() -> void:
	if dart_timer == 0:
		vy = HOVER_VY_HIGH if position.y >= HOVER_SLOW_Y else HOVER_VY_LOW
	if mode_timer > MODE_TIMER_START - 1:
		mode_timer = 0
		if turn_dir == 1:
			vx += 2.0 if vx < 0.0 else 1.0
			if position.x > HOVER_RIGHT:
				turn_dir = -1
				vx -= 2.0
		elif turn_dir == -1:
			vx -= 2.0 if vx > 0.0 else 1.0
			if position.x < HOVER_LEFT:
				turn_dir = 1
				vx += 2.0
		target_timer = _roll_target_timer()


func _tick_mode_timers() -> void:
	mode_timer += 1
	random_timer += 1
	if random_timer > RANDOM_SWITCH_TICKS:
		random_timer = 0
		if _roll(RANDOM_SWITCH_CHANCE) == 0:
			swim_mode = rng_type_id_range()


## The original's `rand%9 + 1` re-roll. Uses the tank stream through the `rng` helper below.
func rng_type_id_range() -> int:
	return _roll(9) + 1


func _roll(limit: int) -> int:
	if tank != null and tank.has_method("randi_below"):
		return tank.randi_below(limit)
	# Spawned outside a tank (editor preview): deterministic, never the global stream.
	return 0


func _roll_target_timer() -> int:
	return _roll(6)


# --- motion tail -------------------------------------------------------------

func _tick_motion() -> void:
	if dart_timer > 0:
		dart_timer -= 1
		vy *= 0.9
	if knockback_timer > 0:
		var displacement := knockback_offset
		knockback_timer -= 1
		knockback_offset = displacement * 0.9
		position.x += displacement * 0.9
	if misc_timer > 0:
		misc_timer -= 1

	# Exact-equality sink ladder: vx 0/1/2/3 adds 1.0/0.75/0.5/0.25 y drift.
	for key: float in SINK_LADDER:
		if vx == key:
			position.y += float(SINK_LADDER[key]) / speed_divisor
			break

	if max_y < SMALL_TANK_MAX_Y:
		position.y -= DRIFT_UP

	position.x = clampf(position.x, min_x, max_x)
	position.y = minf(position.y, max_y)
	if dart_timer < 1 or vy <= 0.0:
		position.y = maxf(position.y, min_y)
	# Else: darting down at dart_timer >= 31 spawns burst FX in the original (particles, P4.4).

	if position.x > max_x - 5.0 and vx > 0.1:
		vx -= WALL_DAMP
	if position.x < WALL_LEFT and vx < -0.1:
		vx += WALL_DAMP

	if vx < -0.05:
		facing = -1
		flip = true
	elif vx > 0.05:
		facing = 1
		flip = false

	var divisor := speed_divisor
	if slow_override:
		divisor = 0.3 if slow_selector == 0 else 0.8
	position.x += vx / divisor
	position.y += vy / divisor


# --- coin scheduler ----------------------------------------------------------

## Slot 81. Stage 0 fish never drop. Normal mode is `counter >= threshold`; the Virtual Tank branch
## reproduces `FUN_004D7100`'s difficulty adjustment and starving rewind.
func _tick_coin_drop() -> void:
	if stage < 1:
		return
	coin_counter += 1
	var threshold := coin_threshold
	if virtual_tank:
		if threshold > COIN_MIN_THRESHOLD:
			threshold += _coin_difficulty() * COIN_DIFFICULTY_STEP
			threshold = maxi(threshold, COIN_MIN_THRESHOLD)
		if _pacing_gate():
			if fullness < 0:
				if threshold < coin_counter:
					coin_counter = threshold - COIN_HUNGRY_REWIND
				return
			if threshold > coin_counter:
				return
		else:
			if threshold < coin_counter:
				coin_counter = 0
			return
	elif threshold > coin_counter:
		return

	coin_counter = 0
	coin_drops += 1
	coin_due.emit(self)


func _coin_difficulty() -> int:
	if tank != null and tank.has_method("coin_difficulty"):
		return tank.coin_difficulty()
	return 0


func _pacing_gate() -> bool:
	if tank != null and tank.has_method("coin_pacing_gate"):
		return tank.coin_pacing_gate()
	return false
