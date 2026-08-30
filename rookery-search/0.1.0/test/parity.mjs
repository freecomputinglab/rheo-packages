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
import { writeFileSync, unlinkSync } from "node:fs";
import { score, bodyScore, search, splitQuery, evalTagQuery, fold } from "../src/rookery-search.js";

// `file` defaults to the hand-written fixture; the generated suite below
// points it at its own throwaway `.typ` instead, so both fixtures share one
// `typst eval` shape.
const evalMetadata = (label, file = "test/parity.typ") =>
  JSON.parse(
    execFileSync("typst", [
      "eval", "--features", "html", "--root", ".", "--format", "json",
      `query(<${label}>).first().value`, "--in", file,
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

// The `tags:` parser — the one rule here whose output is not a number, so it is
// diffed AS DATA: the RPN flattened to a string exactly as `_rpn-str` flattens
// it in `test/parity.typ`, the residual text, and one boolean per fixed tag set.
// All three, not just the verdict: a parser that agreed only on the final
// booleans could still have drifted on precedence or on where the expression
// ends.
let tagBad = 0;
const tagRows = evalMetadata("tag-parity");
// CHARACTER FOR CHARACTER `tag-sets` in `test/parity.typ`, AND IN THE SAME
// ORDER — `evals` is compared positionally, so a reordering here reads as a
// parser drift. Change one list, change the other.
const TAG_SETS = [["note"], ["note", "draft"], ["draft"], ["a", "c"], ["b", "c"], []];
// `_rpn-str`'s twin: an atom in quotes, an operator bare, joined by spaces.
const rpnStr = (rpn) =>
  rpn.map((t) => (t.t === "atom" ? `"${t.v}"` : t.v)).join(" ");
for (const row of tagRows) {
  const js = splitQuery(row.query);
  const jsRpn = rpnStr(js.rpn);
  // `fold` each tag, as the fixture does and as every real caller must:
  // `evalTagQuery`'s atoms were folded at push time and it compares folded
  // against folded.
  const jsEvals = TAG_SETS.map((s) => evalTagQuery(js.rpn, s.map(fold)));
  if (jsRpn !== row.rpn || js.text !== row.text ||
      JSON.stringify(jsEvals) !== JSON.stringify(row.evals)) {
    tagBad++;
    console.error(`MISMATCH query=${JSON.stringify(row.query)}
  typst rpn=${JSON.stringify(row.rpn)} text=${JSON.stringify(row.text)} evals=${JSON.stringify(row.evals)}
  js    rpn=${JSON.stringify(jsRpn)} text=${JSON.stringify(js.text)} evals=${JSON.stringify(jsEvals)}`);
  }
}
if (tagBad > 0) {
  console.error(`${tagBad}/${tagRows.length} cases disagree — parse-tag-query and parseTagQuery have drifted`);
  process.exit(1);
}
console.log(`tag parity OK across ${tagRows.length} cases`);

// ---- Generated fuzz suite --------------------------------------------------
//
// Everything above is a regression table: every case was added chasing a
// defect already found. The two scorers are implemented in two languages with
// two different string models — Typst's `.clusters()` (extended grapheme
// clusters) against a JS `[...str]` spread (UTF-16 code points) — and that gap
// is exactly the kind of thing a hand-written table does not think to probe.
// MEASURED (typst 0.15.1): a base character plus a combining mark
// (`"e" + "́"`) is ONE Typst cluster and TWO JS code points; a ZWJ emoji
// sequence (family: 👨‍👩‍👧‍👦) is ONE cluster and SEVEN code points; a
// variation-selector emoji (❤️) is ONE cluster and TWO code points. Every
// place `fuzzy-score`/`score` count "one character" — the match loop, the
// length-difference bonus, the near-start bonus — reads a different unit on
// each side for a haystack or query containing one of these, so this is
// where real drift is most likely to be sitting undetected.
//
// FIXED SEED, so a failure is reproducible without saving the case first —
// the whole reason for the paste-ready MISMATCH line below.
const SEED = 0xc0ffee;
function mulberry32(seed) {
  let a = seed >>> 0;
  return () => {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const rand = mulberry32(SEED);
const randInt = (lo, hi) => lo + Math.floor(rand() * (hi - lo + 1)); // inclusive
const pick = (arr) => arr[randInt(0, arr.length - 1)];

// The alphabet. ASCII words (the common case, weighted heaviest below),
// `-`/`_` joins (what `_fold` exists to collapse), combining-mark sequences
// and ZWJ/variation-selector emoji (the cluster-vs-codepoint gap above), and
// CJK words (single codepoint, single cluster, single grapheme on both sides
// — the control group that should never disagree).
const ASCII_WORDS = [
  "window", "windows", "flat", "ids", "tags", "depth", "budget", "index",
  "note", "draft", "alpha", "beta", "rheo", "context", "html", "typst",
  "script", "render", "glass", "spine", "width", "widow", "wind", "wander",
  "under", "over", "cafe", "search", "query", "score",
];
const COMBINING_BASE = ["e", "a", "o", "u", "i", "n", "c", "y"];
// Acute, grave, breve, diaeresis, cedilla, tilde — MEASURED above, each pairs
// with its base into exactly one Typst cluster.
const COMBINING_MARKS = ["́", "̀", "̆", "̈", "̧", "̃"];
const PRECOMPOSED = ["café", "naïve", "niño", "façade", "résumé", "jalapeño"];
const EMOJI_VS16 = ["❤️", "☀️", "✈️"]; // ❤️ ☀️ ✈️
const EMOJI_ZWJ = [
  "\u{1f468}‍\u{1f469}‍\u{1f467}‍\u{1f466}", // family: man, woman, girl, boy
  "\u{1f469}‍\u{1f4bb}", // woman technologist
  "\u{1f3f3}️‍\u{1f308}", // rainbow flag
];
const CJK_WORDS = [
  "窗户", "深度", "索引", "笔记", "视窗", "预算", "中文", "检索", "日本語", "ウィンドウ", "カフェ", "ノート",
];

const mixedCase = (w) =>
  [...w].map((c) => (rand() < 0.5 ? c.toUpperCase() : c.toLowerCase())).join("");

// One "term" — no raw space inside, since both scorers split on a literal
// space. Weighted toward plain ASCII (the bulk of a real hay/body) with the
// exotic kinds appearing often enough to matter.
function randomToken() {
  const kind = pick([
    "ascii", "ascii", "ascii", "ascii", "hyphen", "hyphen",
    "combining", "precomposed", "emoji-vs16", "emoji-zwj", "cjk",
  ]);
  switch (kind) {
    case "ascii": {
      const w = pick(ASCII_WORDS);
      return rand() < 0.3 ? mixedCase(w) : w;
    }
    case "hyphen":
      return `${pick(ASCII_WORDS)}${pick(["-", "_"])}${pick(ASCII_WORDS)}`;
    case "combining": {
      let s = "";
      for (let i = 0, n = randInt(1, 3); i < n; i++) s += pick(COMBINING_BASE) + pick(COMBINING_MARKS);
      return s;
    }
    case "precomposed":
      return pick(PRECOMPOSED);
    case "emoji-vs16":
      return pick(EMOJI_VS16);
    case "emoji-zwj":
      return pick(EMOJI_ZWJ);
    case "cjk":
      return pick(CJK_WORDS);
  }
}

const randomHay = () => {
  const n = randInt(2, 6);
  const parts = Array.from({ length: n }, randomToken);
  return parts.join(pick([" ", " ", " ", "-", "_", ""]));
};

// Query strategies over a hay, sliced at CODE-POINT boundaries (`[...hay]`) —
// the same unit `score()` iterates in. Slicing there rather than at cluster
// boundaries is deliberate: it is exactly what lets a substring/subsequence
// query land in the MIDDLE of a combining-mark or ZWJ sequence, which is the
// case that actually exercises the cluster-vs-codepoint gap.
const codepoints = (s) => [...s];

function substringQuery(hay) {
  const cps = codepoints(hay);
  if (cps.length === 0) return "";
  const start = randInt(0, cps.length - 1);
  const len = randInt(1, Math.min(6, cps.length - start));
  return cps.slice(start, start + len).join("");
}

function subsequenceQuery(hay) {
  const cps = codepoints(hay);
  if (cps.length === 0) return "";
  const k = randInt(1, Math.min(5, cps.length));
  const idxs = new Set();
  while (idxs.size < k) idxs.add(randInt(0, cps.length - 1));
  return [...idxs].sort((a, b) => a - b).map((i) => cps[i]).join("");
}

// A substring/subsequence, then perturbed so it is unlikely to still be a
// clean match — the "near-miss" the bead asks for, exercising the `none`/
// `null` path and the boundary around it.
function nearMissQuery(hay) {
  const cps = codepoints(rand() < 0.5 ? substringQuery(hay) : subsequenceQuery(hay));
  if (cps.length === 0) return pick(ASCII_WORDS);
  switch (pick(["drop", "insert", "swapcase", "reverse"])) {
    case "drop":
      cps.splice(randInt(0, cps.length - 1), 1);
      break;
    case "insert":
      cps.splice(randInt(0, cps.length), 0, pick(ASCII_WORDS)[0]);
      break;
    case "swapcase": {
      const i = randInt(0, cps.length - 1);
      cps[i] = cps[i] === cps[i].toUpperCase() ? cps[i].toLowerCase() : cps[i].toUpperCase();
      break;
    }
    case "reverse":
      cps.reverse();
      break;
  }
  return cps.join("");
}

function randomFuzzyCase() {
  const hay = randomHay();
  if (rand() < 0.05) return { hay, query: "" }; // the empty-query edge, scores 0 on both sides
  const query = pick([substringQuery, subsequenceQuery, nearMissQuery])(hay);
  return { hay, query };
}

// `body-score`'s body is a TERM LIST, not prose — see its comment in
// `src/lib.typ` — so a generated body is a space-joined run of the same
// token pool, and a query term is drawn from an EXACT body term, a PREFIX of
// one (substring matching), or a term absent from the body (the AND-miss
// path, `none` on both sides).
const randomBody = () => Array.from({ length: randInt(3, 10) }, randomToken).join(" ");

function randomBodyQuery(body) {
  const terms = body.split(" ").filter((t) => t !== "");
  const k = randInt(1, Math.min(3, terms.length || 1));
  const qterms = [];
  for (let i = 0; i < k; i++) {
    if (terms.length === 0) { qterms.push(pick(ASCII_WORDS)); continue; }
    switch (pick(["exact", "prefix", "miss"])) {
      case "exact":
        qterms.push(pick(terms));
        break;
      case "prefix": {
        const cps = codepoints(pick(terms));
        qterms.push(cps.slice(0, randInt(1, cps.length)).join(""));
        break;
      }
      case "miss":
        qterms.push(pick(ASCII_WORDS) + "zzqx"); // vanishingly unlikely to be a substring of any term
        break;
    }
  }
  return qterms.join(" ");
}

// Typst string-literal escaping — backslash, quote, and any control
// character (none of the alphabet above should ever produce one, but a
// mutation strategy like `insert`/`reverse` is otherwise unconstrained).
// Everything else, including every non-ASCII character in the alphabet
// above, is written straight into the UTF-8 `.typ` source with no escaping.
function typstStr(s) {
  let out = "";
  for (const ch of s) {
    if (ch === "\\") out += "\\\\";
    else if (ch === '"') out += '\\"';
    else if (ch.codePointAt(0) < 0x20) out += "\\u{" + ch.codePointAt(0).toString(16) + "}";
    else out += ch;
  }
  return `"${out}"`;
}
const typstTuple = (a, b) => `(${typstStr(a)}, ${typstStr(b)})`;

const N_FUZZY = 250;
const N_BODY = 150;
const fuzzyCases = Array.from({ length: N_FUZZY }, randomFuzzyCase);
const bodyCases = Array.from({ length: N_BODY }, () => {
  const body = randomBody();
  return { body, query: randomBodyQuery(body) };
});

// Written next to `parity.typ`, imports the same `/src/lib.typ`, evaluated
// exactly as `evalMetadata` already evaluates the hand-written fixture, then
// deleted — this file is a byproduct of one run, not a fixture to keep.
// A pid+timestamp name, not a fixed one, because another agent running
// `just parity` concurrently in this same checkout must not collide with it.
const genFile = `test/.generated-parity-${process.pid}-${Date.now()}.typ`;
const genSrc = `// AUTO-GENERATED by test/parity.mjs, seed 0x${SEED.toString(16)} — do not
// edit, do not commit. Deleted by the run that wrote it; see its comment.
#import "/src/lib.typ": body-score, fuzzy-score
#let fuzzy-cases = (
  ${fuzzyCases.map((c) => typstTuple(c.hay, c.query)).join(",\n  ")},
)
#metadata(fuzzy-cases.map(c => (
  hay: c.at(0),
  query: c.at(1),
  score: fuzzy-score(c.at(0), c.at(1)),
))) <generated-parity>
#let body-cases = (
  ${bodyCases.map((c) => typstTuple(c.body, c.query)).join(",\n  ")},
)
#metadata(body-cases.map(c => (
  body: c.at(0),
  query: c.at(1),
  score: body-score(c.at(0), c.at(1)),
))) <generated-body-parity>
`;

// `exitCode` rather than an in-place `process.exit()`: `process.exit()` skips
// pending `finally` blocks entirely (MEASURED — it left the temp file on
// disk on a mismatch, the exact leak the `finally` below exists to prevent),
// so a bad exit is deferred until after cleanup has actually run.
let exitCode = 0;
writeFileSync(genFile, genSrc, "utf8");
try {
  let genFuzzyBad = 0;
  const genFuzzyRows = evalMetadata("generated-parity", genFile);
  for (const row of genFuzzyRows) {
    const js = score(row.hay, row.query);
    if (js !== row.score) {
      genFuzzyBad++;
      console.error(
        `GENERATED MISMATCH hay=${JSON.stringify(row.hay)} query=${JSON.stringify(row.query)} typst=${row.score} js=${js}\n` +
          `  paste into parity.typ's \`cases\`: ${typstTuple(row.hay, row.query)},`,
      );
    }
  }
  if (genFuzzyBad > 0) {
    console.error(`${genFuzzyBad}/${genFuzzyRows.length} generated fuzzy-score cases disagree — see above for paste-ready regression cases`);
    exitCode = 1;
  } else {
    console.log(`generated fuzzy parity OK across ${genFuzzyRows.length} cases (seed 0x${SEED.toString(16)})`);
  }

  let genBodyBad = 0;
  const genBodyRows = evalMetadata("generated-body-parity", genFile);
  for (const row of genBodyRows) {
    const js = bodyScore(row.body, row.query);
    if (js !== row.score) {
      genBodyBad++;
      console.error(
        `GENERATED MISMATCH body=${JSON.stringify(row.body)} query=${JSON.stringify(row.query)} typst=${row.score} js=${js}\n` +
          `  paste into parity.typ's \`body-cases\`: ${typstTuple(row.body, row.query)},`,
      );
    }
  }
  if (genBodyBad > 0) {
    console.error(`${genBodyBad}/${genBodyRows.length} generated body-score cases disagree — see above for paste-ready regression cases`);
    exitCode = 1;
  } else {
    console.log(`generated body parity OK across ${genBodyRows.length} cases (seed 0x${SEED.toString(16)})`);
  }
} finally {
  unlinkSync(genFile);
}
if (exitCode !== 0) process.exit(exitCode);
