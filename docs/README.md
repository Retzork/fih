# Insaniquarium Deluxe -> Godot remake - documentation index

Reverse-engineering and reconstruction project for **Insaniquarium Deluxe v1.1** (Steam build),
rebuilt in **Godot 4.7** (this project).

## Document map

| File | Purpose |
| --- | --- |
| `../AGENTS.md` (project root) | Handoff protocol for new agent sessions. **Read first when starting a session.** |
| `PLAN.md` | Master checklist: every task, its status, date, evidence refs. **The source of truth for progress.** |
| `EVIDENCE.md` | Append-only ledger: each verified claim + how it was verified + confidence. |
| `TARGET.md` | Immutable facts: game paths, SHA-256s, versions, environment, REA commands. |
| `DECISIONS.md` | Settled decisions (D-####) and open questions (Q-####). |
| `analysis/` | Investigation artifacts: snapshots, per-subsystem notes, exported evidence bundles. |
| `evidence/` | Raw REA evidence exports / captured JSON, referenced from EVIDENCE.md. |

## Status legend (used in PLAN.md)

- `[ ]` pending - `[~]` in progress / partially done - `[x]` done (has evidence) - `[!]` blocked
- Progress counts are maintained in the PLAN.md summary table.

## Workflow loop (per task)

0. New session? Read `AGENTS.md` (project root) first.
1. Pick the next pending task from `PLAN.md` (top-down within the current phase).
2. Investigate with REA / file inspection. Keep raw outputs under `analysis/` or `evidence/`.
3. Append new findings to `EVIDENCE.md` (new EV-#### IDs: `EV-0001`, `EV-0002`, ...).
4. Tick the task in `PLAN.md`, writing date + EV refs on the line.
5. Update the summary table counts and the "Last updated" header.
6. Record any new decision/question in `DECISIONS.md`.

## Tools

Native analysis runs through REA + Ghidra. Use the wrapper (sets `GHIDRA_INSTALL_DIR`, `JAVA_HOME`,
`REA_ANALYSIS_PROVIDER`):

```powershell
# from the project root
& .\tools\rea.ps1 analyze "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe" --provider ghidra --json --snapshot docs\analysis\snapshots\insaniquarium.json
& .\tools\rea.ps1 search "<exe>" "some string" --provider ghidra --json --snapshot docs\analysis\snapshots\insaniquarium.json
& .\tools\rea.ps1 function "<exe>" 0x406400 --provider ghidra --json --snapshot docs\analysis\snapshots\insaniquarium.json
& .\tools\rea.ps1 decompile "<exe>" 0x406400 --provider ghidra --json --snapshot docs\analysis\snapshots\insaniquarium.json
```

- Always analyze the **Steam exe**; never modify anything in the game folder.
- Engine-free shortcut: `powershell -File tools\pe-imports.ps1 <exe>` prints PE32 facts, sections,
  imports, exports and delay-load imports without Ghidra (used for EV-0011, EV-0014).
- The shared snapshot (`analysis/snapshots/insaniquarium.json`) caches results across agent
  sessions. Repeated identical queries hit the cache; new queries still need Ghidra (cold import
  can take minutes - set generous timeouts, >= 600s).
- REA docs live in `C:\Users\Fauzi\Documents\project\rea\docs\` (cli.md, native-investigation.md,
  ghidra-provider.md, windows-ghidra-p0.md). The agent skill is at
  `C:\Users\Fauzi\Documents\project\rea\.agents\skills\reverse-engineer-anything\SKILL.md`.

## Environment snapshots

See `TARGET.md` for exact versions and hashes. Everything was verified working on 2026-10-15.
