class_name Pet
extends SimEntity
## Pet base (P2.7). One entity with a `PetDef` table and per-index behaviour, because the original has
## two update bodies (`Fun_004F2E80` OtherTypePet, `FUN_004F7AD0` FishTypePet) plus one slot-81
## dispatcher `FUN_004E5900` that switches on the pet index - not 24 classes.
##
## Gate order (P2.7 §3.1, SPECS §3.4): base tick -> pause gate -> tank-5 action skip -> alien gate
## (slot 81 skipped while hostile aliens are present, except Stanley) -> slot 81 action ->
## steering/targeting -> contact. The pause gate is `SimEntity`'s; the rest is here.
##
## Implemented: the roster table, Stinky's bottom-lane coin chase with his hide counter, Niko's pearl
## cycle (1224/1233/1440/1450 ticks, reset to `rand % 50`), Angie's corpse handoff (target
## `+0x1A0 > 0x5F`, contact 30/60 px, phase 100 -> 10), and the two plain timer droppers Vert (216
## ticks, coin kind 2), Shrapnel (633..652 ticks, coin kind 0x11) and Nostradamus (300..599 ticks,
## the snot coin 0x12). The other 18 pets are represented
## in `DEFS` but their slot-81 bodies are not written yet (Q-0044), so they idle.
##
## Q-0044 (open): the note pins Stinky's speed (1.2) and fixed y (370) and Niko's four tick marks, but
## not the other pets' speeds, their fixed-y lanes, or most action periods (only the periods listed in
## P2.7 §7.6 are recovered). Those cells stay 0 in `DEFS` rather than being filled in with guesses.

enum Family { OTHER, FISH }

## Roster indexes (P2.7 §1). 999 is a card only and is deliberately absent.
const STINKY := 0x00
const NIKO := 0x01
const VERT := 0x06
const SHRAPNEL := 0x0B
const NOSTRADAMUS := 0x15
const ANGIE := 0x12
const STANLEY := 0x16
const PET_COUNT := 24

## Angie's revive handoff (P2.7 §4.19, EV-0099): she only looks at corpses whose own counter is still
## high enough (`+0x1A0 > 0x5F`), and on contact writes `FUN_004D5630`'s 100 -> 10 into the corpse's
## phase. The 60 px range is the id-6 (Ultravore) size, 30 px otherwise. Her own steering speed lives
## in the FishTypePet defaults and is not recovered (Q-0044), so she revives what comes to her.
const ANGIE_TARGET_STAGE := 0x5F
const ANGIE_CONTACT := 30.0
const ANGIE_CONTACT_BIG := 60.0

## Vert (P2.7 §4.7, EV-0087): a plain `+0x224` timer. At 216 it asks `FUN_004D70B0` (1 in normal play)
## and drops coin kind 2 at `(x+15, y+10)`; the counter then restarts. The Virtual Tank branch needs the
## avatar-screen state the port does not model yet, so the gate is normal play here.
const VERT_PERIOD := 216
const VERT_DROP := 0x02
const VERT_OFFSET := Vector2(15.0, 10.0)

## Shrapnel (P2.7 §4.12, EV-0092): `+0x224` is rolled once to 633..652 in the ctor, then drops coin kind
## 0x11 (worth 150) at `(x+15, y+10)`. The `+0x258` white-flash countdown before the drop has no
## recovered tick length, so it is left out (Q-0044); the 0x143 sound has no `SOUND_*` name (Q-0030).
const SHRAPNEL_MIN := 633
const SHRAPNEL_MAX := 652
const SHRAPNEL_DROP := 0x11
const SHRAPNEL_OFFSET := Vector2(15.0, 10.0)

## Nostradamus (P2.7 §4.22, EV-0102): `+0x224` is `rand % 300 + 300` in the ctor, then `FUN_005434E0`
## spawns snot (coin kind 0x12) at `(x+15, y+10)`. The "Sneeze of Power" and the clone behaviour were
## not recovered, so only the snot timer is here.
const NOSTRADAMUS_MIN := 300
const NOSTRADAMUS_SPAN := 300
const SNOT_DROP := 0x12
const SNOT_OFFSET := Vector2(15.0, 10.0)

## Niko's cycle: `+0x1B4` counts up; sound, pearl, close-sound, reset (P2.7 §4.2).
const NIKO_OPEN_SOUND := 1224
const NIKO_PEARL := 1233
const NIKO_CLOSE_SOUND := 1440
const NIKO_CLOSE := 1450
const NIKO_RESET_MAX := 0x32
const PEARL_KIND := 0x0F
const PEARL_OFFSET := Vector2(1.0, -2.0)

## Stinky: fixed bottom lane, speed 1.2, hide counter max 9 (`+0x1B4`).
const STINKY_SPEED := 1.2
const STINKY_Y := 370.0
const STINKY_HIDE_MAX := 9
## Coin exclusions (P2.7 §4.1): bombs, snot, the Star/Penta pair while the Penta list is non-empty.
const COIN_BOMB := 0x11
const COIN_SNOT := 0x12
const COIN_STAR := 0x03
const COIN_STAR_ALT := 0x0A

## Index -> definition. `speed` 0 and `period` 0 mean "not recovered" (Q-0044), never a value to use.
const DEFS := {
	0x00: {"name": "Stinky the Snail", "family": Family.OTHER, "speed": 1.2, "fixed_y": 370.0, "period": 0},
	0x01: {"name": "Niko the Oyster", "family": Family.OTHER, "speed": 0.0, "fixed_y": -1.0, "period": 1233},
	0x02: {"name": "Itchy the Swordfish", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x03: {"name": "Prego the Momma Fish", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 930},
	0x04: {"name": "Zorf the Sea Horse", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 65},
	0x05: {"name": "Clyde the Jellyfish", "family": Family.OTHER, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x06: {"name": "Vert the Skeleton", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 216},
	0x07: {"name": "Rufus the Fiddler Crab", "family": Family.OTHER, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x08: {"name": "Meryl the Mermaid", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 1400},
	0x09: {"name": "Wadsworth the Whale", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x0A: {"name": "Seymour the Turtle", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x0B: {"name": "Shrapnel the Robot Fish", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 633},
	0x0C: {"name": "Gumbo the Angler", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x0D: {"name": "Blip the Porpoise", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x0E: {"name": "Rhubarb the Hermit Crab", "family": Family.OTHER, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x0F: {"name": "Nimbus the Manta Ray", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x10: {"name": "Amp the Electric Eel", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 3000},
	0x11: {"name": "Gash the Shark", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 1570},
	0x12: {"name": "Angie the Angelfish", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x13: {"name": "Presto the Tadpole", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x14: {"name": "Brinkley the Scuba Elephant", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
	0x15: {"name": "Nostradamus the Nose", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 300},
	0x16: {"name": "Stanley the Sea Serpent", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 100},
	0x17: {"name": "Walter the Penguin", "family": Family.FISH, "speed": 0.0, "fixed_y": -1.0, "period": 0},
}

## Index -> `Content` image id, one 80x80 sheet per pet (P2.15: the resource's own grid, playback mode
## and frame delay drive the sprite; the tank draws the animated sheet, not a frame the entity picks).
const IMAGES := {
	0x00: "IMAGE_STINKY", 0x01: "IMAGE_NIKO", 0x02: "IMAGE_ITCHY", 0x03: "IMAGE_PREGO",
	0x04: "IMAGE_ZORF", 0x05: "IMAGE_CLYDE", 0x06: "IMAGE_VERT", 0x07: "IMAGE_RUFUS",
	0x08: "IMAGE_MERYL", 0x09: "IMAGE_WADSWORTH", 0x0A: "IMAGE_SEYMOUR", 0x0B: "IMAGE_SHRAPNEL",
	0x0C: "IMAGE_GUMBO", 0x0D: "IMAGE_BLIP", 0x0E: "IMAGE_RHUBARB", 0x0F: "IMAGE_NIMBUS",
	0x10: "IMAGE_AMP", 0x11: "IMAGE_GASH", 0x12: "IMAGE_ANGIE", 0x13: "IMAGE_PRESTO",
	0x14: "IMAGE_BRINKLEY", 0x15: "IMAGE_NOSTRADAMUS", 0x16: "IMAGE_STANLEY", 0x17: "IMAGE_WALTER",
}

## Sound/sparkle cues for the audio layer (P4.13); no stream ids are wired yet.
signal cue(name: String, at: Vector2)

var index := STINKY
var vx := 0.0
var vy := 0.0
var speed := 0.0
## Slot-81 counter (`+0x1B4`): only advances while the action gate is open.
var action_timer := 0
## Stinky's `+0x1B4` hide counter (0..9), driven by the coin-list state.
var hide_counter := 0
## Niko's `+0x1C0`: the pearl was taken, so the open-animation is skipped.
var pearl_taken := false
## Shrapnel's ctor roll (`+0x224`, 633..652); unused by the other pets.
var drop_period := SHRAPNEL_MIN


static func create(index_: int, pos: Vector2) -> Pet:
	var pet := Pet.new()
	if not DEFS.has(index_):
		push_error("Pet.create: unknown pet index %d" % index_)
		index_ = STINKY
	pet.index = index_
	pet.position = pos
	var def: Dictionary = DEFS[index_]
	pet.speed = float(def["speed"])
	if index_ == SHRAPNEL:
		pet.drop_period = randi_range(SHRAPNEL_MIN, SHRAPNEL_MAX)
	elif index_ == NOSTRADAMUS:
		pet.drop_period = randi_range(NOSTRADAMUS_MIN, NOSTRADAMUS_MIN + NOSTRADAMUS_SPAN - 1)
	if float(def["fixed_y"]) >= 0.0:
		pet.position.y = float(def["fixed_y"])
	return pet


## The pet's body sheet (80x80 cells, `Content`'s own animation metadata).
func image_id() -> String:
	return String(IMAGES.get(index, ""))


func display_name() -> String:
	return String(DEFS[index]["name"])


func family() -> int:
	return int(DEFS[index]["family"])


func is_fish_type() -> bool:
	return family() == Family.FISH


## The slot-81 gate: tank 5 skips it, and hostile aliens skip it for everyone but Stanley.
func action_gate_open() -> bool:
	if tank == null:
		return false
	if int(tank.tank_index) == 5:
		return false
	if bool(tank.aliens_present) and index != STANLEY:
		return false
	return true


func _advance() -> void:
	if action_gate_open():
		action_timer += 1
		_slot81()
	_steer()
	_contact()


## `FUN_004E5900` branches. Only the three recovered bodies are here; the rest idle (Q-0044).
func _slot81() -> void:
	match index:
		STINKY:
			_stinky_hide()
		NIKO:
			_niko_cycle()
		VERT:
			_vert_drop()
		SHRAPNEL:
			_shrapnel_drop()
		NOSTRADAMUS:
			_snot_drop()
		ANGIE:
			_angie_revive()


## Stinky's hide counter: up to 9 while the coin sources are populated, back to 0 when they clear.
func _stinky_hide() -> void:
	var busy := tank != null and bool(tank.pet_sources_busy) and not _coins_empty()
	if busy:
		hide_counter = mini(hide_counter + 1, STINKY_HIDE_MAX)
	else:
		hide_counter = maxi(hide_counter - 1, 0)


func _coins_empty() -> bool:
	return tank == null or tank.coin_count() == 0


func is_hidden() -> bool:
	return hide_counter >= STINKY_HIDE_MAX


## Niko (`+0x1B4`): sound at 1224, pearl at 1233, close sound at 1440, reset to `rand % 50` at 1450.
func _niko_cycle() -> void:
	match action_timer:
		NIKO_OPEN_SOUND:
			cue.emit("niko_open", position)
		NIKO_PEARL:
			if not pearl_taken:
				tank.spawn_coin(PEARL_KIND, position + PEARL_OFFSET)
				pearl_taken = true
				cue.emit("pearl", position + PEARL_OFFSET)
		NIKO_CLOSE_SOUND:
			cue.emit("niko_close", position)
		NIKO_CLOSE:
			pearl_taken = false
			action_timer = tank.randi_below(NIKO_RESET_MAX)


## Vert's 216-tick drop: the gate is normal play's always-true `FUN_004D70B0` answer.
func _vert_drop() -> void:
	if action_timer < VERT_PERIOD:
		return
	action_timer = 0
	tank.spawn_coin(VERT_DROP, position + VERT_OFFSET)
	cue.emit("drop", position + VERT_OFFSET)


## Shrapnel's rolled 633..652-tick drop, the bomb coin (P2.7 §4.12).
func _shrapnel_drop() -> void:
	if action_timer < drop_period:
		return
	action_timer = 0
	tank.spawn_coin(SHRAPNEL_DROP, position + SHRAPNEL_OFFSET)
	cue.emit("drop", position + SHRAPNEL_OFFSET)


## Nostradamus' rolled 300..599-tick snot drop (P2.7 §4.22).
func _snot_drop() -> void:
	if action_timer < drop_period:
		return
	action_timer = 0
	tank.spawn_coin(SNOT_DROP, position + SNOT_OFFSET)
	cue.emit("snot", position + SNOT_OFFSET)


## Angie's contact handoff: the first corpse still inside its death window gets its phase rewritten to
## 10, which starts the revive countdown in `DeadFish` (P2.4 §4, EV-0053).
func _angie_revive() -> void:
	if tank == null:
		return
	for corpse: DeadFish in tank.corpses():
		if corpse.stage <= ANGIE_TARGET_STAGE or corpse.phase_counter != DeadFish.PHASE_START:
			continue
		var range := ANGIE_CONTACT_BIG if corpse.corpse_id == 6 else ANGIE_CONTACT
		if corpse.position.distance_to(position) > range:
			continue
		corpse.phase_counter = DeadFish.REVIVE_PHASE
		cue.emit("revive", corpse.position)
		return


## Stinky chases the nearest acceptable coin along his lane; other pets do not steer yet.
func _steer() -> void:
	if index != STINKY or speed <= 0.0:
		return
	var target := _nearest_coin()
	if target == null:
		return
	var dx := target.position.x - position.x
	if absf(dx) > 2.0:
		vx = signf(dx) * speed
		position.x += vx
		position.y = STINKY_Y


func _contact() -> void:
	if index != STINKY or is_hidden():
		return
	for coin: Coin in tank.coins():
		if not accepts_coin(coin):
			continue
		if coin.can_collect(position + Vector2(36.0, 36.0)):
			coin.collect()
			return


## The per-pet coin predicate (P2.7 §7.5): exclusions are per pet, not a shared "collectible" flag.
func accepts_coin(coin: Coin) -> bool:
	if coin == null or coin.dead or coin.claimed:
		return false
	if coin.kind == COIN_BOMB or coin.kind == COIN_SNOT:
		return false
	if coin.kind == PEARL_KIND:
		return false  # Niko's pearl is clickable, never money-pet food
	if coin.kind == COIN_STAR or coin.kind == COIN_STAR_ALT:
		if tank != null and bool(tank.penta_present):
			return false
	return true


func _nearest_coin() -> Coin:
	var best: Coin = null
	var best_distance := INF
	for coin: Coin in tank.coins():
		if not accepts_coin(coin):
			continue
		var distance := absf(coin.position.x - position.x)
		if distance < best_distance:
			best_distance = distance
			best = coin
	return best
