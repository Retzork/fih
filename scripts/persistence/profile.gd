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
## `profile+0x54`: Cyrax hp-scaling counter (P2.9 §8/§10): +1 when a boss
## fight ends with >1000 damage dealt and no minions left; Cyrax hp reads
## `5000 - 125 * clamp(profile+0x54 - 1, 0, 20)`. The loss/retry vs defeat
## naming is Q-0022; the save default is 0 (P2.13 profile sample).
var cyrax_attempts := 0
## `profile+0x4C`: level sessions started.
var sessions_started := 0
## `profile+0x44`: the per-mode save slot (`userdata/<stem><slot>.dat`, EV-0142).
var save_slot := 1
## `profile+0x72..+0x77`: six backdrop ownership flags (Q-0026, EV-0141).
## One backdrop is owned at start; the store roller sells one random unowned backdrop
## at 15000 shells per refresh, then falls back to a random pet.
const BACKDROP_SLOTS := 6
const BACKDROP_PRICE := 15000
var backdrops_owned: Array[int] = []


func _init() -> void:
	owned_pets.resize(PET_SLOTS)
	owned_pets.fill(0)
	selected_pets.resize(PET_SLOTS)
	selected_pets.fill(0)
	challenge_unlocks.resize(CHALLENGE_SLOTS)
	challenge_unlocks.fill(0)
	backdrops_owned.resize(BACKDROP_SLOTS)
	backdrops_owned.fill(0)
	backdrops_owned[0] = 1


## The remake's own profile format (P4.12): semantics preserved, bytes not (SPECS §7.4).
## JSON under `user://profile.json`; the original `user%d.dat` stays the reference copy.
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"tank": tank,
		"level": level,
		"shells": shells,
		"owned_pets": owned_pets.duplicate(),
		"selected_pets": selected_pets.duplicate(),
		"challenge_unlocks": challenge_unlocks.duplicate(),
		"bonus_adventure": bonus_adventure,
		"tank5_wins": tank5_wins,
		"cyrax_attempts": cyrax_attempts,
		"sessions_started": sessions_started,
		"save_slot": save_slot,
		"backdrops_owned": backdrops_owned.duplicate(),
	}


static func from_dict(data: Dictionary) -> Profile:
	var p := Profile.new()
	p.tank = int(data.get("tank", 1))
	p.level = int(data.get("level", 1))
	p.shells = int(data.get("shells", 0))
	p.bonus_adventure = bool(data.get("bonus_adventure", false))
	p.tank5_wins = int(data.get("tank5_wins", 0))
	p.cyrax_attempts = int(data.get("cyrax_attempts", 0))
	p.sessions_started = int(data.get("sessions_started", 0))
	p.save_slot = int(data.get("save_slot", 1))
	for i in PET_SLOTS:
		if i < (data.get("owned_pets", []) as Array).size():
			p.owned_pets[i] = int((data["owned_pets"] as Array)[i])
		if i < (data.get("selected_pets", []) as Array).size():
			p.selected_pets[i] = int((data["selected_pets"] as Array)[i])
	for i in CHALLENGE_SLOTS:
		if i < (data.get("challenge_unlocks", []) as Array).size():
			p.challenge_unlocks[i] = int((data["challenge_unlocks"] as Array)[i])
	for i in BACKDROP_SLOTS:
		if i < (data.get("backdrops_owned", []) as Array).size():
			p.backdrops_owned[i] = int((data["backdrops_owned"] as Array)[i])
	return p


const PROFILE_PATH := "user://profile.json"


func save_to_file(path: String = PROFILE_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	return OK


static func load_from_file(path: String = PROFILE_PATH) -> Profile:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return null
	return from_dict(data)


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
