// P2.14 helper - extract the startup sound table: push "SOUND_x" ... mov [global], eax.
// Every entry in the table function has the shape
//   push <name VA> / lea ecx,[ebp-x] / call <string ctor> / mov eax,[this] / mov edx,[eax+0x44]
//   push <&str> / mov ecx,<this> / mov [ebp-4],<state> / call edx / mov [<global>],eax
// This scanner reports name -> global for every such site, engine-free.
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
const vaToOff = (va) => {
  for (const s of sections)
    if (va >= imageBase + s.va && va < imageBase + s.va + s.rawSize) return s.rawPtr + (va - imageBase - s.va);
  return null;
};
const readCStr = (va) => {
  const off = vaToOff(va);
  if (off === null) return null;
  let s = "";
  for (let i = off; i < buf.length && s.length < 80; i++) {
    const c = buf[i];
    if (c < 0x20 || c > 0x7e) break;
    s += String.fromCharCode(c);
  }
  return s;
};

const rows = [];
const seen = new Set();
for (let i = tStart; i < tEnd - 5; i++) {
  if (buf[i] !== 0x68) continue; // push imm32
  const strVA = buf.readUInt32LE(i + 1);
  const name = readCStr(strVA);
  if (!name || !/^SOUND_/.test(name)) continue;
  // scan the next 96 bytes for `a3 <global>` (mov [imm32], eax) before a ret/call boundary
  for (let k = i + 5; k < Math.min(i + 96, tEnd - 5); k++) {
    if (buf[k] === 0xa3) {
      const glob = buf.readUInt32LE(k + 1);
      // skip false positives: the immediate byte 0xa3 also occurs inside call/jmp rel32 operands.
      // A real store targets the module's .data image (0x5E0000..0x600000 here).
      if (glob < 0x5e0000 || glob > 0x600000) continue;
      const key = name + "@" + glob.toString(16);
      if (!seen.has(key)) { seen.add(key); rows.push({ name, glob, at: i }); }
      break;
    }
    if (buf[k] === 0xc3) break; // ret
  }
}
console.log("# name | global (sound id storage) | store-site VA");
for (const r of rows.sort((a, b) => a.name.localeCompare(b.name)))
  console.log(`${r.name} | 0x${r.glob.toString(16)}`);
console.log(`# entries: ${rows.length}`);
