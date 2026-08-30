// The `tags:` query language: a boolean expression over a note's tags.
//
// A shunting-yard parse to RPN, an evaluator over that RPN, and the atom
// extractor the UI marks matched pills with. The biggest single subject in this
// package and the one with a JavaScript twin — `parseTagQuery`/`evalTagQuery` in
// src/rookery-search.js, pinned to this file case for case by test/parity.mjs.

#import "base.typ": *

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
