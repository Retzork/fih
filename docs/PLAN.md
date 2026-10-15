# Master plan - Insaniquarium Deluxe (v1.1 Steam) -> Godot 4.7 remake

Last updated: 2026-10-15 (docs verified; AGENTS.md created; Godot boot check done; target mirror check done).
Next: P1.4 - first Ghidra import + binary overview of Insaniquarium.exe (cold import, allow >= 600 s).

Status legend: `[ ]` pending - `[~]` in progress - `[x]` done (with evidence) - `[!]` blocked

## Progress summary

| Phase | Scope | Done | Total | Status |
| --- | --- | --- | --- | --- |
| P0 | Environment & tooling | 11 | 13 | `[~]` |
| P1 | Reconnaissance & target identity | 4 | 9 | `[~]` |
| P2 | Reverse engineer game systems | 0 | 16 | `[ ]` |
| P3 | Asset extraction & pipeline | 0 | 8 | `[ ]` |
| P4 | Godot implementation | 0 | 14 | `[ ]` |
| P5 | Validation & polish | 0 | 5 | `[ ]` |

---

## P0 - Environment & tooling

- [x] **P0.1** Clone `morluto/rea`, study `reverse-engineer-anything` skill. (2026-10-15)
- [x] **P0.2** Verify Node.js >= 24.11. Node 24.16.0, npm 12.2.0. (2026-10-15)
- [x] **P0.3** Install 64-bit JDK 21. Temurin 21.0.12.1+1 via winget. (2026-10-15)
- [x] **P0.4** Install Ghidra 12.1.x. Ghidra 12.1.4, zip SHA-256 verified, extracted to `C:\tools`. (2026-10-15)
- [x] **P0.5** Install `rea-agents` CLI globally. v6.5.0. (2026-10-15)
- [x] **P0.6** Set `GHIDRA_INSTALL_DIR` / `JAVA_HOME` / `REA_ANALYSIS_PROVIDER` (User scope). (2026-10-15)
- [x] **P0.7** `rea doctor` shows Ghidra `available: true` (all 9 checks). (2026-10-15)
- [x] **P0.8** Create `tools\rea.ps1` wrapper (inline env for pre-change shells). (2026-10-15)
- [x] **P0.9** Create docs scaffold (README, PLAN, EVIDENCE, TARGET, DECISIONS). (2026-10-15;
  AGENTS.md was missing on disk until P0.12)
- [ ] **P0.10** (Optional, needs user approval - Q-0007) register REA MCP + skill into opencode:
  `npx rea-agents setup --client opencode` after a `--dry-run` review.
- [x] **P0.11** Locate local Godot editor + boot this project (Q-0001). Godot 4.7.1 stable at
  `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe`; `--headless --import` exits 0. (2026-10-15)
- [x] **P0.12** Create `AGENTS.md` handoff protocol at project root (referenced by D-0003; absent until now). (2026-10-15)
- [ ] **P0.13** (Optional, needs user approval - Q-0008) `git init` the remake project for diffable agent handoffs.

## P1 - Reconnaissance & target identity

- [x] **P1.1** Hash executables, screensaver, bass.dll; record sizes. -> EV-0001, TARGET.md (2026-10-15)
- [x] **P1.2** Read `crash.txt` + `readme.html` for version/product facts. -> EV-0002, EV-0003 (2026-10-15)
- [x] **P1.3** Full file inventory of the install root (recursive listing). -> EV-0004, EV-0005, EV-0006 (2026-10-15)
- [ ] **P1.4** REA overview of `Insaniquarium.exe` (PE arch, sections, imports, strings, procedure
  count) with shared snapshot. Confirm x86 vs x86-64 admission; confirm `bass.dll` imports (EV-0006).
- [ ] **P1.5** Identify engine/build provenance from strings/symbols (PopCap SexyAppFramework
  version markers, compiler, library versions).
- [ ] **P1.6** Identify Steam/DRM wrapper boundary inside the exe (search steam_api, drmss, wrapper
  strings) - separates wrapper code from game code for later phases.
- [ ] **P1.7** Enumerate subsystem seed strings (fish/pet/alien names, menu labels, cheat strings,
  file/save names) and save the search results under `analysis/`.
- [ ] **P1.8** Write Phase 1 dossier (`analysis/notes/p1-recon.md`) summarizing entry points,
  naming conventions, address ranges of interest; cross-link EV IDs.
- [x] **P1.9** Hash-verify secondary local copy vs canonical: exe + bass.dll byte-identical. -> EV-0007 (2026-10-15)

## P2 - Reverse engineer game systems (one investigation pass each; write notes per system)

For each: find entry points -> focused function dossiers -> record constants via byte reads ->
notes file + EV entries. Candidate systems (adjust as evidence dictates; P1.7 + resources.xml
will confirm the actual rosters):

- [ ] **P2.1** Frame loop & timestep (SexyAppFramework update cadence, dt handling, FPS target)
- [ ] **P2.2** Tank simulation: fish swim/turn motion, tank bounds, direction/facing logic
- [ ] **P2.3** Feeding: food drop physics, hunger/satiety timers, eating states, coin spawn rules
- [ ] **P2.4** Fish growth & death: guppy -> carnivore -> ultravore stages, starvation, drops
- [ ] **P2.5** Economy: coin values/denominations, pickup logic, money display, store prices
- [ ] **P2.6** Progression: 5 tanks x 5 levels, egg drops, hatching, pet unlock/trophy flow
- [ ] **P2.7** Pets: enumerate roster from binary, then per-pet behavior notes (batch: 3-5 pets
  per pass; each pet gets its own EV entries)
- [ ] **P2.8** Aliens: per-tank alien types, spawn waves, attack patterns, hitpoints
- [ ] **P2.9** Bosses: final-level boss per tank, phases, damage/weak points
- [ ] **P2.10** Weapons & projectiles: laser upgrades, missiles/perks, collision and damage math
- [ ] **P2.11** Game modes: Adventure, Challenge, Time Trial, Virtual Tank (screensaver ecosystem)
- [ ] **P2.12** Menus & UI flow: title/profile/options/help/store screens, dialog structure
- [ ] **P2.13** Save/profile format: writer/reader functions, file location, versioning, Steam paths
- [ ] **P2.14** Audio system: BASS usage, mo3 music playback, channel/mixing behavior
- [ ] **P2.15** Resource system: `properties\resources.xml` semantics (image/animation/sound tables)
- [ ] **P2.16** Screensaver variants (`Insaniquarium.scr`, `WinFish_Scr.exe`): feature deltas
- [ ] **P2.17** Cheat codes / debug hooks (string search; document only)

## P3 - Asset extraction & pipeline

- [ ] **P3.1** Parse `resources.xml` into a machine-readable inventory (script under `tools\`)
- [ ] **P3.2** Determine sprite frame geometry (sheet cell layout, offsets) from resource data
- [ ] **P3.3** Extract per-animation frame sets into `assets_raw/` (input for Godot conversion)
- [ ] **P3.4** Investigate `guppy_swim1.gif.frames.png` (Q-0003) and record the outcome
- [ ] **P3.5** Build Godot import step: PNGs -> texture atlases + `SpriteFrames` per animation
- [ ] **P3.6** Audio: collect `.ogg`; convert `.au` -> `.wav`; document conversion commands
- [ ] **P3.7** Music: `.mo3` decode/transcode decision + pipeline (tooling choice in DECISIONS.md)
- [ ] **P3.8** Fonts/UI/cursor assets inventory + conversion

## P4 - Godot implementation

- [ ] **P4.1** Architecture doc: scenes, autoloads, signals, tick model mirroring P2.1
- [ ] **P4.2** Resource loader mirroring resources.xml semantics (P2.15)
- [ ] **P4.3** Core entities: Fish, Pet, Alien, Coin, Projectile, Food (state machines from P2.2-P2.10)
- [ ] **P4.4** Tank simulation + feeding loop (from P2.2/P2.3)
- [ ] **P4.5** Economy & store UI (P2.5)
- [ ] **P4.6** Egg/level/tank progression + trophy room (P2.6)
- [ ] **P4.7** Pets implementation (per-pet tasks after P2.7 enumeration)
- [ ] **P4.8** Aliens + waves (P2.8)
- [ ] **P4.9** Bosses (P2.9)
- [ ] **P4.10** Weapons/projectiles (P2.10)
- [ ] **P4.11** Modes: Adventure, Challenge, Time Trial, Virtual Tank (P2.11)
- [ ] **P4.12** Save system (P2.13) - own format unless compatibility is decided
- [ ] **P4.13** Audio integration (P2.14 + P3.6/3.7)
- [ ] **P4.14** Menus/UI shell, options, help (P2.12)

## P5 - Validation & polish

- [ ] **P5.1** Constant cross-check sheet: every recovered value (speeds, prices, HP, timers)
  listed against its EV entry (differential table)
- [ ] **P5.2** Side-by-side playtest checklist per tank/level vs original (screenshots + notes)
- [ ] **P5.3** Timing/feel comparison (P2.1 tick model vs Godot implementation)
- [ ] **P5.4** Performance sanity (target: trivial for a 2D game; check draw calls on tank scenes)
- [ ] **P5.5** Packaging decision + README for running the remake

## Backlog / ideas (not committed)

- Widescreen/HD layout (see Q-0005), mod support, achievements, localization.
