# Evidence ledger (append-only)

Every behavioral claim in this project must trace to an entry here. Never edit or delete past
entries - correct them with a new entry that references the old ID.

## Entry format

```
### EV-NNNN - <one-line claim>
- Date: YYYY-MM-DD
- Type: observation | inference | unknown
- Source: exact command / file / address range (+ REA Evidence ID if any)
- Raw: relative path under docs/evidence/ or docs/analysis/ (if exported)
- Confidence: high | medium | low
- Notes: boundaries of the search, what this does NOT establish
```

Rules: an inference must name the observations it is derived from. An unknown must say what was
searched. Static analysis never proves runtime behavior; mark runtime-dependent claims accordingly.

---

### EV-0001 - Main game executables are byte-identical
- Date: 2026-10-15
- Type: observation
- Source: `Get-FileHash` on both files (see TARGET.md table)
- Confidence: high
- Notes: `Insaniquarium.exe` and `InsaniquariumDeluxe.exe` share SHA-256
  `f54c2c6e...a3ff66`. Analysis of either covers both.

### EV-0002 - Game version is 1.1
- Date: 2026-10-15
- Type: observation
- Source: `readme.html` ("Version 1.1"), `crash.txt` ("Product: Insaniquarium / Version: 1.1")
- Confidence: high
- Notes: Version of the Steam build on disk. Does not establish which upstream build shares code.

### EV-0003 - Shipped crash.txt reports internal module name and DirectX stack
- Date: 2026-10-15
- Type: observation (historical artifact)
- Source: `crash.txt` in install root
- Confidence: high for file contents; the crash itself is not attributed to a current run
- Notes: internal module `popcapgame1.exe`; guard page violation at `004402E0`; Windows NT 6.2
  Build 9200; DDraw/DSound. The internal name is useful for string searches (PopCap build wrapper).

### EV-0004 - Steam build ships loose assets, not pak archives
- Date: 2026-10-15
- Type: observation
- Source: full recursive file listing of the install root
- Confidence: high
- Notes: `images\` (gif/jpg), `sounds\` (ogg/au), `music\` (mo3), `properties\resources.xml`.
  No `.pak`/`.dat` archives observed at any depth. Does not establish that the original retail
  distribution used the same layout.

### EV-0005 - Unexplained per-frame PNG inside images folder
- Date: 2026-10-15
- Type: unknown (origin), observation (existence)
- Source: file listing: `images\guppy_swim1.gif.frames.png` (10,009 bytes)
- Confidence: high that it exists; origin unknown
- Notes: only one `.frames.png` file exists. Could be a shipped quirk or a leftover from an asset
  tool run on this copy. Verify against a fresh Steam install later (Q-0003).

### EV-0006 - bass.dll indicates BASS audio engine usage
- Date: 2026-10-15
- Type: inference from observation
- Source: file listing: `bass.dll` (92,728 bytes) at install root
- Confidence: medium until imports confirm linking
- Notes: To confirm, check `Insaniquarium.exe` imports for `BASS.dll` functions (Phase 1, P1.4).
  Affects how audio behavior maps to Godot (sample formats, stream handling).

### EV-0007 - Secondary local copy's exe and bass.dll are byte-identical to the canonical install
- Date: 2026-10-15
- Type: observation
- Source: `Get-FileHash` (SHA-256) on `C:\Users\Fauzi\Documents\project\Insaniquarium Deluxe\Insaniquarium.exe`
  and `...\bass.dll`
- Confidence: high
- Notes: exe = `f54c2c6e...a3ff66`, bass.dll = `d98cd5d6...61c01` - both match the canonical
  Steam install (TARGET.md). The local copy carries repack wrapper files (revLoader.exe, rev.ini,
  extra Steam client DLLs) but its game binary matches the canonical build. This does NOT establish
  that the remaining asset files in that copy match Steam; only these two files were hashed.

### EV-0008 - PE32 overview: layout, segments, procedure/string counts
- Date: 2026-10-15
- Type: observation
- Source: REA `inspect` (evidence_id `ev_2414058192a3c3f8b5e0778574e1c8ee60aca68fa7ae0782a48aa6b849c50e16`),
  Ghidra 12.1.4; raw: `docs/evidence/p1.4-overview.json`; cold import 123.2 s
- Confidence: high
- Notes: format `pe`, architecture `x86` (32-bit admitted on Windows P0). Image base `0x400000`.
  6 segments: Headers `0x400000-0x401000`; .text `0x401000-0x516000` (1,134,592 B);
  .rdata `0x516000-0x554000`; .data `0x554000-0x5bbce0`; .rsrc `0x5bc000-0x5e5000`;
  `tdb 0xffdff000-0xffe00000` (provider artifact block; meaning not established).
  procedure_count 7,061; string_count 2,496 (Ghidra-defined string Data only - packed/undefined
  string bytes may be absent; completeness applies to that inventory only).

### EV-0009 - Executable references a PDB named DRMProtectRun2.pdb
- Date: 2026-10-15
- Type: observation (PDB reference); inference (its meaning)
- Source: REA `inspect` limitation text, same evidence ID as EV-0008 (`p1.4-overview.json`)
- Confidence: high for the reference; medium for the interpretation
- Notes: RSDS PDB reference `DRMProtectRun2.pdb`, GUID `f484378d-2f07-40d7-828b-7429ae0c47dc`,
  age 1, load state unknown (no PDB on disk). Inference: the executable was produced under a
  build project named "DRMProtectRun2", consistent with PopCap DRM protection tooling. This does
  NOT establish which protection features are active at runtime.

### EV-0010 - Full-tree hash comparison: both installs share byte-identical game data; extras explained
- Date: 2026-10-15
- Type: observation (hashes, timestamps); inference (fragment origin)
- Source: full recursive SHA-256 of both install trees; `Get-Item` timestamps
- Confidence: high
- Notes: Steam copy 660 files, local copy 664. Every path present in both is byte-identical
  (zero mismatches). Only in Steam: `crash.txt` (mtime 12 Aug 2026 15:53), `images\balrog.gif.frames.png`
  and `images\guppy_swim1.gif.frames.png` (both mtime 12 Aug 2026 12:15:16, same second). Only in
  local: repack wrapper files (`revLoader.exe`, `rev.ini`, `ReadMe.txt`, `Steam.dll`, `steamclient*.dll`,
  `steam_appid.txt`). Shipped assets carry 11 Aug 2026 timestamps. User states a prior reverse-engineering
  attempt ran on this machine. Inference: the three Steam-only files are leftovers of that prior
  attempt (batch-written `.frames.png` artifacts; crash log from a later run that day), not shipped
  content. Answers Q-0003. Does NOT prove the Steam install is pristine against an official depot -
  only that it matches the independent mirror for all shared files.

### EV-0011 - Static import table: 10 system DLLs; no bass.dll / ddraw / dsound / steam_api imports
- Date: 2026-10-15
- Type: observation
- Source: `tools\pe-imports.ps1` (engine-free PE import reader); raw: `docs/evidence/p1.4-pe-imports.txt`
- Confidence: high for the on-disk import directory contents
- Notes: imports are WSOCK32.dll (2 ordinals), KERNEL32.dll (136), USER32.dll (74), GDI32.dll (20),
  ADVAPI32.dll (5), SHELL32.dll (1), ole32.dll (4), OLEAUT32.dll (2 ordinals), WININET.dll (7),
  WINMM.dll (3). GDI32 imports are render-shaped (BitBlt, StretchBlt, CreateDIBSection, fonts).
  `LoadLibraryA` is imported but `GetProcAddress` is NOT; no bass/ddraw/dsound/steam_api names
  anywhere in the import dump. Corrects EV-0006 in part: bass.dll is present in the install, but
  the on-disk exe does not statically import it; dynamic resolution remains possible and is P1.6
  scope. Also recorded: REA searches for `BASS_` procedure names and `BASS_\w+` strings returned
  zero matches (`p1.4-bass-procedures.json`, `p1.4-bass-strings.json`; Ghidra-defined inventory only).

### EV-0012 - PopCap/DRM seed strings in .rdata and .rsrc
- Date: 2026-10-15
- Type: observation
- Source: REA string search `popcap` (default case-insensitive literal), 20 matches; raw: `docs/evidence/p1.5-popcap-strings.json`
- Confidence: high for string presence/addresses; no behavior inferred yet
- Notes: highlights - `SOFTWARE\PopCap\` (`0x5331a0`), `?popcapdrmprotect!` (`0x533b74`),
  `?popcapdrmprotend!` (`0x533b88`), BuildInfoMarker string (`0x533ba0`), `popcapgame1.exe` /
  `popcapgame2.exe` / `popcapgame3.exe` (`0x533e18+`; explains crash.txt module name),
  `PopCapDRM_*` API names (`0x53420c-0x5342b8`: EnableLocking, EnableTiming, QueryData, IPC,
  IPC_Response, ForceLock, BuyGame, ShowScreen, WaitUI), `SOFTWARE\PopCapInternal\SteamTest`
  (`0x534a24`), `PopCapSteamDebugQueryMsg` (`0x534ae8`). Seeds for P1.5 provenance and P1.6
  boundary mapping.

### EV-0013 - Engine identified: PopCap SexyAppFramework with Lua binding layer (MSVC RTTI map)
- Date: 2026-10-15
- Type: observation (RTTI/class-name strings); inference (engine identification)
- Source: REA string search `Sexy` (default case-insensitive literal), 322 matches; raw: `docs/evidence/p1.5-sexy-strings.json`
- Confidence: high
- Notes: `.rdata` region `0x5540a4-0x55e828` holds MSVC RTTI type-name strings (`.?AV...@Sexy@@`,
  `. ?AV...@LuaLib@@`) exposing the class architecture. Highlights: `SexyAppBase`, `SexyApp`,
  `LuaApp`, `PopLua`; widgets (`Widget`, `WidgetManager`, `WidgetContainer`, `ButtonWidget`,
  `Checkbox`, `EditWidget`, `ListWidget`, `ScrollbarWidget`, `Dialog`, `HyperlinkWidget`,
  `TextWidget`); Lua wrappers (`LuaWidget`, `LuaImage`, `LuaFont`, `LuaWidgetTpl<T>`,
  `LuaHTTPTransfer`, `MethodWrapper<...>`); graphics (`Graphics`, `Image`, `DDImage`,
  `MemoryImage`, `DDInterface`); text (`Font`, `ImageFont`, `SysFont`, `ActiveFontLayer`);
  audio (`SoundManager`, `DSoundManager`, `SoundInstance`, `DSoundInstance`, `DSoundDecoder`,
  `OggDecoder`); `XMLParser`, `PropertyBag`, `CircularBuffer`, `WinInetHTTPTransfer`,
  `Message`. Also resource-name strings `sexy.Widget`, `sexy.WidgetManager`, `sexy.Graphics`,
  `sexy.PlaySample`, `sexy.WidgetContainer` (`0x5171cc-0x518730`) and runtime message
  `SexyChar sizes do not match with current build and state file: ` (`0x536618`).
  Inference: the game runs PopCap's SexyAppFramework (MSVC C++), with a Lua scripting/binding
  layer, DirectDraw-class and DirectSound-class graphics/audio backends, and an HTTP transfer
  class. Explains WININET/WINMM/gdi32 imports and the MVC architecture to mirror in Godot.

### EV-0014 - PE structure extras: 4 sections, no exports, no delay-load imports
- Date: 2026-10-15
- Type: observation; inference (import-resolution hypothesis)
- Source: extended `tools\pe-imports.ps1` (now also prints sections/exports/delay-loads); raw:
  `docs/evidence/p1.4-pe-imports-ext.txt`
- Confidence: high for the read values; hypothesis explicitly unverified
- Notes: on-disk section table has exactly 4 sections: `.text` VA `0x1000`, VS 1,131,348,
  file offset 0x1000; `.rdata` VA `0x116000`, VS 252,696, off 0x116000; `.data` VA `0x154000`,
  VS 425,184, off 0x154000; `.rsrc` VA `0x1bc000`, VS 167,184, off 0x1bc000. Export directory
  empty (rva 0, size 0); delay-load import directory empty (rva 0, size 0). Therefore the
  absent `GetProcAddress` (EV-0011) is NOT explained by delay loading. Hypothesis (unverified):
  the DRMProtect build resolves dynamic APIs (ddraw/dsound/bass/steam) through a protector-
  embedded resolver and/or a rewritten import table. Follow-up in P1.6/P2.14: locate the
  loader/registration stub in `.text`.

### EV-0015 - Steam integration: legacy Steam.dll API, loaded dynamically
- Date: 2026-10-15
- Type: observation; inference (API generation)
- Source: REA string search `Steam`, 15 matches; raw: `docs/evidence/p1.6-steam-strings.json`
- Confidence: high for strings; medium for which paths are active at runtime
- Notes: matches - `STEAM ERROR` (`0x5330cc`), `Unable to load Steam.dll` (`0x5330d8`),
  `SteamSetUser Failed` (`0x5330f4`), `SteamId` (`0x533548`), `SteamTestUserName` (`0x533558`),
  `-steamuser` (`0x533b68`), `SOFTWARE\PopCapInternal\SteamTest` (`0x534a24`), `steam.dll`
  (`0x534a54`), `SteamStartup` (`0x534a60`), `SteamBlockingCall` (`0x534a70`),
  `SteamIsAppSubscribed` (`0x534a84`), `SteamSetUser` (`0x534a9c`), `SteamCleanup` (`0x534aac`),
  `Failed to startup Steam: %s` (`0x534abc`), `PopCapSteamDebugQueryMsg` (`0x534ae8`).
  Inference: integration uses Valve's pre-`steam_api.dll` `Steam.dll` API (Startup/BlockingCall/
  IsAppSubscribed/SetUser/Cleanup are exports of that library), dynamically loaded at runtime.
  `SteamIsAppSubscribed` indicates the entitlement check; `-steamuser` is a command-line switch.
  Explains why the repack folder bundles old Steam client DLLs.

### EV-0016 - Embedded Lua is version 5.0.2
- Date: 2026-10-15
- Type: observation
- Source: REA string search `Lua 5`, 2 matches; raw: `docs/evidence/p1.5-lua-version.json`
- Confidence: high
- Notes: `0x535b40`: `$Lua: Lua 5.0.2 Copyright (C) 1994-2004 Tecgraf, PUC-Rio $` (+ Authors/URL
  lines); `0x536ebc`: `Lua 5.0.2`. The scripting layer (LuaLib/PopLua per EV-0013) is Lua 5.0.2 -
  fixes the language semantics baseline for any script-driven behavior in later phases.

### EV-0017 - `drmss.jpg` is referenced by the DRM string cluster
- Date: 2026-10-15
- Type: observation
- Source: REA string search `drmss`, 1 match; raw: `docs/evidence/p1.6-drmss.json`
- Confidence: high
- Notes: `0x5331f4`: `drmss.jpg` - inside the same `.rdata` cluster as `SOFTWARE\PopCap\`
  (`0x5331a0`) and the `?popcapdrmprotect!` markers (`0x533b74/0x533b88`). The root `drmss.jpg`
  image is loaded by the DRM subsystem (likely the DRM/entitlement splash screen asset).

### EV-0018 - Asset inventory: 495 files; naming conventions; 30-pet select set
- Date: 2026-10-15
- Type: observation
- Source: recursive listing of `images/`, `sounds/`, `music/`; raw: `docs/evidence/p1.7-assets-raw.txt`,
  base-name set: `docs/evidence/p1.7-asset-names.txt`
- Confidence: high
- Notes: 495 files total: 390 `.gif`, 50 `.ogg`, 35 `.jpg`, 15 `.au`, 3 `.mo3`, 2 `.png`
  (the 2 PNGs are the known prior-attempt leftovers, EV-0010). Naming: lowercase; trailing `_`
  marks alpha/mask companions (e.g. `mainbutton_`); `N`-suffix = animation frame variants
  (`guppy_swim1..3`); `scl_<pet>` = pet-select icon set (30 names).

### EV-0019 - Bounded negatives: game-content names are NOT in the exe string inventory
- Date: 2026-10-15
- Type: observation (bounded searches); inference (data-driven content)
- Source: three REA searches; raw: `docs/evidence/p1.7-creatures.json`,
  `docs/evidence/p1.7-aliens-save.json`, `docs/evidence/p1.7-bass-literal.json`
- Confidence: high for the negatives within the Ghidra-defined inventory
- Notes: (1) regex `guppy|carnivore|ultravore|breeder|starcatcher|prego|scl_|<30 pet names>` = 0
  matches. (2) regex `balrog|...|sylv|simcarnivore|userdata|savegame|highscore|cheat|timetrial|challenge`
  = 13 matches, ALL false positives: 7 MSVC CRT strings (`...vector destructor iterator`,
  `dynamic atexit destructor for`, etc. at `0x53270c-0x532a08`) and 6 Lua runtime strings
  (`userdata`, `lightuserdata`, `UserData@%p`, `LightUserData@%p`, `userdata: %p`). (3) literal
  `bass` (case-insensitive) = 0 matches. Inference: game content names/parameters live in data
  files (`properties\resources.xml`), not in exe strings; and `bass.dll`/BASS symbols are never
  plain strings - loading mechanism still unknown (P2.14).

### EV-0020 - `drm\` subsystem on disk: config XMLs, DRM images, compiled custom Lua scripts
- Date: 2026-10-15
- Type: observation
- Source: file inventory + header read of `drm\common\scripts\DRMApp.luc`
- Confidence: high for files/bytes; variant interpretation marked unknown
- Notes: contents: `drm\common\drm.xml` (6,790 B) + `.sig`, `drm\custom\drm.xml` (904 B) + `.sig`,
  `drm\game.png`, `drm\logo.png`, `drm\common\fonts\` (5 Arial `.txt` + 5 `.png`), and
  `drm\common\scripts\` with 14 `.luc` files: main, DRMApp, Game, Screen, Layout, LuaApp,
  LuaWidget, LuaCommonWidgets, Common, Consts, DProps, Default, Bullets, ClassLink. `.luc` files
  are binary; first bytes of DRMApp.luc: `1B 4C 75 61 56 01 02 04 04 04 06 08 09 09 08 B6` =
  `ESC "LuaV"` - NOT a stock Lua 5.0 (`50`) or 5.1 (`51`) bytecode header; custom/obfuscated
  variant (exact format unknown). Inference: the DRM/wrapper UI is implemented as a Lua-scripted
  app (matches `LuaApp`/`LuaWidget`/`LuaWidgetTpl` RTTI, EV-0013).

### EV-0021 - `properties\partner.xml`: 640x480 confirmed, Steam appid 3320, screensaver exe
- Date: 2026-10-15
- Type: observation
- Source: direct file read (`properties\partner.xml`, 589 B)
- Confidence: high
- Notes: `Width 640`, `Height 480` (confirms the pixel policy answer Q-0005 against game data);
  `SteamId 3320`; `Steam` partner; `ProdName Insaniquarium`; `DisplayName Insaniquarium Deluxe`;
  `ScrExe WinFish_Scr.exe`; `RegistryKey PopCap\Insaniquarium`; `NoReg true`, `DontUpdate true`
  (Steam build disables registration nag and updater); `VistaCompliant true`; `Offering 15`.

### EV-0022 - `resources.xml` manifest: 333 IDs; full pet/alien/tank rosters; animation geometry
- Date: 2026-10-15
- Type: observation
- Source: direct file read (`properties\resources.xml`, 21,253 B, 391 lines; 333 `id=`
  attributes counted across groups Init/Register/LoadingThread)
- Confidence: high
- Notes: ROSTERS - pets (30, from `SCL_*` set): Stinky, Niko, Itchy, Prego, Zorf, Clyde, Vert,
  Rufus, Meryl, Wadsworth, Seymour, Shrapnel, Gumbo, Blip, Rhubarb, Nimbus, Amp, Gash, Angie,
  Presto, Brinkley, Nostradamus, Stanley, Walter, Oscar, Grubber, Starcatcher, Gekko, Breeder,
  Ultra(vore). Aliens/boss (9, `<!-- aliens -->` block): Sylvester (`SYLV`, `MINISYLV`), Balrog,
  Gus, Destructor, Ulysses, Psychosquid, Bilaterus, Boss. Tanks: `AQUARIUM1-6` + `TANKMASK1-6` +
  `TANKBACKDROP1-6` (six sets). Fish families: `SIM{SWIM,EAT,TURN}1-3` (guppy stages by size),
  `SMALL*`, `HUNGRY*` (hungry/carnivore visuals), `SIMCARNIVORE`, `BREEDER`, `ULTRA`,
  `STARCATCHER`. Per-image animation geometry present as attributes: `cols`, `rows`, `framemap`,
  `framedelay`, `begindelay`, `anim` (loop/once/pingpong), `alphaimage` (mask companion),
  `ddsurface` (DirectDraw surface flag; used by AQUARIUM1-6), `perframedelay`. Sounds: 68
  entries (`SOUND_*`) with `volume`/`alias` options. Screens: `TITLEPAGE`, `SELECTORSCREEN`,
  `STORESCREEN`, `HATCHSCREEN`. Seeds P2.2-P2.12 (systems), P3.1/P3.2 (pipeline).

### EV-0023 - `drm\custom\drm.xml` content: marketing bullets, Steam store link
- Date: 2026-10-15
- Type: observation
- Source: direct file read (`drm\custom\drm.xml`, 904 B)
- Confidence: high
- Notes: bullet marketing strings for the DRM/upsell screen ("4 tanks with secret pets and
  amazing new bosses!", "Challenge mode or beat the clock in Timed!", "Earn shells and customize
  your own Virtual Tank screensaver!"); `BuyURL` = `steam://store/3320`; content descriptors
  ("Animated Blood", "Mild Cartoon Violence", "Suggestive Themes"); CopyrightDisclaimer
  "(c)2002 PopCap Games, Inc.". Context for the DRM UI seen in EV-0017/EV-0020.

### EV-0024 - `resources.xml` parsed to a machine-readable inventory; syntax quirks; count corrections
- Date: 2026-10-15
- Type: observation
- Source: `tools\parse-resources.ps1` against canonical `properties\resources.xml` (read-only);
  raw: `docs\analysis\resources.json`
- Confidence: high
- Notes: 326 resource elements: 246 Image, 15 Font, 65 Sound; groups Init=14, Register=16,
  LoadingThread=296. Corrects EV-0022 counts: the "333 `id=` attributes" figure was a regex
  artifact (329 true element ids: 326 resources + 3 group ids; 4 extra matches were the tail of
  `alphagrid="`); Sound entries are 65, not 68. Manifest syntax quirks (accepted by the game's
  SexyApp XMLParser, rejected by strict parsers): 5 unquoted attribute values (`cols=3` x4,
  `cols=4` x1) and 6 bare boolean attributes (`ddsurface` on AQUARIUM1-6). Pet roster (30 SCL_*),
  aliens (9) and tank sets (6) match EV-0022.

### EV-0025 - Manifest-to-disk resolution: all entries resolve; 14 need underscore-variant files
- Date: 2026-10-15
- Type: observation (disk files); inference (engine fallback hypothesis)
- Source: `tools\parse-resources.ps1`; raw: `docs\analysis\resources.json`
- Confidence: high for the on-disk facts; engine behavior explicitly unverified
- Notes: resolution is case-insensitive (`Aquarium5.jpg` etc.) and probes .gif/.jpg/.png.
  312/326 entries resolve by plain name; 14 Image entries have no plain-name file on disk:
  TANKMASK1-6 -> `_maskN.jpg` (leading underscore), HATCHREFLECTION -> `_IncubatorReflection.gif`,
  MENUBUTTONREFLECTION -> `_MBREFLECTION.gif`, TITLEPAGEMASK -> `titlescreenmask_.gif`
  (trailing), PETBUTTONREFLECT -> `petbuttonreflect_.gif`, PETBUTTONHOLE -> `petbuttonhole_.gif`,
  STORELEFTHILIGHT/STORETOPHILIGHT/STORERIGHTHILIGHT -> `*_.gif`. Hypothesis (UNVERIFIED): the
  engine resolves these via the same underscore fallback; needs P2/P4 confirmation. Seven
  unreferenced asset files exist: the two prior-attempt leftovers (EV-0010),
  `images\nebula1.jpg`, `images\talkshow.jpg` (use unknown), and `music\Alien.mo3`,
  `music\Insaniq2.mo3`, `music\Lullaby.mo3` (music is not in the manifest).

### EV-0026 - Alpha model: grayscale mask companions; base GIFs are alpha-free except 3
- Date: 2026-10-15
- Type: observation; inference (composition semantics)
- Source: `tools\inspect-images.ps1` (System.Drawing pixel reads); raw:
  `docs\analysis\p3.2-image-report.json`
- Confidence: high for the file/pixel facts; composition is an inference
- Notes: 204/246 images have a literal mask file (17 explicit: MAINBUTTON/LEFTBUTTON/RIGHTBUTTON/
  CENTERBUTTON via `alphagrid`, MENUBTND2 via `alphaimage`, TANKBACKDROP1-6, EGGBRINKLEY/
  EGGNOSTRADAMUS/EGGSTANLEY/EGGWALTER, AA_TOP1/AA_TOP2; 187 matched via leading/trailing
  underscore candidates). Masks are 100% grayscale except `bonusbuttonoverlay_.gif` (245x69) and
  `bubbulator_.gif` (71x1840). 243/246 base images contain zero transparent pixels - alpha must
  come from the mask layer. Exceptions with built-in GIF transparency: SLIDERTHUMB
  (`SLIDERWIDGET.gif`, 132 px), HELPALIEN (763 px), HELPPETCHOOSE (300 px). `alphagrid` mask files
  are one grid cell in size (mainbutton 270x29 base vs 90x29 mask; left/right/center 189x29 vs
  63x29). Unexplained mismatch: EDITBOX 90x42 vs `_EditBox.gif` 96x33. TANKMASK1-6 base files are
  themselves grayscale 640x80 (`_maskN.jpg`). Inference (unverified): the engine composites the
  mask as alpha and may colorize grayscale art at runtime (see EV-0027).

### EV-0027 - Frame geometry: exact declared grids; 80x80-cell convention; sim-fish two-layer art
- Date: 2026-10-15
- Type: observation; inference (grid for undeclared sheets)
- Source: `tools\inspect-images.ps1`; visual inspection of `guppy_swim1.gif`, `_guppy_swim1.gif`
  via image viewer; raw: `docs\analysis\p3.2-image-report.json`
- Confidence: high for declared grids/dims; medium for the inferred 10x80px grid on undeclared sheets
- Notes: every declared grid divides its image exactly (0 remainder issues across 246 images).
  Character/effect sheets use 80x80 px cells; declared examples: STINKY 10x3, HUNGRYSWIM 10x5,
  GEKKO 10x7 (all 800 px wide). 30 sheets have NO declared grid but are multi-cell:
  SIMSWIM/SIMEAT/SIMTURN 1-3 are 800x240 (10x3), SMALLTURN/SMALLEAT/SMALLDIE/HUNGRYTURN/
  HUNGRYEAT are 800x400 (10x5), SIMCARNIVORE and HUNGRYBREEDER are 800x960 (10x12); the
  prior-attempt leftover `guppy_swim1.gif.frames.png` independently shows the same 10x3 eye
  layout (EV-0010). Observed two-layer art for the sim fish: base sheet holds eyes only on black
  (e.g. `guppy_swim1.gif`: 10x3 eyes), companion mask holds 3-size body silhouettes
  (`_guppy_swim1.gif`); SIMSWIM2/3, SIMEAT2/3, SIMTURN2/3 have no mask file on disk. 36 base
  images are grayscale-only (SPARKLE, ENERGYBALL, LASERS, SMOKEMISSILE, MISCITEMS, WAVESIDE,
  WAVE, SIM* sheets, TANKMASK1-6, TITLEPAGEMASK, shadow/reflection masks-as-images, TANKLIGHTING,
  GUMBOLIGHT, BLANK/PEANUT). Inference (unverified, needs P2): grayscale art is colorized at
  runtime (laser upgrade colors, wave tints). Does NOT establish runtime composition, tint
  colors, or animation semantics (framemap `-1` meaning remains unknown).

### EV-0028 - P3.3 extraction: 244 base + 179 mask PNGs + 3,036 frames, pixel-exact
- Date: 2026-10-15
- Type: observation
- Source: `tools\extract-assets.ps1`; outputs under `assets_raw\` (gitignored: personal-use
  assets, Q-0006; regenerable); manifest: `assets_raw\extraction.json`
- Confidence: high
- Notes: 244 base PNGs written (246 Image records, 2 aliases deduped: PEANUT=blank,
  MENUBTND2=mbuttond), 179 unique mask PNGs (shared masks deduped; 14 self-masks skipped:
  TANKMASK1-6 and the underscore-only entries where base file = mask file), 3,036 frame PNGs
  across 129 multi-cell sheets (3036 = declared grids + 16 inferred 10x(h/80) grids on
  undeclared 800-px sheets). Total 3,460 files / 22.0 MB. Pipeline: GDI+ (System.Drawing)
  32bppArgb, DrawImageUnscaled (no resampling), frames cropped by exact cell rects. Fidelity
  check: SIMSWIM1 frame f013 vs source `guppy_swim1.gif` region (240,80)-(320,160) = 0/6,400
  differing pixels. Frames keep color and alpha layers UNCOMPOSITED (decision in
  `docs\analysis\notes\p3-assets.md`); masks exported as whole sheets, not per-frame.

### EV-0029 - P3.4 outcome: the two `*.gif.frames.png` leftovers are plain GIF->PNG conversions
- Date: 2026-10-15
- Type: observation
- Source: full-pixel comparison (System.Drawing LockBits) of leftovers vs source GIFs in the
  canonical install (read-only)
- Confidence: high
- Notes: `guppy_swim1.gif.frames.png` = 800x240, 0/192,000 differing RGB pixels vs
  `guppy_swim1.gif`; `balrog.gif.frames.png` = 1600x320, 0/512,000 differing RGB pixels vs
  `balrog.gif`. Despite the ".frames" name they contain no slicing/rearrangement - the prior
  attempt (EV-0010) performed straight format conversion only. Corroborates Q-0003's answer;
  the files are ignored by this pipeline (not referenced by the manifest, EV-0025).

### EV-0030 - P3.5 Godot import: 129 SpriteFrames resources generated and verified
- Date: 2026-10-15
- Type: observation
- Source: `tools\godot\gen_spriteframes.gd` run via
  `Godot_v4.7.1-stable_win64.exe --headless --path . --script ...`; inputs:
  `assets_raw\extraction.json`; outputs: `resources\sprites\<ID>.tres`; Godot import of
  `assets_raw` = 423 files (244 images + 179 masks; `frames\` excluded via `.gdignore`)
- Confidence: high (generator self-verifies every resource; exit 0)
- Notes: one SpriteFrames per multi-cell image: animation `default`, frames are AtlasTexture
  regions (pixel rects) over the sheet PNG in `assets_raw\images\`; framemap order applied when
  declared (MERYLBLINK = 5 frames from `0,1,2,1,0,-1` with -1 skipped; MERYLTAIL reversed).
  129 generated / 129 re-loaded + frame-count verified / 0 failures; 3,038 total frames;
  resources total 648 KB. Atlasing is region-based (AtlasTexture) - no repacking; masks are
  imported as separate textures for P4 composition. Animation speeds/delays are NOT baked: the
   manifest delay units are unresolved until P2.1; raw attrs remain in `extraction.json`.

### EV-0031 - P3.6 sound extraction: 50 `.ogg` copied + 15 `.au` decoded to WAV, all probe-verified
- Date: 2026-10-15
- Type: observation
- Source: `tools\extract-audio.ps1` run against `docs\analysis\resources.json` + canonical install;
  outputs: `assets_raw\sounds\` (50 `.ogg` + 15 `.wav`) + `assets_raw\audio.json`
- Confidence: high (manifest lists 65 sounds; 65 outputs; every output re-probed, 0 failures)
- Notes: `.ogg` copied 1:1 (manifest-named stems); all 15 `.au` are `pcm_mulaw` 8,000 Hz mono
  (verified by ffprobe; e.g. `sounds\buttonclick.au`) converted with
  `ffmpeg -c:a pcm_s16le` to WAV - exact command per file recorded in `audio.json`. Total output
  752,298 bytes; manifest `volume`/`alias` attrs preserved into `audio.json` (e.g. AWOOGA
  alias=START). Install holds exactly 50 ogg + 15 au under `sounds\` (recounted).

### EV-0032 - P3.7 music: 3 `.mo3` decoded to OGG via ffmpeg libopenmpt; BASS route abandoned
- Date: 2026-10-15
- Type: observation
- Source: `tools\decode-music.ps1` run against `music\*.mo3` in the canonical install; outputs:
  `assets_raw\music\{Alien,Insaniq2,Lullaby}.ogg` + `assets_raw\music.json`; tooling decision D-0006
- Confidence: high (ffprobe identifies all 3 sources as `libopenmpt` demuxer, `TAG:encoder=MO3 v1`;
  3/3 outputs re-probed, 0 failures)
- Notes: the ffmpeg 8.1.1 build carries libopenmpt, so `.mo3` needs no x86 BASS P/Invoke; the
  earlier plan (the P3.7 route via bass.dll exports) was retired - `tools\pe-imports.ps1` fails on
  `bass.dll` with an ArgumentOutOfRangeException (import-walk bug for that DLL; the exe import
  audit, EV-0011, is unaffected). Per-file facts: Alien.mo3 61,564 B
  sha256=677773BFD665339D1DCA8DAA0B584E94E3FC434CEC0FE43DDBED8CC74162F393, tag title
  "Alien Battle Music", 10.240 s; Insaniq2.mo3 334,214 B
  sha256=4F78284DD170EE2AC97BE94573287CC6473EFAD9479FA4B833FB224D47FBD9D2, title "Winfish",
  113.664 s; Lullaby.mo3 8,520 B sha256=7A13CDDFC9FF37AB7B248E9EF41A91121983CDB8A19BDC3FDF4C4A435E64E314,
  no title, 115.700 s. Encoded `libvorbis -q:a 5`, 48,000 Hz stereo; total output 2,718,641 bytes;
  ogg durations read ~0.1 s longer than source probes (decoder padding; tracker loop semantics
  unresolved, P2.14 concern).

### EV-0033 - P3.8 fonts/UI/cursor: 15 bitmap fonts parsed and converted, verified in Godot
- Date: 2026-10-15
- Type: observation
- Source: `tools\convert-fonts.ps1` (inputs: `docs\analysis\resources.json` + `data\*.txt`/`*.gif`
  in the canonical install) and `tools\godot\verify_fonts.gd`; outputs: `assets_raw\fonts\`
  (15 x `<ID>.fnt` + `<ID>.png` + `raw\` layers) + `assets_raw\fonts.json`; decision D-0007
- Confidence: high (atlas choice validated by rect-extent fit on all 15; every font re-loads in
  Godot with all expected chars present; verifier exit 0)
- Notes: descriptor format decoded: `Define` blocks CharList/WidthList/RectList/OffsetList/
  KerningPairs/KerningValues (cp1252) + trailer commands `LayerSetImage` (atlas name),
  `LayerSetAscent` (baseline), `LayerSetCharWidths Main (' ') (N)` (explicit space width 3-10 px;
  space is NOT in CharList), `LayerSetAscentPadding`, `LayerSetLineSpacingOffset`, `PointSize`.
  Atlas resolution: 5 fonts use `data\<name>.gif` (JungleFever 10/12/15/17outline,
  ContinuumBold12outline), 10 resolve via the underscore name (`_<name>.gif`); all 15 glyph-rect
  extents (+offsets) fit their atlas exactly (maxExtent = atlas size - 1..2 px). On the 5
  two-file fonts, base = thin fill layer and mask = expanded silhouette (JungleFever10outline
  first 140 columns: base ink 484 px vs mask 728 px; "outline text" = tinted fill + dark ring).
  Kerning: pairs are 2-char strings with backslash-escaped quotes (e.g. `"\",","\".` ->
  ('"',','),('"','.')); BlambotPro8 has 155 pairs once unescaped; 6 fonts (ContinuumBold12,
  ContinuumBold12outline, ContinuumBold14, ContinuumBold14outback, Pix118, Pix118Bold) contain no
  kerning sections at all. Totals: 1,788 glyphs, 813 kerning pairs, 327 KB output. Three fonts
  genuinely lack glyphs: ContinuumBold12outline (no `{`,`}`,`~`), ContinuumBold14 and
  ContinuumBold14outback (no `{`,`}`). Godot verification: 15/15 load as FontFile, 1,803 per-font
  char checks (all expected codes + space), all sample string widths > 0, exit 0. Cursors:
  manifest `CURSOR_POINTER/HAND/DRAGGING/TEXT` + `CROSSHAIR` (and `HELPARROW` = `arrow1.gif`) are
  plain manifest Images already extracted pixel-exact in P3.3 - no conversion needed; P4 assigns
  them via custom mouse cursors. Outside the manifest, `drm\common\fonts\` holds 5 more Arial
   descriptors + underscore-only PNG atlases (DRM dialog layer, EV-0020) - inventoried, NOT
   converted (DRM dialogs are out of remake scope unless P2.13 says otherwise).

### EV-0034 - P2.1: main loop is a fixed-timestep 10 ms (100 Hz) loop in SexyAppBase::Process
- Date: 2026-10-15
- Type: observation (assembly/pseudocode); inference (object-layout naming)
- Source: REA `decompile`/`instructions`/`function` on canonical exe:
  `FUN_0049f1b4` (`0x49f1b4`), ctor `FUN_004a259f` (`0x4a259f`, inline `0x4a26af`);
  raw: `docs/evidence/p2.1-process-instructions.json`, `p2.1-setter-4a26af.json`
- Confidence: high for instructions/constants; naming follows SexyAppFramework conventions
- Notes: loop reads `interval = this+0x44`, `last = this+0x50`, clock = `timeGetTime` (IAT
  `0x5163f8`); per pass runs at most 10 updates; each update: if `now - last < interval` call
  virtual `[EAX+0x1c]` (site `0x49f344`), advance `last += interval`, clamp `last = now - 1000`
  when behind >1000 ms, increment frame count; else catch-up `Sleep(interval - (now - last))`
  when `[this+0x6e]` set. Ctor sets `this+0x44 = 10` (`MOV dword ptr [ESI+0x44], 0xA` @
  `0x4a26af`) -> **10 ms tick (100 logic updates/s)**; `this+0x40 = 0`; `this+0x70 = 0.85`
  double read from `0x51bf00` (update multiplier); `this+0x10/0x14 = 0x280/0x1e0` (640x480).
  Driver: DRM wrapper WinMain `FUN_004067cd` (`0x4067cd`) calls `FUN_0049f1b4(DAT_0055fbc0)`
  after each message dispatch. Does NOT establish the Lua-side per-frame hook or the runtime
  cadence on original hardware.

### EV-0035 - P2.1: FPS overlay computes frames-per-1000ms (IMUL 0x3e8); debug string `FPS: %d`
- Date: 2026-10-15
- Type: observation
- Source: REA `search`/`decompile`/`instructions`: string `FPS: %d` at `0x51bdec` (the only
  "fps" string hit); draw `FUN_0049fdf1` (`0x49fdf1`), xref site `0x49ff64`; raw:
  `docs/evidence/p2.1-fps-strings.json`, `p2.1-fps-draw.json`, `p2.1-fps-instructions.json`
- Confidence: high
- Notes: global frame counter `DAT_0055fbb8` (incremented per Process pass), reset every
  1000 ms; FPS = `IMUL EAX,EAX,0x3e8` (x1000) / elapsed seconds (`0x4beb79` perf timer),
  `FADD 0.5` (`0x539e78` double), int; drawn via `FPS: %d`. The 1000 ms threshold is baked in
  FPU code - no stored 1000.0 double/float anywhere in the image (bounded negative: full-file
  search for `00 00 00 00 00 00 8F 40` and `00 00 7A 44` = 0 hits). Overlay gated by byte
  `DAT_0055fbc8`; exact enable point not yet located.

### EV-0036 - P2.1: timing primitives - QueryPerformanceCounter timer class + timeGetTime
- Date: 2026-10-15
- Type: observation
- Source: REA `instructions`/`decompile`; raw: `docs/evidence/p2.1-timer-primitive.json`,
  `p2.1-timer-query.json`
- Confidence: high for the routines; medium for class-identity naming
- Notes: perf timer reset `FUN_004beb59` sets `[this+0x10] = 1` and calls
  `QueryPerformanceCounter` (IAT `0x5160e0`); elapsed `FUN_004beb79` returns double seconds at
  `[this+0x8]` (lazy init via `0x4beb0f`). Loop clock = WINMM `timeGetTime` (IAT `0x5163f8`).
  `Sleep` IAT = `0x5161ec`; all `Sleep(1)` call sites resolved: `0x413ff5`/`0x41417a` (HTTP
  transfer thread wait loops), `0x49dbe9` (worker thread spawn), `0x49f395` (Process catch-up,
  see EV-0034); CRT `__malloc_crt` retry sleep chain at `0x4f2220+`. No DDraw/DSound timing.
  Vtable anchors observed: arrays in `.rdata` at `0x516804`, `0x51be94`, `0x51bf3c`, `0x534934`
  contain `FUN_004a002d` (frame gate); `SexyApp` vftables at `0x51bf1c`/`0x51bf0c` (from
  `0x4a2a5f`), `SexyAppBase` at `0x51bd5c`/`0x51be74`/`0x51be68` (from
  `0x4a259f`).

### EV-0037 - Wrapper PE resources hold no scripts: DRM metadata + UI only
- Date: 2026-10-16
- Type: observation
- Source: REA `inspect-pe-resources` on the canonical wrapper exe; raw:
  `docs/evidence/p2.2-pe-resources.json`
- Confidence: high
- Notes: 18 resources total: custom `DATA/__GDF_XML` (3,280 B - DRM "Game Definition File"
  XML), 12x `RT_ICON`, `RT_MENU`, `RT_DIALOG`, `RT_GROUP_ICON` (IDI_MAIN_ICON), `RT_VERSION`,
  `RT_MANIFEST`. No RCDATA / script / Lua payloads of any size; rules out PE-resource storage
  for a gameplay script layer. (`crash.txt` identifies the image as module `popcapgame1.exe`,
  per EV-0010.)

### EV-0038 - `drm\common\scripts\*.luc` = wide-string Lua 5.0.2 bytecode; DRM wrapper app only
- Date: 2026-10-16
- Type: observation
- Source: byte-level header reads + full-file wide-string extraction over the 14 `.luc` files
  in `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe\drm\common\scripts\`; wrapper-exe
  string search (REA) for `\drm\common\scripts\main.lua` etc. Extracted wide strings (1,060):
  `docs/evidence/p2.2-luc-strings.txt`, cross-checked against the module string inventory
  `docs/evidence/p2.2-game-module-strings.txt`
- Confidence: high for format and for "wrapper-only" scope; medium for exact VM dialect
- Notes: every `.luc` begins `1B 4C 75 61` + version byte `0x56` (non-stock 5.0.2 = `0x51`),
  format byte `0x01`; all embedded strings, including source names (`@common\scripts\Game.lua`,
  `main.lua`, ...) are UTF-16LE, so this is a **wide-string rebuild of Lua 5.0.2**. String
  vocabulary is exclusively e-commerce/DRM app content: TrialScreen/BuyScreen/ExpireScreen,
  `CheckSignature`, `drm.xml`, `gCheckSignatures`, LuaWidget/Layout/DProps/Bullets framework -
  no fish/tank/game vocabulary. Wrapper exe host string: `\drm\common\scripts\main.lua`
  @ 0x534884; Lua console/error strings at 0x535b40/0x535d48/0x535fec. Refines EV-0020/EV-0023
  (compiled Lua layer) and EV-0019 (game vocabulary absent from the outer image).

### EV-0039 - Canonical exe is a dual image: DRM wrapper + embedded full game module
- Date: 2026-10-16
- Type: observation
- Source: PE section parse + byte reads of the canonical exe; deterministic carving via
  `tools\extract-game-module.ps1`; string verification against
  `docs\evidence\p2.2-game-module-strings.txt`; fresh REA string search over the whole wrapper
  image (`docs/evidence/p2.2-gamewords-strings.json`)
- Confidence: high
- Notes: outer PE has 4 sections ending at file 0x188000; the trailing 0x214C38 bytes are an
  overlay starting with ASCII `!popcapdrmprotect!` at 0x188000. A complete PE32 image starts at
  file 0x1881A2 (MZ, e_lfanew 0xF0, ImageBase 0x400000, entry RVA 0x167F2E) and extends to EOF:
  **2,181,782 bytes**, SHA-256
  `33f34bae5eeee213c2a3819a13a4515c99a357f4247d42e5314da20621efe2c4`; sections `.text`
  0x401000 (VS 0x1948FC), `.rdata` 0x596000 (0x481DC), `.data` 0x5DF000 (0x43B9C), `.rsrc`
  0x623000 (0x28B44). Game text lives here: "Fish are about to die of hunger! Click on
  aquarium!" @ module 0x598D14, pet bios, `IMAGE_*`/`SOUND_*` ids. The wrapper image itself has
  0 hits for the fish/pet vocabulary. Carved read-only copy:
  `docs\analysis\snapshots\insaniquarium-game-module.exe` (gitignored). Install untouched
  (D-0004, Q-0006).

### EV-0040 - Game module Ghidra overview (new snapshot `insaniquarium-game-module`)
- Date: 2026-10-16
- Type: observation
- Source: REA `analyze` on the module; raw: `docs/evidence/p2.2-game-module-analyze.json`;
  snapshot: `docs/analysis/snapshots/insaniquarium-game-module.json`
- Confidence: high
- Notes: 4 RAM segments (headers + .text/.rdata/.data/.rsrc); procedure_count 9,407;
  string_count 4,021 (Ghidra-defined string data - not the full inventory; a byte-level local
  scan found 17,849 strings >= 4 chars with VA mapping in
  `docs/evidence/p2.2-game-module-strings.txt`). All module queries reuse this snapshot.

### EV-0041 - Game-module MSVC RTTI map: 218 classes / 251 vtables (tool + TSV)
- Date: 2026-10-16
- Type: observation (addresses deterministic); inference (slot roles until decompiled)
- Source: `tools\rtti-classmap.ps1` (byte-level chain: name string -> TypeDescriptor
  `{vftable, spare=0, name inline at +8}` -> CompleteObjectLocator -> vtable with
  `vtable[-4] = COL`); output: `docs/evidence/p2.2-module-rtti-classes.txt`; cross-ref string
  inventory `docs/evidence/p2.2-game-module-strings.txt`
- Confidence: high for class addresses; medium for slot semantics
- Notes: 218 classes / 218 descriptors / 1054 locators / 251 recovered vtables. Selected
  (vtable = slot-0 address): `GameObject` 0x596844, `Fish` 0x597D54 (desc 0x5DF768),
  `DeadFish` 0x597BFC, `Food` 0x59817C, `Coin` 0x597964, `Alien` 0x59740C, `Breeder` 0x597814,
  `Grubber` 0x59698C, `Larva` 0x596AD4, `Missle` 0x596C1C, `Penta` 0x596EE4, `Shadow` 0x59702C,
  `Shot` 0x597174, `Warp` 0x5972C4, `Ultra` 0x59872C, `Gekko` 0x5982C4, `Oscar` 0x59843C,
  `SylvesterFish` 0x5985BC, `FishTypePet` 0x597EC4, `BubbleMgr` 0x59D5B4, `TankScreen` 0x5A18B0
  (7 slots) + 0x5A18D4 (64 slots). Screens (Title/Store/Hatch/Pets/SimFish/Help/HighScore/
  Interlude/Story/Bonus/SimSetup) and widgets (FishButtonWidget/PetButtonWidget/MoneyDialog/
  PetDialog/FishNamingDialog/...) also mapped. Refines EV-0009/EV-0013 (wrapper RTTI) with the
  actual game class map. Tool caveat: slot walk capped at 64.

### EV-0042 - P2.2: `Fish::Update` (slot 22 = 0x4F6970) + hover/facing slot 26 (0x4E4A90)
- Date: 2026-10-16
- Type: observation (pseudocode/constants); inference (field naming, path semantics)
- Source: REA `function` on module: `docs/evidence/p2.2-fish-4F6970.json` (6.1 MB dossier) and
  `docs/evidence/p2.2-fish-4E4A90.json`; vtable identity from EV-0041; full anatomy in
  `docs/analysis/notes/p2.2-tank-sim.md` (sections 4-6)
- Confidence: high for code/constants; medium for names
- Notes: `Fish` (vtable 0x597D54) overrides slots 0 (0x4F0CB0), 22 (0x4F6970, 4,440 B, 0 call
  sites - vtable-only), 26 (0x4E4A90, 381 B) vs `GameObject`; `Ultra` inherits 22/26, `DeadFish`
  22=0x4F64E0, `Food` 22=0x4F8AA0, `Coin` 22=0x4F5050. Doubles: x@+0x158, y@+0x160 (+y down),
  vx@+0x168, vy@+0x170, speed divisor@+0x180; ints: x/y@+0x30/+0x34, tank*@+0x88 (manager
  +0x730; pause +0x94), bounds x@+0x194/+0x19C, y floor@+0x198, ceiling@+0x190; swim mode
  @+0x1AC (0-4, 0x7B) with 30/39/40/50-frame timers, per-40-frame vel steps (±0.5/±1/±1.3),
  mode presets vy +0.5 / -8.0, drag 0.95, wall bounce margins 20, `y>240 → mode 0`; random mode
  reroll ~10 % per 20 frames; food-approach steering (dead bands ±5/±10 px: vx steps ±0.05/±0.2/
  ±1.3 cap ±4, vy aim = food.y - 20, steps 0.7/-0.5/1.3/-1.0, caps +4/-3) gated by target
  predicate (manager+0x174) + flag +0x229; cursor/global attractor path via `DAT_005e89d0`/
  `DAT_005e89d4`/`DAT_005e89d8` (direct move, dead zone ±5, band ±50). Slot 26: hover check vs
  the same globals (±8 px) toggling a double flag on `this[0x25]+0x168` (0/1), then virtual
  slot 83 (`*this+0x14c`)(arg, flip) with flip from `+0xF5` or facing `[0x71]`; extra call
  `FUN_004e1400(arg, 0)` when `+0xC4` set - candidate: draw with flip + overlay. Virtual slots
  used inside Update: 41 (arg = RNG), 81 (+0x144, when target predicate false), 82 (+0x148,
  suppress gate), 89 (+0x164).
