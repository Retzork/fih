#!/usr/bin/env bash
# P2.14 audio - batch 2: decompile the code sites found by the engine-free imm-xref scan.
# Each cold query re-imports the module in Ghidra (~3 min).
set -u
cd "$(dirname "$0")/../.." || exit 1
EXE=docs/analysis/snapshots/insaniquarium-game-module.exe
SNAP=docs/analysis/snapshots/insaniquarium-game-module.json
run() { # $1=slug  $2=address
  echo "=== $1 : $2  $(date +%H:%M:%S)"
  rea decompile "$EXE" "$2" --provider ghidra --json --snapshot "$SNAP" \
      > "docs/evidence/p2.14-decompile-$1.json" 2> "docs/evidence/p2.14-decompile-$1.err"
  echo "=== $1 exit=$? $(date +%H:%M:%S)"
  node docs/analysis/tools/p2.14-fn.js "docs/evidence/p2.14-decompile-$1.json" \
      > "docs/evidence/p2.14-decompile-$1.txt" 2>> "docs/evidence/p2.14-decompile-$1.err"
}
run 498010 0x498010   # BASS loader (loads .\bass.dll, resolves the name table)
run 550E53 0x550E53   # music selector: references all three music\*.mo3 names
run 419363 0x419363   # "Out of free sound ids" - SoundRes id allocation / play
run 483C82 0x483C82   # "Num Sounds: %d" - sound-manager inventory
run 47E2B2 0x47E2B2   # MusicVolume / SfxVolume (prefs read)
run 47EEFC 0x47EEFC   # MusicVolume / SfxVolume (prefs write)
echo "BATCH2 DONE $(date +%H:%M:%S)"
