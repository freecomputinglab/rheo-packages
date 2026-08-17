# @rheo/rookery-search

Fuzzy search over the notes in a [`@rheo/rookery`](../../rookery/0.2.0) — by
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
#import "@rheo/rookery:0.2.0": idea, rookery
#import "@rheo/rookery-search:0.2.0": search-bar
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
#import "@rheo/rookery-search:0.2.0": search-ideas
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
`title`, `text`, `body`, `href`, `minted`, `updated` — plus `score` and `kind`.
Sorted TWO TIERS deep: every `kind: "name"` row (matched on id or title) before
every `kind: "body"` row (matched only on body text), best score first within
each tier, ties falling back to id order, so a build is reproducible. `href`
is `none` without rheo, since nothing mints note pages there; link to
`label(e.id)` instead, as above.

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

Tags are not searched, for now, on either id/title or body.

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

## The corpus in the browser

A compile-time search is not a search box. For that the browser needs the
corpus, and `#search-index()` puts it on the page as JSON:

```html
<script type="application/json" id="rookery-search-index">[{"id":"idea:flat-ids","name":"flat-ids","text":"Flat ids, and why","body":"Flat ids are …","href":"ideas/flat-ids.html"}, ...]</script>
```

One row per note: `id`, `name`, `text` (the plain-text title, `""` when there
is none), `body` (the plain-text body, `""` when there is none) and `href`.
The field is `text` and not `title` deliberately — it is the same name,
meaning and type as `search-ideas` returns, and a name that meant content in
Typst and a string in JSON is how a consumer gets it wrong.

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
#import "@rheo/rookery-search:0.2.0": search-bar
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
#import "@rheo/rookery-search:0.2.0": search-modal
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
- `index` / `elem-id` / `body-chars` — the same parameters `#search-bar`
  takes, forwarded to `#search-index` unchanged.

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
a build opened straight off disk falls back to the plain-text excerpt from the
island's own `body` field — centred on the match for a body-tier hit, from the
start for a name-tier one. That excerpt is also what the pane shows for the
moment before the fetch lands, and what it keeps if a note's page 404s. A note
with no body text at all shows a muted "No preview" line rather than a blank
pane. Nothing breaks in any of these cases; the pane is simply plainer.

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

Below a 40em (≈640px) viewport width the preview pane and the `Ctrl K` hint
both disappear and the list takes the full width — a preview column that
narrow shows about four words and is worse than none. That breakpoint is a
literal in the package's CSS, not a custom property (a `@media` condition
cannot read one); a site wanting a different breakpoint overrides the whole
`@media` block, unlayered, like any other rule here.

## Working on it locally

Unlike rookery, this package is **built**. `typst.toml` points at `dist/`, and
`dist/` is produced by vite:

```sh
cd rookery-search/0.2.0
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

`snippet` in `src/rookery-search.js` is the one deliberate exception: the
modal's preview excerpt has no Typst counterpart and needs none — a static
listing shows titles, not excerpts — so it carries no parity requirement.

```sh
just parity
```

feeds two lists of cases (one per ranking rule) through both languages and
diffs every score, failing loudly when they disagree. The cases live in
`test/parity.typ`, as two labelled metadata arrays; extend them when you
extend a rule, and change both copies in the same commit. It needs no build —
the fixture imports `src/` on both sides.

To develop against a live rheo project, symlink the package into the Typst
package cache:

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo/rookery-search
```
