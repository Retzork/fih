extends SceneTree
## Headless check for the tank-save framing (P4.12, P2.13 §6).
##
##   & "<godot>" --headless --path . --script res://tests/headless_save_check.gd
##
## Covers the §6.1 field order, the class-0x1F skip, the fixed object slots, the overlay block, the
## 24 pet flags, the 316 scalars and 12 store rows, the section arithmetic (`42+E+S`, `454+E+S`,
## `658+E+S`), a full round trip, and the loader's version gate (rejects `<= 0x34`, accepts 0x35).

const TankSaveScript := preload("res://scripts/persistence/tank_save.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_round_trip()
	_test_layout()
	_test_skip()
	_test_version_gate()

	if _checks == 0:
		printerr("headless_save_check: no assertions ran (a script error aborted the checks)")
		quit(1)
		return
	if _failures == 0:
		print("headless_save_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_save_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _sample() -> TankSave:
	var save: TankSave = TankSaveScript.new()
	save.tank = 3
	save.level = 2
	save.tank_complete = 1
	save.entity_enable = 0
	var slot := PackedByteArray()
	slot.resize(TankSaveScript.OBJECT_SLOT)
	slot.fill(7)
	save.entities = [
		{"class": 0x01, "slot": slot},
		{"class": 0x1F, "slot": slot},
		{"class": 0x02, "slot": slot},
	]
	save.boss_present = true
	var boss := PackedByteArray()
	boss.resize(TankSaveScript.BOSS_SLOT)
	boss.fill(3)
	save.boss_object = boss
	save.overlay_text = "hello"
	save.overlay_colors = [Color8(1, 2, 3, 4), Color8(5, 6, 7, 8)]
	save.overlay_a = 11
	save.overlay_b = 12
	save.overlay_c = 13
	save.overlay_d = 14
	save.pet_flags[0] = 1
	save.pet_flags[23] = 1
	save.scalars[0] = 9
	save.store[0] = {"slot": 0, "price": 300, "base": 300, "increment": 3, "present": 1}
	save.timestamp = 12345
	return save


func _test_round_trip() -> void:
	var save := _sample()
	var bytes := save.to_bytes()
	var read: TankSave = TankSaveScript.from_bytes(bytes)
	_expect(read != null, "the sample parses")
	if read == null:
		return
	_expect(read.version == TankSaveScript.VERSION, "the version survives")
	_expect(read.tank == 3 and read.level == 2, "tank and level survive")
	_expect(read.tank_complete == 1 and read.entity_enable == 0, "the two latches survive")
	_expect(read.entities.size() == 2, "the skipped class is not written (got %d)" % read.entities.size())
	_expect(int(read.entities[1]["class"]) == 0x02, "entity order is preserved")
	_expect(read.boss_present and read.boss_object.size() == TankSaveScript.BOSS_SLOT,
		"the boss presence byte and object survive")
	_expect(read.overlay_text == "hello", "the overlay string survives")
	_expect(read.overlay_colors[0] == Color8(1, 2, 3, 4) and read.overlay_colors[1] == Color8(5, 6, 7, 8),
		"both overlay colors survive")
	_expect(read.overlay_a == 11 and read.overlay_b == 12, "the two overlay dwords survive")
	_expect(read.overlay_c == 13 and read.overlay_d == 14, "the byte and last dword survive")
	_expect(read.pet_flags[0] == 1 and read.pet_flags[23] == 1 and read.pet_flags[1] == 0,
		"the 24 pet flags survive")
	_expect(read.scalars.size() == TankSaveScript.SCALARS and read.scalars[0] == 9,
		"the 316-byte scalar block survives")
	_expect(int(read.store[0]["slot"]) == 0 and int(read.store[0]["price"]) == 300
		and int(read.store[0]["increment"]) == 3 and int(read.store[0]["present"]) == 1,
		"the first store row survives")
	_expect(int(read.store[1]["slot"]) == -1, "empty store rows stay -1")
	_expect(read.timestamp == 12345, "the timestamp survives")
	_expect(bytes.size() == save.file_size(), "the size matches file_size()")
	_expect(bytes.size() == TankSaveScript.BASE_SIZE + save.entity_bytes() + save.overlay_length()
		+ save.boss_bytes(), "the size follows 662 + E + S (+ the boss object)")


func _test_layout() -> void:
	# The note's offsets assume no `+0x110` object (both samples have presence 0).
	var save := _sample()
	save.boss_present = false
	var bytes := save.to_bytes()
	var e := save.entity_bytes()
	var s := save.overlay_length()
	_expect(_u32(bytes, 0x00) == TankSaveScript.VERSION, "offset 0 is the version")
	_expect(_u32(bytes, 0x04) == 3, "offset 4 is the tank")
	_expect(_u32(bytes, 0x08) == 2, "offset 8 is the level")
	_expect(int(bytes[0x0C]) == 1 and int(bytes[0x0D]) == 0, "offsets 0x0C/0x0D are the latches")
	_expect(_u32(bytes, 0x0E) == 2, "offset 0x0E is the kept entity count")
	_expect(e == 2 * (4 + TankSaveScript.OBJECT_SLOT), "E is 2 object slots (got %d)" % e)
	_expect(s == 5, "S is the string length without its prefix (got %d)" % s)
	_expect(_u32(bytes, 42 + e + s) == 1, "the pet flags start at 42+E+S")
	_expect(_u32(bytes, 454 + e + s) == 0, "the store table starts at 454+E+S")
	_expect(_u32(bytes, 658 + e + s) == 12345, "the timestamp sits at 658+E+S")
	_expect(bytes.size() == 662 + e + s, "the file ends at 662+E+S")
	var with_boss := _sample()
	var wb := with_boss.to_bytes()
	_expect(wb.size() == with_boss.file_size(), "a boss object is counted by file_size()")
	_expect(_u32(wb, 42 + with_boss.entity_bytes() + with_boss.overlay_length()
		+ TankSaveScript.BOSS_SLOT) == 1, "the boss object shifts the pet flags by 0x208")


func _test_skip() -> void:
	var save: TankSave = TankSaveScript.new()
	var slot := PackedByteArray()
	slot.resize(TankSaveScript.OBJECT_SLOT)
	save.entities = [{"class": 0x1F, "slot": slot}]
	_expect(save.serialized_entities() == 0, "a lone class 0x1F entity serializes nothing")
	_expect(save.to_bytes().size() == save.file_size(), "a skipped entity costs no bytes")
	var read: TankSave = TankSaveScript.from_bytes(save.to_bytes())
	_expect(read != null and read.entities.is_empty(), "a skipped entity does not come back")


func _test_version_gate() -> void:
	var bytes := _sample().to_bytes()
	var old := bytes.duplicate()
	old[0] = 0x34
	_expect(TankSaveScript.from_bytes(old) == null, "version 0x34 is rejected")
	var oldest := bytes.duplicate()
	oldest[0] = 0x35
	_expect(TankSaveScript.from_bytes(oldest) != null, "version 0x35 is accepted")
	_expect(TankSaveScript.from_bytes(bytes.slice(0, 10)) == null, "a short file is rejected")
	var cut := bytes.slice(0, bytes.size() - 8)
	_expect(TankSaveScript.from_bytes(cut) == null, "a truncated body is rejected")


# --- helpers -----------------------------------------------------------------

func _u32(bytes: PackedByteArray, at: int) -> int:
	return int(bytes[at]) | (int(bytes[at + 1]) << 8) | (int(bytes[at + 2]) << 16) \
		| (int(bytes[at + 3]) << 24)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
