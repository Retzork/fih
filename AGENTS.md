# AGENTS.md - agent handoff protocol

**Read this file first.** It is the entry point for any agent session (any tool or model)
continuing this project. The docs under `docs/` are the single source of truth: if it is not
written there, it did not happen.

## What this is

Remake of **Insaniquarium Deluxe v1.1 (Steam)** in **Godot 4.7.1**. The original has no source
code; all behavioral claims come from binary analysis (REA + Ghidra, read-only) and file
inspection. Human owner: Fauzi.

## Reading order

**Mandatory every session:**

1. `AGENTS.md` (this file).
2. `docs/PLAN.md` - master task list with statuses and evidence refs. **Source of truth for progress.**

**Read on demand only, when the current task needs them:**

3. `docs/EVIDENCE.md` - append-only ledger of verified claims (`EV-NNNN`).
4. `docs/TARGET.md` - target identity (paths, SHA-256s), environment, tool paths.
5. `docs/DECISIONS.md` - settled decisions (`D-NNNN`) and open questions (`Q-NNNN`).
6. `docs/analysis/notes/` - per-subsystem investigation notes.
7. `docs/PIPELINE.md` - asset pipeline + Godot usage contract (read before any asset or P4 work).
8. `docs/analysis/notes/wiki-refs.md` - internal <-> wiki display-name index (D-0010).

(You still must UPDATE these when your work produces new evidence/decisions - see hard rules.)

## Hard rules

1. **Read-only target.** Never modify, patch, rename, or write inside the game install
   `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe`. REA imports its own private copies.
2. **Evidence first.** Every completed PLAN task records date + `EV-` refs on its line. Label
   observations / inferences / unknowns exactly as `docs/EVIDENCE.md` defines. Static analysis
   never proves runtime behavior.
3. **Append-only evidence.** Never edit or delete existing `EV-NNNN` entries; correct them with
   a new entry that cites the old ID. Never renumber `EV-`/`D-`/`Q-` sequences.
4. **No invented facts.** If a search found nothing, record the bounded search (pattern, range)
   as an explicit unknown. Never guess addresses, constants, or behavior.
5. **Keep docs current as you go**, not only at session end: tick tasks, add evidence, update
   the PLAN summary counts and its `Last updated` header (including its `Next:` pointer).
6. **Personal-use assets.** Extracted game assets stay in this project only (Q-0006); do not
   publish them.
7. **Wiki-guided understanding (D-0010).** Do not guess mechanics or terminology: consult the
   game wiki (section below) before interpreting behavior. Record internal <-> display-name
   bindings and wiki-only claims in `docs/analysis/notes/wiki-refs.md` + `wiki-ref` EV entries;
   the binary remains the only proof of behavior, and wiki-vs-binary conflicts stay recorded as
   open items, never silently resolved.

## Game wiki (secondary source)

- Base: `https://insaniquarium.fandom.com/wiki/` - fetch a page for review with `?action=raw`
  appended (clean wikitext; the normal HTML page adds nav chrome).
- Role (D-0010): reference for **display names, terminology and mechanics context**. Check it
  before interpreting behavior so we do not guess. It is not proof: behavior/constants still
  require a binary EV; wiki-only content enters as a `wiki-ref` EVIDENCE entry.
- Name policy: use wiki display names in prose (notes, PLAN, specs) and keep internal
  class/type names as the technical identifiers. Record every internal <-> display binding in
  `docs/analysis/notes/wiki-refs.md` with its binding evidence (EV refs); record wiki-vs-binary
  discrepancies as open items instead of silently picking one.

## Environment (verified 2026-10-15; re-verify before trusting)

- Node 24.16.0, npm 12.2.0, `rea-agents` 6.5.0.
- Ghidra 12.1.4 at `C:\tools\ghidra_12.1.4_PUBLIC`; JDK 21 Temurin at
  `C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot`; provider `ghidra` (Windows
  Ghidra P0 boundary: read-only, x86/x86-64 PE only).
- Godot 4.7.1 stable: `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe` (this project
  imports/boots headless, exit 0).
- REA reference: repo `C:\Users\Fauzi\Documents\project\rea\` - skill at
  `.agents\skills\reverse-engineer-anything\SKILL.md`, docs at `docs\cli.md`,
  `docs\native-investigation.md`, `docs\windows-ghidra-p0.md`.
- Canonical target exe: `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe`.
  The parent-folder copy (`...\project\Insaniquarium Deluxe\`) is byte-identical for the exe and
  `bass.dll` but is NOT canonical (D-0001, EV-0007).

## Running REA (CLI route)

Always work from the project root and go through the wrapper (it sets `GHIDRA_INSTALL_DIR`,
`JAVA_HOME`, `REA_ANALYSIS_PROVIDER` for the call):

```powershell
$exe  = "C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\Insaniquarium.exe"
$snap = "docs\analysis\snapshots\insaniquarium.json"

& .\tools\rea.ps1 analyze   $exe --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 search    $exe "<pattern>" --kind strings --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 function  $exe 0xADDRESS --provider ghidra --json --snapshot $snap
& .\tools\rea.ps1 decompile $exe 0xADDRESS --provider ghidra --json --snapshot $snap
```

- **Always pass `--snapshot`**: results are cached across sessions; identical queries become
  free. New queries still run Ghidra (cold import, deadline ~330 s) - use tool timeouts >= 600 s.
- Do not repeat an identical query whose result is already recorded. Reuse the snapshot,
  exported JSON, or notes instead (REA skill rule).
- Save bulky outputs as JSON under `docs\analysis\snapshots\` or `docs\evidence\`, then cite
  the path + key excerpts in EVIDENCE.md. Quote addresses and hex exactly as returned.
- MCP tools are registered for opencode but only appear after a client restart (P0.10); until then
  use this CLI route.
- **P2 game-module target** (D-0009): gameplay code is NOT in the outer image. Carve the embedded
  module once with `powershell -File tools\extract-game-module.ps1` ->
  `docs\analysis\snapshots\insaniquarium-game-module.exe`, then pass it as `<exe>` with snapshot
  `docs\analysis\snapshots\insaniquarium-game-module.json`. Outer-exe addresses are only for
  wrapper/DRM/main-loop behavior (P2.1).
- Engine-free shortcuts: `powershell -File tools\pe-imports.ps1 <exe>` prints the PE import table
  without Ghidra (used for EV-0011); `powershell -File tools\rtti-classmap.ps1` maps the module's
  MSVC RTTI classes -> vtables/slots (EV-0041).

## Session end checklist

- [ ] PLAN.md: statuses, dates, EV refs, summary counts, `Last updated` + `Next:` line.
- [ ] EVIDENCE.md: appended entries for every new claim.
- [ ] P2 system notes end with an "Implementation spec for P4" section (D-0008).
- [ ] DECISIONS.md: new decisions/questions recorded.
- [ ] Raw outputs saved under `docs/analysis/` or `docs/evidence/` and referenced.
- [ ] Blocked tasks marked `[!]` with the exact blocker and what would unblock them.
