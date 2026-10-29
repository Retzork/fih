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
