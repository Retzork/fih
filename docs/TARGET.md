# Target dossier - Insaniquarium Deluxe v1.1 (Steam)

Last verified: 2026-10-15

## Game (canonical analysis target - READ ONLY)

- Install root: `C:\Games\Steam\steamapps\common\Insaniquarium Deluxe`
- Title: Insaniquarium Deluxe v1.1 (readme.html and crash.txt agree); developed by Flying Bear
  Entertainment, published by PopCap Games; Steam edition.
- Layout: loose files (no `.pak` archives observed); assets as `.gif/.jpg` under `images\`,
  audio as `.ogg/.au` under `sounds\`, music as `.mo3` under `music\`, manifests as XML under
  `properties\` (`resources.xml`, `partner.xml` + `.sig`).

### Executables and libraries (SHA-256, size)

| File | SHA-256 | Size |
| --- | --- | --- |
| `Insaniquarium.exe` | `f54c2c6ee54b00ae6da7f4bde15feb90d0a867aba6b4151b0277c1f81da3ff66` | 3,787,832 |
| `InsaniquariumDeluxe.exe` | `f54c2c6ee54b00ae6da7f4bde15feb90d0a867aba6b4151b0277c1f81da3ff66` | 3,787,832 (byte-identical to above) |
| `Insaniquarium.scr` | `beceb69377a570d5aa07ccc1784f2e1768e05ca21abdf59d68c02610b23a0bf8` | 274,432 |
| `WinFish_Scr.exe` | `c904b14cfbf985043aca01b7d77bc06d0fd24101800e49fa6fc374ce5b92b878` | 2,172,232 |
| `bass.dll` | `d98cd5d6ed9c4a95701684aa83777cefd5d8096e14c836493f67159d68161c01` | 92,728 |

Other root files: `crash.txt`, `drmss.jpg`, `license.txt`, `readme.html`.

### Secondary copy on this machine (non-canonical mirror)

- Path: `C:\Users\Fauzi\Documents\project\Insaniquarium Deluxe\` (repack build; extra wrapper
  files `revLoader.exe`, `rev.ini`, bundled Steam client DLLs, `steam_appid.txt`).
- `Insaniquarium.exe` and `bass.dll` are **byte-identical** to the canonical Steam install
  (EV-0007); full-tree comparison shows every shared file byte-identical (EV-0010).
- User authorizes this copy as a fallback source if the Steam install is insufficient; analysis
  still defaults to the Steam install (D-0001).

### Notes

- `crash.txt` is a **local leftover from a prior run** (12 Aug 2026 15:53; absent from the mirror
  copy; EV-0010), not shipped content. Internal module name `popcapgame1.exe`, Product
  "Insaniquarium", Version 1.1, DirectDraw/DirectSound usage. Historical only.
- `images\balrog.gif.frames.png` and `images\guppy_swim1.gif.frames.png` are leftovers of a prior
  attempt on this machine (batch mtime 12 Aug 2026 12:15:16; absent from mirror; Q-0003 answered
  in EV-0010).
- Static imports (EV-0011): 10 system DLLs only - no bass.dll / ddraw / dsound / steam_api;
  `LoadLibraryA` imported but `GetProcAddress` not (dynamic-resolution mechanism unknown; P1.6).
  4 on-disk sections only; no exports; no delay-load imports (EV-0014).
- Engine: PopCap **SexyAppFramework** (MSVC RTTI class map in `.rdata`) with embedded
  **Lua 5.0.2**; Steam integration via legacy `Steam.dll` API; DRM build `DRMProtectRun2`
  (EV-0009, EV-0013, EV-0015, EV-0016).
- Content is data-driven: pet/alien/fish names do not appear in exe strings; rosters live in
  `properties\resources.xml` (333 IDs; 30 pets, 9 aliens, 6 tank sets) - EV-0019, EV-0022.
  `properties\partner.xml`: 640x480, Steam appid 3320, ScrExe `WinFish_Scr.exe` - EV-0021.
- Wrapper layer on disk: `drm\` folder (config XMLs + `.sig`, DRM screens, 14 compiled custom-Lua
  `.luc` scripts) - EV-0020, EV-0023.

## Remake project

- Root: `C:\Users\Fauzi\Documents\project\fih\fih` (Godot 4.7, Forward Plus, `canvas_items`
  stretch, Jolt for 3D; 2D game, 3D physics unused).
- Editor: Godot 4.7.1 stable at `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe` (also a
  zip + exe copy in `Downloads\`). `--headless --import` of this project exits 0 (2026-10-15).
- `project.godot` `config/name="fih"` (kept as-is per Q-0002).
- Local git repo on `main` (initial commit `68f1d75`; Q-0008).

## Analysis environment (2026-10-15, verified working)

| Component | Version / value |
| --- | --- |
| OS | Windows (Nano Server-compatible? no) - win32 x64, NT 10 |
| Node.js / npm | 24.16.0 / 12.2.0 |
| rea-agents CLI | 6.5.0 (global) |
| Ghidra | 12.1.4 PUBLIC at `C:\tools\ghidra_12.1.4_PUBLIC` (zip SHA-256 `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` verified) |
| JDK | Temurin 21.0.12.1+1 (64-bit) at `C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot` |
| REA repo (docs/skill) | `C:\Users\Fauzi\Documents\project\rea` |
| winget | 1.29.380 |

Environment variables (User scope, set 2026-10-15):

- `GHIDRA_INSTALL_DIR = C:\tools\ghidra_12.1.4_PUBLIC`
- `JAVA_HOME = C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot`
- `REA_ANALYSIS_PROVIDER = ghidra`

If a shell does not inherit them (started before the change), use `tools\rea.ps1`, which sets
them per-invocation.

## Provider boundary (Windows Ghidra P0 - read the full doc before assuming capabilities)

- Read-only analysis; 26 inventory/memory/function operations. No database mutation
  (`annotate_native_function` unavailable on Windows).
- Windows admission is limited to native x86/x86-64 PE and raw NMOS 6502 images. No DOS MZ/COM on
  Windows - if a fallback target ever needs DOS analysis, it must happen on Linux/macOS.
- First query on a target pays a Ghidra import cost (up to ~330 s deadline); use the shared
  snapshot file to avoid re-imports across sessions.
- Full doc: `C:\Users\Fauzi\Documents\project\rea\docs\windows-ghidra-p0.md`.
