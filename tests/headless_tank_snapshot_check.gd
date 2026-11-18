extends SceneTree
## Headless check for the tank snapshot glue (P4.12, P2.13 notes #10/#11).
##
##   & "<godot>" --headless --path . --script res://tests/headless_tank_snapshot_check.gd
##
## Covers capture (fish only, header stamped, store rows and pet flags preserved), the record encoding
## (magic guard, every field), the save round trip through `TankSave`, restore into a fresh tank, and
## the deliberate exclusion of food/coins.

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const FoodScript := preload("res://scripts/entities/food.gd")
const TankSaveScript := preload("res://scripts/persistence/tank_save.gd")
const TankSnapshotScript := preload("res://scripts/persistence/tank_snapshot.gd")
const TankScalarsScript := preload("res://scripts/persistence/tank_scalars.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const SaveFilesScript := preload("res://scripts/persistence/save_files.gd")

var _failures := 0
var _checks := 0
var sim: Node


func _init() -> void:
	sim = SimScript.new()
	_test_capture()
	_test_record()
	_test_restore()
	_test_skips()
	_test_scalars()
	_test_level_save_load()
	sim.free()

	if _checks == 0:
		printerr("headless_tank_snapshot_check: no assertions ran")
		quit(1)
		return
	if _failures == 0:
		print("headless_tank_snapshot_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_tank_snapshot_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _test_capture() -> void:
	var tank := _tank(900)
	var guppy: Fish = tank.spawn_fish(FishScript.Species.GUPPY, Vector2(200.0, 250.0), 1, -1)
	guppy.fullness = 123
	guppy.food_points = 2
	tank.spawn_fish(FishScript.Species.OSCAR, Vector2(300.0, 220.0), 1, 1)
	var pellet: Food = FoodScript.create(Vector2(400.0, 250.0), 0, false, 0, 0, tank.rng)
	tank.spawn_at(pellet, SimScript.Phase.FOOD, pellet.position)

	var save: TankSave = TankSaveScript.new()
	save.pet_flags[3] = 1
	save.store[0] = {"slot": 6, "price": 1500, "base": 1500, "increment": 15, "present": 0}
	var captured: TankSave = TankSnapshotScript.capture(tank, 3, 2, save)
	_expect(captured.tank == 3 and captured.level == 2, "capture stamps the tank and level")
	_expect(captured.entities.size() == 2, "only the two fish are captured (got %d)"
		% captured.entities.size())
	_expect(captured.pet_flags[3] == 1, "the pet flags in the save are preserved")
	_expect(int(captured.store[0]["price"]) == 1500, "the store rows in the save are preserved")
	_expect(int(captured.entities[0]["class"]) == TankSnapshotScript.FISH_CLASS,
		"a captured entity uses the port's fish class")
	tank.shutdown()
	tank.free()


func _test_record() -> void:
	var state := {"species": 2, "stage": 1, "x": 123.5, "y": 222.25, "facing": -1,
		"fullness": 456, "food_points": 7}
	var slot := TankSnapshotScript.encode_fish(state)
	_expect(slot.size() == TankSaveScript.OBJECT_SLOT, "the record fills one object slot")
	_expect(slot.decode_u32(0) == TankSnapshotScript.MAGIC, "the record starts with the magic")
	var back: Dictionary = TankSnapshotScript.decode_fish(slot)
	_expect(int(back["species"]) == 2 and int(back["stage"]) == 1, "species and stage decode")
	_expect(is_equal_approx(float(back["x"]), 123.5) and is_equal_approx(float(back["y"]), 222.25),
		"the position decodes as floats")
	_expect(int(back["facing"]) == -1, "the facing decodes")
	_expect(int(back["fullness"]) == 456 and int(back["food_points"]) == 7,
		"hunger and growth points decode")
	var foreign := PackedByteArray()
	foreign.resize(TankSaveScript.OBJECT_SLOT)
	_expect(TankSnapshotScript.decode_fish(foreign).is_empty(),
		"a slot without the magic is not a fish record")


func _test_restore() -> void:
	var tank := _tank(901)
	tank.spawn_fish(FishScript.Species.GUPPY, Vector2(200.0, 250.0), 2, -1)
	var carnivore: Fish = tank.spawn_fish(FishScript.Species.OSCAR, Vector2(300.0, 220.0), 1, 1)
	carnivore.fullness = 777
	var save: TankSave = TankSnapshotScript.capture(tank, 3, 2)
	tank.shutdown()
	tank.free()

	# Through the real byte framing, not the in-memory object.
	var bytes := save.to_bytes()
	var reread: TankSave = TankSaveScript.from_bytes(bytes)
	_expect(reread != null, "the captured save parses back")
	if reread == null:
		return
	var fresh := _tank(902)
	_expect(fresh.entities_in(SimScript.Phase.FISH).is_empty(), "the fresh tank starts empty")
	var restored := TankSnapshotScript.restore(fresh, reread)
	_expect(restored == 2, "both fish are restored (got %d)" % restored)
	var fish := fresh.entities_in(SimScript.Phase.FISH)
	_expect(fish.size() == 2, "the tank holds two fish again")
	if fish.size() == 2:
		var stage_two := fish[0] as Fish
		var adult := fish[1] as Fish
		_expect(stage_two.stage == 2, "the first fish keeps its stage")
		_expect(stage_two.position == Vector2(200.0, 250.0), "the first fish keeps its position")
		_expect(adult.species == FishScript.Species.OSCAR, "the second fish keeps its species")
		_expect(adult.fullness == 777, "the second fish keeps its hunger")
		_expect(adult.facing == 1, "the second fish keeps its facing")
	_expect(fresh.pet_capacity == 2, "restore does not disturb the tank's other state")
	fresh.shutdown()
	fresh.free()


func _test_skips() -> void:
	var save: TankSave = TankSaveScript.new()
	var slot := PackedByteArray()
	slot.resize(TankSaveScript.OBJECT_SLOT)
	save.entities = [{"class": 0x02, "slot": slot}, {"class": 0x07, "slot": slot}]
	var tank := _tank(903)
	_expect(TankSnapshotScript.restore(tank, save) == 0, "non-fish entries are not restored")
	_expect(tank.entities_in(SimScript.Phase.FISH).is_empty(), "nothing was spawned for them")
	tank.shutdown()
	tank.free()


# --- helpers -----------------------------------------------------------------

## P2.13 §6.3: the scalar block's mapped fields survive a Level -> bytes -> Level trip.
func _test_scalars() -> void:
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 1200)
	level.money = 190
	level.food_quantity = 3
	level.food_quality = 2
	level.backdrop = 1
	level.alien_selection = 4
	level.wave.timer = 100
	level.tank.pet_capacity = 8
	level.star_potion_armed = true
	level.backdrop_tint = Color8(1, 2, 3, 4)

	var block := TankScalarsScript.capture(level)
	_expect(block.size() == TankScalarsScript.BLOCK_BYTES, "the block is 316 bytes")
	_expect(block.decode_u32(73) == 190, "money sits at +0x3F0 (offset 73)")
	_expect(block.decode_u32(308) == 3, "food quantity sits at offset 308")
	_expect(block.decode_u32(304) == 2, "food quality sits at offset 304")
	_expect(block.decode_u32(65) == 8, "pet capacity sits at +0x3E4 (offset 65)")
	_expect(block.decode_u32(5) == 4, "the wave selection sits at +0x2BC (offset 5)")
	_expect(block.decode_u32(9) == 2900, "the countdown is 3000 - the clock timer")
	_expect(int(block[101]) == 1, "the star potion flag sits at +0x440 (offset 101)")
	_expect(int(block[312]) == 1 and int(block[313]) == 2 and int(block[314]) == 3
		and int(block[315]) == 4, "the backdrop tint is the last four bytes")

	var other: Level = LevelScript.new()
	other.render = false
	other.setup(sim, 1201)
	TankScalarsScript.apply(block, other)
	_expect(other.money == 190, "money restores")
	_expect(other.food_quantity == 3 and other.food_quality == 2, "the food levels restore")
	_expect(other.tank.pet_capacity == 8, "the pet capacity restores")
	_expect(other.backdrop == 1 and other.alien_selection == 4, "backdrop and wave selection restore")
	_expect(other.wave.timer == 100, "the clock returns to its saved tick")
	_expect(other.star_potion_armed, "the armed star potion survives")
	_expect(other.backdrop_tint == Color8(1, 2, 3, 4), "the backdrop tint survives")

	level.money = 12000000
	level.food_quantity = 20
	var clamped := TankScalarsScript.capture(level)
	_expect(clamped.decode_u32(73) == 9999999, "money clamps to the AddMoney ceiling")
	_expect(clamped.decode_u32(308) == 9, "food quantity clamps to 9")
	level.tank.shutdown()
	level.free()
	other.tank.shutdown()
	other.free()


## The level-level pair: F5/F9 in method form, end to end through disk.
func _test_level_save_load() -> void:
	var path := "user://save_check/adv3.dat"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 1300)
	level.money = 250
	level.food_quantity = 4
	level.tank.tank_index = 3
	level.level_index = 2
	level.tank_store.append({"slot": 6, "price": 1500, "base": 1500, "increment": 15, "present": 0})
	level.egg_pieces = 3
	_expect(level.save_game(path) == OK, "save_game writes the file")
	var disk: TankSave = SaveFilesScript.read_tank_save(path)
	_expect(disk != null, "the written file parses")
	if disk != null:
		_expect(disk.tank == 3 and disk.level == 2, "the header carries tank and level")
		_expect(int(disk.store[0]["price"]) == 1500, "the store table is in the file")
		_expect(disk.scalars.decode_u32(73) == 250, "the money is in the scalar block")
		_expect(disk.entities.size() == LevelScript.STARTING_FISH, "the fish are in the file")
		_expect(disk.scalars.decode_u32(TankScalarsScript.OFF_EGG_PIECES) == 3,
			"the egg progress is in the scalar block")

	level.money = 1
	level.food_quantity = 1
	level.egg_pieces = 1
	for entity in level.tank.entities_in(Sim.Phase.FISH):
		level.tank.despawn(entity)
	_expect(level.load_game(path), "load_game reads the file back")
	_expect(level.money == 250, "the wallet restores")
	_expect(level.egg_pieces == 3, "the egg progress restores (D-0037)")
	_expect(level.food_quantity == 4, "the food quantity restores")
	_expect(level.tank_store.size() > 0 and int(level.tank_store[0]["price"]) == 1500,
		"the store table restores")
	_expect(level.tank.entities_in(Sim.Phase.FISH).size() == LevelScript.STARTING_FISH,
		"the fish are rebuilt, not merged")
	_expect(not level.load_game("user://save_check/missing.dat"), "a missing save returns false")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	level.tank.shutdown()
	level.free()


func _tank(seed_value: int) -> Tank:
	var tank := TankScript.new()
	tank.setup(sim, seed_value)
	return tank


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
