#!/usr/bin/env bash
# P2.14 audio - batch 4: music playback wrapper, the per-mode track switch, and the sample path.
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
run 54B1A0 0x54B1A0   # the music playback wrapper every screen calls
run 54B2F0 0x54B2F0   # the per-mode / per-track switch block that calls it
run 4896B0 0x4896B0   # SexyAppBase vtable slot 0xD8 (the game's sample-play entry)
echo "BATCH4 DONE $(date +%H:%M:%S)"
