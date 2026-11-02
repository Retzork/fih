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
	]
