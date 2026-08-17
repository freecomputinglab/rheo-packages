// Pins `fuzzy-score` (src/lib.typ) and `score` (src/rookery-search.js) to the
// same numbers. Run from the package root: `just parity`.
//
// Tests the SOURCE module, not `dist/lib.js`: vite bundles and minifies, it does
// not change semantics, and testing the source means the fixture runs without a
// build. The module's auto-init is guarded on `typeof document`, so importing it
// under node wires nothing.
import { execFileSync } from "node:child_process";
import { score } from "../src/rookery-search.js";

const rows = JSON.parse(
  execFileSync("typst", [
    "eval", "--features", "html", "--root", ".", "--format", "json",
    "query(<parity>).first().value", "--in", "test/parity.typ",
  ], { encoding: "utf8" }),
);

let bad = 0;
for (const row of rows) {
  const js = score(row.hay, row.query);
  if (js !== row.score) {
    bad++;
    console.error(`MISMATCH hay=${JSON.stringify(row.hay)} query=${JSON.stringify(row.query)} typst=${row.score} js=${js}`);
  }
}
if (bad > 0) {
  console.error(`${bad}/${rows.length} cases disagree — fuzzy-score and rookery-search.js have drifted`);
  process.exit(1);
}
console.log(`parity OK across ${rows.length} cases`);
