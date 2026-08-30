// A SECOND root, deliberately separate from root.typ: `prefix:` and
// `theme:` are document-wide state (`_prefix`/`_theme`, lib.typ:169/246), so
// setting either inside root.typ's own document would apply to a.typ/b.typ
// too — renaming "idea:pinned" out from under the `<idea:pinned>`/
// `@idea:pinned` references those files already hardcode, rather than
// adding a case beside them. This document exists only to carry a
// non-default `prefix`/`theme`.
//
// Build (PDF):  typst compile --features html --root ../.. root-prefix.typ build/root-prefix.pdf
// Build (HTML): typst compile --features html --format html --root ../.. root-prefix.typ build/root-prefix.html
#import "../../src/lib.typ": rookery
#show: rookery.with(
  prefix: "note",
  theme: (
    link-color: rgb("#0055aa"),
    fold-color: rgb("#aa00aa"),
    id-color: rgb("#888888"),
    date-color: rgb("#888888"),
    border-color: rgb("#3366ff"),
    tags-color: (phd: (background: rgb("#ffcc00"), text: rgb("#000000"))),
  ),
  // Granular arguments override whatever `theme:` set (lib.typ:2756-2767) —
  // this OVERRIDES the theme dict's `border-color` above, and adds two keys
  // the dict left unset.
  border-color: rgb("#cc3300"),
  rule-width: 3pt,
  pad: 0.6em,
)

#include "theme.typ"
