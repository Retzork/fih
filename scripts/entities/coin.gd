class_name Coin
extends SimEntity
## Coin (factory ids 0x19/0x1A/0x1B; play ctor `FUN_004EEAD0`, update `FUN_004F5050`; P2.5 §5).
## The nine denominations share one class in the original too - only `kind` (+0x194) and the `Value()`
## table differ - so the sprite variants are a kind field, not a subclass.
##
## Field map (the note's offsets): `kind` +0x194, frame timer +0x16C (wraps at 79), age +0x170,
## animation frame +0x174, fade +0x178 (set to 5 by `FUN_004D5390`), `+0x1C0` the Virtual Tank value
## base read by `FUN_004D53A0`.
##
## Phase: coins ride `Sim.Phase.COLLISION`. The original advances coins from the tank's coin list with
## one update that also does the contact test against collectors (P2.5 §5), so the contact phase is the
## only existing slot whose position matches; giving coins their own phase would reorder the fixed
## update order ARCHITECTURE §1 makes load-bearing.
##
## Ownership: the coin knows its value and when it is gone; it does **not** add money. Collection and
## expiry emit `collected`/`expired`/`banked` and the level (P4.7, `Tank::AddMoney`) credits the right
## pool - normal money, level total, Virtual Tank shells.
##
## Q-0040 (open, four coin internals unflagged in the decompile):
##   1. the animation-frame function `f(+0x16C, kind, virtual)` - implemented as `timer / 10 % 8`,
##      i.e. 10 ticks per frame, because the timer wraps at 79 and the shipped coin sheets have 8 cells;
##   2. the `+0x1C0` base of the Virtual Tank value - defaulted to the normal value so a Virtual Tank
##      coin is not worth zero, which is a placeholder, not a recovered figure;
##   3. the kind 0x10 branch (targets y 50 or -50 by `+0x68`, "remove unless rising") - not implemented,
##      so kind 0x10 behaves like an ordinary coin worth 0;
##   4. the HUD flight destination (`FUN_00538CD0`) after Virtual Tank homing - the bank is emitted when
##      the coin reaches (550, 30) instead of inventing the follow-up path;
##   plus the landing/bob pair: the note lands coins at y 370 and applies Food's staged 120..150 rise
##   table, which makes a landed coin climb ~30 ticks before it oscillates in the band. Both facts are
##   implemented as written; that they belong together is unverified.

## `FUN_004D53A0`: kind -> normal value. Pairs {n, n+7} share a value (two sprite variants each).
const VALUES := {
	0x01: 15, 0x08: 15, 0x12: 15,
	0x02: 35, 0x09: 35,
	0x03: 40, 0x0A: 40,
	0x04: 200, 0x0B: 200, 0x05: 200, 0x0C: 200,
	0x06: 500, 0x0D: 500,
	0x07: 2000, 0x0E: 2000,
	0x11: 150,
	0x0F: 250,
	0x10: 0,
}
## Virtual Tank multipliers, same order as the wiki denominations (silver/gold/star/shells/...).
const VIRTUAL_MULTIPLIER := {
	0x01: 1, 0x08: 1, 0x12: 1,
	0x02: 2, 0x09: 2,
	0x03: 3, 0x0A: 3,
	0x04: 5, 0x0B: 5, 0x05: 5, 0x0C: 5,
	0x06: 10, 0x0D: 10,
	0x07: 20, 0x0E: 20,
	0x11: 5,
	0x0F: 10,
}

## Fall per tick and the landing line (both double constants in `Coin::Update`).
const FALL_SPEED := 1.5
const LAND_Y := 370.0
## The landed bob: the same staged rise table Food uses (P2.3 §1 step 5).
const BOB_BANDS := [
	[150.0, 8.0],
	[135.0, 2.5],
	[130.0, 1.5],
	[125.0, 1.0],
	[120.0, 0.5],
]
## Frame timer wraps at 79; the fade-out runs 5 ticks before removal.
const FRAME_WRAP := 79
const FRAME_TICKS := 10
const FADE_TICKS := 5
## Expiry after landing: hinted tanks hold coins longer, demo/tank-flag modes differ (P2.5 §5).
const EXPIRY_DEFAULT := 20
const EXPIRY_HINTED := 150
const EXPIRY_DEMO := 108
const EXPIRY_TANK_FLAG := 200
## Niko's Pearl lingers 217 ticks; kind 0x10 is the unidentified special path (Q-0040).
const KIND_NIKO_PEARL := 0x0F
const NIKO_PEARL_EXPIRY := 217
const KIND_SPECIAL := 0x10
## Virtual Tank: home to the top-right corner, then hand over to the HUD.
const HOMING_TARGET := Vector2(550.0, 30.0)
const HOMING_DIVISOR := 7.0
const BANK_DISTANCE := 40.0
## Collection: coin centre is (x+36, y+36) against a 60x60 collector box (P2.5 §5).
const COLLECT_CENTER := Vector2(36.0, 36.0)
const COLLECT_BOX := 60.0

## Emitted when something collects the coin. `amount` is already in the level's currency.
signal collected(coin, amount: int)
## Emitted when the expiry threshold ran out and the fade finished.
signal expired(coin)
## Emitted when a Virtual Tank coin reaches the HUD hand-off point.
signal banked(coin)

var kind := 0x01
## `+0x198`: a collector reserved the coin (P2.7 §4.1 excludes already-claimed coins).
var claimed := false
## `+0x1C0`: the Virtual Tank value base. Defaults to `value()` (placeholder, Q-0040 item 2).
var virtual_base := 0
var landed := false
## Bob direction: rising through the staged band table, or falling back to its bottom.
var rising := false
var gate := false
var frame_timer := 0
var age := 0
var anim_frame := 0
var fade := 0
## Ticks left before the fade starts; 0 means "not landed yet" and is set on landing.
var expiry_ticks := 0


## Build a coin. No ctor randomness is recovered, so the kind is the only input.
static func create(kind_: int, pos: Vector2, virtual_base_: int = -1) -> Coin:
	var coin := Coin.new()
	coin.kind = kind_
	coin.position = pos
	coin.virtual_base = coin.value() if virtual_base_ < 0 else virtual_base_
	return coin


## `FUN_004D53A0` normal value; an unknown kind is 0, exactly as the recovered table's default.
func value() -> int:
	return int(VALUES.get(kind, 0))


## `FUN_004D5360`: 1 when the manager is in mode 5 or `Tank+0x2A5` is set - i.e. Virtual Tank.
func virtual_mode() -> bool:
	return tank != null and bool(tank.virtual_tank)


## What the coin is worth in the current mode. Virtual Tank multiplies `+0x1C0` (the note's formula).
func amount() -> int:
	if virtual_mode():
		return virtual_base * int(VIRTUAL_MULTIPLIER.get(kind, 0))
	return value()


## The coin's own pickup square, centred on (x+36, y+36).
func collect_box() -> Rect2:
	var centre := position + COLLECT_CENTER
	return Rect2(centre - Vector2(COLLECT_BOX * 0.5, COLLECT_BOX * 0.5), Vector2(COLLECT_BOX, COLLECT_BOX))


## Whether a collector centred at `collector_centre` overlaps this coin (the tank hands over the
## candidates; per-list dispatch and its ordering stay with the collectors, EV-0055 / Q-0010).
func can_collect(collector_centre: Vector2) -> bool:
	if dead:
		return false
	return absf(collector_centre.x - (position.x + COLLECT_CENTER.x)) <= COLLECT_BOX * 0.5 \
		and absf(collector_centre.y - (position.y + COLLECT_CENTER.y)) <= COLLECT_BOX * 0.5


## Take the coin. Safe to call twice; the amount is reported, never credited here.
func collect() -> void:
	if dead:
		return
	var amount_value := amount()
	collected.emit(self, amount_value)
	despawn()


func expire() -> void:
	if dead:
		return
	expired.emit(self)
	despawn()


func _advance() -> void:
	if fade > 0:
		fade -= 1
		if fade == 0:
			expire()
		return

	_tick_animation()

	if virtual_mode():
		_virtual_step()
		return

	if not landed:
		position.y += FALL_SPEED
		if position.y >= LAND_Y:
			position.y = LAND_Y
			_land()
		return

	_bob()
	if expiry_ticks > 0:
		expiry_ticks -= 1
		if expiry_ticks == 0:
			fade = FADE_TICKS


## Frame timer wraps at 79; the frame is `timer / 10` (Q-0040 item 1).
func _tick_animation() -> void:
	frame_timer = (frame_timer + 1) % FRAME_WRAP
	age += 1
	anim_frame = int(frame_timer / FRAME_TICKS) % 8


func _land() -> void:
	landed = true
	gate = false
	rising = true
	expiry_ticks = _landing_expiry()


## Expiry after landing. Hinted tanks hold coins, demo and `Tank+0x16C` modes override the base.
func _landing_expiry() -> int:
	if kind == KIND_NIKO_PEARL:
		return NIKO_PEARL_EXPIRY
	var base := EXPIRY_DEFAULT
	if _hint_active():
		base = EXPIRY_HINTED
	if _demo_mode():
		base = EXPIRY_DEMO
	elif _tank_flag():
		base = EXPIRY_TANK_FLAG
	return base


func _hint_active() -> bool:
	return tank != null and bool(tank.coin_hint_active)


func _demo_mode() -> bool:
	return tank != null and bool(tank.demo_mode)


func _tank_flag() -> bool:
	return tank != null and bool(tank.tank_flag_16c)


## Rise through the staged bands, then fall back: the coin oscillates between the table's bottom
## (120) and its top band (150).
func _bob() -> void:
	if rising:
		for band: Array in BOB_BANDS:
			if position.y >= float(band[0]):
				position.y -= float(band[1])
				return
		rising = false
		gate = true
	else:
		position.y += FALL_SPEED
		if position.y >= float(BOB_BANDS[0][0]):
			rising = true
			gate = false


## Virtual Tank: homing into the top-right corner, then the (unrecovered) HUD hand-off.
func _virtual_step() -> void:
	position.x += (HOMING_TARGET.x - position.x) / HOMING_DIVISOR
	position.y += (HOMING_TARGET.y - position.y) / HOMING_DIVISOR
	if position.distance_to(HOMING_TARGET) <= BANK_DISTANCE:
		banked.emit(self)
		despawn()
