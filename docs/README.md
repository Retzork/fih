# Insaniquarium Deluxe -> Godot 4.7 remake - documentation index

**Handover status: Phase 2 in progress (2026-10-21).** Phase 0, Phase 1 and Phase 3 are
complete; Phase 2 is 4/18 done. P2.1-P2.4 are closed, P2.5 and P2.6 are substantially complete
with tracked open questions, and **P2.7 (pets) is the next planned system**. Phase 4 (Godot
gameplay implementation) has not started: the repository currently contains the Godot project
shell plus the imported sprite resources. `PLAN.md` is the source of truth for progress.

## Start here

1. **New agent session:** read `../AGENTS.md` first, then `PLAN.md` (mandatory). Follow the
   session-end checklist in `AGENTS.md`.
2. **Want the current state quickly?** Read the `P2.6` entry in `PLAN.md`, then
   `analysis/notes/p2.6-progression.md` (second pass, EV-0061..EV-0076).
3. **Need to run analysis?** Read the REA section below and the matching section of
   `../AGENTS.md`; the game install is read-only.
4. **Need asset details?** Read `PIPELINE.md` before touching assets or starting P4.

## Current state (handover snapshot)

| Area | State |
| --- | --- |
| P0 environment / tooling | Complete (13/13) |
| P1 target identity | Complete (10/10) |
| P2 reverse engineering | In progress (4/18): P2.1-P2.4 `[x]`; P2.5 `[~]`; P2.6 `[~]`; P2.7+ pending |
| P3 assets | Complete (8/8): 129 `SpriteFrames`, audio/music/fonts regenerate into `assets_raw/` |
| P4 Godot implementation | Not started (0/14) |
| P5 validation / polish | Not started (0/5) |

- **P2.6 second pass (2026-10-20)** closed the progression lifecycle: tank/level advance writer
  (Q-0012 answered), egg-completion branches and pet grants, level-6 sentinel/finalizer, bonus
  rounds/payout, tank-5 victory gate, corrected store tables and session init. Evidence is
  EV-0061..EV-0076; the note ends with an "Implementation spec for P4" section (D-0008).
- **P2.6 still open:** Q-0013 trophy/story gate, Q-0014 mode 2, Q-0015 `+0x58`/`+0x50`
  semantics, Q-0016 credits trigger, Q-0017 tank 6, Q-0018 StoreScreen/store-item population,
  Q-0019 `scr%d.dat`. Do not guess these in the remake.
- **P2.5 leftovers:** mode-enum naming -> P2.11; coin-hit gameplay intent (Q-0010) -> runtime;
  VT beetle value. See `PLAN.md`.
- **Next planned task:** P2.7 pets (roster enumerated; then per-pet behavior notes).
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
| `EVIDENCE.md` | Append-only ledger: each verified claim + how it was verified + confidence. Newest IDs are at the bottom (currently EV-0076). |
| `TARGET.md` | Immutable facts: game paths, SHA-256s, versions, environment, REA setup. |
| `PIPELINE.md` | Asset pipeline + Godot usage contract (P3 output; read before P4/asset work). |
| `DECISIONS.md` | Settled decisions (D-####) and open questions (Q-####), including the current P2.6 opens. |
| `analysis/notes/` | Per-subsystem dossiers (`p2.1-frameloop.md` ... `p2.6-progression.md`, `wiki-refs.md`); each P2 note ends with an "Implementation spec for P4". |
| `analysis/` | Inventories (`resources.json`, `extraction.json`, ...), snapshots (gitignored), evidence maps. |
| `evidence/` | Raw REA evidence JSON exports cited by EV IDs. |

## Handover checklist

- [ ] Read `../AGENTS.md` and `PLAN.md`; check `git status` is clean.
- [ ] Read the latest EVIDENCE entries and the current system note (`p2.6-progression.md` now).
- [ ] Pick the next task from `PLAN.md` (`P2.7` pets next); check its open questions first.
- [ ] Keep the target read-only; every claim gets an `EV-` entry; correct old EVs with new ones.
- [ ] End the session with: updated `PLAN.md` (statuses, `Last updated`, `Next:`), appended
  `EVIDENCE.md`, `DECISIONS.md` questions, note's P4 spec, saved raw output, and a commit.
