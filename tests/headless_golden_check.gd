extends SceneTree
## Headless check for the P4.12 golden-file fixtures (P2.13 / EV-0144).
##
##   & "<godot>" --headless --path . --script res://tests/headless_golden_check.gd
##
## Verifies the two preserved real saves byte-for-byte against the note's section map:
## `adv1.dat` 1081 B (E=362, S=49, slack 8) and `sim1.dat` 11800 B (E=10946, S=32,
## slack 160). The entities are variable-length serialize bodies, so the check walks
## the note's offsets (`42+E+S`, `454+E+S`, `658+E+S`) directly rather than through
## `TankSave.from_bytes`, which is the port's own fixed-slot format.

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_sample("res://docs/analysis/inputs/p2.13-saves-2026-10-21/adv1.dat", 1081, 1, 1, 362, 49, 8, "Here are your first fish! Take good care of them!")
	_test_sample("res://docs/analysis/inputs/p2.13-saves-gamebanana-100/sim1.dat", 11800, 1, 5, 10946, 32, 160, "ALIEN SIGNATURE TYPE-II DETECTED")
	if _failures == 0:
		print("headless_golden_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_golden_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _read(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


func _u32(bytes: PackedByteArray, at: int) -> int:
	return int(bytes[at]) | (int(bytes[at + 1]) << 8) | (int(bytes[at + 2]) << 16) \
		| (int(bytes[at + 3]) << 24)


func _test_sample(path: String, size: int, tank_no: int, level_no: int, e: int, s: int, slack: int, overlay: String) -> void:
	var name := path.get_file()
	var bytes := _read(path)
	_expect(bytes.size() == size, "%s is %d bytes (got %d)" % [name, size, bytes.size()])
	if bytes.size() != size:
		return
	_expect(_u32(bytes, 0) == 0x36, "version is 0x36 (got %d)" % _u32(bytes, 0))
	_expect(_u32(bytes, 4) == tank_no, "tank is %d (got %d)" % [tank_no, _u32(bytes, 4)])
	_expect(_u32(bytes, 8) == level_no, "level is %d (got %d)" % [level_no, _u32(bytes, 8)])
	_expect(bytes.size() == 662 + e + s + slack,
		"the size law holds: 662+362/10946+49/32+slack (got %d)" % bytes.size())
	var boss_at := 18 + e
	_expect(int(bytes[boss_at]) == 0, "no +0x110 boss object in %s" % name)
	var len_at := boss_at + 1
	_expect(int(bytes[len_at]) | (int(bytes[len_at + 1]) << 8) == s,
		"the overlay length is %d" % s)
	var text := bytes.slice(len_at + 2, len_at + 2 + s).get_string_from_utf8()
	_expect(text == overlay, "the overlay line is \"%s\"" % overlay)
	_expect(42 + e + s + 0 < bytes.size(), "the pet section 42+E+S is inside the file")
	_expect(454 + e + s + 204 + 4 <= bytes.size(), "the store 454+E+S..658+E+S fits")
	_expect(658 + e + s + 4 + slack == bytes.size(), "the timestamp 658+E+S + slack closes the file")


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
