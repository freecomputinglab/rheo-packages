# @rheo/rookery-search

Fuzzy search over the notes in a [`@rheo/rookery`](../../rookery/0.6.0) — by
id and title, and by full text — a Typst primitive that ranks them, a JSON
index of the corpus, an inline search bar, a site-wide overlay modal, and a
faceted filter panel.

It is a separate package rather than part of rookery because search is only
worth having with JavaScript, and rookery is deliberately the one package here
that ships none. Splitting keeps rookery buildless and puts the JavaScript in a
package built like every other one in this repo.

Two things follow from that, and both catch people out. This package **is
built**: it resolves through `dist/`, so an edit to `src/` does nothing until
you run `just build` — rookery's edits are live, these are not. And only its
Typst ranking works without rheo; the index and the bar need it. Both are
spelled out below.

```typst
#import "@rheo/rookery:0.6.0": idea, rookery
#import "@rheo/rookery-search:0.6.0": search-bar
#show: rookery

#search-bar()
```

## 0.6.0

**`#panel` — a faceted filter over a `tag-index` projection.** A different surface
from the bar and the modal, and the difference is the point: those two rank the
whole corpus against a query and pop a dropdown, while a panel filters a list that
is ALREADY ON THE PAGE, by facets you declare. See "#panel" below.

**The browse ordering reads `created`.** Rookery 0.6.0 removed its `updated` field,
and the empty-query listing sorted on it. Left alone that branch would have found
`none` on every row, dropped every note into the undated bucket, and silently
reverted the default listing to id order — no error, just the wrong answer.

**The JSON island's date key renamed with it**, `updated` → `created`. A key named
`updated` carrying a creation date is exactly the drift the rest of this package's
comments exist to prevent, and `just parity` keeps the Typst and JS halves reading
the same one. If you built your own UI on `readIndex`, read `row.created`.

## 0.4.0

- **The theme comes from rookery's `:root` rule now**, rather than being
  copied into this package. Retheme the rookery and the search bar, the modal
  and the result rows follow, with nothing to keep in sync. Requires
  `@rheo/rookery:0.6.0`, which this version imports.
- **The default browse listing — the empty query — sorts dated notes
  newest-first**, instead of by id. An undated note still sorts after every
  dated one.
- **The corpus is compressed once per build under rheo**, in this package's new
  `.marrow.typ`, rather than once per emitted page. MEASURED on a 200-note,
  40-page synthetic rookery: 10.9s to 6.3s, with byte-identical islands. See
  "The corpus is compressed once per build" below for the two cases that still
  compress inline.

## 0.3.0

- **Breaking: the island's `body` field is no longer prose.** It used to be a
  prefix of the note's own text; it is now a weight-ordered list of the
  note's most distinctive terms — keyword soup, not readable prose. Anything
  that read the island JSON and rendered `body` as text now renders keyword
  soup instead. Read a note's prose from its own minted page instead —
  `note-href()` plus a `fetch`, which is what `#search-modal`'s preview pane
  itself now does. See "The preview pane fetches the note's page" below.
- **A row now carries a `tags` key** when the note has any tags, omitted
  entirely when it has none. MEASURED over a 40-note corpus: +723 bytes,
  +1.4%.
- **A `tags:` query grammar exists now** (`tags:draft window`, and so on) —
  see "Filtering by tag" below for the grammar itself.
- **Tag chips render on result rows, and keyboard navigation works in
  `#search-bar`'s dropdown** — see "Working it from the keyboard" below.
- **Both `#search-bar` and `#search-modal` now pick up rookery's own theme**
  even in a site header, for the first time: `--idea-*` custom properties reach
  them by inheriting rookery's document-scope `:root` rule (`@rheo/rookery`
  publishes it once per page), the same rule any other element on the page
  inherits from — no per-container copy needed on this package's side. The
  last-resort fallback colour of every rule moved from `rgba(0, 0, 0, 0.25)` to
  rookery's own `rgba(128, 0, 255, 0.12)`. A site with no explicit theme
  override sees a visible colour change.
- **Focusing the search-bar input or the modal input now thickens the
  input's own rule/border**, rather than drawing the browser's default blue
  focus ring.
- **The JavaScript ranking port now counts extended grapheme clusters** (via
  `Intl.Segmenter`) rather than UTF-16 code points. A haystack containing a
  combining mark or a multi-codepoint emoji now scores differently than it
  did before. Typst-side scoring is unaffected — it already counted clusters.
  This is a JS-only change, relevant only to a site with non-ASCII or emoji
  note titles/ids.

## Import both packages, in your own files

**A project using search must import `@rheo/rookery` AND `@rheo/rookery-search`
in its own `.typ` files.** This is a requirement, not a tidiness preference.

rheo only scans a project's own files for package imports — not the packages
those files' packages import in turn. So importing only `rookery-search` and
reaching rookery through it does not register rookery with the build. The cost
is not cosmetic: rookery's `.marrow.typ` never runs, **no note pages are minted
at all**, and with no minted pages there are no hrefs, so the index comes out
empty and the bar has nothing to link to. Its stylesheet is missing too.

In practice this is free — a project with notes in it writes `#idea`, and so
imports rookery already. It is stated here because the failure is silent: a
build with no rookery import succeeds, and produces a search bar that finds
nothing.

For the same reason this package does **not** re-export rookery's functions.
There is no arrangement in which importing rookery-search alone is correct, so
it does not offer one.

## What needs rheo

Four functions, and they do not all need the same things:

- **`search-ideas(query)` — no rheo, no JavaScript.** It ranks the corpus and
  hands you the matches; you render them however you like. Works under plain
  `typst compile`, and a static list of results is a real answer, not a
  fallback.
- **`search-index()` — rheo only.** Its rows link to minted note pages, and
  only rheo mints them. Without rheo every link would be `none`, so it emits
  nothing at all rather than shipping a browser a list of nulls.
- **`search-bar()` and `search-modal()` — rheo only**, twice over each: the
  same minted pages, plus a script that rheo injects from this package's
  manifest. Both emit nothing without rheo, rather than rendering an input or
  a trigger that could never work.

None of the last three is useful in a single-document build anyway — a PDF has
no pages to navigate between and nothing to run a script.

Where rheo is what you build with, it must be **rheo >= 0.5.2**. All three
rheo-only functions are downstream of the note pages rookery mints from its
`.marrow.typ`, and inlining a package's `.marrow.typ` landed in 0.5.2. On an
older rheo nothing errors — no pages are minted, so the index comes out empty
and the bar/modal have nothing to link to, which is the same silent failure as
forgetting to import rookery at all.

OBSERVED (rheo 0.5.2, built from source at tag `v0.5.2`; typst 0.15.1), on a
project importing both this package and rookery: `dist/lib.js` and
`dist/rookery-search.css` are copied to `build/html/rheo/rookery-search/` and
linked from every page's `<head>` at the correct depth-relative prefix
(`rheo/…` at the root, `../rheo/…` one level down), and the JSON index island
parses with one row per note, every `href` resolving to a minted page that
exists on disk. So both manifest keys this package depends on —
`[tool.rheo.html] js_scripts` and `css_stylesheet` — and its `.marrow.typ`
corpus cache all work on the declared floor. Nothing here reaches for a rheo
surface newer than 0.5.2.

## Searching, without JavaScript

`#search-ideas(query)` ranks the corpus and hands you the matches as data. It
is pure Typst — no rheo, no JavaScript, nothing in the browser — which is why
it is a layer of its own rather than something the search bar hides inside.

```typst
#import "@rheo/rookery-search:0.6.0": search-ideas
#context {
  for e in search-ideas("") {
    let shown = if e.text == "" { e.name } else { e.text }
    if e.href == none [ - #link(label(e.id), shown) ]
    else [ - #link(e.href, shown) ]
  }
}
```

That is a whole static index of the rookery, rendered at compile time. An empty
query matches everything, so the same function does double duty as "list them
all". Pass `limit: 10` to cap it.

**It has to be called inside `#context`** — it reads rookery's registry, and
reading a Typst state whole is only legal there. It is not a context function
itself, because a context function can only return content, and this returns
data you can filter and count.

Each entry is everything rookery's `#ideas()` gives you — `id`, `name`,
`title`, `text`, `label`, `tags`, `body`, `href`, `page`, `created` — plus `score`
and `kind`. Sorted TWO TIERS deep: every `kind: "name"` row (matched on id or title)
before every `kind: "body"` row (matched only on body text), best score first
within each tier, ties falling back to id order, so a build is reproducible.
`href` is `none` without rheo, since nothing mints note pages there; link to
`label(e.id)` instead, as above.

**`body-search: false` drops the second tier**, leaving ids and titles: no row
comes back `kind: "body"`, and a note findable only by a word buried in its own
prose stops being findable at all. That is a judgement about a particular
corpus, not a default worth picking — for a rookery whose notes are looked up
by name, a four-word query landing on the one note that mentions all four in
passing, above the note actually called that, is noise. The same switch is
carried through `#search-index`, `#search-bar` and `#search-modal`, where it
also stops shipping body text to the browser at all; see "Ids and titles only"
below.

**`tags: "phd"` narrows the corpus instead**, so `#search-ideas("", tags: "phd")`
is a static index of just the notes tagged `phd`. It changes what is searched,
not what the query matches; see "Scoping the corpus by tag" below.

**A leading `tags:` in the QUERY narrows it too**, on a different axis — the
reader's rather than the author's. `#search-ideas("tags:draft window")` keeps
the notes tagged `draft` and ranks those by the text query `window`, and the
same expression works typed into the bar or the modal. See "Filtering by tag"
below.

### What matches, and what doesn't

**id and title** match by **subsequence** — the note's better-scoring one of
the two. So "wnd" finds `windows`, and a note is findable both by the name you
type into `#window` and by the title you read on the page.

Scoring rewards, in rough order of weight: characters matched in a contiguous
run, a prefix match, matching near the start, and the note being close in
length to the query. That last one is why "window" ranks `windows` above
`window-depth` rather than tying them.

`-` and `_` fold to a space **on both sides**, so `flat-ids` is findable as
"flat ids" — and still as "flat-ids", because the query folds too.

**The body matches too, but by a different rule.** A subsequence match over a
2000-character body is close to useless — it matches almost every query
against almost every note, and the length term above collapses to zero for
all of them, so the surviving score is noise. `body-score` is instead an
**AND** match: split the (folded) query on whitespace, and EVERY term has to
appear somewhere in the body, or the note does not match on body at all — one
term missing is a miss, not a partial credit. Among notes that do match,
earlier and more frequent term occurrences score higher, and the whole phrase
appearing contiguously scores a bonus on top.

**A body match never outranks an id/title match** — that is the two tiers
above, not a blended number. A reader looking for a note by name should never
have it pushed below some other note that happens to mention the word six
times; a weighted sum only approximates that and needs constant retuning,
where two tiers say it plainly. `kind` on each result is what tells a caller
(and the modal's preview pane) which rule matched.

**A tag is never a search TERM**, on id/title or on body. A bare "phd" finds
the note *called* that, not the notes *tagged* with it. What tags do instead is
choose the corpus, by two routes that both run before anything is scored: the
author's `tags:` parameter (see "Scoping the corpus by tag" below) and a
reader's leading `tags:` expression in the query itself (see "Filtering by tag"
below). Neither turns a tag into something the query scores against.

**Accents are not folded**, on id/title or on body: "cafe" does not match
"Café". Fixing it means Unicode normalisation that the JavaScript half of this
package would have to reproduce character for character, and a rule that
disagreed with itself between the static list and the live bar would be worse
than one that is simply narrow.

No stemming and no stop words either, on either rule — a plural, a different
tense or a word like "the" has to be typed as it appears in the note.

`#fuzzy-score(hay, query)` and `#body-score(body, query)` are public too —
`none` for no match, otherwise an
integer. Rank something other than notes with it, or sort matches your own way,
without inventing a second rule that disagrees with the bar's.

## Filtering by tag

A query that OPENS with `tags:` is a **filter**, not a search term. Everything
up to the first unescaped space is a boolean expression over each note's own
tags, applied before a single score is computed; everything after it is an
ordinary text query over the notes that survived.

```
tags:draft window depth     among my drafts, ranked by "window depth"
tags:draft                  every draft, newest-dated first, undated by id
window depth                no prefix, no filter — unchanged
tags:                       an empty expression is no filter: everything
```

This is the READER's axis, typed into a bar or a modal. The `tags:`/`match:`
PARAMETERS on `#search-bar`, `#search-modal`, `#search-index` and
`#search-ideas` are the AUTHOR's, fixed at build time — see "Scoping the corpus
by tag" below. Both exist, both narrow before anything is scored, and they
compose: a reader's expression filters within whatever the parameter already
selected.

The rule is written twice, once per language — `parse-tag-query`/
`eval-tag-query`/`split-query` in `src/lib.typ` and `parseTagQuery`/
`evalTagQuery`/`splitQuery` in `src/rookery-search.js` — so `#search-ideas`
and the live bar answer the same query identically. `just parity` pins the two
over 21 cases in `test/parity.typ`, diffing the parsed expression itself as
data rather than only its final verdict.

### The grammar

`&` binds tighter than `|`, `!` binds tightest of all, and `()` groups:

```
tags:a&b                  tagged a AND tagged b
tags:a|b&c                a OR (b AND c) — `&` first, without parentheses
tags:(a|b)&c              the grouped form: (a OR b) AND c
tags:!draft               every note NOT tagged draft
tags:!(draft|todo)&note   tagged note, and neither draft nor todo
```

`!` is right-associative, which is what makes a stacked negation parse rather
than emit a `!` with nothing under it: `tags:!!draft` is `tags:draft`, and
`tags:!!!draft&note` is `tags:!draft&note`.

### Where the expression ends

At the **first unescaped whitespace**. What follows is the residual text query,
trimmed; repeated spaces inside it cost nothing, both matchers dropping empty
terms.

```
tags:draft   window  depth      residual "window  depth" — the extra spaces are dropped
tags:draft                      residual "", so every survivor sits in the name
                                tier at score 0 — the default browse order,
                                newest-dated first, undated by id
```

Only a **leading** `tags:` is recognised, case-insensitively (`TAGS:note`
works), and only leading whitespace is trimmed before that test. So a note
whose body contains the literal "tags:" can never be mistaken for a filter, and
a `tags:` appearing mid-query is just characters the text query matches.

### The escape set, and it is frozen

`\` takes the next cluster literally into the current atom. The characters that
need it are exactly `( ) | & !` and `\` itself:

```
tags:a\&b         the single tag `a&b`
tags:a\|b|c       the tag `a|b`, OR the tag `c`
tags:\(paren\)    the tag `(paren)`
tags:a\ b         the tag `a b` — an escaped space does not end the expression
```

**The set is frozen, and that is part of the contract rather than an
implementation detail.** Promoting some further character to an operator later
would silently change what queries already written mean — a tag containing it
would stop being addressable, and no error would say so. That sentence is why
`!` shipped in the first version instead of being added when someone wanted it.

### Prefix matching, and the honest consequence

An atom matches a tag **by prefix** on the folded form. `tags:note` matches
`note`, `notebook` and `notes` alike, and **there is no way to spell "exactly
note"**.

That is deliberate. The bar and the modal are incremental: with exact matching,
every keystroke of a tag until the last one shows an empty list, so a reader
typing `draft` would see nothing at all four times out of five.

The mitigation is legibility rather than precision — each row in the MODAL
shows that note's own tags as pills on a second line, so a `notebook` hit
explains itself instead of looking like a mystery. **The dropdown ships them
hidden**, and a site that wants the same mitigation in the bar writes one rule:

```css
.rookery-search-results .rookery-search-tags { display: flex }
```

See "Tag pills on a result row" below for why that is the default.

### Folding: `a-b`, `a_b` and `a b` are one tag

Atoms and tags both go through the same `_fold` the rest of the package uses —
lowercase, `-` and `_` read as a space — and on both sides, so all three of

```
tags:in-progress
tags:in_progress
tags:In\ Progress
```

match a tag written `in-progress`, `in_progress`, `In Progress` or `In-Progress`.
It follows that `a-b`, `a_b` and `a b` are the SAME tag as far as search is
concerned; no query distinguishes them.

### Nothing typeable is an error

**Parsing never fails.** A live search box types every prefix of a valid query
on the way to it — `tags:(a|` is what a reader has typed one keystroke before
`tags:(a|b)` — so an incomplete expression cannot be treated as a failure.
Every malformed form REPAIRS instead. MEASURED, these are the actual answers:

```
tags:(a|          unclosed group; the dangling `|` is skipped for want of
                  operands, so it matches what `tags:a` matches
tags:a&           dangling operator, the same skip: matches `tags:a`
tags:)a           unmatched close, discarded: matches `tags:a`
tags:a\           a trailing `\` has nothing to escape and is dropped: `tags:a`
tags:note&&draft  the doubled `&` collapses: matches `tags:note&draft`
tags:((note))     redundant groups: matches `tags:note`
tags:             no filter at all — every note matches
```

The parser does record WHY it repaired (`unclosed-open`, `unmatched-close`,
`trailing-backslash`) on the `repaired` field of its result. Nothing reads that
field yet; it is there for an affordance in the bar.

This holds on the Typst side too — `#search-ideas("tags:(a|")` returns matches
rather than failing the build. One lenient rule shared by both languages is
also the only version of this that could be parity-tested: two different error
paths cannot be diffed against each other.

### A tag is a predicate, never a scorer

A tag match adds **no third tier and no score bonus**, and leaves the two-tier
ranking above exactly as it was. Tags decide which notes are CANDIDATES; the
residual text decides how they rank. With no residual text there is nothing to
rank by: `fuzzy-score` returns 0 for an empty query, so every survivor lands in
the name tier at score 0 — and THAT tie breaks by date, newest first, undated
notes falling to the end in `#ideas()`'s own id order (the same default browse
order described above).

**Highlighting uses the residual only.** MEASURED in a browser, `tags:phd alpha`
marks "Alpha" in a title and "alpha" in an id and nothing else — the literal
`tags:` is an instruction, not something any note contains, so marking it would
highlight the query rather than the match. A bare `tags:draft` still opens the
dropdown, the raw input being non-empty, and marks nothing.

### What it costs

Filtering happens BEFORE scoring, which makes a tag query **cheaper** than a
bare text query rather than dearer: the pool the body tier walks shrinks before
it is walked. MEASURED in node over a synthetic corpus with 1200-cluster
bodies, per keystroke:

| corpus | `window depth` | `tags:note&draft` |
| --- | --- | --- |
| 500 notes | 1.734 ms | 0.096 ms |
| 5000 notes | 15.1 ms | 0.850 ms |

Parsing itself is 1-2 microseconds, which is why it does not show up in those
numbers.

**A negation is the exception**, keeping most of the corpus: `tags:!draft window
depth` costs the baseline, 13.2 ms at 5000 notes. No speedup, and no
regression either.

Typst-side a parse is about 60 microseconds, and a build parses once — the
split happens before the ranking loop rather than per row.

Carrying each note's tags in the JSON island costs about **18 bytes a note**.
MEASURED at 40 tagged notes, with bodies under the previous release's 1200-cluster prefix cap:
51.1 KB -> 51.8 KB, so +723 B, +1.4%. The per-note cost is unchanged now the cap
is a term budget; the percentage is larger, the rest of the row having shrunk.
**That is why there is no `tag-search: false` switch to match `body-search:
false`**: 18 bytes a note does not earn a knob, where `body-search: false`
removes the largest field in the row — a tenth of the island, measured above —
and settles a real per-project question about whether full-text hits are noise.

### The limits of a tag query

- **No way to express an exact tag match.** See prefix matching above:
  `tags:note` cannot be narrowed to exclude `notebook`.
- **A tag containing a space produces a broken class, here and in rookery
  alike.** `#idea` validates tags nowhere, so a tag written `my tag` already
  emits a two-class `idea-tag-my tag` in rookery's own output; the pills this
  package renders reproduce that rather than sanitising it. A package quietly
  disagreeing with rookery about what class a tag carries would be worse than
  reproducing a hazard rookery already has.
- **The whitespace test is each language's own `trim`**, and JavaScript trims
  U+FEFF where Rust does not. A tag expression containing a zero-width no-break
  space therefore ends in the browser and not in Typst. Stated for
  completeness: it cannot arise from typing.
- **Only a LEADING `tags:` is a filter**, so a note whose body contains the
  literal "tags:" is still findable by text. That is the intended trade — a
  filter that could begin mid-query would make the string unsearchable.

### Building your own UI on the same rule

`#parse-tag-query(src)`, `#eval-tag-query(rpn, tags)` and `#split-query(q)` are
public, and so are their ports `parseTagQuery`, `evalTagQuery` and `splitQuery`
on the `RheoRookerySearch` global — the same reason the ranking is exported
there. A site with its own search UI should run the reader's own rule rather
than fork it or write a second one that disagrees with the bar about what
`tags:!draft` means.

`split-query` is the entry point a UI wants: it returns `(rpn, text, repaired)`,
with `rpn: ()` for a query carrying no `tags:` prefix and `text` the residual to
rank and highlight by. `parse-tag-query` returns `(rpn, residual, repaired)` for
the expression alone. `eval-tag-query` expects tags **you have folded
yourself** — the expression's atoms are folded when parsed, and folding one side
only would make `in-progress` unfindable as "in progress". JavaScript exports
`fold` for it; the Typst `_fold` is private, so a Typst caller spells out the
same three steps: `lower(t).replace("-", " ").replace("_", " ")`.

## Scoping the corpus by tag: `tags:` and `match:`

This is the AUTHOR's `tags:`, a build-time parameter, and it is a different
thing from the reader's `tags:` expression in a query string — see "Filtering by
tag" above. The parameter decides what is in the corpus at all, on every page it
renders on; the reader's expression filters within that, at each keystroke.

The parameter narrows WHICH notes are searched. **It does not make the query
match tags** — ranking still looks at id and title, and at body text when
`body-search` is on, and never at a tag, whichever axis put a note in the pool.

Both parameters are rookery's own, passed straight through to its `#ideas()`:

- `tags` — `none` (the whole rookery; the default), one tag as a string, or an
  array of tags.
- `match` — `"any"` (the default) or `"all"`. Given an array, `"any"` keeps a
  note carrying at least one of those tags, `"all"` only a note carrying every
  one of them.

`#search-ideas`, `#search-index`, `#search-bar` and `#search-modal` all accept
the pair. `tags: none` indexes the whole rookery exactly as it did before this
existed, so no existing call changes behaviour.

**The predicate is not reimplemented here.** This package does not filter by tag
itself and does not import `#tags-of`: rookery owns the rule — the same one
`#window(tags: …)` applies — and this is a pass-through. One rule written twice
drifts, and it would drift silently, a bar and a window quietly disagreeing
about what "tagged phd" means.

Two things follow from narrowing in Typst rather than in the browser. An excluded
note is never scored, and never pays for its plain-text body conversion either,
because `#ideas()` filters before it builds each row. And the JSON island holds
only the notes that survived, so a scoped bar ships a smaller island — inline on
every page, so the saving is multiplied by the page count, the same arithmetic as
the `body-search: false` measurement below.

The island DOES carry each note's own `tags`, and that is the reader's axis
rather than this one: the parameter's selection is settled in Typst, but a
reader's `tags:` expression is evaluated per row in the browser, so the field
has something left to read it. It costs about 18 bytes a note — see "What it
costs" above.

### A bar over one tag

```typst
#import "@rheo/rookery-search:0.6.0": search-bar
#search-bar(tags: "phd", placeholder: "Search phd notes")
```

That bar finds the notes tagged `phd` and nothing else. A note without that tag
is not in its island at all, so no query typed into it can reach one.

### Two bars, two tags, one page

Two scopes are two corpora, so they are two islands — `elem-id:` names them, and
both bars keep `index: true`:

```typst
#search-bar(tags: "phd", elem-id: "phd-index", placeholder: "phd notes")
#search-bar(tags: "trip", elem-id: "trip-index", placeholder: "trip notes")
```

Nothing new is needed for this. `elem-id:` already names the island a bar reads
(the wrapper's `data-rookery-search` carries that name), and the markup carries
no other id, so the pair coexists on one page. Note how it differs from the
`index: false` case below: two bars over the SAME corpus share one island and the
second passes `index: false`, where two bars over DIFFERENT corpora are two
islands and each emits its own.

`match: "all"` scopes to an intersection instead of a union:

```typst
#search-bar(tags: ("phd", "draft"), match: "all", elem-id: "phd-draft-index")
```

## The corpus in the browser

A compile-time search is not a search box. For that the browser needs the
corpus, and `#search-index()` puts it on the page as JSON:

```html
<script type="application/json" id="rookery-search-index">[{"id":"idea:flat-ids","name":"flat-ids","text":"Flat ids, and why","tags":["phd"],"body":"Flat ids are …","href":"ideas/flat-ids.html"}, ...]</script>
```

One row per note: `id`, `name`, `text` (the plain-text title, `""` when there
is none), `tags` (the note's own tag array — **the key is absent** when it has
none, rather than written as `[]` per row), `body` (the plain-text body, `""`
when there is none) and `href`.
The field is `text` and not `title` deliberately — it is the same name,
meaning and type as `search-ideas` returns, and a name that meant content in
Typst and a string in JSON is how a consumer gets it wrong.

**`tags:`/`match:` decide which notes reach the island**, and the `tags` field is
what a READER's own `tags:` expression is evaluated against, per row, once they
are there — the two axes again, and see "Filtering by tag" above. The author's
selection is settled in Typst; the field is the reader's to filter with.

**`body` is capped, not the whole note.** `search-index`'s `body-chars`
parameter (1200 by default, `none` for no cap) truncates each row's body to
that many CLUSTERS before it goes into the JSON, because this island is
**inline in every page**, not fetched once. MEASURED for rookery.ohrg.org: its
`content/*.typ` sources total ~31 KB across roughly 40 notes, so an uncapped
index costs on the order of 20-25 KB of JSON on every page (it compresses
well, being prose). A note longer than the cap stays findable by its opening,
and fully findable through the Typst-side `#search-ideas`, which never
truncates. No separate fetched JSON file, on purpose: rheo emits pages from
typst with no supported way to emit a standalone asset alongside them, so an
inline island is what the package can actually produce — and it also works
from `file://` with no fetch.

### The corpus is compressed once per build, not once per page

`#search-index` runs on every page that carries the island, and the corpus pass
behind `body-search` costs far more than the island's own JSON. Under rheo the
whole compression is hoisted into this package's `.marrow.typ`, which runs ONCE
at the bundle root, and every page reads the finished terms back out of a state
keyed by note id.

MEASURED on a synthetic rookery — 200 notes of 1500 words, 40 vertebrae, one
`#search-modal` each:

| | build |
| --- | --- |
| before, compressed per page | 10.9s |
| after, compressed once | 6.3s |
| `body-search: false` (no corpus pass at all) | 1.0s |

The island's bytes are identical either way — this is a timing change and
nothing else. What is left is the one corpus pass, which is the irreducible
part.

Two cases fall back to compressing inline, and both are correct rather than
merely tolerated:

- **Without rheo.** There is no bundle root, the marrow never runs, and the
  state keeps its empty default. Plain `typst compile` behaves exactly as it
  did.
- **A tag-filtered index**, `#search-index(tags: "post")`. Note count and
  document frequency are properties of the CORPUS, so a filtered index's terms
  are genuinely different terms and have to be computed over the notes it
  selected. Same for a non-default `body-terms`/`df-ceiling`, which the marrow
  does not know to precompute.

### Ids and titles only: `body-search: false`

`body-search: false` leaves the `body` field OUT of every row, so the island
carries `id`, `name`, `text`, `href` and a tagged note's `tags` and nothing
else — a reader's `tags:` filter keeps working with body text gone, having never
read that field. It is the one switch
for "search this rookery by name, not full text", and it is accepted by
`#search-ideas`, `#search-index`, `#search-bar` and `#search-modal` alike —
configure it where you invoke the package in your own files:

```typst
#import "@rheo/rookery-search:0.6.0": search-modal
#search-modal(placeholder: "Search weeknotes", body-search: false)
```

MEASURED on weeknotes.ohrg.org (56 indexed notes, 69 output pages): the island
goes from **54,610 bytes to 5,456**, a tenth of the size, and the whole build
from 17 MB to 14 MB — the island ships inline on every page, so its bytes are
multiplied by the page count. The `body-chars` cap bounds that cost; this
removes it.

No JavaScript counterpart is needed, and that is by construction rather than
luck: the browser reads a missing `body` as `""`, and the body matcher returns
no score for an empty haystack, so no row can reach the body tier.

Two consequences, both intended. A note findable only by a word in its body
becomes unfindable — that is the point. And the modal's keyword-row fallback is
built from this same field, so with it gone the pane shows "No preview" wherever
it cannot fetch the note's own page: `file://`. Over http the fetched preview is
unaffected, so a served site loses nothing but the bytes.

The hrefs are **relative to the page the call sits on**, so an index emitted
from a site's shared template comes out right on a nested page too — `../ideas/…`
there, `ideas/…` at the root. The rows are id-ordered, so the island is
byte-stable between builds and a diff of the output means something.

`#search-bar()` emits this for you; call it directly only when you are building
your own UI, or when several bars share one index. Reading it is one line:

```js
const rows = JSON.parse(
  document.getElementById("rookery-search-index").textContent,
);
```

Rank those rows with `RheoRookerySearch.score(hay, query)` — the same rule
`#fuzzy-score` applies at compile time, ported. Use it rather than writing a
second one, so a custom UI and the built-in bar agree about what "best match"
means.

**HTML under rheo, and nothing else.** Every row needs an `href` and only rheo
mints the pages those point at, so under plain `typst compile` the rows filter
to nothing and no island is emitted at all — rather than shipping a browser a
list of `null`s. Under a paged or EPUB target nothing is emitted either: a
`<script>` is meaningless in a PDF, and EPUB readers may refuse or strip it.

## The search bar

`#search-bar()` is the whole UI: the island, an input, and a results list the
package's JavaScript wires together.

```typst
#import "@rheo/rookery-search:0.6.0": search-bar
#search-bar()
#search-bar(placeholder: "Find a note", limit: 12, class: "topbar-search")
#search-bar(index: false)   // a second bar, sharing the first one's island
```

- `placeholder` — the input's placeholder, and its `aria-label`.
- `limit` — how many results to show. A positive integer; 8 by default.
- `class` — appended to the wrapper's own `rookery-search` class, so a project
  can target one bar without touching the rest.
- `index` — emit the JSON island alongside the bar. `true` by default; pass
  `false` on every bar after the first on a page, so one island serves them all.
- `body-chars` — forwarded to `#search-index`'s cap on each row's body text, in
  clusters. 1200 by default; `none` for no cap.
- `body-search` — forwarded to `#search-index`. `false` leaves body text out of
  the island entirely, so the bar searches ids and titles only. See "Ids and
  titles only" above.
- `tags` / `match` — forwarded to `#search-index`, which forwards them to
  rookery's `#ideas()`. They scope which notes are in this bar's island at all;
  they do not make the query match tags. `tags: none` (the default) indexes the
  whole rookery. See "Scoping the corpus by tag" above.

**It is rheo only, and it emits nothing at all without it.** Twice over: the
script comes from this package's `js_scripts` manifest key, which only rheo
reads, and the results link to minted note pages, which only rheo produces. A
bar without both could only ever be a dead input, so rather than render one it
renders nothing — the same way the index does. Without rheo, use
`#search-ideas` and render a static list; that path is not a consolation prize,
it is the supported one.

### Put it anywhere, more than once

The bar emits **phrasing content only** — a `<span>` wrapper around an `<input>`
and a `<span role="listbox">`, never a `<div>` or a `<ul>`. That is deliberate:
a `<div>` inside a paragraph is invalid HTML, and it would rule out exactly the
placements this is for. Put a bar mid-sentence, in a heading, in a table cell,
in your site's topbar.

Nor does the emitted markup carry any `id`, apart from the island's. Markup with
a hardcoded id cannot appear twice on a page; the listbox ids are assigned at
runtime instead, and `aria-controls` is wired to them there. So a second bar
costs you `index: false` and nothing else.

### The classes it emits

Style them from your own stylesheet; they are the contract.

| | |
| --- | --- |
| `.rookery-search` | the wrapper span (plus your `class:`) |
| `.rookery-search-input` | the `<input type="search">` |
| `.rookery-search-results` | the listbox span |
| `.rookery-search-row` | one result, an `<a>` |
| `.rookery-search-title` | the note's title, or its name when untitled |
| `.rookery-search-id` | the note's full id, bracketed — `[idea:etal]` |
| `.rookery-search-tags` | a tagged row's second line of pills — `display: none` outside the modal |
| `.rookery-search-tag` | one tag pill, also carrying rookery's own `idea-tag-<tag>` |

The wrapper also carries `data-rookery-search-open="true|false"`, flipped as the
results open and close — that is the hook to show and hide the list, so the CSS
does not have to guess at emptiness.

### Working it from the keyboard

The dropdown is reachable without a pointer, and by the same keys as the modal —
one search, one set of keys:

| key | what it does |
| --- | --- |
| `↓` / `Ctrl+N` | move down the results |
| `↑` / `Ctrl+P` | move up |
| `↵` | open the highlighted result |
| `esc` | clear the input, close the list, blur |

**Nothing is highlighted until you ask.** The dropdown opens under a field you
are still typing in, so pre-selecting its first row would claim `↵` goes
somewhere before you had looked; the first `↓` lands on the first result. The
modal is the other way round — it opens on a selected row, because its preview
pane needs something to show. A fresh query clears the highlight rather than
keeping the old index.

The selection is **clamped, never wrapped**: arrowing past the last result keeps
the last result. In a list whose length changes on every keystroke, a wrap loses
your place.

`↵` with nothing highlighted is **left alone** — a bar can sit inside a form, and
swallowing a submit you did not ask us to swallow is worse than doing nothing.
The arrow keys are only taken while the list is open; with it shut they are the
text caret's again.

For a screen reader, the input carries `aria-activedescendant` naming the
highlighted row (ids assigned at runtime, as the listbox's is) and each row
carries `aria-selected`, so the current option is announced rather than merely
drawn. The highlight itself is `data-rookery-search-selected="true"` on the row,
styled with `--rookery-search-hover` — the same rule the modal uses, so the two
surfaces cannot drift apart. Hovering does **not** move the keyboard highlight
here, unlike in the modal, where hovering drives the preview pane.

Clicking anywhere outside the bar closes it too, but **leaves what you typed in
the field** — dismissing a dropdown is not the same as abandoning a search. It
stays shut while that query sits there, including if you click back into the
input; typing again is what brings it back, being the one gesture that
unambiguously asks for it.

Result titles are set with `textContent`, never `innerHTML`, so nothing in a
note title can inject markup.

The dropdown is **wider than the input** by default, and deliberately: a row
carries a title and an id on one line, and an input sized for typing into is
too narrow to hold both without the title wrapping against its own id. It sizes
to its widest row, never narrower than the input and never wider than
`--rookery-search-max-width`. It hangs from the input's left edge and grows
rightward; for a bar at the right-hand end of a header, flip it with
`left: auto; right: 0`.

### Styling it: your CSS always wins

The package's default styling is thin — enough that the input and its dropdown
read correctly out of the box, and no fonts, sizes or page colours.

**Every rule it ships lives in a cascade layer called `rookery-search`, and that
is what guarantees you can override it.** rheo links a package's stylesheet
*after* the project's own, so on equal specificity the package would win every
tie and there would be no "later" for you to write your rule in. Layers invert
that: an unlayered rule anywhere in your stylesheet beats a layered one whatever
its specificity or position. So this is all it takes, in your own `style.css`,
even though it is linked first:

```css
.rookery-search-input { border: 2px solid red; }
```

No `!important`, no specificity games, no `:where()`. If you use layers
yourself, note that unlayered still beats layered — keep your overrides
unlayered, or order your layers after `rookery-search`.

For the common cases you do not need a rule at all, only a property:

```css
.rookery-search {
  --rookery-search-hover: rgb(0, 128, 0);
  --rookery-search-width: 24em;
}
```

| property | default |
| --- | --- |
| `--rookery-search-fg` | `inherit` |
| `--rookery-search-bg` | `white` |
| `--rookery-search-border` | `rgba(0, 0, 0, 0.25)` |
| `--rookery-search-radius` | `4px` |
| `--rookery-search-hover` | `--idea-link-color`, else `rgba(128, 0, 255, 0.12)` |
| `--rookery-search-id-color` | `--idea-id-color`, else `gray` |
| `--rookery-search-width` | `16em` |
| `--rookery-search-max-width` | `28em` (a ceiling; the dropdown hugs its longest row below it) |
| `--rookery-search-max-height` | `20em` |
| `--rookery-search-z` | `1000` |

The last two colours fall back to **rookery's own theme properties** before
their literals. So a site that sets `#show: rookery.with(theme: (link-color:
…))` gets a search bar tinted to match its notes without configuring anything
twice — an agreement made in CSS, by name, so the two packages stay uncoupled
in Typst.

## The search modal

`#search-bar` is not deprecated by this — it is the inline, in-page
affordance, and stays exactly what it was. `#search-modal` is the site-wide
one: a trigger button (for a topbar, typically) that opens a full-height
telescope-style overlay with a results list and a preview pane side by side.
One sentence to tell them apart: reach for the bar when the search belongs
INSIDE a page, and for the modal when it should be reachable from EVERY page.
Both share one island and one ranking rule, so a site is free to offer both
without them ever disagreeing about what "best match" means.

```typst
#import "@rheo/rookery-search:0.6.0": search-modal
#search-modal()
#search-modal(placeholder: "Search ideas", limit: 30, trigger-label: "Search")
#search-modal(trigger: false)   // markup only; open it from your own button
```

- `placeholder` — the input's placeholder, and its `aria-label`.
- `limit` — how many results to show. A positive integer; 30 by default — a
  modal is a full-height list rather than a dropdown under an input, so it
  does not need the bar's smaller cap.
- `class` — appended to the dialog's own `rookery-search-modal` class.
- `trigger` — emit the trigger button. `true` by default; `false` for markup
  only, when you want to open the dialog from your own button.
- `trigger-label` — the trigger's `aria-label` ("Search" by default).
- `index` / `elem-id` / `body-chars` / `body-search` / `tags` / `match` — the
  same parameters `#search-bar` takes, forwarded to `#search-index` unchanged.
  With `body-search: false` the modal searches ids and titles only, and its pane
  shows "No preview" rather than a keyword row wherever the note's page cannot be
  fetched. With `tags:` set, a site-wide modal in a shared header is scoped to
  that tag's notes on every page it renders on.

There is no knob for the preview pane, because the preview costs the build
nothing to produce: it is the note's own minted page, fetched when a reader
selects the row. See "The preview pane fetches the note's page" below.

**It is rheo only, and it emits nothing at all without it** — the same two
reasons as the bar: the script comes from this package's `js_scripts`, and the
results link to minted note pages.

### What it emits

A trigger button and a `<dialog>`, found and paired by island name — the
trigger's `data-rookery-search-modal` equals the dialog's
`data-rookery-search`, the same attribute `#search-bar` uses to find its own
island. So several triggers can open one modal, and nothing needs a hardcoded
id. **A page should carry at most one modal per island name**; the script
wires the first matching dialog.

| | |
| --- | --- |
| `.rookery-search-trigger` | the trigger `<button>` |
| `.rookery-search-icon` | its magnifier `<svg>` |
| `.rookery-search-key` | its `Ctrl K` hint, `aria-hidden` |
| `.rookery-search-modal` | the `<dialog>` |
| `.rookery-search-modal-inner` | column: input, panes, hint |
| `.rookery-search-panes` | the two-column grid |
| `.rookery-search-list` | the left pane, one `.rookery-search-row` per hit |
| `.rookery-search-preview` | the right pane |
| `.rookery-search-hint` | the `↑↓ navigate · ↵ open · esc close` line |

The JSON island, the trigger and the dialog: that is the whole of it. Nothing
is emitted for the preview pane — see below.

A `<dialog>` and `showModal()`, deliberately, rather than a hand-rolled overlay
`<div>`: focus trapping, page inertness behind it, `::backdrop` dimming and
Escape-to-close all come for free, and it renders in the browser's TOP LAYER,
which escapes every stacking context — including a sticky, z-indexed site
header that would trap a plain absolutely-positioned overlay underneath it.

### Behaviour

**`Ctrl+K` / `Cmd+K` opens the first modal on the page from anywhere** —
ignored while typing in another input, textarea or contenteditable element, so
a reader's literal keystroke still lands where they meant it to. Clicking a
trigger opens its own paired dialog directly.

**An empty query lists the whole corpus**, unlike the bar's dropdown, which
stays shut until you type: a full-height modal is a browsable index as much as
a search box, the way `nvim-telescope`'s own pickers behave with nothing
typed.

Arrow keys (and `Ctrl+N`/`Ctrl+P`) move the selection, clamped at the ends —
no wrapping. Hovering a row selects it too, so pointer and keyboard always
agree on what the preview is showing. Enter opens the selected row; Escape or
a click on the backdrop closes the dialog, leaving the query in place so a
reopen (`Ctrl+K` again, or the trigger) resumes exactly where you left off.

The bar's dropdown takes the **same keys**, off the same implementation — see
"Working it from the keyboard" above for the two places the surfaces differ on
purpose (the modal opens on a selected row and lets hover move it; the dropdown
does neither).

### The preview pane fetches the note's page

**The pane shows the matched note's REAL content** — links, styling, footnotes,
citations, figures, a real syntax-highlighted `<pre><code>` for a note that
quotes any — and it gets it by `fetch`ing that note's own minted page
(`ideas/<slug>.html`, which `@rheo/rookery` already emits) the first time the
row is selected, then holding it for the rest of the session. Everything
between the fetched page's `<h1 class="idea">` and its `<footer
class="idea-footer">` comes across — the note, its footnotes and its
references, not the heading the result row already shows and not the page's
Context/Backlinks navigation. Relative links and image sources are resolved
against the note's own URL on the way in, so they still point where they did.
Every matched term is wrapped in `<mark>` by walking the fetched content's own
text nodes, never `innerHTML`.

**Why fetch rather than build it in.** An earlier version of this package
emitted a hidden container holding `#idea-body`'s rendering of every note, and
because `#search-modal` lives in a site's header, that ran on every page:
`notes × pages` Typst renders. MEASURED on a 57-note, 69-page site, that cost
14.6s against a 2.65s baseline, and 312 MB of output (301 MB of it base64, Typst's
HTML export inlining every `#image`). The cost was per CALL, not per byte —
rendering the same bodies near-empty at `limit: 1` still cost 10.3s — so no
truncation knob could have fixed it. A page rheo already emits costs the build
nothing, which is why there is no `preview-limit` any more and why figures can
now reach the pane at all.

**The trade: rich previews need http.** `fetch` does not work from `file://`, so
a build opened straight off disk falls back to a **keyword row** built from the
island's own `body` field — that note's most distinctive terms, in the weight
order the index put them in, most distinctive first, each one its own chip. Terms
the query matched are marked with the same `<mark>` a result row uses, and hoisted
to the front so the cap cannot cut the matched one off; the row shows twelve at
most, because the field can run to dozens and a wall of boxes is not a preview.
A short muted line above it says the note's page could not be loaded, so a bag of
words is never left looking like the intended rendering.

That fallback is what the pane shows whenever the request cannot succeed: a
`file://` build, a note whose page 404s, a hit with no minted page at all. A note
with no terms at all shows a muted "No preview" line instead of an empty row.
Nothing breaks in any of these cases; the pane is simply plainer. The row is
`.rookery-search-keywords` with a `.rookery-search-keyword` per chip, both styled
in the package's layer like everything else here.

It is chips rather than a sentence because the field is no longer prose. It used
to be a prefix of the note's body and the pane excerpted it, centred on the
match; since the index began carrying compressed terms there is nothing to
excerpt, and setting those terms as running text reads as debug output that
leaked into the UI. `snippet` — the excerpt window — is gone from
`src/rookery-search.js` with it.

**Nothing is shown before the fetch lands.** While a request is in flight the pane
holds a small muted spinner in its corner and no text — the fetched rendering is
the first and only text it shows. The excerpt used to render synchronously first,
which meant every selection visibly reflowed from plain text to the same note as
real content a few milliseconds later: a worse rendering of the thing that was
about to replace it.

A query that matches NOTHING is a different state again, and the pane says so:
a muted "No match found" line, rather than the previous query's preview left
sitting beside an empty result list.

### Styling: the telescope layout, and the same escape hatch

The modal's rules live in the same `@layer rookery-search` as the bar's, so the
same unlayered-rule-always-wins escape hatch applies — see "Styling it: your
CSS always wins" above. It reuses the bar's `--rookery-search-fg`/`-bg`/
`-border`/`-radius`/`-hover`/`-id-color` properties, and adds:

**The preview pane's fetched content styles itself, mostly for free.** A note
lifted out of its page arrives wrapped in rookery's own `.idea-window
.idea-window-plain` pair, wearing the theme custom properties the minted page
set on its `<h1>` — so link colours, raw/code styling and footnote layout come
from `@rheo/rookery`'s stylesheet, in that note's own theme, including a
project's `#show: rookery.with(theme: (...))`. `.idea-window-plain` is
rookery's own modifier for "not a box": it strips the left accent rule and
hover tint rookery.css draws around an actual `#window`, because a search
preview is the pane's own content, not a window transcluded onto a page, and
should not draw a second box inside the pane's first. Images are held to
`max-width: 100%` — Typst writes literal `width`/`height` attributes, and a
figure at its intrinsic size would overflow the column.

| property | default |
| --- | --- |
| `--rookery-search-modal-width` | `min(56rem, calc(100vw - 2rem))` |
| `--rookery-search-modal-height` | `min(32rem, calc(100vh - 8rem))` |
| `--rookery-search-backdrop` | `rgba(0, 0, 0, 0.5)` |
| `--rookery-search-mark` | `--idea-link-color`, else `rgba(128, 0, 255, 0.25)` |
| `--rookery-search-tag-color` | a tag pill's text: `--idea-tag-color`, else `--rookery-search-id-color`, else `--idea-id-color`, else `gray` |
| `--rookery-search-tag-bg` | that pill's fill: `--idea-tag-bg`, else a 14% `currentColor` tint (`rgba(128, 128, 128, 0.18)` without `color-mix`) |
| `--rookery-search-tag-size` | that pill's text size, a factor of the row's own — `0.85em`, a chosen default and not a measurement |
| `--rookery-search-tag-radius` | that pill's corners — `999px` is a pill, `0` is a rectangle |
| `--rookery-search-tag-gap` | the space between two pills on a row — `0.3em` |

Below a 40em (≈640px) viewport width the preview pane and the `Ctrl K` hint
both disappear and the list takes the full width — a preview column that
narrow shows about four words and is worse than none. That breakpoint is a
literal in the package's CSS, not a custom property (a `@media` condition
cannot read one); a site wanting a different breakpoint overrides the whole
`@media` block, unlayered, like any other rule here.

### Tag pills on a result row

A note that has tags gets a **second line** on its result row, beneath the title
and the bracketed id: one filled, fully rounded pill per tag, in the author's own
tag order. In the **modal's list only**, and only for a note that has tags — an
untagged row stays one line tall, so the modal's fixed-height list keeps its
result count.

The dropdown's DOM carries the same pills and hides the container, because the
row builder is shared between the two surfaces on purpose: building rows two ways
is exactly what that sharing prevents, and visibility is something CSS can
express without breaking it. One rule turns them on in the bar:

```css
.rookery-search-results .rookery-search-tags { display: flex }
```

That is not the default because a dropdown is a few titles hanging under an
input, and doubling every row's height there is a cost the modal's fixed-height
two-pane list does not pay.

**One shape at one size, colour the only difference between tags.** A pill reads
as a discrete thing in a list where every other line is prose. It is
deliberately not the shape of `.rookery-search-keyword` in the preview pane —
that is an unfilled `--rookery-search-radius` rectangle with a border — because
the two are different KINDS of thing (a keyword is a term lifted out of the
note's compressed body, a tag is something the author wrote) and they never
appear in the same pane.

Every pill also carries rookery's own `idea-tag-<tag>` class alongside
`.rookery-search-tag`, the same class rookery puts on a note's heading and box.
So per-tag styling written for a note's own page applies in the modal with no new
selectors — and that, rather than a custom property per tag, is the intended way
to colour tags by kind. Pill text is set with `textContent`, never `innerHTML`,
like every other string this package renders.

**A tag themed in rookery colours its chip here too.** `theme: (tags-color:
(draft: rgb("#3366ff")))` in `#show: rookery.with(..)` is delivered as a
generated `.idea-tag-draft` rule setting `--idea-tag-bg` and `--idea-tag-color`,
and this package's chip reads both — so a chip picks the colour up even though
JavaScript inserts it long after Typst has run, because the rule matches the
class the chip already wears. Precedence, in order: `--rookery-search-tag-bg` /
`--rookery-search-tag-color`, which a project sets for EVERY chip in the modal,
still win; a rookery-themed tag comes next; this package's own defaults last. A
project that wants uniform chips keeps setting the `--rookery-search-tag-*`
properties and sees no change.

The shape is not this package's invention.
[hacker-archives](https://ficarelli.github.io/hacker-archives/) shipped these
chips in its own stylesheet before the package had any, and its `.listing-tag`
is where the defaults above were taken from (its two pinks stayed its own).

## `#panel` — a faceted filter over a projection

The bar and the modal rank the whole corpus against a query and pop a dropdown.
A panel does something else: it filters a list that is **already on the page**, by
facets you DECLARE as a `tag-index` projection, and it reorders that list as you
type.

```typst
#import "@rheo/rookery:0.6.0": ideas, tag-index
#import "@rheo/rookery-search:0.6.0": panel

#let INDEX = tag-index((
  sort:  (family: "sort-"),
  state: (from: state-of),
))

#context panel(
  rows: ideas(tags: "submission", index: INDEX),
  facets: ("sort", "state"),
  sort: "deadline",
  visible: 5,
  noun: "submissions",
  render: r => [#r.label],
)
```

**PANELS TAKE AN INDEX, THEY NEVER BUILD ONE.** Build one projection per page and
pass the projected rows to everything on it. A self-building panel would put back
the very cost `tag-index` exists to remove — a project with four widgets on one
page was opening each with its own `#tag-data()` walk to read a handful of fields.

**NO JSON ISLAND.** Every faceted field rides as a `data-<field>` attribute on the
row carrying it, so the payload and the markup cannot disagree — and with no
JavaScript the rendering is a complete readable list rather than an empty container
waiting to be filled. The projection's scalar guarantee is exactly what makes that
generic instead of hand-written per widget.

That guarantee is enforced HERE, at the attribute boundary, and the message names
the field:

```
panel field `stage` holds content, which cannot become an HTML attribute. A
faceted or sorted field must be a scalar — project it through `tag-index(..)`
first, and note that `ideas(values: true)`'s `tags-dict` is for Typst-side
rendering only.
```

That is the division: `ideas(values: true)` may carry arbitrary values for
Typst-side rendering, and this is where such a value would otherwise be
stringified into an attribute and read back as nonsense.

### The rules it follows

- **Pills are one per value a listed row actually has**, never one per value the
  vocabulary permits. A pill for a value nothing carries is a filter that could
  only ever return nothing.
- **Within a facet the values OR; across facets they AND.** An empty set is
  unconstrained, which is what makes "no pills pressed" show everything rather
  than nothing.
- **`visible:` is a SCROLL CAP, not a data cap.** Every row stays in the markup and
  the count rides as a CSS custom property. A consuming site had capped its list
  and hidden the rest; its own comment records why that was abandoned — it "made
  the box a preview of the corpus rather than the corpus", and you could not reach
  the thirty-third row without narrowing the query enough to lift it into the top
  five, which you could not do if you did not know its name.
- **A hidden row uses the `hidden` ATTRIBUTE, not a class**, which is what tells
  assistive technology the row is gone rather than merely invisible.
- **`sort:` orders by a projected field, unset LAST.** A missing date is not an
  early one, and an undated row floating to the top of a list sorted by deadline
  reads as urgent when it is merely unset. A date projected with `stamp: true` is a
  zero-padded `[year][month][day]` string, so this is a plain string sort in date
  order.
- **Ids are generated at runtime**, so two panels on one page both work. Markup
  carrying a hardcoded id cannot be placed twice.

### Without JavaScript

The container is emitted with `data-panel-ready="false"` and the stylesheet hides
the input, the pills and the scroll cap while it says so. What is left is an
ordinary complete list of every row — the chrome that would do nothing never
appears. On a paged or EPUB target the same rows render as a Typst list.

### What it replaced

One fuzzy subsequence scorer was being written three times across two packages and
a consuming site: `src/score.js` here, `todo-search.js` in `@rheo/rookery-todos`,
and a site's own copy whose comment said outright that it was "Ported from
`todo-search.js`". Above them sat three near-identical Typst halves, each existing
because `#todos-search` renders its pill row internally with no hook to add a facet
to it.

`#panel` closes both gaps: facets are declared rather than baked in, and a DERIVED
value reaches a facet through a projection. `panel.js` imports `score` rather than
porting it a fourth time.

## Working on it locally

Unlike rookery, this package is **built**. `typst.toml` points at `dist/`, and
`dist/` is produced by vite:

```sh
cd rookery-search/0.6.0
just build          # pnpm install && pnpm run build
```

That copies `src/lib.typ` and `src/rookery-search.css` into `dist/` unchanged
and bundles `src/rookery-search.js` into `dist/lib.js`.

**Editing `src/` does nothing until you rebuild.** This is the one place
rookery's habits mislead: there, `src/` *is* the published package and an edit
is live immediately. Here the loop is edit `src/`, `just build`, then rebuild
the consuming project. `dist/` is a build artifact and is gitignored.

### Keeping the two copies of each ranking rule honest

Each ranking rule exists twice: `fuzzy-score`/`score` for id and title, and
`body-score`/`bodyScore` for the body — a Typst copy for the compile-time
search, a JavaScript copy for the live bar and modal. Two implementations of
one rule drift silently — a static list and a search box would simply start
ranking differently, and nothing would fail.

There is no longer an exception. `snippet`, the excerpt window, was one — no
Typst counterpart and none wanted, a static listing showing titles rather than
excerpts — and it went when the preview's plain-text fallback became a keyword
row, which needs no ranking of its own: the terms arrive already in weight order
from the index.

```sh
just parity
```

feeds each list of cases through both languages and diffs every score, failing
loudly when they disagree. The cases live in `test/parity.typ`, as labelled
metadata arrays; extend them when you extend a rule, and change both copies in
the same commit. It needs no build — the fixture imports `src/` on both sides.

The `tags:` parser is the one pair whose output is not a number, and it is
diffed the same way: `<tag-parity>`'s 21 cases compare the parsed expression as
a flattened RPN string, the residual text, and one boolean per fixed tag set —
all three, because a parser agreeing only on the final verdict could still have
drifted on precedence or on where the expression ended. That is why the parser
is shunting-yard and emits a token array; see "Filtering by tag" above.

To develop against a live rheo project, symlink the package into the Typst
package cache:

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo/rookery-search
```
