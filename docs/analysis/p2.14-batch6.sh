#!/usr/bin/env bash
# P2.14 audio - batch 6: the BASS music load/play helper behind BassMusicInterface slot 1.
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
run 49B5E0 0x49B5E0   # BASS music load/play helper (called by BassMusicInterface slot 1)
echo "BATCH6 DONE $(date +%H:%M:%S)"
