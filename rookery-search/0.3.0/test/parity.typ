// The parity fixture. `test/parity.mjs` reads this via `typst eval` and diffs
// every score against `score` in `src/rookery-search.js`. Not shipped: the
// release archive tars `dist/`, which vite builds from `src/` alone.
#import "/src/lib.typ": _rank, body-score, fuzzy-score
#let cases = (
  ("flat-ids", "flat"), ("flat-ids", "flat ids"), ("flat-ids", "flat-ids"),
  ("windows", "window"), ("window-depth", "window"), ("windows", "windows"),
  ("Flat ids, and why", "why"), ("Flat ids, and why", "flt"),
  ("tags", "zzz"), ("tags", ""), ("Windows", "wnd"),
  ("the window depth budget, and why an index does not want it", "window"),
  ("W i n d o w s", "window"), ("ETAL", "etal"), ("etal", "ETAL"),
  ("a_b_c", "a b"), ("Café", "cafe"),
)
#metadata(cases.map(c => (
  hay: c.at(0),
  query: c.at(1),
  score: fuzzy-score(c.at(0), c.at(1)),
))) <parity>

// A second fixture for `body-score` — the AND, full-text matcher over note
// bodies. Its own labelled array, `<parity>` above kept untouched, because
// `body-score` is a different rule with a different signature (`none` on ANY
// missing term, not a fuzzy subsequence).
#let body-cases = (
  // Long prose, a multi-term query where every term is present.
  (
    "The first paragraph, with bold and raw code. A second paragraph "
      + "mentioning transclusion and windows. a list item another item",
    "transclusion windows",
  ),
  // Multi-term query where one term is present and one is not — must score
  // `none`, not a partial score.
  (
    "The first paragraph, with bold and raw code. A second paragraph "
      + "mentioning transclusion and windows. a list item another item",
    "windows zzz",
  ),
  // A contiguous phrase match, to exercise the +6 whole-phrase bonus.
  (
    "The first paragraph, with bold and raw code. A second paragraph "
      + "mentioning transclusion and windows. a list item another item",
    "raw code",
  ),
  // Non-ASCII body: a query missing only on accent (no accent folding, by
  // design — see `_fold`), so this must also score `none`.
  (
    "Café con leche is a Spanish drink, mentioned well past the two "
      + "hundred and fiftieth character mark, to make sure cluster counting "
      + "picks the right earliness bucket for a body full of accented and "
      + "other unicode text: café, café, café.",
    "cafe unicode",
  ),
  // Same non-ASCII body, this time with the accent matched — exercises
  // CLUSTER (not byte or UTF-16) counting past a multi-byte character.
  (
    "Café con leche is a Spanish drink, mentioned well past the two "
      + "hundred and fiftieth character mark, to make sure cluster counting "
      + "picks the right earliness bucket for a body full of accented and "
      + "other unicode text: café, café, café.",
    "café unicode",
  ),
  // An empty query is the name rule's business, not this one — `none`.
  ("Any note at all.", ""),
)
#metadata(body-cases.map(c => (
  body: c.at(0),
  query: c.at(1),
  score: body-score(c.at(0), c.at(1)),
))) <body-parity>

// A third fixture, for the layer ABOVE the two scorers: which tier a row lands
// in, how the tiers order against each other, how ties break, and where `limit`
// cuts. That rule is implemented twice — `_rank` here, `search` in
// `src/rookery-search.js` — and diffing only the leaf scorers left it unchecked.
//
// ORDER IS THE THING UNDER TEST, so the runner compares the id SEQUENCE, not a
// set. Rows are kept in ID ORDER because that is what `ideas()` hands `_rank`
// (see its comment): Typst leans on a stable sort for ties where JavaScript
// breaks them by id, and the two agree only for id-ordered input.
//
// Each row below exists for a boundary named in the comment beside it. `body` is
// ABSENT from one row on purpose — that missing key is the whole implementation
// of `body-search: false`, read as `""` on both sides.
#let tier-rows = (
  // Matches on TITLE only: "aaa" has no w-i-n-d-o-w subsequence.
  (id: "idea:aaa", name: "aaa", text: "Window handling", body: "prose about nothing in particular"),
  // Matches on BODY only, and carries `text: ""` — the branch that skips the
  // title score entirely rather than scoring an empty haystack.
  (id: "idea:bbb", name: "bbb", text: "", body: "win window windows, mentioned early and often"),
  // NO `body` KEY AT ALL. Must never reach the body tier, and must not error.
  (id: "idea:ccc", name: "ccc", text: ""),
  // Two rows tying on score, so the tie must break by id: ddd before eee.
  (id: "idea:ddd", name: "wnd", text: "Wnd"),
  (id: "idea:eee", name: "wnd", text: "Wnd"),
  // A WEAK name match: the query's letters appear scattered through a long
  // haystack, so its score lands BELOW a strong body-tier score. It must still
  // sort above every body row — that is the tiering rule, not a score contest.
  (id: "idea:scatter", name: "wqqiqqnqqqqqqqqqqqqqqqqqqqqqqqq", text: ""),
  // Two strong name matches that the length term separates (35 vs 40 for
  // "window") — the pair the scorer's own comment cites.
  (id: "idea:window-depth", name: "window-depth", text: "Controlling window depth"),
  (id: "idea:windows", name: "windows", text: "Windows"),
)
// Emitted for the runner too, so the JavaScript side ranks THE SAME rows rather
// than a hand-copied second corpus that could drift from this one.
#metadata(tier-rows) <tier-rows>

#let tier-cases = (
  ("window", none), // full tiering, name rows above the body row
  ("window", 2), // `limit` cutting INSIDE the name tier
  ("window", 3), // `limit` landing exactly ON the tier boundary: the one body
  // row is dropped, because the cut applies to the CONCATENATION and not per tier
  ("window", 0), // a zero limit is empty, not unlimited
  ("win", none), // body-tier score ABOVE a weak name-tier score
  ("wnd", none), // a tie, broken by id
  ("", none), // empty query: every row scores 0 in the name tier, id order
  ("zzz", none), // no match anywhere
  ("window depth", none), // multi-term: AND over the body, subsequence over names
)
#metadata(tier-cases.map(c => {
  let hits = _rank(tier-rows, c.at(0), limit: c.at(1))
  (
    query: c.at(0),
    limit: c.at(1),
    ids: hits.map(h => h.id),
    scores: hits.map(h => h.score),
    kinds: hits.map(h => h.kind),
  )
})) <tier-parity>
