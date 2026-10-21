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

### D-0006 - Music tooling: decode `.mo3` with ffmpeg/libopenmpt
- Date: 2026-10-15
- Decision: `.mo3` music is decoded/transcoded with ffmpeg (libopenmpt demuxer -> libvorbis
  `-q:a 5`, 48 kHz stereo) via `tools\decode-music.ps1`; BASS P/Invoke decoding and a lossless
  WAV archive are both rejected. The read-only install keeps the MO3 originals; `assets_raw\` is
  gitignored and regenerable, so no second lossless copy is kept.
- Why: ffprobe/ffmpeg verified to read all three MO3 v1 files natively (EV-0032), avoiding
  32-bit PowerShell + x86 DLL loading entirely; OGG matches the game's own sound container and
  imports directly in Godot. On-disk leftovers check: installed `bass.dll` is NOT imported
  statically by the exe (EV-0011), so nothing in this pipeline depends on it.

### D-0007 - Font storage & composition (SexyApp bitmap fonts -> BMFont)
- Date: 2026-10-15
- Decision: Each font emits one Godot page PNG composed as RGB = base atlas pixel (or underscore
  fallback atlas) and A = luminance of the mask atlas (or of the atlas itself when there is no
  distinct mask), plus one BMFont-text `.fnt` (space glyph from `LayerSetCharWidths`;
  `base` = `LayerSetAscent`; `lineHeight` = atlas cell height). Raw base/mask GIFs are kept 1:1
  under `assets_raw\fonts\raw\`; all raw metric fields stay in `fonts.json`.
- Why: reproduces the original two-image draw model (colorize/mul with alpha mask, which yields
  the tint-fill + dark-outline look of the outline fonts) and imports directly in Godot
  (EV-0033). Raw layers preserved so P4 can switch to explicit two-pass outline rendering if
  P2.12 proves the engine tints layers separately. Line-advance semantics
  (AscentPadding/LineSpacingOffset) are approximations until P2.12.

### D-0008 - Phase 2 output standard: implementation specs for P4
- Date: 2026-10-15
- Decision: Every P2 system note (`docs\analysis\notes\p2*.md`) must end with an
  "Implementation spec for P4" section: recovered constants (address + EV refs), formulas,
  timings, state machines, spawn tables and file formats, written so P4 can be implemented
  without re-reading the binary. Phase 2 closes with `docs\SPECS.md` (task P2.18), the
  cross-system contract for P4, modeled on `docs\PIPELINE.md` (the asset-side contract).
- Why: reverse-engineering output must be directly actionable; P4 should consume two complete
  contracts - assets (`docs\PIPELINE.md`) and behavior (`docs\SPECS.md`).

### D-0009 - The embedded game module (carved from the exe) is the primary P2 analysis target
- Date: 2026-10-16
- Decision: Gameplay analysis (P2.x systems) cites **game-module VAs** from
  `docs\analysis\snapshots\insaniquarium-game-module.exe` - a deterministic carve of the
  canonical exe (embedded PE32 at file 0x1881A2, SHA-256
  `33f34bae5eeee213c2a3819a13a4515c99a357f4247d42e5314da20621efe2c4`; regenerate with
  `tools\extract-game-module.ps1`; REA snapshot `insaniquarium-game-module.json`). Outer-image
  addresses remain canonical only for wrapper behavior (P2.1 main loop, DRM/LuaApp).
- Why: the outer exe is a Lua/DRM e-commerce wrapper (EV-0037/EV-0038); all gameplay code,
  classes and strings live in the PopCap-DRM-protected embedded module (EV-0039..EV-0042).
  The install stays read-only (D-0004); the carved copy is derived, local, personal use (Q-0006)
  and lives in a gitignored directory.

### D-0010 - Game wiki as a secondary source for names and mechanics context (user instruction)
- Date: 2026-10-16
- Decision: The Insaniquarium Wiki (`https://insaniquarium.fandom.com/wiki/`, raw pages via
  `?action=raw`) is the project's secondary source for display terminology and mechanics
  context (mode names, money items, store prices, creature behavior). It is used for naming and
  hypothesis framing only: behavior and constants still require a binary observation, and
  wiki-only claims enter as `wiki-ref` EVIDENCE entries plus rows in
  `docs\analysis\notes\wiki-refs.md`. Internal class names remain the technical identifiers,
  and every internal <-> display binding is documented with its binding evidence. Wiki-vs-binary
  conflicts are recorded as open items, never silently resolved.
- Why: user directive (2026-10-16): do not guess mechanics - understand them from the wiki and
  document each finding clearly. Earlier name-shaped guesses (BallFish/SylvesterFish/BiFish =
  hostile aliens) were wrong - they are the Virtual Tank prize fish (EV-0060).

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

### Q-0009 - Who sets the corpse revive phase (`DeadFish+0x190 <= 10`)?
- OPEN (2026-10-16, EV-0052/0053). Natural death ends with silent corpse removal (`stage < 1`,
  slot 0x144); the successor (revive) branch at `phase < 1` requires an external writer we have
  not found yet (candidates: a pet ability in P2.7, zombie mode `DAT_005e89ce`). Revisit when
  P2.6/P2.7 are analyzed; do not guess a trigger in the remake.

### Q-0010 - Gameplay intent of the coin-vs-creature hit dispatch
- OPEN (2026-10-16, EV-0055). A falling coin hit-tests `+0xAC < 0` objects per list and runs
  the target's corpse-spawn routine for Penta (`+0xD0`), Grubber-region (`+0xC4`) and
  Breeder-family (`+0xC0`) lists (same routines as their starvation deaths). Whether this is
  collect/kill/eat behavior cannot be decided statically; verify in-game during P2.6/P2.8/P5.

### Q-0011 - Where are the hostile alien classes in the game module?
- OPEN (2026-10-16, EV-0060). The RTTI class map (`docs\evidence\p2.2-module-rtti-classes.txt`)
  exposes `Alien::Sexy` plus only `Bilaterus`/`BilaterusHead`/`BilaterusBone` (and `DeadAlien`,
  `Missle`, `Larva`); no Sylvester/Balrog/Gus/Destructor/Ulysses/Psychosquid classes. The
  hostile aliens are plausibly `Alien` instances selected by type id/data (or classes without
  RTTI), but nothing is confirmed. Resolve in P2.8 by tracing the alien spawn waves and the
  `Alien` ctor callers; do not guess class names for the remake until then.

### Q-0012 - Who writes the tank/level advance (`profile+0x1C`/`profile+0x20`)? - ANSWERED 2026-10-20
- `FUN_00501370` (ECX = `profile`) is the advance writer (EV-0066): level++; tank 4 + level 6
  -> tank 5 + level 1; tank 5 + level > 1 -> `profile+0x50++` and `profile+0x59 = 1`;
  level > 6 or (`profile+0x59 != 0` and level > 5) -> tank++, level 1; always
  `profile+0x58 = 1`. Callers: 0x545D41/0x545D88 in `FUN_00545960` and 0x547B31 in
  `FUN_00547610`. `FUN_00501530` is the new-profile reset, not the advance. Pet awards use the
  completed level copies `Tank+0x3C8/+0x3CC`, not the post-advance profile (EV-0076).

### Q-0013 - Trophy/story award gate (`profile+0xB4`, `profile+0xB0`)
- OPEN (2026-10-20, EV-0071/EV-0074/EV-0075). `profile+0xB4` is reset to 3 and Sandbox raises
  it to 11; `profile+0xB0` is the bonus-pet/upgrade card index 1-6 (Brinkley..Walter, 4-pet and
  7-pet cards). No writer/reader was found that maps the wiki's 32 Challenge stories or the
  33rd gold-trophy ending onto these fields. Revisit in P2.11/P2.12; do not invent a trophy
  trigger in the remake.

### Q-0014 - Mode 2 role
- OPEN (2026-10-20, EV-0075). No observed condition or name for `manager+0x87C == 2`. Do not
  assign it a name/behavior; resolve with the other mode bindings in P2.11. (Modes 0 Adventure,
  1 Time Trial, 3 Sandbox, 4 Challenge, 5 Virtual Tank are observed.)

### Q-0015 - `profile+0x58` reader and `profile+0x50` semantics
- OPEN (2026-10-20, EV-0066/EV-0069/EV-0075). `profile+0x58` is set to 1 by every
  `FUN_00501370` call, but no reader was located. `profile+0x50` increments on every tank-5
  level > 1 completion and feeds the tank-5 BonusScreen payout `max(1,+0x50-1)*5000` (cap
  25000); whether it counts completed runs, boss wins, or tank-5 levels is not proven.

### Q-0016 - Credits trigger
- OPEN (2026-10-20, EV-0071/EV-0075). `FUN_00525A60` (credits sequence) has only the data xref
  0x5A0E4C; no code caller was found. The tank-5 score helper prepares the empty-pet-slot data
  used by the pet-loss jokes (EV-0067), but the screen trigger is unknown. Resolve in P2.12.

### Q-0017 - Tank 6 path
- OPEN (2026-10-20, EV-0075). `FUN_00501370` can increment to tank 6 when `profile+0x59 != 0`
  and level > 5, but `FUN_0054B2A0` tests only `profile+0x20 == 6`, `FUN_00541200` has no
  tank-6 store case, and `FUN_0054B2D0` has no tank-6 event. Do not implement tank 6 until the
  intended Bonus Adventure end state is confirmed.

### Q-0018 - StoreScreen item population / normal store-item owner
- OPEN (2026-10-20, EV-0071/EV-0072/EV-0075). `FUN_0052B2D0` creates 8 child item objects and
  a Shell counter but does not read `profile+0xB0` or set prices; population/price display lives
  in the child/update code, which was not decompiled. The normal (non-mode-4) store-item object
  owner is also open (xrefs 0x4F18xx tutorial loop, 0x54782A tank update). Resolve in P2.12.

### Q-0019 - `userdata/scr%d.dat` format and Shells persistence
- OPEN (2026-10-20, EV-0069/EV-0075). `FUN_005148C0` formats `userdata/scr%d.dat` from
  `this+0x44`, deserializes it (`FUN_0047F5D0`), compares a stored integer with `this+0x88`, and
  on a match consumes 50 filler ints + 1 + 50 filler ints; `FUN_00515910(param)` writes
  `FUN_005148C0(0)+param` surrounded by 50 `rand()%20000` ints. Serializer/return path,
  obfuscation, and the exact timestamp/value meaning are unresolved. Resolve in P2.13.
- 2026-10-21 update (EV-0108): the live folder is
  `C:\ProgramData\Steam\Insaniquarium\userdata`, and a real sample is copied to
  `docs\analysis\inputs\p2.13-saves-2026-10-21\` (`users.dat`, `user1.dat`, `adv1.dat`).
  The Adventure save is `adv%d.dat` (version dword `0x36`), not `scr%d.dat`; `scr%d.dat`
  remains the separate Shells file and is absent because this profile has no Shells. The
  `users.dat` layout is readable (profile name `okokok`); `user%d.dat` and `adv%d.dat` field
  order still need the P2.13 parse. The sample is early-game, so trophy/credits states are not
  covered.
