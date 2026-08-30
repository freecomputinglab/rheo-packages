// card-gap.typ — the clearance between one card's floor and the next card's
// lifted id.
//
// A REGRESSION FIXTURE for bead rheo-packages-empty-body-overlap-xssz, which
// reported a following card's `[idea:...]` tab overlapping the box above it,
// and got worse the larger `--idea-label-size` was set.
//
// THE REPORT BLAMED THE EMPTY BODY AND THE MEASUREMENT SAYS OTHERWISE. An
// empty-bodied card's clearance is identical to a full one's at every label
// size — the body has nothing to do with it. What was actually wrong is that
// card-after-card had NO declared gap, so it rode the UA's collapsed
// `figure { margin: 1em }` while the card's id ate into that 16px by half a
// label: `16 - 0.5 * label`, which reaches 0 at 2rem and goes negative past it.
//
// `figure + figure:has(> .idea-box)` in `src/rookery.css` now adds the overhang
// back, so the clearance is a constant 1rem whatever the label is. MEASURED
// after the fix at 0.57rem, 0.85rem, 1.4rem, 2rem and 3rem: 16px at every one.
//
// The empty-bodied card is kept here anyway. It is the shape the bug was
// reported against, and a fixture that dropped it would not have caught the
// thing the reporter actually saw.

#import "../../src/lib.typ": idea

= Card gaps

#idea("cg-empty", title: [An empty-bodied card])[]

#idea("cg-after")[
  The card immediately after an empty-bodied one. Its id must clear the floor
  of the box above rather than sitting on it.
]

#idea("cg-a", title: [Card A])[An ordinary card, for the same gap between two
  ordinary ones.]

#idea("cg-b", title: [Card B])[And the one after it.]
