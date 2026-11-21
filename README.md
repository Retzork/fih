# Insaniquarium Deluxe -> Godot 4.7 remake

Remake of **Insaniquarium Deluxe v1.1 (Steam)** in **Godot 4.7.1**, built from binary analysis
of the original (no source code). The game install is read-only; all behavioral claims live in
`docs/EVIDENCE.md` as `EV-NNNN` entries.

## Handover

**Start with [`AGENTS.md`](AGENTS.md)** (session protocol + hard rules), then
**[`docs/PLAN.md`](docs/PLAN.md)** (source of truth for progress) and
**[`docs/SPECS.md`](docs/SPECS.md)** (the behaviour contract Phase 4 is built against). The detailed
documentation index, repository map, analysis commands and handover checklist are in
**[`docs/README.md`](docs/README.md)**.

**Current status (2026-11-22):** Phase 2 is **closed**, 14/18 systems documented - P2.1-P2.4 and
P2.7-P2.15 are done, P2.5 and P2.6 are substantially complete with tracked open questions, and only
the optional P2.16 (screensaver) / P2.17 (cheats) remain. Phase 3 (assets) is complete.
The 2026-11-08 completion pass was **revoked by the owner after a playtest**: the suites prove
modules, not the assembled game. **The Review table in [`docs/PLAN.md`](docs/PLAN.md) is the
current work list.** R1/R2/R3 (starting money, HUD, egg on the `MENUBAR` dome) and R5/R6/R7
(species art, coin art, pellet sink-out + Angie's re-lay) are fixed with evidence
EV-0162..EV-0176, and R10's masked mermaid tail plus the Hatch card art are in; the Review table has since grown to R48
(R11-R48 fixed 2026-11-10..2026-11-22, latest: the documentation pass, D-0058); **R8 (the owner's live playtest of tanks 2-4 and 5-1 - its windowed frames are captured) and R9 (4 named pet guards: Seymour's aura writer, Amp's click, Nostradamus' sneeze, Walter's glove launch) are open.** R9 was narrowed on 2026-11-10: Wadsworth's shelter, Gumbo's corner steering, Blip's instant unlock and Presto's transform now act in the tank, the CHANGE-O picker and its "Recharging..." notice are in (EV-0177..EV-0182). The suites still pass - **24 headless
checks, 1564 assertions** (23 `--script` suites + the scene-backed integration suite, re-run
2026-11-22) - which is necessary but not sufficient for the assembled feel. The 2026-11-10 additions
are the render path, the 5-1 completion walk, the egg in the bar's seventh dome and the Hatch
card art: the level's effect layer is now covered
(`headless_render_check`), because the
freeze that hung the game (and the desktop with it) lived in `Level._sync_fx` - a `queue_free()` loop
that no `render = false` suite could reach. The port runs the
~36 Hz reading of Q-0034. Validation lives in [`docs/P5-VALIDATION.md`](docs/P5-VALIDATION.md),
with its status withdrawn pending R8.

**The contracts.** Behaviour: [`docs/SPECS.md`](docs/SPECS.md) (P2.18, D-0008) — tick model and click
order, resource loading, entity/tank/creature rules, economy, mode matrix, UI, persistence, audio,
cross-system rules, a shared constant sheet and the open-question index. Assets:
[`docs/PIPELINE.md`](docs/PIPELINE.md). Design: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (P4.1) —
how the remake is put together, including the ~36 Hz `Sim` tick (Q-0034's port decision) with the
original's catch-up rules and the per-tick phase order every new system must register into.
**Consistent rate, one open lead**: Q-0034 - the wrapper loop is 10 ms (100 Hz) but every
gameplay timer calibrates at ~36 Hz, so the simulation runs at the 36 Hz reading (one
`Sim.TICK_MS` constant) until the unfound 100 Hz gate is located. The newest system note is
[`docs/analysis/notes/p2.15-resources.md`](docs/analysis/notes/p2.15-resources.md)
(EV-0150..EV-0154, EV-0157); the latest corrections are EV-0155 (coin predicate), EV-0156 (fish swim
branch) and EV-0157 (the font-global map the UI fonts come from). Audio is at
[`p2.14-audio.md`](docs/analysis/notes/p2.14-audio.md) (EV-0145..EV-0149) and saves at
[`p2.13-saves.md`](docs/analysis/notes/p2.13-saves.md) (EV-0144).

## Quick start

```powershell
git status
git log -1 --oneline

# required for a usable checkout (once, and after asset changes): extract from the owned game
# install into gitignored assets_raw/. content.json and every SpriteFrames resource reference it.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\parse-resources.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\extract-audio.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\decode-music.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\convert-fonts.ps1

# then verify the Godot project imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import

# the tick-driver contract (20 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_sim_check.gd

# the content-registry contract (51 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_content_check.gd

# the entity/tank seam and Food rules (43 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_entity_check.gd

# the Fish entity (148 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_fish_check.gd

# the Coin entity (161 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_coin_check.gd

# the Projectile entity (64 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_projectile_check.gd

# the playable level: feeding, waves, shooting, pets (248 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_level_check.gd

# the level's effect layer: the dot pool tracks the effect lists both ways (17 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_render_check.gd

# the shop screen and the MENUBAR bar (97 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_store_ui_check.gd

# P2.6 progression: store tables, egg prices, pet awards, advance (86 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_progression_check.gd

# the main menu: EV-0131 ids, mode writers, gates and the tail strip (28 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_menu_check.gd

# the assembled path: menu -> level -> wave -> boss -> 5-1 completion (136 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . res://tests/headless_integration_check.tscn --quit-after 1200

# the audio layer: buses, effect pool, music pairs (40 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_audio_check.gd

# tick-driven sprite playback and per-cell keying (18 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_anim_check.gd

# the pet base, roster, steering, slot-81 bodies and Angie's food re-lay (113 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_pet_check.gd

# game modes: Time Trial, Challenge, Virtual Tank, Sandbox + shop wiring (28 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_mode_check.gd

# weapons: Larva, laser sparks, weapon HUD, cue consumers + particles (23 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_weapon_check.gd

# the recovered screens + stock roller + per-mode saves + profile JSON (57 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_profile_check.gd

# the golden tank saves, byte-for-byte against EV-0144 (22 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_golden_check.gd

# aliens + the wave clock + HP-bar geometry (65 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_alien_check.gd

# the Cyrax boss fight (46 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_boss_check.gd

# the tank-save framing (38 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_check.gd

# the save file layer (21 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_files_check.gd

# capture/restore and the level save/load pair (71 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_tank_snapshot_check.gd

# regenerate resources/content.json after any asset regeneration
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_content.gd

# boot the scene for 400 frames (no script errors expected)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 400
```

The boot scene loads the content manifest (`Init` -> `Register` -> `LoadingThread`), then shows the
main menu; choosing Adventure starts the playable level. `tools/godot/screenshot.gd` captures the
menu, the level and the store to `shot_menu.png` / `shot_level.png` / `shot_store.png` when run
windowed (the headless driver renders nothing) - useful for eyeballing the art. For analysis, carve the embedded game module once with
`tools\extract-game-module.ps1` and follow the REA section in `AGENTS.md` / `docs/README.md`;
always cite game-module VAs (D-0009). Extracted assets are personal use only (Q-0006) and
`assets_raw/` is gitignored/regenerable.

## Ground rules

- Never modify anything inside the game install (D-0004).
- Every claim needs an `EV-` entry; correct superseded entries with a new ID, never edit old ones.
- Update `PLAN.md`, `EVIDENCE.md`, `DECISIONS.md` and the current system note as you go; commit
  at session end for diffable handoffs.
- The wiki is a secondary source for names/mechanics context only (D-0010); the binary is proof.
