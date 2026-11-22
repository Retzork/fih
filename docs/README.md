# Insaniquarium Deluxe -> Godot 4.7 remake - documentation index

**Progress audit (2026-11-05, re-run 2026-11-07):** all 19 headless suites re-run green on this checkout (1010 assertions after the projectile homing follow-up, EV-0158; at the 2026-11-05 audit baseline it was 992; the scene-backed integration suite covers menu -> level -> wave -> boss, the alien/boss HP bars and the native UI fonts); the capability and implementation-fidelity assessment, export-risk findings and recommended order are in [AUDIT.md](AUDIT.md). **Review reset (2026-11-08):** the completion pass was revoked by the owner after a playtest - the suites prove modules, not the assembled game. `PLAN.md`'s Review table is the current work list (R8/R9 open); all 26 suites still pass (1658 assertions, re-run 2026-11-22).

**Handover status: Phase 2 closed (2026-11-02).** Phase 0, Phase 1 and Phase 3 are complete; Phase 2
is 14/18 with **every technical system decoded** and `SPECS.md` written - only the two optional items
P2.16 (screensaver variants) and P2.17 (cheats) remain. **P2.18 `docs/SPECS.md` is complete**: the
behaviour-side contract for P4, twin of `PIPELINE.md` (D-0008), and the first thing to read before any
Phase 4 task. It also raises **Q-0034**, the one genuine cross-system contradiction found while
writing it: P2.1's wrapper loop is 10 ms (100 Hz) but P2.7-P2.9's gameplay timers calibrate at ~36 Hz
(the ratio is 100/36 ≈ 2.78). The remake runs the 36 Hz reading (2026-11-04) and keeps the rate in
one constant until P5.3 measures the original. P2.1-P2.4, P2.7-P2.15 and P2.18 are closed, P2.5 and
P2.6 are substantially complete with tracked open questions, and P2.12 has its screen and dialog
passes done (screen map, mode writer, store screen and stock refresh, level-start flow, all 13 screen
constructors and their click handlers, the dialog base plus all ten dialog ctors and their click
handlers); what is left there are the tracked open questions.
**Phase 4 and Phase 5 are in review (2026-11-09):** the 2026-11-08 completion pass was revoked by
the owner after a playtest, so P4.4-P4.14 and P5.1-P5.5 are back to `[~]`. All 24 headless checks
pass (1658 assertions, re-run 2026-11-22), but the Review table in `PLAN.md` is the source of truth:
R1/R2/R3/R4/R5/R6/R7 and R10 are fixed, R8 (the owner's live playtest of tanks 2-4/5-1) and R9 (pet
guards) remain. The 2026-11-15 pass also rebuilt the in-tank Options dialog on the shipped art and
wired the shared pause gate (`D-0016`, `EV-0192`).

## Start here

1. **New agent session:** read `../AGENTS.md` first, then `PLAN.md` (mandatory). Follow the
   session-end checklist in `AGENTS.md`.
2. **Want the current state quickly?** Read the Review table at the end of `PLAN.md` (the open
   R-rows are the work list), then `SPECS.md` (the behaviour contract - it summarises every
   system and maps the P4 tasks), then the newest note `analysis/notes/p2.15-resources.md` (EV-0150..
   EV-0154; latest corrections EV-0155/EV-0156, plus EV-0157's font-global map), then
   `analysis/notes/p2.12-menus.md` for the
   screen/vtable map, the dialog layer and store population (EV-0131..EV-0140) and
   `analysis/notes/p2.13-saves.md` for the save bodies (EV-0144).
3. **Need to run analysis?** Read the REA section below and the matching section of
   `../AGENTS.md`; the game install is read-only.
4. **Need asset details?** Read `PIPELINE.md` before touching assets or starting P4.
5. **Writing gameplay code?** Read `SPECS.md` (behaviour) and `ARCHITECTURE.md` (tick model,
   autoloads, coupling rules) first; per-tick work is `_sim_tick()` registered with `Sim`, never
   `_physics_process`.

## Current state (handover snapshot)

| Area | State |
| --- | --- |
| P0 environment / tooling | Complete (13/13) |
| P1 target identity | Complete (10/10) |
| P2 reverse engineering | Closed (14/18): P2.1-P2.4 `[x]`; P2.5 `[~]`; P2.6 `[~]`; P2.7-P2.15, P2.18 `[x]`; P2.16/P2.17 optional |
| P3 assets | Complete (8/8): 129 `SpriteFrames`, audio/music/fonts regenerate into `assets_raw/` |
| P4 Godot implementation | In review (3/14): playable level, store + roller, Hatch/Pets/Bonus, selector + Options/Help/Hall, audio + cues, saves + golden fixtures, pets (all steer, 16 slot-81 bodies), aliens, Cyrax, projectiles + Larva, laser, all modes; 26 headless checks green (1658 assertions), but R8/R9 keep the assembled game unverified |
| P5 validation / polish | In review (0/5): `P5-VALIDATION.md` withdrawn pending R8/R9 |

- **2026-11-15 in-tank Options (D-0015/D-0016, EV-0192):** the tank MENU opens the shipped-art
  Options panel over a genuinely paused tank (`Game.gameplay_paused` -> `Tank.pause_source`).
  `Dialogue-panel`/`DialogButton2`/`Checkbutton`/slider sheets are composed with their alpha masks;
  `OptionSlider`/`OptionCheck` keep the native metrics. Music/SFX sliders, Fullscreen, Custom Cursors
  and Hardware Acceleration, Help/OK and in-level Back to Main Menu are in, plus the labelled
  port-only debug block. Help swaps in the tutorial HelpScreen while the tank stays paused. The
  main-menu variant is the plain base panel. The MENU -> Options entry remains the owner-directed
  divergence; the binary's id-99 dispatch still closes the tank.

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
  takes `FUN_005363D0` (the *buyable* path, which re-applies `SetPrice` `FUN_00536350`, a bare
  `sprintf("%d")`) or `FUN_005372F0`, which writes the literal **`SOLD`**. The price itself is a
  property of the prize the slot rolled (EV-0138): `FUN_00519730` is a method on the `Sexy::Fish` /
  `Sexy::Oscar` object the factory just built, keyed on the prize kind at `+0x8C`, with the tank index
  from `FUN_00501060()` overriding it flat. The screen's slots (attach/detach/refresh/update/draw/
  mousemove) and its tooltip (`FUN_0051B9E0` kind-to-text, 16 ticks of hover, "Thanks for shopping at
  the Fish Emporium!") are mapped too.
- **P2.12 screen pass (2026-10-29, EV-0136):** the vtable-xref recipe only worked on the first four
  screens, so the ctor map was rebuilt from an RTTI + vtable-immediate scan (a class stores its
  vtable with `mov [reg], imm32`, so the vtable VA appears in `.text` two bytes after the
  instruction): all **13 screen ctors** plus 7 inline overlay ctors are located and written up. Each
  screen gets a field map (Help's 8-page counter at `+0xA4`, HighScore's tab at `+0xA8`, Pets' 24-slot
  grid and its `profile[0x5A+i]` writer, SimFish's 20-row browser, SimSetup's three vtables with the
  manager at `+0x90` and its checkbox copy into `Tank+0x4FC..+0x500`, Story's `profile+0x7C` popcount
  gate, Bonus' `manager+0x738` read), all 10 click dispatchers are decoded, and the transition
  helpers are tabulated. Story unlock stays Q-0013.
- **P2.12 dialog pass (2026-10-29, EV-0137):** ten dialogs sit on one shared base built by
  `FUN_00530920(manager, font, colour, pad, flag, title, message, buttonLabel, kind)` -> the
  `Sexy::Dialog` ctor `FUN_00475C40` + the base vtable pair + `manager` at `+0x150`. `kind` drives the
  built-in button row: 0 none, 1 Yes/No, 2 OK/Cancel (both with ids 1000/1001), 3 one caller-labelled
  button; captions come from the localization keys `DIALOG_BUTTON_YES/NO/OK/CANCEL`. All ten ctors and
  their one or two opener call sites are mapped, each dialog's extra widgets/ids are written up
  (Options' sliders/checkboxes and visibility flags, Pet's 24 cells, User's list and scrollbar,
  ScreenSaver's six checkboxes over `app+0x838..0x83E`), and five click handlers cover all of them.
  The base vtable pair is RTTI-named `Sexy::MoneyDialog` and no `.?AVDialog@Sexy@@` exists - recorded
  as a naming conflict and settled as D-0011 (no money dialog is ported). A final wiring pass (EV-0139)
  closed the last two questions: the per-character **edit filter is slot 2** of the edit listener (the
  base default is `mov al,1; ret 8`; the three dialogs narrow it to printable ASCII, alnum + space, and
  digits), and `RegisterDialog` **relabels** the base's two auto buttons to Register/Cancel. That pass
  also fixed two wrong listener addresses in §11.2. A residue pass (EV-0140) then settled the odd
  field: `UserDialog`'s digits-only `"0"` box is the **shells transfer amount** of the "TRANSFER
  SHELLS" mode (drawn only when `+0x174 != 0`), and Rename/Delete read the highlighted list row.
- **P2.12 still open (Q-0018, Q-0025, Q-0027):** the owner of the *normal* store-item object (its
  price display is answered, and EV-0138 closed the "is the rolled pet the receiver of
  `FUN_00519730`" question - yes); `manager+0x738` now has a reader
  (the Bonus handler) but still no writer; `profile+0x18` is unbound (the `profile+0x5A` clear is
  explained - it is the PetsScreen ctor resetting the pending pet selection); and Q-0027
  keeps two dialog loose ends without blocking the port (Options' `+0x18C` writer and the screen-saver
  flag writers - its third item, `UserDialog`'s box, is answered in EV-0140). Q-0026 is **settled**
  (EV-0141): `profile+0x72..+0x77` are the six backdrop ownership flags, since the store roller builds
  its kind-3 stock from the clear entries and buys one backdrop for 15000. Do not guess these.
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
  semantics, Q-0016 credits trigger, Q-0017 tank 6, Q-0018 StoreScreen/store-item population.
  Q-0019 (`scr%d.dat`) is settled by EV-0143. Do not guess these in the remake.
- **P2.13 saves (2026-11-01, complete):** live folder
  `C:\ProgramData\Steam\Insaniquarium\userdata`; real early and GameBanana samples are copied
  under `analysis/inputs/`. `users.dat` and the full 232-byte `user%d.dat` field order are
  mapped through `FUN_00513850`, `FUN_005145A0`/`FUN_00514730`, and `FUN_00503730`
  (EV-0108/EV-0109). The GameBanana profile has `+0x7C = 0xFFFFFFFF` and `+0x80 = 1`, a strong
  candidate for a 32-story mask + gold trophy, but the reader is not located; Q-0013 stays
  open. The tank save is **one file per game mode** (EV-0142): `FUN_00505880(out, mode, slot)`
  formats `userdata\%s%d.dat` with `adv`/`tim`/`snd`/`sur`/`sim` for modes 0/2, 1, 3, 4 and 5, so
  `sim%d.dat` is the Virtual Tank save; `FUN_005497A0` saves and `FUN_0054CB20` loads through the
  shared `FUN_00546990`/`FUN_00546AA0` pair. Q-0019 is settled (EV-0143): `scr%d.dat` is not a tank
  save but the bonus-round **Shells escrow** - 102 raw dwords, `[profile+0x88 token] [50 x
  rand()%20000] [pending shells] [50 x rand()%20000]`, written by SaveGame from `Tank+0x400` and paid
  into `profile+0x48` by `FUN_00514B00`. The **tank body is decoded end to end** (EV-0144):
  `FUN_00546240` is both writer and reader, and the order is version `0x36`, tank, level,
  `+0x2A5`, `+0x2A6`, entity stream (type `0x1F` skipped), optional `+0x110` object, overlay block,
  24 per-pet flags, 316 scalar bytes, 12 x 17-byte store rows, then SaveGame's `__time64`; section
  starts are `42+E+S`, `454+E+S`, `658+E+S`, and both samples parse with no remainder. Residual
  unbound fields are bounded in Q-0029; the save/delete gate stays Q-0028. Note:
  `analysis/notes/p2.13-saves.md`.
- **P2.5 leftovers:** mode-enum naming is answered (EV-0126); coin-hit gameplay intent (Q-0010) ->
  runtime; VT beetle value. See `PLAN.md`.
- **P2.14 audio (2026-11-01, complete):** the game ships **two mixers**. Effects are DirectSound:
  `Sexy::SoundRes::ResourceManager` -> `Sexy::DSoundManager` -> `IDirectSoundBuffer`, a fixed pool
  of **256** slot records (28 B at `+0x404`) with a per-slot volume array of doubles at `+0x2408`
  (all 1.0), on the default device. Music is BASS: `Sexy::BassMusicInterface` over
  `Sexy::BASS_INSTANCE`, which loads `.\bass.dll` and resolves 48 entry points into fixed dword
  slots. `FUN_00488300` picks a null/FMOD/BASS interface off `app+0xF0`/`+0xF1`; the install ships
  `bass.dll` and no `fmod.dll`, so the FMOD path (and its `_FSOUND_*` table) is dead. `SexyApp::Init`
  preloads `music\{Alien,Lullaby,Insaniq2}.mo3` as ids **1/3/4**; a `.mo3` is read whole into memory
  and passed to `BASS_MusicLoad(mem=1, ...)`, and the play slot always restarts with the loop bit
  and can seek by order. Gameplay requests music through one `SetMusic(a, b)` (`FUN_0054B1A0`, 21
  call sites); the per-stage selector gives stage 1-4 -> (0,22)/(0,0)/(2,32)/(2,45), the level
  sentinel -> (0,13), and **Virtual Tank (mode 5) plays no music**. Effects are triggered by the id
  alone (app vtable slot `0xD8` = `FUN_004896B0`), allocated by `FUN_00419320` from the pool
  (`"Out of free sound ids"` when full) with the record's default volume/pan; all **65** `SOUND_*`
  names are bound to their id globals. Volumes are doubles 0..1 at `app+0xD0`/`+0xD8`, persisted as
  `MusicVolume`/`SfxVolume` percent. Evidence EV-0145..EV-0149; note
  `analysis/notes/p2.14-audio.md`; open Q-0030/Q-0031.
- **P2.15 resources (2026-11-02, complete):** `properties\resources.xml` is parsed by the game's own
  XML tokenizer - `FUN_00418780` (`"Resource file not found: "`) -> `FUN_00418420` (only
  `<Resources>`, else `"Invalid Section '"`, `"No id specified."`) -> `FUN_00417F10` (element
  dispatch by vtable slot: `Image` `+0x08`, `Sound` `+0x04`, `Font` `+0x0C`, `SetDefaults` `+0x10`).
  Ids are `SetDefaults idprefix` + `id`, paths are `SetDefaults path` + `path`, and files resolve
  through a fixed six-extension probe (`.tga`,`.jpg`,`.png`,`.gif`,`.j2k`,`.jp2`). The manifest's
  **326 ids partition exactly** across the group handlers - `Init` 14 (loader screen + cursors + 2
  fonts + click sound), `Register` 16 (13 fonts + dialog skin), `LoadingThread` 296 (232 images +
  64 sounds). `<Image>` entries are grids (`cols`/`rows`, row-major cells) with `anim` =
  none/once/pingpong/loop, `framedelay` (all shipped values 2/4), `begindelay`/`enddelay` and the
  parallel `framemap`/`perframedelay` lists; transparency is a **second file** - implicit `_name`
  companions and explicit `alphaimage` (sheet-sized) / `alphagrid` (one cell, tiled) - merged as
  alpha = mask blue channel. Elements are registered at parse time and loaded later by
  `FUN_00419480` (failures are per-asset, not fatal); `GetImage`/`GetSound`/`GetFont` are three maps
  that return deferred placeholders during the loading thread and otherwise throw
  `"X resource not found: %s"`. Evidence EV-0150..EV-0154 and EV-0157 (font globals); note
  `analysis/notes/p2.15-resources.md`;
  open Q-0032/Q-0033 (non-blocking).
- **Phase 2 close-out:** P2.18 `SPECS.md` is complete (the cross-system P4 contract, D-0008);
  P2.16 (screensaver deltas) and P2.17 (cheats) stay optional. P2.15 is closed
  (EV-0150..EV-0154, EV-0157); P2.14 is closed (EV-0145..EV-0149); P2.13 is closed (EV-0144).
  P2.12 is closed (EV-0139/EV-0140) with only Q-0027's two dialog loose ends tracked. Q-0018's tank-side
  call site is identified (`0x54782A` = `FUN_005409B0()` inside `FUN_00547610`, gated on tank 5 /
  `Tank+0x110 == 0` / `+0x2A5 == 0` / `+0x3AF == 0`); the tutorial-loop owner and the
  `prize+0x1D0/+0x1D1` writers stay open.

## What is in the repository

| Path | Content |
| --- | --- |
| `project.godot`, `icon.svg` | Godot 4.7.1 project shell (Forward Plus, `canvas_items` stretch, Jolt configured; 2D game), five autoloads and the 640x480 settings. `scenes/main.tscn` boots the selector; `scripts/` holds the gameplay (level, entities, UI, persistence). |
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

# required for a usable checkout: extract the owned game's assets (read-only install -> assets_raw/)
# content.json and every SpriteFrames resource reference these files; the folder is gitignored.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\parse-resources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1

# then verify the Godot project imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import
```

The playable level is in `scripts/tank/level.gd`: it mounts the tank, feeds fish, collects coins,
runs the store and the wave clock, and is entered from the game selector. `PLAN.md` is the source
of truth for what remains; read `SPECS.md` (behaviour contract, §12 maps each P4 task onto its
section, note and asset set) and `PIPELINE.md` (asset contract) before starting new work.

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
| `AUDIT.md` | Progress audit (2026-11-05): re-run test counts, per-system capability assessment, findings and next-step priority. |
| `EVIDENCE.md` | Append-only ledger: each verified claim + how it was verified + confidence. Newest IDs are at the bottom (currently EV-0229). |
| `TARGET.md` | Immutable facts: game paths, SHA-256s, versions, environment, REA setup. |
| `PIPELINE.md` | Asset pipeline + Godot usage contract (P3 output; read before P4/asset work). |
| `SPECS.md` | Behaviour contract for P4 (P2.18 output): tick model, resource contract, entity rules, economy, modes, UI, persistence, audio, cross-system rules, shared constant sheet, open-question index. Read before any P4 task. |
| `ARCHITECTURE.md` | Phase 4 design (P4.1): the tick contract and phase order, autoloads and scene tree, ownership map, coupling rules, project settings, verification commands, file map. |
| `P5-VALIDATION.md` | Phase 5 validation (withdrawn pending R8/R9): differential table, playtest checklist, timing, perf, packaging. |
| `DECISIONS.md` | Settled decisions (D-####) and open questions (Q-####), including the current P2.6, P2.8-P2.15 opens and **Q-0034** (tick rate, the one item that affects every timed system). |
| `analysis/notes/` | Per-subsystem dossiers (`p2.1-frameloop.md` ... `p2.15-resources.md`, `p3-assets.md`, `wiki-refs.md`); each P2 note ends with an "Implementation spec for P4". |
| `analysis/` | Inventories (`resources.json`, `extraction.json`, ...), snapshots (gitignored), evidence maps. |
| `evidence/` | Raw REA evidence JSON exports cited by EV IDs. |

## Handover checklist

- [x] Remake scope complete (P4 + P5). Next work is optional: windowed eye-check (P5.2 art),
  REA-only unknowns (see PLAN) and new feature scope.
- [ ] Read `../AGENTS.md` and `PLAN.md`; check `git status` is clean.
- [ ] Read `SPECS.md` and the completion pass in `PLAN.md`; P5 detail is in `P5-VALIDATION.md`.
- [ ] Check the open questions first - Q-0034 (tick rate) affects everything timed.
- [ ] Keep the target read-only; every claim gets an `EV-` entry; correct old EVs with new ones.
- [ ] End the session with: updated `PLAN.md` (statuses, `Last updated`, `Next:`), appended
  `EVIDENCE.md`, `DECISIONS.md` questions, note's P4 spec, saved raw output, and a commit.
