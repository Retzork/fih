#!/usr/bin/env bash
# P2.15 resource system - batch 3: the manifest element dispatcher, the loader core and the fuzzy
# file finder. Waits for batch 2 so the Ghidra queue stays serial.
set -u
cd "$(dirname "$0")/../.." || exit 1
for i in $(seq 1 600); do
  grep -q "BATCH2 DONE" docs/analysis/p2.15-batch2.log 2>/dev/null && break
  sleep 5
done
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
run 417F10 0x417F10   # group element dispatcher (Image / Sound / Font / SetDefaults / Resources)
run 419270 0x419270   # resource creation core (sound load, !ref: fonts, image/font load)
run 41CED0 0x41CED0   # directory scan + fuzzy filename resolution ("*.*")
echo "BATCH3 DONE $(date +%H:%M:%S)"
