// P2.15 helper - resolve absolute VAs back to ASCII strings (and numeric constants).
// Usage: node docs/analysis/tools/p2.15-vastr.js 0x5afd38 0x5c1390 ...
const fs = require("fs");
const path = "docs/analysis/snapshots/insaniquarium-game-module.exe";
const buf = fs.readFileSync(path);

const peOff = buf.readUInt32LE(0x3c);
const numSec = buf.readUInt16LE(peOff + 6);
const optSize = buf.readUInt16LE(peOff + 20);
const optOff = peOff + 24;
const magic = buf.readUInt16LE(optOff);
const imageBase = magic === 0x10b ? buf.readUInt32LE(optOff + 28) : null;
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
const toOff = (va) => {
  const rva = va - imageBase;
  for (const s of sections)
    if (rva >= s.va && rva < s.va + s.rawSize) return s.rawPtr + (rva - s.va);
  return null;
};

for (const a of process.argv.slice(2)) {
  const va = Number(a.startsWith("0x") ? a : "0x" + a);
  const off = toOff(va);
  if (off === null) {
    console.log(`${a} -> (not in a raw section)`);
    continue;
  }
  let end = off;
  while (end < buf.length && buf[end] !== 0) end++;
  const raw = buf.toString("latin1", off, Math.min(end, off + 200));
  const printable = /^[\x20-\x7e]*$/.test(raw) && raw.length > 0;
  console.log(`${a} -> ${printable ? JSON.stringify(raw) : "0x" + buf.readUInt32LE(off).toString(16) + " (non-ascii)"}`);
}
