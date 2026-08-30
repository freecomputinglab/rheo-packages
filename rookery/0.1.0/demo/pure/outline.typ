// outline.typ — #ideas-outline, both `rookery-wide` forms, `depth:`, and
// `title: none` (lib.typ:2329).
#import "../../src/lib.typ": idea, ideas-outline

#idea(title: [Outline root])[
  An outlined parent.

  #idea("outline-child", title: [Outline child], tags: ("draft",))[
    A nested, titled child — shows one level deep in the outline.
  ]
]

// Default form (`rookery-wide: false`) — this PAGE's own ideas only, per
// `state("rheo-handle")` (lib.typ:2145). Under plain `typst compile` that
// state is never published (`here` and every idea's `handle` both read
// `none`), so this and the `rookery-wide: true` form below produce identical
// output here — the distinction only bites under rheo, where each vertebra
// publishes its own handle. Included to prove the call itself compiles.
#ideas-outline(title: [Page outline])

// `rookery-wide: true` — same notes, explicit whole-rookery form.
#ideas-outline(title: [Whole rookery], rookery-wide: true)

// `depth: 1` — caps to the top level only, dropping "Outline child".
#ideas-outline(title: [Depth-capped], rookery-wide: true, depth: 1)

// `title: none` — omits the heading entirely; the list still renders.
#ideas-outline(title: none, rookery-wide: true)
