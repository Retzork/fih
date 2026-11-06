# Behaviour contract for Phase 4 (Phase 2 output)

Status: **P2.18 complete** (2026-11-02). This is the behaviour-side counterpart of
[`PIPELINE.md`](PIPELINE.md) (the asset contract): together they are the two documents P4 implements
against (D-0008). Every number here is recovered from the game module and carries an `EV-` reference
or a pointer to the system note that owns it; nothing here is invented, and where the binary is still
silent the item is listed in §11 instead of being guessed.

Rules that always apply: the game install is READ-ONLY (D-0004); every new behavioural claim needs an
`EV-` entry in [`EVIDENCE.md`](EVIDENCE.md); game-module VAs are the citation currency (D-0009);
unresolved behaviour ships behind a named config flag with the wiki-safe default disabled
(the "guard" pattern, §11).

How to use this document: read §1-§3 before writing any runtime code, then the section for the
system you are implementing. The system notes remain the deep reference - this document defines the
*contracts between* systems and the shared constants, and says which of the notes' details are
load-bearing.

---

## 1. The simulation contract

### 1.1 The tick model

`SexyAppBase` runs a **fixed-timestep loop with catch-up** over WinMM `timeGetTime()` (EV-0034,
`analysis/notes/p2.1-frameloop.md`):

| constant | value | meaning |
| --- | --- | --- |
| frame interval (`this+0x44`) | `10` ms | the loop's logic tick |
| update multiplier (`this+0x70`) | `0.85` | `mUpdateMultiplier`, applied per update |
| catch-up cap | 10 ticks per `Process()` | after that the loop yields |
| backlog clamp | 1000 ms | if `now - last > 1000`, `last = now - 1000` |
| logical resolution (`this+0x10/+0x14`) | 640x480 | the coordinate space everything is authored in |

**P4 must implement the same shape**: accumulate real `dt`, run `update()` in fixed slices, render
once per frame, cap catch-up at 10 slices, clamp the backlog to 1000 ms, and keep the 0.85
multiplier (it damps motion toward its target each tick). Do not use delta-scaled floats inside the
simulation.

### 1.2 The unresolved tick rate (Q-0034)

Two recovered datasets disagree, and P4 must not silently pick one:

| evidence | implies |
| --- | --- |
| P2.1: the ctor writes `10` into the frame-interval field | **100 Hz** |
| P2.7: Blip's unlock compares level age against `200`/`720` for the wiki's 5 s/20 s (200/5 = 40, 720/20 = 36); Prego 930 ≈ 26 s, Meryl 1400 ≈ 39 s, Shrapnel 633..652 ≈ 18 s | **~36 Hz** |
| P2.8: the alien wave clock is 3000 ticks | 83 s at 36 Hz, **30 s at 100 Hz** |
| P2.9: the boss arrival countdown is 300 ticks | 8.3 s at 36 Hz, **3 s at 100 Hz** |

The ratio is 100/36 ≈ 2.78, and the two groups cannot both be read the way their own notes read them:
at 100 Hz the wave clock is 30 s and the boss arrival 3 s, not the 83 s and 8.3 s quoted in P2.8/P2.9;
at 36 Hz the wrapper's 10 ms interval is not the tank's update period. Which of the two matches the
observable game is **not established** (the wiki carries no per-wave timing, `analysis/notes/
wiki-refs.md`), so this is a measurement job, not an inference. P2.2 flagged the same reconciliation as
the outstanding item in its pass.

**Keep every timer an integer tick count** (all P2 notes already do), expose the rate as one constant,
and settle the value by measurement (P5.3) before tuning feel. P4's animation delays are affected by
the same constant (P2.15: `framedelay` values are 2 and 4).

**Port decision (2026-11-04).** The remake runs the **~36 Hz** reading: `Sim.TICK_MS = 1000/36`. Every
gameplay timer recovered as a tick count was calibrated against wiki seconds at that cadence (and the
pellet tumbler only spins at a readable rate there - Q-0051), while the wrapper's `10` is a loop
interval whose consumer in the tank path was never located. Q-0034 stays open for that missing gate;
changing the rate back is one constant.

### 1.3 Space, bounds and layers

- Coordinate space: 640x480 logical, integer scaling, nearest filtering (Q-0005).
- Tank water rectangle: feed/click water is `x 31..586`, `y 61..399` (P2.10 §5); the fish spawn band
  is `x 10..540`, `y 95..370` with the floor at `y 370` and the top clamp field `+0x190`
  (321 = small-tank drift-up at P2.2 §5).
- Food dies at `y 410` (star-quality food at 400) (P2.3 §10).
- Draw order used by the notes: tank backdrop → backdrops/lighting → food and coins → creatures
  (fish, pets, aliens) → particles/effects → HUD → screens/dialogs. Each system note names its own
  sprite ids; the original's z-order is stable because every system draws in list order.

### 1.4 Object model

Objects are one flat type space with a class id per type: `FUN_00537570` is the factory
(`switch(id) -> new(size) + ctor`) and each ctor writes its id at `+0x8C` (EV-0044). P4 does not need
the allocation details but **does** need the id space, because saves and the Virtual Tank screen both
key on it:

| ids | class | note |
| --- | --- | --- |
| `0x00` | Fish (Guppy base) | `0x230` bytes |
| `0x05` / `0x06` / `0x07` | Oscar / Ultravore / Gekko | |
| `0x15` | `FishTypePet` | |
| `0x1B` | DeadFish / corpse object | P2.4, EV-0052 |
| `0x1C` | Food | |
| `0x22` / `0x23` / `0x24` | Sylvester / Ball / Bi fish | |
| `0x0A`-`0x0C` | Breeder creatures (stages 0-2, corpse ids 10-12) | P2.4 §7 |
| `0x08`, `0x09`, `0x14`, `0x16`, `0x17`, `0x19`, `0x1A`, `0x1D`, `0x1E`, `0x1F`, `0x20`, `0x21` | object classes with only a ctor + allocation size recovered (P2.2 §9.1) | `0x1F` is never serialized; `0x19`/`0x1A` are candidate coin classes |

Runtime spawn recipe (every store buy, alien spawn and roster spawn goes through it):

```
new + (x,y) ctor  ->  activate(obj, 1)  ->  add to Tank's list  ->  register(obj)  ->  UI refresh
```

`register` is also what updates the per-species high-water counters, so it must not be skipped when a
system re-spawns an object. The (x,y) ctors are *not* the factory ctors: gameplay objects use the
2-argument variant, which runs the full init plus `FUN_004DE370(x, y)` and clears the state byte
(P2.2 §9.1).

**Serialization** is per object (slot 0x140, direction in the stream header) and the tank body is
`FUN_00546240` (P2.13 §6.1). P4 replaces both with a field model (§7).

### 1.5 Interaction order per click

The whole game funnels through **one** click handler with six stages, first success wins (EV-0122,
P2.10 §1): bonus/prize → boss hit lists → aliens → tank list `+0xDC` (projectiles) → list `+0xF4`
(missiles/larvae) → feed the tank. The laser spark is drawn on any hit, including stages that do
nothing else. This single entry point is the reason P4 should not attach per-object input handlers.

---

## 2. Resource contract (P4.2)

`analysis/notes/p2.15-resources.md` is the reference; the contract is:

1. **Ids are strings, resolved once.** `IMAGE_*`, `SOUND_*`, `FONT_*` come from the manifest as
   `idprefix + id`, and the original resolves each exactly once at load time into a global. P4
   resolves them once at boot into typed handles and never looks up by string at runtime.
2. **Three load phases, in this order** (P2.15 §2): `Init` (14 ids: loader screen, cursors, blank,
   two fonts, click sound) before the first frame; `Register` (16: 13 UI fonts + dialog skin) before
   any dialog; `LoadingThread` (296: 232 images + 64 sounds) behind the loading bar.
3. **Grids and animation** come from `extraction.json` / the committed `SpriteFrames`: `cols*rows`
   cells, row-major, `framemap` as the playback order, `anim` = loop/once/pingpong. Delays are
   integer ticks (Q-0034) - keep them in data, not baked into `.tres` (P3.5 did this deliberately).
4. **Alpha is a second file**: base RGB from the image, alpha from the mask's blue channel
   (P2.15 §5.3). The build-side `frames/<ID>/fNNN.png` output already bakes this; prefer it.
5. **Sounds** map id → stream once, with the manifest's `volume` as the pool default; `alias` is
   unused by the binary and can be ignored. Sound ids are not stable indices (P2.14).
6. **Do not port** the XML parser, the extension-probe chain, the `ddsurface`/`nopal`/`a4r4g4b4`/
   `a8r8g8b8`/`nobits`/`minsubdivide` loader hints, or the refcount handles.

---

## 3. The tank and its creatures

### 3.1 Fish

State per fish (P2.2 §8): `pos`, `vel`, swim mode + timers, `facing`/`flip`, hunger, growth points,
stage, species, plus the effect timers (dart, knockback, hit flash). Per tick, in this order:
hunger/target predicate (P2.3) → path choice (food approach / attractor / swim machine) → velocity
integration and clamp → timer decay → facing/flip. Swimming is a **preset-velocity** machine, not
steering physics: 40-tick steps, re-roll every >20 ticks at 10 %, glide subtraction, wall-bounce
margins of 20 px and a 0.95 drag after 30 ticks in mode `0x7B`.

Spawn defaults (`FUN_004DE370`): size 80x80, band `10..540 x 95..370`, vertical drift `-0.5`, speed
class `{2.0, 1.8, 1.6}`, initial hunger 400-599 (Oscar 600-799), growth threshold 4-6 points
(Virtual Tank 12-20), random facing. Creatures: hunger 900-1099, speed 45, fall 2.5-2.7.

Hunger (P2.3 §10): `fullness` starts 0, `-1` per tick while no effect is active; hints at -1/-200/
-400, death below -499, clamp -1000; eating adds +500 / +700 / +1100 by food quality with caps
800/1000/1400.

Growth and death (P2.4 §8): feed points vs per-stage threshold; stage-up restarts points and plays
the grow animation; overshoot (8 in Virtual Tank, 15 otherwise) jumps to the diminutive stage; death
leaves an inert corpse that sinks while its own stage counter falls and is removed silently when it
reaches 0 - the fish is gone, there is no replacement. The death sound and the **live** successor
from the id table belong to the corpse's uncalled `phase < 1` revive branch (trigger unrecovered,
Q-0043); reviving a corpse is Angie's job (P2.7), not the death path.

### 3.2 Food

Two speed profiles (P2.3): drop falls at 1.5; a landed pellet bobs on a 120..150-tick cycle with 0.05
drift decay. Normal pellets never expire on their own. Feeding spends `Tank+0x4AC` (base 5) per pellet,
drops it at the cursor, latches hold-to-feed on `+0x4EC`/`+0x4ED`, and caps non-special pellets at the
`food_quantity` level. The star potion is an armed flag (`Tank+0x440`): the next manual drop is
quality 3, which kills small fish, stages a stage-2 guppy up, and splashes on death.

### 3.3 Coins

Every fish carries a drop counter (`+0x220`) that spawns a coin at a per-species/stage threshold; the
kind → value table and Virtual Tank multipliers live in P2.5 §5. Coins fall, land at `y 370`, bob,
expire by threshold, and are collected by proximity to non-Fish creatures, the cursor-driven
collectors, and the "collect all" call that runs at level end (`FUN_0053C2D0`). Collection dispatch is
per-list and order-sensitive (EV-0055); the intent question for coin hits is Q-0010. P4 seam: `Fish`
emits `coin_due` when the counter matures (EV-0155); the coin system owns the stage -> kind mapping
(Q-0036), and the coin object itself is not part of P4.3.

### 3.4 Pets

Two entity families (`OtherTypePet`: Stinky, Niko, Clyde, Rufus, Rhubarb; `FishTypePet`: the rest),
one `PetDef` per index 0..23, and a fixed update gate order (P2.7 §7): base tick → pause gate
(`Tank+0x94`) → tank-5 skip → alien gate → slot-81 action → steering → contact → render. Timers are
integer ticks; reproduce the slot-81 branches exactly (Prego 930/1230/2000, Zorf 65 with 2/4 cadence,
Vert 216, Meryl 1400/4320, Shrapnel 633..652, Nostradamus 300..599/1080..1279, Amp 3000, Gash
1570/1520, Stanley 100). Coin eligibility is a **predicate per pet**, not a shared "collectible" flag.

Presto is a swap (`recharge → spawn target at same x/y → remove old → cleanup`); Walter's glove is its
own short-lived entity (life 30, 0xA0x50 box, hit list `Tank+0x108`); Angie only targets corpses with
`+0x1A0 > 0x5F`. Every despawn/sell/transform/level teardown must run the pet-cleanup equivalent
(hidden-Wadsworth count, Meryl song flag, glove detach) or state leaks across levels.

### 3.5 Aliens

**One** entity with a `kind` field and a `kind → AlienDef` table (P2.8 §11) - the original does not
have one class per species. Kinds: 1/2 Sylvester (hp 50/60, speed 2.0/1.6), 3 Balrog (130, 1.2), 4 Gus
(100, 1.6, eats pellets), 5 Destructor (150, 1.2, bottom lane, 3 missiles), 6 Ulysses (220, 3.5,
bottom lane, 2 balls), 7 Psychosquid (260, 0.5/2.0, rest cycle), 8 Bilaterus, `0x14` Minisylvester
(1 hp, 0.8-1.2), `0x15` Cyrax (2500-5000). Kinds 9-`0xC` are composite spawn recipes, not entities.

- **Wave clock**: 3000 ticks, and it only advances while `alien_type != 0`, no boss is alive, and the
  alien/projectile lists are empty. Milestones fire in a fixed order (message → warp hole + coordinate
  roll → sound → warning → event → spawn). Spawn point: `x = rand%450 + 20`, `y = rand%195 + 105`,
  rolled once and reused for the second member of a composite.
- **Selection vs instance**: the tank stores the spawn selection, the alien stores its own kind; a
  composite type spawns two entities without changing the stored selection.
- **Movement**: clamped bands `x -10..490`, `y 85..290` (mini `10..540 / 95..370`), quadrant wander
  with 0.1 steering steps and a 20-tick/10 % re-roll, `±3` intro drift for 7 ticks.
- **Attacks are data-driven**: none (Sylvester/Balrog/Gus/mini), missiles_3 (Destructor, sound 0x128,
  period 75 then `rand%50+150`), balls_2 (Ulysses, sound 0x143), rest_cycle (Psychosquid, 400 ticks,
  sound 0x135), boss (Cyrax: projectile every 75 ticks, 4-9 minions after 300 clear ticks), heads
  (Bilaterus).
- **Eating is a chase plus a reach test**, not an instant consume: nearest eligible target, steer
  (0.1/tick, cap 1.8; Gus on pellets 0.3/tick, cap 3.0), then a centre-to-centre box of ±45 x / ±65 y
  (±30 mini, ±70/±85 against type 6) hands off to consume/get-eaten. A flashing alien cannot bite;
  kinds 5 and 6 never eat.
- **Death**: one path. A kind-independent Diamond coin (kind 4, value 200) when killed by a shot while
  no boss is alive, then per-kind debris and sounds (0x11D/0x11E, 0x11F mini), a death animation only
  for the default kinds, then unregister. `from_shot == 0` skips every effect.

### 3.6 Bosses

Tank 5 level 1 is `boss = "cyrax"` (P2.9 §10): egg pieces 3, one free egg item in store slot 6,
pet capacity forced to 10 when he spawns, 300-tick arrival, `hp = 5000 - 125 * clamp(profile_counter -
1, 0, 20)`, speed divisor 2.0, 160x160 box, y clamp 85..290, 15-tick intro, minions every 75 ticks at
`+40,+40`, an alien pulse every 300 ticks only while the field is clear, waves frozen until death and
then never again. Damage is a single pool; a shot does `3 * pet_capacity` (30 at the boss value 10, 6
at the normal 2), at most one hit per 10 ticks per alien; pet melee is 1.0 (Itchy) / 3.0 (Gash). The
HP bar is always drawn for the boss; other aliens only when the tank's bar flag is set and the tank is
not 5.

`Bilaterus` is the exception to "one alien entity": it owns two head entities (80x80, 100 hp each) and
six cosmetic bones, because pets must be able to target a head.

### 3.7 Projectiles

One class with three kinds (P2.10 §6): 0 = Destructor missile (80x80, speed 0.8, homing, clamped
`x 10..550 / y 95..370`, smoke trail), 1 = Ulysses ball (dies outside `x -20..580 / y 45..380`,
deflectable), 2 = 50x50 falling shot (speed 0.4, gravity 0.2). Spawn immunity 15 ticks, expiry 10 ticks
once the target is gone, and the victim pointer (`target+0x98`) is always set by the spawner and must
be cleared when either side dies. Clicking a projectile destroys kind 0 and deflects kind 1.

Weapon damage is `3 * weapon_level` (`2*speed + 2` for the Destructor/Ulysses pair), weapon level
2..12, forced to 10 during the boss fight. Level 12 unlocks hold-to-fire: period `11 - level/2` ticks
(5 at 12), never faster than one shot per 100 ms, and it re-tests only missiles → larvae → aliens.

---

## 4. Economy and progression

### 4.1 Money

Money is one integer on the tank. Every spend goes through the same gate order (P2.5 §8): mode
exemption → demo floor 5 → affordability, where affordability counts **uncollected coins in the tank**
as spendable → sound/hint → subtract. "Collect all" banks those coins at level end. Purchases funnel
through one `buy_item(index)`; upgrades are tank counters: food quality 0..2, food quantity 0..9,
weapon 0..11.

### 4.2 Store

A data table of 12 items `{id, name_key, price, handler}` rendered into 8 slots (P2.12 §6). Slot kind
`+0x14C`: 0 sold out, 1 egg/pet, 2 Bubbulator, 3 backdrop, 4 alien attractor, 5 food upgrade; price
line shows `SOLD` when unavailable and greys to `0xCCCCCC` when disabled. Stock re-rolls on attach and
on a 100-249-tick refresh timer; one slot is always a random **unowned backdrop** at 15000 shells,
falling back to a random pet once all six are owned (EV-0141). In Virtual Tank, actions 0-0xB bypass
`BuyItem` and action 10 routes to the pet store; action 0xF is the egg handler in every mode.

### 4.3 Level start, egg completion and the bonus

The level-start algorithm and the exact store/bonus data are in P2.6 §10.2-10.7 and P2.11 §10.2; the
contract points:

- starting money 200 (999999 in Sandbox), pellet price 5, egg pieces 1 (3 on tank 5), pet capacity 2
  (8 in the demo build, 10 during the boss), alien countdown 3000;
- `sessions_started` increments on **every** level start;
- egg completion: stop the clock, collect all coins, clear the boss flag, then branch by mode
  (Virtual Tank writes the challenge record; bonus adventure fast-finalizes; otherwise advance and
  grant the pet), with tank 4 level 5 awarding nothing (the 999 card) and tank 5 level 1 granting pet
  19 plus 5000 shells;
- tank-complete bonus: base timers `[10, 10, 15, 20, 25, 10]` plus `clamp(level,1,6) - 1`, starts 160
  ticks after completion, and ends only when the timer has expired, the coin list is empty and the
  counter is above 100;
- payouts: Adventure non-tank-5 → `bonus_shells`; tank 5 → `clamp(max(1, counter-1)*5000, 0, 25000)`;
  Time Trial → `money*5/100`; Challenge → 2000/5000/10000/20000 by tank. Always through the clamped
  Shells setter (0..9,999,999).

### 4.4 Pets roster

Indices 0-23 (Stinky, Niko, Itchy, Prego, Zorf, Clyde, Vert, Rufus, Meryl, Wadsworth, Seymour,
Shrapnel, Gumbo, Blip, Rhubarb, Nimbus, Amp, Gash, Angie, Presto, Brinkley, Nostradamus, Stanley,
Walter) plus 999, which is a card/UI definition only - never a `PetDef`. The award map (which level
grants which index) is P2.6 §10.5.

---

## 5. Modes

Mode is an **input** to level start, never derived (P2.11 §10, EV-0126): `0` Adventure, `1` Time
Trial, `2` unused, `3` Sandbox, `4` Challenge, `5` Virtual Tank.

| mode | money | timing | pets | save file | reward |
| --- | --- | --- | --- | --- | --- |
| 0 Adventure | 200 | none | yes | `adv%d.dat` | shells / bonus |
| 1 Time Trial | 200 | 300 s (tank 1), 600 s (tanks 2-4); expiry collects coins and ends the level | **no** | `tim%d.dat` | `money*5/100` |
| 2 unused | - | keep the row empty | - | - | - |
| 3 Sandbox | 999999 | none | yes | `snd%d.dat` | none; per-frame price re-roll |
| 4 Challenge | 200 | egg-priced inflation every 150/150/175/200 ticks by tank | yes | `sur%d.dat` | 2000/5000/10000/20000 |
| 5 Virtual Tank | 200 | VT tick | yes (VT periods) | `sim%d.dat` | shell conversion |

Mode-specific rules that bite elsewhere: Virtual Tank plays **no music** (P2.14), runs its own init
(no starter fish, no alien clock, aliens only if the tank's unlock flag is set), spawns fish on a
76 %/24 % ordinary-vs-prize split with a 26/25/25/10/5/3/3/3 weighted table and a 100-try retry, and
converts coins to shells instead of money. Challenge turns a rolled alien type 8 into `0xC` after
wave 4 and writes an unlock byte plus a record block per tank. Sandbox has no tank-5 case.

Do **not** port `FUN_004D80C0` as a "demo" test - it is an object-kind test (EV-0130), and the earlier
"demo" reading of random-velocity missiles is withdrawn.

---

## 6. UI shell

Screens are widget containers plus a listener mixin; the original keeps two vtables per screen
(draw/update/children and six button callbacks), and P4 should keep them as two components (P2.12 §1).
Port screens as **data + one id-dispatched handler**, not as bespoke classes:

| screen | content | key rules |
| --- | --- | --- |
| Title | two image buttons | registration button hidden by the profile flag |
| Main menu (`GameSelector`) | eight buttons | ids 2/8/9 are the only mode writers; Time Trial gated on tank 2 unlocked, Challenge on Adventure finished ("Not Yet!" otherwise); no Sandbox entry; clear the demo flag on every press |
| Store | 8 slots + shell counter + frame overlay | §4.2; one random backdrop slot |
| Hatch | pet card | OK → pets screen; tank 4 level 5 shows card 999 |
| Pets | 24 buttons, 3-run layout | Confirm needs 3 selected pets outside Virtual Tank; Virtual Tank diffs against the open-time snapshot |
| Bonus | prize card | Continue branches by mode and by the `manager+0x738` byte |
| Interlude | one button | the tank-5 level-2 "Back To Main Menu" gate |
| Help / tutorial | 8 pages | the same screen serves both; tutorial hides "Click Here To Continue" and relabels Menu to "Back to Game" |
| High score | four tabs | |
| Story | 32 pages | Previous/Next hidden until the story mask has ≥ 2 bits |
| Sim fish / Sim setup | Virtual Tank management | 20 rows over `type id < 0x14`; setup copies five checkboxes into the tank and cycles the six backdrop flags |

Dialogs are one modal base with a `kind` that drives the built-in button row and nothing else
(0 none, 1 Yes/No, 2 OK/Cancel, 3 one caller-labelled button with id 1000), captions resolved through
the localization keys `DIALOG_BUTTON_YES/NO/OK/CANCEL`. All eleven dialogs and their extra widgets are
tabulated in P2.12 §11; port them as data. `MoneyDialog` has no constructor and is never instantiated -
do not port it.

Options lives in one dialog: Register/Help/web/Back-to-menu/Check-updates actions, two sliders seeded
from the mixer, three checkboxes. `MusicVolume`/`SfxVolume` persist as integer percent and apply
instantly (P2.14 §6).

---

## 7. Persistence

P2.13 is the reference. The contract P4 must satisfy:

1. **Profile separate from tanks.** `users.dat` is the profile list (version `0x0E`, count, names,
   trailing dwords); `user%d.dat` is a 232-byte profile slot; tank saves are **one file per mode**
   keyed by the profile slot (`adv`/`tim`/`snd`/`sur`/`sim`, EV-0142). A mode must never clobber
   another mode's tank.
2. **Model fields, not offsets.** A `ProfileData` with named fields (money, tank, level,
   bonus_adventure, 24 owned-pet bytes, selected pets, pet capacity, challenge unlocks, shells,
   sessions, records, story mask/gold candidates) and a `TankData` with the level copies, money,
   bonus shells, egg pieces, timers, entity array, overlay, 24 pet presence flags, scalar block, food
   globals, backdrop tint, 12-row store table and timestamp. Unresolved fields stay explicitly named
   `unknown_XX` so evidence can rename them without breaking saves.
3. **Load repairs are part of the contract** (P2.13 §6.6): recompute the store widget count, rebuild
   widgets for rows whose `present` latch is set, drop the hidden-Wadsworth count when no pet
   container is populated, clear the Meryl song flag when Meryl is not owned, and recompute the
   `+0x2DC` value from the store table instead of trusting it.
4. **Own format is allowed, byte compatibility is not promised.** P4.12 should ship a versioned
   remake format that preserves *semantics*; if compatibility with original saves is wanted, add a
   separate importer/exporter and never overwrite the original files. The trailing `+0x88` dword is
   not a verified checksum - do not invent one.
5. **Bonus-shell escrow**: the original banks `Tank+0x400` in `scr%d.dat` because it is absent from
   the tank body. P4 keeps the counter in its own save and pays it back **exactly once**; the failure
   modes to avoid are losing shells on quit-mid-bonus and paying them twice.
6. **Entity persistence policy is a documented divergence**: the original dumps every live entity
   (`u32 class id + Serialize`, skipping type `0x1F`). P4 should persist only state that cannot be
   reconstructed (fish tiers/positions, store state) and rebuild coins, missiles, food and particles.
7. **Golden-file tests** for both profile samples and both tank samples (`adv1.dat`, `sim1.dat`) with
   the section offsets `42+E+S` / `454+E+S` / `658+E+S` asserted - that is the regression guard for
   the whole body order.

---

## 8. Audio

Two independent mixers, two volume controls (P2.14 §8):

- **Music** on its own bus: three tracks loaded once at startup (`Alien` = id 1, `Lullaby` = 3,
  `Insaniq2` = 4), always looping, `SetMusic` re-uses one call for both level and menu music. The
  per-stage selector gives stage 1-4 → `(0,22)/(0,0)/(2,32)/(2,45)`, level complete → `(0,13)`, and
  Virtual Tank plays nothing. The exact `(track, order)` mapping of those pairs is still open
  (Q-0031b) - start every track at position 0.
- **Effects** on a second bus with a fixed pool (256 slots in the original): a play call takes the id
  alone - no per-call volume or pan - and uses the resource's default volume. Overlapping identical
  sounds are normal (the tank fires the same click repeatedly); drop and log when the pool is
  exhausted, mirroring `"Out of free sound ids"`.
- Volumes are doubles 0..1 in memory, integer percent on disk, applied instantly to live voices.

Sound **trigger points** are documented per system (P2.14 §5 lists the 65 resources; Q-0030 tracks the
per-event mapping). Trigger from the events the system notes describe, never from a guessed table.

---

## 9. Cross-system rules

These are the couplings that are easy to get wrong when systems are implemented separately:

1. **One tick, one order.** Tank update per tick: timers/clock → fish (hunger, movement) → pets
   (gated) → aliens (movement, eating, attacks) → projectiles → collisions/collection → food →
   particles → render. A system that runs its own timer breaks the wave clock's pause contract and the
   pet gates, which read the same tick counters.
2. **Pause gates are shared state.** `Tank+0x94` pauses pets; the alien gate (`FUN_005392A0`)
   suppresses attacks during intros and for resting kinds; the tank-5 skip suppresses pet actions.
   These are read by several systems - implement them once as tank-level predicates.
3. **Level teardown is a contract.** Every despawn/sell/transform/level change runs pet cleanup and
   clears the projectile victim pointers (`target+0x98`); the boss death additionally wipes all aliens
   and enemy projectiles and freezes waves.
4. **Mode changes the rules, not the code path.** Mode is passed into level start; the store, the
   bonus payout, the egg price, the wave/pet timers and the save file all branch on it. Keep those
   branches in one `mode_rules` table.
5. **Money and shells are clamped and gated in one place.** All spends go through the §4.1 gate; all
   shell grants go through the 0..9,999,999 setter.
6. **Resources are resolved before use.** A system that needs `IMAGE_X`/`SOUND_Y` must be downstream of
   the load phase that registers it (`Init` / `Register` / `LoadingThread`).
7. **The click handler is the only input entry.** Feeding, shooting, collecting and dialog clicks all
   arrive through the staged handler of §1.5 plus the screen/dialog listeners.
8. **Randomness is per-site.** The original calls `rand()` at spawn, wander re-roll, attack period,
   egg roll and VT roster sites; keep the *shape* (ranges, retry counts) but not the sequence - no
   gameplay value depends on matching the RNG stream.

---

## 10. Shared constant sheet

Values every system may reference. Format: value(s) - meaning - owner (§) - evidence.

**Simulation**

| value | meaning | section | evidence |
| --- | --- | --- | --- |
| 10 ms / 100 Hz (disputed: ~36 Hz) | logic tick, see Q-0034 | 1.1/1.2 | EV-0034, EV-0080 |
| 0.85 | per-tick update multiplier | 1.1 | EV-0034 |
| 640x480 | logical resolution | 1.3 | EV-0034 |
| 10 ticks / 1000 ms | catch-up cap / backlog clamp | 1.1 | EV-0034 |

**Tank and fish**

| value | meaning | section | evidence |
| --- | --- | --- | --- |
| `x 31..586`, `y 61..399` | feed/click water | 1.3 | EV-0122 |
| `x 10..540`, `y 95..370` | fish spawn band | 3.1 | EV-0049 |
| 80x80, 10 columns | sprite cell / sheet layout | 3.1 | EV-0026 |
| 400-599 / 600-799 | initial hunger (common / Oscar) | 3.1 | EV-0049 |
| 4-6 / 12-20 | growth threshold (normal / VT) | 3.1 | EV-0049 |
| 8 / 15 | stage-4 overshoot multiplier (VT / normal) | 3.1 | EV-0056 |
| -1, -200, -400, -500, -1000 | hunger hint / HUD / death / clamp | 3.1 | EV-0048 |
| +500 / +700 / +1100, caps 800/1000/1400 | nutrition by food quality | 3.1 | EV-0048 |
| 370 / 410 (400 star) | coin floor / food death line | 3.2/3.3 | EV-0045, EV-0047 |
| 2.0 / 1.8 / 1.6 | fish speed classes | 3.1 | EV-0049 |

**Creatures and combat**

| value | meaning | section | evidence |
| --- | --- | --- | --- |
| 3000 ticks | alien wave clock | 3.5 | EV-0114 |
| 1/2: 50/60 hp, 3: 130, 4: 100, 5: 150, 6: 220, 7: 260, `0x14`: 1, `0x15`: 2500-5000 | alien hp by kind | 3.5 | EV-0111 |
| ±45 / ±65 (mini ±30, vs type 6 ±70/±85) | bite reach box | 3.5 | EV-0116 |
| 75 ticks, then `rand%50+150` | Destructor/Ulysses attack period | 3.5 | EV-0113 |
| 400 ticks | Psychosquid rest cycle | 3.5 | EV-0113 |
| 80x80 x2 heads, 100 hp | Bilaterus | 3.6 | EV-0112 |
| 5000 - 125*clamp(n-1,0,20) | Cyrax hp | 3.6 | EV-0117 |
| 75 / 300 ticks, `rand%6+4` | Cyrax minion / pulse | 3.6 | EV-0117 |
| 3 * weapon_level (2*speed+2 for 5/6) | shot damage | 3.7 | EV-0120 |
| 10 ticks | per-alien hit cooldown | 3.7 | EV-0120 |
| 3 * pet_capacity (6 at 2, 30 at 10) | shot damage as P2.9 measured it | 3.6 | EV-0121 |
| `11 - level/2`, ≥ 100 ms | Rapid Fire period | 3.7 | EV-0129 |

**Economy and progression**

| value | meaning | section | evidence |
| --- | --- | --- | --- |
| 200 / 999999 / 5 / 2 | start money / Sandbox money / pellet price / pet capacity | 4.3 | EV-0128 |
| 15000 | backdrop price in the store roller | 4.2 | EV-0141 |
| [10,10,15,20,25,10] + clamp(level,1,6)-1 | bonus timer base by tank | 4.3 | EV-0076 |
| 160 ticks | delay before the bonus starts | 4.3 | EV-0076 |
| 5000 * (counter-1), clamp 25000 | tank-5 bonus shells | 4.3 | EV-0076 |
| 300 s / 600 s | Time Trial budget (tank 1 / 2-4) | 5 | EV-0127 |
| 150/150/175/200 ticks | Challenge price inflation period | 5 | EV-0127 |
| 76/24 % and 26/25/25/10/5/3/3/3 | Virtual Tank fish roll | 5 | EV-0128 |
| 0..9,999,999 | shells clamp | 4.3 | EV-0066 |

**Audio**

| value | meaning | section | evidence |
| --- | --- | --- | --- |
| 256 | effect-slot pool | 8 | EV-0149 |
| ids 1/3/4 | music tracks (Alien, Lullaby, Insaniq2) | 8 | EV-0147 |
| `(0,22)/(0,0)/(2,32)/(2,45)`, `(0,13)` | stage 1-4 / level complete music | 8 | EV-0148 |

This sheet is the seed for P5.1's full differential table; add values there with their EV entry rather
than editing numbers in place.

---

## 11. Open questions P4 must respect

Do not guess these; ship them behind a named config flag with the wiki-safe default **disabled**, and
reference the question id in the code comment.

This table is the P2.18 snapshot and stops at Q-0039. Questions raised later (Q-0040..Q-0059) are
live in [`DECISIONS.md`](DECISIONS.md) and are cited from the P4 task lines in `PLAN.md`; Q-0059 is
the UI-font one.

| id | what is open | impact |
| --- | --- | --- |
| Q-0010 | coin-hit gameplay intent | coin collection dispatch (§3.3) |
| Q-0011 | hostile alien class identities | answered by EV-0110 for kinds; residual in P2.8 |
| Q-0013 | trophy/story award gate | do not hard-code "100 %" (§7.2) |
| Q-0014 | mode 2 | keep the mode row empty (§5) |
| Q-0015 | `+0x58`/`+0x50` semantics | bonus-adventure bookkeeping (§4.3) |
| Q-0016 | credits trigger | do not invent a screen transition |
| Q-0017 | tank 6 | treat as out of scope |
| Q-0018 | normal store-item object owner | store stock population (§4.2) |
| Q-0020 | kind 1 vs 2, alien gate sub-predicates, Gus pellet hp cost | alien AI (§3.5) |
| Q-0021 | boss egg-purchase gate | P4 gates it on the boss being dead - a **documented divergence** |
| Q-0024 | mode writer/`+0x19C` receiver/`Tank+0x4FE` writer | mode plumbing (§5) |
| Q-0025 | Virtual Tank residuals | sim screens (§6) |
| Q-0027 | two dialog loose ends | options/screen-saver dialogs (§6) |
| Q-0028 | save/delete gate | delete-profile flow (§7) |
| Q-0029 | unbound tank-save fields | `unknown_XX` fields (§7.2) |
| Q-0030 | which event plays which of the 33 unbound sounds | SFX triggers (§8) |
| Q-0031 | music `(track, order)` mapping, BASS load flags, backend switches | start tracks at 0 (§8) |
| Q-0032 | `framemap` `-1`, `framedelay` unit | animation (§2.3) |
| Q-0033 | grayscale runtime colourisation | fish/effect tints (§3.1) |
| Q-0034 | 100 Hz vs 36 Hz tick rate | **everything time-based** (§1.2) |
| Q-0035 | `Food` landed flag and `FUN_004D62D0` bottom behaviour | food fall/land (§3.2) |
| Q-0036 | which coin kind each species/stage emits | coin spawn (§3.3) |
| Q-0037 | stage-4 overshoot for non-Guppy species | growth (§3.1) |
| Q-0038 | two food-approach paths + per-species `+0x229` | feeding/steering (§3.1) |
| Q-0039 | swim target-timer operand (`FUN_00564160`) | swim timing (§3.1) |

---

## 12. Mapping to the P4 tasks

| P4 task | sections here | primary note | assets |
| --- | --- | --- | --- |
| P4.1 architecture (scenes, autoloads, signals, tick) | §1, §9 | p2.1-frameloop | - |
| P4.2 resource loader | §2 | p2.15-resources | `extraction.json`, `SpriteFrames` |
| P4.3 core entities | §1.4, §3.1-3.3 | p2.2-tank-sim, p2.3-feeding, p2.4-growth-death | frames, masks |
| P4.4 tank simulation + feeding | §1.5, §3.1-3.3 | p2.2, p2.3 | tank backdrops, food |
| P4.5 economy + store UI | §4.1, §4.2, §6 | p2.5-economy, p2.12-menus | store art, fonts |
| P4.6 egg/level/tank progression | §4.3, §4.4 | p2.6-progression | hatch art, pet cards |
| P4.7 pets | §3.4 | p2.7-pets | pet sheets |
| P4.8 aliens + waves | §3.5 | p2.8-aliens | alien sheets |
| P4.9 bosses | §3.6 | p2.9-bosses | boss art, health bar |
| P4.10 weapons/projectiles | §3.7 | p2.10-weapons | missile/laser art |
| P4.11 modes | §5 | p2.11-modes | - |
| P4.12 save system | §7 | p2.13-saves | - |
| P4.13 audio | §8 | p2.14-audio | `assets_raw/{sounds,music}` |
| P4.14 menus/UI/options/help | §6 | p2.12-menus | UI art, BMFonts |

---

## 13. Deliberate divergences from the original

Recorded here so P5.2 does not report them as bugs:

1. Own save format (semantics preserved, bytes not) - unless an importer is added (§7.4).
2. Entity persistence is selective: derived state is rebuilt, not dumped (§7.6).
3. The boss egg is gated on the boss being dead (Q-0021).
4. No demo mode, no FMOD path, no BASS, no `.mo3` streaming - Godot supplies the mixer (§8).
5. No XML parsing at runtime; the manifest is a build-time input (§2).
6. Unresolved mechanics ship behind disabled config flags (§11), never as guessed behaviour.

---

## 14. Reproducing this pass

P2.18 adds no binary evidence: it is a synthesis of EV-0022..EV-0154 and the fifteen system notes. The
per-system dossiers are the sources, each ending with its own P4 spec:

`p2.1-frameloop` (loop/tick), `p2.2-tank-sim` (fish, factory, save pipeline), `p2.3-feeding`,
`p2.4-growth-death`, `p2.5-economy`, `p2.6-progression`, `p2.7-pets`, `p2.8-aliens`, `p2.9-bosses`,
`p2.10-weapons`, `p2.11-modes`, `p2.12-menus`, `p2.13-saves`, `p2.14-audio`, `p2.15-resources`. The
asset side is [`PIPELINE.md`](PIPELINE.md); the task list is [`PLAN.md`](PLAN.md) §§P4/P5.
