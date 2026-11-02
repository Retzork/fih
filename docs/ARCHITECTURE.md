# Architecture (Phase 4 start)

Status: **P4.1-P4.2 complete; P4.3 in progress** (2026-11-02). This is the design the P4 tasks build against, derived from
[`SPECS.md`](SPECS.md) (behaviour) and [`PIPELINE.md`](PIPELINE.md) (assets). It is deliberately small:
it fixes the tick model, the resource registry, the autoload set and the coupling rules, and leaves
every system to its own P4 task.

What exists after P4.3's Fish pass: the boot scene, four autoloads, the project settings that make the
remake a 640x480 pixel game, the committed content manifest resolving all 326 ids into typed handles,
the entity/tank seam, `Food`, and `Fish` for all seven species. Four headless checks cover the tick
driver, the content registry, the entity seam/Food, and Fish. There is still no playable scene,
rendering, economy or HUD.

## 1. The tick contract

`Sim` (`scripts/autoload/sim.gd`) is the **only** driver of simulation time. It reproduces the
original loop (SPECS.md §1.1, P2.1/EV-0034):

| rule | value | why |
| --- | --- | --- |
| logic slice | `TICK_MS` = 10.0 ms | the `SexyAppBase` ctor constant (100 Hz) |
| slices per rendered frame | at most 10 | the original pumps at most 10 updates per `Process()` |
| backlog clamp | 1000 ms | the original rewinds its `last` stamp instead of catching up further |
| damping factor | `UPDATE_MULTIPLIER` = 0.85 | `mUpdateMultiplier`, for consumers that smooth motion |

`Sim._process(delta)` calls `advance(delta * 1000)`; `advance()` is pure with respect to the scene
tree, which is what makes it testable headlessly.

**Q-0034 is still open** (100 Hz from the ctor vs ~36 Hz from the gameplay timer calibrations in
P2.7-P2.9). `TICK_MS`/`TICKS_PER_SECOND` are therefore the *single* place the rate is defined: no
subsystem may hard-code a rate, convert ticks to seconds, or use `delta` inside simulation code. When
P5.3 settles the rate, it is a two-line change plus a re-tune.

**Never use `_physics_process` for gameplay.** Godot's physics tick is a second, independent clock
with its own catch-up cap; mixing the two would make the wave clock's pause contract and the pet
gates unverifiable. `_process` on ordinary nodes is fine for presentation only (label animation,
camera smoothing).

### Phase order

Systems register a node and implement `_sim_tick()`:

```gdscript
Sim.register_phase(Sim.Phase.FISH, self)

func _sim_tick() -> void:
    ...
```

One tick runs every phase, in order: `CLOCK → FISH → PETS → ALIENS → PROJECTILES → COLLISION → FOOD →
PARTICLES` (SPECS.md §9.1). The order is load-bearing: the wave countdown must advance before aliens
move, pets read the same tick counters, and collection resolves before food expires. A system that
runs itself elsewhere breaks those contracts, so the registry is the review checkpoint for every new
entity type.

`_sim_tick()` may despawn its own node (sell, transform, death); `Sim` indexes the bucket rather than
iterating it and skips freed registrants. Nodes must `Sim.unregister(self)` in `_exit_tree()` - the
"freed node" path exists for robustness, not as the normal route.

## 2. Project settings that are part of the contract

| setting | value | reason |
| --- | --- | --- |
| `display/window/size/viewport_width` / `height` | 640 / 480 | the original's logical space (P2.1) |
| `window/stretch/mode` / `aspect` | `canvas_items` / `keep` | integer-friendly scaling, no distortion |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (nearest) | pixel art (Q-0005) |
| `run/main_scene` | `res://scenes/main.tscn` | boot scene |
| `[autoload]` | `Content`, `Sim`, `Game`, `Screens` (in that order) | see §3 |

The 3D physics engine setting still reads Jolt; nothing in the remake uses 3D physics - the original
has no physics engine at all (movement is integer/float integration in `Update`). Leave it alone
rather than churning the file.

## 3. Autoloads and the scene tree

Four autoloads, each with one job:

| autoload | owns | does not own |
| --- | --- | --- |
| `Content` | the resource registry and the three load phases | gameplay state, screens, entity data |
| `Sim` | the tick driver, the phase registry, tick counters | any entity or system state |
| `Game` | active mode, save-file stems, the shared gameplay pause gate | level state, screens, resources |
| `Screens` | the screen layer, the current screen, the single modal dialog slot | any concrete screen or dialog |

```
Main (scenes/main.tscn, Node2D)
├── Screens   (CanvasLayer, layer 10)   <- Screens.replace() mounts screens here
└── Debug     (CanvasLayer, layer 90)   <- FPS/tick overlay (P2.1/EV-0035 string)
```

`Main` attaches its layer to `Screens` in `_ready()` and does nothing else. The level, its entities and
all HUD widgets will be children of the current screen - not siblings of `Main` - so a screen change
tears the level down with it, with no manual cleanup list to keep in sync.

There is deliberately **no** autoload per system (pets, aliens, audio, save...). Those arrive with
their P4 task either as a node inside the tank screen (which owns their lifetime) or as a service
autoload **only** if the state must outlive a level (audio buses, the profile). Adding an autoload is
an architecture change: update this document and `SPECS.md` §9 before doing it.

### Content: the registry and the three load phases

`Content` (`scripts/autoload/content.gd`) is autoload #1 because `Init`-phase resources include the
loading screen and the cursors themselves (SPECS.md §2.2): `bootstrap()` resolves them from `_ready()`,
which runs before any scene, so the game can draw its own loading screen.

Nothing parses the XML manifest at runtime. `tools/godot/gen_content.gd` reads the three P3 manifests
(`assets_raw/{extraction,audio,fonts}.json`) and emits the committed `resources/content.json` - one
entry per id, in the original's groups. The generator is also where the group partition is enforced
(**Init 14 / Register 16 / LoadingThread 296 = 326**); a different split fails the build instead of
drifting. It is byte-stable for unchanged inputs, so a regeneration diff means the assets changed.

Every id resolves once into a typed handle: `IMAGE_*` -> `ImageRes` (grid, `SpriteFrames`, tick
delays), `SOUND_*` -> `AudioStream` plus its manifest volume, `FONT_*` -> `FontFile` plus its native
point size. Lookups by string are a dictionary hit for setup code, never a load; a live system captures
its handles once and holds them (SPECS.md §2.1), so a per-tick string lookup is a bug.

The phases are an ordering contract, not a convenience:

| phase | ids | must be ready |
| --- | --- | --- |
| `Phase.INIT` | 14 | before the first frame: loading screen, cursors, blank, 2 fonts, click sound |
| `Phase.REGISTER` | 16 | before any dialog or menu: dialog skin + 13 UI fonts |
| `Phase.LOADING` | 296 | behind the loading bar: 232 images + 64 sounds |

`bootstrap()` completes `INIT`. `ensure_phase(Phase.REGISTER)` pulls the dialog skin synchronously
where a menu first needs it. `start_phase(Phase.LOADING)` + `pump(budget_ms)` loads the bulk a slice at
a time so a loading bar can draw between slices; `pump()` always makes at least one step, and starting
one phase while another is still loading is refused. `Main` pumps ~4 ms per frame today; P4.5 replaces
that with the real loading screen, which is a screen change, not a loader change.

Sound `alias` attributes become alias keys for the same stream (`SOUND_START` -> `SOUND_AWOOGA`),
resolved from the manifest rather than by filename guessing (PIPELINE.md §4). A missing id is a
`push_error` plus null - the original throws "resource not found" (EV-0153); a remake should be loud
but not die mid-frame - and `Content.failures` keeps the list for the boot log and the checks.

`resources/content.json` is a plain `.json`: P5.5 must confirm the export includes it (non-resource
file filter) or convert it to a `.tres`.

### Entities and the tank host

`SimEntity` (`scripts/entities/sim_entity.gd`) is the base for everything the simulation ticks, and
`Tank` (`scripts/tank/tank.gd`) is the host that owns them - the original's structure: objects live in
per-type lists on the tank and are advanced by the tank's update.

- **An entity never registers itself.** `Tank.spawn(entity, phase)` assigns the phase, parents the node
  to that phase's draw layer (ordered FOOD < FISH < PETS < ALIENS < PROJECTILES < PARTICLES) and
  registers it with `Sim`, so "one entity, one phase" holds by construction.
- **`_advance()` is the only per-tick hook.** `_sim_tick()` is the wrapper that applies the pause gate
  and the tick counter, which is why an entity never polls `Game`.
- **`despawn()` unregisters before `queue_free()`**, so an entity may despawn itself from inside
  `_advance()` (death, eaten, sold). `_exit_tree()` is the net for a node freed some other way.
- **`Tank.shutdown()` is level teardown**: despawn everything, unregister, drop pending sim time.
- **Randomness is `Tank.rng`**, seeded per level (`setup(sim, seed)`). Nothing inside a tank may call
  the global `randi()`/`randf()`: a second stream makes level runs unreproducible (SPECS.md §9.8).
- **The pause gate lives in one place.** `Tank.paused` (the original's `Tank+0x94`) OR'd with an
  injected `pause_source.gameplay_paused` (`Game` in the real app). Injecting it keeps headless checks
  free of autoloads while leaving the tank the single answer to "is the level running".

`Food` is the first concrete entity and the template for the rest: constants named after the field
offset and update step they came from (`+0x188` quality, `+0x18C` kind, `+0x190` landed, `+0x60`
lifetime), every decoded branch implemented, and the one unlocated branch (landing/bob trigger and the
death-line call, Q-0035) left explicit rather than guessed.

## 4. Ownership map

| concern | owner (task) | registers / mounts |
| --- | --- | --- |
| resource loading (`Init`/`Register`/`LoadingThread` phases) | `Content` autoload (P4.2, done) | typed handles + the three phases |
| fish, food, coins | `Tank` host (P4.3/P4.4) | `FISH`, `FOOD`, `COLLISION` phases |
| pets | `Tank` (P4.7) | `PETS` |
| aliens, bosses | `Tank` (P4.8/P4.9) | `ALIENS`, `PARTICLES` |
| projectiles | `Tank` (P4.10) | `PROJECTILES` |
| economy/store UI | `StoreScreen` + `Tank` (P4.5) | screens; no phases |
| progression/hatch/bonus | screens (P4.6) | screens |
| modes | `Game` + level start (P4.11) | none |
| saves | a `Save` service (P4.12) | none |
| audio | an `Audio` autoload (P4.13) | none (event-driven) |
| menus/options/help | screens (P4.14) | screens |

`Content` was the one autoload that had to exist before the first frame, because `Init`-phase resources
include the loading screen and the cursors themselves (SPECS.md §2.2); it now does, from `_ready()`.
The rest of the table is the checklist for which P4 task owns which phase registration.

## 5. Coupling rules

1. **Downward calls only.** Screens may call `Game`/`Screens`/`Sim`; `Sim`/`Game` never call a screen.
2. **Signals for lifecycle, not per tick.** `Sim.ticked` is for HUD/observers. Never route per-entity
   work through signals - a few hundred entities on a 100 Hz tick would dominate the frame.
3. **One shared pause gate.** `Game.gameplay_paused` is the original's `Tank+0x94`: pets and alien
   actions read it; it is not `get_tree().paused`, because screens and dialogs keep running.
4. **No direct cross-system reach-through.** A system asks the tank for typed queries (nearest
   pellet, live aliens, coin list), it does not walk another system's children.
5. **Input belongs to screens.** The staged click handler of SPECS.md §1.5 is one function on the tank
   screen; per-object `_input`/`_unhandled_input` handling is not used for gameplay.
6. **Resource ids are resolved once.** Gameplay code holds the handle it was given at load; a string id
   at runtime is a bug (SPECS.md §2.1).

## 6. Screens and dialogs

A screen is a `Control` subtree plus one `match id:` click handler, ported as data (button list: id,
label, rect, font/colour) rather than as a bespoke class per screen (SPECS.md §6, P2.12). `Screens`
provides `replace(screen, id)` and the single modal slot `open_dialog()`/`close_dialog()` - the original
has exactly one add-window slot, so a second open is a caller bug and is refused with a warning.

`Screens.replace()` frees the previous screen after mounting the new one, so a button callback may open
its successor directly. Level teardown therefore happens by screen destruction; a screen that spawns
entities must still `Sim.unregister()` them (or `clear_registrations()` on teardown) and call
`Sim.flush_backlog()` so a hitch does not pop the first frames of the new level.

## 7. Data, timing and determinism

- **Integer ticks everywhere.** All timers, cooldowns, periods and delays are integer tick counts
  (every P2 note stores them that way). `Sim.ticks_to_seconds()` is for UI/tooltips only.
- **No `delta` in simulation code.** Update functions take a tick, not a float.
- **Per-site RNG, not the global stream.** The tank owns one `RandomNumberGenerator`; systems draw from
  it with the *range shapes* the notes record (`rand%450+20` → `rng.randi_range(0,449)+20`, no
  `%` on a float). Matching the original's sequence is explicitly not a goal (SPECS.md §9.8), but the
  observability of a seed is: one seeded stream per tank makes level runs reproducible.
- **Constants live in data.** Recovered numbers are named constants next to the module address in a
  comment (e.g. `const FOOD_DEATH_Y := 410.0  # 0x… EV-0045`), never magic literals in logic, so P5.1's
  differential sheet can be generated by grepping.

## 8. Verification

Everything P4 adds should be checkable headlessly, because the original cannot be diff-tested against
a running remake:

```powershell
# import new assets (after any asset regeneration)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import

# the tick driver contract (17 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_sim_check.gd

# the content registry contract (51 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_content_check.gd

# the entity/tank seam and Food rules (38 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_entity_check.gd

# the Fish entity (92 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_fish_check.gd

# regenerate the runtime manifest after any asset regeneration (writes resources/content.json)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_content.gd

# boot the game scene for 300 frames (resolves all three content phases) and fail on any script error
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 300
```

`tests/headless_sim_check.gd` covers: sub-slice frames producing no tick, an exact 10 ms slice, the
10-tick per-frame cap, the 1000 ms backlog clamp (and that pending time is kept, not silently
dropped), `flush_backlog`, phase order, re-registration moving a node, unregister/clear, freed
registrants being skipped, and the ticks→seconds helper.

`tests/headless_content_check.gd` covers: the phase table, `Init` completing before anything else,
each phase making exactly its own ids available (a LoadingThread id is absent after Init and after
Register), the 14/16/296 partition, `pump()` progress and budget behaviour, typed handles carrying the
manifest's grid/animation/volume metadata, `framemap` playback order with per-frame delays, sound
aliases, and a missing id returning null after being recorded.

`tests/headless_entity_check.gd` covers: phase assignment and phase-ordered ticking, per-phase draw
layers, `despawn` unregistering, the level and app pause gates, teardown leaving nothing registered,
per-tank seeded RNG reproducibility, and `Food::Update`'s decoded rules (fall 1.5/tick, drift decay
0.05, x clamp 20..550, death at 410/400, star and breeding removals, lifetime, inedible countdown,
animation wrap, the 120..150 bob bands, homing).

`tests/headless_fish_check.gd` covers: the seven-species ctor defaults (stages, bands, hunger, boxes,
coin thresholds), hunger decay/hints/death and successor requests, every swim branch (modes 0-4,
`0x7B` drift, the default `>= 5` hover), the ±5/±10 approach bands, the eat window and acceptance
rules (homing, inedible, variant 1, breeding pellet gate), nutrition per quality/species, the shared
growth tail and stage-4 overshoot, the star potion, the slot-81 coin scheduler (stage gate, food
suppression, threshold reset) and same-seed RNG reproducibility.

Golden-file tests for saves (P4.12) and the existing `verify_fonts.gd` / `gen_spriteframes.gd` tools
follow the same pattern: a `--script` entry point that prints per-assertion lines and exits non-zero on
any failure.

## 8b. Ordering of a level frame

For P4.4 onwards, one rendered frame is: `Sim.advance()` runs 0-10 slices; each slice runs the phases
in order (CLOCK, FISH, PETS, ALIENS, PROJECTILES, COLLISION, FOOD, PARTICLES) and, inside a phase, the
entities in spawn order; then the tree draws the phase layers. Level setup is `Tank.setup(sim, seed)`
then spawn; teardown is `Tank.shutdown()` - both before any other tank work, because `shutdown()`
drops the backlog and a screen change must not carry old time into the next level.


## 9. What the scaffold still does not have

| not done | task |
| --- | --- |
| the remaining entity types (pets, aliens, coins, projectiles) | P4.3/P4.4 |
| input map / click routing beyond the screen-listener plan | P4.3/P4.14 |
| any concrete screen, dialog, HUD widget | P4.5-P4.14 |
| audio buses and music/SFX wiring | P4.13 |
| save format and profile handling | P4.12 |
| renderer/packaging decisions (Forward+ kept as-is) | P5.5 |

## 10. File map (P4.1-P4.3 output)

```
project.godot                     main scene, four autoloads, 640x480, nearest filtering
scenes/main.tscn                  boot scene: Screens + Debug layers
scripts/main.gd                   screen layer, loading pump, debug overlay
scripts/autoload/content.gd       resource registry + the three load phases
scripts/autoload/sim.gd           fixed-tick driver, phase registry, tick<->seconds
scripts/autoload/game.gd          mode, save stems, shared pause gate
scripts/autoload/screens.gd       screen stack + single modal slot
scripts/data/image_res.gd         resolved image handle: grid, SpriteFrames, tick delays
scripts/entities/sim_entity.gd    entity base: phase, tick, despawn
scripts/entities/food.gd          Food pellet (P2.3 §1 rules)
scripts/entities/fish.gd          Fish: seven species, swim/feed/grow/coin (P2.2-P2.4)
scripts/tank/tank.gd              tank host: spawn/despawn, layers, seeded RNG, pause
resources/content.json            committed runtime manifest, 326 ids (generated)
tools/godot/gen_content.gd        manifest generator + group-partition check
tests/headless_sim_check.gd       17-assertion contract check for the tick driver
tests/headless_content_check.gd   51-assertion contract check for the content registry
tests/headless_entity_check.gd    38-assertion check for the entity seam and Food
tests/headless_fish_check.gd      92-assertion check for Fish (P2.2-P2.4)
```

Next: the rest of P4.3's entity set (pets, aliens, coins, projectiles), then P4.4 (the tank
simulation and feeding loop).
