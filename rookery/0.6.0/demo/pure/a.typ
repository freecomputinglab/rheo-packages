#import "../../src/lib.typ": idea

= Page A

// The tagged note sits inside a TITLED but UNTAGGED one, which is what makes
// page B's pair of `#ideas-outline` calls demonstrate PRUNE AND PROMOTE: the
// parent shows in the unfiltered index and does not match the filter, so under
// `tags: "phd"` it is pruned and the child re-based to the top level rather than
// left dangling at a depth with no parent above it.
//
// The parent needs a TITLE for that to be visible at all — though as of 0.6.0 it
// gets one either way: `_ideas-outline-data` skips only a note whose title is
// `none`, and `#idea` now DERIVES one from the body for every titleless note
// (`_derived-title`, src/pure.typ), so the skip is reached only by an empty-bodied
// note. The explicit title here is kept for legibility rather than necessity.
// `titles.typ` covers the derivation itself, and `paged.typ` still carries an
// untitled auto-id note.
//
// The child's two tags also put `idea-tag-phd idea-tag-draft` on its outline row.
#idea(title: [Auto note])[
  An auto-id note on page A.

  #idea("pinned", title: [Pinned], tags: ("phd", "draft"))[
    A pinned note, referenced cross-page from page B.
  ]
]
