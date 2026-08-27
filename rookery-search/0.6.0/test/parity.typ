// The parity fixture. `test/parity.mjs` reads this via `typst eval` and diffs
// every score against `score` in `src/rookery-search.js`. Not shipped: the
// release archive tars `dist/`, which vite builds from `src/` alone.
#import "/src/lib.typ": (
  _fold, _rank, body-score, eval-tag-query, fuzzy-score, parse-tag-query,
  split-query,
)
#let cases = (
  ("flat-ids", "flat"), ("flat-ids", "flat ids"), ("flat-ids", "flat-ids"),
  ("windows", "window"), ("window-depth", "window"), ("windows", "windows"),
  ("Flat ids, and why", "why"), ("Flat ids, and why", "flt"),
  ("tags", "zzz"), ("tags", ""), ("Windows", "wnd"),
  ("the window depth budget, and why an index does not want it", "window"),
  ("W i n d o w s", "window"), ("ETAL", "etal"), ("etal", "ETAL"),
  ("a_b_c", "a b"), ("Café", "cafe"),
  // CLUSTERS WIDER THAN ONE CODE POINT, named rather than left to the generated
  // suite. The port counted UTF-16 code points where `fuzzy-score` counts
  // extended grapheme clusters, and since `hc.len()` and `first` are global terms
  // in the score, one such sequence anywhere in a hay moved every query against
  // it. These five are the failures that found it, kept as a named regression:
  // the generator can only catch them again at a seed that happens to draw them.
  // `\u{306}` written as an escape, NOT as a precomposed `ĕ`: the precomposed form
  // is one code point AND one cluster, so it agrees either way and pins nothing.
  // MEASURED — with the spread restored, four of these five fail and the
  // precomposed spelling of this one passed.
  ("👩‍💻-queRY", "💻eY"), ("résumé-❤️", "rsu❤"), ("❤️ window", "w"),
  ("e\u{306} beta", "e\u{306} be"), ("检索c̃", "索c̃"),
)
#metadata(cases.map(c => (
  hay: c.at(0),
  query: c.at(1),
  score: fuzzy-score(c.at(0), c.at(1)),
))) <parity>

// A second fixture for `body-score` — the AND, rank-scored matcher over note
// bodies. Its own labelled array, `<parity>` above kept untouched, because
// `body-score` is a different rule with a different signature (`none` on ANY
// missing term, not a fuzzy subsequence).
//
// THE BODIES ARE TERM LISTS, NOT PROSE, and that is the fixture following the
// rule rather than a convenience. What `#search-index` ships is
// `_compress-corpus`' output — a note's most distinctive terms, space-joined in
// weight order — and RANK over that list is the whole score now, so prose here
// would pin a shape the browser never sees. (`#search-ideas` does still score
// full prose through the same function, a word simply being a term there; no case
// below needs to be prose to hold that down.)
//
// NO CASE COUNTS CLUSTERS, because the rule no longer does — a rank is a term
// index, which Typst and JavaScript count identically. The non-ASCII case is
// therefore about accent folding NOT happening, and nothing else.
#let body-cases = (
  // A compressed island row, as `_compress-corpus` really emits them (this one
  // is the spike's own sample output). Multi-term AND, a hyphenated and a dotted
  // term surviving whole, the exact-match +3 twice, and one bucket step:
  // `rheo-context` at rank 0 scores 10 + 3, `html` at rank 6 scores
  // 10 - int(6 / 4) = 9, + 3. So 25.
  (
    "rheo-context typst changes 0.5.1 removing types html released 0.6.0",
    "rheo-context html",
  ),
  // Multi-term query where one term is present and one is not — must score
  // `none`, not a partial score.
  (
    "rheo-context typst changes 0.5.1 removing types html released 0.6.0",
    "rheo-context zzz",
  ),
  // TWO PREFIX MATCHES AND NO EXACT ONE: `chang` in `changes` at rank 2, `0.5`
  // in `0.5.1` at rank 3, both in bucket 0, neither equal to a kept term. 10 + 10
  // = 20, where the same pair matched exactly would be 26 — that difference is
  // the bonus under test. Also pins that a query may address PART of a dotted
  // term.
  (
    "rheo-context typst changes 0.5.1 removing types html released 0.6.0",
    "chang 0.5",
  ),
  // THE RANK FLOOR, `max(1, 10 - int(rank / 4))`, and that the exact-match +3 is
  // added AFTER it: 42 terms in SEVENS below (so ranks 0-6, 7-13, 14-20, 21-27,
  // 28-34, 35-41 line up with the six string chunks), the query's second term
  // last at rank 41, where 10 - int(41 / 4) is 0 and the floor lifts it to 1.
  // `marx` at rank 0 scores 10 + 3, `endpaper` at rank 41 scores 1 + 3, so 17. A
  // note is capped at `body-terms` (48), so a rank in the forties is a real
  // position in a real island row and not a synthetic extreme.
  (
    "marx kohei saito eco-marxist anthropocene deutscher torino "
      + "fame prize degrowth capital metabolic rift grundrisse "
      + "lecture seminar translation japanese ecology socialism abundance "
      + "scarcity commons enclosure rentier austerity municipal utopia "
      + "archive pamphlet footnote marginalia hardback paperback remainder "
      + "warehouse catalogue imprint colophon errata frontispiece endpaper",
    "marx endpaper",
  ),
  // NON-ASCII, and a query missing only on the accent: `cafe` is not a substring
  // of `café`, so the AND fails and the score is `none`. No accent folding, by
  // design and documented as a limitation in the readme — the tokenizer keeps the
  // accent, so the reader must type it.
  ("café leche madrid cortado azúcar tostada", "cafe tostada"),
  // An empty query is the name rule's business, not this one — `none`. Load-
  // bearing for `#search-index`, which builds its rows from `search-ideas("")`
  // and relies on every note scoring `none` here so the body tier stays empty.
  ("kernel module driver", ""),
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
  (id: "idea:aaa", name: "aaa", text: "Window handling", label: "Window handling", body: "prose about nothing in particular"),
  // Matches on BODY only. It carries `text: ""` — no authored title — and a
  // `label` whose words do NOT include the query, which is what keeps this case
  // constructible at all now that the name tier scores `label`: rookery derives a
  // titleless note's label from its body's FIRST 60 characters, so a body-only
  // match is one whose match falls later than that. The old fixture relied on
  // `text: ""` skipping the
  // title score entirely rather than scoring an empty haystack.
  (
    id: "idea:bbb",
    name: "bbb",
    text: "",
    // NO LETTER `w` ANYWHERE IN THE LABEL, which is what makes this a body-only
    // row for both queries the tier cases use ("win" and "wnd"): a subsequence
    // match needs its first letter, so neither can touch the name tier here.
    label: "opening clause, mentions the query only later on",
    body: "opening clause, mentions the query only later on, then win window windows",
  ),
  // NO `body` KEY AT ALL. Must never reach the body tier, and must not error.
  // `label` falls back to the NAME, which is what rookery does for a titleless
  // note with no body either.
  (id: "idea:ccc", name: "ccc", text: "", label: "ccc"),
  // Two rows tying on score. For a REAL query ("wnd" below) the tie still
  // breaks by id: ddd before eee. DATED, so the empty-residual case ("", none
  // below) breaks the same tie by date instead — newest first, eee (Mar 2026)
  // before ddd (Jan 2026) — and sorts both ahead of every undated row.
  (id: "idea:ddd", name: "wnd", text: "Wnd", label: "Wnd", created: datetime(year: 2026, month: 1, day: 5)),
  (id: "idea:eee", name: "wnd", text: "Wnd", label: "Wnd", created: datetime(year: 2026, month: 3, day: 1)),
  // A WEAK name match: the query's letters appear scattered through a long
  // haystack, so its score lands BELOW a strong body-tier score. It must still
  // sort above every body row — that is the tiering rule, not a score contest.
  (id: "idea:scatter", name: "wqqiqqnqqqqqqqqqqqqqqqqqqqqqqqq", text: "", label: "wqqiqqnqqqqqqqqqqqqqqqqqqqqqqqq"),
  // TAG-CARRYING ROWS, placed HERE and not appended: `idea:tg*` sorts between
  // `idea:scatter` and `idea:window-depth`, and this array MUST stay in id order
  // (see the comment above it) or the empty-query case diverges — MEASURED, an
  // appended pair failed exactly that case and nothing else.
  //
  // For the `tags:` predicate. Deliberately free of the letter
  // `w`, so they cannot subsequence-match "window"/"win"/"wnd" and perturb the
  // nine cases that predate them. Every OTHER row here has no `tags` key at
  // all, which is the shape `#search-index` emits for an untagged note and the
  // one both sides must read as "no tags" rather than erroring.
  (id: "idea:tg1", name: "tg1", text: "Alpha", label: "Alpha", body: "alpha prose", tags: ("phd", "draft")),
  (id: "idea:tg2", name: "tg2", text: "Beta", label: "Beta", body: "beta prose", tags: ("phd",)),
  // Two strong name matches that the length term separates (35 vs 40 for
  // "window") — the pair the scorer's own comment cites.
  (id: "idea:window-depth", name: "window-depth", text: "Controlling window depth", label: "Controlling window depth"),
  (id: "idea:windows", name: "windows", text: "Windows", label: "Windows"),
)
// Emitted for the runner too, so the JavaScript side ranks THE SAME rows rather
// than a hand-copied second corpus that could drift from this one.
//
// `created` IS RESTAMPED ON THE WAY OUT, and that is not a divergence from
// "the same rows" — it is the SAME conversion `#search-index`'s row-builder
// makes when it ships an `ideas()` row (raw `datetime`) to the browser as JSON
// (a `"[year][month][day]"` string): `typst eval --format json` has no native
// encoding for `datetime` and falls back to its debug repr
// (`"datetime(year: ..)"`, MEASURED), which is not a lexicographically-ordered
// stamp. `_rank(tier-rows, ..)` below still sees the RAW `datetime` on `ddd`/
// `eee`, exactly as `ideas()` would hand it — only the metadata dump for the
// JS runner is restamped, matching what a real island row actually carries.
#metadata(tier-rows.map(e => {
  // TWO CONVERSIONS, both of them what `#search-index`'s row-builder does when it
  // ships an `ideas()` row to the browser as JSON. `_rank` below still sees the
  // RAW row, exactly as `ideas()` would hand it; only the metadata dump for the JS
  // runner is restamped, so both halves see what they see in production.
  //
  // `text` <- `label`: the island's `text` field means WHAT TO CALL THE NOTE, and
  // `label` is rookery's answer — the authored title flattened, else the body's
  // first 60 characters, else the name, never empty. Without this the JS scored an
  // empty title for every titleless row while Typst scored its label, and the two
  // disagreed on exactly the rows this fixture exists to pin down.
  let e = (..e, text: e.at("label", default: e.at("text", default: "")))
  let u = e.at("created", default: none)
  if u == none { e } else { (..e, created: u.display("[year][month][day]")) }
})) <tier-rows>

#let tier-cases = (
  ("window", none), // full tiering, name rows above the body row
  ("window", 2), // `limit` cutting INSIDE the name tier
  ("window", 3), // `limit` landing exactly ON the tier boundary: the one body
  // row is dropped, because the cut applies to the CONCATENATION and not per tier
  ("window", 0), // a zero limit is empty, not unlimited
  ("win", none), // body-tier score ABOVE a weak name-tier score
  ("wnd", none), // a tie, broken by id
  // Empty query: every row scores 0 in the name tier. Dated rows (eee, ddd)
  // now sort newest-first ahead of the undated rows, which keep their old id
  // order — the new default/browse-listing rule, not the old flat id order.
  ("", none),
  ("zzz", none), // no match anywhere
  ("window depth", none), // multi-term: AND over the body, subsequence over names
  // THE `tags:` PREDICATE, which nothing above reaches. It is one line in each
  // language and it runs ahead of every scorer, so an untested copy would drift
  // silently: MEASURED, deleting it from the JavaScript side leaves all nine
  // cases above passing.
  ("tags:phd", none), // filter only, no residual: survivors at score 0, id order
  ("tags:phd&!draft", none), // negation, so tg1 drops and tg2 stays
  ("tags:phd alpha", none), // filter THEN rank the residual over the survivors
  ("tags:nope", none), // matches no note: empty, not unfiltered
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

// A fourth fixture, for the `tags:` query parser and its evaluator — the one
// rule here whose output is not a number. It is diffed AS DATA: a flattened RPN
// string, the residual text, and a boolean per fixed tag set, all three of which
// a JavaScript twin can produce character for character. That is the whole
// reason the parser is shunting-yard and emits a token array (see
// `parse-tag-query`), rather than a recursive descent whose only comparable
// output would be its final verdict.
//
// THE FIRST 19 CASES ARE THE EXACT SET THE SPIKE VERIFIED — do not thin them
// out. They are the only place precedence, the frozen escape set, folding, the
// space that ends an expression, and every repair path (`unclosed-open`,
// `unmatched-close`, a dangling operator, a trailing `\`) are pinned. A case that
// looks redundant is holding one of those down.
//
// Note that `\\` in a Typst string literal is ONE backslash in the query, which
// is what a reader would actually type: `"tags:a\\&b"` is the query `tags:a\&b`.
#let tag-cases = (
  "tags:(a|b)&c", "tags:a|b&c", "tags:!draft", "tags:!(draft|todo)&note",
  "tags:draft window depth", "tags:draft   window  depth ", "tags:a\\&b",
  "tags:a\\|b|c", "tags:\\(paren\\)", "tags:a\\ b", "tags:(a|", "tags:a&",
  "tags:)a", "tags:", "tags:a\\", "TAGS:note", "window depth",
  "tags:note&&draft", "tags:((note))",
  // STACKED `!`, added after the spike, and the ONLY thing in this table that
  // exercises `!` being RIGHT-associative. MEASURED: against the 19 cases above,
  // deleting the right-associativity entry from the JavaScript port's operator
  // table changed no case at all and `just parity` still passed — a rule the
  // comment above claimed to pin and did not. `!!draft` is the shortest input
  // that needs it: read left-associatively, the second `!` pops the first off the
  // stack before it has an operand.
  "tags:!!draft", "tags:!!!draft&note",
  // CLUSTERS IN A TAG QUERY, and these pin an EQUIVALENCE rather than a past bug.
  // `parse-tag-query` walks `.clusters()`; the JavaScript port walked code points
  // until bead rheo-packages-j6e, which is a real drift in `fuzzy-score` (see the
  // five cases in `cases` above) — but MEASURED, it was unobservable here, and all
  // four of these agreed under both implementations.
  //
  // WHY, because it is the thing that could stop being true: the only path that
  // cares how wide a unit is is the escape branch, which consumes exactly ONE, and
  // every other branch merely appends the unit to `atom` — where concatenating a
  // cluster's code points rebuilds the same string. So `a\❤️b` is one atom either
  // way: a spread escapes only U+2764 and then appends U+FE0F as ordinary text,
  // which is where it would have landed regardless. It takes an operator character
  // INSIDE a cluster to break that, and the frozen escape set is all ASCII while no
  // grapheme cluster continues with ASCII. Widen the escape set and this is where
  // it shows up.
  "tags:résumé", "tags:❤️|c̃", "tags:👩‍💻&note", "tags:a\\❤️b",
)
// One fixed ladder of tag sets, evaluated for EVERY case, so the runner compares
// a whole boolean row rather than a single verdict — the last set is the untagged
// note, which is where a negation has to keep working.
#let tag-sets = (("note",), ("note", "draft"), ("draft",), ("a", "c"), ("b", "c"), ())
#let _rpn-str(rpn) = {
  let s = rpn.map(t => if t.at(0) == "atom" { "\"" + t.at(1) + "\"" } else { t.at(1) }).join(" ")
  // `array.join()` on an EMPTY array returns `none`, not `""` (MEASURED, and
  // documented at `#search-index` in `src/lib.typ`), and an empty RPN is a case
  // here twice over — `tags:` and `window depth` both produce one.
  if s == none { "" } else { s }
}
// `eval-tag-query` wants FOLDED tags (its atoms are folded at push time), so the
// fixture folds each set with `_fold` exactly as a real caller must — the one
// step a port could skip and still look right on ASCII single-word tags.
#metadata(tag-cases.map(c => {
  let r = split-query(c)
  (
    query: c,
    rpn: _rpn-str(r.rpn),
    text: r.text,
    evals: tag-sets.map(ts => eval-tag-query(r.rpn, ts.map(_fold))),
  )
})) <tag-parity>
