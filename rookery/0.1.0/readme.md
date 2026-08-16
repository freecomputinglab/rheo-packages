# @rheo/rookery

Atomic, interlinked, transcludable notes for Typst — Zettelkasten-style, and
rheo-aware where rheo is present.

A note exists ONLY where you write `#idea("name")[...]`. There is no document
show rule and no "every heading is a note" behaviour — a labeled heading is
just a labeled heading. `#idea[body]` (no name) works too: the package
generates a sequential id and shows it to you as a `[idea:1]`-style permalink
next to the note, since with no name there's no other way to know it.

```typst
#import "@rheo/rookery:0.1.0": idea

#idea[A frictionless note — reads its generated id off the [idea:1] permalink.]
#idea("etal")[A pinned note — its id is always `idea:etal`.]
```

Full signature: `idea(level: 1, title: none, tags: (), minted: none,
updated: none, show-date: false, ..args)`, where the sink accepts the body
alone, `(name, body)`, or `(<name>, body)` — the name may be a string or a
Typst label, identically.

## Setup, and the `idea:` prefix

Nothing above needed any setup, and that stays true. One optional template
does all of it in a line, and is the only place anything is configurable:

```typst
#import "@rheo/rookery:0.1.0": rookery, idea, window
#show: rookery.with(
  prefix: "note",                 // ids are now `note:etal`
  window-depth: 1,                // a window inside a window unfurls one level
  theme: (
    link-color: "rgba(230, 140, 0, 0.16)",  // hover background on any link
    fold-color: "rgba(255, 190, 40, 0.07)", // ...and on a foldable block
    date-color: rgb("#a08a5a"),
  ),
)
```

`#show: rookery` does exactly five things: it publishes the id prefix, the
nested-window depth, the minted-page template (`idea-page-template`, see
"Standalone note pages") and the theme, and it installs `link-to-page` (see below and "Referencing a note") so
`@note:etal` renders the note rather than a bare figure number. It sets no
other styles, wraps `doc` in nothing, and emits nothing of its own — on a
document with no notes in it, it is a no-op, and even the `ref` rule passes
every non-rookery reference straight through. Pass `refs: false` to keep the
rest and skip that rule.

`ref-target: "page"` (the default) picks `link-to-page`, so `@note:etal` links
to the note's own minted page. Pass `ref-target: "anchor"` to pick
`link-to-anchor` instead, making every `@note:etal` in the document link to
the note's in-context anchor, the same destination `#link(label("note:etal"))`
always uses. Ignored when `refs: false`, since there is then no installed rule
for it to configure.

`prefix` must be a non-empty string with no `:` in it (the separator is added
for you).

### Nested windows, and `window-depth`

A note you transclude may itself contain a `#window`. By default that nested
window does **not** unfurl: it collapses to its `[idea:etal]` permalink, so
the block you opened shows one note rather than a tree of them. A nested
`#idea` — one note written literally inside another's body — is a different
thing and always renders in full, whatever the depth.

`window-depth: n` (default `0`) unfurls `n` levels of nested windows as real
windows, collapsing at the `n+1`th; `#window(..., depth: n)` overrides it for
one call site. Per call site because both readings are reasonable on the same
page: an index of forty backlinks wants the collapse, a homepage showing one
note in full may want a level or two.

The budget is what makes this safe. A note that windows itself, or two notes
that window each other, would otherwise expand forever; with a depth they
bottom out at the collapsed permalink, and there is no configuration that can
make them not.

Depth is not free — each level re-renders the transcluded note's body, so `n`
levels over a fan-out of `k` windows is `k^n` blocks in the page. Small
numbers.

### The theme

Four colours, the whole of what the package will style for you:

| key | what it colours | default |
| --- | --- | --- |
| `link-color` | hover background on **any** rookery link | `rgba(128, 0, 255, .12)` |
| `fold-color` | hover background on a foldable window block | `rgba(0, 100, 255, .05)` |
| `id-color` | the `[idea:etal]` permalink's text | `gray` |
| `date-color` | an idea's/window's date, where shown | `gray` |

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
  every target, not just HTML.

  `folded: true` starts the block CLOSED. That is all it does: a folded window
  and an open one are the same block, so `limit:` stays meaningful under
  either and the two are orthogonal. Under a paged target, where there is
  nothing to click, `folded` is ignored and the body always shows.

  `show-date: true` shows the note's minted date beside the permalink — off
  by default. See "Dates" below.

  `depth: n` unfurls `n` levels of `#window`s written inside the transcluded
  note; `auto` (the default) takes the document-wide `window-depth`, itself
  `0`. See "Nested windows, and `window-depth`" above.

  See "The click budget" below for what clicking each part does.
- `@idea:etal` — the terse form, but on its own it renders as a bare figure
  NUMBER (Typst's stock `@` rendering for a labeled figure — a note's id
  lives on a hidden anchor figure). `#show: rookery` installs the rule that
  fixes this, so if you already applied the template there is nothing to do.
  Without it, apply the exported `link-to-page` by hand:

  ```typst
  #import "@rheo/rookery:0.1.0": idea, window, link-to-page
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
  #import "@rheo/rookery:0.1.0": idea, window, link-to-anchor
  #show ref: link-to-anchor
  ```

  `#show: rookery.with(ref-target: "anchor")` does the same thing document-wide
  when you're using the template rather than importing `link-to-anchor`
  directly.

## Outlining notes

`#ideas-outline()` lists the current page's own notes as a nested tree.

```typst
#import "@rheo/rookery:0.1.0": ideas-outline
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
`.idea-title`, `.idea-label`, `.idea-date`, `.idea-tag-<tag>`, `.idea-ref`,
`.idea-window`, `.idea-window-summary`, `.idea-window-title`, `.idea-window-date`,
`.idea-window-body`, `.idea-window-details`, `.idea-outline`,
`.idea-outline-row`, on an idea that carries footnotes `.idea-fn-ref`,
`.idea-footnotes`, `.idea-footnotes-title`, `.idea-footnote-list`,
`.idea-footnote`, `.idea-fn-backlink`, on one that cites
`.idea-references` and on any page with citations of its own
`.idea-page-refs`, and on a minted note page
`.idea-footer`, `.idea-footer-title`, `.idea-context`, `.idea-backlinks`,
`.idea-page-list`, `.idea-page-row`.

The two footer sections have the same shape — a heading with rows flowing down
from it — because they are the same kind of thing: places this note is
reachable from. A page cannot be a `#window`, having no note to fold open, so it
is a plain link wearing the row shape a `#window` gives a note (`.idea-page-row`
carries the same left rule and indent as `.idea-window`), which is what lets
Context, note backlinks and page backlinks read as one list of entries.

**Not yet:** a hover-preview link (`#preview`) was tried and reverted — it
would have composed `@rheo/tooltip`, but rheo's package asset auto-detection
only scans a project's own `.typ` files for package imports, not the packages
those files' packages import in turn. That would have forced every project
using it to also import `@rheo/tooltip` directly just to get its JS
auto-injected — a leaky requirement, not worth the feature.

## Tags

A free-form array of tag strings, nothing more — there is no fixed or
recognised set and no `kind`/`type` parameter. Notes are flat; tags are
tags, not a taxonomy, and NOT a task tracker.

```typst
#idea("meeting-notes", tags: ("draft", "review"))[...]
```

Each tag becomes its own `idea-tag-<tag>` CSS class on the note's
heading, alongside the base `idea` class — style them in your own stylesheet.

`#note` and `#todo` are pure sugar over `tags`, prepending their own tag to
whatever the caller passes:

```typst
#note("x")[...]              // == #idea("x", tags: ("note",))[...]
#todo("y", tags: ("draft",))[...]  // == #idea("y", tags: ("todo", "draft"))[...]
```

Still no kind or type parameter, and still no recognised set of tags — these
are two constructors for the two common cases, nothing more.

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
#idea("a", show-date: true)[Shows its date beside the permalink.]
#window("a", show-date: true) // shows it again here, independently
```

The two are independent per call site: passing `show-date: true` to a `#window`
surfaces the date even when the note's own `#idea` left it hidden, and vice
versa — nothing links the two settings together beyond both defaulting off.

## Footnotes

A footnote belongs to the idea it was written in, not to the page that happens
to be showing it. Import `footnote` alongside `idea` and write it exactly as
you always have:

```typst
#import "@rheo/rookery:0.1.0": idea, footnote

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

## Standalone note pages (rheo only)

Importing this package mints one output page per note automatically, at
`ideas/<id>.html` — e.g. `ideas/etal.html` for `<idea:etal>`, the prefix
stripped off whatever it is set to — via a package
`.marrow.typ` that rheo inlines at the bundle root. No `rheo.toml` entry and
no project file needed. Typst will print `warning: bundle export is
experimental` — expected, not a sign anything is wrong.

Each minted page shows the note's title and permalink id, then its body, then
a footer with two parts — each omitted, rather than left empty, when it has
nothing to say.

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

- **`#window` expands exactly ONE level.** A note transcluded via `#window`
  renders its content once; if that content itself contains a `#window`, the
  inner one collapses to its own `[idea:x]` permalink instead of expanding
  further. This is deliberate and permanent (it's what makes self-windows and
  window cycles safe to compile), not a tunable depth.
- An author's own `<label>` written inside a note's body is duplicated if
  that note is transcluded elsewhere — a note owns exactly one id, attached
  by `#idea` itself.
- Backlinks appear on minted note pages, so under rheo only — see "Standalone
  note pages".
- Typst's own `#footnote` inside an idea is a build error, not a page-level
  escape hatch. Nothing can intercept it (see "Footnotes"), so the alternative
  was letting it silently put a note's body somewhere the note has no block.
  A page-level footnote still works everywhere outside an idea.

## Requirements

- typst >= 0.15.
- `--features html` on EVERY build, not just HTML/EPUB output. `#idea` calls
  `std.target()` unconditionally, which typst gates behind that feature
  regardless of output format — even a plain PDF build needs the flag, or it
  hard-errors.

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
