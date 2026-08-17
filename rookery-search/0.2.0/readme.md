# @rheo/rookery-search

Fuzzy search over the notes in a [`@rheo/rookery`](../../rookery/0.1.2) — a
Typst primitive that ranks them, a JSON index of the corpus, and a search bar
you can drop into a page.

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
#import "@rheo/rookery:0.1.2": idea, rookery
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

Three functions, and they do not all need the same things:

- **`search-ideas(query)` — no rheo, no JavaScript.** It ranks the corpus and
  hands you the matches; you render them however you like. Works under plain
  `typst compile`, and a static list of results is a real answer, not a
  fallback.
- **`search-index()` — rheo only.** Its rows link to minted note pages, and
  only rheo mints them. Without rheo every link would be `none`, so it emits
  nothing at all rather than shipping a browser a list of nulls.
- **`search-bar()` — rheo only**, twice over: the same minted pages, plus a
  script that rheo injects from this package's manifest. It emits nothing
  without rheo, rather than rendering an input that could never work.

Neither of the last two is useful in a single-document build anyway — a PDF has
no pages to navigate between and nothing to run a script.

Where rheo is what you build with, it must be **rheo >= 0.5.2**. Both
rheo-only functions are downstream of the note pages rookery mints from its
`.marrow.typ`, and inlining a package's `.marrow.typ` landed in 0.5.2. On an
older rheo nothing errors — no pages are minted, so the index comes out empty
and the bar has nothing to link to, which is the same silent failure as
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
`title`, `text`, `href`, `minted`, `updated` — plus `score`. Sorted by score,
and ties fall back to id order, so a build is reproducible. `href` is `none`
without rheo, since nothing mints note pages there; link to `label(e.id)`
instead, as above.

### What matches, and what doesn't

Matching is a **subsequence** match against the note's **id and its title**,
whichever scores better. So "wnd" finds `windows`, and a note is findable both
by the name you type into `#window` and by the title you read on the page.

Scoring rewards, in rough order of weight: characters matched in a contiguous
run, a prefix match, matching near the start, and the note being close in
length to the query. That last one is why "window" ranks `windows` above
`window-depth` rather than tying them.

`-` and `_` fold to a space **on both sides**, so `flat-ids` is findable as
"flat ids" — and still as "flat-ids", because the query folds too.

**Bodies are never searched.** That is a full-text index, a different thing
with different costs, and it would make nearly every note match nearly every
query. Tags are not searched either, for now.

**Accents are not folded**: "cafe" does not match "Café". Fixing it means
Unicode normalisation that the JavaScript half of this package would have to
reproduce character for character, and a rule that disagreed with itself
between the static list and the live bar would be worse than one that is
simply narrow.

`#fuzzy-score(hay, query)` is public too — `none` for no match, otherwise an
integer. Rank something other than notes with it, or sort matches your own way,
without inventing a second rule that disagrees with the bar's.

## The corpus in the browser

A compile-time search is not a search box. For that the browser needs the
corpus, and `#search-index()` puts it on the page as JSON:

```html
<script type="application/json" id="rookery-search-index">[{"id":"idea:flat-ids","name":"flat-ids","text":"Flat ids, and why","href":"ideas/flat-ids.html"}, ...]</script>
```

One row per note: `id`, `name`, `text` (the plain-text title, `""` when there
is none) and `href`. The field is `text` and not `title` deliberately — it is
the same name, meaning and type as `search-ideas` returns, and a name that
meant content in Typst and a string in JSON is how a consumer gets it wrong.

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

### Keeping the two copies of the ranking rule honest

The ranking exists twice: `fuzzy-score` in `src/lib.typ`, for the compile-time
search, and `score` in `src/rookery-search.js`, for the live bar. Two
implementations of one rule drift silently — a static list and a search box
would simply start ranking differently, and nothing would fail.

```sh
just parity
```

feeds one list of cases through both and diffs every score, failing loudly when
they disagree. The cases live in `test/parity.typ`; extend them when you extend
the rule, and change both copies in the same commit. It needs no build — the
fixture imports `src/` on both sides.

To develop against a live rheo project, symlink the package into the Typst
package cache:

```sh
ln -sfn "$PWD" ~/.cache/typst/packages/rheo/rookery-search
```
