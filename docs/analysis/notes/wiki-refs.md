# Wiki cross-reference - internal names <-> display names

Status: living index (created 2026-10-16; second pass 2026-10-20; pet pass 2026-10-21).
Policy: D-0010. Backing evidence: EV-0060 (first wiki pass), EV-0074 (second pass) and EV-0105
(24 pet pages), plus the binary-binding EVs cited per row. The wiki is a **secondary source**:
behavior/constants still require binary evidence; wiki-vs-binary conflicts are listed in §11 and
stay open until resolved. All addresses are game-module VAs (D-0009).

Fetch method: raw wikitext via `https://insaniquarium.fandom.com/wiki/<Page>?action=raw` (the
normal HTML page adds nav chrome). Pages consulted 2026-10-16: Main Page, Sylvester, Balrog,
Bilaterus, Aliens, Guppycruncher, Beetlemuncher, Starcatcher, Ball Fish, Minisylvester,
Bilaterus Head, Money, Virtual Tank Mode, Time Trial Mode, Challenge Mode, Adventure Mode,
Sandbox Mode. Second pass 2026-10-20: Bonus_Round and Tank_5 fetched successfully; Pets,
Challenge_Mode and Time_Trial_Mode returned HTTP 403 on retry but had been fetched earlier in
the same pass. Third pass 2026-10-21: all 24 pet pages fetched via `?action=raw` (Stinky ...
Walter); no wiki text is saved locally (the URLs above are the record).

Naming policy: use the wiki display names in prose (notes, PLAN, specs); internal class/type
names stay the technical identifiers. Add every new binding here with its binding evidence.

## 1. Fish / store-bought creatures

| Internal (binary) | Type id | Display name (wiki) | Binding evidence |
| --- | --- | --- | --- |
| `Sexy::Fish` | 0 | Guppy | store item 0 "buy guppy" -> `FUN_00546D70` (EV-0046/0056) |
| `Sexy::Oscar` | 5 | Carnivore | store item 4 "buy carnivore" -> `FUN_00544C00` (EV-0046/0049) |
| `Sexy::Ultra` | 6 | Ultravore | store item 9 "buy ultravore" -> `FUN_00544E60` (EV-0046/0050); tank4 store slot 4 at $10000 (EV-0072) |
| `Sexy::Gekko` | 7 | Beetlemuncher | store item 8 "buy beetlemuncher" -> `FUN_00545080` (EV-0056); wiki art trivia: sprites named "gekko" |
| `Sexy::Grubber` | 9 | Guppycruncher | store item 7 "buy guppycruncher" -> `FUN_00545430` (EV-0056); wiki art trivia: sprites named "Grubber"/"Grubgrubber" |
| `Sexy::Penta` | 8 | Starcatcher | store item 6 -> `FUN_00545260` -> ctor `FUN_004EC080` (EV-0059); corpse successor id 8 (EV-0053) |
| `Sexy::Breeder` | 0xA-0xC | Breeder | corpse ids 10-12, ctor `FUN_004EE5C0` (EV-0054) |

Virtual Tank prize fish (weighted roster spawner `FUN_0051B260` + VT populate `FUN_0052F0D0`,
EV-0056) - **not** hostile aliens:

| Internal (binary) | Type id | Display name (wiki) | Binding evidence |
| --- | --- | --- | --- |
| `Sexy::SylvesterFish` | 0x22 | Minisylvester | VT roster weight 3% (EV-0056); grows 1 -> 2 (160x160) via `FUN_004D9D50`; wiki Minisylvester page |
| `Sexy::BallFish` | 0x23 | Ball Fish | VT roster weight 3% (EV-0056); inline stage 0->1->2 = whiffle/soccer/beach (wiki) |
| `Sexy::BiFish` | 0x24 | Bilaterus Head | VT roster weight 3% (EV-0056); `+0x230 = rand&1` = round/pointed head variant (wiki) |

Internal-only: `Sexy::DeadFish` (type 0x1B) = corpse with successor spawn (EV-0052/0053);
`FishTypePet` (type 0x15) = pet-carried fish type, P2.7.

## 2. Hostile aliens (open)

Wiki entity roster (matches `resources.xml`, EV-0022): Sylvester (SYLV/MINISYLV), Balrog, Gus,
Destructor, Ulysses, Psychosquid, Bilaterus, Boss. The module RTTI map
(`docs\evidence\p2.2-module-rtti-classes.txt`) has **no** matching subclasses - only
`Alien::Sexy` plus `Bilaterus`/`BilaterusHead`/`BilaterusBone` and the helper classes `DeadAlien`,
`Missle` (Destructor missiles), `Larva`. Where the hostile alien types live is open (Q-0011);
resolve in P2.8 by tracing the spawn waves and `Alien` ctor callers. Wiki HP figures (Sylvester
10 hits, Balrog 22 hits, Bilaterus 17 per head) are wiki-only until P2.8 verifies them.

Per-level type selections observed in the binary are listed in the P2.6 note §8 (EV-0070);
`0x15` is the tank-5 Cyrax boss selection, not a proven class identity.

## 3. Money denominations (`Coin::Value` `FUN_004D53A0`, EV-0047)

| Kind `+0x194` | Normal value | VT multiplier | Wiki item (Money page) |
| --- | --- | --- | --- |
| 1, 8, 0x12 | 15 | x1 | Silver Coin |
| 2, 9 | 35 | x2 | Gold Coin |
| 3, 0xA | 40 | x3 | Star |
| 4, 0xB, 5, 0xC | 200 | x5 | Diamond |
| 6, 0xD | 500 | x10 | Pearl |
| 7, 0xE | 2000 | x20 | Treasure Chest |
| 0x11 | 150 | x5 | Beetle |
| 0xF | 250 | x10 | Niko's Pearl |

Kind pairs {n, n+7} = two sprite variants of the same item. VT multiplier names (wiki Virtual
Tank Mode): x1 Silver, x2 Gold, x3 Star, x5 Blue shell, x10 Spiral shell, x20 Bag o' shells.
Open: kind 0x10 (binary value 0) identity; VT beetle value (see §11).

## 4. Game modes (`[manager+0x87C]`)

| Mode | Observed binary behavior | Wiki mode | Status |
| --- | --- | --- | --- |
| 0 | Adventure banners ("Welcome to the Insaniquarium!" / "Welcome to the next level!" / second-tank banner), tank/level from `profile+0x1C/+0x20`, bonus after tanks 1-3 (EV-0063/0068/0073/0076) | Adventure | high; P2.11 finalizes |
| 1 | random-pet purchase, price doubling `2*B[11]` (EV-0057); session timer `Tank+0x3BC` = 300 s tank1 / 600 s tanks 2-4; "%d%% Bonus Award" = `money*5/100` (EV-0069/0073) | Time Trial | high; wiki's 5%/10% timer wording open -> §11 |
| 2 | not observed | unknown | open; Q-0014, P2.11 |
| 3 | "You've discovered the top-secret SANDBOX mode!"; money 999999 (EV-0072/0073); egg handler calls `FUN_00552230` and returns (EV-0067) | Sandbox | high; entry condition `profile+0xB0 > 5`, sets `profile+0xB4 = max(+0xB4, 11)` (EV-0065) |
| 4 | price inflation via D array + reset to C on egg purchase, "Prices have been reset!" (EV-0067/0072); tank-complete unlock `profile+0x77+tank`; bonus 2000/5000/10000/20000 by tank; "Click for Story Time" (EV-0069/0071) | Challenge | high |
| 5 | economy off (`SpendMoney` exempt), shells `Tank+0x400`, HUD coin flight (EV-0046/0047); no session banner; `FUN_0053C3F0` init; VT pets 0..0x11 on tank 5 (EV-0073) | Virtual Tank / screensaver | high |

Mode 0/1/4 all use `profile+0x59` (Bonus Adventure flag) differently; the session pet branch is
`(profile+0x59 == 0 || (mode != 1 && mode != 4)) && profile+0x18 < 4` -> owned pets, else selected
pets (EV-0073).

## 5. Store prices (binary, EV-0072; first pass EV-0062 corrected)

| Item id | Display name | Binary slot / price | Notes |
| --- | --- | --- | --- |
| 0 | Guppy | s0 / $100 (tanks 1-3) | - |
| 1 | Breeder | s0 / $200 (tank 4) | - |
| 2 | Food quality | s1 / $200 | tank1 hides L1; tank2 L1 shows |
| 3 | Food quantity | s2 / $300 | tank1 hides L1 |
| 4 | Carnivore | s3 / $1000 (tanks 1, 4) | tank1 hides L1-L2 |
| 5 | Star Potion | s3 / $250 (tank 2) | - |
| 6 | Starcatcher | s4 / $750 (tank 2) | tank2 L1 hides it + weapon |
| 7 | Guppycruncher | s3 / $750 (tank 3) | - |
| 8 | Beetlemuncher | s4 / $2000 (tank 3) | tank3 L1 hides it + weapon |
| 9 | Ultravore | s4 / $10000 (tank 4) | tank4 L1 hides it + weapon; **not** Beetlemuncher (first-pass error corrected) |
| 10 | Weapon upgrade | s5 / $1000 (tanks 1-2), $2000 (tank 3), $5000 (tank 4) | hidden on tank1 L1-L2, tank2 L1, tank3 L1, tank4 L1 |
| 11 | Egg piece | s6; tank1 150/500/2000/3000/5000, tank2 750/3000/5000/7500/10000, tank3 1000/5000/7500/10000/15000, tank4 3000/25000/50000/75000/99999, tank5 $0 | prices by level 1-5; tank5 starts with 3 pieces |

Mode 4 overrides egg price to 5000 (tank 2), 15000 (tank 3), 25000 (tank 4); mode 1 sets it to
100. Store slots are per tank, and hidden items are `A = -1` for the listed levels. The wiki's
$99,999 egg price for tank 4 level 5 matches the binary. Demo (`manager+0x880 != 0`) builds a
fuller store and runs the demo-only alien selector `FUN_00537C20` (EV-0070/EV-0072).

## 6. Virtual Tank creature notes (wiki, EV-0060)

- Minisylvester: VT price 15,000 shells; grows from mini to adult; eats carnivores as a baby and
  ultravores as an adult.
- Ball Fish: 20,000 shells; stages named whiffle / soccer / beach.
- Bilaterus Head: 10,000 shells; round and pointed variants; eats baby guppies; drops gold
  shells.
- Starcatcher: eats Stars, tosses Diamonds ($200) - matches coin kinds 4/5/0xB/0xC (EV-0047).
- Guppycruncher: eats small guppies, produces Beetles ($150) - matches kind 0x11 (EV-0047).
- Beetlemuncher: eats Beetles, produces Pearls ($500) - matches kinds 6/0xD (EV-0047).
- VT Emporium rarity: the rare trio (Bilaterus Head, Ball Fish, Minisylvester) is listed as rare
  and the binary roster roll gives each 3% (Penta 26 / Grubber 25 / Gekko 25 / Breeder 10 /
  Ultra 5 / Bi 3 / Ball 3 / Sylvester 3, EV-0056).

## 7. Pets - unlock order and bonus pets

Full index -> display binding from the `FUN_0051F770` switch (EV-0067). The award formula uses
the **completed** level (`Tank+0x3C8/+0x3CC`), `index = tank*5 - 6 + level` (EV-0076):

| Index | Display | Unlock (binary) | Wiki order |
| --- | --- | --- | --- |
| 0 | Stinky | tank1 L1 | Stinky 1-1 |
| 1 | Niko | tank1 L2 | Niko 1-2 |
| 2 | Itchy | tank1 L3 | Itchy 1-3 |
| 3 | Prego | tank1 L4 | Prego 1-4 |
| 4 | Zorf | tank1 L5 | Zorf 1-5 |
| 5 | Clyde | tank2 L1 | Clyde 2-1 |
| 6 | Vert | tank2 L2 | Vert 2-2 |
| 7 | Rufus | tank2 L3 | Rufus 2-3 |
| 8 | Meryl | tank2 L4 | Meryl 2-4 |
| 9 | Wadsworth | tank2 L5 | Wadsworth 2-5 |
| 10 | Seymour | tank3 L1 | Seymour 3-1 |
| 11 | Shrapnel | tank3 L2 | Shrapnel 3-2 |
| 12 | Gumbo | tank3 L3 | Gumbo 3-3 |
| 13 | Blip | tank3 L4 | Blip 3-4 |
| 14 | Rhubarb | tank3 L5 | Rhubarb 3-5 |
| 15 | Nimbus | tank4 L1 | Nimbus 4-1 |
| 16 | Amp | tank4 L2 | Amp 4-2 |
| 17 | Gash | tank4 L3 | Gash 4-3 |
| 18 | Angie | tank4 L4 | Angie 4-4 |
| 19 | Presto | tank5 L1 (+5000 Shells) | Presto 5-1 |
| 20 | Brinkley | bonus pet card | bonus pet |
| 21 | Nostradamus | bonus pet card | bonus pet |
| 22 | Stanley | bonus pet card | bonus pet |
| 23 | Walter | bonus pet card | bonus pet |
| 999 | Evil Alien Mastermind | tank4 L5 card (no grant) | - |

### 7.1 Per-pet binary behavior anchors (P2.7, EV-0077..EV-0104)

Class split from `FUN_00544A90`: `OtherTypePet` = 0 Stinky, 1 Niko, 5 Clyde, 7 Rufus,
0xE Rhubarb; every other pet is `FishTypePet`. Timer fields are raw 36 Hz ticks (EV-0080).
"Open" means the wiki ability has no binary body yet (see §11).

| Idx | Pet | Binary anchor | EV |
| --- | --- | --- | --- |
| 0 | Stinky | nearest coin (`FUN_004EBC80`/`FUN_004E7270`); hide counter `+0x1B4` (`FUN_004E2A20`) | EV-0081 |
| 1 | Niko | pearl timer `+0x1B4` at 1224/1440; pearl kind 0xF (`FUN_004E2A20` idx 1) | EV-0082 |
| 2 | Itchy | target `FUN_004E5FC0`; 1.0 melee (`FUN_004FE740`), sound 0xB | EV-0083 |
| 3 | Prego | birth timer `+0x224` 930/1230/2000; guppy spawn `FUN_00546EF0` | EV-0084 |
| 4 | Zorf | food timer `+0x224`=65; food kinds 1/2 (`FUN_00543280`) | EV-0085 |
| 5 | Clyde | coin collect (`FUN_004EB7C0`/`FUN_004E02D0`); no hide | EV-0086 |
| 6 | Vert | coin timer `+0x224`=216; coin kind 2 | EV-0087 |
| 7 | Rufus | bottom y=365; 2.0 melee (`FUN_004FE740`) | EV-0088 |
| 8 | Meryl | song timer `+0x224`=1400; marker `+0x220`=1300, kind 0x10, `DAT_005e89cc` | EV-0089 |
| 9 | Wadsworth | hide flag `+0x250`; hidden count `DAT_005e89d0`; `FUN_004D6250` cleanup | EV-0090 |
| 0xA | Seymour | `Tank+0x16C`: coin fall 1.5->0.8, expiry 0x14->0x82; **writer open** | EV-0091 |
| 0xB | Shrapnel | bomb timer `+0x224`=633..652; kind 0x11; flash `+0x258` | EV-0092 |
| 0xC | Gumbo | target `FUN_004E5FC0`; opposite-corner steering `FUN_004E02D0`; glow `+0x258`; **fish lure not found** | EV-0093 |
| 0xD | Blip | unlock branch `FUN_004F7AD0` (200/720) -> `FUN_005409B0(i,1)`; **overlays not found** | EV-0094 |
| 0xE | Rhubarb | bottom snap y 270 normal / 250 aliens; fish `+0x208`=50, vy -20/-30 | EV-0095 |
| 0xF | Nimbus | coin kind <8 -> +7; toss speed 1.8; sleep `+0x245` | EV-0096 |
| 0x10 | Amp | charge timer `+0x224`=3000; flags `+0x55`/`+0x7C`; **click path not found** | EV-0097 |
| 0x11 | Gash | 3.0 melee (`FUN_004FE740`); `+0x224`=1570/1520; guppy bite resets `+0x220` | EV-0098 |
| 0x12 | Angie | corpse target `Tank+0x98`; `FUN_004D5630` sets corpse `+0x190` 100->10 | EV-0099 |
| 0x13 | Presto | recharge `+0x238`=360; transform `FUN_004F89A0`; picker `FUN_0054C6F0` | EV-0100 |
| 0x14 | Brinkley | feed count `+0x240`; rewards at 15/45/135; cooldown `+0x23C` 45/108 | EV-0101 |
| 0x15 | Nostradamus | snot timer `+0x224`=300..599; kind 0x12 (`FUN_005434E0`); **sneeze not found** | EV-0102 |
| 0x16 | Stanley | shot timer `+0x224`=100; interception `FUN_004E55D0`; cooldown `+0x23C` 90/30 | EV-0103 |
| 0x17 | Walter | glove `FUN_004EF7C0`, update `FUN_004E9A60`, effect `FUN_004E0ED0`; **click/5-punch open** | EV-0104 |
| 999 | Evil Alien Mastermind | display card only; no spawn/grant (`FUN_0051F770`) | EV-0077/EV-0105 |

Pet capacity/upgrade chain: wiki says 4 pets -> 7 (Virtual Tank) -> 11 (Sandbox). Binary
`profile+0xB0` is the bonus-pet/upgrade card index (1-4 = Brinkley..Walter, 5 = "FOUR pets?!!!",
6 = "SEVEN pets at the same time!"); `profile+0xB4` is reset to 3 and Sandbox raises it to 11.
The 4/7/11 mapping is not yet bound to either field -> Q-0013.

## 8. Trophy / bonus-pet cards

- `FUN_0051CF30` (second "Congratulations!" string at 0x51D1D6) is the bonus-pet/upgrade purchase
  card keyed on `profile+0xB0`: 1-4 -> Brinkley/Nostradamus/Stanley/Walter with "You Have
  Bought" and joke text; 5 -> "FOUR pets?!!! That's INSANE!"; 6 -> "SEVEN pets at the same
  time!" plus the Virtual Tank disclaimer (EV-0071).
- `FUN_0051E280` title tooltips 5/6 are "Wow!  Nice trophy!" and the solid-gold-trophy text;
  they are title-menu tooltips, **not** the victory screen (EV-0071).
- The wiki Challenge page describes 32 stories plus a 33rd gold-trophy ending (EV-0074). No
  binary writer/reader mapping those stories onto `profile+0xB0/+0xB4` was found -> Q-0013.

## 9. Bonus Round references (wiki, EV-0074; binary EV-0068/0069/0076)

- Wiki: a bonus round after each tank except Tanks 4 and 5 in Adventure, after each individual
  stage in Bonus Adventure; shells go to the player's Shell balance for Virtual Tank purchases.
- Binary: normal Adventure runs the tank-complete sentinel at tanks 1-3 with 15/20/25 s; tank 4
  L5 goes straight to tank 5 L1; tank 5 L1 goes to the victory-gate state. Bonus Adventure uses
  the fast path on every level with 10 + level - 1 s (EV-0073/EV-0076).
- Wiki shell values: Silver 1, Gold 2, Blue Conch 5, Silver Spiral 10, Bag O' Shells 20; combos
  multiply by combo length (max 10), with caps at 500/250/125 etc. These bonus-shell item values
  are wiki-only; the binary bonus counter `Tank+0x3F4`/`+0x3F8` and payout switch are in
  EV-0069. Bind item values in P2.5/P2.11 if needed.
- Wiki: time increases slightly each round; binary `base(tank)+clamp(level)-1` covers per-tank
  and per-level growth (EV-0068/EV-0076).

## 10. Tank 5 / Cyrax / ending (wiki, EV-0074; binary EV-0067/0071)

- Wiki Tank 5: one level, the Cyrax boss battle; egg piece free; no food/laser/fish/food-chain
  upgrades; 18 pets available (Stinky..Gash); Presto unlocked (delayed from Tank 4-5); after
  defeating Cyrax with at least one pet, 5000 shells + credits (Angie revives dead pets, then
  cast/staff roll); completing Adventure unlocks Bonus Adventure.
- Binary: tank 5 store has only item 11 at price 0 and `Tank+0x43C = 3` (one purchase); boss
  type 0x15 sets the boss flags; completion advances to tank 5/L2, grants Presto (index 19) +
  5000 Shells, and opens the HatchScreen; tank5/L2 is the victory-gate state handled by
  `FUN_00517C70`/`FUN_0051E060` -> InterludeScreen (EV-0067/0071). The credits trigger is
  unresolved (Q-0016); the 5000 is granted at the Presto hatch, not at a separate Cyrax screen.
- Wiki lists six "pets survived" messages (8-12 ... 18); the tank-5 score helper prepares the
  empty-slot indices/count used by those jokes (EV-0067).

## 11. Discrepancies / open items

- Tank 5: wiki says one level; binary has the tank5/L2 victory-gate state (EV-0071). Read L2 as
  a marker, not a second played boss level until P2.11/P2.12 proves otherwise.
- Tank 5 ending: wiki says 5000 shells + credits after Cyrax; binary grants 5000 at the Presto
  hatch (index 19) and the credits caller is unfound (Q-0016).
- Pets 4/7/11 capacity vs `profile+0xB0` (1-6 bonus cards) / `profile+0xB4` (3, Sandbox 11):
  Q-0013.
- Time Trial wiki wording "5%/10%" is not yet matched to the binary 300/600 s timers and
  `money*5/100` bonus (EV-0069/EV-0073); P2.11.
- Mode 2 is unobserved (Q-0014); mode names 0/1/3/4/5 are bound by observed behavior.
- Minisylvester growth: wiki describes two mini stages + one adult; binary init is stage 1 and
  grows once to 160x160 stage 2 (EV-0056) - stage 0 likely the unused twin mini. Re-check P2.7.
- VT beetle value: binary virtual multiplier is x5 for kind 0x11; an unresolved wiki "7 shells"
  figure was noted in the first pass - re-check in P2.11.
- Kind 0x10: binary value 0 ("not handled"); no wiki item identified.
- Hostile alien classes absent from RTTI (Q-0011); alien HP values are wiki-only (P2.8).
- Egg piece commerce resolved: tank4 L5 $99,999 matches; tank5 price 0 (EV-0072). The first-pass
  discrepancy (store rebuild B[11] = 0) was mode-specific, not a conflict.
- **Niko perch:** wiki says he stays on a fixed pillar; binary spawn is generic random x/y and
  the update is the common wander (EV-0082/EV-0105). No perch field or clamp found - open.
- **Stinky target choice:** wiki says random; binary proves nearest collectible (EV-0081). The
  wiki "red after 20 s with Nimbus" cosmetic and the exact collection cooldown are also
  unresolved (EV-0106).
- **Brinkley rewards:** binary feeds 15/45/135 (star/diamond/pearl/chest) vs wiki 12/36/108
  (EV-0101). The star cadence is every 3rd feed in both; the numbers stay open.
- **Amp charge time:** binary 3000 ticks = 83.3 s vs wiki 75 s (EV-0097). Do not round to the
  wiki value; the click/electrocute body is unfound (EV-0106).
- **Nostradamus snot:** binary random 300..599 ticks (8.3..16.6 s) vs wiki fixed 15 s; the 50%
  invasion-warning sneeze and the clones have no binary body (EV-0102/EV-0106).
- **Gumbo lure:** only Gumbo's own alien targeting, opposite-corner movement and glow are proven;
  no guppy/breeder redirection exists in the traced code (EV-0093/EV-0106).
- **Blip overlays:** the instant-unlock branch is proven (200/720 ticks); hunger arrows, alien
  radar and HP meters were not found (EV-0094/EV-0106).
- **Seymour aura:** only the `Tank+0x16C` coin-effect read is proven; the writer/trigger is
  unfound, so no aura radius or stacking rule may be assumed (EV-0091/EV-0106).
- **Wadsworth shelter:** hide flag/count/position are proven; the fish size filter and the
  Challenge-Mode sleep are not (EV-0090/EV-0106).
- **Walter glove:** the glove entity, hit scan and effect fields are proven; click binding,
  five-punch counter, 10 s sleep and the untouchable-pet table remain open (EV-0104/EV-0106).
- **Virtual Tank sleep:** `FUN_004D6B70` is a generic `Tank+0x28 - Tank+0xF0 < 0x1950` test with
  a `%0x3C` random branch; the wiki "3 minutes" is not proven for Stinky specifically (EV-0106).
- **Meryl song:** the timer, note marker (kind 0x10) and `DAT_005e89cc` flag are proven; the
  guppy "three coins" reaction is inferred from the fish side and remains P2.3 follow-up
  (EV-0089).
