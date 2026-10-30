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
- 2026-10-21 update (EV-0109): a second sample from GameBanana
  (`docs\analysis\inputs\p2.13-saves-gamebanana-100\`) has `users.dat`, `user1.dat`, and
  `sim1.dat`, but still no `scr%d.dat`. The 232-byte `user%d.dat` field order is now mapped
  end-to-end through `FUN_00503730` (see P2.13 note). The `scr%d.dat` serializer, its
  obfuscation, and the exact timestamp/value meaning remain **OPEN**.

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
- **`Tank+0x4FE` writer.** In Virtual Tank the byte gates the entire alien/wave clock (mode 5 +
  `+0x4FE == 0` skips it) and elsewhere it is the warning-sound enable (P2.8). No writer is traced,
  so "VT can have aliens" is not implementable - keep it a flag defaulting to 0.
- **`Tank+0x2DC` / `+0x2E0` pair.** Sandbox re-rolls the store while `+0x2E0 < +0x2DC`; both fields
  are otherwise unbound (P2.6 lists `+0x2DC` only as "item arrays A/B/C/D and +0x2DC"). Do not use
  them as a counter in the remake.
- **VT session helpers.** `FUN_005394E0` (populate), `FUN_0053A4F0` (store), `FUN_0053AA00` (HUD),
  `FUN_0054BC30` (create) and `FUN_0054B3A0` (load) are named by call site only; the `sim%d.dat`
  payload itself is P2.13.

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
