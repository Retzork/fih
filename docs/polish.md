# Polish - final-touch feedback

Owner playtest feedback captured 2026-11-22, plus agent suggestions for the final polish pass.
This is a working checklist, not evidence: no `EV-` entries exist for these items yet.

**Triaged 2026-11-22:** the 15 owner items are folded into
[`REVIEW.md`](REVIEW.md) as **R52-R66** (R54 confirmed covered by R51 on a windowed re-check, EV-0233;
R66 fixed 2026-11-22, EV-0234; the rest open); this file keeps the owner's wording and the suggested starting points. The agent
suggestions below remain untracked in PLAN.

## Owner feedback

### Fish and movement

- [ ] **Swim speed feels off.** The fish do not move at the pace the original shows.
- [ ] **Swim target is far off.** Fish aim for a point noticeably away from where they should be heading.
- [ ] **Swimming direction is wrong.** The facing/direction does not match the movement.
  - *2026-11-22:* covered by R51 (EV-0232) and confirmed on a windowed 1-1 frame: fish draw
    head-first in the direction of travel (`captures/shot_facing.png`, EV-0233). R54, no open work.
- [ ] **Size-up animation is missing.** Fish do not play the growth/size-up transition.

### Coins

- [ ] **Coin death is too fast.** The coin disappears before it reads.
- [ ] **Coin pickup animation is missing.** Collecting a coin has no animation.

### Egg and pets

- [ ] **Egg animation when a pet is revealed is wrong.** The reveal does not match the original.
- [ ] **Pet animation is weird.** Only the snail has been checked so far.
- [ ] **Pet select screen is missing.** The screen for choosing pets is absent.

### Aliens

- [ ] **Alien hitbox is wrong.** Clicks/hits do not land where the alien is drawn.
- [x] **Aliens should not have a health bar by default.** The HP bar is shown when it should be hidden (related: Q-0058). Fixed 2026-11-22 as R62 (EV-0235): `Tank.show_alien_health` defaults off; Cyrax's bar stays.
- [x] **Alien sprite background is not properly masked when the sprite has a hole inside it.** The transparency/keying leaves a filled hole. Fixed 2026-11-22 as R63 (EV-0236): alien cells compose their mask companion; the border key stays for unmasked sheets.

### Shop and UI

- [ ] **The dome shop is slightly off size.** The dome row/geometry does not match the original.
- [ ] **Lose screen is missing.** There is no game-over/loss screen.

### Upgrades

- [ ] **Pellet upgrade isn't working.** Buying/using the pellet upgrade has no effect. ("pellete" in the original feedback.)

## Agent suggestions

These are additions from the agent, not owner feedback. They are ordered by player impact.

- [ ] **Audio defaults and mix.** The port starts muted (Q-0056); consider a first-run sound prompt or a clearly visible master volume, and verify every cue/music pair and both sliders.
- [ ] **Save/load feedback and robustness.** Add a brief "Saved" confirmation, handle missing/corrupt saves without losing the profile, and make load failures visible instead of silent.
- [ ] **Pause every clock.** Verify Options pauses the level, wave, hunger, bonus round, pet timers and FX; resume must not fast-forward through the Sim catch-up clamp.
- [ ] **Window/display polish.** Fullscreen toggle, letterboxing at non-4:3 sizes, cursor visibility, and auto-pause on alt-tab/focus loss.
- [ ] **Input polish.** Keyboard navigation (arrows/Enter/Escape) for menus and dialogs, a visible focus state, and no click-through behind modals.
- [ ] **Hit and collection feedback.** Alien hit flash/knockback, coin fly-to-wallet, pellet splash, and an HP bar that appears on hit/hover instead of always (ties to the owner's HP-bar item).
- [ ] **UI text and scaling.** Check every label at 640x480 and 1280x960 for clipping, add shop tooltips, and keep `$`/number formatting consistent.
- [ ] **Failure UX.** If a content asset is missing, show the missing ID/path in a readable error screen instead of a crash; add a boot self-check.
- [ ] **Performance and stability.** Avoid per-frame rebuilds/allocations, cap particle counts, and profile a busy tank plus the 1200-frame integration path.
- [ ] **Release packaging.** Add an export preset, version stamp, quick-start README, and keep debug keys/tools behind a dev flag.

## Suggested starting points

Suggestions only, not diagnoses. Paths are relative to the project root (`fih/fih/`).

| Area | Likely files |
| --- | --- |
| Fish movement/growth | `scripts/entities/fish.gd`, `scripts/tank/level.gd` |
| Coins | `scripts/entities/coin.gd` |
| Egg/pets | `scripts/ui/egg_widget.gd`, `scripts/entities/pet.gd`, `scripts/ui/hatch_screen.gd`, `scripts/ui/pets_screen.gd` |
| Aliens/HP bar | `scripts/entities/alien.gd`, `scripts/tank/level.gd` |
| Dome shop | `scripts/ui/store_bar.gd` |
| Lose screen | `scripts/main.gd`, `scripts/tank/level.gd` |
| Pellet upgrade | `scripts/tank/level.gd`, `scripts/progression/progression.gd`, `scripts/economy/store.gd` |

## Rules for fixing

- Verify each item against the original game (binary or recording) before calling it fixed; add an `EV-` entry for the recovered behaviour.
- Keep the owner's wording above and add a short note under each item as the cause is found.
- Re-run the relevant headless suite and capture a windowed frame for visual items.
