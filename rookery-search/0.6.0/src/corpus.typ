// The corpus pass — every note compressed to its most distinctive terms — and
// the build-once cache that keeps it from running per emitted page.
//
// The two belong together: the cache exists to serve the pass, `.marrow.typ`
// imports from both, and the measurements that justify either are written
// against the pair.

#import "base.typ": *
#import "lookup.typ": *


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
// cost a key per row to say the same thing. The port reads `row.tags ?? []`.
// ---- The build-once corpus cache ------------------------------------------
//
// `_compress-corpus` is a pure function of its arguments and Typst memoises it
// perfectly WITHIN one document — MEASURED natively: 20 identical calls cost
// the same 1.1s as one, whether the argument array is a reused value or rebuilt
// with `.map` on every call, inside `context` or not. None of the obvious
// suspects defeats it.
//
// Under rheo it does not collapse, and that is what this cache is for. rheo
// emits many documents from one build, and the memo does not carry across them.
// MEASURED on a synthetic rookery of 200 notes at 1500 words, 40 vertebrae, one
// `#search-modal` each:
//
//     40 vertebrae emitting the island   10.2s
//      1 vertebra  emitting the island    5.6s
//     40 vertebrae, body-search: false     1.0s
//
// so ~118ms per emitting page, against ~15ms for the island's own JSON, which
// scales the whole build by the page count on exactly the sites big enough to
// want search.
//
// `.marrow.typ` next to this file runs ONCE at the bundle root, compresses the
// whole rookery there, and publishes the result here. KEYED BY NOTE ID, not by
// position: `#search-index` selects and orders its own rows, and an id lookup
// survives both. The knobs that change the terms are in the key too, so an index
// built with different `body-terms`/`df-ceiling` never reads another's terms.
//
// EMPTY WITHOUT RHEO, which is the whole fallback: `.final()` gives `(:)`, every
// lookup misses, and `#search-index` compresses inline exactly as before. Same
// under rheo for a TAG-FILTERED index — see the miss path at its call site.
#let _corpus-cache = state("rookery-search-corpus", (:))

// The cache key for one set of compression knobs. A string rather than a dict
// so it can be a dictionary key at all.
#let _corpus-key(body-terms, df-ceiling) = "t" + str(body-terms) + "/d" + str(df-ceiling)

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
  _assert-bool(body-search, "body-search", "#search-index's")
  _assert-tags(tags, "#search-index's")
  _assert-match(match, "#search-index's")
  let selected = search-ideas("", tags: tags, match: match).filter(e => e.href != none)
  // BODIES, NOT ROWS, and the whole reason is in `_compress-corpus`' comment:
  // this call runs on every output page and is memoised only while every argument
  // is page-invariant, which `href` is not. `e.body` is projected out here and
  // the result is zipped back on positionally below.
  let bodies = if not body-search {
    ()
  } else {
    // The bundle-root cache first (see `_corpus-cache` above). Only for an
    // UNFILTERED index: `tags:` narrows the corpus, and both the note count and
    // the document frequencies are corpus-wide, so a filtered index's terms are
    // genuinely different terms and must be computed over the notes it selected.
    // A missing id falls through the same way — a note the marrow could not see
    // (no minted page yet, no rheo at all) must not silently index as nothing.
    let cached = _corpus-cache.final().at(_corpus-key(body-terms, df-ceiling), default: (:))
    if tags == none and selected.len() > 0 and selected.all(e => e.id in cached) {
      selected.map(e => cached.at(e.id))
    } else {
      _compress-corpus(
        selected.map(e => e.body),
        body-terms: body-terms,
        df-ceiling: df-ceiling,
      )
    }
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

// What `#search-bar` and `#search-modal` do identically, before either draws
// anything: validate the four arguments they share and emit the island.
//
// MEASURED before this existed: 34 of `#search-bar`'s 66 code lines were byte
// for byte the same as lines in `#search-modal` — the parameter list, the
// guard, four asserts and the whole `#search-index` call with its six forwarded
// arguments. Bead `rp-modal-limit-default-c88` was that duplication biting: the
// modal's JavaScript fallback for `limit` had drifted from the Typst default.
//
// `where` is the caller's name for the messages, the same convention the
// `_assert-*` validators above use.
//
// NOT SHARED, deliberately: the `<input>` element. Both spell the same eight
// attributes, but in a different ORDER, and Typst emits them in the order given
// — so one canonical version would change the bytes of every page carrying the
// other. That is a real cleanup and it needs its own bead, with a diff a
// reviewer can look at, not a silent rider on this one.
//
// The guard `if _target() != "html" or _rheo-ctx() == none { return }` stays in
// both too: `return` belongs to the function that means to return.
#let _search-ui-common(
  where,
  limit,
  class,
  index,
  elem-id,
  body-terms,
  df-ceiling,
  body-search,
  tags,
  match,
) = {
  assert(
    type(limit) == int and limit > 0,
    message: "@rheo/rookery-search: " + where + " `limit` must be a positive "
      + "integer — got " + repr(limit),
  )
  assert(
    class == none or type(class) == str,
    message: "@rheo/rookery-search: " + where + " `class` must be none or a "
      + "string — got " + repr(class),
  )
  _assert-tags(tags, where)
  _assert-match(match, where)
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
}

// One class attribute for both, so a project's `class:` lands the same way on a
// bar and on a modal.
#let _search-class(base, class) = if class == none { base } else { base + " " + class }
