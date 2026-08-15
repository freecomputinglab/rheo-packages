#import "../../src/lib.typ": idea, window, link-to-page
#show ref: link-to-page

= Page B

A plain link back to page A: #link(label("idea:pinned"))[jump to the pinned note].

// Without `#show ref: link-to-page` above, `@idea:pinned` would resolve (the
// `<idea:pinned>` label exists as soon as `#idea("pinned")` runs) but render
// as a bare FIGURE NUMBER — Typst's default `@` rendering for a labeled
// figure, not the note's title. With the rule applied, it renders the note's
// title instead, linked, and an ordinary `@`-reference to a real figure
// elsewhere passes through unaffected.
Terse form, now that link-to-page is applied: @idea:pinned

A transcluded window of the same note:

#window("pinned")
