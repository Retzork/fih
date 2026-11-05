class_name Profile
extends RefCounted
## The Adventure profile: the fields P2.6/P2.13 name and this port already uses. The original keeps
## them at `profile+0x00..` behind `[manager+0x8B8]` (`docs/analysis/notes/p2.13-profile.md`); the
## offsets are recorded per field so the save work (P4.12) can map them back.
##
## Deliberately partial: shells, tank/level progress, the owned/selected pet bytes, the Challenge
## unlock bytes and the two flags the menus gate on. The score tables, the challenge records
## (`profile+0x34`) and the `scr%d.dat` block are P4.6/P4.12 remainder (Q-0053).

## `profile+0x48`: Shells, clamped 0..9,999,999 by `FUN_00501200` (P2.6 §5).
const SHELLS_MAX := 9999999
## Owned/selected pet bytes: 24 slots (`profile+0x00..+0x17`, `+0x5A..+0x71`).
const PET_SLOTS := 24
## Challenge unlock bytes, one per tank (`profile+0x77+tank`).
const CHALLENGE_SLOTS := 5

## `profile+0x1C` tank, `+0x20` level (1..6, 6 is the "tank complete" sentinel).
var tank := 1
var level := 1
## `profile+0x48`.
var shells := 0
## `profile+0x00+i`: the pets the player owns.
var owned_pets: Array[int] = []
## `profile+0x5A+i`: the pets picked for the next level.
var selected_pets: Array[int] = []
## `profile+0x77+i`: Challenge-mode tanks beaten.
var challenge_unlocks: Array[int] = []
## `profile+0x59`: the Bonus Adventure flag (the menus read it as "adventure done").
var bonus_adventure := false
## `profile+0x50`: how many times tank 5 has been won.
var tank5_wins := 0
## `profile+0x4C`: level sessions started.
var sessions_started := 0


func _init() -> void:
	owned_pets.resize(PET_SLOTS)
	owned_pets.fill(0)
	selected_pets.resize(PET_SLOTS)
	selected_pets.fill(0)
	challenge_unlocks.resize(CHALLENGE_SLOTS)
	challenge_unlocks.fill(0)


## `FUN_00501420(i, v)`: writes an owned byte and keeps the count (`profile+0x18`) in step by
## counting the array, which is the same quantity.
func grant_pet(index: int) -> bool:
	if index < 0 or index >= PET_SLOTS:
		return false
	if owned_pets[index] != 0:
		return false
	owned_pets[index] = 1
	return true


func owns_pet(index: int) -> bool:
	return index >= 0 and index < PET_SLOTS and owned_pets[index] != 0


func pet_count() -> int:
	var total := 0
	for flag in owned_pets:
		if flag != 0:
			total += 1
	return total


## `FUN_00501200(n)`: adds Shells, clamped to 0..9,999,999, and returns the new total.
func add_shells(amount: int) -> int:
	shells = clampi(shells + amount, 0, SHELLS_MAX)
	return shells


## `profile+0x1C`: the tank the player has reached; Time Trial needs 2 (P2.12 EV-0131).
func tanks_unlocked() -> int:
	return tank


## `profile+0x59`: the Adventure is over once the Bonus Adventure flag is set (tank 5 L2).
func adventure_done() -> bool:
	return bonus_adventure


## The dictionary `GameSelector.choose` reads (it was written before this class existed).
func to_menu_state() -> Dictionary:
	return {
		"tanks_unlocked": tanks_unlocked(),
		"adventure_done": adventure_done(),
		"tank": tank,
		"level": level,
		"shells": shells,
	}
