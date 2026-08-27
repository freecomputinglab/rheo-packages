// Everything with no rookery dependency of its own: whether we are compiling
// under rheo and to what, plus a re-export of `pure.typ`.
//
// EVERY OTHER MODULE IMPORTS THIS ONE, and this one imports nothing but
// `pure.typ` — which is what keeps the module graph a DAG. A `#let` closure
// captures the scope visible at definition time, so a cycle here would not be a
// warning, it would be an unresolvable name.

// ---- Target detection — the only rheo-specific read ------------------------
//
// `std.target()` reports EPUB as "html"; rheo's own context distinguishes
// them. Use `std.target()` rather than a bare `target()`: rheo injects its
// `target()` polyfill into each vertebra's scope, not into package scope.
//
// REQUIRES `--features html`: `std.target` is gated by that compiler feature,
// not by output format — it is absent from `dictionary(std)` under a plain
// `typst compile` with no `--features html`, even when compiling to PDF. This
// package accepts that constraint rather than working around it: every
// invocation, including a plain paged build with no rheo, needs the flag.
// Document this as a hard requirement (readme bead).
#let _rheo-ctx() = sys.inputs.at("rheo-context", default: none)

#let _target() = {
  let c = _rheo-ctx()
  if c != none and "target" in c { c.target } else { std.target() }
}

// ---- pure.typ — the ordering-free half ------------------------------------
//
// `pure.typ` holds the helpers that are pure functions of their arguments: no
// `state`, no `context`, no `query`, no target detection, nothing that reads
// document state. They therefore carry none of the definition-time scope
// capture the rest of THIS file's ordering is load-bearing for.
//
// The wildcard form is deliberate, because it RE-EXPORTS — VERIFIED: a name
// imported into `lib.typ` with `#import "pure.typ": *` is visible to anything
// importing `lib.typ`. `test/units.typ` relies on it directly (twelve of its
// fifteen imported internals now live in `pure.typ`), and `.marrow.typ`
// imports eighteen of this file's own internals by name on the same footing —
// an underscore is a convention here, not a barrier.
//
// A RELATIVE import is safe here: it resolves against the package's own
// directory. UNLIKE `.marrow.typ`, whose text is spliced into rheo's bundle
// root (its own header explains it), so that file must keep importing from
// `"@rheo/rookery:0.6.0"` by name.
#import "pure.typ": *

// ---- CONSUMED BY .marrow.typ — a real API, with no other marker ------------
//
// `.marrow.typ` (this package's own, at the package root) imports SEVENTEEN
// names from `"@rheo/rookery:0.6.0"`, seventeen of them underscore-private. They
// are as load-bearing as anything public here, and nothing else in this file
// says so. RENAMING OR RE-SIGNING ANY OF THEM MEANS CHANGING `.marrow.typ` IN
// THE SAME COMMIT.
//
// The failure mode is why this banner exists rather than a convention. rheo's
// `package_marrow_source` returns None for a marrow it cannot read instead of
// erroring, so a broken marrow does not fail a build: the package installs,
// compiles, and simply mints none of the pages it exists to mint. Nothing goes
// red. The site just quietly loses every note page.
//
//   _registry            the note store; marrow walks `.final()` to mint one
//                        page per note, and inverts its `links` for backlinks
//   _note-page           slug + minted path + minted handle for one note, the
//                        one place that mirror lives (see "Note page URLs")
//   _pfx                 the `<prefix>:` to strip off a BACKLINK id, for the
//                        `#window` call that renders the backlinks list
//   _head                per-page <head> contributions
//   _permalink           a note's `[idea:x]` permalink
//   _permalink-tab       the top-rule permalink tab a note wears in a card,
//                        reused on the minted page with a self-fragment href
//   _themed              carries the document's theme as inline custom props
//   _handle-title        the human title of the vertebra a handle names, for
//                        the Context section's links back into the spine
//   _page-links          which notes a given PAGE links to directly
//   _page-href           depth-relative href from this page to another page
//   _body-at             a note's body at a given nested-window budget
//   _footnoted           wraps a body with its own Footnotes block
//   _refs-block          the References block for a set of citation keys
//   _own-cited-keys      which keys a body cites, minus the windowed ones
//   _window-depth        the document-wide nested-window budget state
//   _idea-page-template  the project's own minted-page template, if any
//   window               public, but listed for completeness: marrow renders
//                        the backlinks list as folded windows
//
// Their DEFINITIONS are deliberately not gathered here. Several (`_footnoted`,
// `_body-at`) sit where they do because a `#let` closure captures the scope
// visible at definition time, and moving them to satisfy a banner would break
// the thing the banner is protecting.
//
// COVERED BY CI as of rheo 0.5.2. `demo/rheo` is still the only thing that
// proves marrow mints, and it needs the `rheo` binary — but package-`.marrow.typ`
// support shipped in v0.5.2 (PR #164, released 2026-08-16), so CI installs that
// release and runs the demo against it. 0.5.2 is also this package's declared
// `[tool.rheo] min_version`, which is the point: the floor CI tests is the floor
// the manifest promises, and nothing in rheo enforces that key yet.
//
// MEASURED on a from-source build at tag v0.5.2: `rheo compile .` in `demo/rheo`
// mints all five `ideas/*.html` pages with no warnings and `./check.sh` prints
// `demo/rheo OK` — all eight blocks, tag-CSS assertions included. Nothing in this
// package or in `@rheo/rookery-search` touches a surface newer than 0.5.2.

// The human title of the vertebra a handle names — "Rookery under Rheo" for
// `index`. Read from `rheo-context`'s `spine-flat`, which every vertebra and
// every marrow contribution sees identically (it is spine-wide, not per-file),
// so this works from package scope with no `ctx:` parameter and no `query()`.
//
// Falls back to the handle itself: a handle is always something a reader can
// place, and this must never be the reason a build fails.
#let _handle-title(handle) = {
  let c = _rheo-ctx()
  if c == none { return handle }
  for v in c.at("spine-flat", default: ()) {
    if v.at("handle", default: none) == handle {
      return v.at("title", default: handle)
    }
  }
  handle
}

// Is this handle one of the project's OWN pages?
//
// `spine-flat` lists the vertebrae the author wrote. It does NOT list the
// per-note pages `.marrow.typ` mints, whose handles are `ideas:<slug>` — and
// that distinction is load-bearing for backlinks. A minted page carries links
// of its own (its permalink, its context link, the windows in its own backlinks
// list), all of which would otherwise be harvested as "this page links to that
// note" and every note would list every other note's page. MEASURED: without
// this filter, `ideas/rookery.html` claimed six page backlinks, four of them
// other minted pages.
#let _is-vertebra(handle) = {
  let c = _rheo-ctx()
  if c == none { return false }
  c.at("spine-flat", default: ()).any(v => v.at("handle", default: none) == handle)
}

// ---- Excluded tags — the build-level corpus filter -------------------------
//
// A note carrying an excluded tag is not hidden, it is ABSENT: `#idea` never
// builds its marker, so there is no output, no registry entry, no Typst label,
// no minted page, no `ideas()` row, no search-index entry, no feeds beacon, no
// outline entry and no backlink. The point is a build script producing
// different subsections of ONE rookery from one source tree — a public site
// that drops `protected` notes, a dev build that keeps them.
//
// THE WHOLE REASON THIS LIVES HERE AND READS `sys.inputs` RATHER THAN A STATE.
// `sys.inputs` is readable from ANY scope with NO `#context` block, exactly as
// `_rheo-ctx` at the top of this file reads it. That property is load-bearing:
// `#idea`'s gate has to sit ABOVE the `figure(kind: IK)` marker, because five
// things walk for that marker STRUCTURALLY, before realization — `_flatten`'s
// IK rule (transclusion.typ), `_outbound` (links.typ), `_std-footnotes` and
// `_footnotes` (pure.typ), and `_ideas-outline-data`'s `query()` (outline.typ).
// A `#context` node's children are not in the content tree until realization,
// so a `#context`-wrapped idea is invisible to all five.
//
// REJECTED, and do not reintroduce it: `#show: rookery.with(exclude-tags: ..)`.
// A template argument becomes STATE, state is read with `.final()`, and
// `.final()` needs `#context` — which is precisely what the gate cannot have.
// Hence the declared half of the list is a plain ARGUMENT on `#idea` and
// `#tagged-idea` instead. (`invisible-tags` IS a `rookery.with` argument, and
// the asymmetry is deliberate: that one is pure presentation, and every site it
// touches already runs inside a `#context`.)
//
// ALSO REJECTED, on measured evidence: gating with
// `show figure.where(kind: IK): none`. `outline.typ` records the MEASURED fact
// that a show rule does NOT remove the figure from `query()`, so the outline
// would go on listing excluded notes — strictly worse than doing nothing.
//
// TWO CHANNELS AND HOW THEY COMPOSE:
//
//   excluded = (declared UNION rookery-exclude) MINUS rookery-include
//
// The DECLARED list is the CD baseline, so a public build needs no environment
// at all — a project declares `exclude-tags: ("protected", "private")` once and
// its published site is correct by default. `rookery-include` is how a DEV
// build puts those notes back. `rookery-exclude` is how a build script carves a
// further subsection without touching the project source.
//
// UNDER RHEO, TODAY: `rheo compile` forwards no `--input`, so the two
// `sys.inputs` keys currently reach a plain `typst compile` only, while the
// declared list works everywhere. A rheo-side `--input` flag plus a
// `rheo.toml [inputs]` table are specced (rheo beads `rheo-cli-input-flag-q12`
// and `rheo-toml-inputs-table-rih`); nothing here changes when they land.

// One `sys.inputs` key as an array of tag names, or `()` when it is absent.
//
// DEFINED HERE, AT THE BOTTOM OF THE FILE, and that is not cosmetic:
// `_split-tag-list` reaches this file through `#import "pure.typ": *` above,
// and a `#let` closure captures the scope visible AT DEFINITION time — placed
// beside `_rheo-ctx` at the top, this would be an unknown-variable error. Same
// ordering discipline the whole module graph is built on (see the header of
// this file and `lib.typ`).
#let _input-tags(key) = {
  let v = sys.inputs.at(key, default: none)
  if v == none { return () }
  assert(
    type(v) == str,
    message: "@rheo/rookery: `--input " + key + "` must be a string of comma- "
      + "or space-separated tag names — got " + repr(v),
  )
  _split-tag-list(v)
}

// The final excluded set. See the banner above for the formula and for why this
// takes no `#context`.
//
// `declared` accepts the SAME four forms `#idea`'s `tags:` accepts — `none`, a
// string, an array, a dictionary — because it is routed through `_norm-tags`.
// That is what makes `exclude-tags: "private"` work with no array ceremony,
// exactly as `tags: "draft"` already does.
#let _resolve-excluded(declared) = {
  let d = _norm-tags(declared).keys()
  let add = _input-tags("rookery-exclude")
  let drop = _input-tags("rookery-include")
  (d + add).dedup().filter(t => t not in drop)
}

