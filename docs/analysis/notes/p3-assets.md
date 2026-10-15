# Phase 3 notes - asset extraction & pipeline

Status: P3.1-P3.7 complete (2026-10-15); EV-0024..EV-0032. P3.8 (fonts/UI/cursor) pending.
Read `AGENTS.md` + `docs/PLAN.md` first; exact claims live in `docs/EVIDENCE.md`.

## Tools built

| Tool | Purpose | Output |
| --- | --- | --- |
| `tools/parse-resources.ps1` | Parse `properties/resources.xml` into a machine-readable inventory; case-insensitive disk resolution; mask-candidate recording | `docs/analysis/resources.json` |
| `tools/inspect-images.ps1` | Per-image geometry + layer classification (dims, declared grid, mask stats, grayscale/color, zero-alpha) | `docs/analysis/p3.2-image-report.json` |
| `tools/extract-assets.ps1` | Slice multi-cell grids into per-frame PNGs; copy all bases/masks 1:1 (P3.3) | `assets_raw/{images,masks,frames}`, `assets_raw/extraction.json` |
| `tools/godot/gen_spriteframes.gd` | Godot headless SpriteFrames generator from the extraction manifest (P3.5) | `resources/sprites/<ID>.tres` |
| `tools/extract-audio.ps1` | Sounds: copy `.ogg` 1:1, decode `.au` -> WAV (P3.6) | `assets_raw/sounds/`, `assets_raw/audio.json` |
| `tools/decode-music.ps1` | Music: `.mo3` -> OGG via ffmpeg/libopenmpt (P3.7) | `assets_raw/music/`, `assets_raw/music.json` |

Run from the project root with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/<tool>.ps1`.

## P3.1 - manifest inventory (EV-0024, EV-0025)

- 326 resources: 246 images, 15 fonts, 65 sounds; groups Init 14 / Register 16 / LoadingThread 296.
- Manifest syntax quirks handled: unquoted attribute values (`cols=3`, `cols=4`), bare boolean
  attribute (`ddsurface`). The game's SexyApp XMLParser accepts both; strict XML parsers reject.
- Count corrections vs EV-0022 (regex artifacts): "333 ids" = 329 true element ids + 4 matches
  inside `alphagrid="`; sounds are 65, not 68.
- Resolution: 312/326 entries by plain name; 14 images exist only as underscore variants
  (leading: TANKMASK1-6 -> `_maskN.jpg`, HATCHREFLECTION, MENUBUTTONREFLECTION; trailing:
  TITLEPAGEMASK, PETBUTTONREFLECT, PETBUTTONHOLE, STORE*HILIGHT). Engine fallback behavior is
  UNVERIFIED (hypothesis for P2/P4).
- Unreferenced asset files: 7 - two prior-attempt leftovers (EV-0010), `images/nebula1.jpg`,
  `images/talkshow.jpg` (use unknown), `music/*.mo3` (not in manifest; loaded elsewhere).

## P3.2 - geometry & layers (EV-0026, EV-0027)

- All 246 declared grids divide exactly (no remainder issues).
- Character/effect sheets use **80x80 px cells, 10 columns**. 30 sheets carry NO declared grid
  but are multi-cell: SIM* 800x240 (10x3), SMALL*/HUNGRY* 800x400 (10x5), SIMCARNIVORE and
  HUNGRYBREEDER 800x960 (10x12). Prior-attempt leftover `guppy_swim1.gif.frames.png` shows the
  same 10x3 eye layout, independent corroboration.
- Alpha model observed: 243/246 base GIFs have no transparent pixels; a grayscale mask companion
  supplies alpha (204/246 images have a literal mask file; 17 explicit via alphagrid/alphaimage,
  187 via underscore candidates). 3 exceptions with built-in transparency: SLIDERTHUMB,
  HELPALIEN, HELPPETCHOOSE.
- `alphagrid` masks are one grid cell in size (e.g. `mainbutton_` 90x29 vs base 270x29 for
  cols=3). `EDITBOX` 90x42 vs `_EditBox.gif` 96x33 is the one unexplained mismatch.
- 36 base images are grayscale-only (effects: SPARKLE, ENERGYBALL, LASERS, SMOKEMISSILE,
  MISCITEMS, WAVESIDE, WAVE; sim fish: SIM*; masks-as-images: TANKMASK1-6, TITLEPAGEMASK;
  others). Inference (unverified): engine colorizes these at runtime (laser upgrade colors,
  wave tints); needs P2 code confirmation.
- SIM fish two-layer art: base file holds eyes on black (e.g. `guppy_swim1.gif`), companion mask
  holds 3-size body silhouettes (`_guppy_swim1.gif`); SIMSWIM2/3, SIMEAT2/3, SIMTURN2/3 have no
  mask file on disk. Composition/tint behavior is a P2 concern; extraction keeps layers separate.

## P3.3 - extraction output (EV-0028)

- `tools/extract-assets.ps1` -> `assets_raw/` (gitignored, regenerable).
- 244 base PNGs (`images/`), 179 mask PNGs (`masks/`), 3,036 frames (`frames/<ID>/fNNN.png`,
  row-major), `extraction.json` manifest with grid provenance (`declared` | `inferred`).
- GDI+ 32bppArgb pipeline, DrawImageUnscaled, exact cell crops; spot check 0/6,400 pixel diffs.
- Shared files deduped (masks shared by 6 backdrops / 4 eggs / 2 AA tops; PEANUT=blank,
  MENUBTND2=mbuttond); self-mask entries (TANKMASK*, underscore-only) flag `selfMask: true`.
- Masks are whole sheets; frames stay separate layers (no compositing) - see decision below.

## P3.5 - Godot import (EV-0030)

- `tools/godot/gen_spriteframes.gd` (headless `--script`) emits one SpriteFrames per multi-cell
  image: `resources/sprites/<ID>.tres`, frames as AtlasTexture regions over the sheet PNGs.
  framemap order applied where declared; delays NOT baked (units unresolved until P2.1).
- 129 generated / 129 reload-verified, 3,038 frames, 648 KB; Godot import of `assets_raw` =
  423 files (`frames\` excluded via `.gdignore`; sounds/music added later -> re-import on demand).

## P3.6 - sounds (EV-0031)

- `tools/extract-audio.ps1`: 65 manifest sounds -> `assets_raw/sounds/` (50 `.ogg` copied 1:1 +
  15 `.au` = `pcm_mulaw` 8 kHz mono -> `pcm_s16le` WAV). 0 probe failures, 752,298 bytes;
  volume/alias attrs preserved in `assets_raw/audio.json`.

## P3.7 - music (EV-0032, D-0006)

- ffmpeg 8.1.1 ships libopenmpt, so `.mo3` (MO3 v1) demuxes natively - no BASS P/Invoke needed.
  `tools/decode-music.ps1` -> `assets_raw/music/*.ogg` (libvorbis `-q:a 5`, 48 kHz stereo) +
  `music.json` with source SHA-256s.
- 3 files: Alien (10.24 s, "Alien Battle Music"), Insaniq2 (113.66 s, "Winfish"), Lullaby
  (115.70 s, no title). Tracker loop semantics unresolved (P2.14 concern). Side note:
  `tools/pe-imports.ps1` fails on `bass.dll` (import-walk ArgumentOutOfRangeException) - the
  export-listing route was retired, not needed.

## Extraction rules for P3.3 (decided)

1. Convert every base image and mask 1:1 to PNG (no compositing, no re-coloring): fidelity first.
2. Slice frames only for multi-cell grids; cell order row-major (col + row*cols); `framemap`
   and delays stay metadata (they define playback, not storage).
3. Undeclared character sheets get the 10x80px rule as an INFERRED grid, tagged `inferred: true`
   in the extraction manifest.
4. Masks are extracted as full sheets (not per-frame); Godot import can sub-rect them.
