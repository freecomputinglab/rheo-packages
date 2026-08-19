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
// `"@rheo/rookery:0.4.0"` by name.
#import "pure.typ": *

// ---- CONSUMED BY .marrow.typ — a real API, with no other marker ------------
//
// `.marrow.typ` (this package's own, at the package root) imports SEVENTEEN
// names from `"@rheo/rookery:0.4.0"`, seventeen of them underscore-private. They
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
// NOT COVERED BY CI, and this is the gap: `demo/rheo` is the only thing that
// proves marrow still mints, and it needs the `rheo` binary, which no published
// release can supply yet — package-`.marrow.typ` support landed after v0.5.1.
// Until a release carries it (the same release bead rheo-packages-2ps waits on),
// this banner and a local `demo/rheo` run are the whole guard.

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

