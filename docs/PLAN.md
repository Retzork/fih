# Master plan - Insaniquarium Deluxe (v1.1 Steam) -> Godot 4.7 remake

Last updated: 2026-11-24 (review pass - **R65, R57 and R60 fixed**: the loss is the shipped
"GAME OVER" card (title / "Oops!  All of your fish have died!" / "Click to Continue") that
`Tank::CanContinue` raises once the tank has no living fish, with the coins collected first, and the
port no longer invents a screen for it; a collected coin throws its recovered `rand%3+3` pickup burst
(kind 0x11 `rand%2+2`) so a pickup reads; the loss card is the base's message id 17 (rescue 16, one generic dialog class for every id);
the pet chooser is the shipped 24-button grid with the
four-pet cap, and a selection now draws `PETBUTTON`'s bright gold face (clipped to the dome
silhouette) plus its ring while every other dome is dimmed (the `PETBUTTONHOLE`/`PETBUTTONREFLECT`
layers are gone - those ids are the sheets' alpha companions, not art). R60's per-row indent stops being asserted as recovered and is now pinned only as its centring invariant; R56 is covered by the burst (the
expiries stay pinned to P2.5 §5) and R29's two hint deviations are confirmed fixed in R42. New
evidence EV-0246..EV-0252; D-0061/D-0062 and Q-0063/Q-0065 carry the port fits and the open handler.
All 26 script suites pass, **1,726 assertions**, plus the 139-assertion integration scene = 27 checks
/ 1,869; the 400-frame boot exits 0.)
A scene gallery (`docs/review/scenes.html`, one labelled capture per implemented screen from a
single live run) now sits beside `REVIEW.md`; regenerate it with `tools/godot/scene_gallery.gd` and
`tools/review/build_scenes.py`.



Last updated: 2026-11-22 (polish triage + Phase 2 reconciliation - R52-R66 folded in from
`polish.md`; P2.5 and P2.6 closed (P2 now 16/18) with their stale open lists corrected and the
unported credits/trophy screens moved to P4.6; P4.8 re-opened on Q-0045/Q-0046; P4.11's landed
Challenge records corrected; R54 confirmed covered by R51 with a windowed capture (EV-0233); the
suite totals restated as 26 script suites / 1,680 assertions plus the 139-assertion integration
suite = 27 checks / 1,819; R66 fixed (EV-0234: a manual drop now carries the Food Quality level;
covers buy→drop, the potion override and the fallback, +6 level assertions); R55 fixed (EV-0237:
the recovered 10-tick `+0x1CC` grow pop is drawn now, +3 fish assertions); R59/R67 fixed (EV-0238:
pets and aliens draw one row at a time instead of walking through every animation in the sheet;
+6 pet, +3 alien, +4 render assertions). Only the temporary
capture aid `tools/godot/shot_facing.gd` was added.
The Review table moved to [`REVIEW.md`](REVIEW.md) (R1-R66) so this file stays a phase checklist.)

Last updated: 2026-11-22 (documentation pass - R48, D-0058, EV-0229: the evidence ledger's
heading level, both READMEs' suite counts, the audit's and the export checklist's mermaid-tail state
were brought back in line with the code. **All 26 suites pass, 1664 assertions**; integration 136;
the 400-frame boot exits 0. The Review list now runs to R48.)

Last updated: 2026-11-16 (OWNER REVIEW 2: the in-tank Options' debug grid moved to its own
`DebugDialog`, the options layout rebuilt on one checkbox per row, the shop bar's fish shelf is no
longer milestone-gated (1-1 opens with the guppy at 100), and the egg cell is clipped to its dome -
R11, D-0017; R12 then fixed the dialogs' proportions and added NEXT LEVEL, D-0018; R13 opened the tank bar to the level's whole stock, D-0019, R14 put the level number in the tank's bottom-right corner, D-0020, R15 animated the guppy dome, D-0022, and R16 matched the bar to a recording of the shipped game, D-0023, and R17 fixed the pellet's tumble and its eat point, D-0024, R18 cached the bar's domes, D-0025, and R19 reviewed that bar work, D-0026, and R20 took the badge geometry and the price colour from the recording's own measurements, D-0027 - **all 24 suites pass, 1492 assertions**.

**Owner vocabulary (D-0021):** when the owner writes "the shop", "the tank shop" or "the shop bar",
they mean the **in-tank store bar** (`scripts/ui/store_bar.gd` plus `EggWidget`) - the row of domes
above the aquarium. The Fish Emporium window (`scripts/ui/store_screen.gd`, opened with S, and the
one Virtual Tank sells from) is never what they mean unless they name it. The 2026-11-15 review reset below still
stands for R8 (owner's live playtest) and R9 (the four pet guards).)

Last updated: 2026-11-15 (REVIEW RESET: the completion pass was revoked by the owner after
playing the build - the game is far from the original despite 24/24 suites green. The suites
prove modules, not the assembled game. P4 14/14 `[x]` and P5 5/5 `[x]` are reverted to `[~]`
below; see [`REVIEW.md`](REVIEW.md) for the confirmed defects, each with its
reproduction. Do not re-mark anything `[x]` until the windowed playtest passes. Re-verified
2026-11-15: all 24 suites pass - 23 script suites + the scene-backed integration suite,
**1431 assertions** - and the 400-frame boot exits 0 with no script error; the remaining Ogg
vendor-comment and ObjectDB/resource-at-exit notices are the known AUDIT F2 noise.)

2026-11-10 addendum: the render path is covered now. `tests/headless_render_check.gd` (17
assertions) pins `Level._sync_fx`'s dot pool to the effect lists in both directions; the old trimmer
was `while get_child_count() > wanted: get_child(...).queue_free()`, and `queue_free()` does not
shrink a parent inside the frame, so the loop never returned - a rendered level froze permanently the
moment an effect expired (a click's laser spark lives 5 ticks), which is what the 2026-11-09 and
2026-11-10 debug sessions hung on. Totals with it: **24 suites, 1341 assertions**.

2026-11-10 play addendum: coins now draw from their box corner like fish, so a click on the visible
coin hits its recovered 60-px pickup square instead of dropping a pellet (EV-0187).

2026-11-10 UI addendum: the tank's egg moved from a bottom-right widget into the seventh `MENUBAR`
dome (R3, EV-0172), and the Hatch card now draws the recovered `HATCHSCREEN` incubator, the
`HATCHANIMATION` crack strip and the awarded pet's first cell (EV-0175). Both masked sheets are
composited through `MaskAlpha` because their backgrounds are opaque fields, not the black key
`SpriteKey` clears. The remaining between-level screens (Pets, Bonus) are text-only.

2026-11-11 MENU/debug addendum: the tank MENU button is wired. The original's TankScreen id
99 runs `FUN_0054AED0()` + `FUN_00552100()` (close tank, main menu) and does not save; the port's
`StoreBar.press_menu()` -> `Level.request_menu()` -> `Main._on_menu_requested()` saves as a safety
net, shuts the tank down, frees the level and remounts the selector in the same frame (EV-0189,
D-0014). The "Leave Game?" confirm is the Options "Back to Main Menu" path, not the tank MENU.
The port-only debug panel is also in: `F1` toggles it, `F2` money, `F3` grow, `F4` feed, `F6`
egg, `F7` max weapon, `F8` reveal store, `F10` spawn guppy (D-0014); the original's only recovered
cheat path remains `FUN_005404A0`'s mode toggles, so none of these actions is claimed as shipped
behavior. `headless_store_ui_check` 54, `headless_level_check` 149,
`headless_integration_check` 67 - totals **24 suites, 1378 assertions** (all exit 0; the rendered
MENU return and F1/F2/F3/F10 path is captured in EV-0190). *Superseded by the 2026-11-14 addendum
below: the tank MENU now opens the in-tank Options dialog before any save/teardown.*

2026-11-14 MENU/settings addendum: the tank MENU now opens the in-tank `OptionsDialog` over the
paused tank instead of going straight to the main menu (owner request; D-0015, EV-0191). OK or
Escape closes the dialog and resumes the same level; "Back to Menu" runs the old leave-tank path
(save via the D-0014 safety net, shut the tank down, free the level, mount `GameSelector`).
Opening Options alone writes no save, and `Level._unhandled_input()` ignores tank clicks/hotkeys
while a modal owns `Screens.dialog()`. The Show Money checkbox is live (`Game.show_money` +
`show_money_changed`), so the wallet plate follows it. `headless_integration_check` 67 -> 81;
all 24 suites pass, **1392 assertions**; the windowed probe is captured in EV-0191
(`captures/shot_menu_options.png`). *Superseded by the 2026-11-15 addendum below: the dialog now uses the
shipped art/layout and the tank pause is wired through `Tank.pause_source`.*

2026-11-15 Options-dialog addendum: the in-tank Options now uses the shipped dialog's art and
layout (D-0016, EV-0192). `Dialogue-panel`, `DialogButton2`, `Checkbutton`/`unCheckbutton` and
the slider track/thumb are composed through their `masks/_<file>` companions (P3.3), so the
rounded panel and widget cut-outs are transparent instead of black. Two small controls replace
the engine widgets that could not match the native metrics: `OptionSlider` (156x17 track, 33x32
thumb) and `OptionCheck` (46x45 icon, label 39 px after the icon). The dialog carries Music/Sound
FX, Fullscreen (a real `DisplayServer.window_set_mode`), Custom Cursors and Hardware Acceleration
(stored port stubs), Help/OK and, in-level, Back to Main Menu; the port-only debug block (D-0014)
is labelled and adds Show Money. Opening Options now genuinely pauses the tank: `Level.setup()`
wires `Tank.pause_source = Game`, `Level._on_sim_tick()` early-returns while paused, and held fire
stops re-aiming, so the level clock, hunger, wave clock and particles all freeze. Help replaces
the dialog with the dimmed tutorial HelpScreen and keeps the tank paused; Escape closes it. The
main-menu Options hides Back to Main Menu and the debug block. `headless_integration_check`
81 -> 116, `headless_level_check` 149 -> 153; all 24 suites pass, **1431 assertions**; the
windowed probe (`captures/shot_menu_options.png`, EV-0192) pins the frozen clock and drives
money/guppy/grow through the dialog.

Next: **R52/R53 (swim speed and target), R56's windowed re-check, R58 (the egg reveal), R61 (the alien
click box, Q-0046) and R64 (the dome row geometry) - R57, R60 and R65 landed 2026-11-24
(EV-0246..EV-0250, D-0061/D-0062, Q-0065) - then R8/R9.** R1 (200 starting money), R2 (HUD/money placement), R3 (the egg in
the seventh `MENUBAR` dome, EV-0172) and R4 (the tank's
`MENUBAR` shop row, EV-0171) are fixed; R7 is closed on evidence
(EV-0159/EV-0160/EV-0161/EV-0166/EV-0169: the bottom branch, the landing
flag with no writer, Angie's re-lay, and the completed sweep - all seven `DropFood` sites read, every
one 0 except Angie, and the loader's type-`0x1C` branch read too: bare Food ctor, no flag), R6 is
closed by the recovered coin draw (EV-0162/EV-0163): the image +
sheet row now come from `FUN_004DD7A0` per kind, so coins no longer all draw `MONEY` row 0, and R5 is
closed by the recovered fish draw (EV-0164): the body sheet is `FUN_004D5AA0`'s swim/eat/hungry pick,
the guppy's row is its stage (3 -> 2, 4 -> 3) and the carnivore's is row 4, so the eye-layer rule is
answered (three/four tinted `SIM` layers) even though that colourised path stays unimplemented.
R9 is narrowed to four named guards (EV-0177..EV-0180): Wadsworth, Gumbo, Blip and Presto now act in the
tank, and only Seymour's aura writer, Amp's click, Nostradamus' sneeze and Walter's glove launch remain
disabled rather than guessed. Remaining: the owner's live playtest of tanks 2-4 and 5-1 (R8's windowed
frames are captured - see `REVIEW.md`), the assembled feel, and the 2026-11-15 owner playtest
of the in-tank MENU settings flow (the base-art Options over a genuinely paused tank; OK/Escape
resume; Help; "Back to Menu" returns to the selector) before it is called done. The windowed probe
for that flow and for F1/F2/F3/F10 is captured in EV-0192 (EV-0191 is the earlier flow-only pass). Audio is muted by default for now at the owner's request
(Q-0056). The P4 lines below keep their evidence; only the premature `[x]` is withdrawn.

## Phase 2 history (retained)

The tank save/load serializer (EV-0044); Food entity/physics/drop flow (EV-0045); money/`SpendMoney`+loan,
store enum, BuyItem hub, spawn map (EV-0046); coin values/AddMoney/collection/spawn (EV-0047);
click-feed, hunger counter, eating/growth pipeline, coin scheduler (EV-0048); species map, ctor
tuning, Oscar/Ultravore inits, DeadFish + successor spawns (EV-0049/0050/0051); corpse spawner +
DeadFish identity (type 0x1B) + full Update replay with LIVE successors (EV-0052/0053); death
entry points + types 0xA-0xC = `Sexy::Breeder` (EV-0054); coin-hit dispatch mapped per list
(EV-0055); per-species closure (EV-0056); credit = uncollected coins, price arrays A/B/C/D,
egg/level handler + `SetStorePrice` xrefs (EV-0057); money label `"%d"` (EV-0058); fourth pass:
store item 6 spawn = Penta = Starcatcher (EV-0059); wiki cross-reference pass + D-0010
(EV-0060); P2.6 first pass (EV-0061-0065). P2.6 second pass (2026-10-20): advance writer/profile
reset/accessors (EV-0066), egg branches/pet table/tank4 L5 (EV-0067), level-6 sentinel/finalizer/
transition/events (EV-0068), bonus payout/HUD/save (EV-0069), alien types/waves (EV-0070),
victory gate/Interlude/StoreScreen + trophy correction (EV-0071), corrected store tables/Shells
routing (EV-0072), session init + normal vs Bonus Adventure lifecycle (EV-0073), wiki second
pass (EV-0074), explicit unknowns (EV-0075), pet-index/bonus-duration corrections (EV-0076).
Notes `p2.2-tank-sim.md` (§9), `p2.3-feeding.md` (final), `p2.4-growth-death.md` (complete),
`p2.5-economy.md`, `p2.6-progression.md` (second pass), `p2.7-pets.md` (complete),
`wiki-refs.md`.)
P2.7 third pass (2026-10-21): 24-pet roster + 999 display card (EV-0077), entity model/
vtables/field map (EV-0078), spawn/session/ctor tuning (EV-0079), shared AI gates + 36 Hz
tick (EV-0080), per-pet behavior entries (EV-0081-EV-0104), wiki pass/discrepancies
(EV-0105), explicit unknowns (EV-0106), corrections to earlier notes (EV-0107).
P2.13 save sample (2026-10-21): live folder `C:\ProgramData\Steam\Insaniquarium\userdata`;
`users.dat`/`user1.dat`/`adv1.dat` copied with hashes and layout notes (EV-0108). A second
GameBanana sample (`users.dat`/`user1.dat`/`sim1.dat`) is in
`docs\analysis\inputs\p2.13-saves-gamebanana-100\`; the 232-byte `user%d.dat` field order is
now mapped through `FUN_00503730` (EV-0109, `docs\analysis\notes\p2.13-saves.md`).
P2.13 body decode (2026-11-01): the tank save is a header + one body function, fully ordered and
byte-verified on both samples; `adv1` = 1081 B (E=362, S=49, tank/level 1/1, money 190, cap 2,
tick 440), `sim1` = 11800 B (E=10946, S=32, 1/5, money 200, cap 8, tick 241676, wave 61).
EV-0144; note §6 has the field table, load repairs and the P4 spec.
P2.8 aliens (2026-10-29): Q-0011 answered - every hostile alien except Bilaterus is one
`Sexy::Alien` class whose kind (`Alien+0x1EC`) selects stats/sprite/attack code; kind table
1/2 Sylvester, 3 Balrog, 4 Gus, 5 Destructor, 6 Ulysses, 7 Psychosquid, 8 Bilaterus, 9-0xC
composites, 0x14 Minisylvester, 0x15 Cyrax (EV-0110); ctor tuning/hp/speed/field map and the
Cyrax hp-scaling counter (EV-0111); Bilaterus two heads x 100 hp + 6 bones + head swap (EV-0112);
`Alien::Update` gates, movement bands, Destructor/Ulysses/Psychosquid/Cyrax attacks, eat target
split and death/drop path (EV-0113); wave clock 3000 ticks with the "one wave at a time" pause,
276/275/33/30/1/0 milestones, per-tank type re-roll, wiki comparison, unknowns + bounded
negatives (EV-0114); late returns folded in: alien eating is a chase (approach steering, not a
bite) and the death drop is a kind-independent Diamond worth 200 rather than the previously
assumed call (EV-0115); the bite (`FUN_004E8F70`: per-type reach boxes, consume/get-eaten
virtuals, Gus pellet cost) and the attack-gate body (`FUN_005392A0`) closed (EV-0116). Note
`docs\analysis\notes\p2.8-aliens.md`.
P2.9 bosses (2026-10-29): only kind 0x15 (Cyrax) is a boss - tanks 1-4 level 5 are ordinary re-rolling
wave sets, so "boss per tank" is corrected at the binary (EV-0117); the kind-0x15 AI is two clocks -
a 1-hp Minisylvester at the boss every 75 ticks (`FUN_00545580` -> kind 0x14) plus a random alien
**type** 4-9 every 300 ticks while `Tank+0xB8`/`+0xF4` are empty (`FUN_005475B0`), correcting EV-0114's
inverted wording; no projectile, no fireballs, no hp-threshold phase, single sprite (EV-0117); HP bar
geometry recovered from the assembly of `FUN_004DAE20` (tube/fill images, x 10, y box_h-3, width
`clamp(tube_w*hp/hp0)`), the boss-only defeat cleanup `FUN_004F9950` (`+0x110=0`, `+0x4F4=1`, wipe
aliens+projectiles) and `FUN_00564160` = CRT `ftol` (EV-0118); egg-piece gates = store object +
`SpendMoney` with **no** boss check, and the exact `profile+0x54` increment condition (EV-0119); the
shot hit handler `FUN_004FA6F0` gives the damage model - inside-box test only, 10-tick cooldown,
`hp -= 3*Tank+0x3E4` (30 at the boss-forced 10), knockback, Psychosquid heal + sub-100 forced sleep,
death call (EV-0120); the same formula at the base weapon level 2 gives the 6 damage per hit that the
wiki's hit counts imply (EV-0121). Note `docs\analysis\notes\p2.9-bosses.md`. New open items: Q-0021 (egg purchase
not boss-gated at handler level) and Q-0022 (`profile+0x54` naming, `from_shot` at the shot kill).
P2.10 weapons & projectiles (2026-10-29): a click *is* the shot - `FUN_00543920` resolves one click
through bonus round -> `Tank+0xBC` (boss-only) -> boss `Tank+0x110` -> `Tank+0xB8` aliens ->
`Tank+0xDC` `Larva::HitTest` -> `Tank+0xF4` `Missle::HitTest` -> feed, with no player weapon object,
no weapon cooldown and no player projectile (EV-0122); the upgrade cap is **12**, not 0xB (corrects
EV-0057), and the 11 -> 12 purchase shows "Hold down mouse button for Rapid Fire!" (EV-0123); the
projectile class pair `Sexy::Missle`/`Sexy::Larva` is mapped - spawner `FUN_00544130`, ctor field
table with kinds 0/1/2 (80x80 or 50x50 box, speed divisor 0.8 or 0.4, 15-tick spawn immunity,
10-tick expiry, victim lock `target+0x98`) (EV-0124); update bounds/gravity/smoke trail, the
shoot-down and deflect hit tests and the `Larva` fall/shell-payout path (EV-0125). Note
`docs\analysis\notes\p2.10-weapons.md`. New open item: Q-0023 (laser draw/frame binding,
`Tank+0xBC` identity, `Larva` role, `FUN_004FF4E0` homing, Rapid Fire implementation).
P2.11 game modes (2026-10-29): the mode is `[manager+0x87C]` = 0 Adventure, 1 Time Trial, 3 Sandbox,
4 Challenge, 5 Virtual Tank (2 unobserved) and it has **no writer anywhere in the decompiled corpus**,
so the selector belongs to P2.12 (EV-0126); `start_level` `FUN_0054CBF0` fixes the per-mode entry
order and mode 5 resumes or creates a Virtual Tank through `FUN_0054CB20` keyed on `profile+0x44`
(EV-0126); Time Trial runs a 300 s (tank 1) / 600 s clock (`Tank+0x3BC`) that ends the level through
collect-all + `FUN_0054EB80`, Challenge inflates store prices by `Tank+0x374[i]` every 150/150/175/200
ticks (tanks 1-4, cap 99999) and swaps a rolled type 8 for 0xC after wave 4, and Sandbox re-rolls
prices through `SetStorePrice` (EV-0127); Virtual Tank's init block and its 76 % ordinary / 24 %
weighted prize-fish spawner are mapped (EV-0128); the Rapid Fire loop Q-0023 left open lives in the
tank update, not the click handler (EV-0129); and `FUN_004D80C0` is an object-kind test
`dword[+0x19C] in {3,4,5}`, **not** the demo flag, so the random-velocity missile branch is
unreachable and every earlier "demo" reading of that predicate is withdrawn (EV-0130). Note
`docs\analysis\notes\p2.11-modes.md`. New open item: Q-0024 (mode writer, `+0x19C` receiver,
`Tank+0x4FE` writer, `+0x2DC`/`+0x2E0`, VT helpers).
Phase 2 closure: [`SPECS.md`](SPECS.md) (P2.18, D-0008) is the behaviour contract, and P2.16
(screensaver) / P2.17 (cheats) remain optional. P2.18, P2.15 and P2.14 are complete
(EV-0150..EV-0154, EV-0157, EV-0145..EV-0149); P2.13 is complete (EV-0144), with Q-0029 bounding the
residual fields. Q-0018's tank-side xref is identified - `0x54782A` is the `FUN_005409B0()` call
inside `FUN_00547610`, gated on tank 5 / `Tank+0x110 == 0` / `+0x2A5 == 0` / `+0x3AF == 0`, so the
tank owns the item cache at `Tank+0x404` and builds lazily; the tutorial-loop xref (`0x4F18xx`)
and the `prize+0x1D0/+0x1D1` writers stay open in Q-0018. Q-0026 is settled (EV-0141: the six
store-roller flags are backdrops, 15000 each). Q-0027 keeps two non-blocking dialog loose ends
(OptionsDialog's `+0x18C` writer and `manager+0x838..0x83E`); its `UserDialog` digits-only `"0"`
box closed in EV-0140. Q-0025's `manager+0x738` writer stays open. P2.8 residuals stay in Q-0020
(kind 1 vs 2, the gate's four sub-predicates, vtable slots 77/75, the Gus pellet hp cost,
`FUN_005442C0` death animation, tank flag writers). P2.6 remains open on Q-0013/Q-0014/Q-0015/
Q-0016/Q-0017/Q-0018/Q-0028. P2.5 leftovers: the mode enum is answered (EV-0126); coin-hit intent
Q-0010 -> runtime; VT beetle value.


Status legend: `[ ]` pending - `[~]` in progress - `[x]` done (with evidence) - `[!]` blocked

## Progress summary

| Phase | Scope | Done | Total | Status |
| --- | --- | --- | --- | --- |
| P0 | Environment & tooling | 13 | 13 | `[x]` |
| P1 | Reconnaissance & target identity | 10 | 10 | `[x]` |
| P2 | Reverse engineer game systems | 16 | 18 | `[~]` |
| P3 | Asset extraction & pipeline | 8 | 8 | `[x]` |
| P4 | Godot implementation | 5 | 14 | `[~]` |
| P5 | Validation & polish | 0 | 5 | `[~]` |

The 2026-11-19 audit (D-0050) re-counted P4 against the tree: P4.9 has no outstanding item left in
its own line, so it is `[x]`. The 2026-11-22 pass re-opened P4.8 (Q-0045/Q-0046 are still open and
`ARCHITECTURE.md` §9 assigns both to it) and closed P4.11 (its last listed item, the Challenge score
records, landed in D-0053), so the count is unchanged at 5. The same pass closed P2.5 and P2.6
(2026-11-22): P2 is now 16/18, with only the optional P2.16/P2.17 left. The counts are the `[x]` task
lines below.

---

## P0 - Environment & tooling

- [x] **P0.1** Clone `morluto/rea`, study `reverse-engineer-anything` skill. (2026-10-15)
- [x] **P0.2** Verify Node.js >= 24.11. Node 24.16.0, npm 12.2.0. (2026-10-15)
- [x] **P0.3** Install 64-bit JDK 21. Temurin 21.0.12.1+1 via winget. (2026-10-15)
- [x] **P0.4** Install Ghidra 12.1.x. Ghidra 12.1.4, zip SHA-256 verified, extracted to `C:\tools`. (2026-10-15)
- [x] **P0.5** Install `rea-agents` CLI globally. v6.5.0. (2026-10-15)
- [x] **P0.6** Set `GHIDRA_INSTALL_DIR` / `JAVA_HOME` / `REA_ANALYSIS_PROVIDER` (User scope). (2026-10-15)
- [x] **P0.7** `rea doctor` shows Ghidra `available: true` (all 9 checks). (2026-10-15)
- [x] **P0.8** Create `tools\rea.ps1` wrapper (inline env for pre-change shells). (2026-10-15)
- [x] **P0.9** Create docs scaffold (README, PLAN, EVIDENCE, TARGET, DECISIONS). (2026-10-15;
  AGENTS.md was missing on disk until P0.12)
- [x] **P0.10** Registered REA MCP + skill into opencode (dry-run reviewed; config backup kept);
  effective after next client restart. (2026-10-15)
- [x] **P0.11** Locate local Godot editor + boot this project (Q-0001). Godot 4.7.1 stable at
  `C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe`; `--headless --import` exits 0. (2026-10-15)
- [x] **P0.12** Create `AGENTS.md` handoff protocol at project root (referenced by D-0003; absent until now). (2026-10-15)
- [x] **P0.13** `git init` + initial commit `68f1d75` (14 files) for diffable agent handoffs. (2026-10-15)

## P1 - Reconnaissance & target identity

- [x] **P1.1** Hash executables, screensaver, bass.dll; record sizes. -> EV-0001, TARGET.md (2026-10-15)
- [x] **P1.2** Read `crash.txt` + `readme.html` for version/product facts. -> EV-0002, EV-0003 (2026-10-15)
- [x] **P1.3** Full file inventory of the install root (recursive listing). -> EV-0004, EV-0005, EV-0006 (2026-10-15)
- [x] **P1.4** REA overview + import audit of `Insaniquarium.exe`: PE32 x86 admitted; 6 segments;
  7,061 procedures; 2,496 strings; static imports = 10 system DLLs (no bass/ddraw/dsound/steam_api).
  -> EV-0008, EV-0009, EV-0011 (2026-10-15)
- [x] **P1.5** Engine/build provenance identified: PopCap SexyAppFramework (MSVC RTTI class map),
  embedded Lua 5.0.2, build project `DRMProtectRun2`. -> EV-0009, EV-0013, EV-0016 (2026-10-15)
- [x] **P1.6** Steam/DRM boundary: legacy `Steam.dll` API (EV-0015), `drmss.jpg` (EV-0017),
  on-disk `drm\` Lua wrapper layer (EV-0020, EV-0023); in-exe caller mapping deferred to
  P2.13/P2.14 per user. (2026-10-15)
- [x] **P1.7** Subsystem seeds: rosters from `resources.xml` (EV-0022), asset inventory (EV-0018),
  data-driven confirmed via bounded negatives (EV-0019). -> EV-0012, EV-0018, EV-0019 (2026-10-15)
- [x] **P1.8** Phase 1 dossier written: `docs/analysis/notes/p1-recon.md` (entry points, naming
  conventions, address clusters, data map; EV cross-links). (2026-10-15)
- [x] **P1.9** Hash-verify secondary local copy vs canonical: exe + bass.dll byte-identical. -> EV-0007 (2026-10-15)
- [x] **P1.10** Full-tree hash comparison + fragment audit (leftovers identified; Q-0003 answered). -> EV-0010 (2026-10-15)

## P2 - Reverse engineer game systems (one investigation pass each; write notes per system)

For each: find entry points -> focused function dossiers -> record constants via byte reads ->
notes file + EV entries. Every system note MUST end with an "Implementation spec for P4" section
(constants+addresses, formulas, timings, state machines - see D-0008). Candidate systems (adjust
as evidence dictates; P1.7 + resources.xml will confirm the actual rosters):

- [x] **P2.1** Frame loop & timestep: `SexyAppBase::Process` (`0x49f1b4`) = fixed 10 ms tick
  (100 Hz), max 10 updates/message, catch-up Sleep, `timeGetTime` clock; ctor defaults
  (640x480, 0.85 multiplier); FPS overlay `0x49fdf1` (1000 ms window). -> EV-0034, EV-0035,
  EV-0036; notes `docs\analysis\notes\p2.1-frameloop.md` (2026-10-15)
- [x] **P2.2** Tank simulation: fish swim/turn motion, tank bounds, direction/facing logic.
  (2026-10-16: game module carved from exe + RTTI map (EV-0039..EV-0041); `Fish::Update`
  0x4F6970 + full vtable map (91 slots), slot 26 = draw entry, slot 83 = sprite draw (EV-0042/
  EV-0043); object factory/type ids/spawn recipe/save serializer (EV-0044); note
  `docs\analysis\notes\p2.2-tank-sim.md`.
  Open (tracked in note §7 + backlog): slots 70/71 semantics, `FUN_004d6ae0`/`FUN_004e1400`,
  0xAE/0xB5/0xB8 draw bases, module tick-rate re-check, periodic-effect spawn; slots 54/56/82/89
  were resolved later in P2.3.)
- [x] **P2.3** Feeding: food drop physics, hunger/satiety timers, eating states, coin spawn rules
  (2026-10-16: Food entity + ctor + `Food::Update` physics + `Tank::DropFood` + quality/quantity
  globals -> EV-0045; second pass -> EV-0048: click-feed virtual (slot 54, pellet price
  `Tank+0x4AC`), pellet cap formula (`quantity` non-special pellets), hunger counter `Fish+0x9C`
  with thresholds -1/-200/-400/-500 and hint strings, eating pipeline slots 82/84/85/86/77,
  nutrition/growth model (quality +500/+700/+1100, points `+0x1A4`/`+0x1A8`, stages 0..4, star
  potion rules), coin scheduler slot 81. Note `docs\analysis\notes\p2.3-feeding.md` (finalized).
  Open (tracked in note §9): module tick rate, runtime color table values, variant-2 pellet
  source, `FUN_0053C280`/`FUN_00538230` roles, species vtable->name mapping.)
- [x] **P2.4** Fish growth & death: guppy -> carnivore -> ultravore stages, starvation, drops
  (2026-10-16: spawn map + type ids (Guppy=0/Oscar=5/Ultra=6/Gekko=7/FishTypePet=0x15/
  SylvesterFish=0x22/BallFish=0x23/BiFish=0x24) + high-water counters -> EV-0044/0046;
  growth/stage/starve-death model -> EV-0048 (p2.3 note §7): stage points `+0x1A4`/`+0x1A8`,
  stage-4 overshoot, slot 88 die `0x4D5F90`, star potion rules; coin kinds -> P2.5 note §5.
  EV-0049/0050/0051 -> note `docs\analysis\notes\p2.4-growth-death.md`: species/vtable map,
  common ctor tuning `FUN_004DE370` (80x80, bounds, speeds 2.0/1.8/1.6, hunger 400-599,
  growth threshold 4-6 / mode5 12-20), Oscar (stage 5, hunger 600-799, consume +900 cap 1300,
  gore splats) and Ultravore (stage 6, 160px, hunger 600-799) inits, DeadFish `FUN_004F64E0`
  (death sound 0x125, successor spawn table 5/6/7/8/9/10-12, corpse drift), stage-carrying
  spawner `FUN_004EEF90`.
  Second pass (2026-10-16): corpse spawner `FUN_005441F0` + DeadFish type 0x1B + field map
  (EV-0052), `DeadFish::Update` full replay with successors = LIVE spawns and detach
  slot 0x144 = `FUN_004DB250` (EV-0053), death entry points slot 88 `FUN_004D5F90` +
  collectors `FUN_004F2890`/`FUN_004F3C60`/`FUN_004DD5D0` + starve gate `FUN_004D69D0`,
  types 0xA-0xC = `Sexy::Breeder` stages 0-2 (EV-0054).
  Third pass (2026-10-16): CLOSED -> EV-0056: per-species init helpers (Gekko `FUN_004D72B0`
  stage 7 / Sylvester `FUN_004D95C0` stage 1 / Ball `FUN_004DB2A0` / Bi `FUN_004DB820` +
  Penta `FUN_004D8D00` / Grubber `FUN_004D7970`), slot-77 eat bodies of all five remaining
  classes (+700 cap 1000; Ultra +900 cap 1300; Sylvester grows via `FUN_004D9D50(2)`;
  Ball inline stage++), tank-roster weighted spawner `FUN_0051B260` (+ virtual populate
  caller `FUN_0052F0D0`), store spawn mapping (guppycruncher -> Grubber, beetlemuncher ->
  Gekko), stage-size switch `FUN_004D9D50`, coin-pacing helper `FUN_004D71D0` (mode-5-only
  override) + slot-81 drop guard. Deferrals: FishTypePet (0x15) -> P2.7; corpse revive
  trigger (writer of phase `+0x190 <= 10`) -> Q-0009 (P2.6/P2.7); stage->coin-kind per
  species tracked in note §7.)
- [x] **P2.5** Economy: coin values/denominations, pickup logic, money display, store prices
  (2026-10-16: money = `Tank+0x3F0`, `Tank::SpendMoney` + loan, store enum/`BuyItem` hub/
  price table `Tank+0x314[12]`, spawn map, demo money global, ShowMoney option -> EV-0046,
  note `docs\analysis\notes\p2.5-economy.md`; EV-0047 coin values/AddMoney/collection/spawn;
  EV-0055 coin-hit per-list dispatch (`+0xD0` Penta list verified; `+0xC4` Grubber /
  `+0xC0` Breeder family by inference).
  Third pass (2026-10-16): -> EV-0057: "loan" corrected - `FUN_0053A0B0` = value of
  uncollected coins in the tank (lists `+0xA8`/`+0xEC`/`+0xC8`), so `SpendMoney` may spend
  coins still on the floor; collect-all `FUN_0053C2D0`; price arrays A `+0x2E4` = slot /
  B `+0x314` = price / C `+0x344` = base / D `+0x374` = increment, `SetStorePrice`
  `FUN_005380C0` has exactly 3 call sites (mode-3 store rebuild + egg price 0; random-pet
  doubling `2*B[11]`; mode-4 reset to C); egg/level handler `FUN_00545960` full flow
  (24 pet slots `Tank+0x144`, `+0x43C` egg pieces, profile unlock `+0x77+tank` for tanks
  1-4, stats slot `tank*5-6+level`); `Tank::SpawnCoin` `FUN_00544430` body.
  Money label format `DAT_005adec0` = `"%d"` (EV-0058).
  Fourth pass (2026-10-16): EV-0059 (store item 6 "buy starcatcher" spawns `Sexy::Penta`:
  alloc 0x1B0, ctor `FUN_004EC080`, y = 65); EV-0060 wiki cross-reference pass (display-name
  bindings incl. Grubber = Guppycruncher / Gekko = Beetlemuncher / Penta = Starcatcher, money
  denominations, mode names incl. Time Trial / Challenge / Virtual Tank, store prices,
  discrepancies) + D-0010 wiki policy; note `docs\analysis\notes\wiki-refs.md`. **Closed 2026-11-22:**
  none of the four items this line listed is undecoded work - the mode enum is answered (P2.11,
  EV-0126); the initial price arrays were a bounded negative handed to P2.6, and the tables the port
  stocks from came from EV-0072; the coin-hit trio's gameplay intent is Q-0010, a runtime
  observation explicitly deferred to P5 and not statically decidable; and the VT beetle value is a
  recorded wiki-vs-binary discrepancy. Q-0010 stays open in DECISIONS.)
- [x] **P2.6** Progression: 5 tanks x 5 levels, egg drops, hatching, pet unlock/trophy flow
  (2026-10-16, first pass -> EV-0061: level-start orchestrator `FUN_0054CBF0` + tank init
  `FUN_00541A20`; EV-0062: store initializer `FUN_00541200`; EV-0063: session init
  `FUN_005498B0`; EV-0064: completion/overlays/tutorial; EV-0065: screen flow + credits.
  2026-10-20, second pass -> EV-0066: `FUN_00501370` is the tank/level advance writer (Q-0012
  answered): level++, tank4+L6 -> tank5+L1, tank5 L>1 -> `+0x50++` + `+0x59=1`, >6 -> tank++,
  always `+0x58=1`; profile reset `FUN_00501530`; pet/Shells accessors `FUN_00501410/00501420/
  00501200`. EV-0067: egg-completion branches, pet index table 0-19 + 999, tank4 L5 = 999 card
  with **no grant**, tank5 L1 Presto + 5000 Shells, score helpers. EV-0076 correction: the pet
  index uses the completed level copies `Tank+0x3C8/+0x3CC` (Stinky 1-1 ... Presto 5-1), not
  post-advance fields; normal bonus duration is 15/20/25 s for tanks 1/2/3. EV-0068: level-6
  sentinel `FUN_0054B2A0`, finalizer `FUN_00537E20`, 160-frame wait + bonus starter, two-stage
  transition, tank-complete events `FUN_0054B2D0`. EV-0069: BonusScreen payout (mode 0/1/4,
  tank5 `max(1,+0x50-1)*5000` cap 25000), HUD `FUN_0053EAF0`, `scr%d.dat` persistence (Q-0019,
  settled by EV-0143: the bonus-shell escrow).
  EV-0070: normal per-level alien types, demo-only `FUN_00537C20`, composite waves 9-12, wave
  countdown. EV-0071: tank5/L2 victory gate -> InterludeScreen `FUN_0054BD80`/`FUN_005256E0`,
  pre-bonus StoreScreen `FUN_0054BCA0`/`FUN_0052B2D0`, trophy/bonus-card correction
  (`FUN_0051CF30`), credits open Q-0016. EV-0072: corrected store tables (tank2 L1 hides 6+10;
  tank4 item 9 = Ultravore s4 10000), Shells routing `FUN_0053C1E0`, tank create/session
  counters. EV-0073: session-init branch, tank5 pets 0..0x11, banners, normal vs Bonus
  Adventure lifecycle. EV-0074: wiki second pass; EV-0075: unknowns + bounded searches. Note
  `docs\analysis\notes\p2.6-progression.md` (second pass). **Closed 2026-11-22 (decoding):** the
  list this line carried was stale - Q-0011 is resolved (P2.8, EV-0110) and Q-0019 by EV-0143;
  Q-0018's price display and grey-out are answered (EV-0135) and its receiver question too
  (EV-0138), leaving only the tutorial-loop owner. The two unported screens - the story/trophy gate
  (Q-0013) and the credits trigger (Q-0016) - are **P4.6 work now**, not P2 (see that line). What
  stays open in DECISIONS is unobservable in the shipped binary: Q-0014 (mode 2 has no writer),
  Q-0015 (`+0x58` set but never read; `+0x50` meaning unproven), Q-0017 (tank 6 has no store case
  or event) and Q-0018's tutorial-loop owner.)
- [x] **P2.7** Pets: enumerate roster from binary, then per-pet behavior notes (batch: 3-5 pets
  per pass; each pet gets its own EV entries). (2026-10-21 complete: 24 pets + 999 card,
  EV-0077-EV-0107; note `docs\analysis\notes\p2.7-pets.md`. Per-pet timings/mechanics are in
  the note and the individual EV entries; Presto transform/picker and Walter glove/Angie
  revive evidence are in the `p2.7-walter-*`/`p2.7-angie-*`/`p2.7-presto-*` JSON files.
  Open items: Gumbo fish lure, Blip overlays, Seymour writer, Amp click/electrocute,
  Nostradamus sneeze/clones, Wadsworth challenge sleep, Brinkley 15/45/135 vs wiki 12/36/108,
  Stinky cooldown/red cosmetic, Niko perch, Walter click/5-punch counter, VT 3-minute sleep.)
- [x] **P2.8** Aliens: per-tank alien types, spawn waves, attack patterns, hitpoints.
  (2026-10-29: one `Sexy::Alien` class + kind table, Q-0011 answered (EV-0110); per-kind
  hp/speed/box + demo override (EV-0111); Bilaterus heads/bones (EV-0112); `Alien::Update`
  gates, 3-missile Destructor, 2-ball Ulysses, Psychosquid rest cycle, Cyrax summons, eat target
  split, death/drop path (EV-0113); wave clock 3000 ticks, pause contract, milestones, type
  re-roll, wiki comparison, bounded negatives (EV-0114); eating is a chase and the death drop is a
  kind-independent Diamond worth 200, correcting EV-0113 (EV-0115); the bite's per-type reach
  boxes + consume/get-eaten virtuals and the attack-gate body (EV-0116). Residuals -> Q-0020; note
  `docs\analysis\notes\p2.8-aliens.md`.)
- [x] **P2.9** Bosses: final-level boss per tank, phases, damage/weak points
  (2026-10-29 complete: only kind 0x15 = Cyrax is a boss; tanks 1-4 L5 are ordinary waves. Two-clock
  AI (75-tick Minisylvester spawn at the boss, 300-tick random type 4-9 wave while the field is
  clear) correcting EV-0114 (EV-0117); HP bar geometry + boss-only defeat cleanup + `ftol` helper
  (EV-0118); egg gates, `SpendMoney`, `profile+0x54` increment (EV-0119); shot hit handler
  `FUN_004FA6F0`: box test, 10-tick cooldown, `3*Tank+0x3E4` damage, knockback, Psychosquid heal,
  death (EV-0120), plus the 6-per-hit cross-check at the base weapon level (EV-0121). Note
  `docs\analysis\notes\p2.9-bosses.md`. Open: Q-0021, Q-0022.)
- [x] **P2.10** Weapons & projectiles: laser upgrades, missiles/perks, collision and damage math
  (2026-10-29 complete: one click = one shot through `FUN_00543920` with a fixed six-stage order
  (bonus -> `Tank+0xBC` boss-only -> boss -> `Tank+0xB8` aliens -> `Tank+0xDC` larva -> `Tank+0xF4`
  missiles -> feed), spark `FUN_00543640(x-0x28, y-0x28)`, tick stamps `Tank+0x4ED`/`+0x4EC`, and
  no player weapon object or cooldown (EV-0122); weapon cap 12 correcting EV-0057 plus the level-12
  "Rapid Fire" hint (EV-0123); `Sexy::Missle`/`Sexy::Larva` spawner and ctor field map, kinds
  0/1/2 with their box/speed/gravity values, victim lock `target+0x98` (EV-0124); update
  bounds/trail, the shoot-down and deflect hit tests and the `Larva` fall/shell payout (EV-0125).
  Note `docs\analysis\notes\p2.10-weapons.md`. Open: Q-0023.)
- [x] **P2.11** Game modes: Adventure, Challenge, Time Trial, Virtual Tank (screensaver ecosystem)
  (2026-10-29 complete: mode table + the no-writer bounded negative, `start_level` order and the VT
  load-or-create path (EV-0126); Time Trial clock/expiry, Challenge price inflation and type
  substitution, Sandbox price re-roll (EV-0127); Virtual Tank init block and weighted fish spawner
  (EV-0128); Rapid Fire loop, answering Q-0023 (EV-0129); `FUN_004D80C0` decoded as an object-kind
  predicate and the "demo" label withdrawn (EV-0130). Note `docs\analysis\notes\p2.11-modes.md`.
  Open: Q-0024.)
- [x] **P2.12** Menus & UI flow: title/profile/options/help/store screens, dialog structure
  (2026-10-29 first pass: screen inventory + the two-vtable `ButtonListener` convention and the
  vtable-xref recipe that finds any screen's constructor, `TitleScreen` and `GameSelector` ctors and
  the eight-button main menu (EV-0131); the **mode writer** `FUN_0051F160` - ids 1/2/8/9 -> modes
  0/5/1/4, the Time Trial and Challenge profile gates, the "Not Yet!" box and the demo-flag clear
  (EV-0132, resolves Q-0024); `StoreScreen` field map + item rects, the store action dispatcher with
  the mode-5 `BuyItem` bypass and the 0xF egg entry, and the dialog create/measure/push template
  (EV-0133); the level-start dispatcher `FUN_00552380` and the `manager+0x738` teardown (EV-0134).
  Second pass (EV-0135): the five `StoreButtonWidget` overrides are **slots 22/26/44/50/51**, not the
  first guess - 26 draws the item art by the kind at `+0x14C` (1 pet, 2 Bubbulator, 3 backdrop, 4
  alien attractor, 5 food), 44 draws the price line from `+0x12C` with the grey `0xCCCCCC` state on
  `+0x55 == 0` and the highlight on `+0x58/+0x59/+0x148`, 50/51 only write `store+0xBA8`; the
  `StoreScreen` slot map (attach/detach/refresh/update/draw/mousemove) and its tooltip (hover timer
  `+0xBAC`, hovered id `+0xBA8`, `FUN_0051B9E0` kind-to-text, "Thanks for shopping at the Fish
  Emporium!"); the **stock refresh** `FUN_0052FEA0` with the roller `FUN_0052F0D0` (one-off unlocks on
  `profile+0x90`/`+0x94`, pet slots on `profile+0x72+i`, the Cookie-once rule through `FUN_0051C0B0` /
  `FUN_0052B800`), and Q-0018's price/grey-out answered: `FUN_00536350` = `SetPrice`
  (`sprintf("%d")`), `FUN_005372F0` writes the literal **`SOLD`**. Note
  `docs\analysis\notes\p2.12-menus.md`.
  Screen pass (EV-0136): the vtable-xref recipe **does not generalise** (8 of 9 screen vtables answer
  empty), so the ctor map was rebuilt with an RTTI + vtable-immediate scan - all 13 screen ctors and 7
  inline overlay ctors located and written up (conventions table in note §10.1); per-screen field maps
  for Hatch, Help (8-page counter at `+0xA4`), HighScore (tab at `+0xA8`), Interlude, Pets (24-slot grid,
  `profile[0x5A+i]` writer), SimFish (20-row browser), SimSetup (three vtables, manager at `+0x90`,
  checkbox -> `Tank+0x4FC..+0x500`, backdrop cycle over `profile+0x72..+0x77`), Story (the
  `profile+0x7C` popcount gate, Q-0013) and Bonus (`manager+0x738` read, mode-4 story branch); all 10
  click dispatchers decoded; the transition-helper table (note §10.12).
  Dialog pass (EV-0137): ten dialogs hang off one shared base - `FUN_00530920` -> the `Sexy::Dialog`
  ctor `FUN_00475C40`, base vtable pair, `manager` at `+0x150`, `-1` at `+0x154` - whose `kind`
  argument (0 none / 1 Yes-No / 2 OK-Cancel / 3 one custom button, ids 1000/1001, captions from the
  `DIALOG_BUTTON_*` localization keys) is the only structural switch; all ten ctors and their one or
  two opener call sites are mapped (note §11.2), each dialog's extra widgets/ids are written up
  (§11.3), five click handlers cover all of them (§11.4), and the Edit/List/Slider/Checkbox listener
  bases are sized (§11.5). The base vtable pair is RTTI-named `Sexy::MoneyDialog` while no
  `.?AVDialog@Sexy@@` locator exists - recorded as a naming conflict and settled as D-0011.
  Price pass (EV-0138): Q-0018's last technical question is closed - `FUN_00519730` is a method on the
  prize the slot rolls (the machine code loads `ECX` from the object just built at all four call
  sites; the children are `Sexy::Fish` 0x597D54 / `Sexy::Oscar` 0x59843C), the prize kind is written
  per class at `+0x8C` (9/8/0xA/7/5/0x22/6/0x23/0x24), and the tank index from `FUN_00501060()`
  overrides the kind price flat for 0-8.
  Wiring pass (EV-0139): the dialog layer's last two wiring questions are closed - the per-character
  **edit filter is slot 2** of the edit listener (the base vtable's default is `mov al,1; ret 8`, and
  three dialogs narrow it: fish name `isprint(c)||c==' '`, new user `isalnum(c)||c==' '`, user dialog
  `isdigit(c)`), and `RegisterDialog` **relabels** the base's two auto buttons to Register/Cancel
  through their `+0x8C` label strings. Two listener addresses in §11.2 were wrong (RegisterDialog's
  ButtonListener is 0x5A644C; OptionsDialog's Slider/Checkbox were swapped) and are fixed; the four
  listener bases are 4/3/1/1 slots and none of their slots is a destructor.
  Residue pass (EV-0140): the last semantic gap closes - `FUN_00536A40` is `UserDialog`'s draw
  override and the digits-only `"0"` box is the **shells transfer amount** of the "TRANSFER SHELLS"
  mode (caption "Transfer Amount", shown only when `+0x174 != 0`, hidden in the "WHO ARE YOU?"
  picker), while Rename/Delete read the highlighted list row and open
  `NewUserDialog(isRename=1)` / a Yes/No confirm. One note-level detail stays unknown: the caption
  drawn left of the amount box comes from a runtime string pointer at 0x5E8B74.
  The phase **closes** here: the remaining loose ends are Q-0027 (Options' `+0x18C` writer and the
  `manager+0x838..0x83E` writers) plus the Q-0018/Q-0025 items already tracked for P2.13.
  Open: the call-site owner of the normal store-item object (Q-0018, deferred to P2.13), Q-0025
  (`manager+0x738` owner, `profile+0x18` - the `profile+0x5A` clear is explained by the PetsScreen
  ctor), Q-0027 (the two dialog writer gaps - Q-0026 is settled by EV-0141); all tracked, none blocking
  the port.)
- [x] **P2.13** Save/profile format: writer/reader functions, file location, versioning, Steam paths
  (2026-10-21: live folder found at `C:\ProgramData\Steam\Insaniquarium\userdata`; sample
  `users.dat`/`user1.dat`/`adv1.dat` copied to `docs\analysis\inputs\p2.13-saves-2026-10-21`
  with hashes/layout notes, EV-0108. Second GameBanana sample in
  `docs\analysis\inputs\p2.13-saves-gamebanana-100`, EV-0109. `adv%d.dat` is the Adventure tank
  save (version `0x36`); `scr%d.dat` is the separate bonus-shell escrow. `users.dat` and the full
  232-byte `user%d.dat` field order are mapped (`FUN_00513850`, `FUN_005145A0`/`FUN_00514730`,
  `FUN_00503730`); the tank-save body semantics remain open.
  2026-10-29 (EV-0141): the six-byte profile block `+0x72..+0x77` (save `0x52..0x57`) is **backdrop
  ownership** - the store roller builds its kind-3 stock from the clear entries and prices one backdrop
  at 15000 - so Q-0026 is settled inside P2.13 without needing the profile writer.
  2026-10-29 (EV-0142): the tank save is **one file per game mode** - `FUN_00505880(out, mode, slot)`
  formats `userdata\%s%d.dat` with `adv` (0/2), `tim` (1), `snd` (3), `sur` (4) or `sim` (5), and `slot`
  is `[profile+0x44]`; `FUN_005497A0` saves through `FUN_00546990` and `FUN_0054CB20` loads through
  `FUN_00546AA0`, while `FUN_005059D0` deletes the profile's `user`/`scr` files plus all six mode files
  (`FUN_0047FBC0` = `DeleteFileA`). `sim%d.dat` is therefore the Virtual Tank save, which explains the
  11800-byte sample.
  2026-10-29 (EV-0143): `scr%d.dat` closes Q-0019 - it is the bonus-shell escrow, 102 raw dwords
  `[token = profile+0x88][50 filler][payload][50 filler]` (408 bytes, no header, no cipher);
  `FUN_005148C0(consume)` returns dword 51 and deletes the file, `FUN_00515910(delta)` writes
  `old + delta`, `FUN_00546990` flushes `Tank+0x400` at save, and `FUN_00514B00` cashes it into the
  Shells (`profile+0x48`) and regenerates the token. `profile+0x88` is a **random** token, not a
  timestamp (correction of EV-0069).
  2026-11-01 (EV-0144): **complete.** `FUN_00546240` is both writer and reader (direction
  `[stream+4]`); the body order is header (version `0x36`, tank, level, `+0x2A5`, `+0x2A6`, count),
  entity stream (type `0x1F` skipped), optional `+0x110` object, overlay block, 24 per-pet flags,
  316 scalar bytes, 12 x 17-byte store rows, then SaveGame's `__time64`. Section starts are
  `42+E+S` / `454+E+S` / `658+E+S` (file ends `662+E+S` + slack); both samples parse with no
  remainder. Field meanings, load-time repairs (`+0x2E0 = 0`, widget rebuilds, Wadsworth/Meryl
  cleanup), the store `present` latch (widget-built, not "sold") and the `sim1` level 5
  (non-Adventure modes write level 5) are in EV-0144 and note §6. Residual unbound fields are
  bounded in Q-0029; they do not block the P4 model.)
- [x] **P2.14** Audio system: BASS usage, mo3 music playback, channel/mixing behavior
  (2026-11-01 complete: the module carries **two audio engines** - effects go
  `Sexy::SoundRes::ResourceManager` -> `Sexy::DSoundManager` -> `IDirectSoundBuffer` (256-slot pool
  of 28-byte records + a 256-double per-slot volume array, `DirectSoundCreate` on the default
  device), music goes `Sexy::BassMusicInterface` -> BASS via `Sexy::BASS_INSTANCE`, which
  `LoadLibrary(".\\bass.dll")` and resolves 48 entry points into fixed dword slots (fatal dialog
  when both volume entries are missing); the factory `FUN_00488300` picks null/FMOD/BASS off
  `app+0xF0`/`+0xF1` and the install ships `bass.dll` but no `fmod.dll`, so the FMOD path is dead
  (EV-0145/EV-0146). `SexyApp::Init` preloads `music\{Alien,Lullaby,Insaniq2}.mo3` as ids 1/3/4
  through music slot 1, which reads a `.mo3` whole into memory and calls `BASS_MusicLoad(mem=1,...)`
  (its extension probe is wav/ogg/mp3 only); slot 2 is the looping play/seek (EV-0147). The game
  layer has one music entry `SetMusic(a, b)` = `FUN_0054B1A0` with 21 call sites, and the per-stage
  selector `FUN_0054B2D0` maps stage 1-4 -> (0,22)/(0,0)/(2,32)/(2,45) and never runs in Virtual
  Tank (mode 5), i.e. VT has no music; an optional remap gated on `DAT_005e28cc` rewrites every
  pair to music 4 with a different order (EV-0148). Effects: `FUN_00419320` allocates a free slot
  (`"Out of free sound ids"` when full) and applies the record's default volume/pan; app vtable
  slot `0xD8` `FUN_004896B0(id)` is the only play entry and takes the id alone (EV-0149). All 65
  `SOUND_*` names are bound to their id globals (`docs/analysis/inputs/p2.14-sound-table.txt`), and
  the options block stores `MusicVolume`/`SfxVolume` as percent, loaded as doubles at
  `app+0xD0`/`+0xD8`. Note `docs/analysis/notes/p2.14-audio.md`. Open: Q-0030, Q-0031.)
- [x] **P2.15** Resource system: `properties\resources.xml` semantics (image/animation/sound tables)
  (2026-11-02 - EV-0150 the three-level parser and its fatal error paths, EV-0151 the `idprefix`/`path`
  model and the six-extension probe plus the **326/326** id partition across `Init` 14 /
  `Register` 16 / `LoadingThread` 296, EV-0152 the `<Image>` attribute set with `rows`/`cols` fields and
  the `anim` enum (56 loop, 8 pingpong, 2 once) with all-`2`/`4` frame delays, EV-0153 the two-file alpha
  model (`_` companion, sheet-sized `alphaimage`, cell-sized `alphagrid`, alpha = mask blue channel),
  EV-0154 the group contents, the deferred entry loader (`FUN_00419480`, non-fatal per-asset failures,
  `!ref:` fonts) and the three typed lookups with their deferred-placeholder rule. Note
  `docs/analysis/notes/p2.15-resources.md` ends with the P4 spec. Ghidra could not decompile the
  `LoadingThread` handler (`0x5073E0`, empty result twice); its 296 ids were recovered statically from
  the `push "<id>"` sites - recorded in EV-0154 note 3. Open: Q-0032 (`framemap` `-1`,
  `framedelay` unit), Q-0033 (grayscale tinting).)
- [ ] **P2.16** (optional) Screensaver variants (`Insaniquarium.scr`, `WinFish_Scr.exe`): feature deltas
- [ ] **P2.17** (optional) Cheat codes / debug hooks (string search; document only)
  (2026-10-16 partial: `FUN_005404A0` mode toggles - Wavy/Original Prego Sound/Original Breeder
  Sound/Ultra Prego Sound/Void/Space/Zombie (`DAT_005e89ce`) -> EV-0046; `Tank::SetTankIndex`
  `FUN_00538A10` 1..6.)
- [x] **P2.18** Write `docs\SPECS.md`: cross-system implementation contract for P4 (per-system
  specs come from the P2.1-P2.17 notes; format modeled on `docs\PIPELINE.md`). (D-0008)
  (2026-11-02 - `docs/SPECS.md` written: 14 sections covering the tick model, resource contract,
  entity/tank/creature rules, economy and progression, the mode matrix, the UI shell, persistence,
  audio, eight cross-system rules, a shared constant sheet seeded from every system's P4 spec, the
  open-question index, the P4.1-P4.14 mapping and the deliberate divergences. No new binary evidence
  (synthesis of EV-0022..EV-0154). One new question: **Q-0034**, the 100 Hz (P2.1 ctor constant) vs
  ~36 Hz (P2.7/P2.8/P2.9 timer calibration) tick-rate conflict - parameterised in SPECS §1.2, to be
  settled by measurement in P5.3. Phase 2 is closed except optional P2.16/P2.17.)

## P3 - Asset extraction & pipeline

- [x] **P3.1** Parse `resources.xml` into a machine-readable inventory (`tools\parse-resources.ps1`;
  326 resources: 246 images/15 fonts/65 sounds; counts corrected vs EV-0022). -> EV-0024, EV-0025 (2026-10-15)
- [x] **P3.2** Determine sprite frame geometry (all declared grids divide exactly; 80x80-cell
  convention; 30 undeclared multi-cell sheets; mask/alpha model). -> EV-0026, EV-0027 (2026-10-15)
- [x] **P3.3** Extract per-animation frame sets into `assets_raw/` (`tools\extract-assets.ps1`;
  244 base + 179 mask PNGs + 3,036 frames, pixel-exact; layers uncompressed). -> EV-0028 (2026-10-15)
- [x] **P3.4** Investigate `guppy_swim1.gif.frames.png` (Q-0003): both leftovers are pixel-exact
  GIF->PNG conversions, no slicing; ignored by pipeline. -> EV-0029 (2026-10-15)
- [x] **P3.5** Godot import step: `tools\godot\gen_spriteframes.gd` -> 129 SpriteFrames
  (AtlasTexture regions; 129/129 verified; exit 0). -> EV-0030 (2026-10-15)
- [x] **P3.6** Audio: 50 `.ogg` copied 1:1 + 15 `.au` -> `.wav` (`pcm_mulaw` 8k mono ->
  `pcm_s16le`), 0 probe failures, 752 KB; command per file in `audio.json`. -> EV-0031 (2026-10-15)
- [x] **P3.7** Music: 3 `.mo3` -> OGG via ffmpeg/libopenmpt (`libvorbis -q:a 5`), 3/3 verified,
  2.7 MB; tooling decision D-0006. -> EV-0032 (2026-10-15)
- [x] **P3.8** Fonts/UI/cursor: 15 SexyApp bitmap fonts parsed + converted (BMFont `.fnt` + composed
  page PNGs, 1,788 glyphs, 813 kerns; atlas/extents validated), Godot verify 15/15 exit 0; cursors
  already extracted as images in P3.3 (no conversion). -> EV-0033, D-0007 (2026-10-15)

## P4 - Godot implementation

> **2026-11-04 - simulation rate.** `Sim.TICK_MS` now runs the **~36 Hz** reading of Q-0034
> (`1000/36`) instead of the wrapper's 10 ms interval, so tick counts and wiki seconds agree
> everywhere (wave clock 83.3 s, boss arrival 8.3 s, weapon hold-to-fire 139 ms at level 12). The
> pellet tumbler reads at 3.6 rotations/s instead of 10. Q-0034 stays open for the unfound gate that
> would explain the 100 Hz wrapper; the rate is one constant (`docs/SPECS.md` §1.2).

Read `docs\PIPELINE.md` (asset contract) and `docs\SPECS.md` (behaviour contract) before starting;
both exist. Per-system detail lives in the fifteen `docs\analysis\notes\p2*.md` dossiers, each of
which ends with its own P4 spec; `SPECS.md` §12 maps every task below onto a section + note + asset
set.

- [x] **P4.1** Architecture doc: scenes, autoloads, signals, tick model mirroring P2.1
  (2026-11-02 - `docs/ARCHITECTURE.md` plus the scaffold it describes: `Sim` autoload = the fixed
  fixed-tick driver (the port now runs 36 Hz, Q-0034) with the original's 10-slice catch-up cap, 1000 ms backlog clamp and 0.85
  multiplier, plus the `CLOCK/FISH/PETS/ALIENS/PROJECTILES/COLLISION/FOOD/PARTICLES` phase registry
  that enforces SPECS §9.1's order; `Game` = mode enum + save stems + the shared pause gate;
  `Screens` = screen stack + single modal slot; `scenes/main.tscn` = Screens/Debug layers. Project
  settings now encode 640x480, `keep` stretch, nearest filtering. Q-0034 is honoured as one
  `TICK_MS`/`TICKS_PER_SECOND` constant pair with a comment stating both readings. Verified headlessly:
  `tests/headless_sim_check.gd` passes 20 assertions (sub-slice frames, exact slice, 10-tick cap,
  1000 ms clamp with pending time kept, `flush_backlog`, phase order, re-registration, unregister/
  clear, freed-registrant skip, tick->seconds) and `--quit-after 180` boots the scene with no script
  error. No binary evidence - implementation only.)
- [x] **P4.2** Resource loader mirroring resources.xml semantics (P2.15)
  (2026-11-02 - `tools/godot/gen_content.gd` emits the committed `resources/content.json` from the
  three P3 manifests, enforcing the group partition (Init 14 / Register 16 / LoadingThread 296 = 326)
  and failing on a missing asset or a different split; regeneration is byte-stable. `Content`
  (`scripts/autoload/content.gd`, autoload #1) resolves every id once into a typed handle - `IMAGE_*`
  -> `ImageRes` (`scripts/data/image_res.gd`: grid, SpriteFrames, `framemap` playback order, tick
  delays, `perframedelay`), `SOUND_*` -> `AudioStream` + manifest volume + `alias` keys
  (`SOUND_START` -> `SOUND_AWOOGA`), `FONT_*` -> `FontFile` + native size - and enforces the load
  order: `bootstrap()` completes INIT before the first frame, `ensure_phase(REGISTER)` pulls the
  dialog skin on demand, `start_phase(LOADING)` + `pump(budget_ms)` loads the 296 bulk resources a
  slice at a time behind the (P4.5) loading bar. Missing ids are reported and return null rather than
  throwing. `Main` now pumps the loading phase and the debug overlay shows `content N/326`. Verified
  headlessly: `tests/headless_content_check.gd` passes **51 assertions** (phase table, Init-before-
  anything, each phase exposing only its own ids, 14/16/296 partition, pump progress/budget, typed
  handles and animation metadata incl. MERYLBLINK's `framemap` + `-1` placeholder, aliases, missing-id
  behaviour) and `--quit-after 400` boots the real autoload path, logging Init 14 -> Register 16 ->
  LoadingThread 296 with no script error. No binary evidence - implementation only.)
- [x] **P4.3** Core entities: Fish, Pet, Alien, Coin, Projectile, Food (state machines from P2.2-P2.10)
  - Presentation is tick-driven now. `scripts/data/anim_state.gd` runs each sprite off the logic
    clock and the resource's own metadata (`anim`, `framedelay`, `perframedelay`, `begindelay`,
    `enddelay`, framemap-ordered positions) instead of one global 10 fps `AnimatedSprite2D` clock:
    a one-shot holds its last frame, a pingpong folds, and playback starts at the tick the entity
    spawned, so simultaneous spawns are the only ones in step. The port-only "animation speeds up
    with the fish" rule is gone - the swim column is `AnimState.SHEET_FRAME_TICKS` per frame.
    Sheets that declare no `anim` (the fish body, `FOOD`, `MONEY`, `SIMSWIM`) are entity-driven in
    the original too; their cadence and the coin sheet's kind->row mapping are Q-0057.
    **The bug behind "animation is not proper"**: `SpriteKey` cached keyed frames by
    `Texture2D.get_rid()`, and an `AtlasTexture` answers with its **atlas's** RID, so every cell of
    a sheet resolved to the first keyed image - the sprites were frozen on cell 0. The cache key
    now includes the atlas region. The menu mermaid's tail also plays its recovered one-shot flop
    (framemap `7,6,5,4,3,2,1,0`, 2 ticks a frame after a 3-tick hold) and returns to the rest pose.
    Verified: `tests/headless_anim_check.gd` (18), the level check (120) and the menu check (37).
  (2026-11-03 - **base + Food + Fish + Coin + Projectile + corpse landed, aliens landed, P4.3 is complete.** `SimEntity`
  (`scripts/entities/sim_entity.gd`) is the tick seam: the tank assigns its phase, `_sim_tick()`
  applies the pause gate and tick counter, `_advance()` is the only per-tick hook, `despawn()`
  unregisters before the free so an entity may despawn itself mid-tick. `Tank`
  (`scripts/tank/tank.gd`) owns them: `spawn(entity, phase)` parents to the phase's draw layer and
  registers with `Sim` (one entity, one phase, by construction), `layer_for()` orders
  FOOD < FISH < PETS < ALIENS < PROJECTILES < PARTICLES, `shutdown()` is the teardown (despawn all,
  unregister, drop the backlog), `rng` is one seeded stream per level, and `is_paused()` ORs
  `Tank.paused` (the original's `Tank+0x94`) with an injected `Game.gameplay_paused` so the checks need
  no autoload. `Food` (`scripts/entities/food.gd`) implements P2.3 §1's decoded update: fall 1.5/tick,
  drift `vy -2`/`vx ±2` decaying 0.05, x clamp 20..550, death at 410 (400 for a star potion, which
  splashes and removes), the variant-2 silent removal, `lifetime`/`inedible` counters, animation wrap at
  `cycle*10`, homing at (550,30) in sevenths, and the 120..150 bob bands. **Q-0035 half closed
  (EV-0159)**: step 8's `FUN_004D62D0` is `if (this+0x180 < 1) this+0x180 = 0xf`, so an ordinary
  pellet that crosses the line keeps sinking and is removed 15 ticks later; the port does that and no
  longer holds it on the line. The landed flag was then swept end to end (EV-0160) and the sweep is
  now complete (EV-0166): no writer exists outside the ctor and every non-Angie call site passes
  `flag = 0`, so dropped food never bobs (the bob is entered only for a spawned-landed pellet). Verified
  headlessly: `tests/headless_entity_check.gd` passes **43 assertions** (phase assignment,
  phase-ordered ticking, layers, despawn, both pause gates, teardown, seeded-RNG reproducibility, and
  every Food rule above). **Fish landed (P2.2/P2.3/P2.4):** `scripts/entities/fish.gd` is one `Fish`
  class plus a `SPECIES` table for Guppy, Oscar, Ultravore, Beetlemuncher, Minisylvester, Ball and
  Bilaterus. It implements the common ctor tuning (bounds, speed class, hunger 400-599/600-799,
  growth 4-6 / VT 12-20, coin threshold), hunger/hints/death, the swim machine (modes 0-4, `0x7B`
  drift, and the default modes >= 5 branch decoded as EV-0156), food seek/eat with the ±5/±10
  approach bands, nutrition and the shared growth tail, the star potion, breeding pellets and the
  slot-81 coin scheduler (`FUN_004D7100`, EV-0155). Lifecycle side effects are signals -
  `hunger_warning`, `died`, `breed_requested`, `grew`, `coin_due` - so the
  level/tank owns spawning; the coin system owns the stage -> kind mapping (Q-0036). `Tank` gained
  `spawn_fish()`, `nearest_food()`, `food_count()`, `randi_below()`, the coin mode helpers and the
  mode-5 fields. Death was corrected in P4.3: `Fish.die()` only reports `died`; the corpse owns the
  stage countdown (`+0x1A0` = 125) and removes itself at 0, so the earlier choice of respawning the
  same stage after the sink (reading the successor table as the death path) is gone - that spawn is
  the corpse's `phase_counter < 1` revive branch, which nothing recovered triggers (Q-0043).
  A crash-free death needed one tick-driver fix: `Sim._tick` walks a copy of each phase bucket,
  because a corpse or eaten fish despawning inside its own bucket shrank the array mid-loop.
  Fish carries no sprite/audio of its own (`sprite_row()` exposes the draw row; the P4.4 level draws guppies from SIMSWIM1..3, Q-0042);
  Penta/Grubber remain out of scope; pets, the DeadFish corpse, the Coin object, aliens and projectiles landed later. Verified headlessly:
  `tests/headless_fish_check.gd` passes **121 assertions** (ctor tuning, hunger/death, all swim
  branches, approach/eat/acceptance, nutrition/growth, star/breeding, coin scheduling, species
  defaults, RNG reproducibility); the three earlier checks stay green and a 400-frame boot exits 0.
  New open questions: Q-0037 (non-Guppy overshoot), Q-0038 (two approach paths/seek gate), Q-0039
  (target-timer operand). The later entity additions are tracked on P4.5 (coins), P4.7 (pets),
  P4.8/P4.9 (aliens/bosses) and P4.10 (projectiles); this core entity set is complete.)
- [~] **P4.4** Tank simulation + feeding loop (from P2.2/P2.3)
  - (2026-11-19, D-0054) A fish bought from the shop now drops in from the tank top: y = 30, `vy`
    `rand%5 + 18`, dart `rand%10 + 45`, x `rand%0x208 + 20` (`FUN_00546D70`, P2.2 §9.1).
  - Rendering: the tank backdrop is drawn at `z_index -100` from `AQUARIUM1..6` (the 640x480 tank
    art, chosen by `+0x3E8`); the `TANKBACKDROP1..6` set turned out to be 190x121 menu previews, so
    it is only a scaled fallback. Every sprite frame is colour-keyed by
    `scripts/tank/sprite_key.gd` before drawing - the extracted sheets keep the original black
    colour key opaque, so a guppy's sheet was painting 80x80 black boxes. The `SIMSWIM1..3`
    sheets are **eye layers only**; the bodies live in `SMALLSWIM` (10 frames per row, one row
    per growth stage), so a guppy now draws row `stage` of that sheet. Layering the eyes back on
    top was measured and rejected for now: no eye cell lands on the body's painted eye exactly
    (the closest is 2-5 px off), so overlaying one would draw a second offset eye (Q-0042). The
    other species keep their old images: measured row extents show only `smallswim`/`hungryswim`
    use row = growth stage, while `breeder`, `gekko`, `ultravore` and `balls` do not grow by row
    (Q-0042), so wiring them would be a guess. The one other sheet that *is* wired is
    `HUNGRYSWIM`: `Fish.uses_hungry_art()` implements `FUN_004D6F30` (`fullness < 301`, stage < 3,
    plus the hit-flash clause when the port has that field), and the sprite is rebuilt on the
    transition. `Tank+0x4FF`, the predicate's other half, is unbound and treated as clear.
  - The corpse draws `SMALLDIE`, the death twin of `SMALLSWIM` (same 10x5 stage rows, death
    cells 6..9): row = the dying stage (`+0x1A4`), cell = `DeadFish.sprite_frame()`, at the fish's
    own 80x80 box and facing. Rendering off in the suites, so this is checked by screenshot
    (`captures/shot_death.png` is not kept). Which cell the original's draw slot picks is still the note's
    frame rule, not a traced sheet index (Q-0043).
  - Animation: playback is `AnimState` from the resource metadata (a frame holds `frameDelay`
    ticks, 5 for the sheets that declare none) and each sprite starts at its spawn tick - the old
    one global 10 fps clock is gone (Q-0057); the pellet is the
    exception because `Food.anim_frame` is the simulation's own counter - the drawing now reads it
    (`Level._food_frame`, the pellet's own tick counter as the sheet frame (one frame per tick, wrapped at `anim_cycle * 10`, and taken modulo the sheet's ten columns so it stays inside its own row; the row itself is the
    food kind - quality 0..3 for the sheet's first four rows and variant 2 for the droplet row,
    an inference from the art that Q-0051 records as unrecovered)), so a pellet no longer
    free-runs through all 50 sheet frames including the rows that belong to other qualities. Fish
    animation speed is a **port presentation choice**, not a recovered rule: `Level._fish_speed_scale`
    plays the swim strip at `0.6 + |v| / speed_divisor` (clamped 0.6..2.0), so a darting fish does not
    paddle in place. No binary evidence covers the mapping, and it changes nothing in the simulation.

- [~] **P4.5** Economy & store UI (P2.5)
  - (2026-11-19, D-0054) The shop screen draws each stocked shelf's item icon through the shop bar's
    binding (`StoreBar.item_cell`), and `SpriteKey` keys a cell's own background colour, so the
    200-value diamond coin no longer draws its navy sheet box (EV-0225).
  - The shop screen is in (`scripts/ui/store_screen.gd`): the `STORESCREEN` art with EV-0133's
    eight shelf rects, the recovered price line (`+0x150`/`+0x154`, shell icon at
    `x + 0x19, y + 3`), greyed prices when the purse is short, "Sold out" for rows whose effect
    is not ported, the Shell plate count and the `+0xBA0` "Thanks for shopping" blurb. Rows come
    from the level's own `tank_store`; the shop opens with the port-only `S` key and Escape
    closes it (Q-0052).
  - The **in-tank store bar** is in (`scripts/ui/store_bar.gd`): the game's own `MENUBAR` art
    (640x75, EV-0171) with seven item slots at `FUN_005409B0`'s recovered rects (`x`
    0x12/0x57/0x90/0xD9/0x122/0x16B/0x1B4, `y` 3, 58x60, EV-0184), each selling the `tank_store`
    row whose `shelf` matches. Every button is the original's `MenuButtonWidget` pair (ctor
    `FUN_005373C0`): the item's shipped 40x40 icon in the dome (`SCL_*`, `FOOD`, `LASERUPGRADES`,
    `SMALLSWIM`, composed through `MaskAlpha`) and the price in the recovered green `0x6EFA6E` on
    `MENUBAR`'s measured purple plate (7, 45, 45, 12). An unstocked slot is an empty dome (the
    original builds no widget for it, so no `SOLD`), and the green plate shows the tank's money. A
    click buys the row (the egg row routes to `buy_egg`). Slot 7's x is not a constant in the
    decompile, so that slot stays blank (Q-0054); the star potion ships no matching icon (EV-0184).
    The bar is always on screen and opens with the level's whole stock: `FUN_005409B0` builds a
    widget for every row with `A >= 0` in one `while (+0x2E0 < +0x2DC)` sweep (EV-0144), so no shelf
    waits for a growth milestone (D-0019 withdrew the guide-reading reveal table). Blip's
    `FUN_005409B0(i, 1)` adds the level-gated (`A = -1`) rows instead.
    The bar refreshes when the purse, the stock or a reveal changes.
  - The store core is in: `scripts/economy/store.gd` holds the twelve recovered item ids with their wiki prices and the handler kind, and `Level.buy_item(index)` spends the row price, checks the upgrade caps (food quality 2, food quantity 9, weapon 0xC), then spawns the fish or raises the counter. Unimplemented items (breeder, Starcatcher, Guppycruncher, the egg/random-pet row) refuse without
    charging (Q-0049); the Beetlemuncher sells as a `Gekko` fish (D-0052). The star potion is implemented: buying it arms `Level.star_potion_armed` (`Tank+0x440`), the next manual drop becomes a quality-3 pellet and the flag clears; `Fish` already handles quality 3 (small fish die, a stage-2 guppy promotes). `tests/headless_level_check.gd` passes **254 assertions**. The weapon level is now the same field the boss forces to 10: `Level.weapon_level` reads and writes `Tank.pet_capacity` (`+0x3E4`), which is why `Tank.shot_damage()` and the upgrade agree, and `Level.hold_fire_period()` implements SPECS §3.5's level-12 hold-to-fire at `11 - level/2` ticks floored at 100 ms, and the level now runs it: the left button sets `holding_fire`, `Sim.ticked` counts `fire_cooldown` down, and `fire_at` re-tests missiles then aliens (there is no larvae entity yet, so that step is absent). Held fire follows the live cursor through `Level.aim` (mouse motion plus a per-frame update in the rendering path), so moving the mouse retargets the next shot. Mode-4 price inflation is in (`Store.inflate`, `Level.inflate_prices`): each row rises by its own `+0x374` increment per tick, clamped at `SetStorePrice`'s 99,999, and rows with a zero increment never move.

`Level.game_mode` now carries the selector's value (P2.12: 0 adventure, 1 time trial, 4 challenge, 5 virtual tank); `_on_sim_tick` inflates one tick per tick in mode 4 only, and `reset_prices()` puts every row back to its `base` at level start (the wiki's "prices reset"). The selector (`scripts/ui/game_selector.gd`, P4.14) sets the mode; the level still has no per-mode rules beyond mode-4 inflation. The store UI and the binary's own price arrays are still open.
- [~] **P4.6** Egg/level/tank progression + trophy room (P2.6)
  - The tables and the completion path are in. `scripts/progression/progression.gd` holds P2.6
    §3's per-tank store table with its slots, prices and level-1/2 hiding, the egg price per
    tank/level (plus Challenge's 5000/15000/25000 and Time Trial's 100), the tank-5 free egg, the
    §5 award formula (tank 5 -> Presto, tank 4 L5 -> the 999 card with no grant, otherwise
    `tank*5 - 6 + level`), the §10.4 advance (with the level-6 sentinel and the 4-5 -> 5-1 jump)
    and the pet-name table. `scripts/persistence/profile.gd` carries the profile fields this
    needs (tank/level, Shells with the 9,999,999 clamp, owned/selected pet bytes, Challenge
    unlocks, the Bonus Adventure flag) and `Game.profile` is the live one.
    `Level.start_level(tank, level)` stocks the shop from that table, sets `egg_pieces` (1, or 3
    on tank 5) and `egg_price`; `Level.buy_egg()` spends the price and completes the level on the
    4th piece; `complete_level()` grants the pet, pays the final boss's 5000 Shells, advances the
    profile and emits `level_completed`, which `Main` uses to start the next level. Tank 5's egg
    is a store row (free, slot 6) that routes to `buy_egg`.
  - The tank's egg widget is in (`scripts/ui/egg_widget.gd`): the recovered `EGGPIECES` cell for the
    piece count, drawn in the seventh `MENUBAR` dome on every tank (2026-11-10, R3/EV-0172); tank 5's
    free store row keeps the same dome and click. The dome placement is port-only because the
    original widget rect was not recovered (Q-0053).
  - Between-level screens: Hatch, Pets and Bonus mount and `Main` runs Hatch -> Pets -> Bonus -> next
    level. Hatch draws the recovered card art (EV-0175); Pets and Bonus stay text-only.
  - **The bonus round is in (2026-11-19, D-0051):** a normal Adventure tank 1-3 level-5 completion
    now runs it between the Pets card and the BonusScreen. `Main` keeps the finalized tank paused
    while Hatch/Pets are up, then `Level.begin_bonus_round` clears the combat field, disarms the wave
    clock, hides the shop and the egg dome, and starts `scripts/tank/bonus_round.gd`: the recovered
    `+0x444 - +0x2A8 > 0x9F` 160-tick wait, then `FUN_00537F40`'s timer (`base + clamp(level,1,6) - 1`
    = 15/20/25 s at level 6), and the end gate (timer passed, coin list `Tank+0xA8` empty, pre-increment
    `+0x3F8 > 100`). While the tank-complete latch is up every collected shell goes to `Tank+0x3F4`
    instead of the wallet (`FUN_0053C1E0`), and that total is what the card pays (`FUN_0051C8E0`,
    `BonusScreen.payout_for`). The HUD draws the recovered `FUN_0053EAF0` strings; tank 4's level 5
    and tank 5 keep their no-round paths, and Bonus Adventure's per-level rounds are not ported
    (Q-0053). `tests/headless_bonus_check.gd` pins 59 assertions on the round itself; "
    "`tests/headless_bonus_flow_check.gd` pins `Main`'s own hand-off (2026-11-22, EV-0231): 1/2/3-5 "
    "-> cards -> round at 540/720/900 ticks -> shells banked once -> card -> 2-1/3-1/4-1, and "
    "tank 4's no-round fast path to 5-1 (64 assertions). Only one round is recovered - one caption, "
    "one payout branch, no selector - so no second or third minigame exists to port (D-0051).
  - **The Hall of Fame records are in (2026-11-19, D-0053):** `Level.complete_level()` snapshots the
    run's seconds (`elapsed_seconds()`, the `+0x3FC` quantity, D-0047) and writes them per level
    (`FUN_00514510`; skipped when the advance lands on level 6, so 1-5..3-5 stay untimed) and per
    Challenge tank (`FUN_005144C0`, tanks 1-4 only), which the Hall's Time Trial, Challenge and
    Adventure tabs now read instead of "No entries yet". `tests/headless_level_check.gd` pins it
    (19 assertions, 222 -> 241). The slot's exact 12-byte layout stays open: `FUN_005142f0`'s body
    was never recovered (Q-0053).
  - Still not ported (Q-0053): the pre-bonus store, the `scr%d.dat` bonus-shell escrow, and the
    credits/trophy screens (**moved here from P2.6's open list on 2026-11-22** - Q-0013's story/trophy
    gate and Q-0016's credits trigger are port work with no recovered entry point, and are listed in
    `ARCHITECTURE.md` §9).
- [~] **P4.7** Pets implementation (per-pet tasks after P2.7 enumeration)
  (2026-11-03 - **foundation landed.** `scripts/entities/pet.gd` holds the roster as data (`DEFS`, 24 entries; 999 stays out) with family/speed/fixed-y/period cells that are 0 when unrecovered, the slot-81 gate order (pause -> tank 5 -> hostile aliens except Stanley), Stinky's bottom-lane chase with his 0..9 hide counter and per-pet coin predicate (bombs, snot, Niko's pearl, claimed coins, the star pair under a Penta), and Niko's 1224/1233/1440/1450 pearl cycle resetting to `rand % 50`. `Tank` gained `spawn_pet` and the tank-index/alien/Penta/source flags the gates read; `Coin` gained `claimed` (+0x198). `tests/headless_pet_check.gd` passes **45 assertions**. Angie (0x12) followed: her recovered target (`+0x1A0 > 0x5F`), the 30/60 px contact ranges and the `FUN_004D5630` phase write from 100 to 10, plus the corpse's ten-tick revive countdown and `Level._on_successor`'s live spawn - so a revived corpse now really returns as a live fish, and `tests/headless_pet_check.gd` passes **53 assertions**. Vert (0x06, 216 ticks, coin kind 2), Shrapnel (0x0B, the ctor-rolled 633..652, bomb coin 0x11 worth 150) and Nostradamus (0x15, 300..599, the 0x12 snot) then made the plain timer droppers real: **66 assertions**, and Angie's food re-lay (EV-0161) then took this suite to **73**. The other 18 pets idle (**Q-0044**). Pets now also **enter the tank**: `Level.spawn_owned_pets()` reads the profile's owned flags (`FUN_00501410`) at `start_level` and spawns each pet through `FUN_00544A90`'s randomized x 105..369 / y 20..539, and `_make_visual`/`_draw_entity_frame` draw every pet from its own 80x80 `Content` sheet (`IMAGE_STINKY`..`IMAGE_WALTER`) using the resource's `loop`/`pingpong`/`framedelay` metadata; `tests/headless_level_check.gd` passes **121 assertions**.)
- [~] **P4.8** Aliens + waves (P2.8)
  (2026-11-03 - **core landed.** `Alien` is one entity with a `kind -> DEFS` table (1/2 Sylvester 50/60,
  3 Balrog 130, 4 Gus 100, 5 Destructor 150, 6 Ulysses 220, 7 Psychosquid 260, 8 Bilaterus, 0x14 mini 1,
  0x15 Cyrax 5000), the full/mini/bottom bands, 0.1-step wander with the 20-tick/10 % re-roll and ±3
  intro drift, `missiles_3` (75 then rand%50+150), `balls_2`, the 400-tick Psychosquid rest, the chase
  plus ±45/±65 (`±30` mini, `±70/±85` vs 6) reach test, and the death path (kind-4 Diamond only for a
  shot death with no boss). `WaveClock` runs the 3000-tick gate, the fixed milestone order, one rolled
  spawn point reused by a composite selection, and asks the level to spawn rather than spawning.
  `Tank` gained `spawn_alien`, `spawn_wave_clock`, `alien_count`, `projectile_count` and `boss_alive`.
  `tests/headless_alien_check.gd` passes **65 assertions**. `Alien.IMAGE_BY_KIND` binds every kind to its recovered sheet (SYLV/BALROG/GUS/DESTRUCTOR/ULYSSES/PSYCHOSQUID/BILATERUS/MINISYLV/BOSS), and `box_size`/`initial_hp` feed the HP bar (160x160 box except the 80x80 mini; Bilaterus has no body hp, so no bar). `start_level` now arms the clock from
  P2.6 §8's per-level selection (tank 1 level 2 starts at 1750 ticks), spawns the requested alien,
  composes 9..0xC into their recovered member pairs (1+3, 7+3, 5+6, 3+8), and re-rolls the type after
  each wave per P2.8 §5.1; the level wires attacks to the tank's projectile spawner and death to the
  pet gate, and routes clicks in P2.10 §6.1 order (projectile, alien, coin, feed); `try_shoot` does
  `3 * weapon_level`. The 2026-11-19 audit (D-0050) marked this `[x]` because the projectile homing
  it listed had landed (EV-0158, Q-0041). **Re-opened 2026-11-22:** the audit read the wrong
  residual - this line's own gaps are Q-0046 (per-kind alien click box) and Q-0045 (wander target +
  bottom lane), both still open and both assigned to P4.8 in `ARCHITECTURE.md` §9, and the owner's
  2026-11-22 playtest reports clicks landing away from the drawn alien (R61).)
- [x] **P4.9** Bosses (P2.9)
  - Cyrax is in (`scripts/entities/boss.gd`): the hp formula and clamp, the 300-tick arrival that cannot be hit, the 15-tick intro, minions every 75 ticks at `+40,+40`, the 300-tick pulse only while no other alien is on the field, the 10-tick per-attacker damage cooldown, and death clearing `boss_alive` then unfreezing and permanently disabling the wave clock. `Tank.spawn_boss` freezes the clock and forces pet capacity 10 (so a shot does 30); `Level.start_boss` wires the minion and pulse signals, `Level.start_level` starts him from the schedule table (`Level.boss_kind_for`: tank 5 level 1 is Cyrax, nothing else has a boss), and shots now go through `Tank.shot_damage()` (`3 * pet_capacity`: 6 normally, 30 against the boss). Cyrax now draws `IMAGE_BOSS` through the same entity visual path and always draws the recovered HP bar (P2.9 §5, `IMAGE_HEALTHBAR` under `IMAGE_HEALTHBARTUBE`). The minion is a 1-hp Minisylvester (kind 0x14) and the pulse spawns a random type 4..9 at a random point through the wave spawner (EV-0117); death wipes surviving aliens and enemy projectiles (`FUN_004F9950`, EV-0118) and a >1000-damage kill with no minions left bumps `profile+0x54` (`Profile.cyrax_attempts`, EV-0119). `tests/headless_boss_check.gd` passes **46 assertions** (Q-0047 resolved). **2026-11-19 audit
  (D-0050):** nothing in this line is outstanding - Cyrax is P2.9's whole boss roster - so the task
  is `[x]`.
- [~] **P4.10** Weapons/projectiles (P2.10)
  - The projectile entities and the weapon damage/hold-fire path are in (see P4.3/P4.5): three
    projectile kinds, click hit-tests, `Tank.shot_damage()` and level-12 hold-to-fire. The kinds
    draw their recovered sheets (`IMAGE_MISSILE`, `IMAGE_ENERGYBALL`, `IMAGE_BALLS`), and the
    integration suite covers a real Destructor missile. **Homing is in (EV-0158):**
    `FUN_004FF4E0` steering (`+-0.2` toward `1.8`, Ultravore wide vs tight bands), target-loss
    expiry, the locked-victim kill and the deflected-ball 30-damage alien hit,
    the farthest-fish picker (`FUN_004E8DF0`, no shot when none is eligible) and the `+0x98`
    lock on `Fish`/`Alien` (`tests/headless_projectile_check.gd` **64 assertions**,
    `tests/headless_alien_check.gd` **65**). **2026-11-19 audit (D-0050):** the `Larva` is no longer
    missing - `scripts/entities/larva.gd` holds `FUN_004F2930`, `Tank.spawn_larva` builds one and
    `Level` tests it first in the click chain (`try_hit_larva`) and connects its payout/burst; what
    is absent is a spawner, since no system creates larvae yet. Still missing: that spawner, the
    laser draw/frame binding and the weapon HUD (Q-0023).
- [x] **P4.11** Modes: Adventure, Challenge, Time Trial, Virtual Tank (P2.11)
  - The mode value, selector dispatch, Challenge's price inflation, Virtual Tank's music silence
    and the per-mode save stems are in (P4.14/P4.5/P4.12), as are the Time Trial clock with its
    budget/elapsed/expiry (`Level.time_trial_*`, `TICKS_PER_SECOND`), the Challenge payout and unlock
    bytes (`BonusScreen.payout_for`, `Profile.challenge_unlocks`) and the Virtual Tank weighted
    spawner (`FUN_0051B260`). **2026-11-19 audit (D-0050):** the Time Trial end condition is in too -
    expiry collects every coin (`collect_all_coins`) and completes the level. **Corrected
    2026-11-22:** the Challenge score records it still listed as missing landed in D-0053
    (`Profile.record_challenge_time` = `FUN_005144C0`, written from `Level.complete_level` and read
    by `HallScreen`'s Challenge tab), so this line has no outstanding item and the task is `[x]`.
    The mode matrix's remaining questions (Q-0014's mode 2, Q-0024's VT session helpers) stay P2
    items, not P4 work.
- [~] **P4.12** Save system (P2.13) - own format unless compatibility is decided
  - The tank-save framing is in (`scripts/persistence/tank_save.gd`): version `0x36` with the loader's `<= 0x34` refusal, tank/level, the two latches, the entity stream with class `0x1F` skipped and `0x140`-byte object slots, the optional `0x208` `+0x110` object, the overlay (string, two colors, two dwords, byte, dword), 24 pet flags, the 316 scalar bytes, 12 x 17-byte store rows (slot `-1` = empty, signed) and the timestamp. The entity bodies, the `+0x110` object and the scalars travel as opaque blocks until their owners port them; the overlay's `+0xD4/+0xD8` remain Q-0029. `tests/headless_save_check.gd` passes **38 assertions**. The file layer is in too (`scripts/persistence/save_files.gd`): the per-mode `userdata\<stem><slot>.dat` path, write/read with the directory created on demand, and the mode-0 tank/level check; `tests/headless_save_files_check.gd` passes **21 assertions**. Entity persistence has started with the fish: `Fish.to_state()`/`Fish.from_state()` carry species, stage, position, facing, fullness and growth points, and deliberately drop coins, food, projectiles and particles, which a load rebuilds (P2.13 implementation note #11); the fish check covers the round trip. `scripts/persistence/tank_snapshot.gd` is the glue: it captures only the tank's live fish into the entity stream as a magic-tagged record (species, stage, position, facing, hunger, growth points), leaves the save's store rows and pet flags alone, and restores through `Tank.spawn_fish`; food, coins, projectiles and particles are never captured. The 316-byte scalar block is mapped too, in its note order: `scripts/persistence/tank_scalars.gd` writes money (`+0x3F0`), food quality/quantity, pet capacity, the backdrop, the wave selection and its countdown (`3000 - timer`), and restores the clock tick from it; unmapped fields keep their slots as zeroes. The star potion's armed flag (`+0x440`) and the backdrop tint (`5e89e8`, the block's last four bytes) are mapped too, so a reloaded tank keeps an armed potion and its tint. The pair is wired into the level as well: `Level.save_game(path)` captures the fish, the store table, the pet flags (from the PETS phase) and the scalars, and `Level.load_game(path)` applies the scalars, replaces the live fish and reloads the store table; F5/F9 trigger both, and a missing or refused file returns false. `tests/headless_tank_snapshot_check.gd` passes **54 assertions**.
- [~] **P4.13** Audio integration (P2.14 + P3.6/3.7)
  - The two mixers are in (`scripts/autoload/audio.gd`): effects on
    an `Sfx` bus through a fixed **256**-slot pool with the original's play contract - id only, no
    per-call volume, the resource's own volume per slot, identical sounds overlapping, and a
    dropped play plus `"Out of free sound ids"` when the pool is full (EV-0149) - and music on a
    separate `Music` bus with the three tracks the app preloads (`Alien` 1, `Lullaby` 3,
    `Insaniq2` 4, EV-0147), looping, driven by the recovered `SetMusic` pairs (EV-0148): stages
    1-4, level complete `(0, 13)`, the startup state `(2, 45)`. Virtual Tank is silenced where the
    original gates it (mode 5), and `Game.set_mode` stops the music at the switch. Volumes are the
    two 0..1 doubles on their buses; the Options sliders seed from them and write the bus. Triggers
    wired so far: stage music on level start, level-complete music, `SOUND_BUY` on a purchase,
    `SOUND_BUTTONCLICK` on menu/shop/bar presses and the existing `SOUND_DROPFOOD` on a drop - the
    rest of the per-event map is Q-0030. **Temporary port choice (2026-11-09, owner request):**
    both volumes start at **0.0**, so the mixes are muted until the Options sliders are raised -
    not a recovered default (Q-0056). `tests/headless_audio_check.gd` passes **40 assertions**.
    Remaining: the battle loop once its trigger is found.
- [~] **P4.14** Menus/UI shell, options, help (P2.12)
  - The `GameSelector` is in (`scripts/ui/game_selector.gd`): EV-0131's eight buttons, with
    `choose()` exposing the dispatch so both gates are testable and `press()` writing
    `Game.set_mode` then emitting `start_requested`. Time Trial needs `tanks_unlocked >= 2`,
    Challenge needs `adventure_done`, and both answer "Not Yet!" without writing a mode.
    Options, hall of fame and help were recognised but had no screen at that pass (Q-0050, since
    closed - see the screen bullets below). `Main` now mounts
    the selector once the content phases finish and starts the level on `start_requested`, so the
    chosen mode reaches `Level.game_mode` (Challenge therefore inflates prices from the menu).
  - The screen itself is now the original art: `SELECTORSCREEN` (640x480, mermaid + the
    telephone-box button panel) is drawn full-rect behind eight **flat** buttons placed at the
    rects `FUN_0052E070` passes to `FUN_00475090` / `FUN_00506820` (EV-0131), one-to-one in the
    640x480 canvas: 1 (0x165,0x30,0xD9,0x42), 8 (0x167,0x8E,0xD5,0x30), 9 (0x167,0xD4,0xD5,0x30),
    2 (0x165,0x11F,0xD9,0x42) and the text buttons 6 (0x191,0x17C,0x7F), 3 (0x145,0x19C,0x5C),
    7 (0x1A3,0x19C,0x5D), 4 (0x202,0x19C,0x59). The ctor records no height for those four ('-'),
    so they use a 22 px row inside the art's small purple slot. The labels are port text drawn
    over the empty slots: the original's button words are baked into per-button bitmaps
    (`DAT_005e8D80` and friends) that are not extracted yet.
  - The menu mermaid's tail is **baked into `SELECTORSCREEN`**; `MERYLTAIL` is the separate fin
    the original flops with. The port overlays it with its measured notch (107,84) on the baked
    stump (152,405) and plays the recovered one-shot flop (`anim: once`, `framemap` 7..0, 2-tick
    frames). The placement stays a port fit because no screen rect was recovered (Q-0055): after
    two turns that each left the painted end showing, the strip is drawn fluke-out at 145 deg and
    0.65 scale with a (-4,0) nudge, so its fluke covers the end (D-0055, D-0056, EV-0226/EV-0227).
    The art, mask and timing are recovered; P3.3's alpha model (`scripts/data/mask_alpha.gd`,
    `masks/tailflop_.png`) supplies the cut-out.
  - Every UI surface now draws with the game's own fonts (`scripts/ui/ui_font.gd`): the selector's
    art slots and small buttons use the two `Init` JungleFever outline fonts at 10/17 px, the store's
    Shell counter and prices use `CONTINUUMBOLD12` (`DAT_005e8CE4`), and the bar, egg widget and HUD
    use the recovered Tiny/TinyBold/Liddie set. Fonts are drawn at the manifest's native pixel size
    with no engine outline over the baked one; the global -> id mapping is EV-0157 and the selector's
    17/10 split is the unresolved part (Q-0059).
  - The tank MENU button is a real control now (EV-0189, EV-0191): a flat hit target over the baked
    `MENUBAR` label at `StoreBar.MENU_RECT` (525, 4, 80, 26; the height is the HatchScreen plate
    because the binary takes it from the button object). `press_menu()` -> `Level.request_menu()`
    -> `Main._on_menu_requested()` opens the in-tank `OptionsDialog` over the paused tank
    (D-0015, an owner-directed port divergence). The dialog is the shipped Options panel - masked
    `Dialogue-panel`/`DialogButton2`/`Checkbutton` art, Music/Sound FX sliders, Fullscreen/Custom
    Cursors/Hardware Acceleration, Help/OK, plus in-level Back to Main Menu (D-0016, EV-0192) -
    with a clearly labelled port-only debug block (D-0014). OK/Escape resume the same level; "Back
    to Menu" saves as a port safety net, shuts the tank down, frees the level and remounts the
    selector in the same frame (D-0014). The original's id-99 dispatch closes the tank screen and
    rebuilds the menu without a save; the Options "Leave Game?" confirm and the pause box are
    separate paths. The port-only debug panel (`F1`; `F2`-`F10` actions) is documented in D-0014.
  - The assembled path is now checked by `tests/headless_integration_check.tscn` (139 assertions):
    it mounts `Main`, presses Adventure through the real `GameSelector`, starts 2-4, advances the
    production wave and the Destructor's real missile, then starts 5-1 through the same menu path
    and asserts the scheduled Cyrax boss. It also drives the tank MENU through Options (base art
    and masked sheets, `Tank.pause_source`/frozen level+wave clock+hunger, no save on open, Show
    Money, the dialog's money/guppy/grow buttons, OK resume, Back to Menu save/release), checks the
    menu-mode Options (no Back row/debug block, Help request, stored checkboxes, mixer), and checks
    the centred alien/missile sprites and the HP bar (full 127-px fill, cut to 64 px at half hp)
    and the native font of every UI surface. It never calls `start_level`, `arm_wave` or
    `start_boss`; this closes audit G13.

## P5 - Validation & polish

- [~] **P5.1** Constant cross-check sheet: every recovered value (speeds, prices, HP, timers)
  listed against its EV entry (differential table) - docs/P5-VALIDATION.md (2026-11-08),
  withdrawn pending the windowed playtest (see Review).
- [~] **P5.2** Side-by-side playtest checklist per tank/level vs original (screenshots + notes)
  - docs/P5-VALIDATION.md §P5.2. The windowed eye-check for the species art (Q-0042)
  remains a human step; every asserted row is covered headlessly.
- [~] **P5.3** Timing/feel comparison (P2.1 tick model vs Godot implementation)
  - docs/P5-VALIDATION.md §P5.3. At 36 Hz the wave (83.3 s), arrival (8.3 s),
  Rapid Fire (139 ms) and pet timers agree with the wiki seconds; Q-0034 stays open
  for the unfound 100 Hz gate.
- [~] **P5.4** Performance sanity (target: trivial for a 2D game; check draw calls on tank scenes)
  - docs/P5-VALIDATION.md §P5.4. Dozens of one-sprite entities, no physics, no shaders,
  cached colour-keying; 26 suites + 400-frame boot + 1200-frame integration all exit 0.
- [~] **P5.5** Packaging decision + README for running the remake
  - docs/P5-VALIDATION.md §P5.5. Forward Plus kept, canvas_items/keep at 640x480,
  content.json export inclusion, ssets_raw regeneration, personal-use note.
  The tailflop backdoor is closed (F1): the sheet loads through the imported texture.

## Completion pass (2026-11-08; implementation only, no new binary evidence)

- **G4/G9** - shop-bought fish now enter through _wire() (died/coin_due/breed_requested);
  Level.coin_kind_for() tiers stage->kind through the recovered value table (port tuning,
  Q-0036 stays open for the binary binding). headless_mode_check **28 assertions**.
- **G7/P4.11** - _apply_mode_flags() writes irtual_tank, Sandbox money, the Time Trial
  budget and save paths at level start. Time Trial expires through collect-all + money*5/100
  shells with no pets; Challenge pays 2000/5000/10000/20000 + unlock bytes; Virtual Tank
  runs the 76/24 weighted spawner (26/25/25/10/5/3/3/3, 100-try retry) with no wave and
  coins to shells. headless_mode_check.
- **G8/P4.7** - Pet.create(index, pos, rng) uses the tank stream (old calls still work);
  Level.spawn_owned_pets() spawns the pending selection when non-empty (branch B) else the
  owned flags (branch A); all 24 pets steer (Stinky/Clyde lane chase, 1.5/3.0/4.0/0.5 ctor
  speeds, wander band) and the recovered slot-81 bodies are in: Prego birth, Zorf food,
  Meryl song marker, Amp charge, Gash/Itchy/Rufus/Walter melee, Stanley balls, Nimbus toss,
  Brinkley feeds at 3/15/45/135. 18 idle pets remain as parameterised guards (Q-0044).
- **G10/P4.12** - Level.current_save_path() resolves userdata/<stem><slot>.dat from mode
  (dv/	im/snd/sur/sim) and profile+0x44; Profile now carries save_slot +
  six backdrop flags and round-trips through user://profile.json (own format, SPECS §7.4).
  Golden fixtures parse the real saves byte-for-byte (E/S/slack, overlays) in
  headless_golden_check **22 assertions**.
- **G11/P4.13** - hunger/growth/pet/alien/wave cue signals are consumed (CUE_SOUNDS maps
  by semantic name, Q-0030 documented) and missile smoke/bursts spawn tick-counted particles
  (Level.spawn_particle, drawn by _sync_fx). headless_weapon_check **23 assertions**.
- **P4.10** - Larva (FUN_004F2930: fall y<64, payout lerp to (550,30) at 1/7, shells at
  y<40) with the Tank+0xDC click order before missiles; spawn_laser() draws the
  FUN_00543640 spark at click-40,40 with laser_cell_for() rows by tier (Q-0023 kept open).
  The port-only HUD info line that carried the weapon level and the Time Trial clock was removed
  in the 2026-11-10 owner review (R2/R3), so neither has an on-screen readout until a recovered
  widget places one. headless_weapon_check.
- **P4.6/P4.14** - HatchScreen (award card incl. 999, and since 2026-11-10 the `HATCHSCREEN` art,
  crack strip and masked pet cell - EV-0175), PetsScreen (24 buttons, writes
  profile+0x5A), BonusScreen (payout switch), OptionsDialog (sliders applied to the
  buses instantly), HelpScreen (8 pages + tutorial relabel), HallScreen (4 tabs) are in,
  and Main runs Hatch -> Pets -> Bonus -> next level. headless_profile_check **56 assertions**.
- **P4.5** - Level.roll_stock() runs the roller: a random unowned backdrop at 15000 shells
  (kind 3), falling back to a random unowned pet (kind 1, 5000). Per-item art/tooltips/paging
  stay with the kind byte (Q-0052).
- **F1** - the tailflop sheet and mask load through the imported textures (no load_from_file
  warning on boot or export).


## Review (moved)

The confirmed defects and their fix status - the playtest work list, now **R1-R66** - live in
[`REVIEW.md`](REVIEW.md). That file is the source of truth for what the owner has played and what is
still wrong; this plan stays the source of truth for phase progress. Rows are append-only, so a fixed
row keeps its text and gains a dated status instead of being rewritten.

## Backlog / ideas (not committed)

- Widescreen/HD layout (see Q-0005), mod support, achievements, localization.
- `[!]` `tools\fnmap.ps1` batch runs hang (child-process output buffering + cold Ghidra imports);
  use individual `rea` calls or move the function-map generation into the module snapshot.
  Unblock: rewrite to poll/stream output, or run one shared `analyze` first.
