// Pins `fuzzy-score`/`body-score` (src/lib.typ) to `score`/`bodyScore`
// (src/rookery-search.js). Run from the package root: `just parity`.
//
// Tests the SOURCE module, not `dist/lib.js`: vite bundles and minifies, it does
// not change semantics, and testing the source means the fixture runs without a
// build. The module's auto-init is guarded on `typeof document`, so importing it
// under node wires nothing.
import { execFileSync } from "node:child_process";
import { score, bodyScore } from "../src/rookery-search.js";

const evalMetadata = (label) =>
  JSON.parse(
    execFileSync("typst", [
      "eval", "--features", "html", "--root", ".", "--format", "json",
      `query(<${label}>).first().value`, "--in", "test/parity.typ",
    ], { encoding: "utf8" }),
  );

let bad = 0;

const rows = evalMetadata("parity");
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

let bodyBad = 0;
const bodyRows = evalMetadata("body-parity");
for (const row of bodyRows) {
  const js = bodyScore(row.body, row.query);
  if (js !== row.score) {
    bodyBad++;
    console.error(`MISMATCH body=${JSON.stringify(row.body)} query=${JSON.stringify(row.query)} typst=${row.score} js=${js}`);
  }
}
if (bodyBad > 0) {
  console.error(`${bodyBad}/${bodyRows.length} cases disagree — body-score and bodyScore have drifted`);
  process.exit(1);
}
console.log(`body parity OK across ${bodyRows.length} cases`);
