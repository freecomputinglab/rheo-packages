#import "../../src/lib.typ": idea, view, ref-rule
#show ref: ref-rule

= Page B

A plain link back to page A: #link(label("idea:pinned"))[jump to the pinned note].

// Without `#show ref: ref-rule` above, `@idea:pinned` would resolve (the
// `<idea:pinned>` label exists as soon as `#idea("pinned")` runs) but render
// as a bare FIGURE NUMBER — Typst's default `@` rendering for a labeled
// figure, not the note's title. With the rule applied, it renders the note's
// title instead, linked, and an ordinary `@`-reference to a real figure
// elsewhere passes through unaffected.
Terse form, now that ref-rule is applied: @idea:pinned

A transcluded view of the same note:

#view("pinned")
