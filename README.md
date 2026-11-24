# Insaniquarium Deluxe → Godot 4.7 remake

A faithful remake of **Insaniquarium Deluxe v1.1 (Steam)** in **Godot 4.7.1**, reconstructed from
the shipped binary rather than from source (the original has none). The game install is treated as
a **read-only target**: every behavioural claim in this repository is backed by a numbered entry in
[`docs/EVIDENCE.md`](docs/EVIDENCE.md) (`EV-NNNN`), produced with REA + Ghidra and file inspection.

**Source:** <https://github.com/Retzork/fih>

The remake is **playable end-to-end in Adventure**: menu → 15 levels across 5 tanks → hatch /
pets / bonus cards → next tank, with the store economy, alien waves, the Cyrax boss, pets, coins,
saves and the original art/audio extracted from the owned copy. It is **not finished**: the
owner's playtest list in [`docs/REVIEW.md`](docs/REVIEW.md) still has open rows, and the suites
prove modules, not the assembled feel.

> **Status date: 2026-11-24.** 27 headless checks green, **1,862 assertions**; the 400-frame boot
> exits 0. See [Status at a glance](#status-at-a-glance) and [What is still open](#what-is-still-open).

---

## Status at a glance

| Area | State |
| --- | --- |
| **Engine** | Godot **4.7.1** stable, GDScript, Forward+, 640×480 logical canvas (`canvas_items` stretch), five autoloads |
| **P0 — environment/tooling** | **Complete** (13/13): REA 6.5.0 + Ghidra 12.1.4 + JDK 21 on Windows, wrapper + snapshot cache |
| **P1 — target identity** | **Complete** (10/10): hashes, PE layout, PopCap SexyAppFramework provenance, DRM boundary, embedded game module carved |
| **P2 — reverse engineering** | **16/18**: every technical system decoded (`P2.1-P2.15`, `P2.18`); only the optional screensaver (`P2.16`) and cheat (`P2.17`) passes remain |
| **P3 — asset pipeline** | **Complete** (8/8): 326 resource ids, 129 `SpriteFrames`, 50 OGG + 15 AU sounds, 3 music tracks, 15 bitmap fonts |
| **P4 — Godot implementation** | **In review** (5/14 tasks `[x]`: architecture, content registry, entities, boss, modes). The rest is implemented but kept `[~]` until the assembled game passes the playtest |
| **P5 — validation/polish** | **0/5, withdrawn** pending the playtest (`docs/P5-VALIDATION.md`): constant sheet, side-by-side and packaging stay reference-only |
| **Playtest review (R-list)** | **R1-R68**: 61 rows closed, **R9 partial** (4 pet guards), **R8** captured but awaiting the owner's live playtest, and **5 open**: R52, R53, R58, R61, R64 |
| **Verification** | **27 checks / 1,862 assertions** — 26 script suites (1,723) + the scene-backed integration suite (139); all re-run green on 2026-11-24 |

The evidence side currently runs to **`EV-0251`**, with the settled decisions (`D-`) and open
questions (`Q-`) registers alongside. `docs/PLAN.md` is the source of truth for task status;
`docs/REVIEW.md` for what is still wrong.

---

## What is playable

### The loop

- **5 tanks × 5 levels** with the recovered store tables (`Progression`), egg pieces and prices,
  pet awards, and the tank-5 free egg.
- **Adventure**: buy fish/food/weapons, feed, collect shells, survive the wave clock, complete the
  level by buying the fourth egg piece, then the between-level cards.
- **Bonus round** after a normal tank-1..3 level-5 completion: the recovered 160-tick wait, the
  level-scaled timer, the shell bank and the payout card (`BonusRound`, `BonusScreen`). Tank 4-5
  and tank 5 keep their shipped no-round paths.
- **Hall of Fame** records: per-level Adventure times and per-tank Challenge times are written on
  completion and read back by the hall's tabs.
- **Modes**: the selector writes **Adventure (0)**, **Time Trial (1)**, **Challenge (4)** and
  **Virtual Tank (5)**; Time Trial's budget/expiry clock, Challenge's price inflation and score
  records, and VT's weighted spawner are in. **Sandbox (3)** is implemented but no shipped button
  writes it (Q-0014). Per-mode save stems (`adv`/`tim`/`snd`/`sur`/`sim`) are used.
- **Loss**: when the last fish dies the shipped **"GAME OVER" card** appears ("Oops! All of your
  fish have died!" / "Click to Continue"); the button pauses the tank and returns to the menu.

### Creatures and combat

- **Fish**: one `Fish` class + a species table — Guppy → Carnivore → Ultravore, Beetlemuncher,
  Ball Fish, and the Minisylvester / Bilaterus-head bodies. Hunger/death/corpse, growth thresholds,
  the star potion, breeding pellets, the per-stage swim art, and the `HUNGRYSWIM` transition are
  implemented.
- **Food**: the decoded fall/drift/die physics, quality levels (normal → star potion), sink-out, and
  Angie's re-laid pellets that really land and bob.
- **Coins**: all 27 recovered kind → art bindings (money, shells, pearls, money bag, the peanut, the
  `rand%3+3` pickup burst), collection, claiming and the stage → kind economy.
- **Aliens**: eight kinds (Sylvester ×2, Balrog, Gus, Destructor, Ulysses, Psychosquid, Bilaterus)
  plus the 1-HP Minisylvester, the 3000-tick wave clock, per-level type re-rolls, bite reach,
  missile/ball attacks, drops and death.
- **Boss**: **Cyrax 5000** on tank 5-1 — 300-tick arrival, minion spawns, the 300-tick pulse, the
  per-attacker damage cooldown, HP bar, defeat cleanup and the attempts counter.
- **Weapons**: click-to-shoot with the recovered click order (larva → missile → alien → coin →
  feed), `3 × weapon level` damage (30 at the boss-forced level), level-12 **Rapid Fire**
  hold-to-fire, homing missiles, deflected balls, and the `Larva` entity.

### Pets

- **24-entry roster** with its family/speed/timer tables, per-pet coin predicates, and the
  slot-81 gate order (pause → tank 5 → hostile aliens).
- Behaviours wired: Stinky's coin chase and hide counter, Niko's pearl cycle, Angie's revive and
  food re-lay, the plain timer droppers (Vert, Shrapnel, Nostradamus, Prego, Zorf, Meryl, Nimbus,
  Brinkley, Stanley, Gash, Amp's charge), plus the R9 additions — Wadsworth's shelter steering,
  Gumbo's opposite-corner protocol, Blip's store unlock and Presto's transform with the CHANGE-O
  picker. Every pet draws its own sheet, one row at a time.
- **Four behaviours stay guarded** (R9 / Q-0044): Seymour's aura writer, Amp's click/electrocute,
  Nostradamus' sneeze and Walter's glove launch. Unrecovered tuning cells stay `0` rather than guessed.
- The **pets screen** is the shipped 24-button grid with the four-pet cap and the bright selected
  dome + ring.

### Screens and UI

All UI is drawn with the game's own extracted art and fonts (`UiFont`), not engine defaults:

- **Game selector** (`SELECTORSCREEN` art, eight measured button rects, mode gates, the mermaid's
  animated tail).
- **Tank**: the `MENUBAR` bar with seven store domes, the egg dome, the wallet plate, the tank
  name/hint row.
- **Store screen** with its eight shelves, prices, "Sold out" rows and the Shell counter.
- **Dialogs**: in-tank **Options** (sliders/checkboxes, Help, OK, Back to Main Menu), port-only
  **Debug** panel/dialog, **Help**, **Presto picker**, **Pets**, **Hatch**, **Bonus**, **Game Over**,
  plus the main-menu **Hall of Fame**.

### Audio

Two mixers like the original: a **256-slot** SFX pool on the `Sfx` bus (id-only plays, overlapping
copies, "Out of free sound ids" when full) and a looping `Music` bus with the three shipped tracks
(`Alien`, `Lullaby`, `Insaniq2`), driven by the recovered `SetMusic` pairs; Virtual Tank is silent.
Options' sliders seed from and write the buses. **Both volumes start at 0.0** — a temporary port
choice (Q-0056), so raise them in Options to hear anything.

### Persistence

- Per-mode tank saves in `userdata/<stem><slot>.dat` using the recovered **version `0x36`** framing
  (header, entity stream, pet flags, a 316-byte scalar block, a 12-row store table of 17-byte rows,
  timestamp).
- Snapshot/restore of live fish, money, food quality/quantity, weapon level, backdrop, wave clock,
  star-potion flag and tint; `F5` saves, `F9` loads (dev keys).
- The live profile is JSON at `user://profile.json` (the original `user%d.dat` remains the reference
  format); golden save fixtures are pinned byte-for-byte.

### Presentation

129 committed `SpriteFrames` generated from the extracted sheets; tick-driven animation from the
resource metadata (`anim`, `framedelay`, `perframedelay`, `framemap`) instead of one global fps;
colour-keying and alpha-mask composition at draw time (`SpriteKey`, `MaskAlpha`); tick-by-tick
sprite rows for fish, pets and aliens.

---

## What is still open

From [`docs/REVIEW.md`](docs/REVIEW.md) — the owner's confirmed playtest defects:

| # | Defect | State |
| --- | --- | --- |
| R8 | Live playtest of tanks 2-4 and 5-1 (alien art, HP bars, missiles, coin drops) | Windowed captures done; **live check still owed** |
| R9 | Pet guards: Seymour's aura writer, Amp's click, Nostradamus' sneeze, Walter's glove | **Partial** (all other pets act) |
| R52 | Fish swim speed feels off | **Open** — not yet matched to the binary/recording |
| R53 | Fish swim target is far off | **Open** — likely Q-0038/Q-0039 |
| R58 | Egg animation when a pet is revealed is wrong | **Open** — timing not yet compared |
| R61 | Alien hitbox: clicks land away from the drawn alien | **Open** — Q-0046 (P4.8 was re-opened for it) |
| R64 | Dome-shop row geometry is slightly off | **Open** — needs a re-measure |

Other known gaps (not R-rows):

- **Credits and trophy screens** and the pre-bonus store / `scr%d.dat` escrow are unported
  (Q-0053, Q-0013, Q-0016); they have no recovered entry point yet.
- **Weapon HUD and laser art binding** plus a **larva spawner** (Q-0023) — the Larva entity exists
  but nothing creates one, and the draw-side laser binding is still unbound.
- **Battle music trigger** (Q-0030) — the rest of the event → sound map is wired.
- **Tick rate (Q-0034)** — the wrapper loop is 100 Hz but every gameplay timer calibrates at ~36 Hz;
  the port runs one `Sim.TICK_MS` at 36 Hz until the missing gate is found.
- **P2.16/P2.17** (screensaver deltas, cheat codes) are optional and unstarted.
- **P5** validation is withdrawn until R8/R9 pass; packaging (P5.5) is still a reference decision,
  not a build pipeline.

---

## Controls

| Input | Action |
| --- | --- |
| **Left click** | Run the recovered click order: larva → missile → alien (shoot) → coin (collect) → else drop food. Food costs 5 shells (free in Virtual Tank) |
| **Hold left button** | Rapid fire once the weapon reaches level 12 |
| **Mouse move while firing** | Re-aim the next shot |
| **`S`** | Open the shop screen (port-only key, Q-0052); `Esc` closes it |
| **`P`** | Open the Presto CHANGE-O picker (port-only key, EV-0181); `Esc` closes it |
| **MENU button** | Open the in-tank Options dialog over a paused tank (owner-directed divergence, D-0015) |
| **`Esc`** | Close the current dialog / modal |
| **`F1`** | Toggle the port-only debug panel |
| **`F2`…`F10`** | Debug actions: money, grow, feed, save, egg, weapon, reveal store, load, spawn guppy |
| **`F12`** | Toggle the FPS/tick stats overlay (hidden by default) |

---

## Quick start

### Requirements

- **Windows 10/11** (verified on Windows; the port is plain 2D Godot and should run anywhere Godot does).
- **Godot 4.7.1 stable** (the project is saved with `config/features = 4.7`).
- **PowerShell 5.1+** for the extraction tools.
- **A legally owned copy of Insaniquarium Deluxe v1.1 (Steam)** — needed once to regenerate the
  assets. The repository ships **no game art, audio or fonts** (see [Assets and legal](#assets-and-legal)).
- *Optional, for re-deriving evidence:* REA 6.5.0, Ghidra 12.1.4 and JDK 21 (see
  [`AGENTS.md`](AGENTS.md)).

### 1. Regenerate the assets (once)

The tools default to the canonical Steam install; pass `-AssetsRoot` / `-Manifest` if yours lives
elsewhere. Output goes to the gitignored `assets_raw/`.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\parse-resources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1
```

Only if an asset changes, regenerate the committed registry:

```powershell
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_content.gd
```

### 2. Import and run

```powershell
# verify the project imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import

# play (windowed)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --path .

# headless boot for 400 frames (no script errors expected)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 400
```

The boot scene resolves the content manifest (`Init` → `Register` → `LoadingThread`, 326 ids), then
mounts the selector. `tools/godot/screenshot.gd` captures menu/level/store to `docs/captures/`
(gitignored) when run windowed; the headless driver renders nothing.

### 3. Run the checks

Every suite is a standalone headless run that exits **0 on pass** and prints its assertion count.
Re-run on 2026-11-24: **1,723 assertions across 26 script suites**, plus the 139-assertion
integration scene = **27 checks / 1,862 assertions**.

| Suite | Covers | Asserts |
| --- | --- | --- |
| `headless_sim_check` | tick driver, phases, catch-up cap, 36 Hz contract | 20 |
| `headless_content_check` | 326-id registry, load order, typed handles | 51 |
| `headless_entity_check` | entity/tank seam + Food rules | 43 |
| `headless_fish_check` | Fish ctor/hunger/swim/eat/growth/coins | 165 |
| `headless_coin_check` | coin art bindings, physics, collection, bursts | 168 |
| `headless_projectile_check` | missiles, homing, deflection, larva | 64 |
| `headless_level_check` | feeding, waves, shooting, pets, loss, saves | 264 |
| `headless_render_check` | effect-layer pool ↔ effect lists | 21 |
| `headless_store_ui_check` | shop screen + `MENUBAR` bar geometry | 97 |
| `headless_progression_check` | store tables, egg prices, pet awards, advance | 86 |
| `headless_menu_check` | selector ids, mode writers, gates, tail strip | 28 |
| `headless_mode_check` | Time Trial/Challenge/Virtual Tank/Sandbox wiring | 28 |
| `headless_weapon_check` | Larva, laser sparks, weapon scaling, cue consumers | 23 |
| `headless_audio_check` | buses, 256-slot pool, music pairs | 40 |
| `headless_anim_check` | tick-driven playback, per-cell keying | 18 |
| `headless_facing_draw_check` | draw-side mirroring of a turning fish | 16 |
| `headless_pet_check` | roster, steering, slot-81 bodies, Angie re-lay | 121 |
| `headless_alien_check` | alien kinds, wave clock, HP-bar geometry | 68 |
| `headless_boss_check` | Cyrax fight | 46 |
| `headless_bonus_check` | bonus round state machine | 59 |
| `headless_bonus_flow_check` | `Main`'s between-level hand-off | 64 |
| `headless_profile_check` | screens, stock roller, per-mode saves, profile JSON | 81 |
| `headless_golden_check` | golden tank saves vs EV-0144 | 22 |
| `headless_save_check` | tank-save framing | 38 |
| `headless_save_files_check` | save file layer | 21 |
| `headless_tank_snapshot_check` | capture/restore + level save/load | 71 |
| **`headless_integration_check.tscn`** | menu → level → wave → boss → 5-1 completion, real dialogs | **139** |

Run one suite:

```powershell
$godot = "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe"
& $godot --headless --path . --script res://tests/headless_level_check.gd
```

Run everything:

```powershell
$godot = "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe"
Get-ChildItem tests -Filter headless_*_check.gd |
  Where-Object Name -ne 'headless_integration_check_scene.gd' |
  ForEach-Object {
    & $godot --headless --path . --script ("res://tests/" + $_.Name) | Select-String 'PASS|FAIL'
  }
& $godot --headless --path . res://tests/headless_integration_check.tscn --quit-after 1200
```

---

## Repository layout

```
project.godot            Godot 4.7 project: 640×480, Forward+, five autoloads, D3D12 on Windows
scenes/main.tscn         Boot scene (screens layer + debug layer)
scripts/
  autoload/              Sim (tick driver), Content (resource registry), Audio, Game, Screens
  data/                  ImageRes, AnimState, MaskAlpha (asset metadata + drawing helpers)
  entities/              SimEntity, Fish, Food, Coin, Pet, Alien, Boss, Projectile, Larva, DeadFish
  tank/                  Tank, Level (the playable tank), WaveClock, BonusRound, SpriteKey
  economy/ progression/  Store tables/prices, per-tank progression + awards
  persistence/           Profile JSON, tank-save framing, scalars, snapshot glue, save files
  ui/                    Selector, store bar/screen, egg widget, all dialogs/screens, fonts
resources/               129 committed SpriteFrames (.tres) + content.json (326 ids)
tests/                   27 headless checks (26 script suites + the integration scene)
tools/                   Asset extraction (PowerShell), REA wrapper, Godot generators/probes
docs/                    PLAN, REVIEW, EVIDENCE, DECISIONS, SPECS, PIPELINE, ARCHITECTURE, notes
assets_raw/              Gitignored: regenerated game art/audio/fonts (personal use only)
docs/analysis/snapshots/ Gitignored: REA snapshot cache + carved game module
docs/captures/           Gitignored: windowed verification screenshots
docs/evidence/           Committed raw REA JSON cited by EV entries
```

## Architecture in brief

- **One clock.** `Sim` is the only simulation driver: `TICK_MS = 1000/36` (the ~36 Hz reading of
  Q-0034), at most 10 slices per rendered frame, a 1000 ms backlog clamp and the original 0.85
  multiplier. Gameplay never uses `_physics_process` or `delta`; each frame `Sim.advance()` runs the
  registered phases in the recovered order: `CLOCK → FISH → PETS → ALIENS → PROJECTILES →
  COLLISION → FOOD → PARTICLES`.
- **Entities are tick consumers.** `SimEntity` registers one entity in one phase; `_advance()` is the
  only per-tick hook and `despawn()` unregisters before freeing, so an entity may despawn itself
  mid-tick. `Tank` owns spawning, layer order and the seeded RNG stream.
- **Content is a typed registry.** `Content` resolves every id once from the committed manifest
  (`IMAGE_*` → `ImageRes` with grid/animation metadata, `SOUND_*` → stream + volume/alias,
  `FONT_*` → font + native size) and enforces the shipped load order.
- **Screens own the shell.** `Screens` keeps the screen stack and a single modal slot; `Main` mounts
  the selector, then the level, and routes the between-level cards. Dialogs draw from
  `DialogSkin`'s measured 9-sliced art and the game's own bitmap fonts.
- **Presentation is data-driven.** Sprite rows and cadence come from the resource metadata and the
  entity state, not from a global fps; colour keys and alpha companions are applied at draw time.

Design detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Behaviour contract:
[`docs/SPECS.md`](docs/SPECS.md). Asset contract: [`docs/PIPELINE.md`](docs/PIPELINE.md).

---

## Documentation map

| File | Purpose |
| --- | --- |
| [`AGENTS.md`](AGENTS.md) | Session protocol and hard rules (read first when continuing the project) |
| [`docs/PLAN.md`](docs/PLAN.md) | Master task list, statuses, dates, `EV-` refs. **Source of truth for progress** |
| [`docs/REVIEW.md`](docs/REVIEW.md) | Confirmed playtest defects R1-R68 and their fix status. **Source of truth for what is wrong** |
| [`docs/EVIDENCE.md`](docs/EVIDENCE.md) | Append-only ledger of verified claims (`EV-0001`…`EV-0251`) |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Settled decisions (`D-`) and open questions (`Q-`) |
| [`docs/SPECS.md`](docs/SPECS.md) | Cross-system behaviour contract (tick model, entities, economy, modes, UI, saves, audio) |
| [`docs/PIPELINE.md`](docs/PIPELINE.md) | Asset extraction pipeline and Godot usage contract |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Phase 4 design: autoloads, tick contract, ownership, coupling rules |
| [`docs/TARGET.md`](docs/TARGET.md) | Target identity: paths, SHA-256s, environment, tool locations |
| [`docs/P5-VALIDATION.md`](docs/P5-VALIDATION.md) | Constant cross-check, playtest checklist, timing/perf/packaging (withdrawn) |
| [`docs/AUDIT.md`](docs/AUDIT.md) | 2026-11-05 progress/capability audit and export-risk findings |
| [`docs/polish.md`](docs/polish.md) | Owner's 2026-11-22 polish feedback (triaged into R52-R66) |
| [`docs/analysis/notes/`](docs/analysis/notes/) | Per-subsystem dossiers (`p2.1`…`p2.15`, `p3-assets`, `wiki-refs`) |

## Evidence and method

- The original install stays **read-only** (D-0004). Gameplay code lives in the **embedded game
  module**, not the outer Steam wrapper exe (D-0009); gameplay claims cite game-module VAs.
- Tooling: **REA 6.5.0** with the **Ghidra 12.1.4** provider, driven through `tools/rea.ps1` with a
  shared snapshot so identical queries are cached. Raw JSON is committed under `docs/evidence/`
  when it supports an `EV-` entry.
- Static analysis never proves runtime behaviour: windowed captures, fixture parses and the owner's
  playtest carry the runtime claims. Unknowns are recorded as bounded negatives or `Q-` items
  instead of guesses.
- The **game wiki** is a secondary source for display names, terminology and mechanics context
  (D-0010); every internal ↔ display binding lives in `docs/analysis/notes/wiki-refs.md`, and
  wiki-vs-binary conflicts stay open, never silently resolved.

## Assets and legal

- This repository contains **no Insaniquarium game assets** (no art, audio, music or fonts). They
  are extracted locally into the gitignored `assets_raw/` by the P3 tools and are for **personal
  use only** (Q-0006). Do not publish them, and do not commit a regenerated `assets_raw/` — keep
  extracted assets out of forks and release builds.
- `docs/evidence/` contains Ghidra decompilation output derived from the shipped executable; it is
  analysis provenance for this project, not redistributable game content.
- You need your own copy of the game to build a runnable checkout. Without it the project imports
  but every sprite/texture lookup returns null.

## Working rules (handoff)

1. Read `AGENTS.md`, then `docs/PLAN.md`; check `docs/REVIEW.md` for the live work list.
2. Every new claim gets an `EV-` entry; superseded entries are corrected with a new ID, never edited.
3. Update `PLAN.md` (`Last updated` + `Next:`), `EVIDENCE.md`, `DECISIONS.md` and the system note as
   you go; tick tasks only when the evidence and the checks back them.
4. A row in `REVIEW.md` becomes `FIXED` only after it is verified against the original, covered by a
   headless check where possible, and re-shot windowed for anything visual.
5. Commit at session end so handoffs stay diffable.
