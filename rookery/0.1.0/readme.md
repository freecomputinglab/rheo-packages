# @rheo/rookery

Atomic, interlinked, transcludable notes for Typst — Zettelkasten-style, and
rheo-aware where rheo is present.

A note exists ONLY where you write `#idea("name")[...]`. There is no document
show rule and no "every heading is a note" behaviour — a labeled heading is
just a labeled heading. `#idea[body]` (no name) works too: the package
generates a sequential id and shows it to you as a `[note:1]`-style permalink
next to the note, since with no name there's no other way to know it.

```typst
#import "@rheo/rookery:0.1.0": idea

#idea[A frictionless note — reads its generated id off the [note:1] permalink.]
#idea("etal")[A pinned note — its id is always `note:etal`.]
```

Full signature: `idea(level: 1, title: none, labels: (), minted: none,
updated: none, ..args)`, where the sink accepts the body alone, `(name,
body)`, or `(<name>, body)` — the name may be a string or a Typst label,
identically.

## Flat ids, and why

`#idea("etal")` is the Typst label `<note:etal>` everywhere — no handle or
filename prefix. That means a note KEEPS ITS ID WHEN IT MOVES BETWEEN FILES:
nothing about `<note:etal>` depends on which file it's written in. Names are
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

**Under rheo.** Nothing extra to write — no `ctx:` parameter, no `#show:`
template. Just `#import` and call `#idea`/`#view` like any other
package. rheo adds exactly two things on top of the pure-Typst behaviour:
correct cross-PAGE hrefs (rheo puts each vertebra in its own output page,
which a plain Typst compile doesn't), and the stylesheet auto-injected via
this package's `[tool.rheo.html]` — no manual `<link>` needed.

See `demo/rheo/` for a working multi-vertebra example, including a nested
vertebra to exercise cross-page links.

## Referencing a note

Three ways, pick by how much ceremony you want:

- `#link(label("note:etal"))[jump to it]` — a plain jump, works everywhere,
  always correct (in-page or cross-page).
- `#view("etal")` — an inline transcluded excerpt of the note's body that is
  ITSELF a link to the note's own page. Accepts a single name, a label, or an
  array of names (`#view(("etal", "second"))` renders both in order).
  `limit: n` truncates to the first `n` content-level blocks (paragraphs,
  grouped list items, ...) plus "…" — this works in every target, not just
  HTML.
  `#view((...), folded: true)` renders a compact index instead — one row per
  note, title left and a muted minted-date right, with the body collapsed
  behind it. A titleless note falls back to its bare id. `limit:` is
  meaningless for a folded row and is silently ignored when combined with
  `folded: true`.

  A folded row costs two clicks, by design: the FIRST click unfolds the row in
  place, and only a click on the unfolded body navigates to the note's page.
  That is a native `<details>`/`<summary>` disclosure — this package ships no
  JS — so the row itself is deliberately not a link; an `<a>` inside a
  `<summary>` swallows the toggle click. Under a paged target, where there is
  nothing to click, a folded view is a plain list of linked titles instead.
- `@note:etal` — the terse form, but by default it renders as a bare figure
  NUMBER (Typst's stock `@` rendering for a labeled figure — a note's id
  lives on a hidden anchor figure). Opt in to a proper rendering by applying
  the exported `ref-rule`:

  ```typst
  #import "@rheo/rookery:0.1.0": idea, view, ref-rule
  #show ref: ref-rule
  ```

  With the rule applied, `@note:etal` renders the note's title (linked)
  instead, cross-page too; a note with no title falls back to the bare id
  text rather than a number. References to anything else (an ordinary
  figure, a heading) pass through untouched.

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
`notes/<id>.html` — e.g. `notes/etal.html` for `<note:etal>` — via a package
`.marrow.typ` that rheo inlines at the bundle root. No `rheo.toml` entry and
no project file needed. Typst will print `warning: bundle export is
experimental` — expected, not a sign anything is wrong.

Each minted page shows the note's title and permalink id, then its body.

Where those pages exist, they are what the package's own clickable surfaces
point at:

- the `[note:etal]` permalink beside a note's heading — the same-page `#id`
  fragment it would otherwise carry is a no-op for a reader already looking at
  that heading;
- an unfolded `#view`, and the body of a folded one.

Hrefs are depth-relative to the page doing the linking (`../notes/etal.html`
from a nested vertebra), and both forms fall back to the note's in-page anchor
when no page is minted — under plain `typst compile`, or for the combined PDF.

What does NOT redirect is anything addressing the note's Typst label:
`#link(label("note:etal"))` and `@note:etal` still resolve to wherever `#idea`
was actually called. A minted page does NOT reuse the `note:<id>` label (two
elements can't share one label without breaking `#link`/`#view`/`ref-rule`
resolution), so the label keeps its original home by construction.

Set `[html] auto_detect_packages = false` in `rheo.toml` to turn this off (it
disables every package-driven behaviour, not just this one). Skipped
automatically for the combined PDF target, which cannot create output files
at all.

## Limitations

- **`#view` expands exactly ONE level.** A note transcluded via `#view`
  renders its content once; if that content itself contains a `#view`, the
  inner one collapses to a plain `[view of note:x]` link instead of
  expanding further. This is deliberate and permanent (it's what makes
  self-views and view cycles safe to compile), not a tunable depth.
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
anywhere under this directory. See `demo/pure/` and `demo/rheo/` for runnable
examples of both modes, each with its own `just watch` for live-rebuild.
