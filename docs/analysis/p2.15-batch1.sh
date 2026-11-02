#!/usr/bin/env bash
# P2.15 resource system - batch 1: the manifest parser handlers, the image loader and group dispatch.
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
run 41897A 0x41897A   # root element handler: "<ResourceManifest>" / "<Resources id=..>"
run 416EF9 0x416EF9   # image element handler (alphagrid / ddsurface / alphaimage)
run 417E0A 0x417E0A   # SetDefaults handler (path / idprefix)
run 4A025F 0x4A025F   # the image loader (".gif" suffix handling)
run 50FF39 0x50FF39   # group-name dispatch (LoadingThread / Register)
echo "BATCH1 DONE $(date +%H:%M:%S)"
