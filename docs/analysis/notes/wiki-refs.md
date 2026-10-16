# Wiki cross-reference - internal names <-> display names

Status: living index (created 2026-10-16). Policy: D-0010. Backing evidence: EV-0060 (wiki
pass 2026-10-16) plus the binding EVs cited per row. The wiki is a **secondary source**:
behavior/constants still require binary evidence; wiki-vs-binary conflicts are listed in §7 and
stay open until resolved. All addresses are game-module VAs (D-0009).

Fetch method: raw wikitext via `https://insaniquarium.fandom.com/wiki/<Page>?action=raw` (the
normal HTML page adds nav chrome). Pages consulted 2026-10-16: Main Page, Sylvester, Balrog,
Bilaterus, Aliens, Guppycruncher, Beetlemuncher, Starcatcher, Ball Fish, Minisylvester,
Bilaterus Head, Money, Virtual Tank Mode, Time Trial Mode, Challenge Mode, Adventure Mode,
Sandbox Mode. No wiki text is saved locally (the URLs above are the record).

Naming policy: use the wiki display names in prose (notes, PLAN, specs); internal class/type
names stay the technical identifiers. Add every new binding here with its binding evidence.

## 1. Fish / store-bought creatures

| Internal (binary) | Type id | Display name (wiki) | Binding evidence |
| --- | --- | --- | --- |
| `Sexy::Fish` | 0 | Guppy | store item 0 "buy guppy" -> `FUN_00546D70` (EV-0046/0056) |
| `Sexy::Oscar` | 5 | Carnivore | store item 4 "buy carnivore" -> `FUN_00544C00` (EV-0046/0049) |
| `Sexy::Ultra` | 6 | Ultravore | store item 9 "buy ultravore" -> `FUN_00544E60` (EV-0046/0050) |
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
Open: kind 0x10 (binary value 0) identity; VT beetle value (see §7).

## 4. Game modes (`[manager+0x87C]`)

| Mode | Observed binary behavior | Wiki mode | Status |
| --- | --- | --- | --- |
| 0 | "Here are your first fish!" intro surfaces | Adventure (intro/tutorial) | medium; P2.11 |
| 1 | random-pet purchase, price doubling `2*B[11]`, timer intro (EV-0057) | Time Trial (wiki table 100 -> 200 -> ... -> 51200 -> 99999) | high binding |
| 2 | not observed | Sandbox candidate (secret code Up Up Down Down Left Right Left Right B A; $999,999 start; egg piece returns to menu) | open; P2.11 |
| 3 | store rebuild (12x CreateStoreItem, egg price 0), "end level" label, `FUN_00552230` (EV-0057) | Adventure level lifecycle | medium; P2.11 |
| 4 | price inflation via D array + reset to C on egg purchase + tank-complete unlock (EV-0057) | Challenge (wiki: inflation; "Prices have been reset!") | high binding |
| 5 | economy off (`SpendMoney` exempt), shells `Tank+0x400`, HUD coin flight (EV-0046/0047) | Virtual Tank / screensaver | high binding |

## 5. Store prices (wiki, to verify against initial A/C/D in P2.6)

| Item id | Display name | Wiki price | Binary status |
| --- | --- | --- | --- |
| 0 | Guppy | $100 | initial B[0]/C[0]/D[0] unfound (EV-0057 bounded search negative) |
| 2 | Food quality upgrade | $200 | same |
| 3 | Food quantity upgrade | $300 | same |
| 6 | Starcatcher | $750 | spawn verified (EV-0059) |
| 7 | Guppycruncher | $750 | same as above |
| 8 | Beetlemuncher | $2000 | same as above |
| 11 | Egg piece | $99,999 (tanks 4-5, wiki) | store rebuild sets B[11] = 0 (EV-0057); verify P2.6 |

Items 1 (Breeder), 4 (Carnivore), 5 (Star Potion), 9 (Ultravore), 10 (weapon upgrade): prices
not captured in the wiki pass - fetch on demand.

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

## 7. Discrepancies / open items

- Minisylvester growth: wiki describes two mini stages + one adult; binary init is stage 1 and
  grows once to 160x160 stage 2 (EV-0056) - stage 0 likely the unused twin mini. Re-check P2.7.
- VT beetle value: binary virtual multiplier is x5 for kind 0x11; an unresolved wiki "7 shells"
  figure was noted in the pass - re-check in P2.11.
- Kind 0x10: binary value 0 ("not handled"); no wiki item identified.
- Hostile alien classes absent from RTTI (Q-0011); alien HP values are wiki-only (P2.8).
- Egg piece commerce: wiki $99,999 (tanks 4-5) vs binary store rebuild B[11] = 0 (EV-0057);
  resolve in P2.6.
- Mode names (0/2/3) finalize in P2.11; the Time Trial/Challenge/Virtual Tank bindings already
  fit the observed behavior (EV-0060).
