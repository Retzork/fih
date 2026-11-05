class_name TankSave
extends RefCounted
## The tank save body, a port of `FUN_00546240` in both directions (P2.13 §6, EV-0144).
##
## Layout (all little-endian, offsets from the note's §6.1 table):
##
##   0x00 u32 version (always 0x36)      0x04 u32 tank            0x08 u32 level
##   0x0C u8  tank-complete (`+0x2A5`)   0x0D u8  entity latch    0x0E u32 entity count
##   then, per entity: u32 class id + a 0x140-byte object slot. Class `0x1F` is skipped entirely.
##   then u8 `+0x110` presence (the boss) + its object when 1, the overlay (`+0x118`, §6.2),
##   24 x u32 per-pet presence, 316 scalar bytes, 12 x 17-byte store rows, u32 `__time64`.
##
## The entity bodies, the `+0x110` object and the 316 scalars are carried as opaque blocks: their
## inner field order is each entity's own save body, which is ported with the entity that owns it.
## What this class fixes today is the framing every one of those ports must agree on, including the
## section arithmetic the note uses as its regression guard (`42+E+S`, `454+E+S`, `658+E+S`).

const VERSION := 0x36
## LoadGame rejects `<= 0x34` (P2.13 §6.1), so 0x35 is the oldest accepted version.
const MIN_VERSION := 0x35
const OBJECT_SLOT := 0x140
## The optional `+0x110` object is a bare `0x208`-byte entity (P2.13 §6.2).
const BOSS_SLOT := 0x208
const SKIPPED_CLASS := 0x1F
const PET_FLAGS := 24
const SCALARS := 316
const STORE_ROWS := 12
const STORE_ROW_BYTES := 17
## 18-byte header + 1 boss flag + 2 string length + 21 overlay tail + 96 pets + 316 scalars +
## 204 store + 4 timestamp. Everything except the entity stream `E` and the overlay length `S`.
const BASE_SIZE := 662

var version := VERSION
var tank := 1
var level := 1
var tank_complete := 0
var entity_enable := 0
## `{ "class": int, "slot": PackedByteArray }`, in file order.
var entities: Array[Dictionary] = []
var boss_present := false
var boss_object := PackedByteArray()
var overlay_text := ""
## `+0xA8` and `+0xB8` (r,g,b,a each).
var overlay_colors: Array[Color] = [Color.BLACK, Color.BLACK]
## `+0xC8`, `+0xD0`, `+0xD4`, `+0xD8`: serialized but with no bound reader yet (Q-0029).
var overlay_a := 0
var overlay_b := 0
var overlay_c := 0
var overlay_d := 0
var pet_flags: Array[int] = []
var scalars := PackedByteArray()
## `{ "slot": int, "price": int, "base": int, "increment": int, "present": int }`.
var store: Array[Dictionary] = []
var timestamp := 0


func _init() -> void:
	pet_flags.resize(PET_FLAGS)
	pet_flags.fill(0)
	scalars.resize(SCALARS)
	scalars.fill(0)
	for i in STORE_ROWS:
		store.append({"slot": -1, "price": 0, "base": 0, "increment": 0, "present": 0})


## The entity stream size `E` (each kept entity is a class id plus one object slot).
func entity_bytes() -> int:
	return serialized_entities() * (4 + OBJECT_SLOT)


## The overlay length `S` (the u16 prefix is not counted).
func overlay_length() -> int:
	return overlay_text.to_utf8_buffer().size()


## `42 + E + S`: where the 24 per-pet flags start.
## The `+0x110` object, when present, sits between the entities and the overlay.
func boss_bytes() -> int:
	return BOSS_SLOT if boss_present else 0


func pet_offset() -> int:
	return 42 + entity_bytes() + overlay_length() + boss_bytes()


## `454 + E + S`: where the twelve store rows start.
func store_offset() -> int:
	return pet_offset() + PET_FLAGS * 4


## `658 + E + S`: the timestamp.
func timestamp_offset() -> int:
	return store_offset() + STORE_ROWS * STORE_ROW_BYTES


func file_size() -> int:
	return BASE_SIZE + entity_bytes() + overlay_length() + boss_bytes()


## Entities as they are written: everything except the skipped class.
func serialized_entities() -> int:
	var count := 0
	for entity in entities:
		if int(entity["class"]) != SKIPPED_CLASS:
			count += 1
	return count


func to_bytes() -> PackedByteArray:
	var out := PackedByteArray()
	var kept: Array[Dictionary] = []
	for entity in entities:
		if int(entity["class"]) != SKIPPED_CLASS:
			kept.append(entity)
	var text := overlay_text.to_utf8_buffer()

	out.resize(18)
	_put_u32(out, 0x00, version)
	_put_u32(out, 0x04, tank)
	_put_u32(out, 0x08, level)
	out[0x0C] = tank_complete & 0xFF
	out[0x0D] = entity_enable & 0xFF
	_put_u32(out, 0x0E, kept.size())

	for entity in kept:
		var start := out.size()
		out.resize(start + 4 + OBJECT_SLOT)
		_put_u32(out, start, int(entity["class"]))
		_copy_into(out, start + 4, entity["slot"], OBJECT_SLOT)

	out.append(1 if boss_present else 0)
	if boss_present:
		var start := out.size()
		out.resize(start + BOSS_SLOT)
		_copy_into(out, start, boss_object, BOSS_SLOT)

	out.append(text.size() & 0xFF)
	out.append((text.size() >> 8) & 0xFF)
	out.append_array(text)
	for color in overlay_colors:
		out.append(int(color.r8))
		out.append(int(color.g8))
		out.append(int(color.b8))
		out.append(int(color.a8))
	_append_u32(out, overlay_a)
	_append_u32(out, overlay_b)
	out.append(overlay_c & 0xFF)
	_append_u32(out, overlay_d)

	for i in PET_FLAGS:
		_append_u32(out, pet_flags[i])

	var padded := scalars.slice(0, SCALARS)
	while padded.size() < SCALARS:
		padded.append(0)
	out.append_array(padded)

	for row in store:
		_append_u32(out, int(row["slot"]))
		_append_u32(out, int(row["price"]))
		_append_u32(out, int(row["base"]))
		_append_u32(out, int(row["increment"]))
		out.append(int(row["present"]) & 0xFF)

	_append_u32(out, timestamp)
	return out


## Parse a save. Returns null when the version is too old or the file is short (LoadGame's refusal).
static func from_bytes(bytes: PackedByteArray) -> TankSave:
	if bytes.size() < 18:
		return null
	var parsed := TankSave.new()
	parsed.version = _get_u32(bytes, 0x00)
	if parsed.version < MIN_VERSION:
		return null
	parsed.tank = _get_u32(bytes, 0x04)
	parsed.level = _get_u32(bytes, 0x08)
	parsed.tank_complete = int(bytes[0x0C])
	parsed.entity_enable = int(bytes[0x0D])
	var count := _get_u32(bytes, 0x0E)
	var at := 18
	for i in count:
		if at + 4 + OBJECT_SLOT > bytes.size():
			return null
		var class_id := _get_u32(bytes, at)
		parsed.entities.append({"class": class_id, "slot": bytes.slice(at + 4, at + 4 + OBJECT_SLOT)})
		at += 4 + OBJECT_SLOT
	if at + 1 > bytes.size():
		return null
	parsed.boss_present = int(bytes[at]) != 0
	at += 1
	if parsed.boss_present:
		if at + BOSS_SLOT > bytes.size():
			return null
		parsed.boss_object = bytes.slice(at, at + BOSS_SLOT)
		at += BOSS_SLOT
	if at + 2 > bytes.size():
		return null
	var text_length := int(bytes[at]) | (int(bytes[at + 1]) << 8)
	at += 2
	if at + text_length > bytes.size():
		return null
	parsed.overlay_text = bytes.slice(at, at + text_length).get_string_from_utf8()
	at += text_length
	if at + 21 > bytes.size():
		return null
	for i in 2:
		parsed.overlay_colors[i] = Color8(int(bytes[at]), int(bytes[at + 1]),
			int(bytes[at + 2]), int(bytes[at + 3]))
		at += 4
	parsed.overlay_a = _get_u32(bytes, at)
	parsed.overlay_b = _get_u32(bytes, at + 4)
	at += 8
	if at + 5 > bytes.size():
		return null
	parsed.overlay_c = int(bytes[at])
	parsed.overlay_d = _get_u32(bytes, at + 1)
	at += 5
	var need := PET_FLAGS * 4 + SCALARS + STORE_ROWS * STORE_ROW_BYTES + 4
	if at + need > bytes.size():
		return null
	for i in PET_FLAGS:
		parsed.pet_flags[i] = _get_u32(bytes, at)
		at += 4
	parsed.scalars = bytes.slice(at, at + SCALARS)
	at += SCALARS
	for i in STORE_ROWS:
		parsed.store[i] = {
			"slot": _signed32(_get_u32(bytes, at)),
			"price": _get_u32(bytes, at + 4),
			"base": _get_u32(bytes, at + 8),
			"increment": _signed32(_get_u32(bytes, at + 12)),
			"present": int(bytes[at + 16]),
		}
		at += STORE_ROW_BYTES
	parsed.timestamp = _get_u32(bytes, at)
	return parsed


# --- byte helpers -------------------------------------------------------------

## Two fields use -1 as their sentinel (`slot`, `increment`), so their reads sign-extend.
static func _signed32(value: int) -> int:
	return value - 4294967296 if value > 0x7FFFFFFF else value


static func _get_u32(bytes: PackedByteArray, at: int) -> int:
	if at < 0 or at + 4 > bytes.size():
		return 0
	return int(bytes[at]) | (int(bytes[at + 1]) << 8) | (int(bytes[at + 2]) << 16) \
		| (int(bytes[at + 3]) << 24)


static func _put_u32(bytes: PackedByteArray, at: int, value: int) -> void:
	bytes[at] = value & 0xFF
	bytes[at + 1] = (value >> 8) & 0xFF
	bytes[at + 2] = (value >> 16) & 0xFF
	bytes[at + 3] = (value >> 24) & 0xFF


static func _append_u32(bytes: PackedByteArray, value: int) -> void:
	var start := bytes.size()
	bytes.resize(start + 4)
	_put_u32(bytes, start, value)


## Copy `source` into `dest` at `at`, zero-filling to `length` (the fixed object slot).
static func _copy_into(dest: PackedByteArray, at: int, source, length: int) -> void:
	var blob: PackedByteArray = source
	for i in length:
		dest[at + i] = blob[i] if i < blob.size() else 0
