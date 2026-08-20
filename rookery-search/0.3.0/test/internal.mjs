// Bridges the module-PRIVATE helpers this suite unit-tests — `matchRanges`,
// `selection`, `extractNote` — none of which carry an `export` keyword in
// `src/rookery-search.js` (only the ranking/parity surface and `init` are
// exported; see that file's own header). `src/rookery-search.js` is left
// completely untouched: this reads its text, appends ONE throwaway
// `export {...}` statement referencing the existing top-level `const`
// bindings (legal anywhere at module top level), writes that to a temp file,
// imports it, then deletes the temp file. The real implementation is what
// gets tested — this only makes it addressable from outside the module.
//
// Modelled on `test/parity.mjs`'s own generated-fixture trick (see its
// `genFile`): write a derived throwaway file next to the real one, import
// it, clean up.
import { readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const srcPath = new URL("../src/rookery-search.js", import.meta.url);
const src = readFileSync(srcPath, "utf8");
const tmp = join(tmpdir(), `rookery-search-internal-${process.pid}-${Date.now()}.mjs`);
writeFileSync(tmp, `${src}\nexport { matchRanges, selection, extractNote };\n`, "utf8");

let mod;
try {
  mod = await import(`file://${tmp}`);
} finally {
  unlinkSync(tmp);
}

export const { matchRanges, selection, extractNote } = mod;
