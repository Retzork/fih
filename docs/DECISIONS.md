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

### D-0011 - The dialog base is ported by role; `Sexy::MoneyDialog` is not a remake class
- Date: 2026-10-29
- Decision: The ten concrete dialogs (Continue, FishNaming, Food, NewUser, Options, Pet, Register,
  ScreenSaver, User, Virtual) are modelled as data on one modal base implemented by role
  (`Dialog`: three strings + `kind` 0/1/2/3 + the 1000/1001 button ids + listener mixins). No
  `MoneyDialog` class is ported, and the base is **not** described as deriving from a money dialog.
- Why: the base vtable pair installed by `FUN_00530920` is the pair RTTI attributes to
  `.?AVMoneyDialog@Sexy@@` (listener 0x5A5D68, object 0x5A5D8C; locator 0x5A5D64 -> TypeDescriptor
  0x5E2034, name read byte-for-byte), the same pair is re-installed by the 0x13-byte helper
  `FUN_005309C0` from every dialog destructor's base call, and **no `.?AVDialog@Sexy@@` locator
  exists in the module**. There is also no constructed MoneyDialog instance: its only "ctor" is that
  helper, whose nine callers all sit in the dialog dtors. So the name is a RTTI artefact of the
  vendored SexyApp framework, not a UI the player can open (EV-0137, note §11.1).
- Boundaries: this settles the *modelling* question only. Why the framework's dialog base carries
  the MoneyDialog name (a folded/merged vtable, most likely) is not established and is not needed
  for the remake.

### D-0012 - "Pellets settle" is a deliberately non-faithful, constant-gated deviation
- Date: 2026-11-09
- Decision: one constant, `Food.SETTLE_TICKS` (shipped **20**), is the whole gate. A dropped pellet
  that reaches its death line rests there that many ticks (`y = death_line()`, `vy = 0`), then falls
  again, crosses the line and takes the recovered 15-tick sink-out. Star potions and breeding pellets
  keep their immediate removals. `SETTLE_TICKS = 0` restores the original behaviour with no other edit.
  There is no runtime switch and no Options checkbox: the constant is the only knob.
- Why: EV-0159/EV-0160/EV-0161/EV-0166 establish that a dropped pellet never lands - only Angie's
  re-lay constructs a landed pellet, and every other drop crosses the line, arms a 15-tick life and is
  removed. A brief floor rest was requested as a visible deviation, so it is kept to one named
  constant a reader can flip, rather than spread through the update as a second mode.
- Boundaries: this is presentation, not recovered behaviour - never cite it as evidence for landing,
  and keep it out of the save format (food is not persisted). `headless_entity_check` pins the rest
  window and the resumed sink-out.

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
- RESOLVED (2026-10-21, EV-0099; originally OPEN 2026-10-16, EV-0052/0053). Angie (pet 0x12)
  is the external writer: `FUN_004FE740` calls `FUN_004D5630`, which changes a corpse's
  `+0x190` from 100 to 10 when it is exactly 100. The corpse then follows the normal revive
  path. Revive sound/animation and the `+0x1A0` timer details remain P2.4 work, not this
  question. Do not treat natural death as the revive trigger.

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
- RESOLVED (2026-10-29, EV-0110/EV-0111). There are no per-species classes: every hostile alien
  except Bilaterus is a `Sexy::Alien` instance whose kind (`Alien+0x1EC`, copied from the spawn
  selection `Tank+0x2BC`) selects stats, sprite, warning sound and attack code.
  `Sexy::Bilaterus`/`BilaterusHead`/`BilaterusBone` are the only other hostile classes;
  `DeadAlien` is a corpse and `Missle`/`Larva` are projectiles. Kind binding: 1/2 Sylvester,
  3 Balrog, 4 Gus, 5 Destructor, 6 Ulysses, 7 Psychosquid, 8 Bilaterus, 9-0xC composite spawn
  selections, 0x14 Minisylvester, 0x15 Cyrax. The remake therefore uses one `Alien` entity plus a
  kind resource table, not one class per species (see `docs/analysis/notes/p2.8-aliens.md`
  §1/§11). The residual identity question (kind 1 vs kind 2) is tracked as Q-0020.

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
- 2026-10-21 update (EV-0109): the GameBanana profile sets `profile+0x7C = 0xFFFFFFFF` and
  `profile+0x80 = 1`, with `+0x84 = 2`, while the early profile has `0/0/2`. This is a strong
  numerical match for a 32-bit story mask plus a 33rd gold-trophy flag, and `FUN_00501530`
  clears `+0x7C/+0x80` alongside the four Challenge record bytes. However, no instruction-level
  reader/writer for `+0x7C` or `+0x80` was located, and the sample's four record bytes are
  `1,1,1,0` rather than a clean four-tank set. Keep Q-0013 **OPEN**; the labels are a lead, not
  a proven trophy trigger.
- 2026-10-29 update (P2.12, EV-0136): the **read side of `profile+0x7C` is found**. The
  `StoryScreen` ctor `FUN_0052EE80` loads `profile+0x7C`, shifts it one bit at a time and counts
  set bits, stopping at 2; if fewer than two bits are set it hides both the Previous and the Next
  button (`byte[+0x54] = 0`). So `+0x7C` is a per-story **unlock bitmask** that gates the story
  browser on "at least two stories seen" - the first instruction-level reader for it. There is
  still no writer for the individual bits and no reader/writer for a 33rd ending flag at `+0x80`.
  Keep Q-0013 OPEN and narrower: the mask semantics are proven, the trophy trigger is not.

### Q-0014 - Mode 2 role
- OPEN (2026-10-20, EV-0075). No observed condition or name for `manager+0x87C == 2`. Do not
  assign it a name/behavior; resolve with the other mode bindings in P2.11. (Modes 0 Adventure,
  1 Time Trial, 3 Sandbox, 4 Challenge, 5 Virtual Tank are observed.)
- 2026-10-29 update (P2.11, EV-0126): still unbound. The tank update, `start_level`, the store
  refresh, the egg handler and the alien/missile code have **no** `mode == 2` branch, no mode-2
  string and no writer for the field at all, so P2.11 could neither name nor refute it. The
  selector and any mode-2 entry belong to the menu layer (P2.12).
- 2026-10-29 update (P2.12, EV-0131): the menu layer is now mapped and it does not create mode 2
  either - the GameSelector callback writes only 0, 1, 4 and 5. Mode 2 and mode 3 (Sandbox) both
  remain writer-less in the corpus, so 3's name rests on the UI text alone and 2 stays unnamed.

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
- 2026-10-29 update (P2.12, EV-0135): **price display and grey-out are ANSWERED**, the owner is not.
  The item widget is `Sexy::StoreButtonWidget`; its draw/price/select slots are 26 `0x531A60`, 44
  `0x531C30`, 50 `0x5319B0`, 51 `0x531A00` (slot 22 `0x531A30` forwards to the child at `+0x124`).
  `FUN_00536350(price)` is `SetPrice` - `[item+0x128] = price` and `sprintf("%d", price)` into the
  string at `+0x12C` - and the sold-out branch `FUN_005372F0` overwrites that string with the literal
  `SOLD` (`0x5A7CA4`) and clears the enabled byte `+0x55`, which is exactly what slot 44 greys to
  `0xCCCCCC`. The stock is rolled by `FUN_0052FEA0` on attach (`FUN_0052F0D0` roller, 8 items gated by
  `profile+0xA8+i`, pet slots by `profile+0x72+i`, one-off unlocks on `profile+0x90`/`+0x94`).
  Still open: the call-site owner of the *normal* store-item object (unchanged) and whether the rolled
  pet is really the receiver of `FUN_00519730()` (the decompiler loses `ECX` there; the fields
  `+0x8C`/`+0x1D0`/`+0x1D1` fit a pet). Close the owner in P2.13 with the tank update.
- 2026-10-29 update (P2.12, EV-0138): **the receiver question is ANSWERED - yes.** The machine code
  sets `ECX` from the object just built at all four call sites (`mov ecx, edi`/`esi` at 0x519F32,
  0x519F48, 0x52F19D, 0x52F27B and 0x52FE61/0x52FE77, right before `call 0x519730`), so the getter is a
  method on the prize, not on the store item: the icon children are `Sexy::Fish` (vtable 0x597D54) and
  `Sexy::Oscar` (0x59843C), and every class the roller's factory can return stamps **its own kind at
  `+0x8C`** in the stub that precedes its ctor (9, 8, 0xA, 7, 5, 0x22, 6, 0x23, 0x24) - exactly the
  switch domain of the getter. A kind-1 slot is therefore priced by the prize it rolled, with the tank
  index from `FUN_00501060()` overriding it flat for 0-8. Remaining: the call-site owner of the normal
  store-item object, still deferred to the tank update in P2.13, plus the unlocated writers of
  `prize+0x1D0`/`+0x1D1`.
- 2026-11-01 update (P2.13, EV-0144): **the tank-side xref is identified, the owner question is
  narrowed.** `0x54782A` is a `FUN_005409B0()` call inside `FUN_00547610`, gated on tank 5 /
  `Tank+0x110 == 0` / `+0x2A5 == 0` / `+0x3AF == 0`. `FUN_005409B0` only lazily builds a widget when
  `Tank+0x404 + slot*4` is null and marks the row's `present` byte, so the **tank owns the item cache**
  and the store screen/widgets are just clients. Still open: the `0x4F18xx` tutorial-loop owner (which
  screen/step triggers it), the `prize+0x1D0`/`+0x1D1` writers, and whether the normal (non-Challenge)
  screen path ever builds the cache through another caller.

### Q-0019 - `userdata/scr%d.dat` format and Shells persistence (RESOLVED)
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
- 2026-10-21 update (EV-0109): a second sample from GameBanana
  (`docs\analysis\inputs\p2.13-saves-gamebanana-100\`) has `users.dat`, `user1.dat`, and
  `sim1.dat`, but still no `scr%d.dat`. The 232-byte `user%d.dat` field order is now mapped
  end-to-end through `FUN_00503730` (see P2.13 note). The `scr%d.dat` serializer, its
  obfuscation, and the exact timestamp/value meaning remain **OPEN**.
- 2026-10-29 update (EV-0142): `this+0x44` is the profile's **save-slot number** - the same `%d`
  used by `userdata/user%d.dat`, `userdata/scr%d.dat` and the six per-mode tank files - so the
  Shells file is one-per-slot, and `FUN_005059D0` deletes it together with the others when the
  profile is removed. `FUN_005148C0`/`FUN_00515910` themselves are still unread; **OPEN**.
- RESOLVED (2026-10-29, EV-0143). `scr%d.dat` is the **escrow for bonus-round Shells**, not a save of
  its own:
- Format: 102 raw little-endian dwords = `0x198` bytes - `[token] [50 x rand()%20000] [payload]
  [50 x rand()%20000]`. The payload is dword 51 (offset `0xCC`). No header, no cipher, no checksum;
  the filler is never validated. `FUN_00500340`/`FUN_005004E0` are plain 4-byte read/write and the
  only structured reader in the family (`FUN_00513E30`) is a `Sexy::DataSync` ctor the escrow writer
  never calls.
- Token gate: dword 0 must equal `profile+0x88`. `FUN_005148C0(consume)` returns the payload on a
  match and 0 otherwise, and deletes the file when `consume != 0` - so a copied or stale file is
  discarded rather than credited.
- Lifecycle: `FUN_00546990` (SaveGame) flushes `Tank+0x400` (the bonus-round shell counter) into the
  escrow and zeroes it; `FUN_00514B00` cashes in - clamp to 100000, `FUN_00501200(v)` adds to Shells
  (`profile+0x48`), regenerate the token, save the profile - from tank load (`FUN_00546AA0`),
  `FUN_0054BCA0` (pre-bonus store), `FUN_0054BF60` (BonusScreen) and `FUN_00552100` (session setup).
- **Correction of the first pass:** the value stored at `profile+0x88` is a **random token**
  (`FUN_0040F9E0`, an RNG entry point; also what `FUN_00501530` seeds `+0x98/+0x88` with), not a
  timestamp. It is the trailing dword of `user%d.dat`, so the escrow is bound to the profile record.
- Port: keep the shell counter in the profile or the tank save and pay it exactly once; the file
  itself is not worth reproducing (`p2.13-saves.md` §7). Residue: why the demo branch cashes at load
  while the full version banks at save is not established.

### Q-0020 - P2.8 residual alien questions
- OPEN (2026-10-29, EV-0110-EV-0116). Items that survived the P2.8 pass; none blocks P2.9/P2.10
  and none may be guessed in the remake:
- **Kind 1 vs kind 2.** Both are Sylvesters (`aliens draw` case 1 and 2 share `DAT_005e8ebc`),
  kind 1 has hp 50 / speed 2.0, kind 2 hp 60 / speed 1.6. The binary carries no second name and
  the wiki has no second Sylvester. Model kind 2 as a stronger Sylvester until the story/asset
  side (P2.12/P3) proves a distinct identity.
- **`FUN_005392A0` sub-predicates.** The predicate itself is decoded (EV-0116): it is true when
  `Tank+0xA0` (fish), `Tank+0xA4` or `Tank+0xD0` (Penta) is non-empty, or when any of
  `FUN_004E3ED0`/`FUN_004E3F00`/`FUN_004E3F30`/`FUN_004E3F60` is true. Those four remain
  undecoded, so the exact "level still in progress" reading is still bounded; keep it behind one
  config flag.
- **Bite handshake virtuals.** `FUN_004E8F70` is decoded (EV-0116): reach boxes per target type,
  then alien vtable slot 77 (`consume`) and the victim's slot 75. The class-map dump stops at 64
  entries, so neither address is bound; the fish side of the same two slots is P2.3/P2.4 material.
- **Gus pellet cost.** Feeding Gus a pellet removes it and subtracts 4-30 from `+0x1F0`, the same
  pool pet melee drains and `Update` kills at `<= 0` (EV-0116). Whether the design intends "food
  damages Gus" or a shared fullness/hp pool is not decidable statically - do not ship the number
  without a runtime check or wiki confirmation (the wiki was unavailable on 2026-10-29, HTTP 403).
- **`FUN_005442C0` death animation.** The default-branch death call takes two resource lookups
  over (frame `+0x1C0`, kind `+0x1EC`, facing) plus those three values; candidate corpse or
  explosion object. Not decompiled (EV-0115). It is *not* the money drop - that is settled
  (`Tank::SpawnCoin` kind 4 = Diamond, 200).
- 2026-10-29 update (EV-0118): the "two resource lookups" are two calls to `FUN_00564160`, which is
  the CRT float->int helper (`ROUND(in_ST0)`), not a table lookup. The frame/kind/facing arguments
  of `FUN_005442C0` are still unbound, so the "corpse or explosion" reading now rests on those three
  arguments alone; the previous derivation is withdrawn.
- **Tank flag writers.** `Tank+0x178` (HP-bar enable), `Tank+0x4F4` (wave-clock hold),
  `Tank+0x4FE` (warning sound enable), `Tank+0x4DE` (tank3 L4 / composite marker): only readers
  are proven.
- **`FUN_004FB1C0` / `FUN_004DAA00`.** Head swap effects and the post-update animation/cleanup
  are named by call site only; `Alien` slot 0xA4's two random arguments are likewise unbound.
- **Base `+0x28` age field.** The VT warp-out compares it with `0x10E0` (4320); its writer is in
  the shared object base and was not traced, so the "aliens retreat after 120 s in Virtual
  Tank" reading stays bounded.
- **Kind 0.** Tank1 L1 selects type 0 and no early-out exists, so `FUN_00545620` builds an
  `Alien` with no stat branch, no draw case and no hp init. Do not spawn a kind-0 alien; treat
  tank1 L1 as alien-free (see `p2.8-aliens.md` §10).

### Q-0021 - Tank-5 victory gate: is the egg piece locked behind the boss?
- OPEN (2026-10-29, EV-0119). The tank-5 egg-piece handler `FUN_00545960` has exactly two gates,
  `FUN_00538090(0xB)` (store object exists) and `Tank::SpendMoney`, and **neither reads
  `Tank+0x110`** - so at handler level a free egg piece can be bought while Cyrax is still alive,
  and `Tank+0x43C` 3 -> 4 completes the level. Two readings stay possible:
  (a) the fight is not gated at all and "beat the boss" is only a soft story expectation;
  (b) the store UI greys the item out (the `FUN_0052B2D0` child/update code was never decompiled -
  Q-0018), so the handler is never reached with a live boss.
  Bounded negative: no `Tank+0x110` test exists in any decompiled tank-5 completion path
  (`FUN_00545960`, `FUN_00501370`, `FUN_00517C70`). Resolve in P2.12 (store UI) or by a runtime
  check. Until then the remake gates the purchase on the boss being dead and records the divergence
  (see `p2.9-bosses.md` §10.9).

### Q-0022 - `profile+0x54` semantics, and `from_shot` at the shot-kill call site
- OPEN (2026-10-29, EV-0119/EV-0120). Two small loose ends from P2.9:
- **`profile+0x54` counter.** It is read by the `Alien` ctor as the Cyrax hp offset
  (`5000 - 125*clamp(+0x54-1,0,20)`, EV-0111) and incremented in exactly one place (EV-0119):
  inside `FUN_00547610`'s tank-5 branch, when `Tank+0xB4` and `Tank+0xB0` are empty and a live boss
  has already lost more than 1000 hp. That branch sits where the "no fish left" loss handler sits
  for other tanks, but it can fire while the boss is still alive, so it is neither a clean "loss"
  nor a clean "defeat" counter. The numbers are proven; only the name and the triggering moment
  (retry vs. partial-damage snapshot) are open. Model it as `cyrax_offset` and keep the increment
  site parameterised until a runtime check shows when it actually moves.
- **`from_shot` at the shot kill.** `FUN_004FA6F0` calls `FUN_004F9C70()` with no visible argument
  (the melee path passes 1 explicitly, EV-0115), and the diamond drop is gated on `from_shot != 0`.
  Static reading says the shot kill still drops the diamond, but the argument is not materialised at
  this call site, so a shot kill producing no coin is not excluded. Not player-visible for Cyrax
  (`Tank+0x110 == 0` is required for the drop and is set only after the unregister), so it only
  affects ordinary aliens.

### Q-0023 - P2.10 residual weapon/projectile questions
- OPEN (2026-10-29, EV-0122-EV-0125). Five items the P2.10 pass could not bind; none blocks the P4
  click handler, and none may be guessed in the remake:
- **Laser draw and frame selection.** `IMAGE_LASERS` (`lasers.gif`, 6x10 = 60 frames of 80x48) and
  `IMAGE_LASERUPGRADES` are the only laser art in `resources.xml`, but **no decompiled weapon
  function references either image** - not the click handler `FUN_00543920`, not `Tank::BuyItem`
  `FUN_00549380`, not the store refresh `FUN_005406A0`. `FUN_00538AE0` (called at the end of every
  resolved click) and `FUN_00543640` (the spark spawner) are the likely draw entry, but neither is
  decoded. The "row = upgrade tier, column = animation" split is an asset-level guess only; keep the
  sprite/frame choice a parameter until `FUN_00538AE0` is decompiled (P2.11/P4 runtime check).
- **`Tank+0xBC` list identity.** The click handler walks it *before* the boss and only while
  `Tank+0x110 != 0`, and it calls `Alien::HitTest` on each element, so the elements are aliens of
  some kind. `Tank+0xB8` is the ordinary alien list (P2.8 §5). Bounded negative: the only `+0xBC`
  writes in the committed decompiled corpus (`docs/evidence/p2.8-wave-block-547610.txt` lines 522
  and 658) copy a `CRect` into a UI object at `in_ECX[0x46]`, not into the tank, so no traced spawn
  path writes `Tank+0xBC`. It may be a second wave/late-spawn container that is simply empty in
  normal play; do not populate it in the remake until a writer is found.
- **`Sexy::Larva` gameplay identity.** Its `Update` has two modes: a fall that despawns at `y < 64`
  and, more tellingly, a lerp to `(550, 30)` that **pays out shells** (`Tank+0x4A8++` +
  `FUN_0053C1E0`, P2.6's Shells routing helper). A projectile class paying shells is not something
  the wiki describes, and the `Larva` vtable is shared with the missiles, so this is likely a
  bonus-round or Virtual-Tank pickup object. No spawn site for it was found. Model the shells
  payout behind a flag and resolve in P2.11.
- **`FUN_004FF4E0` homing body and `FUN_004FE480` missile box test.** Both are referenced by
  `Missle::Update`/`Missle::HitTest` and neither is decompiled, so the steering curve (turn rate,
  target offset) and the clickable hitbox of a missile are unproven. `FUN_004FE480` gates on
  `+0x158 != 0`, i.e. on the double x having been set, which suggests a radius/box helper on the
  float position - not confirmed.
- **Rapid Fire implementation.** Level 12 shows `"Hold down mouse button for Rapid Fire!"`
  (`FUN_005406A0`, item 10, `Tank+0x3E4 > 0xB`), but no auto-repeat loop was found in the tank
  update, and the click handler `FUN_00543920` is a plain bound handler (one shot per OS click).
  Either the repeat lives in the platform input layer that feeds `FUN_0046E3A0`, or the flag is
  read somewhere not yet traced. The remake should implement hold-to-fire keyed on
  `weapon_level > 11` and record the divergence (see `p2.10-weapons.md` §3/§6).
- 2026-10-29 update (EV-0129): **answered.** The repeat is in the tank update, not the click
  handler: while `Tank+0x4ED` is armed and the mouse bit `Tank+0xEC & 1` is set, the update fires
  every `11 - Tank+0x3E4/2` ticks (5 at level 12) subject to a 100 ms stamp (`Tank+0x3C4`), testing
  `Tank+0xF4` -> `Tank+0xDC` -> `Tank+0xB8` (missiles, larvae, aliens) and skipping the boss,
  `Tank+0xBC`, the bonus round and the feed path. Releasing the mouse clears `Tank+0x4ED`.
- 2026-10-29 update (P2.11, EV-0126-EV-0130): the mode pass did **not** resolve the `Larva`
  identity. Bounded negative: apart from the projectile spawner (`FUN_00544130`, the `Missle` ctor)
  no committed decompiled body constructs that class, and no Virtual-Tank or bonus-round branch
  refers to it - the `Larva` ctor itself was never identified, so this is a corpus-wide absence,
  not proof. The shells payout stays behind a flag and the item moves to the P4 runtime list. The
  laser draw question also stands (`FUN_00538AE0` still not decompiled).

### Q-0024 - P2.11 residual mode/mode-predicate questions
- OPEN (2026-10-29, EV-0126-EV-0130). What P2.11 could not bind; none blocks the mode table:
- **Mode writer - ANSWERED** (2026-10-29, P2.12, EV-0131). The writer is the GameSelector
  `ButtonListener` callback `FUN_0051F160(button_id)`: id 1 -> mode 0, id 2 -> mode 5, id 8 ("Time
  Trial") -> mode 1, id 9 ("Challenge") -> mode 4, id 3 -> options dialog, id 4 ("Quit") -> exit,
  id 6 -> hall of fame, id 7 ("Help") -> help screen, id 9999 -> `FUN_0054B5F0`. Every entry first
  clears the demo flag `manager+0x880`, and ids 8/9 are gated on the profile (`+0x1C >= 2` /
  `+0x59 != 0` for Time Trial, `+0x59 != 0` for Challenge) with a "Not Yet!" dialog below the gate.
  Modes 2 and 3 still have no writer (Q-0014).
- **`FUN_004D80C0` receiver.** The body is `dword[this+0x19C] in {3,4,5}` (EV-0130) and it has 11
  call sites across the missile/larva/alien/spawner code; for missiles the offset is the kind, for
  aliens it is a byte flag, so the per-call receiver class is not uniform and not proven. Consequence
  already applied to the remake: missiles start still and the victim lock `target+0x98` is always
  set; the earlier "demo" label is withdrawn. Re-open if a caller passes a different class
  explicitly.
- **`Tank+0x4FE` writer - ANSWERED** (2026-11-01, P2.13, EV-0136/EV-0144). The writer is the
  `SimSetupScreen` "Return to Tank" handler: it copies the five checkbox state bytes back into
  `Tank+0x4FC..+0x500`, so `+0x4FE` is one of the five Virtual Tank option bytes (`+0x4FC`..`+0x500`
  are serialized as group 31 of the tank body). It still defaults to 0, but the remake can now expose
  it as a named VT checkbox instead of an unbound flag.
- **`Tank+0x2DC` / `+0x2E0` pair - ANSWERED** (2026-11-01, P2.13, EV-0144). `+0x2DC` is the count of
  store rows whose slot id is >= 0, recomputed by `FUN_00541A20` at level init (and serialized).
  `+0x2E0` is a runtime "widgets built" counter: `FUN_005409B0` increments it only when it creates a
  missing store widget, and the loader resets it to 0; it is **not serialized**. Sandbox's re-roll
  loop "while `+0x2E0 < +0x2DC`" therefore means "while some store rows still lack widgets". Model it
  as a rebuilt-on-load UI count, never as progress.
- **VT session helpers.** `FUN_005394E0` (populate), `FUN_0053A4F0` (store), `FUN_0053AA00` (HUD),
  `FUN_0054BC30` (create) and `FUN_0054B3A0` (load) are named by call site only; the `sim%d.dat`
  payload itself is decoded in EV-0144 (§6 of the P2.13 note).

### Q-0025 - P2.12 residual screen-flow questions
- OPEN (2026-10-29, EV-0131-EV-0134). Three loose ends from the menu pass; none blocks the flow
  map:
- **`manager+0x738` owner.** `FUN_0054B360()` removes the object at `[manager+0x738]` from the
  render list `[manager+0x320]`, destroys it through manager vtable slot 0x88 and clears the field;
  it runs before every mode start (EV-0132). No ctor in the corpus writes the field (bounded
  negative over `docs/evidence/*.txt`), and it is **not** the Tank (`manager+0x730`) nor the tank
  screen (`manager+0x82C`, EV-0134). Do not bind it to a class in the remake; treat the teardown as
  "close whatever screen is open".
- **`profile+0x5A` clear.** The level-start funnel clears 24 bytes at `profile+0x5A` before
  `start_level` (EV-0134), while P2.6 §1.5 reads the same array to instantiate pets. Until
  `FUN_0054C540`/`FUN_00541A20`/`FUN_005498B0` are decompiled, the remake must **not** clear the pet
  selection on level start; the array's role is the open point (selected pets vs a per-run copy).
- **`profile+0x18`.** Compared against the second return word of `FUN_0054B2A0()` (Ghidra's
  `extraout_EDX`) in the between-tanks branch (EV-0134). The field is not in `user%d.dat` (the file
  starts at `+0x1C`), so it is runtime state; "current tank < unlocked tanks" is a reading, not
  evidence.
- 2026-10-29 update (P2.12, EV-0136) - two of the three are now narrower:
  - **`profile+0x5A` has a second writer.** The `PetsScreen` ctor `FUN_00527820` clears all 24 bytes
    (`profile[0x5A + i] = 0`, i = 0..0x17) on every open **outside** Virtual Tank; in mode 5 it leaves
    the array alone and instead derives the per-pet owned flag from the tank (it walks `Tank+0x108`,
    keeps type ids `-1000 < 0x18`, sets `PetButtonWidget+0x56` and the screen byte `+0x100+(id-1000)`, and
    counts them into `+0x124`). The array is therefore the **pending pet selection**, cleared both by the
    pet screen and by the level-start funnel - clearing it in both places is faithful.
  - **`manager+0x738`** is still unwritten: nine more screen ctors (`Hatch`, `Help`, `HighScore`,
    `Interlude`, `Pets`, `SimFish`, `SimSetup`, `Story`, `Bonus`) were opened and none writes it (bounded
    negative over `docs/evidence/p2.12-fn-5*.txt`). It does have a **reader**: the BonusScreen click
    handler `FUN_0051E060` sends Continue down the `FUN_00552230()` branch when `[manager+0x738] != 0`,
    i.e. the field means "a side screen is open". The identity of its writer is still open; the teardown
    stays "close whatever is open".
  - `profile+0x18` is still unbound. `PetsScreen` reads it only as `min(profile+0xB4, profile+0x18)`,
    clamped to 4 outside Virtual Tank, which is consistent with "unlocked tanks" but not proof.

### Q-0026 - `profile+0x72..+0x77` role: six backdrop ownership flags (RESOLVED)
- RESOLVED (2026-10-29, EV-0141). Two passes read the same six bytes differently; the store's own code
  settles it for **backdrops**:
- EV-0136 (Virtual Tank setup) had it right: the SimSetupScreen Prev/Next picker writes
  `profile[0x72 + (Tank+0x3E8 - 1)] = 1` when the player views a backdrop, skips entries whose flag is
  0 while cycling, and Sell refuses when exactly one of the six is set - i.e. six **backdrop ownership**
  flags.
- EV-0135's "store pet slots" label was the misreading. Re-decoding the roller `FUN_0052F0D0` past the
  blocks the decompiler dropped as unreachable shows it appends every clear `profile[0x72+i]` (i = 0..5)
  to a `std::vector<int>`, then rolls one of them and calls `FUN_00537230(3, index, 15000)` on the
  store's `+0xB8` sub-object: **kind 3 = backdrop**, 15000 shells. Only when all six are owned does that
  slot fall back to `FUN_0051B260(1,-1,9)`, a random pet - which is where the pet reading came from.
- Pet ownership is elsewhere and stays unambiguous: the 24 flags at `profile+0x00..+0x17`
  (`FUN_00501410`), with the pending selection at `profile+0x5A..+0x71`. The save samples agree - the
  six bytes are `01 00 00 00 00 00` in the real profile (one default backdrop) and all `01` in the
  maxed one.
- Port: model six backdrop-owned booleans, one owned at start; the store offers one random unowned
  backdrop per refresh at 15000. Do not derive pet ownership from these bytes.

### Q-0027 - P2.12 residual dialog questions: two blind writers, one answered field
- OPEN (2026-10-29, EV-0137-EV-0140). The dialog layer is mapped end to end (§11 of the note) and
  P2.12 is closed as a mapping phase; these two stay open without blocking the port:
- **OptionsDialog `+0x18C`.** The dialog only *reads* it (non-zero hides "Back to Main Menu") and no
  writer appears in the OptionsDialog ctor `FUN_005349D0`, its opener (`0x54C66D`, inside
  `FUN_0054C620`) or its click handler `FUN_00535430`. Port the button's visibility as "hidden unless
  something outside the dialog sets it".
- **`manager+0x838..0x83E`.** The ScreenSaverDialog ctor reads six of these seven bytes into its
  checkboxes (`+0x83D` is skipped), and a bounded negative over the decompiled dialog/screen corpus
  (`docs/evidence/p2.12-fn-*.txt`) finds no writer; whether OK persists them anywhere is unknown. Port
  the six as booleans with an unknown producer rather than inventing a settings store.
- **`UserDialog`'s edit box - ANSWERED in EV-0140.** It is the shells **transfer amount** of the
  "TRANSFER SHELLS" mode: digits-only, seeded with `"0"`, captioned "Transfer Amount" and drawn only
  when `+0x174 != 0`, while the plain "WHO ARE YOU?" picker hides it and shows Rename/Delete instead.
  Rename/Delete read the highlighted list row (`FUN_00536990` -> `list->vtable[0x120](out,
  [list+0xD4])`) and open `NewUserDialog(isRename=1)` / a Yes/No confirm. Only the *text* of the
  runtime caption at 0x5E8B74 stays unknown - a note-level bounded negative, not a port blocker.

### Q-0028 - Save lifecycle: the save/delete gate and the no-write flag
- OPEN (2026-10-29, EV-0142). Two small gates around the per-mode tank save are read but not bound:
- **`FUN_00537BF0()`.** `FUN_005497A0` saves the tank only when it returns true; otherwise it deletes
  the same file (`FUN_0047FBC0`). It is also the gate of the OptionsDialog "Back to Main Menu" branch
  (EV-0137). Its body and the field it tests are unread.
- **`[app+0x511]`.** `FUN_0047FBC0` returns 1 without touching disk when this byte is non-zero (a
  "no writes" mode such as the screensaver would use); the writer is unknown.
- Also open: the id-0 branch of the Continue handler `FUN_00533760` deletes the current mode's file
  *before* `[manager]->vtable[0x134](this+0xB4)`; whether that is "consume the resume file" or a
  discarded-session path is unproven. Port the delete/save decision behind one named flag instead of
  guessing which way it flips.

### Q-0029 - P2.13 residual tank-body fields (bounded, non-blocking)
- OPEN (2026-11-01, EV-0144). The tank body is fully ordered and byte-verified, but these fields are
  serialized without a proven writer or consumer. They are carried in the P4 model as named
  `unknown_XX` values; none changes the file order or blocks the remake:
  - **27-dword run:** `+0x448`, `+0x464`, `+0x468`, `+0x474`, `+0x478`, `+0x47C`, `+0x480`, `+0x484`,
    `+0x488`, `+0x490`, `+0x498..+0x4A4`, `+0x4A8`. The late `sim1` values (`+0x468=107`,
    `+0x474=136`, `+0x488=219`) are *consistent with* lifetime spawn/purchase totals, but no writer
    was read; `adv1` has all three at 0, which is equally consistent.
  - **Timers:** `+0x2C4` (set to 35 by the wave-0 block) and `+0x2C8` (set to 36 when hostiles
    clear); consumers unread.
  - **Scalars:** `+0x440` (cleared by the finalizer), `+0x4F0` u32 / `+0x4F4` u8 (no writer or reader
    in the captured corpus), `+0x2AC`/`+0x2B0` (finalizer writes -1/0; meaning unbound).
  - **Overlay tail:** `+0xC8`, `+0xD0`, `+0xD4`, `+0xD8` are serialized by `FUN_00530780` but their
    readers are not located.
  - **`+0x2A6` direction:** the writer/consumers are bound (`FUN_00539AD0`, spawn = 0, wave-clear = 1,
    mode-5 load re-applies the saved byte, `+0x2A7` flushes through it), but which value means
    "enabled" is not proven.
  - **Attractor triples:** `5e89d0/d4/d8` (hidden Wadsworth count + mouth x/y) and `5e89c0/c4/c8`
    (held-pellet/cursor attractor flag + x/y) are written and read, but the exact gameplay effect of
    the held-pellet triple is only observed as "fish pause within 8 px".
  - **`+0x3EC` writer:** only the body's temporary swap/restore reads it; no writer is bound. It is
    correctly absent from the file.
- Bounded negatives: the forward parse of both samples consumes every byte through the timestamp, so
  no hidden field exists between the listed groups; `+0x2E0` and the stream slack after the timestamp
  are runtime-only.
### Q-0030 - P2.14 residual: which gameplay event plays which sound (33 of 65 bound)
- OPEN (2026-11-01, EV-0149). Every `SOUND_*` resource has a named global that holds its allocated
  SoundManager id - all 65 bindings are in `docs/analysis/inputs/p2.14-sound-table.txt` - but the
  *trigger* side is only partly bound: a whole-`.text` scan for `mov reg,[global]` / `push [global]`
  finds direct read sites for 33 of the 65 ids (`p2.14-sound-id-xrefs.txt`, VAs only, containing
  function not resolved).
- What is missing: for each read site, which gameplay event it belongs to. Bounded search used:
  direct absolute-address reads only (`A1`, `8B0D`, `8B15`, `8B1D`, `FF35`); a global reached through
  a register/array copy is not covered.
- Non-blocking: the P4 remake triggers sounds from the events the other P2 notes already describe
  (buy, hatch, death, splash, roar, button click ...), and the resource names are semantic, so an
  event->name mapping can be built without the remaining VAs. Resolve by decompiling the 33 read
  sites' functions when a per-event audit is wanted.

### Q-0031 - P2.14 residual: music parameter wiring, BASS load flags and the backend/pause switches
- OPEN (2026-11-01, EV-0145/EV-0147/EV-0148/EV-0149). Five bounded gaps around otherwise complete
  audio paths:
  - **(a)** `BASS_MusicLoad`'s flags word: the load reads `interface+0x14` (`FUN_00498A00`), which the
    decompile does not resolve to a constant. The play slot always restarts with bit `4`
    (`FUN_00498620(pos, 4 | 0x8200)`), so looping is certain; the *load* flags are not.
  - **(b)** How `FUN_0054B1A0`'s `(a, b)` reach `PlayMusic(track, position, flag)`: the pseudocode
    shows the values stored at `manager+0x88C`/`+0x890` and the interface slot 2 called with no
    visible arguments. The mapping `(a: 0/1/2, b: 0/1/3/5/13/22/32/45/54)` -> `(track, order, flag)`
    is therefore unfixed; P4 starts every track at position 0 (note §8.3), which matches all
    observed level-play calls.
  - **(c)** `DAT_005e28cc`, the gate on the remap `FUN_0054B090` (EV-0148 note 4). Its writer and
    meaning (version/language/mode switch) are unknown; the remap is not ported.
  - **(d)** Writers of `app+0xF0` (null music backend) and `app+0xF1` (prefer FMOD), and of
    `app+0x42C` (the second operand of the derived `Muted` value, EV-0149 note 6).
  - **(e)** The exact `WAVEFORMATEX` fields of `DSoundManager`'s primary buffer: the ctor builds the
    block on the stack and the decompile shows raw dwords only (`0x100004`, `0x14`, `1`, `0`, `0x12`,
    `0`), so sample rate/bit depth of the DirectSound path are not proven. Not needed for P4: Godot
    supplies its own mixer.

### Q-0032 - P2.15 residual: the `framemap` `-1` entry and the time unit of `framedelay`
- OPEN (2026-11-02, EV-0152). Two bounded gaps in an otherwise complete image-entry model:
  - **(a) `-1` in `framemap`.** Only `MERYLBLINK` uses it (`0,1,2,1,0,-1` with
    `perframedelay="3,2,3,1,1,1"` on a 3-cell sheet). It is not a terminator (the parallel delay
    list has six entries) and not a frame index. The animation builder `FUN_004575E0` stores the map
    verbatim and only uses its length, so the decoding has to be in the frame-advance path. The
    reading that fits both the art and the slice model is "hold the previous frame for this step" -
    a dwell on the open-eye pose. P3.5 currently *skips* negative entries, which shortens the blink
    by one step.
  - **(b) `framedelay` unit.** The parser stores it with `atol` into `entry+0xE4` and the value is
    passed on; every shipped value is `2` or `4`. With P2.1's 10 ms logic tick that is 20/40 ms
    (50/25 fps), which is plausible for a swim cycle, but the countdown site that would prove
    "ticks, not milliseconds" is in the animation update (P2.2). P4 starts from `1 unit = one logic tick` (10 ms under the wrapper, 27.8 ms at the ported ~36 Hz).
- What is missing: one trace from the animated-image frame timer to its delay field.
- Non-blocking: both readings are visually safe (one 10 ms step; two candidate frame durations);
  the committed `SpriteFrames` deliberately bake neither delay nor `-1` handling, and the raw
  attributes stay in `assets_raw/extraction.json` so either can be re-applied without re-extracting.

### Q-0033 - P2.15/P3 residual: runtime colourisation of grayscale sheets
- OPEN (2026-11-02, EV-0153; first raised in P3.2). 36 of 246 base images are grayscale-only and the
  `SIM*` fish pair a **black-bodied** base (eyes on black) with a silhouette mask, so the alpha merge
  alone would render them black. The engine must colourise them at runtime (laser tier colours, wave
  tints, fish species colours), and the manifest says nothing about it - there is no `color`/
  `tint` attribute anywhere in `properties\resources.xml`.
- What is missing: the call sites that set a colour on an `Image`/`AnimatedImage` before drawing
  (expected in the drawing layer, P2.2/P2.10 territory, or in `Sexy::Graphics`).
- Non-blocking: P3 keeps base and mask layers separate and P4 composites them; the colour values
  are already in the P2 gameplay notes (fish species colours, laser tiers) even though the exact
  engine mechanism is not traced.

### Q-0034 - Cross-system: the simulation tick rate is 100 Hz in P2.1 but ~36 Hz in P2.7/P2.8/P2.9
- OPEN (2026-11-02, raised while writing `docs/SPECS.md` §1.2; sources EV-0034, EV-0080, EV-0105,
  EV-0114, EV-0117). Two recovered datasets imply different rates for the *same* update tick:
  - **100 Hz.** The `SexyAppBase` ctor writes `10` into the frame-interval field at `0x4a26af`, and
    `FUN_0049F1B4` consumes it as "ms per logic tick" with a 10-iteration catch-up loop (EV-0034).
  - **~36 Hz.** Every gameplay timer is quoted in ticks and calibrated against wiki seconds: Blip's
    instant-unlock test compares level age against `200`/`720` for 5 s/20 s (200/5 = 40, 720/20 =
    36), Prego 930 ≈ 26 s, Meryl 1400 ≈ 39 s, Shrapnel 633..652 ≈ 18 s (EV-0080/EV-0105); the boss
    arrival countdown of 300 ticks is called 8.3 s (EV-0117) and the 3000-tick wave clock 83.3 s
    (EV-0114) - both of which are 36 Hz arithmetic.
  The ratio is 100/36 ≈ 2.78, and the two groups cannot both be read the way their notes read them:
  at 100 Hz the wave clock is 30 s and the boss arrival 3 s (against the 83 s and 8.3 s quoted in
  P2.8/P2.9), while at 36 Hz the wrapper's 10 ms interval is not the tank's update period. Either the
  wrapper ticks at 10 ms while the *tank* update runs every ~2.78th tick (an unwritten gate nobody
  has located), or one of the two calibrations is wrong. Which reading matches the game's observable
  cadence is not established - the wiki has no per-wave timing figure (wiki-refs), so this needs
  measurement, not inference.
- What is missing: the call site that advances the tank update relative to the wrapper's logic tick -
  i.e. a frame counter, a second interval field, or a timer that gates `Tank::Update`. Bounded search
  to run: the tank update's caller chain (`FUN_00547610` upward) for a counter compare against a
  constant, plus a live measurement in the running game (P5.3) of any 3000-tick observable (wave
  arrival) against a stopwatch.
- Non-blocking: every P2 note already stores timers as **integer ticks**, so P4 can be written now
  against a single `TICKS_PER_SECOND` constant and re-tuned once. `docs/SPECS.md` §1.2 is the
  contract: keep the rate parameterised, do not bake seconds anywhere in the simulation.

**Port status (2026-11-04).** The remake adopts the **36 Hz** reading (`Sim.TICK_MS = 1000/36`, the
one place the rate lives). Rationale: six independent wiki-second calibrations (Blip 200/720, Prego
930, Meryl 1400, Shrapnel 633..652, boss arrival 300 = 8.3 s, wave clock 3000 = 83.3 s) and the
pellet tumbler's ten-column row (Q-0051: ten rotations a second at 100 Hz against 3.6 at 36 Hz) all
agree, whereas the 100 Hz reading rests on one ctor constant whose consumer in the tank path is
still unfound. The question stays open for that call site - a frame counter or a second interval that
gates `Tank::Update` - and the ported rate is a single constant to change once it is located.

### Q-0035 - Food: the landed flag comes from Angie's food re-lay (RESOLVED)
- **RESOLVED 2026-11-08 (EV-0159 + EV-0160 + EV-0161).** Nothing writes `+0x190` after construction:
  the flag is the play ctor's `param_4`, and the write sweep cleared `Food::Update`, `Tank::Update`,
  `Tank::DropFood`, the click test, the pellet nudge `FUN_004D6290` (which sets the *homing* flag
  `+0x185`) and the post-ctor list helper. **Exactly one caller passes `flag = 1`**: Angie's food
  re-lay in `FUN_004FE740` (`0x4FF2AA`), which removes an ordinary (kind 0) pellet inside her 30 px box
  and re-drops it landed with the same quality - so that pellet bobs. Click/feed drops pass 0, so
  dropped food falls, crosses the line, arms a 15-tick life and is removed. The remake does both.
  **Sweep complete 2026-11-09 (EV-0166):** the last sites pass 0 as well - `0x4E4DEF` (the
  `+0x229`-gated twin `FUN_004E4C10`) and `Tank::Update`'s own periodic drop at `0x547DFD`, whose
  elided arguments decode from the bytes to kind 0, **flag 0**, quality 20 - and the save path cannot
  produce one either: the body `FUN_00546240` never touches `+0x190`, and the factory's type-`0x1C`
  branch (`FUN_00537570` `case 0x1c`) allocates `0x1A0` bytes and runs the **bare** Food ctor
  `FUN_004EF820` - no `flag` argument at all, unlike `DropFood`'s `FUN_004EF840(x, y, kind, flag, ...)`
  (EV-0169). Nothing is left open in this entry.
- Original entry follows.
- **Bottom branch RESOLVED 2026-11-08 (EV-0159).**
  `FUN_004D62D0` is a void function whose body is `if (this+0x180 < 1) this+0x180 = 0xf`: step 8's
  remaining branch arms a 15-tick life on an ordinary pellet that crossed the line, so it sinks out
  and step 3 removes it. The port implements that and no longer clamps `y` at the line (medium
  confidence on the clamp: the callee writes no return value). `FUN_004F22C0`, the shared per-tick
  helper, was decompiled and does not write `+0x190`, so the landed/bob entry is still unrecovered.
- OPEN (2026-11-02, raised while writing `scripts/entities/food.gd` for P4.3; source P2.3 §1,
  `p2.3-food-4F8AA0.json`).
- `Food::Update` (`FUN_004F8AA0`) step 4 bobs only when `(char)[100]` / `+0x190` is set:

  - `+0x190 == 0 || +0x184 != 0` -> fall `y += 1.5` (or the homing branch when `+0x185` is set);
  - else -> the staged bob (`y >= 150 -> -8`, `135..150 -> -2.5`, `130..135 -> -1.5`,
    `125..130 -> -1.0`, `120..125 -> -0.5`, `y < 120 -> +0x184 = 1`).
- `+0x190` is written only by the ctor from `param_4`, and nothing recovered writes it afterwards, so
  a pellet spawned with `flag = 0` falls forever and never enters the bob; a pellet spawned with
  `flag = 1` starts bobbing from wherever it is. Neither reading matches "it drops, lands, then bobs",
  which is what the game looks like. Either a caller passes `flag` contextually, or the setter lives in
  the shared per-tick helper `FUN_004F22C0` / the tank's food list pass, neither of which was
  decompiled for writes to `+0x190`.
- Second loose end, same function, step 8 - **settled in EV-0159**: `FUN_004D62D0` writes only
  `+0x180` (the lifetime counter) to `0xf` when it is below 1, so the branch is "arm 15 ticks, keep
  sinking, get removed by step 3", not a bounce or a float. The star (410 -> 400 + splash + remove)
  and breeding (`+0x194 == 2` -> remove silently) branches were already decoded.
- The sweep this entry asked for was run in two passes: EV-0160 found no *writer*, and EV-0161 found
  the one caller that passes `flag = 1` (Angie's re-lay at `0x4FF2AA`) by decompiling the call sites.
  Examined: `0x4E4A42` and `0x4E5DC8`/`0x4E5DDB` (both pass 0), `0x4FF2AA` (passes 1), `0x4E4DEF`
  (`FUN_004E4C10`, passes 0 - EV-0166), `0x543DC8` (`FUN_00543920`, passes 0) and `0x547DFD`
  (inside `Tank::Update`; elided in pseudocode, decoded from the bytes as kind 0 / flag 0, EV-0166).
  The `0x543441`/`0x54352E`/`0x5435F2` cluster cited above is
  not in REA's xref list for `FUN_00543280`; the observed sites are `0x4E4A42`, `0x4E4DEF`, `0x4E5DC8`,
  `0x4E5DDB`, `0x4FF2AA`, `0x543DC8`, `0x547DFD`.
- Non-blocking: `scripts/entities/food.gd` implements every decoded branch, enters the bob only for a
  pellet spawned landed, and gives an ordinary pellet the recovered 15-tick bottom life
  (`tests/headless_entity_check.gd` asserts the arming, the continued sink and the removal).
  `docs/SPECS.md` §3.2's wording ("landed pellet bobs on a 120..150-tick cycle") is a y-band reading,
  not a tick cycle, and stays as written.

### Q-0036 - Which coin kind does each species/stage emit?
- OPEN (2026-11-02, raised by `scripts/entities/fish.gd` for P4.3; source P2.4 §6/§7, P2.5 §5).
- `FUN_00544430` takes the coin kind as an argument; the slot-81 call sites in the species update
  bodies decompile with the argument elided, so the stage -> kind assignment is not bound. P2.5 §5
  has the value/kind table and the Virtual Tank multipliers, not the per-species selector.
- What is missing: register/stack inspection at each `FUN_00544430` call site (or the caller's
  `this` type + stage at that point), and a runtime sample of one drop per species/stage.
- Non-blocking: `Fish` emits `coin_due(fish)` and the level/coin system owns the mapping. No value
  or kind is guessed inside the entity.

### Q-0037 - Shared growth tail: the stage-4 overshoot for non-Guppy species is unverified in play
- OPEN (2026-11-02, raised by `scripts/entities/fish.gd` for P4.3; source P2.3 §7.5, P2.4 §1-§3).
- The consume tail is shared: `stage < 2` grows one step, and a second independent `if` promotes
  `stage > 1 && stage != 4` to stage 4 when feed points reach `(virtual ? 8 : 15) * food_needed`.
  Oscar/Ultra/Gekko start at stages 5/6/7 and their species inits leave the food-point threshold at
  the common 4-6, so under a literal reading they could reach 60-90 points and take the stage-4
  branch. No recovered spawn path creates a stage-4 Carnivore/Ultravore/Beetlemuncher, and the
  stage field's meaning for those classes may differ (their stage starts are observed, not a
  progression).
- What is missing: a runtime/write reference that shows whether the overshoot branch is reachable
  for stages > 2 in the original, or whether a class/flag gate suppresses it.
- Non-blocking: `Fish._apply_growth()` implements the decoded tail literally (Q-0037) so the
  Guppy path matches P2.3; non-Guppy stage-4 promotion is treated as an accepted, documented
  divergence until measured.

### Q-0038 - Two food-approach paths and the `+0x229` seek gate
- OPEN (2026-11-02, raised by `scripts/entities/fish.gd` for P4.3; source P2.2 §5.4-§5.5,
  P2.3 §7).
- `Fish::Update`'s food branch (guarded by the pending-object predicate and `+0x229`) steers with
  the same ±5/±10 px acceleration bands that slot 84's approach/eat uses; the independent call
  sites are not fully separated in the recovered body. P4 implements one combined seek+eat path
  instead of double-steering. The `+0x229` value is confirmed 0 only for Ultra (`FUN_004D9EE0`);
  for the other six classes the ctor's value is not yet read, so `can_seek` in the species table is
  an inference from the branch semantics.
- P4 reading: `can_seek` suppresses active steering; a non-seeker still consumes a pellet that
  enters the ~35 px eat window, because the shared update calls the eat virtual. This keeps
  Carnivore/Ultravore/Beetlemuncher functional while avoiding a second steering controller.
- What is missing: per-species `+0x229` ctor values and the slot-84 body's own target search, so the
  "who moves toward the pellet" split can be stated exactly.
- Non-blocking: Guppy/Sylvester/Ball/Bi seek; Oscar/Ultra/Gekko eat opportunistically.

### Q-0039 - The swim target-timer seed: `FUN_00564160`'s float operand is not in the decompile
- OPEN (2026-11-02, raised by `scripts/entities/fish.gd` for P4.3; source EV-0156, P2.2 §5.3).
- Modes 0-4 call `FUN_00564160()` to seed `+0x6F` (the 0..5 target timer). EV-0118 establishes
  `FUN_00564160` as the CRT float->int helper, not an RNG, so the decompiled call shows no modulus;
  the float argument is consumed from the x87 stack and is not rendered. P4 uses `rand % 6` from
  the tank stream as a deterministic placeholder.
- What is missing: the assembly around each call (`FSUB/FMUL` source) or a runtime trace of `+0x6F`
  after a mode entry.
- Non-blocking: the timer only feeds animation/oscillator timing; it does not affect hunger,
  growth, death or the coin counter.

### Q-0040 - Coin internals: four fields and one pairing are not in the decompile
- OPEN (2026-11-03, raised by `scripts/entities/coin.gd` for P4.3; source EV-0047, P2.5 §5).
- `Coin::Update` (`FUN_004F5050`) is recovered step by step, but nothing in the note pins these:
  1. the animation-frame function `f(+0x16C, kind, virtual)` - the timer wraps at 79 and the sheets
     are 8 cells, so P4 uses `timer / 10 % 8` (10 ticks per frame);
  2. the `+0x1C0` base that `FUN_004D53A0` multiplies in Virtual Tank - P4 defaults it to the normal
     value so a Virtual Tank coin is not worth zero;
  3. the kind-0x10 branch (targets y 50 or -50 by `+0x68`, "remove unless rising") - P4 does not
     implement it, so kind 0x10 behaves like an ordinary coin worth 0;
  4. the HUD flight destination `FUN_00538CD0` after Virtual Tank homing - P4 emits `banked` at
     (550, 30) instead of inventing the follow-up path;
  plus the pairing itself: coins are landed at y 370 and then use Food's staged 120..150 rise table,
  which makes a landed coin climb for ~30 ticks before it oscillates in the band. Both facts are
  implemented as written; that they belong to the same branch is unverified.
- What is missing: a read of `FUN_004D5360`'s callers, the `+0x1C0` writer, and the coin draw/anim
  helper (slot 26, `0x4DD7A0`, unanalyzed).
- Non-blocking: values, landing, expiry, collection and the Virtual Tank flight all match the note
  without any of these; only the coin's animation cadence and the special kind stay approximate.

### Q-0041 - The homing body `FUN_004FF4E0` is missing, so a shot starts still
- PARTIALLY ANSWERED (2026-11-07, EV-0158; source EV-0130, P2.10 §5.2-§5.3, P4.10).
- The homing body is now decompiled (`docs/evidence/p2.10-fn-4FF4E0.txt`) and implemented in
  `scripts/entities/projectile.gd`: `+-0.2` steering toward `1.8`, Ultravore wide bands vs
  tight bands, target-loss expiry for kinds 0/1, and the on-target check (`FUN_004FC070`)
  that kills the locked fish (or, when deflected, damages aliens/boss). Aliens now pick the
  farthest fish (`FUN_004E8DF0`) and hold the volley when none is eligible, and `Fish`/`Alien`
  carry the `+0x98` lock that the homing body reads.
- What remains open: the kind-2 (`FALLING`) victim/damage sub-branches name classes the port
  does not spawn here (the port keeps the bounce only), the `FUN_004FC070` `Tank+0xF4` /
  `+0xB4` / `+0xB0` list scans name head/entity lists the port does not model, and the
  type-0 target-picker gate (`FUN_00500FF0`) is unrecovered (treated as always eligible).
  None of these block P4.10's flight/damage path; they are recorded in the note so the next
  reader does not mistake a port simplification for a binary fact.

### Q-0042 - Fish sprite assembly: ids, stage rows and the 40x40 art inside the 80x80 box
- OPEN (2026-11-03, raised by `scripts/tank/level.gd` for P4.4; source P2.2 §5, P3 asset pass).
- The level draws a stage-0 guppy from the three separate images `IMAGE_SIMSWIM1..3` (three cells each,
  `SIMSWIM1..3` are separate files, not one sheet), positions the art at +20/+20 inside the 80x80 bounds
  box and mirrors it with `flip_h`. The consumes (`SIMEAT1..3`) and turns (`SIMTURN1..3`) are not wired
  yet, and the carnivore/boss sprite ids per stage (`OSCAR`, `ULTRA`, `GEKKO`, `SYLV`, `BALLS`,
  `BILATERUS`) have no verified stage -> id/animation table.
- What is missing: the fish draw slot's frame-selection code (P2.2 never decompiled slot 26) or a
  runtime trace of which image id a stage-2 Oscar draws.
- Non-blocking: gameplay does not read sprites; only the visual pick per species/stage is approximate,
  and P4.4 draws guppies only.
- **Update (2026-11-09, EV-0164).** The binding now comes from the binary, not from measuring art.
  Every fish class overrides the sprite draw (slot 83), the guppy's row follows its stage (0/1/2 as
  is, 3 -> 2, 4 -> 3) and the carnivore fixes row 4 at every stage. The body sheet is
  `FUN_004D5AA0`'s pick - SMALLSWIM/HUNGRYSWIM, SMALLEAT/HUNGRYEAT while the eat-fx timer runs or
  the fed countdown is past 100, SMALLTURN/HUNGRYTURN for the turn state - whose ids resolve to those
  images through the runtime table's 16-entry offset. Implemented as `Fish.draw_state()`,
  `Fish.draw_image()` and `Fish.row_for()`, with the level swapping the sheet in place.
- The eye-layer question is answered as well: the `SIM*` sheets are the single-channel layers of the
  colourised style (`+0x1D0`), stacked three at a time (SIMSWIM/SIMEAT/SIMTURN 1..3) and tinted
  white, `+0x1E8`, `+0x1D8`; the carnivore stacks four layers of a 12-row sheet with a third tint at
  `+0x1F8`. **Closed as a bounded negative (EV-0168).** The fields are 4-byte colours handed to the
  same setter as the white and flash colours, but no site in the module stores a colour constant into
  them (the only literal stores are small integers such as `0x0C`/`0x14`), and the runtime palette
  table is empty in the file, so the values are runtime-only. The port does not composite the layered
  path - any colour it used would be invented - and finishing it needs a runtime capture at the draw
  call.
- Still open: the five other classes' draw bodies (Gekko `0x4E17F0`, Ultra `0x4E3A10`, Sylvester
  `0x4E3420`, Ball `0x4DB3B0`, Bi `0x4DB9B0`), which keep the earlier stand-in sheets; the turn sheet,
  because `+0x1C4` is not yet distinguished from a latched facing; and the stage-3 double draw plus the
  hit-flash overlays.

### Q-0043 - The corpse's revive branch has no trigger, and its art/divisor stay approximate
- OPEN (2026-11-03, amended 2026-11-04 after `EV-0053` was re-read for the death pass; source
  EV-0052/EV-0053, P2.4 §4).
- Settled by the amendment: the natural death path is **terminal and silent**. The corpse is inert
  (`FUN_00542EE0(obj, 0)`), its own stage counter `+0x1A0` starts at 125 and drops a step per tick once
  `stage > 0x69` or the sink line is passed (y > 300 for id 6, 365 for ids 8/9, 370 otherwise), and at
  `stage < 1` it detaches with no sound and no successor. The frames come from `+0x1A4` (the dying
  fish's stage) and the falling counter, and the drift subtracted from the fish's vy is 1.0 when the
  spawn y is below 115 or vy is already below -3.0, else 2.0. The port now reproduces all of that; the
  earlier reading - successor after the sink - was the other branch and is gone.
- Settled since: the writer is **Angie** (Q-0009, EV-0099). `FUN_004D5630` sets a corpse's `+0x190`
  from 100 to 10 on contact, after which the corpse counts 10..1 while its revive cells play and at 0
  runs the branch (detach + live successor by `+0x1A4` through the 5/6/7/8/9/10-12 table). The port
  has both halves: `DeadFish.reviving` countdown and `Pet._angie_revive()` with the recovered target
  (`+0x1A0 > 0x5F`) and contact ranges (30 px, 60 for id 6), covered by `headless_pet_check`.
- Also unbound: the corpse's death-sound id `0x125` has no `SOUND_*` name binding (Q-0030), the exact
  cell the 1..10 counter maps to (the port uses `phase - 1`, descending, inside the row), and the
  sheet the rule indexes (drawn from `SMALLDIE`, row = the dying stage). Angie's own steering speed is
  the unrecovered `FishTypePet` default, so she revives only what drifts into reach (Q-0044); the
  corpse's speed divisor stays the 0.8 shared with the fish family.
- Non-blocking: the sink, the drift, the per-tick counter, the frames rule, the silent removal, the
  Angie handoff and the ten-tick revive are all reproduced; only the art mapping and Angie's movement
  stay approximate/absent.

### Q-0044 - 18 of the 24 pet bodies, and their speeds, are not written yet
- OPEN (2026-11-03, raised by `scripts/entities/pet.gd` for P4.7; source EV-0077..EV-0100, P2.7).
- The roster, the family split and the gate order are recovered, and six slot-81 bodies are ported
  (Stinky, Niko, Vert, Shrapnel, Nostradamus, Angie). Everything else idles: `DEFS` carries `speed = 0` and
  `period = 0` for pets whose tuning or period the note does not pin, rather than plausible-looking
  values.
- Recovered periods still without a body (Prego 930, Zorf 65, Meryl 1400, Amp 3000, Gash 1570,
  Stanley 100) are recorded in `DEFS` but nothing acts on them. Nostradamus' "Sneeze of Power" and
  clone behaviour stay unimplemented (EV-0106 recovered only the snot timer).
- Rendering: every pet draws from its own `IMAGE_<NAME>` sheet (80x80 cells) and the sheet's own
  `loop`/`pingpong`/`framedelay` metadata via `AnimState`; the pet entity does not pick a column, so a
  per-pet animation state (Stinky's shell frames, Niko's open/closed) is not modelled yet.
- Left out of Vert/Shrapnel on purpose: Vert's `FUN_004D70B0` Virtual Tank branch (it reads the
  avatar-screen state the port does not model) and Shrapnel's `+0x258` pre-drop flash (no recovered
  tick length) and `0x143` sound (no `SOUND_*` name, Q-0030).
- What is missing: each pet's slot-81/slot-84/86 body and its ctor tuning (speed, fixed-y, box),
  Presto's transform, Walter's glove entity, and the cleanup hooks (hidden Wadsworth, Meryl song flag).
- Non-blocking: the base, the gates and two pets are faithful; the remaining bodies are additive.

### Q-0045 - Alien wander target, bottom lane and two hp cells are not pinned
- OPEN (2026-11-03, raised by `scripts/entities/alien.gd` for P4.8; source P2.8 §3/§11, EV-0124).
- Recovered and implemented: hp/speed per kind, the full/mini bands, 0.1 steering with the
  20-tick/10 % re-roll, the 7-tick ±3 intro, the attack timers, the reach boxes and the death rule.
- Not in the note: how the "quadrant wander" picks its target (P4 uses a random point inside the
  band), the bottom lane's y for kinds 5/6 (P4 uses the band's lower quarter), Bilaterus' own hp (its
  two heads are 100 each; `DEFS` carries 0), Cyrax's profile-scaled hp (P4 uses the maximum 5000) and
  the `balls_2` period (P4 reuses the 75 + rand%50+150 shape).
- Non-blocking: movement, attacks as spawn requests, eating and death are faithful; only the wander
  flavour and those four cells are approximate.

### Q-0046 - Alien click box is a placeholder; composites and the wave schedule are now wired
- OPEN for the click box only (2026-11-03, raised by `scripts/tank/level.gd` for P4.8; source P2.8 §11, P2.10 §6.1).
- The level shoots whatever alien is under an 80x80 box at its position. P2.10 has no per-kind hit box
  in the recovered code (the click handler tests the object's own `HitTest`), so the box is a port
  choice, flagged here rather than presented as recovered.
- Composite selections 9..0xC are now composed by `Level._on_wave_spawn`: 1+3, 7+3, 5+6 and 3+8, at
  the one rolled point. `start_level` arms P2.6 §8's per-level type (tank 1 level 2 at 1750 ticks)
  and `WaveClock.wave_spawned` re-rolls it per P2.8 §5.1 after each wave.


**Sheet row layout (2026-11-04, measured).** Row extents were measured per sheet (opaque bounding box
of the first column), to see whether "row = growth stage" holds everywhere it is needed:

| sheet | rows | bbox per row | reading |
|---|---|---|---|
| `smallswim` / `hungryswim` | 5 | 32, 48, 65, 67, 71 px | **rows grow: stages** - the guppy body |
| `breeder` | 9 | 43, 45, 45, 53, 57, 57, 68, 71, 71 | three sizes x three variants, not nine stages |
| `gekko` | 7 | 66..69 px throughout | not growth; rows are poses/directions |
| `bilaterus` | 8 | 48, 48, 47, 65, 65, 66, 32, 32 | mixed, not growth |
| `ultravore` | 4 | 148..146 px | not growth |
| `balls` | 4 | 28, 46, 38, 38 | not growth |

So `row = stage` is only proven for the guppy body sheets. Wiring Oscar, Gekko, Ultra or the balls to
their sheets would need the actual row meaning, which is not recovered; they keep their old images.
`HUNGRYSWIM` is structurally the starving twin of `SMALLSWIM` (same five stage rows, same extents), but
`Fish` has no starving state to switch on, so the port never selects it yet.

**Update (2026-11-04, measured).** The sheets were measured directly rather than guessed at:

- `smallswim.png` / `hungryswim.png` are 800x400 = 5 rows of ten 80x80 cells - **rows are growth stages**,
  columns are animation frames. This is the body layer, and the port now draws row `stage` of
  `smallswim.png` for a guppy (`Level.BODY_IMAGE`).
- `guppy_swim1..3.png` are 800x240 = 3 rows of ten cells and contain **eyes only** (about 98% of each
  cell is the black colour key; the surviving pixels are the eye). So `SIMSWIM1..3` are eye layers, not
  fish sprites, which is why drawing them alone produced floating eyes.
- Which eye cell belongs on which body was tested by comparing bright-pixel centroids per cell. For
  stages 0-3 the closest cell is sheet 3 (2-5 px off, shifting by row); sheet 2 sits 10-18 px to the
  right, sheet 1 7-21 px to the left. **No cell matches exactly**, and every candidate lands a few
  pixels away from the eye already painted in the body art, so overlaying one would draw a second,
  slightly offset eye. The layers are therefore *not* composited: a guppy draws its body only, and the
  remaining question is the eye-offset rule (or whether these sheets are a blink/expression set keyed by
  something not yet identified) - not something to fake.

### Q-0047 - the boss fight's three gaps

RESOLVED (2026-11-07, EV-0117/EV-0118/EV-0119). P2.9 §§4/8/10 name the content the earlier
placeholder text called unnamed:

- the **minion** is a kind-0x14 Minisylvester at the boss position +40,+40 every 75 ticks
  (`FUN_00545580`), spawned by `Level._on_boss_minion`;
- the **pulse** is `type = rand%6 + 4` (4..9) every 300 ticks while `Tank+0xB8` and
  `Tank+0xF4` are empty, at `x 20..469, y 105..299`, routed through the wave spawner
  (`FUN_005475B0`), spawned by `Level._on_boss_pulse`;
- the **HP bar** is a draw rule, not a simulation rule (the boss bar is always drawn; other
  aliens only when the tank's flag is set and the tank is not 5). It is implemented; Q-0058
  records the missing flag writer and the remake's default.

`Level.start_level` reads Cyrax's hp counter from `Profile.cyrax_attempts`
(`profile+0x54`) when no explicit counter is given, death wipes the field
(`FUN_004F9950`), and a >1000-damage kill with no minions left bumps `profile+0x54`
(Q-0022 keeps the loss/retry vs defeat naming open). The pulse gate also checks the
projectile list, and `_on_boss_died` excludes the dying boss from the minion count.

`tests/headless_boss_check.gd` covers the recovered parts (46 assertions).

### Q-0048 - not assigned

No decision or question record uses this id: the ledger runs from Q-0047 to Q-0049. IDs are
append-only and are never renumbered (AGENTS.md hard rule 3), so the gap is retained rather than
filled retroactively.

### Q-0049 - the store items without an effect

`scripts/economy/store.gd` carries all twelve recovered item ids, but five cannot be honoured yet, so `Level.buy_item` refuses them instead of charging for nothing: the **breeder**, the **three pet purchases** (only Stinky and Niko have bodies), and the **egg piece / random pet / end-level row** (needs P4.6 progression and the `manager+0x87C` latch). Prices come from the wiki figures of EV-0060 because the binary's own price arrays were never located (P2.5 §3), and mode-4 inflation (`+0x374`) is not applied. The **star potion** was implemented after this entry was written: the purchase arms `Level.star_potion_armed` (`Tank+0x440`), the next manual drop is a quality-3 pellet, and `Fish` already applies the quality-3 rules.

### Q-0050 - the menu screens that are not built yet

`scripts/ui/game_selector.gd` carries EV-0131's dispatch: ids 1/2/8/9 pick a mode (with the tank-2
and adventure-finished gates returning "Not Yet!" and changing nothing), 4 quits, and 3/6/7 are
recognised but only report "not ported yet". The **options dialog (id 3), the hall of fame (id 6)
and help (id 7)** have no screen: P2.12 names the buttons and the gates, but the contents of those
three screens (option rows, defaults, hall layout, help pages) were never recovered, so nothing is
drawn for them rather than invented. `Main` mounts the selector before the level, so
the menu is the entry point and its choice reaches `Level.game_mode`.

`tests/headless_menu_check.gd` covers the dispatch and both gates (21 assertions).

### Q-0051 - the pellet animation: which sheet row a pellet draws, and what the frame unit really is

`Food::Update` (`FUN_004F8AA0`, P2.3 §1 step 2) advances `[0x5E]` every tick and wraps it at
`[0x5F] * 10 - 1`, where `[0x5F] = (rand & 1) + 3`, i.e. 30 or 40. The extracted `FOOD` sheet is
10x5 and its five rows are *food kinds*, not animation phases: row 0 brown pellets, 1 green
capsules, 2 red/white pills, 3 green flasks, 4 yellow droplets. Each row's ten columns are one
rotation of a tumbler.

Two things therefore stay open:

- **Row binding.** The draw code that turns a pellet's quality `+0x188` / variant `+0x194` into a
  row was not decompiled. The port follows the sheet's own order instead - row 0 brown (quality 0),
  1 green, 2 red, 3 the star-potion flask, 4 the breeding droplet (`Level._food_row`) - which is an
  inference from the art plus the recovered quality values (3 = star potion, variant 2 = breeding
  pellet), not a traced constant. Row 0 for a plain drop and row 3 for a potion are the two the port
  can actually produce today; the green/red rows are only reachable through other droppers.
- **Frame unit.** With the wrap at `cycle * 10` and ten columns per row, the only reading that uses
  the whole row is one tick per column, looping the ten-frame tumbler `cycle` times - a held frame
  of ten ticks would show just three columns. That fixes the counter's meaning but makes the
  tumbler run at the wrapper's 100 Hz, i.e. ten rotations a second. At the ~36 Hz gameplay rate the
  P2.7/P2.8/P2.9 timers imply (Q-0034) it is 3.6/s, which is what the pellet should look like.

So the pellet tumbler is an independent argument for the 36 Hz reading of Q-0034, and an easy one
to settle by eye: at 100 Hz the pellet blurs, at 36 Hz it spins at a readable rate. The port runs the 36 Hz reading (Q-0034's port decision) and draws `anim_frame % 10` inside row 0 (`Level._food_frame`).

`tests/headless_level_check.gd` pins the column arithmetic (frames 25 -> 5, 29 -> 9).

### Q-0052 - the store screen: geometry is recovered, the stock roller and the item art binding are not

`FUN_0052B2D0` (EV-0133) hands us the door, the eight shelf rects, the price line's offsets and the
Shell counter widget; `FUN_0052FEA0`/`FUN_0052F0D0` (EV-0135) is the stock roller and it is **not**
ported. So the screen draws what the level already owns: the `tank_store` rows the save is shaped
around, one row per shelf, with the recovered price line, greyed prices when the purse is short and
"Sold out" for every row whose effect has no body yet (Q-0049 stands: those refuse without charging).

Still unrecovered, and therefore not drawn:

- the stock roller itself (what each shelf offers, the one-off unlocks at `profile+0x90`/`+0x94`/
  `DAT_005e89dc`, the coin flips), so the level's own row table decides the stock;
- the widget's kind byte `+0x14C` and its five drawing branches, so per-item art is not drawn. The
  kind table itself **is** recovered: 0 sold out, 1 a pet/egg (the slot hosts the prize object and
  forwards to it), 2 the Bubbulator icon, 3 a backdrop scaled by `+0x158`, 4 the alien-attractor icon,
  5 the food-upgrade digit; `FUN_00537230(kind, id, price)`, `FUN_00537290` (kind 1) and
  `FUN_005372F0` (kind 0) write it. What is missing is the *port's* stock on those kinds: the original
  sells pets, the Bubbulator, backdrops, the alien attractor and food upgrades, while the port's
  `Store.ITEMS` is the P2.5 buy hub's twelve item ids, so no row can carry a kind until the roller
  runs;
- the tooltip table (`FUN_0051B9E0`) is recovered text but keyed by that same kind byte;
- the refresh timer `+0x1CC` and the three paging arrows, and the store's own close control.

The price line's three states are now the recovered ones: `"%d"` of the price (`FUN_00536350`),
the four-character literal `SOLD` for an unavailable row (`FUN_005372F0`), and `?` for an item whose
figure the table never recovered. A 0 in `Store.ITEMS` is that marker rather than a free price, so
`Store.price_known(row)` refuses the sale.

Port-only decisions: the shop opens with `S` and closes with Escape (the original's tank-screen store
button is not reconstructed), the item's name is drawn above the price line at the widget's `y + 84`
(the original shows names in the tooltip), the Shell count sits on the art's bottom plate because the
counter's ctor rect (250,155,150,255) is a label layout box rather than that plate, and the
"Thanks for shopping at the Fish Emporium!" blurb - whose `+0xBA0` period is unrecovered - stays up
for two seconds.

`tests/headless_store_ui_check.gd` pins the shelf rects, the price offsets, the row states and the
three price-line states (40 assertions).
### Q-0053 - progression: the tables and the completion path are in, the screens around them are not

P2.6 is the one phase note that reads like an implementation spec, so its tables went in whole:
`scripts/progression/progression.gd` carries §3's per-tank store table (item, store slot, price, the
level-1/2 hiding lists), the egg price per tank and level with Challenge's flat 5000/15000/25000 and
Time Trial's 100, the tank-5 free egg at slot 6, §5's award formula, §10.4's advance and the 24-name
pet table with card 999. `scripts/persistence/profile.gd` carries the profile fields the rest of the
port already needed (tank/level, Shells, owned/selected bytes, Challenge unlocks, the Bonus Adventure
flag, the session counter) and `Game.profile` is the live instance.

What that buys today: `Level.start_level(tank, level)` stocks the shop from the tank's own table, sets
the egg counter and price, and `Level.buy_egg()` completes the level on the fourth piece (tank 5: the
first). Completion grants the awarded pet, pays Presto's 5000 Shells, advances the profile - into the
level-6 sentinel on a level-5 win - and emits `level_completed`, which `Main` uses to start the next
level. A start on the sentinel resolves to the next tank's level 1. The tank's egg widget is in
(`scripts/ui/egg_widget.gd`): the recovered `EggPieces` art and a click call `buy_egg()` on tanks 1-4
(tank 5 keeps its free store row); its rect is port-placed because the original's was not recovered.

Still missing, in dependency order:

- the bonus rounds: the 160-frame wait, `FUN_00537F40`'s start, the timer, the payout switch and the
  BonusScreen. `Progression.resolve_start` therefore walks the sentinel immediately, which is a port
  shortcut, not the original sequence;
- the Hatch and Pets screens (`FUN_0054BE80`, `FUN_005289F0`): the award is recorded and the pet is
  owned, but nothing shows the card, and pet selection is not written back;
- the score records (`FUN_00514510`, `FUN_005144C0`), `Tank+0x3FC` elapsed seconds, the coin sweep at
  completion, and the challenge record's storage in the profile;
- the credits, story and trophy screens (Q-0013/Q-0016 still open, so no trigger is invented).

Port decisions recorded here: the per-tank store table replaces the id-order stock the shop used
before, so tank 1 level 1 now shows a single shelf (the guppy) exactly as §3 says, and the level's
`tank_store` rows carry the table's `shelf` field for ordering; a row whose 0 is a recovered price
(tank 5's egg) is marked `free` so `Store.price_known` sells it, while every other 0 still means
"figure not recovered" and refuses.

`tests/headless_progression_check.gd` pins the tables, the award map, the advance transitions, the
profile's clamps and both completion paths (79 assertions).

**2026-11-10 update (R3 + hatch art).** The early paragraphs are history. The egg no longer sits
bottom-right on tanks 1-4: `EggWidget` draws the `EGGPIECES` cell in the seventh `MENUBAR` dome
(`StoreBar.slot_rect(6)`) on every tank, over the same purple price plate, and tank 5's free row
keeps that dome with its text blanked (`FREE` comes from the widget) - EV-0172. The dome placement
is still port-only because the original widget rect is not recovered. Hatch, Pets and Bonus all
mount; `HatchScreen` now draws the `HATCHSCREEN` incubator, the `HATCHANIMATION` strip and the pet
cell (EV-0175), while Pets and Bonus remain text-only. The progression suite is now 86 assertions.
### Q-0054 - the in-tank store bar: geometry recovered, slot 7's x and the item art are not

`FUN_005409B0` (EV-0150, `docs/evidence/p2.13-decompile-5409B0.txt`) is the tank's item-cache builder:
it resolves the row's store slot (`Tank+0x2E4[item]`, negative = not for sale), returns the cached
widget at `Tank+0x404 + slot*4` if one exists, and otherwise builds a `StoreButtonWidget` at
`Rect(x[slot], 3, 60, 58)`. The x table is the seven constants pushed before the call:
`0x12, 0x57, 0x90, 0xD9, 0x122, 0x16B, 0x1B4` - 18, 87, 144, 217, 290, 363, 436 in the 640-wide tank.
That is what `scripts/ui/store_bar.gd` draws, using the same row -> slot mapping (`shelf`) the
progression table carries and the same `SOLD` / price / grey rules as the StoreScreen (Q-0052).

Unrecovered, therefore recorded rather than guessed:

- **slot 7's x**: the decompile pushes the eighth element of the table from the stack (`local_3c[7] =
  &iStack_68`), so no constant for it exists in the evidence. The port draws nothing on that slot and
  `slot_rect(7)` answers an empty rect; a byte dump around 0x5409F0 would fill it in one line.
- **the per-kind widget art** (`+0x14C`, Q-0052): the buttons show the item's name and price instead
  of the fish/upgrade icons, because the item ids the port sells are the P2.5 buy hub's while the art
  is keyed by the store kind the roller sets.
- the tooltips, keyed by the same kind byte, and the widget's pressed state.

**2026-11-09 update (R4):** the bar now draws the game's own **`MENUBAR`** art (640x75, EV-0171):
seven item domes with purple price plates, the MENU button and the green `$` wallet plate. The seven
recovered x values sit exactly 7 px inside the art's plates, which confirms the rects are the bar
slots. The wallet number is drawn on the green plate, and the HUD line below carries only the counts
the art does not. An **unstocked** slot now stays empty: `FUN_005409B0` returns null when the item's
store slot is negative, so the original builds no widget there. `SOLD` belongs to the StoreScreen's
sold-out branch (EV-0135), not to an empty tank slot; the earlier port text was wrong on that point.

Port decisions: the bar is a `CanvasLayer` Control over the tank rather than tank-space widgets, the
item name in the dome is port text (the original draws only the icon and the price), and the
`MENUBAR` MENU control is baked art with no handler yet (no in-level menu screen is ported).
`Level.buy_item` is the single purchase path for both the bar and the StoreScreen.

`tests/headless_store_ui_check.gd` pins the slot rects, the `MENUBAR` binding and wallet plate, the
empty dome (no `SOLD`), the row -> slot mapping, the empty slot 7 and a bar purchase (40 assertions).
`headless_integration_check` pins the assembled bar's background, wallet text and empty dome.
### Q-0055 - the menu mermaid's tail: the sprite and its mask are recovered, its placement is not

`resources.xml` gives the menu mermaid a tail of her own: `MERYLTAIL` (`tailflop.png`, 8 cells of
238x165, `anim: once`, `framemap="7,6,5,4,3,2,1,0"`, `framedelay=2`, `begindelay=3`). The backdrop
art (`selectorback.png`) also carries a mermaid with a tail - and that baked tail is a pale, flat
shape that reads as unfinished, which is what "the tail isn't proper" was looking at.

`MERYLTAIL` has no transparency (P3.3: 243 of 246 base GIFs are opaque and a grayscale mask companion
supplies the alpha). `masks/tailflop_.png` is that companion: white is the tail, black is clear.
`scripts/data/mask_alpha.gd` composes it onto the base sheet - the general mechanism for any masked
sheet drawn on a coloured field.

**2026-11-09 update (R10): the overlay was removed.** The owner's windowed menu check saw a green
strap across the baked tail, because the sheet was drawn without its mask (its field is opaque
green) and with the wrong cell.

**2026-11-10 update (owner review): the overlay is back, masked.** The owner read the baked-only
mermaid as unfinished - the backdrop's pale flat tail is the shape that "isn't proper". With
`MaskAlpha` composing `masks/tailflop_.png`, the sprite is transparent where it should be, and a
windowed fit places cell 0 (the flop's last cell, so it doubles as the idle pose) at (120, 268)
with `flip_h = true`: mirrored, its dark silhouette wraps the pale baked tail and the mermaid reads
as one tail (`shot_menu.png`). The recovered playback is unchanged and now covered
(`headless_menu_check` 28): `anim="once"`, `framemap="7,6,5,4,3,2,1,0"`, `framedelay="2"`,
`begindelay="3"` on the 36 Hz clock, then the rest cell. Q-0055 stays open as a missing **exact**
screen rect - the offset and the mirror are a port fit, not recovered bytes.

Still not drawn for the same missing-placement reason: `MERYLLIPS`/`MERYLBLINK` overlays - the
baked art already has her mouth and eyes, and the blink is a `once` animation with its own trigger.

General note for the asset layer: any *other* sprite drawn straight from a masked sheet is a solid
rectangle until it goes through `MaskAlpha.apply`. The fish sheets avoid it because their base art is
on black and `sprite_key.gd` keys that; masked sheets on a coloured field (this tail was on green)
need the mask.

`tests/headless_menu_check.gd` covers the selector dispatch (ids, gates and labels; 21 assertions).
The tail's cell/offset/flop assertions were removed with the overlay (R10).
### Q-0056 - audio: which track a `SetMusic` pair names, the battle loop, and the default volumes

P4.13 ports the *mechanism* of P2.14 but three parts of it are not recovered, so they are recorded
here rather than guessed:

- **pair -> file.** `SetMusic(a, b)` (`FUN_0054B1A0`) stores both numbers and calls the music
  interface's play slot; all 21 call sites, the per-stage selector and the optional remap are
  recovered (EV-0148), but nothing in the binary says which of the three loaded modules a pair
  resolves to. The port plays `Insaniq2` (id 4) for every recovered pair: §4.2's remap rewrites
  **every** pair to `a = 4`, and the `SexyApp::Init` site - the state the main theme plays in - is
  `(2, 45)`, the same pair stage 4 asks for. `tests/headless_audio_check.gd` pins that choice
  (`TRACK_MAIN`) so a later correction is one constant.
- **the battle loop has no trigger.** `Alien` (10 s) is unmistakably battle music, but no recovered
  call site ties a `SetMusic` to a wave, an alien's arrival or the boss; the 21 sites are the
  startup, the stage selector, level complete and screens. The port therefore loads it (as
  `SexyApp::Init` does) and never plays it. Wiring it to "a wave started" would be an invented
  mapping - Q-0030/Q-0031b stay open on it.
- **event -> sound.** Two triggers are grounded and wired: `SOUND_BUTTONCLICK` (14 UI read sites,
  and the Init-phase click sound every screen's handler uses) and `SOUND_BUY` (the read at
  `0x520836`, next to the money subtraction). The rest of the 65 ids wait on Q-0030; the per-event
  `FUN_00538230(0x1NN, ...)` calls in the entity notes name **numeric ids**, and no recovered
  mapping turns those numbers into `SOUND_*` names, so wiring them by name would be a guess.
- **default volumes.** The config keys are `MusicVolume`/`SfxVolume` as integer percent; the shipped
  default is not in evidence. **Temporary port choice (2026-11-09):** both start at **0.0 (muted)**
  because the owner asked for silence during review. This is not a recovered value: the Options
  sliders seed from the mixer (so they show 0) and are the only place that raises it; applying a
  value is already instant because it writes the bus. Restore a non-zero default only with a
  recovered config value or an owner decision.
- **voice count.** Only the *slots* are capped at 256 (the original's table of loaded sound ids);
  playback allocates a voice per call with no cap, which is what `DSoundInstance` per play does.
  `"Out of free sound ids"` is emitted for a new id when all 256 slots are taken, matching
  `FUN_00419320`'s failure path.
- **`.ogg` transcode caveat.** Several shipped `.ogg` files carry a non-conforming Vorbis comment
  (`"Sonic Foundry Ogg Vorbis 1.0 Final"`, no `=`), so Godot logs a warning per file as the
  LoadingThread phase loads it. They decode and play; the files are P3.6's 1:1 copies and are not
  rewritten.
### Q-0057 - sprite playback: what the resource data recovers, and the two sheets it does not

"Animation is not proper" had three causes, only one of which was a missing feature:

1. **A frozen-frame bug.** `SpriteKey.keyed()` cached keyed frames on `Texture2D.get_rid()`, and an
   `AtlasTexture` answers with its **atlas's** RID - so the first cell keyed for a sheet was returned
   for every cell of that sheet. Every fish, pellet and coin drew cell 0 forever; the earlier
   `AnimatedSprite2D` clock was advancing through frames that all looked identical. The cache key now
   carries the atlas region (`atlas rid | x,y,w,h`), pinned by `tests/headless_anim_check.gd`.
2. **One global clock.** Every sprite was an `AnimatedSprite2D` started together at a hardcoded 10 fps,
   which ignored the recovered metadata (`anim`, `framedelay`, `perframedelay`, `begindelay`,
   `enddelay`, framemap order - P2.15 §8.5) and had no pingpong or one-shot. `scripts/data/anim_state.gd`
   now computes the playback position from the logic tick and that metadata, starting at the tick its
   entity spawned.
3. **An invented presentation rule.** The level scaled `speed_scale` with a fish's displacement
   ("presentation only"), so a darting fish animated up to 2x faster. Removed: the original advances
   the frame column from the entity's own counter (`+0x1C0`), not from velocity.

Still **not recovered**, and therefore port defaults:

- **which slot advances the column** for entity-driven sheets. `+0x1C0` is the frame column and P2.2
  names slots 81 (`0x4F1400`, called when `FUN_004da780() == 0`) and 89 (`0x4DE840`, every Update tail)
  as candidates, without proving either. The cadence is therefore `anim_state.gd`'s
  `SHEET_FRAME_TICKS = 5` (20 fps at the 100 Hz tick). It applies to the sheets that declare no
  `anim`: the fish body (`SMALLSWIM`/`HUNGRYSWIM`), `SIMSWIM1..3`, `FOOD` and `MONEY`.
- ~~**the coin sheet's row.**~~ **Recovered (EV-0162/EV-0163, 2026-11-08).** The draw (slot 26,
  `FUN_004DD7A0`) picks the image *and* the sheet row per `kind`: `MONEY` rows 0..4 in a normal tank,
  the 4-row `SHELLS` sheet in the Virtual Tank, `MONEYBAG` for the 2000-value kinds there, and the
  single-cell `PEARL` for kinds 0x06/0x0D (plus 0x0F behind its `+0x198` gate). `Coin.sprite_image()`
  and `Coin.sprite_row()` carry the binding and `_draw_entity_frame` draws
  `row * sheet_columns + column` - the blit's own `(column, row)` cell maths. Still open and recorded
  in EV-0162, not modelled: the coin's own column rule (`+0x174` vs this clock, Q-0040 item 1) and the
  0x0F gate. The special kinds were split on 2026-11-09 (EV-0167): **0x11 draws the single-cell
  `MISCITEMS` plus the `SPARKS` overlay at (10,-10)**, and **0x12 draws its recovered `PEANUT`**
  (EV-0170) - the binding is followed even though the shipped `PEANUT` resource is the blank 107x34
  placeholder (P3.3), so the snot is intentionally invisible rather than drawn as a coin. `0x10`
  still draws the fallback because its `+0x1A0` colour ramp is unrecovered (Q-0040). The Virtual Tank
  branch for these three is unverified (EV-0162's virtual switch covers only 0x01..0x0E), so that
  mode keeps the fallback.
  **Open art question:** the `MONEY` row-3 cells ship on an opaque blue plate and `SpriteKey` only
  clears border-connected black, so the diamond now draws with that plate behind it. Nobody has
  recovered a second colorkey, so the port does not key one - this is a visible fidelity gap, not a
  presentation choice.
- **the fish body's row** is the growth stage (0..4), which the art supports and P2.2 §Render notes.
- **the food pellet** keeps the simulation's `anim_frame` (one column per tick, wrapped at
  `anim_cycle * 10 - 1`), which its note states outright - that one is recovered, so it is not on
  this clock.

The menu mermaid's tail plays its recovered one-shot flop when the menu opens and returns to the
rest pose; Q-0055 records the port-placed offset/mirror and why the return is a port choice rather
than holding the last cell.

### Q-0058 - `Tank+0x178` has no located writer, so the remake shows alien HP bars by default

P2.9 §5 recovers the HP bar down to the draw instruction: `IMAGE_HEALTHBAR` clipped to
`round(127 * hp / hp0)` under the full `IMAGE_HEALTHBARTUBE` glass, at x 10 and y box height - 3;
Cyrax (kind 0x15) always draws it, ordinary aliens only when `Tank+0x178` is set and the tank index
is not 5. The flag's writer was never located (bounded negative, EV-0118), so the remake adds
`Tank.show_alien_health` (default `true`) instead of leaving ordinary aliens barless, and keeps the
tank-5 suppression. If the writer is found, drive the flag from that path and drop the default.

`Level` builds the bar once per alien (`_make_health_bar`) and re-cuts the fill every frame from
`hp / initial_hp()`; `Alien.initial_hp()` is the spawn copy (`+0x1F8`, 0 for Bilaterus, so no bar),
and `Boss.initial_hp()` returns the profile-scaled maximum. The glass is drawn over the fill so the
red empties from the right; the recovered call order in the note (`0x455E40` then `0x455D20`) is kept
in the note, while the port's layer order is a presentation choice.

### Q-0059 - UI fonts: the globals map cleanly, the selector's 17/10 split is an inference

EV-0157 maps every font global of `FUN_0050E190`/`FUN_00506EA0` to its manifest id, so the store's
Shell counter (`DAT_005e8CE4`) is `FONT_CONTINUUMBOLD12` and the two notifier strings are
`FONT_JUNGLEFEVER12OUTLINE`. `scripts/ui/ui_font.gd` applies those fonts at the manifest's native
pixel size to every UI surface (menu, store, in-tank bar, egg widget, HUD); the outline fonts keep
their baked outline and no engine outline is added. The HUD, in-tank bar and egg widget fonts are port
choices because P2.12 does not bind a font to them (Q-0054/Q-0053).

Open: `GameSelector` preloads font ids `0x61`/`0x62`, and the decompile does not say which id is the
10 px outline and which the 17 px. The port assigns 17 px to the art-sized slots and 10 px to the
small text buttons; swapping them is a two-constant change (`UiFont.SELECTOR_BIG_FONT`/
`SELECTOR_SMALL_FONT`). The menu tail still plays on the 36 Hz tick clock (Q-0034) as integer tick
counts; only the erroneous "20 ms/30 ms" comment was corrected, not the recovered delays.

### Q-0060 - the Hatch card's crack timing is the port's clock choice

`HATCHANIMATION` ships three 57x60 cells but no `anim`/`framedelay` metadata in its manifest entry,
so the original hatch screen's per-cell hold and pet-reveal point were not recovered. The port
holds each cell for 0.3 s and shows the pet after 0.9 s (`HatchScreen.CRACK_SECONDS`,
`crack_frame()`, `hatched()`); the windowed captures are `shot_tank5_award.png` /
`shot_tank5_hatched.png`. Everything else on the screen is recovered art (`HATCHSCREEN` 640x480;
the id-99 plate at (186,445,264,30), id-100 at (525,4,80,26)) with the "Please Wait..." and "Menu"
labels. The strip and the pet cell are `MaskAlpha`-composited (`masks/_HatchANIMATION.png`,
`masks/_<pet>.png`) because their PNG fields are opaque colours, and the composition is cropped per
cell so the 800x240 pet sheets are never walked whole. Pets and Bonus remain text-only (Q-0053).
Open: the real per-cell hold and the pet reveal point.

### Completion-pass updates (2026-11-08; implementation only, no new binary evidence)

- **Q-0036 (coin kind):** the port tiers by stage through EV-0047 (`Level.coin_kind_for`:
  1->15, 2->35, 3->40, 4->200, 5/6->500, 7->2000). The binary binding stays open for the
  slot-81 kind argument; this is a documented port tuning, not a recovered fact.
- **Q-0044 (pets):** narrowed. All 24 pets now steer (lane chase, 2D chase, wander band),
  use the recovered ctor speeds where given, and Prego/Zorf/Meryl/Amp/Gash/Itchy/Rufus/
  Stanley/Nimbus/Brinkley/Walter bodies are in (signals for birth/food/melee, `Level` applies).
  The 8 guards (Wadsworth shelter, Seymour aura, Gumbo lure, Blip overlays, Amp click,
  Nostradamus sneeze, Presto transform, Walter glove entity) stay disabled and named.
- **Q-0050 (menu screens):** closed in the port. Options/Hall/Help now mount
  (`OptionsDialog`, `HallScreen`, `HelpScreen`); the Hall tabs read the profile rather
  than inventing scores.
- **Q-0052 (store roller):** partially closed. `Level.roll_stock()` runs the recovered
  roller shape (random unowned backdrop at 15000, kind 3; pet fallback when all six owned).
  Per-item art/tooltips/paging still need the kind byte binding.
- **Q-0053 (progression screens):** partially closed. Hatch/Pets/Bonus are in (`Main` runs
  Hatch -> Pets -> Bonus -> next level); since 2026-11-10 Hatch also draws the recovered card art
  (Q-0060, EV-0175). The 160-tick bonus wait, the pre-bonus store, score records and
  credits/trophy still need their triggers (Q-0013/Q-0016).
- **F1 (export):** the tailflop and Hatch sheets load their imported textures through `load()` +
  `get_image()`, never `Image.load_from_file`, so no export-time raw-PNG warning is introduced;
  `content.json` export inclusion stays open until a real export is run.


### R9 pet-body update (2026-11-10; port bindings, no new binary evidence)

- **Q-0044 narrowed again.** Four more slot-81 bodies are in: Wadsworth's shelter and the fish
  follow (EV-0177), Gumbo's opposite-corner steering and glow (EV-0178), Blip's instant store unlock
  (EV-0179) and Presto's transform with the recharge and the cross-pet cleanup (EV-0180).
  `headless_pet_check` covers all four (113 assertions).
- **Still guarded, and why** - each needs the half the binary has not yielded: Seymour's aura (only
  the `Tank+0x16C` consumer is proven, its writer is not, EV-0091), Amp's click -> electrocute path
  (EV-0097), Nostradamus' "Sneeze of Power" (EV-0102) and Walter's glove launch (the glove entity,
  hit table and effect fields are proven, the click binding and punch counter are not, EV-0104).
  None of them is guessed; they stay inert until their trigger is recovered.
- **Binding, not evidence.** Gumbo's corner points are the tank bounds, Blip's unlocked row set is the
  whole table, and the shelter's accel bands reuse the fish's existing 5/10 px pair - the note gives
  the constants' shape, not the literals. Recorded above and in the EV entries.

### D-0013 - Wadsworth's hide toggle runs on his recovered 120-tick period

- Date: 2026-11-10 (implementation, R9; source EV-0090, P2.7 §4.10)
- Status: accepted for the port; replace it if the writer is ever isolated.
- The binary proves the `+0x250` state, the hidden-count/mouth globals, `FUN_004D6250`'s cleanup and
  the ctor period `+0x224 = 120`, but not the branch that flips the flag. The port flips it every 120
  ticks of slot-81 time rather than leaving the whole shelter unreachable; the body is one function
  (`Pet._wadsworth_hide`), so the recovered writer drops straight in.
- The mouth point is `position + (40,40)` (the 80x80 sprite centre) because the recovered globals store
  a point, not an offset from the pet.

### D-0014 - The debug panel/cheats are port-only; MENU saves as a port safety net

- Date: 2026-11-11 (implementation, owner request; source EV-0189, EV-0046, P2.17)
- Status: accepted for the port. The debug actions carry no binary claim; replace them if a real
  cheat path is ever recovered.
- **Debug panel.** `scripts/ui/debug_panel.gd` is a playtest aid, not a recovered feature. The
  original's known cheat path is `FUN_005404A0` (Wavy/Prego sounds/Void/Space/Zombie toggles,
  EV-0046); no instant-money, grow, feed, egg, weapon, store-reveal or spawn-guppy cheat was
  recovered, and P2.17's string search found no cheat console/menu text. `Level.debug_action()`
  is the single dispatcher; the panel buttons and the `F2`-`F10` keys both go through it. `F1`
  toggles the panel. `F5`/`F9` keep their existing save/load meaning.
- **Why the panel does not pause.** The simulation keeps ticking while it is open, so a playtest
  can observe growth/hunger/coin timing with the controls visible. The panel is built only when
  rendering is on (`Level.render`); the headless suites call `debug_action()` directly.
- **MENU save.** `FUN_0051B6C0(99)` closes the tank screen and goes straight to the main menu with
  no save call (EV-0189). The port's leave-tank path saves to the level's `save_path` first,
  because a menu-started level does not auto-resume the previous run yet. The save is a safety
  net, not a claim about the original; remove it once menu starts resume the tank the way
  `FUN_0054CB20()` does. **Updated by D-0015:** the save now runs only from the Options dialog's
  "Back to Menu" button (`Main._leave_tank()`), not when the tank MENU is first pressed.
- **MENU transition.** `StoreBar.press_menu()` -> `Level.request_menu()` -> `Main` (save, clear
  pause, `Tank.shutdown()`, free the level, `_mount_selector()` in the same frame). The binary's
  two helpers map to close-tank + rebuild-menu; the port does not route through the Options
  "Leave Game?" confirm or the pause box, which are separate paths (EV-0189).
  **Superseded by D-0015 (2026-11-14):** the tank MENU now opens the in-tank Options dialog; the
  save/teardown/remount path above runs only from that dialog's "Back to Menu" button.

### D-0015 - The tank MENU opens the in-tank Options dialog (owner-directed port divergence)

- Date: 2026-11-14 (implementation, owner request; source EV-0191, EV-0189, P2.12 §10.11)
- Status: accepted for the port. This is a deliberate divergence: the binary's TankScreen id 99
  still runs `FUN_0054AED0()` + `FUN_00552100()` (close tank, rebuild menu, no save). Do not cite
  the new flow as recovered behavior; cite EV-0189 for the original and EV-0191 for the port.
- The owner asked for the pop-up MENU in the level to open the settings UI. `StoreBar.press_menu()`
  -> `Level.request_menu()` -> `Main._on_menu_requested()` now mounts the existing `OptionsDialog`
  through `Screens.open_dialog()` and pauses the tank (`Game.gameplay_paused`). The level stays
  mounted; opening the dialog alone writes no save.
- OK and Escape close the dialog and resume the same tank. "Back to Menu" closes the dialog and
  runs the old leave-tank path: save to the level's `save_path` (the D-0014 safety net), shut the
  tank down, free the level, mount `GameSelector`. The binary's "Leave Game?" confirm and the
  "GAME PAUSED" box remain separate paths and are not used here.
- While any modal dialog owns `Screens.dialog()`, `Level._unhandled_input()` ignores tank clicks
  and hotkeys, so F1..F10/S/P and feeding cannot fire behind the dialog.
- The Show Money checkbox is live (`Game.show_money` + `show_money_changed`); the in-tank wallet
  plate follows it. D-0016 corrects where it lives: Show Money is the TankScreen INI option
  (P2.5, `TankScreen+0x83C`), not a base Options checkbox, so the rebuilt dialog puts it in the
  labelled port-only debug block.

### D-0016 - The in-tank Options uses the shipped dialog's art/layout; the debug block is port-only

- Date: 2026-11-15 (implementation, owner request; source EV-0192, EV-0191, P2.12 §11.3, P2.5)
- Status: accepted for the port. The base Options contents are recovered (P2.12 §11.3); the
  debug block and the custom-cursor/hardware-acceleration storage are explicitly port-only.
- **Art.** The dialog draws the shipped `Dialogue-panel` (240x240, 9-slice margins 32/44),
  `DialogButton2` (288x33, three 96x33 frames purple/hover/pressed) and the `Checkbutton`/
  `unCheckbutton` (46x45) and slider `slidertrack` (156x17) / `SLIDERWIDGET` (33x32) cells. All
  six sheets are opaque, so they are composed with their `masks/_<file>` companions through
  `MaskAlpha.compose()` (P3.3); without the mask the rounded panel corners and the widget tiles
  draw as black/brown rectangles. The menu panel keeps the reference rect (154,32,328,312); the
  in-level panel grows downward to 460 px to hold Back to Main Menu and the debug block.
- **Controls.** `OptionSlider` and `OptionCheck` are small port controls, not engine HSlider/
  CheckBox: the engine widgets add theme content margins and stretch the track, which moved the
  labels off the reference offsets (the checkbox label starts 39 px after the icon, not 46+8).
  Both resolve `Content` lazily and fall back to flat blocks under `--script`.
- **Base options.** Music and Sound FX write the `Audio` mixer instantly (the port still starts
  muted, Q-0056). Fullscreen is a real `DisplayServer.window_set_mode()` toggle. Custom Cursors
  and Hardware Acceleration only store `Game.custom_cursors` / `Game.hardware_acceleration`;
  no cursor layer or runtime renderer switch exists in the port, so they are stubs, not recovered
  behavior.
- **Port-only block.** The debug grid is labelled "DEBUG (PORT-ONLY)" and reaches the live level
  through `Main._on_options_debug_action()` -> `Level.debug_action()` (D-0014): money, grow, feed,
  egg, max weapon, reveal store, spawn guppy. Show Money is the TankScreen INI option (P2.5,
  `TankScreen+0x83C`), **not** a base Options checkbox, so it lives in this block; its label
  carries ON/OFF and the bar's wallet plate follows `Game.show_money_changed`. The block is hidden
  in the main-menu Options, which is the plain base panel with no Back row.
- **Pause.** Opening Options sets `Game.gameplay_paused`. `Level.setup()` now assigns
  `Tank.pause_source = Game` (previously nothing did, so the flag was written but never read);
  `Tank.is_paused()` freezes entities and `Level._on_sim_tick()` early-returns so the level clock,
  wave clock, particles and store refresh freeze too. `Level._process()` also stops re-aiming held
  fire. This is the original's shared Tank+0x94 gate, not a scene-tree pause.
- **Help.** The Help button replaces Options with the existing dimmed tutorial `HelpScreen` while
  the tank stays paused; its Menu button (relabelled "Back to Game") and Escape both close it and
  resume the same tank. It is not a second stacked modal (Screens has one slot).
- The tank MENU -> Options flow itself remains the D-0015 divergence; this entry only fixes the
  dialog's contents and the pause path.

### D-0017 - Debug controls get their own dialog; the fish shelf is never reveal-gated; the egg cell is clipped to its dome

- Date: 2026-11-16 (owner playtest review; source D-0014/D-0016, EV-0185, P2.6 §3/§5)
- Status: accepted for the port. Owner-directed: the 2026-11-15 in-tank Options shipped with the
  debug grid pasted over the base panel's bottom frame, and the shop bar opened with no shelf on
  1-1 / 1-3.
- **DebugDialog.** The port-only controls (D-0014) moved out of `OptionsDialog` into
  `scripts/ui/debug_dialog.gd`: its own masked `Dialogue-panel` modal with a two-column button
  grid, the Show Money toggle and CLOSE. The in-level Options carries one `DEBUG` row that hands
  the single `Screens` modal slot to it; CLOSE hands the slot back to Options, so the detour never
  resumes the tank by itself. `Main._on_debug_action()` still dispatches through
  `Level.debug_action()`. Nothing here is recovered behaviour - the binary has no cheat
  console/menu (P2.17).
- **Shared skin.** `scripts/ui/dialog_skin.gd` is the single owner of the masked
  `Dialogue-panel` / `DialogButton2` composition (9-slice margins, three button frames); both
  dialogs build from it instead of each carrying a copy. D-0016's art rules are unchanged.
- **Options layout.** One checkbox per row (FULLSCREEN / CUSTOM CURSORS / HARDWARE ACCELERATION):
  side by side, the 8 px outlined "FULLSCREEN" label ran into the second box's icon. The in-level
  panel grows to 328x384 only for the MAIN MENU + DEBUG row.
- **Fish shelf.** `Progression.reveal_rules()` no longer gates item 0 on any tank. With the guide's
  keypoint lists applied literally, 1-1 and 1-3 opened with every dome empty, so the 200 starting
  shells could not buy a fish until a stock guppy grew on its own. The food, predator, blaster and
  egg shelves keep their milestones; EV-0185's "1-1 guppy at medium" line is withdrawn as a port
  reading (it was a guide keypoint, not a binary claim). `headless_store_ui_check` pins the opening
  shelf.
- **Egg dome.** The shipped `EGGPIECES` cell carries its own purple dome window and is opaque: the
  `masks/_EggPieces.png` companion has no transparency at all (measured 2026-11-16: 5,382 of 5,382
  pixels at alpha 255), and `menubar.png` is opaque at every dome pixel (255) too, so drawing the
  cell *behind* the bar is not an option. `EggWidget` therefore draws the cell over the bar's
  `MENUBAR` art, clipped to the dome's glass window (38x33 at (10, 3)), so it can no longer spill
  across the gold rim or the price plate.

### D-0018 - The dialogs draw the base art at a uniform 1.25 scale; NEXT LEVEL is a debug skip

- Date: 2026-11-16 (owner playtest review; source D-0017, D-0014)
- Status: accepted for the port; owner-directed follow-up to D-0017.
- **Proportions.** `DialogSkin.PANEL_WIDTH` is 300 - the 240-px `Dialogue-panel` at a uniform 1.25
  scale - and both dialogs use it, so the title plaque and the corner brackets keep the art's own
  proportions instead of stretching 1.37x sideways (the menu panel was 328 wide). Heights stay
  per-dialog (Options 312 menu / 380 in-level, Debug 336): only the fixed top band carries an
  ornament, so a taller panel does not distort the plaque.
- **Buttons.** `DialogButton2` is now 9-sliced (`BUTTON_CAP` 20x6) instead of stretched whole, so a
  264-px row keeps the brass end caps and their rivets at their native width. Stretching the 96-px
  frame to 3x is what made the menu's buttons read as fat smeared pills.
- **Debug grid.** Two columns of 128x33; Show Money is a full-width row under the grid (as the
  ninth grid cell it left an empty slot), so the panel closes at 336 instead of 360.
- **NEXT LEVEL.** `Level.debug_next_level()` walks the profile one level on (rolling into the next
  tank after level 5) and emits the new `skip_level_requested`; `Main._on_level_skip()` closes any
  modal, tears the level down and starts the next one **without** the Hatch/Pets/Bonus cards. It is
  a playtest aid, not recovered behaviour: the binary's own advance is the continue path with its
  cards (P2.6 §1.2), which stays untouched.
- Totals after the change: 24 suites, 1452 assertions (`headless_level_check` 156,
  `headless_integration_check` 134).

### D-0019 - The tank bar has no in-level reveal: a level's whole stock is on it from the first frame

- Date: 2026-11-16 (owner playtest; supersedes the EV-0185 reveal table introduced under D-0014/D-0017)
- Status: accepted for the port.
- **Owner report.** "The shop didn't open properly, it just has the fish png and the background still
  closed, but can be purchased": 1-1 and 1-2 showed one dome (or two, once a fish grew) and the egg
  dome stayed hidden, so the bar read as an empty shop that only happened to sell a fish.
- **The binary has no such gate.** `Tank+0x2DC` is the count of rows with `A >= 0` and `Tank+0x2E0`
  is a "widgets built" latch: `FUN_005409B0` builds one widget per in-stock row and the
  `while (+0x2E0 < +0x2DC)` loop only runs until every such row has one (EV-0144, P2.13). Nothing
  hides a stocked shelf behind a growth stage, so the earlier milestone table was a port invention
  read off the guide's keypoint lists even though the guide describes tutorials, not gates.
- **What changed.** `Progression.reveal_rules`/`PREDATOR` are deleted, with `Level.store_reveal`,
  `_prime_store_reveals`, `reveal_store_for_stage/after`, the `row.hidden` flag, `Level.egg_unlocked`
  and the `buy_item` hidden check. `stock_default_store()` now stocks exactly `Progression.store_rows`
  (the `§3` `A = -1` gating still decides what a level sells), the egg dome shows its price from the
  first frame, and a save's stale `hidden` keys are dropped on load.
- **Blip still means something.** `Tank.store_locked` (`+0x2E0 < +0x2DC` as the port reads it) now
  genuinely only means "some rows lack a widget", which an eagerly built bar clears; `_unlock_store_rows()`
  performs the recovered `FUN_005409B0(i, 1)` effect (the level-gated rows join the bar, prices kept),
  and F8 / REVEAL STORE is the same call on demand.
- **StoreScreen.** Unstocked shelves draw nothing rather than the literal `SOLD`: the original builds
  no widget for `A = -1`, so `SOLD` belongs only to a stocked row `Store.is_available()` refuses.
- Checks: `headless_store_ui_check` now pins the whole 1-3 bar (guppy, both food shelves, carnivore,
  blaster) and the priced egg dome; `headless_level_check` pins that 1-3 opens with its whole stock
  and that the reveal action reports no change where the level hides nothing.

### D-0020 - The tank draws its own level number in the bottom-right corner

- Date: 2026-11-16 (owner request)
- Status: accepted for the port. **Port addition, not recovered behaviour**: `TankScreen` draws no
  level readout, so this is a HUD extra and nothing in it claims a binary writer.
- **What.** `Level` adds a `LevelLabel` to its `Hud` CanvasLayer at `LEVEL_LABEL_RECT`
  (534, 452, 100, 22), right-aligned, `FONT_TINYBOLD` in white, mouse-transparent. Text is
  `"%d-%d" % [tank_index, level_index]` - the same pair the save and the selector use, so 1-3 reads
  `1-3`.
- **When it changes.** `_refresh_level_label()` runs from `_add_level_label()`, `start_level()` and
  `load_game()`; nothing polls it per frame. With `render = false` (headless checks) the label is
  never built and the getter stays null.
- Verified against `shot_menu_tank.png` (1-1 in the corner) with `headless_level_check` 155,
  `headless_integration_check` 134 and the boot run all clean.

### D-0021 - "The shop" in owner reports is the in-tank bar, not the Fish Emporium

- Date: 2026-11-16 (owner correction)
- Status: accepted. Read every future owner report with this mapping before touching either screen.
- **"The shop" / "the tank shop" / "the shop bar"** = the in-tank store bar: `scripts/ui/store_bar.gd`
  (`StoreBar`, the row of seven domes above the aquarium, built by `FUN_005409B0`) together with the
  egg dome the `EggWidget` draws in the seventh slot. Everything the owner has reported so far under
  the word "shop" - the empty bar, the fish icon, "the background still closed", "can be purchased"
  - is about this bar.
- **The Fish Emporium** = `scripts/ui/store_screen.gd` (`StoreScreen`, the STORESCREEN room opened
  with S; Virtual Tank shops there too). The owner calls it "the virtual tank shop" or names it
  directly; it is *not* what "the shop" means.
- **Why it matters.** R13's report ("the shop didn't open properly") was read as the bar and fixed as
  the bar (D-0019); this entry keeps that reading on record so a later session does not chase
  `StoreScreen` for a bar report, or the bar for an Emporium report.

### D-0022 - The guppy dome swims, and a stocked dome is filled with the art's own lit glass

- Date: 2026-11-16 (owner report: "the fish swimming animation with open background")
- Status: accepted for the port. The swim row is the tank's own animation; the glass fill is a
  port-only restyle of the base art, not recovered behaviour.
- **Swim row.** `StoreBar` plays the stage-0 row of `SMALLSWIM` - all ten columns, one per
  `AnimState.SHEET_FRAME_TICKS`, through `AnimState.column_at(0, Sim.tick_count, 10)`. That is the
  same clock and the same cells the tank's guppy uses, so the dome shows the live animal rather than
  one held cell. The ten cells are composed once, on the first frame that draws the fish dome
  (mask composite, then crop), and kept.
- **Crop.** All ten cells share one crop box - the union of their opaque pixels - so the fish fills
  the dome and does not breathe in scale from cell to cell. The earlier fixed 44x44 centre crop left
  the dome's own shading showing around a small fish, which is what read as a shut lid.
- **Open glass.** `MENUBAR` shades the lower half of every dome as opaque moulding, and its alpha
  companion (`masks/_menubar.png`, 640x75) is white at every dome pixel: the shipped art cannot be
  transparent glass and no "open" variant exists in the assets. The bar therefore paints the art's
  own lit-glass colour (`GLASS_COLOR`, sampled at 0.969, 0.816, 0.404) **into the icon cell**: a
  34x34 canvas holding a soft-edged disc with the fish fitted two pixels inside it. Baking it into
  the cell, rather than drawing a disc behind the icon, is what keeps the fish whole - a separate
  disc sat forward of the icon and covered the fish's head, because the icon box is wider than the
  dome's glass (found on the 1-2/1-3 walkthrough). Unstocked domes keep the bare art.
- **Egg dome.** `EGGPIECES` ships an alpha companion too (`masks/_EggPieces.png`). Drawing the raw
  cell put an opaque purple square across the bar's gold rim; the `EggWidget` now composes every
  piece cell through that mask (cached per piece count), so the purple reads as the dome window the
  art draws. The price keeps the measured plate and the greyed colour when the purse is short.
- Verified on a 1-2 and 1-3 walkthrough with a slot-by-slot dump: 1-2 stocks shelves 0-2 at
  100/200/300 plus the 500 egg dome; 1-3 stocks 0-3 and 5 at 100/200/300/1000/1000 plus the 2000 egg
  dome; every stocked shelf has an icon, every empty one none, and the price digit colour follows the
  purse. The swim row was measured at ten cells with the column advancing every five ticks (0 -> 1 at
  tick 56, 2 at 61).

### Q-0061 - Presto's picker contents and its opening input are port bindings

- OPEN (2026-11-10, raised by `scripts/ui/presto_picker.gd` for R9; source EV-0100, P2.7 §3.3/§4.20,
  EV-0106, EV-0181).
- Recovered: `FUN_0054C6F0` allocates the `Sexy::PetDialog` (0x2F8 bytes) through `FUN_005355C0`,
  pushes screen id 0x1F, and the dialog carries the "PRESTO CHANGE-O" name; `FUN_004F89A0` gates on
  `+0x238` and performs the swap.
- Open: **which** pets the dialog lists (the wiki says every unlocked pet; the list itself was not
  enumerated) and **which input** opens it (the wiki says right-click on the pet; the binding was not
  traced). The port lists the owned pets minus the current index and binds the `P` key, beside the
  port-only `S` shop key.
- Non-blocking: the swap, its recharge gate, the cleanup and the level wiring are the recovered
  parts; only the roster filter and the key are the port's choice. Recorded so a later pass replaces
  them instead of shipping them as facts.

### Recharging notice (2026-11-10; port binding)

- **EV-0182:** the literal ("Recharging...") and the anchor (`x + width/2 - 20`, `y - 10`) are
  `FUN_004F89A0`'s, and the notice is raised from the same failure path (a refused transform
  attempt), not shown permanently.
- **Port choice:** the 90-tick dwell. The binary's draw is per attempt with no recovered lifetime, so
  the port holds the text for 2.5 s at the 36 Hz rate instead of a single frame. `PRESTO_NOTICE_TICKS`
  is the one constant to change when a lifetime is recovered.

### Q-0062 - tanks 2-4's shelf reveal order is inferred from the guide's pattern

The GameFAQs walkthrough itemises tank 1's keypoints (medium guppy -> guppy/food, large guppy ->
carnivore/egg, buying a carnivore -> blaster + egg) and states tank 3's two predators, but it does not
list tanks 2-4 item by item. `Progression.reveal_rules` therefore applies the same pattern to them:
food at medium, the tank's next predator at large, the blaster and egg after that predator is bought;
tank 2's star potion at large and its starcatcher after the potion; tank 3's beetlemuncher after the
guppycruncher; tank 4's ultravore after the carnivore. That ordering is the port reading, not a
recovered table - the binary's own slot writer (the `0x4F18xx` tutorial/growth path, Q-0018) is still
unidentified, and EV-0185 records the guide evidence for the mechanism itself.

### Store-bar reveal and the mermaid (2026-11-10; extends Q-0054 and Q-0055)

- **EV-0185:** the bar is permanently on screen; shelves appear at growth/purchase milestones (tank 1
  from the guide, tanks 2-4 per Q-0062), Blip forces all of them after 200 ticks (720 as Presto), Time
  Trial opens the bar at the first medium fish. A hidden shelf keeps its row and price but draws no
  widget, so no fabricated stock enters the save. The price label sits at (7, 44, 45, 18) so the 8-px
  glyphs read slightly below the plate's middle.
- **Q-0054:** the per-item icon binding from EV-0184 stands; the reveal state is `row.hidden`, which
  `StoreBar.row_at`/`row_index` skip and `Level.buy_item` refuses, so an unrevealed shelf cannot be
  bought from the bar or the StoreScreen.
- **EV-0186 / Q-0055:** the menu mermaid's `MERYLTAIL` strip is measured and its playback kept, but
  no recovered screen position exists and four composited placements all drew a second tail; the port
  now draws the shipped `SELECTORSCREEN` mermaid alone. Q-0055 stays open for the draw position.

**2026-11-10 second pass on the mermaid (EV-0188):** the fin is drawn again. The baked tail's stump at
~(152,405) is real, so the `MERYLTAIL` crescent is the missing fin; at 1:1 it read as a second tail,
so the port fits it at scale 0.6 with its root notch on the stump and keeps the recovered flop. The
placement is still the port's (Q-0055), not a recovered coordinate.
