// P2.14 helper - render a `rea decompile --json` result as pseudocode text.
// normalized_result is a per-character array for some provider versions, so join it.
const fs = require("fs");
const file = process.argv[2];
const j = JSON.parse(fs.readFileSync(file, "utf8"));
const r = j.normalized_result;
let code = "";
if (typeof r === "string") code = r;
else if (Array.isArray(r)) code = r.join("");
else if (r && typeof r === "object") code = r.pseudocode || r.code || JSON.stringify(r, null, 1);
const fn = j.parameters && (j.parameters.address || j.parameters.procedure);
process.stdout.write(`/* ${fn || ""} decompile (rea/ghidra) */\n\n${code}\n`);
