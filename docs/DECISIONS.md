# Decisions and open questions

## Settled decisions

### D-0001 - Canonical analysis target is the Steam install
- Date: 2026-10-15
- Decision: All analysis and asset sourcing uses `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe`.
  The other copy on disk (`C:\Users\Fauzi\Documents\project\Insaniquarium Deluxe`) is not used.
- Why: official, verifiable, hashable build; reproducible evidence.

### D-0002 - Toolchain and provider
- Date: 2026-10-15
- Decision: REA (rea-agents 6.5.0) with the Ghidra 12.1.4 provider on Windows (P0 read-only
  boundary); JDK 21 Temurin. Native queries run through `tools\rea.ps1` with a shared snapshot.
- Why: matches REA's verified Windows configuration; snapshot reuse keeps multi-agent work cheap.

### D-0003 - Documentation protocol (agent hopping)
- Date: 2026-10-15
- Decision: PLAN.md is the single source of progress; EVIDENCE.md is append-only; every completed
  task must carry date + EV refs; AGENTS.md defines the handoff rules.
- Why: enables different agents/sessions to continue work without losing state or provenance.

### D-0004 - Read-only analysis target
- Date: 2026-10-15
- Decision: The game install is never modified. No patching, no in-place debugging writes.
- Why: integrity of the reference build; REA Windows P0 is read-only anyway.

## Open questions

### Q-0001 - Godot editor availability - ANSWERED 2026-10-15
- Godot 4.7.1 stable win64: `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe` (a second
  copy of the exe + zip sits in `Downloads\`). `--headless --import` of this project exits 0.
  See TARGET.md and PLAN P0.11.

### Q-0002 - Project naming
- The Godot project is `config/name="fih"`. Rename to e.g. "Insaniquarium Remake"? User call.

### Q-0003 - `guppy_swim1.gif.frames.png` origin
- Is it shipped with the Steam build or a leftover on this machine? If the user can re-download
  / verify on a second install, that settles it.

### Q-0004 - Remake scope
- Full game (5 tanks x 5 levels, Adventure + Challenge + Time Trial + Virtual Tank, all pets,
  all aliens) vs. vertical slice first (Tank 1 complete)? Recommendation: vertical slice first,
  then widen. User decision.

### Q-0005 - Display and resolution policy
- Original is 640x480. Keep pixel-exact 4:3 window/scaling, or design a widescreen layout?
  Affects asset pipeline and UI work. User decision.

### Q-0006 - Asset redistribution
- Extracted PopCap assets are fine for personal use here. If distribution is ever intended,
  art/audio/music must be replaced with original or licensed work. Noted per AGENTS.md rule 6.

### Q-0007 - REA MCP registration into opencode
- `rea doctor` shows opencode registration missing. Registering (`npx rea-agents setup --client
  opencode`) would give future sessions direct MCP tools instead of CLI-only. Needs user approval;
  changes `C:\Users\Fauzi\.config\opencode\opencode.jsonc` and installs the REA skill.

### Q-0008 - Version control for the remake project
- `fih\fih` has `.gitignore` + `.gitattributes` but no `.git` repository. A local `git init`
  (no remote needed) would make agent handoffs diffable and auditable - useful for agent hopping.
  Needs user approval (PLAN P0.13).
