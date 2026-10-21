# GameBanana 100% save sample (2026-10-21)

Source (user-provided, read-only): `C:\Users\Fauzi\Downloads\userdata_b3b31\userdata`

This folder is a copied GameBanana save pack, kept as an **analysis sample**, not as
proof that the uploaded profile is a legitimate 100% completion. The pack contains
only `.dat` files; no executable was present or run. The files were copied unchanged.

| File | Bytes | SHA-256 |
| --- | --- | --- |
| `users.dat` | 21 | `A2E2DB3DD982BDD27A88BCC4E76FC61303C1BC8CCF60A4F98766ABC4E49AEC7D` |
| `user1.dat` | 232 | `CF3A3D7F1624904271E4BA0968B1B91127BB4E081AB44B597F33F661E31A20D1` |
| `sim1.dat` | 11800 | `C32D01A4A89C4849E40B0F7353BF14B306D8E7018F0F5CE504B21F1D30CD837D` |

The pack does **not** contain `adv1.dat`, `scr1.dat`, `highscores.dat`, or any other
slot file. Its timestamps are not used as evidence.

## What the files show

### `users.dat` - profile list

Observed bytes:

`0E 00 00 00` | `01 00` (one profile) | `05 00` (name length) | ASCII `Roman` |
`04 00 00 00` | `01 00 00 00`

- The stored name is **`Roman` (5 characters)**.
- `FUN_00513850` is the `users.dat` serializer; `FUN_00514C00` / `FUN_00514D50`
  load/save the list.
- The two trailing dwords are `4, 1`. Their meaning is unresolved. The early local
  sample has `1, 1`, so the first dword is not a constant format marker.

### `user1.dat` - profile slot

The file is exactly the layout produced by `FUN_00503730` through the save path
`FUN_00514730` (load path `FUN_005145A0`). `FUN_00503010` writes/reads a dword and
`FUN_00503070` writes/reads a byte. The observed body values are raw little-endian;
there is no whole-file encryption.

| File offset | Profile offset | Type | This sample | Early local sample | Meaning |
| --- | --- | --- | --- | --- | --- |
| `0x00` | - | dword | `0x80000000` | `0x80000000` | format marker written by the serializer |
| `0x04` | `+0x48` | dword | `9,999,999` | `200` | money (`FUN_00501530` starts at 200) |
| `0x08` | `+0x1C` | dword | `1` | `1` | tank (1-5) |
| `0x0C` | `+0x20` | dword | `1` | `1` | level (1-6; 6 = tank-complete sentinel) |
| `0x10` | `+0x59` | byte | `1` | `0` | Bonus Adventure flag (P2.6) |
| `0x11` | `+0x58` | byte | `0` | `0` | written by `FUN_00501370`; reader unknown (Q-0015) |
| `0x12` | `+0x90` | dword | `1` | `0` | unknown |
| `0x16` | `+0x94` | dword | `1` | `0` | unknown |
| `0x1A` | `+0x8C` | dword | `0` | `0` | unknown |
| `0x1E` | `+0x4C` | dword | `54` | `2` | unknown |
| `0x22` | `+0x50` | dword | `100` | `0` | tank-5 completion counter (P2.6) |
| `0x26` | `+0x54` | dword | `0` | `0` | unknown |
| `0x2A` | `+0xA0` | dword | `20,253` | `0` | unknown |
| `0x2E` | `+0x98` | dword | `0x51459CDC` | `0x02E57079` | unknown; reset assigns a generated value |
| `0x32` | `+0xB0` | dword | `6` | `0` | bonus-pet/upgrade card index 1-6 (P2.6) |
| `0x36` | `+0xB4` | dword | `24` | `3` | reset 3, Sandbox raises to 11; semantics still open (Q-0013) |
| `0x3A..0x51` | `+0x00..+0x17` | 24 bytes | all `01` | all `00` | owned-pet flags; `FUN_00501410/20` read/write them |
| `0x52..0x57` | `+0x72..+0x77` | 6 bytes | all `01` | `01 00 00 00 00 00` | six-byte block; reset sets only the first byte to 1. Do not call this the selected-pet array without further proof |
| `0x58..0x5F` | `+0xA8..+0xAF` | 8 bytes | all `00` | all `00` | unknown |
| `0x60..0x83` | `+0x78..+0x7B`, `+0x11C..+0x128`, `+0x10C..+0x118` | 4 x (byte + 2 dwords) | bytes `1,1,1,0`; dwords all `0xFFFFFFFF` except rec 3 first dword (`+0x128`) `0xFFFF01FF` | bytes `0,0,0,0`; dwords all `0xFFFFFFFF` | four records; likely Challenge records, not proven |
| `0x84` | `+0x7C` | dword | `0xFFFFFFFF` | `0` | **candidate** 32-bit story mask; reader not yet located |
| `0x88` | `+0x80` | dword | `1` | `0` | **candidate** gold-trophy/33rd-story flag; reader not yet located |
| `0x8C` | `+0x84` | dword | `2` | `2` | bitmask written by `FUN_005014D0`; load clears bit 6 |
| `0x90..0xE3` | `+0xB8..+0x10B` | 21 dwords | all `-1` except `+0x108 = 18` | all `-1` | unknown; `+0x108` is likely a count/state, not a score |
| `0xE4` | `+0x88` | dword | `0x56BD6F1A` | `0x44945926` | trailing dword; **not** a plain CRC32 of the body |

The field order is confirmed by the serializer, and the file length `0xE8` is the
sum of the serialized fields. The names in the "Meaning" column are proven only where
they point to an existing P2.6 binding; the story/trophy labels are hypotheses.

## What this sample does not prove

- It does not contain an Adventure tank save (`adv1.dat`) or Shells data (`scr1.dat`),
  so it cannot prove Adventure completion, a tank-5/credits state, or Shells values.
- The `+0x7C = 0xFFFFFFFF` / `+0x80 = 1` values match a 32-story mask plus a 33rd
  gold-trophy flag, but no instruction-level reader/writer for those fields has been
  located yet. They stay candidates under Q-0013.
- The four record bytes are `1,1,1,0`; this is not a full four-tank Challenge set.
  The GameBanana "100%" label therefore describes the upload, not verified progress.
- The pack may have been edited. Treat every value as observed data, not as the
  expected output of normal play.

## `sim1.dat`

`sim1.dat` starts with `36 00 00 00` (54), the version written by `FUN_00546990`
(SaveGame). `FUN_00546240` serializes the tank, and its first fields are tank/level;
this file reads `1, 5`. It is in the `adv`/`sim` tank-save family, but the `sim`
prefix semantics and the meaning of level `5` are not proven. It is not used as
Adventure evidence.
