#!/usr/bin/env bash
# P2.14 audio - batch 7: MusicInterface slot 2 (play) and the game's music-id mapper.
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
run 498D10 0x498D10   # BassMusicInterface slot 2 - the play call FUN_0054B1A0 makes
run 54B090 0x54B090   # the game's music-id mapper called just before it
echo "BATCH7 DONE $(date +%H:%M:%S)"
