#!/usr/bin/env bash
# P2.14 audio - batch 5: the startup sound table (every SOUND_* name -> a global sound id).
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
# (superseded) the startup sound table was extracted statically - see docs/analysis/inputs/p2.14-sound-table.txt
echo "BATCH5 DONE $(date +%H:%M:%S)"
