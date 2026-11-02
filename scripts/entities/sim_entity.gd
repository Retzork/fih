class_name SimEntity
extends Node2D
## Base for everything the simulation ticks (P4.3).
##
## An entity does not own its registration, its lifetime, or its clock - the tank does. That is the
## original's structure too: objects live in per-type lists on `Tank` and are advanced by the tank's
## update, which is why SPECS.md §1.4 makes list membership the thing that despawn unregisters from.
##
## Subclasses implement `_advance()`. They must not use `_process` or `_physics_process`: `Sim` calls
## `_sim_tick()` once per fixed 10 ms slice, in the phase the tank registered them in
## (docs/ARCHITECTURE.md §1).
##
## Despawning is `despawn()`; it unregisters first and frees at the end of the frame, so an entity may
## despawn itself from inside `_advance()` (death, being eaten, being sold).

## Phase this entity ticks in, assigned by `Tank.spawn()`. -1 means "not registered".
var phase := -1
## Host tank (typed as Node to avoid a Tank <-> SimEntity class cycle). Queries go through it.
var tank: Node = null
## Logic ticks this entity has been alive; the original keeps per-object counters like this.
var ticks_alive := 0
## Set by `despawn()`; `Sim` skips the entity from that point even if the free is still pending.
var dead := false


## Called by the tank, never by gameplay code.
func _sim_tick() -> void:
	if dead:
		return
	if tank != null and tank.is_paused():
		return
	ticks_alive += 1
	_advance()


## One logic tick. Override this; call `super()` only if a subclass genuinely wants the parent pass.
func _advance() -> void:
	pass


## Remove this entity from the tank and the tick. Safe to call twice.
func despawn() -> void:
	if dead:
		return
	dead = true
	if tank != null:
		tank.despawn(self)
	else:
		queue_free()


## A freed entity must not stay in the tick. The tank unregisters on `despawn()`; this is the net for
## any path that frees the node directly (level teardown, a scene change).
func _exit_tree() -> void:
	# `is_instance_valid`: a tank teardown frees children, so the host may already be gone.
	if is_instance_valid(tank) and tank.has_method("untrack"):
		tank.untrack(self)
