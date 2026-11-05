extends SceneTree
## Headless check for the save file layer (P4.12, P2.13 §6, EV-0142).
##
##   & "<godot>" --headless --path . --script res://tests/headless_save_files_check.gd
##
## Covers the per-mode stems (`adv` for modes 0 and 2, then tim/snd/sur/sim), the
## `userdata\<stem><slot>.dat` path, a real write/read round trip under `user://`, the version gate on
## disk, a missing file, and the Adventure-only tank/level match.

const TankSaveScript := preload("res://scripts/persistence/tank_save.gd")
const SaveFilesScript := preload("res://scripts/persistence/save_files.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_paths()
	_test_round_trip()
	_test_refusals()
	_test_profile_rule()

	if _checks == 0:
		printerr("headless_save_files_check: no assertions ran")
		quit(1)
		return
	if _failures == 0:
		print("headless_save_files_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_save_files_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_paths() -> void:
	_expect(SaveFilesScript.path_for(0, 1) == "userdata/adv1.dat", "mode 0 is adv")
	_expect(SaveFilesScript.path_for(2, 3) == "userdata/adv3.dat", "mode 2 is also adv")
	_expect(SaveFilesScript.path_for(1, 2) == "userdata/tim2.dat", "mode 1 is tim")
	_expect(SaveFilesScript.path_for(3, 1) == "userdata/snd1.dat", "mode 3 is snd")
	_expect(SaveFilesScript.path_for(4, 1) == "userdata/sur1.dat", "mode 4 is sur")
	_expect(SaveFilesScript.path_for(5, 4) == "userdata/sim4.dat", "mode 5 is sim, slot from the profile")
	_expect(SaveFilesScript.path_for(9, 0) == "userdata/sim0.dat",
		"a mode past the table clamps to the last stem")


func _test_round_trip() -> void:
	var root := "user://save_check"
	var path := SaveFilesScript.path_for(0, 1, root)
	_cleanup(path)
	var save: TankSave = TankSaveScript.new()
	save.tank = 2
	save.level = 3
	save.overlay_text = "round trip"
	save.pet_flags[4] = 1
	save.store[0] = {"slot": 6, "price": 1500, "base": 1500, "increment": 15, "present": 0}
	_expect(SaveFilesScript.write_tank_save(path, save) == OK, "the write succeeds")
	_expect(FileAccess.file_exists(path), "the file exists on disk")
	var read: TankSave = SaveFilesScript.read_tank_save(path)
	_expect(read != null, "the file reads back")
	if read != null:
		_expect(read.tank == 2 and read.level == 3, "tank and level round trip through disk")
		_expect(read.overlay_text == "round trip", "the overlay string round trips through disk")
		_expect(read.pet_flags[4] == 1, "a pet flag round trips through disk")
		_expect(int(read.store[0]["price"]) == 1500, "a store row round trips through disk")
		_expect(read.to_bytes().size() == save.to_bytes().size(), "the bytes are stable across the trip")
	_cleanup(path)


func _test_refusals() -> void:
	var root := "user://save_check"
	_expect(SaveFilesScript.read_tank_save(SaveFilesScript.path_for(0, 9, root)) == null,
		"a missing file reads as null")
	var path := SaveFilesScript.path_for(0, 8, root)
	_cleanup(path)
	var bytes := TankSaveScript.new().to_bytes()
	bytes[0] = 0x34
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	_expect(SaveFilesScript.read_tank_save(path) == null, "a 0x34 file is refused on disk")
	_cleanup(path)


func _test_profile_rule() -> void:
	var save: TankSave = TankSaveScript.new()
	save.tank = 2
	save.level = 3
	_expect(SaveFilesScript.matches_profile(save, 0, 2, 3), "Adventure accepts the matching profile")
	_expect(not SaveFilesScript.matches_profile(save, 0, 2, 4), "Adventure refuses a level mismatch")
	_expect(not SaveFilesScript.matches_profile(save, 0, 1, 3), "Adventure refuses a tank mismatch")
	_expect(SaveFilesScript.matches_profile(save, 1, 5, 5), "Time Trial does not compare the profile")


# --- helpers -----------------------------------------------------------------

func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
