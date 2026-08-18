# @rheo/rookery-search

Fuzzy search over the notes in a [`@rheo/rookery`](../../rookery/0.3.0) — by
id and title, and by full text — a Typst primitive that ranks them, a JSON
index of the corpus, an inline search bar, and a site-wide overlay modal.

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
#import "@rheo/rookery:0.3.0": idea, rookery
#import "@rheo/rookery-search:0.3.0": search-bar
#show: rookery

#search-bar()
```

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

## Searching, without JavaScript

`#search-ideas(query)` ranks the corpus and hands you the matches as data. It
is pure Typst — no rheo, no JavaScript, nothing in the browser — which is why
it is a layer of its own rather than something the search bar hides inside.

```typst
#import "@rheo/rookery-search:0.3.0": search-ideas
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
`title`, `text`, `tags`, `body`, `href`, `minted`, `updated` — plus `score` and
`kind`. Sorted TWO TIERS deep: every `kind: "name"` row (matched on id or title)
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
tags:draft                  every draft, in id order
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
                                tier at score 0, in id order
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
rank by, and no special case is needed for it: `fuzzy-score` returns 0 for an
empty query, so every survivor lands in the name tier at score 0 and the stable
sort leaves them in the id order `#ideas()` gave.

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
MEASURED at 40 tagged notes, with bodies under 0.2.0's 1200-cluster prefix cap:
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
#import "@rheo/rookery-search:0.3.0": search-bar
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

### Ids and titles only: `body-search: false`

`body-search: false` leaves the `body` field OUT of every row, so the island
carries `id`, `name`, `text`, `href` and a tagged note's `tags` and nothing
else — a reader's `tags:` filter keeps working with body text gone, having never
read that field. It is the one switch
for "search this rookery by name, not full text", and it is accepted by
`#search-ideas`, `#search-index`, `#search-bar` and `#search-modal` alike —
configure it where you invoke the package in your own files:

```typst
#import "@rheo/rookery-search:0.3.0": search-modal
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
#import "@rheo/rookery-search:0.3.0": search-bar
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

Escape clears the input, closes the list and blurs. Clicking anywhere outside
the bar closes it too, but **leaves what you typed in the field** — dismissing a
dropdown is not the same as abandoning a search. It stays shut while that query
sits there, including if you click back into the input; typing again is what
brings it back, being the one gesture that unambiguously asks for it.

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
#import "@rheo/rookery-search:0.3.0": search-modal
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
| `--rookery-search-tag-color` | a tag pill's text: `--rookery-search-id-color`, else `--idea-id-color`, else `gray` |
| `--rookery-search-tag-bg` | that pill's fill: a 14% `currentColor` tint (`rgba(128, 128, 128, 0.18)` without `color-mix`) |
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

The shape is not this package's invention.
[hacker-archives](https://ficarelli.github.io/hacker-archives/) shipped these
chips in its own stylesheet before the package had any, and its `.listing-tag`
is where the defaults above were taken from (its two pinks stayed its own).

## Working on it locally

Unlike rookery, this package is **built**. `typst.toml` points at `dist/`, and
`dist/` is produced by vite:

```sh
cd rookery-search/0.3.0
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
