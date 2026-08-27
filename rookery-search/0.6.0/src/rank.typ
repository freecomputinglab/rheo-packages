// The ranking rule: fuzzy scoring, body scoring, and the two tiers.
//
// `_rank` takes the rows it ranks rather than reading them, which is what lets
// `test/parity.typ` hand it the same fixtures the JavaScript gets. Every number
// here has a twin in src/rookery-search.js; change one and change the other, or
// `just parity` will say so.

#import "base.typ": *
#import "tagquery.typ": *

// ---- _rank — the tiering rule, over rows GIVEN rather than read ------------
//
// Split out of `#search-ideas` so `test/parity.typ` can run the rule on a
// literal corpus. The rule is implemented TWICE by design — here, and as
// `search` in `src/rookery-search.js` — and until this was a pure function of
// its rows, only the two LEAF scorers could be diffed: the layer that decides
// tiers, order and `limit` was duplicated and unchecked. `#search-ideas` below
// is now this, plus its asserts, plus `ideas()`.
//
// ROWS MUST ARRIVE IN ID ORDER, which is exactly what `ideas()` guarantees
// ("ordered by id so a build is reproducible"). Ties within a tier fall to
// Typst's stable sort, i.e. to the incoming order, where the JavaScript side
// breaks them by id explicitly. The two agree for id-ordered input and can
// disagree for anything else, so an arbitrarily ordered corpus is outside the
// parity guarantee — which is why the fixture keeps its rows id-ordered, and why
// this comment is here rather than a defensive sort nobody needs.
//
// THE `tags:` SPLIT LIVES HERE, not in `#search-ideas`, because `search` in
// `src/rookery-search.js` is this function's counterpart and splits in exactly
// the same place. Keeping the split inside the rule means the fixture can diff a
// TAG QUERY across the two languages as data, the same way it diffs a text one,
// and `_rank`'s signature stays `(rows, query, ...)` — passing a pre-parsed RPN
// down from `#search-ideas` would have widened it and left the parse untested.
//
// Private: the public surface is `#search-ideas`. `test/parity.typ` imports it
// by relative path, the same way it imports `fuzzy-score`.
#let _rank(rows, query, limit: none, body-search: true) = {
  // SPLIT ONCE, before the loop. A parse is cheap (about 60 microseconds,
  // MEASURED at `parse-tag-query`) but its answer cannot change between rows, so
  // parsing per row would buy nothing and cost a parse per note.
  //
  // `q` IS THE RESIDUAL TEXT, and every scorer below sees it rather than `query`
  // — otherwise a `tags:draft window` query would hand the literal "tags:draft"
  // to `fuzzy-score` and match nothing.
  //
  // THE EMPTY RESIDUAL IS NO LONGER "NO SPECIAL CASE": `fuzzy-score` still
  // returns 0 for an empty query, so every surviving note ties at score 0 in the
  // NAME tier — but a plain stable sort over that tie is no longer the wanted
  // answer. For `q == ""` (a bare `""` query, or a `tags:`-only query with no
  // residual) the DEFAULT/BROWSE listing sorts dated notes newest-first, with
  // undated notes falling to the end in their old id order. This mirrors
  // `_sort-ids` in `rookery/0.4.0/src/pure.typ` (`sort: "date"`) — same
  // dated/undated split, same zero-padded `[year][month][day]` stamp comparison,
  // same dedup-and-walk-descending — applied here to `e.updated` instead of to
  // an id's registry-looked-up `minted`. The body tier stays empty for `q == ""`
  // either way, `body-score` returning `none` for an empty query.
  let tq = split-query(query)
  let q = tq.text
  let name-hits = ()
  let body-hits = ()
  for e in rows {
    // FILTER BEFORE SCORING, never after, and as the FIRST statement in the loop.
    // Correctness first: `limit:` must apply to the FILTERED set, or a limited
    // `tags:` query spends its slots on notes the filter rejects. MEASURED in the
    // JavaScript port over a synthetic corpus with 1200-cluster bodies, it is a
    // large speedup too, because the pool the body tier walks shrinks before it is
    // walked — at 5000 notes, 15.1 ms for a bare "window depth" against 0.850 ms
    // for "tags:note&draft". A negation (`tags:!draft`) keeps most of the corpus
    // and so costs the baseline: expected, not a regression.
    //
    // A TAG MATCH IS A PREDICATE, NOT A SCORER, so `continue` is the only thing it
    // may do here. It adds no third tier and no bonus to `score`, and the tiering
    // below is therefore untouched by it: tags decide WHICH notes are candidates,
    // never how they rank.
    //
    // `e.at("tags", default: ())` rather than `e.tags`, mirroring `row.tags ?? []`
    // in the port for the same reason: this function ranks rows a CALLER supplies
    // (`test/parity.typ`'s literal corpus, not only `ideas()`), so a row with no
    // `tags` field must read as untagged rather than error. Under `ideas()` the
    // field is always there — bead tagq-ideas-tags landed it and the manifest pins
    // `@rheo/rookery:0.6.0`.
    if tq.rpn.len() > 0 and not eval-tag-query(tq.rpn, e.at("tags", default: ()).map(_fold)) {
      continue
    }
    let s-name = fuzzy-score(e.name, q)
    let s-text = if e.text == "" { none } else { fuzzy-score(e.text, q) }
    let name-score = if s-name == none {
      s-text
    } else if s-text == none { s-name } else { calc.max(s-name, s-text) }
    if name-score != none {
      name-hits.push((..e, score: name-score, kind: "name"))
      continue
    }
    if not body-search { continue }
    let body-score-val = body-score(e.at("body", default: ""), q)
    if body-score-val != none {
      body-hits.push((..e, score: body-score-val, kind: "body"))
    }
  }
  // A REAL SEARCH (`q != ""`) sorts by score, descending — untouched. THE
  // EMPTY RESIDUAL (`q == ""`) instead sorts by date, newest first, mirroring
  // `_sort-ids` in `rookery/0.4.0/src/pure.typ`: split into dated/undated
  // (each `.filter` preserves `name-hits`' existing id-ascending order within
  // its split, same as `_sort-ids`), walk the dated group's distinct stamps
  // newest to oldest, and append the undated group unchanged at the end.
  name-hits = if q != "" {
    name-hits.sorted(key: e => -1 * e.score)
  } else {
    let stamp-of(e) = {
      let u = e.at("updated", default: none)
      if u == none { none } else { u.display("[year][month][day]") }
    }
    let dated = name-hits.filter(e => stamp-of(e) != none)
    let undated = name-hits.filter(e => stamp-of(e) == none)
    let ordered = ()
    for s in dated.map(stamp-of).dedup().sorted().rev() {
      ordered += dated.filter(e => stamp-of(e) == s)
    }
    ordered + undated
  }
  body-hits = body-hits.sorted(key: e => -1 * e.score)
  let out = name-hits + body-hits
  if limit == none { out } else { out.slice(0, calc.min(limit, out.len())) }
}
