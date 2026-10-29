# Insaniquarium Deluxe -> Godot 4.7 remake - documentation index

**Handover status: Phase 2 in progress (2026-10-29).** Phase 0, Phase 1 and Phase 3 are
complete; Phase 2 is 9/18 done with **P2.12 (menus & UI flow) in progress**. P2.1-P2.4, P2.7-P2.11
are closed, P2.5 and P2.6 are substantially complete with tracked open questions, and P2.12 has
its first pass plus the store pass done (screen map, mode writer, store screen and stock refresh,
level-start flow). Phase 4 (Godot
gameplay implementation) has not started: the repository currently contains the Godot project shell
plus the imported sprite resources. `PLAN.md` is the source of truth for progress.

## Start here

1. **New agent session:** read `../AGENTS.md` first, then `PLAN.md` (mandatory). Follow the
   session-end checklist in `AGENTS.md`.
2. **Want the current state quickly?** Read the `P2.12` entry in `PLAN.md`, then
   `analysis/notes/p2.12-menus.md` (screen/vtable map, the mode writer, store screen and stock
   refresh, level-start flow, EV-0131..EV-0135), then `analysis/notes/p2.11-modes.md` for the mode
   behavior itself.
3. **Need to run analysis?** Read the REA section below and the matching section of
   `../AGENTS.md`; the game install is read-only.
4. **Need asset details?** Read `PIPELINE.md` before touching assets or starting P4.

## Current state (handover snapshot)

| Area | State |
| --- | --- |
| P0 environment / tooling | Complete (13/13) |
| P1 target identity | Complete (10/10) |
| P2 reverse engineering | In progress (9/18): P2.1-P2.4 `[x]`; P2.5 `[~]`; P2.6 `[~]`; P2.7-P2.11 `[x]`; P2.12 `[~]`; P2.13 `[~]`; P2.14+ pending |
| P3 assets | Complete (8/8): 129 `SpriteFrames`, audio/music/fonts regenerate into `assets_raw/` |
| P4 Godot implementation | Not started (0/14) |
| P5 validation / polish | Not started (0/5) |

- **P2.12 menus & UI flow (2026-10-29, first pass):** every screen class is a widget container plus
  an embedded `Sexy::ButtonListener` at `+0x88` (manager at `+0x8C`, callbacks get `object+0x88`),
  and `xrefs` on a class vtable returns exactly its destructor and constructor - which is how
  `TitleScreen` (0x52EB50), `GameSelector` (0x52E070), `StoreScreen` (0x52B2D0) and `TankScreen`
  (0x52CB40) were located (EV-0131). The main menu has eight buttons; the **mode writer** is its
  click callback `FUN_0051F160`: id 1 -> 0 Adventure, 2 -> 5 Virtual Tank, 8 "Time Trial" -> 1,
  9 "Challenge" -> 4, with "Not Yet!" gates on `profile+0x1C`/`+0x59` and the demo flag
  `manager+0x880` cleared on every press (EV-0132, resolves Q-0024). `StoreScreen`'s field map, its
  eight item slots and the action dispatcher (Virtual Tank bypasses `BuyItem`, action 0xF is the egg
  purchase) are mapped, as is the dialog create/measure/push template (EV-0133). The level-start
  funnel `FUN_00552380` and the `TankScreen` builder `FUN_0054C130` close the loop (EV-0134).
  Evidence is EV-0131..EV-0135; the note (`analysis/notes/p2.12-menus.md`) ends with an
  "Implementation spec for P4" section (D-0008).
- **P2.12 store pass (2026-10-29, EV-0135):** the store item widget's five overrides are vtable
  slots **22/26/44/50/51** - slot 26 draws the item art by the kind at `+0x14C` (0 sold out, 1 pet,
  2 Bubbulator, 3 backdrop, 4 alien attractor, 5 food), slot 44 draws the price line from `+0x12C`
  and greys it to `0xCCCCCC` when the enabled byte `+0x55` is 0. The stock is rolled on attach by
  `FUN_0052FEA0` -> `FUN_0052F0D0` (one-off unlocks on `profile+0x90`/`+0x94`, pet slots on
  `profile+0x72+i`, Cookie handed out once through `FUN_0051C0B0`/`FUN_0052B800`); each slot then
  takes `FUN_005363D0` (`SetPrice`, `sprintf("%d")`) or `FUN_005372F0`, which writes the literal
  **`SOLD`**. The screen's slots (attach/detach/refresh/update/draw/mousemove) and its tooltip
  (`FUN_0051B9E0` kind-to-text, 16 ticks of hover, "Thanks for shopping at the Fish Emporium!") are
  mapped too.
- **P2.12 still open (Q-0018, Q-0025):** the owner of the *normal* store-item object and whether the
  rolled pet is really the receiver of `FUN_00519730`, `manager+0x738` has no known
  owner, the 24-byte `profile+0x5A` clear contradicts the pet-selection reading (Q-0025) and
  `profile+0x18` is unbound. Do not guess these.
- **P2.11 game modes (2026-10-29)** mapped all four shipped modes off the single binding
  `mode = [manager+0x87C]`: 0 Adventure, 1 Time Trial, 3 Sandbox, 4 Challenge, 5 Virtual Tank
  (2 is referenced but never observed). `FUN_0054CBF0` is `start_level`, and the per-mode work
  happens inside the tank update `FUN_00547610`: Time Trial recomputes the clock at `Tank+0xEC`
  and ends the level when it goes negative, Challenge inflates every store price by its per-tank
  increment every 150/150/175/200 ticks (capped 99999) and swaps type 8 for 0xC on later waves,
  Sandbox re-rolls the priced stock every tick. Virtual Tank gets its own init block, its
  `sim%d.dat` slot at `profile+0x44` and a 76 %-ordinary weighted spawn table; Rapid Fire was
  found here too (period `11 - level/2` ticks, ≥100 ms apart, missiles -> larvae -> aliens).
  Evidence is EV-0126..EV-0130; the note (`analysis/notes/p2.11-modes.md`) ends with an
  "Implementation spec for P4" section (D-0008).
- **P2.11 still open (Q-0024):** the mode writer is answered by P2.12 (EV-0132); still open are the
  receiver class of `FUN_004D80C0`, the `Tank+0x4FE` writer, the `Tank+0x2DC/+0x2E0` pair and the VT
  session helpers. Modes 2 and 3 have no writer, so Q-0014 stays open. Do not guess these.
- **P2.10 weapons & projectiles (2026-10-29)** proved that a click *is* the shot: the tank handler
  `FUN_00543920` resolves one click through six stages (bonus round, the boss-only `Tank+0xBC` list,
  the boss, `Tank+0xB8` aliens, `Tank+0xDC` larvae, `Tank+0xF4` missiles, feed) and there is no
  player weapon object, no weapon cooldown and no player projectile. The upgrade cap is **12**
  (correcting EV-0057) and the 11 -> 12 purchase unlocks "Rapid Fire". The projectile class pair
  `Sexy::Missle`/`Sexy::Larva` is mapped end to end (spawner, ctor field table, kinds 0/1/2, update
  bounds, shoot-down and deflect hit tests, the `Larva` fall/shell payout). Evidence is
  EV-0122..EV-0125; the note (`analysis/notes/p2.10-weapons.md`) ends with an
  "Implementation spec for P4" section (D-0008).
- **P2.10 still open (Q-0023):** no decompiled weapon function binds `IMAGE_LASERS`/
  `IMAGE_LASERUPGRADES` (draw side unbound), the `Tank+0xBC` list identity, the `Larva`'s gameplay
  role and the `FUN_004FF4E0` homing body. The Rapid Fire loop is answered (EV-0129); the
  random-velocity missile branch is unreachable (EV-0130, which withdraws the old "demo flag"
  reading of `FUN_004D80C0`). Do not guess the rest.
- **P2.9 bosses (2026-10-29)** settled the boss question: only kind 0x15 (Cyrax) is a boss, the
  tank-5 fight is two spawn clocks (75-tick Minisylvester at the boss, 300-tick random alien type
  4-9 while the field is clear), there is no projectile and no hp-threshold phase, and the shot hit
  handler `FUN_004FA6F0` gives the damage model (`3*Tank+0x3E4`, one hit per 10 ticks, knockback),
  i.e. 30 per hit at the boss-forced 10 and 6 at the base weapon level 2.
  It also recovered the HP-bar geometry, the boss-only defeat cleanup and the egg-piece gates.
  Evidence is EV-0117..EV-0121; the note (`analysis/notes/p2.9-bosses.md`) ends with an
  "Implementation spec for P4" section (D-0008).
- **P2.9 still open (Q-0021/Q-0022):** the egg purchase is not boss-gated at handler level (store
  UI unverified), `profile+0x54` naming/trigger, and the `from_shot` argument at the shot kill.
  Do not guess these.
- **P2.8 aliens (2026-10-29)** answered Q-0011 (every hostile alien except Bilaterus is one
  `Sexy::Alien` class discriminated by kind) and mapped the ctor tuning, the 3000-tick wave clock
  with its one-wave-at-a-time pause, the per-tank type re-roll, the Destructor/Ulysses/
  Psychosquid/Cyrax attacks, the eat chase, the bite's reach boxes and the death/drop path.
  Evidence is EV-0110..EV-0116; the note (`analysis/notes/p2.8-aliens.md`) ends with an
  "Implementation spec for P4" section (D-0008).
- **P2.8 still open (Q-0020):** kind 1 vs kind 2 identity, the attack gate's four sub-predicates,
  the bite's consume/get-eaten vtable slots, the Gus pellet hp cost, the `FUN_005442C0` death
  animation, tank flag writers. Do not guess these.
- **P2.7 pets (2026-10-21)** completed the pet system: 24-pet roster + 999 display card, both pet
  classes and vtables, spawn/session loading, constructor tuning, shared AI gates and 36 Hz timer
  reading, plus per-pet mechanics for all 24 pets. Evidence is EV-0077..EV-0107; the note
  (`analysis/notes/p2.7-pets.md`) ends with an "Implementation spec for P4" section (D-0008).
- **P2.7 still open:** Gumbo fish lure, Blip overlays, Seymour `Tank+0x16C` writer, Amp
  click/electrocute, Nostradamus sneeze/clones, Wadsworth challenge sleep, Brinkley 15/45/135 vs
  wiki 12/36/108, Stinky cooldown/red cosmetic, Niko perch, Walter click/5-punch counter, VT
  3-minute sleep. Do not guess these in the remake.
- **P2.6 second pass (2026-10-20)** closed the progression lifecycle: tank/level advance writer
  (Q-0012 answered), egg-completion branches and pet grants, level-6 sentinel/finalizer, bonus
  rounds/payout, tank-5 victory gate, corrected store tables and session init. Evidence is
  EV-0061..EV-0076; the note ends with an "Implementation spec for P4" section (D-0008).
- **P2.6 still open:** Q-0013 trophy/story gate, Q-0014 mode 2, Q-0015 `+0x58`/`+0x50`
  semantics, Q-0016 credits trigger, Q-0017 tank 6, Q-0018 StoreScreen/store-item population,
  Q-0019 `scr%d.dat` (real saves now available; `scr` itself still absent, EV-0108/EV-0109).
  Do not guess these in the remake.
- **P2.13 saves (2026-10-21, partial):** live folder
  `C:\ProgramData\Steam\Insaniquarium\userdata`; real early and GameBanana samples are copied
  under `analysis/inputs/`. `users.dat` and the full 232-byte `user%d.dat` field order are
  mapped through `FUN_00513850`, `FUN_005145A0`/`FUN_00514730`, and `FUN_00503730`
  (EV-0108/EV-0109). The GameBanana profile has `+0x7C = 0xFFFFFFFF` and `+0x80 = 1`, a strong
  candidate for a 32-story mask + gold trophy, but the reader is not located; Q-0013 stays
  open. `adv`/`sim` body semantics and `scr%d.dat` remain open. Note:
  `analysis/notes/p2.13-saves.md`.
- **P2.5 leftovers:** mode-enum naming is answered (EV-0126); coin-hit gameplay intent (Q-0010) ->
  runtime; VT beetle value. See `PLAN.md`.
- **Next planned task:** finish P2.12 - the store price/grey-out is done (EV-0135), so walk the
  remaining screen ctors with the vtable-xref
  recipe (`HelpScreen` 0x5A0A20/0x5A0A44, `HighScoreScreen` 0x5A0B60/0x5A0B84, `PetsScreen`,
  `HatchScreen`, `SimFishScreen`, `SimSetupScreen`, `StoryScreen`, `InterludeScreen`) and the three
  dialogs, then close Q-0018's two residuals. Q-0025's `profile+0x5A` clear is the one item that
  needs the session-init functions.
- **Phase 2 close-out:** P2.18 `SPECS.md`, the cross-system P4 contract (D-0008).

## What is in the repository

| Path | Content |
| --- | --- |
| `project.godot`, `icon.svg` | Godot 4.7.1 project shell (Forward Plus, `canvas_items` stretch, Jolt configured; 2D game). No gameplay scenes/scripts yet. |
| `resources/sprites/` | 129 committed `SpriteFrames` (`.tres`) generated from the extracted sheets. |
| `assets_raw/` | **Gitignored, regenerate with P3 tools:** images, masks, sliced frames, sounds, music, fonts. Personal use only (Q-0006). |
| `tools/` | PowerShell extraction/REA wrappers + `tools/godot/` verification/generation scripts. |
| `docs/` | Plan, evidence, decisions, target dossier, asset contract, subsystem notes, raw evidence. |
| `docs/analysis/snapshots/` | **Gitignored:** regenerable REA snapshots, including the carved game module. |
| `docs/evidence/` | Committed raw REA evidence JSON, cited from `EVIDENCE.md`. |

## Quick start

```powershell
# from the repository root
git status
git log -1 --oneline

# verify the Godot project still imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import

# optional: regenerate extracted assets (read-only install -> assets_raw/)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\parse-resources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1
```

There is no playable scene yet. P4.1 (architecture doc/scenes/autoloads/tick model) is the first
implementation task; read `PIPELINE.md` and the P2 notes' "Implementation spec for P4" sections
before starting it.

## Analysis toolchain

The game install is **READ-ONLY** (D-0004). Gameplay code lives in the embedded module, not the
outer exe (D-0009):

```powershell
# one-time carve (writes docs\analysis\snapshots\, gitignored)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-game-module.ps1

$exe  = "docs\analysis\snapshots\insaniquarium-game-module.exe"
$snap = "docs\analysis\snapshots\insaniquarium-game-module.json"

# CLI route (wrapper sets GHIDRA_INSTALL_DIR / JAVA_HOME / REA_ANALYSIS_PROVIDER)
& .\tools\rea.ps1 analyze   $exe --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 search    $exe "<pattern>" --kind strings --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 function  $exe 0x501370 --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 decompile $exe 0x501370 --provider ghidra --json --snapshot $snap
```

- Use REA MCP (`rea`) when the client exposes it; `tools/rea.ps1` is the documented fallback.
- Always pass `--snapshot`; identical queries are cached. New queries still run Ghidra (cold
  import can take minutes — use timeouts >= 600 s).
- **Cite game-module VAs** for gameplay claims (D-0009). Outer-exe addresses are only for the
  wrapper/DRM/main loop (P2.1).
- Save bulky results under `docs/evidence/` and cite the path + excerpts in `EVIDENCE.md`.
- Engine-free shortcuts: `tools\pe-imports.ps1` (PE imports), `tools\rtti-classmap.ps1` (module
  RTTI class -> vtable/slot map), `tools\fnmap.ps1` (function map; see backlog note about hangs).
- Wiki (`https://insaniquarium.fandom.com/wiki/`, `?action=raw`) is a secondary source for names
  and mechanics context only (D-0010); the binary remains the proof. Keep bindings in
  `analysis/notes/wiki-refs.md`.

## Document map

| File | Purpose |
| --- | --- |
| `../AGENTS.md` (project root) | Handoff protocol, hard rules, REA commands. **Read first when starting a session.** |
| `PLAN.md` | Master checklist: every task, status, date, evidence refs, `Next:` pointer. **Source of truth for progress.** |
| `EVIDENCE.md` | Append-only ledger: each verified claim + how it was verified + confidence. Newest IDs are at the bottom (currently EV-0135). |
| `TARGET.md` | Immutable facts: game paths, SHA-256s, versions, environment, REA setup. |
| `PIPELINE.md` | Asset pipeline + Godot usage contract (P3 output; read before P4/asset work). |
| `DECISIONS.md` | Settled decisions (D-####) and open questions (Q-####), including the current P2.6, P2.8, P2.9, P2.10, P2.11 and P2.12 opens. |
| `analysis/notes/` | Per-subsystem dossiers (`p2.1-frameloop.md` ... `p2.11-modes.md`, `p2.12-menus.md`, `p2.13-saves.md`, `wiki-refs.md`); each P2 note ends with an "Implementation spec for P4". |
| `analysis/` | Inventories (`resources.json`, `extraction.json`, ...), snapshots (gitignored), evidence maps. |
| `evidence/` | Raw REA evidence JSON exports cited by EV IDs. |

## Handover checklist

- [ ] Read `../AGENTS.md` and `PLAN.md`; check `git status` is clean.
- [ ] Read the latest EVIDENCE entries and the current system note (`p2.12-menus.md` now).
- [ ] Pick the next task from `PLAN.md` (finish `P2.12` menus & UI flow); check its open questions
  (Q-0018, Q-0025) first.
- [ ] Keep the target read-only; every claim gets an `EV-` entry; correct old EVs with new ones.
- [ ] End the session with: updated `PLAN.md` (statuses, `Last updated`, `Next:`), appended
  `EVIDENCE.md`, `DECISIONS.md` questions, note's P4 spec, saved raw output, and a commit.
