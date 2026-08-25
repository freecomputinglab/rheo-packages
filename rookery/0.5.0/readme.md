# @rheo/rookery

Atomic, interlinked, transcludable notes for Typst — Zettelkasten-style, and
rheo-aware where rheo is present.

A note exists ONLY where you write `#idea("name")[...]`. There is no document
show rule and no "every heading is a note" behaviour — a labeled heading is
just a labeled heading. `#idea[body]` (no name) works too: the package
generates a sequential id and shows it to you as a `[idea:1]`-style permalink
next to the note, since with no name there's no other way to know it.

```typst
#import "@rheo/rookery:0.5.0": idea

#idea[A frictionless note — reads its generated id off the [idea:1] permalink.]
#idea("etal")[A pinned note — its id is always `idea:etal`.]
```

Full signature: `idea(level: 1, title: none, tags: (), minted: none,
updated: none, show-date: false, show-tags: false, ..args)`, where the sink accepts the body
alone, `(name, body)`, or `(<name>, body)` — the name may be a string or a
Typst label, identically.

## 0.5.0

**A note's tags are a DICTIONARY.** Keys are tag names, values are arbitrary
Typst values, and a plain tag's value is `none` — so a tag can carry metadata
instead of only naming itself. `tags: none`, `tags: "draft"`, `tags: ("a", "b")`
and `tags: (a: 1)` are all accepted and all normalize to that one shape. See
"Tags".

`note` and `todo` are GONE, replaced by `tagged-idea(tag, value: none)`, a
factory you build your own constructors from. `tag-data()` and `tag-value()` are
new, and `#ideas-outline`'s `filter:` now receives the tag dictionary. See
"Migrating from 0.4.1" below for the four breaking changes in full.

`@rheo/rookery-search` 0.5.0 ships in lockstep and is REQUIRED: the note
registry's state key is not versioned, so an older search package sharing a
document with this one reads these records and fails.

### Migrating from 0.4.1

1. **`note` and `todo` are no longer exported.** Two lines restore them
   verbatim, and every existing call site then works unchanged:

   ```typst
   #import "@rheo/rookery:0.5.0": tagged-idea
   #let note = tagged-idea("note")
   #let todo = tagged-idea("todo")
   ```

2. **`#ideas-outline(filter:)` receives the tag DICTIONARY**, not an array of
   names. `t => "phd" in t` is unaffected — `in` tests keys. A predicate using
   an array method must be rewritten: `t.map(..)`, `t.any(..)`, `t.all(..)` and
   `t.at(0)` no longer work, because a dictionary has no `.any`/`.all` and its
   `.at` takes a key rather than an index.

3. **Tag order is unspecified.** `#ideas().tags` and `#tags-of()` still hand
   back an array of names, but nothing guarantees the sequence any more. Sort
   it yourself if you depended on it.

4. **`show-tags:` renders pills for flat tags only** — those whose value is
   `none`. CSS classes are unaffected and still cover every key, so a stylesheet
   needs no changes.

Nothing else moved. `#idea`, `#window`, `#hyperlink`, `#ideas()`, dates,
footnotes, bibliographies and minted pages all behave exactly as they did.

## 0.4.0

`#note-path(id)` is new, and every `#ideas()` row now carries the matching
`page` field: an output path measured from the site root rather than from the
calling page, for a caller that has no page of its own to measure from — a feed
config, a sitemap, anything invoked once from shared code. `#note-href()` is
unchanged and remains the right call from a vertebra. See "Reading the rookery
as data".

An idea's hat can show its tags as pills, opt-in via `show-tags`, and the hat's
label size is themeable through `label-size` alongside the `label-font` that
landed in 0.3.0. The theme is published once per page as a `:root` rule, so a
package layered on top of rookery inherits it instead of restating it —
`@rheo/rookery-search` 0.4.0 is the first to do so.

A tag can carry its own colour, `theme: (tags-color: (draft: rgb("#3366ff")))`,
delivered as a generated `.idea-tag-<tag>` rule in `@layer rookery-tags` rather
than as a style on the pill. That is what makes it reach every surface wearing the
tag's class — the hat pill, an outline row's marker, and `@rheo/rookery-search`'s
modal chips, which JavaScript builds in the browser — and what lets a project's
own unlayered stylesheet override it. A themed tag's name must be usable as a CSS
class, since it becomes one. See "Per-tag colour: `tags-color`".

Rookery mints an `ideas/index.html` landing page for the whole rookery by
default now — every note linked to its own page, with its date and its tags.
Set `index-page: false` to opt out. See "A landing page for the whole rookery"
below.

A citation written inside a `#footnote` now belongs to the idea the footnote was
written in, which is what this readme always said it did. Before this it was
dropped: the author-date marker rendered and no references block was emitted
anywhere, so a reader met a citation with nothing on the site saying what it
cited. A `#window` or `@idea:` reference written inside a footnote registers its
backlink now for the same reason — one walk, two symptoms.

Minted note pages can carry an opt-in `<rssfeed:item>` beacon,
`#show: rookery.with(syndicate: true)`, default off. See "A feed is another"
below for when to reach for it and when to source a feed from `#ideas()`
directly instead.

## 0.3.0

`#ideas()` rows now carry a `tags` field — additive, part of the field-list
contract documented in the comment above `ideas()`, and safe for a downstream
package to rely on from this release. `#ideas-outline()` (and the rest of the
outline/`#ideas()` family) gained their `tags:`/`match:`/`filter:` parameters
in the same release. A new `label-font` theme key also landed:
`#ideas-outline()`'s "Contents" title now renders in that face, as a hat,
matching the rest of the theme system — see "The theme" and "The click
budget" below.

## Setup, and the `idea:` prefix

Nothing above needed any setup, and that stays true. One optional template
does all of it in a line, and is the only place anything is configurable:

```typst
#import "@rheo/rookery:0.5.0": rookery, idea, window
#show: rookery.with(
  prefix: "note",                 // ids are now `note:etal`
  window-depth: 2,                // a window inside a window unfurls one level
  theme: (
    link-color: "rgba(230, 140, 0, 0.16)",  // hover background on any link
    fold-color: "rgba(255, 190, 40, 0.07)", // ...and on a foldable block
    date-color: rgb("#a08a5a"),
  ),
)
```

`#show: rookery` does exactly six things: it publishes the id prefix, the
nested-window depth, the minted-page template (`idea-page-template`, see
"Standalone note pages"), the bibliography (see "Bibliographies") and the
theme, and it installs `link-to-page` (see below and "Referencing a note") so
`@note:etal` renders the note rather than a bare figure number. It sets no
other styles and wraps `doc` in nothing. It emits nothing of its own either,
with one exception: a page that cites something outside every idea gets a
references block after its content, because a citation no bibliography claims
fails the build. On a document with no notes in it, it is a no-op, and even the
`ref` rule passes every non-rookery reference straight through. Pass
`refs: false` to keep the rest and skip that rule.

`ref-target: "page"` (the default) picks `link-to-page`, so `@note:etal` links
to the note's own minted page. Pass `ref-target: "anchor"` to pick
`link-to-anchor` instead, making every `@note:etal` in the document link to
the note's in-context anchor, the same destination `#link(label("note:etal"))`
always uses. Ignored when `refs: false`, since there is then no installed rule
for it to configure.

`prefix` must be a non-empty string with no `:` in it (the separator is added
for you).

### Nested windows, and `window-depth`

`window-depth` counts **levels of transclusion**, and every number on the
scale means one thing:

| `window-depth` | what a `#window` renders |
| --- | --- |
| `0` | **a link only.** The note's title, linked to the note's own page — no summary row, no disclosure, no body. Nothing is transcluded anywhere in the document. |
| `1` | **the default.** The note renders once, and a `#window` written *inside* it collapses to its `[idea:etal]` permalink — the block you opened shows one note rather than a tree of them. |
| `n` | the note renders, and `n-1` further levels of nested windows unfurl as real windows, collapsing at the `n`th. |

`#window(..., depth: n)` overrides the document setting for one call site, and
that is per call site because all three readings are reasonable on the same
page: an index of forty backlinks wants the collapse, a dense index may want no
transclusion at all, and a homepage showing one note in full may want a level
or two.

A nested `#idea` — one note written literally inside another's body — is a
different thing and always renders in full, whatever the depth.

**Migrating from the old scale.** Before this, `0` was the default and `n`
unfurled `n` nested levels. Every number moved up by one, so **add one**: a
project that set `window-depth: 2` wants `3`. There is no automatic upgrade,
and a project that sets nothing is unaffected — the default renders exactly
what it always did.

The budget is what makes this safe. A note that windows itself, or two notes
that window each other, would otherwise expand forever; with a depth they
bottom out at the collapsed permalink, and there is no configuration that can
make them not.

Depth is not free — each level re-renders the transcluded note's body, so `n`
levels over a fan-out of `k` windows is `k^n` blocks in the page. Small
numbers.

A note's own **minted page** counts from one level further in, because a minted
page is not a transclusion: it shows the note as the page's own top level, so a
`#window` written in that note's body is a top-level window there and renders
with a top-level window's budget, exactly as it does on the page the note was
hatched in. What `window-depth` governs on a minted page is the windows nested
inside *those* — at the default of `1` they collapse to their permalinks. (At
`window-depth: 0` a minted page's own windows collapse to their permalinks too,
which is the link that setting asks for.) A minted page's **Context** and
**Backlinks** rows are pinned at `depth: 1` whatever the document sets: an index
of what points here is a list to scan, not prose to unfurl.

### The theme

Five colours, three lengths and one font — the whole of what the package will style
for you:

| key | what it colours | default |
| --- | --- | --- |
| `link-color` | hover background on **any** rookery link | `rgba(128, 0, 255, .12)` |
| `fold-color` | hover background on a foldable window block | `rgba(0, 100, 255, .05)` |
| `id-color` | the `[idea:etal]` permalink's text | `gray` |
| `date-color` | an idea's/window's date, where shown | `gray` |
| `border-color` | the rule down a note, a window and an outline, and the tab that rules off the top of a card | falls back to `link-color` |
| `rule-width` | how **thick** every one of those rules is, markers included | `2px` |
| `pad` | the indent between a note's rule and its content, and a window's right padding | `0.5em` (halved under 600px) |
| `label-font` | the face every **hat** is set in — a note's id, and `#ideas-outline`'s title | `monospace` |
| `label-size` | the size every **hat** is set in — a note's id, and `#ideas-outline`'s title | `0.57rem` |

The first two are the look, and the contrast between them is the point. Both
are hover *backgrounds*, so they compare like with like: the lighter blue
belongs to the fold — a block that only opens and closes — and the stronger
purple to every link, which actually goes somewhere. (Forester makes the same
split with one blue at two alphas; two hues survive being read quickly.)

`link-color` reaches every link rookery is responsible for, not just the
permalink: an `@idea:other` reference, and an author's own link inside a note
or a transcluded copy of one. It is deliberately *not* a bare `a:hover` — this
stylesheet is injected into every page of a rheo project, and a package has no
business restyling a site's nav.

Each key is also a granular parameter of its own, and the granular form
**wins** over `theme:` — so the two compose:

```typst
#show: rookery.with(theme: MY-THEME, link-color: rgb("#ffd166"))
```

reads as "my theme, but that one colour". Precedence, least specific first:
the stylesheet's default → `theme:` → the granular argument. Anything left
unset at every level stays the stylesheet's default and nothing is emitted for
it.

Values are Typst colours, or raw CSS strings when you want something Typst's
colour type can't express (`"rgba(0, 100, 255, .1)"`, `"var(--accent)"`,
`"transparent"`). A misspelled key is a build error naming the valid ones, not
a silently ignored colour.

`rule-width` and `pad` are the exceptions, being lengths rather than colours: pass
a Typst length (`2pt`, `0.15em`) or a CSS length string (`"3px"`) — a string is the
only way to say `px`, which Typst has no literal for.

`rule-width` is deliberately ONE value for every line that frames a note, so a
card, a window, the tab across the top of both and `#ideas-outline`'s rule and row
markers can never disagree about their own weight. The separators above a footnotes
or references block are not governed by it: those are apparatus, not the frame.

`pad` is the matching ONE value for the indent — how far a note's content sits from
the rule beside it, and on a window how far it sits from the right edge, so the two
sides agree. Three other things measure the same distance in order to close the
frame's corner on that rule: the tab's own offset, the top rule's stub, and a folded
window's tint. They all read this, so a value of your own keeps the corner shut
rather than opening a notch in it.

`label-font` is the third exception, being neither a colour nor a length. A **hat**
is the stub of rule out of a frame's top-left corner with a label sitting on its
end — a note's `[idea:etal]` id wears one, and so does `#ideas-outline`'s
"Contents", because both label the frame they sit on. This is the face they are set
in, and it is deliberately the only `font-family` the package sets: your prose is
yours. Pass a CSS font stack as a string, or the family names as an array and the
commas are added for you:

```typst
#show: rookery.with(theme: (label-font: ("Berkeley Mono", "monospace")))
#show: rookery.with(label-font: "Berkeley Mono, monospace")   // identical
```

The default is `monospace`, the **generic** family — so out of the box a hat is
whatever monospace face the reader has configured, not one this package chose for
them. An id is machine text and a monospace face says so without a word of
explanation. A `#footnote` or references block's own heading is NOT a hat and does
not follow this: those label a list inside a note, not the note's frame.

The size a hat is set in travels with its face — a project theming `label-font`
should usually theme `label-size` alongside it, since both describe the same
object.

`label-size` is the fourth exception, a length like `rule-width`/`pad` but with a
twist: the primary way to set it is a **string in `rem`**, not a bare Typst
length, and that matters more here than for the other two. `--idea-label-size`
is not just cosmetic — the tab's lift, a window's summary lift, a folded
window's tint offset and the footer's own padding are all expressed as
`calc()`s against this same variable, so retheming it keeps the card's corner
shut instead of opening a notch. It is `rem`, deliberately, not `em`: an id is
one object wherever it appears, and `em` made it three visibly different
sizes depending on context — 0.57 of an `#idea` heading, 0.57 of a minted
page's `<h1>`, 0.57 of a window summary's body text (MEASURED, on
rookery.ohrg.org). `rem` keeps a hat one size everywhere; `em` does not. This
package doesn't police a theme's choice of unit — `em`, `px`, anything CSS
accepts is still a legal value — but a theme reaching for something other
than `rem` here is opting back into that per-context drift.

```typst
#show: rookery.with(theme: (label-size: "0.8rem"))
#show: rookery.with(label-size: "0.8rem")   // identical
```

Like the prefix, the theme is **one value for the whole document** — two
vertebrae asking for different themes get whichever the spine ends on, not one
each. Apply the same arguments in every vertebra.

**The prefix is ONE value for the whole document.** Under rheo, apply the
template in every vertebra that uses the package — imports are per-file, so a
vertebra that omits it loses the `ref` rule. It does not lose the prefix: a
file that never applies the template still mints ids with whatever prefix the
document settled on, which is what keeps a `#window` across that boundary
resolving instead of panicking on an id nothing registered.

CSS class names are NOT affected: the heading is `idea`/`idea-tag-<tag>` and
the permalink is `.idea-label` whatever the prefix reads as.

## Flat ids, and why

`#idea("etal")` is the Typst label `<idea:etal>` everywhere — no handle or
filename prefix. That means a note KEEPS ITS ID WHEN IT MOVES BETWEEN FILES:
nothing about `<idea:etal>` depends on which file it's written in. Names are
therefore globally unique by design; giving two notes the same id is a build
error naming the id, as soon as anything (`#window`, `link-to-page`/
`link-to-anchor`) looks the id up.

## Two modes

**Pure Typst, no rheo.** One root file `#include`s your note files; `#window`
and cross-references work because everything compiles as one document.
`--features html` is required for every build, even a plain PDF — see below.
HTML output needs `src/rookery.css` included manually (rheo does this for you
automatically, see below).

```typst
// root.typ
#include "notes.typ"
#include "more-notes.typ"
```

```sh
typst compile --features html root.typ root.pdf
typst compile --features html --format html root.typ root.html
```

**Under rheo.** Nothing extra to write — no `ctx:` parameter, and the `#show:
rookery` template is optional even here. Just `#import` and call
`#idea`/`#window` like any other
package. rheo adds exactly two things on top of the pure-Typst behaviour:
correct cross-PAGE hrefs (rheo puts each vertebra in its own output page,
which a plain Typst compile doesn't), and the stylesheet auto-injected via
this package's `[tool.rheo.html]` — no manual `<link>` needed.

`demo/pure/` in this repo is the pure-Typst side: no template at all, default
prefix, `link-to-page` wired up by hand. The rheo side lives in the sibling repo
**`rookery.ohrg.org`** — this package's documentation site, written with the
package it documents. It is the worked multi-vertebra example, including a
nested vertebra to exercise cross-page hrefs, a custom prefix and theme, and
`#show: rookery` applied once in a site template rather than repeated per
page.

## Referencing a note

Three ways, pick by how much ceremony you want:

- `#link(label("idea:etal"))[jump to it]` — a plain jump, works everywhere,
  always correct (in-page or cross-page).
- `#window("etal")` — transcludes the note: its title, its `[idea:etal]`
  permalink and its body, as one foldable block. Accepts a single name, a
  label, or an array of names (`#window(("etal", "second"))` renders both in
  order, each its own block). `limit: n` truncates the body to the first `n`
  content-level blocks (paragraphs, grouped list items, ...) plus "…", in
  every target, not just HTML. `n` must be `none` or a positive integer:
  `limit: 0` would show an ellipsis and nothing else, which reads as a mistake
  rather than a request, so it is rejected along with negatives and non-integers.

  A limit can no longer land mid-paragraph. One paragraph is one block however
  many inline runs it is made of, so a plain text run and the `raw` span beside
  it are never separated, and the space between them survives — the MEASURED
  defect that once rendered "three layers, because" as "three layers,because".
  A block-level element (a heading, a table, a block quote) is still a block of
  its own, and the whitespace around it is still dropped, because that gap is
  drawn by margins rather than content.

  `folded: true` starts the block CLOSED. That is all it does: a folded window
  and an open one are the same block, so `limit:` stays meaningful under
  either and the two are orthogonal. Under a paged target, where there is
  nothing to click, `folded` is ignored and the body always shows.

  `show-date: true` shows the note's `updated` date at the right-hand end of the
  hat, opposite the permalink — off by default. See "Dates" below.

  `show-tags: true` shows the note's tags as a row of pills in the hat, between
  the permalink and the date — off by default, same mechanism as `show-date`.
  See "Tags" below.

  `depth: 0` renders this window as a LINK to the note's page and transcludes
  nothing; `depth: 1` renders the note and collapses any `#window` written
  inside it; `depth: n` unfurls `n-1` levels of those. `auto` (the default)
  takes the document-wide `window-depth`, itself `1`. See "Nested windows, and
  `window-depth`" above.

  `tags: ("phd",)` selects notes instead of naming them — and ADDS to the
  names rather than replacing them. `#window(<intro>, tags: "phd")` shows
  Intro, then everything tagged `phd`; a note that is both named and tagged
  appears once, where you named it. Either half may be left out, but not
  both. `match:` is `"any"` (the default) or `"all"`, so
  `tags: ("phd", "draft"), match: "all"` wants notes carrying both.

  Tag selection is always rookery-wide: it reads the whole registry, so it
  pulls the same notes wherever the window sits. That is the point — an index
  written once keeps up as you add notes, instead of going quietly out of date
  the way a hand-listed set of ids does.

  `sort:` is `auto`, `"date"` or `"lexicographic"`. `auto` keeps the notes you
  named in the order you named them and appends the tag matches by id, so a
  window that names its notes reads exactly as it always has; naming a sort
  orders the whole selection instead. `"date"` is newest first on the minted
  date, undated notes last.

  One asymmetry to know about: a note you NAMED gets a backlink from the
  window, and a note the tags pulled in does not. A window announces what it
  points at before the registry can be read, and a tag match is not known that
  early — so the backlink simply cannot be recorded. Name a note explicitly if
  you want the link to travel back to it.

  See "The click budget" below for what clicking each part does.
- `@idea:etal` — the terse form, but on its own it renders as a bare figure
  NUMBER (Typst's stock `@` rendering for a labeled figure — a note's id
  lives on a hidden anchor figure). `#show: rookery` installs the rule that
  fixes this, so if you already applied the template there is nothing to do.
  Without it, apply the exported `link-to-page` by hand:

  ```typst
  #import "@rheo/rookery:0.5.0": idea, window, link-to-page
  #show ref: link-to-page
  ```

  With the rule applied, `@idea:etal` renders the note's title (linked)
  instead, cross-page too; a note with no title falls back to the bare id
  text rather than a number. References to anything else (an ordinary
  figure, a heading) pass through untouched — checking whether the reference
  actually resolves to a rookery note anchor is what lets `show ref:` be
  installed document-wide with no narrower selector, rather than something
  scoped only to `idea:` refs.

  **Custom text:** `@idea:etal[custom text]` (Typst's own ref-supplement
  syntax) overrides the title:

  ```typst
  @idea:etal[click here]
  ```

  **Where it links:** `link-to-page` (above) goes to the note's own minted
  page — same as the permalink, falling back to the in-context anchor where
  no page is minted (plain `typst compile`, or the combined PDF). Use
  `link-to-anchor` instead to make `@idea:etal` link to the in-context anchor
  unconditionally, like `#link(label("idea:etal"))` does:

  ```typst
  #import "@rheo/rookery:0.5.0": idea, window, link-to-anchor
  #show ref: link-to-anchor
  ```

  `#show: rookery.with(ref-target: "anchor")` does the same thing document-wide
  when you're using the template rather than importing `link-to-anchor`
  directly.

## Outlining notes

`#ideas-outline()` lists the current page's own notes as a nested tree.

```typst
#import "@rheo/rookery:0.5.0": ideas-outline
#ideas-outline()
#ideas-outline(title: none, depth: 2)
#ideas-outline(title: [Everything], rookery-wide: true)
```

Typst's own `#outline()` cannot do this: it lists `heading` elements, and a
note only becomes one on the paged target — on HTML/EPUB its title is a raw
`html.elem("h…")` with no Typst heading behind it. So `#outline()` would find
every note in a PDF and none in the primary targets. This is built off the
same query-time machinery backlinks already use, and works identically
everywhere.

`title` and `depth` mirror `#outline()`'s so the two read as one family:
`title: auto` prints "Contents", `none` omits it, anything else replaces it;
`depth` caps how many levels show, counting from 1 like Typst's heading
levels.

**Nesting is real containment** — one `#idea` written inside another's body —
not the author-set `level:`, which is a heading-size knob most notes never
touch. So the tree is right with no ceremony, matching `#idea`'s own "hatch
without ceremony" design. Untitled notes are omitted: an outline entry is a
title, and there is nothing to label an auto-numbered note with.

**`rookery-wide: true`** lists every note in the rookery instead of only this
page's — one tree, nested by the same real containment. The whole spine
compiles as one Typst document, so this is the per-page filter being lifted
rather than a second pass, and entries link straight across pages. `depth`
composes with it and still means containment levels, not pages.

Pages come in **spine order** — the order you configured, via the directory
scan and `[[spine.section]]`, not the order the files happen to be named in —
with **`index.typ` first** wherever it exists. rheo already puts a nested
directory's `index.typ` first, as that directory's landing page; at the root
it treats `index.typ` as an ordinary leaf, so a rookery whose front door sorts
into the middle of the alphabet would otherwise have its index of everything
start somewhere in the middle. Hoisting it makes both levels read the same
way: landing page first.

Neither applies to a single-document target — the combined PDF, or plain
`typst compile`. There the outline follows the document, because reordering it
against the page sequence a reader is holding would be a lie, and it is also
why the two forms agree there rather than disagreeing about an order only one
of them applied.

It is deliberately not grouped under per-page headings. A note's id is flat
and travels between files precisely so a reader never has to know which file
holds it (see "Flat ids, and why"); an index that led with filenames would put
that back.

Notes transcluded onto the page by a `#window` are never listed, at any depth
of nesting — they are echoes of notes stored (and usually written) elsewhere,
not this page's structure.

Where the output is a single document — the combined PDF, or plain `typst
compile` with no rheo — the two forms agree and both list everything. That is
the same set: there is only one page.

**`tags:` and `match:`** are the same pair `#window` and `#ideas()` take,
through the same shared predicate: `tags:` is `none`, a string or an array of
strings, `match:` is `"any"` (the default) or `"all"`. An empty array
(`tags: ()`) is no filter at all rather than a filter matching nothing — asking
for none of the tags is not the same as asking for a tag no note has.

```typst
#ideas-outline(tags: "todo")
#ideas-outline(tags: ("todo", "phd"))               // ANY of them
#ideas-outline(tags: ("todo", "phd"), match: "all") // ALL of them
#ideas-outline(title: [Open], filter: t => "todo" in t and "done" not in t)
```

**`filter:`** is a predicate of your own over the note's TAG DICTIONARY,
returning a boolean, ANDed with `tags:`/`match:` when both are given — both must
hold, never either. It exists because `tags:`/`match:` can say "any of these"
and "all of these" and nothing else: they cannot say `phd` but NOT `draft`, nor
`(phd AND draft) OR todo`. Keyword parameters for those would be a filter
language grown one special case at a time (`exclude:`, then `any-of:`, then
nested groups), and a Typst function value already is that language. It sees the
tag dictionary and nothing else — no title, no id, no depth.

Because it is the dictionary, a filter can select on a tag's VALUE and not
merely on its presence:

```typst
#ideas-outline(title: [Urgent], filter: t => t.at("priority", default: 9) <= 1)
```

`t => "phd" in t` still works unchanged — `in` tests keys. What does NOT work is
an array method: `t.map(..)`, `t.any(..)`, `t.all(..)` and `t.at(0)` are gone,
because a dictionary has no `.any`/`.all` and its `.at` takes a key. See
"Migrating from 0.4.1".

**A filter prunes AND PROMOTES.** A matching note whose parent does NOT match is
re-based to its nearest KEPT ancestor's level, so the tree never shows a hole
where an excluded parent was. MEASURED on `Top` (tagged `phd`) > `Mid`
(untagged) > `Deep` (tagged `phd`): `#ideas-outline(tags: "phd")` renders `Top`
with `Deep` nested directly under it, one level shallower than the unfiltered
outline puts it. Keeping unmatched ancestors as unlinked scaffolding was
rejected — it would put notes in the index the filter said to exclude.

**`depth:` counts levels in the FILTERED tree**, because pruning happens BEFORE
the depth cap. MEASURED on the same three notes,
`#ideas-outline(tags: "phd", depth: 1)` renders `Top` alone: `depth: 1` means
"the top level of what I asked for", not "whatever survived from the top level
of everything".

**A filtered outline that matches nothing renders NOTHING AT ALL, heading
included.** An unfiltered empty outline still prints its heading — that case is
unchanged, and the two differ on purpose. An empty unfiltered outline is an
answer ("here are this page's notes", there are none, the heading is the
sentence); an empty filtered one is a promise the filter already ruled out, and
a `#ideas-outline(title: [Todos], tags: "todo")` carried on every section would
otherwise render a "Todos" heading over emptiness on every section without one.
`depth:` deliberately does not count as a filter here: it drops levels below the
first, so it cannot empty an outline that had anything in it at all.

## The corpus, as data

`#ideas()` hands you the whole rookery as a plain array of dictionaries. It is
the seam this package deliberately leaves open: everything above renders notes
the way rookery thinks they should be rendered, and this is where you take the
same material and do something else with it.

```typst
#import "@rheo/rookery:0.5.0": ideas, note-href
#context {
  for e in ideas() {
    [#e.name — #e.text \ ]
    // e.body is a plain string too: [#e.body.slice(0, 80)] previews a note's
    // opening without rendering it.
  }
}
```

**It has to be called inside `#context`.** The registry is a Typst state, and
reading it whole means reading it at the end of the document, which is only
legal in a context block. `#ideas()` is not itself a context function, because
a context function can only return content — and the entire point is that this
one returns data you can sort, filter and count.

Each entry is:

- `id` — the full id, prefix included (`"idea:etal"`).
- `name` — the same id with the prefix stripped (`"etal"`), the form you write
  in `#window("etal")`.
- `title` — the title as content, or `none` for an untitled note.
- `text` — that title flattened to a plain string, `""` when there is none.
  Useful for matching, sorting and anything else that wants a string rather
  than something to render.
- `tags` — the note's tag NAMES as an array of strings, `()` when it has none.
  Every key, valued tags included; order is unspecified. `#tags-of()` below asks
  the same question about one note; this is the bulk form, and the cheaper one
  when you are walking the whole rookery.
  The VALUES are deliberately NOT on this row, and that is load-bearing rather
  than tidiness: `@rheo/rookery-search` serializes these rows into a JSON index,
  and a value can be a `datetime` or content. Reach for `#tag-data()` when you
  want them.
- `body` — the note's body flattened to a plain string, `""` when there is
  none. Block boundaries (a paragraph break, a list item) collapse to a
  single space rather than gluing adjacent words together; a nested `#idea`'s
  own text is excluded (it registers separately and owns its text); a
  `#footnote`'s body is excluded too. A plain string, not the content:
  matchable and excerptable, but not renderable — that is the whole reason it
  exists where the content body still does not: `@rheo/rookery-search` ranks
  and previews full text against it, and a string can be matched and
  excerpted without turning every consumer into a second transclusion engine
  the way handing out the content itself would.
- `href` — a depth-relative link to the note's minted page, from wherever you
  are calling. See `#note-href()` below.
- `page` — the same minted page, as a site-root-relative path instead — the
  same string `#note-path()` returns, for a consumer with no page of its own
  to measure depth from (a feed, a sitemap). See `#note-path()` below.
- `minted`, `updated` — the note's dates, or `none`. See "Dates".

`#ideas()` also takes `tags:` and `match:` — the same pair `#window` takes, with
the same meanings and the same shared predicate behind them. `tags:` is a single
string or an array; `match: "all"` demands every one of them where the default
`"any"` takes a note carrying at least one:

```typst
#context ideas(tags: "phd")                            // tagged phd
#context ideas(tags: ("phd", "draft"), match: "all")   // tagged both
```

An empty array (`tags: ()`) is no filter rather than a filter matching nothing —
asking for none of the tags is not asking for a tag no note has. You could write
the `"any"` case yourself as `ideas().filter(e => "phd" in e.tags)`; the
parameter exists because it filters BEFORE each surviving row is built, and
because `#search-bar` builds its index internally where your `.filter` cannot
reach.

The array is ordered by id, not by the order notes were written or the order
their pages appear. Sorting is your business: an id order is the one order
that is stable across builds, and it makes a diff of generated output mean
something.

A note's body AS CONTENT, its `raw` source and its backlinks are deliberately
absent from THIS array — only the plain-string form above is exposed here.
Handing out every note's content in bulk would turn every consumer into a
second transclusion engine — one that does not agree with `#window` about
folding, depth or dates. If you want a note rendered, render it with
`#window`, or — for the body alone, no chrome — with `#idea-body`, next.

### `#idea-body` — one note's body, rendered

`#window`'s content, without the summary and the disclosure — for a consumer
that wants to SHOW a note's actual prose (links, styling, footnotes,
citations) rather than describe it in a string, one note at a time:

```typst
#import "@rheo/rookery:0.5.0": idea-body
#context idea-body("etal")                // the whole body
#context idea-body("etal", limit: 3)       // the first three blocks
```

`limit:` truncates by block, the same unit and the same "…" `#window`'s own
`limit:` uses — so a paragraph is one block here too, a limit cannot land inside
a sentence, and the same `none`-or-positive-integer rule applies.
`depth:` is the same transclusion budget `#window` takes, but is pinned to `1`
here rather than left at `auto` — a caller asking for one note's body is
usually about to show a LOT of them (`@rheo/rookery-search`'s preview pane
calls this once per note in the whole rookery), and letting each one unfurl its
own nested windows by the document's `window-depth` setting could blow that up
unpredictably. So the body renders with any nested `#window` collapsed to its
permalink. Pass `depth:` explicitly if you want more. (`depth: 0` renders the
body all the same: `#idea-body` has no chrome, so it has no link to fall back
to the way a `#window` at `0` does.)

**Why not just call `#window`?** `#window` ANNOUNCES the note it shows, the
same marker `#ideas()`'s backlink data reads at registration time — a note
shown in a `#window` counts as a link TO it from wherever the window sits.
Right for a window an author writes into their own prose; wrong for a
function meant to run once per note on every page, which would otherwise
leave every page "linking" to every note in the rookery. `#idea-body` skips
the announcement — it only renders.

This is bulk-safe in the way handing out every note's CONTENT from `#ideas()`
is not: `#idea-body` still renders one note at a time, on request, the same
permission `#window` has always given an author explicitly.

`#note-href(name)` gives you the same link `href` carries, for a note you name
yourself:

```typst
#context note-href("etal")   // -> "../ideas/etal.html"
```

It takes whatever `#window` takes — a bare name, a full id, or a label — and
the string it returns is **relative to the page it was called on**, because
that is what an href in the output has to be. Do not compute one on a page and
use it on another.

Both `href` and `#note-href` are `none` where nothing mints pages: plain
`typst compile` with no rheo, and the combined PDF target. `ideas()` itself
still works there and still lists everything, because the corpus does not
depend on rheo — only on links to pages that only rheo produces.

`#note-path(name)` gives you the same page, but from the SITE ROOT rather than
from wherever you're calling — the `page` field above, computed on demand:

```typst
#context note-path("etal")   // -> "ideas/etal.html"
```

Use it where `#note-href` is the wrong shape: a caller with no page of its
own — a feed config, a sitemap, anything invoked once from shared code rather
than from a vertebra — has no "current page" to measure depth from, so a
depth-relative string built at the wrong call site would simply be wrong.
`page` and `#note-path` are `none` under the same two conditions
`href`/`#note-href` are.

This is the supported way to build behaviour on top of a rookery, and it
exists so that you do not have to reach into the package's internals to do it.
An index page, a feed, a "recently minted" list, a graph of the rookery: all
of them are a `for` loop over `ideas()`.

**Search is one of them, and it lives in `@rheo/rookery-search`** — fuzzy and
full-text ranking, a JSON index, an embeddable search bar, and an overlay
search modal — written entirely against `#ideas()`, `#note-href()` and
`#idea-body()`. It is a separate package on purpose. A search box is only
worth having with JavaScript, and this package ships none: no `package.json`,
no build step, `typst.toml` pointing straight at `src/`. Keeping search out
keeps that true. Install it alongside rookery if you want it; nothing here
depends on it, and nothing here changes if you never do.

**A feed is another.** `@rheo/rssfeed` builds Atom feeds from sources — plain
functions `cfg => (entries)` — and a rookery reaches it two ways.

The direct way, and the one to reach for first: write a source that calls
`ideas(tags:)` itself and maps its rows onto rssfeed's entry shape. Because
`page` above (and `#note-path()`) is site-root-relative rather than
depth-relative, this works from a feed config exactly as it would from a
vertebra — there is no "current page" for a feed to measure a link from, and
none is needed. `@rheo/rssfeed`'s own readme, "Sourcing from another
package", carries the worked recipe verbatim, run against this package's
`ideas()`; the two packages import nothing from each other, in either
direction.

The other way is `@rheo/rssfeed`'s own `<rssfeed:item>` beacon protocol, for a
source with no accessor like `ideas()` to call at all — a hand-authored page
syndicating itself, or a package that cannot import rookery's internals. For
rookery's own notes this stays secondary: every note is already reachable
through `ideas()`, so a rookery-sourced feed should reach for the direct way
above first. It exists as an opt-in, `#show: rookery.with(syndicate: true)`
(default `false` — a package must not emit into another package's label
namespace unasked). Turned on, each minted note page (`ideas/<slug>.html`)
also carries a `#metadata((..)) <rssfeed:item>` beacon, so `@rheo/rssfeed`'s
`items()` picks it up with no import in either direction — rookery never
imports `@rheo/rssfeed`, and the beacon is inert (`#metadata` renders no HTML)
when nothing reads it. A note with neither `minted` nor `updated` never gets
one: Atom requires `<updated>`, so an undated beacon would only be an entry
`items()`/`resolve-entries` drops on the floor.

`demo/rheo` turns it on and asserts it: the demo's own vertebra queries the
beacons back and renders their payloads, and `check.sh` pins the count, the
titles and the minted paths. That query is half the point — the beacons are
emitted inside the minted pages, so reading them from a vertebra is what shows
rheo's introspection carries them across the bundle, which is the premise the
whole protocol rests on. Nothing in that demo imports `@rheo/rssfeed`.


## The click budget

Interaction is modelled on [Forester](https://www.forester-notes.org), and the
whole of it fits in two rules:

- **The summary of a `#window` folds and unfolds. That is all it does.** Click
  the title, the date, the space between them — the block opens or closes and
  nothing navigates.
- **The `[idea:etal]` permalink is the only link the package emits**, and it
  goes to the note's own page. It sits beside the title, or alone at the top
  of the window when the note has no title (the id doing double duty as its
  name). `#idea` renders the identical affordance beside its own heading, and
  a `#window` nested inside a transcluded body collapses to it once the depth
  budget runs out — so the rule holds at every depth. Where the budget does
  reach, the nested window is a full window, summary and all, identical to the
  same `#window` written at the top level: still one link, still the permalink.

The disclosure is a native `<details>`/`<summary>`; the package ships no JS.
An `<a>` inside a `<summary>` does not break the toggle — only an `<a>` around
the whole summary does, which is why the body of a window is never wrapped in
one. There is no trailing "→" either: it was a second navigational affordance
competing with the permalink for the same click.

`src/rookery.css` carries just enough to make this read correctly — the
permalink grey and light, the disclosure marker hidden (the summary is
clickable as a whole, so a triangle at one end would misdescribe it), and two
hover states, both Forester's: a faint `rgba(0, 100, 255, .04)` on the block
to signal that it folds, and the same accent at `.1` on the permalink, twice
as strong because that one is a link.

Every one of those colours is `var(--x, <default>)`, and "The theme" above is
how you set the `--x`. It arrives as an inline custom property on the elements
that root a rookery subtree — `.idea-box`, `.idea-window`, a minted page's `<h1>`
— and inherits down to the permalink and the date. The default lives inside
the `var()` call, so an unconfigured document, and any reader that doesn't
understand custom properties, still gets the look above. The package emits no
`<style>` element and wraps the document in nothing, so there is no `:root` to
hang a variable on; this is the mechanism that needs neither.

Setting those properties in your own stylesheet works identically — they are
the same four properties, listed at the top of `src/rookery.css`.

A note carries a light left rule, blockquote-fashion, so a new `#idea` is
visible as one without a box or a background. `#idea` wraps itself in a
`<figure>` — the marker the package uses to find notes again — and browsers
indent that 40px by default; the stylesheet halves that and moves it onto the
note, so the rule sits at the text margin with the body indented from it. That
needs `figure:has(> .idea-box)`, since Typst emits a bare `<figure>` with no
class to hook; where `:has()` is unsupported the note simply sits further in.

`#ideas-outline` wears the same rule from the same property, one more rule per
nesting level, so a page's table of contents reads as part of the same
apparatus as the notes it lists. Its bullets are hairlines in that colour
rather than discs — drawn as a `border-top` on a zero-height `::before` (1px
whatever the font, and supported far more widely than `content` in `::marker`),
sitting on the font's own x-height via `vertical-align: middle` rather than a
guessed offset. This is the one thing the package emits with no themed
ancestor to inherit from, being a sibling of the notes rather than a
descendant, so the properties go inline on the outermost `<ul>`. Paged targets
get Typst's plain nested `list()` instead: there is no `.idea-box` rule there
for an outline to be in line with.

Override any of it; the classes are the contract: `.idea`, `.idea-box`,
`.idea-title`, `.idea-tab`, `.idea-label`, `.idea-date`, `.idea-tag`, `.idea-tag-<tag>`, `.idea-ref`,
`.idea-window`, `.idea-window-summary`, `.idea-window-title`,
`.idea-window-body`, `.idea-window-details`, `.idea-outline`,
`.idea-outline-row`, `.idea-outline-title`, on an idea that carries footnotes `.idea-fn-ref`,
`.idea-footnotes`, `.idea-footnotes-title`, `.idea-footnote-list`,
`.idea-footnote`, `.idea-fn-backlink`, on one that cites
`.idea-references` and on any page with citations of its own
`.idea-page-refs`, and on a minted note page
`.idea-footer`, `.idea-footer-title`, `.idea-context`, `.idea-backlinks`,
`.idea-page-list`, `.idea-page-row`, and around every note's header `.idea-head`.

An outline ROW carries the note's tags too, built the same way `#idea` builds
them for a note's heading and its card — one convention, three emission sites,
so a site that styles a todo note in the body can style the same note's row in
the index. MEASURED: a `todo`-tagged row is
`<li class="idea-outline-row idea-tag-todo">`, a two-tag note's row is
`<li class="idea-outline-row idea-tag-phd idea-tag-draft">`, and an untagged
note's row is exactly `<li class="idea-outline-row">`. Every key appears,
valued tags included, and the order between them is unspecified.
This is also the zero-API half of tag filtering: with the classes there, a site
can grey, badge or hide rows in its own CSS with no Typst-side filter at all.
The package ships NO default rule for any `.idea-tag-*` on the card or the note's
heading — a tag is free-form, not a recognised set, and styling one would
invent an opinion. A row's own marker is the exception, and only for a tag you
themed by name: `theme: (tags-color: ...)` publishes `--idea-tag-line` on that
tag's class, which the marker reads (see "Per-tag colour" below).

`.idea-tab` is a **hat**: a short stub of rule out of a frame's top-left corner
with a label sitting on its end, in the same `--idea-border-color` as the rule
beside it so the two meet at that corner, and in `--idea-label-font`. It appears
in three places — above a note's heading and above a window's title, where it
wraps the permalink in a `<span>`; and on `#ideas-outline`'s
`.idea-outline-title`, which carries `idea-tab` on the `<h4>` itself, because a
`<span>` may not contain a heading. A bare permalink standing in prose — a nested
window with no depth budget left — has no tab, because there is no frame for it to
rule off.

`.idea-outline-title` is that `<h4>`, and it is styled to uppercase at label size
rather than left to a site's heading scale: `font-variant: normal` and
`text-transform: uppercase` are asserted on the class, so a site setting
`h1..h6 { font-variant: small-caps }` cannot turn "Contents" into small caps
against the ids beside it.

`.idea-head` is the element around the tab and the heading beneath it, in a card
and on a minted note page alike. It exists because the two have to be real
siblings for the stylesheet to close the gap between them, and loose content is
not reliably that: Typst's HTML export wraps a leading inline run in a `<p>` of
its own in some cards and not others. On a minted page, where there is no
`.idea-box`, it is also that page's theme container — the element a `theme:`
override lands on.

The two footer sections have the same shape — a heading with rows flowing down
from it — because they are the same kind of thing: places this note is
reachable from. A page cannot be a `#window`, having no note to fold open, so it
is a plain link wearing the row shape a `#window` gives a note (`.idea-page-row`
carries the same left rule and indent as `.idea-window`), which is what lets
Context, note backlinks and page backlinks read as one list of entries. A
`#window` at `depth: 0` wears the same row, for the same reason: at that depth
it is a pointer to somewhere the note can be read, not a transclusion of it.

**Not yet:** a hover-preview link (`#preview`) was tried and reverted — it
would have composed `@rheo/tooltip`, but rheo's package asset auto-detection
only scans a project's own `.typ` files for package imports, not the packages
those files' packages import in turn. That would have forced every project
using it to also import `@rheo/tooltip` directly just to get its JS
auto-injected — a leaky requirement, not worth the feature.

## Tags

A free-form set of tags, nothing more — there is no fixed or recognised set and
no `kind`/`type` parameter. Notes are flat; tags are tags, not a taxonomy, and
NOT a task tracker.

```typst
#idea("meeting-notes", tags: ("draft", "review"))[...]
```

Underneath, a note's tags are a DICTIONARY: keys are the tag names, values are
whatever you put there, and a plain tag's value is `none`. Four forms are
accepted and all normalize to that one shape, so write whichever is closer to
hand:

| you write | it becomes |
| --- | --- |
| `tags: none` | `(:)` |
| `tags: "draft"` | `(draft: none)` |
| `tags: ("draft", "review")` | `(draft: none, review: none)` |
| `tags: (draft: none, priority: 1)` | unchanged |

`("draft", "review")` and `(draft: none, review: none)` are therefore the same
record, and a pinned id written one way in one place and the other way in
another is not a duplicate-id collision.

A VALUED tag is how a tag carries metadata rather than only naming itself:

```typst
#idea("ship-it", tags: (draft: none, priority: 1, depends-on: ("fetch", "build")))[...]
```

That is the primitive `@rheo/rookery-todos` builds its dependency graph on, and
`@rheo/rookery-dates` its `scheduled`/`deadline` dates. A value can be any
Typst value at all — an integer, an array, a `datetime`, content.

**Tags are UNORDERED.** Key order is unspecified as of 0.5.0 and nothing may
depend on it; sort them yourself if you need a stable sequence.

**Naming a key.** A tag key becomes a CSS class fragment (`.idea-tag-<key>`),
so keep keys class-safe — alphanumerics and hyphens. A package contributing
tags to notes it does not own should NAMESPACE its keys with a hyphen prefix
(`todo-deps`, `date-deadline`) rather than claiming a bare generic name, since
two packages both wanting `depends-on` would silently collide.

Each tag becomes its own `idea-tag-<key>` CSS class on the note's heading and
card, alongside the base `idea` class — EVERY key, valued tags included — so
style them in your own stylesheet.

**`show-tags: true`** on `#idea`/`#window` ALSO renders a note's tags as a row
of visible pills in the hat — the same `.idea-tab` the id and (with
`show-date: true`) the date sit on, in that fixed order: id, then tags, then
date. Off by default, the same mechanism as `show-date`:

```typst
#idea("meeting-notes", tags: ("draft", "review"), show-tags: true)[...]
#window("meeting-notes", show-tags: true) // pills again here, independently
```

An untagged note has no tags either way, so `show-tags: true` renders no pill
for it.

**Pills are FLAT TAGS ONLY** — those whose value is `none`. A valued tag keeps
its `.idea-tag-<key>` class everywhere, but gets no pill: `depends-on` rendered
as a pill would show its name and none of its dependencies, which is noise. A
package holding metadata in tags renders it its own way instead.

Each pill carries TWO classes: `.idea-tag`, the pill's own hook, and
`.idea-tag-<tag>` — the SAME class the note's heading and card already wear.
**`@rheo/rookery-search`'s own result-row chips wear it too** (alongside that
package's own `.rookery-search-tag`), so one project rule — `.idea-tag-draft {
color: ...; }` — styles that tag everywhere it shows up: the note's heading,
its card, an outline row, a hat pill, and a search result chip alike.

Five CSS custom properties style a tag. Two of them — `--idea-tag-size` and
`--idea-tag-radius` — have no `theme:` entry and use only the raw custom-property
mechanism, the same "your own stylesheet" pattern as `--idea-external-color`.
The other three are what `theme: (tags-color: (...))` (described below) sets
per-tag, as a rule on `.idea-tag-<tag>` in `@layer rookery-tags`. Being layered,
those generated rules beat the package's own CSS defaults and lose to YOUR
unlayered stylesheet — so a project can restate any of them for a themed tag:

| property | what it sets | default |
| --- | --- | --- |
| `--idea-tag-size` | the pill's font size | `--idea-label-size` (`0.57rem`) |
| `--idea-tag-radius` | the pill's corner radius | `999px` |
| `--idea-tag-color` | the pill's text colour | `--idea-id-color` (`gray`) |
| `--idea-tag-bg` | the pill's background | `rgba(128, 128, 128, 0.18)`, or `color-mix(in oklab, currentColor 14%, transparent)` where supported |
| `--idea-tag-line` | the colour of an outline row's marker, the tick off the outline's rule | `--idea-border-color`, else `--idea-link-color`. Set from a themed tag's `text` colour where it has one and its `background` otherwise |

### Per-tag colour: `tags-color`

Syntax, both value forms:

```typst
#show: rookery.with(theme: (
  tags-color: (
    draft: rgb("#3366ff"),                          // background only
    note: (background: rgb("#0000ff"), text: white), // background + text
    warn: (text: rgb("#aa0000")),                    // text only
  ),
))
```

A bare colour or CSS colour string is shorthand for `(background: ...)`. A tag with no entry in `tags-color` keeps the CSS default (`--idea-tag-bg`/`--idea-tag-color`, or your own project stylesheet rule) — `tags-color` only overrides the tags it names.

A `tags-color` KEY has to be usable as a CSS class — a letter or an underscore first, then letters, digits, hyphens and underscores — because the key becomes a selector. `tags-color: ("in progress": ...)` fails the build with a message naming the tag. A tag in a note's own `tags:` array is unconstrained, as before: the rule is about naming a colour for a tag, not about carrying one.

**Delivered as generated CSS rules, not as a style on the pill.** Each themed tag becomes one `.idea-tag-<tag>` rule setting `--idea-tag-bg`, `--idea-tag-color` and `--idea-tag-line`, wrapped in `@layer rookery-tags` and emitted once per page — by `#show: rookery` on every vertebra, and again on every page the package mints. So the colours reach every surface already wearing that class:

- the **hat pill** (`show-tags: true`);
- an **outline row's marker**, the hairline tick off the outline's own rule, through `--idea-tag-line`;
- **`@rheo/rookery-search`'s modal chips**, built in the browser and therefore beyond the reach of anything Typst could write inline.

It deliberately does NOT colour the **card** or the **note's heading**, which stay a rule for your own stylesheet to write. The pill already names the kind beside them, and colouring a note's own title makes the page's typography argue with its prose.

Two consequences worth knowing:

- **A project stylesheet can override a themed pill.** The generated rules sit in a layer, and unlayered CSS beats layered CSS whatever the source order, so your own `.idea-tag-draft { --idea-tag-bg: ... }` wins. The inline style this replaced could not be overridden at all.
- **A themed pill is NOT coloured in EPUB or PDF.** An EPUB here ships no stylesheet, so the `var()`s fall back to their defaults, and the paged target renders no hat at all. Accepted deliberately in exchange for the reach above, not overlooked.

Like the rest of `theme:`, this is **one value for the whole document** — apply the same arguments in every vertebra (see "The theme" above and "Setup").

`@rheo/rookery-search`'s own result-row chips DO pick up `tags-color`. That package renders them client-side from JavaScript, so no style Typst writes can reach them — but each chip carries `idea-tag-<tag>`, and `tags-color` arrives as a rule on that class, which applies whenever the chip enters the DOM. A chip reads `--idea-tag-bg`/`--idea-tag-color` behind its own `--rookery-search-tag-bg`/`--rookery-search-tag-color`, so a project styling every chip in the modal still wins over a themed tag.

### `tagged-idea` — build your own constructors

`tagged-idea(tag, value: none)` returns an `#idea` variant that prepends one
tag to whatever the caller passes. Define whatever vocabulary your project
wants:

```typst
#let note = tagged-idea("note")
#let todo = tagged-idea("todo")
#let claim = tagged-idea("claim")

#note("x")[...]                    // == #idea("x", tags: (note: none))[...]
#todo("y", tags: ("draft",))[...]  // == #idea("y", tags: (todo: none, draft: none))[...]
```

The returned function forwards everything untouched, so all three `#idea` call
forms still work — `#note[body]`, `#note("name")[body]`, `#note(<name>)[body]` —
along with every named argument (`title`, `level`, `minted`, `updated`,
`show-date`, `show-tags`).

`value:` binds a DEFAULT VALUE for the tag, for a wrapper whose tag means more
than its own presence. A caller naming that tag themselves wins outright, with
no deep merge:

```typst
#let flagged = tagged-idea("flag", value: "yes")
#flagged("a")[...]                       // flag: "yes"
#flagged("b", tags: (flag: "no"))[...]   // flag: "no"
```

Do NOT write `#let note = idea.with(tags: (note: none))`. An explicit `tags:` at
the call site OVERRIDES a value bound by `.with()`, so `#note("x", tags:
("draft",))` would silently drop `note` — the tag you reached for `#note` to get.
`tagged-idea` exists because `.with()` cannot express "merge, don't replace".

`@rheo/rookery-todos` builds its whole `#todo`/`#epic` surface on this.

### Reading tags back

A tag is not only a styling hook: the note records the tags it was created
with, and three accessors read them back.

`#context tags-of(name)` gives the note's tag NAMES — every key, valued tags
included, in unspecified order:

```typst
#context tags-of("y")   // -> ("todo", "draft")
```

`#context tag-value(name, key, default: none)` gives ONE tag's value:

```typst
#context tag-value("ship-it", "priority")           // -> 1
#context tag-value("ship-it", "nope", default: 4)   // -> 4
```

A plain tag's value is `none`, which is indistinguishable from a `default:
none` on an absent key — ask `tags-of` when the question is presence.

`#context tag-data()` gives every note's whole tag store at once, keyed by full
id:

```typst
#context tag-data()   // -> ("idea:ship-it": (draft: none, priority: 1), ..)
```

Use the bulk form when you are walking the corpus: `tags-of` and `tag-value`
each resolve the registry for ONE note, so N notes cost N reads, where one
`#ideas()` plus one `#tag-data()` covers everything and the two join on `id`.

All three take the same name forms as `#window` and `#hyperlink` — a bare name,
a full id, or a label — and answer emptily for an untagged note and for an id
that does not exist. An unknown id is deliberately not an error: a caller asking what
something is tagged is filtering, not dereferencing, and a filter that panics
on the first miss is useless. That is what lets another package pick out a
tagged subset of your notes without reaching into rookery's internals.

Rookery uses this itself: `#window(tags: ...)` transcludes every note carrying
a tag, alongside any it was given by name. See "Referencing a note" above.
`#ideas-outline(tags: ..., match: ..., filter: ...)` narrows an INDEX the same
way — see "Outlining notes" above.

Filtering an index by a tag does not make tags a taxonomy or a task tracker
either, though it is the feature that most invites the opposite reading.
`tags: "todo"` looks like a status field and is not one: nothing validates the
string, no tag is recognised or reserved, a note carrying `todo` means only that
you wrote `todo` on it, and a filter is a question asked at one call site rather
than a schema the rookery holds you to. Free-form array of strings, still.

## Dates

Resolution order, most specific first:

1. The `minted:` / `updated:` arguments passed to `#idea`, when given.
2. The containing document's own `#set document(date: ...)`.
3. Otherwise: no date is recorded. A date is never invented (no
   `datetime.today()`, no file mtimes, no VCS).

```typst
#set document(date: datetime(year: 2026, month: 1, day: 10))

#idea("a")[Inherits the document date.]
#idea("b", minted: datetime(year: 2025, month: 5, day: 1))[Overridden, this note only.]
```

A date is always RESOLVED and stored on the note's registry record, but
rendering it is opt-in — `show-date: false` by default, on both `#idea` and
`#window`, so an unconfigured note's header is just the title and its id:

```typst
#idea("a", show-date: true)[Shows its date at the right-hand end of the hat.]
#window("a", show-date: true) // shows it again here, independently
```

**Where it renders is the hat** — the `.idea-tab` rule across the top of a card
or a window, with the id on the stub at the left end and the date pushed to the
far right. It is the frame's metadata, not a subtitle: it used to sit inside the
`<h2>` on a card and as a third item in a window's summary row, which made one
piece of information wear two classes in two places. Now it is `.idea-date`
inside `.idea-tab`, wherever it appears. The top rule does not resume on the
date's far side — the hat draws one stub, to the left, and stops at the id.

**Which date is `updated`**, not `minted`: the date a reader wants off the top of
a card is when the note was last touched. `updated` falls back to `minted`, which
falls back to the document's own date, so a note that never says `updated:` looks
exactly as it did.

A note's own minted page is the exception: there the date shows **always**, with
no `show-date:` to gate it — and its tags render as pills too, same hat, same
"always", no `show-tags:` to gate that either. Nobody writes an `#idea` call for
that page — `.marrow.typ` mints it from the registry — and a note's own page is
the one place its date and its tags are metadata rather than a decoration on
someone else's prose.

The two call-site settings are independent: passing `show-date: true` to a
`#window` surfaces the date even when the note's own `#idea` left it hidden, and
vice versa — nothing links them beyond both defaulting off.

On a paged target there is no hat to hang it on, so `#idea` and `#window` keep
printing the date where they always did; only *which* date it is has changed.

## Footnotes

A footnote belongs to the idea it was written in, not to the page that happens
to be showing it. Import `footnote` alongside `idea` and write it exactly as
you always have:

```typst
#import "@rheo/rookery:0.5.0": idea, footnote

#idea("etal")[A claim#footnote[The evidence.] worth qualifying.]
```

Numbering is per idea, so two notes on one page may each carry a footnote 1 —
the point rather than a collision, since a reader meets a note in the context
of one idea and a number counting the whole page would be counting something
they cannot see. The bodies render in a `Footnotes` block at the end of the
idea.

That block follows the note everywhere the note goes — the page it was hatched
in, every `#window` on it, its own minted page — and each of those gets its OWN
block with its own anchors. They have to be separate: a footnote reference is a
same-page fragment, so a window on another page needs its target on that page.
On a minted page the block sits between the body and the Context/Backlinks
footer, keeping the note's own apparatus attached to the note and leaving the
footer last as the way back out.

A `#window` with `limit:` lists only the footnotes whose references survive the
truncation, so a shortened note never shows an entry with nothing pointing at
it.

**`#footnote` has to be imported to take effect**, and Typst imports are
per-file: every vertebra that writes a footnote needs `footnote` in its own
import list, the same way each one needs the template for the `ref` rule.
Omitting it used to be silent — the body went to the page's endnote section,
numbered page-wide, and the idea rendered no block at all — so it is now a
build error naming the import to add. A footnote in ordinary page prose,
outside any idea, is untouched by that check and still behaves exactly as
Typst's does: page-wide numbering, body in the page's own endnote section.
`#show: rookery` installs that fallback, so a document that never applies the
template and writes a rookery `#footnote` in bare prose renders nothing for it
— the same shape of caveat as `@idea:etal` rendering a bare figure number
without the template.

The reason this is a shadowed `#footnote` rather than a show rule over Typst's
own is that Typst's cannot be intercepted. Its HTML exporter collects footnote
bodies by introspection, so neither `show footnote: it => ...` nor
`show footnote: none` keeps a body out of the page's endnote section; the
import site is the only place the decision can be made.

## Bibliographies

One bibliography for the whole rookery, configured on the template with Typst's
own `#bibliography` arguments:

```typst
#show: rookery.with(bibliography: arguments(
  bytes(read("refs.bib")),
  style: "chicago-author-date",
))
```

**Bytes, not a path.** Typst resolves a path relative to the file the call
appears in, and every call this package makes appears inside the package — a
path would be looked for next to `lib.typ`. `bytes` carries its data instead, so
your own `read()` resolves against your own file. It is one of the source types
`#bibliography` already accepts, so this is still literally its argument list,
and a path is rejected up front with the `read()` form to write instead. Both
BibTeX and Hayagriva work; the format is recognised from the content, there
being no filename left to go on.

Like the prefix and the theme, it is one value for the whole document — see the
note under "Setup" for why, and apply the same arguments in every vertebra.

`style:` defaults to an author-date style when you pass none. Citation numbering
in Typst is document-wide and cannot be reset: CSL assigns the numbers and no
counter controls them, so under a numeric style the third idea on a page reads
`[3]`, and a note's own page can show its only reference as `[7]`. An
author-date style has no numbers and the question does not arise. A numeric
style is still honoured without complaint — this is a default, not a
restriction.

Every idea that cites anything renders its own `References` block at the end of
it, and an idea that cites nothing renders none: no empty heading. Like
footnotes, the block follows the note to each surface it appears on — its hatch
page, every `#window` on it, its minted page — each with its own copy, since a
citation link is a same-page fragment and a window on another page needs its
target on that page. On a minted page it sits between the body and the
Context/Backlinks footer.

Citations written in page prose, outside any idea, are collected into a
page-level `References` block after the page's content. Getting them there
takes a little machinery you may see in the markup: rookery emits an
unlabelled, usually empty claiming block before every idea, because Typst
assigns each citation to the nearest bibliography FOLLOWING it, and without one
a citation written above an idea would land in that idea's list. An idea never
sees the prose around it, so that block cannot be conditional.

The same rule decides what happens when an idea contains a `#window`: the
window's own block comes first and claims what precedes it, so a citation
written before a window in the same note is listed under the window rather than
under the note. It is the reader's next block either way.

**A window's citations resolve inside the window**, not on the note's own page.
Linking them across was tried and dropped: redirecting a citation means
de-registering it, a de-registered citation renders nothing, and the package
would then have to format the marker itself — which means reading authors and
dates out of your bibliography and reimplementing what Typst already does.
Rookery reads the key list and nothing else, only ever to answer "does this idea
cite anything"; Typst formats every citation and every entry.

## Standalone note pages (rheo only)

Importing this package mints one output page per note automatically, at
`ideas/<id>.html` — e.g. `ideas/etal.html` for `<idea:etal>`, the prefix
stripped off whatever it is set to — via a package
`.marrow.typ` that rheo inlines at the bundle root. No `rheo.toml` entry and
no project file needed. Typst will print `warning: bundle export is
experimental` — expected, not a sign anything is wrong.

This is the part that needs **rheo >= 0.5.2**: inlining a package's
`.marrow.typ` landed there, and an older rheo passes over it in silence rather
than failing, so the symptom is not an error but an absence — no `ideas/`
pages, and links into them that resolve to nothing.

Each minted page shows the note's title and permalink id, then its body, then
a footer with two parts — each omitted, rather than left empty, when it has
nothing to say.

### A landing page for the whole rookery: `index-page`

`ideas/` is the parent directory of every permalink this package mints, and the
URL a reader will guess. Rookery mints `ideas/index.html` there by default: a
heading, a count, and every note in the rookery linked to **its own minted
page**, carrying its date and its tags. The rows wear `#ideas-outline`'s
classes — `.idea-outline`, `.idea-outline-row`, `.idea-tag-<tag>` — so a
stylesheet that already knows the outline knows this page too, and it needs no
CSS of its own. They are listed in id order, which is what `#ideas()` returns.

It is NOT `#ideas-outline(rookery-wide: true)`, and the difference matters: the
outline links each row to the note's anchor on the vertebra that authored it,
which is right for a table of contents sitting on that page and wrong for a page
whose whole job is to index the minted ones.

Turn it off if a project already has its own index — a homepage built from
`#window(tags: "post")`, say — and doesn't want a second one published under it:

```typst
#show: rookery.with(index-page: false)
```

The page goes through `idea-page-template` exactly as a note page does, so it
inherits your project's chrome. It is the one minted page that is not a note,
and the template sees that: `id` is `none` and `note` is an empty dictionary. A
template that assumes a string id needs one branch —
`rookery/0.5.0/demo/rheo/content/lib.typ` carries the two-line version.

### Giving minted pages your own chrome

A minted page is a separate document spliced in at the bundle root, *outside*
every vertebra — so it inherits nothing from the `#show:` your project applies
to its own pages, and by default has no site header or nav.
`idea-page-template` is how you hand one over:

```typst
// One named, top-level function...
#let idea-page(id: none, note: (:), doc) = {
  show: chrome.with(current-page: id)
  doc
}

// ...registered once, in the template every vertebra applies.
#show: rookery.with(idea-page-template: idea-page)
```

It is called once per note, wrapping the **whole** minted page — heading, body
and footer — so it sees exactly what a vertebra's own `#show:` would.

- `id` is the note's full id (`idea:etal`), the same string `#window` and
  `@idea:etal` name it by, and the natural "which page am I on" key.
- `note` is the note's registry record — `title`, `minted`, `updated`,
  `origin` (the handle of the page it was written in) and `links` — so a
  richer idea-page header needs no query.

Make it a **named top-level binding**, not a closure written inline inside the
template that registers it. The package holds it on a document-wide state, and
a fresh closure per vertebra puts a different value on that state's timeline
for each one; a named binding is one value however many vertebrae reference
it.

Apply your *chrome* from it rather than your whole page template, and split
that chrome out of the template if you have not already — otherwise the two
have to reference each other. A minted page also has no need to re-apply
`#show: rookery`: every vertebra has already set the prefix, theme and window
depth by the time one is minted.

Left unset, minted pages are bare, exactly as before.

**Context** is the page the note was *written* in:

```
Context: Rookery under Rheo
```

The link goes to the note's own anchor on that page, not to the top of it — a
minted page shows a note stripped of everything around it, and this is the way
back to the argument it was written inside. The name shown is rheo's own title
for that vertebra, so give a page a `#set document(title: ...)` or the footer
will read as its title-cased filename ("Index").

Where a note was written is captured at `#idea` time, because that is the only
moment anything knows it: a minted page is a separate document that inherits
nothing, and a `#window` can transclude a note onto any number of other pages.

**Backlinks** is everything that points at this note — an index of what refers
here. Three things count as pointing, all of which a reader would call a link:

```typst
#link(label("idea:etal"))[...]   // an explicit jump
@idea:etal                        // a reference
#window("etal")                    // a transclusion
```

An entry is whatever **directly** contains the link:

- a **note**, if the link is inside one — rendered as a folded `#window`, which
  you can open in place;
- otherwise the **page**, if the link is in its prose or in a page-level
  `#window` — rendered as a plain link, since there is no note to fold open.

Attribution is to the innermost container and stops there. A link inside a
note belongs to that note and not also to a note enclosing it, nor to the page
holding either. So a page whose only links to a note are inside its own notes
does not appear; those links are already listed, as notes. Each entry appears
once, however many times it links here.

The note's **own page never appears** — Context already names it, and says it
more precisely, linking to the note's anchor rather than to the top of the
page. A page that holds a note and also `#window`s it qualifies for both, which
is exactly the case this rule exists for.

A transcluded body counts for the note it came from, not for whichever page is
showing it — a note `#window`ed on five pages does not thereby give its own
outbound links to those five pages.

Note entries come from a map built at `#idea` time: each note's body is walked
once for outbound links, and the backlink list is that map inverted.
Registration is the only place that can happen, since a link is an element
buried in a content tree and there is no way to ask an element which note it
sits *inside* — which is exactly what a backlink asks. Page entries can't come
from there (a link in page prose belongs to no note), so they come from a
`query()` over the document instead, with `#idea` and `#window` bracketing their
content so a single ordered pass can tell depth 0 — the page itself — from
anything nested.

Where those pages exist, they are what the permalink points at — in `#idea`'s
heading, in a `#window`'s summary, and in a nested window's collapsed form alike,
since all three are the same affordance. The same-page `#id` fragment a
permalink would otherwise carry is a no-op for a reader already looking at
that heading; the minted page is what they actually want.

Hrefs are depth-relative to the page doing the linking (`../ideas/etal.html`
from a nested vertebra), and fall back to the note's in-page anchor when no
page is minted — under plain `typst compile`, or for the combined PDF.

What does NOT redirect is anything addressing the note's Typst label:
`#link(label("idea:etal"))` and `@idea:etal` still resolve to wherever `#idea`
was actually called. A minted page does NOT reuse the `idea:<id>` label (two
elements can't share one label without breaking `#link`/`#window`/
`link-to-page`/`link-to-anchor` resolution), so the label keeps its original
home by construction.

Set `[html] auto_detect_packages = false` in `rheo.toml` to turn this off (it
disables every package-driven behaviour, not just this one). Skipped
automatically for the combined PDF target, which cannot create output files
at all.

## Limitations

- **`window-depth` is a RECURSION depth, and it is finite.** It counts how many
  levels of transclusion are allowed before links take over:

  | value | what happens |
  | --- | --- |
  | `0` | no windowing anywhere — every `#window` is a link row |
  | `1` | a window renders its note once; a window inside that body is a link row |
  | `n` | `n` levels render, level `n+1` is a link row |

  `1` is the default, and `depth: n` on one call site overrides it there. A
  bottomed-out window is ONE rendering wherever it ran out: the note's title,
  linked to its page, in the same row shape a page backlink uses — a titleless
  note falls back to its `[idea:x]` permalink, having nothing else to be named
  by. What is permanent is that the budget is finite: that is what makes
  self-windows and window cycles safe to compile. See "Nested windows, and
  `window-depth`" above.
- An author's own `<label>` written inside a note's body is duplicated if
  that note is transcluded elsewhere — a note owns exactly one id, attached
  by `#idea` itself.
- Backlinks appear on minted note pages, so under rheo only — see "Standalone
  note pages".
- Typst's own `#footnote` inside an idea is a build error, not a page-level
  escape hatch. Nothing can intercept it (see "Footnotes"), so the alternative
  was letting it silently put a note's body somewhere the note has no block.
  A page-level footnote still works everywhere outside an idea.
- Citation numbering is document-wide under a numeric style, so a note's own
  page can show its only reference as `[7]`. CSL assigns those numbers and no
  Typst counter resets them; an author-date style, the default, has none.
- A window's citations resolve to the window's own reference block rather than
  to the note's page — see "Bibliographies" for why linking them across is not
  available.

## Requirements

- typst >= 0.15.
- `--features html` on EVERY build, not just HTML/EPUB output. `#idea` calls
  `std.target()` unconditionally, which typst gates behind that feature
  regardless of output format — even a plain PDF build needs the flag, or it
  hard-errors.
- rheo >= 0.5.2 — but only if you build with rheo at all. The rheo-only half of
  the package (minted note pages, the hrefs that point into them, backlinks)
  rides on rheo inlining a package's `.marrow.typ` at the bundle root, and
  0.5.2 is the first release that does. An older rheo does not complain: it
  ignores the file, mints nothing, and every `@note:etal` then links at a page
  that was never written. Plain `typst compile` is unaffected — the standalone
  half has no floor beyond typst itself, see "Two modes".

  OBSERVED (rheo 0.5.2, built from source at tag `v0.5.2`; typst 0.15.1):
  `rheo compile .` in `demo/rheo` mints all five `ideas/*.html` pages with no
  warnings, and `./check.sh` prints `demo/rheo OK` — all eight blocks, including
  the generated `@layer rookery-tags` assertions. The floor is measured, not
  inferred: this package reads only `state("rheo-handle")`, `rheo-document()`,
  and `rheo-context`'s `target`/`ext`/`spine-flat`, every one of which 0.5.2
  provides. CI installs the 0.5.2 release and runs that demo, so the version
  this line promises is the version actually tested.

## Build and local development

Pure Typst, no build step: `typst.toml`'s entrypoint points straight at
`src/lib.typ` (and `src/rookery.css`), so editing `src/` takes effect
immediately — no `dist/`, no copy step to forget to re-run.

```sh
# from the repo root, only if @rheo/rookery does not already resolve
ln -sfnT "$PWD/rookery" ~/.cache/typst/packages/rheo/rookery
```

Only needed once, and only if it doesn't already resolve — e.g. if the whole
repo is symlinked in as the `rheo` namespace, this is already covered. Note
`-T`: without it, if `~/.cache/typst/packages/rheo/rookery` already exists as
a directory, a bare `ln -sfn` drops a self-referential link *inside* it
instead of replacing it.

No package-specific devShell either: this repo's own root `flake.nix`/`.envrc`
already provide `just` and `typst`, and direnv finds them by walking up from
anywhere under this directory. `demo/pure/` has its own `just watch` for
live-rebuild; for the rheo side, `just watch` in the `rookery.ohrg.org` repo
picks up edits to `src/` on the next rebuild, since the whole of this repo is
symlinked into the package cache as the `rheo` namespace.
