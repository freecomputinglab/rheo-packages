// window-tags.typ — `#window(tags:)` written INSIDE a note that carries the
// same tag, at two nesting depths.
//
// A REGRESSION FIXTURE, and it is the whole reason this file exists. Bead
// rheo-packages-d411 reported that such a window rendered a SUBSET of its
// selection with no marker, no link row and no warning: 8 of 15 notes on
// rookery.ohrg.org under rookery 0.4.0, and the 8 survivors were exactly the
// first 8 in sorted id order, which read as a truncation rather than a
// recursion guard.
//
// MEASURED on 0.5.0 and it does not reproduce — at one level of nesting, at
// two, and with 22 selected notes. Every selected note renders, INCLUDING the
// note the window is written inside and its parent. The bead was closed as no
// longer valid on that evidence, and this file is what keeps the closure
// honest: if the thinning ever returns, the count below stops matching.
//
// The rule this pins, therefore: a tag window transcludes every note carrying
// the tag, and being an ancestor of the window does not exempt a note from it.

#import "../../src/lib.typ": idea, window

= Tag windows written inside a tagged note

#idea("wt-one", title: [WT one], tags: "wt")[First.]
#idea("wt-two", title: [WT two], tags: "wt")[Second.]

#idea("wt-outer", title: [WT outer], tags: "wt")[
  An outer note, itself tagged `wt`, holding a nested note that holds the
  window — the two-deep shape the original report had.

  #idea("wt-inner", title: [WT inner], tags: "wt")[
    The window lives here, and selects the tag its own ancestors carry.

    #window(tags: "wt", folded: true)
  ]
]

#idea("wt-three", title: [WT three], tags: "wt")[Third, written after the window.]
