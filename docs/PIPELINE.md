# Asset pipeline & Godot usage guide (Phase 3 output contract for Phase 4)

Status: **Phase 3 complete** (2026-10-15, P3.1-P3.8; evidence EV-0024..EV-0033). This document is
the bridge between the extracted assets and the Godot implementation: what exists, where it came
from, how to (re)generate it, and how P4 is expected to consume it. Read it before any P4 task
that touches assets.

Rules that always apply: the game install is READ-ONLY (D-0004); `assets_raw/` is regenerable and
gitignored; extracted PopCap assets are personal use only (Q-0006).

## 1. Data flow

```
install (read-only)                                     durable repo artifacts
  properties\resources.xml  --tools\parse-resources.ps1-->  docs\analysis\resources.json
  images\ sounds\ music\ data\
    ├─ tools\extract-assets.ps1 --> assets_raw\{images,masks,frames}\ + extraction.json   (P3.3)
    ├─ tools\extract-audio.ps1  --> assets_raw\sounds\              + audio.json          (P3.6)
    ├─ tools\decode-music.ps1   --> assets_raw\music\               + music.json          (P3.7)
    └─ tools\convert-fonts.ps1  --> assets_raw\fonts\               + fonts.json          (P3.8)
  assets_raw\extraction.json --tools\godot\gen_spriteframes.gd--> resources\sprites\<ID>.tres
                                                                 (129 files, committed, EV-0030)
```

Regeneration (from the project root, in this order):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\parse-resources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_spriteframes.gd
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/verify_fonts.gd
```

`--import` must run after new asset files appear before Godot can `load()` them. Keeping the repo
clean: `assets_raw/` and `.godot/` are gitignored; only `resources/sprites/*.tres` and the
`docs/analysis/*.json` inventories are committed.

## 2. What is where

| Path | Content | Inventory/manifest |
| --- | --- | --- |
| `assets_raw\images\` | 244 PNGs (all manifest images, 1:1 from GIF/JPG) | `extraction.json` |
| `assets_raw\masks\` | 179 grayscale PNGs (alpha sources, whole sheets) | `extraction.json` |
| `assets_raw\frames\` | 3,036 sliced frames (`<ID>\fNNN.png`, row-major) - `.gdignore`d | `extraction.json` |
| `assets_raw\sounds\` | 50 copied `.ogg` + 15 `.au`-decoded `.wav` | `audio.json` |
| `assets_raw\music\` | `Alien.ogg`, `Insaniq2.ogg`, `Lullaby.ogg` | `music.json` |
| `assets_raw\fonts\` | 15 BMFont `.fnt` + matching composed page `.png`; `raw\` keeps the 1:1 source layers | `fonts.json` |
| `resources\sprites\` | 129 `SpriteFrames` (`<ID>.tres`), AtlasTexture regions (committed) | generator self-verifies |
| `docs\analysis\resources.json` | 326 manifest resources: `id`, `type` (Image/Font/Sound), `file`, `attrs`, resolution provenance | EV-0024/0025 |

Manifest notes for a P4 loader (P4.2): attribute values may be unquoted (`cols=3`) and bare
booleans appear (`ddsurface`); 14 image ids resolve to underscore-variant filenames
(`_maskN.jpg`, `_EditBox.gif`, ...) - engine fallback behavior is an unverified hypothesis
(EV-0025). `extraction.json` per id records: source file, mask file, `declared`/`inferred` grid,
cell size, frame rects, `framemap`, delay attrs, `selfMask` flags.

## 3. Art model (EV-0026, EV-0027, EV-0028)

- Character/effect sheets: **80x80 px cells, 10 columns**; declared grids all divide exactly.
  30 sheets carry no declared grid and were sliced with an inferred 10-column grid
  (`inferred: true` in `extraction.json`).
- **Two-layer model**: base file = color/ink (243/246 GIFs have no alpha), companion grayscale
  mask supplies alpha at runtime. Exceptions with built-in transparency: `SLIDERTHUMB`,
  `HELPALIEN`, `HELPPETCHOOSE`. 36 images are grayscale-only and are believed to be colorized at
  runtime (laser colors, wave tints, sim fish) - INFERRED, needs P2 confirmation.
- SIM fish are two-layer: eyes in the base file, body silhouettes in the mask; `SIMSWIM2/3`,
  `SIMEAT2/3`, `SIMTURN2/3` have no mask on disk (composition rule is a P2 topic).
- `alphagrid` masks are one grid cell in size (tileable), not a whole-sheet mask.
- `framemap` = playback order; `-1` means skip (applied in the `.tres` already, e.g. MERYLBLINK).
  Frame delays live in the manifest but their unit is unresolved (P2.1) - do NOT bake speeds yet.
- Unreferenced leftovers: `images\nebula1.jpg`, `images\talkshow.jpg`, two prior-attempt PNGs
  (EV-0010/0029). Music/fonts load outside the manifest.

## 4. Using assets in Godot (for P4 tasks)

### Sprites & animations
- `resources\sprites\<ID>.tres` is a `SpriteFrames` with a single animation `"default"`; frames
  are `AtlasTexture` regions over `assets_raw\images\<basename>.png` (129 multi-cell ids).
- Single-cell images have NO `.tres` - load the PNG directly (buttons, backdrops, cursors).
- Example wiring:

```gdscript
var sf: SpriteFrames = load("res://resources/sprites/EXPLOSION.tres")
animated_sprite.sprite_frames = sf
animated_sprite.play("default")
```

- Masks are separate textures (`assets_raw\masks\<name>.png`, grayscale); composition/tint is
  decided per system in P2 notes, not here. Keep base and mask layers uncompressed until P2 says
  otherwise.
- Rendering policy: native pixel sizes at 640x480 logical resolution, integer scaling, nearest
  filtering (Q-0005).

### Fonts
- `assets_raw\fonts\<ID>.fnt` (BMFont text) + `<ID>.png` (page). Load as `FontFile`:

```gdscript
var font: FontFile = load("res://assets_raw/fonts/LIDDIE12.fnt")
label.add_theme_font_override("font", font)
label.add_theme_font_size_override("font_size", 12)  # native size = "size=" in the .fnt
```

- Composition model is D-0007: page RGB = base atlas pixel, A = luminance(mask|self). This
  reproduces the original tint-fill/outline behavior under Godot `modulate`. Raw layers are kept
  in `fonts\raw\` and all raw metrics in `fonts.json` for P2.12 refinement (line advance and
  two-pass outline rendering are open items).
- Verified: all 15 fonts load and cover their exact source char lists (EV-0033).

### Sounds
- `assets_raw\sounds\*.ogg|*.wav`; id -> file mapping and attrs (`volume`, `alias`) live in
  `audio.json`. Example alias: `AWOOGA alias=START` - resolve aliases through the manifest, not
  by filename guessing.

### Music
- `assets_raw\music\{Alien,Insaniq2,Lullaby}.ogg` (EV-0032). Tracker loop semantics are NOT yet
  recovered (P2.14) - play them non-looped or with a temporary rule until then.

### Cursors
- `assets_raw\images\cursor_pointer.png`, `cursor_hand`, `cursor_dragging`, `cursor_text`,
  `crosshair`, `arrow1` (HELPARROW) + their masks. Use
  `Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)`. Hotspots and intended
  scale are not yet recovered (see open items).

## 5. Open items P4 must respect (do not silently guess)

| Item | Where recorded | Resolved by |
| --- | --- | --- |
| Frame delay units / animation speed | EV-0026, EV-0030, `extraction.json` delays | P2.1 |
| Grayscale runtime colorization (36 images) | EV-0027 | P2.2 / P4.3 |
| SIM fish mask/body composition | EV-0027 | P2.2 |
| Underscore filename fallback semantics | EV-0025 | P2.15 / P4.2 |
| `EDITBOX` 90x42 vs `_EditBox.gif` 96x33 | EV-0027 | P2.12 |
| Mask compositing for all UI/tank art | EV-0027/0028, D-0007 | per-system P2 notes |
| MO3 loop points | EV-0032 | P2.14 |
| Cursor hotspots/scale | this doc | P2.12 / P4.14 |

## 6. Tooling gotchas (learned the hard way)

- PowerShell 5.1: never name a helper function `Compare` (collides with the `Compare-Object`
  alias) - use distinct names.
- ffmpeg (winget Gyan build, 8.1.1) is required for P3.6/P3.7 regeneration; it ships libopenmpt
  (MO3) and libvorbis. `ffprobe` is used throughout for verification.
- `assets_raw\frames\` is `.gdignore`d so Godot never imports the 3,036 loose frame PNGs; the
  `.tres` files address the sheets, not individual frames.
- Godot CLI runs used throughout: `--headless --path . --import` and
  `--headless --path . --script res://tools/godot/<tool>.gd` (exit code 0 = pass).
- `tools\pe-imports.ps1` works for the exe but fails on `bass.dll` (import-walk bug); BASS is
  not needed by this pipeline (D-0006).
