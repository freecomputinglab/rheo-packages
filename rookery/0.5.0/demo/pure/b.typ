#import "../../src/lib.typ": idea, ideas-outline, window, hyperlink
#show ref: hyperlink

= Page B

A plain link back to page A: #link(label("idea:pinned"))[jump to the pinned note].
Same thing via #hyperlink: #hyperlink("pinned")[jump to the pinned note].

// Without `#show ref: hyperlink` above, `@idea:pinned` would resolve (the
// `<idea:pinned>` label exists as soon as `#idea("pinned")` runs) but render
// as a bare FIGURE NUMBER — Typst's default `@` rendering for a labeled
// figure, not the note's title. With the rule applied, it renders the note's
// title instead, linked, and an ordinary `@`-reference to a real figure
// elsewhere passes through unaffected.
Terse form, now that hyperlink is applied as the ref rule: @idea:pinned

A transcluded window of the same note:

#window("pinned")

// Two indexes of the same notes, side by side, because the PAIR is what shows
// the filter's one surprising rule. Unfiltered, `Pinned` sits one level down,
// inside the untitled note that contains it. Filtered to `phd`, that parent does
// not match — so it is pruned and `Pinned` is PROMOTED to the top level, rather
// than left dangling at a depth with no parent above it. A filter matching
// nothing would render no heading at all, where the unfiltered one always does.
//
// `rookery-wide: true` on both: the notes live on page A and this is page B, and
// the whole demo compiles as ONE Typst document, so the per-page default would
// leave both indexes empty here.
#ideas-outline(title: [Everything], rookery-wide: true)
#ideas-outline(title: [Tagged phd], rookery-wide: true, tags: "phd")
