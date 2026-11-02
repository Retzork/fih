#!/usr/bin/env bash
# P2.14 audio - batch 3: music-interface slots and the audio backend factories.
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
run 498A00 0x498A00   # BassMusicInterface slot 1 (the call the game makes with id + path)
run 498950 0x498950   # BassMusicInterface slot 0
run 4883BA 0x4883BA   # the code that constructs BassMusicInterface
run 488CE7 0x488CE7   # the code that constructs DSoundManager
run 4955D9 0x4955D9   # DSoundManager constructor
echo "BATCH3 DONE $(date +%H:%M:%S)"
