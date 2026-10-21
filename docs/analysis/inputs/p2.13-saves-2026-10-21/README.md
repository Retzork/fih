# Real save-file sample (2026-10-21)

Source (read-only): `C:\ProgramData\Steam\Insaniquarium\userdata`

This is the live save folder of the installed game, **not** the game directory. The
outer Steam wrapper keeps per-user data under `ProgramData`, so searching the install
folder or the project copy does not find it. The files were copied here unchanged.

| File | Bytes | SHA-256 |
| --- | --- | --- |
| `users.dat` | 22 | `72C04ED19F737765214BC14D1202922391CE1AB484BC08CD9DF70DB2268087BE` |
| `user1.dat` | 232 | `7FB78F263F8127F224E9F4F7DF656B177ECE1266893472B6BC52CB735553B527` |
| `adv1.dat` | 1081 | `52C171140AFE19019CF85C6657BCDD387C105677829948F5FCE7A8014A4B5A44` |

Local timestamps: 2026-08-12 15:56:37 (`users.dat`), 15:57:00 (`user1.dat`,
`adv1.dat`).

## What the files show

- `users.dat` contains the profile list. Byte layout observed:
  `0E 00 00 00` | `01 00` (one profile) | `06 00` (name length) | ASCII `okokok` |
  `01 00 00 00` | `01 00 00 00`.
  The stored name is **`okokok` (6 characters)**, matching
  `HKCU\Software\PopCap\Insaniquarium\CurUser = okokok`. A search for `okokokok`
  cannot match this file.
- `adv1.dat` starts with `36 00 00 00` = 54; `FUN_00546990` (SaveGame) writes
  version dword `0x36`, so this is an Adventure tank save from the `%s%d.dat`
  family (`adv%d.dat`). The next dwords are `1, 1`, consistent with tank 1 / level 1;
  the ASCII tutorial string "Here are your first fish! Take good care of them!"
  appears at offset `0x184`. Treat the tank/level reading as an inference until the
  serializer field order is confirmed in P2.13.
- `user1.dat` has `C8 00 00 00` (200) at offset 4. The profile reset
  `FUN_00501530` writes starting money 200 at `+0x48`; this is consistent with a
  fresh profile, but the exact file-to-struct offset mapping is not yet proven.

## Consequence for P2.13 / Q-0019

- The Adventure save is `adv%d.dat`; `scr%d.dat` is a separate file used by the
  Shells persistence path (`FUN_005148C0`/`FUN_00515910`), and it does not exist for
  this profile because no Shells have been earned.
- This sample is an early Adventure save. It is useful for the file header,
  `users.dat`, and `user%d.dat` layout, but it does **not** contain a completed
  Challenge run, a trophy state, or a tank-5/credits state.
