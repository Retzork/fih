class_name Tank
extends Node2D
## Tank - the level host (P4.3). It owns entity lifetime, tick registration, the seeded RNG and the
## shared pause gate.
##
## Entities never register themselves: `spawn()` assigns the phase, parents the node to that phase's
## draw layer and registers it with `Sim`, so "every entity is in exactly one phase" is true by
## construction (docs/ARCHITECTURE.md §1).
##
## The tank is a Node2D, not a screen. A screen (P4.4/P4.5) mounts it, so a screen change tears the
## level down with it; `shutdown()` is the explicit path for anything that keeps the tank around.
##
## RNG: one seeded stream per tank (SPECS.md §9.8). Matching the original's sequence is explicitly not
## a goal, but reproducibility is, so nothing here may use the global `randi()`/`randf()`.

signal entity_spawned(entity: SimEntity)
signal entity_despawned(entity: SimEntity)

## Typed spawn helper; preloaded so `Tank` does not depend on global class registration order.
const FishScript := preload("res://scripts/entities/fish.gd")
## Coin spawner helper, preloaded for the same reason.
const CoinScript := preload("res://scripts/entities/coin.gd")
## Projectile spawner helper, preloaded for the same reason.
const ProjectileScript := preload("res://scripts/entities/projectile.gd")
## Larva spawner helper (P2.10 §5.5).
const LarvaScript := preload("res://scripts/entities/larva.gd")
## Corpse spawner helper (dead-fish bodies, P2.4 §4).
const DeadFishScript := preload("res://scripts/entities/dead_fish.gd")
## Pet spawner helper (P2.7).
const PetScript := preload("res://scripts/entities/pet.gd")
## Alien spawners (P2.8).
const AlienScript := preload("res://scripts/entities/alien.gd")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")
## The boss (Cyrax) spawner.
const BossScript := preload("res://scripts/entities/boss.gd")

## The Sim driver (injected, so headless checks can pass their own instance).
var sim: Node = null
## Optional node whose `gameplay_paused` flag gates the level (Game in the real app, null in tests).
var pause_source: Node = null
## Level-local pause - the original's `Tank+0x94`.
var paused := false
## Per-level RNG; the only source of randomness inside a tank.
var rng := RandomNumberGenerator.new()
## Live entities, in spawn order.
var entities: Array[SimEntity] = []

## Mode flags the fish/coin rules read (P4.11 sets the real values). `virtual_tank` mirrors the
## original's mode 5 (`tank+0x87c`): it changes growth thresholds, nutrition caps and coin pacing.
var virtual_tank := false
## `+0x14C` difficulty multiplier used only by the mode-5 coin threshold adjustment.
var coin_difficulty_value := 0
## The original's `Tank+0x500` pacing gate; only meaningful in Virtual Tank.
var coin_pacing_gate_value := false
## Demo mode: coins expire after 108 ticks instead of 20 (P2.5 §5); P4.11 sets it.
var demo_mode := false
## `FUN_00537B80` hint flag: a hinted tank holds coins 150 ticks.
var coin_hint_active := false
## `Tank+0x16C`; purpose open, only the coin expiry reads it (200 ticks).
var tank_flag_16c := false
## `Tank+0x3C8`: tank index; 5 is the boss tank, whose slot-81 pet action is skipped.
var tank_index := 0
## Hostile aliens on the field: they freeze every pet's slot-81 action except Stanley's.
var aliens_present := false
## `Tank+0xD0` (Penta list) non-empty: Stinky/Clyde stop taking star coins.
var penta_present := false
## `Tank+0xB8`/`+0xF4` non-empty: the coin sources Stinky's hide counter watches.
var pet_sources_busy := false
## A boss is alive: it freezes the wave clock and suppresses alien death Diamonds.
var boss_alive := false
## `Tank+0x178`: draw a health bar over ordinary aliens (Cyrax always has one). The binary's writer
## was not located (P2.9 §5, Q-0058), so the remake keeps it configurable; it defaults **off** like
## the shipped gate, whose ordinary bars only appeared with this flag armed (R62). Tank 5 still
## suppresses the ordinary bars, and Cyrax bypasses the flag.
var show_alien_health := false
## Pet slots (2 normally); the boss forces 10, which also sets the shot damage (P2.9 §10).
var pet_capacity := 2
## A live boss freezes the wave clock.
var wave_frozen := false
## After the boss dies, waves never resume.
var waves_disabled := false
## `Tank+0x444`: logic ticks since the level started. Blip's instant unlock reads it (EV-0094).
var age_ticks := 0
## `DAT_005e89d0`/`+0xD4`/`+0xD8` (EV-0090/EV-0144, tank-serialized): the hidden-Wadsworth count and
## his mouth point. While the count is non-zero, a stage 0/1 fish with `+0x229` steers to the mouth
## instead of seeking food (p2.3 §6).
var wadsworth_count := 0
var wadsworth_mouth := Vector2.ZERO
## `Tank+0x2E0 < Tank+0x2DC`: the store still hides rows, so Blip's unlock (EV-0094) has work to do.
var store_locked := false

var _layers: Dictionary = {}


## Wire the driver and seed the level. Call before spawning.
func setup(sim_node: Node, seed_value: int = 0) -> void:
	sim = sim_node
	rng.seed = seed_value


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func is_paused() -> bool:
	if paused:
		return true
	# Direct property access on purpose: a renamed flag should fail loudly, not read as "not paused".
	return pause_source != null and bool(pause_source.gameplay_paused)


## Register `entity` for `phase` and parent it to that phase's layer. Returns the entity.
func spawn(entity: SimEntity, phase: int) -> SimEntity:
	entity.tank = self
	entity.phase = phase
	layer_for(phase).add_child(entity)
	entities.append(entity)
	if sim != null:
		sim.register_phase(phase, entity)
	entity_spawned.emit(entity)
	return entity


## Spawn at a position (the common case: the spawner already knows where the object goes).
func spawn_at(entity: SimEntity, phase: int, position: Vector2) -> SimEntity:
	entity.position = position
	return spawn(entity, phase)


## Spawn a Fish through the level's one RNG stream (the original's per-species play ctors).
func spawn_fish(species: int, position: Vector2, stage: int = -1, facing: int = 0) -> Fish:
	var fish: Fish = FishScript.create(species, position, rng, stage, facing, virtual_tank)
	return spawn_at(fish, Sim.Phase.FISH, position) as Fish


## Spawn a coin. Coins ride the contact phase (see `Coin` header) and draw above the particles.
func spawn_coin(kind: int, position: Vector2) -> Coin:
	var coin: Coin = CoinScript.create(kind, position)
	return spawn_at(coin, Sim.Phase.COLLISION, position) as Coin


## Spawn an alien projectile. `target` is the homing victim, which receives the `+0x98`
## back-pointer when it supports `lock_projectile()` (P2.10 §5.1).
func spawn_projectile(kind: int, position: Vector2, target: Node2D = null) -> Projectile:
	var shot: Projectile = ProjectileScript.create(kind, position, target)
	spawn_at(shot, Sim.Phase.PROJECTILES, position)
	if target != null and target.has_method("lock_projectile"):
		target.lock_projectile(shot)
	return shot


## Spawn a larva (P2.10 §5.5). No system spawns one yet (Q-0023); the entity and the
## click order exist so a spawner can be bound without guessing one.
func spawn_larva(position: Vector2, mode: int = 0, vy: float = 1.5, hit_kind: int = 0) -> Larva:
	var larva: Larva = LarvaScript.create(position, mode, vy, hit_kind)
	return spawn_at(larva, Sim.Phase.PROJECTILES, position) as Larva


## Spawn a food pellet through the tank stream (Zorf's drop, P2.7 §4.5). `landed` is the play ctor's
## `param_4`, i.e. `Food+0x190`: only Angie's food re-lay passes true (EV-0161), and such a pellet
## enters `Food::Update`'s bob instead of falling.
func spawn_food(position: Vector2, food_kind: int = 0, quality: int = 0, landed: bool = false) -> Food:
	const FoodScript := preload("res://scripts/entities/food.gd")
	var pellet: Food = FoodScript.create(position, food_kind, landed, 0, quality, rng)
	return spawn_at(pellet, Sim.Phase.FOOD, position) as Food


## Spawn the corpse a dead fish leaves (P2.4 §4). It sinks in the PARTICLES phase and emits
## `successor_requested` when its death animation ends; the level spawns the live successor.
## `corpse_id` is the dying fish's stage (`+0x1A4`); the corpse starts with its own stage counter
## at 125 and sinks until that reaches 0 (EV-0052/EV-0053).
func spawn_dead_fish(
	species: int,
	corpse_id: int,
	position: Vector2,
	facing: int = 1,
	vx: float = 0.0,
	vy: float = 0.0,
	speed: float = DeadFishScript.SPEED_DIVISOR
) -> DeadFish:
	var corpse: DeadFish = DeadFishScript.create(species, corpse_id, position, facing, vx, vy, speed)
	return spawn_at(corpse, Sim.Phase.PARTICLES, position) as DeadFish


## Spawn a pet. Stinky's fixed lane is applied by the ctor, so the spawn keeps its own y.
## `transformed` is Presto's `FUN_004F89A0` swap: the target is a real pet of its own index that
## inherits the 360-tick recharge (`+0x230`/`+0x1C8` set, EV-0100).
func spawn_pet(index: int, position: Vector2, transformed: bool = false) -> Pet:
	var pet: Pet = PetScript.create(index, position, rng, transformed)
	return spawn_at(pet, Sim.Phase.PETS, pet.position) as Pet


## Spawn an alien of `kind` (P2.8). The wave clock only asks; the level calls this.
func spawn_alien(kind: int, position: Vector2) -> Alien:
	var alien: Alien = AlienScript.create(kind, position)
	return spawn_at(alien, Sim.Phase.ALIENS, position) as Alien


## Spawn the wave clock (one per level).
func spawn_wave_clock() -> WaveClock:
	var clock: WaveClock = WaveClockScript.new()
	return spawn_at(clock, Sim.Phase.CLOCK, Vector2.ZERO) as WaveClock


func alien_count() -> int:
	var live := 0
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead and entity.phase == Sim.Phase.ALIENS:
			live += 1
	return live


func projectile_count() -> int:
	var live := 0
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead and entity.phase == Sim.Phase.PROJECTILES:
			live += 1
	return live


## Shot damage: `3 * pet_capacity` (6 normally, 30 at the boss's forced 10 - SPECS §3.6).
func shot_damage() -> int:
	return 3 * pet_capacity


## Spawn the Cyrax boss with `hp = 5000 - 125 * clamp(counter - 1, 0, 20)`, freeze the waves and
## force the pet capacity to 10 (P2.9 §10).
func spawn_boss(counter: int, position: Vector2) -> Boss:
	var boss: Boss = BossScript.create(counter, position)
	var spawned := spawn_at(boss, Sim.Phase.ALIENS, boss.position) as Boss
	boss_alive = true
	wave_frozen = true
	pet_capacity = BossScript.FORCED_PET_CAPACITY
	return spawned


## Unregister and free. Called by `SimEntity.despawn()`; safe to call directly.
func despawn(entity: SimEntity) -> void:
	entity.dead = true
	untrack(entity)
	entities.erase(entity)
	entity_despawned.emit(entity)
	entity.queue_free()


## Remove from the tick without touching the node - used by `despawn()` and by
## `SimEntity._exit_tree()` when something else frees the node.
func untrack(entity: SimEntity) -> void:
	if sim != null:
		sim.unregister(entity)


## Draw layer for a phase, created on first use. Layers are ordered by `_layer_order()`.
func layer_for(phase: int) -> Node2D:
	if _layers.has(phase):
		return _layers[phase]
	var layer := Node2D.new()
	layer.name = "Layer%d" % phase
	layer.z_index = _layer_order().find(phase)
	add_child(layer)
	_layers[phase] = layer
	return layer


## Level teardown: unregister every entity, free them, and drop pending sim time so a hitch cannot
## pop the first frames of the next level (docs/ARCHITECTURE.md §6).
func shutdown() -> void:
	for entity in entities.duplicate():
		despawn(entity)
	entities.clear()
	# The boss is gone with the rest, so its fight flags go too (a stray boss_alive would keep the
	# wave clock frozen forever).
	boss_alive = false
	wave_frozen = false
	pet_capacity = 2
	# Level-scoped globals: a hidden Wadsworth cannot outlive the level he was hidden in.
	wadsworth_count = 0
	wadsworth_mouth = Vector2.ZERO
	age_ticks = 0
	if sim != null:
		sim.flush_backlog()


## Entities ticking in one phase, for system queries (fish near a pellet, live aliens, coin list).
func entities_in(phase: int) -> Array[SimEntity]:
	var found: Array[SimEntity] = []
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead and entity.phase == phase:
			found.append(entity)
	return found


## Nearest pellet to `from`, or null. Fish apply their own acceptance rules (P2.3 §7.4), so this
## deliberately does not filter by species diet or the pellet's inedible countdown.
func nearest_food(from: Vector2) -> Food:
	var best: Food = null
	var best_distance := INF
	for entity in entities:
		if not is_instance_valid(entity) or entity.dead or entity.phase != Sim.Phase.FOOD:
			continue
		var pellet := entity as Food
		if pellet == null:
			continue
		var distance := from.distance_squared_to(pellet.position)
		if distance < best_distance:
			best_distance = distance
			best = pellet
	return best


## The original's "target/food list non-empty" predicate (`FUN_004DA780`): fish suppress the coin
## scheduler while any pellet exists (P2.2 §5.4).
func food_count() -> int:
	var count := 0
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead and entity.phase == Sim.Phase.FOOD:
			if entity is Food:
				count += 1
	return count


## One roll from the tank stream in `rand%limit` shape, for entities that must not hold the RNG.
## Live coins, for collectors and the level-end "collect all" sweep (P2.5 §5).
## Every live corpse (P2.4 §4). Angie targets these (P2.7 §4.19).
func corpses() -> Array[DeadFish]:
	var found: Array[DeadFish] = []
	for entity in entities:
		if not is_instance_valid(entity) or entity.dead:
			continue
		var corpse := entity as DeadFish
		if corpse != null:
			found.append(corpse)
	return found


func coins() -> Array[Coin]:
	var found: Array[Coin] = []
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead and entity.phase == Sim.Phase.COLLISION:
			var coin := entity as Coin
			if coin != null:
				found.append(coin)
	return found


func coin_count() -> int:
	return coins().size()


## Live fish, i.e. `Tank+0xA0`'s list - the one the defeat check tests (EV-0249). A fish leaves this
## list the moment it dies: the corpse replaces it.
func fish() -> Array[Fish]:
	var found: Array[Fish] = []
	for entity in entities:
		if not is_instance_valid(entity) or entity.dead:
			continue
		var swimmer := entity as Fish
		if swimmer != null:
			found.append(swimmer)
	return found


func randi_below(limit: int) -> int:
	if limit <= 1:
		return 0
	return rng.randi_range(0, limit - 1)


func coin_difficulty() -> int:
	return coin_difficulty_value


func coin_pacing_gate() -> bool:
	return coin_pacing_gate_value


func entity_count() -> int:
	var live := 0
	for entity in entities:
		if is_instance_valid(entity) and not entity.dead:
			live += 1
	return live


## Back-to-front draw order. Resolved at runtime because `Sim.Phase` lives on an autoload.
func _layer_order() -> Array:
	return [
		Sim.Phase.FOOD,
		Sim.Phase.FISH,
		Sim.Phase.PETS,
		Sim.Phase.ALIENS,
		Sim.Phase.PROJECTILES,
		Sim.Phase.PARTICLES,
		# Coins tick in the contact phase and draw last: they are clickable, and the original draws
		# them after the tank contents.
		Sim.Phase.COLLISION,
	]
