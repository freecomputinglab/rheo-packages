#import "@rheo/rookery:0.1.0": view, ref-rule
#show ref: ref-rule

= Guide intro

A plain link back to the top-level notes page: #link(label("note:pinned"))[jump
to the pinned note].

// With ref-rule applied, `@note:pinned` renders the note's title, linked,
// cross-page too. See demo/pure/b.typ for what it renders as WITHOUT the
// rule applied (a bare figure number).
Terse form, now that ref-rule is applied: @note:pinned

A transcluded view of the same note, cross-page:

#view("pinned")

A truncated view, `limit: 1`, dropping the second paragraph:

#view("multi", limit: 1)
