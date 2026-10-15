# Evidence ledger (append-only)

Every behavioral claim in this project must trace to an entry here. Never edit or delete past
entries - correct them with a new entry that references the old ID.

## Entry format

```
### EV-NNNN - <one-line claim>
- Date: YYYY-MM-DD
- Type: observation | inference | unknown
- Source: exact command / file / address range (+ REA Evidence ID if any)
- Raw: relative path under docs/evidence/ or docs/analysis/ (if exported)
- Confidence: high | medium | low
- Notes: boundaries of the search, what this does NOT establish
```

Rules: an inference must name the observations it is derived from. An unknown must say what was
searched. Static analysis never proves runtime behavior; mark runtime-dependent claims accordingly.

---

### EV-0001 - Main game executables are byte-identical
- Date: 2026-10-15
- Type: observation
- Source: `Get-FileHash` on both files (see TARGET.md table)
- Confidence: high
- Notes: `Insaniquarium.exe` and `InsaniquariumDeluxe.exe` share SHA-256
  `f54c2c6e...a3ff66`. Analysis of either covers both.

### EV-0002 - Game version is 1.1
- Date: 2026-10-15
- Type: observation
- Source: `readme.html` ("Version 1.1"), `crash.txt` ("Product: Insaniquarium / Version: 1.1")
- Confidence: high
- Notes: Version of the Steam build on disk. Does not establish which upstream build shares code.

### EV-0003 - Shipped crash.txt reports internal module name and DirectX stack
- Date: 2026-10-15
- Type: observation (historical artifact)
- Source: `crash.txt` in install root
- Confidence: high for file contents; the crash itself is not attributed to a current run
- Notes: internal module `popcapgame1.exe`; guard page violation at `004402E0`; Windows NT 6.2
  Build 9200; DDraw/DSound. The internal name is useful for string searches (PopCap build wrapper).

### EV-0004 - Steam build ships loose assets, not pak archives
- Date: 2026-10-15
- Type: observation
- Source: full recursive file listing of the install root
- Confidence: high
- Notes: `images\` (gif/jpg), `sounds\` (ogg/au), `music\` (mo3), `properties\resources.xml`.
  No `.pak`/`.dat` archives observed at any depth. Does not establish that the original retail
  distribution used the same layout.

### EV-0005 - Unexplained per-frame PNG inside images folder
- Date: 2026-10-15
- Type: unknown (origin), observation (existence)
- Source: file listing: `images\guppy_swim1.gif.frames.png` (10,009 bytes)
- Confidence: high that it exists; origin unknown
- Notes: only one `.frames.png` file exists. Could be a shipped quirk or a leftover from an asset
  tool run on this copy. Verify against a fresh Steam install later (Q-0003).

### EV-0006 - bass.dll indicates BASS audio engine usage
- Date: 2026-10-15
- Type: inference from observation
- Source: file listing: `bass.dll` (92,728 bytes) at install root
- Confidence: medium until imports confirm linking
- Notes: To confirm, check `Insaniquarium.exe` imports for `BASS.dll` functions (Phase 1, P1.4).
  Affects how audio behavior maps to Godot (sample formats, stream handling).

### EV-0007 - Secondary local copy's exe and bass.dll are byte-identical to the canonical install
- Date: 2026-10-15
- Type: observation
- Source: `Get-FileHash` (SHA-256) on `C:\Users\Fauzi\Documents\project\Insaniquarium Deluxe\Insaniquarium.exe`
  and `...\bass.dll`
- Confidence: high
- Notes: exe = `f54c2c6e...a3ff66`, bass.dll = `d98cd5d6...61c01` - both match the canonical
  Steam install (TARGET.md). The local copy carries repack wrapper files (revLoader.exe, rev.ini,
  extra Steam client DLLs) but its game binary matches the canonical build. This does NOT establish
  that the remaining asset files in that copy match Steam; only these two files were hashed.
