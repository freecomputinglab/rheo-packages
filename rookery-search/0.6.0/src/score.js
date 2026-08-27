// Scoring and ordering: the fuzzy matcher, the body matcher, the date tie-break
// and the two-tier `search`.
//
// The other half of the parity contract with the Typst side.

import { clusters, clustersCached, fold } from "./text.js";
import { evalTagQuery, parseTagQuery, positiveAtoms } from "./tagquery.js";

// Port of `split-query`. Only a LEADING `tags:` is recognised, so a note
// body containing "tags:" can never be mistaken for a filter.
export const splitQuery = (q) => {
  const s = q.replace(/^\s+/, "");
  if (!s.toLowerCase().startsWith("tags:")) return { rpn: [], text: q, repaired: [] };
  const { rpn, residual, repaired } = parseTagQuery(s.slice(5));
  return { rpn, text: residual, repaired };
};
// Port of `fuzzy-score`. `null` (Typst `none`) when the query's characters do
// not all appear in `hay` in order; otherwise an integer, higher better.
export const score = (hay, query) => {
  const h = fold(hay);
  const q = fold(query);
  if (q === "") return 0;
  // Cached on the folded HAY, fresh on the query — see `clustersCached`.
  const hc = clustersCached(h);
  const qc = clusters(q);
  let i = 0;
  let first = null;
  let prev = null;
  let points = 0;
  for (const ch of qc) {
    let found = null;
    for (let j = i; j < hc.length; j++) {
      if (hc[j] === ch) {
        found = j;
        break;
      }
    }
    if (found === null) return null;
    if (first === null) first = found;
    points += prev !== null && found === prev + 1 ? 3 : 1;
    prev = found;
    i = found + 1;
  }
  if (h.startsWith(q)) points += 10;
  else if (h.includes(q)) points += 5;
  points += Math.max(0, 5 - first);
  points += Math.max(0, 10 - (hc.length - qc.length));
  return points;
};
// Port of `body-score`: an AND match over a note's body, which here is always
// the COMPRESSED TERM STRING `#search-index` ships — that note's most
// distinctive terms, space-joined in weight order. `null` unless every
// whitespace-split query term is a substring of some term in that list, so a
// prefix query still lands (`justif` finds `justification`).
//
// The score is RANK, since position is the weight: per query term,
// `max(1, 10 - floor(rank / 4))` for the first term containing it, plus 3 when
// the query term IS one of the terms exactly. See `body-score` in `src/lib.typ`
// for the measurements and for every choice below; this is the port, not the
// record.
//
// TWO THINGS THAT WERE HERE ARE GONE. The +6 contiguous-phrase bonus, because no
// phrase survives compression. And all the cluster counting — the old earliness
// term had to re-measure `indexOf`'s UTF-16 offset through a spread to agree with
// Typst's `.clusters()`; a rank is a term INDEX, which both languages count
// identically for nothing.
//
// `toLowerCase()`, NOT `fold()`: folding turns `-`/`_` into spaces, which would
// split `rheo-context` into two query terms and lose the exact-match bonus.
// Deliberate, and mirrored in `body-score` — the compression preserves `.` and
// `-` inside a term precisely so a reader can type them.
export const bodyScore = (body, query) => {
  const h = body.toLowerCase();
  const q = query.toLowerCase();
  if (q.trim() === "") return null;
  const terms = q.split(" ").filter((t) => t !== "");
  if (terms.length === 0) return null;
  const kept = h.split(" ").filter((t) => t !== "");
  let points = 0;
  for (const term of terms) {
    let rank = null;
    for (let i = 0; i < kept.length; i++) {
      if (kept[i].includes(term)) {
        rank = i;
        break;
      }
    }
    if (rank === null) return null;
    points += Math.max(1, 10 - Math.floor(rank / 4));
    if (kept.includes(term)) points += 3;
  }
  return points;
};
// Same rule as `search-ideas`: match on the id AND the title first (tier 0),
// take the better of the two; failing that, match on the body (tier 1) via
// `bodyScore`. Every tier-0 row ranks above every tier-1 row; within a tier,
// best score first, ties broken by id so the order is stable.
//
// `row.body` MISSING IS THE WHOLE IMPLEMENTATION OF `body-search: false`, not
// merely tolerated: `#search-index(body-search: false)` omits the field, this
// reads it as `""`, and `bodyScore("", q)` is `null` for every non-empty query,
// so no row can reach tier 1 and the browser searches ids and titles only. Keep
// the `?? ""` and keep `bodyScore` returning `null` on an absent term match —
// between them they are what makes the switch need no JavaScript counterpart.
// It also covers an older island that never carried bodies at all.
// A LEADING `tags:` EXPRESSION IS EXTRACTED, NOT SCORED. The query is split once
// before the loop — the tag expression becomes a PREDICATE on each row, and the
// residual text is what the two tiers rank. `_rank`'s Typst twin does exactly
// this, in the same place and the same order, which is what `tier parity` pins.
//
// The predicate runs FIRST, ahead of every scorer, so a note the tags exclude is
// never scored at all. And it stays a predicate: no third tier, no score bonus
// for a tag hit, no perturbation of the tier/sort/limit block below. A tag says
// WHICH notes are in the corpus; the residual text says how they rank.
//
// `row.tags ?? []` for the same reason `row.body ?? ""` is there: an older
// island, or a row for a note with no tags, simply has no key — `#search-index`
// omits it rather than shipping `[]` per row.
//
// With a tag expression and NO residual text (`tags:draft` on its own), `q` is
// `""`, `score(hay, "")` is 0 for every survivor, and they all land in the name
// tier at score 0. THAT tie no longer breaks by id alone: for `q === ""` (a bare
// `""` query too) `dateCmp` below breaks it by `row.created` first, newest
// first, undated last — the JS twin of `_rank`'s date branch in `src/lib.typ`,
// which mirrors `_sort-ids` in rookery's own `src/pure.typ`. A REAL query
// (`q !== ""`) is untouched: ties there still break by id alone, exactly as
// before.
//
// `row.created` is ALREADY the zero-padded `"[year][month][day]"` stamp
// `#search-index` ships (see its comment in `src/lib.typ`) — never a raw date
// object — so lexicographic string comparison is numeric-order comparison,
// with no parsing needed here.
//
// THE KEY IS `created`, not `updated`, since 0.6.0: rookery dropped its
// `updated` field, and the island key renamed with it rather than shipping a
// name that disagreed with its contents.
const dateCmp = (a, b) => {
  if (a.created == null && b.created == null) return 0;
  if (a.created == null) return 1;
  if (b.created == null) return -1;
  return a.created < b.created ? 1 : a.created > b.created ? -1 : 0;
};
export const search = (rows, query, limit) => {
  const { rpn, text } = splitQuery(query);
  const q = text;
  const out = [];
  for (const row of rows) {
    if (rpn.length > 0 && !evalTagQuery(rpn, (row.tags ?? []).map(fold))) continue;
    const sName = score(row.name, q);
    const sText = row.text === "" ? null : score(row.text, q);
    const nameScore =
      sName === null ? sText : sText === null ? sName : Math.max(sName, sText);
    if (nameScore !== null) {
      out.push({ ...row, score: nameScore, kind: "name" });
      continue;
    }
    const bScore = bodyScore(row.body ?? "", q);
    if (bScore !== null) out.push({ ...row, score: bScore, kind: "body" });
  }
  const tier = (hit) => (hit.kind === "name" ? 0 : 1);
  out.sort(
    (a, b) =>
      tier(a) - tier(b) ||
      b.score - a.score ||
      (q === "" ? dateCmp(a, b) : 0) ||
      (a.id < b.id ? -1 : a.id > b.id ? 1 : 0),
  );
  return limit == null ? out : out.slice(0, limit);
};
