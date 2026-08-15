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

Full signature: `idea(level: 1, title: none, labels: (), minted: none,
updated: none, ..args)`, where the sink accepts the body alone, `(name,
body)`, or `(<name>, body)` — the name may be a string or a Typst label,
identically.

## Setup, and the `idea:` prefix

Nothing above needed any setup, and that stays true. One optional template
does all of it in a line, and is the only place anything is configurable:

```typst
#import "@rheo/rookery:0.1.0": rookery, idea, view
#show: rookery.with(
  prefix: "note",                 // ids are now `note:etal`
  theme: (
    link-color: "rgba(230, 140, 0, 0.16)",  // hover background on any link
    fold-color: "rgba(255, 190, 40, 0.07)", // ...and on a foldable block
    date-color: rgb("#a08a5a"),
  ),
)
```

`#show: rookery` does exactly three things: it publishes the id prefix and the
theme, and it installs `ref-rule` so `@note:etal` renders the note rather than
a bare figure number (see "Referencing a note"). It sets no other styles,
wraps `doc` in nothing, and emits nothing of its own — on a document with no
notes in it, it is a no-op, and even the `ref` rule passes every non-rookery
reference straight through. Pass `refs: false` to keep the rest and skip that
rule.

`prefix` must be a non-empty string with no `:` in it (the separator is added
for you).

### The theme

Four colours, the whole of what the package will style for you:

| key | what it colours | default |
| --- | --- | --- |
| `link-color` | hover background on **any** rookery link | `rgba(128, 0, 255, .12)` |
| `fold-color` | hover background on a foldable view block | `rgba(0, 100, 255, .05)` |
| `id-color` | the `[idea:etal]` permalink's text | `gray` |
| `date-color` | the date in a view's summary | `gray` |

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
document settled on, which is what keeps a `#view` across that boundary
resolving instead of panicking on an id nothing registered.

CSS class names are NOT affected: the heading is `idea`/`idea-label-<tag>` and
the permalink is `.idea-label` whatever the prefix reads as.

## Flat ids, and why

`#idea("etal")` is the Typst label `<idea:etal>` everywhere — no handle or
filename prefix. That means a note KEEPS ITS ID WHEN IT MOVES BETWEEN FILES:
nothing about `<idea:etal>` depends on which file it's written in. Names are
therefore globally unique by design; giving two notes the same id is a build
error naming the id, as soon as anything (`#view`, `ref-rule`)
looks the id up.

## Two modes

**Pure Typst, no rheo.** One root file `#include`s your note files; `#view`
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
`#idea`/`#view` like any other
package. rheo adds exactly two things on top of the pure-Typst behaviour:
correct cross-PAGE hrefs (rheo puts each vertebra in its own output page,
which a plain Typst compile doesn't), and the stylesheet auto-injected via
this package's `[tool.rheo.html]` — no manual `<link>` needed.

`demo/pure/` in this repo is the pure-Typst side: no template at all, default
prefix, `ref-rule` wired up by hand. The rheo side lives in the sibling repo
**`rookery.ohrg.org`** — this package's documentation site, written with the
package it documents. It is the worked multi-vertebra example, including a
nested vertebra to exercise cross-page hrefs, a custom prefix and theme, and
`#show: rookery` applied once in a site template rather than repeated per
page.

## Referencing a note

Three ways, pick by how much ceremony you want:

- `#link(label("idea:etal"))[jump to it]` — a plain jump, works everywhere,
  always correct (in-page or cross-page).
- `#view("etal")` — transcludes the note: its title, its `[idea:etal]`
  permalink and its body, as one foldable block. Accepts a single name, a
  label, or an array of names (`#view(("etal", "second"))` renders both in
  order, each its own block). `limit: n` truncates the body to the first `n`
  content-level blocks (paragraphs, grouped list items, ...) plus "…", in
  every target, not just HTML.

  `folded: true` starts the block CLOSED. That is all it does: a folded view
  and an open one are the same block, so `limit:` stays meaningful under
  either and the two are orthogonal. Under a paged target, where there is
  nothing to click, `folded` is ignored and the body always shows.

  See "The click budget" below for what clicking each part does.
- `@idea:etal` — the terse form, but on its own it renders as a bare figure
  NUMBER (Typst's stock `@` rendering for a labeled figure — a note's id
  lives on a hidden anchor figure). `#show: rookery` installs the rule that
  fixes this, so if you already applied the template there is nothing to do.
  Without it, apply the exported `ref-rule` by hand:

  ```typst
  #import "@rheo/rookery:0.1.0": idea, view, ref-rule
  #show ref: ref-rule
  ```

  With the rule applied, `@idea:etal` renders the note's title (linked)
  instead, cross-page too; a note with no title falls back to the bare id
  text rather than a number. References to anything else (an ordinary
  figure, a heading) pass through untouched.

## The click budget

Interaction is modelled on [Forester](https://www.forester-notes.org), and the
whole of it fits in two rules:

- **The summary of a `#view` folds and unfolds. That is all it does.** Click
  the title, the date, the space between them — the block opens or closes and
  nothing navigates.
- **The `[idea:etal]` permalink is the only link the package emits**, and it
  goes to the note's own page. It sits beside the title, or alone at the top
  of the view when the note has no title (the id doing double duty as its
  name). `#idea` renders the identical affordance beside its own heading, and
  a `#view` nested inside a transcluded body collapses to it too — so the rule
  holds at every depth.

The disclosure is a native `<details>`/`<summary>`; the package ships no JS.
An `<a>` inside a `<summary>` does not break the toggle — only an `<a>` around
the whole summary does, which is why the body of a view is never wrapped in
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
that root a rookery subtree — `.idea-box`, `.idea-view`, a minted page's `<h1>`
— and inherits down to the permalink and the date. The default lives inside
the `var()` call, so an unconfigured document, and any reader that doesn't
understand custom properties, still gets the look above. The package emits no
`<style>` element and wraps the document in nothing, so there is no `:root` to
hang a variable on; this is the mechanism that needs neither.

Setting those properties in your own stylesheet works identically — they are
the same four properties, listed at the top of `src/rookery.css`.

Override any of it; the classes are the contract: `.idea`, `.idea-box`,
`.idea-label`, `.idea-label-<tag>`, `.idea-view`, `.idea-view-summary`,
`.idea-view-title`, `.idea-view-date`, `.idea-view-body`,
`.idea-view-details`.

**Not yet:** a hover-preview link (`#preview`) was tried and reverted — it
would have composed `@rheo/tooltip`, but rheo's package asset auto-detection
only scans a project's own `.typ` files for package imports, not the packages
those files' packages import in turn. That would have forced every project
using it to also import `@rheo/tooltip` directly just to get its JS
auto-injected — a leaky requirement, not worth the feature.

## Labels

A free-form array of tag strings, nothing more — there is no fixed or
recognised set and no `kind`/`type` parameter. Notes are flat; labels are
tags, not a taxonomy, and NOT a task tracker.

```typst
#idea("meeting-notes", labels: ("draft", "review"))[...]
```

Each label becomes its own `idea-label-<tag>` CSS class on the note's
heading, alongside the base `idea` class — style them in your own stylesheet.

`#note` and `#todo` are pure sugar over `labels`, prepending their own tag to
whatever the caller passes:

```typst
#note("x")[...]              // == #idea("x", labels: ("note",))[...]
#todo("y", labels: ("draft",))[...]  // == #idea("y", labels: ("todo", "draft"))[...]
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

Dates are RECORDED on the note but no longer rendered in the note header —
the header is just the title and its id. They surface once the folded `#view`
lands (a right-hand meta column, `#view(..., folded: true)`).

## Standalone note pages (rheo only)

Importing this package mints one output page per note automatically, at
`notes/<id>.html` — e.g. `notes/etal.html` for `<idea:etal>`, the prefix
stripped off whatever it is set to — via a package
`.marrow.typ` that rheo inlines at the bundle root. No `rheo.toml` entry and
no project file needed. Typst will print `warning: bundle export is
experimental` — expected, not a sign anything is wrong.

Each minted page shows the note's title and permalink id, then its body.

Where those pages exist, they are what the permalink points at — in `#idea`'s
heading, in a `#view`'s summary, and in a nested view's collapsed form alike,
since all three are the same affordance. The same-page `#id` fragment a
permalink would otherwise carry is a no-op for a reader already looking at
that heading; the minted page is what they actually want.

Hrefs are depth-relative to the page doing the linking (`../notes/etal.html`
from a nested vertebra), and fall back to the note's in-page anchor when no
page is minted — under plain `typst compile`, or for the combined PDF.

What does NOT redirect is anything addressing the note's Typst label:
`#link(label("idea:etal"))` and `@idea:etal` still resolve to wherever `#idea`
was actually called. A minted page does NOT reuse the `idea:<id>` label (two
elements can't share one label without breaking `#link`/`#view`/`ref-rule`
resolution), so the label keeps its original home by construction.

Set `[html] auto_detect_packages = false` in `rheo.toml` to turn this off (it
disables every package-driven behaviour, not just this one). Skipped
automatically for the combined PDF target, which cannot create output files
at all.

## Limitations

- **`#view` expands exactly ONE level.** A note transcluded via `#view`
  renders its content once; if that content itself contains a `#view`, the
  inner one collapses to its own `[idea:x]` permalink instead of expanding
  further. This is deliberate and permanent (it's what makes self-views and
  view cycles safe to compile), not a tunable depth.
- An author's own `<label>` written inside a note's body is duplicated if
  that note is transcluded elsewhere — a note owns exactly one id, attached
  by `#idea` itself.
- Backlinks (which notes link to this one) are not implemented yet.

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
