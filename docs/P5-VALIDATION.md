# P5 - Validation & polish (in review)

Status: **withdrawn pending the Review fixes** (2026-11-09). The 2026-11-08 completion pass was
revoked by the owner after a playtest; `PLAN.md`'s Review table is the work list. This document
keeps the constant sheet (P5.1), the playtest checklist (P5.2), the timing model (P5.3), the
performance sanity (P5.4) and the packaging decision (P5.5) as reference evidence, but P5.2/P5.3
cannot close until R8 (windowed tanks 2-4/5-1) and R9 (pet guards) pass. Every value below cites
its `EV-` entry or its port code path; nothing here is new binary evidence.

Test totals for the tree this document describes: **24 suites, 1303 assertions** (2026-11-10
re-run: 23 `--script` suites at 1203 plus the scene-backed integration suite at 60). The boot
check exits 0. The pre-existing Ogg vendor-comment warnings and the ObjectDB/resource leak
notices at exit are unchanged (AUDIT F2) and are not failures.

## P5.1 - Constant cross-check (differential table)

Every recovered value the port ticks against, seeded from `SPECS.md` §10 and verified
against the code named in the right column. "Port" is the site that must change if the
value ever moves.

| value | meaning | evidence | port site |
| --- | --- | --- | --- |
| 1000/36 ms (36 Hz) | logic tick | EV-0034 (100 Hz wrapper) vs Q-0034 port decision 2026-11-04 | `scripts/autoload/sim.gd` `TICK_MS` |
| 0.85 | update multiplier | EV-0034 | `Sim.UPDATE_MULTIPLIER` |
| 640x480 | logical resolution | EV-0034 | `project.godot`, `canvas_items`/`keep` |
| 10 ticks / 1000 ms | catch-up cap / backlog clamp | EV-0034 | `Sim` |
| `x 31..586`, `y 61..399` | feed/click water | EV-0122 | `Level` click order |
| `x 10..540`, `y 95..370` | fish spawn band | EV-0049 | `Fish.SPECIES` |
| 80x80, 10 columns | sprite cell / sheet layout | EV-0026 | `ImageRes`, `Level` |
| 400-599 / 600-799 | initial hunger (common / Oscar) | EV-0049 | `Fish.SPECIES` |
| 4-6 / 12-20 | growth threshold (normal / VT) | EV-0049 | `Fish._configure` |
| 8 / 15 | stage-4 overshoot multiplier (VT / normal) | EV-0056 | `Fish._apply_growth` |
| -1, -200, -400, -500, -1000 | hunger hint / HUD / death / clamp | EV-0048 | `Fish` |
| +500/+700/+1100, caps 800/1000/1400 | nutrition by food quality | EV-0048 | `Fish._consume` |
| 370 / 410 (400 star) | coin floor / food death line | EV-0045, EV-0047 | `Coin.LAND_Y`, `Food.DEATH_Y` |
| 2.0 / 1.8 / 1.6 | fish speed classes | EV-0049 | `Fish.SPEED_CLASSES` |
| 3000 ticks | alien wave clock | EV-0114 | `WaveClock.WAVE_TICKS` |
| 50/60/130/100/150/220/260, 1, 2500-5000 | alien hp by kind (1/2, 3, 4, 5, 6, 7, `0x14`, `0x15`) | EV-0111 | `Alien.DEFS`, `Boss` |
| ±45/±65 (mini ±30, vs type 6 ±70/±85) | bite reach box | EV-0116 | `Alien` |
| 75 ticks, then `rand%50+150` | Destructor/Ulysses attack period | EV-0113 | `Alien.MISSILE_PERIOD` |
| 400 ticks | Psychosquid rest cycle | EV-0113 | `Alien.REST_TICKS` |
| 80x80 x2 heads, 100 hp | Bilaterus | EV-0112 | `Alien.DEFS` kind 8 |
| `5000 - 125*clamp(n-1,0,20)` | Cyrax hp | EV-0117 | `Boss.max_hp_for` |
| 75 / 300 ticks, `rand%6+4` | Cyrax minion / pulse | EV-0117 | `Boss.MINION_TICKS`, `Level._on_boss_pulse` |
| `3 * weapon_level` | shot damage (6 at level 2, 30 at the boss's 10) | EV-0120, EV-0121 | `Tank.shot_damage` |
| 10 ticks | per-alien hit cooldown | EV-0120 | `Boss.HIT_COOLDOWN` |
| `11 - level/2`, ≥ 100 ms | Rapid Fire period | EV-0129 | `Level.hold_fire_period` |
| 200 / 999999 / 5 / 2 | start money / Sandbox money / pellet price / pet capacity | EV-0128 | `Level._apply_mode_flags`, `Tank` |
| 15000 | backdrop price in the store roller | EV-0141 | `Profile.BACKDROP_PRICE`, `Level.roll_stock` |
| `[10,10,15,20,25,10]` + level - 1, 160 ticks | bonus timer base, post-completion wait | EV-0076 | `BonusScreen.payout_for` uses the payout switch; the wait stays with `Progression.resolve_start` (Q-0053) |
| `5000*(counter-1)`, clamp 25000 | tank-5 bonus shells | EV-0076 | `BonusScreen.payout_for`, banked by `Main._on_level_completed` (adventure only, once) |
| 300 s / 600 s | Time Trial budget (tank 1 / 2-4) | EV-0127 | `Level.time_trial_budget_ticks` (ticks at 36 Hz) |
| 150/150/175/200 ticks | Challenge price inflation period | EV-0127 | `Level.inflate_prices` (per-tick shape via `Store.inflate`) |
| 76/24 % and 26/25/25/10/5/3/3/3 | Virtual Tank fish roll | EV-0128 | `Level.spawn_virtual_fish`, `VT_PRIZE` |
| 0..9,999,999 | shells clamp | EV-0066 | `Profile` |
| 2000/5000/10000/20000 | Challenge flat rewards (tanks 1-4) | EV-0127 | `Level.CHALLENGE_REWARDS` |
| 256 | effect-slot pool | EV-0149 | `Audio.SFX_SLOT_LIMIT` |
| ids 1/3/4 | music tracks (Alien, Lullaby, Insaniq2) | EV-0147 | `Audio.TRACKS` |
| `(0,22)/(0,0)/(2,32)/(2,45)`, `(0,13)` | stage 1-4 / level complete music | EV-0148 | `Audio.PAIR_STAGE`, `PAIR_LEVEL_COMPLETE` |

Port tunings, not recovered values (kept in code, not here): the stage -> coin-kind tier
table (`Level.coin_kind_for`, Q-0036), the fish wander selector and Clyde's 2D step,
the alien wander target, the bottom-lane height, the laser row binding
(`Level.laser_cell_for`, Q-0023), and the `SHEET_FRAME_TICKS = 5` entity clock (Q-0057).

## P5.2 - Side-by-side playtest (per tank/level)

The original remains the judge; this is the checklist a human runs with both builds open.
Statuses are what the headless suites already assert; anything that needs eyes is marked
"windowed".

| tank : level | expected port behaviour | suite |
| --- | --- | --- |
| 1:1 | no wave; feeding/growth/coins; first fish tutorial line | `headless_level_check`, `headless_integration_check` |
| 1:2 | Sylvester wave armed at 1750 ticks; bonus wait walked | `headless_level_check` (1750), windowed check of the banner |
| 1:3-1:4 | Balrog/Gus waves; Challenge inflation only in mode 4 | `headless_alien_check`, `headless_mode_check` |
| 1:5 | tank-5 gate armed (waves freeze, pet capacity 10 on Cyrax, HP bar always) | `headless_boss_check`, `headless_integration_check` |
| 2:1-2:5 | Re-rolls and pairs (2:5 pair, composite 9) | `headless_level_check` (composites), windowed re-roll rate |
| 3:1-3:5 | Composite-driven roster; Ball/Bi art only | windowed (Q-0042 species art) |
| 4:1-4:5 | Bolt-on store tables; 4:5 is the 999 card (no grant) | `headless_progression_check` |
| 5:1 | Cyrax: 300-tick arrival (unhittable), 75-tick Minisylvester, 300-tick pulse while the field is clear, death wipe, `profile+0x54` bump | `headless_boss_check` (46) |
| Time Trial (any) | 300/600 s clock, collect-all expiry, `money*5/100` shells, no pets | `headless_mode_check` |
| Challenge (any) | per-item inflation, type-8 -> 0xC after wave 4, flat 2000-20000 shells, unlock byte | `headless_mode_check`, `headless_progression_check` |
| Virtual Tank | no music, no wave, weighted spawner, coins -> shells, `sim<slot>.dat` | `headless_mode_check`, `headless_profile_check` |
| Sandbox | 999999 money, price re-roll, no tank-5 case | `headless_mode_check` |
| Between levels | Hatch -> Pets -> Bonus -> next level; tanks advance, Presto pays 5000 shells; Hatch draws the recovered card art, Pets/Bonus stay text-only | `headless_profile_check`, `headless_integration_check` (5-1 walk), `shot_tank5_*.png` |
| Menus | selector gates ("Not Yet!"), Options sliders, Help 8 pages, Hall 4 tabs | `headless_menu_check`, `headless_profile_check` |

Screenshots: `tools/godot/screenshot.gd` still captures menu/level/store windowed; the
headless driver renders nothing, so the art check stays a human step.

## P5.3 - Timing / feel

The remake runs the **~36 Hz** reading of Q-0034 (`Sim.TICK_MS = 1000/36`). Consequences,
all in integer ticks:

- wave clock 3000 ticks = 83.3 s; boss arrival 300 ticks = 8.3 s; first missile 75 ticks.
- pellet tumbler 10 columns at 3.6 rotations/s (readable; at 100 Hz it blurs).
- weapon hold-to-fire at level 12 is 5 ticks ≈ 139 ms, floored at 100 ms.
- Blip 200/720 ticks = 5.5/20 s; Prego 930 = 25.8 s; Meryl 1400 = 38.9 s.
  These are why 36 Hz was chosen (2026-11-04 port decision).

The wrapper's 10 ms interval stays open as Q-0034: changing the rate is one constant.
A live-measurement pass against the original (stopwatch on wave arrival) is still the
only way to close the question; there is no per-wave timing figure in the wiki.

No simulation code may use `delta` or hard-code a rate (ARCHITECTURE §1). Presentation
(`_process`, HUD, screen flow) runs on the same tick counters.

## P5.4 - Performance sanity

A 2D Godot game: the tick driver walks small phase buckets once per slice, and each
entity is one `Sprite2D` (plus one HP bar per alien). There are no physics bodies, no
shaders beyond the default, and no per-tick string lookups (resource handles are
captured at spawn). Entity counts in play stay in the dozens (a few dozen fish, up to
24 pets, a wave of aliens), each doing O(1) arithmetic per tick; the phase walk is a
copy of the bucket (needed after the mid-tick despawn fix). No profiling run was needed
beyond the boot check: the 400-frame headless boot and the 1200-frame integration scene
both exit 0 with no script error, and the full 23-suite run is seconds, not minutes.

The one perf note that matters: `_sync_visuals` and `_sync_fx` rebuild per-entity state
every frame while rendering, which is the right shape for this count; if a future level
ever holds hundreds of live entities, per-cell keying (already cached per `(id, cell)`)
is the only place left to look.

## P5.5 - Packaging decision + run guide

Decision: **keep Forward Plus and `canvas_items`/`keep` stretch at 640x480** (Q-0005
pixel-exact policy). The 3D physics engine setting stays Jolt and unused - there is no
3D physics in the original and none in the port. Renderer changes are not needed to ship.

Export checklist:

- `resources/content.json` is committed and generated; it must be included in the export.
  The export prescription is to include the non-resource file (or convert it to a `.tres`
  in a future pass); `tools/godot/gen_content.gd` fails if the 14/16/296 partition drifts.
- `assets_raw/` is gitignored/regenerable. An export needs it present at build time:
  regenerate per the README Quick start, then `--import`, then export.
- The tailflop overlay is removed (R10, Q-0055): the menu leaves the baked `SELECTORSCREEN`
  art alone, so no raw PNG is loaded at runtime and the old export warning (F1) cannot recur.
- The `Profile` file is `user://profile.json` (the port's own format, SPECS §7.4); tank
  saves stay `userdata/<stem><slot>.dat` in the port's framing (same paths, own bytes).
  Neither writes into the read-only original install.
- Personal-use note (Q-0006): the extracted art/audio/music must not be redistributed;
  a public build needs replacement assets.

Run:

```powershell
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 400
```

This boots the selector and pumps the loading bar to completion (exit 0). The full
suite is the 24 headless checks plus the scene-backed integration check (see README).
