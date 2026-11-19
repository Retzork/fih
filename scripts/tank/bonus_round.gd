class_name BonusRound
extends RefCounted
## P2.6 §6 - the tank-complete bonus round (EV-0068/EV-0069/EV-0072).
##
## The original's two-stage transition lives in the tank update `FUN_00547610`: `FUN_00537E20` has
## already set the tank-complete latch `Tank+0x2A5` and the duration `Tank+0x3BC`, and once
## `Tank+0x444 - Tank+0x2A8 > 0x9F` (160 frames) `FUN_00537F40` starts the round by setting
## `Tank+0x2A4 = 1`, resetting `+0x3B4/+0x3B8`, zeroing the elapsed clock `+0x3B0` and moving the
## anchor `+0x2A8` to the current frame. The round then ends when
## `Tank+0x3BC - (now - +0x3B8)/1000 < 0`, the coin list `Tank+0xA8` is empty and the pre-increment
## `Tank+0x3F8 > 100`; the tank advances and `FUN_0054BF60` opens the BonusScreen.
##
## The round has no spawner of its own in the recovered evidence. `Tank+0x2A5` is exactly the latch
## that routes collected shells into `Tank+0x3F4` instead of the wallet (`FUN_0053C1E0`, EV-0072), so
## the tank's own fish keep dropping coins and the player clicks them: `shells` is the `+0x3F4`
## total the BonusScreen pays for a normal Adventure tank (EV-0069). The three minigames a player may
## remember are not in these notes; only this one round is recovered, and nothing here invents the
## other two (D-0051).

## `+0x444 - +0x2A8 > 0x9F`: the wait is 160 frames, and the strict `>` puts the start on the
## 160th tick after the finalizer's anchor.
const START_WAIT_TICKS := 0xA0
## `FUN_00537E20`'s `base` by tank; the default and tank 5 are 10 (`§6.1`).
const BASE_SECONDS := {1: 10, 2: 15, 3: 20, 4: 25, 5: 10}
const DEFAULT_BASE_SECONDS := 10
## `base + clamp(level, 1, 6) - 1`.
const COUNTED_LEVEL_MAX := 6
## The pre-increment `+0x3F8 > 100` test in the end gate.
const BLINK_GATE := 100

enum Phase { WAITING, PLAYING, CLOSED }

## `+0x2A4`: 0 while waiting, 1 while the round runs.
var phase := Phase.WAITING
var duration_ticks := 0
var ticks_per_second := 36
## `+0x444` since the finalizer's anchor `+0x2A8`.
var age := 0
var anchor := 0
## `+0x3B0`: the round's elapsed clock, reset by `FUN_00537F40`.
var elapsed := 0
## `+0x3F8`: the HUD's blinking counter, incremented every playing tick.
var blink := 0
## `+0x3F4`: the round's shells, also the BonusScreen's reward for a normal Adventure tank.
var shells := 0


## `base + clamp(level, 1, 6) - 1` seconds (`§6.1`). A normal tank completion runs it at the
## sentinel (level 6), so tanks 1/2/3 get 15/20/25 s.
static func seconds_for(tank_no: int, level_no: int) -> int:
	var base := int(BASE_SECONDS.get(tank_no, DEFAULT_BASE_SECONDS))
	return base + clampi(level_no, 1, COUNTED_LEVEL_MAX) - 1


## `FUN_0053EAF0`'s "Time Remaining: %d:%02d" (`§6.3`).
static func time_text(seconds_left: int) -> String:
	var secs := maxi(seconds_left, 0)
	return "Time Remaining: %d:%02d" % [secs / 60, secs % 60]


## `FUN_00537E20` + the wait's anchor: a fresh round for this tank completion.
func begin(tank_no: int, level_no: int, ticks_per_second_: int = 36) -> void:
	ticks_per_second = maxi(ticks_per_second_, 1)
	duration_ticks = maxi(seconds_for(tank_no, level_no) * ticks_per_second, 1)
	phase = Phase.WAITING
	age = 0
	anchor = 0
	elapsed = 0
	blink = 0
	shells = 0


## One tank tick. `coins_empty` is the tank's own coin list `Tank+0xA8`. Returns `&"start"` on the
## tick the round begins, `&"finish"` on the tick the end gate opens, and `&""` otherwise - the
## caller owns the side effects (HUD, advance, BonusScreen).
func tick(coins_empty: bool) -> StringName:
	age += 1
	if phase == Phase.WAITING:
		if age - anchor > START_WAIT_TICKS - 1:
			# `FUN_00537F40`.
			phase = Phase.PLAYING
			elapsed = 0
			blink = 0
			anchor = age
			return &"start"
		return &""
	if phase == Phase.PLAYING:
		var was_blink := blink
		blink += 1
		elapsed += 1
		if duration_ticks - elapsed < 0 and coins_empty and was_blink > BLINK_GATE:
			phase = Phase.CLOSED
			return &"finish"
	return &""


## `Tank+0x3F4 += amount` (the `Tank+0x2A5` shells routing, `FUN_0053C1E0`).
func add_shells(amount: int) -> void:
	if amount <= 0 or phase == Phase.CLOSED:
		return
	shells += amount


## `+0x3BC - +0x3B0` in whole seconds, floor like the tank's own clock.
func seconds_left() -> int:
	if phase != Phase.PLAYING:
		return 0
	return maxi(0, int((duration_ticks - elapsed) / ticks_per_second))


func is_playing() -> bool:
	return phase == Phase.PLAYING


func is_closed() -> bool:
	return phase == Phase.CLOSED
