// P2.15 - inventory the shipped properties\resources.xml (elements, attributes, per-entry flags).
// Read-only against the install copy; the parse is deliberately loose because the manifest has
// unquoted attribute values and bare boolean attributes (EV-0024).
const fs = require("fs");

const path = process.argv[2];
const xml = fs.readFileSync(path, "utf8");

const tagRe = /<([A-Za-z_]\w*)([^>]*?)\/?>/g;
const els = [];
let m;
while ((m = tagRe.exec(xml))) {
  const tag = m[1];
  const rest = m[2];
  const attr = (n) => {
    const r = new RegExp("(^|\\s)" + n + "\\s*=\\s*(\"([^\"]*)\"|([^\\s\"/>]+))", "i");
    const mm = rest.match(r);
    if (!mm) return undefined;
    return mm[3] !== undefined ? mm[3] : mm[4];
  };
  const bare = (n) => new RegExp("(^|\\s)" + n + "(\\s|/|$)", "i").test(rest);
  els.push({
    tag,
    id: attr("id"),
    path: attr("path"),
    cols: attr("cols"),
    rows: attr("rows"),
    anim: attr("anim"),
    framedelay: attr("framedelay"),
    perframedelay: attr("perframedelay"),
    begindelay: attr("begindelay"),
    framemap: attr("framemap"),
    alphaimage: attr("alphaimage"),
    alphagrid: attr("alphagrid"),
    volume: attr("volume"),
    ddsurface: bare("ddsurface"),
    alias: attr("alias"),
  });
}

const by = (k) => els.filter((e) => e[k] !== undefined && e[k] !== false);
const tags = {};
for (const e of els) tags[e.tag] = (tags[e.tag] || 0) + 1;

const out = [
  "# P2.15 - the shipped properties\\resources.xml, inventoried (2026-11-01)",
  "# source: canonical install manifest, read-only; element counts cross-check docs/analysis/resources.json (P3.1)",
  "# elements: " + Object.entries(tags).map(([k, v]) => `${k}=${v}`).join(", "),
  "# groups: " + els.filter((e) => e.tag === "Resources").map((e) => e.id).join(", "),
  "",
  "## animation attributes",
  "anim=loop (" + by("anim").filter((e) => e.anim === "loop").length + "): " +
    by("anim").filter((e) => e.anim === "loop").map((e) => e.id).join(", "),
  "anim=once (" + by("anim").filter((e) => e.anim === "once").length + "): " +
    by("anim").filter((e) => e.anim === "once").map((e) => e.id).join(", "),
  "anim=pingpong (" + by("anim").filter((e) => e.anim === "pingpong").length + "): " +
    by("anim").filter((e) => e.anim === "pingpong").map((e) => e.id).join(", "),
  // Counted from the raw text so the substring trap is avoided: `grep framedelay=` also matches
  // `perframedelay=`, which makes the shipped manifest look like it has 66 instead of 65.
  "framedelay (" + (xml.match(/(^|[\s"])framedelay\s*=/gm) || []).length + "): values " +
    [...new Set(by("framedelay").map((e) => e.framedelay))].join(","),
  "perframedelay: " + by("perframedelay").map((e) => `${e.id}=[${e.perframedelay}]`).join(", "),
  "begindelay: " + by("begindelay").map((e) => `${e.id}=${e.begindelay}`).join(", "),
  "framemap: " + by("framemap").map((e) => `${e.id}=[${e.framemap}]`).join(", "),
  "",
  "## alpha / surface attributes",
  "alphaimage (" + by("alphaimage").length + "): " +
    by("alphaimage").map((e) => `${e.id} -> ${e.alphaimage}`).join(", "),
  "alphagrid (" + by("alphagrid").length + "): " +
    by("alphagrid").map((e) => `${e.id} -> ${e.alphagrid}`).join(", "),
  "ddsurface (" + els.filter((e) => e.ddsurface).length + "): " +
    els.filter((e) => e.ddsurface).map((e) => e.id).join(", "),
  "",
  "## sound attributes",
  "volume: " + by("volume").map((e) => `${e.id}=${e.volume}`).join(", "),
  "alias: " + by("alias").map((e) => `${e.id}=${e.alias}`).join(", "),
  "",
  "## grids",
  "cols values: " + [...new Set(by("cols").map((e) => e.cols))].join(","),
  "rows values: " + [...new Set(by("rows").map((e) => e.rows))].join(","),
  "entries declaring cols: " + (xml.match(/(^|[\s"])cols\s*=/gm) || []).length +
    ", rows: " + (xml.match(/(^|[\s"])rows\s*=/gm) || []).length +
    ", animated: " + (xml.match(/(^|[\s"])anim\s*=/gm) || []).length,
];

process.stdout.write(out.join("\n") + "\n");
