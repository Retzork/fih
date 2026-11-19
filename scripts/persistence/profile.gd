class_name Profile
extends RefCounted
## The Adventure profile: the fields P2.6/P2.13 name and this port already uses. The original keeps
## them at `profile+0x00..` behind `[manager+0x8B8]` (`docs/analysis/notes/p2.13-profile.md`); the
## offsets are recorded per field so the save work (P4.12) can map them back.
##
## Deliberately partial: shells, tank/level progress, the owned/selected pet bytes, the Challenge
## unlock bytes, the two flags the menus gate on, and the level/Challenge time records the level
## completion writes (D-0053). The `scr%d.dat` block and the credits/story fields stay open (Q-0053).
##
## Record shape: the base keeps one 12-byte slot per level (`FUN_00514510` -> `FUN_005142f0`) and per
## Challenge tank (`FUN_005144C0` -> the same helper at `profile+0x34+(tank-1)*12`), but that helper's
## body was never recovered, so the port stores what the call sites prove - the run's seconds, the
## fastest run and how many runs landed in the slot - instead of guessing the three dwords.

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
## `FUN_00514510`: elapsed seconds per completed level, keyed `"mode:tank:level"` (the mode is part
## of the key because the Hall's Time Trial and Adventure tabs read separate lists, a port choice
## recorded in D-0053). Each value is `{"seconds": int, "best": int, "runs": int}`.
var level_times: Dictionary = {}
## `FUN_005144C0`: the Challenge record per tank (`profile+0x34+(tank-1)*12`, tanks 1-4 only),
## keyed by tank number with the same `{"seconds", "best", "runs"}` shape.
var challenge_times: Dictionary = {}


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
		"level_times": level_times.duplicate(true),
		"challenge_times": challenge_times.duplicate(true),
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
	p.level_times = _read_records(data.get("level_times", {}))
	p.challenge_times = _read_records(data.get("challenge_times", {}))
	return p


## JSON gives every number back as a float, so a record is rebuilt field by field.
static func _read_records(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for key in (raw as Dictionary):
		var value = raw[key]
		if typeof(value) != TYPE_DICTIONARY:
			continue
		out[String(key)] = {
			"seconds": int(value.get("seconds", 0)),
			"best": int(value.get("best", 0)),
			"runs": int(value.get("runs", 0)),
		}
	return out


## `FUN_00514510(tank, level, profile, Tank+0x3FC)`: one slot per completed level. The first run's
## seconds are its best; a later, faster run lowers the best. Returns the stored record.
func record_level_time(tank_no: int, level_no: int, seconds: int, mode: int = 0) -> Dictionary:
	return _write_record(level_times, _level_key(mode, tank_no, level_no), seconds)


## `FUN_005144C0(tank, profile, time)`: the Challenge record, tanks 1-4 only (`param_1 - 1 < 4`).
func record_challenge_time(tank_no: int, seconds: int) -> Dictionary:
	if tank_no < 1 or tank_no > CHALLENGE_SLOTS - 1:
		return {}
	return _write_record(challenge_times, str(tank_no), seconds)


static func _level_key(mode: int, tank_no: int, level_no: int) -> String:
	return "%d:%d:%d" % [mode, tank_no, level_no]


static func _write_record(into: Dictionary, key: String, seconds: int) -> Dictionary:
	var value := maxi(seconds, 0)
	var record: Dictionary = into.get(key, {})
	if record.is_empty():
		into[key] = {"seconds": value, "best": value, "runs": 1}
		return into[key]
	record["seconds"] = value
	record["best"] = mini(int(record.get("best", value)), value)
	record["runs"] = int(record.get("runs", 0)) + 1
	into[key] = record
	return record


func level_record(tank_no: int, level_no: int, mode: int = 0) -> Dictionary:
	return level_times.get(_level_key(mode, tank_no, level_no), {})


func challenge_record(tank_no: int) -> Dictionary:
	return challenge_times.get(str(tank_no), {})


## The fastest recorded run in `mode` as `{"seconds", "tank", "level"}`, or `{}`.
func fastest_level_time(mode: int = 0) -> Dictionary:
	var best := {}
	for key in level_times:
		var parts := String(key).split(":")
		if parts.size() != 3 or int(parts[0]) != mode:
			continue
		var record: Dictionary = level_times[key]
		var seconds := int(record.get("best", 0))
		if best.is_empty() or seconds < int(best["seconds"]):
			best = {"seconds": seconds, "tank": int(parts[1]), "level": int(parts[2])}
	return best


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
