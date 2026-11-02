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

**Current status (2026-11-02):** Phase 2 is **closed**, 14/18 systems documented - P2.1-P2.4 and
P2.7-P2.15 are done, P2.5 and P2.6 are substantially complete with tracked open questions, and only
the optional P2.16 (screensaver) / P2.17 (cheats) remain. Phase 3 (assets) is complete. **Phase 4 has
started**: P4.1 landed the architecture ([`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)), the fixed-tick
`Sim` driver with its phase registry, the `Game`/`Screens` autoloads and the boot scene; P4.2 landed the
content registry ([`scripts/autoload/content.gd`](scripts/autoload/content.gd)) - all 326 manifest ids
resolved into typed handles through the original's `Init` -> `Register` -> `LoadingThread` phases, from
a committed `resources/content.json`; P4.3 started the entity layer - `SimEntity` + the `Tank` host
(spawn/despawn, phase layers, seeded RNG, pause gate) plus `Food` with its decoded `Update` rules.
Still no gameplay on screen, but the loop, the assets, the entity seam and three headless checks exist.
**Next task: the rest of P4.3** (fish, pets, aliens, coins, projectiles).

**The contracts.** Behaviour: [`docs/SPECS.md`](docs/SPECS.md) (P2.18, D-0008) — tick model and click
order, resource loading, entity/tank/creature rules, economy, mode matrix, UI, persistence, audio,
cross-system rules, a shared constant sheet and the open-question index. Assets:
[`docs/PIPELINE.md`](docs/PIPELINE.md). Design: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (P4.1) —
how the remake is put together, including the 100 Hz `Sim` tick with the original's catch-up rules and
the per-tick phase order every new system must register into.
**One cross-system question blocks tuning**: Q-0034 - the wrapper loop is 10 ms (100 Hz) but every
gameplay timer calibrates at ~36 Hz, so the simulation rate stays parameterised until P5.3 measures
it. The newest system note is
[`docs/analysis/notes/p2.15-resources.md`](docs/analysis/notes/p2.15-resources.md) (EV-0150..EV-0154);
audio is at [`p2.14-audio.md`](docs/analysis/notes/p2.14-audio.md) (EV-0145..EV-0149) and saves at
[`p2.13-saves.md`](docs/analysis/notes/p2.13-saves.md) (EV-0144).

## Quick start

```powershell
git status
git log -1 --oneline

# verify the Godot project imports (exits 0)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import

# the tick-driver contract (17 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_sim_check.gd

# the content-registry contract (51 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_content_check.gd

# regenerate resources/content.json after any asset regeneration
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_content.gd

# the entity/tank seam and Food rules (38 assertions; exits 0 on pass)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tests/headless_entity_check.gd

# boot the scene for 180 frames (no script errors expected)
& "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 180
```

There is no gameplay yet: the boot scene loads the content manifest (logging `Init` -> `Register` ->
`LoadingThread`) and shows only the FPS/tick/content overlay, because P4.3 onwards builds entities and
screens on top of it. For analysis, carve the embedded game module once with
`tools\extract-game-module.ps1` and follow the REA section in `AGENTS.md` / `docs/README.md`;
always cite game-module VAs (D-0009). Extracted assets are personal use only (Q-0006) and
`assets_raw/` is gitignored/regenerable.

## Ground rules

- Never modify anything inside the game install (D-0004).
- Every claim needs an `EV-` entry; correct superseded entries with a new ID, never edit old ones.
- Update `PLAN.md`, `EVIDENCE.md`, `DECISIONS.md` and the current system note as you go; commit
  at session end for diffable handoffs.
- The wiki is a secondary source for names/mechanics context only (D-0010); the binary is proof.
