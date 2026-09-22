# @rheo/contents-panel

A contents box pinned beside a page, each row filling left to right as the
reader moves through the section it names. One `#show` rule at the top of a
vertebra, and nothing else:

```typst
#import "@rheo/contents-panel:0.1.0": contents

#show: contents
```

The rows come from the page's own headings. Clicking one scrolls to it; the
row for the section being read fills in proportion to how far through it the
reader is; rows already passed stay marked. Below a breakpoint the box is not
drawn at all.

Modelled on the contents box at [anil.recoil.org](https://anil.recoil.org),
whose `toc.js` is the source of the progress geometry here — a section runs
until the next entry at the same depth or shallower, which is what keeps a
top-level row filling while its own subsections scroll past.

## What it emits

A `<nav class="rheo-panel-box rheo-contents-box">` inside an
`<aside class="rheo-panel-aside rheo-contents-aside">`, plus one empty
`<div class="rheo-contents-anchor" id="...">` before each entry to scroll to.

**Two prefixes, on the same two elements.** `rheo-panel-*` is the frame — the
aside's position, the two rules, the hat, the title, the arrow — and
`rheo-contents-*` is the list. A project's own layout rules belong on the
first, which is also all a bare `frame` emits; see *The frame on its own*.

**The document is not wrapped in anything**, and that is not a stylistic
choice. `#show: contents` at the top of a vertebra composes *outside* the
project's own template, so the template's content — including its
`set document(title: ..)` — would land inside any element this package put
around it, and Typst rejects that outright with *"document set rules are not
allowed inside of containers"*. Measured against waterline's weeknotes: a flex
wrapper, the obvious layout, fails the compile for every vertebra whose
template sets a document title, which is most of them.

So the box is a *sibling* of the page's content, `position: fixed` against the
right edge of the viewport, and `reserve:` pads the page to keep clear of it.
The practical difference from a sticky column is that the box is pinned from
the first pixel of scroll rather than travelling with the page — arguably the
better behaviour for a box whose whole job is to say where the reader is.

## Two progress signals

A row fills to show how far through **that section** the reader is. The hat
fills to show how far through **the whole page** they are — set as
`--rheo-contents-page-progress` on the box and drawn as a gradient behind the
title, so nothing is added to the markup.

`--rheo-panel-hat-pad-top` gives the title room above it inside the hat,
so the fill does not start flush against the top of the letterforms. It is
added back into the hat's lift: `height` is the content height, so padding
would otherwise push the bottom-aligned rule down and reopen the corner.

The arrow is centred on the hat rather than sharing the title's baseline —
at 1.5× the text size it would otherwise stand proud of the track and stay
uncovered when the bar reaches the end of the page.

The track starts at the right-hand tip of the hat rule rather than at the
header's left edge, which is outside the frame: a full-width track ran under
the rule itself and read as the bar having a permanent head start. It is
offset by `background-position`/`background-size` rather than by insetting the
element, so the rule, the title and the arrow stay where they are.

`--rheo-contents-page-fill` is that wash, a little darker than a row's fill:
the row fill sits under small type in a narrow band, where the title is a
larger and more open target, so the same value reads lighter there. Fainter
values were tried first and do not read as a bar at all. It has to be mapped
explicitly in rookery mode rather than derived from the accent: a custom
property substitutes its `var()`s where it is **declared**, so the `:root`
default had already resolved against the package's own accent before the
rookery block changed it, and the track came out blue on a green site.

The title defaults to `auto`, meaning the document's own
`set document(title: ..)`. Measured: that resolves per vertebra under rheo,
despite the whole project compiling as one Typst document.

## Framed like an idea

The panel takes the shape `@rookery/core` gives a note: a left rule with the
content padded off it, the hat pulled back over that rule's outer edge and
lifted clear of the box so its rule lands on the box's top edge with the title
resting **on** the rule — the two meeting as a corner — plus a bottom rule to
close it — which an idea has no need of and a contents list
does, having a definite end. Square, not rounded: a rounded panel beside
square ideas reads as a different kind of object.

`--rheo-panel-border` is the frame's colour (the accent by default, not a
neutral hairline — it marks the block rather than dividing it),
`--rheo-panel-rule-width` its thickness, `--rheo-panel-pad` the content
inset, and `--rheo-panel-title-font` the title's face (monospace by
default — it is a label on a rule, not prose).

Padding is on the left only, where the rule is. Not on the right: both
progress fills are backgrounds on elements spanning the content box, so any
right padding stops them short of the frame and they no longer finish level
with the right-hand end of the bottom rule — which is exactly the moment, at
the foot of the page, when they are meant to say "that is all of it".

`--rheo-panel-hat-width` is the hat rule's length, separable from the
padding it is normally derived from because an `em` here resolves against the
*panel's* font size, which need not be the size the thing it matches was drawn
at. In rookery mode the script copies that length and the padding across
**resolved**, in pixels: passing `--idea-pad: 0.5em` through as a token drew an
8.8px hat against the idea's 12.7px, since the idea's box is set larger than
the panel.

One size governs the whole panel: `--rheo-panel-font-size`, set on the box
so the header, the numbers and the labels all inherit it. In rookery mode it
takes `--idea-label-size`, so the panel is sized as an idea's hat is.

## The frame on its own

That shape is a function, and `contents` is one caller of it:

```typst
#import "@rheo/contents-panel:0.1.0": frame

#frame(cap-text: "about the author")[
  Prose the page hands it, rather than a list the package derived.
]
```

The reason to want it is that every fiddly part of this package is in the
frame, not the list: the hat's lift, the corner it makes with the left rule,
the negative margin pulling it back over that rule, the track that starts at
the rule's tip. A project wanting a second panel beside its pages — an
about-the-author note on a homepage, where a contents list has nothing to
report — had to restate all of it and keep the copy in step.

A bare frame has no rows, so `contents.js` leaves it alone after one thing:
where it sits. That part is frame-level — see *Where it sits* — and the two
selectors that drive it are `frame` arguments. Everything else the script does
belongs to the list, and a panel that is not the page's contents reports none
of it.

| | |
| --- | --- |
| `cap-text` | the name on the hat, or `none` for no hat at all |
| `top` | draw the jump-to-top arrow (default `false`) |
| `aria-label` | the landmark's accessible name |
| `element` | the tag the box is, inside the aside (default `div`) |
| `side` | which edge the panel is pinned to, `right` (default) or `left` |
| `rookery` | adopt `@rookery/core`'s `--idea-*` palette |
| `offset-selector` | selector for the project's sticky header, if it has one |
| `align-selector` | selector to line the panel up with before scrolling |
| `aside-class` / `box-class` / `box-attrs` | what a caller hangs its own rules and data attributes on |

`element` is `div` by default and `nav` for a contents box, which is what a
list of links to the page's own sections is. A panel of prose emitted as a
`nav` is a navigation landmark with no links in it, which is worse than no
landmark at all.

On the paged and EPUB targets a frame emits its body and nothing else — the
hat and the rules are a pinned box's furniture, and there is nothing to pin on
a page.

`demo/rheo/content/frame.typ` is the worked example, asserted in `check.sh`:
the frame comes out a frame, `cap-text` reaches the hat, and none of the list's
classes ride along.

## Colours

Every colour is a custom property, declared on `:root` with a two-step
fallback: a project variable first, then a literal that reads acceptably in a
project defining nothing. Declarations sit on `:root` but every rule that
paints is scoped to a `.rheo-panel-*` or `.rheo-contents-*` class, so the
stylesheet restyles nothing on a page that does not render the box — and a
project overriding a variable in its own `body { .. }` rule wins, which it did
not when the declarations lived on `body:has(.rheo-contents-aside)`.

| variable | falls back to | then |
| --- | --- | --- |
| `--rheo-panel-accent` | `--color-link` | `#2563eb` |
| `--rheo-panel-title-fg` | `--color-muted` | `#9ca3af` |
| `--rheo-panel-border` | `--rheo-panel-accent` | |
| `--rheo-panel-page-bg` | `--color-bg` | `#ffffff` |
| `--rheo-panel-bg` | `--rheo-panel-page-bg` | |
| `--rheo-contents-accent` | `--rheo-panel-accent` | |
| `--rheo-contents-fg` | `--color-secondary` | `#6b7280` |
| `--rheo-contents-num-fg` | `--color-muted` | `#9ca3af` |
| `--rheo-contents-rule` | `--color-muted` | `#9ca3af` |
| `--rheo-contents-fill` | derived from the accent | |

So `--color-link: rebeccapurple` in a project's `:root` recolours the active
rows with no knowledge of this package, `--rheo-panel-accent: rebeccapurple`
recolours the whole box, and `--rheo-contents-accent: rebeccapurple` just the
rows.

The rows' accent defaults to the frame's rather than to `--color-link` again,
so a project setting one colour gets a box that agrees with itself. The
rookery block redeclares both, because a custom property substitutes its
`var()`s where it is **declared** — the row accent had already resolved
against the frame's default before that block changed it.

**The palette is light by default and the package never switches it.** A
`prefers-color-scheme: dark` block was written and removed: it swapped the
literals on a dark system, so a light-only site got a contents box that went
dark underneath it whenever the *reader's* system was dark — the package
overriding the site's own decision. A project's dark theme still reaches the
box by the route it already takes, since every variable defers to the
project's before its own literal, wherever the project declares it.

Geometry is tunable the same way: `--rheo-panel-width`, `-gap`, `-right`,
`-top`, `-font-size`, plus the list's own `--rheo-contents-max-height` and
`-radius`.

The breakpoint is **not** a variable, because a custom property cannot be used
in an `@media` query. It is the `breakpoint:` argument, and the two rules keyed
to it are emitted per page into `<head>` rather than shipped in the stylesheet.

### `breakpoint: none`

Emits no width-keyed CSS at all — not the rule that makes the panel static,
not the one hiding the hat, not the one shortening the list, and not
`reserve:`, which is width-keyed too. The project's own stylesheet owns all
of it.

Worth doing wherever the project already has its own rules at the same width,
such as a two-column layout the panel is a column *of*. A breakpoint cannot be
a custom property, so a package-side one plus the project's own column rules
means the same number written in two files with nothing keeping them in step.

The trick that gets it down to one occurrence is to make the narrow layout the
**default** and the columns the exception: put the static-panel rules at the
top level and override them inside a single `@media (min-width: ..)`. Written
the other way round — columns by default, a `max-width` query to undo them —
the number is needed twice again.

## On a phone it drops into the flow

Below `breakpoint:` (default `64rem`) the panel stops being pinned and becomes
an ordinary block above the article: `position: static`, full width, with a
shorter list.

The hat goes with it — on a phone the panel sits directly under the page's own
title, where a hat would repeat that title and its rule would read as a stray
mark. The page-progress fill goes too, being drawn behind that title, and is
no loss: a static block does not track scrolling.

It used to be `display: none` there, which left a phone with no contents at
all — only tolerable if something else on the page supplies them, and nothing
generally does. A pinned rail genuinely cannot work at that width, there being
no room beside the prose; but the markup is already in the right place to read
as a block, because the aside is emitted BEFORE the document rather than after
it. So the same list becomes a short static contents above the article, which
is the conventional shape on a phone anyway.

## Where it sits

`position: fixed`, and the script publishes the offset as
`--rheo-panel-top`. **This is the one part of the script every panel gets**,
`frame` included: a pinned box has to clear whatever covers the top of the
viewport, and CSS can measure neither that element nor the thing the panel is
meant to line up with. Both arguments are therefore `frame`'s, and `contents`
forwards them.

Measured on waterline's weeknotes index, whose about panel is a bare frame:
before this, its hat cleared the header by a hand-written `calc()` restating
the header's height, the content's leading and the hat's own overhang, and
still landed a pixel or two off the first card's tab. With the selectors it is
measured, and it rises and pins like a week's.

- `offset-selector:` names a sticky header. The script takes that element's
  **bottom edge**, recomputed every frame — not its height. Measured on
  waterline's weeknotes, whose header is sticky inside a `body` with 50px of
  padding: its height is 57px but its bottom edge is at 107px, so pinning to
  the height put the panel 38px *inside* the header until the reader scrolled.
- `align-selector:` names something to line up with before any scrolling,
  typically the first section's own header. The script takes whichever of the
  two is lower, which reproduces exactly what `position: sticky` would do if
  the panel could be a column: level with that element at rest, rising with it,
  then pinned under the header. It aligns the **hat's** middle to the target's
  middle, both measured live, so the two read as sharing a line whatever
  either is sized at.

`--rheo-panel-top-gap` (0.75rem) is the clearance between the header and
the top of the hat, applied only while pinned — at rest the panel is aligned
to the first section instead, and adding it there would break that alignment.
The hat overhangs the box's top edge, so it is the hat and not the box's edge
that has to clear the header.

### Which side, and why that is not a text direction

`side: left` moves the panel to the other edge. It is `frame`'s argument, so a
bare frame takes it too, and `contents` forwards it *and* derives the side its
`reserve:` padding goes on — the side is stated once rather than once in Typst
and again in the project's stylesheet. The offsets are `--rheo-panel-right`
and `--rheo-panel-left`; only the one matching `side:` is read.

What moves with it is the **frame**: the rule, the padding off that rule, the
hat's negative margin and the page-progress track's inset. Those sit on the
edge facing away from the prose, so they mirror when the panel does.

What does **not** move is the **list**. The subsection thread, the indent, the
numbers' alignment and both progress fills follow the reader's script, not the
side of the page — a left-hand rail on an LTR site has its rule on the right
and its rows still running left to right. They are written as
`inset-inline-start`, `padding-inline-start` and `text-align: end`, so they
also mirror correctly under `:dir(rtl)` at either side.

`direction: rtl` on the aside was the first design and is wrong for exactly
this reason: it flips both axes at once, so moving the panel reversed the
labels with it. The one thing logical properties cannot carry is a gradient —
`linear-gradient(to inline-end, …)` is specified and implemented nowhere — so
the two fills read `--rheo-contents-fill-dir`, which a `:dir(rtl)` rule flips.

`demo/rheo/content/side.typ` is the worked case. `check.sh` asserts both
halves of the switch, positively and negatively, because either half alone
compiles and renders: the class without the padding puts the box over the
prose, and the padding without the class clears a column the box is not in.

## When the sections are not headings

`separator:` is the escape hatch, and it exists because a vertebra's sections
are not always `heading` elements.

Measured against waterline's weeknotes: that template hands its body to
rookery's `#ideate` with `separator: heading.where(level: 2)`, which **consumes**
those headings and re-emits each section title as a raw `html.elem("h2", ..)`.
rookery's own `core/0.1.0/src/outline.typ` states the rule — an idea "only ever
becomes [a heading] on the PAGED target … never on html/epub". That page has
eight visible sections and `query(heading)` finds none of them.

Point the box at what they are instead. `separator:` takes any Typst selector,
and **replaces** the default rather than adding to it:

```typst
#show: contents.with(separator: figure.where(kind: "demo-section"))
```

`demo/rheo/content/sections.typ` is a worked example over a custom figure kind.
An entry's label is read by `entry-title` — `title`, then `caption`, then
`body` — and its rung by `entry-depth` — `depth`, then `level`, else flat.
`title-of:` and `depth-of:` override either.

### `separator: idea`, for a rookery

A rookery gets sugar, because a selector alone is not enough there:

```typst
#import "@rookery/core:0.1.0": idea
#show: contents.with(separator: idea, levels: (1,))
```

Measured on `26w38`, that lists the week's seven sections, numbered `1`–`7`,
every anchor resolving. Without `levels: (1,)` you get eight rows, because the
week itself is an idea enclosing all of them — correct containment, but usually
not the contents box you want.

`idea` is a plain function, not an element, so it cannot be queried and this
package cannot compare it against anything it is allowed to import. It is
recognised **by name**: `repr` of a named function is its name. The call site
importing `idea` from `@rookery/core` is what says "this is a rookery"; nothing
is imported here, and this package has no dependency on that one.

It is sugar for an entry *resolver*, not for a selector, because three things
have to happen at once — all of them mirroring `@rookery/core`'s own
`outline.typ`, which is the authority for each:

- an idea is a `figure(kind: "rheo-idea")`;
- its authored title is a `metadata` payload among the figure body's children,
  **not** rendered text. Measured: walking an idea's body for text returns the
  empty string for every idea on a weeknote, which is why a generic `title-of:`
  cannot rescue this case;
- nesting and windowing come from the `<rookery-edge>` markers `_bracket` wraps
  every idea and window in. Walking those together with the figures, in
  document order, gives containment depth without parsing anything — and lets
  a windowed idea be skipped, which it must be: a `show figure.where(kind: ..)`
  rule does not remove the original from `query()`, so a note windowed onto the
  page would otherwise re-list every idea its stored body ever contained.

#### It adopts the rookery's theme

`@rookery/core` publishes its palette as inline custom properties on the
`.idea-box` it wraps each idea in — `--idea-date-color`, `--idea-link-color`,
`--idea-border-color`, `--idea-label-font`. In `separator: idea` mode the panel
is emitted *inside* that box, so it already inherits them, and `frame`'s
`rookery:` adds `.rheo-panel-rookery` to the aside so `contents.css` can map
them onto its own variables. The accent, the rules, the title and the row face all follow the
rookery; the progress fill takes `--idea-link-color`, which is rookery's own
hover wash of the accent and so is what the fill wants to be anyway.

Nothing is imported and nothing is hardcoded but rookery's published variable
names, every mapping keeps the package default as its fallback, and the class
is absent off a rookery — where there is no theme to adopt.

Where the panel is **not** inside an idea box, the script copies the `--idea-*`
properties onto the aside from an idea that is on the page, since CSS cannot
inherit sideways. Measured: on a weeknote the aside's parent is the week's own
`.idea-box` and the mapping resolves to the rookery's green, but on a
rookery-minted page (`/ideas/<slug>`) the same aside has no idea box above it,
every lookup fell through, and the panel came out blue on a green site.

#### Replayed in a preview or a window

A rookery re-renders an idea's stored body away from the page it was written
on: `@rookery/search`'s preview pane, and `#window`, which transcludes one
note into another. In rookery mode the panel is part of that body, so it
travels into both — which is right, since the contents of a week are as useful
in a preview of that week as anywhere else.

It cannot be a pinned rail there: `position: fixed` escapes any ancestor and
floats it over the whole viewport rather than over the pane. Both containers
therefore get the same compact form a phone gets — in the flow, full width,
no hat. An earlier version hid it in a preview outright, before that form
existed.

Inside a **window** the figure and ground swap. A window paints itself with
`--idea-fold-color` whenever it is hovered or folded, so the ground the panel
sits on is already the wash its own fills are made of: left alone it is a
white block on a tinted field, with two progress fills that have nothing to
read against. In a window the panel therefore takes the wash as its ground
and fills with the page colour — light bars on a tinted panel rather than
tinted bars on a light one. Set unconditionally, not only on hover, so the
panel does not change colour under the pointer while the window does. A
search preview has its own ground and is not tinted, so the page-side
colours stay as they are there.

Two things this needs, both measured:

- The container rules are two classes deep, so they beat a project's own
  `body .rheo-panel-aside` pinning rule. A container is not a width, and
  the viewport is still wide when the pane is not.
- The windowed-echo guard has to be **relative**. The guard exists so a page's
  panel does not list ideas merely echoed onto it by a window; but a panel
  *inside* a window must list that window's own ideas. Measured on the
  weeknotes index, which is one `#window(tagged: "weeknote")`: an absolute
  `window-depth > 0` read every idea there as an echo, so all sixteen panels
  resolved to zero entries and the page rendered none at all.

## Arguments

`contents`'s own; `frame`'s are in *The frame on its own* above.

| | |
| --- | --- |
| `title` | the box's header text, or `auto` for the document's own title |
| `separator` | selector whose matches become the rows (default `heading`), or `idea` |
| `title-of` | entry → label content (`auto` uses `entry-title`) |
| `depth-of` | entry → integer rung (`auto` uses `entry-depth`) |
| `levels` | depths to include, or `auto` |
| `numbered` | draw `1`/`1.1` numbers (default `true`) |
| `top` | draw the jump-to-top arrow (default `true`) |
| `breakpoint` | CSS length below which the panel drops into the flow, or `none` |
| `side` | which edge the panel is pinned to, `right` (default) or `left` |
| `reserve` | selector to pad on the panel's side (default `"body"`, `none` to opt out) |
| `offset-selector` | selector for the project's sticky header, if it has one |
| `align-selector` | selector to line the panel up with before scrolling |

Row spacing between a number and its label is `--rheo-contents-num-gap`.

`levels: auto` takes every depth the page uses. A fixed `(1, 2)` was the first
design and is wrong for any project whose template supplies the page title and
whose sections therefore start at `==`: measured against the weeknotes, every
row came out as an indented subsection of nothing, numbered `0.1`, `0.2`. An
explicit list is normalised against the depths actually present, so passing
`(1, 2)` to such a page does not reinstate that.

### Two rungs, and what happens below them

Only two levels are *drawn*. Anything deeper is **flattened** into the second
rather than dropped, for the reason `@rheo/sidebar` gives for its own
two-level nav: flattening loses the grouping, dropping loses the entry, and an
entry missing from the contents is the worse failure — a reader cannot jump to
what is not listed. Measured: with `separator: heading` on a page using `=`,
`==` and `===`, taking the two shallowest depths silently omitted every `===`.

A flattened `===` therefore numbers as a sibling of the `==` above it. Its
**real** depth still reaches the script as `data-level`, so the progress
geometry is unaffected: the enclosing `==` keeps filling until the next entry
at its own depth or shallower, exactly as it would if the third level were
drawn. `demo/rheo/content/nested.typ` is the worked case, asserted in
`check.sh`.

A third drawn rung would need a second thread colour and a second indent to
stay legible, which is worth designing against a real three-level vertebra
rather than in anticipation of one.

## Scoping

rheo compiles a whole project in **one** `typst::compile` pass, so a bare
`query()` inside one vertebra returns every other page's elements too — in this
package's own demo, a probe page owning no headings saw thirteen belonging to
two other pages. The rows here are scoped by a counter stepped either side of
the page's content: an entry is this page's if it reads the same value.

Two other approaches were tried and are worth not repeating. Filtering on
`state("rheo-handle")` gives the handle of the vertebra that *authored* an
entry, which is not the page that *renders* it — on a weeknote, which
transcludes each section from an idea vertebra of its own, it admitted three
entries and none of the eight sections. Walking the `doc` content tree misses
anything produced inside a `context` block, which is unresolved until layout;
on the same page it found nothing at all.

## Other targets

PDF and EPUB get the document untouched — no box, no anchors, no wrapper. A
progress rail is meaningless on a page that does not scroll, and EPUB builds
its own outline from the headings (rheo core's `collect_headings`). Asserted in
`check.sh` against the built EPUB, because the show rule is applied
unconditionally by the vertebra and a regression in that guard would be
invisible in the HTML.

## Requirements

- A built package: `dist/` must exist before a project sees an edit.
- rheo 0.6.0 or later for the `<rheo-head>` hoist the breakpoint rules use.
  Nothing else here is rheo-specific — the box renders under bare
  `typst compile --format html` too.

## Development

```sh
cd contents-panel/0.1.0
just build   # bundles src/ into dist/
just check   # builds the demo and asserts on its output
```
