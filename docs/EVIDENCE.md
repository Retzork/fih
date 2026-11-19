# Evidence ledger (append-only)

Every behavioral claim in this project must trace to an entry here. Never edit or delete past
entries - correct them with a new entry that references the old ID.

## Entry format

```
### EV-NNNN - <one-line claim>
- Date: YYYY-MM-DD
- Type: observation | inference | unknown | wiki-ref
- Source: exact command / file / address range (+ REA Evidence ID if any)
- Raw: relative path under docs/evidence/ or docs/analysis/ (if exported)
- Confidence: high | medium | low
- Notes: boundaries of the search, what this does NOT establish
```

Rules: an inference must name the observations it is derived from. An unknown must say what was
searched. Static analysis never proves runtime behavior; mark runtime-dependent claims accordingly.
A `wiki-ref` entry cites the Insaniquarium Wiki (secondary source, D-0010; page URL + access
date) for display names/terminology/mechanics context - it is never sufficient alone for
behavior or specs; follow up with a binary observation entry.

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

### EV-0043 - P2.2: Fish vtable fully mapped (91 slots); slot 26 = draw entry, slot 83 = sprite draw
- Date: 2026-10-16
- Type: observation (bytes/pseudocode); inference (role naming)
- Source: local byte read of `docs\analysis\snapshots\insaniquarium-game-module.exe` (Fish
  vtable 0x597D54, 96 dwords, file offset = VA - 0x400000); REA dossiers
  `docs/evidence/p2.2-fish-4DEA00.json`, `p2.2-fish-4F22C0.json`, `p2.2-fish-4DA780.json`;
  note updates in `docs/analysis/notes/p2.2-tank-sim.md`
- Confidence: high for addresses/instructions; medium for role naming
- Notes: Fish vtable real length **91 slots (0-90)** - the dword at 0x597EC0 (slot 91) is
  `FishTypePet`'s COL (0x5C868C; FishTypePet vtable starts 0x597EC4). Fish overrides vs
  `GameObject`: 0=0x4F0CB0, 22=0x4F6970 (Update), 26=0x4E4A90 (draw entry), 54=0x4E4C10,
  56=0x4D5300, 70=0x51A440, 71=0x4D5A80, 81=0x4F1400, 82=0x4F15C0, 83=0x4DEA00, 89=0x4DE840
  (remaining slots inherited, e.g. 0x46B5B0/0x46C690). **Slot 83 (0x4DEA00) = sprite draw**
  (Graphics + flip args): 80x80 source cells; srcX = `this[0x1C0]` (frame column) * 80;
  srcY = row * 80 with row = `this[0x1A0]` (0/1/2 as-is, 3->2, 4->3); colorize via
  `FUN_004d6f30` / `FUN_004d5aa0` + `FUN_005008f0`; alt 3-frame flash style (bases 0xAE/0xB5/
  0xB8, alpha toggling `FUN_004558c0`); hit-flash overlay when +0xA0 in 1..5 (alpha
  `(a0*255)/5`); shadow when +0x98; special render path when `DAT_005e89ce != 0` (sheet column
  6/9, `FUN_004560a0`). `FUN_004f22c0` = per-tick helper: decrements +0x108/+0x10C/+0xF8/+0x120
  and, while the live handle at +0x11C exists (`FUN_00538490` check), emits an effect every 30
  frames at `(x + w/2 - 20, y - 50)` via `FUN_005444e0` (started by `FUN_00540cc0(this[0x8c],
  this[0x124])`). `FUN_004da780` = predicate "container at `this+0xB8` or `this+0xF4` non-empty"
  (begin/end pointer pairs, 4-byte elements; 18 in-module callers) - not a hunger check.

### EV-0044 - P2.2/P2.4: object factory by type id, spawn recipe, Tank save/load serializer
- Date: 2026-10-16
- Type: observation (pseudocode/bytes); inference (type names via RTTI vtables)
- Source: REA dossiers `docs/evidence/p2.3-site-5375CD.json` (factory), `p2.4-ctor-*.json`,
  `p2.4-ctorxy-*.json`, `p2.4-site-537B1E.json` (object reader), `p2.4-site-546332.json`
  (Tank serialize/unserialize), `p2.4-tankserialize-xrefs.json`, `p2.4-site-546B73.json`
  (load path), `p2.4-spawn-546D70.json`, `p2.4-spawn-544C00.json`, `p2.3-food-*` ; note section
  `docs/analysis/notes/p2.2-tank-sim.md` §9
- Confidence: high for addresses/tables; medium for some role names
- Notes: `FUN_00537570` = object factory (switch id -> `new(size)` + ctor): 0=Fish/Guppy,
  5=Oscar, 6=Ultra, 7=Gekko, 0x15=FishTypePet (all sizes/vtables confirmed), 0x1C=Food,
  0x22=SylvesterFish, 0x23=BallFish, 0x24=BiFish, plus pending ids 8,9,0xA,0x14,0x16,0x17,
  0x19,0x1A,0x1B,0x1D-0x21 (ctors captured). Every ctor writes its **game type id to
  object+0x8C ([0x23])** - this is also the field tested as `== 6` (Ultra) in Fish::Update.
  Gameplay spawns do NOT use the factory: they run (x,y) ctors (`FUN_004EEF00` Fish/Guppy,
  `FUN_004EFDA0` Oscar, base init + `FUN_004DE370(x,y)` + `[0x68] = 0`), then
  `FUN_00542EE0(obj,1)`, list-add via `[Tank+0x10]` vtable slot 3 (0xC), `FUN_00544800(obj)`
  (updates high-water counters `Tank+0x46C` carnivores / `+0x48C` guppies), `FUN_0053AA40()`
  (UI). Object `Serialize` = vtable slot 0x140 (80). `FUN_00537B00` = read one object from
  stream (id -> factory -> slot 0x140; throws `Sexy::DataReaderException`). `FUN_00546240` =
  Tank serialize/unserialize (write skips type 0x1F; read routes `+0xF4==0` to pending list
  else activates; dumps Tank fields incl. `+0x3F0` money, `+0x314..+0x3D0` 4x12-int arrays,
  and globals `DAT_005e89d0/4/8/c0/c4/c8/cc/dc`). `FUN_00546990` = SaveGame (version dword
  0x36 + Time64). `FUN_00546AA0` = LoadGame (rejects version `<= 0x34`; mode `[manager+0x87C]
  == 5`: reject saves older than ~121 s; seeds `DAT_005df590` (rand 5000..50000) when
  `thunk_FUN_00479FC0()`). Globals `DAT_005e89d0/4/8` are serialized Tank fields;
  `DAT_005e89cc` is cleared when `Tank+0x164 == 0`; `DAT_005e89d0` kept only while the
  container at `Tank+0xB8`/`+0xF4` is non-empty.

### EV-0045 - P2.3: Food entity, Food::Update physics, Tank::DropFood, food level globals
- Date: 2026-10-16
- Type: observation (pseudocode); inference (field roles)
- Source: REA dossiers `docs/evidence/p2.3-foodctorxy.json` (`FUN_004EF840`),
  `p2.3-food-4F8AA0.json` (Update), `p2.3-dropfood.json` (`FUN_00543280`),
  `p2.3-foodxy-xrefs.json`, `p2.3-foodvt-xrefs.json`; note
  `docs/analysis/notes/p2.3-feeding.md`
- Confidence: high for logic/constants; medium for the few ambiguous gates
- Notes: `Food` = type 0x1C, size 0x1A0. Play ctor `FUN_004EF840(x, y, kind, flag, variant)`
  sets x/y at `+0x158/+0x160`, vx `+0x168` = +/-2.0 by kind, vy `+0x170` = -2.0, 40x40 size
  (`+0x38/0x3C`), quality/type `+0x188`, drift kind `+0x18C`, landed flag `+0x190`, variant
  `+0x194`, lifetime `+0x180` (0 from ctor; dropper sets), countdown `+0x198` = 20, flags
  `+0x184/+0x185` = 0. `Food::Update` `FUN_004F8AA0`: pause gate via tank
  `[manager+0x730]+0x94`; `FUN_004F22C0()` shared per-tick; lifetime countdown -> remove
  (`FUN_004D9570`); fall `y += 1.5` or homing `(550, 30)` at /7 steps when `+0x185`
  (remove + `FUN_0053C1E0` when int x < 40); landed bob cycle 120..150 (staged -0.5..-8 by
  depth); drift decay (+/-0.05 steps); x clamp [20, 550]; death at y > 410 (400 for type 3):
  type 3 = sound 0x11D + 2..4 particles (`FUN_005436F0`) + remove; variant 2 = silent remove;
  else `y = FUN_004D62D0()` (open). `Tank::DropFood` `FUN_00543280(x, y, kind, flag, param5,
  type_override)`: manual drops (kind 0) gated by pellet cap tied to `DAT_005df58c` (exact
  formula ambiguous - listed as open), sets `Food+0x188 = DAT_005e89dc` (quality level),
  star potion path (`Tank+0x440` armed -> type 3 + clear), `param5 -> +0x198`, override ->
  `+0x188`; then activate/list-add/UI. Callers `0x543441`, `0x54352E`, `0x5435F2` (Tank input
  cluster; click vs auto-feed unresolved). Globals: `DAT_005e89dc` = food quality (max 2),
  `DAT_005df58c` = food quantity (max 9). Hunger: anchors only so far (`"Quite Hungry"`
  0x596658, `"Fish are about to die of hunger! Click on aquarium!"` 0x598D14, `IMAGE_HUNGRY*`
  0x59C870; string xrefs 0x501BBD/0x5099EE); the fish hunger counter/tint path NOT yet
  identified; `DAT_005e89ce` is zombie mode (NOT hunger).

### EV-0046 - P2.5: money variable, SpendMoney+loan, store item enum, BuyItem hub, spawn map
- Date: 2026-10-16
- Type: observation (pseudocode); inference (prices table semantics)
- Source: REA dossiers `docs/evidence/p2.5-site-540C10.json` (`FUN_00540B30`),
  `p2.5-loan-xrefs.json`, `p2.5-spend-xrefs.json`, `p2.4-site-538116.json` (`FUN_00538100`),
  `p2.5-store-5493E7.json` (`FUN_00549380`), `p2.5-money-xrefs.json`,
  `p2.5-showmoney-xrefs.json` (`FUN_0054E2D0` options), `p2.4-site-54058D.json` (cheat
  toggles); note `docs/analysis/notes/p2.5-economy.md`
- Confidence: high for flow/addresses; medium for trial-mode roles
- Notes: **money = `Tank+0x3F0`** (serialized). `Tank::SpendMoney` `FUN_00540B30(amount)`:
  mode `[manager+0x87C]==5` exempt; demo floor 5 (`[manager+0x880]`); affordability =
  `money + FUN_0053A0B0()` (loan/credit; `"OUT OF MONEY! ... float you a loan"` @0x5A8300,
  `MoneyDialog` class); refusal: sound 0x112 (cooldown `Tank+0x450` = 70), zero-money hint
  `FUN_00537B80` + dialog `FUN_0054B5B0(0x13,1,...,3)`; success: subtract + `FUN_0053A360`
  (money UI). `DAT_005df590` = separate demo money (rand-seeded 5000..50000 in LoadGame;
  compared in `FUN_004D70B0` vs `Tank+0x400` in mode 5). Store items `FUN_00538100`: 0 guppy,
  1 breeder, 2 food quality, 3 food quantity, 4 carnivore, 5 star potion, 6 starcatcher,
  7 guppycruncher, 8 beetlemuncher, 9 ultravore, 10 weapon, 11 egg piece/random pet/end level
  (by `[manager+0x87C]` 1/3). `Tank::BuyItem` `FUN_00549380`: selected item+price from
  `FUN_00538090`; **price table = `Tank+0x314[idx]` (12 ints)**; spend first; cases ->
  spawn/upgrade calls (guppy `FUN_00546D70`, breeder `FUN_005470A0`, carnivore `FUN_00544C00`,
  ultravore `FUN_00544E60`, guppycruncher `FUN_00545430`, beetlemuncher `FUN_00545080`,
  starcatcher `FUN_00545260`; food upgrades bump `DAT_005e89dc` (max 2) / `DAT_005df58c`
  (max 9) via `FUN_005406A0`; weapon `Tank+0x3E4` max 0xB; star potion arms `Tank+0x440`;
  egg `FUN_00545960`). Tutorial/hint infrastructure: `Tank+0x3C8/+0x3CC` step counters,
  `+0x3A7`, `FUN_005409B0` advance, `FUN_0041D8B0` hint text, `FUN_0053E950`. Spawn geometry:
  guppy x=rand%0x208+20 y=30 dv=rand%5+18 dart=rand%10+45; carnivore dv=rand%5+23 y=40
  (high-water counters `Tank+0x48C`/`+0x46C`). `"ShowMoney"` option -> `TankScreen+0x83C`
  (options `+0x839..0x83E`, loader `FUN_0054E2D0`). Cheat toggles `FUN_005404A0`: Wavy/Prego
  sounds/Void/Space/Zombie modes (`DAT_005e89ce` = zombie; cross-ref P2.17). Coins: factory
  ids 0x19/0x1A/0x1B pending; `FUN_004F5050` dossier fetched, not analyzed.

### EV-0047 - P2.5: Coin kind values, AddMoney paths, coin physics/collection, spawn API
- Date: 2026-10-16
- Type: observation (pseudocode/constants); inference (list ownership)
- Source: temp pseudocode `docs/evidence/p2.3-coin-4F5050.json` (Coin::Update, 607 lines),
  `p2.5-coinhelper-*.json` (`FUN_004D5360/5390/54E0/5510`, `FUN_004DD5D0`, `FUN_0053A360`),
  `p2.5-coinhelper2-*.json` (`FUN_0053C1E0`, `FUN_004D53A0`), `p2.5-coinspawn.json`; note
  `docs/analysis/notes/p2.5-economy.md` §5
- Confidence: high for values/constants/add-paths; medium for collector list ownership
- Notes: `Coin::Value` `FUN_004D53A0` by kind `+0x194`: {1,8,0x12}=15, {2,9}=35, {3,0xA}=40,
  {4,0xB,5,0xC}=200, {6,0xD}=500, {7,0xE}=2000, 0x11=150, 0xF=250, 0x10 unhandled/0; in
  virtual/mode-5 (`FUN_004D5360()` = `[manager+0x87C]==5 || Tank+0x2A5 != 0`) value =
  `coin+0x1C0` x {1,2,3,5,10,20,5,10}. `Tank::AddMoney` `FUN_0053C1E0(n)`: mode 5 ->
  `Tank+0x400 += n`; virtual -> `Tank+0x3F4 += n`; normal -> `Tank+0x3F0 += n`
  (clamp 9,999,999) + `Tank+0x460 += n` (level total), then `FUN_0053A360` (money label at
  `Tank+0x438`, format `DAT_005adec0`; mode-5 source `[manager+0x8B8]+0x48`). `Coin::Update`
  physics: fall +1.5 (mode tweaks), land **y=370**, bob 120..150, x clamp, expiry thresholds
  (20/108/150/200 by demo/hint/`Tank+0x16C`; kind 0xF = 217 ticks; kind 0x10 special target
  y=50/-50), fade via `FUN_004D5390` (+0x178=5), removal `FUN_004D5510`. Virtual mode: homing
  to (550,30) then HUD-target flight (`FUN_00538CD0`, squared-dist gate 0x57E5) ending in
  `FUN_004D54E0` = `Tank+0x4EE=1` + `FUN_0053C1E0(FUN_004D53A0())`. Normal collection:
  hit-test coin center (x+36,y+36) vs 60x60 boxes of objects with `obj+0xAC < 0` in Tank
  lists `+0xC0/+0xC4/+0xCC/+0xD0/+0xD4`; on hit: vtable slot 0x160(1) / `FUN_004DD5D0(1)` /
  `FUN_004F3C60(1)` / `FUN_004F2890(1)`, then remove + particle burst (rand%3+3); kind 0x11
  removal (when `+0x198`==0): sound 0x11D + particles. Coin spawn: `Tank::SpawnCoin`
  `FUN_00544430(args)` = new + `FUN_004EEAD0(x,y,kind,...,extra)` + `coin+0x28 = extra` +
  activate + list-add + UI; fish slot 81 caller confirmed. `FUN_004D5510` removal = manager
  object-mgr slot 4 + `[manager+0x88]()` notify + `FUN_00541D90(coin,0)`.

### EV-0048 - P2.3 complete: click-feed, hunger counter, eating pipeline, growth, coin scheduler
- Date: 2026-10-16
- Type: observation (pseudocode/constants/vtable bytes); inference (species order, tick-rate hint)
- Source: `docs\evidence\p2.3-eat-*.json` (slots 54/56 click+release, slot 82 hunger, slot 84
  approach, slot 77 consume, `FUN_004D5F20`, `FUN_004D7100`, `FUN_004D6BD0`, `FUN_004D6EF0`,
  `FUN_004D69D0`, `FUN_004D6C50`), `p2.3-eatfn-*.json` (slot 85/86 Guppy), `p2.3-consumeguupy.json`,
  `p2.3-colorize-*.json`, `p2.3-feed-*.json`, `p2.3-clickslot-refs.json`,
  `p2.3-releaseslot-refs.json`, `p2.3-fishslot82.json`; note `docs/analysis/notes/p2.3-feeding.md`
- Confidence: high for numbers/flow; medium for open semantics items (§9 of note)
- Notes: (1) Fish click virtual slot 54 `0x4E4C10` (in all 7 species vtables
  `0x597D54/0x5982C4/0x59843C/0x5985BC/0x59872C/0x5988B4/0x598A24`): click in water
  (30..587 x, 60..400 y) when `Tank+0xB8/+0xF4/+0xDC` empty and `fish+0x229` ->
  `SpendMoney(Tank+0x4AC)` -> `DropFood(round click, 0, 0, offset, -1)` + `Tank+0x4EC=1` +
  `Tank+0x3C0` timestamp; `Tank+0x4AC` = pellet price; slot 56 `0x4D5300` clears
  `Tank+0x4EC/+0x4ED`. `FUN_00539F30` = click-vs-falling-pellet pop test (variant-2 food,
  `FUN_004D6290`). (2) Hunger: `Fish+0x9C` decrements 1/tick via `FUN_004D6EF0` (paused when
  `+0x11C != -1`), clamp -1000; thresholds -1/-200/-400 (hint strings confirmed) and < -499 ->
  slot 88 (shared die `0x4D5F90`); pet starvation `FUN_004D69D0` (demo -2159; types 7/8/9
  -4319; non-demo `[0x9C] < 1`). (3) Eating: Update -> slot 82 -> slot 84 `0x4D5B20` (approach,
  2 accel profiles by `[0x9C] < 301`) -> slot 85 `0x4EF050` (nearest-food by `FUN_004D5F20`
  distance; food-near timers) -> slot 86 `0x4EF1B0` (eat windows ~35 px; mouth-open `[0x1C8]`)
  -> slot 77 `0x4F1BA0` (nutrition: quality 0/1/3 -> `[0x9C]` +500/+700/+1100-1400 caps
  800/1000/1400; food points `+0x1A4` vs threshold `+0x1A8`; growth stage `+0x1A0` <2 stage++;
  overshoot (mode5?8:15)x -> stage 4; star potion: stage<=1 dies, stage 2 -> stage 3;
  variant-2 pellet -> spawn guppy `FUN_00546D70`). (4) Coin scheduler slot 81 (Guppy `0x4F1400`):
  `[0x220]++` vs threshold via `FUN_004D7100` (mode-5 pacing with `[0x14C]` and `DAT_005df590`),
  gate `FUN_004D6BD0` (demo: no coins when `[0x9C] < 1`), special `[0x124]==5` needs stage>=2 ->
  `Tank::SpawnCoin` `FUN_00544430`; tutorial hint `"Click on coins for extra money!"`.
  (5) Food cap in DropFood: refuse when `DAT_005df58c + specials <= total` (specials =
  `[0x18C]!=0 || [0x194]!=0`) => max `quantity` non-special pellets. Open: module tick rate,
  runtime color table values, variant-2 pellet source, `FUN_0053C280`/`FUN_00538230` roles,
  species vtable->name mapping.

### EV-0049 - P2.4: species map, common ctor tuning, carnivore consume, DeadFish
- Species map resolved from bare-ctor vtable immediates (raw .text bytes) + type ids: 0x597D54
  Guppy (0), 0x5982C4 Gekko (7), 0x59843C Oscar (5), 0x5985BC SylvesterFish (0x22),
  0x59872C Ultra (6), 0x5988B4 BallFish (0x23), 0x598A24 BiFish (0x24); full per-species slot
  table in `docs\analysis\notes\p2.4-growth-death.md` §1 (slots 54/56/68/82/88 shared).
- Fish common ctor FUN_004DE370(x,y): 80x80 box, bounds x 10..540 y 95..370, vy -0.5,
  speed class {2.0,1.8,1.6}, hunger = rand%200+400, growth threshold 4-6 (mode5 12-20),
  coin timer +0x224 = FUN_004D71D0(rand%200+150), 50% initial flip.
- Oscar init FUN_004D84C0: stage 5, hunger rand%200+600, top bound 105, demo slot-90 call.
- Oscar consume FUN_004F2B00: [0x9C] += 900 cap 1300; splat particles when prey is not Food
  and manager+0x882 (gore) on; [0x124]==3 speech "This is my last pizza," / "I swear!".
- DeadFish::Update FUN_004F64E0: death sound FUN_00538230(0x125,3,1.0); spawn-by-id table
  5/6/7 -> FUN_00544D80/FE0/51C0, 8/9 -> FUN_00545360/54F0, 10-12 -> FUN_00547270, else
  FUN_00546FC0; corpse drift/clamps; pet corpse frames by ids 0x65-0x69.
- Spawn fns are physics-only (FUN_00546D70 guppy: y=30, vy=rand%5+18, dart rand%10+45,
  high-water Tank+0x48C; FUN_00544C00 carnivore: y=40, vy=rand%5+23, Tank+0x46C).
- Note `docs\analysis\notes\p2.4-growth-death.md` written (status COMPLETE; open items in §7).

### EV-0050 - P2.4: play ctors, Ultra init, stage-carrying species spawner (extends EV-0049)
- Species play ctors: `FUN_004EFDA0` Oscar (= guppy ctor + vtable + init `FUN_004D84C0`),
  `FUN_004F02A0` Ultra (= guppy ctor + vtable + init `FUN_004D9EE0`).
- Ultravore init `FUN_004D9EE0`: type 6, `+0x1A0 = 6` (stage), sprite box 160x160, bounds
  left 0 / bottom 310 / top 75 / right 480, hunger `rand%200 + 600`, coin timer
  `FUN_004D71D0(rand%250 + 200)`, `+0x229 = 0`, byte `+0x55 = DAT_005e8f14`.
- Generic spawner `FUN_00546FC0(x, y, id, facing)` -> ctor `FUN_004EEF90(x, y, stage, facing)`
  (base Fish at explicit stage; used as DeadFish's default corpse-spawn case; guppy list
  counter `Tank+0x48C`).
- Ultravore buy-spawn `FUN_00544E60` = ctor `FUN_004F02A0(rand x, rand y)` + vy `rand%5+25`,
  y 40.0, dart `rand%10+45`, high-water `Tank+0x470`. Carnivore buy-spawn analog (EV-0049)
  updates `Tank+0x46C`.
- Correction to EV-0049/note: stages are NOT sequential per species (Oscar 5, Ultra 6;
  guppy 0); shared growth machine.

### EV-0051 - P2.4: DeadFish successor-spawn table resolved to play ctors (extends EV-0049)
- All six spawn wrappers are thin (allocate 0x230 + ctor + activate + list + register + UI):
  5 -> FUN_00544D80 -> FUN_004EFE00(x,y,facing) (Oscar family), guppy-list counter NOT used,
  carnivore high-water Tank+0x46C updated;
  6 -> FUN_00544FE0 -> FUN_004F0310(x,y,facing) (Ultra family);
  7 -> FUN_005451C0 -> FUN_004EFA10(x,y,facing) (Gekko family);
  8 -> FUN_00545360 -> FUN_004EC080(x) (type 8), high-water Tank+0x494;
  9 -> FUN_005454F0 -> FUN_004EA740(x) (type 9);
  10..12 -> FUN_00547270(x,y,idx,facing) -> FUN_004EE5C0 (types 0xA-0xC);
  else -> FUN_00546FC0 -> FUN_004EEF90(x,y,stage,facing) (base Fish at stage).
- Interpretation (ghost/next-tier successor vs live respawn) recorded as OPEN in note §4/§7;
  the call graph itself is exact.

### EV-0052 - P2.4: corpse spawner `FUN_005441F0` + `DeadFish` identity/fields (closes EV-0044 pending id 0x1B)
- Date: 2026-10-16
- Type: observation (pseudocode/bytes); inference (class identity via RTTI vtable store)
- Source: REA dossiers `docs/evidence/p2.4b-corpse-5441F0.json`,
  `p2.4b-deadfishctor-4EED20.json`, `p2.4-4F64E0.json`, `p2.4b-die-4D5F90.json`,
  `p2.4b-collector-4DD5D0.json`, `p2.4b-collector-4F2890.json`, `p2.4b-collector-4F3C60.json`,
  `p2.4b-deadfish-slot81-4DB250.json`; RTTI map `docs/evidence/p2.2-module-rtti-classes.txt`
- Confidence: high for addresses/fields; medium for spawner argument roles
- Notes: `FUN_005441F0(...)` = corpse (`DeadFish`) spawner: alloc `0x1A8` -> `FUN_004EED20`,
  then `FUN_00542EE0(obj, 0)` (activation flag 0 = inert; live creatures activate with 1),
  list-add via `[manager+0x10]` vtable `+0xC`, `obj+0x94 = parent` (when non-null the parent's
  `+0x158` receives the corpse back-pointer), UI refresh `FUN_0053AA40()`. Play ctor
  `FUN_004EED20` stores `Sexy::DeadFish::vftable` (0x597BFC; Update slot 22 = 0x4F64E0 per
  EV-0043) and type id `[0x8C] = 0x1B` - **this resolves the "pending 0x1B" factory id of
  EV-0044/EV-0046 to DeadFish** (bare ctor `FUN_004EED00`, size 0x1A8; coin factory ids
  0x19/0x1A remain pending). Field model (ctor + Update): position doubles `+0x160`
  (vertical) / `+0x168` (horizontal) with packed int copies `+0x30/+0x34`; velocity doubles
  `+0x170` (vx, raw from one spawner arg) / `+0x178` (vy = arg - drift; drift = 1.0 when
  spawn vertical < 115.0 or vy < -3.0 else 2.0); speed divisor `+0x180`; facing byte `+0x158`;
  frame int `+0x18C`; phase int `+0x190` = 100; jitter double `+0x198` = 1.0; stage int
  `+0x1A0` = 0x7D (125); corpse id int `+0x1A4`; byte `+0x188` = 0; byte `+0x55` = 0; box
  `+0x38/+0x3C` = 0x50 (0xA0 for id 6). `FUN_004DB250` (vtable slot 0x144) = generic detach:
  manager list remove (`[tank+0x730]+0x10` vtable slot 0x10), tank vtable `+0x88` call,
  `FUN_00541D90(obj, 0)`, parent cleanup `FUN_004D9080()` when `+0x94 != 0`.

### EV-0053 - P2.4: `DeadFish::Update` (0x4F64E0) full replay; successor spawns are LIVE (closes EV-0051 open item)
- Date: 2026-10-16
- Type: observation (pseudocode); inference (lifecycle interpretation)
- Source: `docs/evidence/p2.4-4F64E0.json` (173-line listing re-read 2026-10-16);
  `docs/evidence/p2.4-544D80/544FE0/5451C0/545360/5454F0/546FC0/547270.json` (successor wrappers)
- Confidence: high for control flow; medium for the phase/revive interpretation
- Notes: gates (tank `[manager+0x730]`, paused `tank+0x94`), `FUN_004F22C0()`; phase `+0x190`:
  outside [0,10] the anim frame `+0x18C` is chosen from stage `+0x1A0` and id `+0x1A4`
  (id 8/9 -> 9, or `9-(stage-0x6A)/2` when stage > 0x69; others -> 7 for stage 0x65/0x66,
  8 for 0x67/0x68, 6 when stage <= 100, 9 when stage > 100, `9-(stage-0x6A)/2` when
  stage > 0x69); inside [0,10] phase decrements 1/tick and is used as the frame (a
  decompiler-visible `if phase == 10 -> phase = 10` re-clamp is noted but has no observable
  effect). While stage < 0x69, jitter `+0x198` decreases 0.02/tick (floor 0) and its value is
  copied to `parent(+0x94)+0x168`. `stage < 1` -> slot 81 (`FUN_004DB250`, EV-0052) and
  return (terminal, silent). `phase < 1` -> sound `FUN_00538230(0x125,3,1.0)`, slot 81, then
  successor by id `+0x1A4` (7 -> `FUN_005451C0`, 5 -> `FUN_00544D80`, 9 -> `FUN_005454F0`,
  8 -> `FUN_00545360`, 10-12 -> `FUN_00547270(id-10)`, 6 -> `FUN_00544FE0`, else
  `FUN_00546FC0`) using packed ints `+0x30/+0x34` and facing `+0x158`. Stage decrement once
  per tick when (id 6 and vertical > 300) or (id 8/9 and vertical > 365) or (vertical > 370
  or stage > 0x69). vx `+0x170` decays 0.03/tick toward 0; vy `+0x178` ramps +0.05 toward
  +2.0, or -0.05 toward -1.5 (wrapping back toward +2.0 at -1.5) when byte `+0x188 != 0`.
  Motion: horizontal `+0x168` += vx/speed, vertical `+0x160` += vy/speed (speed `+0x180`);
  clamps horizontal 10..540, vertical 85..370 (310 for id 6, 380 otherwise); commit
  `FUN_00564160` x2 + vtable slot 0xA4. **Interpretation (closes EV-0051 open item):** all
  successor wrappers activate `FUN_00542EE0(obj, 1)` while the corpse used flag 0 -> the
  successor is a **live** creature spawned at the corpse's packed position after the corpse
  is detached (slot 81). The natural lifecycle is: corpse sinks/animates until stage < 1 ->
  silent removal (phase frozen at 100); the successor (revive) branch requires phase to be
  set <= 10 by another subsystem - trigger source NOT found (open Q; candidates: pet revive
  or zombie mode `DAT_005e89ce`). Recorded as explicit unknown, not runtime behavior.
  Wrapper spot-checks: `FUN_00545360` (id 8) allocs 0x1B0 -> Penta ctor `FUN_004EC080`
  (vtable 0x596EE4), appends to Tank list `+0xD0`, updates high-water `Tank+0x494`;
  `FUN_005454F0` (id 9) allocs 0x1B0 -> Grubber ctor `FUN_004EA740` (vtable 0x59698C).

### EV-0054 - P2.4: death entry points (slot 88, collector trio, hunger ticks) + types 0xA-0xC = `Sexy::Breeder`
- Date: 2026-10-16
- Type: observation (pseudocode); inference (creature attribution of callers)
- Source: `docs/evidence/p2.4b-die-4D5F90.json`, `p2.4b-diehelper-538610.json`,
  `p2.4b-collector-4DD5D0/4F2890/4F3C60.json`, `p2.4b-deathdispatch-4F139D/4F8FBA.json`,
  `p2.4b-petstarve-4D69D0.json`, `p2.4b-type1012-ctor-4EE5C0.json`,
  `p2.4b-type8-ctor-4EC080.json`, `p2.4b-type9-ctor-4EA740.json`
- Confidence: high for routine bodies; medium for the creature class of the hunger ticks
- Notes: `FUN_004D5F90` (fish-family die, slot 88): optional voice `FUN_00538610([0x8C])`,
  vtable `0x15C(0)` call, facing = sign of `+0x168`, forwards `+0x168`/`+0x170`/`+0x180`
  (velocity/speed), id `+0x1A0` (stage) and parent `+0x94` to `FUN_005441F0` -> corpse id =
  stage. `FUN_00538610(type)` = creature audio helper: base id `0x117` shifted by type
  (5 -> -6, 6 -> -12, 7/0x22/0x23/0x24 -> -3, 8 -> +4, 9 -> -6, 10 -> +5), playback via
  manager `+0x4B4` vtable slots 0x20/0x10/0x1C with `DAT_005e8a70` (eat-vs-death semantic
  open). Collector trio, same body shape (`param != 0` gates the voice call):
  `FUN_004F2890` (region 0x4F8Fxx, xref inside `FUN_004F8F60` right before Grubber::Update
  0x4F8FE0) -> `FUN_004F2740(0)`; `FUN_004F3C60` (region 0x4F93xx, xrefs 0x4F93C4/0x4F94BA
  near Penta::Update 0x4F94E0) -> `FUN_004F3AD0(0)`; `FUN_004DD5D0` -> `FUN_004DD530(0)` and
  **corpse id = `[+0x1A0] + 10`**. All three forward `(+0x168, 0, +0x178, id, facing, parent)`
  to `FUN_005441F0` (id = `[0x8C]` for the first two).
  **Types 0xA-0xC = `Sexy::Breeder` (vtable 0x597814, Update 0x4F4180 per EV-0041):** ctor
  `FUN_004EE5C0` stores the Breeder vftable, base `FUN_004E9CB0` + `FUN_004DCBF0(x,y)`, sets
  `+0x168` and `+0x188` = +/-1.0, stage `+0x1A0` = param, life/hunger field `+0x1D4` =
  (stage 0/1 ? rand%400+1000 : rand%200+800). Corollary: corpse ids 10-12 revive as Breeder
  at stage 0/1/2; the `[+0x1A0]+10` id accounting in `FUN_004DD5D0` fits a Breeder-family
  creature whose stage selects the successor stage. Starvation gate `FUN_004D69D0`:
  `+0xAC >= 0` -> false; demo (`[manager+0x880] != 0`): type 7/8/9 -> hunger `+0x9C` < -4319,
  else < -2159; non-demo: hunger < 1. Callers: `FUN_004F1340` (region 0x4F1xxx; starve ->
  `FUN_004DD5D0(1)`; hunger < 500 -> `FUN_004F0880` gated on tank list `+0xB8` member
  `+0x1EC != 4`; beat-flash `FUN_004D6C50`) and `FUN_004F8F60` (region 0x4F8Fxx; starve ->
  `FUN_004F2890(1)`; hunger < 900 -> `FUN_004EFAD0`); the exact creature class of these two
  tick bodies is open (recorded by region only).

### EV-0055 - P2.4/P2.5: Coin::Update collection dispatch mapped per list + corrections (extends EV-0047)
- Date: 2026-10-16
- Type: observation (pseudocode line refs); inference (list ownership where marked)
- Source: `docs/evidence/p2.3-coin-4F5050.json` (raw re-read), `docs/evidence/p2.4-545360.json`
  (list `+0xD0`), note `docs/analysis/notes/p2.5-economy.md` §5
- Confidence: high for the dispatch; medium for gameplay meaning
- Notes: normal-mode collection resolves per list (dossier line refs): first-phase entity
  iterators (tank `+0xB8`/`+0xF4`, helpers `FUN_004E5040/FUN_004E3DD0/FUN_004E3E00`),
  list `+0xD4` (probable) and list `+0xCC` -> virtual slot `0x160(1)` (default collector);
  list `+0xD0` -> `FUN_004F3C60(1)`; list `+0xC4` -> `FUN_004F2890(1)`; list `+0xC0` ->
  `FUN_004DD5D0(1)`; hit box = coin center `(x+36, y+36)` vs `[+0x10, +0x46]` of objects with
  `+0xAC < 0`; after the handler: coin remove `FUN_004D5510` + particle burst
  `FUN_005436F0(rand%3+3)` (raw lines ~211/220/270/361/404/417/459/470/512/523/560/595-598).
  **List ownership (answers the EV-0046/EV-0047 "collector class owners" open item in part):**
  `+0xD0` is the Penta list (verified: successor spawner `FUN_00545360` appends there,
  EV-0053); the `+0xC4` and `+0xC0` handlers are the Grubber-region and Breeder-family
  routines of EV-0054, so those lists most plausibly hold Grubber (type 9) and Breeder
  (types 0xA-0xC) creatures - written as inference. The three handlers are the same routines
  used by the starvation-death paths, so the observed pattern is "a creature touched by a
  coin runs its corpse-spawn routine"; the gameplay intent (collect vs kill vs eat) is NOT
  verified and stays open. `+0xAC < 0` filter: base GameObject ctor leaves `+0xAC = -1`;
  the Fish family clears it (>= 0) - consistent with the EV-0048/p2.3 "pets" reading, but the
  writer that clears it for fish is not yet pinned down (to refine in P2.7).
- Corrections/extends: EV-0044/EV-0046 "pending id 0x1B" -> DeadFish (EV-0052); EV-0051
  "ghost vs live" -> live successor spawn (EV-0053); EV-0049 "types 0xA-0xC parked" ->
  `Sexy::Breeder` (EV-0054).

### EV-0056 - P2.4 third pass: per-species closure (init helpers, eat bodies, spawn paths, stage-size switch, pacing helper)
- Date: 2026-10-16
- Type: observation (pseudocode/assembly)
- Source: `docs/evidence/p2.4-eat-*.json` (4E1950/4E3720/4E3C60/4E3F90/4E40A0),
  `docs/evidence/p2.4b-init-*.json` (4D72B0/4D95C0/4DB2A0/4DB820/4D8D00/4D7970),
  `docs/evidence/p2.4b-ctor2-*.json` (4EF9E3/4F0223/4F05B3/4F0673),
  `docs/evidence/p2.4b-playctorxrefs-*.json` + `p2.4b-vtxrefs-5982C4/5985BC/5988B4/598A24.json`,
  `p2.4b-randspawn-xrefs.json`, `p2.4b-randspawn-caller-52F17F.json`,
  `p2.4b-spawndispatch-51B542.json`, `p2.4b-store-spawn-545080/545430.json`,
  `docs/evidence/p2.4c-pacing-4D71D0.json`, `p2.4c-stageup-4D9D50.json`,
  `p2.4c-coinkind-544430.json`, `p2.2-fish-4F1400.json` (slot-81 guard re-read);
  note `docs/analysis/notes/p2.4-growth-death.md` §1/§5.1/§6
- Confidence: high
- Notes: init helpers (common shape: `[0x8C]=type`, byte `+0x229=0`, stage `+0x1A0`, top
  `+0x198=0x69`, bottom `+0x190=0x168`, `+0x55=DAT_005e8f14`, `+0x224=FUN_004D71D0(rand%0xFA+200)`):
  Gekko `FUN_004D72B0` (type 7, stage 7), Sylvester `FUN_004D95C0` (0x22, stage 1),
  Ball `FUN_004DB2A0` (0x23, stage 0, box 0x32), Bi `FUN_004DB820` (0x24, stage 0, box 0x50,
  `+0x230=rand()&1`, `+0x234=0`); Penta `FUN_004D8D00` (type 8: y=rand%5+360, box 80x80,
  fall speed `+0x178` 2.7/2.5/2.6 by rand%3, hunger `+0x9C=rand%200+900`, `+0x194=40`,
  growth threshold `+0x1A8=1`, `+0x190=rand%10`, speed `+0x180=45`); Grubber `FUN_004D7970`
  (type 9: same, but `+0x1A8=0` and `+0x1AC=FUN_004D71D0(rand%200+300)`). Play ctors:
  Gekko `FUN_004EF9A0`, Sylvester `FUN_004F01E0`, Ball `FUN_004F0570`, Bi `FUN_004F0630`
  (guppy ctor + vtable swap + init helper + facing write).
  Slot-77 eat bodies: Gekko `FUN_004E1950` (hunger +700 cap 1000; food test `prey+0x8C==0x1C`
  -> sound `FUN_005384C0(fish+0x104)` else `FUN_00538560`), Sylvester `FUN_004E3720` (+700 cap
  1000; grows only at stage 1 -> `FUN_004D9D50(2)`, reset points, grow anim `+0x1CC=10`,
  sound 0x122), Ultra `FUN_004E3C60` (+900 cap 0x514; special sound `FUN_005384A0` when
  `+0x124==4 && +0x11C!=-1`), Ball `FUN_004E3F90` (+700 cap 1000; inline stage++ while <2),
  Bi `FUN_004E40A0` (+700 cap 1000).
  Tank-roster spawner `FUN_0051B260`: weighted rand%100 Penta 26 / Grubber 25 / Gekko 25 /
  Breeder 10 / Ultra 5 / Bi 3 / Ball 3 / Sylvester 3, dispatched to ctors `FUN_004EC0F0`/
  `FUN_004EA7B0`/`FUN_004EF9A0`/`FUN_004EE530`/`FUN_004F02A0`/`FUN_004F0630`/`FUN_004F0570`/
  `FUN_004F01E0` (alloc sizes 0x1B0/0x1B0/0x230/0x1E0; Bi 0x238); called by virtual-tank
  populate `FUN_0052F0D0` (xref sites 0x52F17F/0x52F25D/0x52FE1F/0x52FE53) + internal retry
  0x51B3A8. Store items: 7 "buy guppycruncher" `FUN_00545430` -> Grubber; 8 "buy
  beetlemuncher" `FUN_00545080` -> Gekko. `FUN_004D9D50(stage)` = stage-size switch
  (1: box 80x80, x/y +40, top 0x69, bottom 0x168, `+0x194=10`, `+0x19C=0x21C`; 2: box 160x160,
  x/y -40, top 0x4B, bottom 0x136, `+0x194=0`, `+0x19C=0x1E0`; parent `+0x94` field `+0x15C`
  = 0/2). `FUN_004D71D0(base)` = mode-5-only override `rand%200+0x10E0`, else base
  (answers the EV-0049 "role open"); slot-81 drop guard `stage +0x1A0 < 1 && +0xAC < 0`
  -> no drop (`FUN_004F1400` re-read). `Tank::SpawnCoin` `FUN_00544430` body: new via
  `FUN_004EEAD0` (5 args), `coin+0x28 = param_6`, `FUN_00542EE0(coin, 0)`, list-add via
  manager `+0x10` vtable +0xC, UI refresh `FUN_0053AA40()`.
- Corrections/extends: EV-0049 "ctors are bare (no init helper)" for Gekko/Sylvester/Ball/Bi
  -> each has an init helper (above); EV-0049/EV-0050 "FUN_004D71D0 role open" -> resolved;
  note p2.4 §4 "stage-carrying spawner" unchanged. The Gekko eat-body fetch earlier failed
  once (error JSON `p2.4b-playctorxrefs-4EF9A0.json` records the retryable snapshot-lock
  message but retains the xrefs 0x51B486/0x52BA17/0x545105).

### EV-0057 - P2.5 third pass: credit = uncollected coins; price arrays A/B/C/D; egg/level handler; SetStorePrice xrefs
- Date: 2026-10-16
- Type: observation (pseudocode/assembly/basic blocks); inference (mode naming deferred)
- Source: `docs/evidence/p2.5c-loan-53A0B0.json`, `p2.5c-loancaller-53C2D3.json`,
  `p2.5c-pricegen-5380C0.json` + `p2.5c-pricegen-xrefs.json`, `p2.5c-pricegen-caller-54810E.json`
  (`Tank::Update` 0x547610 analyze), `p2.5c-eggpiece-545960.json` (decompile) +
  `p2.5c-eggpiece-fn-545960.json` (assembly/basic blocks), `p2.5c-itemget-538090.json`,
  `p2.5c-iteminit-5409B0.json`, `p2.5c-applyupgrade-5406A0.json`, `p2.5c-tankflush-537D30.json`,
  `p2.4-site-546332.json` (serializer re-read); note `docs/analysis/notes/p2.5-economy.md` §1/§3/§3.1
- Confidence: high for bodies/xrefs; mode naming deliberately left open
- Notes: `FUN_0053A0B0` is NOT a loan: it sums uncollected coin values in the tank - lists
  `+0xA8` and `+0xEC` via `Coin::Value()` `FUN_004D53A0` for members with byte `+0x198 != 0`,
  plus list `+0xC8` (offset 200) via `FUN_004D7E60()` for members with byte `+0x174 != 0`;
  `SpendMoney` therefore lets you spend coins still lying in the tank (the "we'll float you
  a loan" text is flavor). `FUN_0053C2D0()` = `money += FUN_0053A0B0()` clamp 0..9,999,999 +
  UI refresh - called by the egg handler (0x545BFD) and `Tank::Update` (0x547A17/0x548F3D).
  Price arrays (all serialized by `FUN_00546240`): `+0x2E4`[12] = store slot id (-1 = not for
  sale), `+0x314`[12] = current price (egg aliases `+0x340` = B[11]), `+0x344`[12] = base
  price (reset target), `+0x374`[12] = mode-4 inflation increment; `+0x3A4+i` bytes =
  item-present flags; `+0x404 + slot*4` = store item UI objects. `FUN_005380C0(index, price)`
  = SetStorePrice (clamp 99999, write B, row refresh `FUN_00534380` via getter `FUN_00538090`);
  only three call sites: 0x54810E (`Tank::Update`, mode==3 && `+0x2E0 < +0x2DC`
  && tank `+0x3C8 != 5`: 12x `CreateStoreItem(i,1)` then `SetStorePrice(11, 0)`),
  0x545A9A (egg handler mode-1 "buy random pet": `SetStorePrice(11, 2*B[11])`, `+0x498 += 1`),
  0x545B81 (egg handler mode-4: reset B[i] = C[i], i != 11, "Prices have been reset!").
  Egg/level handler `FUN_00545960` full flow in note §3.1: item-11 presence check; mode 3 ->
  `FUN_00552230` (no spend); spend B[11]; mode 1 -> random-pet grant over the tank's 24 pet
  slots `Tank+0x144` (skip i==0x13, filter `FUN_00501410(profile,i)`, grant `FUN_00544A90`,
  double B[11], sound 0x111, return); else egg path (`+0x43C += 1` pieces owned, tutorial
  "Collect 2 more egg pieces to finish level!", mode-4 `+0x454 = 500` + price reset, refresh
  `FUN_005406A0(0xB,1)`); at `+0x43C >= 4`: `Tank+0x3FC = FUN_00538040()`, `+0x4EE = 0`,
  collect-all `FUN_0053C2D0()`, mode 4 -> profile unlock `[profile+0x8B8 + 0x77 + tankIdx] = 1`
  (tanks 1..4) + `FUN_005144C0`/`FUN_0054BF60` level-complete flow; else stats slot
  `tank*5 - 6 + level` (`Tank+0x3C8` tank, `+0x3CC` level) via   `FUN_00501420`, tank-5 special
  rebuilds the free-pet list into globals `DAT_005e8fe0` (array) + `DAT_005e9080` (count),
  jingles/screens
  `FUN_00501370`/`FUN_00501200`/`FUN_0054BE80`/`FUN_0053DC10`. Initial A/C/D values for a
  fresh tank remain unfound (bounded search: `FUN_00538090`, `FUN_005409B0`, `FUN_005406A0`,
  `FUN_00546240`, `FUN_00537D30`, `FUN_00546AA0` + all setter xref sites) - hand-off to P2.6.
- Corrections/extends: EV-0046 "loan" -> uncollected-coin credit (correction); EV-0046 price
  table `+0x314` -> four-array model A/B/C/D; p2.5 note §3.1 new; `FUN_00534450` = item-11
  refresh when random-pet candidates <= 1 (role recorded, purpose open).

### EV-0058 - P2.5: money label format `DAT_005adec0` = `"%d"` (closes an EV-0047 open item)
- Date: 2026-10-16
- Type: observation (decompile + raw byte read)
- Source: `docs/evidence/p2.5c-moneydisplay-53A360.json`; byte read of
  `docs\analysis\snapshots\insaniquarium-game-module.exe` at VA 0x5ADEC0 (file offset 0x1ADEC0)
- Confidence: high
- Notes: `FUN_0053A360` (money label refresh, label object `Tank+0x438`) formats
  `mode5 ? [profile+0x8B8]+0x48 : Tank+0x3F0` with `FUN_004120c0(buf, &DAT_005adec0, value)`.
  Raw bytes at VA 0x5ADEC0: `25 64 00 00` = `"%d"` (immediately followed by
  "Content-Length: " at 0x5ADEC4); the string dump missed it (2-char string). The shell icon
  is drawn separately; the label is the bare integer.

### EV-0059 - P2.5: store item 6 "buy starcatcher" spawns `Sexy::Penta` (type 8)
- Date: 2026-10-16
- Type: observation
- Source: REA `decompile` of `FUN_00545260` (module); raw:
  `docs\evidence\p2.5c-starcatcher-spawn-545260.json`
  (evidence_id `ev_6e8133bc7f7954636fbd0a57da8f904f6adb4d5a4f0a5c77975e42cfd85ddd65`)
- Confidence: high
- Notes: item-6 case of `Tank::BuyItem` (`FUN_00549380`, EV-0046): alloc 0x1B0
  (`FUN_00564345`) -> ctor `FUN_004EC080(rand%0x208 + 0x14)` (x = 20..539; type 8, vtable
  0x596EE4 = `Sexy::Penta` per EV-0041); writes y double `+0x160 = 0x4050400000000000` (= 65.0)
  and packed int `+0x34 = 0x41` (65); activates live `FUN_00542EE0(obj, 1)`; list-add via
  `[Tank+0x10]` vtable +0xC; refreshes high-water `Tank+0x494` from list `+0xD0` size;
  `FUN_00544800(obj)`; UI `FUN_0053AA40()`. Same family as the id-8 corpse successor
  `FUN_00545360` (EV-0053), so store-bought and successor Pentas share the type. Display name
  "Starcatcher" is wiki-ref (EV-0060); the binary proves only id-6 spawn = Penta.

### EV-0060 - P2.5 wiki-ref: internal <-> display bindings, mode names, money denominations, store prices
- Date: 2026-10-16
- Type: wiki-ref (secondary source)
- Source: `https://insaniquarium.fandom.com/wiki/<Page>?action=raw` (clean wikitext), all
  fetched 2026-10-16: Main Page, Sylvester, Balrog, Bilaterus, Aliens, Guppycruncher,
  Beetlemuncher, Starcatcher, Ball Fish, Minisylvester, Bilaterus Head, Money, Virtual Tank
  Mode, Time Trial Mode, Challenge Mode, Adventure Mode, Sandbox Mode. Index:
  `docs\analysis\notes\wiki-refs.md`. No wiki text saved locally (URLs are the record).
- Confidence: medium (naming/context only)
- Notes: (1) Display-name bindings - `Sexy::Grubber` = Guppycruncher and `Sexy::Gekko` =
  Beetlemuncher (wiki trivia: their art files are named "Grubber"/"gekko"), matching store
  items 7/8 (EV-0056); `Sexy::Penta` = Starcatcher (store item 6, EV-0059); `Sexy::Oscar` =
  Carnivore, `Sexy::Ultra` = Ultravore (items 4/9, EV-0046); `Sexy::SylvesterFish` =
  Minisylvester, `Sexy::BallFish` = Ball Fish, `Sexy::BiFish` = Bilaterus Head - all three are
  the Virtual Tank prize fish (roster spawner `FUN_0051B260` + VT populate, EV-0056; Bi
  `+0x230 = rand&1` fits the wiki's two head variants), NOT the hostile aliens. Hostile
  Sylvester/Balrog/Gus/Destructor/Ulysses/Psychosquid have no matching RTTI classes -> Q-0011.
  (2) Money (Money page) matches `Coin::Value` (EV-0047): 15 Silver Coin, 35 Gold Coin,
  40 Star, 200 Diamond, 500 Pearl, 2000 Treasure Chest, 150 Beetle, 250 Niko's Pearl; virtual
  multipliers x1/x2/x3/x5/x10/x20 = Silver Coin/Gold Coin/Star/Blue shell/Spiral shell/Bag o'
  shells; kind 0x10 has no value in the binary - open. (3) Mode cross-refs: mode 1's random-pet
  price doubling (`2*B[11]`, EV-0057) matches the wiki Time Trial Mode table (100 -> 200 ->
  ... -> 51200 -> 99999); mode 4's inflation/reset/tank-unlock matches Challenge Mode; mode 5 =
  Virtual Tank/screensaver; modes 0/3 = Adventure intro/level lifecycle (store rebuild +
  "end level" + `FUN_00552230`); mode 2 unobserved (wiki Sandbox is a secret mode:
  Up Up Down Down Left Right Left Right B A, $999,999 start, egg piece returns to menu) -
  naming stays P2.11. (4) Wiki store prices to verify against the initial A/C/D arrays in P2.6:
  guppy $100, food quality $200, food quantity $300, starcatcher $750, guppycruncher $750,
  beetlemuncher $2000; egg pieces $99,999 (tanks 4-5). (5) Discrepancies recorded: VT beetle
  value (binary virtual multiplier x5 for kind 0x11 vs an unresolved wiki "7 shells" figure);
  Minisylvester growth (binary init stage 1 -> grows once to 160x160 stage 2, EV-0056; wiki
  describes two mini stages + adult); alien HP values (Sylvester 10, Balrog 22, Bilaterus 17
  per head - wiki only, verify P2.8). None of this changes any binary-derived value.

### EV-0061 - P2.6 first pass: level-start pair - `Tank` init `FUN_00541A20` + orchestrator `FUN_0054CBF0` (closes the EV-0057 initial-value hand-off)
- Date: 2026-10-16
- Type: observation (decompile of two functions + caller xrefs)
- Source: `docs/evidence/p2.6-storeinit-caller-541C1A.json` (`FUN_00541A20`), `p2.6-tankinit-caller-54CC19.json`
  (`FUN_0054CBF0`), `p2.6-storeinit-xrefs.json`, `p2.6-tankinit-xrefs.json`
- Confidence: high
- Notes: `FUN_0054CBF0` (level-start orchestrator, single caller chain from menu/selector flows):
  clears manager byte `+0x883`; mode 5 gate `FUN_0054CB20`; `FUN_0054C540()`; then `FUN_00541A20()`;
  `FUN_0054B2A0()` true -> `FUN_00537E20()` + `FUN_0054B2D0()`; mode 5 -> `FUN_0053C3F0()` +
  `FUN_0054B2D0()`; else `FUN_005498B0()` (EV-0063) + `FUN_0054B2D0()`.
  `FUN_00541A20` (`Tank` method, `in_ECX` = tank, manager = `Tank+0x8C`) is the per-level state reset:
  (1) 12-item loop zeroes `A` (`+0x2E4`) to -1, `B` (`+0x314`) to 0, `D` (`+0x374`) to -1, and
  item-present bytes `+0x3A4+i` to 0; (2) mode 0 (Adventure): tank `+0x3C8 = profile+0x1C`,
  level `+0x3CC = profile+0x20`; other modes: tank `= manager+0x888`, level = 5;
  (3) money `Tank+0x3F0` = 999999 (mode 3) else 200; `+0x4AC = 5`; `+0x2C0 = 3000`;
  **`+0x43C = 1` (egg-piece counter starts at 1)**; `+0x3E4 = 2` (pet slots); `+0x2BC = 2`;
  demo (`manager+0x880 != 0`): `+0x3E4 = 8`, `+0x3F0 = 200`, `DAT_005df58c = 3`;
  (4) clears `+0x460..+0x4A8`; (5) `FUN_0053A360()` (money label), `memset(Tank+0x4B0, 0, 0x36)`,
  `FUN_00541200()` (EV-0062); (6) final 12-item loop: `C[i] = B[i]` (`+0x344 <- +0x314`),
  `D[i] = B[i]/100` when `D[i] == -1`, and `+0x2DC` = number of items with `A[i] >= 0` (visible
  item count used by the mode-3 store rebuild EV-0057); (7) mode 5 -> `FUN_0053E280()`, then a
  vtable `+0x28` call. Resolves EV-0057's "initial A/C/D unfound": A/B come from `FUN_00541200`,
  C = B and D = B/100 by default (`FUN_00537C20` role still open).

### EV-0062 - P2.6: per-tank/level store initializer `FUN_00541200` (A/B tables, egg-piece prices, mode overrides)
- Date: 2026-10-16
- Type: observation
- Source: `docs/evidence/p2.6-storeinit-541200.json`; located via REA `search-bytes` of
  `E4 02 00 00` in `.text` 0x401000-0x595900 -> 10 hits (`docs/evidence/p2.6-disp2E4-search.json`),
  one write site inside `FUN_00541200`
- Confidence: high (bodies); table semantics per prior EV-0057 mapping
- Notes: called only from `FUN_00541A20` (EV-0061). Non-demo branch writes per tank (`+0x3C8`) and
  level (`+0x3CC`):
  - tank 1: `B[0]=100` (guppy), `B[2]=200` (food quality), `B[3]=300` (food quantity),
    `B[4]=1000` (carnivore), `B[10]=1000` (weapon); A slots present: 0/1/2/3/5/6; level switch
    hides items by `A = -1` - L1 hides quality+quantity+carnivore+weapon, L2 hides
    carnivore+weapon, L3-5 all present; egg price `B[11] = 150/500/2000/3000/5000` for L1-5.
  - tank 2: `B[0]=100`, `B[2]=200`, `B[3]=300`, `B[5]=250`, `B[6]=750` (starcatcher, EV-0059),
    `B[10]=1000`; A: 0->0 guppy, 2->1 quality, 3->2 quantity, 5->3 (B=250), 6->4 (starcatcher),
    10->5 weapon, 11->6 egg; carnivore `A[4]` stays -1 (not sold); L1-2 hide weapon; egg price
    750/3000/5000/7500/10000.
  - tank 3: `B[0]=100`, `B[2]=200`, `B[3]=300`, `B[7]=750` (guppycruncher), `B[8]=2000`
    (beetlemuncher), `B[10]=2000`; A: 0, 1, 2, 7->3, 8->4, 10->5, 11->6; no starcatcher
    (`A[6]` stays -1); L1 hides weapon + beetlemuncher, L2 randomizes `+0x2BC = 4 | rand&1`;
    egg price 1000/5000/7500/10000/15000.
  - tank 4: `B[1]=200`, `B[2]=200`, `B[3]=300`, `B[4]=1000` (carnivore), `B[9]=10000`
    (ultravore), `B[10]=5000`; A: 1->0 (breeder), 2->1, 3->2, 4->3, 8->4, 10->5, 11->6;
    L1 hides weapon + beetlemuncher, L2 sets `+0x2BC=8`; egg price 3000/25000/50000/75000/99999.
  - tank 5: egg price `B[11]=0`, `+0x43C = 3` (counter starts at 3 - one more piece completes),
    `+0x2BC = 0x15`.
  Demo branch (manager `+0x880 != 0`): sets `B[0]=100`, `B[4]=1000`, `B[6]=750`, `B[7]=750`,
  `B[8]=2000`, `B[9]=10000`, `A[11]=6`, `A[0]=0`, egg price 5000/5000/10000/25000 for tanks
  1-4 (sold slots: 0, 4, 6, 7, 8, 9, 11). Post-switch overrides: mode 4 -> egg price
  5000/15000/25000 (tanks 2/3/4); mode 1 ->
  `B[11] = 100` (Time Trial random-pet start, matches EV-0060 wiki table); mode 5 ->
  `FUN_00538A10(profile+0x8C + 1)` (VT theme). Ends with 12x `FUN_005409B0(i, 1)`
  (CreateStoreItem) + `FUN_00537C20()`. Wiki prices (EV-0060) now confirmed against binary for
  guppy/food/starcatcher/guppycruncher/beetlemuncher; egg prices are per tank/level as above.

### EV-0063 - P2.6: level-start screen init `FUN_005498B0` (mode names, welcome banners, pet grants, timers)
- Date: 2026-10-16
- Type: observation; inference (mode-2 role left open)
- Source: `docs/evidence/p2.6-nextlevel-fn-549C6E.json` (xref of `"Welcome to the next level!"`
  0x5A8BAC -> 0x549C6E)
- Confidence: high
- Notes: banner selection by mode/tank/level: mode 0 Adventure - `"Welcome to the Insaniquarium!"`
  (tank1 L1, `profile+0x59 == 0`), `"Welcome to the Bonus Adventure!"` (same, `+0x59 != 0` +
  `profile+0x50 == 1`), `"Welcome to the next level!"` (tank1 L2), `"Welcome to the second tank!
  Now things get tricky!"` (tank2 L1); mode 1 Time Trial - `"Welcome to Time Trial mode!"` with
  timer `Tank+0x3BC = 300` (tank1) / 600 (tanks 2-4) sec; mode 3 - `"You've discovered the
  top-secret SANDBOX mode!"`; mode 4 - `"Welcome to Challenge mode!"`; mode 5 - no banner.
  **Mode naming correction to EV-0060: mode 3 = Sandbox (not "Adventure level lifecycle"); mode 0
  = Adventure.** Pet setup: if `((profile+0x59 == 0 || (mode != 1 && mode != 4)) && profile+0x18 < 4)`
  loop i 0..0x12 with `FUN_00501410(i)` -> `FUN_00544A90(i)` (create owned pets); else loop i
  0..0x17 and create pet i when `profile+0x5A+i != 0` (selection flags written by the PetsScreen,
  EV-0065); tank 5: creates pets 0..0x11 unconditionally + `+0x2C0 = 300`. Tank 4 spawns
  `FUN_005471E0()` and marks the last spawned object `+0x1A4 = 2`; tanks 1-4 spawn 2x
  `FUN_00546EF0()` likewise (`+0x1A4 = 2`, tank1 L1 also sets `+0x228 = 1`). End: clears
  `+0x444/+0x450/+0x454/+0x45C/+0x458`, sets `+0x3B4 = +0x3B8 = FUN_00537B60()` (level timer
  base, feeds EV-0064's completion time), `+0x4E8 = 0`, `+0x4E6 = 0`.

### EV-0064 - P2.6: completion path - egg counter semantics, elapsed time, overlay spawners, tutorial flag
- Date: 2026-10-16
- Type: observation
- Source: `docs/evidence/p2.6-eggresult-538040.json` (`FUN_00538040`), `p2.6-levelcomplete-54BE80.json`
  (`FUN_0054BE80`), `p2.6-levelcomplete-53DC10.json` (`FUN_0053DC10`), `p2.6-levelend-54BF60.json`
  (`FUN_0054BF60`), `p2.6-egg3str-fn-4F19CE.json` (`FUN_004F1840`, xref of `"Buy 3 egg pieces to
  complete level!"` 0x598DCC -> 0x4F19CE)
- Confidence: high
- Notes: (1) Egg counter closed: `+0x43C = 1` at level start (EV-0061), `FUN_00545960` increments per
  purchase and completes at `>= 4` (EV-0057), tank 5 starts at 3 (EV-0062) - so 3 purchases per
  level; the tutorial hint at `+0x43C == 1` (`"Collect 2 more egg pieces to finish level!"`) and
  `"Buy 3 egg pieces to complete level!"` are consistent. (2) `FUN_00538040` =
  `(FUN_00537B60() - Tank+0x3B8) / 1000` -> `Tank+0x3FC` = level completion time in seconds.
  (3) Overlay spawners (not level advance): `FUN_0054BE80` allocs 0xB8 -> ctor `FUN_0051F450`
  (`manager+0x814`) for the normal completion path (profile `+0x59 == 0`); `FUN_0054BF60` allocs
  0x18C -> ctor `FUN_0052DAD0` (`manager+0x818`) for Challenge mode and tank5/L1 completions.
  `FUN_0053DC10` = thin `profile+0x59 != 0` path: `+0x4EE = 1`, `FUN_0053C480(+0x10)`,
  `FUN_0054B020`, `FUN_0054B1A0(2, 0x36, 0)`, `FUN_00537E20` (no overlay). (4) Tutorial driver
  `FUN_004F1840` (step object `+0x1A0`): tank1 L1 sets `Tank+0x4B2 = 1` and pending flag
  `Tank+0x4D8 = 1` (consumed by the egg handler, EV-0057); later steps show
  `"Upgrade Food Quality to make food more nourishing!"` etc.; `+0x59 != 0` suppresses all hints.

### EV-0065 - P2.6: screen flow - PetsScreen confirm, next-screen spawns, event dispatcher, sandbox entry, credits (open: profile tank/level writer)
- Date: 2026-10-16
- Type: observation; explicit unknown (advance writer)
- Source: `docs/evidence/p2.6-selector-528D83.json` (`FUN_005289F0` = PetsScreen method 0x5289F0 per
  RTTI vtable `PetsScreen::Sexy`), `p2.6-flow-552100.json` (`FUN_00552100`), `p2.6-start-552475.json`
  (`FUN_00552380`), `p2.6-advance-552A1E.json` (`FUN_005527C0`), `p2.6-hatch-517843.json`
  (`FUN_005177E0`), `p2.6-vanquished-fn-525B2F.json` (`FUN_00525A60`), `p2.6-hatch-51A500.json`
  (`FUN_0051A500`), `p2.6-lvlreset-search.json`
- Confidence: high for bodies; the advance writer is NOT located (no guess)
- Notes: `FUN_005289F0(param)` = PetsScreen pet slots (`param < 0x18` toggles slot object
  `+0x130`, sets current `+0xA4`); `param == 99` confirm: copies 24 slot flags (objects at `+0x14`,
  stride 4) into `profile+0x5A+i`; when `this+0x9C <= 2` (fewer than 3 pets) shows the
  `"Are you sure you want to continue to the next level without selecting 3 pets?"` /
  `"...at least 3 pets?"` dialogs (branch `this+0xA8 < 4`); then `FUN_0054AF90()` and either
  reload pets into the running tank (`manager+0x730 != 0`: `FUN_00538940()` + `FUN_0053DB80(0)`)
  or start the level `FUN_0054CBF0()` (EV-0061); `param == 100` = back (`FUN_00552100`).
  `FUN_00552100` spawns the next-screen object 0xE8 (`FUN_0052E070`) at `manager+0x738`.
  `FUN_00552380`: clears `profile+0x5A..0x71`, tutorial branch (mode 0, tank1, `profile+0x20 < 4`,
  `+0x59 == 0`) -> `FUN_0054C220(1)`; else `FUN_0054C2D0()` (spawns 0x138 screen `FUN_00527820` at
  `manager+0x80C`) or `FUN_0054CBF0()`. `FUN_005527C0` = UI event dispatcher (switch over 0..0x28,
  0xBBB/0xBBC/0xBD0-0xBE0, 2000+x, 3000+x; ids 4 and 0x14 call `FUN_0054CBF0`). Sandbox entry
  `FUN_005177E0`: `profile+0xB0 > 5` -> `mode = 3`, `profile+0xB4 = max(profile+0xB4, 11)`,
  `FUN_0054B360()` + `FUN_0054CBF0()`. Challenge-mode pet unlock bytes `profile+0x77+i` gate pet
  buttons in `FUN_0051A500` (HatchScreen layout helper; Time Trial gates by `profile+0x1C` and
  `+0x59`). `FUN_00525A60` = end-credits/victory sequence (uses `"Congratulations!"`,
  `"You've successfully vanquished the alien hordes!"`, pet-loss jokes keyed on `DAT_005e9080`,
  then the full PopCap credits roll; a second `"Congratulations!"` xref at 0x51D1D6 not yet
  examined). **Open:** no writer of `profile+0x1C/+0x20` (tank/level advance) located this pass;
  bounded `search-bytes` `C7 ?? 20 01 00 00 00` in `.text` -> 5 hits (`FUN_004B2010` 0x4B242E,
  `FUN_00501530` 0x501541, `FUN_0051A500` 0x51A5BF = stack local, 2x CRT); first two unexamined
  -> Q-0012.

### EV-0066 - P2.6 second pass: tank/level advance writer `FUN_00501370`, profile reset, pet/Shell accessors (Q-0012 ANSWERED)
- Date: 2026-10-20
- Type: observation (decompile + xrefs)
- Source: `docs/evidence/p2.6b-advance-profile.json` (`ev_40de37a5` `FUN_00501370`,
  `ev_0766ab6...` `FUN_00501530`, `ev_8d0a8d8...` `FUN_00501200`, `ev_19ddeeb...` `FUN_00501410`,
  `ev_a022616...` `FUN_00501420`, `ev_c328e99...` `FUN_005014D0`, `ev_c146e83...` xrefs)
- Confidence: high for bodies and call sites; field naming (`+0x50`, `+0x58`, `+0x59`) is
  inference from use
- Notes: `FUN_00501370` (ECX = `profile`) is the tank/level advance writer Q-0012 asked for:
  (1) `profile+0x20++` (level++);
  (2) if `tank+0x1C == 4 && level+0x20 == 6` -> tank = 5, level = 1 (normal tank-4 completion);
  (3) if `tank == 5 && level > 1` -> `profile+0x50++` and `profile+0x59 = 1`;
  (4) if `level > 6 || (profile+0x59 != 0 && level > 5)` -> tank++, level = 1;
  (5) always `profile+0x58 = 1`.
  Call sites: 0x545D41 and 0x545D88 inside `FUN_00545960` (egg handler), and 0x547B31 inside
  `FUN_00547610` (tank update / bonus transition). `+0x50` therefore increments on **every**
  tank-5 level completion past L1, not demonstrably once per run; `+0x59` is the Bonus Adventure
  flag (EV-0063/EV-0073) and is set by the first tank-5 L1 completion. `+0x58` is written but
  its reader was not located (Q-0015).
  `FUN_00501530` (ECX = `profile`) is the new-profile reset: tank = level = 1; owned-pet count
  `+0x18 = 0`; `+0x4C/+0x50/+0x54 = 0`; `+0xB4 = 3`; `+0x84 = 0` + `FUN_005014D0(1,1)` (bit 1 of
  `+0x84`); `+0x98/+0x88 = FUN_0040F9E0()`; clears `+0x78..+0x80`; clears the 24 owned-pet bytes
  `+0x00..0x17` and the 24 selected-pet bytes `+0x5A..0x71`; `+0x72 = 0`, word `+0x76 = 0`,
  `+0xA0/+0xA4 = 0`, then `+0x72 = 1`; `+0xA8/+0xAC/+0xB0 = 0`; Shells `+0x48 = 200`; the 29-int
  score/story table `+0xB8..+0x128` = -1; `+0x59 = +0x58 = 0`. Callers: 0x50374A ->
  `FUN_00503730`, 0x504E3B -> `FUN_00504E00`, 0x51471A -> `Catch@00514717`.
  Accessors: `FUN_00501410(i)` returns raw owned-pet byte `profile+i`; `FUN_00501420(i,v)` writes
  it and adjusts `profile+0x18` only when the value changes (`v == 0` decrements, non-zero
  increments); `FUN_00501200(n)` adds `n` to Shells `profile+0x48` clamped to 0..9,999,999;
  `FUN_005014D0(bit,val)` sets/clears bit `1 << (bit & 0x1F)` in `profile+0x84`.

### EV-0067 - P2.6 second pass: egg-completion branches, pet index/name table, tank-4 L5 no-pet rule, Presto + 5000 Shells
- Date: 2026-10-20
- Type: observation (decompile + assembly re-check)
- Source: `docs/evidence/p2.6b-egg-unlock.json` (`ev_345b0cc...` `FUN_00545960`,
  `ev_66190be...` instructions, `ev_a7d6f38...` `FUN_0054BE80`, `ev_cb90483...` `FUN_00538040`);
  `docs/evidence/p2.6b-transition-verify.json` (`ev_8d57342...` `FUN_0051F770`)
- Confidence: high
- Notes: `FUN_00545960` (egg-purchase handler) increments `Tank+0x43C`; at `>= 4` it records
  `Tank+0x3FC = FUN_00538040()` seconds, clears `Tank+0x4EE`, collects coins `FUN_0053C2D0`, then
  branches:
  - **Mode 4 (Challenge):** `profile+0x77+tank = 1` for tanks 1-4; `FUN_005144C0(tank, profile,
    Tank+0x3FC)`; `FUN_0054BF60` (BonusScreen). No level advance.
  - **`profile+0x59 != 0` (Bonus Adventure):** tank 5 + level 1 -> `FUN_00501370()` then
    `FUN_0054BF60`; every other level -> `FUN_0053DC10()` (finalizer/fast path, EV-0068).
  - **Normal Adventure:** `FUN_00501370()` first, then pet grant from the **post-advance** tank/
    level fields `Tank+0x3C8/+0x3CC`: tank 5 -> index 19; tank 4 + level 5 -> `EDI = 0x3E7`
    (999) and jump straight to `FUN_0054BE80(999)` with **no** `FUN_00501420` grant; otherwise
    `index = tank*5 - 6 + level`. `FUN_00501420(index,1)` grants the pet; index 19 also adds
    5000 Shells (`PUSH 0x1388` -> `FUN_00501200`); then `FUN_0054BE80(index)` (HatchScreen).
  `FUN_00514510(tank, level, profile, score)` receives `score` = `Tank+0x3FC` level time for
  non-tank-5 completions, but for tank 5 the assembly replaces it with the count of empty pet
  slots `Tank+0x144+i` (excluding index 0x12) plus the combined lengths of lists `Tank+0xB0`/
  `+0xB4`; the empty-slot indices are also copied to `DAT_005e8fe0` and their count to
  `DAT_005e9080` (used by the credits pet-loss jokes). ECX = `manager+0x8AC`; the record is at
  `manager+0x8AC+100+FUN_00500DD0(tank,level)*12`. `FUN_005144C0(tank, profile, time)` uses
  Challenge records at `+0x34+(tank-1)*12`.
  Pet index -> display name, proven by the switch in `FUN_0051F770`:
  0 STINKY, 1 NIKO, 2 ITCHY, 3 PREGO, 4 ZORF, 5 CLYDE, 6 VERT, 7 RUFUS, 8 MERYL, 9 WADSWORTH,
  0xA SEYMOUR, 0xB SHRAPNEL, 0xC GUMBO, 0xD BLIP, 0xE RHUBARB, 0xF NIMBUS, 0x10 AMP, 0x11 GASH,
  0x12 ANGIE, 0x13 PRESTO, 0x14 BRINKLEY, 0x15 NOSTRADAMUS, 0x16 STANLEY, 0x17 WALTER; 999 =
  "Evil Alien Mastermind". Index 19 also displays "You have been awarded 5000 shells for
  defeating the Final Boss!". **Correction to the first-pass note:** tank-4 L5 does not grant a
  pet; it shows the 999 "Evil Alien Mastermind" hatch card and then starts tank 5.

### EV-0068 - P2.6 second pass: level-6 sentinel, finalizer, bonus timing, two-stage transition, tank-complete event
- Date: 2026-10-20
- Type: observation (decompile + xrefs + assembly re-check)
- Source: `docs/evidence/p2.6b-level6-finalizer.json` (`ev_dda5ffe...` `FUN_0054CBF0`,
  `ev_e124fca...` `FUN_0054B2A0`, `ev_bb1b689...` `FUN_0054B2D0`, `ev_c70dd18...` `FUN_00537E20`,
  `ev_55772c8...` `FUN_0054B020`), `docs/evidence/p2.6b-transition-verify.json`
  (`ev_2468562...` `FUN_00537F40`, `ev_500f653...` `FUN_00547610`), `p2.6-levelcomplete-53DC10.json`
- Confidence: high for bodies; the exact meaning of the 160-frame wait is inferred from the
  threshold `0xA0`
- Notes: `FUN_0054B2A0` is the tank-complete sentinel: true when mode 0 and `profile+0x20 == 6`,
  or when the live tank's `+0x2A5` is set. `FUN_0054CBF0` branches on it: `FUN_0054C540` (new
  tank) -> `FUN_00541A20` -> sentinel true -> `FUN_00537E20` + `FUN_0054B2D0` (no session init);
  mode 5 -> `FUN_0053C3F0` + `FUN_0054B2D0`; else `FUN_005498B0` + `FUN_0054B2D0`.
  `FUN_00537E20` (Tank finalizer): clears `[Tank+0x118]+0xD0`; `+0x2A8 = +0x444`;
  `+0x2BC = 0`; `+0x94 = 0`; `+0x2A5 = 1`; `+0x2A4 = 0`; clears globals `DAT_005e89dc`,
  `DAT_005e89cc`, `DAT_005e89d0`, `DAT_005e89c0` and sets `DAT_005df58c = 1`; clears
  `+0x440/+0x450/+0x454/+0x45C/+0x458`; sets bonus timer `+0x3BC` = base by tank (default/tank1/
  tank5 10, tank2 15, tank3 20, tank4 25) + clamp(level,1,6) - 1; `+0x3F4 = +0x3F8 = 0`;
  `+0x2AC = -1`; `+0x2B0 = 0`; `+0x3B4 = +0x3B8 = now`.
  `FUN_00537F40` (bonus starter): if `level != 6` calls `FUN_0054B2D0` (tank-complete event);
  sets `+0x2A4 = 1`, resets `+0x3B4/+0x3B8`, `+0x3B0 = 0`, `+0x2A8 = +0x444`.
  `FUN_00547610` (tank update) runs the two-stage transition: if `+0x2A5 != 0 && +0x2A4 == 0`
  and `+0x444-+0x2A8 > 0x9F`, call `FUN_00537F40`; when `+0x2A4 != 0` and the bonus timer
  `+0x3BC-(now-+0x3B8)/1000 < 0`, then require coin list `Tank+0xA8` empty and the **old**
  `+0x3F8 > 100` (increment happens in the condition), then `FUN_00501370()`, call
  `FUN_00514510(tank,level,profile,Tank+0x3FC)` **only if post-advance level < 6**, then
  `FUN_0054BF60()` (BonusScreen). `FUN_0053DC10` = Bonus Adventure fast path: `+0x4EE = 1`,
  `FUN_0053C480([Tank+0x10])`, `FUN_0054B020`, event `FUN_0054B1A0(2,0x36,0)`, `FUN_00537E20`.
  `FUN_0054B020` clears overlay slots 0-4 on `manager+0x374` and sets `manager+0x88C/+0x890 = -1`.
  `FUN_0054B2D0` maps the tank-complete event (mode 5 skipped): level-6 sentinel ->
  `FUN_0054B1A0(0,0xD,0)`; current tank 1 -> `(0,0x16)`, tank 2 -> `(0,0)`, tank 3 ->
  `(2,0x20)`, tank 4 -> `(2,0x2D)`, tank 5 -> none.

### EV-0069 - P2.6 second pass: BonusScreen payout, HUD, Shells/save helpers, `scr%d.dat` persistence
- Date: 2026-10-20
- Type: observation; explicit unknown (file format, `+0x50` run semantics)
- Source: `docs/evidence/p2.6b-bonus-payout.json` (`ev_975b1af...` `FUN_0051C8E0`,
  `ev_4d29cc8...` `FUN_0053EAF0`, `ev_86c6f02...` `FUN_00514B00`, `ev_59c3f98...` `FUN_005148C0`,
  `ev_ac8770a...` `FUN_00515910`), `docs/evidence/p2.6c-bonus-store-calls.json`
  (`ev_07f341fb...` `FUN_0054BF60`), `docs/evidence/p2.6b-victory-ui.json` (`ev_ce804cb...`
  `FUN_0052DAD0`)
- Confidence: high for the switch/formula; medium for the save-file semantics
- Notes: `FUN_0051C8E0` (BonusScreen ctor helper) sets the reward `this+0xBC` and always ends at
  `FUN_00501200(reward)` (adds to `profile+0x48`):
  - mode 0, tank != 5: reward = `Tank+0x3F4`; labels "Level Time"/"Your Best Time".
  - mode 0, tank 5: reward = `max(1, profile+0x50-1)*5000` capped at 25000; labels "Surviving
    Pets"/"Your Score"/"Your Best Score". (First completion `+0x50 == 1` -> 5000; because
    `FUN_00501370` increments `+0x50` on every tank-5 level >1 completion, the exact
    "completed-run" meaning is open -> Q-0015.)
  - mode 1: reward = `Tank+0x3F0*5/100`, text "%d%% Bonus Award".
  - mode 4: tank 1/2/3/4 -> 2000/5000/10000/20000, labels "Level Time"/"Your Best Time".
  - other modes: no explicit reward branch (constructor-initialized `this+0xBC` is still added).
  If no tank exists (`manager+0x730 == 0`) it only fills placeholder "Level Info"/"Bonus
  Reward" records and returns without paying.
  `FUN_0053EAF0` renders "BONUS ROUND", "Collect as many shells as you can!", `Tank+0x3F4`, and
  `"Time Remaining: %d:%02d"` from `Tank+0x3BC - Tank+0x3B0` (when `+0x2A4`); `+0x3F8` controls
  the blinking counter.
  `FUN_0054BF60` sets `manager+0x884 = 1`, clears `Tank+0x4EE`, calls `FUN_0054AE30`, calls
  `FUN_00514B00()` when a profile exists, spawns BonusScreen 0x18C (`FUN_0052DAD0`) at
  `manager+0x818`, then `FUN_0054AFD0`/`FUN_0054BC30`/`FUN_0054B020`/`FUN_0054B1A0(2,0x36,0)`.
  `FUN_0052DAD0` also disables "Click Here To Continue" when `profile+0x1C == 5 &&
  profile+0x20 == 2` (tank-5/L2 interlude gate), and adds "Click for Story Time" in mode 4.
  `FUN_00514B00` reads `FUN_005148C0(1)`, ignores values <1, clamps >= 100001 to 100000, calls
  `FUN_00501200(value)`, stores now at `this+0x88`, and saves via `FUN_00514730`.
  `FUN_005148C0` formats `userdata/scr%d.dat` with `this+0x44`, deserializes it (`FUN_0047F5D0`),
  reads a stored integer, compares it with `this+0x88` (the bonus timestamp), and on a match
  consumes 50 filler ints + 1 + 50 filler ints. `FUN_00515910(param)` writes
  `FUN_005148C0(0)+param` to the same file surrounded by 50 `rand()%20000` ints
  (caller 0x546A5E). The serializer/return path and whether the file is encrypted/obfuscated are
  not established -> Q-0019.

### EV-0070 - P2.6 second pass: normal per-level alien types, demo-only selector, wave spawner/countdown
- Date: 2026-10-20
- Type: observation (decompile + assembly + bounded searches)
- Source: `docs/evidence/p2.6b-selector-waves.json` (`ev_2442c61...`/`ev_d080674...`
  `FUN_00537C20`, `ev_bff19b4...` `FUN_00545620`, `ev_c863438...` xrefs, `ev_016dd23...` etc.
  byte reads)
- Confidence: high
- Notes: `FUN_00537C20` writes `Tank+0x2BC` from a pool by **tank** (no level): tank1 {2,3},
  tank2 {2,3,4,5}, tank3 {3,4,5,7,6}, tank4 {3,4,5,7,6,8}; no tank-5 case. Its only xrefs are
  0x5412E4 (inside the `manager+0x880 != 0` demo branch of `FUN_00541200`) and 0x548BB6 (inside
  the `manager+0x880 != 0` demo branch of the wave block in `FUN_00547610`) - i.e. the selector
  is demo-only; the normal path uses fixed per-level types assigned by `FUN_00541200`:
  tank1 L1 0, L2 1 (+`Tank+0x2C0 = 0x6D6` = 1750), L3 2, L4/L5 3; tank2 L1 2, L2 3,
  L3 4, L4 5, L5 4|5; tank3 L1 3, L2 4|5, L3 7, L4 6, L5 6|7; tank4 L1 3, L2 8, L3 4,
  L4 8, L5 8; tank5 0x15 (Cyrax). The wave block then re-rolls variants at L5: tank2 picks
  4/5, tank3 6/7, and tank4 stays 8; it also maps tank4 L3 to 10/11, L4 to 11/12, L5 to
  8/10/(11 or 12) by `rand()` (mode 4 substitutes 0xC after 4 waves).
  `FUN_00545620` spawns composite waves: 9 = 1 + 3, 10 = 7 + 3, 11 = 5 + 6, 12 = 3 + 8;
  boss type 0x15 sets `Tank+0x4EE = 1`, stores the alien at `Tank+0x110`, sets `+0x3E4 = 10`.
  Arrival countdown `Tank+0x2C0` starts at 3000 after each wave: at 276 a message/tutorial
  block, at 33 a sound, at 30 `FUN_00543F40` warning, at 1 an event; it resets to 3000.
  Bounded `search_bytes BC 02 00 00` and `C0 02 00 00` in `.text` 0x401000-0x5B0000 returned 84
  and 30 hits dominated by unrelated immediates, so absence of other writers is not proven.

### EV-0071 - P2.6 second pass: victory gate, Interlude, pre-bonus StoreScreen, bonus-card/trophy correction, credits open
- Date: 2026-10-20
- Type: observation; explicit unknown (credits trigger)
- Source: `docs/evidence/p2.6b-victory-ui.json` (`ev_5ffcf03...` `FUN_0054BD80`,
  `ev_93af8ee...` `FUN_00517C70`, `ev_9331bc7...` `FUN_0051E060`, `ev_a710c49...`
  `FUN_0051CF30`, `ev_5e26860...` `FUN_0051E280`, `ev_2b70879...` `FUN_005256E0`,
  `ev_cd09cb4...` resolve 0x51D1D6), `docs/evidence/p2.6c-store-interlude.json`
  (`ev_9b3921d3...` `FUN_0054BCA0`, `ev_c46b6b1e...` `FUN_0052B2D0`, `ev_48e61dcf...` handler),
  `docs/evidence/p2.6c-bonus-store-calls.json` (`ev_a48d9e2a...` ctor re-read)
- Confidence: high for spawners/gates; medium for the role of the tank-5/L2 state
- Notes: tank-5 victory gate: `FUN_00517C70` (param 99 = confirm, 100 = back) and
  `FUN_0051E060` (param 0/2) both test `profile+0x1C == 5 && profile+0x20 == 2` and call
  `FUN_0054BD80`, which allocates object 0xB8, ctor `FUN_005256E0` (`Sexy::InterludeScreen`) at
  `manager+0x81C`; the ctor creates the "Back To Main Menu" button. Xrefs to `FUN_0054BD80` are
  0x517CE5 and 0x51E10E. The tank-5 L1 completion advances the profile to tank 5/level 2
  (EV-0066) and grants Presto + 5000 Shells (EV-0067); level 2 is therefore a victory-gate
  state, not a second played boss level (wiki, EV-0074).
  `FUN_0054BCA0` is the pre-bonus-pet StoreScreen spawner (not the Interlude): it optionally
  calls `FUN_0053DB80(1)`, calls `FUN_00514B00()` when a profile exists, allocates 0xBB0, ctor
  `FUN_0052B2D0` (`Sexy::StoreScreen`) at `manager+0x810`, positions it, and adds it to the list
  at `manager+0x320`. It is case 10 of UI handler `FUN_0054A370` (jump/data table 0x5A83E4;
  call site 0x54A3BE); xref to 0x54BCA0 is only 0x54A3BE; xref to 0x52B2D0 is 0x54BD10.
  `FUN_0052B2D0` sets `Sexy::StoreScreen` + `Sexy::ButtonListener` vtables, manager at
  `this+0x8C`, caches `manager+0x320`, creates 8 child item objects via `FUN_005331A0` (slot
  array at `this+0x9C`), builds a Shell counter via `FUN_00534600` + "%d", calls
  `FUN_0054B020`/`FUN_0054B1A0`, and attaches a 640x480 `StoreScreenOverlay`. It does **not**
  read `profile+0xB0`; item population/price display lives in the child/update code
  (not decompiled) -> Q-0018.
  Bonus-pet/upgrade card correction: the second `"Congratulations!"` at 0x51D1D6 resolves to
  `FUN_0051CF30`, which is the **bonus-pet/upgrade purchase card**, keyed on `profile+0xB0`:
  1-4 -> Brinkley/Nostradamus/Stanley/Walter (with "You Have Bought" and per-pet joke text);
  5 -> "FOUR pets?!!! That's INSANE!"; 6 -> "SEVEN pets at the same time!" (plus the Virtual
  Tank disclaimer). It is not a victory screen. `FUN_0051E280` title tooltip cases 5/6 are
  "Wow!  Nice trophy!" and the solid-gold-trophy text; the only xrefs to those strings are
  0x51E3DF/0x51E3D8 inside `FUN_0051E280`, i.e. title-menu tooltips, not the victory flow.
  Credits sequence `FUN_00525A60` still has only the data xref 0x5A0E4C; its trigger is not
  located -> Q-0016.

### EV-0072 - P2.6 second pass: corrected store tables, Shells routing, level-start/tank creation counters
- Date: 2026-10-20
- Type: observation; correction of EV-0062
- Source: `docs/evidence/p2.6b-shells-routing.json` (`ev_e0dd8c8...` `FUN_0053C1E0`,
  `ev_c124896...` `FUN_00541200`), `docs/evidence/p2.6b-flow-verify.json` (`ev_27b0f9d...`
  `FUN_00541A20`, `ev_8a3244b...` `FUN_0054C540`, `ev_62a6342...` `FUN_00542150`),
  `docs/evidence/p2.6b-advance-profile.json` (`ev_40de37a5` etc.)
- Confidence: high
- Notes: `FUN_0053C1E0(n)` routes Shells: mode 5 -> add to `profile+0x48` (unless
  `thunk_FUN_00479FC0()` is true) and add to `Tank+0x400`; tank complete (`Tank+0x2A5`) ->
  `Tank+0x3F4`; otherwise `Tank+0x3F0` + `Tank+0x460`, capped 9,999,999.
  `FUN_00541200` normal-mode store tables (A[item] = slot, B[item] = price; egg price by level):
  - tank1: items 0->0 (100), 2->1 (200), 3->2 (300), 4->3 (1000), 10->5 (1000), 11->6
    (150/500/2000/3000/5000). L1 hides 2,3,4,10; L2 hides 4,10; L3-L5 show all.
  - tank2: items 0->0 (100), 2->1 (200), 3->2 (300), 5->3 (250), 6->4 (750), 10->5 (1000),
    11->6 (750/3000/5000/7500/10000). L1 hides **6 and 10 only**; L2-L5 show all.
  - tank3: items 0->0 (100), 2->1 (200), 3->2 (300), 7->3 (750), 8->4 (2000), 10->5 (2000),
    11->6 (1000/5000/7500/10000/15000). L1 hides 8,10.
  - tank4: items 1->0 (200), 2->1 (200), 3->2 (300), 4->3 (1000), 9->4 (10000), 10->5 (5000),
    11->6 (3000/25000/50000/75000/99999). L1 hides 9,10.
  - tank5: item 11->6, price 0, `Tank+0x43C = 3`, `Tank+0x2BC = 0x15`.
  Mode 4 overrides egg price to 5000 (tank2), 15000 (tank3), 25000 (tank4); mode 1 sets egg
  price 100. The demo branch (`manager+0x880 != 0`) builds a fuller store and is the only path
  that runs the 12x `FUN_005409B0` + `FUN_00537C20` block. **Corrections to EV-0062:** tank2 L1
  hides items 6+10 only (the earlier "L1-2 hide weapon" is wrong); tank4 item 9 is Ultravore at
  store slot 4 for 10000 (not Beetlemuncher). Normal store-item object ownership remains open
  (xrefs 0x4F18xx tutorial loop, 0x54782A tank update) -> Q-0018.
  `FUN_00541A20` (Tank level start): mode 0 -> `Tank+0x3C8/+0x3CC = profile+0x1C/+0x20`; other
  modes -> tank = `manager+0x888`, level = 5; money 999999 (mode 3) else 200; `+0x4AC = 5`;
  `+0x2C0 = 3000`; `+0x2A4 = +0x2C8 = +0x2A8 = 0`; `+0x43C = 1`; `+0x3E4 = 2`; `+0x2BC = 2`
  (overwritten by the store init); demo -> `+0x3E4 = 8`, money 200. `FUN_0054C540` allocates
  0x504 bytes, ctor `FUN_00542150`, stores at `manager+0x730`, adds to the list at
  `manager+0x320`, and increments `profile+0x4C` (sessions started); the ctor clears
  `+0x2A5`/`+0x4EE`, so a fresh tank cannot re-finalize a previous tank.

### EV-0073 - P2.6 second pass: session init corrections and the normal vs Bonus Adventure lifecycle
- Date: 2026-10-20
- Type: observation; inference (tank-5 "L2 as gate" role; `+0x50` semantics)
- Source: `docs/evidence/p2.6b-flow-verify.json` (`ev_514e04a...` `FUN_005498B0`),
  `docs/evidence/p2.6b-egg-unlock.json`, `docs/evidence/p2.6b-transition-verify.json`,
  `docs/evidence/p2.6b-level6-finalizer.json`
- Confidence: high for conditions/banners/timers; medium for lifecycle role labels
- Notes: session init `FUN_005498B0` pet branch is exactly
  `(profile+0x59 == 0 || (mode != 1 && mode != 4)) && profile+0x18 < 4` -> loop i 0..0x12 and
  create every **owned** pet byte set by `FUN_00501410(i)`; otherwise loop i 0..0x17 and create
  pet i when `profile+0x5A+i != 0` (selected pets). Tank 5 additionally sets `Tank+0x2C0 = 300`
  and unconditionally creates pets 0..0x11 (18: Stinky..Gash, excluding Angie 0x12 and Presto
  0x13 and bonus pets). Tank 4 uses decoration `FUN_005471E0` once; other tanks use
  `FUN_00546EF0` twice; tank1 L1 marks two objects `+0x228 = 1`; demo uses only `FUN_00546EF0`
  twice. Banners: tank1 L1 mode 0 + `+0x59 == 0` -> "Welcome to the Insaniquarium!"; +`0x59 != 0`
  and `+0x50 == 1` -> "Welcome to the Bonus Adventure!"; tank1 L2 -> "Welcome to the next
  level!"; tank2 L1 -> "Welcome to the second tank! Now things get tricky!"; mode 4 ->
  "Welcome to Challenge mode!"; mode 3 -> "You've discovered the top-secret SANDBOX mode!";
  mode 1 -> "Welcome to Time Trial mode!" with `+0x3BC` 300 (tank1) / 600 (tanks2-4) and
  `+0x3BC/0x3C` minutes; mode 5 -> none. End: clears `+0x444/+0x450/+0x454/+0x45C/+0x458`,
  `+0x3B4 = +0x3B8 = now`, `+0x4E8 = 0`, `+0x4E6 = 0`.
  Lifecycle now closed: normal L1-L4 -> advance + pet + HatchScreen -> pet selection -> next
  level; L5 -> advance to level 6 + last pet + Hatch; after pet selection, `FUN_0054CBF0`
  sees `profile+0x20 == 6`, runs `FUN_00537E20` + `FUN_0054B2D0` (tank-complete event), then
  `FUN_00547610` waits >= 0xA0 frames, starts the bonus (15/20/25 s for tanks 2/3/4), waits for
  the timer + empty coin list + `+0x3F8 > 100`, advances to the next tank L1, and opens
  BonusScreen. Tank4 L5 skips the pet grant (EV-0067) and starts tank5 L1 directly; tank5 L1
  -> L2 + Presto + 5000 Shells -> Hatch -> interlude gate (EV-0071). Bonus Adventure
  (`profile+0x59 != 0`) uses the fast path on **every** level: `FUN_0053DC10` -> finalizer ->
  bonus 10/15/20/25 + level-1 seconds -> advance -> BonusScreen; tank5 L1 -> L2 + BonusScreen
  with no Presto/Hatch. This matches the wiki's "bonus after each tank except 4 and 5; every
  stage in Bonus Adventure" (EV-0074). `+0x58` is set by every advance but its reader is
  still open (Q-0015).

### EV-0074 - P2.6 wiki-ref second pass: Bonus Round, Tank 5, Challenge, Pets, Time Trial (access 2026-10-20)
- Date: 2026-10-20
- Type: wiki-ref (D-0010; secondary source)
- Source: `https://insaniquarium.fandom.com/wiki/Bonus_Round?action=raw` (fetched 2026-10-20),
  `https://insaniquarium.fandom.com/wiki/Tank_5?action=raw` (fetched 2026-10-20); the following
  were fetched successfully earlier in the same pass and retried unsuccessfully on 2026-10-20
  (HTTP 403): `Pets`, `Challenge_Mode`, `Time_Trial_Mode`
- Confidence: wiki claims only; binary bindings cited in EV-0066..EV-0073
- Notes: Bonus Round page: bonus after each tank **except Tanks 4 and 5** in Adventure, after
  **each individual stage** in Bonus Adventure; shells collected go to the player's Shell
  balance for Virtual Tank purchases; "3, 2, 1" countdown, bucket, timer, shell lineup; shell
  values Silver 1, Gold 2, Blue Conch 5, Silver Spiral 10, Bag O' Shells 20; time increases
  slightly each round; combos multiply by combo length (max 10) and max at 500/250/125 etc.
  Tank 5 page: only one level, the Cyrax boss battle; egg piece costs no money; no food/laser/
  fish/food-chain upgrades; 18 pets available (Stinky..Gash); Presto unlocked (delayed from
  Tank 4-5); after defeating Cyrax with at least one pet, the player earns 5000 shells and a
  credits scene (Angie revives dead pets, then cast/staff roll); completing Adventure unlocks
  Bonus Adventure, which has bonus rounds after every level. The page also lists the six
  "pets survived" messages (8-12 ... 18) used by the credits.
  Challenge Mode page (earlier fetch): 32 stories plus a 33rd gold-trophy ending. Pets page
  (earlier fetch): unlock order per tank/level (Stinky 1-1 ... Presto 5-1); bonus pets after
  Bonus Round/Time Trial; four bonus pets -> 4-pet upgrade -> 7-pet VT -> 11 with Sandbox.
  Time Trial page (earlier fetch): timer 5%/10% and 5% of money converted to shells.
  Conflicts/nuances kept open: (1) Tank 5 says one level while the binary gate is tank5/L2
  (EV-0071); the L2 state is read as the victory marker, not a second played level.
  (2) Tank 5 says 5000 shells + credits after defeating Cyrax; the binary grants the 5000 at
  the Presto HatchScreen (index 19) and the credits trigger is still unfound (Q-0016).
  (3) "Bonus after tanks 1-3 only" matches binary normal Adventure, but Bonus Adventure gets
  one after every level including tank4 L5 (EV-0073). (4) The Pets page's "4 pets -> 7 -> 11"
  capacity is not yet bound to `profile+0xB0` (which is 1-6 for bonus cards) or `profile+0xB4`
  (reset 3; Sandbox raises to 11) -> Q-0013. (5) Time Trial's 5%/10% timer wording is not yet
  matched to the binary 300/600 s and 5% money award (EV-0069) -> P2.11.

### EV-0075 - P2.6 second pass: explicit unknowns and bounded negative searches
- Date: 2026-10-20
- Type: explicit unknowns
- Source: current pass (EV-0066..EV-0074); `docs/evidence/p2.6b-selector-waves.json`
  (`ev_a602464...`/`ev_d33309f...` `search_bytes`), `p2.6b-victory-ui.json`
  (`ev_aaf22c4...` xrefs 0x525A60), `p2.6b-bonus-payout.json`
- Confidence: high that these are unresolved
- Notes:
  - Credits trigger: `FUN_00525A60` has only the data xref 0x5A0E4C; no code xref. Q-0016.
  - Trophy/story award: `profile+0xB4` is reset to 3 and Sandbox raises it to 11;
    `profile+0xB0` is the bonus-pet/upgrade card index (1-6). No writer/reader was found that
    maps Challenge stories 1-32 or the 33rd gold trophy onto these fields. Q-0013.
  - Mode 2: still unobserved; do not assign a name/behavior (P2.11). Q-0014.
  - `profile+0x58`: set to 1 by every `FUN_00501370` call, reader not located. Q-0015.
  - Tank 6: `FUN_00501370` can increment to tank 6 if `profile+0x59 != 0` and level > 5, but
    `FUN_0054B2A0` checks only `profile+0x20 == 6`, `FUN_00541200` has no tank-6 case, and
    `FUN_0054B2D0` has no tank-6 event. Q-0017.
  - StoreScreen item population/price display is not in `FUN_0052B2D0`; the normal store-item
    object owner is also unresolved (xrefs 0x4F18xx tutorial loop, 0x54782A tank update).
    Q-0018.
  - `userdata/scr%d.dat`: serializer/obfuscation, return path of `FUN_005148C0`, and exact
    meaning of the stored timestamp/value pair are unresolved. Q-0019.
  - `profile+0x50`: increments on every tank-5 level >1 completion; whether it counts runs,
    boss wins, or tank-5 levels is not proven (payout first win 5000 is consistent either way).
  - Bounded `search_bytes` for immediates `BC 02 00 00` / `C0 02 00 00` in `.text`
    0x401000-0x5B0000 (84 / 30 hits) is too noisy to prove the set of `Tank+0x2BC`/`+0x2C0`
    writers; the writers cited in EV-0070 are those actually decompiled.
  - The hostile alien classes remain absent from RTTI (Q-0011); type ids 9-12/0x15 are observed
    spawn selections only, not class identities (P2.8).

### EV-0076 - P2.6 second pass: corrections - pet reward uses the completed session's level; normal bonus duration table
- Date: 2026-10-20
- Type: correction of EV-0067 and EV-0073
- Source: `docs/evidence/p2.6b-egg-unlock.json` (`ev_345b0cc...` `FUN_00545960`),
  `docs/evidence/p2.6b-advance-profile.json` (`ev_40de37a0...` `FUN_00501370`),
  `docs/evidence/p2.6b-level6-finalizer.json` (`ev_c70dd18...` `FUN_00537E20`)
- Confidence: high (both corrections are directly in the cited bodies)
- Notes:
  (1) EV-0067 described the pet grant as reading "post-advance" `Tank+0x3C8/+0x3CC`. That is
  wrong: `FUN_00501370` writes only `profile+0x1C/+0x20`, and `FUN_00545960` reads the Tank's
  level-start copies `Tank+0x3C8/+0x3CC`, which still hold the **completed** level. Therefore
  `index = tank*5 - 6 + level` uses the level just completed: tank1 L1 -> 0 Stinky, L2 -> 1
  Niko, L3 -> 2 Itchy, L4 -> 3 Prego, L5 -> 4 Zorf; tank2 L1 -> 5 Clyde ... L5 -> 9 Wadsworth;
  tank3 L1 -> 10 Seymour ... L5 -> 14 Rhubarb; tank4 L1 -> 15 Nimbus, L2 -> 16 Amp, L3 -> 17
  Gash, L4 -> 18 Angie, L5 -> special-cased 999 (no grant, because the formula would yield 19 =
  Presto); tank5 L1 -> 19 Presto + 5000. The tank4-L5 special case tests the same
  `Tank+0x3C8 == 4 && Tank+0x3CC == 5`. This matches the wiki unlock order "Stinky 1-1 ...
  Presto 5-1" (EV-0074).
  (2) EV-0073's parenthetical "bonus (15/20/25 s for tanks 2/3/4)" is wrong. `FUN_00537E20` sets
  `Tank+0x3BC = base(tank) + clamp(level,1,6) - 1` with base default/tank1/tank5 = 10, tank2 =
  15, tank3 = 20, tank4 = 25. The normal tank-complete path runs at profile level 6 (sentinel),
  so tanks 1/2/3 get 15/20/25 s. Tank 4 never reaches the sentinel (its L5 advances straight to
  tank5 L1, EV-0067), and tank 5 uses the per-level fast path (10 + level - 1 s). All other
  statements in EV-0067/EV-0073 stand.

### EV-0077 - P2.7 roster: 24 gameplay pets plus the 999 display card
- Date: 2026-10-21
- Type: observation (roster)
- Source: `docs/evidence/p2.7-51F770.json` (`ev_8d57342a...` `FUN_0051F770`),
  `docs/evidence/p2.7-petspawn-decompile.json` (`ev_20a52188...` `FUN_00544A90`),
  EV-0067/EV-0076 (pet grant table)
- Confidence: high
- Notes: the gameplay roster is 24 entries, indexes 0x00..0x17:
  0 Stinky, 1 Niko, 2 Itchy, 3 Prego, 4 Zorf, 5 Clyde, 6 Vert, 7 Rufus,
  8 Meryl, 9 Wadsworth, 0xA Seymour, 0xB Shrapnel, 0xC Gumbo, 0xD Blip,
  0xE Rhubarb, 0xF Nimbus, 0x10 Amp, 0x11 Gash, 0x12 Angie, 0x13 Presto,
  0x14 Brinkley, 0x15 Nostradamus, 0x16 Stanley, 0x17 Walter. Index 999
  ("Evil Alien Mastermind") is produced only by the tank4-L5 card branch in
  `FUN_00545960`; it is not a spawnable pet and grants no profile slot
  (EV-0067/EV-0076). The spawn helper `FUN_00544A90` switches on the 24-entry
  index range; 999 has no case. Display-name bindings are in
  `docs/analysis/notes/wiki-refs.md` section 7.

### EV-0078 - P2.7 entity model: OtherTypePet vs FishTypePet, vtables and fields
- Date: 2026-10-21
- Type: observation (class layout)
- Source: `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...`),
  `docs/evidence/p2.7-othertypepet-vt-xrefs.json` (`ev_6cf3eee8...`)
- Confidence: high (ctor writes and vtable dumps)
- Notes: two classes implement all pets. `Sexy::OtherTypePet` (vtable
  `0x596D74`) covers `{0,1,5,7,0xE}` and its vtable ends at slot 80
  (`0x4D8AD0`, destructor); it has no 81+ overrides. `Sexy::FishTypePet`
  (vtable `0x597EC4`) covers every other pet and overrides slots 81
  `0x4E5900`, 82 `0x4E9790`, 83 `0x4F8610` (render), 84 `0x4E02D0`
  (steering), 85 `0x4E5FC0` (targeting), 86 `0x4FE740` (contact/attack),
  87 `0x4DF0B0`, 88 `0x4D5F90`, 89 `0x4DFC50`. OtherTypePet keeps the pet
  index at `+0x1C4`; FishTypePet keeps it at `+0x234`. Field tables and the
  cross-class offset traps are in `p2.7-pets.md` section 2.1.

### EV-0079 - P2.7 pet spawn helper, session pet loading, constructor tuning
- Date: 2026-10-21
- Type: observation (spawn/ctor)
- Source: `docs/evidence/p2.7-544A90.json` (`ev_a40eb69d...`),
  `docs/evidence/p2.7-5498B0.json` (`ev_514e04a3...`),
  `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-4EB7C0.json` (`ev_b2e4642a...`)
- Confidence: high
- Notes: `FUN_00544A90(index,x,y,transformed,?)` is the only pet factory; it
  selects OtherTypePet for `{0,1,5,7,0xE}` and FishTypePet otherwise. With
  `x == -1` it randomizes x in 105..369 and y in 20..539. Mode 5 writes
  `obj+0xAC = 1000 + (transformed ? 0x13 : index)`; index 0x13 forces the
  Presto flag. `FUN_005498B0` spawns pets by two branches: (A) owned flags
  `FUN_00501410(i)` for i=0..0x12; (B) selected `profile+0x5A+i` for
  i=0..0x17; branch choice depends on `profile+0x18 < 4` and mode/
  `profile+0x59` (exact `profile+0x18` semantics open). Ctor constants:
  Stinky y 370/speed 1.2; Clyde 1.5; Rufus y 365; Rhubarb y 355; Prego
  `+0x224=930`, `+0x190=360`; Zorf 65/3.0/270; Vert 216 (1080..1279 VT);
  Meryl 1400 (4320 VT); Wadsworth 120/4.0; Nimbus 0.5/320; Amp
  0.5/3000/460; Gash 1570/1520; Shrapnel 633..652 (1080..1279 VT);
  Nostradamus 300..599 (1080..1279 VT); Stanley 100; Walter flags
  `+0x55=1`, `+0x7C=1`, `+0x70=10`, `+0x78=15`. See `p2.7-pets.md` 2.2.

### EV-0080 - P2.7 shared pet AI: update chains, gates, slots, 36 Hz tick
- Date: 2026-10-21
- Type: observation (framework)
- Source: `docs/evidence/p2.7-4F2E80.json` (`ev_e96f85ec...`),
  `docs/evidence/p2.7-4F7AD0.json` (`ev_434fb0aa...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...`),
  `docs/evidence/p2.7-pet-helpers-batch.json` (`ev_0ae4497a...`),
  `docs/evidence/p2.7-tank-update-batch.json` (`ev_69faeda7...`)
- Confidence: high for the dispatch/gates; derived for 36 Hz
- Notes: `FUN_004F2E80` updates OtherTypePet, `FUN_004F7AD0` updates
  FishTypePet. Common gates: `Tank+0x94 != 0` pauses actions; tank index
  `Tank+0x3C8 == 5` skips the slot-81 action tick; slot 81 is skipped while
  hostiles are present except for Stanley (0x16). `FUN_004E9790` is the
  slot-82 action gate. `FUN_004E5900` is the per-pet timer/action switch and
  is the authoritative source for Prego/Zorf/Vert/Meryl/Shrapnel/Amp/Gash/
  Nostradamus/Stanley timers. `FUN_004E02D0` steers, `FUN_004E5FC0` selects
  targets, `FUN_004FE740` resolves contact, `FUN_004F8610` renders. Pet timers
  are raw 36 Hz ticks: the independent anchors are Blip's `200`/`720`
  thresholds for the wiki's 5 s/20 s (EV-0094), Prego 930 ticks ~= 26 s, and
  Shrapnel 633..652 ~= 18 s. This is a derived rate, not a constant read from a
  clock. Keep all periods as integer ticks.

### EV-0081 - P2.7 Stinky (0x00): bottom-lane coin collector, hide counter
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EB7C0.json` (`ev_b2e4642a...`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_2303a828...` `0x4EBC80`,
  `ev_2ddc8596...` `0x4E7C30`, `ev_07ea6bf6...` `0x4E2A20`)
- Confidence: high
- Notes: OtherTypePet; ctor forces `y = 370.0` and speed 1.2, so he is a
  fixed bottom lane with vx-only steering (not a hard bottom clamp).
  `FUN_004EBC80`/`FUN_004E7270` chase the nearest coin. Excluded kinds:
  3 and 10 while the Penta list `Tank+0xD0` is non-empty; 0x11 (bomb);
  0x12 (snot); coins with the claimed flag `+0x198` set. `FUN_004E2A20`
  index 0 increments the hide counter `+0x1B4` up to 9 while `Tank+0xB8` or
  `Tank+0xF4` is non-empty and zeroes `+0x1BC`; it decrements to 0 when both
  lists are empty. Hidden Stinky does not collect. The wiki's "random target"
  is contradicted by the nearest-coin code; the exact collection cooldown and
  the Nimbus red cosmetic were not isolated (EV-0106).

### EV-0082 - P2.7 Niko (0x01): pearl timer, pearl kind 0xF, render
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-behavior-batch.json` (`ev_07ea6bf6...`
  `0x4E2A20`; `ev_504ee005...` `0x4E2BD0`), `docs/evidence/p2.7-4EB5C0.json`
- Confidence: high
- Notes: OtherTypePet. No fixed perch: spawn is the generic random x/y and the
  update is the generic wander (wiki "stationary" is an open discrepancy).
  `FUN_004E2A20` index 1 runs only when `Tank+0x3C8 != 5`. Timer `+0x1B4`:
  0x4C8 (1224) sound 0x129; 0x4D1 (1233) spawn pearl kind `0xF` at
  `(x+1,y-2)`, clear `+0x1C0`, sparkle at `(x+0xB,y+5)` and `(x+7,y+3)`;
  0x5A0 (1440) sound 0x12A; 0x5AA (1450) close and reset to `rand % 0x32`.
  `FUN_004E2BD0` selects the open/closed/empty frame from `+0x1B4` and
  `+0x1C0`. 1224/1440 ticks = 34/40 s at 36 Hz, matching the wiki.

### EV-0083 - P2.7 Itchy (0x02): nearest-alien melee, 1.0 damage
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-melee-damage.json` (`ev_d796abf4...`
  `FUN_004FB5B0`), `docs/evidence/p2.7-pet-vtable-batch.json`
  (`ev_6946bb69...` `0x4E5FC0`/`0x4FE740`)
- Confidence: high for damage/target; unknown for cadence
- Notes: FishTypePet. `FUN_004E5FC0` selects the nearest hostile in
  `Tank+0xF4`/`Tank+0xB8`. `FUN_004FE740` -> `FUN_004FB5B0` index 2 subtracts
  1.0 from `+0x1F0` (0.25 against alien class `+0x1EC` 4 or 5) and plays
  sound 0xB. No projectile interception. The wiki's 0.25 s attack rate was
  not isolated in slot 86; keep it as a tuning parameter until P2.8.

### EV-0084 - P2.7 Prego (0x03): 930/1230/2000 birth thresholds
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`),
  `docs/evidence/p2.7-pet-helpers-batch.json` (`ev_0ae4497a...` `0x4DA710`)
- Confidence: high
- Notes: FishTypePet; ctor `+0x224=0x3A2` (930), `+0x190=360`. Slot 81
  increments `+0x220`; in VT at `threshold-0xD2` it samples fish counts and
  rewinds the timer by 300 if the population condition fails. At the
  threshold it resets the timer, spawns a guppy with
  `FUN_00546EF0(x+7,y+25)`, sets the VT guppy field `+0x120=0x28`, plays
  sound 0, then sets the next threshold: fish count >10 -> 2000; otherwise
  930 + (rand > 5 ? 300 : 0), i.e. 930 or 1230. Slot-81 skip during aliens
  explains the wiki's paused birth timer. The exact VT population test and
  the belly-swell frames remain open.

### EV-0085 - P2.7 Zorf (0x04): 65-tick level-2 food dropper
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`)
- Confidence: high for timer/food kind; medium for `Tank+0x194`
- Notes: FishTypePet; ctor `+0x224=65`, speed 3.0, `+0x190=270`. Slot 81
  acts when `Tank+0x194 == 0` only if a fish with `+0x9C < 300` and
  `+0xF0 == 0` exists; when `Tank+0x194 != 0` it increments `+0x240` and
  acts every 2 ticks normal / 4 ticks VT even without a hungry fish. On act
  it sets `+0x220=-10` and spawns food kind 1 or 2 at `(x+15,y+10)` with
  `FUN_00543280`, chosen by vx sign. `Tank+0x194` is an unidentified cached
  tank value; it is **not** proven to be a Brinkley count (EV-0107).

### EV-0086 - P2.7 Clyde (0x05): 2D coin collector, speed 1.5
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EB7C0.json` (`ev_b2e4642a...`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_2303a828...`)
- Confidence: high
- Notes: OtherTypePet; speed 1.5, no fixed y. `FUN_004EB7C0` index 5 advances
  the direction animation every 0x13 (19) frames; `FUN_004E02D0` steers with
  target vx +/-1.0. He collects the same coin set as Stinky (3/10 only while
  Penta exists; excludes 0x11/0x12/claimed) plus the `FUN_004E4F90` check.
  He has no hide branch and remains active during alien attacks. The wiki's
  "slides when a coin is stolen" is consistent with the steering state but was
  not separately traced.

### EV-0087 - P2.7 Vert (0x06): 216-tick gold-coin drop
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`),
  `docs/evidence/p2.7-walter-angie-batch.json` (`ev_9cbadb72...` `0x4D70B0`)
- Confidence: high
- Notes: FishTypePet; ctor `+0x224=216` normal, `1080..1279` VT. Slot 81
  increments `+0x220`; at the threshold it calls `FUN_004D70B0` and, if
  allowed, spawns coin kind 2 at `(x+15,y+10)`. No food required. 216 ticks =
  6.0 s, matching the wiki. `FUN_004D70B0` is the mode-5 spawn gate (returns 1
  outside mode 5; in mode 5 it checks avatar-screen state and a global count).

### EV-0088 - P2.7 Rufus (0x07): bottom lane, 2.0 melee
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EB7C0.json` (`ev_b2e4642a...`),
  `docs/evidence/p2.7-melee-damage.json` (`ev_d796abf4...`)
- Confidence: high for constants/damage; unknown for the bottom trigger
- Notes: OtherTypePet; ctor forces `y=365.0`; steering caps x at 560 and uses
  speed 1.8. `FUN_004E5FC0` selects the nearest hostile in
  `Tank+0xF4`/`Tank+0xB8`; `FUN_004FE740` deals 2.0 (0.5 against alien class
  4/5/6). The exact y threshold that counts as "lured to the bottom" was not
  isolated; expose it as a parameter for P2.8.

### EV-0089 - P2.7 Meryl (0x08): 1400/4320 song timer, kind-0x10 marker
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`)
- Confidence: high for timer/marker; inferred for the guppy reaction
- Notes: FishTypePet; ctor `+0x224=1400` normal, `4320` VT. Slot 81 increments
  `+0x220`; at `threshold-100` (1300) it sets `DAT_005e89cc=1`, spawns coin
  kind 0x10 at `(x+15,y-5)`, and plays sound 0x137; at the threshold it clears
  `DAT_005e89cc=0` and resets the timer. Kind 0x10 has value 0 (P2.5), so it is
  a song/note marker; the actual three-coin guppy drop is the fish reaction to
  the song (inference, body not decompiled here). 1400/4320 ticks = 38.9/120 s,
  matching the wiki's 40 s/2 min.

### EV-0090 - P2.7 Wadsworth (0x09): hide flag, global count, mouth position
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-walter-angie-batch.json` (`ev_9cbadb72...` `0x4D6250`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_453fbe78...` 0x4F22C0 etc.)
- Confidence: high for flags/cleanup; unknown for the size filter
- Notes: FishTypePet; ctor `+0x224=120`, speed 4.0. Hidden state is `+0x250`;
  a hidden Wadsworth increments `DAT_005e89d0` and stores the mouth position
  in `DAT_005e89D4/+0xD8`. `FUN_004E7010`, `FUN_004E7130`, `FUN_004E3EA0`
  are the eligibility predicates; `FUN_004E9790` gates the action during
  aliens. `FUN_004D6250` decrements `DAT_005e89d0` on removal (clamped at 0).
  The wiki's small/medium size filter and Challenge-Mode sleep were not
  isolated (EV-0106).

### EV-0091 - P2.7 Seymour (0x0A): only the `Tank+0x16C` coin-slow effect
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-behavior-batch.json` (`ev_453fbe78...`
  `0x4F5050` coin update), `docs/evidence/p2.7-tank-update-batch.json`
- Confidence: medium (effect observed; writer unknown)
- Notes: FishTypePet; no ctor branch. While `Tank+0x16C` is set, coin fall
  speed is 1.5 -> 0.8 and coin expiry 0x14 -> 0x82. No writer of
  `Tank+0x16C` was found in the analyzed pet/tank functions; the aura radius,
  stacking rule, and whether Seymour is the only writer remain explicit
  unknowns (EV-0106). Do not implement a radius until the writer is found.

### EV-0092 - P2.7 Shrapnel (0x0B): 633..652-tick bomb drop
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`)
- Confidence: high for timer/kind; unknown for explosion
- Notes: FishTypePet; ctor `+0x224 = rand % 0x14 + 0x279` (633..652) normal,
  `1080..1279` VT. Slot 81 spawns coin kind 0x11 at `(x+15,y+10)` and plays
  sound 0x143. `+0x258` is the white-flash timer (0 -> 1 -> -1). 648 ticks =
  18 s, matching the wiki. The bomb's explosion/damage path is
  `FUN_004D6040`/the coin path, not this slot; radius and fish damage remain
  P2.3/P2.8 work.

### EV-0093 - P2.7 Gumbo (0x0C): opposite-corner movement, no fish-redirect code
- Date: 2026-10-21
- Type: observation (pet behavior) + bounded negative
- Source: `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...`
  `0x4E02D0`, `0x4E5FC0`), `docs/evidence/p2.7-4EF420.json`
- Confidence: high for movement/glow; high that no fish-redirect body was found
- Notes: FishTypePet; no ctor branch. `FUN_004E5FC0` selects the nearest
  hostile in `Tank+0xF4`/`Tank+0xB8`. `FUN_004E02D0` steers to the corner
  opposite the alien: x thresholds 0x123/0x14A (291/330), y thresholds
  0x105/300. `+0x258` drives the lure glow while aliens exist. No code was
  found that moves guppies/breeders toward Gumbo; the wiki's lure mechanic is
  unproven and must stay disabled until a guppy target branch is found.

### EV-0094 - P2.7 Blip (0x0D): instant store unlock at 200/720 ticks
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4F7AD0.json` (`ev_434fb0aa...`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_453fbe78...` `0x5409B0`)
- Confidence: high for the unlock; bounded negative for the overlays
- Notes: FishTypePet; no ctor branch. The unlock branch triggers when
  `Tank+0x2E0 < Tank+0x2DC` and either level age `+0x444 > 200` or, for a
  transformed Presto, `+0x28 > 0x2D0` (720). It calls `FUN_005409B0(i,1)` for
  i=0..0xB, which spawns/unlocks every store item. 200/720 ticks = 5.5/20 s,
  matching the wiki's 5 s/20 s and anchoring the 36 Hz rate. Hunger arrows,
  alien entrance radar, and alien HP meters were not found in Blip's
  update/render (EV-0106).

### EV-0095 - P2.7 Rhubarb (0x0E): bottom repeller, 260/250 targeting
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EB5C0.json` (`ev_7b934c66...`),
  `docs/evidence/p2.7-4EB7C0.json` (`ev_b2e4642a...`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_2ddc8596...` `0x4E7C30`)
- Confidence: high
- Notes: OtherTypePet; ctor `y=355.0`; steering speed 1.8. Targets fish with
  y > 260 normally and y > 250 during aliens; snaps at y=270 normal or 250
  aliens. On a snap he sets the fish's `+0x208=50`, vy -20 (normal) or -30
  (aliens), and `+0x1B4=0x14` (20). He continues during alien attacks. The
  exact exempt-species filter was not fully enumerated; keep it data-driven.

### EV-0096 - P2.7 Nimbus (0x0F): coin kind<8 -> +7, sleep divisor
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-4F7AD0.json` (`ev_434fb0aa...`)
- Confidence: high for coin rule; medium for speed split
- Notes: FishTypePet; ctor speed 0.5, `+0x198=320`. Coin handling maps kind
  <8 to kind+7 (toss-up) and excludes 0x11, 3, 10, 0x12. Movement uses 0.5
  normally and 1.8 while tossing; `+0x245` is the sleep flag and divides
  movement by 5. The wiki's "does not toss stars" matches the 3/10 exclusion;
  the exact upward velocity and the food branch were not isolated.

### EV-0097 - P2.7 Amp (0x10): 3000-tick charge, click path unresolved
- Date: 2026-10-21
- Type: observation (pet behavior) + explicit unknown
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`)
- Confidence: high for charge; high that the click path was not found
- Notes: FishTypePet; ctor speed 0.5, `+0x224=3000`, size 0xA0x50,
  `+0x19C=460`, `+0x220=300`. Slot 81 increments `+0x220`; at 3000 ticks
  (83.3 s) it plays sound 0x11A, sets byte `+0x55=1` and `+0x7C=1` (charged),
  and the render flashes via `+0x258`. The wiki says 75 s, a recorded
  discrepancy. The click -> electrocute -> guppy-to-diamond path, the
  three-click counter, and the free-baby-guppy rescue were not found
  (EV-0106). Do not implement the electrocution from the wiki alone.

### EV-0098 - P2.7 Gash (0x11): 3.0 melee, hungry-guppy bite
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-melee-damage.json` (`ev_d796abf4...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`)
- Confidence: high
- Notes: FishTypePet; ctor `+0x224=0x622` (1570) normal, 0x5F0 (1520) when
  transformed. Slot 81 only increments `+0x220`; the attack is in
  `FUN_004FE740`: subtract 3.0 (0.5 against alien class 4/5), play sound 9.
  A hungry-guppy bite resets `+0x220=0`; `+0x1C8=10` is the attack debounce;
  the bite cooldown is 20 ticks. The exact hungry-guppy selection and the
  "last guppy" loss edge are P2.4/P2.8 interactions.

### EV-0099 - P2.7 Angie (0x12): corpse target and `+0x190` 100 -> 10
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...`
  `0x4E5FC0`, `0x4FE740`), `docs/evidence/p2.7-walter-angie-batch.json`
  (`ev_9cbadb72...` `0x4D5630`)
- Confidence: high
- Notes: FishTypePet; no ctor branch. `FUN_004E5FC0` targets corpses in
  `Tank+0x98` with `+0x1A0 > 0x5F`; contact range 30 px (60 px when
  `+0x1A4 == 6`). `FUN_004FE740` calls `FUN_004D5630`, which rewrites the
  corpse's `+0x190` from 100 to 10 if it is exactly 100. The corpse then
  follows the normal revive path (P2.4). Revive sound/animation and the
  `+0x1A0` timer semantics remain P2.4 work.

### EV-0100 - P2.7 Presto (0x13): transform, recharge, picker, cleanup
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...`
  `0x4F89A0`), `docs/evidence/p2.7-behavior-batch.json` (`ev_453fbe78...`
  `0x4F2650`, `0x54C6F0`), `docs/evidence/p2.7-walter-angie-batch.json`
  (`ev_9cbadb72...` `0x4D6250`),
  `docs/evidence/p2.7-presto-picker-54C6F0.json` (`ev_f671ea07...`)
- Confidence: high
- Notes: FishTypePet; ctor sets `+0x238=360` for a normal pet and 0 for Presto
  itself/mode 5. `FUN_004F89A0(target)` ignores a same-index target and
  requires `FUN_004F2650(+0x238)` (timer < 1; otherwise it draws
  "Recharging..." at `(x+width/2-20,y-10)`). On success it plays sound 0x122,
  spawns the target at the same x/y with `FUN_00544A90(target,x,y,1,0)`,
  removes the old object, copies `+0x264/+0x260` when swapping Walter/Presto,
  and calls `FUN_004D6250`. `FUN_0054C6F0` opens the "PRESTO CHANGE-O"
  `Sexy::PetDialog` (0x2F8 bytes) and pushes screen 0x1F; it is not a sell
  path. 360 ticks = 10 s.

### EV-0101 - P2.7 Brinkley (0x14): feed counter and 15/45/135 rewards
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-547610.json` (`ev_500f6536...` tank update),
  `docs/evidence/p2.7-4F7AD0.json` (`ev_434fb0aa...`),
  `docs/evidence/p2.7-walter-angie-batch.json` (`ev_9cbadb72...` `0x4D70B0`)
- Confidence: medium-high (contact/reward path in tank update)
- Notes: FishTypePet. Feed contact uses the rect x+5..x+35, y..y+35.
  `+0x240` counts feedings; rewards occur on feeds 3, 15, 45, 135 with coin
  kinds 0xA, 0xB, 0xD, 0xE (star, diamond, pearl, treasure chest).
  `+0x23C` is the cooldown: 45 ticks normal / 108 ticks VT (the ctor-style
  `(-(mode != 5) & 0xFFFFFFC1) + 0x6C`). `FUN_004D70B0` is the VT gate.
  Wiki says 12/36/108, so 15/45/135 is a recorded discrepancy (EV-0105);
  do not silently pick either.

### EV-0102 - P2.7 Nostradamus (0x15): 300..599/1080..1279 snot timer
- Date: 2026-10-21
- Type: observation (pet behavior) + bounded negative
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`),
  `docs/evidence/p2.7-pet-helpers-batch.json` (`ev_0ae4497a...` `0x5434E0`)
- Confidence: high for snot; high that the sneeze was not found
- Notes: FishTypePet; ctor `+0x224 = rand % 300 + 300` (300..599) normal,
  `1080..1279` VT. Slot 81 increments `+0x220`; at the threshold it calls
  `FUN_005434E0(x+15,y+10)`, which spawns snot (coin kind 0x12). The wiki's
  fixed 15 s is not the binary shape (300..599 ticks = 8.3..16.6 s); 30 s VT
  is within 1080..1279. The 50% "Sneeze of Power" and clone behavior were not
  found (EV-0106).

### EV-0103 - P2.7 Stanley (0x16): ball shot and projectile interception
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-4EF420.json` (`ev_f6e71a1f...`),
  `docs/evidence/p2.7-pet-vtable-batch.json` (`ev_6946bb69...` `0x4E5900`),
  `docs/evidence/p2.7-behavior-batch.json` (`ev_504ee005...` `0x4E55D0`)
- Confidence: high
- Notes: FishTypePet; ctor `+0x224=100`. Slot 81 calls `FUN_004E55D0`
  (projectile intercept) every tick; when the action timer exceeds 100 it
  resets, sets `+0x23C=50` if zero, fires a ball at x+40 (facing right) or x
  (left), plays sound 0x122, and sets `+0x1C8=10`. `FUN_004E55D0` intercepts
  projectiles in `Tank+0xDC` with alien class `+0x1EC` 5/6/4; its cooldown is
  90 or 30 ticks. The per-alien ball damage table is wiki-only (P2.8).

### EV-0104 - P2.7 Walter (0x17): boxing glove entity, hit scan, effect fields
- Date: 2026-10-21
- Type: observation (pet behavior)
- Source: `docs/evidence/p2.7-walter-glove.json` / `p2.7-walter-angie-batch.json`
  (`ev_9cbadb72...` `0x4EF7C0`, `0x4E1000`, `0x4E9A60`, `0x4E0ED0`)
- Confidence: high for glove/hit/effect; unknown for input/5-punch counter
- Notes: FishTypePet; ctor sets byte `+0x55=1`, `+0x7C=1`, `+0x70=10`,
  `+0x78=15`. `FUN_004EF7C0` creates `Sexy::BoxingGlove` (0x168 bytes): life
  `+0x15C=30`, direction `+0x160`, shot cooldown `+0x164=5`. `FUN_004E1000`
  renders it (frame from `|life-15|`, 0xA0x50). `FUN_004E9A60` positions the
  glove at the target x-60 (left) or x-20 (right), y = target y; while life >
  12 it scans `Tank+0x108` and calls `FUN_004E0ED0(dir,type)` for fish types
  0/5/6/7/0x22/0x23/0x24 (type 5), pet indexes 6/0xB/0x10 (type 5), and
  Nostradamus 0x15 (type 10). `FUN_004E0ED0` sets target `+0x20C=50`,
  `+0x210=0xB4`, `+0x220=+0x224-type`, and knockback `+0x218=dir*15` or
  `dir*10`; a hit plays sound 3 and sets `+0x164=5`. The click binding, the
  five-punch counter writer, and the 10 s sleep were not found (EV-0106).

### EV-0105 - P2.7 wiki pass: 24 pet pages, bindings, and discrepancies
- Date: 2026-10-21
- Type: wiki-ref (D-0010)
- Source: `https://insaniquarium.fandom.com/wiki/<Pet>?action=raw` for all 24
  display names, fetched 2026-10-21; `docs/analysis/notes/wiki-refs.md` section 7
- Confidence: wiki claims only; binary bindings cited above
- Notes: confirmed roles/timings: Stinky bottom collector; Niko 34 s first
  pearl then 40 s, $250; Itchy 0.25 s melee; Prego ~26 s; Zorf 2 s level-2
  food; Clyde 2D collector; Vert 6 s; Rufus bottom melee; Meryl 40 s (2 min
  VT); Wadsworth shelter; Seymour slow money; Shrapnel 18 s bomb; Gumbo lure;
  Blip info + 5 s/20 s unlock; Rhubarb bottom snap; Nimbus toss; Amp 75 s +
  3 clicks; Gash heavy melee; Angie revive; Presto right-click/10 s; Brinkley
  12/36/108; Nostradamus 15 s/30 s + 50% sneeze; Stanley balls; Walter 5
  punches/10 s. Discrepancies kept open: Niko perch, Brinkley 12/36/108 vs
  15/45/135, Stinky random vs nearest, Gumbo fish lure, Blip overlays, Seymour
  writer, Amp click path, Nostradamus sneeze/clones, Wadsworth challenge
  sleep, Amp 75 s vs 3000 ticks. See `p2.7-pets.md` section 6.

### EV-0106 - P2.7 explicit unknowns and bounded negative searches
- Date: 2026-10-21
- Type: explicit unknowns
- Source: current pass (EV-0077..EV-0105); `p2.7-search-1c4.json`
  (`ev_3d0780f0...`), `p2.7-search-234.json` (`ev_ecb4b7a5...`)
- Confidence: high that these are unresolved
- Notes:
  - Gumbo's guppy/breeder redirection: only his own opposite-corner movement
    and `+0x258` glow were found; no fish target branch. EV-0093.
  - Blip hunger arrows, alien entrance radar, alien HP meters: not found in
    `FUN_004F7AD0`/`FUN_004F8610`; only the store unlock is proven. EV-0094.
  - Seymour `Tank+0x16C` writer: not found; the effect fields are observed.
    EV-0091.
  - Amp click -> electrocute -> guppy-to-diamond, three-click counter, free
    baby guppy: not found. EV-0097.
  - Nostradamus 50% sneeze and clones: not found. EV-0102.
  - Wadsworth small/medium filter and Challenge sleep: not found. EV-0090.
  - Brinkley 15/45/135 vs wiki 12/36/108: unresolved conflict. EV-0101.
  - Stinky collection cooldown and Nimbus red cosmetic: not isolated. EV-0081.
  - Niko stationary perch: not in spawn/update. EV-0082.
  - `Tank+0x194`: unidentified cached value; not a proven Brinkley count.
    EV-0085.
  - Walter click binding, five-punch counter writer, and 10 s sleep: not
    found. EV-0104.
  - VT "3 minutes" sleep: only the generic `FUN_004D6B70` test
    (`Tank+0x28 - Tank+0xF0 < 0x1950` with a `%0x3C` branch) is known; do not
    hard-code 180 s. EV-0081/EV-0086.
  - `FUN_004D6280` referenced in the first pass resolves to `FUN_004D6250`;
    cite the canonical entry. EV-0107.
  - Bounded immediate searches `C4 01 00 00` and `34 02 00 00` in `.text`
    0x401000..0x595900 (300-hit limits) were used to find pet-index
    comparisons; they are not exhaustive and do not prove absence.

### EV-0107 - P2.7 corrections to earlier notes and field semantics
- Date: 2026-10-21
- Type: correction (EV-0044/EV-0052/EV-0076 era claims)
- Source: EV-0078..EV-0104
- Confidence: high
- Notes:
  (1) The tank-relative list map used here is `Tank+0xA0` fish, `+0xA8` coins,
  `+0xAC` food, `+0xB8` hostile aliens, `+0xF4` type-0x17 invaders, `+0x98`
  corpses/revive, `+0x108` Walter glove hit list, `+0xD0` Penta/Starcatcher.
  Earlier P2.2 wording that treated `Tank+0xB8`/`+0xF4` as generic "child
  lists" is narrowed to hostile presence lists; the entity `+0x98` shadow flag
  is unrelated to the Tank corpse list.
  (2) `FishTypePet+0x230` and `OtherTypePet+0x1C8` are the Presto-transformed
  flags; `FishTypePet+0x1C8` is an attack/target debounce, not a Presto flag.
  `FishTypePet+0x1B0` is a steering cadence counter; `OtherTypePet+0x1B0` is a
  sleep/idle movement divisor. Do not share one field table across classes.
  (3) Rhubarb targets at y > 260 normal / 250 aliens and snaps at 270/250;
  the earlier "270/260 snap" pairing was wrong. EV-0095.
  (4) Brinkley's binary reward feeds are 15/45/135, not the wiki 12/36/108;
  the cooldown is 45 ticks normal / 108 VT. EV-0101.
  (5) Stinky's bottom behavior is a fixed y=370 lane with vx steering, not a
  hard bottom clamp. EV-0081.
  (6) Niko has no fixed perch in the spawn/update path; the pearl timer and
  render are the only special code. EV-0082.
  (7) 999 is a display/card index only; it is never spawned and grants no pet
  slot. EV-0077/EV-0105.
  (8) `FUN_004D6280` resolves to `FUN_004D6250`; use the canonical address.
  EV-0106.

### EV-0108 - Real save files located: `ProgramData\Steam\Insaniquarium\userdata`
- Date: 2026-10-21
- Type: observation (local save files + module strings)
- Source: user-provided files copied to
  `docs/analysis/inputs/p2.13-saves-2026-10-21/` (`users.dat`, `user1.dat`,
  `adv1.dat`); module strings `userdata/users.dat`, `userdata/user%d.dat`,
  `userdata/scr%d.dat`, `userdata/%s%d.dat`, `userdata/highscores.dat`
- Confidence: high for paths/files/hashes; medium for the first-field reading
- Notes: the live save folder is `C:\ProgramData\Steam\Insaniquarium\userdata`, not
  the game install. `users.dat` (22 B) stores one profile: version/header
  `0E 00 00 00`, count `01 00`, name length `06 00`, ASCII `okokok`, then two
  dwords `01 00 00 00`; `HKCU\Software\PopCap\Insaniquarium\CurUser` also reads
  `okokok`. The profile name is 6 characters; a search for `okokokok` cannot match.
  `adv1.dat` (1081 B) begins with dword `0x36` (54), matching the SaveGame version
  written by `FUN_00546990`; the next dwords are `1, 1`, consistent with tank 1 /
  level 1, and the tank-1 tutorial string "Here are your first fish! Take good care
  of them!" sits at `0x184`. `user1.dat` (232 B) has dword 200 at offset 4,
  consistent with the profile reset's starting money `+0x48 = 200`. No `scr%d.dat`
  exists for this profile. The Adventure save is `adv%d.dat`; `scr%d.dat` remains
  the separate Shells-persistence file (`FUN_005148C0`/`FUN_00515910`). This sample
  is early-game and does not contain a completed Challenge/trophy/tank-5 state.
  Hashes and layout notes: the folder README.

### EV-0109 - GameBanana 100% profile sample; full `user%d.dat` serializer map
- Date: 2026-10-21
- Type: observation + code trace (user-provided save files + module decompilation)
- Source: `C:\Users\Fauzi\Downloads\userdata_b3b31\userdata` copied to
  `docs/analysis/inputs/p2.13-saves-gamebanana-100/` (`users.dat` 21 B,
  `user1.dat` 232 B, `sim1.dat` 11800 B); no executable in the pack. Code:
  `FUN_00513850` (`users.dat` serializer), `FUN_005145A0` / `FUN_00514730`
  (profile load/save), `FUN_00503730` (profile field serializer),
  `FUN_00503010` (dword field), `FUN_00503070` (byte field),
  `FUN_005014D0` (profile bitmask at `+0x84`), `FUN_00546990` /
  `FUN_00546240` (tank SaveGame/body).
- Confidence: high for file structure, field order, and observed bytes; medium for
  the candidate story/trophy labels; no claim of legitimate 100% completion
- Notes: the copied `users.dat` is `0E 00 00 00 | 01 00 | 05 00 | "Roman" |
  04 00 00 00 | 01 00 00 00`; the trailing dwords remain unresolved. The
  GameBanana `user1.dat` is exactly 232 bytes and matches the writer order of
  `FUN_00503730`: marker `0x80000000`, money `+0x48`, `+0x1C`, `+0x20`, bytes
  `+0x59`/`+0x58`, dwords `+0x90,+0x94,+0x8C,+0x4C,+0x50,+0x54,+0xA0,+0x98,
  +0xB0,+0xB4`, 24 owned-pet bytes `+0x00..+0x17`, six bytes `+0x72..+0x77`,
  eight bytes `+0xA8..+0xAF`, four records `(byte +0x78+i, dword +0x11C+4i,
  dword +0x10C+4i)`, dwords `+0x7C,+0x80,+0x84`, 21 dwords `+0xB8..+0x10B`,
  trailing dword `+0x88`. The file offsets are money `0x04`, owned pets
  `0x3A..0x51`, six-byte block `0x52..0x57`, eight-byte block `0x58..0x5F`,
  records `0x60..0x83`, `+0x7C` at `0x84`, `+0x80` at `0x88`, `+0x84` at
  `0x8C`, 21-dword block `0x90..0xE3`, `+0x88` at `0xE4`. Observed 100%
  values: money 9,999,999; `+0x1C/+0x20 = 1/1`; `+0x59 = 1`; `+0x90/+0x94 =
  1/1`; `+0x4C/+0x50/+0x54 = 54/100/0`; `+0xA0 = 20253`; `+0x98 =
  0x51459CDC`; `+0xB0/+0xB4 = 6/24`; all 24 pet bytes `1`; six-byte block
  all `1`; eight-byte block all `0`; record bytes `1,1,1,0`; record dwords all
  `0xFFFFFFFF` except record 3's first dword (`+0x128`) `0xFFFF01FF`; `+0x7C =
  0xFFFFFFFF`, `+0x80 = 1`, `+0x84 = 2`; 21-dword block all `-1` except
  `+0x108 = 18`; trailing `+0x88 = 0x56BD6F1A`. The early local sample has
  money 200, all pet bytes `0`, six-byte block `01 00 00 00 00 00`, `+0x7C =
  0`, `+0x80 = 0`, `+0xB4 = 3`, 21-dword block all `-1`, and `+0x88 =
  0x44945926`. CRC32 of the body did not match the trailing dword, so `+0x88`
  is not a plain CRC32. `FUN_00503730` has a legacy branch: a loaded marker
  `< 0x7fffffff` reads each record byte as a 4-byte boolean and skips
  `+0x7C/+0x80/+0x84`; the current marker path writes them. The 100% profile's
  `+0x7C = 0xFFFFFFFF` and `+0x80 = 1` are a strong numerical match for a
  32-bit story mask plus a 33rd gold-trophy flag, but no reader/writer for
  those fields was located; Q-0013 stays open. The pack contains no
  `adv1.dat`/`scr1.dat`; its `sim1.dat` starts with version 54 and tank/level
  `1,5`, in the `FUN_00546990`/`FUN_00546240` tank-save family, but `sim`
  prefix semantics remain unproven. Hashes and per-field notes:
  `docs/analysis/inputs/p2.13-saves-gamebanana-100/README.md`; analysis:
  `docs/analysis/notes/p2.13-saves.md`.

### EV-0110 - P2.8 alien identity: one `Sexy::Alien` class plus a kind table (Q-0011 answered)
- Date: 2026-10-29
- Type: code trace (module decompilation) + wiki cross-check
- Source: `docs/evidence/p2.8-alien-draw-4DB210.json` (`ev_` in file),
  `docs/evidence/p2.8-fn-4DAE20.json` (`FUN_004DAE20`), `docs/evidence/p2.8-fn-4ECFA0.json`
  (`FUN_004ECFA0`), `docs/evidence/p2.6b-selector-waves.json` (`FUN_00545620`),
  `docs/evidence/p2.2-module-rtti-classes.txt`, `docs/analysis/inputs` wiki text
- Confidence: high for the class/kind split and the image binding; medium for kind 1 vs 2
- Notes: every hostile alien except Bilaterus is a `Sexy::Alien` (vtable `0x59740C`, type id
  `+0x8C = 0x16`, alloc `0x208`) whose kind (`Alien+0x1EC`, copied from the spawn selection
  `Tank+0x2BC`) drives stats, sprite, sound and attack code. There are no Sylvester/Balrog/
  Gus/Destructor/Ulysses/Psychosquid/Cyrax RTTI classes; Q-0011 is answered. The kind -> species
  binding is triple-sourced and agrees: (a) per-level types and the demo pools per tank,
  (b) composite spawn pairs 9=1+3, 0xA=7+3, 0xB=5+6, 0xC=3+8, (c) one image pointer per kind in
  the sprite switch (`1/2` -> `DAT_005e8ebc`, `3` -> `DAT_005e8cec`, `4` -> `DAT_005e8ae4`,
  `5` -> `DAT_005e8ec8`, `6` -> `DAT_005e8e58`, `7` -> `DAT_005e8c4c`, `0x14` -> `DAT_005e8c0c`,
  `0x15` -> `DAT_005e8cb8`, `8` -> no case because Bilaterus draws itself). Result: 1/2 Sylvester,
  3 Balrog, 4 Gus, 5 Destructor, 6 Ulysses, 7 Psychosquid, 8 Bilaterus, 9-0xC composite
  selections, 0x14 Minisylvester, 0x15 Cyrax. Kinds 1 and 2 share one image and differ only in
  speed/HP (2.0/50 vs 1.6/60); the binary has no second Sylvester name (Q-0020). Kind 0 is the
  tank1-L1 selection and has no stat branch, sprite case or hp init - see EV-0114 bounded note.

### EV-0111 - P2.8 `Alien` ctor: per-kind hp/speed/box, field map, demo override, Cyrax scaling
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-alien-ctor-4ECFA0.json` / `.txt` (`FUN_004ECFA0`, base
  `FUN_004E9CB0`, `Sexy::Alien::vftable`)
- Confidence: high
- Notes: ctor `(x, y, kind)` sets `+0x8C = 0x16`, x/y ints via ftol plus doubles at
  `+0x160/+0x168`, box `+0x38/+0x3C = 160` (mini 80), intro timer `+0x158 = 15`, vx `+-3.0`,
  facing `+0x1C8 = +-1.0`, `+0x1C0 = 1`, `+0x1A0 = 100` (mini 40), `+0x1A4 = 0`,
  `+0x1A8 = 75` (demo 144), `+0x1AC = 0`, `+0x1DC/0x1E0 = 0`, `+0x1E4 = 300`, `+0x1E8 = 75`,
  `+0x1D4 = 40`, `+0x1D8 = 20`, `+0x1D0 = rand()%10`, `+0x158 = 15`, hp copy `+0x1F8 = +0x1F0`.
  Per kind (`+0x1B8` speed divisor / `+0x1F0` hp): 1 -> 2.0/50, 2 -> 1.6/60, 3 -> 1.2/130,
  4 -> 1.6/100, 5 -> 1.2/150, 6 -> 3.5/220, 7 -> 0.5/260 (+cycle 200/400), 0x14 ->
  `(rand%5)/10+0.8` / 1.0, 0x15 -> 2.0 / `5000 - 125*clamp(profile+0x54-1,0,20)`. Kinds 5 and 6
  are forced to y 290 (int y 280) unless game mode is 5. Demo (`manager+0x880 != 0`) overwrites hp
  with `rand%100+150` (kind 4: `rand%50+70`) and `+0x1A8 = 144`. `profile+0x54` is the Cyrax
  defeat counter: the wave block increments it when the boss lost more than 1000 hp in the level
  (EV-0113), so each cleared boss lowers the next Cyrax by 125 hp (5000 down to 2500).

### EV-0112 - P2.8 Bilaterus: body, two heads (100 hp each), six bones, head swap
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-bilaterus-ctor-4FE000.json` / `.txt` (`FUN_004FE000`),
  `docs/evidence/p2.8-bilaterus-update-4FE250.json` / `.txt` (`FUN_004FE250`),
  `docs/evidence/p2.8-fn-4EE210.json` / `.txt` (`FUN_004EE210`),
  `docs/evidence/p2.7-melee-damage.json` (`FUN_004FB4C0`)
- Confidence: high for layout/hp/swap triggers; medium for `FUN_004FB1C0` semantics
- Notes: `Sexy::Bilaterus` (`+0x8C = 0x17`, alloc `0x178`) owns head A `+0x158`, head B `+0x15C`,
  a 6-entry bone list `+0x160`, byte `+0x164` (head lost), int `+0x168 = 8`, countdown
  `+0x16C = 15`, swap counter `+0x170`; 50% of spawns call `FUN_004FB1C0()` (start on the other
  head), otherwise sound `0x131`. Heads (`FUN_004EE210(parent,x,y,side)`, alloc `0x208`, vtable
  `Sexy::BilaterusHead::vftable`) are 80x80, store the parent at `+0x158`, side at `+0x15E`,
  `+0x160 = (side == 0)` and **hp `+0x1D8 = 100.0`**; other constants `+0x1A8 = 370`,
  `+0x1AC = 10`, `+0x1B0 = 95`, `+0x1B4 = 540`, `+0x1BC = 40`, `+0x1D4 = 100`, `+0x200 = 12`.
  Update order: VT warp-out (mode 5, base `+0x28 > 0x10E0`) with warp holes for both heads, sound
  `0x136`, `FUN_004D6830`; `+0x16C` setup countdown; while `+0x164 == 0` every 1000 ticks swap the
  active head and reset `+0x170`; head A update `FUN_004F0EA0`, 6 bones `FUN_004EDEA0`, head B
  update; if head A `+0x1D8 <= 0` -> `FUN_004FB4C0` (destroy/swap, sets `+0x164 = 1`, clears
  `+0x15C`, effects 4/5, sounds `0x11D`/`0x11E`). 100 hp per head with ~6 damage per laser hit is
  the wiki's "17 hits per head".

### EV-0113 - P2.8 `Alien::Update`: gates, movement, Destructor/Ulysses/Psychosquid/Cyrax attacks, death
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-alien-update-4FD560.json` / `.txt` (`FUN_004FD560`),
  `docs/evidence/p2.8-fn-4F03D0.json` / `.txt` (`FUN_004F03D0`),
  `docs/evidence/p2.8-fn-4E8B60.json` / `.txt` (`FUN_004E8B60`),
  `docs/evidence/p2.8-fn-4E8DF0.json` / `.txt` (`FUN_004E8DF0`),
  `docs/evidence/p2.8-fn-4F9C70.json` / `.txt` (`FUN_004F9C70`),
  `docs/evidence/p2.8-fn-4D4580.json` / `.txt` (`FUN_004D4580`),
  `docs/evidence/p2.7-melee-damage.json`
- Confidence: high for the call order, constants and attack geometry; medium for the attack gate
- Notes: `Update` bails on a missing tank or `Tank+0x94` (pause), runs `FUN_004F22C0`, applies the
  mode-5 vertical ramp for kinds 5/6, the `+-3` intro drift while `+0x158 > 8`, the
  `FUN_004F03D0` action gate, wander steering (quadrant `+0x1D0`, targets `+0x180/+0x188`,
  0.1 steps, re-roll every 20 ticks at 10%), the Psychosquid cycle, bounds, integration,
  `slot 0xA4(rand, rand)` + `FUN_004DAA00`, then the death check. Bounds: x -10..490 and
  y 85..290 (mini 10..540 / 95..370), snapped not wrapped. The action gate is
  `Tank+0x110 != 0 ? 1 : FUN_005392A0()`; when closed the alien may still act if it is Gus with
  pellets in `Tank+0xAC` or a boss alien is alive. With the gate open, kinds 1/2/3/4/7/8/0x14 eat
  (`FUN_004E8B60` nearest-target scan over `Tank+0xAC` for Gus and `Tank+0x108` otherwise, then
  `FUN_004ED460`), kinds 5/6 shoot, a resting Psychosquid (`+0x204 != 0`) does nothing. Destructor:
  `+0x1A4` -> `+0x1A8` (75) then up to 3 missiles `FUN_004E8DF0(1)` + `FUN_00544130(x+90/105/120,
  y-35/-30/-25, target, 0)` (mirrored when facing left), sound `0x128`, next delay `rand%50+150`
  (300 demo), `+0x1AC = 10`. Ulysses: one projectile 15 ticks early, two at the deadline at
  `x+-0x46/+-0x4E, y-0x18/-0x10`, sound `0x143`, same delay. Psychosquid: `+0x194` -> `+0x198`
  (400) flips `+0x204`, sets `+0x1AC = 10`, re-seeds `+0x194 = rand%100`, speed 0.5/2.0, sound
  `0x135` + `FUN_00537F90(-1)` on rest. Cyrax: `FUN_00545580(x,y)` every `+0x1E8` (75), and while
  `Tank+0xB8`/`Tank+0xF4` stay empty `+0x1DC` -> `+0x1E4` (300) then `Tank+0x700 = rand%6+4` and
  `FUN_005475B0(count,1)` summons 4-9 Minisylvesters. Death (`FUN_004F9C70(from_shot)`): detach
  `+0x98`, optional `FUN_00544430(x+0x19,y+0x19,4,0,0,-1.0,0)` when no boss is alive and
  `FUN_004D70B0()` passes, base cleanup, then per-kind debris (Gus 2-3 + 4-6 pairs, mini smaller,
  default 0-1 / 0-2), sounds `0x11D`/`0x11E` (`0x11F` mini), and a money drop through
  `FUN_005442C0` carrying kind and facing for all kinds except Gus/mini; `FUN_004F9950`
  unregisters. `FUN_004E8DF0` is the projectile target picker: it keeps the *farthest* eligible
  object from `Tank+0x108` (types 5-0xA, type 0 via `FUN_00500FF0`, 0x14/0x15 only with a live
  boss) and returns 0 when none exists. HP feedback: kind 4 flashes only with no boss, kind 5
  flashes during `+0x1AC` 1..9, kind 7 uses rest rows while `+0x204`; the HP bar draws for Cyrax
  and for regular aliens when `Tank+0x178 != 0` and tank index != 5.

### EV-0114 - P2.8 wave clock, type re-roll, wiki comparison, explicit unknowns
- Date: 2026-10-29
- Type: code trace (module decompilation) + observation (wiki text) + bounded negatives
- Source: `docs/evidence/p2.8-wave-block-547610.txt` (extracted from `p2.7-547610.json`,
  `FUN_00547610`), `docs/evidence/p2.6b-selector-waves.json` (`FUN_00545620`),
  `docs/evidence/p2.8-fn-4E8B60.json`, `docs/evidence/p2.8-fn-4D4580.json`
- Confidence: high for the clock/milestones/re-roll expressions; medium for the timer meaning of
  `FUN_005392A0`
- Notes: the alien countdown `Tank+0x2C0` starts at 3000 and only decrements while
  `Tank+0x2BC != 0`, `Tank+0x110 == 0` (no boss), `Tank+0x4F4 == 0`, and the lists `Tank+0xB8`,
  `Tank+0xDC`, `Tank+0xF4` are all empty - the "one wave at a time" contract. Milestones: 276
  tutorial message, 275 warp-hole prep + spawn-coordinate roll (`x = rand%450+20`,
  `y = rand%195+105`), 33 sound when `Tank+0x4FE != 0`, 30 `FUN_00543F40` warning when
  `Tank+0x198 != 0` and tank != 5, 1 `FUN_0054B1A0` event, 0 spawn + mode-4 extra spawns +
  type re-roll + `Tank+0x45C++` + reset to 3000 (also sets `Tank+0x2C4 = 0x23`, clears `+0x4ED`).
  Re-roll: tank1 L5 -> 3 or 9; tank2 L5 -> 4/5 toggle (10%) or 9 (5%); tank3 L2 -> 4/5 toggle
  (10%), L5 -> 6 or 7; tank4 L3 -> 4 or 10 (50/50), L4 -> 8 or 11 (50/50), L5 -> 10 (40%), 11
  (40%), 8 (20%), with an 8 becoming 0xC in mode 4 after wave 4. Mode 4 also adds
  `wave / divisor` extra spawns (divisor 4/5/5/6 by tank, one less for type 0xC) and shows the
  warp hole at countdown 2999; mode 5 delegates to `FUN_005394E0`/`FUN_00539330`; demo
  (`manager+0x880 != 0`) delegates to `FUN_00537C20`. Wiki comparison: composite pairs match the
  multi-alien levels, Destructor 3 homing missiles, Ulysses 2 balls, Psychosquid rest phase, Gus
  fed not shot, Bilaterus 2 x 17 hits, Cyrax summons, ~7.7 s warning (276 ticks at 36 Hz) all
  agree with the wiki. Explicit unknowns (Q-0020): kind 1 vs kind 2 identity; the exact condition
  inside `FUN_005392A0` (used as the attack gate and as the wave block's level-complete test);
  `FUN_004ED460` eat effects (the decompile did not return in this session); writers of
  `Tank+0x178/0x4F4/0x4FE/0x4DE`; `FUN_004FB1C0` and `FUN_004DAA00` semantics; the base `+0x28`
  tick that bounds the 4320-tick VT retreat. Bounded negatives: no `Tank+0x2BC == 0` early-out
  exists in the wave block, so tank1 L1's type 0 does reach `FUN_00545620`, which builds a kind-0
  `Alien` with no stat branch, no draw case and no `+0x1F0` init - do not model a kind-0 alien;
  no hostile-alien subclasses exist beyond `Alien`/`Bilaterus*` (EV-0110).

### EV-0115 - P2.8 corrections: eat approach decoded, death/drop rebuilt
- Date: 2026-10-29
- Type: code trace (module decompilation), **corrects EV-0113 and EV-0114**
- Source: `docs/evidence/p2.8-fn-4ED460.json` / `.txt` (`FUN_004ED460`, returned late in the
  session after the EV-0113 entry was written), re-read of `docs/evidence/p2.8-fn-4F9C70.txt`
  (`FUN_004F9C70`), `docs/evidence/p2.7-pet-helpers-batch.json` (`FUN_00544430` body), EV-0047
  (coin kinds/values), EV-0077 (`FUN_004D70B0` mode-5 spawn gate)
- Confidence: high for the call graph, constants and gating
- Notes: two statements in EV-0113 are wrong and are replaced here - `FUN_004ED460` is not the
  eat operation and `FUN_005442C0` is not the money drop.
  (1) **`FUN_004ED460()` is the approach step.** It re-runs `FUN_004E8B60()` for the nearest
  eligible target, then steers `+0x170` (vx) / `+0x178` (vy) toward it: the alien point is its
  box centre `(+0x160,+0x168)+80` (Minisylvester `+40`); the target point is the target's int
  `(+0x30,+0x34)` + `0x14` for a Gus pellet (`+0x190 != 0`) and + `0x28` for everything else; vx
  steps 0.1 while `|vx| < 1.8`; vy steps 0.1 (Gus-on-pellet 0.3, ceiling 3.0) while `|vy| < 1.8`.
  It ends with `if (((+0x1A0 < 1) || (kind == 4)) && target != 0) FUN_004E8F70();` and returns
  `target != 0`, which is what makes `FUN_004F03D0` skip the wander step. Eating is therefore a
  *chase*: the bite/contact test lives in `FUN_004E8F70()` (still open, Q-0020). A flashing
  non-Gus alien approaches but never bites.
  (2) **The death drop is a Diamond, not `FUN_005442C0`.** Step 2 of `FUN_004F9C70` calls
  `FUN_00544430(x+0x19, y+0x19, 4, 0, -1.0, 0)` = `Tank::SpawnCoin` with coin kind 4 =
  **Diamond, base value 200** (EV-0047), gated only on `Tank+0x110 == 0`, `from_shot != 0` and
  `FUN_004D70B0()`. The branch is **not** kind-gated, so Gus and Minisylvester drop it too;
  `FUN_004D70B0` returns 1 outside mode 5 (EV-0077), so this is normal-play behavior. When
  `from_shot == 0` the function only detaches `+0x98`, runs `FUN_004DB250()`/`FUN_00539C90()` and
  unregisters - no coin, no debris, no animation call.
  (3) **Debris counts, exact.** Gus: `(rand&1)+2` iterations of two `FUN_00538AC0` particles at
  `(rand%0x46+0x1E, rand%0x46+0x1E)` and `(rand%0x32+0x32, rand%0x32+0x32)`; then `rand%3+4`
  iterations of two `FUN_005436F0(x, y, size)` chunks with `size = rand%3+3` at
  `(rand%0x32+0x14, …)` / `(rand%0x1E+0x28, …)`; then `(rand&1)+2` iterations of two chunks with
  `size = (rand&1)+6`; sounds `0x11D` + `0x11E`; unregister and return. Minisylvester: the same
  three loops with `rand%0x23`, `rand%0x19+10` and `rand%0xF+10`, one sound `0x11F`; return.
  Default kinds: `rand&1` (0-1) particle iterations, `rand%3` (0-2) iterations of size 3-5, 0-1
  iterations of size 6-7, sounds `0x11D` + `0x11E`, then
  `FUN_005442C0(lookup2, lookup1, +0x1C0, +0x1EC, 0.0 < +0x170)` where
  `lookup1 = FUN_00564160(+0x1C0, +0x1EC, facing)` and `lookup2 = FUN_00564160(lookup1)` - a pair
  of resource lookups over (animation frame, kind, facing), i.e. a death animation or corpse, not
  money. `FUN_004F9950` unregisters on every path.
  (4) Consequence for the remake: the alien death reward is a flat 200-value coin per killed
  alien in every mode and for every kind, independent of the debris/animation branch.

### EV-0116 - P2.8: the bite (`FUN_004E8F70`) and the attack gate (`FUN_005392A0`)
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-fn-4E8F70.json` / `.txt`, `docs/evidence/p2.8-fn-5392A0.json` /
  `.txt`, `docs/evidence/p2.2-module-rtti-classes.txt` (Alien vtable), `p2.3-feeding.md` §4/§7
  (food field map, slot 77 consume), `docs/evidence/p2.7-melee-damage.json` (`+0x1F0` is hp)
- Confidence: high for both bodies; the *intent* of the Gus pellet effect stays an open question
- Notes: (1) **`FUN_005392A0()` is a Tank predicate** (ECX = Tank) returning 1 when any of three
  list containers is non-empty - `Tank+0xA0` (the fish list; P2.7 reads its count), `Tank+0xA4`
  and `Tank+0xD0` (the Penta list, P2.4/P2.5) - or when any of `FUN_004E3ED0()`, `FUN_004E3F00()`,
  `FUN_004E3F30()`, `FUN_004E3F60()` returns non-zero; otherwise 0. Each list test is the usual
  begin/end count (`end - begin >> 2 == 0` = empty). The four sub-predicates were not decompiled.
  The alien attack gate `FUN_004D4580` therefore opens while a boss is alive or while the tank is
  still "active" in this sense, and the wave block reuses the same predicate as its
  level-complete test.
  (2) **`FUN_004E8F70()` is the bite/consume step** that `FUN_004ED460` calls every tick while a
  target is held. For Gus (kind 4) it scans the food list `Tank+0xAC`: a pellet is in reach when
  Gus's centre (`+0x160`/`+0x168` + 80) lies inside `pellet.x - 0x19 .. pellet.x + 0x41` (and the
  same in y), with `pellet+0x198 == 0` (edible) and this alien's `+0x200 < 6`. On a bite it
  removes the pellet through `FUN_004D9570()` (the helper the fish consume also uses), sets
  `+0x200 = 10`, calls `FUN_005384C0()`, and **subtracts from `+0x1F0`**: 30 / 25 / 20 for pellet
  variants 3 / 5 / 4, `quality*2 + 4` for every other variant via `FUN_004E3E00()`, 20 for a
  star-potion pellet (`pellet+0x188 == 3`, which also plays sound `0x11D` and spawns 1-3 debris
  pairs), and 8 in demo. `+0x1F0` is the pool pet melee drains and `Update` kills at `<= 0`, so in
  binary terms eating a pellet costs Gus health; the gameplay intent is recorded as open (Q-0020).
  For every other kind the branch is gated by `FUN_00503580()` and, for non-Gus aliens, by
  `+0x1A0 < 1`; it scans the creature list `Tank+0x108`, skipping objects with `+0xAC >= 0` or
  `+0x120 > 0`, then applies a centre-to-centre reach test - `+-0x2D` x / `+-0x41` y for aliens
  (`+-0x1E`/`+-0x1E` for Minisylvester), `+-0x46`/`+-0x55` for target type 6 - and on a hit calls
  the alien's vtable slot `0x134/4 = 77` (the index Fish uses for `consume`) plus the target's
  slot `0x12C/4 = 75`, then returns. Target eligibility: types 5-0xA unconditional, type 0 only
  when `FUN_00500FF0()` returns 0, types 0x14/0x15 only while a boss alien is alive.
  (3) The Alien vtable dump in `p2.2-module-rtti-classes.txt` is capped at 64 entries, so the
  addresses behind slots 77 and 75 are not bound yet (bounded negative: nothing in the existing
  dossiers maps them for `Alien`).
  (4) This entry closes the "`FUN_004E8F70` still open" item of EV-0115 and the
  "`FUN_005392A0` not decompiled" items of EV-0113/EV-0114; it does not alter their other claims.

### EV-0117 - P2.9 Cyrax's two spawn timers decoded (corrects EV-0114)
- Date: 2026-10-29
- Type: code trace (module decompilation), **corrects EV-0114**
- Source: `docs/evidence/p2.8-fn-4F03D0.txt` (kind 0x15 branch, re-read),
  `docs/evidence/p2.9-fn-545580.json` / `.txt` (`FUN_00545580`),
  `docs/evidence/p2.9-fn-5475B0.json` / `.txt` (`FUN_005475B0`), `docs/evidence/p2.8-alien-ctor-4ECFA0.txt`
- Confidence: high for both bodies and for the timer wiring; the runtime *rate* depends on the
  36 Hz tick assumption (EV-0080)
- Notes: EV-0114 §8.4 read the two Cyrax actions the wrong way round ("`FUN_00545580` spawns a boss
  projectile", "`FUN_005475B0(count,1)` summons 4-9 Minisylvesters"). The bodies prove the reverse:
  (1) **`FUN_00545580(x, y)` spawns a Minisylvester.** It allocates 0x208 bytes (`FUN_00564345`),
  calls `FUN_004ECFA0(x + 0x28, y + 0x28, 0x14)` - i.e. kind **0x14** (Minisylvester) offset by
  40,40 from the caller's point - registers it with `FUN_00542EE0(obj, 1)`, appends it through the
  manager list vtable (`[manager+0x10]` slot +0xC), then `FUN_00544800()` and `FUN_0053AA40()`
  (UI/score refresh). Called from the kind-0x15 branch with `(+0x30, +0x34)` = the boss's own
  anchor, every `+0x1E8 = 75` ticks.
  (2) **`FUN_005475B0(type, play_sound)` is the generic wave spawner wrapper.** Two
  `FUN_0040AEB0()` rolls and `FUN_00545620(type, rand%0x1C2 + 0x14, rand%0xC3 + 0x69,
  play_sound)` - the same `(20..469, 105..299)` spawn rectangle as the wave block (EV-0114).
  (3) The kind-0x15 branch therefore runs two independent clocks: `+0x1E0` against `+0x1E8 = 75`
  (unconditional, respawns a 1-hp Minisylvester at the boss), and `+0x1DC` against `+0x1E4 = 300`
  gated on **both** `Tank+0xB8` (aliens) and `Tank+0xF4` (enemy projectiles) being empty, which sets
  `Tank+0x700 = rand()%6 + 4` and calls `FUN_005475B0(Tank+700, 1)`. The rolled value is an alien
  **type** in 4..9 (Gus, Destructor, Ulysses, Psychosquid, Bilaterus, Sylvester+Balrog), not a
  count. `Tank+0x700` lies outside the 0x504-byte Tank allocation and is read back by the same
  call - a scratch slot, not a field.
  (4) Bounded negative: no projectile spawner exists anywhere in the kind-0x15 branch, and no body
  compares `Alien+0x1F0` against a fraction of `+0x1F8`, so "Cyrax shoots fireballs" and "Cyrax has
  phases" have no binary counterpart. The only escalation is the `profile+0x54` hp scaling of
  EV-0111.

### EV-0118 - P2.9 boss defeat cleanup, HP-bar geometry, and `FUN_00564160` = CRT `ftol`
- Date: 2026-10-29
- Type: code trace (module decompilation), **corrects EV-0113 §9**
- Source: `docs/evidence/p2.9-fn-4F9950.json` / `.txt`, `docs/evidence/p2.9-fn-4DAE20-dossier.json`
  (`rea function 0x4DAE20`, assembly + native value flow, block `0x4DB131-0x4DB1B6`),
  `docs/evidence/p2.9-fn-564160.json` / `.txt`, `docs/evidence/p2.8-alien-sprite-4DAE20.txt`
- Confidence: high for the cleanup and the arithmetic; the `+0x178` flag's writer is still unknown
- Notes: (1) **`FUN_004F9950` is boss-only.** Its body is wrapped in
  `if (Alien+0x1EC == 0x15)`: clear `Tank+0x110` (boss slot), set `Tank+0x4F4 = 1`, loop
  `Tank+0xBC` calling `FUN_005420E0(&obj)`, then collect `Tank+0xB8` (aliens) and `Tank+0xDC`
  (enemy projectiles) into one vector and call `FUN_004D6830(1)` on each. Because the wave clock
  needs `Tank+0x4F4 == 0` (EV-0114), killing Cyrax also permanently freezes wave spawning for the
  level. Every other kind takes the unconditional unregister path only.
  (2) **HP-bar geometry, from the assembly.** The bar block is entered when
  `Alien+0x1EC == 0x15 || (Tank+0x178 != 0 && Tank+0x3C8 != 5)`. `tube_w =
  [DAT_005e8e3c + 0x24]`, `tube_h = [DAT_005e8e3c + 0x28]`, `y = [Alien+0x3C] - 3` (box height
  160 - 3), `w = clamp(ftol(tube_w * [Alien+0x1F0] / [Alien+0x1F8]), 0, tube_w)` via
  `FILD [EBP+0xc]; FMUL [EDI+0x1f0]; FDIV [EDI+0x1f8]; CALL 0x564160`, then
  `FUN_00455E40(DAT_005e8e3c, 10, y, &CRect(0, 0, w, tube_h))` and `FUN_00455D20(DAT_005e8eb8, 10, y)`.
  The two globals are `IMAGE_HEALTHBARTUBE` (0x59CD64) and `IMAGE_HEALTHBAR` (0x59CD78).
  (3) **`FUN_00564160` is the CRT float->int helper**, not a resource lookup: its body is
  `ROUND(in_ST0)` (`_ftol`-style; it reads the x87 stack top and takes no stack arguments). This
  corrects EV-0113 §9, where `FUN_005442C0(FUN_00564160(...), FUN_00564160(...), frame, kind,
  facing)` was read as "a pair of resource lookups"; the first two arguments of `FUN_005442C0` stay
  unexplained and are re-opened in Q-0020. The same helper supplies `local_2c` in the intro-scale
  path of `FUN_004DAE20`, so it is a plain conversion there too.

### EV-0119 - P2.9 egg-piece purchase gates, `Tank::SpendMoney`, and the `profile+0x54` increment
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.5c-eggpiece-fn-545960.txt` (extracted from
  `p2.5c-eggpiece-fn-545960.json`), `docs/evidence/p2.9-fn-540B30.json` / `.txt`
  (`Tank::SpendMoney`), `docs/evidence/p2.9-fn-538090.json` / `.txt` (`FUN_00538090`),
  `docs/evidence/p2.9-xrefs-599188.json`, `docs/evidence/p2.8-wave-block-547610.txt`
- Confidence: high for the call graph and constants; the store UI was not decompiled (Q-0021)
- Notes: (1) **`FUN_00545960` (egg piece) has exactly two gates**: `FUN_00538090(0xB)` and
  `FUN_00540B30(price, quiet)`. `FUN_00538090(i)` is a store-object getter - `slot = Tank+0x2E4 +
  i*4`, negative -> 0, else `Tank+0x404 + slot*4`. `FUN_00540B30` is `Tank::SpendMoney`: mode 5 is
  exempt and returns 1 immediately; it returns 1 after `Tank+0x3F0 -= amount`; otherwise it plays
  sound `0x112`, sets `Tank+0x450 = 70` and returns 0. **Neither gate reads `Tank+0x110`**, so the
  binary does not require Cyrax to be dead before the free egg piece can be bought.
  (2) On success the handler increments `Tank+0x43C`, records `Tank+0x3FC`, clears `Tank+0x4EE`
  and completes at `Tank+0x43C >= 4` (P2.5c, EV-0067/EV-0115).
  (3) **`profile+0x54` increment, exact.** In `FUN_00547610`, inside the `Tank+0x2A5 == 0 &&
  mode != 5` block, the tank-5 branch (`Tank+0x3C8 == 5`) runs when the containers `Tank+0xB4` and
  `Tank+0xB0` are both empty: `FUN_0053DB80(); Tank+0x4EE = 0;` then
  `if ((boss = Tank+0x110) != 0 && boss->[0x1F8] - boss->[0x1F0] > 1000.0) (*(int*)(profile+0x54))++;`
  followed by dialog events 0x11/0x12/0x13 through `FUN_0054B5B0`. Its sibling (non-tank-5) branch
  is the "no fish left" loss handler, so the tank-5 branch reads as the loss/retry counter that
  feeds the hp scaling of EV-0111. Recorded as a naming question only (Q-0022).
  (4) `docs/evidence/p2.9-xrefs-599188.json`: the string `"Stop shooting! Alien regains health!"`
  (0x599188) has exactly one reference, `0x4FA7C6` (EV-0120).

### EV-0120 - P2.9 `FUN_004FA6F0` is the shot hit handler: damage, cooldown, knockback, Psychosquid heal
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.9-fn-4FA7C6.json` / `.txt` (`FUN_004FA6F0`), reached from the single
  xref of the hint string (`docs/evidence/p2.9-xrefs-599188.json`); `docs/evidence/p2.7-melee-damage.json`
  for the melee path
- Confidence: high for the branch structure, formulas and constants; the `from_shot` argument at the
  kill call site is not visible (Q-0022)
- Notes: (1) **Hit box.** The point must satisfy `+0x160 < x < +0x160 + 160` and
  `+0x168 < y < +0x168 + 160`; otherwise return 0. Single test for every kind - no sub-region, no
  direction requirement, so Cyrax has no weak point.
  (2) **Cooldown.** `if (0 < +0x200) return 0;` at entry and `+0x200 = 10` before every successful
  return, i.e. at most one hit per 10 ticks per alien (~0.28 s at 36 Hz).
  (3) **Damage.** Kinds 5/6 (`Destructor`/`Ulysses`): `hp -= Tank+0x3E4 * 2 + 2`. Every other kind
  including 0x15: `hp -= Tank+0x3E4 * 3`. `Tank+0x3E4` is the field used as pet capacity at level
  start (2), in demo (8) and forced to **10** when the boss spawns (EV-0113), and as the store's
  weapon-upgrade counter up to 12 (EV-0057). At the boss-forced value a Cyrax hit removes **30** hp,
  so 5000 hp = 167 hits (1670 ticks / 46.4 s of continuous shooting) and 2500 hp = 84 hits (23.3 s).
  The field's double role (capacity + shot damage) is a P2.10 item.
  (4) **Psychosquid special case** (kind 7, not boss-related): while resting (`+0x204 != 0`) and with
  no boss alive (`Tank+0x110 == 0`) a shot *heals* `Tank+0x3E4 * 3` and calls `FUN_0041D8B0` with
  `"Stop shooting! Alien regains health!"`; a shot that takes it below 100 hp forces sleep again
  (`+0x204 = 1`, `+0x19C = 1`, `+0x1AC = 10`, `+0x194 = rand()%100`), outside demo.
  (5) **Knockback** after the damage step: the click point is compared against the inner 60x60 and
  100x100 sub-boxes and `+0x170`/`+0x178` are set to `+0x1B8 * (+-2.5 / +-3.0 / +-3.5 / +-4.0)`
  (full quadrant table in the raw listing). Kinds 5/6 skip it while `+0x1AC != 0`.
  (6) **Death.** `if (+0x1F0 <= 0.0) { FUN_004F9C70(); return 1; }` - the shot kill enters the
  P2.8 §9 path. The argument is not materialised at this call site; the melee path passes 1
  explicitly, so the diamond drop for shot kills is taken as 1 per EV-0115 and kept as a small open
  detail (Q-0022).
  (7) Bounded negative: no shield, regeneration or invulnerability branch exists for kind 0x15 in
  this body; the boss can only be worn down.

### EV-0121 - P2.9 laser damage cross-check: `Tank+0x3E4` is the weapon level, 6 damage per hit at base
- Date: 2026-10-29
- Type: inference (from EV-0057, EV-0063, EV-0120 and the wiki hit counts of EV-0060/EV-0074)
- Source: EV-0057 (store item 10 "weapon" bumps `Tank+0x3E4`, max 0xB), EV-0063 (`+0x3E4 = 2` at
  session init, 8 in demo), EV-0113 (`Tank+0x3E4 = 10` when the boss spawns), EV-0120 (damage =
  `3 * Tank+0x3E4`), `wiki-refs.md` §2 (wiki hit counts)
- Confidence: high for the arithmetic; medium for the "weapon level" label (the field's two uses are
  proven, the name comes from one store case)
- Notes: evaluated at the level-start value `Tank+0x3E4 = 2`, the formula of EV-0120 gives **6 damage
  per laser hit**, which reproduces the wiki's hit counts exactly - Sylvester 50 hp / 10 hits (9.0
  needed), Balrog 130 hp / 22 hits (21.7), Bilaterus 100 hp per head / 17 hits (16.7) - and the
  field's own store item is the **weapon upgrade** (item 10, cap 11, so the ceiling would be 33 per
  hit). This supports the "one field, two uses" reading (pet capacity + shot damage) and removes
  EV-0120's open worry about a missing damage source; P2.10 still owns the click/laser pipeline and
  the store item's write. It does not establish what the wiki counted for other kinds.

### EV-0122 - P2.10 the tank click handler: one click = one shot, resolved in a fixed order
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.10-fn-543A38.json` / `.txt` (`FUN_00543920`, entered from the
  `Alien::HitTest` xref `0x543A38`), `docs/evidence/p2.10-xrefs-4FA6F0.json`
- Confidence: high for the branch order, guards and calls; the identity of the `Tank+0xBC` list is
  still open (Q-0023)
- Notes: (1) `FUN_00543920(x, y, button)` starts with `FUN_0046E3A0(x, y, button)` and then
  dispatches in this order, stopping at the first branch that reports a hit:
  `Tank+0x2A5 != 0` (bonus round) -> `FUN_00537F40` when `button >= 0` / `FUN_0053BFB0(x, y)` when
  `button < 0` and `y > 40`; then the `Tank+0xBC` list (only while `Tank+0x110 != 0` **and**
  `y > 40`) calling `Alien::HitTest` `FUN_004FA6F0` per element; then the boss itself
  (`Tank+0x110`, same call); then the `Tank+0xB8` alien loop (skipped entirely when the first
  alien is kind 4 with no boss alive); then the `Tank+0xDC` list with `Larva::HitTest`
  `FUN_004D82A0(x, y)`; then the `Tank+0xF4` list with `Missle::HitTest` `FUN_004FFAE0(x, y)`;
  finally the feed path.
  (2) **Any resolved click** ends with `FUN_00538AE0()` (an internal `hit` flag is set by the
  alien, boss and projectile branches). Those branches draw the laser spark with
  `FUN_00543640(x - 0x28, y - 0x28)` and the alien/projectile branches stamp
  `Tank+0x4ED = 1` and `Tank+0x3C4 = FUN_00537B60()`. The feed path instead spends `Tank+0x4AC`
  through `Tank::SpendMoney(price, 1)`, calls `FUN_00543280(x - 10, y - 10, 0, 0, variant, -1)`
  and sets `Tank+0x4EC = 1`, `Tank+0x3C0 = FUN_00537B60()`.
  (3) **Guards.** Alien/boss/projectile branches require `y > 0x28` (40) - the water line. The
  feed branch requires the click to be inside `x 31..586` and `y 61..399` (the unsigned range
  tests `x - 0x1F <= 0x22B`, `y - 0x3D <= 0x152`) and no target alive. A click on a Gus with no
  boss alive takes the `FUN_004D46F0(x, y)` path and drops a variant-`0x14` pellet.
  (4) There is **no weapon object, cooldown or projectile owned by the player** in this path; the
  only rate limit is the per-alien `Alien+0x200` cooldown of EV-0120.

### EV-0123 - P2.10 weapon upgrade: cap is 12, and level 12 unlocks Rapid Fire (corrects EV-0057)
- Date: 2026-10-29
- Type: code trace (module decompilation), **corrects EV-0057**
- Source: `docs/evidence/p2.10-fn-549380.json` / `.txt` (`Tank::BuyItem` `FUN_00549380`),
  `docs/evidence/p2.10-fn-5406A0.json` / `.txt` (store refresh `FUN_005406A0`),
  `docs/evidence/p2.2-game-module-strings.txt` (0x5A82C8)
- Confidence: high
- Notes: (1) `case 10` (store item "weapon") is
  `if (Tank+0x3E4 < 0xc && Tank::SpendMoney(price, quiet)) { Tank+0x3E4 += 1; FUN_005406A0(); }`,
  so the cap is **12**; EV-0057's "weapon `Tank+0x3E4` max 0xB" is a misreading of the
  `case 0xb` label. Damage therefore spans 6 (level 2) to 36 (level 12) per hit (EV-0120/EV-0121).
  (2) `FUN_005406A0(item, show_hint)` re-targets the selected store object through
  `FUN_00538090()` and refreshes it; its item-10 branch calls `FUN_00530410()` and, when
  `Tank+0x3E4 > 0xB` with the hint flag set, shows
  `"Hold down mouse button for Rapid Fire!"` (0x5A82C8) through `FUN_0041D8B0` +
  `FUN_0053E950()`, then `FUN_00534450()`. Level 12 is thus a behavioural unlock, not only +3
  damage. Its implementation (auto-repeat loop) was not found (Q-0023).
  (3) Same function, item 3 (food quantity) shows `"Hold down mouse button to Auto-Feed!"`
  (0x5A8AB4) on the first purchase in tank 1 - consistent with P2.3's auto-feed note.

### EV-0124 - P2.10 `Sexy::Missle`/`Sexy::Larva`: spawner `FUN_00544130` and ctor `FUN_004EAE40`
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.10-fn-544130.json` / `.txt`, `docs/evidence/p2.10-fn-4EAE40.json` /
  `.txt`, `docs/evidence/p2.2-module-rtti-classes.txt` (vtables `0x5DF5D4` Larva, `0x5DF5F0`
  Missle; update slot 22 = `0x4F2930` / `0x4FFB30`)
- Confidence: high for the fields and constants; the homing body is not decompiled
- Notes: (1) `FUN_00544130(x, y, target, kind)` allocates 0x1B8, calls `FUN_004EAE40(x, y, target,
  kind)`, registers with `FUN_00542EE0(obj, 0)`, then through `[this+0x10]`'s vtable calls slot +0xC
  with the object and slot +0x2C twice (the second call with `[this+0x100]`), and finally, **outside
  demo only**, stores the object at `target+0x98` (the victim's "incoming projectile" pointer).
  (2) The ctor installs `Sexy::Missle::vftable` and sets `+0x158/+0x160` = x/y (doubles),
  `+0x30/+0x34` = their ftol copies, `+0x19C` = kind, `+0x1A4` = target pointer,
  `+0x168/+0x170` = vx/vy 0, `+0x38/+0x3C` = 80x80 box (**50x50 for kind 2**), `+0x188` = 0.8
  speed divisor (**0.4 for kind 2**), `+0x194/+0x198` = 1/1, `+0x1A8/+0x1AC` = 0/10,
  `+0x17C` = 15, `+0x1A0` = `rand() & 3`, `+0x190` = 0, `+0x8C` = 0x1E. In demo it also seeds
  vx and vy from `{-6,-5,-4,+4,+5,+6}` (random direction).
  (3) Call sites: Destructor `FUN_00544130(x, y, target, 0)` (3 missiles, P2.8 §8.1), Ulysses
  `..., 1` (2 balls, P2.8 §8.2). No decompiled body creates kind 2 yet (Q-0023).

### EV-0125 - P2.10 projectile update, hit tests and the `Larva` fall/shell path
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.10-fn-4FFB30.json` / `.txt` (`Missle::Update`),
  `docs/evidence/p2.10-fn-4FFAE0.json` / `.txt` (`Missle::HitTest`),
  `docs/evidence/p2.10-fn-4D82A0.json` / `.txt` (`Larva::HitTest`),
  `docs/evidence/p2.10-fn-4F2930.json` / `.txt` (`Larva::Update`)
- Confidence: high for the bounds/flags; the homing target logic (`FUN_004FF4E0`) and the missile
  box test (`FUN_004FE480`) are not decompiled
- Notes: (1) `Missle::Update` returns when `Tank == 0` or `Tank+0x94 != 0`, runs `FUN_004F22C0`
  (base update), expires via `+0x1A8` counting to `+0x1AC` (10) -> `FUN_004D80E0()`, runs the
  homing step `FUN_004FF4E0()`, then applies kind-specific bounds: kind 0 is **clamped** into
  `x 10..550`, `y 95..370`; kinds 1/2 call `FUN_004D80E0()` outside `x -20..580`, `y 45..380`
  (kind 1 only after `+0x190 != 0`). kind 2 with `+0x190` gets `vy += 0.2` per tick (gravity).
  Movement is `x += vx/speed`, `y += vy/speed`; `+0x17C` counts down; kind 0 emits an 8-px smoke
  particle through `FUN_005436F0` on `rand() % 3 == 0`.
  (2) `Missle::HitTest(x, y)`: when `+0x158 != 0`, `FUN_004FE480(x, y)` decides the hit; a hit
  spawns a 2-px burst at `(x - 0x28, y - 0x28)` and returns 1 - clicking a missile shoots it down.
  (3) `Larva::HitTest(x, y)`: kind 1 tests `(+0x158+10..+0x158+70)` x `(+0x160+10..+0x160+70)`
  while `+0x17C < 1` and **deflects** the object: `vx = ((click.x - x0) - 40)/-5`,
  `vy = ((click.y - y0) - 40)/-5`, each clamped to +-1, then `+0x190 = 1`; kind 0 tests a 60x60
  box centred on the object and calls `FUN_004D80E0()` (destroy). Both spawn the 2-px burst and
  return 1; kind 2 returns 0.
  (4) `Larva::Update` uses the same pause gate, sets `+0x55 = 1` and `+0x7C = 1` once when
  `+0x58 < 320` and `+0x175 == 0`, then runs one of two modes keyed by `+0x5D`: mode 0 falls
  (`y -= vy`) and despawns through `FUN_004D9570()` at `y < 64` (x wraps at 530); mode 1 lerps
  towards `(550, 30)` at 1/7 of the distance per tick and, when the integer y drops below 40,
  despawns, increments `Tank+0x4A8` and calls `FUN_0053C1E0(...)` (the Shells routing helper of
  P2.6) - so this object **pays out shells** when it reaches the corner. Its gameplay identity is
  open (Q-0023).

### EV-0126 - P2.11 the mode field, `start_level` and the per-mode banners
- Date: 2026-10-29
- Type: code trace (module decompilation) + string table
- Source: `docs/evidence/p2.11-fn-54CBF0.json` / `.txt` (`FUN_0054CBF0`), `docs/evidence/p2.11-fn-54CB20.json`
  / `.txt` (`FUN_0054CB20`), `docs/evidence/p2.11-fn-5498B0.json` / `.txt` (`FUN_005498B0`),
  `docs/evidence/p2.11-fn-5404A0.json` / `.txt` (`FUN_005404A0`), `docs/evidence/p2.8-wave-block-547610.txt`
  (tank update, lines 891-918), `docs/evidence/p2.2-game-module-strings.txt`
- Confidence: high for the branches and banner strings; the mode **writer** is not located
- Notes: (1) `[manager+0x87C]` is the game mode, read by more than twenty sites; the values bound by
  behavior are 0 = Adventure, 1 = Time Trial, 3 = Sandbox, 4 = Challenge, 5 = Virtual Tank, and 2 is
  unobserved (Q-0014). Bounded negative: no write to `[manager+0x87C]` appears in any committed
  decompiled body (`docs/evidence/*.txt`), so the selector is menu code (P2.12).
  (2) `FUN_0054CBF0` is `start_level`: clear `manager+0x883`; if mode 5 and `FUN_0054CB20()` is
  non-zero return (resume a Virtual Tank); `FUN_0054C540()` (fresh tank + session counter),
  `FUN_00541A20()` (tank init); if `FUN_0054B2A0()` (sentinel) -> `FUN_00537E20` + `FUN_0054B2D0`;
  if mode 5 -> `FUN_0053C3F0()` + `FUN_0054B2D0`; else `FUN_005498B0()` + `FUN_0054B2D0`.
  (3) `FUN_0054CB20` is Virtual Tank load-or-create: `FUN_0054C540()`, then
  `FUN_00505880(path, mode, profile+0x44)`, then `FUN_00546AA0(path)`; when that is false it calls
  `FUN_0054BC30()`, otherwise it clears `manager+0x883` and, if the mode is not 5, calls
  `FUN_0054B3A0()`. `profile+0x44` is therefore the VT tank slot; `sim%d.dat` is the file (P2.13).
  (4) `FUN_005498B0` is the normal session init and is mode-independent: tank 4 spawns through
  `FUN_005471E0` and sets the first `+0xC0` fish `+0x1A4 = 2`; tank 5 sets `Tank+0x2C0 = 300` and
  spawns 18 pets (`FUN_00544A90`, indices 0..0x11); other tanks spawn two starters via `FUN_00546EF0`
  and set the first `+0x1A4 = 2`, plus `+0x228 = 1` on the tank-1 level-1 guppy.
  (5) Per-mode banners at tick `0x96`, all through `FUN_00426BE0`/`FUN_0053E950`: mode 0 "Here are
  your first fish! Take good care of them!" (and "On this level you will meet your 1st alien
  opponent!"), mode 1 "How much money can you earn before time runs out?", mode 4 "Can you fend off
  the increasingly hungry aliens?", mode 3 "Make sure caps-lock is off and GO TO TOWN!!"; mode 5
  has no banner.
  (6) `FUN_005404A0(option)` is **not** a mode selector: it toggles `Wavy Mode`, `Original Prego
  Sound`, `Original Breeder Sound`, `Ultra Prego Sound`, `Void Mode`, `Space Mode` (also
  `FUN_00511580`) and `Zombie Mode` (`DAT_005e89ce`), each printing an Enabled/Disabled toast.

### EV-0127 - P2.11 Time Trial timer, Challenge price inflation, Sandbox re-roll
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-wave-block-547610.txt` (tank update: lines 181-197 for the clocks,
  227-291 for the mode-4 store block, 432-440 for mode 3), `docs/evidence/p2.2-game-module-strings.txt`
  (0x5A26C0, 0x5A26D4)
- Confidence: high
- Notes: (1) Mode 1 (Time Trial): every tick `Tank+0x3B0 = (FUN_00537B60() - Tank+0x3B8) / 1000`
  (integer seconds); when `Tank+0x3BC - Tank+0x3B0 < 0` the tank clears `Tank+0x4EE`, calls
  `FUN_0053C2D0()` (collect all coins), `FUN_00514470()` and `FUN_0054EB80()` and returns. Mode 4
  writes the same `Tank+0x3B0` elapsed field. Budgets are 300 s (tank 1) / 600 s (tanks 2-4), and
  the results screen labels are "TIME TRIAL RESULTS" (0x5A26C0) / "CHALLENGE RESULTS" (0x5A26D4).
  (2) Mode 4 (Challenge) **price inflation**: while `Tank+0x454 < 1`, `Tank+0x43C < 6` and byte
  `Tank+0x3A4` or `Tank+0x3A5` is non-zero, every `period` ticks (150/150/175/200 for tanks 1/2/3/4)
  the loop runs `price[i] = min(price[i] + increment[i], 99999)` over the 12 store items
  (`Tank+0x314[i] += Tank+0x374[i]`) followed by the refresh helper `FUN_00534380()` per item.
  (3) Mode 4 alien substitution: when the wave counter `Tank+0x45C > 4` and the rolled type
  (`Tank+0x2BC`) is 8, it is replaced by 0xC; no hp/speed multiplier exists in a mode-4 branch.
  (4) Mode 3 (Sandbox): while the tank index is not 5 and `Tank+0x2E0 < Tank+0x2DC`, the update runs
  twelve `FUN_005409B0()` item refreshes and then `FUN_005380C0()` = `SetStorePrice` (P2.5).

### EV-0128 - P2.11 Virtual Tank: init block and the 76 %/weighted fish spawner
- Date: 2026-10-29
- Type: code trace (module decompilation) + string table
- Source: `docs/evidence/p2.11-fn-53C3F0.json` / `.txt` (`FUN_0053C3F0`),
  `docs/evidence/p2.11-fn-51B260.json` / `.txt` (`FUN_0051B260`), `docs/evidence/p2.8-wave-block-547610.txt`
  (line 294 and line 470 for the mode-5 skip, line 813 for the lose check),
  `docs/evidence/p2.2-game-module-strings.txt` (0x5A3CBC-0x5A44F0)
- Confidence: high for the fields and weights; the VT store/HUD helpers and `Tank+0x4FE`'s writer are
  unbound
- Notes: (1) `FUN_0053C3F0()` resets the tank for a virtual session: `Tank+0x2BC = 0`, `+0x94 = 0`,
  `+0x4EE = 1`, `+0x440 = 0`, `+0x444 = 0`, `+0x450 = 0`, `+0x454 = 0`, `+0x458 = 0`, `+0x45C = 0`,
  globals `DAT_005e89dc = 0`, `DAT_005df58c = 1`, `DAT_005e89cc = 0`, `DAT_005e89d0 = 0`,
  `DAT_005e89c0 = 0`, `Tank+0x3B4 = Tank+0x3B8 = now()` and `Tank+0x4FC = <byte>`; then
  `FUN_005394E0()` (populate), `FUN_0053A4F0()` (store), `FUN_0053AA00()` (HUD).
  (2) No aliens in VT: the tank update jumps over the whole wave clock when mode is 5 and
  `Tank+0x4FE == 0` (the same byte gates the warning sound elsewhere); its writer is unbound
  (Q-0020). A VT-specific sub-branch also fires `FUN_005409B0()` while `Tank+0x344 == 0`, `+0x340 == 0`
  and the level-end flags are clear.
  (3) `FUN_0051B260(flag, excluded_type)`: when `flag != 0` and `rand() % 100 < 76` it spawns an
  ordinary fish through `FUN_00519E00()` (and with 76 % again upgrades it via `FUN_00519890(obj, 1)`);
  otherwise it rolls a prize fish from the weighted table below. A roll equal to `excluded_type`, or
  `FUN_005195E0() == 0`, retries up to 100 times and then recurses with `excluded_type = -1`.

  | weight | type id | alloc | spawn helper |
  | --- | --- | --- | --- |
  | 26 | 8 | 0x1B0 | `FUN_004EC0F0` |
  | 25 | 9 | 0x1B0 | `FUN_004EA7B0` |
  | 25 | 7 | 0x230 | `FUN_004EF9A0` |
  | 10 | 10 | 0x1E0 | `FUN_004EE530` |
  | 5 | 6 | 0x230 | `FUN_004F02A0` |
  | 3 | 0x24 | 0x238 | `FUN_004F0630` (+ `+0x230 = rand() & 1`) |
  | 3 | 0x23 | 0x230 | `FUN_004F0570` |
  | 3 | 0x22 | 0x230 | `FUN_004F01E0` |

  The weights sum to 100 and the test is a strict `<`, so index 8 is unreachable and type 5 shares
  the type-8 branch. (4) Mode 5 prints "Here you'll be able to build your own custom fish tank!" at
  tick 150 when `profile+0x48 == 0`. (5) The in-game help text fixes the VT rules: fish cannot die,
  grow in about a real-world week when fed daily, want three meals a day, the store changes with the
  real date, and the tank can be set as the screensaver from the Tank screen.

### EV-0129 - P2.11/P2.10 Rapid Fire is implemented in the tank update (resolves Q-0023's item)
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.8-wave-block-547610.txt` (lines 315-405),
  `docs/evidence/p2.11-fn-46CCE0.json` / `.txt`
- Confidence: high
- Notes: (1) The click handler only arms the repeat: it stamps `Tank+0x4ED = 1` and
  `Tank+0x3C4 = FUN_00537B60()`. The tank update then runs
  `if (Tank+0x4ED != 0) { if ((FUN_0046CCE0() == 0)) Tank+0x4ED = 0; else if (Tank+0x3E4 > 0xB &&
  tick % (0xB - Tank+0x3E4 / 2) == 0 && now() > Tank+0x3C4 + 100 && click_y > 0x28) { ... } }`.
  (2) `FUN_0046CCE0()` is `return *(byte *)(this + 0xEC) & 1`, i.e. the tank's mouse-button latch bit.
  (3) The repeated shot tests `Tank+0xF4` (`Missle::HitTest`), then `Tank+0xDC` (`Larva::HitTest`),
  then `Tank+0xB8` (`Alien::HitTest`), then draws the spark (`FUN_00543640`) and calls
  `FUN_00538AE0()`. The boss, the `Tank+0xBC` list, the bonus round and the feed path are not
  repeated. (4) At the cap (level 12) the period is `11 - 6 = 5` ticks, but the 100 ms stamp
  (`Tank+0x3C4`) is the real limiter at 36 Hz.

### EV-0130 - P2.11 `FUN_004D80C0` is an object-kind test, not the demo flag (corrects P2.8/P2.10 wording)
- Date: 2026-10-29
- Type: code trace (module decompilation), **corrects the `demo` label used in EV-0124/EV-0125**
- Source: `docs/evidence/p2.11-fn-4D80C0.json` / `.txt`, `docs/evidence/p2.11-xrefs-4D80C0.json`
- Confidence: high for the body and the call sites; the per-call receiver class is unresolved
- Notes: (1) `FUN_004D80C0` is `v = *(int *)(this + 0x19C); return (v == 3 || v == 4 || v == 5);`.
  Eleven call sites (0x4D8139, 0x4D8278, 0x4E213D, 0x4E2223, 0x4EAF52, 0x4FD44F, 0x4FFAA1,
  0x4FFBAD, 0x541F0F, 0x5430B3, 0x5441C4). (2) For `Sexy::Missle`/`Sexy::Larva` the field is the
  kind (`in_ECX[0x67]`), so the predicate is `kind in {3,4,5}`; the only known spawn sites create
  kinds 0 and 1, so the missile ctor's random-velocity branch (EV-0124) and the kind-3+ bounds rule
  (EV-0125) are unreachable in retail play. For `Sexy::Alien` the same offset is a byte flag
  (Psychosquid's once-only sleep, EV-0120), so the predicate must not be ported to aliens.
  (3) The retail demo flag is `manager+0x880` (P2.8) - a different field; every "demo" claim that
  rested on `FUN_004D80C0` is withdrawn. Consequence: missiles always start still, are steered by
  `FUN_004FF4E0`, and the victim pointer `target+0x98` is always set by the spawner (Q-0024).
  Claims that read `manager+0x880` directly (EV-0111, EV-0115, EV-0120's damage gate) are
  unaffected and stand; only the function's name was wrong.

### EV-0131 - P2.12 screen inventory, the two-vtable convention and the Title/GameSelector ctors
- Date: 2026-10-29
- Type: code trace (module decompilation) + RTTI table + literal dump
- Source: `docs/evidence/p2.2-module-rtti-classes.txt` (rows 44-100),
  `docs/evidence/p2.12-xrefs-{5A2220,5A2244,5A2104,5A1654}.json` / `.txt`,
  `docs/evidence/p2.12-fn-at-52E0C1.json` / `.txt` (GameSelector ctor),
  `docs/evidence/p2.12-fn-at-52EB94.json` / `.txt` (TitleScreen ctor),
  `docs/evidence/p2.12-fn-at-51C169.json` / `.txt` (TitleScreen dtor),
  `docs/evidence/p2.12-fn-51C2A0.json` / `.txt`, `docs/evidence/p2.12-fn-51AA30.json` / `.txt`,
  `docs/analysis/snapshots/insaniquarium-game-module.exe` (vtable + literal bytes)
- Confidence: high for the field offsets and the button table; the widget/rect binding and the
  role of `FUN_0050FF90("give")` are unbound
- Notes: (1) Every screen class is a widget container plus an embedded `Sexy::ButtonListener` at
  `+0x88`; the object vtable is 64 slots at `+0x00`, the listener vtable is 7 slots (dtor + 6
  callbacks) and the manager pointer is `in_ECX[0x23]` (= `+0x8C`). ButtonListener callbacks receive
  `this = object+0x88`, so they read the manager as `[this+4]`. The listener slots a class does not
  override all point at the shared no-op `0x46C690`. This is why screen code uses `[obj+0x8C]` while
  the single-vtable gameplay classes use `[obj+0x88]` (P2.8).
  (2) `xrefs` on a class vtable returns exactly two code writers - the destructor and the
  constructor: TitleScreen 0x5A2104 -> {0x51C169, 0x52EB94}, GameSelector 0x5A2220 -> {0x51C300,
  0x52E0C1} and 0x5A2244 -> {0x51C2FA, 0x52E0BB}, StoreScreen 0x5A1654 -> {0x51954B, 0x52B31F}.
  Decompiling the non-destructor writer gives the constructor, which is how the two ctors below were
  found.
  (3) `TitleScreen` ctor `FUN_0052EB50(manager)` stores the manager at `+0xD4`, creates two image
  widgets at `+0x8C`/`+0x90` (`FUN_004728E0(index, &this[0x22])`), labels the second one "Click Here
  To Register!" and hides it when `app+0x71C`, `thunk_00479FC0()` or `app+0x71D` is set (else it
  calls `FUN_0052D2E0`). Its `.text`/`.data`-order vtables are 0x5A20E4 (listener) and 0x5A2104
  (object). The dtor `FUN_0051C140` sets both vtables, deletes the two children, frees the
  `std::string` at `+0xA8` (capacity `+0xBC`, length `+0xB8`) and calls `FUN_0046DD50`; `FUN_0051C2A0`
  is its scalar-deleting wrapper and is slot 0 of 0x5A2104. The listener slots 1 and 2 (`0x51AA30`,
  `0x51AA50`) both just forward to `(*DAT_005EB6A4)->vtable[0xD8](DAT_005E8C40)` - the title screen
  holds no menu logic.
  (4) `GameSelector` ctor `FUN_0052E070(manager)` builds eight buttons with `FUN_00475090(id,
  &this[0x22])` (image buttons: 1 at (0x165,0x30,0xD9,0x42) with bitmaps `DAT_005e8D80`/`...8CF8`/
  `...8E00`, 2 "Virtual Tank" at (0x165,0x11F,0xD9,0x42), 9 "Challenge" at (0x167,0xD4,0xD5,0x30),
  8 "Time Trial" at (0x167,0x8E,0xD5,0x30)) and `FUN_00506820(id, ...)` (text buttons: 3 "Options"
  at (0x145,0x19C,0x5C,-), 4 at (0x202,0x19C,0x59,-), 6 "Hall of Fame" at (0x191,0x17C,0x7F,-),
  7 at (0x1A3,0x19C,0x5D,-)); the 4-byte labels at 0x5A5BF4 and 0x5A5BEC are the NUL-terminated
  strings `Quit` and `Help` in a consecutive literal pool that also holds `give` and `Options.`.
  Fields: buttons at `+0x90/+0x94/+0x98/+0x9C/+0xA0/+0xA4/+0xA8/+0xAC`, overlay `+0xC4` (640x480),
  timer `+0xDC = rand()%150+100`, timer `+0xE0 = rand()%500+200`, `FUN_0050FF90("give")` widget
  `+0xCC`, `FUN_00504D30()` `+0xC8`, resource preloads `FUN_00505BA0(0x25..0x28)` x8 and
  `FUN_00505BD0(0x61/0x62)`, then the banner trio `FUN_0054B170(2,0)`/`FUN_0054B020()`/
  `FUN_0054B1A0(2,0,0)` when `manager+0x883 == 0`, and `FUN_005013F0()` when a profile exists.

### EV-0132 - P2.12 the mode writer is the GameSelector button callback (resolves Q-0024)
- Date: 2026-10-29
- Type: code trace (module decompilation) + vtable byte dump
- Source: `docs/evidence/p2.12-fn-at-51F160.json` / `.txt`,
  `docs/analysis/snapshots/insaniquarium-game-module.exe` (vtable 0x5A2220 bytes),
  `docs/evidence/p2.12-fn-552380.json` / `.txt`, `docs/evidence/p2.12-fn-54B360.json` / `.txt`
- Confidence: high
- Notes: (1) `FUN_0051F160(id)` is slot 2 of GameSelector's 7-slot ButtonListener vtable 0x5A2220
  (`0x517910, 0x46C690, 0x51F160, 0x46C690 x3, 0x49B300`), so it is the single click callback the
  menu overrides; `in_ECX` is `selector+0x88` and `[in_ECX+4]` is the manager.
  (2) Every id first clears the demo flag `[manager+0x880] = 0`. Ids 1 -> `[manager+0x87C] = 0`,
  2 -> `5`, 8 ("Time Trial") -> `1`, 9 ("Challenge") -> `4`; ids 3/4/6/7 are not mode buttons
  (`FUN_0054C620(1)` options dialog, `FUN_005517F0()` quit, `FUN_005522D0()` hall of fame,
  `FUN_0054C220(0)` help); 9999 -> `FUN_0054B5F0()`. The gates: Time Trial needs
  `profile+0x1C >= 2 || profile+0x59 != 0`, Challenge needs `profile+0x59 != 0`, and a refused
  press raises the 3-string "Not Yet!" box through `app->vtable[0x120](0xE, 1, ...)`.
  (3) Paths differ: id 1/2 run `FUN_0054B360()` (remove + destroy the object at `manager+0x738` and
  clear it) then `FUN_00552380(1,1)`; ids 8/9 run `FUN_0054B360()`, then
  `if (FUN_0054CB20() == 0) FUN_0054C130();`.
  (4) Consequence: modes 2 and 3 (Sandbox) have **no** writer anywhere in the corpus, so Q-0014
  stays open and Sandbox's name rests on the UI text alone; the demo-flag clear confirms EV-0130's
  reading of `manager+0x880`.

### EV-0133 - P2.12 StoreScreen field map, store action dispatch, dialog template
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.12-fn-52B2D0.json` / `.txt`, `docs/evidence/p2.12-fn-54A370.json` /
  `.txt`, `docs/evidence/p2.12-fn-54C620.json` / `.txt`, `docs/evidence/p2.12-fn-54B360.json` /
  `.txt`, `docs/evidence/p2.12-fn-534600.json` / `.txt`, `docs/evidence/p2.12-fn-5517F0.json` /
  `.txt`
- Confidence: high for the fields, rects and dispatch table; the item ctor `FUN_005331A0` is a plain
  field filler, so population/grey-out is not covered
- Notes: (1) `FUN_0052B2D0(manager)` stores `[manager+0x320]` (render list) at `+0x10`,
  `+0x1C4 = 0xC0` / `+0x1C8 = 0x6F` (row origin and pitch), the screen x/y from `manager+0xC0/C4`, then
  builds eight item widgets at `+0x9C..+0xB8` in a loop (`FUN_005331A0` + `vtable[0x9C]` with a rect
  from an 8-entry stack array), sets `+0x154 = 0x54` on the eighth and `+0x150 = 0` on items 4-7, a
  Shell counter at `+0xC0` (`FUN_00534600`; `+0xB4 = 2`, `+0x30 = 0xEE`, `+0x34 = 0x1B7`,
  `+0x38 = 0x50`, rect (250,155,150,255)), an `%d` buffer at `+0xC4`, `+0x1CC = rand()%150+100`, the
  refresh hooks `FUN_0054B020()`/`FUN_0054B1A0()`, and a 640x480 `StoreScreenOverlay` at `+0x94`. The
  item rects are (1,5,109,140), (1,143,109,140), (1,282,109,140), (193,38,98,140), (303,38,98,140),
  (414,38,98,140), (525,38,98,140), (489,339,121,100) in creation order.
  (2) The store action dispatcher is `FUN_0054A370(action)`: after the click sound it runs
  `Tank::BuyItem` (`FUN_00549380`) only when `mode != 5 && action < 0xC`; the tail switch handles
  0xA pet store (`FUN_0054BCA0`), 0xB `FUN_0054C060`, 0xC `FUN_0054C2D0`, 0xD `FUN_00551C90`,
  0xE `FUN_005492B0` (only when `FUN_0054B4B0() == 0`) and 0xF the egg purchase `FUN_00552230`. So
  Virtual Tank disables the item economy at the *caller* and the egg entry is reachable in every
  mode - only a grey-out inside the item widget can gate it on the boss (Q-0018/Q-0021).
  (3) Dialog creation `FUN_0054C620(flag)`: `FUN_0054B4C0()` (pause/retract), `new` 400-byte
  `OptionsDialog` via `FUN_005349D0(this, flag)` (vtable 0x5A6040/0x5A6074), size from
  `vtable[0x124]`, rect (0x8F,0x1A,0x15C,h), then `(*this)[0x12C](1, dlg)` pushes the window. Slots
  0x120 (message box) and 0x12C (window push) are the two app-level dialog entry points.
  (4) The Shell counter is a `Sexy::MyLabelWidget` (`FUN_00534600`): empty `std::string` (capacity
  `+0xA0`), `FUN_00433300()` default colour, a placeholder rect at `+0xA4` and a font at `+0xB8`;
  StoreScreen rewrites the rect (250,155,150,255) and the font (`DAT_005e8CE4`), and `FUN_005346D0`
  refreshes the text. The quit button `FUN_005517F0` raises the `0xB` message box with
  "Stop the insanity?" and a `Quit` button (`DAT_005a5BF4`), the same 0x5A5Bxx literal pool as the
  menu labels.

### EV-0134 - P2.12 level-start funnel, the `profile+0x5A` clear and the TankScreen builder
- Date: 2026-10-29
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.12-fn-552380.json` / `.txt`, `docs/evidence/p2.12-fn-54C130.json` /
  `.txt`, `docs/evidence/p2.12-fn-54B170.json` / `.txt`, `docs/evidence/p2.12-fn-5331A0.json` /
  `.txt`
- Confidence: high for the control flow; the `profile+0x5A` intent and the `profile+0x18`
  comparison are unresolved (Q-0025)
- Notes: (1) `FUN_00552380(start, tutorial)` is the single level-start funnel: an in-flight session
  wins (`FUN_0054BBB0()` -> `FUN_00552100()`), then `FUN_0054BC30()` (the tank create helper of
  EV-0128), then the first-Virtual-Tank banner when `mode == 5 && DAT_005e963C == 0` (`DAT_005e8F16
  = 1`, `DAT_005e963C = 1`, `FUN_005025F0(&LAB_0054B280, 0)`), then `if (start &&
  FUN_0054CB20()) return;` (resume), then it clears 24 bytes at `profile+0x5A`, then the first-run
  help (`tutorial && mode == 0 && profile+0x59 == 0 && profile+0x1C == 1 && profile+0x20 < 4 ->
  FUN_0054C220(1)`), then the between-tanks stop (`FUN_0054B2A0() == 0 && mode != 5 && edx <
  profile+0x18 && (mode != 0 || profile+0x1C != 5) -> FUN_0054C2D0()`), and only then
  `FUN_0054CBF0()` (start_level, EV-0126).
  (2) The 24-byte clear collides with P2.6 §1.5, which reads `profile+0x5A+i` to instantiate pets
  at level start; `FUN_0054C540`/`FUN_00541A20`/`FUN_005498B0` were not decompiled here, so the
  refill is unverified - tracked as Q-0025, and the remake must not clear its pet selection yet.
  `profile+0x18` is compared against the second return word of `FUN_0054B2A0()` (Ghidra
  `extraout_EDX`); the field is runtime-only (P2.13's `user%d.dat` starts at `+0x1C`).
  (3) `FUN_0054C130()` (the Time Trial/Challenge follow-up of EV-0132) is the TankScreen builder:
  `FUN_0054B4C0()`, `FUN_0054AED0()`, `screen = new(200) TankScreen` via `FUN_0052CB40`,
  `manager+0x82C = screen`, `SetRect(0,0,manager+0xC0,manager+0xC4)`, then the render list
  `[manager+0x320]` slot 0xC attach plus slot 0x30 (no tank) or 0x38 (with tank).
  (4) `FUN_0054B170(a, b)` is the banner-already-shown predicate: it returns 1 when
  `[manager+0x88C] == a && [manager+0x890] == b`. `Sexy::StoreButtonWidget` (vtable 0x5A719C) is the
  store item class; its ctor `FUN_005331A0(id, listener, data)` chains `FUN_00475090`, stores the app
  at `+0x120` and the data link at `+0xB0`, derives the three image records from `data+0x24/+0x28`
  and reads **no** profile or price field, which is why Q-0018 narrows to its five overrides
  (`0x531A30`, `0x531A60`, `0x531C30`, `0x5319B0`, `0x531A00`).

### EV-0135 - P2.12 store UI: widget slots, the stock refresh, `SOLD` and the price formatter
- Date: 2026-10-29
- Type: code trace (module decompilation + vtable/literal dumps)
- Source: `docs/evidence/p2.12-fn-531A00.json` / `.txt`, `p2.12-fn-531A30`, `p2.12-fn-531A60`,
  `p2.12-fn-5319B0`, `p2.12-fn-531C30`, `p2.12-fn-5346D0`, `p2.12-fn-52FF90`, `p2.12-fn-51A050`,
  `p2.12-fn-51A1B0`, `p2.12-fn-51A0C0`, `p2.12-fn-51A440`, `p2.12-fn-51A120`, `p2.12-fn-51A260`,
  `p2.12-fn-52BB50`, `p2.12-fn-51B9E0`, `p2.12-fn-52FEA0`, `p2.12-fn-52F0D0`, `p2.12-fn-5363D0`,
  `p2.12-fn-5372F0`, `p2.12-fn-536350`, `p2.12-fn-537290`, `p2.12-fn-519730`, `p2.12-fn-519EB0`,
  `p2.12-fn-519F70`, `p2.12-fn-52FE10`, `p2.12-fn-51B260`, `p2.12-fn-51C0B0`, `p2.12-fn-52B800`,
  `p2.12-fn-54B020`, `p2.12-fn-54B1A0`
  (all `.json` + `.txt`), vtable dumps of 0x5A719C and 0x5A1654, literals at 0x5A7CA4 and 0x5ADEC0
- Confidence: high for the slot maps, the refresh chain and the SOLD/price mechanism; the receiver
  binding of `FUN_00519730` is inferred from its fields (see note 5)
- Notes: (1) The five `StoreButtonWidget` overrides are vtable slots **22/26/44/50/51**
  (`0x531A30`, `0x531A60`, `0x531C30`, `0x5319B0`, `0x531A00`), not 21/26/41/48/49 as first guessed:
  slot 26 draws the item art by the kind at `+0x14C` (1 forwards to the child at `+0x124`, 2/4 draw
  the Bubbulator/attractor icons, 3 draws the backdrop scaled by `+0x158`, 5 draws a food-level digit
  `([+0x28]/4)%10`); slot 44 draws the price line from the string at `+0x12C` (green `0x6E,0xFA,0x6E`
  plus the `DAT_005e8c3c` icon, grey `0xCCCCCC` when the byte `+0x55` is 0, highlight
  `0xF0,0xFF,0xC1` plus a badge when `+0x58`/`+0x59`/`+0x148` is set); slots 50/51 only write
  `store+0xBA8` (`= [this+0x88]`, then `-1`) and clear `store+0xBAC`.
  (2) The kind-to-text table `FUN_0051B9E0(item+0x14C)` gives the five kinds their names: 0 "Sorry,
  this is sold out.\nCheck back tomorrow!", 1 `FUN_0051B790(FUN_00531990(0))` (the pet blurb), 2
  Bubbulator, 3 backdrop, 4 alien attractor, 5 food upgrade.
  (3) `StoreScreen` (vtable 0x5A1654) overrides slots 20 `FUN_0052FF90` (attach: `FUN_0052FEA0(0)`
  then 11 children to render-list slot 0xC), 21 `FUN_0051A050` (detach, list slot 0x10), 22
  `FUN_0051A1B0` (Update), 26/47/48 `FUN_0051A440` (empty), 30 `FUN_0051A0C0` (list slot 0x2C), 44
  `FUN_0052BB50` (Draw), 50 `FUN_0051A260`, 52 `FUN_0051A120` (MouseMove hit-test through item slot
  0x110). Update re-rolls the refresh timer `+0x1CC` (`rand%15+15` on a 1-in-7 roll, otherwise
  `rand%150+100`) and Draw paints the refresh bar `FUN_00456A00(DAT_005e8ad4,0xFF,0x121,+0x1CC)` plus
  the tooltip (frame at 0x189,0xEB,200,300 in font `DAT_005e8ea8`, text after 16 hover ticks or when
  `+0xBA0` is set, then "Thanks for shopping at\nthe Fish Emporium!").
  (4) The stock itself is rolled by `FUN_0052FEA0(extra)`: it seeds the store RNG from
  `profile+0x98 + DAT_005e8f1c + [manager+0x748] + extra`, runs `FUN_00519EB0`, `FUN_00519F70`,
  `FUN_0052FE10` and the roller `FUN_0052F0D0`, then for each of the 8 items takes the buyable branch
  `FUN_005363D0` when `profile[0xA8+i] == 0 && item+0x14C != 0` and the sold-out branch
  `FUN_005372F0` otherwise. `FUN_0052F0D0` spends the one-off unlocks first (`profile+0x90 == 0` ->
  `FUN_00537230(2,0,20000)`, `profile+0x94 == 0` -> `FUN_00537230(4,0,50000)`, `DAT_005e89dc == 0` ->
  `FUN_00537230(5,0,20000)`) and walks `profile+0x72+i` (i = 0..5) for the pet slots.
  (5) `FUN_00536350(price)` is `SetPrice`: `[item+0x128] = price`, `sprintf(buf, "%d", price)` via
  `FUN_004120C0` on `DAT_005adec0` (= `"%d"`), then `FUN_00422210` assigns it to the widget's string.
  `FUN_00537290(child, price)` installs the kind-1 slot (destroys the old child, `+0x124 = child`,
  `child+0xE0 = price`, `+0x14C = 1`) or, with `child == 0`, sets `+0x14C = 0`. `FUN_005372F0` then
  overwrites the string with the 4-character literal **`SOLD`** (`0x5A7CA4`) and clears `+0x55`, which
  is exactly the state slot 44 greys. `FUN_0051B260(flag, id)` is the random pet roll: a 76 % ordinary
  branch (`FUN_00519E00`) and otherwise a weighted table of 8 pet ids (8/9/7/10/6/0x24/0x23/0x22 with
  weights 26/25/25/10/5/3/3/3) dispatched to `FUN_004EC0F0`, `FUN_004EA7B0`, `FUN_004EF9A0`,
  `FUN_004EE530`, `FUN_004F02A0`, `FUN_004F0630`, `FUN_004F0570`, `FUN_004F01E0`. `FUN_00519730()`
  reads a kind at `+0x8C`, flags `+0x1D0`/`+0x1D1` and the tank from `FUN_00501060()`, returning
  fixed 25000/30000/40000/50000 for tanks 1-8 and a kind-based price otherwise (10000 for kinds 6 and
  0x24, 3500 for 7, 2500 for 8/9, 5000 for 10, 15000/20000 for 0x22/0x23); the decompiler loses the
  `ECX` binding at its four call sites, so the receiver is read as "the rolled pet" from its fields,
  not proven.
  (6) `FUN_005346D0(str)` is `MyLabelWidget::SetText` (assign through `FUN_00422210`, then
  `vtable[0x44]` slot 17 to relayout), so the StoreScreen's `sprintf("%d")` + `FUN_005346D0` is the
  Shell counter write, not a formatter. `FUN_0054B020()` resets `[manager+0x374]->vtable[0xC](0..4)`
  and the screen-id pair `manager+0x88C/+0x890` to -1, and `FUN_0054B1A0(a,b)` stamps that pair and
  calls `[manager+0x374]->vtable[8]`, so 0x88C/0x890 is a **current screen id pair**, not a banner
  flag - it refines the EV-0134 reading of `FUN_0054B170`. `FUN_0051C0B0(kind)` is the "is that pet
  already in the tank" test (walks `Tank+0x108`, compares `entity->type->[+0x124]` with `kind`) and
  `FUN_0052B800(kind)` builds the named pet outright (0 Rocky, 1 Ludwig, 2 Cookie, 3 Johnny V., 4
  Kilgore; `[pet+0x124] = kind`), so the roller's `FUN_0051C0B0(2) / FUN_0052B800(2)` pair is "hand out
  Cookie once, roll randomly after that".

### EV-0136 - P2.12 the remaining screens: ctor map, the click wire-up, the story mask gate
- Date: 2026-10-29
- Type: code trace (module decompilation + RTTI/vtable scan)
- Source: `docs/evidence/p2.12-vtable-inventory.txt` (derived; RTTI CompleteObjectLocator ->
  TypeDescriptor -> mangled name, plus byte-aligned vtable-immediate scan over `0x590000-0x5C8000`),
  `docs/evidence/p2.12-fn-51F498.json`/`.txt`, `p2.12-fn-520998`, `p2.12-fn-524218`, `p2.12-fn-52572F`,
  `p2.12-fn-527870`, `p2.12-fn-52A1E1`, `p2.12-fn-52DB11`, `p2.12-fn-52EECB`, `p2.12-fn-52F30B`,
  `p2.12-fn-54C220`, `p2.12-fn-517C70`, `p2.12-fn-5182A0`, `p2.12-fn-518570`, `p2.12-fn-5187D0`,
  `p2.12-fn-5289F0`, `p2.12-fn-529DD0`, `p2.12-fn-52AE40`, `p2.12-fn-52EAF0`, `p2.12-fn-51E060`,
  `p2.12-fn-517560`, `p2.12-fn-51B6C0` (all `.json` + `.txt`), `p2.12-xrefs-5A0904.json` (answered),
  `p2.12-xrefs-5A0A44.json` (empty - the negative that motivated the scan)
- Confidence: high for the ctor map, the per-screen field/button tables and the id dispatchers; medium
  for the *roles* of the `FUN_0054Axxx`/`FUN_0055xxxx` transition helpers, which are named from their
  call sites only (note 5)
- Notes:
  (1) **`xrefs` is not a general recipe.** It returned the dtor+ctor pair for `HatchScreen`'s object
  vtable (0x517959, 0x51f498) and an **empty list** for the other eight screen vtables. The ctor map
  was obtained instead from `p2.12-vtable-inventory.txt`: MSVC writes its vtable with
  `mov [reg], imm32` (`C7 xx imm32`), so a **byte-aligned** little-endian copy of the vtable VA inside
  `.text` sits exactly 2 bytes after the instruction start; two hits per class = deleting dtor
  (`0x51xxxx`) + ctor (`0x52xxxx`), one hit = a ctor that also builds an inline overlay. The rule
  reproduces the four ctors already known from the other direction (Title `0x52EB96`, GameSelector
  `0x52E0BB`, Store `0x52B321`, Tank `0x52CB83`). Full map: Hatch 0x51F450, Help 0x520950, HighScore
  0x5241D0, Interlude 0x5256E0, Pets 0x527820, SimFish 0x52F2C0, SimSetup 0x52A190, Story 0x52EE80,
  Bonus 0x52DAD0; the seven overlays have ctor-only hits inside their parent (`HatchScreenOverlay`
  0x51F6FD, `GameSelectorOverlay` 0x52E7AA, `InterludeScreenOverlay` 0x5259CD, `PetScreenOverlay`
  0x527E66, `SimFishScreenOverlay` 0x52FAD1, `StoreScreenOverlay` 0x52B7B1, `BonusScreenOverlay`
  0x52DC07).
  (2) **Every screen's `ButtonListener` slot 2 is one `(int id)` dispatcher** - Hatch `FUN_00517C70`,
  Help `FUN_005182A0`, HighScore `FUN_00518570`, Interlude `FUN_005187D0`, Pets `FUN_005289F0`,
  SimFish `FUN_00529DD0`, SimSetup `FUN_0052AE40`, Story `FUN_0052EAF0`, Bonus `FUN_0051E060`, Tank
  `FUN_0051B6C0`. Only Pets/SimFish also override slots 4/5 (hover) and only Bonus overrides slot 1
  (`FUN_00517560`, cursor + a hit test of the prize button); everything else keeps the shared no-op
  `0x46C690`. The screen flow is therefore a button table + one switch per screen - no hidden state
  machine.
  (3) **`SimSetupScreen` is the only three-vtable screen**: `ButtonListener` at `+0x88` (0x5A13C8),
  `CheckboxListener` at `+0x8C` (0x5A13D0) and the object vtable at `+0x00` (0x5A13F4), which pushes
  the manager to **`+0x90`** (all other screens keep it at `+0x8C`). Its five checkboxes are
  `FUN_00500B70(kind, checkboxListener, Tank+0x4FC..+0x500)` with the state byte at `checkbox+0x90`, and
  "Return to Tank" copies those five bytes back into the tank (kind 6 <-> `Tank+0x500`, kind 7 <->
  `+0x4FF`), setting `Tank+0x2C0 = 3000` when `Tank+0x4FE` is clear.
  (4) **`StoryScreen` reads `profile+0x7C` as a bitmask**: the ctor shifts the dword one bit at a time
  and stops after two set bits; with fewer than two it hides Previous and Next. That is the first
  instruction-level reader for the 32-bit story mask Q-0013 tracked (the mask semantics are now
  proven; the gold-trophy flag `profile+0x80` is still unwritten/unread). The page field is `+0xA4`,
  clamped to `0..0x20` (else `DAT_005e9088`), and ids 1/2 call `FUN_0052E9D0(-1)`/`(+1)`.
  (5) The transition helpers are un-named but consistent: `FUN_00552100` = main menu (Hatch, Help,
  Interlude, Pets, Story, Tank); `FUN_0054AD70`/`ADB0`/`ADF0`/`AE30`/`AE70`/`AED0`/`AF10`/`AF50`/`AF90`
  = one "close this screen" member per class, always the first call of the click handler;
  `FUN_0054AFF0` = "the tank changed" follow-up; `FUN_00538940` + `FUN_0053DB80(0)` = return into the
  running tank; `FUN_0054BD80` = the Virtual Tank screen; `FUN_0054CBF0` = continue the flow with no
  tank; `FUN_00552230` = advance the bonus/hatch stage; `FUN_00552280` = leave the hall of fame;
  `FUN_00552E50(x)` = the in-tank menu entry. Only `FUN_0054C220` is a real screen opener
  (`manager+0x834 = new HelpScreen(...)`, rect 0,0,cx,cy, pushed to render-list slot 0xC).
  (6) **`PetsScreen` confirms `profile+0x5A` is the pet selection and adds a second clear**: outside
  Virtual Tank the ctor zeroes all 24 bytes, and Continue writes them back from the buttons'
  `+0x130` flags (`profile[0x5A+i] = button+0x130`); Virtual Tank instead diffs the open-time snapshot
  `screen+0x100+i` against the buttons and calls `FUN_0053A770(id+1000)` / `FUN_00544A90(i,-1,-1,0,0)`
  to add/remove pets. Fewer than three selections outside Virtual Tank raises the app message box
  (slot 0x120, kind 0x14) "Select More Pets?" with the "3 pets"/"at least 3 pets" wording chosen by
  whether the cap `screen+0x130` is below 4.
  (7) **`manager+0x738` gains its first reader**: `BonusScreen`'s Continue handler takes the
  `FUN_00552230()` branch when `[manager+0x738] != 0` (as it does in mode 1), so the field means "a
  side screen is open". No writer was found in nine further ctors (Q-0025).
  (8) **`profile+0x72..+0x77` conflict.** The SimSetup backdrop picker writes
  `profile[0x72 + (Tank+0x3E8 - 1)] = 1`, skips unset entries while cycling and refuses to sell the
  last one ("You are not allowed to sell your only backdrop!", refund 10000), i.e. six backdrop
  ownership flags - while EV-0135 read the same six bytes as the store's pet slots. Recorded as
  Q-0026; do not derive pet ownership from that range until the roller is re-read.
  (9) Other ctors: `HelpScreen` has **8 pages** at `+0xA4` (seeded from `DAT_005e15f8`, wrapping 1..8)
  and switches between the paged and tutorial layouts on its ctor flag (the tutorial hides "Click Here
  To Continue" and, with a live tank, relabels Menu to "Back to Game"); `HighScoreScreen` writes the
  selected tab to `+0xA8` (default `DAT_005e15fc`); `InterludeScreen` seeds `DAT_005e9084 = 0` and
  `DAT_005e907C = 12*0x23 + 0x1C39`; `BonusScreen` holds seven `std::string`s at `+0xE8..+0x1B4` and
  relabels Continue to "Click for Story Time" in Challenge mode 4 with a live tank; `TankScreen`'s ids
  0-3 call `FUN_0051A710(id+1)`, id 4 calls `FUN_0054AED0() + FUN_00552E50(-1)`, id 99 goes to the main
  menu. `HatchScreen` sets `manager+0x884 = 1` on construction.

### EV-0137 - P2.12 the dialog layer: the `Sexy::Dialog` base, all 11 dialogs, 5 click handlers
- Date: 2026-10-29
- Type: code trace (module decompilation + vtable/RTTI scan + direct byte reads)
- Source: `docs/evidence/p2.12-vtable-inventory.txt`, `docs/evidence/p2.12-fn-{475C40,530920, 5309C0,
  530AE0,5302E0,476E70}.json`/`.txt` (base dialog + shared handlers),
  `p2.12-fn-{5309C0,5334D0,533A40,533D80,534740,5349D0,5355C0,535A40,535E10,536450,536C80}.json`/`.txt`
  (the dialog ctors), `p2.12-fn-{533760,531680,535430,536BD0,536990}.json`/`.txt` (the per-dialog click
  handlers and the user-list getter); call-site scan: `E8 rel32` over `.text` (`0x401000-0x5A0000`) with
  the ctor entries as targets; string reads via `[IO.File]::ReadAllBytes` at `VA - 0x400000`
- Confidence: high for the ctor map, the base-dialog layout/parameter roles, the per-dialog fields and
  the id dispatchers; medium for `FUN_00475C40`'s parameter *names* (roles are read off the stores, not
  off any symbol table)
- Notes:
  (1) **The base is `Sexy::Dialog`, and it is a 9-argument builder.** `FUN_00475C40` (0x475C40) installs
  `ButtonListener` at `+0x88` and `Dialog` over both sub-objects, creates the three `std::string`s
  (title `+0xA4` with its size at `+0xB4`, message `+0xC0`/`+0xD0`, button label `+0xDC`/`+0xEC`),
  stores the font at `+0x90`, the rect
  `(0x18,0x18,0x18,0x18)` at `+0x11C`, the byte flag at `+0x140` and the layout kind at `+0xF4`.
  Argument roles, read off the stores: `(font, colour, +0x13C, flag, title, message, buttonLabel,
  kind)`. **Kind** 1 = the built-in Yes/No pair, 2 = OK/Cancel, 3 = one custom button labelled by the
  caller's `buttonLabel`, 0 = no buttons; kinds 1/2 create two `ButtonWidget`s (0x138 bytes) with ids
  **1000/1001** through `FUN_00476EB0`, and their captions come from the localization keys
  `"DIALOG_BUTTON_YES"`/`"NO"` or `"DIALOG_BUTTON_OK"`/`"CANCEL"` through `FUN_004872F0`.
  (2) **`FUN_00530920` is the 9-argument dialog ctor every dialog calls first**: it forwards
  `(font, colour, heightOrPad, flag, title, message, buttonLabel, kind)` to `FUN_00475C40`, then
  installs the base vtables, sets `+0x150 = manager` and `+0x154 = -1`, then calls `FUN_00504060`. The
  two vtables it installs are the pair RTTI attributes to `.?AVMoneyDialog@Sexy@@`
  (0x5A5D68 ButtonListener / 0x5A5D8C object, COL at 0x5A5D64 -> TypeDescriptor 0x5E2034 -> the
  mangled name read byte-for-byte), and the *same* pair is re-installed by `FUN_005309C0`, a 0x13-byte
  body (`mov [ecx],0x5A5D8C` / `mov [ecx+0x88],0x5A5D68` / tail `jmp 0x4761A3`) that is called from the
  dialog **destructor** cluster (0x530C45, 0x530E41, 0x531499, 0x53176F, 0x531F37, 0x5322DB,
  0x5323ED, 0x532603, 0x5327C6) - i.e. the base-class sub-object ctor/dtor pair that restores the same
  vtables. There is **no `.?AVDialog@Sexy@@` locator in the module's RTTI**, so the base vtable pair
  carries the MoneyDialog name; the note records this as a naming conflict, not as "dialogs derive from
  a money dialog".
  (3) **Ctor map for all 11 dialogs** (object vtable / ctor function; parameters): `MoneyDialog`
  0x5A5D8C / - (no standalone ctor found: every writer of its vtables is the shared base helper or the
  dialog dtors, so it is never instantiated in this build); `ContinueDialog` 0x5A6A24 / `FUN_005334D0
  (manager)`; `FishNamingDialog` 0x5A6B94 / `FUN_00533A40(manager, initialName)`; `FoodDialog`
  0x5A6CF4 / `FUN_00533D80(manager)`; `NewUserDialog` 0x5A5EFC / `FUN_00534740(manager, isRename)`;
  `OptionsDialog` 0x5A6074 / `FUN_005349D0(manager, flag)`; `PetDialog` 0x5A62FC / `FUN_005355C0
  (manager)`; `RegisterDialog` 0x5A646C / `FUN_00535A40(manager)`; `ScreenSaverDialog` 0x5A65D4 /
  `FUN_00535E10(app)`; `UserDialog` 0x5A6764 / `FUN_00536450(manager, isCreateNew)`; `VirtualDialog`
  0x5A68C4 / `FUN_00536C80(manager)`. Each ctor writes its own vtables *after* calling the base, and
  each embeds its listeners directly behind the base object: ButtonListener always at `+0x88`,
  EditListener at `+0x158` (FishNaming, NewUser, Register, User), SliderListener `+0x158` +
  CheckboxListener `+0x15C` (Options), CheckboxListener `+0x158` (ScreenSaver), ListListener `+0x158` +
  EditListener `+0x15C` (User).
  (4) **The openers are one call site each** (E8 scan against the ctor entry, so these are exact):
  Continue 0x54B3E4, FishNaming 0x54C848, Food 0x54C7C9, NewUser 0x54B6F1 + 0x54B7C2, Options
  0x54C66D, Pet 0x54C741, Register 0x54E9D9, ScreenSaver 0x54FF39, User 0x54B641 + 0x54F151, Virtual
  0x54B530. All of them are the `new(398..)` + `vtable[0x124]()` measure + `vtable[0xA0](rect)` +
  `[manager]->vtable[0x12C](1, dlg)` template already recorded for the options dialog in §8 of the
  note (EV-0133).
  (5) **Only five click handlers exist** (slot 2 of each dialog's ButtonListener vtable, read from the
  module bytes): 0x530AE0 is shared by MoneyDialog, FishNaming, Food, NewUser, Pet, ScreenSaver and
  Virtual; ContinueDialog uses 0x533760, RegisterDialog 0x531680, OptionsDialog 0x535430, UserDialog
  0x536BD0. `FUN_00530AE0(id)` is a 12-byte body: `if ([this+0xCC] < [this-0x60]) FUN_00476E70(id)`,
  and `FUN_00476E70` only acts on ids **1000/1001** - it stores the id at `+0xBC` (relative to the
  listener) and notifies `[this+4]` through `vtable[1]` - so the shared handler is the auto-button
  result reporting, not a close. The two operands of the guard (`+0xCC` = object `+0x154`, the `-1`
  sentinel of note 2, and `-0x60` = object `+0x28`) are not both explained; the id is forwarded on the
  stack, which the decompiler drops.
  (6) **ContinueDialog** (`FUN_005334D0`): title "CONTINUE GAME?", message "", one custom button
  "CANCEL" (kind 3). Mode 0 adds "Continue" (id 0, `+0x158`) and "Restart Level" (id 1, `+0x15C`);
  every other mode adds "Continue"/"New Game". Click 0 = `FUN_00505880(path, mode, profile+0x44)` +
  `FUN_0047FBC0(path)` + `[manager]->vtable[0x134](dlg+0x154)`; click 1 = a nested message box of kind
  0x22 ("Restart Level?"/"New Game?" with "Are you sure that you want to restart the level?" /
  "...start a new game?"); any other id = `vtable[0x134](...)` + `FUN_00552100()` (main menu).
  (7) **OptionsDialog**: title "Options", "OK" (kind 3), then buttons Register id 0, `Help` id 1 (the
  label comes from the 4-byte string at `DAT_005a5bec`), the web link id 2 (label built by
  `FUN_004872F0` from the strings "weblinktext" and "weblink"), Back to Main Menu id 3, Check Updates
  id 4; two sliders `FUN_0046F360(colour, colour, 5/6)` at `+0x164`/`+0x168` seeded from
  `[manager]->vtable[0xE0]`/`[0xE4]`, three checkboxes `FUN_00500B70(7/8/9)` at `+0x16C/+0x170/+0x174`
  seeded from `manager+0x6A5`/`manager+0x71D`/`FUN_00489A20()`. Visibility: `manager+0x6A5` hides Check
  Updates, `manager+0x71D` hides Register, the byte at `+0x18C` hides Back to Main Menu, and the web
  button is shown only when `[widget+0xA0] != 0`. Click: 0 -> `FUN_0054E8A0` (register), 1 ->
  `FUN_0054C220(0)` (help, unpaged), 2 -> `[manager]->vtable[0x94]("http://www.popcap.com", 0)`, 3 ->
  `FUN_0054E760()` when `mode != 5 && Tank != 0 && FUN_00537BF0()` else `FUN_00552230()`, 4 ->
  `FUN_00551A70()`.
  (8) **World/account dialogs.** `UserDialog` ("WHO ARE YOU?" type-2 base; "TRANSFER SHELLS" when
  creating) builds a list widget `FUN_00470B60(0, DAT_005e8dac, +0x158)` at `+0x160`, a scrollbar
  `FUN_0046FDF0(0, list+0x88)` at `+0x168`, an edit widget at `+0x164`, "Rename" id 0 (+0x16C) and
  "Delete" id 1 (+0x170), and stores the create-new flag at `+0x174`; it hides the edit box when
  selecting and the two buttons when creating; click `FUN_00536BD0` reads the name with
  `FUN_00536990(out)` (the list's selected text, empty when `list+0xD4 < 1`) and calls `FUN_0054B770
  (name)` for id 0 / `FUN_0054F790(name)` for id 1. `NewUserDialog` ("NEW USER" / "RENAME USER",
  body "\nPlease enter your name.", label "", kind 2) embeds an EditListener at `+0x158` whose char
  filter is the derived slot 2 = 0x530D00, creates edit widget `FUN_00500AD0(0, +0x158)` at `+0x160`
  with max length 0xC at `widget+0xF0`, and the same font/rect/colour block as FishNaming.
  `RegisterDialog` ("Register Insaniquarium", body "You must obtain a registration code online and
  enter it below.", kind 2) has `+0x150 = manager`, two edit widgets at `+0x15C`/`+0x160` cross-linked
  through `+0x80/+0x84` for tab order, the link button "CLICK HERE TO GET REGISTRATION CODE" id 0 at
  `+0x164`, and click 0 = `[manager]->vtable[0x190]()` (open the registration page).
  (9) **Content dialogs.** `FoodDialog` ("FOOD SELECTOR", "CLOSE", kind 3) clears eight 24-byte
  records at `+0x160..+0x21F` {x,y,0x32,0x32,index,owned}, fills the owned bytes from `FUN_0053A3C0`
  (all eight when `Tank == 0`), centres the row at `x = 300 - count*56/2`, y = 2. `PetDialog`
  ("PRESTO CHANGE-O", "CANCEL", kind 3) clears 24 16-byte icon rects at `+0x160` and lays them out in
  three runs (7 rows of 50 px at x = 10 from y = 120, 11 columns of 52 px at y = 420, 6 more at x = 582
  counting down from 370), storing the ownership flags from `FUN_00501410(i)` at `+0x2E0..+0x2F7`.
  `FishNamingDialog` ("Name Your Fish", body = the current name, kind 2) puts the edit widget at
  `+0x160` (max length 0xC at `+0xF0`, width 0xAA at `+0xF4`), keeps the manager at `+0x15C` and 0x3039
  at `+0x164`, and its EditListener slot 2 = `FUN_005302E0`, a character filter that accepts printable
  ASCII only. `VirtualDialog` ("WELCOME TO VIRTUAL TANK!", "OK", kind 3) sets its own size
  (550x400 at `+0x38/+0x3C`), an inner rect (30,85,490,220) at `+0x15C..+0x168` and an image widget
  `FUN_00505350()` at `+0x158`. `ScreenSaverDialog` ("Screensaver", "", "", kind 2) maps six
  checkboxes ids 0-5 at `+0x15C..+0x170` to `manager+0x838`, `+0x839`, `+0x83A`, `+0x83B`, `+0x83C` and
  `+0x83E` - note the gap at `+0x83D`, which no id reads.
  (10) Bounded negatives: no instruction in the module calls the MoneyDialog vtable pair as a
  constructed object; `RegisterDialog` builds the strings "Register" and "Cancel" without the
  decompiled body using them (the call that consumes them is lost to the decompiler - recorded as open);
  the `+0x18C` byte of OptionsDialog is only *read* (hides Back to Main Menu) and its writer was not
  found; `FUN_00536990`'s receiver is the dialog object (it reads `+0x160`/`+0x174`), while the click
  handler's receiver is the listener at `+0x88`, and the decompiler does not show the adjustment.

### EV-0138 - Q-0018 closed: the store price getter prices the *prize*, and the prize kind lives at `+0x8C`
- Date: 2026-10-29
- Type: code trace (direct byte reads of the carved module; no new decompilation)
- Source: `docs\analysis\snapshots\insaniquarium-game-module.exe` read at `VA - 0x400000` - byte dumps
  of 0x519EB0-0x519F5A, 0x52F160-0x52F290, 0x52FE30-0x52FE90, 0x4EEF00-0x4EFDF0 and 0x4F02A0-0x4F0330,
  plus a `.text` scan (0x4E0000-0x501000) for `C7 86 8C 00 00 00 <imm32>`; class names from
  `docs/evidence/p2.12-vtable-inventory.txt` (rows `.?AVFish@Sexy@@` 0x00597D54, `.?AVOscar@Sexy@@`
  0x0059843C); decompiled bodies `p2.12-fn-519EB0/519730/51B260/52F0D0/52FE10.txt`
- Confidence: high - the register trace, the per-class kind writer and the switch domain agree, and no
  single one of them is load-bearing on its own
- Notes:
  (1) **Every call site sets `ECX` from the object it just built.** `FUN_00519EB0` keeps its `this` in
  EBX (`mov ebx, ecx` at 0x519ED7), allocates two 0x230-byte objects and captures them with
  `mov edi, eax` (after `FUN_004EEF00`) and `mov esi, eax` (after `FUN_004EFDA0`); then at 0x519F32
  `8B CF` (`mov ecx, edi`) -> `call 0x519730` at 0x519F36 -> `push eax; push edi; call 0x547290`
  (`FUN_00537290`), and at 0x519F48 `mov ecx, esi` -> `call 0x519730` at 0x519F4A -> same wiring with
  ESI. The roller `FUN_0052F0D0` does the same after its factory calls (`mov edi, eax` then `mov ecx,
  edi` at 0x52F19D, `call` at 0x52F1A0; second roll at 0x52F27B/0x52F27E), and `FUN_0052FE10` with EBX
  (0x52FE61/0x52FE66) and EDI (0x52FE77/0x52FE7A). The decompiler's bare `FUN_00519730()` is therefore
  a thiscall on the newly constructed object, **not** on the store item.
  (2) **Those objects are prize fish.** `FUN_004EEF00` installs vtable 0x597D54 = `.?AVFish@Sexy@@`
  (`C7 06 54 7D 59 00` at 0x4EEF3D) and `FUN_004EFDA0` installs 0x59843C = `.?AVOscar@Sexy@@`
  (`C7 06 3C 84 59 00` at 0x4EFDE0), i.e. the icon children of a kind-1 slot are fish objects, and the
  roller's factory returns the same family.
  (3) **`+0x8C` is the prize kind, and each class writes it itself.** The scan finds one
  `mov dword [esi+0x8C], <kind>` per factory class, each in the tail of the function that precedes that
  class's ctor: 0x4EA70E = 9 (before `FUN_004EA7B0`), 0x4EC04E = 8 (before `FUN_004EC0F0`), 0x4EE512 =
  0xA (before `FUN_004EE530`), 0x4EF97E = 7 (before `FUN_004EF9A0`), 0x4EFD8E = 5 (before the Oscar ctor
  `FUN_004EFDA0`), 0x4F01BE = 0x22, 0x4F027E = 6, 0x4F055E = 0x23, 0x4F061C = 0x24 (each before the
  matching `FUN_004F01E0`/`FUN_004F02A0`/`FUN_004F0570`/`FUN_004F0630`). Those values are exactly the ids
  of `FUN_0051B260`'s weighted table (8/9/7/10/6/0x24/0x23/0x22) and exactly the cases of
  `FUN_00519730`'s switch (0, 5, 6, 7, 8, 9, 10, 0x22, 0x23, 0x24).
  (4) So a kind-1 slot's price is a property of the prize rolled - `25000/30000/40000/50000` flat for
  the tank index 1/2/4/5, 0/3/6, 7 and 8 from `FUN_00501060()`, and only for 9 the kind table (10000 for
  6/0x24, 3500 for 7, 2500 for 8/9, 5000 for 10, 15000/20000 for 0x22/0x23, 25/500/2500 for kind 0,
  100 default) rounded down to a multiple of 5 with a 10 floor. Re-bind the index when P2.13 names
  `FUN_00501060`.
  (5) Bounded negatives: no writer of `prize+0x1D0`/`+0x1D1` was located (the getter reads them as two
  variant bytes: kind 0 is 25 when `+0x1D0 == 0`, else 500 or 2500 with `+0x1D1`; kind 5 is 1000 or
  5000, and falls back to 100 when `+0x1D0 == 0`); the `+0x8C` writers sit in 0x0A-0xA2-byte stubs that
  were not decompiled, so they are cited by address only.

### EV-0139 - Dialog wiring closed: the edit filter is slot 2, and `RegisterDialog` relabels the built-in buttons
- Date: 2026-10-29
- Type: code trace (direct byte reads of the carved module + three new decompiles)
- Source: byte dumps of 0x535B3C-0x535B9F, 0x53675A, 0x4D5350, 0x519120, 0x530CE0 and 0x532240; the
  vtable dwords at 0x5A5D54, 0x5A5EC8, 0x5A6B60, 0x5A6438, 0x5A6720, 0x5A6710, 0x5A6038, 0x5A13C0;
  strings 0x59D880 "Register", 0x5AF930 "Login", 0x5AF938 "Cancel" and `DAT_005ae104` "0";
  decompiled bodies `p2.12-fn-530D00.txt`, `p2.12-fn-532260.txt`, `p2.12-fn-536450.txt`,
  `p2.12-fn-535A40.txt`
- Confidence: high for (1)-(5) - each is a byte-level or decompiled fact; medium for the slot-2
  dispatch itself, see (6)
- Notes:
  (1) **`RegisterDialog` relabels the base's two auto buttons.** The calls that read as orphaned in
  `FUN_00535A40` are `std::string::assign` on the button labels: 0x535B49 `mov ecx,[esi+0x94]`,
  0x535B58 `push 8`, 0x535B5A `add ecx,0x8C`, 0x535B60 `push 0x59D880` ("Register"), `call 0x426BE0`
  at 0x535B87; then 0x535B8C `mov ecx,[esi+0x98]`, 0x535B92 `push 6`, 0x535B94 `add ecx,0x8C`,
  0x535B9A `push 0x5AF938` ("Cancel"), `call 0x426BE0` at 0x535B9F. So a `kind`-2 RegisterDialog
  reads **Register / Cancel**, and `+0x94`/`+0x98` now have a *consumer*, not just the base's writers.
  (2) **`NewUserDialog`'s filter is `isalnum(c) || c == ' '`.** `FUN_00530D00` is a two-line body
  (`_isalnum(c)` or a space -> 1, else 0), installed at slot 2 of 0x5A5EC8 (dword at 0x5A5ED0). New
  user names therefore admit letters, digits and spaces only.
  (3) **`UserDialog`'s filter is `isdigit(c)` only** (`FUN_00532260`, slot 2 of 0x5A6720 at 0x5A6728),
  and its edit widget is seeded with the one-character string `"0"`: at 0x53675A `push 1; push
  0x5AE104` builds the string (`DAT_005ae104` = "0") and the widget at `[dialog+0x164]` then gets it
  through vtable `+0x124`. A digits-only, `"0"`-seeded field does not look like a name entry - open,
  see (6).
  (4) **The character filter is slot 2 of the edit listener, and the default is "accept".** The base
  `EditListener` table (0x5A5D54) holds 4 slots: `0x519120` = `ret 8`, then `0x4D5350` x3, and
  `0x4D5350` is `B0 01 C2 08 00` = `mov al,1; ret 8`. Every dialog's derived table replaces slot 0 with
  a text-change forwarder and slot 2 with the predicate above. No slot is a destructor: `ret 8` pops
  two dwords, which fits a `(int id, char c)` callback and not a `this`-only dtor. The sibling bases
  are `ListListener` 0x5A6710 (3 slots: 0x531E70, 0x51A440, 0x531E70), `SliderListener` 0x5A6038
  (1 slot: 0x531E70) and `CheckboxListener` 0x5A13C0 (1 slot: the `ret 8` stub).
  (5) **Two listener addresses in the note's ctor map were wrong and are now fixed.** `RegisterDialog`
  installs ButtonListener **0x5A644C** at 0x535B71 (`C7 86 88 00 00 00 4C 64 5A 00`; 0x5A6454 is the
  next dword and was a transcription slip), and OptionsDialog installs the **Slider 0x5A6048** at
  `+0x158` and the **Checkbox 0x5A6040** at `+0x15C` - the pair had been swapped. Both were re-derived
  by scanning each ctor body for `mov [reg+disp], imm32` stores with a 0x5A0000-0x5A9000 immediate.
  (6) Bounded negatives: a `.text` scan finds **no** `E8` call to any of the three filters and only 20
  `call [reg+disp8]`-style slot-2 sites in the whole module, none with a nearby character argument, so
  the "the edit widget feeds the typed character into slot 2" step is inferred from the default-accept
  stub plus three `ctype` predicates rather than observed at a call site. `UserDialog`'s digits-only
  box is unexplained for the same reason: the rename path's name comes from `FUN_00536990`, whose
  receiver is its own open question, so whether that box is a name field is not settled.

### EV-0140 - `FUN_00536A40` is `UserDialog`'s draw override: the digits-only box is the shells transfer amount
- Date: 2026-10-29
- Type: code trace (one new decompile + byte reads of the ctor, the draw override and three vtables)
- Source: `p2.12-fn-536A40.txt` (new), re-reads of `p2.12-fn-536450.txt`, `p2.12-fn-536990.txt`,
  `p2.12-fn-536BD0.txt`, `p2.12-fn-54B770.txt`, `p2.12-fn-54F790.txt`; byte dumps 0x53658C-0x5365DA,
  0x536B20-0x536BB0, 0x5A6710-0x5A6790, 0x509848-0x509860, 0x522BC0-0x522BFF and the module dword at
  0x5E8B74
- Confidence: high - ctor, draw override and both action helpers are decompiled, and every frame/slot
  claim below is a byte read
- Notes:
  (1) **The ctor confirms the §11.2 field map, and visibility is mode-based.** `FUN_00536450` indexes
  the dialog object as `in_ECX[0x56..0x5d]` = `+0x158..+0x174`. The stores are 0x53658E
  `[+0x158] = 0x5A6710`, 0x536598 `[+0x15C] = 0x5A5D54`, 0x5365BA `[+0] = 0x5A6764`, 0x5365C0
  `[+0x88] = 0x5A6744`, 0x5365CA `[+0x158] = 0x5A6734`, 0x5365D0 `[+0x15C] = 0x5A6720` and 0x5365DA
  `[+0x174] = param_2`. At the end of the ctor the scrollbar hides while
  `[manager+0x8b0]+0xC < 8` users exist, then `param_2 == 0` hides the **edit widget**
  (`+0x164`->`vtable[0x7C](0)`) while `param_2 != 0` hides **Rename and Delete**. The draft note's
  "selecting hides the edit box" was wrong: it is the mode, not the selection.
  (2) **Rows.** `param_2 == 0` adds "(Create a New User)" (19 chars) first; when `[manager+0x8b8]`
  (current user) is set, its name (`+0x24`) is added through `list->vtable[0x124]` and the result is
  passed to `list->vtable[0x14C]` (read as "select that row"; that slot is inferred, not decompiled).
  The remaining users come from `[manager+0x8b0]`, each node's name at `+0x54`, skipping the one that
  compares equal to the current name.
  (3) **`FUN_00536A40` is the draw override and only draws the box in transfer mode.** It calls the
  base draw `FUN_00476710(g)` and, only when `[+0x174] != 0`, draws "Transfer Shells to User" (0x17
  chars), "Transfer Amount" (0xF chars) at `y = editY - dialogY + 0x11`, a caption at
  `(editX - dialogX - 0x23, editY - dialogY + 3)` through `FUN_00455D20` from the global at 0x5E8B74,
  and finally the widget itself `FUN_00503470(g, [+0x164])`. The three `[dialog+0x164]` reads
  (0x536B29, 0x536B6F, 0x536BA4) all sit in this function, which starts at 0x536A40
  (`55 8B EC 6A FF 68 C0 8D 58 00`), so the digits-only, `"0"`-seeded box is the transfer amount and
  not a name field.
  (4) **Rename and Delete read the highlighted row.** `FUN_00536990` returns
  `list->vtable[0x120](out, [list+0xD4])` after a bound check against `list->vtable[0x12C]()`, and
  guards `[+0x174] == 0 && [list+0xD4] < 1` to an empty string - so in picker mode row 0 (the
  "(Create a New User)" placeholder) can never be renamed or deleted. `FUN_00536BD0` then calls
  `FUN_0054B770(name)` for id 0 - close 0x1B, `FUN_00564345(0x164)`, `FUN_00534740(manager, 1)`
  (NewUserDialog with `isRename = 1`), `vtable[0x124](400)` measure, centred `vtable[0xA0]` rect,
  `FUN_00532820(name)` prefill, push as id 0x1B - and `FUN_0054F790(name)` for id 1 - close 0x1A,
  build "Are You Sure?" (0xD) plus "This will permanently remove '%s' from the player roster!",
  `vtable[0x120](0x1A, 1, message, formatted, title, 1)`. Names therefore come from `NewUserDialog`
  (alnum + space, 12 characters), never from this box.
  (5) **Derived listener tables** (dwords; each table is followed by its COL pointer): base
  ListListener 0x5A6710 = (0x531E70, 0x51A440, 0x531E70); `UserDialog`'s list listener 0x5A6734 =
  (0x5321E0, 0x51A440, 0x531E70); `UserDialog`'s edit listener 0x5A6720 = (0x532240, 0x4D5350,
  0x532260, 0x4D5350), with slot 2 still the `isdigit` predicate of EV-0139. The two base list bodies
  are stubs - 0x531E70 = `C2 0C 00` (`ret 0xC`), 0x51A440 = `C2 04 00` (`ret 4`) - so a row click has
  no callback and the dialog reads `[list+0xD4]` on demand.
  (6) Bounded negative: the caption text behind 0x5E8B74 is not statically readable. The global is 0
  in the file image and is filled at runtime (0x509852 `A3 74 8B 5E 00` = `mov [0x5E8B74],eax` right
  after a call), with a reader at 0x522BD9 that also dereferences it.

### EV-0141 - Q-0026 settled: `profile+0x72..+0x77` are the six backdrop flags, and the store sells one unowned backdrop for 15000
- Date: 2026-10-29
- Type: code trace (byte-level decode of the stock roller's dropped blocks + the save-field map)
- Source: byte dumps 0x52F1D4-0x52F2A6 and 0x52F206-0x52F2B6 of `FUN_0052F0D0`; `p2.12-fn-52F0D0.txt`
  (the blocks are dropped there as "unreachable": ram 0x52F20E/0x52F218/0x52F233/0x52F238/0x52F297);
  `docs/analysis/notes/p2.13-saves.md` field table (rows `0x3A..0x51` and `0x52..0x57`), the real and
  GameBanana samples, and the SimSetup picker of EV-0136
- Confidence: high - the store's own code names the kind (3) and the price (0x3A98), and the save map
  independently puts pet ownership elsewhere
- Notes:
  (1) **The roller's candidate list is a `std::vector<int>` of indexes 0..5.** 0x52F1DB `lea
  ecx,[esi+0x1D0]` + call 0x40AEB0 is the store RNG; 0x52F1F0/0x52F1F3 `lea edx,[ebp-0x10]` (the loop
  index), `lea ecx,[ebp-0x20]` (the vector) and the call at 0x52F1F7 push the index when
  `profile[0x72+i] == 0` (with the extra `rand%5 == 0` gate on `i == 5`).
  (2) **After the loop it consumes the vector and buys a backdrop.** 0x52F206-0x52F215: `begin`, `end`,
  `count = (end-begin)/4`, skip when 0; 0x52F217-0x52F227 seeds the roll with the cached 64-bit store
  time (`+0xB98`/`+0xB9C`) and the count; 0x52F237-0x52F23A `mov eax,[edx+ebx*4]` reads the chosen
  candidate; 0x52F23D-0x52F24B `mov ecx,[esi+0xB8]`, `push 0x3A98`, `push eax`, `push 3`, call
  `FUN_00537230` - i.e. **kind 3, that backdrop index, price 15000**, the same setter the one-off
  unlocks use (`FUN_00537230(2,0,20000)`, `(4,0,50000)`, `(5,0,20000)`). Kind 3 is the backdrop kind
  of the store map (§6), so the six bytes are backdrop ownership.
  (3) **Fallback.** With no clear flag left (all six owned) the same slot rolls
  `FUN_0051B260(1,-1,9)` - a random pet - which is why the range also looked like a pet list.
  (4) **Independent confirmation from the save map.** Pet ownership is the 24-byte flag array at
  `profile+0x00..+0x17` (save `0x3A..0x51`, read by `FUN_00501410` for the PetDialog), and pet
  *selection* is the 24 bytes at `profile+0x5A..+0x71` that the PetsScreen ctor clears. The six bytes
  at `profile+0x72..+0x77` are save `0x52..0x57`, `01 00 00 00 00 00` in the real sample and all `01` in
  the maxed GameBanana one - exactly "one default backdrop owned" versus "all six bought", matching
  the picker's "not allowed to sell your only backdrop" rule.
  (5) The wall-clock store seed is `profile+0x98` (`FUN_0040AE50(profile[0x98] + t)`), and the roller's
  one-off unlock gates remain `profile+0x90` / `+0x94`.

### EV-0142 - P2.13: the tank save is one file per game mode (`adv`/`tim`/`snd`/`sur`/`sim`)
- Date: 2026-10-29
- Type: code trace (module decompilation + byte decode of the string ladder and the IAT slot)
- Source: `docs/evidence/p2.13-fn-505880.json` / `.txt` (`FUN_00505880`), `p2.13-fn-42D4E0.json` / `.txt`
  (the string assign), `p2.13-fn-5497A0.json` / `.txt` (`FUN_005497A0`, save), `p2.13-fn-5059D0.json` /
  `.txt` (`FUN_005059D0`, delete-all), `p2.11-fn-54CB20.txt` (load), `p2.12-fn-533760.txt` (Continue);
  byte dumps 0x105880-0x105B10 (code), 0x19D5C0-0x19D5FF (strings), 0x7FBC0-0x7FC00 (`DeleteFileA`)
- Confidence: high for the prefix table, the callers and the file lifecycle; the `[app+0x511]` gate and
  the intent of the Continue branch stay open
- Notes:
  (1) **`FUN_00505880(out, mode, slot)` builds the tank-save path.** The mode ladder (byte-decoded at
  0x5058A5-0x5058E1, confirmed by the decompile): `mode == 5` -> 0x59D608 `sim`, `== 1` -> 0x59D604
  `tim`, `== 4` -> 0x59D600 `sur`, `== 3` -> 0x59D5FC `snd`, everything else (0, 2) -> 0x59D5F8 `adv`.
  The prefix feeds `FUN_004120C0(tmp, "userdata\\%s%d.dat", prefix, slot)` and the result is assigned
  into the caller's `std::string` by `FUN_0042D4E0` (a two-operand string assign: `FUN_00422210` on the
  first, `FUN_004269F0` on the second, then capacity `+0x18 = 0xF`).
  (2) **The literals sit back to back.** `userdata\%s%d.dat` starts at 0x59D5E4 and the five 3-byte
  prefixes follow at 0x59D5F8 (`adv`), 0x59D5FC (`snd`), 0x59D600 (`sur`), 0x59D604 (`tim`), 0x59D608
  (`sim`). Each prefix is referenced exactly once in the module (dword scan: 0x5058B5 `sim`, 0x5058C1
  `tim`, 0x5058CD `sur`, 0x5058D7 `snd`, 0x5058DE `adv`) and the format string once (0x5058EB), so this
  is the only tank-save name builder.
  (3) **`mode` is the game-mode field.** Every non-test caller passes `[manager+0x87C]`, the mode of
  EV-0126 (0 Adventure, 1 Time Trial, 3 Sandbox, 4 Challenge, 5 Virtual Tank; 2 unobserved). The tank
  save is therefore per mode, one file each, all written by the same `FUN_00546990`/`FUN_00546AA0` pair
  (EV-0044). `sim%d.dat` is the **Virtual Tank** save; mode 2 would also land in `adv%d.dat`.
  (4) **`slot` is `[profile+0x44]`.** It is the `%d` of all three name families - `userdata\%s%d.dat`,
  `userdata/scr%d.dat` and `userdata/user%d.dat` - so it is the profile's save-slot number, not a
  Virtual-Tank-specific field. This corrects the wording of EV-0126 note (3) ("`profile+0x44` is
  therefore the VT tank slot"): the field is shared, the *file type* comes from the mode.
  (5) **Call sites** (E8 scan): 0x505B49 in `FUN_005059D0` (mode hard-coded 0), 0x5337B4 in
  `FUN_00533760` (ContinueDialog), 0x5497E7 in `FUN_005497A0` (save), 0x54CB65 in `FUN_0054CB20` (load),
  0x5524E1 in `FUN_00552480`. Save chain: `FUN_005497A0` builds the path, then on `FUN_00537BF0()`
  false calls `FUN_0047FBC0(path)`, else `FUN_00411BC0("userdata")` (create directory) and
  `FUN_00546990(path)` = SaveGame (version 0x36, tank body, `__time64`). Load chain: `FUN_0054CB20` ->
  path -> `FUN_00546AA0(path)` = LoadGame (EV-0126 note 3).
  (6) **`FUN_0047FBC0` is a `DeleteFileA` wrapper.** 0x47FBC0: `80 B9 11 05 00 00 00` `cmp byte
  [ecx+0x511],0`, `74 05` (equal -> `B0 01 C2 04 00` = return 1), else it pushes the `std::string`
  buffer (`[string+4]` once capacity `>= 0x10`) and calls the IAT slot 0x59612C, which resolves to
  `DeleteFileA`; the `neg/sbb/neg` epilogue returns "success != 0". `FUN_005059D0` is the matching
  delete-all routine: it removes `userdata/user<N>.dat`, `userdata/scr<N>.dat` and then loops
  `i = 0..5` through `FUN_00505880(slot)`, i.e. all six mode files of profile `<N>` - independent proof
  that all six kind values are used.
  (7) **Samples line up.** The local `adv1.dat` is mode 0 / slot 1 (tank 1, level 1, 1081 bytes, the
  tutorial string at 0x184); the GameBanana `sim1.dat` is mode 5 / slot 1 (tank 1, level 5, 11800
  bytes). Both start with version `0x36`, so the size gap is content (a populated Virtual Tank), not a
  second format. That pack has no `adv1.dat`.
  (8) Bounded negative: the `[app+0x511]` delete gate is unbound (a "no disk writes" flag reading as
  "pretend success"), and the id-0 branch of `FUN_00533760` deletes the current mode's file *before*
  `[manager]->vtable[0x134](this+0xB4)`, whose meaning is still P2.12's open "start session" call.

### EV-0143 - Q-0019 settled: `scr%d.dat` is the bonus-shells escrow - 102 raw dwords gated by `profile+0x88`
- Date: 2026-10-29
- Type: code trace (decompilation of the reader/writer/SaveGame plus a byte-level decode of the reader's
  return path and of the save-side flush)
- Source: `docs/evidence/p2.13-fn-5148C0.json`/`.txt` (reader), `p2.13-fn-515910.json`/`.txt` (writer),
  `p2.13-fn-47F5D0.json`/`.txt` (whole-file loader), `p2.13-fn-546990.json`/`.txt` (SaveGame),
  `p2.13-fn-546AA0.json`/`.txt` (LoadGame), `p2.13-fn-500340`, `p2.13-fn-5004E0`, `p2.13-fn-5030F0`,
  `p2.13-fn-513E30`/`p2.13-fn-513EE0` (the two `DataSync` ctors), `p2.13-fn-40F9E0` (the token RNG),
  `p2.13-caller-552167.json`/`.txt` (`FUN_00552100`); `p2.13-dump-514AE4-5469B0.txt` (byte dumps of the
  cash-in function 0x514AE4-0x514B70 and of SaveGame's 0x5469B0-0x546A6C); E8 scans for 0x5148C0,
  0x515910, 0x514B00, 0x501200 and 0x40F9E0
- Confidence: high for the layout, the token gate, the return value and the four cash-in sites; the
  intent of the demo/registered gate stays open
- Notes:
  (1) **The file is 102 raw dwords - no header, no cipher.** `FUN_00515910(delta)` writes
  `[profile+0x88]`, 50 x `_rand() % 20000`, `old + delta`, 50 x `_rand() % 20000`, i.e.
  4 + 50*4 + 4 + 50*4 = **0x198 = 408 bytes**. The helpers are plain: `FUN_00500340()` is
  `FUN_00500290(&v,4)` (raw dword read), `FUN_005004E0(v)` is `FUN_00500480(&v,4)` (raw dword write),
  and `FUN_005030F0(0x20)` is the buffer reset `if (n < 0x20) n = 0x20; [this+0x10] = n; [this+8] =
  alloc(n)` - every save writer calls it with 0x20 (user `FUN_00514730`, tank `FUN_00546990`, scr), so
  it is a growth hint, not a version. The only structured reader, `FUN_00513E30`, is a
  `Sexy::DataSync` constructor (`*ecx = Sexy::DataSync::vftable`, two sentinel lists, `[ecx+1] =
  param_1`) and the scr writer never constructs one: the escrow carries no DataSync header.
  (2) **The reader returns the payload; a token mismatch yields 0.** `FUN_005148C0(consume)` reads
  dword 0 and compares it with `[profile+0x88]` (`cmp eax,[edi+0x88]`, `je` to the read loops); on a
  match it skips 50 dwords, reads one into EDI, skips 50 more, and returns EDI (`mov eax,edi`); every
  other exit runs `xor eax,eax`. The epilogue is `mov esp,ebp; pop ebp; ret 4` (one stack argument),
  so the stored value is dword **index 51 = file offset 0xCC** and a stale/moved file reads as 0
  instead of being added - the token check is what makes a copied `scr%d.dat` worthless on another
  slot.
  (3) **`consume != 0` deletes the file** right after a successful read (`FUN_0047FBC0`, the
  `DeleteFileA` wrapper of EV-0142 note 6), so the read is destructive by design; the writer's own
  `FUN_005148C0(0)` call is the non-destructive variant.
  (4) **Who fills it: `FUN_00546990` (SaveGame).** After `FUN_0047F310` has written the tank file the
  body runs `if (thunk_FUN_00479FC0()) { FUN_00515910(*(this + 0x400)); *(this + 0x400) = 0; }`
  (byte-decoded 0x546A47-0x546A6C: `test al,al` / `je`, `mov edx,[esi+0x400]`, `mov eax,[esi+0x8C]`,
  `mov ecx,[eax+0x8B8]` = profile, `push edx`, call 0x515910). `this` is the tank - the same function
  writes `Tank+0x4EE`/`+0x118`/`+0x438`/`+0x2A6` on the load side - so the flushed value is the
  bonus-round shell counter `Tank+0x400` of EV-0073 and the save leaves it at 0.
  (5) **Who empties it: `FUN_00514B00`.** `v = FUN_005148C0(1)`, clamp `v > 100000 -> 100000`, return
  when `v <= 0`, else `FUN_00501200(v)` (add Shells, `profile+0x48`, EV-0065), `profile+0x88 =
  FUN_0040F9E0()`, then a tail jump into `FUN_00514730` (the `user%d.dat` save). Four E8 sites land on
  its entry: 0x546AEE in `FUN_00546AA0` (LoadGame, taken when `thunk_FUN_00479FC0()` is **false**),
  0x54BCED in `FUN_0054BCA0` (pre-bonus store screen), 0x54BFB4 in `FUN_0054BF60` (BonusScreen
  opener) and 0x552167 in `FUN_00552100` (session setup, gated on `this[0x22E]` = `manager+0x8B8`,
  the profile pointer).
  (6) **Correction of EV-0069.** EV-0069 note (2) read this as "stores now at `this+0x88`" and called
  the stored dword a bonus timestamp. The callee at 0x514B24 is `FUN_0040F9E0`, a two-instruction
  thunk (`FUN_0040AEB0(); return;`) onto the module's `rand32` helper - the same one the backdrop
  roller calls (EV-0141) - and what the profile reset seeds `+0x98/+0x88` with (EV-0063).
  `profile+0x88` is therefore a full 32-bit **random token**: regenerated at every cash-in,
  serialized as the trailing dword of `user%d.dat`, and the key the escrow must match. The escrowed
  number is likewise a shell amount, not a time.
  (7) Bounded negative: the two branches around `thunk_FUN_00479FC0()` (the demo/registered check of
  `p2.5-economy.md`) are measured - the full version banks `Tank+0x400` at save, the demo cashes the
  escrow at load - but why they differ is not established from the code. `FUN_00513EE0` is the second
  `DataSync` ctor (the same body as `FUN_00513E30`, storing its argument at `+0x08` instead of
  `+0x04`), so no escrow writer ever builds one - the file is header-less by construction.

### EV-0144 - P2.13: the tank-save body end to end - order, field meanings, both-sample values, P4 model
- Date: 2026-11-01
- Type: code trace (module decompilation of the body serializer, SaveGame/LoadGame, the level init, the
  overlay/optional-object serializers, the entity-enable writer, the store-item builder and the backdrop
  tint) + byte decode (forward parse of both samples against that order)
- Source: `docs/evidence/p2.13-decompile-546240.txt`/`.json` (`FUN_00546240`, the body),
  `p2.13-fn-546990.txt` (SaveGame `FUN_00546990`), `p2.13-fn-546AA0.txt` (LoadGame `FUN_00546AA0`),
  `p2.13-decompile-541A20.txt` (level init `FUN_00541A20`), `p2.13-decompile-530780.txt` (overlay
  `FUN_00530780`), `p2.13-decompile-505860.txt` + `p2.13-decompile-504010.txt` (string sync),
  `p2.13-decompile-5387F0.txt` (optional `Tank+0x110` object), `p2.13-decompile-539AD0.json` and
  `p2.13-decompile-539C90.json` (`Tank+0x2A6`), `p2.13-decompile-5409B0.txt` (store-item build),
  `p2.13-decompile-547610.txt` (tank update: VT wave gate, egg hint, `+0x2A7`), `p2.13-decompile-537D30.json`
  (backdrop tint), `p2.13-decompile-503010/503040/503070.json` (the sync helpers),
  `p2.13-forward-tank-parse.txt` (authoritative forward parse of both files); samples
  `docs/analysis/inputs/p2.13-saves-2026-10-21/adv1.dat` (1081 bytes) and
  `docs/analysis/inputs/p2.13-saves-gamebanana-100/sim1.dat` (11800 bytes); field bindings from EV-0044,
  EV-0063, EV-0073, EV-0089, EV-0090, EV-0127, EV-0136
- Confidence: high for the order, the sizes, the file offsets and the values; medium for the intent of
  `+0x2A6`, `+0x2C4/+0x2C8` and the overlay tail; residual unknowns are bounded in note (7)
- Notes:
  (1) **One body function, both directions.** `FUN_00546990` (SaveGame) resets the stream
  (`FUN_005030F0(0x20)`, a growth hint not a version), constructs the `DataSync` (`FUN_00513EE0`), writes
  dword version `0x36` (`FUN_005004E0`), calls `FUN_00546240` for the body, appends the low dword of
  `__time64`, then flushes (`FUN_00512310` + `FUN_0047F310`). `FUN_00546AA0` (LoadGame) reads the whole file
  into a string (`FUN_0047F5D0`), builds the same stream, reads the version and rejects `<= 0x34`, calls the
  same `FUN_00546240`, reads the timestamp and rebuilds the scene. Direction is `[stream+4]`: 0 writes,
  nonzero reads. The helpers are dword `FUN_00503010`, byte `FUN_00503070`, color `FUN_005036A0` (four
  `FUN_00503040` byte syncs, i.e. r,g,b,a) and string `FUN_00505860` (u16 length + chars,
  `FUN_00500480`). On a read in mode 0 the body also refuses a save whose tank/level do not match
  `profile+0x1C/+0x20` (returns 0, so LoadGame falls through to a fresh tank).
  (2) **The body order (file offsets).** `E` = entity-stream bytes, `S` = overlay string bytes. The entity
  stream starts at 0x12; after it the pet array starts at **42 + E + S**, the store array at
  **454 + E + S**, the timestamp at **658 + E + S**, and the file ends at **662 + E + S** plus the
  stream's spare capacity (8 bytes in `adv1`, 160 in `sim1` - zeroes after the timestamp that the loader
  never reads).

  | # | Field (type) | Meaning / evidence | adv1 / sim1 |
  | --- | --- | --- | --- |
  | 1 | `+0x3C8` u32 | tank index | 1 / 1 |
  | 2 | `+0x3CC` u32 | level; written as 5 for every non-Adventure mode (`FUN_00541A20`) | 1 / 5 |
  | 3 | `+0x2A5` u8 | tank-complete latch (set by the finalizer `FUN_00537E20`) | 0 / 0 |
  | 4 | `+0x2A6` u8 | tank-wide entity-enable latch (`FUN_00539AD0`, see note 3) | 1 / 1 |
  | 5 | u32 count | entities that follow | 2 / 39 |
  | 6 | entities | each u32 class id + the object's slot 0x140 `Serialize`; type `0x1F` is skipped | 362 / 10946 B |
  | 7 | `+0x110` object | u8 presence + object (`FUN_005387F0`; alloc 0x208, bare ctor `FUN_004ECF80`) | absent / absent |
  | 8 | overlay `+0x118` | string (`+0x8C`, u16 + chars), color `+0xA8`, color `+0xB8`, dword `+0xC8`, dword `+0xD0`, byte `+0xD4`, dword `+0xD8` (`FUN_00530780`) | text 49 B / 32 B |
  | 9 | 24 x u32 `+0x144..+0x1A0` | **per-pet presence**, index = pet id 0..23 | all 0 / all 1 |
  | 10 | `+0x2A4` u8 | bonus round active | 0 / 0 |
  | 11 | `+0x2A8` u32 | tick anchor of the bonus start | 0 / 0 |
  | 12 | `+0x2BC` u32 | alien type for the next wave | 0 / 6 |
  | 13 | `+0x2C0` u32 | alien countdown (3000 at wave start) | 3000 / 1518 |
  | 14 | `+0x2C4` u32 | timer set to 35 by the wave-0 block; consumer unread | 0 / 0 |
  | 15 | `+0x2C8` u32 | timer set to 36 by `FUN_00539C90` (hostiles clear); consumer unread | 0 / 0 |
  | 16 | `+0x2CC..+0x2D8` 4 x u32 | alien spawn points x1,y1,x2,y2 (rolled at countdown 275) | 0,0,0,0 / 228,140,271,291 |
  | 17 | `+0x2DC` u32 | count of store entries whose slot id is >= 0 (computed in `FUN_00541A20`) | 2 / 6 |
  | 18 | `+0x3B0..+0x3BC` 4 x u32 | elapsed seconds (bonus-freeze value), bonus time base x2, bonus countdown | 0,0,0,0 / 0,0,0,0 |
  | 19 | `+0x3C0` / `+0x3C4` u32 | last feed / last fire wall-clock stamp (`FUN_00537B60`) | 1540,0 / 6713084,6628468 |
  | 20 | `+0x3E4` u32 | pet capacity (2 base, 8 demo, boss sets 10) | 2 / 8 |
  | 21 | `+0x3E8` u32 | backdrop index; `+0x3EC` is a live override, never saved | 1 / 1 |
  | 22 | `+0x3F0` u32 | money | 190 / 200 |
  | 23 | `+0x3F4` u32 | bonus-round shells | 0 / 0 |
  | 24 | `+0x3F8` u32 | bonus end delay counter (P2.6/E2.6) | 0 / 0 |
  | 25 | `+0x3FC` u32 | elapsed seconds | 0 / 0 |
  | 26 | `+0x2AC` i32 | unknown; finalizer writes -1 | -1 / -1 |
  | 27 | `+0x2B0` u32 | unknown; finalizer writes 0 | 0 / 0 |
  | 28 | `+0x43C` u32 | egg pieces / progress (starts at 1) | 1 / 1 |
  | 29 | `+0x440` u8 | unknown; cleared by the finalizer | 0 / 0 |
  | 30 | `+0x444..+0x4AC` 27 x u32 | see note (4) | see note (4) |
  | 31 | `+0x4FC..+0x500` 5 x u8 | VT checkbox seeds for store kinds 3/4/5/7/6 (EV-0136) | 0,0,0,0,1 / 1,1,1,0,1 |
  | 32 | `+0x4B0..+0x4E5` 54 x u8 | tutorial/hint byte block (memset at level start) | `01 01 00..` / all 0 |
  | 33 | `+0x4E6` u8 | egg-hint armed; `+0x4E8` dword is its idle counter (hint at > 1500) | 0,0 / 0,0 |
  | 34 | `+0x4F0` u32 / `+0x4F4` u8 | unknown, no writer/reader in the captured corpus | 0,0 / 0,0 |
  | 35 | `5e89d0/d4/d8` 3 x u32 | hidden-Wadsworth count + mouth x/y (EV-0090) | 0,0,0 / 0,506,109 |
  | 36 | `5e89c0/c4/c8` 3 x u32 | held-pellet / cursor attractor flag + x/y (fish pause within 8 px) | 0,0,0 / 0,0,0 |
  | 37 | `5e89cc` u8 | Meryl song-active (EV-0089) | 0 / 0 |
  | 38 | `5e89dc` u32 | food quality level 0..2 | 0 / 2 |
  | 39 | `5df58c` u32 | food quantity level 1..9 | 1 / 5 |
  | 40 | `5e89e8` 4 B | backdrop tint r,g,b,a (`FUN_00537D30`; backdrop 1 = 0x42,0x30,0x29) | `42 30 29 ff` / same |
  | 41 | 12 x 17 B | store table, see note (5) | see note (5) |
  | 42 | timestamp u32 | `__time64` low dword, not written by the body | 0x6A7C355C / 0x684E93F0 |

  (3) **`+0x2A6` and the optional object.** `FUN_00539AD0(b)` stores `b` in `Tank+0x2A6` and in every
  element's `+0x55` for the lists at `Tank+0xA0` and `+0xC0`, plus the pets in `+0xB4` when Meryl (index
  `0x10`) is ready to sing or index `0x17`. `FUN_00545620` (spawn) calls it with 0, `FUN_00539C90` calls it
  with 1 once the three hostile containers are empty, and the mode-5 loader re-applies the saved byte
  (`FUN_00546AA0` tail). `FUN_00547610` also flushes a pending `Tank+0x2A7` through it. The byte is
  therefore a tank-wide "entity latch"; which value means enabled is not proven. The `Tank+0x110` object is
  written as a presence byte plus the object's own serializer (the boss spawn of P2.8 stores its pointer
  there); both samples have no object.
  (4) **The 27-dword run `+0x444..+0x4AC`.** Bound: `+0x444` tick counter (`FUN_00537B60`/frames),
  `+0x450/+0x454/+0x458` mode timers (`+0x454` is the Challenge price-inflation countdown, 500 at mode-4
  start), `+0x45C` wave number, `+0x460` level total earned, `+0x46C` carnivore/Oscar high-water,
  `+0x470` Ultravore high-water, `+0x48C` guppy high-water, `+0x494` Penta high-water, `+0x4AC` pellet
  price. Unknown: `+0x448` (tick-like), `+0x464`, `+0x468`, `+0x474`, `+0x478`, `+0x47C`, `+0x480`,
  `+0x484`, `+0x488`, `+0x490`, `+0x498..+0x4A4`, `+0x4A8` (incremented by the corner-reaching larva
  before `FUN_0053C1E0`, P2.10). The late `sim1` values `+0x468=107`, `+0x474=136`, `+0x488=219` are the
  reason a "lifetime spawn/purchase total" label is tempting, but no writer for them was read; `adv1` is
  an early level and has all three at 0, which is consistent with (not proof of) that hypothesis.
  (5) **The store table.** Twelve entries, each `u32 slot id (+0x2E4)`, `u32 price (+0x314)`, `u32 base
  (+0x344)`, `u32 increment (+0x374)`, `u8 present (+0x3A4)`. Slot id -1 = empty entry. `FUN_00541A20`
  computes `+0x2DC` as the count of entries with slot >= 0 and, when increment is -1, sets
  increment = price / 100 and base = price. `FUN_005409B0(i, ...)` resolves slot `i`, and only when the
  widget at `+0x404+slot*4` is null does it create it, mark `present[i] = 1` and increment `+0x2E0`;
  `+0x2E0` is therefore a runtime "widgets built" count, reset to 0 after a load and **not serialized**.
  The loader rebuilds a widget for every entry whose `present` byte is set. `adv1` slots
  `[0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,6]`; `sim1` `[0,-1,1,2,3,-1,-1,-1,-1,-1,5,6]`; all 24 `present`
  bytes are 0 in both, i.e. no store widget had been built when those files were written.
  (6) **Sample cross-check.** `adv1` (E=362, S=49): pet array 0x1C5, store 0x361, timestamp 0x42D, 8
  trailing zeroes. `sim1` (E=10946, S=32): pet array 0x2B0C, store 0x2CA8, timestamp 0x2D74, 160 trailing
  zeroes. The two body parses consume every byte through the timestamp with no remainder, so the order
  above is self-consistent on both save families.
  (7) **Bounded unknowns (Q-0029).** `+0x448`, `+0x464`, `+0x468`, `+0x474`, `+0x478`, `+0x47C`,
  `+0x480`, `+0x484`, `+0x488`, `+0x490`, `+0x498..+0x4A8`, `+0x2C4/+0x2C8`, `+0x440`, `+0x4F0`,
  `+0x4F4`, `+0x2AC/+0x2B0`; the overlay tail `+0xC8/+0xD0/+0xD4/+0xD8`; the direction of `+0x2A6`;
  the exact gameplay effect of the two attractor triples; and the `+0x3EC` writer (only the body's
  swap-restore reads it). `+0x4E6/+0x4E8` are bound (egg hint) and `+0x2E0` is runtime-only.

### EV-0145 - P2.14: the audio architecture - DirectSound for effects, BASS for music, two mixers
- Date: 2026-11-01
- Type: code trace (module decompilation + engine-free image scans: PE imports, vtable dumps,
  immediate-reference and call-site scans)
- Source: `docs/evidence/p2.2-module-rtti-classes.txt` (class -> vtable map, EV-0041);
  `tools/pe-imports.ps1 docs\analysis\snapshots\insaniquarium-game-module.exe` (import table);
  vtable dumps (`0x5C1084`, `0x5C1104`, `0x5C10D0`, `0x5C11BC`, `0x5C1164`, `0x5C1214`);
  `docs/evidence/p2.14-decompile-4883BA.txt` (the factory `FUN_00488300`);
  strings `0x5C05DC..0x5C0A48` (BASS/FMOD name tables), `.snd`/`cached\`/`dsound.dll`
- Confidence: high for the class/vtable split, the backend selection and the "two mixers" reading;
  medium for `app+0xF0`/`+0xF1` being the no-sound / prefer-FMOD switches
- Notes:
  (1) **Three layers.** The module carries `Sexy::SoundManager` (abstract, vtable `0x5C1084`, 18
  slots, only slot 0 real) with the single concrete subclass `Sexy::DSoundManager` (vtable
  `0x5C1104`, 18 slots) and `Sexy::DSoundInstance` (`0x5C10D0`, 12), plus the resource layer
  `Sexy::SoundRes::ResourceManager` (`0x5B0470`, 2 slots). Effects therefore go
  SoundRes -> DSoundManager -> `IDirectSoundBuffer`. DirectSound is bound **dynamically**: the
  static import table carries no `dsound.dll` (the 9 imported DLLs are KERNEL32, USER32, ADVAPI32,
  WINMM, WSOCK32, GDI32, SHELL32, ole32, OLEAUT32), and the `DSoundManager` ctor resolves
  `DirectSoundCreate` through `GetProcAddress` on a handle loaded from the literal `dsound.dll`
  string.
  (2) **Music is a separate engine.** `Sexy::MusicInterface` (`0x5C1164`, 20 slots) has two
  implementations in the image: `Sexy::BassMusicInterface` (`0x5C11BC`) and
  `Sexy::FModMusicInterface` (`0x5C1214`). The install ships `bass.dll` and no `fmod.dll`
  (EV-0001/EV-0004), and the `_FSOUND_*`/`fmod.dll` strings (`0x5C0A48..`) belong to the dead FMOD
  path, so BASS is the live music backend.
  (3) **Backend selection.** `FUN_00488300` (called from app init) allocates exactly one
  interface: 4 B base `MusicInterface` (`FUN_0049B2A0`) when `app+0xF0 != 0` (silent), 0x20 B
  `FModMusicInterface` (`FUN_00499DD0`) when `app+0xF1 != 0`, else 0x18 B `BassMusicInterface`
  (`FUN_00498750`). The 0x18-byte size fits BassMusicInterface's field count.
  (4) **Two independent volume paths.** The framework's option block stores `MusicVolume` and
  `SfxVolume` as *separate* settings (EV-0149), and the BASS wrapper keeps its own
  `BASS_SetGlobalVolumes`/`BASS_SetVolume` handles (`BASS_INSTANCE[9]`/`[10]`) beside the
  DirectSound side - consistent with music and effects being mixed by two different engines.

### EV-0146 - P2.14: the BASS wrapper - `Sexy::BASS_INSTANCE` and its 48-entry function table
- Date: 2026-11-01
- Type: code trace (module decompilation, string/immediate scans)
- Source: `docs/evidence/p2.14-decompile-498010.txt` (`FUN_00498010`, 1434 B) and
  `docs/evidence/p2.14-trace-bassdll.json` (string xrefs for `bass.dll`); strings
  `0x5C05DC` (`%s function not found in bass.dll`), `0x5C0608..0x5C0A04` (the name table),
  `0x5C0A18` (`.\bass.dll`), `0x5C0A24` (`Can't find bass.dll.`), `0x5C0660` (the fatal
  SetGlobalVolumes/SetVolume message)
- Confidence: high
- Notes: `FUN_00498010` stores its vtable at `+0x0`, `LoadLibraryA(".\\bass.dll")` into `+0x4`,
  then `GetProcAddress` for every name in `.rdata`, one fixed dword index each: `[3]` GetVersion,
  `[4]` Init, `[6]` Free, `[7]` Stop, `[8]` Start, `[9]` SetGlobalVolumes, `[10]` SetVolume,
  `[11]` GetVolume, `[12]` GetInfo, `[13]` SetConfig, `[14]` GetConfig, `[15]` ChannelStop,
  `[16]` ChannelPlay, `[17]` ChannelPause, `[18]` ChannelSetAttributes, `[19]` GetAttributes,
  `[20]` SetPosition, `[21]` GetPosition, `[22]` SetFlags, `[23]` IsActive, `[24]` SlideAttributes,
  `[25]` IsSliding, `[26]` GetLevel, `[27]` ChannelSetFX, `[28]` ChannelRemoveFX,
  `[30]` ChannelGetData, `[32]` ChannelSetSync, `[33]` ChannelRemoveSync, `[34]` MusicLoad,
  `[36]` MusicFree, `[37]` StreamCreateFile, `[38]` StreamFree, `[39]` FXSetParameters,
  `[40]` FXGetParameters, `[41]` MusicGetAttribute, `[42]` MusicSetAttribute, `[43]` MusicGetOrders,
  `[44]` MusicGetOrderPosition, `[46]`..`[52]` SampleLoad/Free/SetInfo/GetInfo/GetChannel/Stop and
  ErrorGetCode. When `BASS_SetConfig` resolves (BASS 2.0 layout; byte `+0x08` = 1), `[4]`->`[5]`,
  `[34]`->`[35]` and the legacy slots are cleared, and the 2.0-only names `BASS_ChannelGetLength`
  (`[29]`), `BASS_ChannelPreBuf` (`[31]`) and `BASS_PluginLoad` (`[45]`) are resolved. Failure
  paths: `FUN_00498690` reports `"Can't find bass.dll."`; `FUN_00497FA0` reports
  `"%s function not found in bass.dll"` per missing entry; missing *both* volume entries is fatal
  (`MessageBoxA(..., "Error", MB_ICONHAND)` + `_exit(0)`). The shipped `bass.dll` exports the 2.0
  API (`BASS_ChannelSetAttributes`, `BASS_ChannelPreBuf`, `BASS_PluginLoad` present;
  SHA-256 `d98cd5d6ed9c4a95701684aa83777cefd5d8096e14c836493f67159d68161c01`).

### EV-0147 - P2.14: music - three `.mo3` tracks loaded once at app init as ids 1/3/4, played through BASS
- Date: 2026-11-01
- Type: code trace (module decompilation of the app init, the BASS load slot and the play slot)
- Source: `docs/evidence/p2.14-decompile-550E53.txt` (`FUN_005503C0` = `SexyApp::Init`),
  `p2.14-decompile-498A00.txt` (`BassMusicInterface` slot 1), `p2.14-decompile-498D10.txt` (slot 2),
  `p2.14-decompile-49B5E0.txt` (the map insert it calls), `p2.14-decompile-498950.txt` (slot 0);
  strings `music\Alien.mo3` / `music\Lullaby.mo3` / `music\Insaniq2.mo3`
  (`0x5A9360`/`0x5A934C`/`0x5A9338`)
- Confidence: high for the ids, the file names, the load path and the play semantics; medium for
  the `BASS_MusicLoad` flags word
- Notes:
  (1) **Preload.** `SexyApp::Init` preloads all three tracks through `app+0x374` (the music
  interface) slot 1 with `(trackId, fileName)`: `1 = music\Alien.mo3` (10.24 s),
  `3 = music\Lullaby.mo3` (115.70 s), `4 = music\Insaniq2.mo3` (113.66 s) - the call sites sit
  back to back at `0x550F10..0x550F5F`. Ids 0 and 2 are never loaded.
  (2) **Slot 1 (`FUN_00498A00`) = LoadMusic.** With no `.` in the name it probes three extensions
  in order `wav`, `ogg`, `mp3` (strings `0x5C0A3C/0x5C0A40/0x5C0A44`) - `mo3` is **not** in the
  probe list. `music\Insaniq2.mo3` therefore takes the second path: the whole file is read into a
  fresh buffer (`FUN_00495420` open, `FUN_004954F0` size, `FUN_00495520` read) and handed to
  `BASS_INSTANCE[34]` = `BASS_MusicLoad(mem = 1, buffer, 0, 0, flags)`, then the buffer is freed;
  the flags word is loaded from the interface field `+0x14` (value not proven). A non-module name
  instead inserts a `std::map` entry keyed by track id (`FUN_0049B5E0` is the red-black-tree
  find/insert).
  (3) **Slot 2 (`FUN_00498D10`) = PlayMusic(track, position, flag).** It finds the track's node,
  copies `node+0x30`->`node+0x20`, zeroes `+0x28`, stores the flag at `+0x38`, applies
  `BASS_INSTANCE[18]` `ChannelSetAttributes` to the node's music handle (`+0x18`, falling back to
  the stream handle `+0x1C`), calls `BASS_INSTANCE[15]` `ChannelStop`, restarts through
  `FUN_00498620(position, 4 | 0x8200)` (loop bit `4`; `0x8200` only when the 2.0 layout byte is
  set), calls `FUN_00498670(position != -1)` and, when `position > 0`, seeks with
  `BASS_INSTANCE[20]` `ChannelSetPosition`. So the interface is load-once / play-and-seek-orders,
  always looping.
  (4) **Slot 0 (`FUN_00498950`) is the destructor** (frees the music, then `_free(this)` when the
  scalar-deleting flag is set).

### EV-0148 - P2.14: music playback in the game layer - `SetMusic(a, b)`, 21 call sites, mode-5 silence, the remap table
- Date: 2026-11-01
- Type: code trace (module decompilation + an engine-free direct-call scan of `.text`)
- Source: `docs/evidence/p2.14-decompile-54B1A0.txt` (`FUN_0054B1A0`),
  `p2.14-decompile-54B2F0.txt` (`FUN_0054B2D0`, the per-stage selector),
  `p2.14-decompile-54B090.txt` (`FUN_0054B090`, the remap); call sites and their recovered
  arguments from the call/`push`-immediate scans of this pass
- Confidence: high for the wrapper, the call-site argument table and the mode-5 gate; medium for
  the intent of the `(a, b)` pair and of `DAT_005e28cc`
- Notes:
  (1) `FUN_0054B1A0(a, b)` writes `b` to `manager+0x890` and `a` to `manager+0x88C`, calls
  `FUN_0054B090()`, then calls music-interface slot 2 (`PlayMusic`, EV-0147). It is the single
  music-request entry of the game layer.
  (2) **21 direct call sites** exist. The `(a, b)` pairs: startup (`0x550F2E`) `(2, 45)`; screens
  `(2, 54)` at `0x517322`/`0x51F755`/`0x527954`/`0x53DC3A`/`0x54C03C`, `(2, 5)` at
  `0x51B000`/`0x52EEDD`, `(2, 0)` at `0x52A239`/`0x52B783`/`0x52F359`/`0x55250A`, `(2, 2)` at
  `0x52E85E`, `(1, 3)` at `0x538A03`, `(1, 1)` at `0x548A45`, `(1, 0)` at `0x54C49F`, plus the
  stage selector below. All sites pass a third argument of 0.
  (3) **`FUN_0054B2D0` is the per-stage selector**: after `FUN_0054B020()` and **only when
  `[manager+0x87C] != 5`** (mode 5 = Virtual Tank) it picks the pair from the level-6/bonus
  sentinel `FUN_0054B2A0()` and the stage index `FUN_0054ACF0()`: sentinel -> `(0, 13)`, stage 1 ->
  `(0, 22)`, stage 2 -> `(0, 0)`, stage 3 -> `(2, 32)`, stage 4 -> `(2, 45)` (call sites
  `0x54B2F4`, `0x54B30B`, `0x54B322`, `0x54B339`, `0x54B350`). Virtual Tank therefore requests no
  music at all.
  (4) **The remap (`FUN_0054B090`), gated on `DAT_005e28cc != 0`**, rewrites the pair before
  playback: `(0,22)->(4,0)`, `(0,0)->(4,12)`, `(0,13)->(4,58)`, `(2,32)->(4,25)`, `(2,45)->(4,37)`,
  `(2,0)->(4,45)`, `(2,54)->(4,49)`, `(2,5)->(4,50)`. Every output has the first value 4 and a
  different second value, i.e. the same music at a different order/position - consistent with slot
  2's seek parameter. What `DAT_005e28cc` switches is not identified, and how `(a, b)` reach slot
  2's three parameters is not proven by the pseudocode (both Q-0031).

### EV-0149 - P2.14: SFX - a 256-slot DirectSound pool, the SoundRes load path, and all 65 name -> global ids
- Date: 2026-11-01
- Type: code trace (module decompilation) + engine-free image scan (the loader's `mov [global],eax`
  stores and the globals' read sites)
- Source: `docs/evidence/p2.14-decompile-4955D9.txt` (`FUN_00495590`, the `DSoundManager` ctor),
  `p2.14-decompile-488CE7.txt` (`FUN_004883F0`, app init; the ctor call site is `0x488CE7`),
  `p2.14-decompile-419363.txt` (`FUN_00419320`), `p2.14-decompile-4896B0.txt` (`FUN_004896B0`,
  app vtable slot `0xD8`), `p2.14-decompile-483C82.txt` (`FUN_00483A20`, the stats overlay),
  `p2.14-decompile-47E2B2.txt`/`p2.14-decompile-47EEFC.txt` (the option block); generated inputs
  `docs/analysis/inputs/p2.14-sound-table.txt`, `p2.14-sound-id-xrefs.txt`,
  `p2.14-sound-manifest.txt`
- Confidence: high for the pool size, the load path, the play path and the name->global table;
  medium for the primary-buffer format fields and the `Muted` derivation
- Notes:
  (1) **Pool.** `FUN_00495590(this, HWND, byte)` - called at `0x488CE7` with `app+0x350` (window
  handle) as second and `*(byte*)(app+0xF1)` as third argument, guarded by `cmp [app+0xF0], 0` - runs
  `_eh_vector_constructor_iterator_(this+0x404, 0x1C, 0x100, ...)`, i.e. **256 slot records of 28
  bytes**, plus a 256-double volume array at `+0x2408` initialised to `1.0` each and a 256-dword
  array at `+0x2C08` cleared. It then resolves `DirectSoundCreate` by name, calls it with the
  default device, sets cooperative level 2 with a fallback to 1, and creates a primary buffer from
  a `WAVEFORMATEX`-shaped stack block (raw dwords `0x100004`, `0x14`, `1`, `0`, `0x12`, `0`)
  followed by `SetFormat`.
  (2) **Load.** `FUN_00419320` asks slot 16 (`0x496D10`) for a free id; a negative answer logs
  `"Out of free sound ids"` and throws. Otherwise slot 3 (`0x496720`) loads, a failure logs
  `"Failed to load sound: %s"`, and on success the record's default volume (double at `+0x70`) is
  applied through slot 6 (`0x496D70`) only when positive, its pan/priority int (`+0x78`) through
  slot 7 (`0x496D90`) only when non-zero, the id is stored at `record+0x6C`, and the resource
  manager notifies itself through its own vtable slot 13.
  (3) **Play.** The app's only sample entry is vtable slot `0xD8` = `FUN_004896B0(soundId)`: if
  `app+0x4B4` (the `SoundManager`) is set, `inst = soundManager->vtable[8](id)` (`0x4976F0`), and
  when non-null `inst->vtable[7](0, 1)` (`0x497E10`) starts the voice. **Gameplay passes the id
  only** - there is no per-call volume or pan. Slot 17 (`0x496D30`) is the occupied-slot count that
  the stats overlay prints as `"Num Sounds: %d"`.
  (4) **The sound table.** A single startup function assigns every `SOUND_*` resource an id and
  stores it in a dedicated global dword; all **65** bindings are extracted in
  `p2.14-sound-table.txt`, e.g. `SOUND_BUTTONCLICK -> 0x5E8C40`, `SOUND_BUY -> 0x5E8D14`,
  `SOUND_HATCH -> 0x5E8D44`, `SOUND_APPLAUSE -> 0x5E8C38`, `SOUND_TONELO -> 0x5E8A3C`. The 65
  resource names/files come from `properties\resources.xml` (P3.1, EV-0024/EV-0025): 64 in the
  `LoadingThread` group plus `BUTTONCLICK` in `Init`; 50 `.ogg`, 15 `.au`.
  (5) **Trigger coverage.** A whole-`.text` scan for `mov reg,[global]` / `push [global]` finds
  direct read sites for **33 of the 65** ids (`p2.14-sound-id-xrefs.txt`), e.g.
  `SOUND_BUTTONCLICK` at `0x530AC8`/`0x5312AA`/`0x532741`/`0x547815`/`0x54A373`,
  `SOUND_BUY` at `0x520836`, `SOUND_DIE` at `0x538681`, the `SOUND_SPLASH*` trio at
  `0x538387..0x5383BD`, the `SOUND_ROAR*` trio at `0x5458BA..0x545928`. Mapping each id to its
  gameplay event is Q-0030.
  (6) **Options.** `FUN_0047EDA0` (read) / `FUN_0047E280` (write) store `MusicVolume` and
  `SfxVolume` as integer percent and load them into doubles at `app+0xD0` (music) and `app+0xD8`
  (effects) as `pct/100.0`; `Muted` (`0x5BF654`) reads back into `app+0x428`, while the write
  emits a derived value from `app+0x428`/`app+0x42C` (`A != B && A - B > 0`), which is left open
  (Q-0031). The other keys in the same block are `ScreenMode`, `PreferredX`, `PreferredY`,
  `CustomCursors`, `WaitForVSync`, `InProgress`, `RegistryKey`, `Buffer`.

### EV-0150 - P2.15: the manifest pipeline - three fatal levels, one element dispatcher
- Date: 2026-11-02
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.15-decompile-41897A.txt` (`FUN_00418780`, `LoadManifest`),
  `docs/evidence/p2.15-decompile-418420.txt` (`FUN_00418420`, the `<ResourceManifest>` body),
  `docs/evidence/p2.15-decompile-417F10.txt` (the `<Resources>` body + element dispatch),
  `docs/evidence/p2.15-decompile-417E0A.txt` (`FUN_00417CA0`, `SetDefaults`); strings
  `0x5AFF7C` `"Resource file not found: "`, `0x5AE0AC` `"Invalid Section '"`, `0x5AE0D8` `"id"`,
  `0x5AFD38` `"path"`, `0x5AFF48` `"Font"`
- Confidence: high (all four layers decompiled end to end; every error string's throw site read)
- Notes:
  (1) **`LoadManifest(path)`** = `FUN_00418780`. It allocates a 124-byte XML parser
  (`FUN_00564345(0x7C)`, ctor `FUN_00402590`) into `manager+0x34`, opens the file with
  `FUN_00402DA0`, and on failure throws `"Resource file not found: " + path`. The token loop calls
  `FUN_004048D0` (advance) and `FUN_00403060(parser)` (next element). A start-element token
  (`kind == 1`) whose name is not `ResourceManifest` throws `"Expecting ResourceManifest tag"`;
  a bad token throws `"Element Not Expected '<name>'"`; matching calls `FUN_00418420` and unwinds.
  (2) **`<ResourceManifest>` body** = `FUN_00418420`. Only `Resources` is accepted (element-name
  compare at `0x4184xx`), everything else throws `"Invalid Section '<name>'"` (`0x4186A3`). For a
  `<Resources>` element it reads the `id` attribute (`FUN_00426BE0(&DAT_005AE0D8, 2)` = `"id"`),
  stores it at `manager+0x30`, throws **`"No id specified."`** when absent, and then calls
  **vtable slot 5** with the id - which is `FUN_0050FF10` (the group dispatcher, EV-0154). At
  document end it frees and nulls the parser (`manager+0x34`).
  (3) **`<Resources>` body** = `FUN_00417F10`. It polls `FUN_00403060(manager[0xD])` in a loop and
  dispatches element names through the object's own vtable: `+0x08` = `Image`, `+0x04` = `Sound`,
  `+0x0C` = `Font`, `+0x10` = `SetDefaults`, and `"Invalid Section '"` for anything else. `kind 3`
  (text) throws `"Element Not Expected '"`; `kind 2` (end element) returns. The name comparison
  itself is `FUN_004010F0(name, "Image", n)` for the first case and `FUN_00422860(0, len, target,
  targetLen)` for the rest - the `len` argument is the element name's length clamped to 5, so the
  comparisons are case-insensitive prefix matches, not exact.
  (4) **`SetDefaults`** = `FUN_00417CA0`. It reads exactly two attributes - `path` (`0x5AFD38`) and
  `idprefix` - and each *replaces* the corresponding inherited string (there is no merge and no
  empty-string reset: both are skipped when the attribute is absent). Its return value 1 means
  "handled".
  (5) **Nothing recovers.** All five error paths above throw through `FUN_0041D8B0` and abort
  startup; there is no partial load, no "skip bad entry" and no log-and-continue. This is why the
  manifest in the install is so regular, and why P4 must not reproduce the brittleness (§8.1 of the
  note).

### EV-0151 - P2.15: id and path resolution - `idprefix` + `id`, then a fixed six-extension probe
- Date: 2026-11-02
- Type: code trace + engine-free scan (generated inventory of the shipped manifest)
- Source: `docs/evidence/p2.15-decompile-4A025F.txt` (`FUN_0049FED0`, the image loader),
  `docs/evidence/p2.15-decompile-417E0A.txt` (`SetDefaults`), `docs/evidence/p2.15-decompile-416EF9.txt`
  (the `<Image>` parser's `path`/`alphaimage` joins); `docs/analysis/inputs/p2.15-groups.txt`
  (generated by `tools/p2.15-groups.js`); string constants `0x5C1390` `.tga`, `0x5C1398` `.jpg`,
  `0x5C13A0` `.png`, `0x5C13A8` `.gif`, `0x5C13B0` `.j2k`, `0x5C13B8` `.jp2`, `0x5B0F58` `"_"`
- Confidence: high for the id/path model and the probe order; high for the 326/326 id partition
- Notes:
  (1) **Id = `idprefix` + `id`.** Every group switches defaults before its entries, so
  `id="BLANK"` under `idprefix="IMAGE_"` becomes `IMAGE_BLANK`, which is exactly the string the
  group handlers push at their `GetImage` call sites. The manifest therefore never contains the
  fully-qualified ids the engine looks up - they are composed at load time.
  (2) **Path = default `path` + `"\\"` + entry `path`.** `Init` walks images -> data -> sounds,
  `Register` data -> images, `LoadingThread` images -> sounds; the full chains are printed per
  group in `p2.15-groups.txt`.
  (3) **Extension probing** (`FUN_0049FED0`): split at the last `.` after the last path separator.
  With an extension, only that decoder runs. Without one, six decoders are tried in a fixed order -
  `.tga` (`FUN_0049BFD0`), `.jpg` (`FUN_0049F800`), `.png` (`FUN_0049BE40`), `.gif` (`FUN_0049C160`),
  `.j2k` (`FUN_0049FB10`), `.jp2` (`FUN_0049FB10`) - each guarded by `__stricmp` against the parsed
  extension and the "no extension" flag. The install is a mix of `.gif` sprites and `.jpg`
  backgrounds and relies on this: not one `path` in `resources.xml` carries an extension.
  (4) **Exact partition.** 246 images = 11 (`Init`) + 3 (`Register`) + 232 (`LoadingThread`);
  15 fonts = 2 + 13 + 0; 65 sounds = 1 + 0 + 64. The three handlers statically reference 14 + 16 +
  296 = **326** ids, i.e. every manifest id and nothing else (`p2.15-groups.txt`). That cross-check
  is the strongest single result of this pass: it proves both the id composition rule and that the
  shipped manifest is exactly what the binary was built against.

### EV-0152 - P2.15: `<Image>` entries - the attribute set, the grid, and the four animation modes
- Date: 2026-11-02
- Type: code trace + generated manifest inventory
- Source: `docs/evidence/p2.15-decompile-416EF9.txt` (`FUN_004166C0`, the `<Image>` parser),
  `docs/evidence/p2.15-decompile-4575E0.txt` (the animation builder, batch 5); attribute-name VAs
  resolved with `tools/p2.15-vastr.js` - `rows` `0x5AFE1C`, `cols` `0x5AFE24`, `anim` `0x5AFE2C`,
  `path` `0x5AFD38`; `docs/analysis/inputs/p2.15-manifest-inventory.txt`,
  `docs/analysis/inputs/p2.15-groups.txt`
- Confidence: high for the attribute list, the field offsets, the grid and the anim enum; medium for
  the time unit of `framedelay` (see Q-0032)
- Notes:
  (1) **The parser** allocates a 0x110-byte `Sexy::Image`/`MemoryImage`, lets the entry fill it
  through a virtual call, then reads the attributes in a fixed order into fixed offsets:
  `nopal` `+0xCD`, `a4r4g4b4` `+0xCE`, `a8r8g8b8` `+0xCF`, `ddsurface` `+0xD0`, `nobits` `+0xD1`
  (with `nobits2d`/`nobits3d` sub-cases consulted first), `minsubdivide` `+0xD2`, `noalpha` `+0xCC`,
  `alphaimage`, `alphacolor` `+0xDC` (default `0xFFFFFF`, `sscanf("%x")`), `variant` (read then
  discarded), `alphagrid`, `rows` `+0xD4` (default 1), `cols` `+0xD8` (default 1), `anim` `+0xE0`,
  `framedelay` `+0xE4`, then `begindelay`, `enddelay`, `perframedelay`, `framemap` and finally
  `FUN_004575E0(animType, beginDelay, endDelay)` to build the animation.
  (2) **Grid.** `frameCount = cols * rows`, cell = `imageSize / (cols, rows)`, frame index
  row-major (`col = i % cols`, `row = i / cols`) - the order `gen_spriteframes.gd` already
  implements. 111 of 246 entries declare `cols` and 52 declare `rows`; of the 114 grid-declaring
  entries, 66 are animated and **48 are not** (manual frame tables used with explicit indices by
  gameplay). All 246 propagate exactly (P3.2).
  (3) **`anim` enum**: `none` = 0, `once` = 1, `pingpong` = 2, `loop` = 3, compared with
  `__stricmp`; any other value throws `"Invalid animation type."` and the entry fails. Shipped use:
  56 `loop`, 8 `pingpong` (`WAVE`, `WAVESIDE`, `NIKO`, `VERT`, `WALTER` + `SCL_NIKO`/`SCL_VERT`/
  `SCL_WALTER`), 2 `once` (`MERYLBLINK`, `MERYLTAIL`), 0 `none`.
  (4) **Delays.** 66 entries are animated; 65 declare `framedelay` and every value is `2` or `4`.
  The 66th is `MERYLBLINK`, which declares only `perframedelay` (`3,2,3,1,1,1`, parallel to its
  six-step `framemap`) - its missing default is clamped to 1 by the builder (note 6). `begindelay`
  is used three times (`MERYLTAIL` 3, `WAVESIDE` 6, `WAVE` 6); `enddelay` never. Whether the unit is
  the 10 ms logic tick (P2.1) or a millisecond is Q-0032 - with a 100 Hz loop, `2`/`4` are 20/40 ms,
  i.e. 50/25 fps, which is the plausible reading for swim cycles.
  (5) **`framemap`** is used twice: `MERYLBLINK` `0,1,2,1,0,-1` and `MERYLTAIL` `7,6,5,4,3,2,1,0`.
  The `-1` is not a terminator (the parallel `perframedelay` list has six entries) and not a frame
  index (the sheet has three cells); see Q-0032.
  (6) **The animation is built once at load** by `FUN_004575E0(data, beginDelay, endDelay)`
  (`docs/evidence/p2.15-decompile-4575E0.txt`), whose record layout is
  `{type, defaultDelay, frameCount, perFrameDelays, frameMap, totalDuration}`:
  `frameCount`/`defaultDelay` are clamped to >= 1; **`pingpong` is expanded into an explicit
  `0..N-1,N-2..1` sequence** rather than interpreted per frame; a supplied `framemap` *replaces* the
  sequence and sets `frameCount` to its length; `perframedelay` entries `< 1` are replaced by
  `defaultDelay` (so partial lists mean "use the default", which is why `MERYLBLINK`'s six delays
  line up with its six map entries); and `totalDuration` is `frameCount * defaultDelay` when there
  are no per-frame delays, otherwise the sum of the per-frame list. The precomputed integer total is
  the strongest evidence that delays are integer ticks (the tick length itself is P2.1's). The
  builder does **not** special-case a negative `framemap` entry - it stores the map verbatim - so
  `-1` must be handled by the frame-advance path (Q-0032a).

### EV-0153 - P2.15: two-file alpha - the `_` companion, `alphaimage`, and the cell-sized `alphagrid`
- Date: 2026-11-02
- Type: code trace + asset measurement (`assets_raw/extraction.json`, `System.Drawing` on the mask
  files)
- Source: `docs/evidence/p2.15-decompile-4A025F.txt` (`FUN_0049FED0`, the mask merge at the tail of
  the loader - `lookForAlpha` branch), `docs/evidence/p2.15-decompile-418A0A.txt`
  (`FUN_004189B0`, the `alphagrid` composition), `docs/evidence/p2.15-decompile-416EF9.txt`
  (where the two attributes are read); string `0x5B0F58` = `"_"`; P3.2 (EV-0026/EV-0027) for the
  on-disk inventory
- Confidence: high for the implicit `_` companion and for `alphagrid`; high for `alphaimage` via
  measurement (no decompile of its own composition path)
- Notes:
  (1) **Implicit `_` companion.** When `FUN_0049FED0(name, 1)` is called, it splits the directory
  off the name, builds `dir + "_" + filename` (`"_"` = `0x5B0F58`), loads that too, and then:
  - if the base failed and the companion loaded, the companion becomes the result with RGB forced
  to white and alpha left from its own channel 0 (the loop `*bits = *bits << 24 | 0xFFFFFF`);
  - if both loaded and the sizes match, it copies the companion's channel-0 byte into the base's
  alpha byte (`base.a = mask.b`, stride 4 on both sides) and frees the companion;
  - a size mismatch silently keeps the base as it is (only the explicit paths throw).
  **Alpha comes from the mask's blue channel only** - the mask's RGB is discarded, so a grayscale
  silhouette is all that is needed. 187 of 246 images in the install rely on this convention.
  (2) **`alphagrid`** = `FUN_004189B0`. It loads the mask with the same `LoadImage(mask, 1)` call,
  computes `cellW = image.w / cols`, `cellH = image.h / rows` from the two fields the entry parser
  filled (`+0xD8` cols, `+0xD4` rows), requires the mask to be *exactly* one cell, otherwise
  throws `"GridAlphaImage size mismatch between %s and %s"`, then walks rows -> cols -> cell pixels
  copying mask channel 0 into the base alpha and marks the image dirty (vtable slot 25).
  (3) **`alphaimage`** names a mask the size of the whole image. Measured on the install:
  `tankbackdrops_.gif` 190x121 = `tankbackdrop1` 190x121, `eggbonus_.gif` 96x121 = `eggbrink`,
  `aatop_.jpg` 32x37 = `aatop1`/`aatop2`, `_mbuttono.gif` 57x60 = `mbuttond`. `alphagrid` masks are
  one cell: `mainbutton_.gif` 90x29 against a 270x29 `cols=3` sheet, `leftbutton_.gif` 63x29
  against 189x29. Every `alphaimage` entry in the shipped manifest is single-cell, so the two
  attributes are interchangeable in this game's data - the rule is simply "mask matches the unit it
  masks".
  (4) **Counts.** 17 entries declare a mask explicitly (13 `alphaimage`, 4 `alphagrid`), 204 of 246
  images have a literal mask file, and only `SLIDERTHUMB`, `HELPALIEN`, `HELPPETCHOOSE` carry alpha
  in the base GIF (P3.2). `EDITBOX`'s `_EditBox.gif` (96x33 against a 90x42 image) is the one size
  mismatch in the set and is a source-asset inconsistency, not an engine case.
  (5) **Grappling with the black-bodied SIM fish is out of scope here**: their `_` companions hold
  body silhouettes while the base holds eyes on black, so a plain alpha merge would leave the fish
  black. The engine must colourise those (Q-0033); P3 keeps the layers separate and P4 composites
  them.

### EV-0154 - P2.15: the three groups, the deferred entry loader, and the typed lookups
- Date: 2026-11-02
- Type: code trace + engine-free static extraction of the handler id lists
- Source: `docs/evidence/p2.15-decompile-50FF39.txt` (`FUN_0050FF10`, the group dispatcher),
  `docs/evidence/p2.15-decompile-506EA0.txt` (group `Init`), `docs/evidence/p2.15-decompile-50E190.txt`
  (group `Register`), `docs/evidence/p2.15-decompile-419780.txt` (`FUN_00419480`, the entry loader),
  `docs/evidence/p2.15-decompile-419E47.txt` (`FUN_00419D50`, `GetImage`),
  `docs/evidence/p2.15-decompile-41A003.txt` (`FUN_00419F40`, `GetSound`),
  `docs/evidence/p2.15-decompile-41A13E.txt` (`FUN_0041A080`, `GetFont`); generated inputs
  `docs/analysis/inputs/p2.15-loadingthread-ids.txt` (296 ids), `p2.15-register-ids.txt` (16),
  `p2.15-groups.txt`
- Confidence: high for the group contents, the partition and the lookup/deferral rules; high for the
  entry loader's three kind branches; medium for the entry record's exact string field offsets
  (Ghidra renders them as unnamed `std::string`s)
- Notes:
  (1) **Group dispatch** = `FUN_0050FF10(name, id)`, reached through manager vtable slot 5 from
  `FUN_00418420`. It is a `strncmp`-chain over `Init` (`FUN_00506EA0`), `LoadingThread`
  (`FUN_005073E0`) and `Register` (`FUN_0050E190`); an unrecognised group name returns 0 and is
  silently ignored (**not** an error, unlike a bad section inside a group).
  (2) **`Init`** = 14 resources, each fetched through the manager vtable and stored in a global:
  fonts `JUNGLEFEVER10/17OUTLINE`, images `BLANK`, `CURSOR_{POINTER,HAND,DRAGGING,TEXT}`,
  `TITLEPAGE`, `TITLEPAGEMASK`, `LOADERBAR`, `LOADERBAROVER`, `LOADERBARLOADING`, `LOADERPLAY`, and
  `SOUND_BUTTONCLICK`. **`Register`** = 16: 13 fonts (`LIDDIE12/15/18`, `JUNGLEFEVER12/15OUTLINE`,
  `BLAMBOTPRO8/15`, `TINY`, `TINYBOLD`, `CONTINUUMBOLD{12,12OUTLINE,14,14OUTLINE}`) plus
  `IMAGE_DIALOG`, `IMAGE_DIALOGBUTTON`, `IMAGE_EDITBOX`. Both set `DAT_005E8F17 = 1` on entry - the
  "boot resources resident" flag.
  (3) **`LoadingThread`** = 296: 232 `IMAGE_*` and 64 `SOUND_*`. Ghidra **cannot decompile
  `0x5073E0`** (it returns an empty result on both the first attempt and the retry), so the group's
  content is taken from its `push "<id>"` sites instead - 296 of them, one per resource, which is
  enough to pin the set exactly. The ids are in `p2.15-loadingthread-ids.txt`.
  (4) **Exact partition.** 246 images = 11 + 3 + 232, 15 fonts = 2 + 13 + 0, 65 sounds = 1 + 0 + 64,
  and 14 + 16 + 296 = 326 = every id in the manifest with no duplicates and none left over. The
  sound split (64 in `LoadingThread` plus `BUTTONCLICK` in `Init`) matches EV-0149 note 4 exactly.
  (5) **Entry creation is not entry loading.** Parsing an element only fills a record (id, path(s),
  grid, flags; payload `+0x6C` empty, "loaded" byte `+0x68` clear). `FUN_00419480(entry)` is the
  loader, and it branches three ways: sounds (`+0x88 == 0`, loaded through `FUN_0045CC30` - the
  `SoundRes` path of EV-0149 - with a **stub object** on failure), images (vtable slot `0x104` of the
  manager's owner, with `lookForAlpha = 1`), and fonts (`+0xAC != 0`, `FUN_00467560(path, flag,
  flag, flag)`, result must RTTI-cast to `ImageFont` with a non-null glyph map, else
  `"Failed to load font: %s"`). Failure is **not** fatal here: the entry stays unloaded and the
  game runs on, which is why a missing asset is a missing sprite rather than a startup crash.
  (6) **`!ref:` fonts.** A font path starting with `!ref:` is a reference, not a file: the loader
  drops the 5-character prefix and calls `GetFont(rest)` (`"Ref font not found: "` on failure). The
  shipped manifest has zero `!ref:` occurrences. A non-empty third string on a font entry is
  `strtok`-ed on `", \r\n\t"` and each token fed to font vtable slot `0x48` before slot `0x58` - also
  unused by the shipped fonts (all 15 carry only `id`/`path`).
  (7) **Three registries, three lookups.** Images live in a map at `manager+0x10`, sounds at `+0x1C`,
  fonts at `+0x28`. `GetImage` = `FUN_00419D50`, `GetSound` = `FUN_00419F40`, `GetFont` =
  `FUN_0041A080`; all three share one shape: look up, and if the payload is still empty return the
  placeholder **when `manager+0xB0` is set and the entry's `+0x68` byte says "deferred"** (i.e. the
  loading thread is mid-run); otherwise throw `"Image/Sound/Font resource not found: %s"`
  (`0x419E47` / `0x41A003` / `0x41A13E`). `GetSound` returns the pool id at `entry+0x6C` and treats
  `-1` as "not loaded"; `GetImage`/`GetFont` return the object pointer (the call sites wrap images in
  an `ImagePtr` whose ctor/dtor are `FUN_004682B0`/`FUN_004681E0`).
  (8) **No string keys at runtime.** Every group handler resolves its ids once at load time into
  globals; the manager's lookup is never on a hot path, and the later gameplay code touches the
  resource objects directly.

### EV-0155 - P2.3: the coin predicate is `counter >= threshold`, with mode-5 difficulty and starving rewinds
- Date: 2026-11-02
- Type: observation
- Source: `docs/evidence/p2.3-lastfn-4D7100.json` (`FUN_004D7100`, operation
  `procedure_pseudo_code`); caller `docs/evidence/p2.2-fish-4F1400.json` (`FUN_004F1400`, the
  per-fish counter at `+0x220`); raw pseudocode quoted in that JSON
- Confidence: high
- Notes:
  (1) **Normal modes** (`Tank+0x87C != 5`): `return param_2 <= *param_1`, i.e. the drop matures
  when `counter >= threshold`. `param_2` is the threshold (the fish's `+0x224`), `param_1` points at
  the counter. `FUN_004F1400` increments `+0x220` and then calls this; the caller is reached from
  the tank's per-fish list pass only while the pending-object predicate `FUN_004DA780` is false.
  (2) **Mode-5 adjustment** (`Tank+0x87C == 5`) is entered only for `+0xAC >= 0` (pets are
  negative). Two gates can skip the adjustment: `thunk_FUN_00479FC0()` and
  `tank_manager+0x400 > DAT_005df590`; the exact meaning of both remains open (Q-0024 family).
  When applied, a threshold above `0x168` (360) is reduced by `difficulty(+0x14C) * 0x21C` (540),
  with a floor of 360.
  (3) **Pacing gate** (`Tank+0x500`): with it set, a starving fish (`fullness +0x9C < 0`) is
  rewound to `threshold - 0x5A` (90) when its counter has passed the threshold, and the call returns
  false; otherwise the plain `threshold <= counter` result is returned. Without the gate, a counter
  past the threshold is reset to 0 and the call returns false, so the drop is suppressed rather than
  emitted.
  (4) This pins the predicate and the counter/threshold rewinds. Which coin **kind** a
  species/stage emits is still not established (the virtual `FUN_00544430` call site elides its
  arguments): Q-0036. `FUN_004D7100` units are objective ticks; the P2.1/P2.7 rate question
  (Q-0034) is unchanged.

### EV-0156 - P2.2: `Fish::Update`'s default swim branch is the `mode >= 5` slow-hover/zigzag, not a fallback glide
- Date: 2026-11-02
- Type: observation
- Source: `docs/analysis/inputs/p2.2-fish-update-pseudocode.txt`, exported from
  `docs/evidence/p2.2-fish-4F6970.json` (`FUN_004F6970`, `procedure.pseudocode`), branch at
  `iVar10 < 5` / `else` (source lines 185-228) and the post-machine tail (lines 408-418)
- Confidence: high for the branch structure and float constants; medium for the `FUN_00564160`
  target-timer operand (see note 4)
- Notes:
  (1) The mode switch (`+0x1AC`) handles `0x7B`, then `0`-`4`, and sends every other value
  (**all modes >= 5**) to one shared default branch. Its per-tick body: if the dart timer
  (`+0x82`) is clear, `vy = -0.5` when `y >= 115`, else `vy = -0.1` (the double is
  `0xBFB999999999999A` = -0.1).
  (2) Every 40 ticks (`mode_timer > 0x27`) it resets the timer and runs a horizontal zigzag: with
  `turn_dir == +1`, `vx += 2.0` if `vx < 0` else `+1.0`; if `x > 250`, `turn_dir = -1` and
  `vx -= 2.0`. With `turn_dir == -1`, `vx -= 2.0` if `vx > 0` else `-1.0`; if `x < 175`,
  `turn_dir = +1` and `vx += 2.0`. The branch has **no** vertical glide subtraction (unlike modes
  0-4). This explains why the previously documented "...mode = 0 default" reading was wrong: any
  unlisted mode uses this branch, and mode 3/4's `y > 240 -> mode 0` is the only fallback.
  (3) The shared tail (all modes) increments `+0x1B0` and `+0x1B4`, and every `> 20` ticks resets
  `+0x1B4` and rerolls `mode = rand()%9 + 1` on a `rand()%10 == 0` roll. `FUN_004DA780` then
  suppresses slot `0x144` (coin scheduler, slot 81) while a target/food is pending.
  (4) The branch calls `FUN_00564160` (already established as the CRT float->int helper, EV-0118)
  to seed the target timer `+0x6F`; this decompile does not expose the float operand, so the P4
  placeholder uses `rand % 6`. Tracked as Q-0039.

### EV-0157 - P2.15: the font globals map 1:1 to the manifest ids
- Date: 2026-11-05
- Type: code trace (decompile) + manifest cross-check
- Source: `docs/evidence/p2.15-decompile-50E190.txt` (group `Register`),
  `docs/evidence/p2.15-decompile-506EA0.txt` (group `Init`), `resources/content.json` (the 15
  `FONT_*` entries and their native sizes)
- Confidence: high for the global -> id mapping; medium for which of the two selector preload ids is
  the 10 px font
- Notes:
  (1) Each font is loaded once and stored in a global. `FUN_0050E190` (Register) assigns:
  `DAT_005e8a28 = FONT_BLAMBOTPRO15`, `DAT_005e8ea8 = FONT_BLAMBOTPRO8`,
  `DAT_005e8ce4 = FONT_CONTINUUMBOLD12`, `DAT_005e8cd0 = FONT_CONTINUUMBOLD12OUTLINE`,
  `DAT_005e8b04 = FONT_CONTINUUMBOLD14`, `DAT_005e8d1c = FONT_CONTINUUMBOLD14OUTLINE`,
  `DAT_005e8a5c = FONT_JUNGLEFEVER12OUTLINE`, `DAT_005e8e18 = FONT_JUNGLEFEVER15OUTLINE`,
  `DAT_005e8dac = FONT_LIDDIE12`, `DAT_005e8bbc = FONT_LIDDIE15`, `DAT_005e8a9c = FONT_LIDDIE18`,
  `DAT_005e8c20 = FONT_TINY`, `DAT_005e8aa4 = FONT_TINYBOLD`. `FUN_00506EA0` (Init) assigns
  `DAT_005e8cf0 = FONT_JUNGLEFEVER10OUTLINE` and `DAT_005e8e40 = FONT_JUNGLEFEVER17OUTLINE`.
  (2) This resolves the earlier pointer citations: the StoreScreen's Shell counter font
  `DAT_005e8CE4` (P2.12 §6) is ContinuumBold12, and the "Please Wait..." / "Click Here To Continue"
  font `DAT_005e8a5c` (P2.12) is JungleFever12Outline.
  (3) The `GameSelector` ctor preloads `FUN_00505BD0(0x61/0x62)` (P2.12 §4/EV-0131) but the two
  preload ids are not resolved to a specific one of the two Init fonts, so assigning the 17 px
  outline to the art slots and the 10 px outline to the text buttons is the port's inference,
  recorded as Q-0059.

### EV-0158 - P2.10: the homing body `FUN_004FF4E0` and the on-target check `FUN_004FC070`
- Date: 2026-11-07
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.10-fn-4FF4E0.json` / `.txt` (homing),
  `docs/evidence/p2.10-fn-4FC070.json` / `.txt` (on-target), `docs/evidence/p2.10-fn-4FFB30.txt`
  (the caller that returns early when the homing body returns 1)
- Confidence: high for steering steps/caps/box tests; medium for the caller-visible flow
  (see notes on `FUN_004FC070`'s list scans)
- Notes: (1) `FUN_004FF4E0` reads the victim from `this+0x1A4`. When the victim is null or its
  `+0x98` is clear and `kind != 2`, it removes the shot (`FUN_004D80E0`, return 1); the
  `FUN_004D80C0` guard tests the shot's own kind in {3,4,5} and is unreachable for kinds 0/1,
  so the port expires directly (EV-0130). A deflected shot (`+0x190` set) skips steering to
  the on-target check. (2) Steering samples at `position + offset` (40 for the 80x80 kinds,
  25 for kind 2; kind 2 with a non-empty `Tank+0xF4` list also uses 40) and steps `vx`/`vy`
  by `0.2` toward caps of `1.8`. The wide bands (victim `+0x8C == 6`, the Ultravore type id)
  use a `+200` far edge and `+110` mid edge with inner targets `1.4`/`0.6` and a `0.1`-step
  vertical deadband at `+-0.2`; everyone else uses `+80`/`+60` with the same near caps and
  the same fine deadband. Steps overshoot by one increment when already near the cap (no
  clamp). (3) The on-target check (`FUN_004FC070`) tests the `+40` sample against the locked
  victim's box (`10..70` both axes; Ultravore `8..140` x `4..140`) and on a hit calls the
  victim's slot-77 consume, then returns 1 (the caller in `FUN_004FFB30` returns early).
  A kind-2 hit instead sets `+0x190`, clears the lock, sets the divisor to `1.5` and flips
  the velocity, returning 0 (the shot survives). (4) A deflected ball (kind 1, `+0x190` set,
  demo flag clear) scans aliens/boss (`+30..+140` x `+10..+150`, 30 damage, then remove) and
  the fish lists (slot-88 die / `FUN_004F3C60` / `FUN_004F2890` / `FUN_004DD5D0`, return 0,
  the ball flies on). The `Tank+0xF4`/`+0xB4`/`+0xB0` scans name head/entity lists the port
  does not model as separate entities; only the alien/boss and fish scans are implemented.
  (5) `FUN_004E8DF0` (P2.8 §8.2) returns the *farthest* eligible fish; no eligible fish means
  no shot, so `Alien._tick_shots` must hold the volley when the picker is empty. The type-0
  gate (`FUN_00500FF0`) is unrecovered and treated as always eligible.

### EV-0159 - P2.3: `FUN_004D62D0` is the bottom-of-tank lifetime setter (closes half of Q-0035)
- Date: 2026-11-08
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.3-fn-4D62D0.json` (the callee),
  `docs/evidence/p2.3-fn-4F22C0.json` (the shared per-tick helper, re-read for a `+0x190` writer)
- Confidence: high for the `+0x180` write; medium for the dropped `y` clamp (see 2)
- Notes: (1) `FUN_004D62D0` takes its object in `ECX` and its entire body is
  `if (this+0x180 < 1) this+0x180 = 0xf`. `+0x180` is `Food`'s lifetime counter (`[0x60]`, P2.3 §1),
  so step 8's remaining branch does not bounce, float or splash the pellet: it arms a **15-tick**
  life on an ordinary pellet that crossed the line, and step 3 then removes it when the counter
  reaches 0. Uneaten food therefore sinks out of the tank ~15 ticks after it passes y 410 (400 for a
  star potion, which is handled earlier by its own branch). (2) The `y = FUN_004D62D0()` reading in
  EV-0045 treats a **void** call as returning a float; no value is written by the callee, so the port
  drops the clamp and lets the pellet keep sinking. That part is an inference from the callee's body
  rather than an observed instruction, hence medium confidence - no bounce was found either. (3) The
  shared per-tick helper `FUN_004F22C0` decrements `+0x108`, `+0x10c`, `+0xf8` and `+0x120` and runs a
  hint/overlay counter at `+0x114`; it does **not** write `+0x190`, so the landed/bob entry is still
  unrecovered and Q-0035 stays open on that half (the writer sweep over the tank's food-list pass and
  `Tank::DropFood`'s non-click callers was still missing at that point; it is EV-0160).

### EV-0160 - P2.3: the `+0x190` landing flag has no writer outside the ctor (closes Q-0035)
- Date: 2026-11-08
- Type: code trace (module decompilation + xref sweep)
- Source: `docs/evidence/p2.3-fn-547610.json` (`Tank::Update`), `docs/evidence/p2.3-dropfood-xrefs.json`
  (the seven call sites), `docs/evidence/p2.3-fn-4D6290.json` (the pellet nudge),
  `docs/evidence/p2.3-fn-542EE0.json` (the post-ctor add-to-list helper),
  `docs/evidence/p2.3-food-4F8AA0.json` (the update body), `docs/evidence/p2.3-dropfood.json`
- Confidence: high for every function read; the residual gap is named in (5)
- Notes: (1) **`FUN_004D6290` is not a landing setter.** It sets `+0x185` (the *homing* flag), clears
  the bytes at `+0x55` and the `in_ECX+0x7C` int, and calls vtable slot `+0x98` with 0; the click test
  `FUN_00539F30` reaches it only for a pellet whose variant (`[0x65]`) is 2, i.e. clicking a breeding
  pellet vacuum-collects it toward (550,30). (2) **`Tank::Update` (`FUN_00547610`, 31 KB of
  pseudocode) contains no reference to `0x190`, `0x184` or `0x185` at all** - the tank's food pass
  never flips the flag - and `Tank::DropFood` (`FUN_00543280`) has none either. (3) `FUN_00542EE0`, the
  helper DropFood calls on the new object, is a dispatcher on the entity type id at `+0x8C` that adds
  the object to its tank list (`FUN_00540EC0`) and sets `+0x2A7`; no flag write. (4) `Food::Update`
  itself only **reads** `(char)[100]` (`+0x190`) and writes `+0x55`, `+0x5E`, `+0x5F`, `+0x56`,
  `+0x58`, `+0x60` and `+0x61` (`+0x184`). It also confirms EV-0159's reading: the bottom branch is
  `fVar7 = (float10)FUN_004D62D0(); y = (double)fVar7;` although the callee is `void`, so the assigned
  `y` has no defined value - the port keeps the pellet's own y (it keeps sinking) rather than copying
  an undefined x87 register. (5) **Conclusion (bounded negative):** the only writer of `Food+0x190` is
  the play ctor from `param_4`, and the click path passes `flag = 0`; a dropped pellet therefore never
  enters the bob - it falls, crosses the line, arms the 15-tick life and is removed. Unexamined and
  named as the residual gap: the other six `FUN_00543280` call sites (`0x4E4A42`, `0x4E4DEF`,
  `0x4E5DC8`, `0x4E5DDB`, `0x4FF2AA`, `0x543DC8`) and the save loader's type-`0x1C` branch. (6)
  Correction note: the `0x543441`/`0x54352E`/`0x5435F2` cluster recorded in P2.3 §2 is **not** in
  REA's xref list for `FUN_00543280`; the seven sites above are the observed ones.

### EV-0161 - P2.3: Angie's food re-lay is the one `flag = 1` caller (corrects EV-0160 note 5)
- Date: 2026-11-08
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.3-callsite-4FF2AA.json` (Angie's body `FUN_004FE740`),
  `docs/evidence/p2.3-callsite-4E4A42.json` (`FUN_004E4870`), `docs/evidence/p2.3-callsite-4E5DC8.json`
  (`FUN_004E5900`), `docs/evidence/p2.3-callsite-543DC8.json`
- Confidence: high for the branch and its arguments; the 5th argument's formal parameter is elided
- Notes: (1) **Correction to EV-0160 (5):** a caller does pass `flag = 1`. Inside Angie's body
  `FUN_004FE740`, at `0x4FF2AA`, behind the gate `FUN_004DA780() == 0 && [manager+0x87C] != 5`, the food
  list at `Tank+0xAC` is scanned for a pellet with `+0x18C == 0` whose sampled centres
  (`pellet+0x30/+0x34 + 0x14` against `Angie+0x158/+0x160 + 40`) are within **30 px** on both axes. On
  a hit it calls `FUN_004D9570()` (remove that pellet) and then
  `FUN_00543280(x, round(y), 0, 1, pellet+0x188)` - kind 0, **flag 1**, and the taken pellet's
  `+0x188`. (2) That re-drop is the only place the landed state is produced, and it is produced by the
  **ctor's** `param_4`, not by a later write - so Q-0035's question has an exact answer: nobody writes
  `Food+0x190`; Angie constructs a new pellet with it set. Such a pellet enters step 4's bob branch
  (`y >= 150 -> -8`, the 135/130/125/120 bands, then `+0x184 = 1` and it falls) instead of falling
  from the start, so it visibly floats up before sinking. (3) Every other caller passes 0: the click
  feed `FUN_004E4870` (0x4E4A42: `kind 0, flag 0`) and `FUN_004E5900` (0x4E5DC8/0x4E5DDB:
  `kind 1/2, flag 0`). (4) The port implements the branch as `Pet._angie_relay_food()` and
  `Tank.spawn_food(..., landed = true)`; the re-laid pellet keeps the taken pellet's `quality`.
  Which formal parameter receives the `+0x188` value is elided at the call site, so the note's
  param_5/param_6 split (P2.3 §2) does not settle it; the semantic - same quality - is what the port
  keeps.

### EV-0162 - P2.5: the coin draw binds image + sheet row per kind (closes Q-0057's coin row)
- Date: 2026-11-08
- Type: code trace (module decompilation) + byte read of the image-name literals
- Source: `docs/evidence/p2.5-coin-draw-4DD7A0.json` (sprite slot 26, `FUN_004DD7A0`, decompile
  exit 0); the handle names are the `PUSH <string>` operands immediately before each
  `MOV [handle], EAX` store, read from the module image at file offsets `0x10a4b4` (`0x5E8E60`),
  `0x10ba91` (`0x5E8D7C`), `0x10a50d` (`0x5E8D88`), `0x10a82f` (`0x5E8BD8`), `0x10a402`
  (`0x5E8BC4`), `0x10c263` (`0x5E8D04`), `0x10a7d6` (`0x5E8C50`)
- Confidence: high for the switch, the rows and the handles; the `+0x19C` head gate is read as
  written but cannot be shown to fire (see note 2)
- Notes: (1) **This replaces P2.5 §5's "Coin draw = slot 26 `0x4DD7A0` (unanalyzed)".** The draw
  reads `kind` `+0x194` once, calls `FUN_004D5360()` (the Virtual Tank predicate, P2.5 §5) and then
  blits **one cell** of a per-kind image with `FUN_00456980(image, dx, dy, column, row)`, where the
  column is the coin's own animation frame `+0x174` and the fourth/fifth arguments are bounded by the
  image's own column/row counts (EV-0163).
  (2) Head of the function: `FUN_004D6AE0()` (base draw), then a gate
  `((+0x19C & 0x7) > 7) && kind != 6 && kind != 7 && +0x198 == 0` -> draw nothing. The masked value
  cannot exceed 7, so the gate as decompiled never suppresses the draw; it is recorded, not modelled.
  The fade is `+0x178 != 0` -> additive blend with the colour `(255,255,255, +0x178 * 255 / 5)`.
  (3) Image handles, all named by their own load site: `0x5E8E60` = `IMAGE_MONEY`, `0x5E8D7C` =
  `IMAGE_SHELLS`, `0x5E8D88` = `IMAGE_MONEYBAG`, `0x5E8BD8` = `IMAGE_PEARL`, `0x5E8BC4` =
  `IMAGE_MISCITEMS`, `0x5E8D04` = `IMAGE_SPARKS`, `0x5E8C50` = `IMAGE_PEANUT`.
  (4) **Normal tank** (`FUN_004D5360() == 0`), `IMAGE_MONEY` unless stated, drawn at (0,0):
  0x01/0x08 -> row 0, 0x02/0x09 -> row 1, 0x03/0x0A -> row 2, 0x04/0x0B/0x05/0x0C -> row 3,
  0x07/0x0E -> row 4, 0x06/0x0D -> `IMAGE_PEARL` single cell, 0x0F -> `IMAGE_PEARL` single cell
  **only when `+0x198` != 0** (else nothing is drawn), 0x12 -> `IMAGE_PEANUT` single cell,
  0x11 -> `IMAGE_MISCITEMS` frame 0 at (0,0) plus `IMAGE_SPARKS` at frame `+0x174` and offset
  (10,-10), 0x10 -> the `+0x1A0` colour ramp over `0x5E8CF0`/`0x5E8E18` (still Q-0040 item 3).
  (5) **Virtual Tank** (`FUN_004D5360() != 0`), `IMAGE_SHELLS` at a (20,20) inset unless stated:
  0x01/0x08 -> row 0, 0x02/0x09 -> row 1, 0x04/0x0B/0x05/0x0C -> row 2, 0x06/0x0D -> row 3,
  0x07/0x0E -> `IMAGE_MONEYBAG` single cell at (18,18) with frame 0, and 0x03/0x0A keep
  `IMAGE_MONEY` row 2 at (0,0) - the switch never routes them to the shell sheet.
  (6) The insets are consistent with the art: `SHELLS` cells are 32x32 and `MONEYBAG` is 36x44, so
  (20,20) and (18,18) centre them in a 72x72 `MONEY` cell. The port draws all coin art centred on the
  entity, which reproduces the money/pearl/shell placement exactly and puts the bag 4 px high.
  (7) Port: `Coin.sprite_image()` / `Coin.sprite_row()`, drawn by `Level._draw_entity_frame` as
  `row * columns + column` with the sheet's own column count; `headless_coin_check` pins all 27
  bindings. Kinds 0x10/0x11/0x12 still draw `MONEY` cell 0 (their art is recorded here, not
  implemented), and the 0x0F `+0x198` gate is not modelled.
  (8) **Visible side effect, open:** the `MONEY` sheet's row 3 (the 200-value kinds) is shipped on an
  opaque blue plate, and `SpriteKey` only clears border-connected black, so the port now draws that
  plate with the diamond. Nothing recovered says the original keys a second colour, so the port does
  not key it; recorded as an open art question rather than a guessed colorkey. A windowed render with
  one coin per row (`0x01/0x02/0x03/0x04/0x07/0x06`) shows silver, gold, star, diamond, chest and
  pearl, i.e. rows 0..4 plus the pearl.

### EV-0163 - P2.5: `FUN_00456980` is a grid blit - (image, dx, dy, column, row)
- Date: 2026-11-08
- Type: code trace (module decompilation)
- Source: `docs/evidence/p2.5-coin-blit-456980.json` (`FUN_00456980`, decompile exit 0)
- Confidence: high
- Notes: (1) `void FUN_00456980(int image, dx, dy, int param_4, int param_5)` bails unless
  `param_5 >= 0 && param_4 >= 0 && param_5 < image[0x2C] && param_4 < image[0x30]` - i.e. the
  **5th** argument is the row (bounded by the image's row count) and the **4th** is the column
  (bounded by its column count). (2) It then sources `x = (image[0x24] / image[0x30]) * param_4` and
  `y = (image[0x28] / image[0x2C]) * param_5` - column times cell width, row times cell height - and
  calls `FUN_00455E40(image, dx, dy, &rect)`. So a cell is `row * columns + column` in the sheet's own
  grid, which is what the port computes from the manifest's `cols`. (3) The menu call recorded in
  P2.12 §`FUN_00531A60` (`(..., 0x28, 0x28, ([+0x28]/4) % 10, 2)`) is the same helper: a 0..9 digit
  column on row 2, which is only coherent with this argument order.
### EV-0164 - P2.2: slot 83 is per class - the draw row rule, the swim/eat/hungry sheets and the layered SIM style
- Date: 2026-11-09
- Type: observation (decompiled pseudocode, vtable bytes); inference (the table's `-0x10` offset,
  corroborated four ways)
- Source: REA decompiles `docs/evidence/p2.2-fish-draw-4DEA00.json` (Fish, `0x4DEA00`),
  `p2.2-fish-image-4D5AA0.json` (`0x4D5AA0`), `p2.2-draw-helper-5008F0.json` (`0x5008F0`),
  `p2.2-oscar-draw-4E2480.json` (Oscar, `0x4E2480`); slot-83 dwords read from the module image at
  the class vtables (Fish `0x597D54`, Oscar `0x59843C`, Gekko `0x5982C4`, Ultra `0x59872C`,
  SylvesterFish `0x5985BC`, BallFish `0x5988B4`, BiFish `0x598A24`); note
  `docs/analysis/notes/p2.2-tank-sim.md` §6
- Confidence: high for addresses, ids and the row rule; medium for what the table offset means
- Notes:
  1. **Every fish class overrides the sprite draw (slot 83)**, so the body art is a per-class
     decision: Fish `0x4DEA00`, Oscar `0x4E2480`, Gekko `0x4E17F0`, Ultra `0x4E3A10`,
     SylvesterFish `0x4E3420`, BallFish `0x4DB3B0`, BiFish `0x4DB9B0`. Slots 22 (Update) and 26
     (draw entry) stay shared, as P2.2 already recorded.
  2. Source rect: `srcX = +0x1C0 * 80`, `srcY = row * 80`, 80x80 cells. `FUN_005008F0` is only a
     cell blit of the drawable it is handed (EV-0165).
  3. **Fish row**: `stage <= 2` -> row = stage; `3` -> 2; `4` -> 3; `>= 5` -> the draw's second
     argument (the same value the blit receives). **Oscar row**: fixed `0x140` = row 4 at every
     stage (`FUN_004E2480` builds its source rect with `0x140`).
  4. **State sheet** (`FUN_004D5AA0(hungry)`), which returns a runtime-table index:
     `+0x1C4 != 0` -> `0xAB` / `0xAC`; `+0x1C8 < 1 && +0x108 < 0x65` -> `0xE2` / `0xB3`; else ->
     `0xAD` / `0xB1` (hungry second). The table carries 16 entries ahead of the first manifest
     image, so manifest image = index `- 0x10`: `0x9B` SMALLTURN / `0x9C` HUNGRYTURN, `0xD2`
     SMALLSWIM / `0xA3` HUNGRYSWIM, `0x9D` HUNGRYEAT / `0xA1` SMALLEAT.
  5. That offset is fixed by four strips the code walks as `base`, `base+1`, `base+2`: `0x9E..0xA0`
     = SIMTURN1..3, `0xA5..0xA7` = SIMEAT1..3 and `0xA8..0xAA` = SIMSWIM1..3 are each exactly
     `0x10` above their manifest indices, and `0x9B`/`0x9C` land on SMALLTURN/HUNGRYTURN.
  6. **The layered style** (`+0x1D0 != 0`, not hungry): Fish draws three passes of the `SIM` family
     for the current state - SIMSWIM1..3, SIMEAT1..3 or SIMTURN1..3 - onto the same 80x80 rect,
     tinted white, then `fish+0x1E8`, then `fish+0x1D8`. Oscar draws **four** passes of one 12-row
     sheet (`DAT_005e8b48`) at rows `iVar6+0..3`, `iVar6` = 0 swim / 4 eat / 8 turn, tinted white /
     `+0x1E8` / `+0x1D8` / `+0x1F8`. That is the assembly rule Q-0042 asked for: the `SIM` sheets
     are single-channel layers stacked with per-fish tints, not a body+eye composite.
  7. Extras in the same draw: stage 3 draws the body twice (alpha `0x9B`, then `200` or
     `(5-+0xA0)*200/5`); `+0xA0` in 1..5 draws the hungry sheet again as a white overlay at
     `(+0xA0*255)/5`; `+0x98 != 0` draws the shadow (`FUN_004D7040`); `FUN_004D6980(500)` adds
     `MISCITEMS` (`DAT_005e8BC4`) at y -5 (Fish) / -10 (Oscar); the `DAT_005e89CE` path draws
     column 6 (hungry) or 9 of `DAT_005e8AA8` at Oscar's row. A windowed render of one fish per row
     (guppy stages 0-4, a hungry guppy, an eating guppy, one carnivore) shows the five growing
     stages, both state sheets and the grey/red carnivore body on row 4.
  8. NOT established: the tint colours at `+0x1E8`/`+0x1D8`/`+0x1F8`; what `DAT_005e89CE` toggles
     (the tank ctor sets it from bit 4 of a config dword); the draw bodies of Gekko, Ultra,
     Sylvester, Ball and Bi (decompiling their slot-83 bodies did not complete); and whether
     `+0x1C4` is a latched facing (slot 26 reads it that way) or a transient turn state (the sheet
     test treats 0 as "not turning").

### EV-0165 - P2.2: `FUN_005008F0` is the cell blit of a drawable, not an image lookup
- Date: 2026-11-09
- Type: observation (pseudocode)
- Source: `docs/evidence/p2.2-draw-helper-5008F0.json` (`0x5008F0`)
- Confidence: high
- Notes: `FUN_005008F0(drawable, &dst, &src, flip)` blits one cell: it takes `FUN_004560A0(drawable,
  dst.x, dst.y, &src, flip)` when `dst.size == src.size` and `FUN_004561C0` (scaled) otherwise. The
  image travels inside the drawable `FUN_004D5AA0` returns, so one id selects both the sheet and its
  palette/colorisation. This narrows EV-0043's "colorize via `FUN_004d6f30` / `FUN_004d5aa0`":
  `FUN_004D5AA0` is the drawable, and the colourisation lives inside it.

### EV-0166 - P2.3: Q-0035 closed - every `Tank::DropFood` site and the tank's own food pass pass `flag = 0` except Angie
- Date: 2026-11-09
- Type: code trace (decompilation of the last two call sites + byte decode of the tank's own drop)
- Source: `docs/evidence/p2.3-callsite-4E4DEF.json` (`FUN_004E4C10`, call `0x4E4DEF`),
  `p2.3-callsite-543DC8.json` (`FUN_00543920`, call `0x543DC8`), `p2.3-callsite-4E4A42.json`
  (`FUN_004E4870`), `p2.3-callsite-4E5DC8.json` (`FUN_004E5900`), `p2.3-callsite-4FF2AA.json`
  (`FUN_004FE740`), `p2.13-decompile-547610.txt` (`Tank::Update` `FUN_00547610`, call `0x547DFD`, and
  the raw bytes at that site), `p2.13-decompile-546240.txt` (save body `FUN_00546240`)
- Confidence: high for every argument; the loader note is bounded by the body's own text
- Notes:
  1. The seven sites REA lists for `FUN_00543280(x, y, kind, flag, param_5, param_6)` and the fourth
     argument each passes:

     | site | enclosing body | kind | `flag` |
     | --- | --- | --- | --- |
     | `0x4E4A42` | `FUN_004E4870` (pointer click/feed) | 0 | 0 |
     | `0x4E4DEF` | `FUN_004E4C10` (its `+0x229`-gated twin) | 0 | 0 |
     | `0x4E5DC8` | `FUN_004E5900` | 1 | 0 |
     | `0x4E5DDB` | `FUN_004E5900` | 2 | 0 |
     | `0x4FF2AA` | `FUN_004FE740` (Angie's re-lay) | 0 | **1** |
     | `0x543DC8` | `FUN_00543920` | 0 | 0 |
     | `0x547DFD` | `Tank::Update` (`FUN_00547610`) | 0 | 0 |

  2. `0x4E4DEF` is `FUN_004E4C10`, the `+0x229`-gated twin of the click/feed body: same window
     (`30 < x < 587`, `60 < y < 400`), same `FUN_00539F30` hit test, same `FUN_00540B30` gate, and the
     same register setup (`uVar7 = 0` -> kind, `uVar8 = 0` -> flag, `iVar4` -> `param_5`,
     `uVar9 = -1` -> `param_6`). The only difference from `0x4E4A42` is the extra `Tank+0x229` gate.
  3. `0x543DC8` (`FUN_00543920`) is the tank's clicked-object body (`FUN_0046E3A0` base, `Tank+0x2A5`,
     `+0x2C8`, `+0x110`, `+0xBC`); it passes `(x-10, y-10, 0, 0, quality, -1)`.
  4. `0x547DFD` - the tank's **own** periodic drop inside `Tank::Update` - is the one site Ghidra
     prints with the arguments elided (the stack stores it shows at `iStack_a0`/`iStack_a4` are the
     `x-10`/`y-10` half and the return-address marker). The bytes at the call site decode to
     `6a ff | 6a 14 | 6a 00 | 6a 00 | 8d 43 f6 / 50 | 83 c7 f6 / 57 | 8b ce | e8 7e b4 ff ff`, i.e.
     `push -1` (param_6), `push 0x14` (`param_5 = 20`), `push 0` (**flag = param_4**), `push 0`
     (kind 0), `push ebx-10` (y), `push edi-10` (x), `mov ecx,esi`, `call 0x543280`. Its gate is
     `Tank+0x13B != 0` + `FUN_0046CCE0() != 0` + `[Tank+0x111] % (0x10 - DAT_005DF58C) == 0` +
     `[Tank+0xF0] + 200 < now` + the `0x1F..0x24B`/`0x3D..0x190` window, so it is the scripted/attract
     feed: periodic, quality 20, and still `flag = 0`.
  5. The save path cannot produce one either: the body `FUN_00546240` contains no reference to `0x190`
     and rebuilds each entity by calling its class's slot `0x140` `Serialize` (EV-0063), so a load
     restores fields at most and never runs a fall-to-land transition. The port does not persist food
     at all (the save note in `DECISIONS.md`), so nothing there can drift.
  6. Conclusion: `Food+0x190` still has exactly one writer (the play ctor's `param_4`, EV-0045) and
     exactly one `flag = 1` caller (Angie, EV-0161). **A dropped pellet never lands and never bobs**:
     it falls at 1.5, crosses the death line, arms its 15-tick life and is removed (EV-0159). The port
     already does this, so no code change follows from this sweep; "land then bob" is a deviation from
     the recovered code, not a missing feature. This closes the residual gap named in EV-0160 (5) and
     EV-0161.

### EV-0167 - P2.5: the 0x11 coin draws `MISCITEMS` + the `SPARKS` overlay; 0x12's `PEANUT` art is blank in the shipped data
- Date: 2026-11-09
- Type: code change against EV-0162's recovered switch + data check of the extracted images
- Source: `EV-0162` note (3)/(4) (the special kinds' images and the overlay's offset), `resources/content.json`
  entries for `MISCITEMS` (3x1), `SPARKS` (5x1) and `PEANUT` (1x1, `assets_raw/images/blank.png`),
  `docs/analysis/notes/p3-assets.md` P3.3 ("PEANUT=blank"), `scripts/entities/coin.gd`,
  `scripts/tank/level.gd` (`_draw_sparks`), `tests/headless_coin_check.gd`
- Confidence: high for the binding and the overlay; the Virtual Tank behaviour of 0x11 is unverified
- Notes: (1) **Implemented:** kind `0x11` (Shrapnel's drop, `Pet.SHRAPNEL_DROP`) now draws
  `IMAGE_MISCITEMS` cell 0 and overlays `IMAGE_SPARKS` at `(10,-10)`, stepping the sparks with the
  coin's own animation column - exactly EV-0162 note 4's `MISCITEMS` frame 0 plus `SPARKS` at frame
  `+0x174`. `Coin.sprite_image()`/`sprite_row()`/`draws_sparks()` carry the binding and
  `Level._draw_sparks` creates the second sprite on demand. (2) **0x12 not wired, deliberately:**
  the recovered switch names `IMAGE_PEANUT`, but the shipped `PEANUT` resource is the blank 1x1
  placeholder (P3.3 deduped it to `blank.png`), so drawing it would make Nostradamus' snot invisible;
  the coin keeps the `MONEY` cell-0 fallback and the mismatch is logged in Q-0057. (3) **Virtual Tank
  unverified for these kinds:** EV-0162 note 5's virtual branch lists only `0x01..0x0E`, so 0x11/0x12
  keep `MONEY` cell 0 there and `draws_sparks()` is false; the port does not guess. (4) Kind `0x10`
  stays on the fallback because its `+0x1A0` colour ramp is unrecovered (Q-0040 item 3). (5) Pinned:
  `headless_coin_check` 143 -> 151 assertions (image, row, overlay flag and offset for 0x11, the 0x12
  fallback, and both Virtual Tank guards). Not visually inspected: the overlay's placement was
  verified against the recovered `(10,-10)`, not by eye.

### EV-0168 - P2.2: the eye-layer tint colours are runtime data, not module constants (Q-0042's last half closed)
- Date: 2026-11-09
- Type: bounded negative (whole-image byte scan) + code reading
- Source: `docs/analysis/snapshots/insaniquarium-game-module.exe` (whole-file scans for every store form
  into `+0x1D8`/`+0x1E8`/`+0x1F8`), `docs/evidence/p2.2-fish-draw-4DEA00.json`, `p2.2-oscar-draw-4E2480.json`,
  `docs/analysis/notes/p3-assets.md` P3.3, `resources/content.json`, `assets_raw/`
- Confidence: high that no literal colour reaches those fields; the values themselves stay unknown
- Notes:
  1. **Shape confirmed.** Both draw bodies set the tint with `FUN_004D6DB0(graphics, colour_ptr)`:
     `FUN_004DEA00` passes `&DAT_005EC478` (the shared white) and then `in_ECX + 0x1E8` /
     `in_ECX + 0x1D8`; `FUN_004E2480` adds `in_ECX + 0x1F8`. The same call is handed
     `CRect::CRect(&local_38, 0xff,0xff,0xff,0xff)` and the hit-flash `(255,255,255,(+0xA0*255)/5)`
     rect, so each field is a 4-byte colour, not an image id or a sheet index.
  2. **Scan.** Across the whole image, every `C7 /r` store (`mov dword [reg+disp32], imm32`) whose
     displacement is one of the three offsets writes a small integer, never a colour:
     `0x4EDE73` -> `0x0C` and `0x4EDEF7` -> `0` (`+0x1E8`), `0x4ED337` -> `0x14` and `0x4E8685` -> `0x32`
     (`+0x1D8`), `0x46CB61` -> `0x3D` (`+0x1F8`). The `89 /r` form has only register copies
     (`0x4F4D27`, `0x52B883`, `0x52B99F`, `0x54CDFA`, `0x571AA3`) and `C6 /r` has one byte store
     (`0x4A71EF`, `0xBF` at `+0x1F8`). No site in the module writes a colour constant into these fields.
  3. The small-integer stores are recorded but not attributed: the offsets collide across classes, and
     the functions containing them were not decompiled.
  4. The runtime colour table is empty in the file - `PTR_DAT_005e0a10` is zero for the colourised
     indices 0xAB..0xE2 (P3.3) - and neither `assets_raw/` nor `resources/content.json` ships a palette
     or ramp image: the `SIM` family is greyscale art with `_`-prefixed mask companions.
  5. **Conclusion.** The assembly rule is fully recovered (three layers for Fish, four for Oscar, the
     layer order, white for the first, and the tint pointer per layer), but the three tint colours are
     supplied from runtime state that the shipped artifacts do not contain. The port therefore does not
     composite the layered path: any colour it chose would be invented. Finishing it needs a runtime
     capture (a memory read of the four bytes at each field while the draw runs), which this evidence
     base cannot produce.
  6. The rest of Q-0042 is implemented and pinned: sheet pick, stage rows, per-class fixed row, the
     hungry/eat/turn transitions and corpse rows (EV-0164), `headless_fish_check` 121 assertions.

### EV-0169 - P2.3: the save loader's type-`0x1C` branch constructs Food with the bare ctor, never a flag (closes Q-0035's last residual)
- Date: 2026-11-09
- Type: code trace (existing factory/reader decompilations re-read against Q-0035)
- Source: `docs/evidence/p2.3-site-5375CD.json` (factory `FUN_00537570`), `docs/evidence/p2.4-site-537B1E.json`
  (object reader `FUN_00537B00`), `docs/evidence/p2.13-decompile-546240.txt` (tank body `FUN_00546240`),
  `docs/evidence/p2.3-callsite-4E4DEF.json`, EV-0044/EV-0063/EV-0166
- Confidence: high for the branch and its constructor; whether Food's own slot-`0x140` serializer carries
  `+0x190` is not established and is noted as such
- Notes: (1) **The branch.** `FUN_00537570`'s switch has `case 0x1c:` -> `FUN_00564345(0x1a0, cookie)`
  (allocates `0x1A0` bytes) -> `FUN_004EF820()`. That is the **bare** Food constructor; the play
  constructor `Tank::DropFood` uses is `FUN_004EF840(x, y, kind, flag, param_5)` (P2.3 §2, EV-0045),
  which is the only place `flag` exists at all. No argument is passed on this path, so a load cannot
  choose `+0x190`. (2) **The reader.** `FUN_00537B00` reads a `u32` id, skips 4 bytes, calls the factory,
  throws `Sexy::DataReaderException` on an unknown id, then calls the new object's slot `0x140`
  (`Serialize`) - so any field a loaded pellet gets comes from its own serialized record, never from a
  fall-to-land transition. (3) The tank body `FUN_00546240` itself contains no reference to `+0x190`
  (EV-0166 note 5). (4) **Conclusion:** combined with EV-0166's seven call sites, every path to a Food
  object is now accounted for - two gameplay constructors (`FUN_004EF840` with `flag`, `FUN_004EF820`
  bare) plus the loader that uses the bare one - and exactly one caller (Angie) passes `flag = 1`.
  Dropped pellets therefore still fall and sink out; the loader cannot change that, and the port does
  not persist food at all. Q-0035 has no residual left.

### EV-0170 - P2.5: kind 0x12 draws the recovered `PEANUT` image (supersedes EV-0167 note 2's fallback)
- Date: 2026-11-09
- Type: code change against EV-0162's recovered switch + data check of the extracted image
- Source: EV-0162 note (3), EV-0167, `resources/content.json`'s `PEANUT` entry (107x34,
  `assets_raw/images/blank.png`), `docs/analysis/notes/p3-assets.md` P3.3 ("PEANUT=blank"),
  `scripts/entities/coin.gd`, `tests/headless_coin_check.gd`
- Confidence: high for the binding; the art it resolves to is the shipped blank placeholder
- Notes: (1) **Implemented:** kind `0x12` (Nostradamus' snot) now returns `IMAGE_PEANUT` from
  `Coin.sprite_image()` with `sprite_row() == -1`, so `_draw_entity_frame` blits its single cell
  instead of `MONEY` cell 0. `0x11` stays on `MISCITEMS` + the `SPARKS` overlay at (10,-10).
  (2) **Deliberate invisibility:** the recovered `PEANUT` is the dedicated blank 107x34 image in the
  shipped data (P3.3 deduped it to `blank.png`), so the snot draws nothing. This replaces EV-0167
  note (2)'s visibility-first fallback: the recovered binding is now followed, and the resource gap is
  recorded instead of hidden behind a coin sprite. (3) **Virtual Tank unchanged:** EV-0162 note 5's
  virtual branch covers only `0x01..0x0E`, so 0x11/0x12 keep `MONEY` cell 0 there and
  `draws_sparks()` is false. (4) Pinned: `headless_coin_check` 151 -> 154 assertions (0x12's image,
  row and overlay flag, plus both Virtual Tank guards). Not visually inspected: a blank sprite has no
  pixels to view.

### EV-0171 - P4.5: the in-tank store bar is the shipped `MENUBAR` art (640x75)
- Date: 2026-11-09
- Type: asset binding + measured geometry against the extracted art
- Source: `resources/content.json`'s `IMAGE_MENUBAR` entry (640x75,
  `assets_raw/images/menubar.png`); `docs/analysis/inputs/p2.15-loadingthread-ids.txt` line 87
  (`0x509dce "IMAGE_MENUBAR"`); `docs/evidence/p2.13-decompile-5409B0.txt` (the widget rect and
  the `local_14 < 0` early return); EV-0135 (the `SOLD` branch is the StoreScreen refresh)
- Confidence: high for the art and the slot alignment; the screen it mounts on is an inference
  (the 640x75 strip and its seven dome x positions match the recovered widget table)
- Notes: (1) **Art binding:** `MENUBAR` is the tank-top strip - seven item domes with purple
  price plates, the MENU button and the green `$` wallet plate. The seven recovered x values
  (0x12/0x57/0x90/0xD9/0x122/0x16B/0x1B4) sit exactly 7 px inside the plates measured in the art
  (25..69, 94..138, 151..195, 224..268, 297..341, 370..414, 443..487 at y 55), so the recovered
  widget rects are the bar slots. (2) **Empty is empty:** `FUN_005409B0` returns null when the
  item's store slot is negative, so an unstocked slot has no widget at all. The port leaves the
  dome empty; it does not draw `SOLD`. That literal is the StoreScreen's sold-out branch
  (EV-0135), not an empty tank slot. (3) **Wallet:** the green plate spans x 530..621,
  y 39..58, so the tank's money is drawn there instead of in the HUD line. (4) Still unrecovered
  (Q-0054): the per-kind item art and slot 7's x; the port draws the item name in the dome and
  the price on the plate. Pinned: `headless_store_ui_check` 40 assertions and
  `headless_integration_check` 40.

### EV-0172 - P4.6/P4.5: the egg is the seventh `MENUBAR` dome, not a bottom-right widget (R3)
- Date: 2026-11-10
- Type: asset binding + port placement (owner review)
- Source: `assets_raw/images/eggpieces.png` (138x39, three 46x39 cells); the `MENUBAR` dome x table
  in EV-0171 (`FUN_005409B0`); `Progression.EGG_PRICES`/`STORE_TABLE` (the tank-5 egg is the free
  row at slot 6); `scripts/ui/egg_widget.gd`, `scripts/ui/store_bar.gd`,
  `scripts/tank/level.gd:_mount_egg_widget`; captures `shot_level.png`, `shot_tank5_bar.png`
- Confidence: high for the art, the cell and the free-price row; the placement inside the dome is a
  port fit (the original widget rect is unrecovered, Q-0053)
- Notes: (1) **Why the earlier widget was invisible:** it was a `Node2D` child of the level, and the
  bar lives on a `CanvasLayer`; `z_index` cannot cross layers. `Level._mount_egg_widget()` now
  `reparent()`s it into the `Hud` layer after the bar, so it draws over the seventh dome on every
  tank. (2) **Tank 5:** `StoreBar` keeps row 6 (the free egg) for the click data but blanks the
  dome's name/price text, and the widget draws `FREE` on the same purple plate. The 0 is a recovered
  price, not the unknown marker. (3) **Readout:** the `EGGPIECES` cells replace the old
  "EGG n/4" text and the price sits on the plate; the port-only "Egg/Fish/Food/Weapon" info line and
  its `Level._update_hud` were deleted. (4) Pinned: `headless_progression_check` 86,
  `headless_integration_check` 60 (the widget's dome position and `FREE`).

### EV-0173 - P4.14: the menu mermaid's `MERYLTAIL` overlay is drawn with its alpha mask (R10)
- Date: 2026-11-10
- Type: asset binding + port placement (owner review)
- Source: `assets_raw/images/tailflop.png` (1904x165, eight 238x165 cells);
  `assets_raw/masks/tailflop_.png` (same dimensions); `MERYLTAIL`'s resources.xml metadata
  (`anim="once"`, `framemap="7,6,5,4,3,2,1,0"`, `framedelay="2"`, `begindelay="3"`);
  `scripts/ui/game_selector.gd`; capture `shot_menu.png`
- Confidence: high for the sheet, the mask, the playback and the composite; the screen offset and
  mirror are a port fit (Q-0055)
- Notes: (1) The old green strap was the unmasked sheet - its field is opaque green, so compositing
  `tailflop_.png` through `MaskAlpha.apply()` is what makes the tail transparent. (2) The overlay is
  mirrored (`TAIL_FLIP`) and parked at (120,268) so the dark cell wraps the backdrop's pale baked
  tail instead of leaving two tails; cell 0 is the rest pose because the recovered flop ends on it.
  (3) The sheet is loaded through its imported texture and `get_image()` (F1), never
  `Image.load_from_file`. (4) Pinned by `headless_menu_check` 28 (cell size, begin delay, two-tick
  cells, return to rest).

### EV-0174 - P4.4: `_sync_fx`'s trim loop froze the rendered level; detaching first fixes it
- Date: 2026-11-10
- Type: runtime observation + code analysis
- Source: `scripts/tank/level.gd:_sync_fx`; `tests/headless_render_check.gd` (17 assertions);
  the frozen windowed capture run exited with `-805306369`
- Confidence: high for the cause and the fix; the freeze is reproducible by expiring any effect
  (the click laser spark lives five ticks)
- Notes: (1) The old trimmer was `while _fx_layer.get_child_count() > wanted.size():
  get_child(...).queue_free()`. `queue_free()` only queues: the node stays a child until the frame
  ends, so the count never shrank and the loop never returned, hanging the main thread. (2) The fix
  copies the children into a working array, `remove_child()`s each surplus dot, then `queue_free()`s
  it; the same array feeds the grow loop and the per-dot update. (3) `headless_render_check` drives
  the pool both ways and pins that a freed dot is detached immediately; the freeze and its cause are
  summarized in the `PLAN.md` 2026-11-10 addendum.

### EV-0175 - P4.6: the Hatch card draws `HATCHSCREEN`, the crack strip and the pet cell through `MaskAlpha`
- Date: 2026-11-10
- Type: asset binding + port timing
- Source: `resources/content.json` `IMAGE_HATCHSCREEN` (640x480, 1 cell),
  `IMAGE_HATCHANIMATION` (3x1 cells 57x60, `SpriteFrames`);
  `assets_raw/masks/_HatchANIMATION.png` (171x60) and `assets_raw/masks/_presto.png` (800x240);
  `scripts/ui/hatch_screen.gd`; captures `shot_tank5_award.png`, `shot_tank5_hatched.png`
- Confidence: high for the art, the cell grid and the masking; the crack hold is a port choice
  (Q-0060)
- Notes: (1) `HATCHANIMATION`'s field is brown (~132,92,42), not black, so `SpriteKey.keyed()` (which
  clears only black connected to the cell border) leaves a box; `MaskAlpha.apply()` uses the mask's
  luminance and clears it. (2) `Content.texture()` is the first cell only, so the crack uses the
  `SpriteFrames` sequence; each cell is composed from its `AtlasTexture` region, not the whole strip.
  (3) The pet cell uses the same per-cell composition with the pet's own `masks/_<name>.png`; the
  mask path is probed as `_<file>` then `<stem>_` (the extracted set has both conventions). Brinkley
  has no mask and keeps the colour-key fallback. (4) The crack is three 0.3 s holds and the pet
  appears at 0.9 s (Q-0060); `Please Wait...`/`Menu` keep the id-99/id-100 rects. (5) Pets and Bonus
  remain text-only.

### EV-0176 - P4.6: the 5-1 completion walk banks the tank-5 bonus once and keeps the menu down
- Date: 2026-11-10
- Type: implementation + test evidence
- Source: `scripts/main.gd:_on_level_completed`/`_process`; `tests/headless_integration_check_scene.gd`
  (60 assertions); `docs/PLAN.md` R8/§5d
- Confidence: high for the tested path; the live timing/feel remains the owner's R8 playtest
- Notes: (1) `Main._process` mounted the selector whenever `_level` was null, so the menu appeared
  behind Hatch/Pets/Bonus; the `_flow` guard keeps it down until the between-level screens finish.
  (2) The tank-5 5000-shell win bonus was computed for the card but never banked; adventure now
  credits it once in `_on_level_completed` (Time Trial and Challenge already bank their reward in
  `Level.complete_level`). (3) The integration suite walks the free egg dome (3 -> 4 pieces, no
  money), Presto's grant, the 5000 + 5000 Shells, profile 5-2/`bonus_adventure`/`tank5_wins = 1`,
  then Hatch -> Pets -> Bonus -> 5-2.

### EV-0177 - P4.7 Wadsworth (R9): the shelter state, the tank globals and the fish follow
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/entities/pet.gd` (`_wadsworth_hide`, `set_sheltering`, `_clear_shelter`, `cleanup`);
  `scripts/tank/tank.gd` (`wadsworth_count`, `wadsworth_mouth`); `scripts/entities/fish.gd`
  (`is_sheltering`, `_steer_to_shelter`); binary source EV-0090, P2.7 §4.10, P2.3 §6, EV-0144
- Confidence: high for the state, the globals, the fish predicate and the cleanup; the hide toggle and
  the mouth offset are port bindings (D-0013)
- Notes: (1) `+0x250` is `Pet.sheltering` - the natural name `hidden` collides with `Node2D.hidden`.
  (2) While set he increments the tank's hidden count and publishes `position + (40,40)` as the mouth;
  that write runs before his own steer step, so the point trails one tick of movement. (3) The fish
  side reproduces `FUN_004F6970`'s top branch exactly as the note gives it - count non-zero, `+0x229`
  (`can_seek`) and `stage <= 1` - and steers to the mouth with the ±5/3/1 ladder *instead of*
  `_find_food`; the bands reuse the 5/10 px pair the food approach already uses, because P2.3 §6 gives
  the three steps and the target but not the band distances. (4) `FUN_004D6250`'s half is
  `Pet.cleanup()`, reached from `despawn()`, `_exit_tree()` and Presto's swap: hidden count -1 clamped
  at 0, and the mouth cleared at 0. (5) `headless_pet_check` 73 -> 113 assertions.

### EV-0178 - P4.7 Gumbo (R9): opposite-corner steering and the `+0x258` glow
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/entities/pet.gd` (`_steer_to_corner`, `_gumbo_glow`); binary source EV-0093,
  P2.7 §4.13
- Confidence: high for the thresholds and the glow; the corner points are a port fit
- Notes: (1) `FUN_004E02D0` compares the nearest hostile against x 291/330 (0x123/0x14A) and y 261/300
  (0x105/300); between a pair the current coordinate is kept, so he commits only once the alien is
  clearly past a threshold. The target corner is not a recovered literal - the far tank bounds
  (x 540/10, y 400/60) stand in for it. (2) The glow is maintained in `_advance`, **not** `_slot81`:
  `FUN_004E9790`'s alien gate closes slot 81 for every pet but Stanley, which is exactly the state
  that lights the glow. The first implementation put it in `_slot81` and `headless_pet_check` caught it.
  (3) The wiki's fish lure stays disabled: EV-0093 found no branch that redirects guppies/breeders.

### EV-0179 - P4.7 Blip (R9): the instant store unlock
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/entities/pet.gd:_blip_unlock`; `scripts/tank/tank.gd` (`store_locked`, `age_ticks`);
  `scripts/tank/level.gd` (`_on_pet_unlock`, `_on_sim_tick`, `start_level`);
  `scripts/progression/progression.gd:store_rows(include_hidden)`; binary source EV-0094, P2.7 §4.14
- Confidence: high for the gate and the thresholds; the unlocked row set is a port binding
- Notes: (1) `Tank.store_locked` is the port's `Tank+0x2E0 < Tank+0x2DC` and is seeded from
  `Progression.hidden_items` at `start_level`; `Tank.age_ticks` is `+0x444`, incremented once per
  `Level._on_sim_tick` and reset at level start. (2) The unlock fires once, at age > 200 (5.5 s), or
  > 0x2D0 (720) when a transformed Presto runs the body. (3) `FUN_005409B0(i, 1)` for every item is
  bound to rebuilding `tank_store` from `Progression.store_rows(..., include_hidden = true)`; the
  level-locked shelves appearing is the port's reading of "every store item". (4) The wiki's hunger
  arrows, entrance radar and HP meters are not in the body (EV-0094/EV-0106) and stay unimplemented.

### EV-0180 - P4.7 Presto (R9): the transform, the recharge and the cleanup
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/entities/pet.gd` (`can_transform`, `transform_to`, `cleanup`, `recharge`);
  `scripts/tank/tank.gd:spawn_pet(transformed)`; `scripts/tank/level.gd:_on_pet_transform`;
  binary source EV-0100, P2.7 §4.20/§7.7
- Confidence: high
- Notes: (1) `+0x238` is 360 on a normal pet and 0 on Presto itself, set in `Pet.create`; it counts
  down in `_advance` and `FUN_004F2650(+0x238) < 1` is `can_transform()`. (2) `FUN_004F89A0`'s order is
  kept: ignore a same-index target, gate on the recharge, run the `FUN_004D6250` cleanup, ask, then
  leave - `transform_requested` is what spawns. (3) `Level._on_pet_transform` spawns the target
  through `Tank.spawn_pet(index, at, true)` so it is a normal body of its own index with `transformed`
  set and the inherited 360 recharge, then rewires every signal. (4) Sound 0x122 has no `SOUND_*`
  binding (Q-0030), so only the semantic `transform` cue is emitted; the "Recharging..." label and the
  `FUN_0054C6F0` picker stay UI work. (5) Walter's `+0x260/+0x264` punch state is not carried because
  no glove entity exists yet (Q-0044).

### EV-0181 - P4.7 Presto's "CHANGE-O" picker: the dialog, its roster binding and the gate
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/ui/presto_picker.gd`; `scripts/tank/level.gd` (`presto_pet`,
  `can_open_presto_picker`, `open_presto_picker`, `close_presto_picker`, the `KEY_P` binding);
  `tests/headless_profile_check.gd` (44 assertions); binary source EV-0100, P2.7 §3.3/§4.20
- Confidence: high for the dialog identity, the screen id and the recharge gate; the roster contents
  and the opening input are port bindings (Q-0061)
- Notes: (1) `FUN_0054C6F0` builds a `Sexy::PetDialog` (0x2F8 bytes) through `FUN_005355C0` and
  pushes screen id 0x1F; the dialog's name is the note's "PRESTO CHANGE-O" and is now its title.
  `PrestoPicker` is a modal `Control` in the `Screens` single-dialog slot, so the tank pauses while it
  is up exactly like the shop. (2) The picker's contents were never enumerated, so the port lists the
  **owned** pets minus the current index (the wiki's "every unlocked pet" is the only statement about
  it); `press()` refuses unowned and same-index picks, and `FUN_004F89A0` does the rest through
  `Pet.transform_to` (EV-0180). (3) The gate is `FUN_004F2650(+0x238) < 1`:
  `can_open_presto_picker()` needs a live Presto with a spent recharge and a free dialog slot, so
  "Recharging..." is the refusal reason rather than a timer this dialog draws. (4) The opening input
  was not traced (EV-0106), so `Level` binds the port-only `P` key beside its existing `S` shop key;
  the wiki's right-click binding stays unbound. (5) A swap spawns the target transformed through
  `Level._on_pet_transform`, then the picker closes and the tank resumes; `headless_profile_check`
  29 -> 44 assertions.

### EV-0182 - P4.7 the "Recharging..." notice over Presto (R9 follow-up)
- Date: 2026-11-10
- Type: implementation + test evidence (no new binary analysis)
- Source: `scripts/tank/level.gd` (`show_presto_recharging`, `_tick_presto_notice`,
  `_sync_presto_notice`, `PRESTO_NOTICE_OFFSET`, `PRESTO_NOTICE_TICKS`);
  `tests/headless_profile_check.gd` (56 assertions); binary source EV-0100, P2.7 §3.3
  (`FUN_004F89A0`, `FUN_004F2650`)
- Confidence: high for the literal and the anchor; the 90-tick dwell is a port choice
- Notes: (1) `FUN_004F89A0` draws "Recharging..." at `(x + width/2 - 20, y - 10)` when
  `FUN_004F2650(+0x238)` has not run out, so the notice belongs to a **refused attempt**
  (`Level.open_presto_picker` with a recharging pet), not to a permanent readout. The pet box is the
  80x80 pet sheet, so the anchor is `position + (20, -10)`. (2) It is a `Label` on the level's `Hud`
  CanvasLayer - the layer the store bar and egg widget draw on, and the only one that can draw over
  the tank's Node2Ds - created on first use and freed on clear. (3) The original's own dwell is not
  recovered; the port keeps the text 90 ticks (2.5 s at the 36 Hz reading, Q-0034) so a key press is
  readable. A dead or freed pet clears it at once, and it is skipped entirely when rendering is off.
  (4) `headless_profile_check` 44 -> 56 assertions: the literal, the anchor, following the pet, the
  refusal path, a ready pet raising nothing, and expiry.

### EV-0183 - R9 UI capture: the picker and the "Recharging..." notice, windowed
- Date: 2026-11-10
- Type: visual evidence (windowed run) + one implementation fix
- Source: `tools/godot/shot_presto.gd` (run with `--audio-driver Dummy`); captures
  `shot_presto_picker.png` and `shot_presto_recharging.png` (1280x960: the 640x480 viewport under
  `canvas_items` stretch); `scripts/ui/presto_picker.gd`
- Confidence: high for what the two frames show
- Notes: (1) The picker opens through the real path (`Level.open_presto_picker` -> `Screens.dialog`)
  over tank 1 level 3 with five owned pets, and draws its title, hint, pet buttons and Cancel inside
  the panel. The **first** capture put the buttons at the screen origin, overlaying the store bar,
  because they were parented to the picker instead of the panel; the frame caught it and they are now
  panel children, with the re-capture showing the list in place. (2) A refused attempt with `+0x238`
  running put "Recharging..." at (320,220) for a Presto parked at (300,230) - `position + (20,-10)`,
  the recovered `x + width/2 - 20, y - 10` for the 80 px box - and it stayed over the pet for the 10
  captured frames. (3) The stage is the port's real tank screen: `MENUBAR` shop row, egg dome, fish
  and backdrop from the extracted art, with the debug FPS/tick overlay still on (R2's dev aid).

### EV-0184 - R4: the tank bar is a `MenuButtonWidget` row - image plus green price, sized and measured
- Date: 2026-11-10
- Type: decompile + measured art + windowed visual
- Source: `docs/evidence/p2.12-fn-5409B0.json` (`FUN_005409B0`),
  `docs/evidence/p2.12-fn-5373C0.json` (`FUN_005373C0`), `assets_raw/images/menubar.png`;
  `scripts/ui/store_bar.gd`, `scripts/ui/egg_widget.gd`; captures `shot_bar_tank1.png` (1-3) and
  `shot_bar_tank5.png` (5-1)
- Confidence: high for the widget class, the green label colour, the 58-px width and the plate/wallet
  rects; medium for the 60-px height (pushed argument order) and for the per-item icon binding (the
  `SCL_*` sheets are the shipped 40-px creature icons, but the original's own image id `0xBC` was not
  resolved)
- Notes: (1) `FUN_005409B0` resolves `Tank+0x2E4 + i*4` (negative = no row), caches
  `Tank+0x404 + slot*4`, and builds through `FUN_005373C0(manager, i, listener)`, which chains the
  `FUN_00475090` image-button ctor, installs `Sexy::MenuButtonWidget::vftable`, stores the item id at
  `+0x188`, a 60-px label width at `+0x190`, zeroes `+0x124/+0x138/+0x13C`, loads image
  `FUN_00564345(0xBC)` into `+0x120`, and writes the green `FUN_00433360(0x6E,0xFA,0x6E)` into its
  label colour. So the tank button is an **image + price**, not the StoreScreen's kind-switching
  `StoreButtonWidget`; the port's name text in the dome was the stand-in this replaces.
  (2) The `vtable[0xA0]` call pushes `0x3C, 0x3A, 3, x`, i.e. `Resize(x, 3, 58, 60)`; the width is
  confirmed by the art (the 45-px plates then leave 7 px on both sides), and the earlier 60x58 was
  the same push order read in reverse. (3) `MENUBAR` measures: purple plates at x 25..69
  (+69 per slot, matching the recovered slot x's + 7) and y 48..59, i.e. (7, 45, 45, 12) slot-local;
  the green wallet plate spans 530..621 x 39..58. (4) Icon binding: the shipped 40x40 `SCL_*` sheets
  cover carnivore/Ultravore/Starcatcher/Guppycruncher/Beetlemuncher/breeder, `FOOD` the two food
  rows, `LASERUPGRADES` the weapon (cell = weapon level) and `SMALLSWIM` the guppy (the `SIM*` sheets
  are eye-only, Q-0042). Every sheet is composed through `MaskAlpha`/`SpriteKey`; the star potion
  ships no matching icon and keeps the price only. (5) The egg is fitted into a 40x34 window inside
  its dome and its price uses the same measured plate, so it no longer spills over the rim.
  (6) `headless_store_ui_check` 40 -> 43, `headless_integration_check` 60, totals **24 suites, 1333
  assertions**.

### EV-0185 - R4: the bar never opens or closes - each shelf is revealed by a growth milestone
- Date: 2026-11-10
- Type: guide text + implementation; windowed capture
- Source: GameFAQs walkthrough (TStodden, 2.002, 8.1.1-8.1.5 and 9) for tank 1's keypoint lists and
  Time Trial's "once you get a medium-sized guppy, the entire shop bar will open up"; the
  Insaniquarium Wiki's Blip page and TV Tropes ("opens all of the available items ... not even 5
  seconds into the game") for the pet unlock; `docs/analysis/notes/p2.7-pets.md` §4.14 / EV-0094 for
  the 200/720-tick thresholds; `scripts/progression/progression.gd` (`reveal_rules`),
  `scripts/tank/level.gd` (`_prime_store_reveals`), `scripts/ui/store_bar.gd`,
  `scripts/ui/egg_widget.gd`; captures `shot_bar_tank1.png` (1-3 with the shelves revealed)
- Confidence: high for tank 1's list (the guide states it item by item) and for the mechanism (the
  bar stays up; items are absent until unlocked, exactly what `FUN_005409B0`'s null return means);
  medium for tanks 2-4's ordering (same pattern, not itemised - Q-0062)
- Notes: (1) **The bar has no open/close timer.** The guide's tank 1 keypoints name the real rule:
  1-1 guppy after a **medium** guppy, egg pieces after a **large** one; 1-2 food upgrades at medium
  and egg pieces after buying Lv 2 food; 1-3..1-5 food at medium, carnivore at large, and the
  blaster plus egg pieces after a carnivore is bought. The port starts every level with the
  `MENUBAR` on screen and those shelves hidden, then reveals them from `_on_fish_grew` (stage 2 =
  medium, 3 = large) and from a successful purchase. (2) **Blip** is the exception: `EV-0094`'s
  branch fires while `Tank+0x2E0 < Tank+0x2DC` once the level age passes 200 ticks (720 as a
  transformed Presto) and reveals every shelf at once, which is what "the pet that opens the shop
  after a few seconds" is; `_on_pet_unlock` clears the hidden flags and the egg gate. (3) Time Trial
  opens the whole bar on the first medium fish; Sandbox, Challenge and tank 5 start open (the challenge
  reading is the port's, tank 5 sells only the egg). (4) `Progression.HIDDEN` stays the level's
  opening stock - 1-1 genuinely has no carnivore or blaster row to reveal - so a hidden shelf is a
  present row flagged `hidden`, never a fabricated price. (5) The price label is (7, 30, 45, 42), centred on y 51 on the purple plate: the owner read the
  digits as too low, and the earlier 18-px box also cut their bottoms (a Label clips to its own
  rect). The icons are fitted to 34x34 inside the dome glass, and the guppy's 80x80 cell is cropped
  to its 44-px centre after masking so it reads at the same size as the 40x40 `SCL_` icons. (6) `headless_store_ui_check` 43 -> 51
  assertions (the hidden start, the medium and large reveals, the purchase reveal, the egg gate);
  `headless_integration_check` 60 passes unchanged; totals **24 suites, 1341 assertions**.

### EV-0186 - R10: the menu mermaid is the shipped art; the flop strip has no recovered position
- Date: 2026-11-10
- Type: measurement + windowed visual; a guess removed
- Source: `assets_raw/images/selectorback.png` (`IMAGE_SELECTORSCREEN`), `tailflop.png` and
  `masks/tailflop_.png`; `tools/godot/measure_mermaid.gd`, `tools/godot/preview_tail.gd`;
  capture `shot_menu.png`; `scripts/ui/game_selector.gd`
- Confidence: high for the measurements and for what the two frames show; the strip's screen
  position stays unrecovered (Q-0055)
- Notes: (1) The baked mermaid's green tail measures x 95..283, y 323..439 and ends in a rounded
  **stump** at about (152, 405); `MERYLTAIL`'s cells are 238x165 transparent strips whose visible
  fringe occupies only y 78..163 (cell 0: x 1..199, root notch at (107, 84)). (2) Four placements
  were composited against that measurement (`shot_tail_candidates.png`): (150,270) plain and
  mirrored, (150,300) flipped vertically and (120,300) mirrored+flipped. Every one draws a long
  second tail across the baked one or over the button panel - the strip is not a fluke sized to the
  baked stump, so no offset can make one silhouette. (3) `SELECTORSCREEN` is the shipped menu art and
  already contains the mermaid; the port now draws exactly that and no longer mounts the strip, which
  is why `shot_menu.png` shows one clean green tail. (4) `MERYLTAIL`'s recovered playback
  (`framemap 7..0`, `framedelay 2`, `begindelay 3`) is kept as data and still pinned by
  `headless_menu_check` (28 assertions); Q-0055 stays open for the draw position.

### EV-0187 - a click on a visible coin now picks it up
- Date: 2026-11-10
- Type: reproduced bug + fix + probe
- Source: `scripts/tank/level.gd` (`_make_visual`), `scripts/entities/coin.gd` (`position`,
  `COLLECT_CENTER`, `can_collect`); windowed probe clicking the visible coin centre
- Confidence: high (reproduced before the change and re-run after)
- Notes: (1) `Coin.position` is the origin of its 80x80 box and the pickup square is centred at
  `position + (36, 36)` with a 60-px side (`P2.5 §5`), but `_make_visual` gave coins `centered = true`,
  so the drawn coin sat centred on `position` - 36 px up-left of its own hit box. A click on the coin
  fell through `try_collect` and paid the 5-shell pellet instead, which is the "coins can't be picked
  up" report. Fish already draw from the box corner (`centered = false` plus a (20,20) offset), so
  coins now use the same origin: the visible coin sits at `+40` inside the 60-px pickup box. (2) Probe:
  a synthetic left click on the withdrawn coin's centre took the wallet 200 -> 215 and removed the
  coin; the same click 36 px away still drops food, as before. (3) `headless_coin_check` 154,
  `headless_level_check` 122, `headless_store_ui_check` 51, `headless_integration_check` 60 all pass.

### EV-0188 - R10: the menu mermaid's fin is drawn at a measured port fit
- Date: 2026-11-10
- Type: measurement + windowed visual (supersedes EV-0186's removal)
- Source: `assets_raw/images/selectorback.png`, `tailflop.png`, `masks/tailflop_.png`;
  `tools/godot/measure_mermaid.gd`, `tools/godot/preview_tail.gd`; `scripts/ui/game_selector.gd`;
  capture `shot_menu.png`
- Confidence: high for the measurements and the result; the fin's exact placement is still a port fit
  (Q-0055)
- Notes: (1) The owner's read was right: the baked tail stops in a rounded stump at about (152, 405)
  and the shipped art has no fin there. `MERYLTAIL` is the fin, a 238x165 transparent cell whose
  visible crescent has its root notch at (107, 84). (2) At 1:1 the crescent is twice the stump's
  width and reads as a second tail; scaled to `TAIL_SCALE` 0.6 (143x99) and placed at
  `TAIL_OFFSET` (110, 360) the notch meets the stump and the fin trails down-right, which is what
  `shot_menu.png` shows. (3) The strip still plays its recovered one-shot flop (`framemap 7..0`,
  2 ticks a frame, 3-tick hold) and returns to cell 0; `headless_menu_check` 28 passes unchanged.
  (4) Q-0055 keeps the exact draw position open - only the fit is port choice, the art and timing are
  recovered.

### EV-0189 - TankScreen MENU is id 99; "Leave Game?" is the Options confirm, not the tank menu
- Date: 2026-11-11
- Type: static analysis (Ghidra) + port wiring + headless coverage
- Source: `docs/evidence/p2.12-fn-52CB40.json/.txt` (TankScreen ctor), `p2.12-fn-51B6C0.txt`
  (TankScreen click dispatch), `p2.12-fn-552100.json` (main-menu transition), `p2.12-fn-54E7C5.json`
  (Leave Game confirm), `p2.12-fn-535430.json` (OptionsDialog handler), `p2.12-fn-54ED21.json`
  (pause box); `scripts/ui/store_bar.gd`, `scripts/tank/level.gd`, `scripts/main.gd`,
  `scripts/ui/debug_panel.gd`, `scripts/entities/fish.gd`
- Confidence: high for the dispatch, the button rect and the Options ownership; the 26-px MENU
  height is a port fit because the binary's height comes from the button object
- Notes: (1) The TankScreen ctor `FUN_0052CB40` creates the button with
  `FUN_00506820(99, in_ECX + 0x22, ...)` and places it through `vtable+0xA0(0x20D, 4, 0x50,
  button[0xF])`. The width is the literal `0x50` (80 px); the fourth argument is the button's own
  measured height, not a literal, so the port borrows the 26-px MENU plate height `HatchScreen`
  already uses. The id is **99**, not 100: 100 is HatchScreen's "Menu" id (P2.12 10.11).
  (2) `FUN_0051B6C0(99)` runs `FUN_0054AED0()` (the TankScreen close helper) then
  `FUN_00552100()` (go to the main menu). There is no save call in that path. Id 4 instead runs
  `FUN_0054AED0()` + `FUN_00552E50(-1)`, which opens a `Sexy::StoryScreen` - so `FUN_00552E50` is
  not an in-tank menu entry; the note's line 888 role is corrected to "StoryScreen opener".
  (3) `FUN_0054E760` builds "Leave Game?" / "Do you want to return to the\nmain menu?\n\nYour game
  will be saved." and is reached only from `FUN_00535430` (OptionsDialog click handler) case 3,
  gated on `mode != 5`, a live tank and `FUN_00537BF0()`; it is the Options "Back to Main Menu"
  confirm, not the tank MENU. (4) The "GAME PAUSED" box is a third, separate path:
  `FUN_0054ECA0` pushes "GAME PAUSED" / "Click to resume game" / "Resume Game" through
  `vtable+0x120(0x12, 1, ...)` while `in_ECX[0x1CC]` is set. (5) Port wiring: `StoreBar` adds a
  flat hit target over the baked `MENUBAR` MENU label at (525, 4, 80, 26);
  `press_menu()` plays the click, calls `Level.request_menu()` and emits `menu_pressed`.
  `Level.request_menu()` emits `menu_requested`; `Main._on_menu_requested()` saves to the level's
  `save_path` as a port safety net (D-0014 - the binary does not save here), clears the pause,
  shuts the tank down, frees the level and calls `_mount_selector()` in the same frame.
  (6) Coverage: `headless_store_ui_check` 51 -> 54 (MENU rect, hit target, forwarding),
  `headless_level_check` 122 -> 149 (the port-only debug dispatcher and actions),
  `headless_integration_check` 60 -> 67 (hidden panel, F1, money, grow button, MENU
  release/mount/save). Totals **24 suites, 1378 assertions**. The debug cheats themselves are
  port-only and carry no binary claim (D-0014).

### EV-0190 - Windowed check: MENU returns to the selector; F1/F2/F3/F10 act in the rendered tank
- Date: 2026-11-11
- Type: windowed rendered probe with synthetic input + screenshots
- Source: `tools/godot/shot_menu_debug.gd`; captures `shot_menu_tank.png`, `shot_menu_return.png`,
  `shot_debug_panel.png`; `scripts/ui/store_bar.gd`, `scripts/tank/level.gd`, `scripts/main.gd`
- Confidence: high for the probe's assertions and the three frames; this is not the owner's live
  playtest
- Notes: (1) The probe boots the real `scenes/main.tscn` windowed (`--audio-driver Dummy`), waits
  for the Content LoadingThread phase (326/326), and starts Adventure through
  `GameSelector.press(1, {})` - the same path as the menu. (2) It sends a synthetic left click at
  the centre of the `Menu` button's global rect (525, 4, 80, 26). `Main` released the level,
  mounted a fresh `GameSelector` and wrote `user://shot_menu_debug.dat` (the D-0014 safety net);
  `shot_menu_return.png` shows the selector. (3) On a second level, `F1` showed the panel,
  `F2` took money 200 -> 1200, `F3` took the first live fish stage 0 -> 1 and `F10` took the FISH
  phase 2 -> 3; `shot_debug_panel.png` shows the panel over the tank with 1200 on the wallet
  plate and the baked MENUBAR MENU label at top right. (4) Exit 0; the Ogg vendor-comment warnings
  and the ObjectDB/resource-at-exit notices are the known AUDIT F2 noise. (5) This verifies the
  rendered wiring, not timing/feel; the owner's live playtest (R8 and the assembled feel) stays
  open.

### EV-0191 - Port flow: tank MENU opens the in-tank Options dialog (owner-directed)
- Date: 2026-11-14
- Type: port behavior change (owner request) + headless integration coverage + windowed probe
- Source: `scripts/main.gd` (`_on_menu_requested`, `_close_options`, `_leave_tank`),
  `scripts/ui/options_dialog.gd`, `scripts/ui/store_bar.gd`, `scripts/autoload/game.gd`,
  `tests/headless_integration_check_scene.gd`, `tools/godot/shot_menu_debug.gd`; captures
  `shot_menu_tank.png`, `shot_menu_options.png`, `shot_menu_return.png`, `shot_debug_panel.png`
- Confidence: high for the port wiring and the probe; the binary's own id-99 dispatch is still
  close-tank + main menu (EV-0189), so this is a deliberate divergence, not a recovered behavior
- Notes: (1) The owner reported that the tank MENU went straight to the main menu and asked for
  the in-level settings UI instead. `StoreBar.press_menu()` -> `Level.request_menu()` ->
  `Main._on_menu_requested()` now mounts the existing `OptionsDialog` through
  `Screens.open_dialog()` and sets `Game.gameplay_paused`; the level stays mounted and no save is
  written. (2) OK or Escape closes the dialog and resumes the same tank. "Back to Menu" closes
  it, saves to the level's `save_path` (the D-0014 safety net), shuts the tank down, frees the
  level and mounts `GameSelector` - the old leave-tank path. (3) `Level._unhandled_input()`
  ignores tank clicks/hotkeys while any modal dialog owns `Screens.dialog()`, so F1..F10/S/P and
  feeding cannot run behind Options. (4) The Show Money checkbox is live: `Game.show_money` has a
  setter and `show_money_changed`; the dialog seeds from it and `StoreBar` hides/shows the wallet
  plate. (5) Windowed probe: MENU opened Options with the tank mounted and paused and wrote no
  save; OK closed it and resumed; a second MENU -> Back to Menu released the level, mounted the
  selector and wrote the save; F1/F2/F3/F10 still behaved (200 -> 1200 money, stage 0 -> 1, FISH
  2 -> 3). Exit 0; Ogg vendor-comment and ObjectDB/resource-at-exit notices are the known noise.
  (6) Coverage: `headless_integration_check` 67 -> 81 assertions; all 24 suites pass,
  **1392 assertions**. D-0015 records the decision.

### EV-0192 - In-tank Options: base art/layout, masked sheets, real pause, debug block, Help
- Date: 2026-11-15
- Type: port UI implementation (base layout from recovered evidence) + headless integration and
  windowed probe
- Source: `scripts/ui/options_dialog.gd`, `scripts/ui/option_slider.gd`,
  `scripts/ui/option_check.gd`, `scripts/data/mask_alpha.gd`, `scripts/tank/level.gd`,
  `scripts/tank/tank.gd`, `scripts/main.gd`, `scripts/ui/game_selector.gd`,
  `scripts/ui/help_screen.gd`, `scripts/ui/hatch_screen.gd`, `scripts/ui/store_bar.gd`,
  `scripts/entities/fish.gd`, `scripts/autoload/game.gd`,
  `tests/headless_integration_check_scene.gd`, `tests/headless_level_check.gd`,
  `tests/headless_store_ui_check.gd`, `tools/godot/shot_menu_debug.gd`; captures
  `shot_menu_options.png`, `shot_menu_help.png`, `shot_menu_tank.png`, `shot_menu_return.png`,
  `shot_debug_panel.png`
- Confidence: high for the port wiring and the headless/windowed assertions. The base dialog's
  contents and ids are recovered (P2.12 §11.3); the debug block, Show Money placement and the
  Custom Cursors/Hardware Acceleration storage are port-only (D-0014/D-0016).
- Notes: (1) **Base contents** (P2.12 §11.3): Music/Sound FX sliders (ids 5/6), Fullscreen/Custom
  Cursors/Hardware Acceleration checkboxes (ids 7/8/9), Help (id 1) and OK; the in-level dialog
  also carries Back to Main Menu (id 3), whose visibility is the `+0x18C` byte. The Steam build
  hides Register, the web link and Check Updates. "Show Money" is not a base Options checkbox: it
  is the TankScreen INI option (`TankScreen+0x83C`, P2.5), so the port puts it in the labelled
  debug block. (2) **Art**: `Dialogue-panel` 240x240 (9-slice 32/44), `DialogButton2` 288x33
  (three 96x33 frames), `Checkbutton`/`unCheckbutton` 46x45, `slidertrack` 156x17 and
  `SLIDERWIDGET` 33x32. Every sheet is opaque and ships a `masks/_<file>` alpha companion (P3.3);
  `MaskAlpha.compose()` now builds the cut-out texture, and the dialog/slider/checkbox use it. The
  windowed before/after shows the black panel corners and brown widget tiles disappearing. The
  new helper is shared: `HatchScreen.mask_for()` delegates to `MaskAlpha.mask_for()` with no
  behavior change. (3) **Controls**: `OptionSlider` keeps the native track/thumb sizes (an engine
  HSlider stretches the track to the control height); `OptionCheck` draws the 46x45 icon and puts
  the label 39 px after its left edge, matching the reference, because an engine CheckBox's
  stylebox content margins pushed "CUSTOM CURSORS" past the panel. Both fall back to flat blocks
  without `Content` (`--script` suites). (4) **Pause**: the original's shared Tank+0x94 gate was
  being written but never read - `Tank.pause_source` had no production assignment, so entities
  kept ticking behind every modal. `Level.setup()` now sets `tank.pause_source = _autoload("Game")`;
  `Tank.is_paused()` freezes entities and `Level._on_sim_tick()` early-returns so the level clock,
  wave clock, particles and store refresh freeze; `Level._process()` no longer re-aims held fire.
  The integration suite asserts `pause_source == Game`, `tank.is_paused()`, frozen `age_ticks`,
  frozen wave timer and frozen fish fullness, then one tick of progress after OK. (5) **Help**
  replaces Options with the existing dimmed tutorial `HelpScreen` (one `Screens` modal slot) and
  keeps the tank paused; Escape and the "Back to Game" button close it and resume. (6) The
  main-menu Options is the plain base panel: no Back row, no debug block; its Help button asks the
  selector to swap modals. In-level the Show Money toggle sits in the debug block and its label
  carries `ON`/`OFF`; the bar's wallet plate follows the shared `Game.show_money` signal. (7)
  **Coverage**: `headless_integration_check` 81 -> 116 (base art and
  masked corners, pause freeze, dialog money/guppy/grow, mixer, Show Money, OK/resume, menu-mode
  panel, Help request), `headless_level_check` 149 -> 153 (shared `PauseSource` gate), all 24
  suites pass, **1431 assertions**; the 400-frame boot exits 0. The windowed probe prints
  `pause frozen age=12 wave=0 fullness=415`, drives the dialog's money button (200 -> 1200) and
  guppy/grow (FISH 2 -> 3, new stage 1) while `still_paused=true`, then OK (clock resumes), Help
  (Escape closes), Back to Menu (level released, selector mounted, save written) and the F1/F2/F3/
  F10 leg (200 -> 1200, stage 0 -> 1, FISH 2 -> 3). Ogg vendor-comment and ObjectDB/
  resource-at-exit notices are the known noise. D-0016 records the decision.

### EV-0193 - The pellet: columns are held `[0x5F]` ticks, and fish feed at the mouth
- Date: 2026-11-16
- Type: port behaviour measurement against the owner's base-game recording + the extracted sheets
- Source: `scripts/entities/food.gd` (`column()`), `scripts/entities/fish.gd` (`mouth_point`,
  `_try_eat`), `scripts/tank/level.gd` (`_food_frame`), `tools` probes (deleted), the owner's
  `Recording 2026-11-16 123332.mp4`
- Owner report: "the animation and collision for the pellet is way off compared to the base game".
- (1) **Sheet layout, re-checked.** `assets_raw/images/food.png` is 400x200 = 10x5 cells of 40x40.
  Dumped at 2x: row 0 brown pellets, 1 green capsules, 2 red/white pills, 3 green flasks, 4 yellow
  droplets - the ten columns are one tumbler run, so the rows are kinds and the drawn frame must be
  `row * 10 + column` (unchanged). The three flask cells of row 3 carry an **opaque cyan
  background**; a star-potion pellet drawn from it would show a cyan box until the art is keyed.
- (2) **Tumbler rate.** The port advanced `Food.anim_frame` one per tick and drew `anim_frame % 10`,
  i.e. ten columns in ten ticks: 0.28 s per run, **3.6 turns a second** at the port's 36 Hz - a
  flicker. Probe log before the change: `t=76 anim=33 col=3, t=77 anim=34 col=4, ... t=83 anim=0`
  (column and counter moved 1:1). The wrap range `[0x5F] * 10` with ten columns means the counter
  holds each column `[0x5F]` = 3 or 4 ticks, which is the only reading where the ctor's random 3/4
  changes anything: the pellet's own spin rate. The port now draws `anim_frame / anim_cycle`.
  Probe after: `cycle=4`, `anim=2 col=0, anim=4 col=1, anim=8 col=2, anim=12 col=3, ...`, one run in
  40 ticks = 1.1 s. The engine's other sprites hold columns too (coins `FRAME_TICKS`, `AnimState` 5).
- (3) **Where a fish eats.** The eat test was `|centre - pellet| <= 35` on both axes, with the centre
  `position + (40, 40)`. Probe: a guppy origin at (231.6, 161.4) consumed a pellet at (240, 190.5) -
  31 px left of and 10 px above its centre, i.e. **at the fish's tail**, after it had swum past.
  The 35 px window is recovered (P2.3 §7.3, EV-0149 slot 86); what was wrong is the point it is
  measured from. The `SMALLSWIM` stage-0 cell (80x80) puts the fish at x 23..54, y 24..54 with its
  mouth tip at (24, 43): 16 px ahead of the cell centre and 3 px below it, mirrored by facing.
  `Fish.mouth_point()` is that point and `_try_eat` measures from it. Probe after: the same guppy
  takes the pellet with it 28 px in front of the mouth; a pellet behind the fish sits 46 px from the
  mouth and is now out of reach.
- (4) **Coverage**: `headless_level_check` 155 -> 157 (a column holds `anim_cycle` ticks; tick 3 is
  column 1, tick 25 is column 8), `headless_fish_check` 121, `headless_entity_check` 43,
  `headless_store_ui_check` 50, all pass. Not re-shot: the pellet art is the base sheet, so a still
  cannot show the tumble rate; the probe log is the evidence.

### EV-0194 - A coin no longer rebuilds the bar's domes
- Date: 2026-11-16
- Type: port performance fix, measured
- Source: `scripts/ui/store_bar.gd` (`_icon_cache`, `icon_for`, `badge_placeholder`),
  `scripts/ui/egg_widget.gd`, `tests/headless_store_ui_check.gd`, a windowed timing probe (deleted)
- (1) **Where the time went.** `StoreBar.refresh()` draws each dome through `_icon_texture()`, which
  composites the item's cell through its mask (`HatchScreen.masked_cell`) and then builds a fresh
  badge in `badge_cell()`: a 44x33 canvas, a per-pixel shading loop, two highlight blobs and a
  bilinear resize of the item. `Level` calls `refresh_if_changed()` on every tick and `refresh()`
  runs whenever the purse moves, so that whole cost was paid **on every coin**.
- (2) **Measured.** A windowed probe stocked seven real domes (ids 1, 2, 4, 6, 7, 8, 9, `shelf`
  assigned so `row_at` finds them), warmed one refresh and timed 100 refreshes with the purse
  moving: **17,365.6 us per refresh** (17.4 ms, i.e. a whole 60 Hz frame per pickup). After the
  cache: **153.2 us per refresh** (15.3 ms for 100) - 113x less. What remains is the price labels,
  the button states and the wallet, which is what a pickup should touch.
- (3) **The cache.** `StoreBar._icon_cache` holds one texture per item id for the run; the weapon
  (id 10) appends its upgrade level because that picks its cell, so it gets one entry per level
  bought. `null` results are cached too - an item whose sheet or mask is missing is as expensive to
  miss again. The bare badge is `StoreBar._badge_placeholder`, composed on first use and shared with
  the egg dome, which used to build its own copy per widget. The fish dome's ten swim cells were
  already composed once (`_swim_loaded`).
- (4) **Risk taken knowingly.** The cache lives as long as the process: the art is run-constant, and
  a `Content` reload (no code path today) would leave stale textures behind.
- (5) **Coverage**: `headless_store_ui_check` 50 -> 53 (every stocked dome is filed under its id,
  the weapon under `10:<level>`; a purse change reuses the same texture; the bare badge is one
  shared instance), `headless_level_check` 157, `headless_integration_check` 134, the 400-frame boot
  exits 0.

### EV-0195 - Review pass on the bar: dead paths dropped, and the egg dome's baked window keyed out
- Date: 2026-11-16
- Type: code review + visual re-check of 1-3, 2-1 and 5-1 (windowed captures at 2x and 3x)
- Source: `scripts/ui/store_bar.gd`, `scripts/ui/egg_widget.gd`, `tests/headless_store_ui_check.gd`
- (1) **Dead path removed.** `StoreBar._body_crop()` cropped `SMALLSWIM` to a fixed 44x44 centre for
  the guppy's static icon, but id 0 never reaches `_icon_texture()`: `refresh()` draws the guppy from
  its own swim row (`_compose_swim_frames`, D-0022), so the crop - and the call site - were left over
  from the static-icon attempt and are gone. `_icon_texture()` now hands the masked cell straight to
  `badge_cell()`.
- (2) **One wallet box.** `MONEY_SIGN_RECT` was (531, 36, 14, 26) against `MONEY_RECT`
  (546, 34, 74, 30); both centres are y 49, so the sign box now shares 34/30 with the number and the
  two cannot drift apart. No pixel moves.
- (3) **Egg geometry.** `ART_SCALE` (0.85) is gone: the cell's height is fitted to `ART_WINDOW` and the
  width derived from it, so the pair cannot disagree (the old constant gave 33.15 px of art in a
  33 px window). With the art inside the badge, the `Window` clip control was redundant and is
  removed, and `PRICE_RECT` is now `StoreBar.PRICE_LABEL_RECT` (same plate, same centre y 51).
- (4) **The egg's second dome.** `EGGPIECES` bakes its own *pointed* violet dome window behind the cup
  (sampled #532B8B, shaded #7D43A2 and a lighter lilac). Drawn over the bar's 44x33 badge it read as
  two domes - the pointed arch poking through the ellipse - which is the owner's "the egg looks off".
  `EggWidget._without_baked_dome()` keys that violet out, so the cell leaves only the cup (pieces 1-2),
  the basket (piece 2) and the whole egg (piece 3) on the shared badge. Dumped per cell at 7x and
  confirmed on 3x captures of 1-3 (`$2000`, cup on the badge) and 5-1 (`FREE`, whole egg on the
  badge). The art's own thin violet outline survives and separates it from the badge.
- (5) **Stocked dome without art.** Id 5 (star potion, tank 2-1 shelf 3) has no `ICON_ART` entry, so
  `icon_for()` returned null and its dome drew as an empty gold dome with a price. It now falls back
  to `badge_placeholder()`, so a stocked shelf always reads as stocked: the 2-1 capture shows `$250`
  on a violet dome between the two food domes and the empty shelves.
- (6) **Flags left open** (no evidence to act on):
  - items 2 and 3 (Food Quality / Food Quantity) both draw `FOOD` frame 0, so 1-3 shows **two
    identical brown-pellet domes**. The real icons live in the unrecovered atlas (Q-0054); the sheet's
    row 1 is the green capsule the tank drops at quality 1, so an id -> frame map would separate them,
    but which row the original's shelf uses was never recovered (Q-0051).
  - Tank 5 works: only the egg row exists there (shelf 6), the bar blanks it, `EggWidget` draws the
    whole egg with `FREE` (a 0 price reached through `free`), and the six other domes are the base
    art's empty ones.
  - `SLOT_COUNT` is 8 but only seven x positions were recovered: a row on shelf 7 would draw nowhere.
    No tank stocks shelf 7 today (Q-0054).
- (7) **Checks**: `headless_store_ui_check` 53, `headless_level_check` 157, `headless_menu_check` 28,
  `headless_fish_check` 121, `headless_integration_check` 134, the 400-frame boot exits 0.

### EV-0196 - The shelf badge measured: 44x38 at slot-local y 3, and no affordability colour
- Date: 2026-11-16
- Type: measurement off the owner's base-game recording (frame at t = 0, bar starts at y 24 of the
  window) + side-by-side captures of 1-1, 1-3
- Source: `scripts/ui/store_bar.gd` (`ICON_RECT`, `PRICE_COLOR`), `scripts/ui/egg_widget.gd`,
  `tests/headless_store_ui_check.gd`
- (1) **Badge geometry.** A per-row scan of the stocked shelf's violet (test: `b > 0.35`,
  `b > r + 0.05`, `r > g + 0.03`, so the gold frame and the fish both fail it) gives, in slot-local
  rows: 14 px wide at y 3, 24 at y 5, 32 at y 7, 36 at y 9, 38 at y 11, 40 at y 13, **44 from y 15 to
  28**, then 42, 40, 34, 32, 26, 20 and it ends at y 40. That is an **ellipse 44 wide by 38 tall
  spanning slot-local y 3..40** - the badge fills the dome window and stops 4 px above the plate.
  The port had 44x33 at (6, 9), i.e. 6 px low and 5 px short, which is the gold moulding the owner
  saw showing above the violet.
- (2) **Price plate.** The same scan shows the violet plate at slot-local y 45..56, 46 px wide; the
  port's `PLATE_RECT` (7, 45, 45, 12) already matched and is unchanged.
- (3) **No affordability colour.** At t = 15 the wallet reads **45** with the guppy shelf at **`$100`**
  and the egg dome at **`$150`**; both prices are the same bright green as at money 400, and the dome
  art is unchanged. The base game never dims a price it cannot pay, so `StoreBar.GREYED_COLOR` and its
  use in `refresh()` are gone, along with `EggWidget`'s grey price branch. Click refusal is untouched:
  the purchase still fails, it just is not signalled by colour.
- (4) **Fitted art.** With the window 5 px taller the egg cell (46x39) is fitted by
  `min(window / cell)` on both axes, so it still sits inside the badge instead of overflowing by a
  fraction of a pixel.
- (5) **Verified visually** by capturing 1-1 and 1-3 at 2x and stacking them against the recording's
  1-1 bar: the badge now meets the gold ring's top and bottom as the base does. The same comparison
  shows two deviations that are **not** changed here: the base's wallet `$` is pale gold on its badge
  where the port draws dark green (#36720A), and the base's price/wallet glyphs are ~10-12 px where
  the port uses the 8 px `FONT_TINYBOLD`. Sampled badge colours (#4B2C5E left, #5332B6 right,
  #532C8E top) sit within a few units of `BADGE_BASE`/`BADGE_EDGE`, so the palette is left alone.
- (6) **Coverage**: `headless_store_ui_check` 53 -> 55 (the badge rect; a price that stays green at
  money 0), `headless_level_check` 157, `headless_menu_check` 28, `headless_fish_check` 121,
  `headless_integration_check` 134, the 400-frame boot exits 0.

#### EV-0196 addendum - the badge's two glows and the item fit, measured the same way
- (7) **Glows.** The brightest violet-ish pixels inside the badge (test: `b > 0.35`, `b > r + 0.05`,
  `r > g + 0.03`) are slot **(16, 8) `#D0BCE1`** and slot **(44.5, 33.5) `#CDB2E9`** - badge-relative
  (10, 6.5) and (38.5, 30.5) of 44x38. So the base has one glow at the **upper left** and a smaller
  one at the **lower right**; the port had two overlapping in the upper-left (#A489C7) whose peak
  measured **0.41** luminance against the base's **0.78**. After `BADGE_GLOWS` + the sampled
  `BADGE_HIGHLIGHT`, the same probe on our 1-1 capture gives **(16, 9) 0.72** and **(44, 33) 0.68** -
  the base's pixels, within JPEG noise.
- (8) **Item fit.** 8x crops of the two badges side by side showed our guppy filling the badge edge to
  edge while the base's icon leaves ~5 px margins (the base's fish spans ~34x30 of 44x38). The cause
  is scale: the shelf icons are 40x40 cells, but the guppy is the tank's 80x80 cell cropped to its
  union box. `badge_cell()` gained an `inset` parameter; the swim row passes `SWIM_INSET (10, 8)`, the
  icon cells keep `(3, 2)`. Re-cropped, the two badges now match in size and margin.
- (9) **Coverage**: `headless_store_ui_check` 55 -> 57 (the glow positions; the swim inset).

## EV-0197 - The bottom row of the tank screen (Tank name, hunger hint)

- Source: `Recording 2026-11-16 123332.mp4` frame at t=2 (636x504 window; the game area starts at
  window y 24, so game row = window row - 24) plus the t=0 frame for the second wording.
- (1) **`Tank  1-1`** occupies window x 14..73 (**60 px**), y 483..493 in pale gold. Its ink columns
  read "Tank" 14..43, a **13-px gap**, then "1-1" 57..73 - a wide gap, i.e. two spaces. Brightest
  pixel `#A49364`; the average over its bright pixels is `#98834F`.
- (2) **Hunger hint** occupies window x 186..462 (**277 px**, centred on 324), y 481..498 including
  its outline. Its bright pixels' mode is `#ADF762` (lime) and the darkest cluster `#004A00` - so the
  outline is dark green, not black.
- (3) **Two wordings.** t=2 shows `Fish are hungry! Click to drop food!`; t=0 shows
  `Fish are REALLY hungry! Click to feed!` - the capitalised form is the deeper warning.
- (4) **Font fit**, all 15 shipped fonts measured at native size: `CONTINUUMBOLD14` draws the hint
  **279 px** (2 px over the recording), `CONTINUUMBOLD12` draws the tank name **72 px** (12 over);
  `LIDDIE12/15/18` and the `JUNGLEFEVER` faces render lowercase as capitals and measure 342-517 px;
  `TINYBOLD` hits the tank name's 60 px but at 8-px glyphs.
- (5) **Our capture** (2x, `hud_mild`/`hud_hungry`): the row reproduces the recording's placement,
  width, mixed case and both wordings. Not matched: the tank name is ~12 px wider than the base's
  and the purple level plate still shows at the bottom right (D-0028 recommends dropping it).

## EV-0198 - The store screen still greyed a price the purse could not pay
- Date: 2026-11-18
- Type: code reading against the recording measurement already on file (EV-0196 (3): wallet 45,
  `$100` guppy shelf, price bright green) + headless assertions
- Source: `scripts/ui/store_screen.gd` (`row_state`, `price_color`, `refresh`),
  `tests/headless_store_ui_check.gd`
- (1) **What was left.** D-0027 removed the bar's and the egg dome's affordability colour, but
  `StoreScreen.row_state()` still computed `greyed = sold_out or not price_known or not affordable`,
  and `refresh()` painted both the name and the price with `GREYED_COLOR` from it. With the wallet
  short, the Fish Emporium's price line was `#CCCCCC` where the base keeps `0x6EFA6E`.
- (2) **The change.** `greyed` is `sold_out or not price_known`; a new `price_color(state)` holds the
  only `PRICE_COLOR`/`GREYED_COLOR` choice and is what `refresh()` uses. `affordable` stays in the
  state dictionary. Nothing else in the port references the grey: the bar sets `PRICE_COLOR` on every
  price label at every refresh, and `EggWidget.refresh()` does the same.
- (3) **Pinned.** `headless_store_ui_check` now asserts `price_color()` is `PRICE_COLOR` for the
  guppy at wallet 50 (the recording's shortage case), `PRICE_COLOR` at exactly enough, and
  `GREYED_COLOR` only for a sold-out row; plus the bar's own `$100` shelf stays green at wallet 45.
  57 -> 62 assertions, PASS; `headless_level_check` 165, `headless_integration_check` 134, boot clean.

## EV-0199 - The debug overlay's box against the measured bottom row
- Date: 2026-11-18
- Type: scene/layout inspection + a headless probe of the boot scene
- Source: `scenes/main.tscn` (`Debug/Info`), `scripts/main.gd` (`STATS_KEY`, `toggle_stats`),
  `scripts/tank/level.gd` (`TANK_LABEL_RECT`, `HINT_RECT`)
- (1) **Overlap.** `Debug/Info` is anchored to the bottom-left with offsets (4, -22, 636, -4), which
  resolves to an absolute box **(4, 453, 632, 23)** - the full width of the tank screen's bottom row.
  `Level.TANK_LABEL_RECT` is (13, 453) and `HINT_RECT` is (0, 454, 640, 22), so the overlay's opaque
  text sits directly on both strings.
- (2) **Probe.** Instantiating `res://scenes/main.tscn` headless and waiting 30 frames prints
  `visible=false`, `toggle_stats() -> true` with `now=true`, and the label's own `position (4, 453)`
  / `size (632, 23)`, confirming the box above is the one that was covering the row.
- (3) **Coverage.** No suite asserted the overlay before and none does now; the boot run (400 frames)
  exits 0 with the label hidden, and the store-UI/level/integration suites are unaffected.

## EV-0200 - Re-shooting 1-1 and 1-3 after deleting the level plate
- Date: 2026-11-18
- Type: 2x captures of the real main path (boot -> GameSelector -> 1-1 and 1-3), bottom strip, with a
  per-pixel ink scan of the same frame
- Source: `scripts/tank/level.gd` (`_add_bottom_hud`, `tank_name`), `tests/headless_level_check.gd`
- (1) **The plate is gone.** Both captures report `Hud/LevelPlate` and `Hud/LevelLabel` as null, and a
  green-ink scan of the old plate's box (575..635, 448..478) finds **no pixels** - the corner is plain
  water.
- (2) **The name** reads `Tank  1-1` / `Tank  1-3` at (13, 453) in `#A89460`, ink x 13..81 (69 px) and
  11 px tall against the recording's x 14..73 (60 px) at 11 px. Position, colour and height match; the
  width is the known `CONTINUUMBOLD12` metric deviation recorded in EV-0197 (4).
- (3) **The hint** at the first warning line reads `Fish are hungry! Click to drop food!` in `#AEF762`
  on `#004A00`; its ink spans x 186..462 - the recording's own 186..462 (277 px) - 13 px tall.
- (4) Neither capture shows the debug stats line: it starts hidden (D-0030).
- (5) **Coverage**: `headless_level_check` 165 -> 168 (the plate/value constants are absent from the
  script's constant map; `tank_name(1, 1)`/`tank_name(1, 3)` are the recording's strings;
  `TANK_LABEL_RECT` is (13, 453)), `headless_store_ui_check` 62, `headless_integration_check` 134,
  boot clean.

- (6) **Sweep after the deletion** (2026-11-18): no `LEVEL_PLATE*`/`LEVEL_LABEL*`/`level_label`
  reference is left under `scripts/`, `tests/`, `tools/` or `scenes/`; the suite's constant-map
  guard and this entry are the only places the old names appear. `level.gd` still has 15 uses of
  `_content`, and the `IMAGE_MENUBAR` lookup the plate made is gone with it (the store bar keeps
  its own). Two comments that repeated D-0031 beside the constants and `_add_bottom_hud()` were
  trimmed; assertions unchanged at 170.

## EV-0201 - What the hint refresh costs per frame, before and after the tick gate
- Date: 2026-11-18
- Type: timing probe on the live 1-1 level (windowed, `--audio-driver Dummy`), 200,000 calls per figure
- Source: `scripts/tank/level.gd` (`_refresh_hint`, `hint_text`, `tank.age_ticks`),
  `tests/headless_level_check.gd`
- (1) **Off-tick cost.** `_refresh_hint()` called 200,000 times with the tick unchanged - the common
  case, since the sim ticks at 30 Hz and the game draws at 60 - averages **0.20 us** a call, i.e. the
  function call plus one integer compare. At 60 fps that is ~12 us a second.
- (2) **The scan it skips.** `hint_text()` on the same frame costs **1.72 us** with two fish (it walks
  `entities_in(FISH)`), so the ungated version paid ~103 us a second for this row, and more as the
  school grows. A label text write is 0.09 us, but it also marks the label's layout dirty, which is
  why a settled wording no longer re-writes it.
- (3) **Behaviour, not just cost.** With the tick gate the hint still appears on the tick the fish
  cross a warning line and disappears on the tick the last live fish dies; `headless_level_check`
  now pins `hint_text() == ""` for a dead fish and for a cleared tank (168 -> 170 assertions).
- (4) Also removed in the review: `_add_bottom_hud()`'s unreachable null guards (single caller,
  labels rebuilt per level). Font constants kept, with the reason in D-0032.

## EV-0202 - The bar's `$` and its text sizes, measured off the 1-1 recording
- Date: 2026-11-18
- Type: frames of `Recording 2026-11-16 123332.mp4` (636x504, 30 fps; t = 15, wallet 45), 32x badge
  crops against `assets_raw/images/menubar.png`, same-scale side-by-sides of the port's own capture
- Source: `scripts/ui/store_bar.gd` (`MONEY_RECT`, `PRICE_SHADOW_COLOR`), `scripts/ui/ui_font.gd`
  (`BAR_PRICE_FONT`, `BAR_MONEY_FONT`), `scripts/ui/egg_widget.gd`, `tests/headless_store_ui_check.gd`
- (1) **The `$` is the art's.** `MENUBAR`'s badge (x 528..541, y 42..57) is a `$` in
  `#006901`/`#138C17`/`#25740F` with `#50872A`/`#32AA33` edges on `#FED172`. The recording's badge at
  the same position (window y - 24) is that glyph with JPEG ringing; at 32x the two are the same shape
  in the same cells. So the base draws no `$` label, and the port's second one was covering the art.
- (2) **The wallet label is recovered.** `FUN_00542CFD` sets `Tank+0x438` to x `0x217` = 535, y `0x28`
  = 40, width `0x50` = 80, height = the font's, font `DAT_005e8ce4` = `FONT_CONTINUUMBOLD12`
  (EV-0157); `FUN_0053A360` formats `"%d"` (`DAT_005adec0`, EV-0058) - no sign in the string.
- (3) **Text sizes off the video.** `$100` inks x 32..57 (**25 px** wide) and y 75..82 (**8 px** tall)
  inside the 45x12 plate; the wallet's `45` inks x 597..612 (**16 px**) and y 68..79 (**11 px**) - two
  different sizes, and both larger than the 8-px `TINYBOLD` the port used (its `$100` advance is 37 px,
  so it filled the plate). Font advances at native size: `FONT_TINY` 27, `FONT_BLAMBOTPRO8` 32,
  `FONT_CONTINUUMBOLD12` 35, `FONT_CONTINUUMBOLD12OUTLINE` 35, `FONT_LIDDIE12` 38, `FONT_TINYBOLD` 37.
- (4) **What the port now draws**: prices in `FONT_TINY` (`$100` advance 27, leaving the plate's
  margins as the base does) with a 1-px `#004A00` shadow, the wallet number in ContinuumBold12 in the
  (535, 40, 80) box, and the art's `$` uncovered. Re-shot at 2x and stacked against the recording at
  the same physical scale: same positions, same margins, same relative sizes.
- (5) **Coverage**: `headless_store_ui_check` 62 -> 65 (the recovered wallet box; no `$` label node;
  the two font ids; the shadow colour), `headless_integration_check` 134 (its two `_uses_font` checks
  move to `BAR_PRICE_FONT`), `headless_level_check` 170, boot clean.

## EV-0203 - The tank name's width: font table at native size, and the re-shot 1-1 label
- Date: 2026-11-18
- Type: `Font.get_string_size("Tank  1-1")` per shipped font at its native size; windowed 1-1 capture
  at 2x (1280x960) with the wallet at 45, ink box of the name label measured on the raw RGB
- Source: `scripts/ui/ui_font.gd` (`BOTTOM_NAME_FONT`, `BOTTOM_NAME_TRACKING`, `apply_tracked`),
  `scripts/tank/level.gd` (`_add_bottom_hud`), `tests/headless_level_check.gd`
- (1) **Advances for `Tank  1-1`** (nine glyphs, two spaces): `FONT_CONTINUUMBOLD12` 72,
  `FONT_CONTINUUMBOLD12OUTLINE` 65, `FONT_JUNGLEFEVER10OUTLINE` 65, `FONT_BLAMBOTPRO8` 64,
  `FONT_TINYBOLD` 60, `FONT_TINY` 51, `FONT_CONTINUUMBOLD14` 77, `FONT_LIDDIE12` 90,
  `FONT_LIDDIE15` 103, `FONT_BLAMBOTPRO15` 114. Heights: 8-px fonts stand ~8 px of caps, the 12-px
  pair 11; the recording's name inks 11 px tall (y 459..469 game).
- (2) **Tracking on ContinuumBold12**: `spacing_glyph` -0.5 -> 72, -1.0 -> 64, -1.5 -> 64, -2.0 -> 56
  (integer advances, so -1.5 buys nothing over -1.0).
- (3) **Re-shot 1-1** (2x capture, raw RGB, ink = pixels within 26 of `#A89460`): name inks
  x 26..147 capture = **61 logical px**, y 920..941 = 11 px tall. Before the trim the same label
  inked 69 px (x 13..81). The recording's is 60 px (x 14..73). Column runs of the re-shot read
  `Tank` = 26..79, then `1-1` = 120..147, so the two-space gap survives the trim.
- (4) **Coverage**: `headless_level_check` 170 -> 171 (the font id and the -1.0 tracking);
  `headless_store_ui_check` 65, `headless_integration_check` 134, boot clean.

## EV-0204 - The hunger hint's cache survives `load_game()` before D-0035
- Date: 2026-11-18
- Type: reading `_refresh_hint`'s two guards against `load_game`'s restore path; headless suite
- Source: `scripts/tank/level.gd` (`_refresh_hint`, `load_game`), `tests/headless_level_check.gd`
  (`_test_hint_cache_on_load`)
- (1) `_refresh_hint()` returns early on `int(tank.age_ticks) == _hint_tick` and, after computing,
  returns before writing when `text == _hint_shown`. `load_game()` replaced the tank's entities
  (`TankSnapshot.restore`) and restored the scalars but never touched either field, so both still
  described the pre-load tank.
- (2) Failure modes, both from that: a restored `age_ticks` that matches the cached tick holds the old
  wording for that tick; a restored fullness whose wording matches `_hint_shown` skips the label write
  even though the label still shows the previous tank's text.
- (3) After D-0035 the load leaves `_hint_tick == -1` and `_hint_shown == ""` (and an empty, hidden
  `hint_label` when there is a HUD), which is the fresh-`start_level` state, so the restored tank's
  next tick recomputes and writes.
- (4) **Coverage**: `headless_level_check` 171 -> 174 (the save writes, the load returns true, and
  `_hint_tick` is back at `-1` after loading a save stuffed with a tick a restored tank could match);
  `headless_tank_snapshot_check` 54, `headless_store_ui_check` 65, `headless_integration_check` 136,
  boot clean.
- (5) **Review of the fix (same day)**: the wording reset and the label clearing were both cut. The
  order that makes them unnecessary is `_refresh_hint()`'s: it runs in `_process` on every rendered
  frame, its only skip is `age_ticks == _hint_tick`, and input is dispatched before `_process` - so the
  `-1` tick alone puts the restored wording on screen in the load's own frame. `_hint_shown` is only
  ever written by `_refresh_hint()` and the load does not touch the label, so it still equals the
  label's text; clearing it was not just redundant but wrong (it described a blank label that was not
  blank). Nothing else carries hint state: `hint_text()` is pure, `Fish._warned` is per-fish and reset
  with the fish, and the scalar block has no hint field.

## EV-0205 - The tick-gated hint re-shot on 1-1 and 1-3 against the recording
- Date: 2026-11-18
- Type: windowed captures of the real main scene (2x, 1280x960) driven a tick at a time, and frames of
  `Recording 2026-11-16 123332.mp4` at 0/1.5/4/9 s; ink boxes measured on raw RGB
- Source: `scripts/tank/level.gd` (`_refresh_hint`, `hint_text`, `HINT_RECT`), `scripts/entities/fish.gd`
  (`HUNGER_HINTS`)
- (1) **Timing holds on both tanks.** Each level is started from the menu and every live fish is
  set just above a warning line so the next decay tick crosses it. 1-1: the crossing tick is 4
  (worst -1) and the label is visible with `Fish are hungry! Click to drop food!` on that same tick;
  after feeding at tick 25 the label is empty and hidden on tick 26 (worst 494). 1-3: crossing tick 5
  (worst -1), cleared tick 22 (worst 499). No tick of stale wording and no tick of delay.
- (2) **The wording tiers are wrong** (found by this comparison; not changed). The base has three
  lines - its own table (`docs/analysis/notes/p2.3-feeding.md:152-153`) puts `-1` at the shallow line,
  `-200` at `REALLY hungry` and `-400` at `about to die`. The recording shows both: t=0/1.5 the
  REALLY line, t=4 `Fish are about to die of hunger! Click on aquarium!`. The port has only the
  shallow and REALLY strings and keys REALLY to `-400`, so at `-210` it still shows the shallow line
  (captured) and at `-451` it shows REALLY where the base shows about-to-die (captured side by side).
- (3) **Sizes.** The recording's REALLY line inks x 173..475 = 303 px, y 457..474; the about-to-die
  line 397 px. The port's REALLY line inks x 173..473.5 = 301 px, centre 323.25 against the base's
  324, so the width and horizontal centre match within JPEG blur. The shallow line (no recording
  frame for it) inks 275.
- (4) **The hint sits ~6 px lower than the base's**: the port's ink rows are y 463..479.5 where the
  recording's are 457..474, with the same height. `HINT_RECT` is (0, 454, 640, 22) and the label
  centres a 26-px line box in it, so the glyph ink lands low; the base's ink bottom is 2 px above the
  rect's bottom where the port's is 3.5 px below it. Left as found - it is a position fix, not a
  tick-gating one.
- (5) After feeding, both tanks draw no hint at all - no outline, no empty band - matching t=9.

## EV-0206 - A watched windowed 1-1 session: bottom row, plate, F12
- Date: 2026-11-18
- Type: windowed run of the real main scene (2x captures, 1280x960) driven from the menu into 1-1 and
  left to run naturally - no fullness forced; keyboard/mouse through `Input.parse_input_event`
- Source: `scripts/tank/level.gd` (`_add_bottom_hud`, `hint_text`), `scenes/main.tscn` (`Debug/Info`)
- (1) **The name reads as the recording's**: `Tank  1-1`, font `CONTINUUMBOLD12` at 12 with the
  recorded tracking, colour `font_color` = (0.6588, 0.5804, 0.3765) = **#A89460** pale gold, at
  (13, 453). Its ink is on screen in every capture of the session, start to cleared.
- (2) **The hint follows natural hunger.** Fish start at 420ish and lose 1 a tick at 36 Hz; the label
  first appears at **tick 428 (t = 11.9 s)** with the worst fullness at exactly **-1** and
  `Fish are hungry! Click to drop food!`, and it stays hidden at tick 396 (worst 31) - so the write
  happens on the crossing tick, not one later.
- (3) **It clears when fed.** Four left-clicks in the tank (through the real input path, after giving
  the fresh level 500 money - a pellet costs `PELLET_PRICE`) dropped four pellets, all of which were
  eaten (food in tank 0); the label is empty and hidden at **tick 479**, worst 101. No stale wording,
  no leftover outline.
- (4) **No plate.** The level has no child whose name contains "plate" or "level", and the bottom-right
  of the strip is bare sand in all four captures.
- (5) **F12 does not steal the row** (after D-0036). With the hint up, F12 shows the line; its box is
  now (4, 429, 632, 23) against the name's (13, 453, 220, 23) and the hint's (0, 454, 640, 26), and
  `Rect2.intersects` is false for both. In the capture the white stats ink sits at y 434..446 while
  the lime hint ink stays at 463..479 and the gold name at 460..471 - three separate bands. A second
  F12 hides it again (`visible` false), and the hint and name are untouched in that capture too.
- (6) **Coverage**: `headless_integration_check` 134 -> 136 (the stats box exists and clears both rects).

## EV-0207 - A windowed 1-1 load with the hint up: the label re-writes without help
- Date: 2026-11-18
- Type: windowed run of the real main scene (render = true, 2x captures), saves written to `user://`
  and loaded back through `Level.load_game`, label state read immediately after the call and again one
  frame later; lime/gold ink counted on the captures
- Source: `scripts/tank/level.gd` (`load_game`, `_refresh_hint`), `tests/headless_level_check.gd`
- (1) **A hungry tank saved**: the hint came up at tick 4 (worst -2) with `Fish are hungry! Click to
  drop food!`, `save_game` returned OK, and the capture shows the lime line (4760 lime pixels, x
  372..921 capture).
- (2) **Fed and saved**: feeding the tank cleared the hint on the same frame it was checked (tick 11,
  worst 495), the second save returned OK, and the capture has no lime at all.
- (3) **Loading the hungry save over the fed tank**: `load_game` returned true at tick 14. Right after
  the call the label still held the fed state (`visible=false`, `text=""`) while the restored fish
  already read -2; **one frame later, same tick**, it read `visible=true`,
  `text="Fish are hungry! Click to drop food!"`, `_hint_shown` matching, and the capture is pixel-for-
  pixel the saved hungry one. So the load's own frame writes the restored wording with no label
  clearing and no `_hint_shown` reset.
- (4) **The other direction**: with the hint up, loading the fed save left the label showing the hungry
  line immediately after the call (restored worst 495), and one frame later it was `visible=false`,
  `text=""`, `_hint_shown=""` - cleared in the load's frame. The capture has no lime.
- (5) **Still live afterwards**: the restored tank went hungry again and the hint came back at tick 33.
- (6) **Coverage**: this is the windowed half the headless suite cannot reach (`render = false` keeps
  `hint_label` null there, so its `_test_hint_cache_on_load` only pins the tick reset).

## EV-0208 - Per-tank state on the Level, and what a load leaves behind
- Date: 2026-11-18
- Type: field-by-field audit of `scripts/tank/level.gd` against `load_game`/`start_level` and
  `TankScalars`; headless scenarios plus a windowed backdrop capture
- Source: `scripts/tank/level.gd`, `scripts/persistence/tank_scalars.gd`,
  `tests/headless_level_check.gd` (`_test_load_refresh`), `tests/headless_tank_snapshot_check.gd`
- (1) **Stale, now fixed**: `Level.tank_index` (the Level's copy; `load_game` only wrote
  `tank.tank_index`), `egg_price` (only set in `start_level`), `egg_pieces` (field present in the block
  at `+0x43C` but never written or read), the backdrop sprite (guarded by `has_node("Backdrop")`),
  `_composite_pending`/`_composite_selection`, and `_presto_notice`.
- (2) **Windowed backdrop check**: the sprite read `aquarium1.png`; setting `backdrop = 3` and calling
  the new `_refresh_backdrop()` showed `aquarium3.png`; `load_game` of the backdrop-1 save returned
  true and the sprite was `aquarium1.png` again in the next frame.
- (3) **Headless**: `_test_load_refresh` saves tank 1 level 2 with 2 egg pieces, poisons the live level
  with tank 5 / level 4 / 1 piece / price 12345 / a queued composite member, and requires the load to
  restore both indices to 1/2, the count to 2, the price to `Progression.egg_price(1, 2, mode)` (2000
  here), the composite queue empty and the notice hidden.
- (4) **Round trip through disk**: the snapshot suite writes `egg_pieces = 3`, reads the block's
  `+0x43C` back as 3, loads over a tank holding 1 and gets 3.
- (5) **Coverage**: `headless_level_check` 174 -> 181, `headless_tank_snapshot_check` 54 -> 56,
  `headless_store_ui_check` 65, `headless_integration_check` 136, boot clean.
- (6) **Left stale on purpose** (no field in the save, or unreachable): `waves_spawned`, `completed`,
  `particles`, `laser_sparks`, and live pet bodies.

## EV-0209 - Fresh-eyes review of the load refresh, and the two tank indices collapsed into one
- Date: 2026-11-19
- Type: read-through of `load_game()` against its callers and the suites; code change plus headless
  runs (no new capture: nothing visual changed)
- Source: `scripts/tank/level.gd` (`tank_index`, `setup`, `start_level`, `save_game`, `load_game`),
  `tests/headless_level_check.gd` (`_test_load_refresh`), `scripts/persistence/tank_scalars.gd`
- (1) **Restore order is sound**: scalars (money/quality/quantity/capacity/backdrop/alien selection/
  potion/tint/wave timer) -> store rows and pet flags -> indices and name label -> despawn + snapshot
  restore -> wave selection sync -> per-tank clears -> `egg_price` re-derived from the restored index
  -> backdrop. `egg_price` reads the index only after it is set, and `_refresh_tank_label()` likewise.
- (2) **Finding, fixed**: `Level.tank_index` and `tank.tank_index` were two fields. D-0037 wrote both
  at load but nothing kept them equal anywhere else: `headless_tank_snapshot_check` sets only
  `level.tank.tank_index = 3` (its save header reads 3 while the level's copy reads 1), and the two
  defaults differ (1 vs 0), so a level between `setup()` and `start_level()` already disagreed with
  its tank. `Level.tank_index` is now a property over `Tank+0x3C8` (D-0038); the duplicate load write
  and `start_level`'s mirror are deleted, and `setup()` seeds 1 so the fresh level still stocks 1-1.
- (3) **Finding, left open**: the Time Trial clock. `time_trial_budget_ticks` is derived from
  `tank_index` in `start_level()` only (300 s on tank 1, 600 s on 2-4) and `time_trial_elapsed` is
  never saved, so F9 loading a save that names another tank keeps the previous run's budget and
  elapsed. Fixing it needs the `+0x3FC` elapsed field mapped in `TankScalars` (the block has it, the
  port writes zeroes there), which is a mapping decision this turn did not measure; restoring only
  the budget would leave the elapsed counter contradicting it, so nothing was half-fixed.
  Recorded as open in PLAN R33.
- (4) **Headless**: `headless_level_check` 181 -> 183 (the accessor reads through the tank, a direct
  tank write reads back through the level, and the load restores the one field from the header),
  `headless_tank_snapshot_check` 56, `headless_progression_check` 86, `headless_pet_check` 113,
  `headless_store_ui_check` 65, `headless_integration_check` 136, 400-frame boot clean (the known
  `2 resources still in use at exit` only).

## EV-0210 - Fresh-eyes review of D-0037 and D-0038: one backdrop path, and a vacuous notice assertion
- Date: 2026-11-19
- Type: read-through of `load_game()`, the backdrop trio, `TankScalars`' egg field and both new
  scenarios; code simplification plus headless runs (no capture: the rendered result is unchanged)
- Source: `scripts/tank/level.gd` (`_add_backdrop`, `_backdrop_texture`, `_fit_backdrop`,
  `load_game`), `scripts/persistence/tank_scalars.gd` (`OFF_EGG_PIECES`),
  `tests/headless_level_check.gd` (`_test_load_refresh`), `tests/headless_tank_snapshot_check.gd`
- (1) **Simplified, the backdrop**: D-0037 split `_add_backdrop` into `_backdrop_texture()` +
  `_fit_backdrop()` and added a third `_refresh_backdrop()` that re-derived the sprite, null-checked
  it, and fell back to `_add_backdrop()`. `_add_backdrop` is now the one idempotent path: it looks up
  the `Backdrop` sprite, creates it when missing, and always fits the current texture - so `setup()`,
  `_ready()` and `load_game()` all call the same function and `_refresh_backdrop` is deleted (9 lines
  and one function fewer, and no call site can forget the re-fit).
- (2) **Finding, fixed - a test that could not fail**: `_test_load_refresh` asserted
  `not level.presto_notice_visible()` without ever raising a notice, so `load_game`'s
  `clear_presto_notice()` was unverified (the assertion passed on an already-empty dictionary). The
  scenario now spawns a Presto, raises the real notice (`show_presto_recharging`), pins it visible,
  then loads. `headless_level_check` 183 -> 184.
- (3) **Kept as they were**: `TankScalars`' egg clamp (capture clamps to
  `EGG_PIECES_AT_START..EGG_PIECES_TO_COMPLETE`, apply clamps the same way, so older zeroed blocks
  restore the starting piece) matches the money/quantity clamps and stays; `_fit_backdrop` stays a
  helper because both the create and re-fit paths need the same scale law; the composite-queue
  assertion is not vacuous (the scenario poisons both fields before the load).
- (4) **Not covered by any suite** (recorded, not changed): the backdrop swap itself - every suite
  runs `render = false`, where `_content` is null and `_add_backdrop` returns at its first guard, so
  the only evidence for the art changing is the windowed capture in EV-0208; `_hint_shown`/label
  handling on load (windowed only, EV-0207); and the restore floor for tank 5's three starting pieces
  (open, see R34).
- (5) **Runs**: `headless_level_check` 184, `headless_tank_snapshot_check` 56.

## EV-0211 - Windowed 1-1 load of a tank 2-3 save: four surfaces, and the store rows that went blank
- Date: 2026-11-19
- Type: windowed run of `tools/godot/shot_load_refresh.gd` (windowed, `--audio-driver Dummy`); two
  1280x960 captures (local, gitignored) plus a headless guard
- Source: `tools/godot/shot_load_refresh.gd`, `scripts/tank/level.gd` (`load_game`,
  `_restore_store_shelves`), `scripts/ui/store_bar.gd` (`row_at`), `tests/headless_level_check.gd`
- (1) **The run.** Boots the real main path, starts adventure 1-1, writes a scratch level's save
  (`tank 2 level 3`, wallet 4321, two egg pieces, its own stock table) and loads it under the running
  1-1, reading the name label, the bar's wallet number, the bar's seven price labels and the egg
  dome's price/pieces **before** the load, **right after the call** and **one tick later**.
- (2) **Before**: `Tank  1-1`, wallet 200, dome `$150` at 1/4, rows `[$100, -, -, -, -, -, -]`.
  `shot_load_refresh_before.png` shows exactly that (one guppy dome, the egg dome, the green 200).
- (3) **Right after the call**: the name is already `Tank  2-3` (`load_game` refreshes it), and the
  wallet reads 4321, but the bar still prints `200` and the dome still prints `$150` at 1/4 - the bar
  and the dome repaint from the tank's tick, not from the load, which is the documented split.
- (4) **One tick later (14 frames)**: `Tank  2-3`, bar wallet `4321`, dome `$5000` at 2/4, and the
  rows read `[$100, $200, $300, $250, $750, $1000, -]`, which is the saved 2-3 table
  (`0:0@100, 1:2@200, 2:3@300, 3:5@250, 4:6@750, 5:10@1000`). `shot_load_refresh_after.png`.
- (5) **Finding, fixed (D-0040)**: the first run of the capture had the rows come back **blank** -
  seven empty domes - while the wallet and dome repainted correctly. The save's store rows are the
  fixed 17-byte records (slot, price, base, increment, present, P2.13 §6.3); the port's `shelf` is
  not in them, `load_game` restored the bare records, and `StoreBar.row_at` matches on `shelf`, so
  no shelf found a row. `Level._restore_store_shelves()` now re-derives `shelf` from the stock table
  for the restored tank and level (hidden shelves included). With it, the rows draw.
- (6) **Headless guard**: `_test_load_refresh` now requires every restored row with a real slot to
  carry a `shelf` (and at least one such row to exist, so it cannot pass on an empty table).
  `headless_level_check` 184 -> 185; `headless_tank_snapshot_check` 56, `headless_store_ui_check` 65,
  `headless_integration_check` 136, all PASS.
- (7) **Coverage note**: the repaint itself stays windowed-only evidence - the suite runs
  `render = false`, so it can pin the shelf mapping but not that the bar draws; the captures are the
  visual record.

## EV-0212 - What the base save does with `completed` and `waves_spawned`
- Date: 2026-11-19
- Type: read of the save format notes (`p2.13-saves.md` §6.1/§6.3/§6.4), the progression/mode notes
  and the forward parse evidence; code change plus headless runs (no capture: no visual change)
- Source: `docs/analysis/notes/p2.13-saves.md`, `docs/evidence/p2.13-forward-tank-parse.txt`,
  `docs/analysis/notes/p2.5-economy.md`, `p2.6-progression.md`, `p2.8-aliens.md`, `p2.11-modes.md`,
  `scripts/persistence/tank_scalars.gd`, `scripts/tank/level.gd`, `tests/headless_level_check.gd`,
  `tests/headless_tank_snapshot_check.gd`
- (1) **`waves_spawned` is saved.** `+0x45C` is the wave number, the sixth dword of the 27-dword run
  `+0x444..+0x4AC` inside the 316-byte scalar block (§6.4), i.e. block offset `102 + 0x18 = 126`.
  The forward parse reads it in both shipped samples: `adv1` = 0, `sim1` = 61 (§6.6's "Wave"
  column). Its writers are the wave block's `Tank+0x45C++` on every spawned wave (P2.8 §5) and the
  clear at session init (P2.6 §1.5, P2.11 §7's VT init); its readers are the challenge re-roll's
  `> 4` test (P2.11 §5) and the challenge extra-spawn count `+0x45C / d` (P2.8 §5.1, not ported yet).
- (2) **`completed` is not saved, because the base does not have it.** Completion *is*
  `Tank+0x43C >= 4` (P2.5 §6 step 7: at `+0x43C >= 4` the level-end runs and records `+0x3FC`;
  P2.9 §10 for tank 5). The header's `+0x2A5` (save `0x0C`) is the **whole-tank** latch that starts
  the bonus round, not a per-level flag - a different thing the port already carries as the save's
  "tank-complete" byte.
- (3) **Decision, mapped:** `OFF_WAVE_NUMBER` (126) is captured and applied with the rest of the
  block, so `waves_spawned` travels with the save; `start_level()` now clears it, which is what the
  base's session init does (without it, a fresh level inherited the previous level's count).
  `completed` is derived on load as `egg_pieces >= EGG_PIECES_TO_COMPLETE` (D-0041).
- (4) **Headless**: `_test_load_refresh` saves the counter at 7, poisons 99, and requires 7 after
  the load; it also poisons `completed = true` before a two-piece save and requires it false, then
  writes a four-piece save and requires the load to come back completed. A new
  `_test_wave_counter_reset` pins the level start clearing it. The scalar suite pins the offset
  (126) and the restore. `headless_level_check` 185 -> 191, `headless_tank_snapshot_check` 56 -> 58,
  `headless_progression_check` 86, `headless_integration_check` 136.
- (5) **Left alone**: the rest of the 27-dword run (mode timers, totals, high-water marks) is still
  written as zeroes; only `+0x45C` was in scope here.

## EV-0213 - Every port-only store-row key across a save: `free` matters, the roller's keys do not (yet)
- Date: 2026-11-19
- Type: reader hunt for the row keys the 17-byte record cannot carry, plus a headless scenario
- Source: `scripts/economy/store.gd` (`price_known`, `is_available`, `item`),
  `scripts/tank/level.gd` (`buy_item`, `roll_stock`, `_restore_store_rows`),
  `scripts/ui/store_bar.gd` (egg branch), `scripts/ui/store_screen.gd` (`row_state`, `price_text`),
  `scripts/progression/progression.gd` (`store_rows`), `tests/headless_level_check.gd`
- (1) **The row record** (P2.13 §6.5) is `slot, price, base, increment, present` only. The port adds
  `shelf` (which dome), `free`, and - on the roller row - `kind_roll`, `backdrop`, `pet`.
- (2) **`free` is lost and is the one that matters.** Its only reader is
  `Store.price_known(row) = price > 0 or free`. Every current reader reaches an egg row *around* it:
  `StoreBar.refresh` `continue`s on `Progression.EGG_ITEM` before pricing a dome;
  `Level.buy_item` routes `EGG_ITEM` to `buy_egg()` before the price test; and
  `StoreScreen.row_state` marks the egg row `sold_out` because `Store.item(11)["kind"]` is still
  `KIND_UNAVAILABLE`, so `price_text` returns `SOLD` before `price_known` and `greyed` is true
  either way. So today the lost flag changes no pixel and no purchase - but the row no longer
  round-trips as the table made it, and binding item 11's recovered kind (still open, Q-0052) would
  flip the tank-5 egg from its 0 price to `?` the moment it is loaded.
- (3) **The roller's `kind_roll`/`backdrop`/`pet` are lost and are inert.** They have no reader
  anywhere in `scripts/` - `Level.roll_stock()` writes them and `headless_profile_check` asserts
  them. The row is `slot -1`, which both UIs ignore: the bar matches on `shelf` (the row has none)
  and `StoreScreen.row_state` turns any `id < 0` into "Sold out". The roller's purchase path is not
  ported (Q-0026), so nothing can change on screen from their loss. Left unmapped and recorded.
- (4) **Fix:** `_restore_store_shelves()` became `_restore_store_rows()` and now also re-derives
  `free` as `slot == EGG_ITEM and price == 0`, the same test `Progression.store_rows` makes, so a
  restored row is indistinguishable from a freshly stocked one.
- (5) **Headless** (`_test_loaded_store_rows`): tank 5 level 1 stocks the free egg; the scenario also
  appends a roller-shaped row (`slot -1`, price 15000, `kind_roll` 3, `backdrop` 1), saves, loads
  and requires the egg row's `free` and `price_known` back, the egg's shelf 6 to resolve to the egg
  row rather than the roller, the roller row to come back with no `shelf`, and `buy_item` on the egg
  row to still buy. `headless_level_check` 191 -> 200; the other 22 script suites and the
  integration suite unchanged (script sum 1377, +136 = 1513).
