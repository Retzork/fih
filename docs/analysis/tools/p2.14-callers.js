// P2.14 helper - guess the function entry at/behind an address, then list direct `call rel32` sites.
// Engine-free: rel32 calls are resolved from the image bytes only.
// Usage: node docs/analysis/tmp/p2.14-callers.js 0x550E53 [0x498010 ...]
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
const text = sections.find((s) => s.name === ".text");
const tStart = text.rawPtr, tEnd = text.rawPtr + text.rawSize;
const vaToOff = (va) => text.rawPtr + (va - imageBase - text.va);
const toVA = (off) => imageBase + text.va + (off - text.rawPtr);

function entryBefore(va) {
  let off = vaToOff(va);
  // walk back to the nearest 0xCC padding or a `55 8B EC` prologue
  for (let i = off; i > off - 0x400 && i > tStart; i--) {
    if (buf[i] === 0xcc && buf[i - 1] === 0xcc) return toVA(i + 1);
    if (buf[i] === 0x55 && buf[i + 1] === 0x8b && buf[i + 2] === 0xec) return toVA(i);
  }
  return va;
}

function callers(target) {
  const out = [];
  for (let i = tStart; i < tEnd - 5; i++) {
    if (buf[i] !== 0xe8) continue;
    const rel = buf.readInt32LE(i + 1);
    const dest = toVA(i) + 5 + rel;
    if (dest === target) out.push(toVA(i));
  }
  return out;
}

for (const a of process.argv.slice(2)) {
  const va = parseInt(a, 16);
  const entry = entryBefore(va);
  console.log(`\naddress 0x${va.toString(16)} -> guessed entry 0x${entry.toString(16)} (offset +${va - entry})`);
  const cs = callers(entry);
  console.log(`  direct call sites: ${cs.length}`);
  for (const c of cs) console.log(`    0x${c.toString(16)}`);
}
