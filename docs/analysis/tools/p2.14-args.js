// P2.14 helper - dump the argument setup before a call site (raw bytes + naive push decode).
// Usage: node docs/analysis/tmp/p2.14-args.js 0x517322 0x51b000 ...
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
const vaToOff = (va) => text.rawPtr + (va - imageBase - text.va);
const readStr = (va) => {
  const off = (() => {
    for (const s of sections)
      if (va >= imageBase + s.va && va < imageBase + s.va + s.rawSize) return s.rawPtr + (va - imageBase - s.va);
    return null;
  })();
  if (off === null) return null;
  let s = "";
  for (let i = off; i < buf.length && buf[i] >= 0x20 && buf[i] < 0x7f && s.length < 60; i++) s += String.fromCharCode(buf[i]);
  return s.length >= 2 ? s : null;
};

for (const a of process.argv.slice(2)) {
  const va = parseInt(a, 16);
  const off = vaToOff(va);
  const start = Math.max(off - 40, text.rawPtr);
  const bytes = buf.subarray(start, off);
  const pushes = [];
  for (let i = 0; i < bytes.length; i++) {
    if (bytes[i] === 0x6a && i + 1 < bytes.length) pushes.push(`push ${bytes[i + 1] > 127 ? bytes[i + 1] - 256 : bytes[i + 1]}`);
    else if (bytes[i] === 0x68 && i + 4 < bytes.length) {
      const v = bytes.readUInt32LE(i + 1);
      const str = readStr(v);
      pushes.push(`push 0x${v.toString(16)}${str ? ` ("${str}")` : ""}`);
      i += 4;
    }
  }
  console.log(`\ncall site 0x${va.toString(16)}  (preceding bytes: ${bytes.toString("hex")})`);
  console.log(`  naive pushes (last = first arg): ${pushes.join("  |  ")}`);
}
