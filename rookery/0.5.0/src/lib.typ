// rookery — atomic, interlinked, transcludable notes ("ideas") for Typst (Zettelkasten-style).
//
// A note exists only where the author writes `#idea("name")[...]` — there is
// no document show rule and no "every heading is a note" behaviour. Notes are
// flat: there is no kind/type taxonomy, only a free-form set of tags an
// author attaches to a note. `#note`/`#todo` are pure sugar over that same
// tags array (see below), not a taxonomy of their own. Note ids are flat
// Typst labels (`<idea:name>`), not handle-prefixed, so a note can move
// between files without breaking inbound links.
//
// This package takes no `ctx` argument and installs no template: under plain
// `typst compile` one root file `#include`s the notes and everything works.
// Under rheo (https://rheo.ohrg.org) it feature-detects `sys.inputs` and the
// `rheo-handle` page state to upgrade cross-page links automatically.
//
// NO `#preview`/tooltip integration: rheo's package asset auto-detection only
// scans a project's own `.typ` files for package imports, not the packages
// those files' packages import in turn — so a `#preview` composing
// `@rheo/tooltip` from inside THIS package would need every consuming project
// to import `@rheo/tooltip` directly too, just to get its JS auto-injected.
// That leaky requirement (REJECTED 2026-08-14) is worse than not having the
// feature; `#hyperlink`/`#window` cover referencing a note without it.

// THE ENTRYPOINT IS A MANIFEST, not a place to add code. Every name this
// package exports lives in one of the modules below, and `#import "x.typ": *`
// re-exports transitively — which is what keeps `@rheo/rookery:0.5.0` a single
// import for a project, `.marrow.typ`'s seventeen internals resolvable by name,
// and `test/units.typ` able to reach the pure helpers.
//
// THE ORDER IS THE DEPENDENCY ORDER and it is load-bearing, not cosmetic: a
// `#let` closure captures the scope visible AT DEFINITION time, so a module can
// only use names from modules imported before it. `hyperlink.typ` sits above
// `transclusion.typ` for exactly that reason — `_flatten` installs
// `show ref: hyperlink` — and `template.typ` sits last because `#show: rookery`
// reads all of them. Typst has no cycles to fall back on here: a wrong order is
// an unknown-variable error, which is how the order above was arrived at.
//
// `_handle-title` and `_is-vertebra`, which `.marrow.typ` imports, live in
// `base.typ` with the rest of the rheo-context reads.
#import "base.typ": *
#import "state.typ": *
#import "theme.typ": *
#import "urls.typ": *
#import "permalink.typ": *
#import "bib.typ": *

#import "hyperlink.typ": *
#import "transclusion.typ": *
#import "links.typ": *
#import "idea.typ": *
#import "window.typ": *
#import "outline.typ": *
#import "template.typ": *
