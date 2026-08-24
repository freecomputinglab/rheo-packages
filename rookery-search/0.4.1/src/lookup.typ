// `#search-ideas` — fuzzy lookup over a rookery's ids, titles and bodies, as
// data rather than as UI.
//
// Below `rank.typ`, which scores, and ABOVE `corpus.typ`, which calls this to
// select the notes it compresses. That last dependency is why this is its own
// module: `#search-index` lives in `corpus.typ` and needs the name here, and a
// module cannot import the entrypoint that imports it.

#import "@rheo/rookery:0.4.1": ideas, note-href
#import "base.typ": *
#import "rank.typ": *

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
  _assert-bool(body-search, "body-search", "#search-ideas'")
  _assert-tags(tags, "#search-ideas'")
  _assert-match(match, "#search-ideas'")
  _rank(
    ideas(tags: tags, match: match),
    query,
    limit: limit,
    body-search: body-search,
  )
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
