#!/usr/bin/env bash
# P2.15 resource system - batch 4: manifest body / group registration, per-entry creation, the
# async load path and the typed lookups (GetImage / GetSound / GetFont).
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
run 418420 0x418420   # ResourceManifest body: <Resources id=..> groups + <SetDefaults>
run 418A0A 0x418A0A   # per-entry create/register (image path; "Failed to load image")
run 419780 0x419780   # async entry load on the loading thread
run 419E47 0x419E47   # GetImage (id -> refcounted Image, "Image resource not found")
run 41A003 0x41A003   # GetSound (id -> sound pool handle, "Sound resource not found")
run 41A13E 0x41A13E   # GetFont (id -> Font, "Font resource not found")
echo "BATCH4 DONE $(date +%H:%M:%S)"
