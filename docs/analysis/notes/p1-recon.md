# Phase 1 recon dossier - Insaniquarium Deluxe v1.1 (Steam)

Status: COMPLETE (2026-10-15). Phase 1 = P1.1..P1.10, all done; evidence EV-0001..EV-0023.
Purpose: orientation for Phase 2+ agents. Read `docs/PLAN.md` + `AGENTS.md` first, then this
file; use EVIDENCE.md for exact claims and `docs/evidence/` for raw data.

## 1. Target identity (see TARGET.md for hashes)

- Canonical: `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe` (read-only, D-0004).
- `Insaniquarium.exe` = `InsaniquariumDeluxe.exe` (byte-identical); `Insaniquarium.scr`,
  `WinFish_Scr.exe` (screensavers); `bass.dll` 92,728 B; `drmss.jpg`.
- Steam appid **3320**; product "Insaniquarium Deluxe"; resolution **640x480** (EV-0021, Q-0005).
- Mirror copy (fallback only): `C:\Users\Fauzi\Documents\project\Insaniquarium Deluxe` -
  every shared file byte-identical (EV-0010); extras there are repack wrappers.
- Local leftovers in the Steam copy (prior attempt on this machine, NOT shipped): `crash.txt`,
  `images\guppy_swim1.gif.frames.png`, `images\balrog.gif.frames.png` (EV-0010; Q-0003 answered).

## 2. Binary facts (EV-0008, EV-0011, EV-0014)

- PE32 x86, image base `0x400000`, 4 sections (.text/.rdata/.data/.rsrc), 7,061 procedures,
  2,496 Ghidra-defined strings (inventory-limited view).
- Static imports: 10 system DLLs only (WSOCK32, KERNEL32, USER32, GDI32, ADVAPI32, SHELL32,
  ole32, OLEAUT32, WININET, WINMM). No exports, no delay-load imports.
- NOT statically imported: `bass.dll`, `ddraw`, `dsound`, `steam(_api).dll`. `LoadLibraryA` is
  imported, `GetProcAddress` is NOT. Dynamic-API resolution mechanism UNKNOWN (protector
  hypothesis, EV-0014) - relevant to P2.13/P2.14. `bass` never appears as a plain string (EV-0019).
- PDB reference: `DRMProtectRun2.pdb` (EV-0009) - build carried PopCap DRM protection tooling.

## 3. Engine / runtime stack (EV-0013, EV-0016, EV-0020)

- **PopCap SexyAppFramework** (C++, MSVC): classes `SexyAppBase`/`SexyApp`, widget system
  (Widget/WidgetManager/Dialog/Button...), `Graphics`/`Image`/`DDImage`/`DDInterface`
  (DirectDraw), `SoundManager`/`DSoundManager` (DirectSound), `XMLParser`, `PropertyBag`,
  `WinInetHTTPTransfer` (explains WININET imports), `OggDecoder`.
- **Lua**: stock Lua **5.0.2** banner embedded (`0x535b40`); a Lua binding layer (`LuaApp`,
  `LuaWidget`, `LuaWidgetTpl<T>`, `LuaLib::MethodWrapper`) compiled in. The on-disk `drm\`
  wrapper scripts are `.luc` files with magic `ESC "LuaV"` - a custom/non-stock container
  (exact format unknown; P1.6 scope).
- **Steam**: legacy `Steam.dll` API (Startup/BlockingCall/IsAppSubscribed/SetUser/Cleanup),
  dynamically loaded; `-steamuser` switch; `SOFTWARE\PopCapInternal\SteamTest` key (EV-0015).
- **DRM**: `PopCapDRM_*` API strings, `?popcapdrmprotect!`/`?popcapdrmprotend!` markers,
  `popcapgame1..3.exe` relaunch names, `drmss.jpg` splash, `PopCapSteamDebugQueryMsg`
  (EV-0012, EV-0017).

## 4. Useful address clusters (Ghidra .rdata view)

| Range | Contents |
| --- | --- |
| `0x5171cc-0x518730` | SexyApp resource-name strings (`sexy.Widget`, `sexy.PlaySample`, ...) |
| `0x53270c-0x532a08` | MSVC CRT strings (`vector destructor iterator`, atexit, ...) |
| `0x5330cc-0x534b04` | DRM/Steam cluster: Steam error strings (`0x5330cc`), `SOFTWARE\PopCap\` (`0x5331a0`), `drmss.jpg` (`0x5331f4`), `-steamuser` (`0x533b68`), `popcapgameN.exe` (`0x533e18`), PopCapDRM_* (`0x53420c+`), steam.dll API names (`0x534a24-0x534ae8`) |
| `0x535b40` | Lua 5.0.2 banner |
| `0x536618` | `SexyChar sizes do not match with current build and state file: ` |
| `0x5540a4-0x55e828` | MSVC RTTI class-name tables (`.?AV...@Sexy@@`, `...@LuaLib@@`) |

## 5. Data map (non-asset files; full list in `docs/evidence/p1.7-datamap.txt`)

- `properties\resources.xml` (21 KB): resource manifest, 333 IDs, 3 groups
  (Init / Register / LoadingThread). Rosters + animation geometry + sounds (EV-0022).
- `properties\partner.xml`: build config (640x480, steam id, screensaver exe) (EV-0021).
- `drm\`: wrapper UI - `drm.xml` configs + `.sig`, `game.png`/`logo.png`, Arial fonts,
  14 compiled Lua scripts (`main`, `DRMApp`, `Screen`, `Layout`, `LuaApp`, `LuaWidget`,
  `LuaCommonWidgets`, `Common`, `Consts`, `DProps`, `Default`, `Bullets`, `ClassLink`, `Game`).
- `data\`: bitmap fonts (`.txt` descriptors + `_*.gif`/`.png` atlases) - P3.8.
- `fishsongs\`: 76 `.txt` note-score files (music puzzle content; semantics unknown).
- `images\` 390 gif + 35 jpg, `sounds\` 50 ogg + 15 au, `music\` 3 mo3 (EV-0018).

## 6. Recognized rosters (from resources.xml; see EV-0022 for full ID list)

- Pets (30): Stinky, Niko, Itchy, Prego, Zorf, Clyde, Vert, Rufus, Meryl, Wadsworth, Seymour,
  Shrapnel, Gumbo, Blip, Rhubarb, Nimbus, Amp, Gash, Angie, Presto, Brinkley, Nostradamus,
  Stanley, Walter, Oscar, Grubber, Starcatcher, Gekko, Breeder, Ultra(vore).
- Aliens/boss (9): Sylvester (+Minisylv), Balrog, Gus, Destructor, Ulysses, Psychosquid,
  Bilaterus, Boss.
- Tanks: AQUARIUM/TANKMASK/TANKBACKDROP 1-6 (six sets).
- Fish visuals: guppy stages (`SIM*`), small, hungry (carnivore), `SIMCARNIVORE`, breeder,
  ultravore, starcatcher.
- Screens: title, tank selector, store, hatch.

## 7. Standing conclusions for Phase 2+

1. Game content is data-driven (names/rosters absent from exe strings, EV-0019); behavior
   numbers (speeds, prices, timers) still likely compile-time constants in `.text` -> classic
   P2 function analysis + byte reads.
2. The `drm\` Lua layer + Steam checks + `DRMProtectRun2` protector form the wrapper; none of
   it should be rebuilt in the Godot remake. In-exe wrapper/game split deferred to P2.13/P2.14.
3. `resources.xml` is the authoritative asset/geometry source -> P3.1 parser first, then P3.2.
4. Open unknowns: `GetProcAddress`-less dynamic resolution; `.luc` container format; BASS load
   mechanism; save/profile format/location; `fishsongs` semantics; `tdb` segment meaning;
   screensaver deltas (P2.16).

## 8. Evidence index for this dossier

- Raw: `docs/evidence/p1.4-*.json/txt`, `p1.5-*.json`, `p1.6-*.json`, `p1.7-*.json/txt`
- Snapshot cache (machine-local): `docs/analysis/snapshots/insaniquarium.json`
- Tool: `tools\pe-imports.ps1` (sections/exports/delay-loads/imports; engine-free)
