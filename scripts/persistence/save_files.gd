class_name SaveFiles
extends RefCounted
## Where the tank saves live and how they get there (P2.13 §6, EV-0142).
##
## `FUN_00505880(out, mode, slot)` formats `userdata\%s%d.dat` with the stem chosen by the mode:
## `adv` for Adventure (modes 0 and 2), then `tim`/`snd`/`sur`/`sim` for 1/3/4/5, and the slot from
## `profile+0x44`. `FUN_00546990` (SaveGame) writes the version dword and then the body; `FUN_00546AA0`
## (LoadGame) reads the version first and refuses `<= 0x34`, which `TankSave.from_bytes` already does.
##
## What this class adds on top of the framing is the file layer: the path, the directory creation, the
## byte-for-byte read/write, and the Adventure rule that a save whose tank/level disagree with the
## profile is refused (mode 0 only).

const ROOT := "userdata"
## Index = game mode; `adv` covers both Adventure and its bonus variant (mode 2).
const STEMS := ["adv", "tim", "adv", "snd", "sur", "sim"]
const ADVENTURE_MODE := 0


## `userdata/<stem><slot>.dat`, e.g. (`1`, `2`) -> `userdata/adv2.dat`.
static func path_for(mode: int, slot: int, root: String = ROOT) -> String:
	var stem: String = STEMS[clampi(mode, 0, STEMS.size() - 1)]
	return "%s/%s%d.dat" % [root, stem, slot]


## Write a save, creating the directory first. Returns the FileAccess error (OK on success).
static func write_tank_save(path: String, save: TankSave) -> Error:
	var directory := path.get_base_dir()
	if directory != "" and not DirAccess.dir_exists_absolute(directory):
		var made := DirAccess.make_dir_recursive_absolute(directory)
		if made != OK:
			return made
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(save.to_bytes())
	file.close()
	return OK


## Read a save. Null when the file is missing, unreadable or refused by the version gate.
static func read_tank_save(path: String) -> TankSave:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return TankSave.from_bytes(bytes)


## Mode 0 refuses a save whose tank/level differ from the profile's (P2.13 §6.1). Other modes don't.
static func matches_profile(save: TankSave, mode: int, tank: int, level: int) -> bool:
	if mode != ADVENTURE_MODE:
		return true
	return save.tank == tank and save.level == level
