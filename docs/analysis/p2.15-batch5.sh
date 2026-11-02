#!/usr/bin/env bash
# P2.15 resource system - batch 5: the animation builder reached from the <Image> parser
# (FUN_004166C0 ends with FUN_004575E0(animType, beginDelay, endDelay)). Settles frame order and
# what a negative framemap entry means (EV-0027 left this open in P3.5). Waits for batch 4.
set -u
cd "$(dirname "$0")/../.." || exit 1
for i in $(seq 1 900); do
  grep -q "BATCH4 DONE" docs/analysis/p2.15-batch4.log 2>/dev/null && break
  sleep 5
done
EXE=docs/analysis/snapshots/insaniquarium-game-module.exe
SNAP=docs/analysis/snapshots/insaniquarium-game-module.json
run() { # $1=slug  $2=address
  echo "=== $1 : $2  $(date +%H:%M:%S)"
  rea decompile "$EXE" "$2" --provider ghidra --json --snapshot "$SNAP" \
      > "docs/evidence/p2.15-decompile-$1.json" 2> "docs/evidence/p2.15-decompile-$1.err"
  echo "=== $1 exit=$?  $(date +%H:%M:%S)"
  node docs/analysis/tools/p2.14-fn.js "docs/evidence/p2.15-decompile-$1.json" \
      > "docs/evidence/p2.15-decompile-$1.txt" 2>> "docs/evidence/p2.15-decompile-$1.err"
}
run 4575E0 0x4575E0   # animation builder: grid slice + framemap + per-frame delays
echo "BATCH5 DONE $(date +%H:%M:%S)"
