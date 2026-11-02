// P2.15 - per-group inventory of properties\resources.xml + cross-check against the ids the
// engine's own group handlers reference statically (docs/analysis/inputs/p2.15-*-ids.txt).
const fs = require("fs");

const manifest = process.argv[2];
const idsDir = process.argv[3] || "docs/analysis/inputs";
const xml = fs.readFileSync(manifest, "utf8");

// walk the manifest keeping the current <Resources id=..> and <SetDefaults ..> in scope
const groups = [];
let cur = null;
let defaults = { path: "", idprefix: "" };
const tagRe = /<(\/?)([A-Za-z_]\w*)([^>]*?)(\/?)>/g;
let m;
const attr = (rest, n) => {
  const r = new RegExp("(^|\\s)" + n + "\\s*=\\s*(\"([^\"]*)\"|([^\\s\"/>]+))", "i");
  const mm = rest.match(r);
  return mm ? (mm[3] !== undefined ? mm[3] : mm[4]) : undefined;
};
while ((m = tagRe.exec(xml))) {
  const closing = m[1] === "/";
  const tag = m[2];
  const rest = m[3];
  if (closing) continue;
  if (tag === "Resources") {
    cur = { id: attr(rest, "id"), defaults: [], images: [], fonts: [], sounds: [] };
    groups.push(cur);
    defaults = { path: "", idprefix: "" };
  } else if (tag === "SetDefaults") {
    defaults = { path: attr(rest, "path") || "", idprefix: attr(rest, "idprefix") || "" };
    if (cur) cur.defaults.push({ ...defaults });
  } else if (cur && (tag === "Image" || tag === "Font" || tag === "Sound")) {
    const e = {
      tag,
      id: defaults.idprefix + (attr(rest, "id") || ""),
      path: (defaults.path ? defaults.path + "\\" : "") + (attr(rest, "path") || ""),
      attrs: {},
    };
    for (const k of ["cols", "rows", "anim", "framedelay", "begindelay", "enddelay",
                     "perframedelay", "framemap", "alphaimage", "alphagrid", "alphacolor",
                     "variant", "volume", "alias", "ddsurface"]) {
      const v = attr(rest, k);
      if (v !== undefined) e.attrs[k] = v;
      else if (new RegExp("(^|\\s)" + k + "(\\s|/|$)", "i").test(rest)) e.attrs[k] = true;
    }
    cur[tag === "Image" ? "images" : tag === "Font" ? "fonts" : "sounds"].push(e);
  }
}

const readIds = (f) => {
  const p = idsDir + "/" + f;
  if (!fs.existsSync(p)) return null;
  return [...fs.readFileSync(p, "utf8").matchAll(/push 0x[0-9a-f]+ "([^"]+)"/g)].map((x) => x[1]);
};

const out = [];
out.push("# P2.15 - resources.xml by group, cross-checked against the engine's own handlers");
out.push("# manifest: " + manifest);
for (const g of groups) {
  out.push("");
  out.push("## group " + g.id +
    ": images=" + g.images.length + ", fonts=" + g.fonts.length + ", sounds=" + g.sounds.length);
  out.push("   SetDefaults chain: " + g.defaults.map((d) => `path=${d.path} idprefix=${d.idprefix}`).join(" -> "));
  if (g.images.length && g.images.length < 20) out.push("   images: " + g.images.map((e) => e.id).join(", "));
  if (g.fonts.length) out.push("   fonts: " + g.fonts.map((e) => e.id).join(", "));
  if (g.sounds.length && g.sounds.length < 20) out.push("   sounds: " + g.sounds.map((e) => e.id).join(", "));
}

// handler cross-check
const lt = readIds("p2.15-loadingthread-ids.txt");
const rg = readIds("p2.15-register-ids.txt");
const all = new Map();
for (const g of groups) for (const e of [...g.images, ...g.fonts, ...g.sounds]) all.set(e.id, e);
const handlers = new Map();
if (lt) for (const id of lt) handlers.set(id, (handlers.get(id) || "") + "LoadingThread");
if (rg) for (const id of rg) handlers.set(id, (handlers.get(id) || "") + "Register");

out.push("");
out.push("## cross-check (manifest ids vs statically referenced handler ids)");
out.push("manifest ids: " + all.size + "; LoadingThread ids: " + (lt ? lt.length : "n/a") +
  "; Register ids: " + (rg ? rg.length : "n/a"));
if (lt && rg) {
  const union = new Set([...lt, ...rg]);
  const missingInHandlers = [...all.keys()].filter((id) => !union.has(id));
  const notInManifest = [...union].filter((id) => !all.has(id));
  out.push("in manifest, never referenced by a group handler (" + missingInHandlers.length + "): " +
    missingInHandlers.join(", "));
  out.push("referenced by a handler but absent from the manifest (" + notInManifest.length + "): " +
    notInManifest.join(", "));
  const dup = [...union].filter((id) => handlers.get(id) === "LoadingThreadRegister" || handlers.get(id) === "RegisterLoadingThread");
  out.push("referenced by both handlers: " + (dup.length ? dup.join(", ") : "none"));
}

// animation sanity: entries that animate but declare odd grids
out.push("");
out.push("## animated entries, as the loader will slice them");
for (const g of groups) {
  for (const e of g.images) {
    if (!e.attrs.anim) continue;
    const cols = e.attrs.cols || "1";
    const rows = e.attrs.rows || "1";
    out.push(`   ${e.id.padEnd(18)} path=${e.path.padEnd(28)} cols=${cols} rows=${rows} anim=${e.attrs.anim}` +
      (e.attrs.framemap ? ` framemap=[${e.attrs.framemap}]` : "") +
      (e.attrs.perframedelay ? ` perframedelay=[${e.attrs.perframedelay}]` : "") +
      (e.attrs.framedelay ? ` framedelay=${e.attrs.framedelay}` : "") +
      (e.attrs.begindelay ? ` begindelay=${e.attrs.begindelay}` : "") +
      (e.attrs.enddelay ? ` enddelay=${e.attrs.enddelay}` : ""));
  }
}
out.push("");
out.push("## non-animated entries that still declare a grid");
for (const g of groups) {
  for (const e of g.images) {
    if (e.attrs.anim) continue;
    if (!e.attrs.cols && !e.attrs.rows) continue;
    out.push(`   ${e.id.padEnd(18)} path=${e.path.padEnd(28)} cols=${e.attrs.cols || "1"} rows=${e.attrs.rows || "1"}` +
      (e.attrs.alphagrid ? ` alphagrid=${e.attrs.alphagrid}` : ""));
  }
}
process.stdout.write(out.join("\n") + "\n");
