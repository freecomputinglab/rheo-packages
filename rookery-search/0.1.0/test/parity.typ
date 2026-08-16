// The parity fixture. `test/parity.mjs` reads this via `typst eval` and diffs
// every score against `score` in `src/rookery-search.js`. Not shipped: the
// release archive tars `dist/`, which vite builds from `src/` alone.
#import "/src/lib.typ": fuzzy-score
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
