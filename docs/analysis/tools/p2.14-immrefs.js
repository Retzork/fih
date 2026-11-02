// P2.14 helper - find immediate references to a VA (string or vtable) inside .text, engine-free.
// Reports the raw 4-byte hits with 6 bytes of leading context and a decode hint.
// Usage: node docs/analysis/tmp/p2.14-immrefs.js 0x5CC6E4 "BASS_Init" ...
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
const toVA = (off) => {
  for (const s of sections)
    if (off >= s.rawPtr && off < s.rawPtr + s.rawSize) return imageBase + s.va + (off - s.rawPtr);
  return 0;
};
const strVA = (needle) => {
  const idx = buf.indexOf(Buffer.from(needle, "ascii"));
  return idx < 0 ? null : toVA(idx);
};

function hitsTo(va) {
  const out = [];
  const imm = Buffer.alloc(4); imm.writeUInt32LE(va);
  for (let i = tStart; i < tEnd - 4; i++) {
    if (buf[i] !== imm[0] || buf[i + 1] !== imm[1] || buf[i + 2] !== imm[2] || buf[i + 3] !== imm[3]) continue;
    const ctx = buf.subarray(Math.max(0, i - 6), i);
    // decode the instruction that owns this immediate
    let decode = "raw";
    const b2 = buf[i - 2], b1 = buf[i - 1];
    if (b1 === 0x68) decode = "push imm32";
    else if (b1 >= 0xb8 && b1 <= 0xbf) decode = `mov ${"eax ecx edx ebx esp ebp esi edi".split(" ")[b1 - 0xb8]},imm32`;
    else if (b2 === 0xc7 && b1 < 0x80) decode = `mov [reg],imm32 (modrm ${b1.toString(16)})`;
    else if (b2 === 0xc7) decode = `mov [reg+disp8],imm32 (modrm ${b1.toString(16)})`;
    else if (b2 === 0x6a) decode = "push8";
    out.push({ at: toVA(i - 2), decode, ctx: ctx.toString("hex") });
  }
  return out;
}

const bySite = new Map();
for (const a of process.argv.slice(2)) {
  const va = a.startsWith("0x") ? parseInt(a, 16) : strVA(a);
  if (!va) { console.log(`${a}: not found`); continue; }
  const hits = hitsTo(va);
  console.log(`\n${a} @0x${va.toString(16)} -> ${hits.length} imm hit(s)`);
  for (const h of hits) {
    console.log(`   0x${h.at.toString(16)}  ${h.decode.padEnd(34)} ctx ${h.ctx}`);
    const b = bySite.get(h.at) || []; b.push(a); bySite.set(h.at, b);
  }
}
console.log("\n--- sorted sites ---");
for (const k of [...bySite.keys()].sort((x, y) => x - y)) console.log(`0x${k.toString(16)}  ${bySite.get(k).join(", ")}`);
