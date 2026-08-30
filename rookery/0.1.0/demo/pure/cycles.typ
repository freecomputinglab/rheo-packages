// cycles.typ — the package's most load-bearing termination claim
// (lib.typ:1129-1152): `_flatten`'s nested-window budget is a
// CLOSURE-CAPTURED CONSTANT, not state, so a self-window or an
// A-windows-B/B-windows-A cycle bottoms out instead of re-expanding forever.
// The REFUTED state-counter approach hit "maximum show rule depth exceeded"
// on exactly this shape (measured on typst 0.14.2 and 0.15.1) — nothing
// here should reproduce that.
#import "../../src/lib.typ": idea, window

// SELF-WINDOW: a note that windows itself.
#idea("self-loop", title: [Self-loop])[
  This note windows itself: #window("self-loop") — at the document default
  depth (1) that nested window collapses to a bare permalink rather than
  re-expanding.
]

// A-WINDOWS-B / B-WINDOWS-A cycle.
#idea("cycle-a", title: [Cycle A])[
  Cycle A windows Cycle B: #window("cycle-b")
]
#idea("cycle-b", title: [Cycle B])[
  Cycle B windows Cycle A: #window("cycle-a")
]

// Rendering either at the top level must terminate at whatever depth is
// asked for rather than looping.
#window("self-loop")
#window("cycle-a")
#window("cycle-a", depth: 3)
