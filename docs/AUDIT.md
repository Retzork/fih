# Progress audit - 2026-11-05

Status: **evaluation of the checked-out tree**, not a behaviour change and not an `EV-` entry. It
records what the remake does today, how that was checked, and where the documentation and the code
still diverge. Facts about the original game stay in [`EVIDENCE.md`](EVIDENCE.md); the contract they
feed is [`SPECS.md`](SPECS.md).

## 1. Method and limits

- Ran all 18 headless suites separately with Godot 4.7.1
  (`C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe --headless --path . --script res://tests/...`).
- Ran the 400-frame boot check (`--quit-after 400`) and read its full log.
- Inspected `scripts/`, `tests/`, the generated assets, the git state and the docs against each other.

Limits, stated so the numbers are not over-read:

- The suites are **contract tests for the port**: each asserts the behaviour written in `SPECS.md`
  and the P2 notes. They are not differential tests against the running original. A green suite means
  "the port agrees with its contract", not "the port is indistinguishable from the game".
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
| P4 implementation | 3/14 tasks `[x]`, 11 `[~]` | all 11 in-progress tasks have landed code and at least one passing suite | understated by task count |
| P5 validation | 0/5 | not started; two concrete blockers now known (§5) | consistent |

**P4 reality.** The task count ("3/14") does not describe capability. Every P4.4-P4.14 task has real
code and a green suite, so the port has a working **vertical slice**: menu -> Adventure level ->
feeding/growth/coins -> store -> waves -> aliens -> Cyrax -> save/load -> next level. What it does not
have is a complete, faithful game. Every row of the `ARCHITECTURE.md` §9 gap table still contains at least one open
item; P4 delivered the skeleton and the ordinary path behind each row, not the row's full behaviour.
`[x]` does not mean "faithful to the binary" either - it means the task's documented scope was done.

## 4. Capability matrix

| Area | State | Basis |
| --- | --- | --- |
| tick driver, phases, pause, seeded RNG | done | `headless_sim_check`, `headless_entity_check` |
| content registry, typed handles, load phases | done | `headless_content_check` |
| feeding, hunger, growth, death/corpses, coins | done | `headless_fish_check`, `headless_coin_check`, `headless_level_check` |
| store UI + in-tank bar | partial: 7 of 12 items available; fixed table, no stock roller/art/tooltips; no boss HP bar | `Store.ITEMS`, `headless_store_ui_check`, Q-0047/Q-0049/Q-0052 |
| progression | partial: tables, egg purchase, pet award, advance; no bonus rounds, Hatch/Pets screens, credits or clickable egg widget | `headless_progression_check`, Q-0053 |
| pets | partial: 6 of 24 bodies (Stinky, Niko, Vert, Shrapnel, Nostradamus, Angie); 18 idle | `pet.gd` `_slot81()`, Q-0044 |
| aliens + waves | partial: kinds, bands, wave clock, eating; composite recipes not composed at the level | `headless_alien_check`, PLAN P4.8 |
| Cyrax boss | partial: fight runs; minion kind and pulse content are placeholders; no HP bar | `headless_boss_check`, Q-0047 |
| weapons/projectiles | partial: damage, click hit-tests, hold-to-fire; homing `_steer()` is a no-op, so spawned shots have zero velocity; no `Larva`, laser binding or weapon HUD | `projectile.gd:123`, Q-0041/Q-0023 |
| modes | partial: Adventure playable; Challenge inflates prices only; Time Trial clock/finish and Virtual Tank spawner absent | `level.gd` `game_mode` reads, PLAN P4.11 |
| saves | partial: full tank framing, scalars, store rows, pet flags, fish records; other entity bodies opaque; no golden fixtures | `headless_save_check`, `headless_tank_snapshot_check` |
| audio | partial: two mixers, 256-slot pool, music pairs; partial event map; no battle loop | `headless_audio_check`, Q-0030/Q-0056 |
| menus/UI | partial: game selector and shop; options/help/hall-of-fame recognised but absent; button labels are port text; loading bar is the debug pump | `headless_menu_check`, Q-0050/Q-0055 |
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
Conversely `[x]` tasks still carry open questions. The PLAN header now points here, but the summary
table will keep understating P4 until statuses become sub-item based or `[~]` tasks record a
done/total pair.

**F4 - Behavioural placeholders are honest but still load-bearing (medium, fidelity).** Beyond the
open questions' own notes: alien projectiles never move (Q-0041), the stage -> coin-kind table uses
kind 1 for every drop (Q-0036), the fish target timer uses `rand % 6` (Q-0039), the Virtual Tank coin
base is a placeholder (Q-0040), and the boss minion/pulse are placeholders (Q-0047). These make the
corresponding systems structurally verifiable but not yet faithful; they should not be read as
"combat is done".

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
statuses.

## 6. Priority for the next sessions

1. **P4.10 projectile homing** (`FUN_004FF4E0`): without it alien fire is inert, so no combat or
   difficulty claim can be checked. This is the documented next task and remains the right one.
2. **P4.11 Time Trial clock + collect-all finish**, then the Virtual Tank spawner: both are bounded
   and directly testable, and they turn selection-only modes into playable ones.
3. **P4.6 bonus rounds / Hatch / Pets screens**: the Adventure loop currently jumps from a completed
   level straight into the next level, so the game's actual progression flow is missing.
4. **F1 export fix + Q-0034 measurement (P5.3)**: both are small, and both gate packaging and feel.
5. Then pets (18 idle), store stock/art/HP bar, options/help screens, and the remaining sound triggers.

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
