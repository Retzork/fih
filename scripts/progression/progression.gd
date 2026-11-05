class_name Progression
extends RefCounted
## P2.6 progression: 5 tanks x 5 levels, the per-tank store table, egg-piece purchases, the pet
## award and the advance rule (EV-0061-EV-0076; `docs/analysis/notes/p2.6-progression.md`).
##
## Every table here is a direct read of that note. What is **not** here: the bonus rounds, the
## HatchScreen/PetsScreen, the credits/trophy screens and the tank-4 L5 card art - none of them is
## ported yet, so Q-0053 records the gap. The award index is still computed, because the profile
## records the pet and the Hatch screen only displays it.
##
## Level 6 is the recovered "tank complete" sentinel (`profile+0x20 = 6`): a level-5 completion
## advances *into* it and the next level start finalizes the tank instead of running a session. The
## 160-frame wait and the bonus round between those two steps are not ported (Q-0053), so
## `resolve_start` walks the sentinel immediately when a level is started on it.

const TANKS := 5
const LEVELS := 5
## `profile+0x20 = 6` on a normal level-5 completion (`FUN_00501370`, EV-0068).
const LEVEL_SENTINEL := 6
## The egg-piece item (`§3`: tank 5 sells only item 11 at slot 6).
const EGG_ITEM := 11
## `Tank+0x43C` starts at 1 (tank 5: 3) and completes the level at 4 (`§5`).
const EGG_PIECES_AT_START := 1
const TANK5_EGG_PIECES := 3
const EGG_PIECES_TO_COMPLETE := 4
## The tank-4 level-5 completion awards card 999 with no pet grant (`§1.3`).
const PET_CARD := 999
## A price the note never recovered, so a caller must refuse rather than sell (`Store.price_known`).
const PRICE_UNKNOWN := -1

## `§3` store table: item id -> tank -> `[price, store slot]`. An absent tank hides the item.
## Item 11 (the egg piece) only appears on tank 5, where it is free and completes the tank.
const STORE_TABLE := {
	0: {1: [100, 0], 2: [100, 0], 3: [100, 0]},
	1: {4: [200, 0]},
	2: {1: [200, 1], 2: [200, 1], 3: [200, 1], 4: [200, 1]},
	3: {1: [300, 2], 2: [300, 2], 3: [300, 2], 4: [300, 2]},
	4: {1: [1000, 3], 4: [1000, 3]},
	5: {2: [250, 3]},
	6: {2: [750, 4]},
	7: {3: [750, 3]},
	8: {3: [2000, 4]},
	9: {4: [10000, 4]},
	10: {1: [1000, 5], 2: [1000, 5], 3: [2000, 5], 4: [5000, 5]},
	11: {5: [0, 6]},
}

## `§3` level gating: items hidden by level 1/2 of a tank (`A = -1`).
const HIDDEN := {
	"1:1": [2, 3, 4, 10],
	"1:2": [4, 10],
	"2:1": [6, 10],
	"3:1": [8, 10],
	"4:1": [9, 10],
}

## `§3` egg price by level 1-5, per tank. Tank 5's egg is free (one purchase completes).
const EGG_PRICES := {
	1: [150, 500, 2000, 3000, 5000],
	2: [750, 3000, 5000, 7500, 10000],
	3: [1000, 5000, 7500, 10000, 15000],
	4: [3000, 25000, 50000, 75000, 99999],
	5: [0],
}
## Challenge mode replaces the egg price outright (`§3`); tank 1 is not named by the note.
const MODE4_EGG := {2: 5000, 3: 15000, 4: 25000}
## Time Trial's egg price (`§3`).
const MODE1_EGG := 100
const MODE_TIME_TRIAL := 1
const MODE_CHALLENGE := 4

## `§5` the full pet index -> display name table (`FUN_0051F770`).
const PET_NAMES := [
	"Stinky", "Niko", "Itchy", "Prego", "Zorf", "Clyde", "Vert", "Rufus", "Meryl", "Wadsworth",
	"Seymour", "Shrapnel", "Gumbo", "Blip", "Rhubarb", "Nimbus", "Amp", "Gash", "Angie", "Presto",
	"Brinkley", "Nostradamus", "Stanley", "Walter",
]
const CARD_NAME := "Evil Alien Mastermind"
## Winning the final boss's level also pays 5000 Shells (`§1.2`).
const FINAL_BOSS_SHELLS := 5000
const FINAL_BOSS_PET := 19


## Items hidden on this level of this tank.
static func hidden_items(tank_no: int, level_no: int) -> Array:
	return HIDDEN.get("%d:%d" % [tank_no, level_no], [])


## `Tank+0x43C` at level start: 1, or 3 on tank 5 (`§3`/`§5`).
static func egg_pieces_at_start(tank_no: int) -> int:
	return TANK5_EGG_PIECES if tank_no == TANKS else EGG_PIECES_AT_START


## The egg-piece price for this tank/level, or `PRICE_UNKNOWN` where the note recovers nothing
## (Challenge mode on tank 1, or a level outside 1-5).
static func egg_price(tank_no: int, level_no: int, mode: int = 0) -> int:
	if tank_no == TANKS:
		return 0
	if mode == MODE_CHALLENGE:
		return int(MODE4_EGG.get(tank_no, PRICE_UNKNOWN))
	if mode == MODE_TIME_TRIAL:
		return MODE1_EGG
	var prices: Array = EGG_PRICES.get(tank_no, [])
	var index := level_no - 1
	if index < 0 or index >= prices.size():
		return PRICE_UNKNOWN
	return int(prices[index])


## The store rows this tank/level offers, ordered by the store slot the original places them at.
## A row is shaped like `Store.row_for` plus `shelf`, and `free` marks the tank-5 egg, whose 0 is a
## recovered price rather than the "not recovered" marker.
static func store_rows(tank_no: int, level_no: int, mode: int = 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var hidden := hidden_items(tank_no, level_no)
	for id in STORE_TABLE:
		var per_tank: Dictionary = STORE_TABLE[id]
		if not per_tank.has(tank_no) or hidden.has(id):
			continue
		var spec: Array = per_tank[tank_no]
		var price := int(spec[0])
		if id == EGG_ITEM:
			price = egg_price(tank_no, level_no, mode)
		rows.append({
			"slot": id,
			"price": price,
			"base": price,
			"increment": 0,
			"present": 0,
			"shelf": int(spec[1]),
			"free": id == EGG_ITEM and price == 0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["shelf"]) != int(b["shelf"]):
			return int(a["shelf"]) < int(b["shelf"])
		return int(a["slot"]) < int(b["slot"]))
	return rows


## The pet a **completed** level awards (`§1.2`): tank 5 -> Presto, tank 4 level 5 -> card 999 with
## no grant, otherwise `tank*5 - 6 + level`.
static func offered_pet(tank_no: int, level_no: int) -> int:
	if tank_no >= TANKS:
		return FINAL_BOSS_PET
	if tank_no == 4 and level_no == 5:
		return PET_CARD
	return tank_no * 5 - 6 + level_no


static func pet_name(index: int) -> String:
	if index == PET_CARD:
		return CARD_NAME
	if index < 0 or index >= PET_NAMES.size():
		return ""
	return String(PET_NAMES[index])


## `FUN_00501370` + the bonus-end advance (`§10.4`). Tank 4 level 5 jumps straight to tank 5 level 1;
## tank 5 beyond level 1 sets the victory gate and the Bonus Adventure flag; a level past 5 (or past
## the sentinel) moves to the next tank's level 1.
static func advance(tank_no: int, level_no: int, bonus_adventure: bool = false) -> Dictionary:
	var tank := tank_no
	var level := level_no + 1
	var bonus := bonus_adventure
	var wins := 0
	if tank == 4 and level == LEVEL_SENTINEL:
		tank = 5
		level = 1
	if tank == TANKS and level > 1:
		wins = 1
		bonus = true
	if level > LEVEL_SENTINEL or (bonus and level > LEVELS):
		tank += 1
		level = 1
	return {"tank": tank, "level": level, "bonus_adventure": bonus, "tank5_wins": wins}


## The tank/level a start actually runs. A start on the sentinel is the post-bonus step, so it
## advances once more (the bonus itself is not ported, Q-0053).
static func resolve_start(tank_no: int, level_no: int, bonus_adventure: bool = false) -> Dictionary:
	if level_no != LEVEL_SENTINEL:
		return {"tank": tank_no, "level": level_no, "bonus_adventure": bonus_adventure}
	var step := advance(tank_no, level_no, bonus_adventure)
	return {"tank": int(step["tank"]), "level": int(step["level"]),
		"bonus_adventure": bool(step["bonus_adventure"])}
