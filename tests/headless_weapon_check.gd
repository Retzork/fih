extends SceneTree
## Headless check for P4.10 weapons (Larva, laser spark, weapon HUD) and the G11 cue wiring.
##
##   & "<godot>" --headless --path . --script res://tests/headless_weapon_check.gd
##
## Covers: Larva spawn/fall/payout, the larvae->missiles->aliens click order, the laser
## spark on every resolved click, the weapon tier row binding (Q-0023 parameterisation),
## hunger/growth/pet/alien/wave cue sounds, and the particle lifetimes.

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const LarvaScript := preload("res://scripts/entities/larva.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_larva()
	_test_laser_and_order()
	_test_cues_and_particles()
	if _failures == 0:
		print("headless_weapon_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_weapon_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _new_level(seed_value: int = 99) -> Dictionary:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, seed_value)
	return {"sim": sim, "level": level}


func _teardown(ctx: Dictionary) -> void:
	ctx["level"].tank.shutdown()
	ctx["level"].free()
	ctx["sim"].free()


func _step(sim: Node, count: int) -> void:
	sim.flush_backlog()
	for i in count:
		sim.advance(SimScript.TICK_MS)


# P2.10 §5.5: fall despawn at y<64, lerp payout with shells at y<40.
func _test_larva() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	var totem := level.tank.spawn_larva(Vector2(200, 100), LarvaScript.Mode.FALL, 2.0, 0)
	_expect(totem != null, "a larva spawns")
	_expect(totem.phase == SimScript.Phase.PROJECTILES, "a larva ticks in PROJECTILES")
	var y0 := totem.position.y
	_step(ctx["sim"], 5)
	_expect(totem.position.y < y0, "the fall mode moves toward the top (%.1f -> %.1f)" % [y0, totem.position.y])
	totem.position.y = 62.0
	_step(ctx["sim"], 1)
	_expect(totem.dead, "the fall mode despawns below y 64")

	var shells_before := level._profile().shells
	var payout := level.tank.spawn_larva(Vector2(400, 100), LarvaScript.Mode.PAYOUT, 0.0, 1)
	payout.position = Vector2(400, 60)
	_step(ctx["sim"], 4)
	_expect(not payout.dead, "the payout mode lerps before paying out")
	var x1 := payout.position.x
	_step(ctx["sim"], 1)
	_expect(payout.position.x > x1, "the payout mode moves toward (550,30)")
	payout.position = Vector2(545, 45)
	_step(ctx["sim"], 8)
	_expect(payout.dead, "the payout mode despawns below y 40")
	_expect(level._profile().shells > shells_before, "the payout adds shells")
	_teardown(ctx)


# Click order + laser spark + tier row.
func _test_laser_and_order() -> void:
	_expect(LevelScript.laser_cell_for(2) == 0, "tier 2 is row 0 of LASERS")
	_expect(LevelScript.laser_cell_for(12) == 50, "tier 12 is row 5 of LASERS")
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.spawn_laser(Vector2(200, 200))
	_expect(level.laser_sparks.size() == 1, "a laser spark is recorded")
	_expect(level.laser_sparks[0]["pos"] == Vector2(160, 160),
		"the spark lands at click-40,40 (got %s)" % str(level.laser_sparks[0]["pos"]))
	_step(ctx["sim"], 5)
	_expect(level.laser_sparks.is_empty(), "the spark fades after 5 ticks")
	# Larvae are hit before missiles at the same point (P2.10 §1 order).
	var larva = level.tank.spawn_larva(Vector2(300, 250), LarvaScript.Mode.FALL, 0.0, 0)
	_expect(level.try_hit_larva(Vector2(300, 250)), "a larva is clickable")
	_expect(larva.dead, "a kind-0 larva is destroyed by the click")
	_teardown(ctx)


# Cue consumers (G11) + particles.
func _test_cues_and_particles() -> void:
	var ctx := _new_level()
	var level: Level = ctx["level"]
	level.spawn_particle(Vector2(100, 100), "smoke", 28)
	level.spawn_particle(Vector2(120, 120), "burst", 5)
	_expect(level.particles.size() == 2, "both particle kinds are recorded")
	_step(ctx["sim"], 5)
	_expect(level.particles.size() == 1, "the burst fades after 5 ticks, smoke remains")
	_step(ctx["sim"], 30)
	_expect(level.particles.is_empty(), "smoke fades after 28 ticks")
	level._on_wave_milestone("warning")
	_expect(level.sounds_played.has("SOUND_ROAR"), "the wave warning plays a sound")
	level._on_fish_hunger(1)
	_expect(level.sounds_played.has("SOUND_SLURP"), "hunger plays a chomp sound")
	level._on_fish_grew(null, 1)
	_expect(level.sounds_played.has("SOUND_GROW"), "growth plays the grow sound")
	level._on_pet_cue("pearl", Vector2.ZERO)
	_expect(level.sounds_played.has("SOUND_PEARL"), "a pearl cue plays the pearl sound")
	level._on_alien_cue("missile")
	_expect(level.sounds_played.has("SOUND_MISSLE"), "an alien missile cue plays")
	_teardown(ctx)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
