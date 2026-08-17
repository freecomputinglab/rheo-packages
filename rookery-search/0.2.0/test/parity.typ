// The parity fixture. `test/parity.mjs` reads this via `typst eval` and diffs
// every score against `score` in `src/rookery-search.js`. Not shipped: the
// release archive tars `dist/`, which vite builds from `src/` alone.
#import "/src/lib.typ": fuzzy-score, body-score
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
// missing term, not a fuzzy subsequence). Consumed by the JS port's own
// parity bead, not by `test/parity.mjs` here.
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
