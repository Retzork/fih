# Master plan - Insaniquarium Deluxe (v1.1 Steam) -> Godot 4.7 remake

Last updated: 2026-10-15 (PHASE 3 COMPLETE: P3.1-P3.8 done; EV ledger through EV-0033).
Next: P2.1 frame-loop & timestep entry-point recon (then P2 top-down; Phase 2 closes with P2.18
`docs\SPECS.md` per D-0008; asset-side contract for P4 is `docs\PIPELINE.md`).

Status legend: `[ ]` pending - `[~]` in progress - `[x]` done (with evidence) - `[!]` blocked

## Progress summary

| Phase | Scope | Done | Total | Status |
| --- | --- | --- | --- | --- |
| P0 | Environment & tooling | 13 | 13 | `[x]` |
| P1 | Reconnaissance & target identity | 10 | 10 | `[x]` |
| P2 | Reverse engineer game systems | 0 | 18 | `[ ]` |
| P3 | Asset extraction & pipeline | 8 | 8 | `[x]` |
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
- [x] **P0.10** Registered REA MCP + skill into opencode (dry-run reviewed; config backup kept);
  effective after next client restart. (2026-10-15)
- [x] **P0.11** Locate local Godot editor + boot this project (Q-0001). Godot 4.7.1 stable at
  `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe`; `--headless --import` exits 0. (2026-10-15)
- [x] **P0.12** Create `AGENTS.md` handoff protocol at project root (referenced by D-0003; absent until now). (2026-10-15)
- [x] **P0.13** `git init` + initial commit `68f1d75` (14 files) for diffable agent handoffs. (2026-10-15)

## P1 - Reconnaissance & target identity

- [x] **P1.1** Hash executables, screensaver, bass.dll; record sizes. -> EV-0001, TARGET.md (2026-10-15)
- [x] **P1.2** Read `crash.txt` + `readme.html` for version/product facts. -> EV-0002, EV-0003 (2026-10-15)
- [x] **P1.3** Full file inventory of the install root (recursive listing). -> EV-0004, EV-0005, EV-0006 (2026-10-15)
- [x] **P1.4** REA overview + import audit of `Insaniquarium.exe`: PE32 x86 admitted; 6 segments;
  7,061 procedures; 2,496 strings; static imports = 10 system DLLs (no bass/ddraw/dsound/steam_api).
  -> EV-0008, EV-0009, EV-0011 (2026-10-15)
- [x] **P1.5** Engine/build provenance identified: PopCap SexyAppFramework (MSVC RTTI class map),
  embedded Lua 5.0.2, build project `DRMProtectRun2`. -> EV-0009, EV-0013, EV-0016 (2026-10-15)
- [x] **P1.6** Steam/DRM boundary: legacy `Steam.dll` API (EV-0015), `drmss.jpg` (EV-0017),
  on-disk `drm\` Lua wrapper layer (EV-0020, EV-0023); in-exe caller mapping deferred to
  P2.13/P2.14 per user. (2026-10-15)
- [x] **P1.7** Subsystem seeds: rosters from `resources.xml` (EV-0022), asset inventory (EV-0018),
  data-driven confirmed via bounded negatives (EV-0019). -> EV-0012, EV-0018, EV-0019 (2026-10-15)
- [x] **P1.8** Phase 1 dossier written: `docs/analysis/notes/p1-recon.md` (entry points, naming
  conventions, address clusters, data map; EV cross-links). (2026-10-15)
- [x] **P1.9** Hash-verify secondary local copy vs canonical: exe + bass.dll byte-identical. -> EV-0007 (2026-10-15)
- [x] **P1.10** Full-tree hash comparison + fragment audit (leftovers identified; Q-0003 answered). -> EV-0010 (2026-10-15)

## P2 - Reverse engineer game systems (one investigation pass each; write notes per system)

For each: find entry points -> focused function dossiers -> record constants via byte reads ->
notes file + EV entries. Every system note MUST end with an "Implementation spec for P4" section
(constants+addresses, formulas, timings, state machines - see D-0008). Candidate systems (adjust
as evidence dictates; P1.7 + resources.xml will confirm the actual rosters):

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
- [ ] **P2.18** Write `docs\SPECS.md`: cross-system implementation contract for P4 (per-system
  specs come from the P2.1-P2.17 notes; format modeled on `docs\PIPELINE.md`). (D-0008)

## P3 - Asset extraction & pipeline

- [x] **P3.1** Parse `resources.xml` into a machine-readable inventory (`tools\parse-resources.ps1`;
  326 resources: 246 images/15 fonts/65 sounds; counts corrected vs EV-0022). -> EV-0024, EV-0025 (2026-10-15)
- [x] **P3.2** Determine sprite frame geometry (all declared grids divide exactly; 80x80-cell
  convention; 30 undeclared multi-cell sheets; mask/alpha model). -> EV-0026, EV-0027 (2026-10-15)
- [x] **P3.3** Extract per-animation frame sets into `assets_raw/` (`tools\extract-assets.ps1`;
  244 base + 179 mask PNGs + 3,036 frames, pixel-exact; layers uncompressed). -> EV-0028 (2026-10-15)
- [x] **P3.4** Investigate `guppy_swim1.gif.frames.png` (Q-0003): both leftovers are pixel-exact
  GIF->PNG conversions, no slicing; ignored by pipeline. -> EV-0029 (2026-10-15)
- [x] **P3.5** Godot import step: `tools\godot\gen_spriteframes.gd` -> 129 SpriteFrames
  (AtlasTexture regions; 129/129 verified; exit 0). -> EV-0030 (2026-10-15)
- [x] **P3.6** Audio: 50 `.ogg` copied 1:1 + 15 `.au` -> `.wav` (`pcm_mulaw` 8k mono ->
  `pcm_s16le`), 0 probe failures, 752 KB; command per file in `audio.json`. -> EV-0031 (2026-10-15)
- [x] **P3.7** Music: 3 `.mo3` -> OGG via ffmpeg/libopenmpt (`libvorbis -q:a 5`), 3/3 verified,
  2.7 MB; tooling decision D-0006. -> EV-0032 (2026-10-15)
- [x] **P3.8** Fonts/UI/cursor: 15 SexyApp bitmap fonts parsed + converted (BMFont `.fnt` + composed
  page PNGs, 1,788 glyphs, 813 kerns; atlas/extents validated), Godot verify 15/15 exit 0; cursors
  already extracted as images in P3.3 (no conversion). -> EV-0033, D-0007 (2026-10-15)

## P4 - Godot implementation

Read `docs\PIPELINE.md` (asset contract) and the P2 implementation specs (`docs\SPECS.md` once
P2.18 lands) before starting; P4 tasks below assume both exist.

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
