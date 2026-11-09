# Progress audit - 2026-11-05

Status: **evaluation of the checked-out tree**, not a behaviour change and not an `EV-` entry. It
records what the remake does today, how that was checked, and where the documentation and the code
still diverge. Facts about the original game stay in [`EVIDENCE.md`](EVIDENCE.md); the contract they
feed is [`SPECS.md`](SPECS.md).

The first pass of this audit verified the suites and read the docs; it concluded the port had a
"working vertical slice". A code-level second pass (§5a) showed that was too generous: several
systems exist as entities and contract tests but are not connected to the assembled game.

## 1. Method and limits

- Ran all 19 headless suites separately with Godot 4.7.1: the 18 `--script` suites plus the
  scene-backed integration suite (`... --script res://tests/...` and
  `... res://tests/headless_integration_check.tscn --quit-after 1200`).
- Ran the 400-frame boot check (`--quit-after 400`) and read its full log.
- Read the gameplay code (`scripts/`) against `PLAN.md`, `ARCHITECTURE.md` §9, `SPECS.md` and the tests.
- Inspected the git state and the generated assets.

Limits, stated so the numbers are not over-read:

- The suites are **contract tests for the port**: each asserts the behaviour written in `SPECS.md`
  and the P2 notes. They are not differential tests against the running original, and §5a shows they
  often call wiring APIs that the real level never calls. A green suite means "the unit agrees with
  its contract", not "the assembled game performs this behaviour".
- P5.2 (side-by-side playtest) and P5.3 (tick-rate measurement) are not done, no windowed visual check
  was part of this audit, and no new Ghidra analysis was run.
- No performance measurement was taken.

## 2. Verified results

| Suite | Assertions |
| --- | ---: |
| `headless_sim_check` | 20 |
| `headless_content_check` | 51 |
| `headless_entity_check` | 38 |
| `headless_fish_check` | 105 |
| `headless_coin_check` | 87 |
| `headless_projectile_check` | 50 |
| `headless_level_check` | 121 |
| `headless_store_ui_check` | 34 |
| `headless_progression_check` | 79 |
| `headless_menu_check` | 37 |
| `headless_integration_check` | 37 |
| `headless_pet_check` | 66 |
| `headless_alien_check` | 61 |
| `headless_boss_check` | 35 |
| `headless_save_check` | 38 |
| `headless_save_files_check` | 21 |
| `headless_tank_snapshot_check` | 54 |
| `headless_audio_check` | 40 |
| `headless_anim_check` | 18 |
| **Total** | **992** |

- All 19 suites exited 0; the per-suite counts above are the suites' own `PASS (... assertions)`
  summaries and sum to exactly the **992** claimed in `PLAN.md` and `README.md`.
- The boot check exits 0 and resolves the three content phases: `Init` 14, `Register` 16,
  `LoadingThread` 296 (326 ids, as `SPECS.md` §2.2 requires).
- The audit began on clean `main` at `46d5f35`; the §5b follow-up is a later commit. `resources/sprites/` holds 129 `SpriteFrames`,
  `assets_raw/` and the carved game module are present, `docs/evidence/` holds 561 JSON exports and
  `docs/analysis/notes/` holds 18 notes.

## 3. Phase assessment

| Phase | Documented | Observed | Verdict |
| --- | --- | --- | --- |
| P0 environment | 13/13 complete | Godot 4.7.1 binary present; REA/Ghidra not re-checked | consistent |
| P1 target identity | 10/10 complete | not re-verified this audit | unchanged |
| P2 reverse engineering | 14/18 (P2.5/P2.6 in progress, P2.16/17 optional) | 18 notes, 561 evidence exports, carved module present | consistent |
| P3 assets | 8/8 complete | 129 `SpriteFrames`, `content.json`, ten `assets_raw` groups; content check enforces 326 ids | consistent |
| P4 implementation | 3/14 tasks `[x]`, 11 `[~]` | all 11 in-progress tasks have code and a passing suite; several are not connected to the assembled game (§5a) | substantially overstated |
| P5 validation | 0/5 | not started; concrete blockers now known (§5/§5a) | consistent |

**P4 reality.** The task count ("3/14") understates how much code exists, but it overstates how much
of the game works. The assembled path now includes menu -> Adventure level -> feeding/growth/coins ->
store -> egg purchase -> next level, and a scene-backed integration suite drives menu -> level ->
wave -> boss through `Main`; `start_level` arms the per-level wave selection, composites
compose, and the type re-rolls after each wave. The threat path is now visible: aliens, Cyrax and
projectiles draw their recovered sheets, and aliens/Cyrax carry the recovered HP bar. What is still
missing is their behaviour: projectiles do not home or damage fish, and the boss placeholders remain. Every row of the `ARCHITECTURE.md` §9 gap table still has an open item;
several rows are scaffolds with their wiring missing, not partially faithful systems. `[x]` means the
task's documented scope was done, not that the system is connected or faithful.

## 4. Capability matrix

| Area | State | Basis |
| --- | --- | --- |
| tick driver, phases, pause, seeded RNG | done | `headless_sim_check`, `headless_entity_check` |
| content registry, typed handles, load phases | done | `headless_content_check` |
| feeding, hunger, growth, death/corpses, coins | done for guppies; other species share the guppy art; shop-bought fish are unwired (G4) | `headless_fish_check`, `headless_coin_check`, `headless_level_check` |
| store UI + in-tank bar | partial: 7 of 12 items available; fixed table, no stock roller/art/tooltips | `Store.ITEMS`, `headless_store_ui_check`, Q-0047/Q-0049/Q-0052 |
| progression | partial: the egg widget buys pieces and completion advances on tanks 1-4; no bonus rounds, Hatch/Pets screens or credits | `headless_progression_check`, Q-0053, G12 |
| pets | partial: 6 of 24 bodies; only Stinky steers/collects; all owned pets spawn rather than the selected slots; two ctors use the global RNG | `pet.gd:150/152/289`, Q-0044, G8 |
| aliens + waves | wired and visible: `start_level` arms the per-level type (with tank 1 level 2's 1750-tick start), 9..0xC compose 1+3/7+3/5+6/3+8, the type re-rolls after each wave, and each kind draws its recovered sheet plus the HP bar | `headless_level_check`, `headless_alien_check`, G1-G3 |
| Cyrax boss | partial: sprite and always-on HP bar draw, but placeholder minions/pulse, 10-tick cooldown bypassed and HP never scaled | `level.gd:447`, `boss.gd`, G6 |
| weapons/projectiles | visible but inert: the three sheets draw, but `_steer()` is a no-op and there is no collision/damage path; no `Larva`, laser binding or weapon HUD | `projectile.gd:123`, G5 |
| modes | Adventure only; Challenge inflates prices only; Time Trial/Virtual Tank rules absent; the mode flags have no writers | `tank.gd:48-66`, G7 |
| saves | fish-only entity records; per-mode save stem unused (always `adv1`); profile not persisted; a loaded wave selection is now armed | `level.gd:81`, `profile.gd`, G10 |
| audio | two mixers, 256-slot pool, music pairs; most effect cues have no consumer; no battle loop | `headless_audio_check`, G11 |
| menus/UI | game selector and shop with their recovered native BMFonts; options/help/hall-of-fame absent; button labels are port text; loading bar is the debug pump | `headless_menu_check`, Q-0050/Q-0055/Q-0059 |
| validation/packaging | absent | P5.1-P5.5 |

## 5. Findings

**F1 - Export blocker not recorded (high, packaging).** The boot log warns twice that
`game_selector.gd:137/140` loads `assets_raw/images/tailflop.png` and `assets_raw/masks/tailflop_.png`
with `Image.load_from_file`, which Godot explicitly says "will not work on export". `ARCHITECTURE.md`
§9 mentions only `resources/content.json` for P5.5, so this second hazard is unowned. Fix by importing
the two files as resources (or preloading them) before packaging; `content.json`'s export inclusion
still needs the same pass.

**F2 - The boot check is not warning-clean (medium, verification hygiene).** Exit 0 hides:
five Ogg vendor-comment warnings (`bonuscount`, `crowned1`, `ultraprego`, `nikoopen`, `nikoclose`);
the two F1 asset warnings; and `4 ObjectDB instances were leaked at exit` plus `2 resources still in
use at exit`. The Ogg lines are harmless metadata noise, but they train readers to ignore boot output,
and the object/resource leaks are not explained anywhere. The README's "no script errors expected" is
literally true; it is not the same as a clean boot.

**F3 - Progress is represented by task count, not capability (medium, documentation).** `PLAN.md`
reports P4 as 3/14 and every remaining task as `[~]`, although all 11 have landed code and suites.
Conversely `[x]` tasks still carry open questions and unwired paths (G3-G12). The PLAN header now
points here, but the summary table will keep misrepresenting P4 until statuses record sub-items.

**F4 - Behavioural placeholders are honest but still load-bearing (medium, fidelity).** Alien
projectiles never move (Q-0041), the stage -> coin-kind table uses kind 1 for every drop (Q-0036),
the fish target timer uses `rand % 6` (Q-0039), the Virtual Tank coin base is a placeholder (Q-0040),
and the boss minion/pulse are placeholders (Q-0047). §5a adds the cases where the gap is not an
unknown but a missing connection.

**F5 - Green tests are machine-local (medium, reproducibility).** `assets_raw/` and the carved module
are gitignored. A fresh clone cannot boot or run any suite until the five PowerShell extractors run
against the owned install. This is documented, but it means the 992 assertions verify *this* checkout,
not the repository alone.

**F6 - Assertion reporting is inconsistent (low, tooling).** Sixteen suites print an `ok` line per
assertion; `headless_anim_check`, `headless_audio_check` and `headless_menu_check` print only failures,
so a naive `grep -c '^  ok'` reports 897 instead of 992. The PASS summary is the reliable count; a
shared check harness would remove the trap.

No stale count or contradiction remained after this pass: `PLAN.md`, `README.md`, `docs/README.md` and
`ARCHITECTURE.md` all agree on 19 suites, 992 assertions, the 36 Hz tick decision and the phase
statuses. §5a records the assembly gap; §5b records the follow-up fixes.

## 5a. Implementation fidelity (code-level pass)

These are not open reverse-engineering questions; they are places where the code, the suites and the
documentation describe a system but the assembled game does not exercise it. This audit itself made
no code changes; G1/G2/G3/G13/G14 were fixed in the follow-up recorded in §5b.

| # | Finding | Evidence | Effect in the game |
| --- | --- | --- | --- |
| G1 | the wave clock was never armed | `Level.arm_wave` (`level.gd:262`) was called only from tests; `start_level` did not arm it and no schedule set a selection | no alien waves in normal play (fixed in §5b) |
| G2 | composite waves were dropped | `WaveClock` emitted selections 9..0xC; `_on_wave_spawn` returned unless `Alien.DEFS.has(selection)`, and `DEFS` has no 9..0xC | an armed composite wave spawned nothing (fixed in §5b: 1+3, 7+3, 5+6, 3+8) |
| G3 | aliens, boss and projectiles had no sprite | `_make_visual` (`level.gd:762`) handled Fish/Food/Coin/Pet/DeadFish and returned null otherwise; `alien.gd`, `boss.gd` and `projectile.gd` contained no `Sprite2D` | invisible threats and shots (fixed in §5b: recovered sheets, centred on their boxes, plus the HP bar) |
| G4 | shop-bought fish are not wired to the level | `buy_item` (`level.gd:574`) calls `tank.spawn_fish(...)` directly; initial and bred fish go through `_wire()` | bought fish never emit `died`/`coin_due`/`breed_requested`: no coins, no corpse, no breeding |
| G5 | projectiles are inert and cannot damage fish | `Projectile._steer()` is `pass` (`projectile.gd:123`); `_advance` has no fish/alien collision, only a click hit-test | alien attacks produce stationary, harmless shots (now drawn) |
| G6 | Cyrax is a placeholder and its damage cooldown is bypassed | `_on_boss_minion`/`_on_boss_pulse` both spawn kind `0x01` (`level.gd:447-452`); `try_shoot` calls `hit(damage, true)` without an attacker (`level.gd:296`), skipping `Boss.hit`'s 10-tick cooldown; `Main` starts the level without the profile counter (`main.gd:51`), so HP is always 5000 | placeholder fight; click-spam damage; the bar draws but HP never scales |
| G7 | every mode flag except Challenge inflation is dead | `Tank.virtual_tank`, `demo_mode`, `coin_difficulty_value`, `coin_pacing_gate_value`, `coin_hint_active`, `tank_flag_16c`, `penta_present`, `pet_sources_busy` are declared and read but never written (`tank.gd:48-66`) | Virtual Tank growth/coin rules unreachable; Stinky never hides; Penta coin exclusion inert; only Challenge inflation does anything |
| G8 | pets: only Stinky moves; all owned pets spawn; two ctors use the global RNG | `Pet._steer` (`pet.gd:289`) returns unless `index == STINKY`; `spawn_owned_pets` loops every owned flag, not `Profile.selected_pets`; `Pet.create` calls global `randi_range` (`pet.gd:150/152`) | up to 24 pets stand still; Angie cannot reach a corpse; runs are not reproducible |
| G9 | coin production is a single placeholder | `_on_coin_due` (`level.gd:490`) always spawns kind 1 (15 shells); the stage -> kind table is Q-0036 | high-value fish and stages pay the same 15; the economy is flat |
| G10 | saves write one fixed path and the profile is not persisted | `Level.save_path` is `userdata/adv1.dat` (`level.gd:81`); `Game.save_stem` has no caller; `Profile` has no serialization; `TankScalars.apply` restores `alien_selection` and `load_game` now arms `wave.selection` | every mode overwrites the Adventure slot; progress resets on restart; the loaded wave selection is armed, but per-mode stems and profile persistence remain |
| G11 | most effect/audio signals have no consumer | no listener for `fish.hunger_warning`/`grew`, `coin.expired`/`banked`, `pet.cue`, `alien.cue`, `projectile.smoke_requested`/`burst_requested` or `wave.milestone` | no hunger/growth/pet/alien sounds, no smoke/burst/wave warnings; only drop/buy/click and music play |
| G12 | progression and UI stop at the level boundary | `Main._on_level_completed` starts the next level directly (`main.gd:59`); no Hatch/Pets/Bonus/credits screens; store has no stock roller/art/tooltips; options/help/hall-of-fame absent | the Adventure loop has no between-level flow, and much of the original UI is missing |
| G13 | the assembled menu flow had no suite | `headless_level_check` starts 1-3 through `start_level`; the boss suite builds a `Tank` and calls `spawn_boss` directly; store tests inject prices; the new scene-backed suite drives menu -> level -> wave -> boss through `Main` | modules were green but the assembled flow was unproven (fixed in §5b: the integration suite) |
| G14 | level completion was unreachable on tanks 1-4 | `buy_egg` was called only from `buy_item` for `EGG_ITEM` (`level.gd:580`), and `STORE_TABLE[11]` stocks that row only on tank 5; no egg widget existed | Adventure could not advance past level 5 of any tank in normal play (fixed in §5b: the egg widget) |

Consequences worth stating plainly:

- The playable game is still a feeding/economy sandbox: the threats and shots are now visible, and
the egg widget lets tanks 1-4 finish a level, but inert projectiles and placeholder boss actions
mean the threat path is not a game yet.
- The "aliens + waves", "boss", "weapons" and "modes" task lines should be read as **entity and table
  work complete, integration incomplete**.
- The 992 assertions remain real and useful; the integration suite now covers the assembled menu
  -> level -> wave -> boss flow, while the rest mostly prove modules.

## 5b. Follow-up fixes (2026-11-05)

- **G14 fixed.** `scripts/ui/egg_widget.gd` draws the recovered `EggPieces` art and calls `buy_egg()`
  on click; it is visible on tanks 1-4 (tank 5 keeps the free store row). Its rect is port-placed
  because the original widget rect was not recovered (Q-0053). The progression suite buys through
  `EggWidget.press()` instead of calling `buy_egg()` directly (79 assertions).
- **G1/G2 fixed.** `Level.start_level()` arms the per-level selection from P2.6 §8 (including tank 1
  level 2's 1750-tick start), and `WaveClock.wave_spawned` re-rolls the type after each wave per
  P2.8 §5.1. `Level._on_wave_spawn` composes 9..0xC into 1+3, 7+3, 5+6 and 3+8. The level suite starts
  1-3 through `start_level` and exercises 0x09 without arming by hand (121 assertions).
- **G3 fixed.** `Alien.IMAGE_BY_KIND` binds every kind to its recovered sheet and
  `Projectile.IMAGE_BY_KIND` does the same for the three shot kinds; `Level._make_visual` creates one
  `Sprite2D` per alien/boss/shot, centred on the entity position (the box centre, P2.8 §2.1), and
  `_draw_entity_frame` plays the sheet's own metadata (Bilaterus draws its first cell, the shots
  their base cell, Q-0041/Q-0057). Each alien also gets the P2.9 §5 HP bar: `IMAGE_HEALTHBAR` clipped
  to `127 * hp / hp0` under the full `IMAGE_HEALTHBARTUBE` glass at x 10 / y box-3, always for Cyrax
  and for ordinary aliens while `Tank.show_alien_health` (`Tank+0x178`, writer unrecovered) is set
  and the tank is not 5. The alien, projectile and integration suites cover the image maps and the
  bar (61/50/37 assertions).
- **G13 fixed.** `tests/headless_integration_check.tscn` mounts the real `Main`, presses Adventure
  on the production `GameSelector`, starts 2-4 and advances the production wave and the Destructor's
  real missile, then starts 5-1 through the same menu path and asserts the scheduled Cyrax boss. It
  also checks the centred sprites, the HP bar (full 127-px fill, 64 px at half hp) and the native
  font of each UI surface; it never calls `start_level`, `arm_wave` or `start_boss`; 37 assertions.
  The suite is scene-backed because
  `--script` does not expose the project autoloads that `main.gd` names.
- **UI fonts and menu animation tidied.** `scripts/ui/ui_font.gd` applies the recovered BMFonts to
  the menu, store, in-tank bar, egg widget and HUD at the manifest's native pixel size, instead of
  the engine default scaled to ad-hoc sizes; the baked outline fonts no longer get a second engine
  outline drawn over them. The menu tail also draws its rest pose during the recovered 3-tick hold
  instead of flashing the flop's first cell for one frame. Q-0059 records the selector's 17/10 split,
  which the decompile does not pin down.
- Still open: projectile motion/damage (G5), the boss placeholders/cooldown (G6), bought-fish/economy
  wiring (G4/G9), modes (G7), pets/persistence (G8/G10), cue consumers (G11), UI/screens (G12) and
  packaging (F1).

## 5c. Completion pass (2026-11-08)

All §5a rows and §6 priorities are closed against the recovered contract:

- **G5/G6 closed upstream (2026-11-07, EV-0158):** homing `FUN_004FF4E0`, on-target
  `FUN_004FC070`, farthest-fish picker, Minisylvester minion + 4..9 pulse, death wipe and the
  `profile+0x54` counter (boss suite 46).
- **G4/G9 fixed:** shop-bought fish enter through `_wire()`; `Level.coin_kind_for()` tiers
  stage -> kind through EV-0047 (port tuning, Q-0036 stays open for the binary binding).
  `headless_mode_check` (28).
- **G7/P4.11 fixed:** `_apply_mode_flags()` writes `virtual_tank`, Sandbox money, the Time Trial
  budget (300/600 s in ticks) and per-mode save paths; Time Trial expires through collect-all +
  `money*5/100` with no pets; Challenge pays 2000/5000/10000/20000 + unlocks; Virtual Tank runs
  the 76/24 weighted spawner (26/25/25/10/5/3/3/3, 100-try retry), no wave, coins to shells.
- **G8 fixed:** `Pet.create` takes the tank RNG; `spawn_owned_pets()` takes the pending
  selection when non-empty (branch B) else the owned flags (branch A); every pet steers and the
  recovered slot-81 bodies are in (Prego, Zorf, Meryl, Amp, Gash/Itchy/Rufus/Walter, Stanley,
  Nimbus, Brinkley). The 8 guard bodies (Wadsworth, Seymour, Gumbo, Blip, Presto, ...) stay
  parameterised (Q-0044).
- **G10 fixed:** per-mode stems (`adv`/`tim`/`snd`/`sur`/`sim` + `profile+0x44`), the Hatch/Pets/
  Bonus + Options/Help/Hall screens, the roller (backdrop 15000, pet fallback), the profile JSON
  round trip, and golden fixtures (`headless_golden_check` 22, `headless_profile_check` 29).
- **G11/F1 fixed:** hunger/growth/pet/alien/wave/projectile cue signals are consumed
  (`CUE_SOUNDS` by semantic name, Q-0030 documented) and missile smoke/bursts spawn tick-counted
  particles; the tailflop loaded through the imported textures (no export warning on boot) and the
  overlay was later removed entirely (R10, Q-0055).
- **P5 closed:** `docs/P5-VALIDATION.md` (differential table, playtest checklist, timing,
  perf, packaging). **Superseded 2026-11-08:** the completion pass was revoked after the owner's
  playtest; see `PLAN.md`'s Review table (R8/R9 open).

Totals: **23 suites, 1123 assertions** (22 `--script` + the scene-backed integration suite),
boot exit 0. The F2 Ogg/ObjectDB notices are unchanged and are not failures.

## 6. Priority for the next sessions

1. **Give projectiles their behaviour** (G5): the homing body, then collision/damage against fish;
   only then does alien fire mean anything. The sprites and the HP bar now make the path visible.
2. **Fix the boss fight** (G6): pass the attacker for the 10-tick cooldown, pass the profile counter
   for HP scaling, and replace the Sylvester minion/pulse placeholders.
3. **Fix the economy wiring** (G4/G9): use `_wire()` for shop-bought fish and recover the stage ->
   coin-kind table (or keep the placeholder explicit in the store/UI).
4. **Implement the mode flags** (G7): `start_level` must set `virtual_tank`, demo/hint/pacing flags
   from the mode, or the mode lines should say "selection only".
5. **Pets and persistence** (G8/G10): selected-slot spawning, movement for the implemented pets,
   per-tank RNG for the pet ctors, per-mode save stems and profile serialization.
6. **Effects, UI and packaging** (G11/G12/F1): connect the cue signals, then the Hatch/Bonus/Pets
   screens, options/help, and the export-safe asset loading.

## 7. Reproduction

```powershell
$godot = "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe"
Get-ChildItem tests\headless_*_check.gd | ForEach-Object {
  & $godot --headless --path . --script ("res://" + $_.Name)
  "rc=$LASTEXITCODE $($_.Name)"
}
& $godot --headless --path . res://tests/headless_integration_check.tscn --quit-after 1200
"rc=$LASTEXITCODE headless_integration_check.tscn"
& $godot --headless --path . --quit-after 400
```

The suites need `assets_raw/` (regenerate per `README.md`) and exit 0 only when every assertion
passes; the boot check exits 0 even with the warnings in F1/F2, so read its log, not just its status.
