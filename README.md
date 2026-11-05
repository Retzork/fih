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

**Current status (2026-11-05):** Phase 2 is **closed**, 14/18 systems documented - P2.1-P2.4 and
P2.7-P2.15 are done, P2.5 and P2.6 are substantially complete with tracked open questions, and only
the optional P2.16 (screensaver) / P2.17 (cheats) remain. Phase 3 (assets) is complete. **Phase 4 is
well underway:** P4.1-P4.3 are complete; P4.4-P4.14 are in progress, with P4.10/P4.11 partial.
The playable level, store, game selector, audio layer, saves, pets, aliens and Cyrax boss are
in, and **19 headless checks pass (992 assertions)**. The port runs the ~36 Hz reading of Q-0034.
**Next task: P4.10/P4.11** (projectile homing/weapon follow-ups and game modes), with the remaining
sub-items on the in-progress tasks tracked in [`docs/PLAN.md`](docs/PLAN.md).

**The contracts.** Behaviour: [`docs/SPECS.md`](docs/SPECS.md) (P2.18, D-0008) — tick model and click
order, resource loading, entity/tank/creature rules, economy, mode matrix, UI, persistence, audio,
cross-system rules, a shared constant sheet and the open-question index. Assets:
[`docs/PIPELINE.md`](docs/PIPELINE.md). Design: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (P4.1) —
how the remake is put together, including the ~36 Hz `Sim` tick (Q-0034's port decision) with the
original's catch-up rules and the per-tick phase order every new system must register into.
**One cross-system question blocks tuning**: Q-0034 - the wrapper loop is 10 ms (100 Hz) but every
gameplay timer calibrates at ~36 Hz, so the simulation rate stays parameterised until P5.3 measures
it. The newest system note is
[`docs/analysis/notes/p2.15-resources.md`](docs/analysis/notes/p2.15-resources.md) (EV-0150..EV-0154);
the latest corrections are EV-0155 (coin predicate) and EV-0156 (fish swim branch). Audio is at
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

# the entity/tank seam and Food rules (38 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_entity_check.gd

# the Fish entity (105 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_fish_check.gd

# the Coin entity (87 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_coin_check.gd

# the Projectile entity (50 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_projectile_check.gd

# the playable level: feeding, waves, shooting, pets (121 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_level_check.gd

# the shop screen's shelves, prices and states (34 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_store_ui_check.gd

# P2.6 progression: store tables, egg prices, pet awards, advance (79 assertions)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_progression_check.gd

# the main menu: EV-0131 ids, mode writers, gates and the tail flop (37 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_menu_check.gd

# the assembled path: menu -> level -> wave -> boss + UI fonts (37 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . res://tests/headless_integration_check.tscn --quit-after 1200

# the audio layer: buses, effect pool, music pairs (40 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_audio_check.gd

# tick-driven sprite playback and per-cell keying (18 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_anim_check.gd

# the pet base + Stinky/Niko/Angie/Vert/Shrapnel/Nostradamus (66 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_pet_check.gd

# aliens + the wave clock + HP-bar geometry (61 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_alien_check.gd

# the Cyrax boss fight (35 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_boss_check.gd

# the tank-save framing (38 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_check.gd

# the save file layer (21 assertions; exit 0 = pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_save_files_check.gd

# capture/restore and the level save/load pair (54 assertions; exit 0 = pass)
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
