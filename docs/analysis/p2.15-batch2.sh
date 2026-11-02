#!/usr/bin/env bash
# P2.15 resource system - batch 2: the three group handlers dispatched by FUN_0050FF10.
set -u
cd "$(dirname "$0")/../.." || exit 1
EXE=docs/analysis/snapshots/insaniquarium-game-module.exe
SNAP=docs/analysis/snapshots/insaniquarium-game-module.json
run() { # $1=slug  $2=address
  echo "=== $1 : $2  $(date +%H:%M:%S)"
  rea decompile "$EXE" "$2" --provider ghidra --json --snapshot "$SNAP" \
      > "docs/evidence/p2.15-decompile-$1.json" 2> "docs/evidence/p2.15-decompile-$1.err"
  echo "=== $1 exit=$? $(date +%H:%M:%S)"
  node docs/analysis/tools/p2.14-fn.js "docs/evidence/p2.15-decompile-$1.json" \
      > "docs/evidence/p2.15-decompile-$1.txt" 2>> "docs/evidence/p2.15-decompile-$1.err"
}
run 506EA0 0x506EA0   # group "Init" handler
run 5073E0 0x5073E0   # group "LoadingThread" handler
run 50E190 0x50E190   # group "Register" handler
echo "BATCH2 DONE $(date +%H:%M:%S)"
