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

### D-0005 - Mandatory vs on-demand docs (user instruction, 2026-10-15)
- Date: 2026-10-15
- Decision: Every session reads `AGENTS.md` + `docs/PLAN.md` (mandatory). `EVIDENCE.md`, `TARGET.md`,
  `DECISIONS.md`, and `docs/analysis/notes/` are read on demand, when the current task needs them.
- Why: faster agent startup; PLAN.md already carries statuses plus EV refs into the rest.

## Open questions

### Q-0001 - Godot editor availability - ANSWERED 2026-10-15
- Godot 4.7.1 stable win64: `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe` (a second
  copy of the exe + zip sits in `Downloads\`). `--headless --import` of this project exits 0.
  See TARGET.md and PLAN P0.11.

### Q-0002 - Project naming - ANSWERED 2026-10-15
- Keep `config/name="fih"`. User decision.

### Q-0003 - `*.frames.png` and `crash.txt` origin - ANSWERED 2026-10-15
- Leftovers of a prior attempt on this machine (timestamps 12 Aug 2026; absent from the mirror
  copy; user confirms the prior attempt). Not shipped content (EV-0010). Revisit only if a fresh
  official install ever shows them.

### Q-0004 - Remake scope - ANSWERED 2026-10-15
- Vertical slice first: Tank 1 complete, then widen to all tanks/modes. Phase ordering should
  serve the Tank 1 slice first.

### Q-0005 - Display and resolution policy - ANSWERED 2026-10-15
- Pixel-exact 640x480 4:3 with integer scaling; keep original asset dimensions.

### Q-0006 - Asset redistribution
- Extracted PopCap assets are fine for personal use here. If distribution is ever intended,
  art/audio/music must be replaced with original or licensed work. Noted per AGENTS.md rule 6.

### Q-0007 - REA MCP registration into opencode - ANSWERED 2026-10-15
- Registered via `npx rea-agents setup --client opencode` (dry-run reviewed first; config backup
  at `opencode.jsonc.rea.backup`; skill installed to
  `C:\Users\Fauzi\.agents\skills\reverse-engineer-anything`). Effective after the next opencode
  restart; the CLI wrapper (`tools\rea.ps1`) remains the documented fallback.

### Q-0008 - Version control for the remake project - ANSWERED 2026-10-15
- `git init` done; initial commit `68f1d75` on `main` (14 files, baseline). Keep committing at
  session ends for diffable agent handoffs.
