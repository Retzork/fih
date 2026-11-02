#!/usr/bin/env bash
# P2.14 audio - batch 1: literal feature traces (string + xrefs), sequential.
# Each cold query re-imports the module in Ghidra (~3 min). Results land in docs/evidence/.
set -u
cd "$(dirname "$0")/../.." || exit 1
EXE=docs/analysis/snapshots/insaniquarium-game-module.exe
SNAP=docs/analysis/snapshots/insaniquarium-game-module.json
run() { # $1=slug  $2=query
  echo "=== $1 : $2  $(date +%H:%M:%S)"
  rea trace "$EXE" "$2" --provider ghidra --json --snapshot "$SNAP" \
      > "docs/evidence/p2.14-trace-$1.json" 2> "docs/evidence/p2.14-trace-$1.err"
  echo "=== $1 exit=$? $(date +%H:%M:%S)"
}
run bassdll        'bass.dll'
run ofsfreeids     'Out of free sound ids'
run music-insaniq2 'music\Insaniq2.mo3'
run loadfail       'Failed to load sound: %s'
run bassfuncnotfound '%s function not found in bass.dll'
run numsounds      'Num Sounds: %d'
run sfxvolume      'SfxVolume'
echo "BATCH1 DONE $(date +%H:%M:%S)"
