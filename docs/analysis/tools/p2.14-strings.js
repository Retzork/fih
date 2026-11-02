// P2.14 helper - dump ASCII strings with file offsets + VAs, and print windows around anchors.
// Usage: node docs/analysis/tmp/p2.14-strings.js "<anchor1>" "<anchor2>" ...
const fs = require("fs");
const path = "docs/analysis/snapshots/insaniquarium-game-module.exe";
const buf = fs.readFileSync(path);

// --- PE section table -> file offset <-> VA (image base from optional header) ---
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
    vsize: buf.readUInt32LE(o + 8),
    va: buf.readUInt32LE(o + 12),
    rawSize: buf.readUInt32LE(o + 16),
    rawPtr: buf.readUInt32LE(o + 20),
  });
}
const toVA = (off) => {
  for (const s of sections)
    if (off >= s.rawPtr && off < s.rawPtr + s.rawSize)
      return imageBase + s.va + (off - s.rawPtr);
  return null;
};

// --- printable strings >= 4 chars ---
const strings = [];
let start = -1;
for (let i = 0; i <= buf.length; i++) {
  const c = i < buf.length ? buf[i] : 0;
  const printable = c >= 0x20 && c < 0x7f;
  if (printable && start < 0) start = i;
  if (!printable && start >= 0) {
    if (i - start >= 4) strings.push({ off: start, len: i - start, s: buf.toString("ascii", start, i) });
    start = -1;
  }
}

const anchors = process.argv.slice(2);
for (const a of anchors) {
  const hits = strings.filter((s) => s.s.includes(a));
  for (const h of hits) {
    console.log(`\n### anchor "${a}" -> file 0x${h.off.toString(16)} VA ${toVA(h.off)?.toString(16)} : ${h.s}`);
    const idx = strings.indexOf(h);
    for (let k = Math.max(0, idx - 6); k <= Math.min(strings.length - 1, idx + 12); k++) {
      const s = strings[k];
      const gap = k > 0 ? s.off - (strings[k - 1].off + strings[k - 1].len) : 0;
      console.log(`  ${k === idx ? "*" : " "} 0x${s.off.toString(16)} VA ${(toVA(s.off) || 0).toString(16)} gap=${gap} ${JSON.stringify(s.s)}`);
    }
  }
}
