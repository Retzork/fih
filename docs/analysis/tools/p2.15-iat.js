// P2.15 helper - map PE import names to IAT VAs and find code xrefs (`FF 15`/`FF 25`) to them.
// Usage: node docs/analysis/tools/p2.15-iat.js FindFirstFileA FindNextFileA ...
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
const toVA = (off) => {
  for (const s of sections)
    if (off >= s.rawPtr && off < s.rawPtr + s.rawSize)
      return imageBase + s.va + (off - s.rawPtr);
  return null;
};
const cstr = (va) => {
  const off = toOff(va);
  if (off === null) return null;
  let end = off;
  while (buf[end] !== 0) end++;
  return buf.toString("latin1", off, end);
};

// --- import directory ---
const ddOff = optOff + (magic === 0x10b ? 96 : 112) + 1 * 8;
const importRva = buf.readUInt32LE(ddOff);
const imports = []; // { dll, name, iatVA }
let desc = toOff(imageBase + importRva);
while (desc) {
  const oft = buf.readUInt32LE(desc);
  const nameRva = buf.readUInt32LE(desc + 12);
  const ft = buf.readUInt32LE(desc + 16);
  if (!oft && !nameRva && !ft) break;
  const dll = cstr(imageBase + nameRva);
  let t = toOff(imageBase + (oft || ft));
  let i = 0;
  while (t) {
    const entry = buf.readUInt32LE(t);
    if (!entry) break;
    let name = null;
    if (!(entry & 0x80000000)) name = cstr(imageBase + entry + 2);
    imports.push({ dll, name, iatVA: imageBase + ft + i * 4 });
    t += 4;
    i++;
  }
  desc += 20;
}

const wanted = process.argv.slice(2);
const text = sections.find((s) => s.name === ".text") || sections.find((s) => s.va !== 0);
for (const w of wanted) {
  const hits = imports.filter((im) => im.name && im.name.toLowerCase() === w.toLowerCase());
  if (!hits.length) {
    console.log(`${w}: NOT IMPORTED`);
    continue;
  }
  for (const im of hits) {
    const sites = [];
    const raw = buf.subarray(text.rawPtr, text.rawPtr + Math.max(text.rawSize, 1));
    for (let i = 0; i + 5 < raw.length; i++) {
      if (raw[i] !== 0xff) continue;
      if (raw[i + 1] !== 0x15 && raw[i + 1] !== 0x25) continue;
      const target = raw.readUInt32LE(i + 2);
      if (target === im.iatVA) {
        sites.push("0x" + toVA(text.rawPtr + i).toString(16).toUpperCase());
      }
    }
    console.log(`${w} (${im.dll}) IAT 0x${im.iatVA.toString(16)} xrefs: ${sites.join(", ") || "(none)"}`);
  }
}
