class_name TankScalars
extends RefCounted
## A typed view over the 316-byte scalar block (P2.13 §6.3), plus the part of it the port maps today.
##
## The offsets below follow the note's field order byte for byte; the arithmetic closes exactly at
## 316. Fields the port has no home for are still written as zeroes in their slots, so the block keeps
## its size and order and can be compared against a real save once every field is bound.
##
## Mapped so far: money (`+0x3F0`), food quality/quantity (`5e89dc`/`5df58c`), pet capacity
## (`+0x3E4`), backdrop index (`+0x3E8`), the wave selection and its countdown (`+0x2BC`/`+0x2C0`),
## the star potion flag (`+0x440`) and the backdrop tint. The 27-dword run, the tutorial block and the spawn points are left as zeroes.

const BLOCK_BYTES := 316

const OFF_BONUS_ACTIVE := 0          # +0x2A4 u8
const OFF_BONUS_TICK := 1            # +0x2A8 u32
const OFF_ALIEN_TYPE := 5            # +0x2BC u32
const OFF_ALIEN_COUNTDOWN := 9       # +0x2C0 u32
const OFF_TIMER_1 := 13              # +0x2C4 u32
const OFF_TIMER_2 := 17              # +0x2C8 u32
const OFF_SPAWN_POINTS := 21         # +0x2CC..+0x2D8, 4 x u32
const OFF_STORE_COUNT := 37          # +0x2DC u32
const OFF_ELAPSED_RUN := 41          # +0x3B0..+0x3BC, 4 x u32
const OFF_LAST_FEED := 57            # +0x3C0 u32
const OFF_LAST_FIRE := 61            # +0x3C4 u32
const OFF_PET_CAPACITY := 65         # +0x3E4 u32
const OFF_BACKDROP := 69             # +0x3E8 u32
const OFF_MONEY := 73                # +0x3F0 u32
const OFF_BONUS_SHELLS := 77         # +0x3F4 u32
const OFF_BONUS_END_DELAY := 81      # +0x3F8 u32
const OFF_ELAPSED := 85              # +0x3FC u32
const OFF_UNKNOWN_A := 89            # +0x2AC i32
const OFF_UNKNOWN_B := 93            # +0x2B0 u32
const OFF_EGG_PIECES := 97           # +0x43C u32
const OFF_FLAG_440 := 101            # +0x440 u8
const OFF_RUN_27 := 102              # +0x444..+0x4AC, 27 x u32
const OFF_CHECKBOXES := 210          # +0x4FC..+0x500, 5 x u8
const OFF_TUTORIAL := 215            # +0x4B0..+0x4E5, 54 x u8
const OFF_EGG_HINT := 269            # +0x4E6 u8
const OFF_EGG_IDLE := 270            # +0x4E8 u32
const OFF_UNKNOWN_C := 274           # +0x4F0 u32
const OFF_UNKNOWN_D := 278           # +0x4F4 u8
const OFF_WADSWORTH := 279           # 5e89d0/d4/d8, 3 x u32
const OFF_HELD_PELLET := 291         # 5e89c0/c4/c8, 3 x u32
const OFF_MERYL := 303               # 5e89cc u8
const OFF_FOOD_QUALITY := 304        # 5e89dc u32
const OFF_FOOD_QUANTITY := 308       # 5df58c u32
const OFF_TINT := 312                # 4 bytes

## The wave clock counts up from 0; the field is the remaining countdown (3000 at the wave start).
const WAVE_TICKS := 3000


## Capture the mapped fields from a `Level` into a fresh 316-byte block.
static func capture(level) -> PackedByteArray:
	var block := PackedByteArray()
	block.resize(BLOCK_BYTES)
	block.fill(0)
	var tank = level.tank
	var wave = level.wave
	block.encode_u32(OFF_MONEY, clampi(int(level.money), 0, 9999999))
	block.encode_u32(OFF_FOOD_QUALITY, clampi(int(level.food_quality), 0, 2))
	block.encode_u32(OFF_FOOD_QUANTITY, clampi(int(level.food_quantity), 1, 9))
	block.encode_u32(OFF_PET_CAPACITY, int(tank.pet_capacity))
	block.encode_u32(OFF_BACKDROP, int(level.backdrop))
	block.encode_u32(OFF_ALIEN_TYPE, int(level.alien_selection))
	block.encode_u32(OFF_ALIEN_COUNTDOWN, countdown_for(wave))
	block.encode_u32(OFF_STORE_COUNT, _store_row_count(level))
	# `+0x43C` is the tank's egg progress (P2.13 §6.3 row 19, "starts at 1"); the dome reads it, so it
	# has to travel with the save or a load would show the pre-load tank's piece count (D-0037).
	block.encode_u32(OFF_EGG_PIECES, clampi(int(level.egg_pieces), Progression.EGG_PIECES_AT_START,
		Progression.EGG_PIECES_TO_COMPLETE))
	# `+0x440` is the star potion's armed flag (P2.3 §2); the note's §6.3 calls it unknown
	# because the finalizer clears it, but the feeding path binds it.
	block[OFF_FLAG_440] = 1 if level.star_potion_armed else 0
	var tint: Color = level.backdrop_tint
	block[OFF_TINT] = tint.r8
	block[OFF_TINT + 1] = tint.g8
	block[OFF_TINT + 2] = tint.b8
	block[OFF_TINT + 3] = tint.a8
	return block


## Restore the mapped fields into a `Level` whose tank and wave clock already exist.
static func apply(block: PackedByteArray, level) -> void:
	if block.size() < BLOCK_BYTES:
		return
	level.money = block.decode_u32(OFF_MONEY)
	level.food_quality = clampi(block.decode_u32(OFF_FOOD_QUALITY), 0, 2)
	level.food_quantity = clampi(block.decode_u32(OFF_FOOD_QUANTITY), 1, 9)
	level.tank.pet_capacity = block.decode_u32(OFF_PET_CAPACITY)
	level.backdrop = block.decode_u32(OFF_BACKDROP)
	level.alien_selection = block.decode_u32(OFF_ALIEN_TYPE)
	level.star_potion_armed = int(block[OFF_FLAG_440]) != 0
	# Saves written before this mapping carry zeroes here, which clamp to the starting piece.
	level.egg_pieces = clampi(block.decode_u32(OFF_EGG_PIECES), Progression.EGG_PIECES_AT_START,
		Progression.EGG_PIECES_TO_COMPLETE)
	level.backdrop_tint = Color8(int(block[OFF_TINT]), int(block[OFF_TINT + 1]),
		int(block[OFF_TINT + 2]), int(block[OFF_TINT + 3]))
	if level.wave != null:
		level.wave.timer = clampi(WAVE_TICKS - block.decode_u32(OFF_ALIEN_COUNTDOWN), 0, WAVE_TICKS)


## The saved countdown for a clock: `3000 - timer`, or 0 when there is no clock.
static func countdown_for(wave) -> int:
	if wave == null:
		return 0
	return clampi(WAVE_TICKS - int(wave.timer), 0, WAVE_TICKS)


static func _store_row_count(level) -> int:
	var count := 0
	for row in level.tank_store:
		if int(row.get("slot", -1)) >= 0:
			count += 1
	return count
