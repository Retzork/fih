class_name TankSnapshot
extends RefCounted
## Tank <-> save glue (P4.12, P2.13 implementation notes #10/#11).
##
## The framing in `TankSave` carries the original's `u32 class id + 0x140-byte object slot` stream.
## The original writes a raw memory image into that slot; the remake instead writes a **defined
## record** (a documented divergence, P2.13 note #11) and only for state a load cannot rebuild. Today
## that means fish: species, stage, position, facing, hunger and growth points.
##
## Food, coins, projectiles and particles are never captured - a load rebuilds them, which is exactly
## what note #11 asks for. Store rows and the 24 pet flags travel through `TankSave` itself.
##
## The 316-byte scalar block (money, food quantity, wave state) is not mapped yet: its fields are
## bound in P2.13 §6.3 but the offsets-to-tank mapping is a later step (Q-0029).

const FISH_CLASS := 0x01
## `"FSH1"`: proves the slot is a port record and not an original memory image.
const MAGIC := 0x46534831
const RECORD_BYTES := 28


## Copy the tank's live fish into `save`'s entity stream. Store rows and pet flags are the caller's
## (they live in `save` already); `tank_no`/`level_no` stamp the header.
static func capture(tank_node, tank_no: int, level_no: int, save: TankSave = null) -> TankSave:
	var out: TankSave = save if save != null else TankSave.new()
	out.tank = tank_no
	out.level = level_no
	out.entities.clear()
	for entity in tank_node.entities_in(Sim.Phase.FISH):
		var fish := entity as Fish
		if fish == null or fish.dead:
			continue
		out.entities.append({"class": FISH_CLASS, "slot": encode_fish(fish.to_state())})
	return out


## Rebuild the captured fish through `Tank.spawn_fish`. Returns how many were restored. Entries that
## are not port fish records are skipped: their bodies belong to the entity that owns them.
static func restore(tank_node, save: TankSave) -> int:
	var restored := 0
	for entry in save.entities:
		if int(entry["class"]) != FISH_CLASS:
			continue
		var state := decode_fish(entry["slot"])
		if state.is_empty():
			continue
		if Fish.from_state(tank_node, state) != null:
			restored += 1
	return restored


## A fish record: magic, species, stage, x, y, facing, fullness, food points (little-endian).
static func encode_fish(state: Dictionary) -> PackedByteArray:
	var slot := PackedByteArray()
	slot.resize(TankSave.OBJECT_SLOT)
	slot.encode_u32(0, MAGIC)
	slot.encode_u32(4, int(state.get("species", 0)))
	slot.encode_u32(8, int(state.get("stage", 0)))
	slot.encode_float(12, float(state.get("x", 0.0)))
	slot.encode_float(16, float(state.get("y", 0.0)))
	slot.encode_s32(20, int(state.get("facing", 1)))
	slot.encode_s32(24, int(state.get("fullness", 0)))
	slot.encode_s32(28, int(state.get("food_points", 0)))
	return slot


## Inverse of `encode_fish`; empty when the slot is not a port fish record.
static func decode_fish(slot: PackedByteArray) -> Dictionary:
	if slot.size() < RECORD_BYTES or slot.decode_u32(0) != MAGIC:
		return {}
	return {
		"species": slot.decode_u32(4),
		"stage": slot.decode_u32(8),
		"x": slot.decode_float(12),
		"y": slot.decode_float(16),
		"facing": slot.decode_s32(20),
		"fullness": slot.decode_s32(24),
		"food_points": slot.decode_s32(28),
	}
