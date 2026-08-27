// footnotes.typ — #footnote, scoped to the enclosing idea's own Footnotes
// block, plus the document-wide fallback `#show: rookery` installs for a
// rookery footnote written OUTSIDE any idea (lib.typ:2799, `show FNK:`).
// The fallback needs `#show: rookery` actually applied somewhere in the
// including document — root.typ now does, for this and bib.typ both.
//
// NOT COVERED HERE, deliberately (lib.typ:1437-1443): a Typst `#footnote`
// (not rookery's) used INSIDE an idea without importing rookery's own
// `footnote` is a compile-time PANIC by design —
//
//   @rheo/rookery: `#footnote` inside an idea is Typst's, not rookery's —
//   its body would land in the page's endnote section instead of this
//   idea's Footnotes block. Add `footnote` to your import:
//   `#import "@rheo/rookery:0.6.0": idea, footnote`.
//
// — so it has no place in a demo that must compile clean. Negative testing
// for the panic message belongs to the unit-test bead, not here.
#import "../../src/lib.typ": idea, footnote

#idea("fn-idea", title: [Footnoted])[
  A claim worth qualifying#footnote[The supporting evidence.], scoped to this
  idea's own Footnotes block rather than the page's.

  A second claim#footnote[Another note.], to prove more than one numbers
  correctly against the same block.
]

// A rookery #footnote written OUTSIDE any idea — no enclosing `_footnoted`
// wrapper to claim it, so it falls to `#show: rookery`'s document-wide
// fallback: page-wide numbering, body in the page's own endnote section,
// exactly like Typst's own footnote.
A page-level claim#footnote[Falls back to Typst's own footnote mechanism.]
made outside any idea.
