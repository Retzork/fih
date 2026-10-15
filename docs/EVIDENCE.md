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
