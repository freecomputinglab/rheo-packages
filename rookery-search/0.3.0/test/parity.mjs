// Pins the Typst and JavaScript copies of the ranking rule to each other, at
// both layers: `fuzzy-score`/`body-score` against `score`/`bodyScore`, and the
// tiering rule above them — `_rank` against `search` — where a drift is silent
// (the static Typst listing and the live bar simply disagree about ordering).
// Run from the package root: `just parity`.
//
// Tests the SOURCE module, not `dist/lib.js`: vite bundles and minifies, it does
// not change semantics, and testing the source means the fixture runs without a
// build. The module's auto-init is guarded on `typeof document`, so importing it
// under node wires nothing.
import { execFileSync } from "node:child_process";
import { score, bodyScore, search } from "../src/rookery-search.js";

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

// The layer above the scorers. Compares the id SEQUENCE, not a set: which tier a
// row lands in, how tiers order against each other, how ties break and where
// `limit` cuts are all order, and order is the thing that drifts.
let tierBad = 0;
const tierRows = evalMetadata("tier-rows");
const tierCases = evalMetadata("tier-parity");
for (const c of tierCases) {
  const js = search(tierRows, c.query, c.limit ?? null);
  const jsIds = js.map((h) => h.id);
  const jsScores = js.map((h) => h.score);
  const jsKinds = js.map((h) => h.kind);
  const at = [...c.ids, ...jsIds].findIndex(
    (_, i) => c.ids[i] !== jsIds[i] || c.scores[i] !== jsScores[i] || c.kinds[i] !== jsKinds[i],
  );
  const same =
    c.ids.length === jsIds.length &&
    c.ids.every((id, i) => id === jsIds[i] && c.scores[i] === jsScores[i] && c.kinds[i] === jsKinds[i]);
  if (!same) {
    tierBad++;
    console.error(
      `MISMATCH query=${JSON.stringify(c.query)} limit=${c.limit} first differs at index ${at}\n` +
        `  typst: ${JSON.stringify(c.ids.map((id, i) => [id, c.scores[i], c.kinds[i]]))}\n` +
        `  js:    ${JSON.stringify(jsIds.map((id, i) => [id, jsScores[i], jsKinds[i]]))}`,
    );
  }
}
if (tierBad > 0) {
  console.error(`${tierBad}/${tierCases.length} cases disagree — _rank and search have drifted`);
  process.exit(1);
}
console.log(`tier parity OK across ${tierCases.length} cases`);
