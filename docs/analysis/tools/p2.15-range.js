// P2.15 helper - list string immediates referenced inside a code range (static, engine-free).
// Usage: node docs/analysis/tools/p2.15-range.js 0x41CED0 0x41D200
const fs = require("fs");
const buf = fs.readFileSync("docs/analysis/snapshots/insaniquarium-game-module.exe");
const pe = buf.readUInt32LE(0x3c), ns = buf.readUInt16LE(pe + 6), os = buf.readUInt16LE(pe + 20), oo = pe + 24;
const ib = buf.readUInt32LE(oo + 28), so = oo + os;
const secs = [];
for (let i = 0; i < ns; i++) {
  const o = so + i * 40;
  secs.push({ name: buf.toString("ascii", o, o + 8).replace(/\0+$/, ""), va: buf.readUInt32LE(o + 12), rs: buf.readUInt32LE(o + 16), rp: buf.readUInt32LE(o + 20) });
}
const toOff = (va) => { const r = va - ib; for (const s of secs) if (r >= s.va && r < s.va + s.rs) return s.rp + (r - s.va); return null; };
const cstr = (va) => { const o = toOff(va); if (o === null) return null; let e = o; while (e < buf.length && buf[e] !== 0 && e - o < 120) e++; const s = buf.toString("latin1", o, e); return /^[\x20-\x7e]+$/.test(s) ? s : null; };

const a = parseInt(process.argv[2], 16), b = parseInt(process.argv[3], 16);
for (let va = a; va < b; va++) {
  const o = toOff(va);
  if (o === null) continue;
  if (buf[o] === 0x68) {
    const v = buf.readUInt32LE(o + 1);
    if (v >= 0x590000 && v < 0x5f0000) { const s = cstr(v); if (s) console.log(`0x${va.toString(16)} push 0x${v.toString(16)} "${s}"`); }
  } else if (buf[o] >= 0xb8 && buf[o] <= 0xbf) {
    const v = buf.readUInt32LE(o + 1);
    if (v >= 0x590000 && v < 0x5f0000) { const s = cstr(v); if (s) console.log(`0x${va.toString(16)} mov imm 0x${v.toString(16)} "${s}"`); }
  }
}
