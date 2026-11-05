# Progress audit - 2026-11-05

Status: **evaluation of the checked-out tree**, not a behaviour change and not an `EV-` entry. It
records what the remake does today, how that was checked, and where the documentation and the code
still diverge. Facts about the original game stay in [`EVIDENCE.md`](EVIDENCE.md); the contract they
feed is [`SPECS.md`](SPECS.md).

The first pass of this audit verified the suites and read the docs; it concluded the port had a
"working vertical slice". A code-level second pass (§5a) showed that was too generous: several
systems exist as entities and contract tests but are not connected to the assembled game.

## 1. Method and limits

- Ran all 18 headless suites separately with Godot 4.7.1
  (`C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tests/...`).
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
| `headless_projectile_check` | 47 |
| `headless_level_check` | 120 |
| `headless_store_ui_check` | 34 |
| `headless_progression_check` | 78 |
| `headless_menu_check` | 37 |
| `headless_pet_check` | 66 |
| `headless_alien_check` | 47 |
| `headless_boss_check` | 35 |
| `headless_save_check` | 38 |
| `headless_save_files_check` | 21 |
| `headless_tank_snapshot_check` | 54 |
| `headless_audio_check` | 40 |
| `headless_anim_check` | 18 |
| **Total** | **936** |

- All 18 suites exited 0; the per-suite counts above are the suites' own `PASS (... assertions)`
  summaries and sum to exactly the **936** claimed in `PLAN.md` and `README.md`.
- The boot check exits 0 and resolves the three content phases: `Init` 14, `Register` 16,
  `LoadingThread` 296 (326 ids, as `SPECS.md` §2.2 requires).
- Checkout is clean on `main` at `46d5f35`; `resources/sprites/` holds 129 `SpriteFrames`,
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
of the game works. The only assembled path that runs is: menu -> Adventure level -> feeding/growth/coins -> store.
**Level completion is not reachable on tanks 1-4** (G14), and the **wave -> alien -> boss path is
not reachable at all**: `Level.arm_wave()` has no production caller, composite waves are dropped, and
aliens, the boss and projectiles are never drawn. Every row of the `ARCHITECTURE.md` §9 gap table still has
an open item; several rows are scaffolds with their wiring missing, not partially faithful systems.
`[x]` means the task's documented scope was done, not that the system is connected or faithful.

## 4. Capability matrix

| Area | State | Basis |
| --- | --- | --- |
| tick driver, phases, pause, seeded RNG | done | `headless_sim_check`, `headless_entity_check` |
| content registry, typed handles, load phases | done | `headless_content_check` |
| feeding, hunger, growth, death/corpses, coins | done for guppies; other species share the guppy art; shop-bought fish are unwired (G4) | `headless_fish_check`, `headless_coin_check`, `headless_level_check` |
| store UI + in-tank bar | partial: 7 of 12 items available; fixed table, no stock roller/art/tooltips; no boss HP bar | `Store.ITEMS`, `headless_store_ui_check`, Q-0047/Q-0049/Q-0052 |
| progression | partial: tables, pet award and advance exist, but `buy_egg` has no UI entry point on tanks 1-4, so a level cannot be completed; no bonus rounds, Hatch/Pets screens or credits | `headless_progression_check`, Q-0053, G12/G14 |
| pets | partial: 6 of 24 bodies; only Stinky steers/collects; all owned pets spawn rather than the selected slots; two ctors use the global RNG | `pet.gd:150/152/289`, Q-0044, G8 |
| aliens + waves | scaffolded: kinds, bands, wave clock and eating rules exist, but the clock is never armed in play, composites are dropped and aliens are invisible | `level.gd:262/273`, `_make_visual`, G1-G3 |
| Cyrax boss | code-only: invisible, placeholder minions/pulse, 10-tick cooldown bypassed, HP never scaled, no HP bar | `level.gd:447`, `boss.gd`, G6 |
| weapons/projectiles | inert: damage and click tests exist, but `_steer()` is a no-op, there is no collision/damage path and no sprite; no `Larva`, laser binding or weapon HUD | `projectile.gd:123`, G5 |
| modes | Adventure only; Challenge inflates prices only; Time Trial/Virtual Tank rules absent; the mode flags have no writers | `tank.gd:48-66`, G7 |
| saves | fish-only entity records; per-mode save stem unused (always `adv1`); profile not persisted; a loaded wave selection is not armed | `level.gd:81`, `profile.gd`, G10 |
| audio | two mixers, 256-slot pool, music pairs; most effect cues have no consumer; no battle loop | `headless_audio_check`, G11 |
| menus/UI | game selector and shop; options/help/hall-of-fame absent; button labels are port text; loading bar is the debug pump | `headless_menu_check`, Q-0050/Q-0055 |
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
Conversely `[x]` tasks still carry open questions and unwired paths (G1-G12). The PLAN header now
points here, but the summary table will keep misrepresenting P4 until statuses record sub-items.

**F4 - Behavioural placeholders are honest but still load-bearing (medium, fidelity).** Alien
projectiles never move (Q-0041), the stage -> coin-kind table uses kind 1 for every drop (Q-0036),
the fish target timer uses `rand % 6` (Q-0039), the Virtual Tank coin base is a placeholder (Q-0040),
and the boss minion/pulse are placeholders (Q-0047). §5a adds the cases where the gap is not an
unknown but a missing connection.

**F5 - Green tests are machine-local (medium, reproducibility).** `assets_raw/` and the carved module
are gitignored. A fresh clone cannot boot or run any suite until the five PowerShell extractors run
against the owned install. This is documented, but it means the 936 assertions verify *this* checkout,
not the repository alone.

**F6 - Assertion reporting is inconsistent (low, tooling).** Fifteen suites print an `ok` line per
assertion; `headless_anim_check`, `headless_audio_check` and `headless_menu_check` print only failures,
so a naive `grep -c '^  ok'` reports 841 instead of 936. The PASS summary is the reliable count; a
shared check harness would remove the trap.

No stale count or contradiction was found in the docs: `PLAN.md`, `README.md`, `docs/README.md` and
`ARCHITECTURE.md` all agree on 18 suites, 936 assertions, the 36 Hz tick decision and the phase
statuses. What they did not describe is the assembly gap in §5a.

## 5a. Implementation fidelity (code-level pass)

These are not open reverse-engineering questions; they are places where the code, the suites and the
documentation describe a system but the assembled game does not exercise it. No code was changed in
this audit.

| # | Finding | Evidence | Effect in the game |
| --- | --- | --- | --- |
| G1 | the wave clock is never armed | `Level.arm_wave` (`level.gd:262`) is called only from tests; `start_level` (`level.gd:333`) never arms it and no schedule sets a selection | no alien waves in normal play |
| G2 | composite waves are dropped | `WaveClock` emits selections 9..0xC; `_on_wave_spawn` (`level.gd:273`) returns unless `Alien.DEFS.has(selection)`, and `DEFS` has no 9..0xC | even a manually armed composite wave spawns nothing |
| G3 | aliens, boss and projectiles have no sprite | `_make_visual` (`level.gd:762`) handles Fish/Food/Coin/Pet/DeadFish and returns null otherwise; `alien.gd`, `boss.gd` and `projectile.gd` contain no `Sprite2D` | invisible threats and shots; only their 80x80 click box reveals them |
| G4 | shop-bought fish are not wired to the level | `buy_item` (`level.gd:574`) calls `tank.spawn_fish(...)` directly; initial and bred fish go through `_wire()` | bought fish never emit `died`/`coin_due`/`breed_requested`: no coins, no corpse, no breeding |
| G5 | projectiles are inert and cannot damage fish | `Projectile._steer()` is `pass` (`projectile.gd:123`); `_advance` has no fish/alien collision, only a click hit-test | alien attacks produce stationary, harmless, invisible shots |
| G6 | Cyrax is a placeholder and its damage cooldown is bypassed | `_on_boss_minion`/`_on_boss_pulse` both spawn kind `0x01` (`level.gd:447-452`); `try_shoot` calls `hit(damage, true)` without an attacker (`level.gd:296`), skipping `Boss.hit`'s 10-tick cooldown; `Main` starts the level without the profile counter (`main.gd:51`), so HP is always 5000 | placeholder fight; click-spam damage; no HP scaling or HP bar |
| G7 | every mode flag except Challenge inflation is dead | `Tank.virtual_tank`, `demo_mode`, `coin_difficulty_value`, `coin_pacing_gate_value`, `coin_hint_active`, `tank_flag_16c`, `penta_present`, `pet_sources_busy` are declared and read but never written (`tank.gd:48-66`) | Virtual Tank growth/coin rules unreachable; Stinky never hides; Penta coin exclusion inert; only Challenge inflation does anything |
| G8 | pets: only Stinky moves; all owned pets spawn; two ctors use the global RNG | `Pet._steer` (`pet.gd:289`) returns unless `index == STINKY`; `spawn_owned_pets` loops every owned flag, not `Profile.selected_pets`; `Pet.create` calls global `randi_range` (`pet.gd:150/152`) | up to 24 pets stand still; Angie cannot reach a corpse; runs are not reproducible |
| G9 | coin production is a single placeholder | `_on_coin_due` (`level.gd:490`) always spawns kind 1 (15 shells); the stage -> kind table is Q-0036 | high-value fish and stages pay the same 15; the economy is flat |
| G10 | saves write one fixed path and the profile is not persisted | `Level.save_path` is `userdata/adv1.dat` (`level.gd:81`); `Game.save_stem` has no caller; `Profile` has no serialization; `TankScalars.apply` restores `alien_selection` but `load_game` never arms `wave.selection` | every mode overwrites the Adventure slot; progress resets on restart; a loaded wave selection does nothing |
| G11 | most effect/audio signals have no consumer | no listener for `fish.hunger_warning`/`grew`, `coin.expired`/`banked`, `pet.cue`, `alien.cue`, `projectile.smoke_requested`/`burst_requested` or `wave.milestone` | no hunger/growth/pet/alien sounds, no smoke/burst/wave warnings; only drop/buy/click and music play |
| G12 | progression and UI stop at the level boundary | `Main._on_level_completed` starts the next level directly (`main.gd:59`); no Hatch/Pets/Bonus/credits/egg widget; no boss HP bar; store has no stock roller/art/tooltips; options/help/hall-of-fame absent | the Adventure loop has no between-level flow, and much of the original UI is missing |
| G13 | the suites mask these gaps | `headless_level_check` calls `arm_wave` itself (line 375); the boss suite builds a `Tank` and calls `spawn_boss` directly; store tests inject prices; no suite drives menu -> level -> wave -> boss through `Main` | green tests are not evidence that the assembled game exercises these paths |
| G14 | level completion is unreachable on tanks 1-4 | `buy_egg` is called only from `buy_item` for `EGG_ITEM` (`level.gd:580`), and `STORE_TABLE[11]` stocks that row only on tank 5; no egg widget exists | Adventure cannot advance past level 5 of any tank in normal play; only tests (and the tank-5 shop row) can call the API |

Consequences worth stating plainly:

- The playable game today is a feeding/economy sandbox with invisible, unreachable threats, and it
  cannot finish a tank on tanks 1-4. It is not an Insaniquarium session.
- The "aliens + waves", "boss", "weapons" and "modes" task lines should be read as **entity and table
  work complete, integration incomplete**.
- The 936 assertions remain real and useful, but they mostly prove modules, not flows.

## 6. Priority for the next sessions

**First blocker:** none of the combat work matters until a level can actually be completed from the
UI. G14 is the smallest end-to-end fix; G1-G3 are next.

1. **Give tanks 1-4 an egg purchase and completion path** (G14): draw the egg widget or stock the egg
   row, and add a headless check that completes a level through the shop rather than `buy_egg()`.
2. **Wire the production wave path** (G1/G2): arm the clock from level data in `start_level`, arm it
   after a load, and resolve composite selections into their member kinds. Add a headless check that
   starts from `start_level` and observes a wave without calling `arm_wave` by hand.
2. **Make threats visible** (G3): sprites for aliens, the boss and projectiles, plus the HP bar. Until
   this exists, no combat claim can be checked visually.
3. **Give projectiles their behaviour** (G5): the homing body, then collision/damage against fish;
   only then does alien fire mean anything.
4. **Fix the boss fight** (G6): pass the attacker for the 10-tick cooldown, pass the profile counter
   for HP scaling, and replace the Sylvester minion/pulse placeholders.
5. **Fix the economy wiring** (G4/G9): use `_wire()` for shop-bought fish and recover the stage ->
   coin-kind table (or keep the placeholder explicit in the store/UI).
6. **Implement the mode flags** (G7): `start_level` must set `virtual_tank`, demo/hint/pacing flags
   from the mode, or the mode lines should say "selection only".
7. **Pets and persistence** (G8/G10): selected-slot spawning, movement for the implemented pets,
   per-tank RNG for the pet ctors, per-mode save stems and profile serialization.
8. **Effects, UI and packaging** (G11/G12/F1): connect the cue signals, then the Hatch/Bonus/Pets
   screens, options/help, and the export-safe asset loading.

## 7. Reproduction

```powershell
$godot = "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe"
Get-ChildItem tests\headless_*_check.gd | ForEach-Object {
  & $godot --headless --path . --script ("res://" + $_.Name)
  "rc=$LASTEXITCODE $($_.Name)"
}
& $godot --headless --path . --quit-after 400
```

The suites need `assets_raw/` (regenerate per `README.md`) and exit 0 only when every assertion
passes; the boot check exits 0 even with the warnings in F1/F2, so read its log, not just its status.
