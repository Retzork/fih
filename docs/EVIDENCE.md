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
