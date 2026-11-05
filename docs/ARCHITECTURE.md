# Architecture (Phase 4)

Status: **P4.1-P4.3 complete; P4.4-P4.14 in progress (P4.10/P4.11 partial)** (2026-11-05).
This is the design the P4 tasks build against, derived from [`SPECS.md`](SPECS.md) (behaviour) and
[`PIPELINE.md`](PIPELINE.md) (assets). It fixes the tick model, the resource registry, the autoload
set and the coupling rules, and leaves every system to its own P4 task.

What exists: the boot scene, five autoloads, the 640x480 project settings, the committed content
manifest resolving all 326 ids into typed handles, the entity/tank seam, the playable level (feeding,
coins, store, waves, pets, boss), the game selector, the two-mixer audio layer and the tank save/load
path. Eighteen headless checks cover the tick driver, content registry, entities, level, store,
progression, menu, audio, animation, pets, aliens, boss, saves and snapshots. Remaining gaps are
listed in §9.

## 1. The tick contract

`Sim` (`scripts/autoload/sim.gd`) is the **only** driver of simulation time. It reproduces the
original loop (SPECS.md §1.1, P2.1/EV-0034):

| rule | value | why |
| --- | --- | --- |
| logic slice | `TICK_MS` = 1000/36 ms | the ~36 Hz reading of Q-0034 (port decision, 2026-11-04) |
| slices per rendered frame | at most 10 | the original pumps at most 10 updates per `Process()` |
| backlog clamp | 1000 ms | the original rewinds its `last` stamp instead of catching up further |
| damping factor | `UPDATE_MULTIPLIER` = 0.85 | `mUpdateMultiplier`, for consumers that smooth motion |

`Sim._process(delta)` calls `advance(delta * 1000)`; `advance()` is pure with respect to the scene
tree, which is what makes it testable headlessly.

**Q-0034's port decision** (2026-11-04): the remake runs the **~36 Hz** reading, because every
gameplay timer recovered as a tick count was calibrated against wiki seconds there, and the pellet
tumbler only reads at that cadence (Q-0051). The `SexyAppBase` ctor's 10 ms interval stays the open
alternative until the gate that would slow the tank path is found. `TICK_MS`/`TICKS_PER_SECOND`
remain the *single* place the rate is defined: no subsystem may hard-code a rate, convert ticks to
seconds, or use `delta` inside simulation code.

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

`_sim_tick()` may despawn its own node (death, eating, sell, transform), and a despawn removes the
node from the phase bucket that is being walked - so `Sim` ticks a **copy** of each bucket and skips
freed registrants, rather than indexing the live array (a fish dying in the FISH phase shrank it and
the next index went out of bounds). Nodes must `Sim.unregister(self)` in `_exit_tree()` - the "freed
node" path exists for robustness, not as the normal route.

## 2. Project settings that are part of the contract

| setting | value | reason |
| --- | --- | --- |
| `display/window/size/viewport_width` / `height` | 640 / 480 | the original's logical space (P2.1) |
| `window/stretch/mode` / `aspect` | `canvas_items` / `keep` | integer-friendly scaling, no distortion |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (nearest) | pixel art (Q-0005) |
| `run/main_scene` | `res://scenes/main.tscn` | boot scene |
| `[autoload]` | `Content`, `Audio`, `Sim`, `Game`, `Screens` (in that order) | see §3 |

The 3D physics engine setting still reads Jolt; nothing in the remake uses 3D physics - the original
has no physics engine at all (movement is integer/float integration in `Update`). Leave it alone
rather than churning the file.

## 3. Autoloads and the scene tree

Five autoloads, each with one job:

| autoload | owns | does not own |
| --- | --- | --- |
| `Content` | the resource registry and the three load phases | gameplay state, screens, entity data |
| `Audio` | the two mixers: the effect-slot pool on `Sfx`, the looping tracks on `Music`, both volumes | gameplay events (they call it), the mode gate it reads |
| `Sim` | the tick driver, the phase registry, tick counters | any entity or system state |
| `Game` | active mode, save-file stems, the shared gameplay pause gate | level state, screens, resources |
| `Screens` | the screen layer, the current screen, the single modal dialog slot | any concrete screen or dialog |

```
Main (scenes/main.tscn, Node2D)
├── Screens   (CanvasLayer, layer 10)   <- Screens.replace() mounts screens here
└── Debug     (CanvasLayer, layer 90)   <- FPS/tick overlay (P2.1/EV-0035 string)
```

`Main` attaches its layer to `Screens` in `_ready()`, pumps the loading phase, mounts the main menu
when the bulk is in, and starts the level on the selector's signal. The level, its entities and all
HUD widgets are children of the current screen - not siblings of `Main` - so a screen change tears
the level down with it, with no manual cleanup list to keep in sync.

There is deliberately **no** autoload per entity system (pets, aliens, save...). Those arrive with
their P4 task either as a node inside the tank screen (which owns their lifetime) or as a service
autoload **only** if the state must outlive a level - `Audio`'s buses and `Game`'s profile are the
two cases. Adding an autoload is an architecture change: update this document and `SPECS.md` §9
before doing it.

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
| audio | an `Audio` autoload (P4.13, done) | two buses, a 256-slot effect pool, looping music |
| menus/options/help | screens (P4.14) | screens |

`Content` was the one autoload that had to exist before the first frame, because `Init`-phase resources
include the loading screen and the cursors themselves (SPECS.md §2.2); it now does, from `_ready()`.
The rest of the table is the checklist for which P4 task owns which phase registration.

## 5. Coupling rules

1. **Downward calls only.** Screens may call `Game`/`Screens`/`Sim`; `Sim`/`Game` never call a screen.
2. **Signals for lifecycle, not per tick.** `Sim.ticked` is for HUD/observers. Never route per-entity
   work through signals - a few hundred entities on a 36 Hz tick would dominate the frame.
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

# the tick driver contract (20 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_sim_check.gd

# the content registry contract (51 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_content_check.gd

# the entity/tank seam and Food rules (38 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_entity_check.gd

# the Fish entity (105 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_fish_check.gd

# the Coin entity (87 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_coin_check.gd

# the Projectile entity (47 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_projectile_check.gd

# the level: feeding loop, wave wiring, shooting, pet session (121 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_level_check.gd

# the store screen and bar (34 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_store_ui_check.gd

# progression, eggs and level completion (79 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_progression_check.gd

# the main menu: EV-0131 ids, mode writers, gates and the tail flop (37 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_menu_check.gd

# the pet base, roster and six implemented pets (66 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_pet_check.gd

# the alien kinds, attacks, eating and the wave clock (47 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_alien_check.gd

# the Cyrax boss fight (35 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_boss_check.gd

# the tank-save framing (38 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_check.gd

# the save file layer (21 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_files_check.gd

# capture/restore and the level save/load pair (54 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_tank_snapshot_check.gd

# the audio layer (40 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_audio_check.gd

# sprite playback and colour keying (18 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_anim_check.gd

# regenerate the runtime manifest after any asset regeneration (writes resources/content.json)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_content.gd

# boot the game scene for 400 frames (resolves all three content phases) and fail on any script error
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 400
```

`tests/headless_sim_check.gd` covers: sub-slice frames producing no tick, a full tick of slices, the
10-tick per-frame cap, the 1000 ms backlog clamp (and that pending time is kept, not silently
dropped), `flush_backlog`, phase order, re-registration moving a node, unregister/clear, freed
registrants being skipped, a node that unregisters itself mid-tick (the death path) not skipping its
phase peers, and the ticks→seconds helper.

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
coin thresholds), hunger decay/hints and a terminal death, every swim branch (modes 0-4,
`0x7B` drift, the default `>= 5` hover), the ±5/±10 approach bands, the eat window and acceptance
rules (homing, inedible, variant 1, breeding pellet gate), nutrition per quality/species, the shared
growth tail and stage-4 overshoot, the star potion, the slot-81 coin scheduler (stage gate, food
suppression, threshold reset) and same-seed RNG reproducibility, plus the persistence record: `Fish.to_state()`/`from_state()` round-trip the species, stage, position, facing, fullness and growth points through `Tank.spawn_fish`, while food, coins, projectiles and particles stay out of the record because a load rebuilds them (P2.13 note #11).

`tests/headless_coin_check.gd` covers: both value tables (every kind, the {n, n+7} pairs, an
unknown kind, the Virtual Tank multipliers and the placeholder `+0x1C0` base), the COLLISION phase
and layer, fall 1.5 to the 370 landing line, the staged bob oscillating in the 120..150 band, the
20/108/150/200 expiry modes and Niko's Pearl's 217, the 5-tick fade, the 60x60 collection square
and single-use `collect()`, Virtual Tank homing/bank, and the 79-tick frame timer.

`tests/headless_projectile_check.gd` covers: the per-kind ctor constants (80x80/0.8 and 50x50/0.4,
15-tick immunity, 0/10 expiry, still spawn velocity), phase and layer, immunity gating the click, the
10-tick expiry, kind-0 clamping vs kinds-1/2 death outside the wide rect (kind 1 only after a
deflection), kind 2's 0.2 gravity, movement through the divisor, both hit-tests (missile destroyed in
a 60x60 box with the burst at click-40; ball deflected by `((click - pos) - 40) / -5` clamped to -1),
kind 2 not being clickable, the smoke roll, and the victim lock.

`tests/headless_level_check.gd` covers the P4.4 level with rendering off: the starting population and
its band, a pellet at the fish centre feeding +500 and being removed, click routing (collect first,
otherwise drop at the cursor), the AddMoney clamps and earned total, coin pickup crediting 15, a
death that leaves a corpse and no fish, and
the pause gate freezing and resuming hunger. The manual-drop cap is there too: `Level.food_quantity`
(1..9) refuses a pellet once that many non-special pellets are in the tank (`Level.non_special_food`),
and specials (`kind != 0 || variant != 0`) are exempt, exactly `Tank::DropFood`'s test.

The death block also covers the corpse: a death leaves a `DeadFish` in the PARTICLES phase with the
corpse id of the dying stage and its own stage counter at 125, whose vy ramps toward the sink target
and whose counter falls a step a tick (the corpse also has a visual: `SMALLDIE` row = the dying
stage, cell = `sprite_frame()`); it is removed silently when that counter reaches 0, and no
replacement fish appears for either a stage-0 or a stage-2 death (the revive branch is unreached,
Q-0043). It also covers the wave wiring: an armed clock spawns its alien after 3000 ticks
and sets the present flag, a click inside the 80x80 box removes 6 hp (`Tank.shot_damage()` at pet capacity 2) while a
distant click misses, a destructor's attack request produces one clickable projectile, and an alien
that eats a fish leaves a corpse through the same death path.

`tests/headless_pet_check.gd` covers the P2.7 foundation: the 24-entry roster (5 OtherTypePet / 19
FishTypePet, no 999), spawn phase and Stinky's forced lane, the three action gates (pause, tank 5,
hostile aliens), the hide counter's rise and fall, Stinky's lane chase and 60x60 contact collection,
the per-pet coin predicate, and Niko's 1224/1233/1440/1450 cycle including the `rand % 50` reset.

`tests/headless_alien_check.gd` covers the alien table (hp/speed pairs, recipes absent), phase and
bands (full, mini, bottom), the 7-tick intro, the missiles_3 volley and its rand%50+150 tail, the
Psychosquid 400-tick rest flip, the reach boxes (Sylvester, mini, out-of-reach, kinds 5/6 never
eating), the Diamond death rule (shot vs boss vs non-shot), and the wave clock (unarmed freeze,
alien freeze, milestone order, spawn point range, composite double spawn at one point). The boss check (`tests/headless_boss_check.gd`) covers the Cyrax fight: the hp formula and its clamp, the spawn flags (boss alive, waves frozen, pet capacity 10), the 300-tick arrival immunity, the 15-tick intro, the 75-tick minion cadence at +40/+40, the 300-tick pulse that stays quiet while another alien is on the field, the 10-tick per-attacker hit cooldown, and death clearing `boss_alive` while unfreezing then disabling the wave clock (35 assertions).

`tests/headless_save_check.gd` covers the tank-save framing: every header field, the class-`0x1F` skip, the round trip through `to_bytes()`/`from_bytes()`, the `42+E+S` / `454+E+S` / `658+E+S` section offsets, the size law, the `+0x110` object shift, and the loader's version gate (`0x34` rejected, `0x35` accepted, short/truncated files refused) - 38 assertions. `tests/headless_save_files_check.gd` covers the file layer: the per-mode stems and paths, a real write/read round trip under `user://`, the on-disk version refusal, a missing file, and the Adventure-only profile match - 21 assertions. `tests/headless_tank_snapshot_check.gd` covers the snapshot glue: capture (fish only, header stamped, store rows and pet flags preserved), the magic-tagged record in a 0x140 slot, a byte-level round trip through `TankSave`, restore into a fresh tank, the exclusion of non-fish entries, and the 316-byte scalar block (money, food levels, pet capacity, backdrop, wave selection and countdown, the `+0x440` star potion flag and the tint bytes, with the offsets the note gives and the clamps), plus the level-level pair `Level.save_game`/`load_game` through real disk (header, store table, money in the scalar block, fish count, wallet/food restore, fish replaced not merged, and a missing file returning false) - 54 assertions. Shots take their damage from `Tank.shot_damage()` (`3 * pet_capacity`, not a hard-coded multiplier), and `Level.start_level()` reads the boss from its schedule table (`Level.boss_kind_for`), so the fight is entered rather than started by hand.

Golden-file tests for saves (P4.12) and the existing `verify_fonts.gd` / `gen_spriteframes.gd` tools
follow the same pattern: a `--script` entry point that prints per-assertion lines and exits non-zero on
any failure.

## 8b. Ordering of a level frame

For P4.4 onwards, one rendered frame is: `Sim.advance()` runs 0-10 slices; each slice runs the phases
in order (CLOCK, FISH, PETS, ALIENS, PROJECTILES, COLLISION, FOOD, PARTICLES) and, inside a phase, the
entities in spawn order; then the tree draws the phase layers. Level setup is `Tank.setup(sim, seed)`
then spawn; teardown is `Tank.shutdown()` - both before any other tank work, because `shutdown()`
drops the backlog and a screen change must not carry old time into the next level.


## 9. What is still missing

| gap | task |
| --- | --- |
| the level HUD is a placeholder; no gore/splat particles; the coin kind uses the placeholder table (Q-0036) | P4.4/P4.5 |
| boss HP bar, per-item store art, stock roller/tooltips/paging, the binary's own price arrays (Q-0047/Q-0052) | P4.5 |
| bonus rounds and their wait, Hatch/Pets screens, pre-bonus store, elapsed-time and Challenge score records, credits/trophy screens (Q-0053) | P4.6 |
| 18 of the 24 pet bodies idle; Stinky, Niko, Angie, Vert, Shrapnel and Nostradamus are implemented (Q-0044) | P4.7 |
| Cyrax's minion kind and pulse content are placeholders (Q-0047) | P4.9 |
| the projectile homing body, the `Larva` object, the laser draw/frame binding and the weapon HUD (Q-0023/Q-0041) | P4.10 |
| the Time Trial clock and collect-all finish, Challenge scoring/records, and the Virtual Tank spawner and rules | P4.11 |
| persistence for entity bodies other than fish (coins/food/projectiles are rebuilt by design) and golden-file save fixtures | P4.12 |
| options sliders, the battle loop (trigger unrecovered), and the rest of the per-event sound map (Q-0030/Q-0056) | P4.13 |
| options/hall-of-fame/help screens, the menu buttons' baked bitmaps (labels are port text) and the mermaid flop trigger (Q-0050/Q-0055) | P4.14 |
| the mermaid tail sheet and mask are loaded with `Image.load_from_file` (Godot warns this does not work on export), and `resources/content.json`'s export inclusion is still unconfirmed (AUDIT.md F1) | P5.5 |
| sprites for aliens/boss/projectiles (AUDIT.md G3) | P4.8/P4.10 |
| shop-bought fish event wiring, stage -> coin-kind mapping, and the Tank mode-flag writers (AUDIT.md G4/G7/G9) | P4.4/P4.5/P4.11 |
| per-mode save stems and profile persistence (AUDIT.md G10) | P4.12 |
| consumers for the hunger/growth/coin/pet/alien/projectile/wave cue signals (AUDIT.md G11) | P4.13 |
| renderer/packaging decisions (Forward+ kept as-is) | P5.5 |

## 10. File map (P4 output)

```
project.godot                     main scene, five autoloads, 640x480, nearest filtering
scenes/main.tscn                  boot scene: Screens + Debug layers
scripts/main.gd                   screen layer, loading pump, menu/level switch, debug overlay
scripts/autoload/content.gd       resource registry + the three load phases
scripts/autoload/sim.gd           fixed-tick driver, phase registry, tick<->seconds
scripts/autoload/game.gd          mode, save stems, shared pause gate
scripts/autoload/audio.gd         two mixers: effect-slot pool and looping music (P2.14)
scripts/autoload/screens.gd       screen stack + single modal slot
scripts/data/image_res.gd         resolved image handle: grid, SpriteFrames, tick delays
scripts/data/anim_state.gd        tick-driven playback: anim mode, per-frame delays, phase
scripts/data/mask_alpha.gd        P3.3 alpha model: a mask's luminance becomes the alpha
scripts/economy/store.gd          the twelve store items, prices and purchase rules
scripts/progression/progression.gd  P2.6 tables: stock, egg prices, pet award, advance
scripts/persistence/profile.gd    Adventure profile: tank/level, Shells, owned pets, gates
scripts/entities/sim_entity.gd    entity base: phase, tick, despawn
scripts/entities/food.gd          Food pellet (P2.3 §1 rules)
scripts/entities/fish.gd          Fish: seven species, swim/feed/grow/coin (P2.2-P2.4)
scripts/entities/coin.gd          Coin: kinds/values, fall/bob/expiry, collection (P2.5 §5)
scripts/entities/projectile.gd    Projectile: three kinds, expiry, bounds, hit tests (P2.10 §5)
scripts/entities/dead_fish.gd     DeadFish corpse: sink physics, stage countdown, revive branch (P2.4 §4)
scripts/entities/pet.gd           Pet base: roster, gates, six implemented pets (P2.7)
scripts/entities/alien.gd         Alien: kinds, bands, attacks, eating, shot death (P2.8)
scripts/entities/boss.gd          Cyrax: hp scale, arrival, minions, pulse, hit cooldown
scripts/tank/wave_clock.gd        wave clock: 3000-tick gate, milestones, spawn roll (P2.8)
scripts/tank/tank.gd              tank host: spawn/despawn, layers, seeded RNG, pause
scripts/tank/level.gd             level: feeding clicks, pickups, money, store, sprites, HUD
scripts/tank/sprite_key.gd        black colour-keying for the extracted sheets, per cell
scripts/ui/game_selector.gd       main menu: EV-0131 dispatch, gates, mermaid tail (P4.14)
scripts/ui/store_screen.gd        shop screen: shelves, price lines, Shell plate (P4.5)
scripts/ui/store_bar.gd           in-tank store bar: eight buy slots (FUN_005409B0)
scripts/persistence/tank_save.gd  tank save framing (0x36 header, sections, store rows)
scripts/persistence/tank_scalars.gd  316-byte scalar block in note order
scripts/persistence/tank_snapshot.gd  fish records in and out of a tank save
scripts/persistence/save_files.gd per-mode paths and file write/read for tank saves
resources/content.json            committed runtime manifest, 326 ids (generated)
tools/godot/gen_content.gd        manifest generator + group-partition check
tools/godot/gen_spriteframes.gd   SpriteFrames generator from the extracted sheets
tools/godot/verify_fonts.gd       font manifest verification
tools/godot/screenshot.gd         windowed menu/level/store captures
tests/headless_sim_check.gd       20-assertion contract check for the tick driver
tests/headless_content_check.gd   51-assertion contract check for the content registry
tests/headless_entity_check.gd    38-assertion check for the entity seam and Food
tests/headless_fish_check.gd      105-assertion check for Fish (P2.2-P2.4)
tests/headless_coin_check.gd      87-assertion check for Coin (P2.5 §5)
tests/headless_projectile_check.gd  47-assertion check for Projectile (P2.10 §5)
tests/headless_level_check.gd     120-assertion check for the level, feeding and waves
tests/headless_store_ui_check.gd  34-assertion check for the shop screen and bar
tests/headless_progression_check.gd  78-assertion check for P2.6 progression and completion
tests/headless_menu_check.gd      37-assertion check for the main menu (P4.14)
tests/headless_pet_check.gd       66-assertion check for the pet base and six pets (P2.7)
tests/headless_alien_check.gd     47-assertion check for aliens and the wave clock (P2.8)
tests/headless_boss_check.gd      35-assertion check for the Cyrax fight (P2.9)
tests/headless_save_check.gd      38-assertion check for the tank-save framing (P2.13)
tests/headless_save_files_check.gd  21-assertion check for the save file layer
tests/headless_tank_snapshot_check.gd  54-assertion check for capture/restore
tests/headless_audio_check.gd     40-assertion check for the audio layer (P2.14)
tests/headless_anim_check.gd      18-assertion check for sprite playback and keying
```

Next: **P4.10/P4.11** (projectile homing and weapon follow-ups, then the game modes), with the
remaining sub-items on P4.4-P4.9/P4.12-P4.14 tracked on their PLAN lines.
