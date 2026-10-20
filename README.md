# Insaniquarium Deluxe -> Godot 4.7 remake

Remake of **Insaniquarium Deluxe v1.1 (Steam)** in **Godot 4.7.1**, built from binary analysis
of the original (no source code). The game install is read-only; all behavioral claims live in
`docs/EVIDENCE.md` as `EV-NNNN` entries.

## Handover

**Start with [`AGENTS.md`](AGENTS.md)** (session protocol + hard rules), then
**[`docs/PLAN.md`](docs/PLAN.md)** (source of truth for progress). The detailed documentation
index, repository map, analysis commands and handover checklist are in
**[`docs/README.md`](docs/README.md)**.

**Current status (2026-10-21):** Phase 2 in progress, 4/18 systems closed. P2.1-P2.4 are done;
P2.5 and P2.6 are substantially complete with tracked open questions; **P2.7 (pets) is next**.
Phase 3 (assets) is complete. Phase 4 (Godot gameplay) has not started — the repository contains
the project shell, committed `SpriteFrames`, tools and documentation, but no gameplay scenes yet.

**P2.6 handover note:** [`docs/analysis/notes/p2.6-progression.md`](docs/analysis/notes/p2.6-progression.md)
(second pass, EV-0061..EV-0076; ends with an "Implementation spec for P4"). Open P2.6 questions:
Q-0013..Q-0019 in [`docs/DECISIONS.md`](docs/DECISIONS.md).

## Quick start

```powershell
git status
git log -1 --oneline

# verify the Godot project imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import
```

There is no playable scene yet. For analysis, carve the embedded game module once with
`tools\extract-game-module.ps1` and follow the REA section in `AGENTS.md` / `docs/README.md`;
always cite game-module VAs (D-0009). Extracted assets are personal use only (Q-0006) and
`assets_raw/` is gitignored/regenerable.

## Ground rules

- Never modify anything inside the game install (D-0004).
- Every claim needs an `EV-` entry; correct superseded entries with a new ID, never edit old ones.
- Update `PLAN.md`, `EVIDENCE.md`, `DECISIONS.md` and the current system note as you go; commit
  at session end for diffable handoffs.
- The wiki is a secondary source for names/mechanics context only (D-0010); the binary is proof.
