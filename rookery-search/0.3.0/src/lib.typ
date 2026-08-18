// @rheo/rookery-search — fuzzy search over a rookery.
//
// Reads the corpus through `@rheo/rookery`'s public primitives and never
// touches its internals: `ideas()` for the notes, `note-href()` for links.
// Nothing here RENDERS a note's body — the modal's preview pane fetches the
// note's own minted page at runtime instead (see `search-modal` below), so
// this package's build cost is one pass over the registry per page rather
// than one full body render per note per page.
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
#import "@rheo/rookery:0.3.0": ideas, note-href

// ---- Target detection — a deliberate copy of rookery's ---------------------
//
// The originals are `_rheo-ctx` and `_target` in `rookery/0.3.0/src/lib.typ`,
// where they are underscore-private. They are copied rather than exported and
// imported: six lines of `sys.inputs` read, against making rookery widen its
// public surface with something no author would ever call. `sys.inputs` is
// readable from any package's scope, so the copy behaves identically.
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. `std.target()` rather than a bare `target()`, because rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope — and
// that read REQUIRES `--features html`, which every build of a project using
// this package therefore needs.
//
// Keep in step with rookery's. If that pair changes, this one changes too.
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// ---- The rookery theme — inherited, not copied ----------------------------
//
// This package's stylesheet reads rookery's own custom properties before its
// literals — `var(--rookery-search-border, var(--idea-border-color, ...))` and
// friends — so a site that themes its notes tints the search UI to match with no
// second configuration. That used to require this package to carry its own copy
// of rookery's theme table and inject it as an inline `style` on `#search-bar`'s
// span and `#search-modal`'s dialog, because neither has a `.idea-*` ancestor to
// inherit from and rookery only emitted the properties on its own containers.
//
// Rookery now ALSO publishes the configured theme once per page as a
// document-scope `<style>:root { --idea-*: ...; }</style>` rule (see the banner
// above `_THEME-KEYS`/`_theme`/`_themed` in `rookery/0.3.0/src/lib.typ`). Custom
// properties inherit down the WHOLE DOM from `:root`, so `#search-bar` and
// `#search-modal` see the theme for free with no private copy of the table and
// no state-key contract to keep in step. MEASURED 2026-08-18: `getComputedStyle`
// on both elements resolves `--idea-border-color` correctly via that inheritance
// alone, with no inline style of their own.

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

// ---- tags: query — a boolean expression over a note's tags ----------------
//
//   tags:(a|b)&c        `&` binds tighter than `|`; `()` groups
//   tags:!draft         `!` negates, binds tightest, right-associative
//   tags:draft window   an unescaped SPACE ends the tag expression; the rest
//                       ("window") is the residual text query
//   tags:a\&b           `\` escapes the next cluster into the current atom
//   tags:in-progress    atoms and tags are BOTH folded, so `-`/`_`/space agree
//
// This is the READER'S axis, typed into the bar, and it is a different thing
// from `#search-ideas`' `tags:` PARAMETER, which an author fixes at build time.
// Both narrow the corpus before a single score is computed; neither makes a tag
// into a search term (see `#search-ideas`' comment).
//
// THE ESCAPE SET IS EXACTLY `( ) | & ! \` AND IS FROZEN. A tag containing one of
// those characters must be escaped in a query, and promoting some further
// character to an operator later would silently change what queries already
// written mean. Adding to this set is a breaking change, not a feature.
//
// SHUNTING-YARD RATHER THAN RECURSIVE DESCENT, for two load-bearing reasons:
// (1) an iterative parser emits an RPN token ARRAY, which `test/parity.typ` can
// diff across the two languages AS DATA, exactly as it already diffs scores;
// (2) it needs no recursion, so a deeply nested query cannot hit Typst's
// call-depth ceiling.
//
// MEASURED (typst 0.15.1): 1000 parses plus 500 evaluations cost 61 ms in
// total, about 60 microseconds per parse — against a build that does ONE parse.
// Cheap enough that nothing here is worth caching.
//
// `src/rookery-search.js` gets the same rules for the live bar, and the two must
// agree token for token; the `<tag-parity>` fixture is what pins them. Every
// decision below is mirrored there, so change neither copy alone.

// The operator table. A DICTIONARY, not an array of operators plus a lookup:
// `c in _prec` is then a KEY test — precisely the question the tokenizer asks of
// each cluster — and the precedence it needs next is in the same structure.
#let _prec = ("!": 3, "&": 2, "|": 1)

// Parse everything after `tags:` into RPN, plus the text that followed the
// expression. `(rpn: (("atom"|"op", str), ..), residual: str, repaired: (str, ..))`.
//
// A token is a 2-TUPLE, `("atom", "draft")` / `("op", "&")`, and not a
// dictionary: JSON-comparable and cheap, and the JavaScript port uses the same
// two slots so the fixture can diff them as data.
//
// PARSING NEVER FAILS. Every malformed form repairs itself and records a reason:
// `tags:(a|` -> `["a" |]` + `unclosed-open`, `tags:)a` -> `["a"]` +
// `unmatched-close`, `tags:a&` -> `["a" &]` (a dangling operator that
// `eval-tag-query` then skips for want of operands). This is not laxity: in a
// live search box every prefix of a valid query is typed on the way to it, so
// `tags:(a|` MUST behave as `tags:a` rather than as an error. One lenient rule
// shared by both languages is also the only version of this that can be
// parity-tested — two different error paths could not be diffed. `repaired` is
// returned for a future affordance in the bar and has no consumer yet.
#let parse-tag-query(src) = {
  let cs = src.clusters()
  let out = ()
  let stack = ()
  let repaired = ()
  let atom = ""
  let residual = ""
  let i = 0
  let n = cs.len()
  let stop = false
  while i < n and not stop {
    let c = cs.at(i)
    if c == "\\" {
      // The escape takes the NEXT cluster literally into the current atom,
      // whatever it is — that is what makes a tag containing an operator
      // reachable at all. A trailing `\` has nothing to escape, so it repairs
      // rather than reading past the end.
      if i + 1 < n {
        atom += cs.at(i + 1)
        i += 1
      } else {
        repaired.push("trailing-backslash")
      }
    } else if c.trim() == "" {
      // `c.trim() == ""` is the whitespace test, not a regex. Rust's
      // `char::is_whitespace` (which Typst's `trim` uses) and JavaScript's
      // `String.trim` agree on every character either language will
      // realistically see in a search box, and each port using its OWN trim is
      // what keeps them honest. They differ on U+FEFF, which JS trims and Rust
      // does not — written up in the readme's limitations rather than pretended
      // impossible.
      //
      // `array.join()` on an EMPTY array returns `none`, not `""` (MEASURED —
      // the same gotcha recorded at `#search-index` below), and the empty slice
      // is reached by a query whose LAST cluster is the separating space
      // (`tags:draft `, typed on the way to `tags:draft window`), so the length
      // is checked here instead of handing `none` to `.trim()` at the end. The
      // spike's 19 cases never end on a bare space; this guard is the one line
      // added to its parser, and JavaScript's `slice(i + 1).join("")` yields
      // `""` unaided, so the ports still agree.
      let rest = cs.slice(i + 1)
      residual = if rest.len() == 0 { "" } else { rest.join("") }
      stop = true
    } else if c == "(" {
      if atom != "" { out.push(("atom", _fold(atom))); atom = "" }
      stack.push("(")
    } else if c == ")" {
      if atom != "" { out.push(("atom", _fold(atom))); atom = "" }
      let found = false
      while stack.len() > 0 and not found {
        let top = stack.pop()
        if top == "(" { found = true } else { out.push(("op", top)) }
      }
      if not found { repaired.push("unmatched-close") }
    } else if c in _prec {
      if atom != "" { out.push(("atom", _fold(atom))); atom = "" }
      let go = true
      while go and stack.len() > 0 {
        let top = stack.last()
        if top == "(" {
          go = false
        } else {
          // `!` at EQUAL precedence does NOT pop (the `c != "!"` below). That is
          // its right-associativity, and it is what makes `!!a` parse instead of
          // emitting a `!` with no operand under it.
          let higher = if _prec.at(top) > _prec.at(c) {
            true
          } else if _prec.at(top) == _prec.at(c) and c != "!" { true } else { false }
          if higher { out.push(("op", stack.pop())) } else { go = false }
        }
      }
      stack.push(c)
    } else {
      atom += c
    }
    i += 1
  }
  // An atom is folded WHEN PUSHED, here and at each operator boundary above, so
  // the RPN carries folded atoms and `eval-tag-query` compares folded against
  // folded. Folding at push time rather than at compare time is what the
  // JavaScript port mirrors, and it means an atom is folded exactly once.
  if atom != "" { out.push(("atom", _fold(atom))) }
  while stack.len() > 0 {
    let top = stack.pop()
    if top == "(" { repaired.push("unclosed-open") } else { out.push(("op", top)) }
  }
  (rpn: out, residual: residual.trim(), repaired: repaired)
}

// Evaluate a parsed `rpn` against ONE note's tags — `true` when the note passes
// the filter. `tags` must already be folded by the caller (`_fold` each of
// them): the RPN's atoms were folded at push time, and folding one side only
// would make `in-progress` unfindable by "in progress".
//
// AN EMPTY RPN MEANS NO FILTER, everything matches, so a bare `tags:` lists the
// whole corpus rather than nothing — the state the bar is in for one keystroke
// every time a reader starts a tag query.
//
// An atom matches a tag by PREFIX on the folded form, not exact equality, so
// `tags:note` matches `note`, `notebook` and `notes`. Deliberate: the bar and
// the modal are incremental, and exact matching shows an empty list for every
// keystroke of a tag until it is complete. The tags rendered on each result row
// are what disambiguates.
//
// The two arity guards (`st.len() > 0`, `st.len() >= 2`) are the other half of
// "parsing never fails": a dangling operator from a repaired query is SKIPPED
// for want of operands rather than crashing the build or the bar. An underflowed
// stack falls back to `true`, i.e. to no filter, which is the same answer an
// empty RPN gives.
#let eval-tag-query(rpn, tags) = {
  if rpn.len() == 0 { return true }
  let st = ()
  for tok in rpn {
    let (kind, v) = tok
    if kind == "atom" {
      st.push(tags.any(tg => tg == v or tg.starts-with(v)))
    } else if v == "!" {
      if st.len() > 0 { st.push(not st.pop()) }
    } else if st.len() >= 2 {
      let b = st.pop()
      let a = st.pop()
      st.push(if v == "&" { a and b } else { a or b })
    }
  }
  if st.len() == 0 { true } else { st.last() }
}

// Split a reader's raw query into its tag filter and its text part:
// `(rpn: (..), text: str, repaired: (..))`. This is the one entry point a UI
// needs — `parse-tag-query` and `eval-tag-query` are exported for a caller doing
// something else with the pieces.
//
// The prefix test is case-insensitive (`TAGS:note` works) but only leading
// whitespace is trimmed before it, so `tags:` must open the query: a mid-query
// `tags:` is text, matching how a person reads it. `slice(5)` is safe on byte
// offsets because `tags:` is five ASCII bytes.
//
// The non-tags branch returns `q` UNTOUCHED rather than trimmed — `fuzzy-score`
// and `body-score` fold and split their own query, so trimming here would only
// be a second place for the two languages to disagree about whitespace.
#let split-query(q) = {
  let s = q.trim(at: start)
  if lower(s).starts-with("tags:") {
    let r = parse-tag-query(s.slice(5))
    (rpn: r.rpn, text: r.residual, repaired: r.repaired)
  } else {
    (rpn: (), text: q, repaired: ())
  }
}

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

// AND match over a note's body: `none` unless every whitespace-split term in
// `query` appears as a substring of some SPACE-SEPARATED TERM of `body`,
// otherwise an integer score, higher is better. Deliberately NOT `fuzzy-score`
// — that is a subsequence matcher, good over a 40-character id and noise over a
// body, where its length term clamps to 0 for nearly everything.
//
// `body` IS A TERM LIST wherever the browser calls this. What `#search-index`
// ships is `_compress-corpus`' output: a note's most distinctive terms,
// space-joined IN WEIGHT ORDER. `#search-ideas` calls the same function on FULL
// prose (see the asymmetry documented there), where a "term" is simply a word
// and the rule degrades to word-position earliness.
//
// AND across terms — every term must appear — is what keeps a multi-word query
// from behaving like an OR and dragging in the whole corpus. Matching is by
// SUBSTRING per term, so a prefix query still lands: `justif` finds
// `justification`, `0.5` finds `0.5.1`.
//
// THE SCORE IS RANK, because in a compressed body position IS the weight (no
// weights are shipped — see `_compress-corpus`). Per query term:
// `max(1, 10 - int(rank / 4))`, where `rank` is the index of the first kept term
// containing it, plus 3 when the query term IS a kept term exactly. Summed over
// the terms. The exact-match bonus tests membership of the whole list, not
// equality with the term at `rank`, so a prefix hit high up does not cost a note
// the bonus its exact term earns further down.
//
// MEASURED in the spike: "rheo-context" scores 13 / 12 / 11 across
// `idea:26w30-rheo`, `26w28-rheo` and `26w29-rheo` purely by where the term sits
// in each note's weight order.
//
// NO PHRASE BONUS. The +6 for the whole query appearing contiguously is gone:
// no phrase survives compression, so it could never fire.
//
// NO 200-CLUSTER BUCKETS EITHER, and with them goes the last place the two
// languages could disagree about offsets — `str.position` is a byte offset,
// JavaScript's `indexOf` a UTF-16 one, and the old rule had to re-count both
// through `.clusters()` to agree. A rank is a term INDEX, which both languages
// count identically for free.
//
// `lower`, NOT `_fold`, and the difference is load-bearing: `_fold` turns `-`
// and `_` into spaces, which would split `rheo-context` — the exact token
// `_tokenize` works to preserve — into two query terms and destroy the
// exact-match +3. Little is lost, because matching is per-term substring: the
// query "flat ids" still finds the term `flat-ids`, both halves being substrings
// of it. What IS lost is the reverse, "flat-ids" typed at a body that spells it
// as two words. That trade buys exact-term scoring and is deliberate.
//
// BOTH SIDES SPLIT ON A LITERAL SPACE, not on whitespace generally, and neither
// side may be "fixed" alone. `_compress-corpus` joins with a space, so the
// browser's input never holds anything else; a full prose body reaching here from
// `#search-ideas` can hold a newline, which then sits inside a term and only
// coarsens its rank. Typst's `split(" ")` and JavaScript's `split(" ")` treat
// that identically — a whitespace regex on one side would not.
//
// Integer arithmetic throughout, same reason as `fuzzy-score`:
// `src/rookery-search.js` ports this rule for the live bar and `just parity`
// diffs the two number for number.
#let body-score(body, query) = {
  let h = lower(body)
  let q = lower(query)
  if q.trim() == "" { return none }
  let terms = q.split(" ").filter(t => t != "")
  if terms.len() == 0 { return none }
  let kept = h.split(" ").filter(t => t != "")
  let points = 0
  for term in terms {
    let rank = none
    let i = 0
    while i < kept.len() {
      if kept.at(i).contains(term) { rank = i; break }
      i += 1
    }
    if rank == none { return none }
    points += calc.max(1, 10 - int(rank / 4))
    if kept.contains(term) { points += 3 }
  }
  points
}

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
  // `_sort-ids` in `rookery/0.3.0/src/pure.typ` (`sort: "date"`) — same
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
    // `@rheo/rookery:0.3.0`.
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
  // `_sort-ids` in `rookery/0.3.0/src/pure.typ`: split into dated/undated
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

// ---- #search-ideas — fuzzy lookup over a rookery's ids, titles and bodies -
//
//   #context search-ideas("flt")   // -> ((id: "idea:flat-ids", .., score: 47, kind: "name"), ..)
//   #context search-ideas("flt", body-search: false)   // ids and titles only
//   #context search-ideas("flt", tags: "phd")          // only notes tagged phd
//   #context search-ideas("tags:(a|b)&c flt")          // a reader's tag filter
//
// Returns a plain ARRAY of dictionaries — every field `@rheo/rookery`'s
// `ideas()` provides (id, name, title, text, tags, body, href, minted, updated)
// plus `score` and `kind` — so a caller renders it however it likes. Pure
// Typst: no rheo needed, though `href` is `none` without it (nothing mints
// note pages), in which case a caller links with `#link(label(id))` instead.
//
// TWO TIERS, not one blended number. `kind: "name"` rows — matched on id or
// title, via `fuzzy-score`, taking the better of the two — always sort above
// every `kind: "body"` row — matched only on body text, via `body-score`. A
// body match and a title match are not the same KIND of evidence, and a
// reader looking for a note by name must never have it pushed below some
// other note that happens to mention the word six times; tiering says that
// plainly, where a weighted sum would only approximate it and need constant
// retuning. `kind` is what the modal's preview pane uses to decide whether to
// show a snippet.
//
// A LEADING `tags:` IN THE QUERY IS A FILTER, EXTRACTED BEFORE ANY SCORING, and
// the rest of the query is a normal text search over the survivors:
//
//   tags:draft window depth   notes tagged draft*, ranked by "window depth"
//   tags:draft                notes tagged draft*, no residual: the browse
//                              order — dated newest-first, undated by id
//   window depth              unchanged — no `tags:` prefix, no filter
//   tags:                     the whole corpus; an empty expression is no filter
//
// The grammar, in full at `parse-tag-query` above: `&` binds tighter than `|`,
// `()` groups, `!` negates and binds tightest, an unescaped SPACE ends the
// expression and opens the residual text, `\` escapes the next cluster into the
// current atom, and an atom matches a tag by PREFIX on the folded form (so
// `tags:note` also matches `notebook`). THE ESCAPE SET `( ) | & ! \` IS FROZEN —
// see `parse-tag-query`, where that and the shunting-yard choice are argued.
// Parsing never fails; a half-typed `tags:(a|` repairs to `tags:a`.
//
// A TAG STILL NEVER BECOMES A SEARCH TERM, and that is the whole shape of this.
// Ranking matches a note's id and title (and its body, when `body-search` is on)
// and nothing else, so the bare query "phd" finds the note CALLED that, not the
// notes tagged with it — only the `tags:` prefix reaches tags, and it decides
// which notes are CANDIDATES rather than how they rank. Narrowing the corpus and
// matching the query are two separate things, and this package keeps them
// separate.
//
// SO THERE ARE TWO `tags:` AXES, and they compose. The `tags:` PARAMETER below is
// the AUTHOR's, fixed at build time and handed to `ideas()`; the `tags:` PREFIX in
// the query string is the READER's, typed into the bar. Both narrow before a score
// is computed, and a query's prefix filters within whatever the parameter already
// selected.
//
// TWO SORTED PASSES CONCATENATED, not one sort on a compound key: Typst's
// `.sorted(key:)` wants a comparable key and an array key is not reliably one
// here. Each tier is filtered out, sorted by score descending, and the two are
// joined — `limit:` is applied to the concatenation, not per tier. Ties stay
// in id order either way, because `ideas()` returns id-ordered rows and
// Typst's sort is stable — that guarantee must survive within each tier.
//
// `body-search: false` DROPS THE SECOND TIER ENTIRELY — ids and titles are
// searched, note bodies are not, and no row ever comes back `kind: "body"`. For
// a rookery whose notes are looked up by name, full-text hits are noise: a
// four-word query lands on the one note that happens to mention all four words
// in passing, below the note actually called that. It is a per-project judgement
// about the corpus, so it is a parameter rather than a default this package
// picks — and `#search-index` carries it through to the browser, where it also
// stops shipping every note's body text on every page. See its comment.
//
// FULL BODIES HERE, COMPRESSED BODIES IN THE BROWSER, and the asymmetry is
// deliberate rather than an oversight. This path scores each note's WHOLE
// plain-text body — it never truncated and still does not — while
// `#search-index` ships only that note's `body-terms` most distinctive terms and
// the JavaScript matches against those. So the static Typst path stays
// EXHAUSTIVE and the browser searches a COMPRESSED index: a note findable here
// by a word the compression dropped is not findable in the bar. Making them
// agree would mean either shipping every body inline on every page (the cost
// `_compress-corpus` exists to avoid) or blinding this path for symmetry's sake,
// and neither is worth having.
//
// Parity is unaffected by that asymmetry. `body-score` and `bodyScore` are ONE
// rule, and `test/parity.typ` feeds both languages the same input — the fixture
// pins the rule, not which caller supplies prose and which supplies a term list.
//
// `tags:`/`match:` are rookery's OWN pair, passed straight through to `ideas()`
// — `tags` is `none` (the whole rookery, the default), one string, or an array
// of strings; `match` is "any" (the default) or "all". Nothing is re-filtered
// here and `tags-of` is deliberately not imported: rookery owns the predicate
// (`_tag-pred`, shared with `#window`), and one filter written twice is how two
// copies drift. It also means an excluded note is never scored, and never pays
// for its body conversion either, because `ideas()` filters before its `.map`.
//
// The rows come back CARRYING `tags` for free, in the author's own order (`()`
// when untagged): a row is `(..e, score: .., kind: ..)` over whatever `ideas()`
// returned, so every field rookery adds arrives here without this package
// naming it. Group or re-filter on that field with no second registry read.
//
// Must be called INSIDE a `#context` block — `ideas()` reads a `state`'s
// `.final()`. It is not itself a context function, because a context function
// can only return content and the whole point here is to return data.
#let search-ideas(
  query,
  limit: none,
  body-search: true,
  tags: none,
  match: "any",
) = {
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
  assert(
    type(body-search) == bool,
    message: "@rheo/rookery-search: #search-ideas' `body-search` must be a "
      + "boolean — got " + repr(body-search),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery-search: #search-ideas' `tags` must be none, a "
      + "string, or an array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery-search: #search-ideas' `match` must be \"any\" or "
      + "\"all\" — got " + repr(match),
  )
  _rank(
    ideas(tags: tags, match: match),
    query,
    limit: limit,
    body-search: body-search,
  )
}

// ---- The corpus pass — a note compressed to its most distinctive terms -----
//
// What `#search-index` puts in a row's `body`. NOT a prose prefix: that field is
// MATCH-ONLY now (the modal's preview pane fetches the note's own minted page
// rather than excerpting the island — see `#search-modal`), so its bytes are
// spent on the terms that DISTINGUISH a note instead of on whatever the note
// happened to open with.
//
// MEASURED on weeknotes.ohrg.org (56 notes): the old 1200-cluster prefix cap
// shipped 48,587 of 76,420 body chars, so 36% of the corpus prose was not
// findable in the browser AT ALL. At `body-terms: 48` and `df-ceiling: 40` the
// terms cost 18,791B and the whole island ~24,190B, against 54,610B before — 44%
// of the old cost, with whole-note coverage. 38 of the 56 notes hit the 48-term
// cap, so the budget is real and not slack.
//
// NO WEIGHTS ARE SHIPPED. Position is the weight, and `body-score` reads rank.
// MEASURED and this is why: in notes this short almost every term has tf=1, so
// the weight collapses to idf, and idf is a property of the TERM (identical
// across notes), so a digit-per-term weight string cost 11% overhead to
// distinguish only the top two or three terms. Rank carries what is left.
//
// BUILD TIME ONLY, and it stays that way: none of this is ported to JavaScript
// and none of it should be, because the browser matches against the RESULT.
// `body-score`/`bodyScore` are the only pair that needs porting.

// The stopword FLOOR — not the filter. MEASURED: the island is 15,112B with this
// list and 15,047B without it, a 0.4% difference, because the df ceiling below
// already catches nearly everything on it. It is here for a SMALL rookery, where
// too few notes exist for df to carry any signal at all.
//
// Function words only, and nothing shorter than three clusters: `_tokenize`'s
// length floor has already dropped `a`, `is`, `of`, `to`, `it` and the rest
// before this dictionary is consulted, so listing them would be dead weight.
// That is also why `im` and `id` are absent while `ive`/`wasnt`/`dont` are here —
// the contractions appear in their apostrophe-stripped form, since an apostrophe
// never survives tokenization.
//
// TYPOS ARE NOT FILTERED, deliberately: `somethign` is in the note, and a reader
// who typed the same typo should find it.
//
// A DICTIONARY, not an array, for the same reason as `_prec`: the question asked
// of every token is a key test, and `t in _stopwords` is that test, where array
// membership is a scan of a hundred strings per token.
#let _stopwords = {
  // Parenthesised, and it has to be: in Typst CODE mode a line break ends the
  // statement, so a continuation line opening with `+` is read as a unary plus
  // on a fresh expression — MEASURED, `cannot apply unary '+' to string`.
  let ws = (
    "the and but not for with was are were been being have has had "
    + "this that these those they them their there then than from into "
    + "over under out off about above below between through before after "
    + "again all any both each few more most other some such only "
    + "same too very can will just should now our you your she her "
    + "his him its who which what when where why how while because "
    + "until against among around also would could might must may here "
    + "does did nor yet whether either neither every another something "
    + "anything nothing everything though although however therefore "
    + "ive wasnt dont cant didnt isnt thats theres youre theyre ill"
  )
  let d = (:)
  for w in ws.split(" ") {
    if w != "" { d.insert(w, true) }
  }
  d
}

// One note's plain-text body to candidate terms, in FIRST-APPEARANCE order with
// duplicates KEPT — `_compress-corpus` counts them for tf.
//
// Lowercased, split on every non-alphanumeric cluster EXCEPT `.` and `-`, which
// are kept INSIDE a token. MEASURED against this corpus: `0.5.1`,
// `rheo-context`, `eco-marxist` and `marrow.typ` are exactly what a reader
// searches for, and splitting them yields `5`, `1`, `rheo`, `context` — none of
// which is the thing wanted. A LEADING `.` is kept too, so `.marrow.typ` survives
// verbatim; the dotted form then answers both queries, a dotless one still being
// a substring of it, where the stripped form answers only the dotless query. A
// TRAILING `.`/`-` is stripped, that one being sentence punctuation rather than
// part of the term (`code.` -> `code`, `well-` -> `well`). The cost of one rule
// doing both is that `word.Next` with no space after the stop reads as a single
// term; a plain-text body puts a space there.
//
// `_` IS A SPLITTER, not a token character. `.` and `-` are the two exceptions
// and the set is closed — every addition is another character a reader has to
// type exactly to match what the build kept.
//
// Dropped: tokens under 3 clusters, bare digit runs, and the stopword floor. A
// bare digit run is `^[0-9]+$` and nothing looser, so `0.5.1` and an id like
// `26w30` are NOT bare numbers and survive — they are among the most distinctive
// terms a note has.
//
// NO STEMMING, no accent folding, no language detection: documented non-goals.
// Each would be a rule the READER now has to reproduce in the search box, since
// the browser matches raw substrings against whatever the build kept.
#let _tokenize(body) = {
  let out = ()
  // Doubled backslashes: Typst rejects `\.` / `\p` as unknown STRING escapes, so
  // the regex the engine sees is `\.?[\p{L}\p{N}][\p{L}\p{N}.\-]*`.
  for m in lower(body).matches(regex("\\.?[\\p{L}\\p{N}][\\p{L}\\p{N}.\\-]*")) {
    let t = m.text
    // `str.len()` and `str.slice` are BYTE offsets, which is safe here and only
    // here: the two characters being stripped are ASCII, so `len() - 1` is always
    // a character boundary. The length FLOOR below counts clusters instead,
    // because that one is about how much of a word a reader sees.
    while t.len() > 0 and (t.ends-with(".") or t.ends-with("-")) {
      t = t.slice(0, t.len() - 1)
    }
    if t.clusters().len() < 3 { continue }
    if t.contains(regex("^[0-9]+$")) { continue }
    if t in _stopwords { continue }
    out.push(t)
  }
  out
}

// The corpus-wide pass: `bodies` in, one space-joined term string per body out,
// SAME ORDER, so the caller zips the result back onto its rows positionally.
//
// THE SIGNATURE TAKES BODIES, NEVER ROWS, and that is a build-cost decision, not
// a matter of taste. `#search-index` runs on EVERY output page, so this pass is
// called once per page. MEASURED (typst 0.15.1, 2026-08-17) with a pure function
// doing ~285 ms of dictionary work, called from one document: an empty document
// costs 42 ms, ONE call 327 ms, THIRTY calls with an IDENTICAL argument 287 ms —
// the same as one, i.e. free — and THIRTY calls with ONE ARGUMENT DIFFERING
// 6242 ms, about 21x. Typst memoises a pure call keyed on its ARGUMENTS, so this
// pass costs once per build as long as every argument is page-invariant.
//
// An `ideas()` row is NOT page-invariant: `href` is depth-relative, so a nested
// vertebra's rows differ from a top-level page's. Hand this the whole rows array
// and every page is a cache miss — the 6242 ms column. `id` and `body` are the
// stable fields; `bodies` is the projection of the only one this needs. DO NOT
// "simplify" it back to taking rows: nothing fails, no test goes red, the build
// time is silently multiplied by the page count. That is exactly how bead
// rheo-packages-ngx was missed.
#let _compress-corpus(bodies, body-terms: 48, df-ceiling: 40) = {
  let n = bodies.len()
  let toks = bodies.map(_tokenize)

  // Document frequency: how many NOTES hold the term, counted once per note, not
  // once per occurrence — a `seen` set per note is what makes it a document
  // frequency rather than a corpus term count.
  let df = (:)
  for ts in toks {
    let seen = (:)
    for t in ts {
      if t in seen { continue }
      seen.insert(t, true)
      df.insert(t, df.at(t, default: 0) + 1)
    }
  }

  toks.map(ts => {
    // tf per term, and `order` in first-appearance order — the tie-break below
    // rides on that order, so it is built here rather than recovered later.
    let tf = (:)
    let order = ()
    for t in ts {
      if t in tf {
        tf.insert(t, tf.at(t) + 1)
      } else {
        tf.insert(t, 1)
        order.push(t)
      }
    }

    // THE DF CEILING is the part that earns its keep. MEASURED on weeknotes at
    // 40%: it cuts the/this/and/that/for/with/was/which/also/but/from/about/
    // have/been AND corpus-specific noise no word list could ever know about —
    // `week`, in 38 of 56 notes. It buys QUALITY, not bytes: size is almost
    // identical from df<=20% to df<=100% (14,998B against 15,130B at 32 terms)
    // because top-K already binds.
    //
    // The percentage is compared by CROSS-MULTIPLICATION, so no float and no
    // rounding decides whether a term is in or out.
    //
    // A df OF 1 IS NEVER DROPPED. A term in exactly one note is by definition
    // not shared with the corpus, and the ceiling exists to remove what IS
    // shared. Without the guard a small rookery indexes NOTHING: at n=2 every
    // term is in 50% or 100% of the notes and 50 > 40. It cannot move the
    // measurement above either — 40% of 56 notes is 22.4, so no df=1 term on
    // weeknotes was ever near the ceiling. It rescues only the corpus too small
    // for df to mean anything, the same case the stopword floor is there for.
    let kept = order.filter(t => {
      let d = df.at(t)
      d <= 1 or d * 100 <= n * df-ceiling
    })

    // Integer tf-idf: round(100 * tf * log2(n / df)). The 100 keeps the ordering
    // a float would carry without a float ever reaching the sort key, and the
    // number itself is never shipped — it only orders.
    //
    // SORTED BY WEIGHT ALONE, tie-broken by FIRST APPEARANCE: `order` is in
    // first-appearance order and Typst's `.sorted` is stable, so equal weights
    // keep the order the note wrote them in and the island is byte-stable between
    // builds. Same stable-sort reliance `_rank` documents, and the reason the
    // key is a plain integer rather than a `(weight, index)` array — an array
    // key is not reliably comparable here.
    let ranked = kept.sorted(key: t => (
      -1 * int(calc.round(100 * tf.at(t) * calc.log(n / df.at(t), base: 2)))
    ))

    let top = ranked.slice(0, calc.min(body-terms, ranked.len()))
    // `array.join()` on an EMPTY array returns `none`, not `""` (MEASURED, and
    // also recorded at `parse-tag-query` above — this is now the second place
    // that gotcha is load-bearing, `#search-index`'s truncation having gone), and
    // an empty result is a real case: MEASURED, one note on weeknotes compressed
    // to zero terms, its body being genuinely empty.
    if top.len() == 0 { "" } else { top.join(" ") }
  })
}

// ---- #search-index — the corpus as a JSON island --------------------------
//
//   #search-index()                       // usually not called directly
//   #search-index(elem-id: "notes-index")  // a second, differently-keyed index
//   #search-index(body-terms: 24)          // a tighter term budget per note
//   #search-index(df-ceiling: 20)          // a harsher cut of shared terms
//   #search-index(body-search: false)      // no body text in the island at all
//   #search-index(tags: "phd")             // only the notes tagged phd
//
// Emits `<script type="application/json" id="rookery-search-index">[...]</script>`,
// one row per note: `(id, name, text, tags, body, updated, href)`, where `text`
// is the plain-text title ("" when untitled), `tags` is the note's own tag
// array (THE KEY IS ABSENT when it has none), `body` is that note's compressed
// term string ("" when it compresses to nothing), `updated` is that note's
// resolved date as a zero-padded `"[year][month][day]"` string (THE KEY IS
// ABSENT when the note is undated — never shipped as `""` or `null`; this is
// the same stamp `_rank` computes from `e.updated` for the default/browse
// listing, see its comment), and `href` is the depth-relative
// path to the note's minted page — computed against the page this call sits on,
// so an island in a site's shared chrome comes out right on a nested vertebra
// too.
//
// The field is `text`, not `title`, on purpose: same name, same meaning, same
// type as `search-ideas` returns. `title` there is CONTENT, which JSON cannot
// carry, and one name meaning two types across two surfaces is how a consumer
// gets it wrong.
//
// `body-terms` AND `df-ceiling` CONTROL THE COMPRESSION, and there is no
// character cap any more: a row's `body` is `_compress-corpus`' output for that
// note — its `body-terms` most distinctive terms, space-joined in weight order,
// with every term appearing in more than `df-ceiling` percent of the SELECTED
// notes dropped first. The measurements behind both defaults are recorded at
// `_compress-corpus`.
//
// `body-chars` IS RETIRED, and that is 0.3.0's breaking change. The budget is a
// term count now, because a prefix cap spent the bytes on whatever a note
// happened to open with and hid the rest of it from the browser entirely —
// MEASURED, 36% of weeknotes' prose was unfindable in the bar. It is legal only
// because this field is no longer read as prose: the preview pane fetches the
// note's own page instead of excerpting the island.
//
// A cap of SOME kind is not optional, because the island is INLINE IN EVERY
// PAGE, not fetched once: MEASURED for rookery.ohrg.org, its `content/*.typ`
// sources total ~31 KB across roughly 40 notes, so an uncapped index costs on
// the order of 20-25 KB of JSON on every page.
//
// THE FIELD IS STILL CALLED `body` and still holds plain text — what changed is
// its CONTENT, not its name or its type. `search()` in
// `src/rookery-search.js` reads `hit.body` and `snippet` excerpts it for the
// failed-fetch fallback; both keep working, and the string they get simply reads
// as a keyword row rather than as a note's opening sentence.
//
// `df-ceiling` IS MEASURED OVER THE SELECTED NOTES, so `tags:` below moves it: a
// term common across a whole rookery can be distinctive within one tag's notes,
// and each island's ceiling is computed for the corpus it actually carries.
//
// A NOTE CAN COMPRESS TO NOTHING, and its `body` is then `""`. MEASURED, one note
// on weeknotes did, its body being genuinely empty. Such a note is unfindable by
// body — the same as an empty note already was — and its keyword row is empty.
//
// `body-search: false` OMITS THE `body` FIELD ALTOGETHER — a row is then
// `(id, name, text, href)`, and the island shrinks to roughly the sum of the
// corpus's ids and titles. It is the same switch `#search-ideas` takes and
// means the same thing on both sides of the language boundary: the browser
// searches ids and titles only. No JavaScript change is needed to enforce it,
// and that is by construction rather than luck — `search()` in
// `src/rookery-search.js` reads `row.body ?? ""`, and `bodyScore("", q)` is
// `null` for every non-empty query, so a row with no body simply cannot produce
// a body-tier hit. Leaving the field out is therefore the whole implementation.
//
// Two consequences worth stating plainly. A note findable ONLY by a word in its
// body becomes unfindable — that is the point, not a regression. And the modal's
// preview pane loses the keyword row drawn from this field, so on `file://`
// (where the rich preview cannot be fetched) it shows "No preview"; over http the
// fetched page is unaffected.
//
// EITHER WAY THE TYPST SIDE STAYS EXHAUSTIVE: `#search-ideas` scores full bodies
// and never truncated, so a term this island drops — to `body-search: false`, to
// the `df-ceiling`, or to the `body-terms` cut — is still findable there. See its
// comment on that deliberate asymmetry.
//
// WHY NOT A SEPARATE FETCHED JSON FILE, which would keep pages small: rheo
// emits pages from typst, and there is no supported way for a package to emit
// a standalone asset file next to them. An inline island is what the package
// can actually produce, and it also works from `file://` with no fetch.
//
// `search-bar` emits this itself, so most projects never call it. Call it
// directly when building a custom UI, or when several bars share one index —
// see `search-bar`'s `index:` parameter.
//
// The rows are `search-ideas("")` — the empty query matching everything — with
// the fields JSON cannot carry dropped, and unmintable notes filtered out. No
// `body-search:` is forwarded to that call and none is wanted: an empty query
// returns `none` from `body-score` for every note, so the body tier is empty
// whatever the switch says, and every row arrives through the name tier.
//
// `tags:`/`match:` ARE forwarded there, and they scope the island: a note the
// selection excludes is not in the JSON, so the browser cannot find it. That is
// how a bar over just the notes tagged `phd` is built — see `#search-bar`.
//
// EACH ROW CARRIES ITS NOTE'S `tags`, because the browser now has something left
// to decide with them: a reader types `tags:(a|b)&c` into the bar and the script
// evaluates that expression per row (see `#search-ideas`' comment on the two
// axes). The author's `tags:` parameter below still settles the CORPUS in Typst —
// what ships is the field the reader's own filter reads.
//
// MEASURED, 40 notes with tags present, bodies under 0.2.0's 1200-cluster prefix
// cap: 51.1 KB -> 51.8 KB, so +723 B, +1.4%, about 18 B per note. The per-note
// cost is unchanged now that the cap is a term budget; the PERCENTAGE is larger,
// the rest of the row having shrunk.
//
// THERE IS DELIBERATELY NO `tag-search: false` SWITCH. 18 B a note does not earn a
// knob — `body-search: false` earns one because it removes the largest field in
// the row, and a per-project judgement about whether full-text hits are noise has
// no counterpart here.
//
// THE KEY IS OMITTED for an untagged note rather than written as `()`, exactly as
// `body-search: false` omits `body`: an absent key means "none", where `()` would
// cost a key per row to say the same thing. The port reads `row.tags ?? []`.
#let search-index(
  elem-id: "rookery-search-index",
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" { return }
  assert(
    type(body-terms) == int and body-terms > 0,
    message: "@rheo/rookery-search: #search-index's `body-terms` must be a "
      + "positive integer — got " + repr(body-terms),
  )
  assert(
    type(df-ceiling) == int and df-ceiling >= 1 and df-ceiling <= 100,
    message: "@rheo/rookery-search: #search-index's `df-ceiling` must be an "
      + "integer between 1 and 100 — got " + repr(df-ceiling),
  )
  assert(
    type(body-search) == bool,
    message: "@rheo/rookery-search: #search-index's `body-search` must be a "
      + "boolean — got " + repr(body-search),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery-search: #search-index's `tags` must be none, a "
      + "string, or an array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery-search: #search-index's `match` must be \"any\" or "
      + "\"all\" — got " + repr(match),
  )
  let selected = search-ideas("", tags: tags, match: match).filter(e => e.href != none)
  // BODIES, NOT ROWS, and the whole reason is in `_compress-corpus`' comment:
  // this call runs on every output page and is memoised only while every argument
  // is page-invariant, which `href` is not. `e.body` is projected out here and
  // the result is zipped back on positionally below.
  let bodies = if body-search {
    _compress-corpus(
      selected.map(e => e.body),
      body-terms: body-terms,
      df-ceiling: df-ceiling,
    )
  } else {
    ()
  }
  // Built by insertion rather than as one literal, so `body` can be left out
  // entirely under `body-search: false` and `tags` left out for an untagged note.
  // Leaving the KEY OUT is not the same state as an empty string, and now that a
  // note really can compress to no terms the difference carries weight: an absent
  // key means "not indexed", `""` means "indexed, and nothing distinctive
  // survived". `href` is inserted after them either way, keeping a row's field
  // order the documented one.
  //
  // THE INSERTION ORDER IS THE FIELD ORDER, and `tags` goes after `text` and
  // before `body` so that an island row reads in the same order as an `ideas()`
  // row. Nothing depends on it — JSON objects are read by key — but two shapes for
  // one record differing only in their order is how a reader diffing them wastes
  // an afternoon.
  //
  // THIS LOOP IS AFTER `_compress-corpus`, deliberately: `tags` is added to the
  // ROW, never to that call's arguments, which stay `selected.map(e => e.body)`.
  // Its memoisation is keyed on its arguments (see its comment — 287 ms for 30
  // identical calls against 6242 ms for 30 differing in one), so widening them
  // would silently multiply build time by the page count.
  let rows = selected.enumerate().map(pair => {
    let (i, e) = pair
    let row = (id: e.id, name: e.name, text: e.text)
    if e.tags.len() > 0 { row.insert("tags", e.tags) }
    if body-search { row.insert("body", bodies.at(i)) }
    // Same `"[year][month][day]"` stamp `_rank`'s `stamp-of` computes from
    // `e.updated` — omitted, never `""` or `none`, for an undated note, the
    // same convention `tags`/`body` above already use.
    let u = e.at("updated", default: none)
    if u != none { row.insert("updated", u.display("[year][month][day]")) }
    row.insert("href", e.href)
    row
  })
  if rows.len() == 0 { return }
  html.elem(
    "script",
    attrs: (type: "application/json", id: elem-id),
    json.encode(rows, pretty: false),
  )
}

// ---- #search-bar — the embeddable search UI. RHEO ONLY --------------------
//
//   #search-bar()
//   #search-bar(placeholder: "Find a note", limit: 12, class: "topbar-search")
//   #search-bar(index: false)   // a SECOND bar on a page that already has one
//   #search-bar(body-terms: 24)  // a tighter term budget per note in the island
//   #search-bar(body-search: false) // ids and titles only, no body text
//   #search-bar(tags: "phd")        // a bar over only the notes tagged phd
//
// Emits the JSON island (via `search-index`, `body-terms:`, `df-ceiling:`,
// `body-search:`, `tags:` and `match:` forwarded to it UNCHANGED — this function
// asserts none of them, `#search-index` owns their validation), an `<input>`, and
// an empty
// results container; `src/rookery-search.js`, injected by rheo from the
// manifest's `js_scripts`, wires them together.
//
// `tags:` SCOPES THE BAR by scoping its island, which is why it belongs here
// rather than in the script: the corpus is chosen in Typst, and the browser
// searches whatever it was handed. Two differently-scoped bars on one page are
// therefore two islands — give each its own `elem-id:` and leave `index: true`
// on both, where two bars over the SAME corpus want one island and
// `index: false` on the second.
//
// PHRASING CONTENT ONLY — a `<span>` wrapper holding an `<input>` and a
// `<span role="listbox">`, never a `<div>`/`<ul>`/`<li>`. A `<div>` inside a
// paragraph is invalid HTML, which would rule out exactly the embeddings this
// is for: mid-sentence, in a heading, in a table cell. The span wrapper is
// `display: inline-block` by default and a project can make it anything.
//
// NO IDS IN THE MARKUP. Markup carrying a hardcoded id cannot be placed twice
// on a page. `rookery-search.js` assigns the listbox id at runtime and wires
// `aria-controls` to it. The one id on the page belongs to the ISLAND, and
// `data-rookery-search` carries its name so several bars can share one index —
// or point at different ones.
//
// EMITS NOTHING without rheo or on a non-HTML target: the script would not be
// there and the index would be empty, so a bar could only be a dead input.
// Silent no-op rather than an assert, matching how the rest of the stack
// degrades.
#let search-bar(
  placeholder: "Search notes",
  limit: 8,
  class: none,
  index: true,
  elem-id: "rookery-search-index",
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  assert(
    type(limit) == int and limit > 0,
    message: "@rheo/rookery-search: #search-bar's `limit` must be a positive "
      + "integer — got " + repr(limit),
  )
  assert(
    class == none or type(class) == str,
    message: "@rheo/rookery-search: #search-bar's `class` must be none or a "
      + "string — got " + repr(class),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery-search: #search-bar's `tags` must be none, a "
      + "string, or an array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery-search: #search-bar's `match` must be \"any\" or "
      + "\"all\" — got " + repr(match),
  )
  if index {
    search-index(
      elem-id: elem-id,
      body-terms: body-terms,
      df-ceiling: df-ceiling,
      body-search: body-search,
      tags: tags,
      match: match,
    )
  }
  html.elem(
    "span",
    // No inline theme style needed: it inherits rookery's `--idea-*` properties
    // from the document-scope `:root` rule. See the theme block near the top of
    // this file.
    attrs: (
      class: if class == none { "rookery-search" } else { "rookery-search " + class },
      "data-rookery-search": elem-id,
      "data-rookery-search-limit": str(limit),
      "data-rookery-search-open": "false",
    ),
    html.elem("input", attrs: (
      class: "rookery-search-input",
      type: "search",
      role: "combobox",
      placeholder: placeholder,
      autocomplete: "off",
      "aria-label": placeholder,
      "aria-expanded": "false",
      "aria-autocomplete": "list",
    ))
      + html.elem("span", attrs: (class: "rookery-search-results", role: "listbox"), []),
  )
}

// ---- #search-modal — the overlay search UI. RHEO ONLY ---------------------
//
//   #search-modal()
//   #search-modal(placeholder: "Search ideas", limit: 30, trigger-label: "Search")
//   #search-modal(trigger: false)   // markup only; open it from your own button
//   #search-modal(tags: "phd")      // only the notes tagged phd
//
// A telescope-style overlay: a trigger button for a site's topbar (a
// magnifier icon and a `Ctrl K` hint), and a `<dialog>` holding a two-pane
// listbox-plus-preview layout. `#search-bar` STAYS — it is the right thing
// for an inline or in-page bar, and both share `#search-index`; this is
// additive, not a replacement.
//
// A NATIVE `<dialog>` and `showModal()`, not a hand-rolled overlay div: focus
// trapping, page inertness behind it, `::backdrop` and Escape-to-close all
// come free and correct. It also renders in the TOP LAYER, which escapes
// every stacking context — load-bearing here because a sticky, z-indexed site
// header would otherwise trap a plain absolutely-positioned overlay under
// exactly the wrong things.
//
// Emits, in order: the JSON island (via `search-index`, same `index:`/
// `elem-id:`/`body-terms:`/`df-ceiling:`/`body-search:`/`tags:`/`match:`
// `#search-bar` already takes, all forwarded unchanged and all asserted by
// `#search-index`), then the trigger button (unless `trigger: false`), then the
// dialog.
// That is ALL it emits — see below on where the preview pane's content comes
// from.
//
// `tags:`/`match:` scope the island exactly as they do for `#search-bar`, so a
// site-wide modal can be restricted to one tag's notes. A modal sitting in a
// site's shared header is the case where that costs least to say and most to
// get wrong: the scope is settled once, in Typst, on every page it renders on.
//
// THE PREVIEW PANE'S RICH CONTENT IS FETCHED, NOT BUILT IN. The pane shows the
// selected note's real rendering — links, styling, footnotes, figures — and it
// gets it by `fetch`ing that note's own minted page (`ideas/<slug>.html`,
// which rookery's `.marrow.typ` already emits) when the reader selects the row,
// then caching it for the session. Nothing is rendered into this page.
//
// That is a build-cost decision, and a MEASURED one. This function sits in a
// site's header, so it runs on EVERY page; an earlier version emitted a hidden
// per-note container holding `#idea-body`'s rendering of every note, which is
// `notes × pages` renders per build — 57 × 69 ≈ 3,900 on weeknotes.ohrg.org,
// costing 14.6s against a 2.65s baseline and 312 MB of output (301 MB of it
// base64 images, since Typst's HTML export inlines every `#image`). Stripping
// the images cut the size to 33 MB but left the time at 14.6s, because the cost
// is PER CALL, not per byte: rendering the same bodies at `limit: 1`, near
// empty, still cost 10.3s. Truncation could not fix that; only not rendering
// N×M could. Fetching reuses pages rheo already emits, so the marginal build
// cost of a rich preview is now exactly zero.
//
// The trade, stated plainly: `fetch` does not work from `file://`, so opening
// a build straight off disk gets the JSON island's `body` field instead of the
// rich rendering — which since 0.3.0 is that note's compressed KEYWORD ROW, not
// a prose excerpt, because the field is compressed precisely on the grounds that
// the pane no longer renders it as prose (see `#search-index`). Rich previews
// need http (`rheo watch`, or any served copy). Serve the build, or accept the
// keyword row. Note that `body-search: false` removes that field, so the two
// together mean no preview at all on `file://`; over http the fetched page is
// unaffected.
//
// SAME ISLAND, SHARED BY NAME, NO IDS IN THE MARKUP — the rule `#search-bar`
// follows (see its comment above). The trigger's `data-rookery-search-modal`
// equals the dialog's `data-rookery-search`, so several triggers can drive
// one modal and nothing here needs an id of its own. A page should carry AT
// MOST ONE modal per island name; the script wires the first matching dialog.
//
// The `<kbd>` hint is `aria-hidden`: a screen reader should hear the button's
// `aria-label`, not the literal keys.
//
// EMITS NOTHING without rheo or on a non-HTML target, same reason and same
// silent no-op as `#search-bar`.
#let search-modal(
  placeholder: "Search notes",
  limit: 30,
  class: none,
  trigger: true,
  trigger-label: "Search",
  index: true,
  elem-id: "rookery-search-index",
  body-terms: 48,
  df-ceiling: 40,
  body-search: true,
  tags: none,
  match: "any",
) = context {
  if _target() != "html" or _rheo-ctx() == none { return }
  assert(
    type(limit) == int and limit > 0,
    message: "@rheo/rookery-search: #search-modal's `limit` must be a positive "
      + "integer — got " + repr(limit),
  )
  assert(
    class == none or type(class) == str,
    message: "@rheo/rookery-search: #search-modal's `class` must be none or a "
      + "string — got " + repr(class),
  )
  assert(
    tags == none
      or type(tags) == str
      or (type(tags) == array and tags.all(t => type(t) == str)),
    message: "@rheo/rookery-search: #search-modal's `tags` must be none, a "
      + "string, or an array of strings — got " + repr(tags),
  )
  assert(
    match == "any" or match == "all",
    message: "@rheo/rookery-search: #search-modal's `match` must be \"any\" or "
      + "\"all\" — got " + repr(match),
  )
  if index {
    search-index(
      elem-id: elem-id,
      body-terms: body-terms,
      df-ceiling: df-ceiling,
      body-search: body-search,
      tags: tags,
      match: match,
    )
  }
  if trigger {
    html.elem(
      "button",
      attrs: (
        class: "rookery-search-trigger",
        type: "button",
        "data-rookery-search-modal": elem-id,
        "aria-label": trigger-label,
      ),
      html.elem(
        "svg",
        attrs: (class: "rookery-search-icon", viewBox: "0 0 24 24", "aria-hidden": "true"),
        html.elem("path", attrs: (
          d: "M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3"
            + " 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49"
            + " 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z",
        )),
      )
        + html.elem("kbd", attrs: (class: "rookery-search-key", "aria-hidden": "true"), [Ctrl K]),
    )
  }
  html.elem(
    "dialog",
    // No inline theme style needed here either: this element is emitted wherever
    // the author calls `#search-modal` — in practice a site's header — and now
    // inherits rookery's `--idea-*` properties from the document-scope `:root`
    // rule rather than from a DOM parent. See the theme block near the top of
    // this file.
    attrs: (
      class: if class == none { "rookery-search-modal" } else { "rookery-search-modal " + class },
      "data-rookery-search": elem-id,
      "data-rookery-search-limit": str(limit),
    ),
    html.elem(
      "div",
      attrs: (class: "rookery-search-modal-inner"),
      html.elem("input", attrs: (
        class: "rookery-search-input",
        type: "search",
        role: "combobox",
        autocomplete: "off",
        "aria-autocomplete": "list",
        "aria-expanded": "false",
        placeholder: placeholder,
        "aria-label": placeholder,
      ))
        + html.elem(
          "div",
          attrs: (class: "rookery-search-panes"),
          html.elem("div", attrs: (class: "rookery-search-list", role: "listbox"), [])
            + html.elem("div", attrs: (class: "rookery-search-preview", "aria-live": "polite"), []),
        )
        + html.elem(
          "div",
          attrs: (class: "rookery-search-hint"),
          [↑↓ navigate · ↵ open · esc close],
        ),
    ),
  )
}
