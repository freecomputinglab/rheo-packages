// @rheo/rookery-search — fuzzy search over a rookery.
//
// Reads the corpus through `@rheo/rookery`'s public primitives and never
// touches its internals: `ideas()` for the notes, `note-href()` for links.
//
// Two layers, and the split matters:
//   - `search-ideas(query)` is pure Typst and works under plain
//     `typst compile` — build a static list of matches with no JavaScript.
//   - `search-index()` and `search-bar()` are RHEO ONLY. The bar's script is
//     injected by rheo from this manifest's `js_scripts`, and the index links
//     to minted note pages, which only rheo produces.
//
// BUILT, unlike `@rheo/rookery`: `typst.toml` points at `dist/`, and `dist/`
// comes from `just build` (vite copies this file and the CSS across and
// bundles `src/rookery-search.js` into `dist/lib.js`). Editing `src/` does
// NOT take effect until you rebuild — the one ergonomic cost of shipping JS.
#import "@rheo/rookery:0.1.0": ideas, note-href

// Lowercase, and `-`/`_` read as a space. Applied to the HAYSTACK AND THE
// QUERY, which is what makes an id findable by how a person types it: the note
// `flat-ids` matches "flat ids", and the exact string "flat-ids" still matches
// too, because both sides collapse to the same thing. Folding only the
// haystack would have broken the second case — the query's literal `-` would
// find no `-` left to match.
//
// Deliberately NOT accent-folding: MEASURED, "cafe" does not match "Café", and
// fixing that means Unicode normalisation the JavaScript port would have to
// reproduce exactly. Recorded as a known limitation in the readme instead.
#let _fold(s) = lower(s).replace("-", " ").replace("_", " ")

// Subsequence fuzzy match: `none` when `query`'s characters do not all appear
// in `hay` in order, otherwise an integer score, higher is better. An empty
// query matches everything at score 0.
//
// The score is: 1 point per matched character, 3 instead when it sits
// immediately after the previous match (a contiguous run beats a scatter);
// +10 for a prefix match, else +5 for a substring match anywhere; up to +5 for
// matching near the start; and up to +10 for the haystack being close in
// length to the query.
//
// That last term is load-bearing, not a flourish. MEASURED without it, the
// query "window" scored `windows` and `window-depth` identically at 31 — both
// are prefix matches of six contiguous characters — and the tie broke by id, so
// the near-exact match sorted BELOW the longer one. With it they are 40 and 35.
// Nothing else in the formula rewards matching a large FRACTION of the hay.
//
// Integer arithmetic throughout, deliberately: `src/rookery-search.js`
// reimplements this rule for the live bar, and integers compare exactly across
// the two languages where floats would not. `just parity` diffs them.
#let fuzzy-score(hay, query) = {
  let h = _fold(hay)
  let q = _fold(query)
  if q == "" { return 0 }
  let hc = h.clusters()
  let qc = q.clusters()
  let i = 0
  let first = none
  let prev = none
  let points = 0
  for ch in qc {
    let found = none
    let j = i
    while j < hc.len() {
      if hc.at(j) == ch { found = j; break }
      j += 1
    }
    if found == none { return none }
    if first == none { first = found }
    points += if prev != none and found == prev + 1 { 3 } else { 1 }
    prev = found
    i = found + 1
  }
  if h.starts-with(q) { points += 10 } else if h.contains(q) { points += 5 }
  points += calc.max(0, 5 - first)
  points += calc.max(0, 10 - (hc.len() - qc.len()))
  points
}

// ---- #search-ideas — fuzzy lookup over a rookery's ids and titles ---------
//
//   #context search-ideas("flt")   // -> ((id: "idea:flat-ids", .., score: 47), ..)
//
// Returns a plain ARRAY of dictionaries — every field `@rheo/rookery`'s
// `ideas()` provides (id, name, title, text, href, minted, updated) plus
// `score` — so a caller renders it however it likes. Pure Typst: no rheo
// needed, though `href` is `none` without it (nothing mints note pages), in
// which case a caller links with `#link(label(id))` instead.
//
// MATCHES ON id AND TITLE, taking the better of the two scores, because both
// are things an author remembers a note by: the id is what they type into
// `#window`, the title is what they read. The BODY is deliberately not
// searched — that is a full-text index, a different thing, and it would make
// every note match almost every query. Tags are not searched either; that is a
// deliberate deferral (rookery's records do not carry them yet — see bead
// rheo-packages-rookery-labels-dpq).
//
// ONE sort, not two: `ideas()` already returns the corpus in id order and
// Typst's sort is stable, so sorting by score alone leaves ties in id order
// and the ranking is reproducible between builds.
//
// Must be called INSIDE a `#context` block — `ideas()` reads a `state`'s
// `.final()`. It is not itself a context function, because a context function
// can only return content and the whole point here is to return data.
#let search-ideas(query, limit: none) = {
  assert(
    type(query) == str,
    message: "@rheo/rookery-search: #search-ideas' `query` must be a string — "
      + "got " + repr(query),
  )
  assert(
    limit == none or (type(limit) == int and limit >= 0),
    message: "@rheo/rookery-search: #search-ideas' `limit` must be none or a "
      + "non-negative integer — got " + repr(limit),
  )
  let out = ()
  for e in ideas() {
    let s-name = fuzzy-score(e.name, query)
    let s-text = if e.text == "" { none } else { fuzzy-score(e.text, query) }
    let score = if s-name == none {
      s-text
    } else if s-text == none { s-name } else { calc.max(s-name, s-text) }
    if score == none { continue }
    out.push((..e, score: score))
  }
  out = out.sorted(key: e => -1 * e.score)
  if limit == none { out } else { out.slice(0, calc.min(limit, out.len())) }
}
