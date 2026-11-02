// P2.14 helper - dump vtable slots (and optional RTTI tag) from the PE image.
// Usage: node docs/analysis/tmp/p2.14-vtable.js 0x5C11BC 20 [0x5C1104 18 ...]
const fs = require("fs");
const path = "docs/analysis/snapshots/insaniquarium-game-module.exe";
const buf = fs.readFileSync(path);

const peOff = buf.readUInt32LE(0x3c);
const numSec = buf.readUInt16LE(peOff + 6);
const optSize = buf.readUInt16LE(peOff + 20);
const optOff = peOff + 24;
const imageBase = buf.readUInt32LE(optOff + 28);
const secOff = optOff + optSize;
const sections = [];
for (let i = 0; i < numSec; i++) {
  const o = secOff + i * 40;
  sections.push({
    name: buf.toString("ascii", o, o + 8).replace(/\0+$/, ""),
    va: buf.readUInt32LE(o + 12),
    rawSize: buf.readUInt32LE(o + 16),
    rawPtr: buf.readUInt32LE(o + 20),
  });
}
const vaToOff = (va) => {
  for (const s of sections) if (va >= imageBase + s.va && va < imageBase + s.va + s.rawSize) return s.rawPtr + (va - imageBase - s.va);
  return null;
};

const args = process.argv.slice(2);
for (let i = 0; i + 1 < args.length; i += 2) {
  const va = parseInt(args[i], 16);
  const n = parseInt(args[i + 1], 10);
  const off = vaToOff(va);
  console.log(`\n### vtable 0x${va.toString(16)} (${n} slots)`);
  if (off === null) { console.log("  not mapped"); continue; }
  const tag = buf.readUInt32LE(off - 4);
  console.log(`  [-1] rtti/col 0x${tag.toString(16)}`);
  for (let k = 0; k < n; k++) {
    const o = off + k * 4;
    if (o + 4 > buf.length) break;
    console.log(`  [${String(k).padStart(2)}] 0x${buf.readUInt32LE(o).toString(16)}`);
  }
}
